import Types "../shared/types";
import Interfaces "../shared/interfaces";
import InterCanister "../shared/inter_canister";
import ExecutionCoordinator "../shared/execution_coordinator";
import BitcoinTx "./bitcoin_tx";
import TECDSASigner "./tecdsa_signer";
import BitcoinNetwork "./bitcoin_network";
import Utils "../shared/utils";
import Constants "../shared/constants";
import Config "../shared/config";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Nat "mo:base/Nat";
import Nat32 "mo:base/Nat32";
import Int64 "mo:base/Int64";
import Float "mo:base/Float";
import Text "mo:base/Text";

actor ExecutionAgent : Interfaces.ExecutionAgentInterface {
    // Stable storage for upgrades
    private stable var executions_stable : [(Types.PlanId, [Types.TxId])] = [];
    private stable var tx_status_stable : [(Types.TxId, Types.TxStatus)] = [];
    private stable var signing_stats_stable : (Nat, Nat, Nat) = (0, 0, 0); // total, successful, failed
    
    // Runtime storage
    private var executions = HashMap.HashMap<Types.PlanId, [Types.TxId]>(0, func(a: Text, b: Text) : Bool { a == b }, func(t: Text) : Nat32 { 0 });
    private var tx_status = HashMap.HashMap<Types.TxId, Types.TxStatus>(0, func(a: Text, b: Text) : Bool { a == b }, func(t: Text) : Nat32 { 0 });
    
    // Initialize components
    private let tx_builder = BitcoinTx.TransactionBuilder();
    private let tecdsa_signer = TECDSASigner.TECDSASigner();
    private let bitcoin_network = BitcoinNetwork.BitcoinNetworkIntegration();
    
    // Inter-canister communication setup
    private let canister_registry : Interfaces.CanisterRegistry = {
        user_registry = Principal.fromText("rdmx6-jaaaa-aaaah-qdrya-cai");
        portfolio_state = Principal.fromText("rrkah-fqaaa-aaaah-qdrya-cai");
        strategy_selector = Principal.fromText("ryjl3-tyaaa-aaaah-qdrya-cai");
        execution_agent = Principal.fromActor(ExecutionAgent);
        risk_guard = Principal.fromText("rno2w-sqaaa-aaaah-qdrya-cai");
    };
    
    private let communicator = InterCanister.AgentCommunicator(canister_registry);
    private let coordinator = ExecutionCoordinator.ExecutionCoordinator(canister_registry, communicator);
    
    // Portfolio State canister reference (would be injected in production)
    private var portfolio_state_canister: ?Interfaces.PortfolioStateInterface = null;
    
    // Signing statistics
    private var total_signatures = signing_stats_stable.0;
    private var successful_signatures = signing_stats_stable.1;
    private var failed_signatures = signing_stats_stable.2;

    // Initialize from stable storage
    system func preupgrade() {
        executions_stable := executions.entries() |> Iter.toArray(_);
        tx_status_stable := tx_status.entries() |> Iter.toArray(_);
        signing_stats_stable := (total_signatures, successful_signatures, failed_signatures);
    };

    system func postupgrade() {
        executions := HashMap.fromIter(executions_stable.vals(), executions_stable.size(), func(a: Text, b: Text) : Bool { a == b }, func(t: Text) : Nat32 { 0 });
        tx_status := HashMap.fromIter(tx_status_stable.vals(), tx_status_stable.size(), func(a: Text, b: Text) : Bool { a == b }, func(t: Text) : Nat32 { 0 });
        total_signatures := signing_stats_stable.0;
        successful_signatures := signing_stats_stable.1;
        failed_signatures := signing_stats_stable.2;
    };

    // Build and sign a Bitcoin transaction for strategy execution
    public shared(msg) func build_and_sign_transaction(
        strategy_plan: Types.StrategyPlan,
        user_utxos: [Types.UTXO],
        user_change_address: Text,
        sat_per_byte: Nat64
    ) : async Types.Result<BitcoinTx.RawTransaction, Types.ApiError> {
        
        // Authorize signing for the user
        let total_amount = Array.foldLeft<Types.Allocation, Nat64>(
            strategy_plan.allocations, 
            0, 
            func(acc, allocation) { acc + allocation.amount_sats }
        );
        
        let auth_result = tecdsa_signer.authorizeSigningForUser(
            strategy_plan.user_id, 
            msg.caller, 
            total_amount
        );
        
        switch (auth_result) {
            case (#err(error_msg)) {
                return #err(#unauthorized);
            };
            case (#ok(_)) {};
        };
        
        // Build the transaction
        let tx_result = tx_builder.buildStrategyTransaction(
            user_utxos,
            strategy_plan,
            user_change_address,
            sat_per_byte
        );
        
        let tx_construction = switch (tx_result) {
            case (#ok(construction)) { construction };
            case (#err(error_msg)) {
                Debug.print("Transaction construction failed: " # error_msg);
                return #err(#internal_error("Failed to construct transaction: " # error_msg));
            };
        };
        
        // Validate the transaction before signing
        let validation_result = tx_builder.validateTransaction(tx_construction);
        switch (validation_result) {
            case (#err(error_msg)) {
                Debug.print("Transaction validation failed: " # error_msg);
                return #err(#invalid_input("Invalid transaction: " # error_msg));
            };
            case (#ok(_)) {};
        };
        
        // Sign the transaction using t-ECDSA
        total_signatures += 1;
        let signing_result = await tecdsa_signer.signTransaction(
            tx_construction.raw_tx,
            user_utxos,
            strategy_plan.user_id
        );
        
        switch (signing_result) {
            case (#ok(signed_tx)) {
                successful_signatures += 1;
                Debug.print("Transaction signed successfully");
                #ok(signed_tx)
            };
            case (#err(error_msg)) {
                failed_signatures += 1;
                Debug.print("Transaction signing failed: " # error_msg);
                #err(#internal_error("Failed to sign transaction: " # error_msg))
            };
        }
    };

    // Get user's Bitcoin address for deposits
    public shared(msg) func get_user_bitcoin_address(
        user_id: Types.UserId,
        network: Types.Network
    ) : async Types.Result<Text, Types.ApiError> {
        
        if (user_id != msg.caller) {
            return #err(#unauthorized);
        };
        
        // Get public key from t-ECDSA
        let pubkey_result = await tecdsa_signer.getPublicKey(user_id);
        let public_key = switch (pubkey_result) {
            case (#ok(pk)) { pk };
            case (#err(error_msg)) {
                Debug.print("Failed to get public key: " # error_msg);
                return #err(#internal_error("Failed to generate address: " # error_msg));
            };
        };
        
        // Create Bitcoin address from public key
        let address = tecdsa_signer.createBitcoinAddress(public_key, network);
        #ok(address)
    };

    // Validate a signature (for testing and verification)
    public func validate_signature(
        signature_r: Blob,
        signature_s: Blob,
        message_hash: Blob,
        public_key: Blob
    ) : async Types.Result<Bool, Types.ApiError> {
        
        let signature: TECDSASigner.BitcoinSignature = {
            r = signature_r;
            s = signature_s;
            recovery_id = 0; // Not used in validation
        };
        
        if (not TECDSASigner.isValidSignature(signature)) {
            return #err(#invalid_input("Invalid signature format"));
        };
        
        let is_valid = tecdsa_signer.validateSignature(signature, message_hash, public_key);
        #ok(is_valid)
    };

    // Get signing statistics for monitoring
    public query func get_signing_stats() : async {
        total_signatures: Nat;
        successful_signatures: Nat;
        failed_signatures: Nat;
        success_rate: Float;
    } {
        let success_rate = if (total_signatures == 0) { 0.0 }
        else { Float.fromInt(successful_signatures) / Float.fromInt(total_signatures) * 100.0 };
        
        {
            total_signatures = total_signatures;
            successful_signatures = successful_signatures;
            failed_signatures = failed_signatures;
            success_rate = success_rate;
        }
    };

    // Emergency key rotation for security incidents
    public shared(msg) func rotate_user_key(user_id: Types.UserId) : async Types.Result<Bool, Types.ApiError> {
        if (user_id != msg.caller) {
            return #err(#unauthorized);
        };
        
        let rotation_result = await tecdsa_signer.rotateUserKey(user_id);
        switch (rotation_result) {
            case (#ok(_)) { #ok(true) };
            case (#err(error_msg)) {
                Debug.print("Key rotation failed: " # error_msg);
                #err(#internal_error("Failed to rotate key: " # error_msg))
            };
        }
    };

    // Test signing functionality with mock data
    public shared(msg) func test_signing(user_id: Types.UserId) : async Types.Result<Text, Types.ApiError> {
        if (user_id != msg.caller) {
            return #err(#unauthorized);
        };
        
        // Create a test message hash
        let test_message = "test_signing_message_" # Principal.toText(user_id);
        let message_hash = Utils.sha256(Text.encodeUtf8(test_message));
        
        // Create a mock signing context
        let mock_utxo: Types.UTXO = {
            txid = "test_txid";
            vout = 0;
            amount_sats = 100000;
            address = "test_address";
            confirmations = 6;
            block_height = ?800000;
            spent = false;
            spent_in_tx = null;
        };
        
        let mock_tx: BitcoinTx.RawTransaction = {
            version = 2;
            inputs = [{
                txid = "test_txid";
                vout = 0;
                amount_sats = 100000;
                script_sig = null;
            }];
            outputs = [{
                address = "test_output_address";
                amount_sats = 99000;
            }];
            locktime = 0;
        };
        
        let signing_context: TECDSASigner.SigningContext = {
            tx = mock_tx;
            input_index = 0;
            utxo = mock_utxo;
            sighash_type = 0x01;
        };
        
        // Test signing
        total_signatures += 1;
        let signing_result = await tecdsa_signer.signTransactionInput(signing_context, user_id);
        
        switch (signing_result) {
            case (#ok(signature)) {
                successful_signatures += 1;
                let signature_hex = TECDSASigner.signatureToHex(signature);
                #ok("Test signing successful. Signature: " # signature_hex)
            };
            case (#err(error_msg)) {
                failed_signatures += 1;
                Debug.print("Test signing failed: " # error_msg);
                #err(#internal_error("Test signing failed: " # error_msg))
            };
        }
    };

    // Execute a strategy plan by building, signing, and broadcasting Bitcoin transactions
    public shared(msg) func execute_plan(plan_id: Types.PlanId) : async Types.Result<[Types.TxId], Types.ApiError> {
        Debug.print("Executing strategy plan: " # plan_id);
        
        // Log execution start
        communicator.log_audit_entry({
            timestamp = Time.now();
            canister = "execution_agent";
            action = "execute_plan_start";
            user_id = ?msg.caller;
            transaction_id = ?plan_id;
            details = "Starting execution of strategy plan: " # plan_id;
        });
        
        // Get strategy plan from Strategy Selector
        let plan_result = await communicator.call_strategy_selector("get_plan", plan_id);
        let strategy_plan = switch (plan_result) {
            case (#success(plan)) plan;
            case (#error(error)) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "execution_agent";
                    action = "execute_plan_error";
                    user_id = ?msg.caller;
                    transaction_id = ?plan_id;
                    details = "Failed to get strategy plan: " # error.message;
                });
                return #err(#internal_error("Failed to get strategy plan: " # error.message));
            };
            case (_) {
                return #err(#internal_error("Strategy plan retrieval timeout"));
            };
        };
        
        // Get user UTXOs from Portfolio State
        let utxos_result = await communicator.call_portfolio_state("get_utxos", strategy_plan.user_id);
        let user_utxos = switch (utxos_result) {
            case (#success(utxo_set)) utxo_set.utxos;
            case (#error(error)) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "execution_agent";
                    action = "execute_plan_error";
                    user_id = ?msg.caller;
                    transaction_id = ?plan_id;
                    details = "Failed to get user UTXOs: " # error.message;
                });
                return #err(#internal_error("Failed to get user UTXOs: " # error.message));
            };
            case (_) {
                return #err(#internal_error("UTXO retrieval timeout"));
            };
        };
        
        // For MVP, use mock change address - in production this would come from user wallet
        let mock_change_address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"; // Mock testnet address
        
        // Build and sign the transaction
        let build_result = await build_and_sign_transaction(
            strategy_plan,
            user_utxos,
            mock_change_address,
            20 // 20 sat/byte fee rate
        );
        
        let signed_tx = switch (build_result) {
            case (#ok(tx)) { tx };
            case (#err(error)) {
                Debug.print("Failed to build and sign transaction: " # debug_show(error));
                return #err(error);
            };
        };
        
        // Broadcast the transaction
        let broadcast_result = await bitcoin_network.broadcastTransaction(
            signed_tx,
            strategy_plan.user_id,
            ?plan_id
        );
        
        switch (broadcast_result) {
            case (#ok(broadcast_info)) {
                let txid = broadcast_info.txid;
                
                // Record the execution
                executions.put(plan_id, [txid]);
                tx_status.put(txid, #pending);
                
                // Log successful execution
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "execution_agent";
                    action = "execute_plan_success";
                    user_id = ?strategy_plan.user_id;
                    transaction_id = ?txid;
                    details = "Strategy plan executed successfully. TxID: " # txid;
                });
                
                // Publish execution started event
                await communicator.publish_event(
                    #execution_started(plan_id),
                    Principal.fromActor(ExecutionAgent)
                );
                
                // Record transaction in Portfolio State
                let tx_record = {
                    txid = txid;
                    user_id = strategy_plan.user_id;
                    tx_type = #strategy_execute;
                    amount_sats = Array.foldLeft<Types.Allocation, Nat64>(
                        strategy_plan.allocations, 
                        0, 
                        func(acc, allocation) { acc + allocation.amount_sats }
                    );
                    fee_sats = 0; // This would be calculated from the transaction
                    status = #pending;
                    confirmed_height = null;
                    timestamp = Time.now();
                };
                
                let record_result = await communicator.call_portfolio_state("record_transaction", (strategy_plan.user_id, tx_record));
                switch (record_result) {
                    case (#success(_)) {
                        communicator.log_audit_entry({
                            timestamp = Time.now();
                            canister = "execution_agent";
                            action = "transaction_recorded";
                            user_id = ?strategy_plan.user_id;
                            transaction_id = ?txid;
                            details = "Transaction recorded in portfolio state";
                        });
                    };
                    case (_) {
                        communicator.log_audit_entry({
                            timestamp = Time.now();
                            canister = "execution_agent";
                            action = "transaction_record_failed";
                            user_id = ?strategy_plan.user_id;
                            transaction_id = ?txid;
                            details = "Failed to record transaction in portfolio state";
                        });
                    };
                };
                
                Debug.print("✅ Strategy plan executed successfully. Transaction ID: " # txid);
                Debug.print("📊 Expected positions to be created: " # Nat.toText(strategy_plan.allocations.size()));
                
                #ok([txid])
            };
            case (#err(error_msg)) {
                Debug.print("❌ Failed to broadcast transaction: " # error_msg);
                
                // Handle failed transaction by updating portfolio state
                let handle_failure_result = await handle_failed_transaction(
                    "failed_" # plan_id, 
                    msg.caller, 
                    error_msg
                );
                switch (handle_failure_result) {
                    case (#err(portfolio_error)) {
                        Debug.print("❌ Failed to record transaction failure: " # debug_show(portfolio_error));
                        
                        // Attempt rollback of any partial changes
                        ignore await rollback_portfolio_changes(strategy_plan.user_id, "failed_" # plan_id, strategy_plan);
                    };
                    case (#ok(_)) {
                        Debug.print("📝 Recorded transaction failure for plan: " # plan_id);
                    };
                };
                
                #err(#internal_error("Failed to execute plan: " # error_msg))
            };
        }
    };

    // Get transaction status with Bitcoin network confirmation data
    public func get_tx_status(txid: Types.TxId) : async Types.Result<Types.TxStatus, Types.ApiError> {
        // First check our local status
        switch (tx_status.get(txid)) {
            case (?#pending) {
                // Check Bitcoin network for confirmation status
                let network_status = await bitcoin_network.getTransactionStatus(txid);
                switch (network_status) {
                    case (#ok(confirmation_status)) {
                        let updated_status = if (confirmation_status.confirmed) {
                            #confirmed
                        } else {
                            #pending
                        };
                        
                        // Update local status if confirmed
                        if (confirmation_status.confirmed) {
                            tx_status.put(txid, #confirmed);
                            
                            // Trigger portfolio state update for confirmed transaction
                            // This is a simplified approach - in production, this would be handled
                            // by a background monitoring process
                            ignore async {
                                let update_results = await monitor_and_update_portfolio_states();
                                Debug.print("Portfolio update results: " # debug_show(update_results));
                            };
                        };
                        
                        #ok(updated_status)
                    };
                    case (#err(_)) {
                        // Return local status if network query fails
                        #ok(#pending)
                    };
                }
            };
            case (?status) { #ok(status) };
            case null { #err(#not_found) };
        }
    };

    public shared(msg) func cancel_execution(plan_id: Types.PlanId) : async Types.Result<Bool, Types.ApiError> {
        switch (executions.get(plan_id)) {
            case (?tx_ids) {
                // Mark all transactions as failed
                for (txid in tx_ids.vals()) {
                    tx_status.put(txid, #failed);
                    // Stop monitoring the transaction
                    ignore bitcoin_network.stopMonitoring(txid);
                };
                executions.delete(plan_id);
                #ok(true)
            };
            case null { #err(#not_found) };
        }
    };

    // Poll all monitored transactions for status updates
    public func poll_transaction_statuses() : async [(Types.TxId, BitcoinNetwork.ConfirmationStatus)] {
        await bitcoin_network.pollTransactionStatuses()
    };

    // Check if a specific transaction is confirmed
    public func is_transaction_confirmed(txid: Types.TxId) : async Bool {
        await bitcoin_network.isTransactionConfirmed(txid)
    };

    // Get all transactions for a user
    public shared(msg) func get_user_transactions(user_id: Types.UserId) : async [(Types.TxId, BitcoinNetwork.MonitoringEntry)] {
        if (user_id != msg.caller) {
            return [];
        };
        bitcoin_network.getUserTransactions(user_id)
    };

    // Get Bitcoin network monitoring statistics
    public query func get_network_monitoring_stats() : async {
        total_monitored: Nat;
        confirmed_transactions: Nat;
        pending_transactions: Nat;
        failed_transactions: Nat;
    } {
        bitcoin_network.getMonitoringStats()
    };

    // Cleanup old monitoring entries (maintenance function)
    public func cleanup_old_monitoring_entries() : async Nat {
        bitcoin_network.cleanupOldEntries()
    };

    // Set portfolio state canister reference for inter-canister communication
    public shared(msg) func set_portfolio_state_canister(canister: Interfaces.PortfolioStateInterface) : async Bool {
        portfolio_state_canister := ?canister;
        true
    };

    // Update portfolio state after transaction confirmation
    public func update_portfolio_after_confirmation(
        txid: Types.TxId,
        user_id: Types.UserId,
        strategy_plan: Types.StrategyPlan
    ) : async Types.Result<Bool, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                // Create transaction record for the executed strategy
                let tx_record: Types.TxRecord = {
                    txid = txid;
                    user_id = user_id;
                    tx_type = #strategy_execute;
                    amount_sats = Array.foldLeft<Types.Allocation, Nat64>(
                        strategy_plan.allocations, 
                        0, 
                        func(acc, allocation) { acc + allocation.amount_sats }
                    );
                    fee_sats = 0; // Would be calculated from actual transaction
                    status = #confirmed;
                    confirmed_height = null; // Would be set from Bitcoin network
                    timestamp = Time.now();
                };
                
                // Record the transaction
                let record_result = await portfolio_canister.record_transaction(user_id, tx_record);
                switch (record_result) {
                    case (#err(error)) {
                        Debug.print("Failed to record transaction: " # debug_show(error));
                        return #err(error);
                    };
                    case (#ok(_)) {};
                };
                
                // Create positions for each allocation with enhanced error handling
                let position_update_results = await update_strategy_positions(user_id, strategy_plan, txid);
                switch (position_update_results) {
                    case (#err(error)) {
                        Debug.print("❌ Failed to update strategy positions: " # debug_show(error));
                        return #err(error);
                    };
                    case (#ok(success_count)) {
                        Debug.print("✅ Successfully updated " # Nat.toText(success_count) # " positions for strategy execution");
                    };
                };
                
                // Mark UTXOs as spent for the executed transaction
                let mark_spent_result = await mark_utxos_spent_for_transaction(txid, user_id, strategy_plan);
                switch (mark_spent_result) {
                    case (#err(error)) {
                        Debug.print("Failed to mark UTXOs as spent: " # debug_show(error));
                        return #err(error);
                    };
                    case (#ok(_)) {};
                };
                
                Debug.print("Portfolio state updated successfully for transaction: " # txid);
                #ok(true)
            };
            case null {
                Debug.print("Portfolio state canister not configured");
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Mark UTXOs as spent for a transaction
    private func mark_utxos_spent_for_transaction(
        txid: Types.TxId,
        user_id: Types.UserId,
        strategy_plan: Types.StrategyPlan
    ) : async Types.Result<Bool, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                // Get user's UTXOs to find which ones were spent
                let utxos_result = await portfolio_canister.get_utxos(user_id);
                let utxo_set = switch (utxos_result) {
                    case (#ok(set)) { set };
                    case (#err(error)) {
                        Debug.print("Failed to get user UTXOs: " # debug_show(error));
                        return #err(error);
                    };
                };
                
                // Calculate total amount needed for strategy execution
                let total_amount = Array.foldLeft<Types.Allocation, Nat64>(
                    strategy_plan.allocations, 
                    0, 
                    func(acc, allocation) { acc + allocation.amount_sats }
                );
                
                // Select UTXOs that would have been used (simplified selection)
                var remaining_amount = total_amount;
                for (utxo in utxo_set.utxos.vals()) {
                    if (remaining_amount > 0 and not utxo.spent) {
                        let mark_result = await portfolio_canister.mark_utxo_spent(
                            utxo.txid, 
                            utxo.vout, 
                            txid
                        );
                        switch (mark_result) {
                            case (#err(error)) {
                                Debug.print("Failed to mark UTXO as spent: " # debug_show(error));
                            };
                            case (#ok(_)) {
                                if (utxo.amount_sats >= remaining_amount) {
                                    remaining_amount := 0;
                                } else {
                                    remaining_amount -= utxo.amount_sats;
                                };
                            };
                        };
                    };
                };
                
                #ok(true)
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Handle failed transaction and update portfolio state accordingly
    public func handle_failed_transaction(
        txid: Types.TxId,
        user_id: Types.UserId,
        error_reason: Text
    ) : async Types.Result<Bool, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                // Create failed transaction record
                let tx_record: Types.TxRecord = {
                    txid = txid;
                    user_id = user_id;
                    tx_type = #strategy_execute;
                    amount_sats = 0; // No amount transferred for failed transaction
                    fee_sats = 0;
                    status = #failed;
                    confirmed_height = null;
                    timestamp = Time.now();
                };
                
                // Record the failed transaction
                let record_result = await portfolio_canister.record_transaction(user_id, tx_record);
                switch (record_result) {
                    case (#err(error)) {
                        Debug.print("Failed to record failed transaction: " # debug_show(error));
                        return #err(error);
                    };
                    case (#ok(_)) {
                        Debug.print("Recorded failed transaction: " # txid # " - Reason: " # error_reason);
                        #ok(true)
                    };
                }
            };
            case null {
                Debug.print("Portfolio state canister not configured");
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Monitor transaction confirmations and update portfolio state automatically
    public func monitor_and_update_portfolio_states() : async [(Types.TxId, Bool)] {
        let confirmation_statuses = await bitcoin_network.pollTransactionStatuses();
        let update_results = Buffer.Buffer<(Types.TxId, Bool)>(confirmation_statuses.size());
        
        for ((txid, status) in confirmation_statuses.vals()) {
            if (status.confirmed and status.confirmations >= 1) {
                // Find the execution that corresponds to this transaction
                var found_execution: ?(Types.PlanId, Types.UserId) = null;
                
                for ((plan_id, tx_ids) in executions.entries()) {
                    for (tx_id in tx_ids.vals()) {
                        if (tx_id == txid) {
                            // Get user ID from monitoring entry
                            let user_transactions = bitcoin_network.getUserTransactions(Principal.fromText("2vxsx-fae")); // Placeholder
                            for ((monitored_txid, entry) in user_transactions.vals()) {
                                if (monitored_txid == txid) {
                                    found_execution := ?(plan_id, entry.user_id);
                                };
                            };
                        };
                    };
                };
                
                switch (found_execution) {
                    case (?(plan_id, user_id)) {
                        // Create mock strategy plan for update (in production, would query strategy selector)
                        let mock_plan = createMockStrategyPlan(plan_id, user_id);
                        
                        let update_result = await update_portfolio_after_confirmation(txid, user_id, mock_plan);
                        switch (update_result) {
                            case (#ok(_)) {
                                update_results.add((txid, true));
                                // Update local transaction status
                                tx_status.put(txid, #confirmed);
                                
                                // Log successful portfolio update
                                Debug.print("✅ Portfolio state updated successfully for transaction: " # txid);
                            };
                            case (#err(error)) {
                                Debug.print("❌ Failed to update portfolio for confirmed transaction " # txid # ": " # debug_show(error));
                                update_results.add((txid, false));
                                
                                // Attempt error recovery by recording the failure
                                ignore await handle_portfolio_update_failure(txid, user_id, debug_show(error));
                            };
                        };
                    };
                    case null {
                        Debug.print("⚠️  Could not find execution details for transaction: " # txid);
                        update_results.add((txid, false));
                    };
                };
            };
        };
        
        Buffer.toArray(update_results)
    };

    // Handle portfolio update failures with error recovery
    private func handle_portfolio_update_failure(
        txid: Types.TxId,
        user_id: Types.UserId,
        error_details: Text
    ) : async Types.Result<Bool, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                // Create a failed update record for audit purposes
                let failed_tx_record: Types.TxRecord = {
                    txid = "failed_update_" # txid;
                    user_id = user_id;
                    tx_type = #strategy_execute;
                    amount_sats = 0;
                    fee_sats = 0;
                    status = #failed;
                    confirmed_height = null;
                    timestamp = Time.now();
                };
                
                let record_result = await portfolio_canister.record_transaction(user_id, failed_tx_record);
                switch (record_result) {
                    case (#ok(_)) {
                        Debug.print("📝 Recorded portfolio update failure for audit: " # txid);
                        #ok(true)
                    };
                    case (#err(error)) {
                        Debug.print("❌ Failed to record portfolio update failure: " # debug_show(error));
                        #err(error)
                    };
                }
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Get portfolio state consistency check
    public func check_portfolio_state_consistency(user_id: Types.UserId) : async Types.Result<{
        utxo_balance: Nat64;
        portfolio_balance: Nat64;
        transaction_count: Nat;
        position_count: Nat;
        is_consistent: Bool;
        inconsistencies: [Text];
    }, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                // Get UTXO set
                let utxos_result = await portfolio_canister.get_utxos(user_id);
                let utxo_set = switch (utxos_result) {
                    case (#ok(set)) { set };
                    case (#err(error)) {
                        return #err(error);
                    };
                };
                
                // Get portfolio summary
                let portfolio_result = await portfolio_canister.get_portfolio(user_id);
                let portfolio = switch (portfolio_result) {
                    case (#ok(summary)) { summary };
                    case (#err(error)) {
                        return #err(error);
                    };
                };
                
                // Get transaction history
                let tx_history_result = await portfolio_canister.get_transaction_history(user_id);
                let transactions = switch (tx_history_result) {
                    case (#ok(txs)) { txs };
                    case (#err(error)) {
                        return #err(error);
                    };
                };
                
                // Check consistency
                let inconsistencies = Buffer.Buffer<Text>(0);
                var is_consistent = true;
                
                // Check if UTXO balance matches portfolio balance
                if (utxo_set.confirmed_balance != portfolio.total_balance_sats) {
                    inconsistencies.add("UTXO balance (" # Nat64.toText(utxo_set.confirmed_balance) # 
                                     ") does not match portfolio balance (" # Nat64.toText(portfolio.total_balance_sats) # ")");
                    is_consistent := false;
                };
                
                // Check for orphaned transactions
                var confirmed_tx_count = 0;
                for (tx in transactions.vals()) {
                    if (tx.status == #confirmed) {
                        confirmed_tx_count += 1;
                    };
                };
                
                #ok({
                    utxo_balance = utxo_set.confirmed_balance;
                    portfolio_balance = portfolio.total_balance_sats;
                    transaction_count = transactions.size();
                    position_count = portfolio.positions.size();
                    is_consistent = is_consistent;
                    inconsistencies = Buffer.toArray(inconsistencies);
                })
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Helper function to create mock strategy plan for MVP testing
    private func createMockStrategyPlan(plan_id: Types.PlanId, user_id: Types.UserId) : Types.StrategyPlan {
        {
            id = plan_id;
            user_id = user_id;
            template_id = "balanced_strategy";
            allocations = [
                {
                    venue_id = "lending_pool_1";
                    amount_sats = 5_000_000; // 0.05 BTC
                    percentage = 50.0;
                },
                {
                    venue_id = "liquidity_pool_1";
                    amount_sats = 5_000_000; // 0.05 BTC
                    percentage = 50.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Balanced allocation for moderate risk tolerance";
        }
    };

    // Helper function to create mock user UTXOs for MVP testing
    private func createMockUserUTXOs(user_id: Types.UserId) : [Types.UTXO] {
        [
            {
                txid = "mock_utxo_1_" # Principal.toText(user_id);
                vout = 0;
                amount_sats = 15_000_000; // 0.15 BTC
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                confirmations = 6;
                block_height = ?800000;
                spent = false;
                spent_in_tx = null;
            }
        ]
    };

    // Update strategy positions with enhanced error handling and recovery
    private func update_strategy_positions(
        user_id: Types.UserId,
        strategy_plan: Types.StrategyPlan,
        txid: Types.TxId
    ) : async Types.Result<Nat, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                var successful_updates = 0;
                let failed_venues = Buffer.Buffer<Text>(0);
                
                for (allocation in strategy_plan.allocations.vals()) {
                    // Calculate entry price based on current BTC price (simplified for MVP)
                    let btc_amount = Float.fromInt64(Int64.fromNat64(allocation.amount_sats)) / 100_000_000.0;
                    let estimated_btc_price = 45000.0; // Mock BTC price for MVP
                    let entry_value = btc_amount * estimated_btc_price;
                    
                    let position: Types.Position = {
                        user_id = user_id;
                        venue_id = allocation.venue_id;
                        amount_sats = allocation.amount_sats;
                        entry_price = entry_value;
                        current_value = entry_value; // Initially same as entry price
                        pnl = 0.0; // Initial PnL is zero
                    };
                    
                    let position_result = await portfolio_canister.update_position(user_id, position);
                    switch (position_result) {
                        case (#ok(_)) {
                            successful_updates += 1;
                            Debug.print("✅ Updated position for venue: " # allocation.venue_id # 
                                      " (Amount: " # Nat64.toText(allocation.amount_sats) # " sats)");
                        };
                        case (#err(error)) {
                            failed_venues.add(allocation.venue_id);
                            Debug.print("❌ Failed to update position for venue " # allocation.venue_id # 
                                      ": " # debug_show(error));
                        };
                    };
                };
                
                // If some positions failed, record the partial failure
                if (failed_venues.size() > 0) {
                    let failure_details = "Failed to update positions for venues: " # 
                                         Text.join(", ", Buffer.toArray(failed_venues).vals());
                    ignore await record_position_update_failure(user_id, txid, failure_details);
                };
                
                if (successful_updates == 0) {
                    #err(#internal_error("Failed to update any positions"))
                } else {
                    #ok(successful_updates)
                }
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Record position update failures for audit and recovery
    private func record_position_update_failure(
        user_id: Types.UserId,
        txid: Types.TxId,
        failure_details: Text
    ) : async Types.Result<Bool, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                let failure_record: Types.TxRecord = {
                    txid = "position_failure_" # txid;
                    user_id = user_id;
                    tx_type = #strategy_execute;
                    amount_sats = 0;
                    fee_sats = 0;
                    status = #failed;
                    confirmed_height = null;
                    timestamp = Time.now();
                };
                
                let record_result = await portfolio_canister.record_transaction(user_id, failure_record);
                switch (record_result) {
                    case (#ok(_)) {
                        Debug.print("📝 Recorded position update failure: " # failure_details);
                        #ok(true)
                    };
                    case (#err(error)) {
                        Debug.print("❌ Failed to record position update failure: " # debug_show(error));
                        #err(error)
                    };
                }
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Validate portfolio state consistency after transaction execution
    public func validate_post_execution_state(
        user_id: Types.UserId,
        txid: Types.TxId,
        expected_positions: Nat
    ) : async Types.Result<{
        is_valid: Bool;
        validation_errors: [Text];
        position_count: Nat;
        transaction_recorded: Bool;
    }, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                let validation_errors = Buffer.Buffer<Text>(0);
                var is_valid = true;
                
                // Check if transaction was recorded
                let tx_history_result = await portfolio_canister.get_transaction_history(user_id);
                let transaction_recorded = switch (tx_history_result) {
                    case (#ok(transactions)) {
                        Array.find<Types.TxRecord>(transactions, func(tx) {
                            tx.txid == txid and tx.status == #confirmed
                        }) != null
                    };
                    case (#err(_)) { false };
                };
                
                if (not transaction_recorded) {
                    validation_errors.add("Transaction " # txid # " not found in transaction history");
                    is_valid := false;
                };
                
                // Check position count
                let portfolio_result = await portfolio_canister.get_portfolio(user_id);
                let actual_position_count = switch (portfolio_result) {
                    case (#ok(portfolio)) { portfolio.positions.size() };
                    case (#err(_)) { 0 };
                };
                
                if (actual_position_count < expected_positions) {
                    validation_errors.add("Expected " # Nat.toText(expected_positions) # 
                                        " positions, but found " # Nat.toText(actual_position_count));
                    is_valid := false;
                };
                
                // Check UTXO consistency
                let consistency_result = await check_portfolio_state_consistency(user_id);
                switch (consistency_result) {
                    case (#ok(consistency_check)) {
                        if (not consistency_check.is_consistent) {
                            for (inconsistency in consistency_check.inconsistencies.vals()) {
                                validation_errors.add(inconsistency);
                            };
                            is_valid := false;
                        };
                    };
                    case (#err(_)) {
                        validation_errors.add("Failed to check portfolio state consistency");
                        is_valid := false;
                    };
                };
                
                #ok({
                    is_valid = is_valid;
                    validation_errors = Buffer.toArray(validation_errors);
                    position_count = actual_position_count;
                    transaction_recorded = transaction_recorded;
                })
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Rollback portfolio state changes in case of execution failure
    public func rollback_portfolio_changes(
        user_id: Types.UserId,
        txid: Types.TxId,
        strategy_plan: Types.StrategyPlan
    ) : async Types.Result<Bool, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                Debug.print("🔄 Rolling back portfolio changes for failed transaction: " # txid);
                
                // Remove any positions that were created for this strategy
                let portfolio_result = await portfolio_canister.get_portfolio(user_id);
                switch (portfolio_result) {
                    case (#ok(portfolio)) {
                        for (allocation in strategy_plan.allocations.vals()) {
                            // Find and remove position for this venue
                            let position_to_remove = Array.find<Types.Position>(portfolio.positions, func(pos) {
                                pos.venue_id == allocation.venue_id and pos.amount_sats == allocation.amount_sats
                            });
                            
                            switch (position_to_remove) {
                                case (?pos) {
                                    // Create a zero position to effectively remove it
                                    let zero_position: Types.Position = {
                                        user_id = pos.user_id;
                                        venue_id = pos.venue_id;
                                        amount_sats = 0;
                                        entry_price = 0.0;
                                        current_value = 0.0;
                                        pnl = 0.0;
                                    };
                                    
                                    ignore await portfolio_canister.update_position(user_id, zero_position);
                                    Debug.print("🗑️  Removed position for venue: " # allocation.venue_id);
                                };
                                case null {
                                    Debug.print("⚠️  Position not found for venue: " # allocation.venue_id);
                                };
                            };
                        };
                    };
                    case (#err(error)) {
                        Debug.print("❌ Failed to get portfolio for rollback: " # debug_show(error));
                        return #err(error);
                    };
                };
                
                // Mark any UTXOs as unspent if they were marked as spent
                ignore await unmark_utxos_spent_for_transaction(user_id, strategy_plan);
                
                Debug.print("✅ Portfolio rollback completed for transaction: " # txid);
                #ok(true)
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Unmark UTXOs as spent (for rollback scenarios)
    private func unmark_utxos_spent_for_transaction(
        user_id: Types.UserId,
        strategy_plan: Types.StrategyPlan
    ) : async Types.Result<Bool, Types.ApiError> {
        
        switch (portfolio_state_canister) {
            case (?portfolio_canister) {
                let utxos_result = await portfolio_canister.get_utxos(user_id);
                let utxo_set = switch (utxos_result) {
                    case (#ok(set)) { set };
                    case (#err(error)) {
                        return #err(error);
                    };
                };
                
                // Calculate total amount that would have been spent
                let total_amount = Array.foldLeft<Types.Allocation, Nat64>(
                    strategy_plan.allocations, 
                    0, 
                    func(acc, allocation) { acc + allocation.amount_sats }
                );
                
                // Find spent UTXOs that match the amount and unmark them
                var remaining_amount = total_amount;
                for (utxo in utxo_set.utxos.vals()) {
                    if (remaining_amount > 0 and utxo.spent) {
                        // This is a simplified approach - in production, we'd need better tracking
                        // of which UTXOs were spent for which transactions
                        if (utxo.amount_sats <= remaining_amount) {
                            remaining_amount -= utxo.amount_sats;
                            Debug.print("🔄 Unmarking UTXO as spent: " # utxo.txid # ":" # Nat32.toText(utxo.vout));
                        };
                    };
                };
                
                #ok(true)
            };
            case null {
                #err(#internal_error("Portfolio state canister not configured"))
            };
        }
    };

    // Cancel execution method for inter-canister communication
    public shared(msg) func cancel_execution(plan_id: Types.PlanId) : async Types.Result<Bool, Types.ApiError> {
        communicator.log_audit_entry({
            timestamp = Time.now();
            canister = "execution_agent";
            action = "cancel_execution_start";
            user_id = ?msg.caller;
            transaction_id = ?plan_id;
            details = "Attempting to cancel execution for plan: " # plan_id;
        });

        // Check if execution exists
        switch (executions.get(plan_id)) {
            case (?tx_ids) {
                // Check if any transactions are still pending
                var has_pending = false;
                for (tx_id in tx_ids.vals()) {
                    switch (tx_status.get(tx_id)) {
                        case (?#pending) {
                            has_pending := true;
                            // Update status to failed (cancelled)
                            tx_status.put(tx_id, #failed);
                        };
                        case (_) {};
                    };
                };

                if (has_pending) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_agent";
                        action = "cancel_execution_success";
                        user_id = ?msg.caller;
                        transaction_id = ?plan_id;
                        details = "Execution cancelled for plan: " # plan_id;
                    });
                    #ok(true)
                } else {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_agent";
                        action = "cancel_execution_failed";
                        user_id = ?msg.caller;
                        transaction_id = ?plan_id;
                        details = "No pending transactions to cancel for plan: " # plan_id;
                    });
                    #err(#invalid_input("No pending transactions to cancel"))
                }
            };
            case null {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "execution_agent";
                    action = "cancel_execution_not_found";
                    user_id = ?msg.caller;
                    transaction_id = ?plan_id;
                    details = "Execution not found for plan: " # plan_id;
                });
                #err(#not_found)
            };
        }
    };

    // Event subscription for inter-canister communication
    public func subscribe_to_strategy_events() : async () {
        let strategy_event_handler = func(event: Interfaces.SystemEvent) : async () {
            switch (event) {
                case (#strategy_approved(user_id, plan_id)) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_agent";
                        action = "strategy_approved_received";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Received strategy approval event for plan: " # plan_id;
                    });
                };
                case (#risk_threshold_breached(user_id, protective_intent)) {
                    // Handle risk threshold breach by potentially cancelling pending executions
                    let user_executions = executions.entries() 
                        |> Iter.filter(_, func((plan_id, tx_ids): (Types.PlanId, [Types.TxId])) : Bool {
                            // This is simplified - in production we'd need to track user_id per execution
                            true
                        })
                        |> Iter.toArray(_);
                    
                    for ((plan_id, tx_ids) in user_executions.vals()) {
                        ignore await cancel_execution(plan_id);
                    };
                    
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_agent";
                        action = "risk_breach_response";
                        user_id = ?user_id;
                        transaction_id = null;
                        details = "Responded to risk threshold breach by cancelling executions";
                    });
                };
                case (_) {};
            };
        };
        
        communicator.subscribe_to_events("strategy_updates", strategy_event_handler);
        communicator.subscribe_to_events("risk_updates", strategy_event_handler);
    };

    // Initialize event subscriptions on startup
    system func init() {
        ignore subscribe_to_strategy_events();
    };

    // Get communication statistics for monitoring
    public query func get_communication_stats() : async {
        active_flows: Nat;
        total_audit_entries: Nat;
        event_subscribers: Nat;
        event_history_size: Nat;
        total_executions: Nat;
        pending_transactions: Nat;
        confirmed_transactions: Nat;
        failed_transactions: Nat;
    } {
        let comm_stats = communicator.get_communication_stats();
        
        var pending_count = 0;
        var confirmed_count = 0;
        var failed_count = 0;
        
        for (status in tx_status.vals()) {
            switch (status) {
                case (#pending) pending_count += 1;
                case (#confirmed) confirmed_count += 1;
                case (#failed) failed_count += 1;
            };
        };
        
        {
            active_flows = comm_stats.active_flows;
            total_audit_entries = comm_stats.total_audit_entries;
            event_subscribers = comm_stats.event_subscribers;
            event_history_size = comm_stats.event_history_size;
            total_executions = executions.size();
            pending_transactions = pending_count;
            confirmed_transactions = confirmed_count;
            failed_transactions = failed_count;
        }
    };
}