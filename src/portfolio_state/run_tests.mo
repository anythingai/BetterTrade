import Debug "mo:base/Debug";
import TestTransactionHistory "./test_transaction_history";
import TestPnLTracking "./test_pnl_tracking";

actor TestRunner {
    public func run_transaction_history_tests() : async Bool {
        Debug.print("Starting Portfolio State Transaction History Tests...");
        await TestTransactionHistory.run_all_tests()
    };
    
    public func run_pnl_tracking_tests() : async Bool {
        Debug.print("Starting Portfolio State PnL Tracking Tests...");
        await TestPnLTracking.run_all_pnl_tests()
    };
    
    public func run_all_tests() : async Bool {
        Debug.print("=== Running All Portfolio State Tests ===");
        
        let transaction_tests = await run_transaction_history_tests();
        let pnl_tests = await run_pnl_tracking_tests();
        
        if (transaction_tests and pnl_tests) {
            Debug.print("✓ All Portfolio State tests passed!");
            true
        } else {
            Debug.print("✗ Some Portfolio State tests failed");
            false
        }
    };
}