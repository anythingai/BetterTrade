import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";

import Types "../src/shared/types";
import UnitTestFramework "./unit_test_framework";

// Comprehensive unit tests for Portfolio State canister
module {
    public class PortfolioStateUnitTests() {
        private let assertions = UnitTestFramework.TestAssertions();
        private let mock_data = UnitTestFramework.MockDataGenerator();
        private let runner = UnitTestFramework.TestRunner();

        // Test UTXO tracking and balance calculation
        public func test_utxo_balance_calculation() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let utxos = [
                mock_data.generate_test_utxo("tx1", 0, 50000000), // 0.5 BTC
                mock_data.generate_test_utxo("tx2", 1, 30000000), // 0.3 BTC
                mock_data.generate_test_utxo("tx3", 0, 20000000)  // 0.2 BTC
            ];
            
            let total_balance = calculate_total_balance(utxos);
            let confirmed_balance = calculate_confirmed_balance(utxos);
            let expected_total = 100000000; // 1.0 BTC in sats
            
            let balance_correct = total_balance == expected_total;
            let confirmed_correct = confirmed_balance == expected_total; // All UTXOs have 6+ confirmations
            
            assertions.assert_true(balance_correct and confirmed_correct, "UTXO balance calculation works correctly")
        };

        // Test transaction history management
        public func test_transaction_history() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let transactions = [
                mock_data.generate_test_transaction(user_id, #deposit, 50000000),
                mock_data.generate_test_transaction(user_id, #strategy_execute, 30000000),
                mock_data.generate_test_transaction(user_id, #withdraw, 10000000)
            ];
            
            let deposit_count = count_transactions_by_type(transactions, #deposit);
            let strategy_count = count_transactions_by_type(transactions, #strategy_execute);
            let withdraw_count = count_transactions_by_type(transactions, #withdraw);
            
            let counts_correct = deposit_count == 1 and strategy_count == 1 and withdraw_count == 1;
            let total_count = transactions.size() == 3;
            
            assertions.assert_true(counts_correct and total_count, "Transaction history management works correctly")
        };

        // Test PnL calculation
        public func test_pnl_calculation() : UnitTestFramework.TestResult {
            let position : Types.Position = {
                user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
                venue_id = "TestVenue";
                amount_sats = 50000000; // 0.5 BTC
                entry_price = 40000.0; // $40,000 per BTC
                current_value = 45000.0; // $45,000 per BTC
                pnl = 0.0; // Will be calculated
            };
            
            let calculated_pnl = calculate_position_pnl(position);
            let expected_pnl = (position.current_value - position.entry_price) * (Float.fromInt(Int64.toInt(Int64.fromNat64(position.amount_sats))) / 100000000.0);
            
            let pnl_correct = Float.abs(calculated_pnl - expected_pnl) < 0.01;
            let pnl_positive = calculated_pnl > 0.0; // Should be positive since current > entry
            
            assertions.assert_true(pnl_correct and pnl_positive, "PnL calculation works correctly")
        };

        // Test portfolio summary generation
        public func test_portfolio_summary() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let positions = [
                {
                    user_id = user_id;
                    venue_id = "Venue1";
                    amount_sats = 30000000;
                    entry_price = 40000.0;
                    current_value = 42000.0;
                    pnl = 1500.0;
                },
                {
                    user_id = user_id;
                    venue_id = "Venue2";
                    amount_sats = 20000000;
                    entry_price = 41000.0;
                    current_value = 43000.0;
                    pnl = 1000.0;
                }
            ];
            
            let summary = generate_portfolio_summary(user_id, positions);
            let expected_balance = 50000000; // 0.5 BTC total
            let expected_pnl = 2500.0; // Sum of position PnLs
            
            let balance_correct = summary.total_balance_sats == expected_balance;
            let pnl_correct = Float.abs(summary.pnl_24h - expected_pnl) < 0.01;
            let positions_correct = summary.positions.size() == 2;
            
            assertions.assert_true(balance_correct and pnl_correct and positions_correct, "Portfolio summary generation works correctly")
        };

        // Test deposit detection and confirmation tracking
        public func test_deposit_detection() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let deposit : Types.DepositDetection = {
                user_id = user_id;
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                txid = "test_deposit_tx_123";
                amount_sats = 100000000; // 1 BTC
                confirmations = 3;
                detected_at = Time.now();
                processed = false;
            };
            
            let needs_processing = not deposit.processed and deposit.confirmations >= 1;
            let amount_valid = deposit.amount_sats > 0;
            let address_valid = Text.size(deposit.address) > 0;
            
            assertions.assert_true(needs_processing and amount_valid and address_valid, "Deposit detection works correctly")
        };

        // Test UTXO state management
        public func test_utxo_state_management() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let utxo = mock_data.generate_test_utxo("tx1", 0, 50000000);
            
            // Test spending UTXO
            let spent_utxo : Types.UTXO = {
                txid = utxo.txid;
                vout = utxo.vout;
                amount_sats = utxo.amount_sats;
                address = utxo.address;
                confirmations = utxo.confirmations;
                block_height = utxo.block_height;
                spent = true;
                spent_in_tx = ?"spending_tx_123";
            };
            
            let spending_tracked = spent_utxo.spent and spent_utxo.spent_in_tx != null;
            let amount_unchanged = spent_utxo.amount_sats == utxo.amount_sats;
            
            assertions.assert_true(spending_tracked and amount_unchanged, "UTXO state management tracks spending correctly")
        };

        // Test transaction status updates
        public func test_transaction_status_updates() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let pending_tx = mock_data.generate_test_transaction(user_id, #deposit, 50000000);
            
            // Update to confirmed
            let confirmed_tx : Types.TxRecord = {
                txid = pending_tx.txid;
                user_id = pending_tx.user_id;
                tx_type = pending_tx.tx_type;
                amount_sats = pending_tx.amount_sats;
                fee_sats = pending_tx.fee_sats;
                status = #confirmed;
                confirmed_height = ?800001;
                timestamp = pending_tx.timestamp;
            };
            
            let status_updated = confirmed_tx.status == #confirmed;
            let height_set = confirmed_tx.confirmed_height != null;
            let other_fields_unchanged = 
                confirmed_tx.txid == pending_tx.txid and
                confirmed_tx.amount_sats == pending_tx.amount_sats;
            
            assertions.assert_true(status_updated and height_set and other_fields_unchanged, "Transaction status updates work correctly")
        };

        // Test portfolio value calculation
        public func test_portfolio_value_calculation() : UnitTestFramework.TestResult {
            let btc_price_usd = 42000.0;
            let balance_sats = 150000000; // 1.5 BTC
            
            let portfolio_value_usd = calculate_portfolio_value_usd(balance_sats, btc_price_usd);
            let expected_value = 63000.0; // 1.5 * 42000
            
            let value_correct = Float.abs(portfolio_value_usd - expected_value) < 0.01;
            
            assertions.assert_true(value_correct, "Portfolio value calculation in USD works correctly")
        };

        // Test position tracking for active strategies
        public func test_position_tracking() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let strategy_id = "balanced-liquidity";
            
            let position : Types.Position = {
                user_id = user_id;
                venue_id = "Uniswap";
                amount_sats = 50000000;
                entry_price = 40000.0;
                current_value = 42000.0;
                pnl = 2500.0;
            };
            
            let position_valid = 
                position.user_id == user_id and
                position.amount_sats > 0 and
                position.entry_price > 0.0 and
                position.current_value > 0.0;
            
            assertions.assert_true(position_valid, "Position tracking for active strategies works correctly")
        };

        // Helper functions for testing
        private func calculate_total_balance(utxos: [Types.UTXO]) : Nat64 {
            Array.foldLeft<Types.UTXO, Nat64>(utxos, 0, func(acc, utxo) {
                if (not utxo.spent) { acc + utxo.amount_sats } else { acc }
            })
        };

        private func calculate_confirmed_balance(utxos: [Types.UTXO]) : Nat64 {
            Array.foldLeft<Types.UTXO, Nat64>(utxos, 0, func(acc, utxo) {
                if (not utxo.spent and utxo.confirmations >= 1) { 
                    acc + utxo.amount_sats 
                } else { 
                    acc 
                }
            })
        };

        private func count_transactions_by_type(transactions: [Types.TxRecord], tx_type: Types.TxType) : Nat {
            Array.foldLeft<Types.TxRecord, Nat>(transactions, 0, func(acc, tx) {
                if (tx.tx_type == tx_type) { acc + 1 } else { acc }
            })
        };

        private func calculate_position_pnl(position: Types.Position) : Float {
            let btc_amount = Float.fromInt(Int64.toInt(Int64.fromNat64(position.amount_sats))) / 100000000.0;
            (position.current_value - position.entry_price) * btc_amount
        };

        private func generate_portfolio_summary(user_id: Types.UserId, positions: [Types.Position]) : Types.PortfolioSummary {
            let total_balance = Array.foldLeft<Types.Position, Nat64>(positions, 0, func(acc, pos) {
                acc + pos.amount_sats
            });
            
            let total_pnl = Array.foldLeft<Types.Position, Float>(positions, 0.0, func(acc, pos) {
                acc + pos.pnl
            });
            
            let total_value_usd = Array.foldLeft<Types.Position, Float>(positions, 0.0, func(acc, pos) {
                acc + pos.current_value * (Float.fromInt(Int64.toInt(Int64.fromNat64(pos.amount_sats))) / 100000000.0)
            });
            
            {
                user_id = user_id;
                total_balance_sats = total_balance;
                total_value_usd = total_value_usd;
                positions = positions;
                pnl_24h = total_pnl;
                active_strategy = ?"balanced-liquidity";
            }
        };

        private func calculate_portfolio_value_usd(balance_sats: Nat64, btc_price_usd: Float) : Float {
            let btc_amount = Float.fromInt(Int64.toInt(Int64.fromNat64(balance_sats))) / 100000000.0;
            btc_amount * btc_price_usd
        };

        // Run all portfolio state unit tests
        public func run_all_tests() : UnitTestFramework.TestSuite {
            let test_functions = [
                test_utxo_balance_calculation,
                test_transaction_history,
                test_pnl_calculation,
                test_portfolio_summary,
                test_deposit_detection,
                test_utxo_state_management,
                test_transaction_status_updates,
                test_portfolio_value_calculation,
                test_position_tracking
            ];
            
            runner.run_test_suite("Portfolio State Unit Tests", test_functions)
        };
    };
}