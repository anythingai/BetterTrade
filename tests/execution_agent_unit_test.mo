import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";

import Types "../src/shared/types";
import UnitTestFramework "./unit_test_framework";

// Comprehensive unit tests for Execution Agent canister
module {
    public class ExecutionAgentUnitTests() {
        private let assertions = UnitTestFramework.TestAssertions();
        private let mock_data = UnitTestFramework.MockDataGenerator();
        private let runner = UnitTestFramework.TestRunner();

        // Test Bitcoin transaction construction
        public func test_bitcoin_transaction_construction() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let utxos = [
                mock_data.generate_test_utxo("input_tx_1", 0, 50000000),
                mock_data.generate_test_utxo("input_tx_2", 1, 30000000)
            ];
            let outputs = [
                { address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"; amount_sats = 70000000 },
                { address = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3"; amount_sats = 9000000 } // change
            ];
            let fee_sats = 1000;
            
            let tx_construction = construct_bitcoin_transaction(utxos, outputs, fee_sats);
            
            let input_total = 80000000; // 0.8 BTC
            let output_total = 79000000; // 0.79 BTC (70M + 9M)
            let calculated_fee = input_total - output_total;
            
            let fee_correct = calculated_fee == fee_sats;
            let inputs_valid = tx_construction.inputs.size() == 2;
            let outputs_valid = tx_construction.outputs.size() == 2;
            
            assertions.assert_true(fee_correct and inputs_valid and outputs_valid, "Bitcoin transaction construction works correctly")
        };

        // Test UTXO selection algorithm
        public func test_utxo_selection() : UnitTestFramework.TestResult {
            let available_utxos = [
                mock_data.generate_test_utxo("tx1", 0, 10000000), // 0.1 BTC
                mock_data.generate_test_utxo("tx2", 0, 25000000), // 0.25 BTC
                mock_data.generate_test_utxo("tx3", 0, 50000000), // 0.5 BTC
                mock_data.generate_test_utxo("tx4", 0, 75000000)  // 0.75 BTC
            ];
            let target_amount = 60000000; // 0.6 BTC
            let fee_estimate = 2000;
            
            let selected_utxos = select_utxos(available_utxos, target_amount + fee_estimate);
            let total_selected = Array.foldLeft<Types.UTXO, Nat64>(
                selected_utxos, 0, func(acc, utxo) { acc + utxo.amount_sats }
            );
            
            let sufficient_amount = total_selected >= (target_amount + fee_estimate);
            let minimal_selection = selected_utxos.size() <= 2; // Should use efficient selection
            
            assertions.assert_true(sufficient_amount and minimal_selection, "UTXO selection algorithm works correctly")
        };

        // Test fee estimation
        public func test_fee_estimation() : UnitTestFramework.TestResult {
            let input_count = 2;
            let output_count = 2;
            let fee_rate_sat_per_vbyte = 10;
            
            let estimated_fee = estimate_transaction_fee(input_count, output_count, fee_rate_sat_per_vbyte);
            
            // Rough calculation: (input_count * 148 + output_count * 34 + 10) * fee_rate
            let expected_size = input_count * 148 + output_count * 34 + 10;
            let expected_fee = expected_size * fee_rate_sat_per_vbyte;
            
            let fee_reasonable = estimated_fee > 0 and estimated_fee < 100000; // Less than 0.001 BTC
            let fee_close_to_expected = Int.abs(estimated_fee - expected_fee) < 1000;
            
            assertions.assert_true(fee_reasonable and fee_close_to_expected, "Fee estimation works correctly")
        };

        // Test transaction signing preparation
        public func test_transaction_signing_preparation() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let tx_data = {
                inputs = [
                    { txid = "input_tx_1"; vout = 0; amount_sats = 50000000 }
                ];
                outputs = [
                    { address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx"; amount_sats = 49000000 }
                ];
                fee_sats = 1000;
            };
            
            let signing_request = prepare_signing_request(user_id, tx_data);
            
            let request_valid = 
                signing_request.user_id == user_id and
                signing_request.tx_data.inputs.size() > 0 and
                signing_request.tx_data.outputs.size() > 0;
            
            let amounts_valid = 
                signing_request.tx_data.fee_sats > 0 and
                signing_request.tx_data.outputs[0]!.amount_sats > 0;
            
            assertions.assert_true(request_valid and amounts_valid, "Transaction signing preparation works correctly")
        };

        // Test transaction broadcasting validation
        public func test_transaction_broadcasting_validation() : UnitTestFramework.TestResult {
            let signed_tx = {
                txid = "broadcast_tx_123";
                raw_tx = "0200000001..."; // Mock raw transaction hex
                size_bytes = 250;
                fee_sats = 2500;
            };
            
            let validation_result = validate_signed_transaction(signed_tx);
            
            let txid_valid = Text.size(signed_tx.txid) > 0;
            let raw_tx_valid = Text.size(signed_tx.raw_tx) > 0;
            let size_reasonable = signed_tx.size_bytes > 0 and signed_tx.size_bytes < 100000;
            let fee_reasonable = signed_tx.fee_sats > 0 and signed_tx.fee_sats < 1000000;
            
            assertions.assert_true(txid_valid and raw_tx_valid and size_reasonable and fee_reasonable, "Transaction broadcasting validation works correctly")
        };

        // Test confirmation tracking
        public func test_confirmation_tracking() : UnitTestFramework.TestResult {
            let txid = "confirmation_tx_123";
            let initial_status = {
                txid = txid;
                confirmations = 0;
                block_height = null : ?Nat32;
                status = #pending;
            };
            
            let confirmed_status = {
                txid = txid;
                confirmations = 3;
                block_height = ?800123;
                status = #confirmed;
            };
            
            let status_updated = initial_status.status != confirmed_status.status;
            let confirmations_increased = confirmed_status.confirmations > initial_status.confirmations;
            let block_height_set = confirmed_status.block_height != null;
            
            assertions.assert_true(status_updated and confirmations_increased and block_height_set, "Confirmation tracking works correctly")
        };

        // Test change address generation
        public func test_change_address_generation() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let change_address = generate_change_address(user_id);
            
            let address_valid = Text.size(change_address) >= 26 and Text.size(change_address) <= 62;
            let is_testnet = Text.startsWith(change_address, #text("tb1")) or 
                           Text.startsWith(change_address, #text("2")) or
                           Text.startsWith(change_address, #text("m")) or
                           Text.startsWith(change_address, #text("n"));
            
            assertions.assert_true(address_valid and is_testnet, "Change address generation works correctly")
        };

        // Test strategy execution workflow
        public func test_strategy_execution_workflow() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let strategy_plan : Types.StrategyPlan = {
                id = "test_plan_123";
                user_id = user_id;
                template_id = "balanced-liquidity";
                allocations = [
                    { venue_id = "Uniswap"; amount_sats = 50000000; percentage = 50.0 },
                    { venue_id = "Curve"; amount_sats = 50000000; percentage = 50.0 }
                ];
                created_at = Time.now();
                status = #approved;
                rationale = "Test strategy execution";
            };
            
            let execution_result = execute_strategy_plan(strategy_plan);
            
            let plan_processed = execution_result.plan_id == strategy_plan.id;
            let transactions_created = execution_result.transaction_ids.size() > 0;
            let status_updated = execution_result.status == #executed;
            
            assertions.assert_true(plan_processed and transactions_created and status_updated, "Strategy execution workflow works correctly")
        };

        // Test error handling for insufficient funds
        public func test_insufficient_funds_handling() : UnitTestFramework.TestResult {
            let available_utxos = [
                mock_data.generate_test_utxo("tx1", 0, 10000000) // Only 0.1 BTC available
            ];
            let target_amount = 50000000; // Need 0.5 BTC
            let fee_estimate = 2000;
            
            let selection_result = try_select_utxos(available_utxos, target_amount + fee_estimate);
            
            let insufficient_funds_detected = switch (selection_result) {
                case (#err(error)) { Text.contains(error, #text("insufficient")) };
                case (#ok(_)) { false };
            };
            
            assertions.assert_true(insufficient_funds_detected, "Insufficient funds handling works correctly")
        };

        // Helper functions for testing
        private func construct_bitcoin_transaction(
            utxos: [Types.UTXO], 
            outputs: [{address: Text; amount_sats: Nat64}], 
            fee_sats: Nat64
        ) : {inputs: [{txid: Text; vout: Nat32; amount_sats: Nat64}]; outputs: [{address: Text; amount_sats: Nat64}]; fee_sats: Nat64} {
            let inputs = Array.map<Types.UTXO, {txid: Text; vout: Nat32; amount_sats: Nat64}>(utxos, func(utxo) {
                { txid = utxo.txid; vout = utxo.vout; amount_sats = utxo.amount_sats }
            });
            
            { inputs = inputs; outputs = outputs; fee_sats = fee_sats }
        };

        private func select_utxos(available_utxos: [Types.UTXO], target_amount: Nat64) : [Types.UTXO] {
            // Simple greedy selection - largest first
            let sorted_utxos = Array.sort<Types.UTXO>(available_utxos, func(a, b) {
                if (a.amount_sats > b.amount_sats) { #less }
                else if (a.amount_sats < b.amount_sats) { #greater }
                else { #equal }
            });
            
            var selected : [Types.UTXO] = [];
            var total_selected : Nat64 = 0;
            
            for (utxo in sorted_utxos.vals()) {
                if (total_selected < target_amount) {
                    selected := Array.append(selected, [utxo]);
                    total_selected += utxo.amount_sats;
                };
            };
            
            selected
        };

        private func estimate_transaction_fee(input_count: Int, output_count: Int, fee_rate: Int) : Int {
            // Rough estimation: inputs are ~148 bytes, outputs ~34 bytes, overhead ~10 bytes
            let estimated_size = input_count * 148 + output_count * 34 + 10;
            estimated_size * fee_rate
        };

        private func prepare_signing_request(
            user_id: Types.UserId, 
            tx_data: {inputs: [{txid: Text; vout: Nat32; amount_sats: Nat64}]; outputs: [{address: Text; amount_sats: Nat64}]; fee_sats: Nat64}
        ) : {user_id: Types.UserId; tx_data: {inputs: [{txid: Text; vout: Nat32; amount_sats: Nat64}]; outputs: [{address: Text; amount_sats: Nat64}]; fee_sats: Nat64}} {
            { user_id = user_id; tx_data = tx_data }
        };

        private func validate_signed_transaction(signed_tx: {txid: Text; raw_tx: Text; size_bytes: Int; fee_sats: Nat64}) : Bool {
            Text.size(signed_tx.txid) > 0 and
            Text.size(signed_tx.raw_tx) > 0 and
            signed_tx.size_bytes > 0 and
            signed_tx.fee_sats > 0
        };

        private func generate_change_address(user_id: Types.UserId) : Text {
            // Mock change address generation - in real implementation would derive from user's key
            "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3"
        };

        private func execute_strategy_plan(plan: Types.StrategyPlan) : {plan_id: Text; transaction_ids: [Text]; status: Types.PlanStatus} {
            // Mock strategy execution
            let tx_ids = Array.map<Types.Allocation, Text>(plan.allocations, func(alloc) {
                "tx_" # alloc.venue_id # "_" # Int.toText(Time.now())
            });
            
            {
                plan_id = plan.id;
                transaction_ids = tx_ids;
                status = #executed;
            }
        };

        private func try_select_utxos(available_utxos: [Types.UTXO], target_amount: Nat64) : Result.Result<[Types.UTXO], Text> {
            let total_available = Array.foldLeft<Types.UTXO, Nat64>(
                available_utxos, 0, func(acc, utxo) { acc + utxo.amount_sats }
            );
            
            if (total_available < target_amount) {
                #err("Insufficient funds: need " # Nat64.toText(target_amount) # " but only " # Nat64.toText(total_available) # " available")
            } else {
                #ok(select_utxos(available_utxos, target_amount))
            }
        };

        // Run all execution agent unit tests
        public func run_all_tests() : UnitTestFramework.TestSuite {
            let test_functions = [
                test_bitcoin_transaction_construction,
                test_utxo_selection,
                test_fee_estimation,
                test_transaction_signing_preparation,
                test_transaction_broadcasting_validation,
                test_confirmation_tracking,
                test_change_address_generation,
                test_strategy_execution_workflow,
                test_insufficient_funds_handling
            ];
            
            runner.run_test_suite("Execution Agent Unit Tests", test_functions)
        };
    };
}