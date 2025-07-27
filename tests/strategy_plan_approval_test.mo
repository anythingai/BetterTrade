import Types "../src/shared/types";
import Interfaces "../src/shared/interfaces";
import StrategySelector "../src/strategy_selector/main";
import ExecutionAgent "../src/execution_agent/main";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Debug "mo:base/Debug";
import Array "mo:base/Array";
import Nat "mo:base/Nat";

module {
    // Test utilities
    private func create_test_user() : Types.UserId {
        Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai")
    };

    private func create_test_user_2() : Types.UserId {
        Principal.fromText("rrkah-fqaaa-aaaah-qcaiq-cai")
    };

    // Test strategy plan creation and approval workflow
    public func test_strategy_plan_approval_workflow() : async Bool {
        let strategy_selector = await StrategySelector.StrategySelector();
        let test_user = create_test_user();
        
        Debug.print("Testing strategy plan approval workflow...");
        
        // Step 1: Create a recommendation
        let recommendation_result = await strategy_selector.recommend(test_user, #balanced);
        let plan = switch (recommendation_result) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create recommendation");
                return false;
            };
        };
        
        Debug.print("Created plan: " # plan.id);
        
        // Verify plan is in pending status
        if (plan.status != #pending) {
            Debug.print("Plan should be in pending status");
            return false;
        };
        
        // Step 2: Accept the plan
        let accept_result = await strategy_selector.accept_plan(test_user, plan.id);
        switch (accept_result) {
            case (#ok(success)) {
                if (not success) {
                    Debug.print("Plan acceptance returned false");
                    return false;
                };
            };
            case (#err(e)) {
                Debug.print("Failed to accept plan");
                return false;
            };
        };
        
        // Step 3: Verify plan status changed to approved
        let updated_plan_result = await strategy_selector.get_plan(plan.id);
        let updated_plan = switch (updated_plan_result) {
            case (#ok(p)) { p };
            case (#err(e)) {
                Debug.print("Failed to retrieve updated plan");
                return false;
            };
        };
        
        if (updated_plan.status != #approved) {
            Debug.print("Plan should be in approved status");
            return false;
        };
        
        Debug.print("Strategy plan approval workflow test passed");
        true
    };

    // Test plan locking - user cannot have multiple approved plans
    public func test_plan_locking() : async Bool {
        let strategy_selector = await StrategySelector.StrategySelector();
        let test_user = create_test_user();
        
        Debug.print("Testing plan locking...");
        
        // Create and approve first plan
        let first_recommendation = await strategy_selector.recommend(test_user, #conservative);
        let first_plan = switch (first_recommendation) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create first recommendation");
                return false;
            };
        };
        
        let first_accept_result = await strategy_selector.accept_plan(test_user, first_plan.id);
        switch (first_accept_result) {
            case (#ok(_)) { /* Success */ };
            case (#err(e)) {
                Debug.print("Failed to accept first plan");
                return false;
            };
        };
        
        // Try to create and approve second plan - should fail
        let second_recommendation = await strategy_selector.recommend(test_user, #aggressive);
        let second_plan = switch (second_recommendation) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create second recommendation");
                return false;
            };
        };
        
        let second_accept_result = await strategy_selector.accept_plan(test_user, second_plan.id);
        switch (second_accept_result) {
            case (#ok(_)) {
                Debug.print("Second plan acceptance should have failed due to locking");
                return false;
            };
            case (#err(#invalid_input(msg))) {
                // This is expected - plan locking should prevent multiple approved plans
                Debug.print("Plan locking working correctly: " # msg);
            };
            case (#err(e)) {
                Debug.print("Unexpected error in plan locking test");
                return false;
            };
        };
        
        Debug.print("Plan locking test passed");
        true
    };

    // Test plan cancellation
    public func test_plan_cancellation() : async Bool {
        let strategy_selector = await StrategySelector.StrategySelector();
        let test_user = create_test_user_2();
        
        Debug.print("Testing plan cancellation...");
        
        // Create a recommendation
        let recommendation_result = await strategy_selector.recommend(test_user, #balanced);
        let plan = switch (recommendation_result) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create recommendation for cancellation test");
                return false;
            };
        };
        
        // Accept the plan
        let accept_result = await strategy_selector.accept_plan(test_user, plan.id);
        switch (accept_result) {
            case (#ok(_)) { /* Success */ };
            case (#err(e)) {
                Debug.print("Failed to accept plan for cancellation test");
                return false;
            };
        };
        
        // Cancel the plan
        let cancel_result = await strategy_selector.cancel_plan(test_user, plan.id);
        switch (cancel_result) {
            case (#ok(success)) {
                if (not success) {
                    Debug.print("Plan cancellation returned false");
                    return false;
                };
            };
            case (#err(e)) {
                Debug.print("Failed to cancel plan");
                return false;
            };
        };
        
        // Verify plan status changed to failed (cancelled)
        let cancelled_plan_result = await strategy_selector.get_plan(plan.id);
        let cancelled_plan = switch (cancelled_plan_result) {
            case (#ok(p)) { p };
            case (#err(e)) {
                Debug.print("Failed to retrieve cancelled plan");
                return false;
            };
        };
        
        if (cancelled_plan.status != #failed) {
            Debug.print("Cancelled plan should be in failed status");
            return false;
        };
        
        Debug.print("Plan cancellation test passed");
        true
    };

    // Test unauthorized plan access
    public func test_unauthorized_plan_access() : async Bool {
        let strategy_selector = await StrategySelector.StrategySelector();
        let test_user_1 = create_test_user();
        let test_user_2 = create_test_user_2();
        
        Debug.print("Testing unauthorized plan access...");
        
        // Create a plan for user 1
        let recommendation_result = await strategy_selector.recommend(test_user_1, #conservative);
        let plan = switch (recommendation_result) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create recommendation for unauthorized test");
                return false;
            };
        };
        
        // Try to accept the plan as user 2 - should fail
        let unauthorized_accept = await strategy_selector.accept_plan(test_user_2, plan.id);
        switch (unauthorized_accept) {
            case (#ok(_)) {
                Debug.print("Unauthorized plan acceptance should have failed");
                return false;
            };
            case (#err(#unauthorized)) {
                // This is expected
                Debug.print("Unauthorized access correctly blocked");
            };
            case (#err(e)) {
                Debug.print("Unexpected error in unauthorized access test");
                return false;
            };
        };
        
        // Try to cancel the plan as user 2 - should fail
        let unauthorized_cancel = await strategy_selector.cancel_plan(test_user_2, plan.id);
        switch (unauthorized_cancel) {
            case (#ok(_)) {
                Debug.print("Unauthorized plan cancellation should have failed");
                return false;
            };
            case (#err(#unauthorized)) {
                // This is expected
                Debug.print("Unauthorized cancellation correctly blocked");
            };
            case (#err(e)) {
                Debug.print("Unexpected error in unauthorized cancellation test");
                return false;
            };
        };
        
        Debug.print("Unauthorized plan access test passed");
        true
    };

    // Test plan validation
    public func test_plan_validation() : async Bool {
        let strategy_selector = await StrategySelector.StrategySelector();
        let test_user = create_test_user();
        
        Debug.print("Testing plan validation...");
        
        // Create a recommendation
        let recommendation_result = await strategy_selector.recommend(test_user, #balanced);
        let plan = switch (recommendation_result) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create recommendation for validation test");
                return false;
            };
        };
        
        // Validate pending plan
        let validation_result = await strategy_selector.validate_plan(plan.id);
        let validation = switch (validation_result) {
            case (#ok(v)) { v };
            case (#err(e)) {
                Debug.print("Failed to validate plan");
                return false;
            };
        };
        
        if (not validation.is_valid) {
            Debug.print("Plan should be valid");
            return false;
        };
        
        if (validation.can_execute) {
            Debug.print("Pending plan should not be executable");
            return false;
        };
        
        // Accept the plan and validate again
        let accept_result = await strategy_selector.accept_plan(test_user, plan.id);
        switch (accept_result) {
            case (#ok(_)) { /* Success */ };
            case (#err(e)) {
                Debug.print("Failed to accept plan for validation test");
                return false;
            };
        };
        
        let approved_validation_result = await strategy_selector.validate_plan(plan.id);
        let approved_validation = switch (approved_validation_result) {
            case (#ok(v)) { v };
            case (#err(e)) {
                Debug.print("Failed to validate approved plan");
                return false;
            };
        };
        
        if (not approved_validation.can_execute) {
            Debug.print("Approved plan should be executable");
            return false;
        };
        
        Debug.print("Plan validation test passed");
        true
    };

    // Test audit trail functionality
    public func test_audit_trail() : async Bool {
        let strategy_selector = await StrategySelector.StrategySelector();
        let test_user = create_test_user();
        
        Debug.print("Testing audit trail...");
        
        // Create and approve a plan to generate audit entries
        let recommendation_result = await strategy_selector.recommend(test_user, #aggressive);
        let plan = switch (recommendation_result) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create recommendation for audit test");
                return false;
            };
        };
        
        let accept_result = await strategy_selector.accept_plan(test_user, plan.id);
        switch (accept_result) {
            case (#ok(_)) { /* Success */ };
            case (#err(e)) {
                Debug.print("Failed to accept plan for audit test");
                return false;
            };
        };
        
        // Get audit trail
        let audit_result = await strategy_selector.get_audit_trail(?10);
        let audit_entries = switch (audit_result) {
            case (#ok(entries)) { entries };
            case (#err(e)) {
                Debug.print("Failed to get audit trail");
                return false;
            };
        };
        
        if (audit_entries.size() == 0) {
            Debug.print("Audit trail should contain entries");
            return false;
        };
        
        // Check for plan approval entry
        let has_approval_entry = Array.find<Interfaces.AuditEntry>(audit_entries, func(entry) {
            entry.action == "strategy_plan_approved"
        });
        
        switch (has_approval_entry) {
            case (?entry) {
                Debug.print("Found plan approval audit entry");
            };
            case null {
                Debug.print("Plan approval audit entry not found");
                return false;
            };
        };
        
        // Get user-specific audit trail
        let user_audit_result = await strategy_selector.get_user_audit_trail(test_user, ?5);
        let user_audit_entries = switch (user_audit_result) {
            case (#ok(entries)) { entries };
            case (#err(e)) {
                Debug.print("Failed to get user audit trail");
                return false;
            };
        };
        
        if (user_audit_entries.size() == 0) {
            Debug.print("User audit trail should contain entries");
            return false;
        };
        
        Debug.print("Audit trail test passed");
        true
    };

    // Test getting user's active plan
    public func test_get_user_active_plan() : async Bool {
        let strategy_selector = await StrategySelector.StrategySelector();
        let test_user = create_test_user();
        
        Debug.print("Testing get user active plan...");
        
        // Initially, user should have no active plan
        let initial_active_result = await strategy_selector.get_user_active_plan(test_user);
        let initial_active = switch (initial_active_result) {
            case (#ok(plan_opt)) { plan_opt };
            case (#err(e)) {
                Debug.print("Failed to get initial active plan");
                return false;
            };
        };
        
        switch (initial_active) {
            case (?plan) {
                Debug.print("User should not have active plan initially");
                return false;
            };
            case null { /* Expected */ };
        };
        
        // Create and approve a plan
        let recommendation_result = await strategy_selector.recommend(test_user, #conservative);
        let plan = switch (recommendation_result) {
            case (#ok(p)) { p };
            case (#err(e)) { 
                Debug.print("Failed to create recommendation for active plan test");
                return false;
            };
        };
        
        let accept_result = await strategy_selector.accept_plan(test_user, plan.id);
        switch (accept_result) {
            case (#ok(_)) { /* Success */ };
            case (#err(e)) {
                Debug.print("Failed to accept plan for active plan test");
                return false;
            };
        };
        
        // Now user should have an active plan
        let active_result = await strategy_selector.get_user_active_plan(test_user);
        let active_plan = switch (active_result) {
            case (#ok(?plan)) { plan };
            case (#ok(null)) {
                Debug.print("User should have active plan after approval");
                return false;
            };
            case (#err(e)) {
                Debug.print("Failed to get active plan after approval");
                return false;
            };
        };
        
        if (active_plan.id != plan.id) {
            Debug.print("Active plan ID should match approved plan");
            return false;
        };
        
        if (active_plan.status != #approved) {
            Debug.print("Active plan should be in approved status");
            return false;
        };
        
        Debug.print("Get user active plan test passed");
        true
    };

    // Run all tests
    public func run_all_tests() : async Bool {
        Debug.print("Running strategy plan approval integration tests...");
        
        let test_results = [
            await test_strategy_plan_approval_workflow(),
            await test_plan_locking(),
            await test_plan_cancellation(),
            await test_unauthorized_plan_access(),
            await test_plan_validation(),
            await test_audit_trail(),
            await test_get_user_active_plan()
        ];
        
        let passed_tests = Array.foldLeft<Bool, Nat>(test_results, 0, func(acc, result) {
            if (result) { acc + 1 } else { acc }
        });
        
        let total_tests = test_results.size();
        
        Debug.print("Test Results: " # Nat.toText(passed_tests) # "/" # Nat.toText(total_tests) # " tests passed");
        
        if (passed_tests == total_tests) {
            Debug.print("All strategy plan approval tests passed!");
            true
        } else {
            Debug.print("Some tests failed");
            false
        }
    };
}