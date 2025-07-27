import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";

import Types "../shared/types";
import UserRegistry "./main";

module {
    // Test utilities
    private func assert_true(condition: Bool, message: Text) {
        if (not condition) {
            Debug.trap("Test failed: " # message);
        };
    };

    private func assert_false(condition: Bool, message: Text) {
        if (condition) {
            Debug.trap("Test failed: " # message);
        };
    };

    private func assert_equal<T>(expected: T, actual: T, message: Text, eq: (T, T) -> Bool) {
        if (not eq(expected, actual)) {
            Debug.trap("Test failed: " # message);
        };
    };

    // Mock principals for testing
    private let test_principal_1 = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
    private let test_principal_2 = Principal.fromText("rrkah-fqaaa-aaaah-qcaiq-cai");

    // Test user registration functionality
    public func test_user_registration() : async () {
        Debug.print("Testing user registration...");
        
        // Test valid registration
        let result1 = await UserRegistry.register("Alice", null);
        switch (result1) {
            case (#ok(user_id)) {
                assert_true(user_id == test_principal_1, "User ID should match caller principal");
            };
            case (#err(error)) {
                Debug.trap("Registration should succeed: " # debug_show(error));
            };
        };

        // Test duplicate registration
        let result2 = await UserRegistry.register("Alice Again", null);
        switch (result2) {
            case (#ok(_)) {
                Debug.trap("Duplicate registration should fail");
            };
            case (#err(#invalid_input(msg))) {
                assert_true(msg == "User already registered", "Should get correct error message");
            };
            case (#err(other)) {
                Debug.trap("Should get invalid_input error: " # debug_show(other));
            };
        };

        // Test invalid display name (empty)
        let result3 = await UserRegistry.register("", null);
        switch (result3) {
            case (#ok(_)) {
                Debug.trap("Empty display name should fail");
            };
            case (#err(#invalid_input(msg))) {
                assert_true(msg == "Display name must be between 1 and 50 characters", "Should get correct error message");
            };
            case (#err(other)) {
                Debug.trap("Should get invalid_input error: " # debug_show(other));
            };
        };

        // Test invalid display name (too long)
        let long_name = "This is a very long display name that exceeds the fifty character limit";
        let result4 = await UserRegistry.register(long_name, null);
        switch (result4) {
            case (#ok(_)) {
                Debug.trap("Long display name should fail");
            };
            case (#err(#invalid_input(_))) {
                // Expected
            };
            case (#err(other)) {
                Debug.trap("Should get invalid_input error: " # debug_show(other));
            };
        };

        Debug.print("✓ User registration tests passed");
    };

    // Test wallet linking functionality
    public func test_wallet_linking() : async () {
        Debug.print("Testing wallet linking...");
        
        // First register a user
        let _ = await UserRegistry.register("Bob", null);

        // Test valid testnet wallet linking
        let testnet_addr = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
        let result1 = await UserRegistry.link_wallet(testnet_addr, #testnet);
        switch (result1) {
            case (#ok(wallet_id)) {
                assert_true(wallet_id != "", "Wallet ID should not be empty");
            };
            case (#err(error)) {
                Debug.trap("Valid wallet linking should succeed: " # debug_show(error));
            };
        };

        // Test duplicate wallet linking
        let result2 = await UserRegistry.link_wallet(testnet_addr, #testnet);
        switch (result2) {
            case (#ok(_)) {
                Debug.trap("Duplicate wallet linking should fail");
            };
            case (#err(#invalid_input(msg))) {
                assert_true(msg == "Wallet already linked", "Should get correct error message");
            };
            case (#err(other)) {
                Debug.trap("Should get invalid_input error: " # debug_show(other));
            };
        };

        // Test invalid Bitcoin address
        let invalid_addr = "invalid_address";
        let result3 = await UserRegistry.link_wallet(invalid_addr, #testnet);
        switch (result3) {
            case (#ok(_)) {
                Debug.trap("Invalid address should fail");
            };
            case (#err(#invalid_input(msg))) {
                assert_true(msg == "Invalid Bitcoin address for specified network", "Should get correct error message");
            };
            case (#err(other)) {
                Debug.trap("Should get invalid_input error: " # debug_show(other));
            };
        };

        // Test mainnet address validation
        let mainnet_addr = "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kw5rljs90";
        let result4 = await UserRegistry.link_wallet(mainnet_addr, #mainnet);
        switch (result4) {
            case (#ok(wallet_id)) {
                assert_true(wallet_id != "", "Mainnet wallet ID should not be empty");
            };
            case (#err(error)) {
                Debug.trap("Valid mainnet wallet linking should succeed: " # debug_show(error));
            };
        };

        Debug.print("✓ Wallet linking tests passed");
    };

    // Test user lookup and management
    public func test_user_management() : async () {
        Debug.print("Testing user management...");
        
        // Register a user first
        let register_result = await UserRegistry.register("Charlie", ?("charlie@example.com"));
        let user_id = switch (register_result) {
            case (#ok(id)) { id };
            case (#err(error)) {
                Debug.trap("Registration should succeed: " # debug_show(error));
            };
        };

        // Test user lookup
        let lookup_result = await UserRegistry.get_user(user_id);
        switch (lookup_result) {
            case (#ok(summary)) {
                assert_true(summary.display_name == "Charlie", "Display name should match");
                assert_true(summary.risk_profile == #conservative, "Default risk profile should be conservative");
                assert_true(summary.wallet_count == 0, "Initial wallet count should be 0");
            };
            case (#err(error)) {
                Debug.trap("User lookup should succeed: " # debug_show(error));
            };
        };

        // Test risk profile update
        let risk_update_result = await UserRegistry.set_risk_profile(user_id, #aggressive);
        switch (risk_update_result) {
            case (#ok(success)) {
                assert_true(success, "Risk profile update should succeed");
            };
            case (#err(error)) {
                Debug.trap("Risk profile update should succeed: " # debug_show(error));
            };
        };

        // Verify risk profile was updated
        let updated_lookup = await UserRegistry.get_user(user_id);
        switch (updated_lookup) {
            case (#ok(summary)) {
                assert_true(summary.risk_profile == #aggressive, "Risk profile should be updated");
            };
            case (#err(error)) {
                Debug.trap("Updated user lookup should succeed: " # debug_show(error));
            };
        };

        // Test wallet retrieval (should be empty initially)
        let wallets_result = await UserRegistry.get_user_wallets(user_id);
        switch (wallets_result) {
            case (#ok(wallets)) {
                assert_true(wallets.size() == 0, "Initial wallet list should be empty");
            };
            case (#err(error)) {
                Debug.trap("Wallet retrieval should succeed: " # debug_show(error));
            };
        };

        // Link a wallet and test retrieval
        let wallet_addr = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3";
        let _ = await UserRegistry.link_wallet(wallet_addr, #testnet);
        
        let wallets_after_link = await UserRegistry.get_user_wallets(user_id);
        switch (wallets_after_link) {
            case (#ok(wallets)) {
                assert_true(wallets.size() == 1, "Should have one wallet after linking");
                assert_true(wallets[0].btc_address == wallet_addr, "Wallet address should match");
                assert_true(wallets[0].network == #testnet, "Network should match");
                assert_true(wallets[0].status == #active, "Wallet should be active");
            };
            case (#err(error)) {
                Debug.trap("Wallet retrieval after linking should succeed: " # debug_show(error));
            };
        };

        Debug.print("✓ User management tests passed");
    };

    // Test wallet status management
    public func test_wallet_status_management() : async () {
        Debug.print("Testing wallet status management...");
        
        // Register user and link wallet
        let _ = await UserRegistry.register("Dave", null);
        let wallet_addr = "tb1q9vza2e8x573nczrlzms0wvx3gsqjx7vavgkx0l";
        let wallet_result = await UserRegistry.link_wallet(wallet_addr, #testnet);
        let wallet_id = switch (wallet_result) {
            case (#ok(id)) { id };
            case (#err(error)) {
                Debug.trap("Wallet linking should succeed: " # debug_show(error));
            };
        };

        // Test wallet status update
        let status_update_result = await UserRegistry.update_wallet_status(wallet_id, #inactive);
        switch (status_update_result) {
            case (#ok(success)) {
                assert_true(success, "Wallet status update should succeed");
            };
            case (#err(error)) {
                Debug.trap("Wallet status update should succeed: " # debug_show(error));
            };
        };

        // Verify status was updated
        let wallet_lookup = await UserRegistry.get_wallet(wallet_id);
        switch (wallet_lookup) {
            case (#ok(wallet)) {
                assert_true(wallet.status == #inactive, "Wallet status should be updated");
            };
            case (#err(error)) {
                Debug.trap("Wallet lookup should succeed: " # debug_show(error));
            };
        };

        Debug.print("✓ Wallet status management tests passed");
    };

    // Test system stats and admin functions
    public func test_system_functions() : async () {
        Debug.print("Testing system functions...");
        
        // Test system stats
        let stats = await UserRegistry.get_system_stats();
        assert_true(stats.user_count > 0, "Should have registered users");
        assert_true(stats.wallet_count > 0, "Should have linked wallets");

        // Test get all users
        let all_users_result = await UserRegistry.get_all_users();
        switch (all_users_result) {
            case (#ok(users)) {
                assert_true(users.size() > 0, "Should have users in the system");
            };
            case (#err(error)) {
                Debug.trap("Get all users should succeed: " # debug_show(error));
            };
        };

        Debug.print("✓ System functions tests passed");
    };

    // Run all tests
    public func run_all_tests() : async () {
        Debug.print("Starting User Registry tests...");
        
        await test_user_registration();
        await test_wallet_linking();
        await test_user_management();
        await test_wallet_status_management();
        await test_system_functions();
        
        Debug.print("✅ All User Registry tests passed!");
    };
}