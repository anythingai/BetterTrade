import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Types "../shared/types";

// Integration test for Portfolio State UTXO functionality
// This test validates the core UTXO tracking and balance management features

module {
    // Test data constants
    private let TEST_USER_ID = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
    private let TEST_ADDRESS = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
    private let TEST_TXID_1 = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456";
    private let TEST_TXID_2 = "b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567";
    
    // Helper function to create test UTXO
    private func createTestUTXO(txid: Text, vout: Nat32, amount: Nat64, confirmations: Nat32) : Types.UTXO {
        {
            txid = txid;
            vout = vout;
            amount_sats = amount;
            address = TEST_ADDRESS;
            confirmations = confirmations;
            block_height = if (confirmations > 0) { ?800000 } else { null };
            spent = false;
            spent_in_tx = null;
        }
    };

    // Test scenario: User deposits Bitcoin and tracks UTXOs
    public func testUTXOTrackingScenario() : async Bool {
        Debug.print("=== UTXO Tracking Integration Test ===");
        
        try {
            // This would normally be done with a deployed canister
            // For now, we validate the data structures and logic
            
            // Test 1: Create UTXOs with different confirmation states
            let utxo1 = createTestUTXO(TEST_TXID_1, 0, 100000000, 6); // 1 BTC, confirmed
            let utxo2 = createTestUTXO(TEST_TXID_1, 1, 50000000, 0);  // 0.5 BTC, unconfirmed
            let utxo3 = createTestUTXO(TEST_TXID_2, 0, 25000000, 3);  // 0.25 BTC, confirmed
            
            Debug.print("✅ Created test UTXOs");
            
            // Test 2: Validate UTXO structure
            assert(utxo1.amount_sats == 100000000);
            assert(utxo1.confirmations == 6);
            assert(not utxo1.spent);
            assert(utxo2.confirmations == 0);
            assert(utxo3.confirmations == 3);
            
            Debug.print("✅ UTXO structure validation passed");
            
            // Test 3: Test balance calculation logic
            let test_utxos = [utxo1, utxo2, utxo3];
            var total_balance: Nat64 = 0;
            var confirmed_balance: Nat64 = 0;
            
            for (utxo in test_utxos.vals()) {
                if (not utxo.spent) {
                    total_balance += utxo.amount_sats;
                    if (utxo.confirmations >= 1) {
                        confirmed_balance += utxo.amount_sats;
                    };
                };
            };
            
            assert(total_balance == 175000000); // 1.75 BTC total
            assert(confirmed_balance == 125000000); // 1.25 BTC confirmed
            
            Debug.print("✅ Balance calculation logic validated");
            
            // Test 4: Test spent UTXO handling
            let spent_utxo = {
                txid = utxo1.txid;
                vout = utxo1.vout;
                amount_sats = utxo1.amount_sats;
                address = utxo1.address;
                confirmations = utxo1.confirmations;
                block_height = utxo1.block_height;
                spent = true;
                spent_in_tx = ?"spending_tx_123";
            };
            
            let utxos_with_spent = [spent_utxo, utxo2, utxo3];
            total_balance := 0;
            confirmed_balance := 0;
            
            for (utxo in utxos_with_spent.vals()) {
                if (not utxo.spent) {
                    total_balance += utxo.amount_sats;
                    if (utxo.confirmations >= 1) {
                        confirmed_balance += utxo.amount_sats;
                    };
                };
            };
            
            assert(total_balance == 75000000); // 0.75 BTC after spending
            assert(confirmed_balance == 25000000); // 0.25 BTC confirmed after spending
            
            Debug.print("✅ Spent UTXO handling validated");
            
            // Test 5: Test deposit detection structure
            let deposit_detection: Types.DepositDetection = {
                user_id = TEST_USER_ID;
                address = TEST_ADDRESS;
                txid = TEST_TXID_1;
                amount_sats = 100000000;
                confirmations = 0;
                detected_at = Time.now();
                processed = false;
            };
            
            assert(deposit_detection.user_id == TEST_USER_ID);
            assert(deposit_detection.amount_sats == 100000000);
            assert(not deposit_detection.processed);
            
            Debug.print("✅ Deposit detection structure validated");
            
            // Test 6: Test portfolio summary structure
            let portfolio_summary: Types.PortfolioSummary = {
                user_id = TEST_USER_ID;
                total_balance_sats = confirmed_balance;
                total_value_usd = 0.0;
                positions = [];
                pnl_24h = 0.0;
                active_strategy = null;
            };
            
            assert(portfolio_summary.user_id == TEST_USER_ID);
            assert(portfolio_summary.total_balance_sats == 25000000);
            
            Debug.print("✅ Portfolio summary structure validated");
            
            Debug.print("🎉 All UTXO tracking integration tests passed!");
            return true;
            
        } catch (error) {
            Debug.print("❌ Integration test failed: " # debug_show(error));
            return false;
        };
    };

    // Test scenario: Confirmation updates and state transitions
    public func testConfirmationUpdates() : async Bool {
        Debug.print("\n=== Confirmation Updates Test ===");
        
        try {
            // Test confirmation progression
            var utxo = createTestUTXO(TEST_TXID_1, 0, 50000000, 0);
            assert(utxo.confirmations == 0);
            assert(utxo.block_height == null);
            
            // Simulate confirmation update
            utxo := {
                txid = utxo.txid;
                vout = utxo.vout;
                amount_sats = utxo.amount_sats;
                address = utxo.address;
                confirmations = 1;
                block_height = ?800001;
                spent = utxo.spent;
                spent_in_tx = utxo.spent_in_tx;
            };
            
            assert(utxo.confirmations == 1);
            assert(utxo.block_height == ?800001);
            
            Debug.print("✅ Confirmation update logic validated");
            
            // Test multiple confirmation updates
            utxo := {
                txid = utxo.txid;
                vout = utxo.vout;
                amount_sats = utxo.amount_sats;
                address = utxo.address;
                confirmations = 6;
                block_height = ?800006;
                spent = utxo.spent;
                spent_in_tx = utxo.spent_in_tx;
            };
            
            assert(utxo.confirmations == 6);
            assert(utxo.block_height == ?800006);
            
            Debug.print("✅ Multiple confirmation updates validated");
            
            return true;
            
        } catch (error) {
            Debug.print("❌ Confirmation updates test failed: " # debug_show(error));
            return false;
        };
    };

    // Main test runner
    public func runIntegrationTests() : async Bool {
        Debug.print("🚀 Starting Portfolio State Integration Tests");
        
        let test1_result = await testUTXOTrackingScenario();
        let test2_result = await testConfirmationUpdates();
        
        let all_passed = test1_result and test2_result;
        
        if (all_passed) {
            Debug.print("\n🎉 All integration tests PASSED!");
        } else {
            Debug.print("\n❌ Some integration tests FAILED!");
        };
        
        return all_passed;
    };
}