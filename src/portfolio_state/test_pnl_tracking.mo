import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";

import Types "../shared/types";
import PortfolioState "./main";

module {
    // Test helper functions
    private func createTestUser() : Types.UserId {
        Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai")
    };

    private func createTestPosition(
        uid: Types.UserId,
        venue: Text,
        amount: Nat64,
        entry_price: Float
    ) : Types.Position {
        let current_value = (Float.fromInt64(Int64.fromNat64(amount)) / 100000000.0) * 50000.0; // Assume $50k BTC
        {
            user_id = uid;
            venue_id = venue;
            amount_sats = amount;
            entry_price = entry_price;
            current_value = current_value;
            pnl = current_value - entry_price;
        }
    };

    // Test PnL history retrieval
    public func test_pnl_history() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Create positions with different PnL
        let profitable_position = createTestPosition(user_id, "lending_1", 50000000, 20000.0); // Profit
        let losing_position = createTestPosition(user_id, "yield_farm_1", 30000000, 60000.0); // Loss
        
        ignore await portfolio.update_position(user_id, profitable_position);
        ignore await portfolio.update_position(user_id, losing_position);
        
        // Get PnL history
        let pnl_result = await portfolio.get_pnl_history(user_id, null, null);
        
        switch (pnl_result) {
            case (#ok(pnl_data)) {
                if (pnl_data.positions.size() == 2) {
                    let total_expected_pnl = profitable_position.pnl + losing_position.pnl;
                    if (pnl_data.total_pnl >= total_expected_pnl * 0.9 and 
                        pnl_data.total_pnl <= total_expected_pnl * 1.1) {
                        Debug.print("✓ PnL history retrieved correctly");
                        Debug.print("Total PnL: " # debug_show(pnl_data.total_pnl));
                        true
                    } else {
                        Debug.print("✗ PnL calculation mismatch");
                        false
                    }
                } else {
                    Debug.print("✗ Wrong number of positions in PnL history");
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to get PnL history");
                false
            };
        }
    };

    // Test transaction history with PnL impact
    public func test_transaction_history_with_pnl() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Record a transaction
        let tx = {
            txid = "pnl_tx_001";
            user_id = user_id;
            tx_type = #strategy_execute;
            amount_sats = 25000000;
            fee_sats = 1000;
            status = #confirmed;
            confirmed_height = ?800000;
            timestamp = Time.now();
        };
        
        ignore await portfolio.record_transaction(user_id, tx);
        
        // Get transaction history with PnL
        let pnl_history_result = await portfolio.get_transaction_history_with_pnl(user_id);
        
        switch (pnl_history_result) {
            case (#ok(pnl_history)) {
                if (pnl_history.size() >= 1) {
                    let tx_with_pnl = pnl_history[0];
                    if (tx_with_pnl.transaction.txid == "pnl_tx_001") {
                        Debug.print("✓ Transaction history with PnL retrieved correctly");
                        true
                    } else {
                        Debug.print("✗ Wrong transaction in PnL history");
                        false
                    }
                } else {
                    Debug.print("✗ No transactions in PnL history");
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to get transaction history with PnL");
                false
            };
        }
    };

    // Test performance metrics calculation
    public func test_performance_metrics() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Create positions with known PnL
        let winning_position = createTestPosition(user_id, "best_venue", 40000000, 30000.0); // Should be profitable
        let losing_position = createTestPosition(user_id, "worst_venue", 20000000, 70000.0); // Should be losing
        let neutral_position = createTestPosition(user_id, "neutral_venue", 30000000, 50000.0); // Should be neutral
        
        ignore await portfolio.update_position(user_id, winning_position);
        ignore await portfolio.update_position(user_id, losing_position);
        ignore await portfolio.update_position(user_id, neutral_position);
        
        // Calculate performance metrics
        let metrics_result = await portfolio.calculate_performance_metrics(user_id, 50000.0);
        
        switch (metrics_result) {
            case (#ok(metrics)) {
                // Check if best and worst positions are identified correctly
                switch (metrics.best_performing_position, metrics.worst_performing_position) {
                    case (?best, ?worst) {
                        if (best.venue_id == "best_venue" and worst.venue_id == "worst_venue") {
                            Debug.print("✓ Performance metrics calculated correctly");
                            Debug.print("Total return: " # debug_show(metrics.total_return));
                            Debug.print("Return percentage: " # debug_show(metrics.total_return_percentage) # "%");
                            true
                        } else {
                            Debug.print("✗ Best/worst positions not identified correctly");
                            Debug.print("Best: " # debug_show(best.venue_id) # ", Worst: " # debug_show(worst.venue_id));
                            false
                        }
                    };
                    case (_, _) {
                        Debug.print("✗ Best or worst position not found");
                        false
                    };
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to calculate performance metrics");
                false
            };
        }
    };

    // Test performance metrics with no positions
    public func test_performance_metrics_empty() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-caj"); // Different user
        
        // Calculate metrics for user with no positions
        let metrics_result = await portfolio.calculate_performance_metrics(user_id, 50000.0);
        
        switch (metrics_result) {
            case (#ok(metrics)) {
                if (metrics.total_return == 0.0 and 
                    metrics.total_return_percentage == 0.0 and
                    metrics.best_performing_position == null and
                    metrics.worst_performing_position == null) {
                    Debug.print("✓ Empty portfolio performance metrics handled correctly");
                    true
                } else {
                    Debug.print("✗ Empty portfolio metrics not zero");
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to calculate empty portfolio metrics");
                false
            };
        }
    };

    // Test PnL calculation with price changes
    public func test_pnl_with_price_changes() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Create position with specific entry price
        let position = {
            user_id = user_id;
            venue_id = "price_test_venue";
            amount_sats = 100000000; // 1 BTC
            entry_price = 40000.0; // Entry at $40k
            current_value = 40000.0; // Initial value
            pnl = 0.0; // Initial PnL
        };
        
        ignore await portfolio.update_position(user_id, position);
        
        // Calculate portfolio with different BTC prices
        let price_scenarios = [45000.0, 35000.0, 50000.0]; // Up 12.5%, Down 12.5%, Up 25%
        
        var all_tests_passed = true;
        
        for (price in price_scenarios.vals()) {
            let summary_result = await portfolio.calculate_portfolio_summary(user_id, price);
            
            switch (summary_result) {
                case (#ok(summary)) {
                    if (summary.positions.size() == 1) {
                        let updated_pos = summary.positions[0];
                        let expected_pnl = price - 40000.0; // Expected PnL
                        
                        if (updated_pos.pnl >= expected_pnl * 0.95 and 
                            updated_pos.pnl <= expected_pnl * 1.05) {
                            Debug.print("✓ PnL correct for price $" # debug_show(price) # ": " # debug_show(updated_pos.pnl));
                        } else {
                            Debug.print("✗ PnL incorrect for price $" # debug_show(price));
                            Debug.print("Expected: " # debug_show(expected_pnl) # ", Got: " # debug_show(updated_pos.pnl));
                            all_tests_passed := false;
                        };
                    } else {
                        Debug.print("✗ Position not found for price test");
                        all_tests_passed := false;
                    };
                };
                case (#err(_)) {
                    Debug.print("✗ Failed to calculate summary for price $" # debug_show(price));
                    all_tests_passed := false;
                };
            };
        };
        
        all_tests_passed
    };

    // Run all PnL tracking tests
    public func run_all_pnl_tests() : async Bool {
        Debug.print("=== Running PnL Tracking Tests ===");
        
        let test_results = [
            await test_pnl_history(),
            await test_transaction_history_with_pnl(),
            await test_performance_metrics(),
            await test_performance_metrics_empty(),
            await test_pnl_with_price_changes(),
        ];
        
        let passed_tests = Array.filter<Bool>(test_results, func(result) { result });
        let total_tests = test_results.size();
        let passed_count = passed_tests.size();
        
        Debug.print("=== PnL Test Results ===");
        Debug.print("Passed: " # debug_show(passed_count) # "/" # debug_show(total_tests));
        
        if (passed_count == total_tests) {
            Debug.print("✓ All PnL tests passed!");
            true
        } else {
            Debug.print("✗ Some PnL tests failed");
            false
        }
    };
}