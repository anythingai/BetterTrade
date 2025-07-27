import Types "./types";
import Interfaces "./interfaces";
import InterCanister "./inter_canister";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Iter "mo:base/Iter";

module {
    // Transaction rollback and error recovery types
    public type TransactionState = {
        #pending;
        #committed;
        #rolled_back;
        #failed;
    };

    public type CompensatingAction = {
        canister: Principal;
        method: Text;
        payload: Text; // JSON serialized payload
        description: Text;
    };

    public type DistributedTransaction = {
        id: Text;
        user_id: Types.UserId;
        plan_id: ?Types.PlanId;
        state: TransactionState;
        participants: [Principal];
        actions: [CompensatingAction];
        compensating_actions: [CompensatingAction];
        started_at: Time.Time;
        completed_at: ?Time.Time;
        timeout_at: Time.Time;
    };

    // State synchronization types
    public type StateCheckpoint = {
        canister: Principal;
        state_hash: Text;
        timestamp: Time.Time;
        version: Nat;
    };

    public type SynchronizationResult = {
        #synchronized;
        #conflict: {
            conflicting_canisters: [Principal];
            resolution_strategy: ConflictResolution;
        };
        #timeout;
        #error: Text;
    };

    public type ConflictResolution = {
        #latest_timestamp;
        #highest_version;
        #manual_intervention;
        #rollback_all;
    };

    // Idempotency types
    public type IdempotencyKey = Text;
    
    public type IdempotentOperation = {
        key: IdempotencyKey;
        canister: Principal;
        method: Text;
        payload_hash: Text;
        result: ?Text; // Serialized result
        status: OperationStatus;
        created_at: Time.Time;
        expires_at: Time.Time;
    };

    public type OperationStatus = {
        #pending;
        #completed;
        #failed;
        #expired;
    };

    // Data consistency coordinator
    public class DataConsistencyCoordinator(
        canister_registry: Interfaces.CanisterRegistry,
        communicator: InterCanister.AgentCommunicator
    ) {
        
        // Distributed transaction management
        private var active_transactions = HashMap.HashMap<Text, DistributedTransaction>(0, Text.equal, Text.hash);
        private var idempotent_operations = HashMap.HashMap<IdempotencyKey, IdempotentOperation>(0, Text.equal, Text.hash);
        private var state_checkpoints = HashMap.HashMap<Principal, StateCheckpoint>(0, Principal.equal, Principal.hash);

        // Two-phase commit protocol for distributed transactions
        public func begin_distributed_transaction(
            user_id: Types.UserId,
            plan_id: ?Types.PlanId,
            participants: [Principal],
            timeout_seconds: Nat
        ) : async Types.Result<Text, Types.ApiError> {
            let tx_id = generate_transaction_id(user_id, plan_id);
            let timeout_ns = Time.now() + (Int.abs(timeout_seconds) * 1_000_000_000);
            
            let transaction = {
                id = tx_id;
                user_id = user_id;
                plan_id = plan_id;
                state = #pending;
                participants = participants;
                actions = [];
                compensating_actions = [];
                started_at = Time.now();
                completed_at = null;
                timeout_at = timeout_ns;
            };
            
            active_transactions.put(tx_id, transaction);
            
            // Log transaction start
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "data_consistency";
                action = "distributed_transaction_started";
                user_id = ?user_id;
                transaction_id = ?tx_id;
                details = "Started distributed transaction with " # Nat.toText(participants.size()) # " participants";
            });
            
            #ok(tx_id);
        };

        public func add_transaction_action(
            tx_id: Text,
            canister: Principal,
            method: Text,
            payload: Text,
            compensating_method: Text,
            compensating_payload: Text
        ) : async Types.Result<Bool, Types.ApiError> {
            switch (active_transactions.get(tx_id)) {
                case (?transaction) {
                    if (transaction.state != #pending) {
                        return #err(#invalid_input("Transaction is not in pending state"));
                    };
                    
                    let action = {
                        canister = canister;
                        method = method;
                        payload = payload;
                        description = "Action: " # method # " on " # Principal.toText(canister);
                    };
                    
                    let compensating_action = {
                        canister = canister;
                        method = compensating_method;
                        payload = compensating_payload;
                        description = "Compensating: " # compensating_method # " on " # Principal.toText(canister);
                    };
                    
                    let updated_transaction = {
                        id = transaction.id;
                        user_id = transaction.user_id;
                        plan_id = transaction.plan_id;
                        state = transaction.state;
                        participants = transaction.participants;
                        actions = Array.append(transaction.actions, [action]);
                        compensating_actions = Array.append(transaction.compensating_actions, [compensating_action]);
                        started_at = transaction.started_at;
                        completed_at = transaction.completed_at;
                        timeout_at = transaction.timeout_at;
                    };
                    
                    active_transactions.put(tx_id, updated_transaction);
                    #ok(true);
                };
                case null {
                    #err(#not_found);
                };
            };
        };

        public func commit_distributed_transaction(tx_id: Text) : async Types.Result<Bool, Types.ApiError> {
            switch (active_transactions.get(tx_id)) {
                case (?transaction) {
                    if (transaction.state != #pending) {
                        return #err(#invalid_input("Transaction is not in pending state"));
                    };
                    
                    // Check if transaction has timed out
                    if (Time.now() > transaction.timeout_at) {
                        ignore await rollback_distributed_transaction(tx_id);
                        return #err(#internal_error("Transaction timed out"));
                    };
                    
                    // Phase 1: Prepare all participants
                    let prepare_results = await prepare_all_participants(transaction);
                    let all_prepared = Array.foldLeft<Bool, Bool>(prepare_results, true, func(acc, result) { acc and result });
                    
                    if (not all_prepared) {
                        // If any participant failed to prepare, rollback
                        ignore await rollback_distributed_transaction(tx_id);
                        return #err(#internal_error("Failed to prepare all participants"));
                    };
                    
                    // Phase 2: Commit all participants
                    let commit_results = await commit_all_participants(transaction);
                    let all_committed = Array.foldLeft<Bool, Bool>(commit_results, true, func(acc, result) { acc and result });
                    
                    if (all_committed) {
                        let committed_transaction = {
                            id = transaction.id;
                            user_id = transaction.user_id;
                            plan_id = transaction.plan_id;
                            state = #committed;
                            participants = transaction.participants;
                            actions = transaction.actions;
                            compensating_actions = transaction.compensating_actions;
                            started_at = transaction.started_at;
                            completed_at = ?Time.now();
                            timeout_at = transaction.timeout_at;
                        };
                        
                        active_transactions.put(tx_id, committed_transaction);
                        
                        communicator.log_audit_entry({
                            timestamp = Time.now();
                            canister = "data_consistency";
                            action = "distributed_transaction_committed";
                            user_id = ?transaction.user_id;
                            transaction_id = ?tx_id;
                            details = "Successfully committed distributed transaction";
                        });
                        
                        #ok(true);
                    } else {
                        // If commit failed, attempt rollback
                        ignore await rollback_distributed_transaction(tx_id);
                        #err(#internal_error("Failed to commit all participants"));
                    };
                };
                case null {
                    #err(#not_found);
                };
            };
        };

        public func rollback_distributed_transaction(tx_id: Text) : async Types.Result<Bool, Types.ApiError> {
            switch (active_transactions.get(tx_id)) {
                case (?transaction) {
                    // Execute compensating actions in reverse order
                    let reversed_actions = Array.reverse(transaction.compensating_actions);
                    
                    for (action in reversed_actions.vals()) {
                        try {
                            // Execute compensating action
                            let result = await execute_compensating_action(action);
                            switch (result) {
                                case (#ok(_)) {
                                    communicator.log_audit_entry({
                                        timestamp = Time.now();
                                        canister = "data_consistency";
                                        action = "compensating_action_executed";
                                        user_id = ?transaction.user_id;
                                        transaction_id = ?tx_id;
                                        details = action.description;
                                    });
                                };
                                case (#err(error)) {
                                    communicator.log_audit_entry({
                                        timestamp = Time.now();
                                        canister = "data_consistency";
                                        action = "compensating_action_failed";
                                        user_id = ?transaction.user_id;
                                        transaction_id = ?tx_id;
                                        details = "Failed: " # action.description # " - " # debug_show(error);
                                    });
                                };
                            };
                        } catch (error) {
                            communicator.log_audit_entry({
                                timestamp = Time.now();
                                canister = "data_consistency";
                                action = "compensating_action_error";
                                user_id = ?transaction.user_id;
                                transaction_id = ?tx_id;
                                details = "Error executing: " # action.description # " - " # debug_show(error);
                            });
                        };
                    };
                    
                    let rolled_back_transaction = {
                        id = transaction.id;
                        user_id = transaction.user_id;
                        plan_id = transaction.plan_id;
                        state = #rolled_back;
                        participants = transaction.participants;
                        actions = transaction.actions;
                        compensating_actions = transaction.compensating_actions;
                        started_at = transaction.started_at;
                        completed_at = ?Time.now();
                        timeout_at = transaction.timeout_at;
                    };
                    
                    active_transactions.put(tx_id, rolled_back_transaction);
                    
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "data_consistency";
                        action = "distributed_transaction_rolled_back";
                        user_id = ?transaction.user_id;
                        transaction_id = ?tx_id;
                        details = "Successfully rolled back distributed transaction";
                    });
                    
                    #ok(true);
                };
                case null {
                    #err(#not_found);
                };
            };
        };

        // State synchronization mechanisms
        public func create_state_checkpoint(canister: Principal, state_data: Text) : async Text {
            let state_hash = hash_state_data(state_data);
            let version = switch (state_checkpoints.get(canister)) {
                case (?existing) existing.version + 1;
                case null 1;
            };
            
            let checkpoint = {
                canister = canister;
                state_hash = state_hash;
                timestamp = Time.now();
                version = version;
            };
            
            state_checkpoints.put(canister, checkpoint);
            
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "data_consistency";
                action = "state_checkpoint_created";
                user_id = null;
                transaction_id = null;
                details = "Created checkpoint for " # Principal.toText(canister) # " v" # Nat.toText(version);
            });
            
            state_hash;
        };

        public func synchronize_state_across_canisters(
            canisters: [Principal],
            timeout_seconds: Nat
        ) : async SynchronizationResult {
            let timeout_ns = Time.now() + (Int.abs(timeout_seconds) * 1_000_000_000);
            
            // Collect current state from all canisters
            let state_results = Buffer.Buffer<(Principal, StateCheckpoint)>(canisters.size());
            
            for (canister in canisters.vals()) {
                if (Time.now() > timeout_ns) {
                    return #timeout;
                };
                
                switch (state_checkpoints.get(canister)) {
                    case (?checkpoint) {
                        state_results.add((canister, checkpoint));
                    };
                    case null {
                        // Create initial checkpoint
                        let initial_checkpoint = {
                            canister = canister;
                            state_hash = "initial";
                            timestamp = Time.now();
                            version = 0;
                        };
                        state_checkpoints.put(canister, initial_checkpoint);
                        state_results.add((canister, initial_checkpoint));
                    };
                };
            };
            
            // Check for conflicts
            let checkpoints = Buffer.toArray(state_results);
            let conflicts = find_state_conflicts(checkpoints);
            
            if (conflicts.size() > 0) {
                let resolution_strategy = determine_conflict_resolution(conflicts);
                
                switch (resolution_strategy) {
                    case (#latest_timestamp) {
                        await resolve_conflicts_by_timestamp(conflicts);
                        #synchronized;
                    };
                    case (#highest_version) {
                        await resolve_conflicts_by_version(conflicts);
                        #synchronized;
                    };
                    case (#rollback_all) {
                        await rollback_all_conflicting_states(conflicts);
                        #synchronized;
                    };
                    case (#manual_intervention) {
                        #conflict({
                            conflicting_canisters = Array.map<(Principal, StateCheckpoint), Principal>(conflicts, func((canister, _)) { canister });
                            resolution_strategy = #manual_intervention;
                        });
                    };
                };
            } else {
                #synchronized;
            };
        };

        // Idempotent operations
        public func execute_idempotent_operation(
            key: IdempotencyKey,
            canister: Principal,
            method: Text,
            payload: Text,
            ttl_seconds: Nat
        ) : async Types.Result<Text, Types.ApiError> {
            let payload_hash = hash_payload(payload);
            let expires_at = Time.now() + (Int.abs(ttl_seconds) * 1_000_000_000);
            
            // Check if operation already exists
            switch (idempotent_operations.get(key)) {
                case (?existing_op) {
                    // Check if it's the same operation
                    if (existing_op.canister == canister and 
                        existing_op.method == method and 
                        existing_op.payload_hash == payload_hash) {
                        
                        switch (existing_op.status) {
                            case (#completed) {
                                // Return cached result
                                switch (existing_op.result) {
                                    case (?result) #ok(result);
                                    case null #err(#internal_error("Completed operation has no result"));
                                };
                            };
                            case (#pending) {
                                #err(#internal_error("Operation is still pending"));
                            };
                            case (#failed) {
                                // Retry failed operation
                                await retry_idempotent_operation(key, canister, method, payload, expires_at);
                            };
                            case (#expired) {
                                // Create new operation
                                await create_new_idempotent_operation(key, canister, method, payload, payload_hash, expires_at);
                            };
                        };
                    } else {
                        #err(#invalid_input("Idempotency key conflict: different operation with same key"));
                    };
                };
                case null {
                    // Create new operation
                    await create_new_idempotent_operation(key, canister, method, payload, payload_hash, expires_at);
                };
            };
        };

        // Helper functions for distributed transactions
        private func prepare_all_participants(transaction: DistributedTransaction) : async [Bool] {
            let results = Buffer.Buffer<Bool>(transaction.participants.size());
            
            for (participant in transaction.participants.vals()) {
                try {
                    // In a real implementation, this would call a prepare method on each canister
                    // For now, we'll simulate preparation
                    let prepare_result = await simulate_prepare_participant(participant, transaction);
                    results.add(prepare_result);
                } catch (error) {
                    results.add(false);
                };
            };
            
            Buffer.toArray(results);
        };

        private func commit_all_participants(transaction: DistributedTransaction) : async [Bool] {
            let results = Buffer.Buffer<Bool>(transaction.participants.size());
            
            for (participant in transaction.participants.vals()) {
                try {
                    // In a real implementation, this would call a commit method on each canister
                    let commit_result = await simulate_commit_participant(participant, transaction);
                    results.add(commit_result);
                } catch (error) {
                    results.add(false);
                };
            };
            
            Buffer.toArray(results);
        };

        private func execute_compensating_action(action: CompensatingAction) : async Types.Result<Bool, Types.ApiError> {
            // In a real implementation, this would make an actual inter-canister call
            // For now, we'll simulate the execution
            try {
                let result = await simulate_compensating_action(action);
                #ok(result);
            } catch (error) {
                #err(#internal_error("Compensating action failed: " # debug_show(error)));
            };
        };

        // Helper functions for state synchronization
        private func find_state_conflicts(checkpoints: [(Principal, StateCheckpoint)]) : [(Principal, StateCheckpoint)] {
            // Simple conflict detection - in production this would be more sophisticated
            let conflicts = Buffer.Buffer<(Principal, StateCheckpoint)>(0);
            
            // Group by timestamp and find conflicts
            for ((canister, checkpoint) in checkpoints.vals()) {
                // Check if this checkpoint conflicts with others
                for ((other_canister, other_checkpoint) in checkpoints.vals()) {
                    if (canister != other_canister and 
                        checkpoint.state_hash != other_checkpoint.state_hash and
                        Int.abs(checkpoint.timestamp - other_checkpoint.timestamp) < 1_000_000_000) { // Within 1 second
                        conflicts.add((canister, checkpoint));
                    };
                };
            };
            
            Buffer.toArray(conflicts);
        };

        private func determine_conflict_resolution(conflicts: [(Principal, StateCheckpoint)]) : ConflictResolution {
            // Simple resolution strategy - in production this would be configurable
            if (conflicts.size() <= 2) {
                #latest_timestamp;
            } else if (conflicts.size() <= 5) {
                #highest_version;
            } else {
                #manual_intervention;
            };
        };

        private func resolve_conflicts_by_timestamp(conflicts: [(Principal, StateCheckpoint)]) : async () {
            // Find the latest checkpoint
            var latest_checkpoint: ?StateCheckpoint = null;
            var latest_canister: ?Principal = null;
            
            for ((canister, checkpoint) in conflicts.vals()) {
                switch (latest_checkpoint) {
                    case null {
                        latest_checkpoint := ?checkpoint;
                        latest_canister := ?canister;
                    };
                    case (?current_latest) {
                        if (checkpoint.timestamp > current_latest.timestamp) {
                            latest_checkpoint := ?checkpoint;
                            latest_canister := ?canister;
                        };
                    };
                };
            };
            
            // Apply the latest state to all conflicting canisters
            switch (latest_checkpoint, latest_canister) {
                case (?checkpoint, ?source_canister) {
                    for ((canister, _) in conflicts.vals()) {
                        if (canister != source_canister) {
                            state_checkpoints.put(canister, checkpoint);
                        };
                    };
                    
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "data_consistency";
                        action = "conflict_resolved_by_timestamp";
                        user_id = null;
                        transaction_id = null;
                        details = "Resolved " # Nat.toText(conflicts.size()) # " conflicts using latest timestamp";
                    });
                };
                case (_, _) {};
            };
        };

        private func resolve_conflicts_by_version(conflicts: [(Principal, StateCheckpoint)]) : async () {
            // Find the highest version checkpoint
            var highest_checkpoint: ?StateCheckpoint = null;
            var highest_canister: ?Principal = null;
            
            for ((canister, checkpoint) in conflicts.vals()) {
                switch (highest_checkpoint) {
                    case null {
                        highest_checkpoint := ?checkpoint;
                        highest_canister := ?canister;
                    };
                    case (?current_highest) {
                        if (checkpoint.version > current_highest.version) {
                            highest_checkpoint := ?checkpoint;
                            highest_canister := ?canister;
                        };
                    };
                };
            };
            
            // Apply the highest version state to all conflicting canisters
            switch (highest_checkpoint, highest_canister) {
                case (?checkpoint, ?source_canister) {
                    for ((canister, _) in conflicts.vals()) {
                        if (canister != source_canister) {
                            state_checkpoints.put(canister, checkpoint);
                        };
                    };
                    
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "data_consistency";
                        action = "conflict_resolved_by_version";
                        user_id = null;
                        transaction_id = null;
                        details = "Resolved " # Nat.toText(conflicts.size()) # " conflicts using highest version";
                    });
                };
                case (_, _) {};
            };
        };

        private func rollback_all_conflicting_states(conflicts: [(Principal, StateCheckpoint)]) : async () {
            // Rollback all conflicting states to a previous consistent state
            for ((canister, checkpoint) in conflicts.vals()) {
                let rollback_checkpoint = {
                    canister = canister;
                    state_hash = "rollback_" # checkpoint.state_hash;
                    timestamp = Time.now();
                    version = checkpoint.version + 1;
                };
                
                state_checkpoints.put(canister, rollback_checkpoint);
            };
            
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "data_consistency";
                action = "conflicts_rolled_back";
                user_id = null;
                transaction_id = null;
                details = "Rolled back " # Nat.toText(conflicts.size()) # " conflicting states";
            });
        };

        // Helper functions for idempotent operations
        private func create_new_idempotent_operation(
            key: IdempotencyKey,
            canister: Principal,
            method: Text,
            payload: Text,
            payload_hash: Text,
            expires_at: Time.Time
        ) : async Types.Result<Text, Types.ApiError> {
            let operation = {
                key = key;
                canister = canister;
                method = method;
                payload_hash = payload_hash;
                result = null;
                status = #pending;
                created_at = Time.now();
                expires_at = expires_at;
            };
            
            idempotent_operations.put(key, operation);
            
            // Execute the operation
            try {
                let result = await simulate_operation_execution(canister, method, payload);
                
                let completed_operation = {
                    key = key;
                    canister = canister;
                    method = method;
                    payload_hash = payload_hash;
                    result = ?result;
                    status = #completed;
                    created_at = operation.created_at;
                    expires_at = expires_at;
                };
                
                idempotent_operations.put(key, completed_operation);
                #ok(result);
            } catch (error) {
                let failed_operation = {
                    key = key;
                    canister = canister;
                    method = method;
                    payload_hash = payload_hash;
                    result = null;
                    status = #failed;
                    created_at = operation.created_at;
                    expires_at = expires_at;
                };
                
                idempotent_operations.put(key, failed_operation);
                #err(#internal_error("Operation execution failed: " # debug_show(error)));
            };
        };

        private func retry_idempotent_operation(
            key: IdempotencyKey,
            canister: Principal,
            method: Text,
            payload: Text,
            expires_at: Time.Time
        ) : async Types.Result<Text, Types.ApiError> {
            // Retry the failed operation
            await create_new_idempotent_operation(key, canister, method, payload, hash_payload(payload), expires_at);
        };

        // Simulation functions (would be replaced with actual inter-canister calls in production)
        private func simulate_prepare_participant(participant: Principal, transaction: DistributedTransaction) : async Bool {
            // Simulate preparation logic
            true;
        };

        private func simulate_commit_participant(participant: Principal, transaction: DistributedTransaction) : async Bool {
            // Simulate commit logic
            true;
        };

        private func simulate_compensating_action(action: CompensatingAction) : async Bool {
            // Simulate compensating action execution
            true;
        };

        private func simulate_operation_execution(canister: Principal, method: Text, payload: Text) : async Text {
            // Simulate operation execution
            "simulated_result_" # method # "_" # Principal.toText(canister);
        };

        // Utility functions
        private func generate_transaction_id(user_id: Types.UserId, plan_id: ?Types.PlanId) : Text {
            let timestamp = Time.now();
            let user_text = Principal.toText(user_id);
            let plan_text = switch (plan_id) {
                case (?pid) pid;
                case null "no_plan";
            };
            "dtx_" # user_text # "_" # plan_text # "_" # Int.toText(timestamp);
        };

        private func hash_state_data(data: Text) : Text {
            // Simple hash function - in production would use proper cryptographic hash
            "hash_" # Int.toText(Text.hash(data)) # "_" # Int.toText(Time.now());
        };

        private func hash_payload(payload: Text) : Text {
            // Simple hash function - in production would use proper cryptographic hash
            "payload_hash_" # Int.toText(Text.hash(payload));
        };

        // Monitoring and health checks
        public func get_consistency_stats() : {
            active_transactions: Nat;
            completed_transactions: Nat;
            failed_transactions: Nat;
            idempotent_operations: Nat;
            state_checkpoints: Nat;
        } {
            var completed_count = 0;
            var failed_count = 0;
            
            for (transaction in active_transactions.vals()) {
                switch (transaction.state) {
                    case (#committed) completed_count += 1;
                    case (#failed or #rolled_back) failed_count += 1;
                    case (_) {};
                };
            };
            
            {
                active_transactions = active_transactions.size();
                completed_transactions = completed_count;
                failed_transactions = failed_count;
                idempotent_operations = idempotent_operations.size();
                state_checkpoints = state_checkpoints.size();
            };
        };

        public func cleanup_expired_operations() : async Nat {
            let current_time = Time.now();
            var cleaned_count = 0;
            
            // Clean up expired idempotent operations
            let expired_keys = Buffer.Buffer<IdempotencyKey>(0);
            
            for ((key, operation) in idempotent_operations.entries()) {
                if (current_time > operation.expires_at) {
                    expired_keys.add(key);
                };
            };
            
            for (key in expired_keys.vals()) {
                idempotent_operations.delete(key);
                cleaned_count += 1;
            };
            
            // Clean up old completed transactions (keep for 24 hours)
            let transaction_expiry = current_time - (24 * 60 * 60 * 1_000_000_000); // 24 hours
            let expired_tx_ids = Buffer.Buffer<Text>(0);
            
            for ((tx_id, transaction) in active_transactions.entries()) {
                if (transaction.state == #committed or transaction.state == #rolled_back) {
                    switch (transaction.completed_at) {
                        case (?completed_time) {
                            if (completed_time < transaction_expiry) {
                                expired_tx_ids.add(tx_id);
                            };
                        };
                        case null {};
                    };
                };
            };
            
            for (tx_id in expired_tx_ids.vals()) {
                active_transactions.delete(tx_id);
                cleaned_count += 1;
            };
            
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "data_consistency";
                action = "cleanup_completed";
                user_id = null;
                transaction_id = null;
                details = "Cleaned up " # Nat.toText(cleaned_count) # " expired operations and transactions";
            });
            
            cleaned_count;
        };
    };
}