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

    private func createTestTransaction(
        txid: Text, 
        uid: Types.UserId, 
        tx_type: Types.TxType, 
        amount: Nat64,
        status: Types.TxStatus
    ) : Types.TxRecord {
        {
            txid = txid;
            user_id = uid;
            tx_type = tx_type;
            amount_sats = amount;
            fee_sats = 1000; // 1000 sats fee
            status = status;
            confirmed_height = ?800000;
            timestamp = Time.now();
        }
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

    // Test transaction recording
    public func test_record_transaction() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Test recording a deposit transaction
        let deposit_tx = createTestTransaction(
            "tx_deposit_001", 
            user_id, 
            #deposit, 
            100000000, // 1 BTC
            #confirmed
        );
        
        let result = await portfolio.record_transaction(user_id, deposit_tx);
        switch (result) {
            case (#ok(txid)) {
                Debug.print("✓ Transaction recorded successfully: " # txid);
                txid == "tx_deposit_001"
            };
            case (#err(error)) {
                Debug.print("✗ Failed to record transaction");
                false
            };
        }
    };

    // Test duplicate transaction prevention
    public func test_duplicate_transaction_prevention() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        let tx = createTestTransaction(
            "tx_duplicate_001", 
            user_id, 
            #deposit, 
            50000000, // 0.5 BTC
            #confirmed
        );
        
        // Record transaction first time
        let result1 = await portfolio.record_transaction(user_id, tx);
        
        // Try to record same transaction again
        let result2 = await portfolio.record_transaction(user_id, tx);
        
        switch (result1, result2) {
            case (#ok(_), #err(#invalid_input(_))) {
                Debug.print("✓ Duplicate transaction correctly prevented");
                true
            };
            case (_, _) {
                Debug.print("✗ Duplicate transaction prevention failed");
                false
            };
        }
    };

    // Test transaction history retrieval
    public func test_get_transaction_history() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Record multiple transactions
        let transactions = [
            createTestTransaction("tx_hist_001", user_id, #deposit, 100000000, #confirmed),
            createTestTransaction("tx_hist_002", user_id, #withdraw, 25000000, #confirmed),
            createTestTransaction("tx_hist_003", user_id, #strategy_execute, 50000000, #pending),
        ];
        
        // Record all transactions
        for (tx in transactions.vals()) {
            ignore await portfolio.record_transaction(user_id, tx);
        };
        
        // Retrieve transaction history
        let history_result = await portfolio.get_transaction_history(user_id);
        
        switch (history_result) {
            case (#ok(history)) {
                if (history.size() >= 3) {
                    Debug.print("✓ Transaction history retrieved successfully: " # debug_show(history.size()) # " transactions");
                    true
                } else {
                    Debug.print("✗ Transaction history incomplete");
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to retrieve transaction history");
                false
            };
        }
    };

    // Test filtered transaction history
    public func test_filtered_transaction_history() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Record transactions of different types
        let deposit_tx = createTestTransaction("tx_filter_001", user_id, #deposit, 100000000, #confirmed);
        let withdraw_tx = createTestTransaction("tx_filter_002", user_id, #withdraw, 25000000, #confirmed);
        let strategy_tx = createTestTransaction("tx_filter_003", user_id, #strategy_execute, 50000000, #confirmed);
        
        ignore await portfolio.record_transaction(user_id, deposit_tx);
        ignore await portfolio.record_transaction(user_id, withdraw_tx);
        ignore await portfolio.record_transaction(user_id, strategy_tx);
        
        // Test filtering by deposit type
        let deposit_filter_result = await portfolio.get_filtered_transaction_history(user_id, ?#deposit, null);
        
        switch (deposit_filter_result) {
            case (#ok(filtered_history)) {
                let all_deposits = Array.filter<Types.TxRecord>(filtered_history, func(tx) {
                    switch (tx.tx_type) {
                        case (#deposit) { true };
                        case (_) { false };
                    }
                });
                
                if (all_deposits.size() == filtered_history.size() and filtered_history.size() >= 1) {
                    Debug.print("✓ Filtered transaction history works correctly");
                    true
                } else {
                    Debug.print("✗ Filtered transaction history failed");
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to get filtered transaction history");
                false
            };
        }
    };

    // Test transaction history with limit
    public func test_transaction_history_with_limit() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Record 5 transactions
        for (i in Array.range(0, 4)) {
            let tx = createTestTransaction(
                "tx_limit_" # debug_show(i), 
                user_id, 
                #deposit, 
                10000000, 
                #confirmed
            );
            ignore await portfolio.record_transaction(user_id, tx);
        };
        
        // Get limited history (3 transactions)
        let limited_result = await portfolio.get_filtered_transaction_history(user_id, null, ?3);
        
        switch (limited_result) {
            case (#ok(limited_history)) {
                if (limited_history.size() == 3) {
                    Debug.print("✓ Transaction history limit works correctly");
                    true
                } else {
                    Debug.print("✗ Transaction history limit failed: got " # debug_show(limited_history.size()) # " transactions");
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to get limited transaction history");
                false
            };
        }
    };

    // Test transaction statistics
    public func test_transaction_statistics() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Record various transactions
        let deposit1 = createTestTransaction("tx_stats_001", user_id, #deposit, 100000000, #confirmed);
        let deposit2 = createTestTransaction("tx_stats_002", user_id, #deposit, 50000000, #confirmed);
        let withdraw1 = createTestTransaction("tx_stats_003", user_id, #withdraw, 25000000, #confirmed);
        let pending_tx = createTestTransaction("tx_stats_004", user_id, #strategy_execute, 30000000, #pending);
        
        ignore await portfolio.record_transaction(user_id, deposit1);
        ignore await portfolio.record_transaction(user_id, deposit2);
        ignore await portfolio.record_transaction(user_id, withdraw1);
        ignore await portfolio.record_transaction(user_id, pending_tx);
        
        // Get transaction statistics
        let stats_result = await portfolio.get_transaction_stats(user_id);
        
        switch (stats_result) {
            case (#ok(stats)) {
                let expected_deposits = 150000000; // 1.5 BTC
                let expected_withdrawals = 25000000; // 0.25 BTC
                
                if (stats.total_transactions >= 4 and 
                    stats.total_deposits == expected_deposits and 
                    stats.total_withdrawals == expected_withdrawals and
                    stats.pending_transactions >= 1) {
                    Debug.print("✓ Transaction statistics calculated correctly");
                    true
                } else {
                    Debug.print("✗ Transaction statistics incorrect");
                    Debug.print("Expected deposits: " # debug_show(expected_deposits) # ", got: " # debug_show(stats.total_deposits));
                    Debug.print("Expected withdrawals: " # debug_show(expected_withdrawals) # ", got: " # debug_show(stats.total_withdrawals));
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to get transaction statistics");
                false
            };
        }
    };

    // Test PnL calculation and position updates
    public func test_pnl_calculation() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Create a position with entry price
        let position = createTestPosition(
            user_id,
            "lending_protocol_1",
            50000000, // 0.5 BTC
            20000.0   // Entry price $20k
        );
        
        // Update position
        let update_result = await portfolio.update_position(user_id, position);
        
        switch (update_result) {
            case (#ok(_)) {
                // Calculate portfolio summary with current BTC price
                let summary_result = await portfolio.calculate_portfolio_summary(user_id, 50000.0); // Current price $50k
                
                switch (summary_result) {
                    case (#ok(summary)) {
                        // Expected PnL: (0.5 BTC * $50k) - $20k = $25k - $20k = $5k profit
                        let expected_pnl = 5000.0;
                        
                        if (summary.positions.size() == 1) {
                            let pos = summary.positions[0];
                            if (pos.pnl >= expected_pnl * 0.9 and pos.pnl <= expected_pnl * 1.1) { // Allow 10% tolerance
                                Debug.print("✓ PnL calculation works correctly: " # debug_show(pos.pnl));
                                true
                            } else {
                                Debug.print("✗ PnL calculation incorrect: expected ~" # debug_show(expected_pnl) # ", got " # debug_show(pos.pnl));
                                false
                            }
                        } else {
                            Debug.print("✗ Position not found in portfolio");
                            false
                        }
                    };
                    case (#err(_)) {
                        Debug.print("✗ Failed to calculate portfolio summary");
                        false
                    };
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to update position");
                false
            };
        }
    };

    // Test portfolio summary generation
    public func test_portfolio_summary_generation() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Add some UTXOs first
        let utxo1 = {
            txid = "utxo_summary_001";
            vout = 0;
            amount_sats = 100000000; // 1 BTC
            address = "tb1test123";
            confirmations = 6;
            block_height = ?800000;
            spent = false;
            spent_in_tx = null;
        };
        
        ignore await portfolio.add_utxo(user_id, utxo1);
        
        // Add a position
        let position = createTestPosition(user_id, "yield_farm_1", 50000000, 25000.0);
        ignore await portfolio.update_position(user_id, position);
        
        // Generate portfolio summary
        let summary_result = await portfolio.calculate_portfolio_summary(user_id, 45000.0); // BTC at $45k
        
        switch (summary_result) {
            case (#ok(summary)) {
                // Expected: 1 BTC in UTXOs + 0.5 BTC in position = 1.5 BTC total
                // At $45k = $67.5k total value
                let expected_btc_value = 45000.0; // 1 BTC * $45k
                let expected_position_value = 22500.0; // 0.5 BTC * $45k
                let expected_total = expected_btc_value + expected_position_value;
                
                if (summary.total_balance_sats == 100000000 and // 1 BTC in UTXOs
                    summary.positions.size() == 1 and
                    summary.total_value_usd >= expected_total * 0.9 and
                    summary.total_value_usd <= expected_total * 1.1) {
                    Debug.print("✓ Portfolio summary generated correctly");
                    Debug.print("Total value: $" # debug_show(summary.total_value_usd));
                    true
                } else {
                    Debug.print("✗ Portfolio summary generation failed");
                    Debug.print("Expected total ~$" # debug_show(expected_total) # ", got $" # debug_show(summary.total_value_usd));
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to generate portfolio summary");
                false
            };
        }
    };

    // Test detailed portfolio retrieval
    public func test_detailed_portfolio() : async Bool {
        let portfolio = await PortfolioState.PortfolioState();
        let user_id = createTestUser();
        
        // Add UTXO
        let utxo = {
            txid = "detailed_utxo_001";
            vout = 0;
            amount_sats = 75000000; // 0.75 BTC
            address = "tb1detailed123";
            confirmations = 3;
            block_height = ?800001;
            spent = false;
            spent_in_tx = null;
        };
        
        ignore await portfolio.add_utxo(user_id, utxo);
        
        // Add multiple positions
        let position1 = createTestPosition(user_id, "lending_1", 25000000, 30000.0);
        let position2 = createTestPosition(user_id, "liquidity_1", 30000000, 35000.0);
        
        ignore await portfolio.update_position(user_id, position1);
        ignore await portfolio.update_position(user_id, position2);
        
        // Get detailed portfolio
        let detailed_result = await portfolio.get_detailed_portfolio(user_id);
        
        switch (detailed_result) {
            case (#ok(detailed)) {
                if (detailed.total_balance_sats == 75000000 and // 0.75 BTC
                    detailed.positions.size() == 2) {
                    Debug.print("✓ Detailed portfolio retrieved correctly");
                    Debug.print("Positions: " # debug_show(detailed.positions.size()));
                    true
                } else {
                    Debug.print("✗ Detailed portfolio retrieval failed");
                    false
                }
            };
            case (#err(_)) {
                Debug.print("✗ Failed to get detailed portfolio");
                false
            };
        }
    };

    // Run all tests
    public func run_all_tests() : async Bool {
        Debug.print("=== Running Transaction History and PnL Tests ===");
        
        let test_results = [
            await test_record_transaction(),
            await test_duplicate_transaction_prevention(),
            await test_get_transaction_history(),
            await test_filtered_transaction_history(),
            await test_transaction_history_with_limit(),
            await test_transaction_statistics(),
            await test_pnl_calculation(),
            await test_portfolio_summary_generation(),
            await test_detailed_portfolio(),
        ];
        
        let passed_tests = Array.filter<Bool>(test_results, func(result) { result });
        let total_tests = test_results.size();
        let passed_count = passed_tests.size();
        
        Debug.print("=== Test Results ===");
        Debug.print("Passed: " # debug_show(passed_count) # "/" # debug_show(total_tests));
        
        if (passed_count == total_tests) {
            Debug.print("✓ All tests passed!");
            true
        } else {
            Debug.print("✗ Some tests failed");
            false
        }
    };
}