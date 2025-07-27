import Debug "mo:base/Debug";
import Validation "./validation_test";

// Validation runner for Portfolio State UTXO functionality
actor ValidateRunner {
    public func validate() : async Bool {
        Debug.print("🔍 Validating Portfolio State UTXO Implementation");
        let result = Validation.runValidation();
        if (result) {
            Debug.print("✅ Task 3.1 validation PASSED");
        } else {
            Debug.print("❌ Task 3.1 validation FAILED");
        };
        result
    };
}