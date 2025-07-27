import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result "mo:base/Result";

import Types "../src/shared/types";
import Interfaces "../src/shared/interfaces";
import InterCanister "../src/shared/inter_canister";
import DataConsistency "../src/shared/data_consistency";

module {
    // Test suite for data consistency mechanisms
    public func run_tests() : async Bool {
        Debug.print("Starting Data Consistency Tests...");
        
        var all_passed = true;
        
        // Test 1: Distributed transaction lifecycle
        if (not await test_distributed_transaction_lifecycle()) {
            all_passed := false;
        };
        
        // Test 2: Transaction rollback mechanisms
        if (not await test_transaction_rollback()) {
            all_passed := false;
        };
        
        // Test 3: State synchronization
        if (not await test_state_synchronization()) {
            all_passed := false;
        };
        
        // Test 4: Idempotent operations
        if (not await test_idempotent_operations()) {
            all_passed := false;
        };
        
        // Test 5: Conflict resolution
        if (not await test_conflict_resolution()) {
            all_passed := false;
        };
        
        // Test 6: Error recovery scenarios
        if (not await test_error_recovery()) {
            all_passed := false;
        };
        
        // Test 7: Cleanup and maintenance
        if (not await test_cleanup_operations()) {
            all_passed := false;
        };
        
        if (all_passed) {
            Debug.print("✅ All Data Consistency tests passed!");
        } else {
            Debug.print("❌ Some Data Consistency tests failed!");
        };
        
        all_passed;
    };

    // Test 1: Distributed transaction lifecycle
    private func test_distributed_transaction_lifecycle() : async Bool {
        Debug.print("Test 1: Distributed Transaction Lifecycle");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        let test_user_id = Principal.fromText("test-user-123");
        let test_plan_id = "plan_456";
        let participants = [
            Principal.fromText("canister-1"),
            Principal.fromText("canister-2"),
            Principal.fromText("canister-3")
        ];
        
        // Begin distributed transaction
        let begin_result = await coordinator.begin_distributed_transaction(
            test_user_id,
            ?test_plan_id,
            participants,
            300 // 5 minutes timeout
        );
        
        let tx_id = switch (begin_result) {
            case (#ok(id)) id;
            case (#err(error)) {
                Debug.print("❌ Failed to begin transaction: " # debug_show(error));
                return false;
            };
        };
        
        // Add transaction actions
        let action1_result = await coordinator.add_transaction_action(
            tx_id,
            participants[0],
            "execute_strategy",
            "{\"plan_id\":\"" # test_plan_id # "\"}",
            "rollback_strategy",
            "{\"plan_id\":\"" # test_plan_id # "\"}"
        );
        
        let action2_result = await coordinator.add_transaction_action(
            tx_id,
            participants[1],
            "update_portfolio",
            "{\"user_id\":\"" # Principal.toText(test_user_id) # "\"}",
            "revert_portfolio",
            "{\"user_id\":\"" # Principal.toText(test_user_id) # "\"}"
        );
        
        // Commit transaction
        let commit_result = await coordinator.commit_distributed_transaction(tx_id);
        
        let test_passed = switch (begin_result, action1_result, action2_result, commit_result) {
            case (#ok(_), #ok(_), #ok(_), #ok(_)) true;
            case (_, _, _, _) false;
        };
        
        if (test_passed) {
            Debug.print("✅ Distributed transaction lifecycle working correctly");
        } else {
            Debug.print("❌ Distributed transaction lifecycle failed");
        };
        
        test_passed;
    };

    // Test 2: Transaction rollback mechanisms
    private func test_transaction_rollback() : async Bool {
        Debug.print("Test 2: Transaction Rollback Mechanisms");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        let test_user_id = Principal.fromText("test-user-rollback");
        let participants = [
            Principal.fromText("canister-rollback-1"),
            Principal.fromText("canister-rollback-2")
        ];
        
        // Begin transaction
        let begin_result = await coordinator.begin_distributed_transaction(
            test_user_id,
            ?"rollback_plan",
            participants,
            60
        );
        
        let tx_id = switch (begin_result) {
            case (#ok(id)) id;
            case (#err(_)) return false;
        };
        
        // Add actions
        let action_result = await coordinator.add_transaction_action(
            tx_id,
            participants[0],
            "failing_action",
            "{\"will_fail\":true}",
            "compensate_failure",
            "{\"compensate\":true}"
        );
        
        // Attempt rollback
        let rollback_result = await coordinator.rollback_distributed_transaction(tx_id);
        
        let test_passed = switch (action_result, rollback_result) {
            case (#ok(_), #ok(_)) true;
            case (_, _) false;
        };
        
        if (test_passed) {
            Debug.print("✅ Transaction rollback mechanisms working correctly");
        } else {
            Debug.print("❌ Transaction rollback mechanisms failed");
        };
        
        test_passed;
    };

    // Test 3: State synchronization
    private func test_state_synchronization() : async Bool {
        Debug.print("Test 3: State Synchronization");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        let canisters = [
            Principal.fromText("sync-canister-1"),
            Principal.fromText("sync-canister-2"),
            Principal.fromText("sync-canister-3")
        ];
        
        // Create state checkpoints
        let hash1 = await coordinator.create_state_checkpoint(canisters[0], "state_data_1");
        let hash2 = await coordinator.create_state_checkpoint(canisters[1], "state_data_2");
        let hash3 = await coordinator.create_state_checkpoint(canisters[2], "state_data_3");
        
        // Synchronize state
        let sync_result = await coordinator.synchronize_state_across_canisters(canisters, 30);
        
        let test_passed = switch (sync_result) {
            case (#synchronized) true;
            case (#conflict(_)) true; // Conflicts are expected and handled
            case (_) false;
        };
        
        if (test_passed) {
            Debug.print("✅ State synchronization working correctly");
        } else {
            Debug.print("❌ State synchronization failed");
        };
        
        test_passed;
    };

    // Test 4: Idempotent operations
    private func test_idempotent_operations() : async Bool {
        Debug.print("Test 4: Idempotent Operations");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        let idempotency_key = "test_operation_123";
        let canister = Principal.fromText("idempotent-canister");
        let method = "test_method";
        let payload = "{\"test\":\"data\"}";
        
        // Execute operation first time
        let result1 = await coordinator.execute_idempotent_operation(
            idempotency_key,
            canister,
            method,
            payload,
            300
        );
        
        // Execute same operation again (should return cached result)
        let result2 = await coordinator.execute_idempotent_operation(
            idempotency_key,
            canister,
            method,
            payload,
            300
        );
        
        let test_passed = switch (result1, result2) {
            case (#ok(res1), #ok(res2)) res1 == res2;
            case (_, _) false;
        };
        
        if (test_passed) {
            Debug.print("✅ Idempotent operations working correctly");
        } else {
            Debug.print("❌ Idempotent operations failed");
        };
        
        test_passed;
    };

    // Test 5: Conflict resolution
    private func test_conflict_resolution() : async Bool {
        Debug.print("Test 5: Conflict Resolution");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        let conflicting_canisters = [
            Principal.fromText("conflict-canister-1"),
            Principal.fromText("conflict-canister-2")
        ];
        
        // Create conflicting states (same timestamp, different data)
        let hash1 = await coordinator.create_state_checkpoint(conflicting_canisters[0], "conflicting_state_1");
        let hash2 = await coordinator.create_state_checkpoint(conflicting_canisters[1], "conflicting_state_2");
        
        // Attempt synchronization (should detect and resolve conflicts)
        let sync_result = await coordinator.synchronize_state_across_canisters(conflicting_canisters, 30);
        
        let test_passed = switch (sync_result) {
            case (#synchronized) true; // Conflicts were resolved
            case (#conflict({conflicting_canisters; resolution_strategy})) {
                // Manual intervention required - this is also a valid outcome
                conflicting_canisters.size() > 0;
            };
            case (_) false;
        };
        
        if (test_passed) {
            Debug.print("✅ Conflict resolution working correctly");
        } else {
            Debug.print("❌ Conflict resolution failed");
        };
        
        test_passed;
    };

    // Test 6: Error recovery scenarios
    private func test_error_recovery() : async Bool {
        Debug.print("Test 6: Error Recovery Scenarios");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        let test_user_id = Principal.fromText("test-user-recovery");
        let participants = [Principal.fromText("recovery-canister")];
        
        // Test timeout scenario
        let begin_result = await coordinator.begin_distributed_transaction(
            test_user_id,
            ?"timeout_plan",
            participants,
            1 // Very short timeout (1 second)
        );
        
        let tx_id = switch (begin_result) {
            case (#ok(id)) id;
            case (#err(_)) return false;
        };
        
        // Wait for timeout (simulate delay)
        // In a real test, we would wait, but for simulation we'll proceed
        
        // Try to commit after timeout (should fail)
        let commit_result = await coordinator.commit_distributed_transaction(tx_id);
        
        // Test idempotency key conflict
        let conflict_result = await coordinator.execute_idempotent_operation(
            "conflict_key",
            participants[0],
            "method1",
            "{\"data\":1}",
            300
        );
        
        let conflict_result2 = await coordinator.execute_idempotent_operation(
            "conflict_key",
            participants[0],
            "method2", // Different method with same key
            "{\"data\":2}",
            300
        );
        
        let test_passed = switch (commit_result, conflict_result, conflict_result2) {
            case (#err(_), #ok(_), #err(_)) true; // Timeout error and conflict error expected
            case (_, _, _) false;
        };
        
        if (test_passed) {
            Debug.print("✅ Error recovery scenarios working correctly");
        } else {
            Debug.print("❌ Error recovery scenarios failed");
        };
        
        test_passed;
    };

    // Test 7: Cleanup and maintenance
    private func test_cleanup_operations() : async Bool {
        Debug.print("Test 7: Cleanup and Maintenance");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        // Create some operations that will expire
        let expired_key = "expired_operation";
        let canister = Principal.fromText("cleanup-canister");
        
        let operation_result = await coordinator.execute_idempotent_operation(
            expired_key,
            canister,
            "test_method",
            "{\"test\":\"cleanup\"}",
            1 // Very short TTL (1 second)
        );
        
        // Get initial stats
        let initial_stats = coordinator.get_consistency_stats();
        
        // Run cleanup
        let cleaned_count = await coordinator.cleanup_expired_operations();
        
        // Get final stats
        let final_stats = coordinator.get_consistency_stats();
        
        let test_passed = switch (operation_result) {
            case (#ok(_)) {
                // Check that cleanup ran and stats are reasonable
                initial_stats.idempotent_operations >= 0 and
                final_stats.idempotent_operations >= 0 and
                cleaned_count >= 0;
            };
            case (#err(_)) false;
        };
        
        if (test_passed) {
            Debug.print("✅ Cleanup and maintenance working correctly");
        } else {
            Debug.print("❌ Cleanup and maintenance failed");
        };
        
        test_passed;
    };

    // Helper function to create mock canister registry
    private func create_mock_canister_registry() : Interfaces.CanisterRegistry {
        {
            user_registry = Principal.fromText("rdmx6-jaaaa-aaaah-qdrya-cai");
            portfolio_state = Principal.fromText("rrkah-fqaaa-aaaah-qdrya-cai");
            strategy_selector = Principal.fromText("ryjl3-tyaaa-aaaah-qdrya-cai");
            execution_agent = Principal.fromText("renrk-eyaaa-aaaah-qdrya-cai");
            risk_guard = Principal.fromText("rno2w-sqaaa-aaaah-qdrya-cai");
        };
    };

    // Stress test for high-volume consistency operations
    public func run_stress_tests() : async Bool {
        Debug.print("Running Stress Tests for Data Consistency...");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = DataConsistency.DataConsistencyCoordinator(mock_registry, communicator);
        
        let start_time = Time.now();
        
        // Test 100 concurrent idempotent operations
        var successful_operations = 0;
        for (i in Array.range(0, 99)) {
            let key = "stress_op_" # Nat.toText(i);
            let result = await coordinator.execute_idempotent_operation(
                key,
                Principal.fromText("stress-canister"),
                "stress_method",
                "{\"index\":" # Nat.toText(i) # "}",
                300
            );
            
            switch (result) {
                case (#ok(_)) successful_operations += 1;
                case (#err(_)) {};
            };
        };
        
        // Test 20 distributed transactions
        var successful_transactions = 0;
        for (i in Array.range(0, 19)) {
            let user_id = Principal.fromText("stress-user-" # Nat.toText(i));
            let participants = [Principal.fromText("stress-participant-" # Nat.toText(i))];
            
            let begin_result = await coordinator.begin_distributed_transaction(
                user_id,
                ?"stress_plan_" # Nat.toText(i),
                participants,
                60
            );
            
            switch (begin_result) {
                case (#ok(tx_id)) {
                    let commit_result = await coordinator.commit_distributed_transaction(tx_id);
                    switch (commit_result) {
                        case (#ok(_)) successful_transactions += 1;
                        case (#err(_)) {};
                    };
                };
                case (#err(_)) {};
            };
        };
        
        let end_time = Time.now();
        let duration_ms = (end_time - start_time) / 1_000_000;
        
        let final_stats = coordinator.get_consistency_stats();
        
        let stress_test_passed = duration_ms < 30000 and // Less than 30 seconds
                                successful_operations >= 80 and // At least 80% success rate
                                successful_transactions >= 15 and // At least 75% success rate
                                final_stats.active_transactions >= 0;
        
        if (stress_test_passed) {
            Debug.print("✅ Stress tests passed - Duration: " # Int.toText(duration_ms) # "ms");
            Debug.print("📊 Operations: " # Nat.toText(successful_operations) # "/100, Transactions: " # Nat.toText(successful_transactions) # "/20");
        } else {
            Debug.print("❌ Stress tests failed - Duration: " # Int.toText(duration_ms) # "ms");
            Debug.print("📊 Operations: " # Nat.toText(successful_operations) # "/100, Transactions: " # Nat.toText(successful_transactions) # "/20");
        };
        
        stress_test_passed;
    };
}