import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Array "mo:base/Array";

import Types "../shared/types";
import UserRegistry "./main";

module {
    // Integration test utilities
    private func assert_true(condition: Bool, message: Text) {
        if (not condition) {
            Debug.trap("Integration test failed: " # message);
        };
    };

    private func assert_false(condition: Bool, message: Text) {
        if (condition) {
            Debug.trap("Integration test failed: " # message);
        };
    };

    // Mock principals for testing
    private let alice_principal = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
    private let bob_principal = Principal.fromText("rrkah-fqaaa-aaaah-qcaiq-cai");
    private let charlie_principal = Principal.fromText("ryjl3-tyaaa-aaaah-qcaiq-cai");

    // Test complete user lifecycle
    public func test_complete_user_lifecycle() : async () {
        Debug.print("Testing complete user lifecycle...");
        
        // 1. Register multiple users
        let alice_result = await UserRegistry.register("Alice", ?("alice@example.com"));
        let alice_id = switch (alice_result) {
            case (#ok(id)) { id };
            case (#err(error)) {
                Debug.trap("Alice registration should succeed: " # debug_show(error));
            };
        };

        let bob_result = await UserRegistry.register("Bob", null);
        let bob_id = switch (bob_result) {
            case (#ok(id)) { id };
            case (#err(error)) {
                Debug.trap("Bob registration should succeed: " # debug_show(error));
            };
        };

        // 2. Verify initial user states
        let alice_summary = await UserRegistry.get_user(alice_id);
        switch (alice_summary) {
            case (#ok(summary)) {
                assert_true(summary.display_name == "Alice", "Alice display name should match");
                assert_true(summary.risk_profile == #conservative, "Default risk profile should be conservative");
                assert_true(summary.wallet_count == 0, "Initial wallet count should be 0");
            };
            case (#err(error)) {
                Debug.trap("Alice lookup should succeed: " # debug_show(error));
            };
        };

        // 3. Link wallets for both users
        let alice_wallet1 = await UserRegistry.link_wallet("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx", #testnet);
        let alice_wallet2 = await UserRegistry.link_wallet("bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kw5rljs90", #mainnet);
        let bob_wallet1 = await UserRegistry.link_wallet("tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3", #testnet);

        // Verify wallet linking succeeded
        switch (alice_wallet1, alice_wallet2, bob_wallet1) {
            case (#ok(_), #ok(_), #ok(_)) {
                // All good
            };
            case _ {
                Debug.trap("All wallet linking should succeed");
            };
        };

        // 4. Update risk profiles
        let _ = await UserRegistry.set_risk_profile(alice_id, #aggressive);
        let _ = await UserRegistry.set_risk_profile(bob_id, #balanced);

        // 5. Verify updated states
        let updated_alice = await UserRegistry.get_user(alice_id);
        switch (updated_alice) {
            case (#ok(summary)) {
                assert_true(summary.risk_profile == #aggressive, "Alice risk profile should be updated");
                assert_true(summary.wallet_count == 2, "Alice should have 2 wallets");
            };
            case (#err(error)) {
                Debug.trap("Updated Alice lookup should succeed: " # debug_show(error));
            };
        };

        let updated_bob = await UserRegistry.get_user(bob_id);
        switch (updated_bob) {
            case (#ok(summary)) {
                assert_true(summary.risk_profile == #balanced, "Bob risk profile should be updated");
                assert_true(summary.wallet_count == 1, "Bob should have 1 wallet");
            };
            case (#err(error)) {
                Debug.trap("Updated Bob lookup should succeed: " # debug_show(error));
            };
        };

        // 6. Test wallet management
        let alice_wallets = await UserRegistry.get_user_wallets(alice_id);
        switch (alice_wallets) {
            case (#ok(wallets)) {
                assert_true(wallets.size() == 2, "Alice should have 2 wallets");
                assert_true(wallets[0].status == #active, "Wallets should be active by default");
                assert_true(wallets[1].status == #active, "Wallets should be active by default");
            };
            case (#err(error)) {
                Debug.trap("Alice wallet retrieval should succeed: " # debug_show(error));
            };
        };

        Debug.print("✓ Complete user lifecycle test passed");
    };

    // Test wallet status management integration
    public func test_wallet_status_integration() : async () {
        Debug.print("Testing wallet status management integration...");
        
        // Register user and link wallet
        let _ = await UserRegistry.register("Charlie", null);
        let wallet_result = await UserRegistry.link_wallet("tb1q9vza2e8x573nczrlzms0wvx3gsqjx7vavgkx0l", #testnet);
        let wallet_id = switch (wallet_result) {
            case (#ok(id)) { id };
            case (#err(error)) {
                Debug.trap("Wallet linking should succeed: " # debug_show(error));
            };
        };

        // Test wallet status transitions
        let _ = await UserRegistry.update_wallet_status(wallet_id, #inactive);
        let inactive_wallet = await UserRegistry.get_wallet(wallet_id);
        switch (inactive_wallet) {
            case (#ok(wallet)) {
                assert_true(wallet.status == #inactive, "Wallet should be inactive");
            };
            case (#err(error)) {
                Debug.trap("Wallet lookup should succeed: " # debug_show(error));
            };
        };

        // Reactivate wallet
        let _ = await UserRegistry.update_wallet_status(wallet_id, #active);
        let active_wallet = await UserRegistry.get_wallet(wallet_id);
        switch (active_wallet) {
            case (#ok(wallet)) {
                assert_true(wallet.status == #active, "Wallet should be active again");
            };
            case (#err(error)) {
                Debug.trap("Wallet lookup should succeed: " # debug_show(error));
            };
        };

        Debug.print("✓ Wallet status management integration test passed");
    };

    // Test system-wide queries and statistics
    public func test_system_queries() : async () {
        Debug.print("Testing system-wide queries...");
        
        // Test system statistics
        let stats = await UserRegistry.get_system_stats();
        assert_true(stats.user_count >= 3, "Should have at least 3 users from previous tests");
        assert_true(stats.wallet_count >= 4, "Should have at least 4 wallets from previous tests");
        assert_true(stats.active_wallet_count <= stats.wallet_count, "Active wallets should not exceed total wallets");

        // Test get all users
        let all_users_result = await UserRegistry.get_all_users();
        switch (all_users_result) {
            case (#ok(users)) {
                assert_true(users.size() >= 3, "Should have at least 3 users");
                
                // Verify user summaries contain expected data
                let alice_found = Array.find<Types.UserSummary>(users, func(u) { u.display_name == "Alice" });
                switch (alice_found) {
                    case (?alice) {
                        assert_true(alice.risk_profile == #aggressive, "Alice should have aggressive risk profile");
                        assert_true(alice.wallet_count == 2, "Alice should have 2 wallets");
                    };
                    case null {
                        Debug.trap("Alice should be found in all users list");
                    };
                };
            };
            case (#err(error)) {
                Debug.trap("Get all users should succeed: " # debug_show(error));
            };
        };

        Debug.print("✓ System queries test passed");
    };

    // Test error handling and edge cases
    public func test_error_handling() : async () {
        Debug.print("Testing error handling and edge cases...");
        
        // Test lookup of non-existent user
        let fake_principal = Principal.fromText("aaaaa-aa");
        let nonexistent_user = await UserRegistry.get_user(fake_principal);
        switch (nonexistent_user) {
            case (#ok(_)) {
                Debug.trap("Non-existent user lookup should fail");
            };
            case (#err(#not_found)) {
                // Expected
            };
            case (#err(other)) {
                Debug.trap("Should get not_found error: " # debug_show(other));
            };
        };

        // Test wallet lookup for non-existent user
        let nonexistent_wallets = await UserRegistry.get_user_wallets(fake_principal);
        switch (nonexistent_wallets) {
            case (#ok(_)) {
                Debug.trap("Non-existent user wallet lookup should fail");
            };
            case (#err(#not_found)) {
                // Expected
            };
            case (#err(other)) {
                Debug.trap("Should get not_found error: " # debug_show(other));
            };
        };

        // Test wallet status update for non-existent wallet
        let fake_wallet_id = "fake:wallet:id";
        let nonexistent_wallet_update = await UserRegistry.update_wallet_status(fake_wallet_id, #inactive);
        switch (nonexistent_wallet_update) {
            case (#ok(_)) {
                Debug.trap("Non-existent wallet status update should fail");
            };
            case (#err(#not_found)) {
                // Expected
            };
            case (#err(other)) {
                Debug.trap("Should get not_found error: " # debug_show(other));
            };
        };

        // Test get non-existent wallet
        let nonexistent_wallet_get = await UserRegistry.get_wallet(fake_wallet_id);
        switch (nonexistent_wallet_get) {
            case (#ok(_)) {
                Debug.trap("Non-existent wallet get should fail");
            };
            case (#err(#not_found)) {
                // Expected
            };
            case (#err(other)) {
                Debug.trap("Should get not_found error: " # debug_show(other));
            };
        };

        Debug.print("✓ Error handling test passed");
    };

    // Test concurrent operations simulation
    public func test_concurrent_operations() : async () {
        Debug.print("Testing concurrent operations simulation...");
        
        // Register multiple users with similar operations
        let user1_result = await UserRegistry.register("User1", null);
        let user2_result = await UserRegistry.register("User2", null);
        let user3_result = await UserRegistry.register("User3", null);

        // Verify all registrations succeeded
        switch (user1_result, user2_result, user3_result) {
            case (#ok(id1), #ok(id2), #ok(id3)) {
                // Link wallets for all users
                let _ = await UserRegistry.link_wallet("tb1q1234567890abcdef1234567890abcdef123456", #testnet);
                let _ = await UserRegistry.link_wallet("tb1q2234567890abcdef1234567890abcdef123456", #testnet);
                let _ = await UserRegistry.link_wallet("tb1q3234567890abcdef1234567890abcdef123456", #testnet);

                // Update risk profiles
                let _ = await UserRegistry.set_risk_profile(id1, #conservative);
                let _ = await UserRegistry.set_risk_profile(id2, #balanced);
                let _ = await UserRegistry.set_risk_profile(id3, #aggressive);

                // Verify final states
                let final_stats = await UserRegistry.get_system_stats();
                assert_true(final_stats.user_count >= 6, "Should have at least 6 users total");
                assert_true(final_stats.wallet_count >= 7, "Should have at least 7 wallets total");
            };
            case _ {
                Debug.trap("All user registrations should succeed");
            };
        };

        Debug.print("✓ Concurrent operations simulation test passed");
    };

    // Run all integration tests
    public func run_all_integration_tests() : async () {
        Debug.print("Starting User Registry integration tests...");
        
        await test_complete_user_lifecycle();
        await test_wallet_status_integration();
        await test_system_queries();
        await test_error_handling();
        await test_concurrent_operations();
        
        Debug.print("✅ All User Registry integration tests passed!");
    };
}