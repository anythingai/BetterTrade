import Types "../shared/types";
import Utils "../shared/utils";
import Constants "../shared/constants";
import Config "../shared/config";
import BitcoinTx "./bitcoin_tx";
import Result "mo:base/Result";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Option "mo:base/Option";
import Debug "mo:base/Debug";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";

module {
    // Bitcoin network configuration
    public type BitcoinNetwork = {
        #mainnet;
        #testnet;
        #regtest;
    };

    // Transaction broadcast result
    public type BroadcastResult = {
        txid: Text;
        broadcast_time: Time.Time;
        network: BitcoinNetwork;
    };

    // Transaction confirmation status
    public type ConfirmationStatus = {
        txid: Text;
        confirmations: Nat32;
        block_height: ?Nat32;
        block_hash: ?Text;
        confirmed: Bool;
        last_checked: Time.Time;
    };

    // Bitcoin API response types (simplified for MVP)
    public type BitcoinAPIResponse = {
        #success: Text;
        #error: Text;
    };

    // Transaction monitoring entry
    public type MonitoringEntry = {
        txid: Text;
        user_id: Types.UserId;
        plan_id: ?Types.PlanId;
        broadcast_time: Time.Time;
        target_confirmations: Nat32;
        callback_canister: ?Principal;
    };

    // Bitcoin network integration class
    public class BitcoinNetworkIntegration() {
        
        // Transaction monitoring storage
        private var monitoring_transactions = HashMap.HashMap<Text, MonitoringEntry>(
            0, 
            func(a: Text, b: Text) : Bool { a == b }, 
            func(t: Text) : Nat32 { Text.hash(t) }
        );
        
        // Confirmation status cache
        private var confirmation_cache = HashMap.HashMap<Text, ConfirmationStatus>(
            0, 
            func(a: Text, b: Text) : Bool { a == b }, 
            func(t: Text) : Nat32 { Text.hash(t) }
        );

        // Get current Bitcoin network based on environment
        public func getCurrentNetwork() : BitcoinNetwork {
            switch (Config.CURRENT_ENVIRONMENT) {
                case (#local) { #regtest };
                case (#testnet) { #testnet };
                case (#mainnet) { #mainnet };
            }
        };

        // Broadcast Bitcoin transaction via ICP Bitcoin API
        public func broadcastTransaction(
            signed_tx: BitcoinTx.RawTransaction,
            user_id: Types.UserId,
            plan_id: ?Types.PlanId
        ) : async Result.Result<BroadcastResult, Text> {
            
            let network = getCurrentNetwork();
            let serialized_tx = BitcoinTx.serializeTransaction(signed_tx);
            let txid = BitcoinTx.calculateTxHash(signed_tx);
            
            Debug.print("Broadcasting transaction: " # txid # " on network: " # debug_show(network));
            
            // For MVP, simulate the ICP Bitcoin API call
            // In production, this would make an actual call to the management canister
            let broadcast_result = await simulateBitcoinAPICall(serialized_tx, network);
            
            switch (broadcast_result) {
                case (#success(response)) {
                    let broadcast_time = Time.now();
                    
                    // Add transaction to monitoring
                    let monitoring_entry: MonitoringEntry = {
                        txid = txid;
                        user_id = user_id;
                        plan_id = plan_id;
                        broadcast_time = broadcast_time;
                        target_confirmations = Constants.BITCOIN_CONFIRMATIONS_REQUIRED;
                        callback_canister = null;
                    };
                    
                    monitoring_transactions.put(txid, monitoring_entry);
                    
                    // Initialize confirmation status
                    let initial_status: ConfirmationStatus = {
                        txid = txid;
                        confirmations = 0;
                        block_height = null;
                        block_hash = null;
                        confirmed = false;
                        last_checked = broadcast_time;
                    };
                    
                    confirmation_cache.put(txid, initial_status);
                    
                    Debug.print("Transaction broadcast successful: " # txid);
                    
                    #ok({
                        txid = txid;
                        broadcast_time = broadcast_time;
                        network = network;
                    })
                };
                case (#error(error_msg)) {
                    Debug.print("Transaction broadcast failed: " # error_msg);
                    #err("Failed to broadcast transaction: " # error_msg)
                };
            }
        };

        // Get transaction confirmation status
        public func getTransactionStatus(txid: Text) : async Result.Result<ConfirmationStatus, Text> {
            switch (confirmation_cache.get(txid)) {
                case (?cached_status) {
                    // Check if we need to refresh the status
                    let time_since_check = Time.now() - cached_status.last_checked;
                    let should_refresh = time_since_check > 60_000_000_000; // 1 minute in nanoseconds
                    
                    if (should_refresh and not cached_status.confirmed) {
                        let updated_status = await refreshTransactionStatus(txid);
                        switch (updated_status) {
                            case (#ok(status)) { #ok(status) };
                            case (#err(_)) { #ok(cached_status) }; // Return cached if refresh fails
                        }
                    } else {
                        #ok(cached_status)
                    }
                };
                case null {
                    #err("Transaction not found in monitoring system")
                };
            }
        };

        // Refresh transaction status from Bitcoin network
        private func refreshTransactionStatus(txid: Text) : async Result.Result<ConfirmationStatus, Text> {
            let network = getCurrentNetwork();
            
            // For MVP, simulate Bitcoin network query
            // In production, this would query the actual Bitcoin network via ICP
            let network_response = await simulateBitcoinStatusQuery(txid, network);
            
            switch (network_response) {
                case (#success(status_data)) {
                    let updated_status = parseStatusResponse(txid, status_data);
                    confirmation_cache.put(txid, updated_status);
                    
                    Debug.print("Updated status for " # txid # ": " # Nat32.toText(updated_status.confirmations) # " confirmations");
                    
                    #ok(updated_status)
                };
                case (#error(error_msg)) {
                    Debug.print("Failed to refresh status for " # txid # ": " # error_msg);
                    #err(error_msg)
                };
            }
        };

        // Poll all monitored transactions for status updates
        public func pollTransactionStatuses() : async [(Text, ConfirmationStatus)] {
            let results = Array.init<(Text, ConfirmationStatus)>(monitoring_transactions.size(), ("", {
                txid = "";
                confirmations = 0;
                block_height = null;
                block_hash = null;
                confirmed = false;
                last_checked = Time.now();
            }));
            
            var index = 0;
            for ((txid, _) in monitoring_transactions.entries()) {
                let status_result = await getTransactionStatus(txid);
                switch (status_result) {
                    case (#ok(status)) {
                        results[index] := (txid, status);
                    };
                    case (#err(_)) {
                        // Keep existing status if refresh fails
                        switch (confirmation_cache.get(txid)) {
                            case (?cached) { results[index] := (txid, cached) };
                            case null { /* Skip this entry */ };
                        };
                    };
                };
                index += 1;
            };
            
            Array.freeze(results)
        };

        // Check if transaction has required confirmations
        public func isTransactionConfirmed(txid: Text) : async Bool {
            let status_result = await getTransactionStatus(txid);
            switch (status_result) {
                case (#ok(status)) {
                    status.confirmations >= Constants.BITCOIN_CONFIRMATIONS_REQUIRED
                };
                case (#err(_)) { false };
            }
        };

        // Get all monitored transactions for a user
        public func getUserTransactions(user_id: Types.UserId) : [(Text, MonitoringEntry)] {
            let user_txs = Array.filter<(Text, MonitoringEntry)>(
                monitoring_transactions.entries() |> Iter.toArray(_),
                func((_, entry)) { entry.user_id == user_id }
            );
            user_txs
        };

        // Remove transaction from monitoring (after confirmation)
        public func stopMonitoring(txid: Text) : Bool {
            switch (monitoring_transactions.remove(txid)) {
                case (?_) { 
                    Debug.print("Stopped monitoring transaction: " # txid);
                    true 
                };
                case null { false };
            }
        };

        // Get monitoring statistics
        public func getMonitoringStats() : {
            total_monitored: Nat;
            confirmed_transactions: Nat;
            pending_transactions: Nat;
            failed_transactions: Nat;
        } {
            var confirmed = 0;
            var pending = 0;
            var failed = 0;
            
            for ((txid, _) in monitoring_transactions.entries()) {
                switch (confirmation_cache.get(txid)) {
                    case (?status) {
                        if (status.confirmed) {
                            confirmed += 1;
                        } else if (status.confirmations > 0) {
                            pending += 1;
                        } else {
                            // Check if transaction is old enough to be considered failed
                            let age = Time.now() - status.last_checked;
                            if (age > 3600_000_000_000) { // 1 hour in nanoseconds
                                failed += 1;
                            } else {
                                pending += 1;
                            }
                        }
                    };
                    case null { pending += 1 };
                };
            };
            
            {
                total_monitored = monitoring_transactions.size();
                confirmed_transactions = confirmed;
                pending_transactions = pending;
                failed_transactions = failed;
            }
        };

        // Simulate Bitcoin API call for MVP (replace with actual ICP Bitcoin API in production)
        private func simulateBitcoinAPICall(
            serialized_tx: Blob, 
            network: BitcoinNetwork
        ) : async BitcoinAPIResponse {
            // Simulate network delay
            let tx_size = Blob.toArray(serialized_tx).size();
            
            // Simulate success/failure based on transaction size (for testing)
            if (tx_size > 0 and tx_size < 100000) { // Reasonable transaction size
                #success("Transaction accepted by network")
            } else {
                #error("Transaction rejected: invalid size")
            }
        };

        // Simulate Bitcoin status query for MVP
        private func simulateBitcoinStatusQuery(
            txid: Text, 
            network: BitcoinNetwork
        ) : async BitcoinAPIResponse {
            // Simulate progressive confirmation for testing
            let current_time = Time.now();
            let tx_age_minutes = (current_time / 60_000_000_000) % 10; // Cycle every 10 minutes
            
            let confirmations = if (tx_age_minutes < 2) { 0 }
                              else if (tx_age_minutes < 4) { 1 }
                              else if (tx_age_minutes < 6) { 2 }
                              else { 3 };
            
            let block_height = if (confirmations > 0) { ?(800000 + Nat32.fromNat(Int.abs(tx_age_minutes))) } else { null };
            
            let status_json = "{\"confirmations\":" # Nat.toText(Int.abs(confirmations)) # 
                             ",\"block_height\":" # (switch (block_height) { case (?h) Nat32.toText(h); case null "null" }) # "}";
            
            #success(status_json)
        };

        // Parse status response from Bitcoin network
        private func parseStatusResponse(txid: Text, response_data: Text) : ConfirmationStatus {
            // Simplified JSON parsing for MVP
            // In production, would use proper JSON parsing library
            
            let current_time = Time.now();
            
            // Extract confirmations (simplified parsing)
            let confirmations = if (Text.contains(response_data, #text "\"confirmations\":0")) { 0 }
                               else if (Text.contains(response_data, #text "\"confirmations\":1")) { 1 }
                               else if (Text.contains(response_data, #text "\"confirmations\":2")) { 2 }
                               else if (Text.contains(response_data, #text "\"confirmations\":3")) { 3 }
                               else { 0 };
            
            // Extract block height (simplified)
            let block_height = if (confirmations > 0) { ?800000 } else { null };
            
            {
                txid = txid;
                confirmations = Nat32.fromNat(Int.abs(confirmations));
                block_height = block_height;
                block_hash = if (confirmations > 0) { ?"mock_block_hash" } else { null };
                confirmed = confirmations >= Int.abs(Constants.BITCOIN_CONFIRMATIONS_REQUIRED);
                last_checked = current_time;
            }
        };

        // Cleanup old monitoring entries
        public func cleanupOldEntries() : Nat {
            let current_time = Time.now();
            let cleanup_threshold = 24 * 3600_000_000_000; // 24 hours in nanoseconds
            var cleaned_count = 0;
            
            let entries_to_remove = Array.filter<(Text, MonitoringEntry)>(
                monitoring_transactions.entries() |> Iter.toArray(_),
                func((txid, entry)) {
                    let age = current_time - entry.broadcast_time;
                    if (age > cleanup_threshold) {
                        // Check if transaction is confirmed before removing
                        switch (confirmation_cache.get(txid)) {
                            case (?status) { status.confirmed };
                            case null { true }; // Remove if no status available
                        }
                    } else { false }
                }
            );
            
            for ((txid, _) in entries_to_remove.vals()) {
                monitoring_transactions.delete(txid);
                confirmation_cache.delete(txid);
                cleaned_count += 1;
            };
            
            if (cleaned_count > 0) {
                Debug.print("Cleaned up " # Nat.toText(cleaned_count) # " old monitoring entries");
            };
            
            cleaned_count
        };
    };

    // Utility functions for Bitcoin network integration

    // Validate transaction ID format
    public func isValidTxId(txid: Text) : Bool {
        Text.size(txid) == 64 and Utils.isValidHexString(txid)
    };

    // Calculate estimated confirmation time
    public func estimateConfirmationTime(confirmations_needed: Nat32) : Nat64 {
        // Average Bitcoin block time is 10 minutes
        let minutes_per_block = 10;
        Nat64.fromNat32(confirmations_needed) * Nat64.fromNat(minutes_per_block) * 60 // Convert to seconds
    };

    // Format confirmation status for display
    public func formatConfirmationStatus(status: ConfirmationStatus) : Text {
        let conf_text = Nat32.toText(status.confirmations);
        let required_text = Nat32.toText(Constants.BITCOIN_CONFIRMATIONS_REQUIRED);
        
        if (status.confirmed) {
            "Confirmed (" # conf_text # "/" # required_text # " confirmations)"
        } else if (status.confirmations > 0) {
            "Pending (" # conf_text # "/" # required_text # " confirmations)"
        } else {
            "Unconfirmed (0/" # required_text # " confirmations)"
        }
    };
}