import Types "../shared/types";
import Utils "../shared/utils";
import Constants "../shared/constants";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Option "mo:base/Option";

module {
    // Bitcoin transaction input
    public type TxInput = {
        txid: Text;
        vout: Nat32;
        amount_sats: Nat64;
        script_sig: ?Blob; // Will be filled during signing
    };

    // Bitcoin transaction output
    public type TxOutput = {
        address: Text;
        amount_sats: Nat64;
    };

    // Raw Bitcoin transaction structure
    public type RawTransaction = {
        version: Nat32;
        inputs: [TxInput];
        outputs: [TxOutput];
        locktime: Nat32;
    };

    // Transaction construction result
    public type TxConstructionResult = {
        raw_tx: RawTransaction;
        total_input: Nat64;
        total_output: Nat64;
        fee_sats: Nat64;
        change_output: ?TxOutput;
    };

    // UTXO selection strategy
    public type UTXOSelectionStrategy = {
        #largest_first;
        #smallest_first;
        #optimal; // Minimize fee while meeting amount requirement
    };

    // Fee estimation parameters
    public type FeeEstimation = {
        sat_per_byte: Nat64;
        estimated_size_bytes: Nat32;
        total_fee_sats: Nat64;
    };

    // Transaction builder class
    public class TransactionBuilder() {
        
        // Estimate transaction size in bytes
        public func estimateTransactionSize(input_count: Nat, output_count: Nat) : Nat32 {
            // Base transaction size: version (4) + input_count (1-9) + output_count (1-9) + locktime (4)
            let base_size = 4 + 1 + 1 + 4; // Simplified for small counts
            
            // Each input: txid (32) + vout (4) + script_sig_length (1) + script_sig (~107 for P2PKH) + sequence (4)
            let input_size = input_count * (32 + 4 + 1 + 107 + 4);
            
            // Each output: amount (8) + script_pubkey_length (1) + script_pubkey (~25 for P2PKH)
            let output_size = output_count * (8 + 1 + 25);
            
            Nat32.fromNat(base_size + input_size + output_size)
        };

        // Estimate transaction fee
        public func estimateFee(input_count: Nat, output_count: Nat, sat_per_byte: Nat64) : FeeEstimation {
            let estimated_size = estimateTransactionSize(input_count, output_count);
            let total_fee = sat_per_byte * Nat64.fromNat32(estimated_size);
            
            {
                sat_per_byte = sat_per_byte;
                estimated_size_bytes = estimated_size;
                total_fee_sats = total_fee;
            }
        };

        // Select UTXOs for a given amount using specified strategy
        public func selectUTXOs(
            utxos: [Types.UTXO], 
            target_amount: Nat64, 
            strategy: UTXOSelectionStrategy
        ) : Result.Result<[Types.UTXO], Text> {
            
            // Filter only confirmed and unspent UTXOs
            let available_utxos = Array.filter<Types.UTXO>(utxos, func(utxo) {
                not utxo.spent and utxo.confirmations >= Constants.BITCOIN_CONFIRMATIONS_REQUIRED
            });

            if (available_utxos.size() == 0) {
                return #err("No confirmed UTXOs available");
            };

            // Sort UTXOs based on strategy
            let sorted_utxos = switch (strategy) {
                case (#largest_first) {
                    Array.sort<Types.UTXO>(available_utxos, func(a, b) {
                        if (a.amount_sats > b.amount_sats) { #less }
                        else if (a.amount_sats < b.amount_sats) { #greater }
                        else { #equal }
                    })
                };
                case (#smallest_first) {
                    Array.sort<Types.UTXO>(available_utxos, func(a, b) {
                        if (a.amount_sats < b.amount_sats) { #less }
                        else if (a.amount_sats > b.amount_sats) { #greater }
                        else { #equal }
                    })
                };
                case (#optimal) {
                    // For optimal selection, prefer UTXOs that minimize the number of inputs
                    // while still covering the target amount
                    Array.sort<Types.UTXO>(available_utxos, func(a, b) {
                        if (a.amount_sats > b.amount_sats) { #less }
                        else if (a.amount_sats < b.amount_sats) { #greater }
                        else { #equal }
                    })
                };
            };

            // Select UTXOs until we have enough to cover the target amount
            let selected_buffer = Buffer.Buffer<Types.UTXO>(sorted_utxos.size());
            var total_selected: Nat64 = 0;

            for (utxo in sorted_utxos.vals()) {
                selected_buffer.add(utxo);
                total_selected += utxo.amount_sats;
                
                if (total_selected >= target_amount) {
                    return #ok(Buffer.toArray(selected_buffer));
                };
            };

            #err("Insufficient funds: need " # Nat64.toText(target_amount) # " sats, have " # Nat64.toText(total_selected) # " sats")
        };

        // Generate change address (simplified - in production would derive from user's wallet)
        public func generateChangeAddress(user_address: Text) : Text {
            // For MVP, return the same address as change address
            // In production, this would derive a new address from the user's wallet
            user_address
        };

        // Build transaction for strategy execution
        public func buildStrategyTransaction(
            user_utxos: [Types.UTXO],
            strategy_plan: Types.StrategyPlan,
            user_change_address: Text,
            sat_per_byte: Nat64
        ) : Result.Result<TxConstructionResult, Text> {
            
            // Calculate total amount needed for all allocations
            var total_allocation: Nat64 = 0;
            for (allocation in strategy_plan.allocations.vals()) {
                total_allocation += allocation.amount_sats;
            };

            if (total_allocation == 0) {
                return #err("Strategy plan has no allocations");
            };

            // Estimate fee for initial UTXO selection (will be refined later)
            let initial_fee_estimate = estimateFee(
                user_utxos.size(), 
                strategy_plan.allocations.size() + 1, // +1 for potential change output
                sat_per_byte
            );

            let total_needed = total_allocation + initial_fee_estimate.total_fee_sats;

            // Select UTXOs
            let utxo_selection = selectUTXOs(user_utxos, total_needed, #optimal);
            let selected_utxos = switch (utxo_selection) {
                case (#ok(utxos)) { utxos };
                case (#err(msg)) { return #err(msg) };
            };

            // Calculate actual total input
            var total_input: Nat64 = 0;
            for (utxo in selected_utxos.vals()) {
                total_input += utxo.amount_sats;
            };

            // Create transaction inputs
            let inputs = Array.map<Types.UTXO, TxInput>(selected_utxos, func(utxo) {
                {
                    txid = utxo.txid;
                    vout = utxo.vout;
                    amount_sats = utxo.amount_sats;
                    script_sig = null; // Will be filled during signing
                }
            });

            // Create transaction outputs for strategy allocations
            let output_buffer = Buffer.Buffer<TxOutput>(strategy_plan.allocations.size() + 1);
            
            for (allocation in strategy_plan.allocations.vals()) {
                // In MVP, we'll use placeholder addresses for different venues
                // In production, these would be actual protocol addresses
                let venue_address = getVenueAddress(allocation.venue_id);
                
                output_buffer.add({
                    address = venue_address;
                    amount_sats = allocation.amount_sats;
                });
            };

            // Recalculate fee with actual input/output counts
            let actual_fee_estimate = estimateFee(
                inputs.size(),
                output_buffer.size() + 1, // +1 for potential change
                sat_per_byte
            );

            let total_output_amount = total_allocation;
            let fee_sats = actual_fee_estimate.total_fee_sats;
            let change_amount = total_input - total_output_amount - fee_sats;

            // Add change output if necessary
            var change_output: ?TxOutput = null;
            if (change_amount > 546) { // Dust threshold
                change_output := ?{
                    address = user_change_address;
                    amount_sats = change_amount;
                };
                switch (change_output) {
                    case (?co) output_buffer.add(co);
                    case null {}; // This shouldn't happen since we check change_amount > 546
                };
            };

            // Validate transaction
            if (total_input < total_output_amount + fee_sats) {
                return #err("Insufficient funds after fee calculation");
            };

            let raw_tx: RawTransaction = {
                version = 2; // BIP 68
                inputs = inputs;
                outputs = Buffer.toArray(output_buffer);
                locktime = 0;
            };

            #ok({
                raw_tx = raw_tx;
                total_input = total_input;
                total_output = total_output_amount + (switch (change_output) { case (?co) co.amount_sats; case null 0 });
                fee_sats = fee_sats;
                change_output = change_output;
            })
        };

        // Get venue address for allocation (placeholder implementation)
        private func getVenueAddress(venue_id: Text) : Text {
            // In MVP, return testnet addresses for different venues
            // In production, these would be actual protocol addresses
            switch (venue_id) {
                case ("lending_pool_1") { "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx" };
                case ("liquidity_pool_1") { "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7" };
                case ("yield_farm_1") { "tb1pxwfh3q9iv9stm5rn7rvaw3leqjzlt2wglc2c8x8mn9cpycghuqxqzrwlq7" };
                case (_) { "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx" }; // Default testnet address
            }
        };

        // Validate transaction before signing
        public func validateTransaction(tx_result: TxConstructionResult) : Result.Result<Bool, Text> {
            let tx = tx_result.raw_tx;
            
            // Basic validation checks
            if (tx.inputs.size() == 0) {
                return #err("Transaction has no inputs");
            };

            if (tx.outputs.size() == 0) {
                return #err("Transaction has no outputs");
            };

            // Check that total input >= total output + fee
            if (tx_result.total_input < tx_result.total_output + tx_result.fee_sats) {
                return #err("Invalid transaction: inputs less than outputs + fee");
            };

            // Validate output amounts (must be above dust threshold)
            for (output in tx.outputs.vals()) {
                if (output.amount_sats < 546) { // Bitcoin dust threshold
                    return #err("Output amount below dust threshold: " # Nat64.toText(output.amount_sats));
                };
            };

            // Validate addresses
            for (output in tx.outputs.vals()) {
                if (not Utils.isValidBitcoinAddress(output.address)) {
                    return #err("Invalid Bitcoin address: " # output.address);
                };
            };

            #ok(true)
        };
    };

    // Utility functions for transaction serialization (simplified for MVP)
    public func serializeTransaction(tx: RawTransaction) : Blob {
        // This is a simplified serialization for MVP
        // In production, would implement proper Bitcoin transaction serialization
        Text.encodeUtf8("serialized_tx_placeholder")
    };

    // Calculate transaction hash (simplified for MVP)
    public func calculateTxHash(tx: RawTransaction) : Text {
        // This would calculate the actual Bitcoin transaction hash
        // For MVP, return a placeholder hash
        "tx_hash_" # Nat32.toText(tx.version) # "_" # Int.toText(Array.size(tx.inputs))
    };
}