import BitcoinTxTest "./bitcoin_tx_test";
import TECDSASignerTest "./tecdsa_signer_test";
import BitcoinNetworkTest "./bitcoin_network_test";
import Debug "mo:base/Debug";

actor TestRunner {
    public func runBitcoinTxTests() : async Bool {
        Debug.print("Starting Bitcoin Transaction Construction Tests...");
        BitcoinTxTest.runAllTests()
    };
    
    public func runTECDSASignerTests() : async () {
        Debug.print("Starting t-ECDSA Signer Tests...");
        await TECDSASignerTest.runTests()
    };
    
    public func runBitcoinNetworkTests() : async Bool {
        Debug.print("Starting Bitcoin Network Integration Tests...");
        await BitcoinNetworkTest.runTests()
    };
    
    public func runAllTests() : async Bool {
        Debug.print("=== BetterTrade Test Suite ===");
        
        let bitcoin_tx_tests = await runBitcoinTxTests();
        await runTECDSASignerTests();
        let bitcoin_network_tests = await runBitcoinNetworkTests();
        
        Debug.print("\n=== Overall Test Results ===");
        let all_passed = bitcoin_tx_tests and bitcoin_network_tests;
        
        if (all_passed) {
            Debug.print("✅ All Bitcoin Transaction tests passed!");
            Debug.print("✅ t-ECDSA Signer tests completed!");
            Debug.print("✅ All Bitcoin Network Integration tests passed!");
        } else {
            if (not bitcoin_tx_tests) {
                Debug.print("❌ Some Bitcoin Transaction tests failed!");
            } else {
                Debug.print("✅ All Bitcoin Transaction tests passed!");
            };
            Debug.print("✅ t-ECDSA Signer tests completed!");
            if (not bitcoin_network_tests) {
                Debug.print("❌ Some Bitcoin Network Integration tests failed!");
            } else {
                Debug.print("✅ All Bitcoin Network Integration tests passed!");
            };
        };
        
        all_passed
    };
}