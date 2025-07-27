import Types "../src/shared/types";
import Interfaces "../src/shared/interfaces";
import ExecutionAgent "../src/execution_agent/main";
import PortfolioState "../src/portfolio_state/main";
import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";

// Integration test for portfolio state updates after strategy execution
module {
    public func run_integration_test() : async Bool {
        Debug.print("Running Portfolio State Integration Test...");
        
        // Initialize canisters
        let execution_agent = await ExecutionAgent.ExecutionAgent();
        let portfolio_state = await PortfolioState.PortfolioState();
        
        // Set up inter-canister communication
        ignore await execution_agent.set_portfolio_state_canister(portfolio_state);
        
        let test_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Step 1: Set up initial user portfolio with UTXOs
        Debug.print("Step 1: Setting up initial portfolio...");
        
        let initial_utxos = [
            {
                txid = "deposit_tx_1";
                vout = 0;
                amount_sats = 50_000_000; // 0.5 BTC
                address = "tb1qintegration1";
                confirmations = 6;
                block_height = ?800000;
                spent = false;
                spent_in_tx = null;
            },
            {
                txid = "deposit_tx_2";
                vout = 0;
                amount_sats = 30_000_000; // 0.3 BTC
                address = "tb1qintegration2";
                confirmations = 3;
                block_height = ?800001;
                spent = false;
                spent_in_tx = null;
            }
        ];
        
        for (utxo in initial_utxos.vals()) {
            let add_result = await portfolio_state.add_utxo(test_user, utxo);
            switch (add_result) {
                case (#err(error)) {
                    Debug.print("Failed to add UTXO: " # debug_show(error));
                    return false;
                };
                case (#ok(_)) {};
            };
        };
        
        // Verify initial portfolio state
        let initial_portfolio_result = await portfolio_state.get_portfolio(test_user);
        let initial_balance = switch (initial_portfolio_result) {
            case (#err(_)) { return false; };
            case (#ok(portfolio)) { portfolio.total_balance_sats };
        };
        
        Debug.print("Initial portfolio balance: " # debug_show(initial_balance) # " sats");
        
        // Step 2: Create and execute a strategy plan
        Debug.print("Step 2: Executing strategy plan...");
        
        let strategy_plan: Types.StrategyPlan = {
            id = "integration_test_plan";
            user_id = test_user;
            template_id = "balanced_integration";
            allocations = [
                {
                    venue_id = "defi_protocol_1";
                    amount_sats = 25_000_000; // 0.25 BTC
                    percentage = 50.0;
                },
                {
                    venue_id = "defi_protocol_2";
                    amount_sats = 25_000_000; // 0.25 BTC
                    percentage = 50.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Integration test balanced allocation";
        };
        
        // Simulate successful transaction execution
        let execution_txid = "integration_execution_tx";
        let update_result = await execution_agent.update_portfolio_after_confirmation(
            execution_txid,
            test_user,
            strategy_plan
        );
        
        switch (update_result) {
            case (#err(error)) {
                Debug.print("Portfolio update failed: " # debug_show(error));
                return false;
            };
            case (#ok(_)) {
                Debug.print("Portfolio updated successfully after execution");
            };
        };
        
        // Step 3: Verify portfolio state after execution
        Debug.print("Step 3: Verifying portfolio state after execution...");
        
        // Check transaction history
        let tx_history_result = await portfolio_state.get_transaction_history(test_user);
        let execution_tx_found = switch (tx_history_result) {
            case (#err(_)) { false };
            case (#ok(transactions)) {
                let found = Array.find<Types.TxRecord>(transactions, func(tx) {
                    tx.txid == execution_txid and tx.tx_type == #strategy_execute
                });
                switch (found) {
                    case null { false };
                    case (?_) { true };
                };
            };
        };
        
        if (not execution_tx_found) {
            Debug.print("Execution transaction not found in history");
            return false;
        };
        
        // Check positions were created
        let portfolio_result = await portfolio_state.get_portfolio(test_user);
        let positions_created = switch (portfolio_result) {
            case (#err(_)) { false };
            case (#ok(portfolio)) {
                portfolio.positions.size() == 2 and
                Array.find<Types.Position>(portfolio.positions, func(pos) {
                    pos.venue_id == "defi_protocol_1" and pos.amount_sats == 25_000_000
                }) != null and
                Array.find<Types.Position>(portfolio.positions, func(pos) {
                    pos.venue_id == "defi_protocol_2" and pos.amount_sats == 25_000_000
                }) != null
            };
        };
        
        if (not positions_created) {
            Debug.print("Positions were not created correctly");
            return false;
        };
        
        // Step 4: Check portfolio consistency
        Debug.print("Step 4: Checking portfolio consistency...");
        
        let consistency_result = await execution_agent.check_portfolio_state_consistency(test_user);
        let is_consistent = switch (consistency_result) {
            case (#err(error)) {
                Debug.print("Consistency check failed: " # debug_show(error));
                false
            };
            case (#ok(check)) {
                if (not check.is_consistent) {
                    Debug.print("Portfolio inconsistencies found: " # debug_show(check.inconsistencies));
                };
                check.is_consistent
            };
        };
        
        // Step 5: Test failed transaction handling
        Debug.print("Step 5: Testing failed transaction handling...");
        
        let failed_tx_result = await execution_agent.handle_failed_transaction(
            "failed_integration_tx",
            test_user,
            "Network timeout during broadcast"
        );
        
        let failed_tx_handled = switch (failed_tx_result) {
            case (#err(_)) { false };
            case (#ok(_)) {
                // Verify failed transaction was recorded
                let updated_history_result = await portfolio_state.get_transaction_history(test_user);
                switch (updated_history_result) {
                    case (#err(_)) { false };
                    case (#ok(transactions)) {
                        let failed_tx = Array.find<Types.TxRecord>(transactions, func(tx) {
                            tx.txid == "failed_integration_tx" and tx.status == #failed
                        });
                        switch (failed_tx) {
                            case null { false };
                            case (?_) { true };
                        };
                    };
                };
            };
        };
        
        // Step 6: Test UTXO spending verification
        Debug.print("Step 6: Verifying UTXO spending...");
        
        let utxos_result = await portfolio_state.get_utxos(test_user);
        let utxos_spent_correctly = switch (utxos_result) {
            case (#err(_)) { false };
            case (#ok(utxo_set)) {
                // Check that some UTXOs were marked as spent
                let spent_utxos = Array.filter<Types.UTXO>(utxo_set.utxos, func(utxo) { utxo.spent });
                spent_utxos.size() > 0
            };
        };
        
        // Final verification
        let all_checks_passed = execution_tx_found and positions_created and is_consistent and 
                               failed_tx_handled and utxos_spent_correctly;
        
        if (all_checks_passed) {
            Debug.print("🎉 Portfolio State Integration Test PASSED!");
            Debug.print("✅ Transaction execution recorded");
            Debug.print("✅ Positions created correctly");
            Debug.print("✅ Portfolio state consistent");
            Debug.print("✅ Failed transactions handled");
            Debug.print("✅ UTXO spending tracked");
        } else {
            Debug.print("💥 Portfolio State Integration Test FAILED!");
            Debug.print("Transaction found: " # debug_show(execution_tx_found));
            Debug.print("Positions created: " # debug_show(positions_created));
            Debug.print("State consistent: " # debug_show(is_consistent));
            Debug.print("Failed tx handled: " # debug_show(failed_tx_handled));
            Debug.print("UTXOs spent correctly: " # debug_show(utxos_spent_correctly));
        };
        
        all_checks_passed
    };
}