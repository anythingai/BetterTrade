import Types "../src/shared/types";
import Interfaces "../src/shared/interfaces";
import ExecutionAgent "../src/execution_agent/main";
import PortfolioState "../src/portfolio_state/main";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Nat "mo:base/Nat";

// Test module for execution agent portfolio state updates
module {
    public func run_tests() : async Bool {
        Debug.print("Running Execution Agent Portfolio State Update Tests...");
        
        var all_tests_passed = true;
        
        // Test 1: Portfolio state update after successful transaction
        let test1_result = await test_portfolio_update_after_confirmation();
        if (not test1_result) {
            all_tests_passed := false;
            Debug.print("❌ Test 1 failed: Portfolio state update after confirmation");
        } else {
            Debug.print("✅ Test 1 passed: Portfolio state update after confirmation");
        };
        
        // Test 2: Failed transaction handling
        let test2_result = await test_failed_transaction_handling();
        if (not test2_result) {
            all_tests_passed := false;
            Debug.print("❌ Test 2 failed: Failed transaction handling");
        } else {
            Debug.print("✅ Test 2 passed: Failed transaction handling");
        };
        
        // Test 3: UTXO spending tracking
        let test3_result = await test_utxo_spending_tracking();
        if (not test3_result) {
            all_tests_passed := false;
            Debug.print("❌ Test 3 failed: UTXO spending tracking");
        } else {
            Debug.print("✅ Test 3 passed: UTXO spending tracking");
        };
        
        // Test 4: Portfolio state consistency check
        let test4_result = await test_portfolio_consistency_check();
        if (not test4_result) {
            all_tests_passed := false;
            Debug.print("❌ Test 4 failed: Portfolio state consistency check");
        } else {
            Debug.print("✅ Test 4 passed: Portfolio state consistency check");
        };
        
        // Test 5: Position tracking for active strategies
        let test5_result = await test_position_tracking();
        if (not test5_result) {
            all_tests_passed := false;
            Debug.print("❌ Test 5 failed: Position tracking for active strategies");
        } else {
            Debug.print("✅ Test 5 passed: Position tracking for active strategies");
        };
        
        // Test 6: Portfolio state validation after execution
        let test6_result = await test_portfolio_state_validation();
        if (not test6_result) {
            all_tests_passed := false;
            Debug.print("❌ Test 6 failed: Portfolio state validation after execution");
        } else {
            Debug.print("✅ Test 6 passed: Portfolio state validation after execution");
        };
        
        // Test 7: Error handling and rollback functionality
        let test7_result = await test_error_handling_and_rollback();
        if (not test7_result) {
            all_tests_passed := false;
            Debug.print("❌ Test 7 failed: Error handling and rollback functionality");
        } else {
            Debug.print("✅ Test 7 passed: Error handling and rollback functionality");
        };
        
        if (all_tests_passed) {
            Debug.print("🎉 All Execution Agent Portfolio State Update tests passed!");
        } else {
            Debug.print("💥 Some Execution Agent Portfolio State Update tests failed!");
        };
        
        all_tests_passed
    };

    // Test portfolio state update after transaction confirmation
    private func test_portfolio_update_after_confirmation() : async Bool {
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up portfolio state canister reference
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        // Create test user and strategy plan
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        let test_txid = "test_confirmed_tx_123";
        
        let test_strategy_plan: Types.StrategyPlan = {
            id = "test_plan_123";
            user_id = test_user;
            template_id = "balanced_strategy";
            allocations = [
                {
                    venue_id = "lending_pool_1";
                    amount_sats = 5_000_000;
                    percentage = 50.0;
                },
                {
                    venue_id = "liquidity_pool_1";
                    amount_sats = 5_000_000;
                    percentage = 50.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Test strategy for portfolio update";
        };
        
        // Add initial UTXO to portfolio state
        let test_utxo: Types.UTXO = {
            txid = "initial_utxo_123";
            vout = 0;
            amount_sats = 15_000_000;
            address = "tb1qtest123";
            confirmations = 6;
            block_height = ?800000;
            spent = false;
            spent_in_tx = null;
        };
        
        let add_utxo_result = await portfolio_state.add_utxo(test_user, test_utxo);
        switch (add_utxo_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {};
        };
        
        // Test portfolio update after confirmation
        let update_result = await execution_agent.update_portfolio_after_confirmation(
            test_txid,
            test_user,
            test_strategy_plan
        );
        
        switch (update_result) {
            case (#err(error)) {
                Debug.print("Portfolio update failed: " # debug_show(error));
                return false;
            };
            case (#ok(_)) {
                // Verify transaction was recorded
                let tx_history_result = await portfolio_state.get_transaction_history(test_user);
                switch (tx_history_result) {
                    case (#err(_)) { return false; };
                    case (#ok(transactions)) {
                        let found_tx = Array.find<Types.TxRecord>(transactions, func(tx) {
                            tx.txid == test_txid and tx.tx_type == #strategy_execute
                        });
                        
                        switch (found_tx) {
                            case null { return false; };
                            case (?tx) {
                                // Verify positions were created
                                let portfolio_result = await portfolio_state.get_portfolio(test_user);
                                switch (portfolio_result) {
                                    case (#err(_)) { return false; };
                                    case (#ok(portfolio)) {
                                        return portfolio.positions.size() == 2; // Two allocations
                                    };
                                };
                            };
                        };
                    };
                };
            };
        };
    };

    // Test failed transaction handling
    private func test_failed_transaction_handling() : async Bool {
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up portfolio state canister reference
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        let test_txid = "test_failed_tx_456";
        let error_reason = "Insufficient funds";
        
        // Test failed transaction handling
        let handle_result = await execution_agent.handle_failed_transaction(
            test_txid,
            test_user,
            error_reason
        );
        
        switch (handle_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {
                // Verify failed transaction was recorded
                let tx_history_result = await portfolio_state.get_transaction_history(test_user);
                switch (tx_history_result) {
                    case (#err(_)) { return false; };
                    case (#ok(transactions)) {
                        let found_tx = Array.find<Types.TxRecord>(transactions, func(tx) {
                            tx.txid == test_txid and tx.status == #failed
                        });
                        
                        switch (found_tx) {
                            case null { return false; };
                            case (?_) { return true; };
                        };
                    };
                };
            };
        };
    };

    // Test UTXO spending tracking
    private func test_utxo_spending_tracking() : async Bool {
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up portfolio state canister reference
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Add test UTXO
        let test_utxo: Types.UTXO = {
            txid = "utxo_to_spend_123";
            vout = 0;
            amount_sats = 10_000_000;
            address = "tb1qtest456";
            confirmations = 6;
            block_height = ?800001;
            spent = false;
            spent_in_tx = null;
        };
        
        let add_result = await portfolio_state.add_utxo(test_user, test_utxo);
        switch (add_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {};
        };
        
        // Create strategy plan that would spend this UTXO
        let strategy_plan: Types.StrategyPlan = {
            id = "spend_test_plan";
            user_id = test_user;
            template_id = "conservative_strategy";
            allocations = [
                {
                    venue_id = "lending_pool_2";
                    amount_sats = 8_000_000;
                    percentage = 100.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Test UTXO spending";
        };
        
        // Test UTXO spending
        let spending_txid = "spending_tx_789";
        let update_result = await execution_agent.update_portfolio_after_confirmation(
            spending_txid,
            test_user,
            strategy_plan
        );
        
        switch (update_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {
                // Verify UTXO was marked as spent
                let utxos_result = await portfolio_state.get_utxos(test_user);
                switch (utxos_result) {
                    case (#err(_)) { return false; };
                    case (#ok(utxo_set)) {
                        let spent_utxo = Array.find<Types.UTXO>(utxo_set.utxos, func(utxo) {
                            utxo.txid == "utxo_to_spend_123" and utxo.spent
                        });
                        
                        switch (spent_utxo) {
                            case null { return false; };
                            case (?utxo) {
                                switch (utxo.spent_in_tx) {
                                    case null { return false; };
                                    case (?spent_tx) { return spent_tx == spending_txid; };
                                };
                            };
                        };
                    };
                };
            };
        };
    };

    // Test portfolio state consistency check
    private func test_portfolio_consistency_check() : async Bool {
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up portfolio state canister reference
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Add test UTXO
        let test_utxo: Types.UTXO = {
            txid = "consistency_test_utxo";
            vout = 0;
            amount_sats = 20_000_000;
            address = "tb1qconsistency";
            confirmations = 6;
            block_height = ?800002;
            spent = false;
            spent_in_tx = null;
        };
        
        let add_result = await portfolio_state.add_utxo(test_user, test_utxo);
        switch (add_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {};
        };
        
        // Check consistency
        let consistency_result = await execution_agent.check_portfolio_state_consistency(test_user);
        switch (consistency_result) {
            case (#err(_)) { return false; };
            case (#ok(check)) {
                // Should be consistent with matching balances
                return check.is_consistent and check.utxo_balance == check.portfolio_balance;
            };
        };
    };

    // Test position tracking for active strategies
    private func test_position_tracking() : async Bool {
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up portfolio state canister reference
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Create multi-allocation strategy plan
        let strategy_plan: Types.StrategyPlan = {
            id = "position_tracking_plan";
            user_id = test_user;
            template_id = "aggressive_strategy";
            allocations = [
                {
                    venue_id = "yield_farm_1";
                    amount_sats = 3_000_000;
                    percentage = 30.0;
                },
                {
                    venue_id = "liquidity_pool_2";
                    amount_sats = 4_000_000;
                    percentage = 40.0;
                },
                {
                    venue_id = "lending_pool_3";
                    amount_sats = 3_000_000;
                    percentage = 30.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Test position tracking";
        };
        
        // Execute strategy and update portfolio
        let update_result = await execution_agent.update_portfolio_after_confirmation(
            "position_tracking_tx",
            test_user,
            strategy_plan
        );
        
        switch (update_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {
                // Verify all positions were created
                let portfolio_result = await portfolio_state.get_portfolio(test_user);
                switch (portfolio_result) {
                    case (#err(_)) { return false; };
                    case (#ok(portfolio)) {
                        if (portfolio.positions.size() != 3) {
                            return false;
                        };
                        
                        // Verify each position has correct venue and amount
                        let venue_1_position = Array.find<Types.Position>(portfolio.positions, func(pos) {
                            pos.venue_id == "yield_farm_1" and pos.amount_sats == 3_000_000
                        });
                        
                        let venue_2_position = Array.find<Types.Position>(portfolio.positions, func(pos) {
                            pos.venue_id == "liquidity_pool_2" and pos.amount_sats == 4_000_000
                        });
                        
                        let venue_3_position = Array.find<Types.Position>(portfolio.positions, func(pos) {
                            pos.venue_id == "lending_pool_3" and pos.amount_sats == 3_000_000
                        });
                        
                        switch (venue_1_position, venue_2_position, venue_3_position) {
                            case (?_, ?_, ?_) { return true; };
                            case _ { return false; };
                        };
                    };
                };
            };
        };
    };

    // Test portfolio state validation after execution
    private func test_portfolio_state_validation() : async Bool {
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up portfolio state canister reference
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        let test_txid = "validation_test_tx";
        
        // Create strategy plan with 2 allocations
        let strategy_plan: Types.StrategyPlan = {
            id = "validation_test_plan";
            user_id = test_user;
            template_id = "balanced_strategy";
            allocations = [
                {
                    venue_id = "validation_venue_1";
                    amount_sats = 6_000_000;
                    percentage = 60.0;
                },
                {
                    venue_id = "validation_venue_2";
                    amount_sats = 4_000_000;
                    percentage = 40.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Test portfolio state validation";
        };
        
        // Execute strategy and update portfolio
        let update_result = await execution_agent.update_portfolio_after_confirmation(
            test_txid,
            test_user,
            strategy_plan
        );
        
        switch (update_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {
                // Validate the post-execution state
                let validation_result = await execution_agent.validate_post_execution_state(
                    test_user,
                    test_txid,
                    2 // Expected 2 positions
                );
                
                switch (validation_result) {
                    case (#err(_)) { return false; };
                    case (#ok(validation)) {
                        return validation.is_valid and 
                               validation.position_count == 2 and 
                               validation.transaction_recorded;
                    };
                };
            };
        };
    };

    // Test error handling and rollback functionality
    private func test_error_handling_and_rollback() : async Bool {
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up portfolio state canister reference
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        let test_txid = "rollback_test_tx";
        
        // Create strategy plan
        let strategy_plan: Types.StrategyPlan = {
            id = "rollback_test_plan";
            user_id = test_user;
            template_id = "test_strategy";
            allocations = [
                {
                    venue_id = "rollback_venue_1";
                    amount_sats = 5_000_000;
                    percentage = 100.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Test rollback functionality";
        };
        
        // First, create a position (simulate successful execution)
        let update_result = await execution_agent.update_portfolio_after_confirmation(
            test_txid,
            test_user,
            strategy_plan
        );
        
        switch (update_result) {
            case (#err(_)) { return false; };
            case (#ok(_)) {
                // Verify position was created
                let portfolio_result = await portfolio_state.get_portfolio(test_user);
                let initial_position_count = switch (portfolio_result) {
                    case (#ok(portfolio)) { portfolio.positions.size() };
                    case (#err(_)) { 0 };
                };
                
                if (initial_position_count == 0) {
                    return false;
                };
                
                // Now test rollback
                let rollback_result = await execution_agent.rollback_portfolio_changes(
                    test_user,
                    test_txid,
                    strategy_plan
                );
                
                switch (rollback_result) {
                    case (#err(_)) { return false; };
                    case (#ok(_)) {
                        // Verify positions were rolled back
                        let final_portfolio_result = await portfolio_state.get_portfolio(test_user);
                        let final_position_count = switch (final_portfolio_result) {
                            case (#ok(portfolio)) {
                                // Count non-zero positions
                                Array.foldLeft<Types.Position, Nat>(
                                    portfolio.positions,
                                    0,
                                    func(acc, pos) {
                                        if (pos.amount_sats > 0) { acc + 1 } else { acc }
                                    }
                                )
                            };
                            case (#err(_)) { 0 };
                        };
                        
                        // After rollback, should have fewer active positions
                        return final_position_count < initial_position_count;
                    };
                };
            };
        };
    };
}