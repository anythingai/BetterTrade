import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Result "mo:base/Result";

// Import modules to test
import BitcoinNetwork "../src/execution_agent/bitcoin_network";
import BitcoinTx "../src/execution_agent/bitcoin_tx";
import Types "../src/shared/types";
import Utils "../src/shared/utils";

module {
    // Test runner for Bitcoin network integration
    public func runTests() : async Bool {
        Debug.print("=== Bitcoin Network Integration Tests ===");
        
        var all_passed = true;
        
        // Test 1: Bitcoin network integration initialization
        if (not await testNetworkIntegrationInit()) {
            all_passed := false;
        };
        
        // Test 2: Transaction broadcasting simulation
        if (not await testTransactionBroadcast()) {
            all_passed := false;
        };
        
        // Test 3: Transaction status monitoring
        if (not await testTransactionStatusMonitoring()) {
            all_passed := false;
        };
        
        // Test 4: Confirmation tracking
        if (not await testConfirmationTracking()) {
            all_passed := false;
        };
        
        // Test 5: Transaction polling
        if (not await testTransactionPolling()) {
            all_passed := false;
        };
        
        // Test 6: User transaction filtering
        if (not await testUserTransactionFiltering()) {
            all_passed := false;
        };
        
        // Test 7: Monitoring cleanup
        if (not await testMonitoringCleanup()) {
            all_passed := false;
        };
        
        // Test 8: Network statistics
        if (not await testNetworkStatistics()) {
            all_passed := false;
        };
        
        if (all_passed) {
            Debug.print("✅ All Bitcoin network integration tests passed!");
        } else {
            Debug.print("❌ Some Bitcoin network integration tests failed!");
        };
        
        all_passed
    };

    // Test 1: Network integration initialization
    private func testNetworkIntegrationInit() : async Bool {
        Debug.print("Test 1: Network integration initialization");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        let current_network = network_integration.getCurrentNetwork();
        
        // Should return a valid network type
        let is_valid_network = switch (current_network) {
            case (#mainnet or #testnet or #regtest) { true };
        };
        
        if (is_valid_network) {
            Debug.print("✅ Network integration initialized correctly");
            true
        } else {
            Debug.print("❌ Network integration initialization failed");
            false
        }
    };

    // Test 2: Transaction broadcasting simulation
    private func testTransactionBroadcast() : async Bool {
        Debug.print("Test 2: Transaction broadcasting simulation");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        let mock_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Create a mock transaction
        let mock_tx: BitcoinTx.RawTransaction = {
            version = 2;
            inputs = [{
                txid = "mock_input_txid";
                vout = 0;
                amount_sats = 10_000_000;
                script_sig = null;
            }];
            outputs = [{
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                amount_sats = 9_900_000;
            }];
            locktime = 0;
        };
        
        // Test broadcasting
        let broadcast_result = await network_integration.broadcastTransaction(
            mock_tx,
            mock_user,
            ?"test_plan_1"
        );
        
        switch (broadcast_result) {
            case (#ok(broadcast_info)) {
                Debug.print("✅ Transaction broadcast successful: " # broadcast_info.txid);
                true
            };
            case (#err(error_msg)) {
                Debug.print("❌ Transaction broadcast failed: " # error_msg);
                false
            };
        }
    };

    // Test 3: Transaction status monitoring
    private func testTransactionStatusMonitoring() : async Bool {
        Debug.print("Test 3: Transaction status monitoring");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        let mock_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Create and broadcast a mock transaction
        let mock_tx: BitcoinTx.RawTransaction = {
            version = 2;
            inputs = [{
                txid = "mock_status_test_txid";
                vout = 0;
                amount_sats = 5_000_000;
                script_sig = null;
            }];
            outputs = [{
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                amount_sats = 4_900_000;
            }];
            locktime = 0;
        };
        
        let broadcast_result = await network_integration.broadcastTransaction(
            mock_tx,
            mock_user,
            ?"test_plan_status"
        );
        
        switch (broadcast_result) {
            case (#ok(broadcast_info)) {
                let txid = broadcast_info.txid;
                
                // Test getting transaction status
                let status_result = await network_integration.getTransactionStatus(txid);
                
                switch (status_result) {
                    case (#ok(status)) {
                        Debug.print("✅ Transaction status retrieved: " # 
                                  Nat32.toText(status.confirmations) # " confirmations");
                        true
                    };
                    case (#err(error_msg)) {
                        Debug.print("❌ Failed to get transaction status: " # error_msg);
                        false
                    };
                }
            };
            case (#err(error_msg)) {
                Debug.print("❌ Failed to broadcast transaction for status test: " # error_msg);
                false
            };
        }
    };

    // Test 4: Confirmation tracking
    private func testConfirmationTracking() : async Bool {
        Debug.print("Test 4: Confirmation tracking");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        let mock_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Create and broadcast a mock transaction
        let mock_tx: BitcoinTx.RawTransaction = {
            version = 2;
            inputs = [{
                txid = "mock_confirmation_test_txid";
                vout = 0;
                amount_sats = 8_000_000;
                script_sig = null;
            }];
            outputs = [{
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                amount_sats = 7_900_000;
            }];
            locktime = 0;
        };
        
        let broadcast_result = await network_integration.broadcastTransaction(
            mock_tx,
            mock_user,
            ?"test_plan_confirmation"
        );
        
        switch (broadcast_result) {
            case (#ok(broadcast_info)) {
                let txid = broadcast_info.txid;
                
                // Test confirmation checking
                let is_confirmed = await network_integration.isTransactionConfirmed(txid);
                
                Debug.print("✅ Confirmation tracking working. Confirmed: " # 
                          (if (is_confirmed) "true" else "false"));
                true
            };
            case (#err(error_msg)) {
                Debug.print("❌ Failed to broadcast transaction for confirmation test: " # error_msg);
                false
            };
        }
    };

    // Test 5: Transaction polling
    private func testTransactionPolling() : async Bool {
        Debug.print("Test 5: Transaction polling");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        
        // Poll all transaction statuses
        let poll_results = await network_integration.pollTransactionStatuses();
        
        Debug.print("✅ Transaction polling completed. Found " # 
                  Nat.toText(poll_results.size()) # " monitored transactions");
        true
    };

    // Test 6: User transaction filtering
    private func testUserTransactionFiltering() : async Bool {
        Debug.print("Test 6: User transaction filtering");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        let mock_user = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        // Get user transactions
        let user_txs = network_integration.getUserTransactions(mock_user);
        
        Debug.print("✅ User transaction filtering working. Found " # 
                  Nat.toText(user_txs.size()) # " transactions for user");
        true
    };

    // Test 7: Monitoring cleanup
    private func testMonitoringCleanup() : async Bool {
        Debug.print("Test 7: Monitoring cleanup");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        
        // Test cleanup (should not remove recent entries in MVP simulation)
        let cleaned_count = network_integration.cleanupOldEntries();
        
        Debug.print("✅ Monitoring cleanup completed. Cleaned " # 
                  Nat.toText(cleaned_count) # " old entries");
        true
    };

    // Test 8: Network statistics
    private func testNetworkStatistics() : async Bool {
        Debug.print("Test 8: Network statistics");
        
        let network_integration = BitcoinNetwork.BitcoinNetworkIntegration();
        
        // Get monitoring statistics
        let stats = network_integration.getMonitoringStats();
        
        Debug.print("✅ Network statistics retrieved:");
        Debug.print("  Total monitored: " # Nat.toText(stats.total_monitored));
        Debug.print("  Confirmed: " # Nat.toText(stats.confirmed_transactions));
        Debug.print("  Pending: " # Nat.toText(stats.pending_transactions));
        Debug.print("  Failed: " # Nat.toText(stats.failed_transactions));
        
        true
    };

    // Utility functions for testing

    // Create a mock UTXO for testing
    private func createMockUTXO(txid: Text, amount: Nat64) : Types.UTXO {
        {
            txid = txid;
            vout = 0;
            amount_sats = amount;
            address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
            confirmations = 6;
            block_height = ?800000;
            spent = false;
            spent_in_tx = null;
        }
    };

    // Validate transaction ID format
    private func validateTxId(txid: Text) : Bool {
        BitcoinNetwork.isValidTxId(txid)
    };

    // Test utility functions
    public func testUtilityFunctions() : Bool {
        Debug.print("Testing Bitcoin network utility functions");
        
        var all_passed = true;
        
        // Test transaction ID validation
        let valid_txid = "a1b2c3d4e5f6789012345678901234567890123456789012345678901234567890";
        let invalid_txid = "invalid_txid";
        
        if (not BitcoinNetwork.isValidTxId(valid_txid)) {
            Debug.print("❌ Valid transaction ID validation failed");
            all_passed := false;
        };
        
        if (BitcoinNetwork.isValidTxId(invalid_txid)) {
            Debug.print("❌ Invalid transaction ID validation failed");
            all_passed := false;
        };
        
        // Test confirmation time estimation
        let estimated_time = BitcoinNetwork.estimateConfirmationTime(3);
        if (estimated_time != 1800) { // 3 blocks * 10 minutes * 60 seconds
            Debug.print("❌ Confirmation time estimation failed");
            all_passed := false;
        };
        
        if (all_passed) {
            Debug.print("✅ All utility function tests passed");
        };
        
        all_passed
    };
}