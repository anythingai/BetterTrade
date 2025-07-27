import BitcoinTx "../src/execution_agent/bitcoin_tx";
import Types "../src/shared/types";
import Constants "../src/shared/constants";
import Utils "../src/shared/utils";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Text "mo:base/Text";
import Nat "mo:base/Nat";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Bool "mo:base/Bool";

module {
    // Test data setup
    private func createTestUTXOs() : [Types.UTXO] {
        [
            {
                txid = "abc123def456";
                vout = 0;
                amount_sats = 5_000_000; // 0.05 BTC
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                confirmations = 6;
                block_height = ?800_000;
                spent = false;
                spent_in_tx = null;
            },
            {
                txid = "def456ghi789";
                vout = 1;
                amount_sats = 3_000_000; // 0.03 BTC
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                confirmations = 3;
                block_height = ?800_001;
                spent = false;
                spent_in_tx = null;
            },
            {
                txid = "ghi789jkl012";
                vout = 0;
                amount_sats = 1_000_000; // 0.01 BTC
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                confirmations = 1;
                block_height = ?800_002;
                spent = false;
                spent_in_tx = null;
            },
            {
                txid = "jkl012mno345";
                vout = 2;
                amount_sats = 2_000_000; // 0.02 BTC
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                confirmations = 0; // Unconfirmed
                block_height = null;
                spent = false;
                spent_in_tx = null;
            },
            {
                txid = "mno345pqr678";
                vout = 0;
                amount_sats = 4_000_000; // 0.04 BTC
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                confirmations = 5;
                block_height = ?799_999;
                spent = true; // Already spent
                spent_in_tx = ?"spent_tx_123";
            }
        ]
    };

    private func createTestStrategyPlan() : Types.StrategyPlan {
        {
            id = "plan_123";
            user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            template_id = "balanced_strategy";
            allocations = [
                {
                    venue_id = "lending_pool_1";
                    amount_sats = 2_000_000; // 0.02 BTC
                    percentage = 50.0;
                },
                {
                    venue_id = "liquidity_pool_1";
                    amount_sats = 2_000_000; // 0.02 BTC
                    percentage = 50.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Balanced allocation for moderate risk profile";
        }
    };

    // Test transaction size estimation
    public func testTransactionSizeEstimation() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        
        // Test with 2 inputs, 2 outputs
        let size = builder.estimateTransactionSize(2, 2);
        
        // Expected: base(10) + inputs(2*148) + outputs(2*34) = 10 + 296 + 68 = 374 bytes
        let expected_min = 350;
        let expected_max = 400;
        
        Debug.print("Transaction size estimation: " # Nat32.toText(size) # " bytes");
        
        size >= Nat32.fromNat(expected_min) and size <= Nat32.fromNat(expected_max)
    };

    // Test fee estimation
    public func testFeeEstimation() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let sat_per_byte = 10;
        
        let fee_estimate = builder.estimateFee(2, 2, sat_per_byte);
        
        Debug.print("Fee estimation: " # Nat64.toText(fee_estimate.total_fee_sats) # " sats");
        Debug.print("Estimated size: " # Nat32.toText(fee_estimate.estimated_size_bytes) # " bytes");
        Debug.print("Sat per byte: " # Nat64.toText(fee_estimate.sat_per_byte));
        
        // Fee should be reasonable (between 3000-4000 sats for 2in/2out at 10 sat/byte)
        fee_estimate.total_fee_sats >= 3000 and fee_estimate.total_fee_sats <= 4000 and
        fee_estimate.sat_per_byte == sat_per_byte
    };

    // Test UTXO selection - largest first strategy
    public func testUTXOSelectionLargestFirst() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let utxos = createTestUTXOs();
        let target_amount = 4_000_000; // 0.04 BTC
        
        let result = builder.selectUTXOs(utxos, target_amount, #largest_first);
        
        switch (result) {
            case (#ok(selected)) {
                Debug.print("Selected UTXOs count: " # Nat.toText(selected.size()));
                
                var total_selected = 0;
                for (utxo in selected.vals()) {
                    total_selected += Nat64.toNat(utxo.amount_sats);
                    Debug.print("Selected UTXO: " # utxo.txid # " amount: " # Nat64.toText(utxo.amount_sats));
                };
                
                // Should select the largest confirmed UTXO first (5M sats)
                // This alone covers the 4M target
                selected.size() == 1 and 
                selected[0].amount_sats == 5_000_000 and
                Nat64.fromNat(total_selected) >= target_amount
            };
            case (#err(msg)) {
                Debug.print("UTXO selection error: " # msg);
                false
            };
        }
    };

    // Test UTXO selection - insufficient funds
    public func testUTXOSelectionInsufficientFunds() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let utxos = createTestUTXOs();
        let target_amount = 20_000_000; // 0.2 BTC (more than available confirmed)
        
        let result = builder.selectUTXOs(utxos, target_amount, #largest_first);
        
        switch (result) {
            case (#ok(_)) {
                Debug.print("Unexpected success with insufficient funds");
                false
            };
            case (#err(msg)) {
                Debug.print("Expected error: " # msg);
                Text.contains(msg, #text "Insufficient funds")
            };
        }
    };

    // Test UTXO selection - only confirmed UTXOs
    public func testUTXOSelectionConfirmedOnly() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let utxos = createTestUTXOs();
        let target_amount = 2_000_000; // 0.02 BTC
        
        let result = builder.selectUTXOs(utxos, target_amount, #smallest_first);
        
        switch (result) {
            case (#ok(selected)) {
                // Verify all selected UTXOs have sufficient confirmations
                let all_confirmed = Array.foldLeft<Types.UTXO, Bool>(selected, true, func(acc, utxo) {
                    acc and utxo.confirmations >= Constants.BITCOIN_CONFIRMATIONS_REQUIRED and not utxo.spent
                });
                
                Debug.print("All selected UTXOs confirmed: " # Bool.toText(all_confirmed));
                all_confirmed
            };
            case (#err(msg)) {
                Debug.print("UTXO selection error: " # msg);
                false
            };
        }
    };

    // Test strategy transaction building - success case
    public func testBuildStrategyTransactionSuccess() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let utxos = createTestUTXOs();
        let strategy_plan = createTestStrategyPlan();
        let change_address = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7";
        let sat_per_byte = 15;
        
        let result = builder.buildStrategyTransaction(utxos, strategy_plan, change_address, sat_per_byte);
        
        switch (result) {
            case (#ok(tx_result)) {
                Debug.print("Transaction built successfully");
                Debug.print("Total input: " # Nat64.toText(tx_result.total_input));
                Debug.print("Total output: " # Nat64.toText(tx_result.total_output));
                Debug.print("Fee: " # Nat64.toText(tx_result.fee_sats));
                Debug.print("Inputs count: " # Nat.toText(tx_result.raw_tx.inputs.size()));
                Debug.print("Outputs count: " # Nat.toText(tx_result.raw_tx.outputs.size()));
                
                // Verify transaction structure
                let tx = tx_result.raw_tx;
                let valid_structure = 
                    tx.inputs.size() > 0 and
                    tx.outputs.size() >= 2 and // At least 2 allocations
                    tx_result.total_input >= tx_result.total_output + tx_result.fee_sats and
                    tx_result.fee_sats > 0;
                
                // Verify allocations are correctly represented in outputs
                let allocation_outputs = Array.filter<BitcoinTx.TxOutput>(tx.outputs, func(output) {
                    output.address != change_address
                });
                
                let correct_allocations = allocation_outputs.size() == strategy_plan.allocations.size();
                
                Debug.print("Valid structure: " # Bool.toText(valid_structure));
                Debug.print("Correct allocations: " # Bool.toText(correct_allocations));
                
                valid_structure and correct_allocations
            };
            case (#err(msg)) {
                Debug.print("Transaction building error: " # msg);
                false
            };
        }
    };

    // Test strategy transaction building - insufficient funds
    public func testBuildStrategyTransactionInsufficientFunds() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let utxos = createTestUTXOs();
        
        // Create a strategy plan that requires more than available confirmed funds
        let large_strategy_plan = {
            id = "plan_large";
            user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            template_id = "aggressive_strategy";
            allocations = [
                {
                    venue_id = "yield_farm_1";
                    amount_sats = 15_000_000; // 0.15 BTC - more than available
                    percentage = 100.0;
                }
            ];
            created_at = Time.now();
            status = #approved;
            rationale = "Large allocation test";
        };
        
        let change_address = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7";
        let sat_per_byte = 15;
        
        let result = builder.buildStrategyTransaction(utxos, large_strategy_plan, change_address, sat_per_byte);
        
        switch (result) {
            case (#ok(_)) {
                Debug.print("Unexpected success with insufficient funds");
                false
            };
            case (#err(msg)) {
                Debug.print("Expected error: " # msg);
                Text.contains(msg, #text "Insufficient funds")
            };
        }
    };

    // Test transaction validation - valid transaction
    public func testTransactionValidationSuccess() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let utxos = createTestUTXOs();
        let strategy_plan = createTestStrategyPlan();
        let change_address = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7";
        let sat_per_byte = 15;
        
        let build_result = builder.buildStrategyTransaction(utxos, strategy_plan, change_address, sat_per_byte);
        
        switch (build_result) {
            case (#ok(tx_result)) {
                let validation_result = builder.validateTransaction(tx_result);
                
                switch (validation_result) {
                    case (#ok(is_valid)) {
                        Debug.print("Transaction validation: " # Bool.toText(is_valid));
                        is_valid
                    };
                    case (#err(msg)) {
                        Debug.print("Validation error: " # msg);
                        false
                    };
                }
            };
            case (#err(msg)) {
                Debug.print("Transaction building failed: " # msg);
                false
            };
        }
    };

    // Test transaction validation - invalid transaction (no inputs)
    public func testTransactionValidationNoInputs() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        
        let invalid_tx_result: BitcoinTx.TxConstructionResult = {
            raw_tx = {
                version = 2;
                inputs = []; // No inputs - invalid
                outputs = [{
                    address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                    amount_sats = 1_000_000;
                }];
                locktime = 0;
            };
            total_input = 0;
            total_output = 1_000_000;
            fee_sats = 0;
            change_output = null;
        };
        
        let validation_result = builder.validateTransaction(invalid_tx_result);
        
        switch (validation_result) {
            case (#ok(_)) {
                Debug.print("Unexpected validation success for invalid transaction");
                false
            };
            case (#err(msg)) {
                Debug.print("Expected validation error: " # msg);
                Text.contains(msg, #text "no inputs")
            };
        }
    };

    // Test transaction validation - dust output
    public func testTransactionValidationDustOutput() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        
        let dust_tx_result: BitcoinTx.TxConstructionResult = {
            raw_tx = {
                version = 2;
                inputs = [{
                    txid = "test_txid";
                    vout = 0;
                    amount_sats = 1_000_000;
                    script_sig = null;
                }];
                outputs = [{
                    address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                    amount_sats = 500; // Below dust threshold (546 sats)
                }];
                locktime = 0;
            };
            total_input = 1_000_000;
            total_output = 500;
            fee_sats = 999_500;
            change_output = null;
        };
        
        let validation_result = builder.validateTransaction(dust_tx_result);
        
        switch (validation_result) {
            case (#ok(_)) {
                Debug.print("Unexpected validation success for dust output");
                false
            };
            case (#err(msg)) {
                Debug.print("Expected validation error: " # msg);
                Text.contains(msg, #text "dust threshold")
            };
        }
    };

    // Test change address generation
    public func testChangeAddressGeneration() : Bool {
        let builder = BitcoinTx.TransactionBuilder();
        let user_address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
        
        let change_address = builder.generateChangeAddress(user_address);
        
        Debug.print("Generated change address: " # change_address);
        
        // For MVP, change address should be the same as user address
        change_address == user_address
    };

    // Test transaction serialization (placeholder)
    public func testTransactionSerialization() : Bool {
        let raw_tx: BitcoinTx.RawTransaction = {
            version = 2;
            inputs = [{
                txid = "test_txid";
                vout = 0;
                amount_sats = 1_000_000;
                script_sig = null;
            }];
            outputs = [{
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                amount_sats = 900_000;
            }];
            locktime = 0;
        };
        
        let serialized = BitcoinTx.serializeTransaction(raw_tx);
        
        Debug.print("Serialized transaction length: " # Nat.toText(serialized.size()));
        
        // For MVP, just verify we get some serialized data
        serialized.size() > 0
    };

    // Test transaction hash calculation (placeholder)
    public func testTransactionHashCalculation() : Bool {
        let raw_tx: BitcoinTx.RawTransaction = {
            version = 2;
            inputs = [{
                txid = "test_txid";
                vout = 0;
                amount_sats = 1_000_000;
                script_sig = null;
            }];
            outputs = [{
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                amount_sats = 900_000;
            }];
            locktime = 0;
        };
        
        let tx_hash = BitcoinTx.calculateTxHash(raw_tx);
        
        Debug.print("Transaction hash: " # tx_hash);
        
        // For MVP, just verify we get a hash string
        Text.size(tx_hash) > 0 and Text.contains(tx_hash, #text "tx_hash_")
    };

    // Run all tests
    public func runAllTests() : Bool {
        Debug.print("=== Running Bitcoin Transaction Construction Tests ===");
        
        let tests = [
            ("Transaction Size Estimation", testTransactionSizeEstimation),
            ("Fee Estimation", testFeeEstimation),
            ("UTXO Selection - Largest First", testUTXOSelectionLargestFirst),
            ("UTXO Selection - Insufficient Funds", testUTXOSelectionInsufficientFunds),
            ("UTXO Selection - Confirmed Only", testUTXOSelectionConfirmedOnly),
            ("Build Strategy Transaction - Success", testBuildStrategyTransactionSuccess),
            ("Build Strategy Transaction - Insufficient Funds", testBuildStrategyTransactionInsufficientFunds),
            ("Transaction Validation - Success", testTransactionValidationSuccess),
            ("Transaction Validation - No Inputs", testTransactionValidationNoInputs),
            ("Transaction Validation - Dust Output", testTransactionValidationDustOutput),
            ("Change Address Generation", testChangeAddressGeneration),
            ("Transaction Serialization", testTransactionSerialization),
            ("Transaction Hash Calculation", testTransactionHashCalculation),
        ];
        
        var passed = 0;
        var total = tests.size();
        
        for ((name, test) in tests.vals()) {
            Debug.print("\n--- Testing: " # name # " ---");
            if (test()) {
                Debug.print("✅ PASSED: " # name);
                passed += 1;
            } else {
                Debug.print("❌ FAILED: " # name);
            };
        };
        
        Debug.print("\n=== Test Results ===");
        Debug.print("Passed: " # Nat.toText(passed) # "/" # Nat.toText(total));
        
        passed == total
    };
}