import Debug "mo:base/Debug";
import Test "./test";

// Simple test runner for Portfolio State UTXO functionality
actor TestRunner {
    public func run() : async () {
        Debug.print("🚀 Starting Portfolio State UTXO Tests");
        await Test.runTests();
        Debug.print("✅ Portfolio State UTXO Tests Complete");
    };
}