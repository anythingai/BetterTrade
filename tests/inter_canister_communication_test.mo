import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result "mo:base/Result";

import Types "../src/shared/types";
import Interfaces "../src/shared/interfaces";
import InterCanister "../src/shared/inter_canister";
import ExecutionCoordinator "../src/shared/execution_coordinator";

module {
    // Test suite for inter-canister communication
    public func run_tests() : async Bool {
        Debug.print("Starting Inter-Canister Communication Tests...");
        
        var all_passed = true;
        
        // Test 1: Agent Communicator initialization
        if (not await test_agent_communicator_init()) {
            all_passed := false;
        };
        
        // Test 2: Event bus functionality
        if (not await test_event_bus()) {
            all_passed := false;
        };
        
        // Test 3: Audit trail logging
        if (not await test_audit_trail()) {
            all_passed := false;
        };
        
        // Test 4: Execution flow coordination
        if (not await test_execution_flow()) {
            all_passed := false;
        };
        
        // Test 5: Inter-canister call protocols
        if (not await test_inter_canister_calls()) {
            all_passed := false;
        };
        
        // Test 6: Error handling and recovery
        if (not await test_error_handling()) {
            all_passed := false;
        };
        
        // Test 7: Strategy execution coordination
        if (not await test_strategy_execution_coordination()) {
            all_passed := false;
        };
        
        if (all_passed) {
            Debug.print("✅ All Inter-Canister Communication tests passed!");
        } else {
            Debug.print("❌ Some Inter-Canister Communication tests failed!");
        };
        
        all_passed;
    };

    // Test 1: Agent Communicator initialization
    private func test_agent_communicator_init() : async Bool {
        Debug.print("Test 1: Agent Communicator Initialization");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        
        let stats = communicator.get_communication_stats();
        
        let test_passed = stats.active_flows == 0 and 
                         stats.total_audit_entries == 0 and
                         stats.event_subscribers == 0 and
                         stats.event_history_size == 0;
        
        if (test_passed) {
            Debug.print("✅ Agent Communicator initialized correctly");
        } else {
            Debug.print("❌ Agent Communicator initialization failed");
        };
        
        test_passed;
    };

    // Test 2: Event bus functionality
    private func test_event_bus() : async Bool {
        Debug.print("Test 2: Event Bus Functionality");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        
        var event_received = false;
        let test_handler = func(event: Interfaces.SystemEvent) : async () {
            event_received := true;
        };
        
        // Subscribe to events
        communicator.subscribe_to_events("user_registered", test_handler);
        
        // Publish an event
        let test_user_id = Principal.fromText("test-user-123");
        await communicator.publish_event(
            #user_registered(test_user_id),
            Principal.fromText("test-canister")
        );
        
        let stats_after = communicator.get_communication_stats();
        
        let test_passed = event_received and 
                         stats_after.event_subscribers == 1 and
                         stats_after.event_history_size == 1 and
                         stats_after.total_audit_entries > 0;
        
        if (test_passed) {
            Debug.print("✅ Event bus functionality working correctly");
        } else {
            Debug.print("❌ Event bus functionality failed");
        };
        
        test_passed;
    };

    // Test 3: Audit trail logging
    private func test_audit_trail() : async Bool {
        Debug.print("Test 3: Audit Trail Logging");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        
        let test_user_id = Principal.fromText("test-user-456");
        
        // Log several audit entries
        communicator.log_audit_entry({
            timestamp = Time.now();
            canister = "test_canister";
            action = "test_action_1";
            user_id = ?test_user_id;
            transaction_id = ?"tx_123";
            details = "Test audit entry 1";
        });
        
        communicator.log_audit_entry({
            timestamp = Time.now();
            canister = "test_canister";
            action = "test_action_2";
            user_id = ?test_user_id;
            transaction_id = ?"tx_456";
            details = "Test audit entry 2";
        });
        
        communicator.log_audit_entry({
            timestamp = Time.now();
            canister = "other_canister";
            action = "other_action";
            user_id = null;
            transaction_id = null;
            details = "Test audit entry 3";
        });
        
        // Test general audit trail retrieval
        let all_entries = communicator.get_audit_trail(?10);
        
        // Test user-specific audit trail retrieval
        let user_entries = communicator.get_user_audit_trail(test_user_id, ?10);
        
        let test_passed = all_entries.size() >= 3 and
                         user_entries.size() == 2 and
                         all_entries[0].action == "test_action_1";
        
        if (test_passed) {
            Debug.print("✅ Audit trail logging working correctly");
        } else {
            Debug.print("❌ Audit trail logging failed");
            Debug.print("All entries: " # debug_show(all_entries.size()));
            Debug.print("User entries: " # debug_show(user_entries.size()));
        };
        
        test_passed;
    };

    // Test 4: Execution flow coordination
    private func test_execution_flow() : async Bool {
        Debug.print("Test 4: Execution Flow Coordination");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        
        let test_user_id = Principal.fromText("test-user-789");
        let test_plan_id = "plan_123";
        
        // Start execution flow
        let start_result = await communicator.start_execution_flow(test_plan_id, test_user_id);
        
        switch (start_result) {
            case (#ok(_)) {
                // Advance through steps
                let step1_result = await communicator.advance_execution_flow(test_plan_id, #validate_plan);
                let step2_result = await communicator.advance_execution_flow(test_plan_id, #check_portfolio);
                let step3_result = await communicator.advance_execution_flow(test_plan_id, #construct_transaction);
                
                let active_flows = communicator.get_active_execution_flows();
                
                let test_passed = active_flows.size() == 1 and
                                 active_flows[0].plan_id == test_plan_id and
                                 active_flows[0].user_id == test_user_id and
                                 active_flows[0].steps_completed.size() == 3;
                
                if (test_passed) {
                    Debug.print("✅ Execution flow coordination working correctly");
                } else {
                    Debug.print("❌ Execution flow coordination failed");
                    Debug.print("Active flows: " # debug_show(active_flows.size()));
                };
                
                test_passed;
            };
            case (#err(error)) {
                Debug.print("❌ Failed to start execution flow: " # debug_show(error));
                false;
            };
        };
    };

    // Test 5: Inter-canister call protocols
    private func test_inter_canister_calls() : async Bool {
        Debug.print("Test 5: Inter-Canister Call Protocols");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        
        // Test synchronous call
        let sync_result = await communicator.call_user_registry("get_user", Principal.fromText("test-user"));
        
        // Test asynchronous call
        let async_result = await communicator.call_execution_agent("execute_plan", "test-plan");
        
        // Test event-driven call
        let event_result = await communicator.call_risk_guard("evaluate_portfolio", Principal.fromText("test-user"));
        
        // Check audit trail for call logs
        let audit_entries = communicator.get_audit_trail(?20);
        let call_entries = Array.filter<Interfaces.AuditEntry>(audit_entries, func(entry) {
            entry.action == "inter_canister_call_start" or entry.action == "inter_canister_call_success";
        });
        
        let test_passed = call_entries.size() >= 6; // 3 start + 3 success entries
        
        if (test_passed) {
            Debug.print("✅ Inter-canister call protocols working correctly");
        } else {
            Debug.print("❌ Inter-canister call protocols failed");
            Debug.print("Call entries found: " # debug_show(call_entries.size()));
        };
        
        test_passed;
    };

    // Test 6: Error handling and recovery
    private func test_error_handling() : async Bool {
        Debug.print("Test 6: Error Handling and Recovery");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = ExecutionCoordinator.ExecutionCoordinator(mock_registry, communicator);
        
        let test_user_id = Principal.fromText("test-user-error");
        let test_plan_id = "error-plan-123";
        
        // Test error handling
        await coordinator.handle_execution_failure(test_plan_id, test_user_id, "Test error condition");
        
        // Check audit trail for error handling logs
        let audit_entries = communicator.get_audit_trail(?10);
        let error_entries = Array.filter<Interfaces.AuditEntry>(audit_entries, func(entry) {
            entry.action == "execution_failure_handling";
        });
        
        let test_passed = error_entries.size() >= 1;
        
        if (test_passed) {
            Debug.print("✅ Error handling and recovery working correctly");
        } else {
            Debug.print("❌ Error handling and recovery failed");
        };
        
        test_passed;
    };

    // Test 7: Strategy execution coordination
    private func test_strategy_execution_coordination() : async Bool {
        Debug.print("Test 7: Strategy Execution Coordination");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        let coordinator = ExecutionCoordinator.ExecutionCoordinator(mock_registry, communicator);
        
        let test_user_id = Principal.fromText("test-user-strategy");
        let test_plan_id = "strategy-plan-456";
        
        // Test strategy execution (this will fail in mock environment but should log properly)
        let execution_result = await coordinator.execute_strategy_plan(test_plan_id, test_user_id);
        
        // Check audit trail for execution logs
        let audit_entries = communicator.get_audit_trail(?20);
        let execution_entries = Array.filter<Interfaces.AuditEntry>(audit_entries, func(entry) {
            entry.action == "validate_plan_start" or 
            entry.action == "check_portfolio_start" or
            entry.action == "execute_transaction_start";
        });
        
        // Check health monitoring
        let health_stats = await coordinator.monitor_execution_health();
        
        let test_passed = execution_entries.size() >= 1 and
                         health_stats.active_flows >= 0; // Should be 0 or more
        
        if (test_passed) {
            Debug.print("✅ Strategy execution coordination working correctly");
        } else {
            Debug.print("❌ Strategy execution coordination failed");
            Debug.print("Execution entries: " # debug_show(execution_entries.size()));
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

    // Performance test for high-volume communication
    public func run_performance_tests() : async Bool {
        Debug.print("Running Performance Tests for Inter-Canister Communication...");
        
        let mock_registry = create_mock_canister_registry();
        let communicator = InterCanister.AgentCommunicator(mock_registry);
        
        let start_time = Time.now();
        
        // Test 100 rapid audit log entries
        for (i in Array.range(0, 99)) {
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "performance_test";
                action = "test_action_" # Nat.toText(i);
                user_id = ?Principal.fromText("perf-user-" # Nat.toText(i % 10));
                transaction_id = ?"tx_" # Nat.toText(i);
                details = "Performance test entry " # Nat.toText(i);
            });
        };
        
        // Test 50 event publications
        for (i in Array.range(0, 49)) {
            await communicator.publish_event(
                #user_registered(Principal.fromText("perf-user-" # Nat.toText(i))),
                Principal.fromText("performance_test")
            );
        };
        
        let end_time = Time.now();
        let duration_ms = (end_time - start_time) / 1_000_000; // Convert to milliseconds
        
        let stats = communicator.get_communication_stats();
        
        let performance_acceptable = duration_ms < 5000 and // Less than 5 seconds
                                   stats.total_audit_entries >= 100 and
                                   stats.event_history_size >= 50;
        
        if (performance_acceptable) {
            Debug.print("✅ Performance tests passed - Duration: " # Int.toText(duration_ms) # "ms");
        } else {
            Debug.print("❌ Performance tests failed - Duration: " # Int.toText(duration_ms) # "ms");
        };
        
        performance_acceptable;
    };
}