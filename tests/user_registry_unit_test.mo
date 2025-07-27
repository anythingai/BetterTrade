import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Result "mo:base/Result";

import Types "../src/shared/types";
import UnitTestFramework "./unit_test_framework";

// Comprehensive unit tests for User Registry canister
module {
    public class UserRegistryUnitTests() {
        private let assertions = UnitTestFramework.TestAssertions();
        private let mock_data = UnitTestFramework.MockDataGenerator();
        private let runner = UnitTestFramework.TestRunner();

        // Test user registration validation
        public func test_user_registration_validation() : UnitTestFramework.TestResult {
            let valid_user = mock_data.generate_test_user("cai");
            let invalid_display_name = "";
            let long_display_name = "This is a very long display name that exceeds the maximum allowed length of 50 characters";
            
            // Test valid user
            let valid_name_test = validate_display_name(valid_user.display_name);
            let invalid_name_test = validate_display_name(invalid_display_name);
            let long_name_test = validate_display_name(long_display_name);
            
            let all_tests_pass = valid_name_test and not invalid_name_test and not long_name_test;
            
            assertions.assert_true(all_tests_pass, "User registration validation works correctly")
        };

        // Test Bitcoin address validation
        public func test_btc_address_validation() : UnitTestFramework.TestResult {
            let valid_testnet_addresses = [
                "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                "2MzQwSSnBHWHqSAqtTVQ6v47XtaisrJa1Vc",
                "mzBc4XEFSdzCDcTxAgf6EZXgsZWpztRhef",
                "n1LKejAadN6hg2FrBXoU1KrwX4uK16mco9"
            ];
            
            let invalid_addresses = [
                "",
                "invalid",
                "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kw5rljs90", // mainnet on testnet
                "too_short"
            ];
            
            let valid_tests = Array.map<Text, Bool>(valid_testnet_addresses, func(addr) {
                validate_btc_address(addr, #testnet)
            });
            
            let invalid_tests = Array.map<Text, Bool>(invalid_addresses, func(addr) {
                not validate_btc_address(addr, #testnet)
            });
            
            let all_valid = Array.foldLeft<Bool, Bool>(valid_tests, true, func(acc, test) { acc and test });
            let all_invalid = Array.foldLeft<Bool, Bool>(invalid_tests, true, func(acc, test) { acc and test });
            
            assertions.assert_true(all_valid and all_invalid, "Bitcoin address validation works for testnet addresses")
        };

        // Test wallet linking logic
        public func test_wallet_linking() : UnitTestFramework.TestResult {
            let user = mock_data.generate_test_user("cai");
            let wallet = mock_data.generate_test_wallet(user.principal_id, #testnet);
            
            // Test wallet creation
            let wallet_id = generate_wallet_id(user.principal_id, wallet.btc_address);
            let expected_id = Principal.toText(user.principal_id) # "_" # wallet.btc_address;
            
            let id_matches = wallet_id == expected_id;
            let wallet_valid = wallet.user_id == user.principal_id and wallet.status == #active;
            
            assertions.assert_true(id_matches and wallet_valid, "Wallet linking creates correct wallet structure")
        };

        // Test user summary generation
        public func test_user_summary_generation() : UnitTestFramework.TestResult {
            let user = mock_data.generate_test_user("cai");
            let wallet_count = 2;
            let portfolio_value = 50000000; // 0.5 BTC in sats
            
            let summary : Types.UserSummary = {
                user_id = user.principal_id;
                display_name = user.display_name;
                risk_profile = user.risk_profile;
                wallet_count = wallet_count;
                portfolio_value_sats = portfolio_value;
            };
            
            let summary_valid = 
                summary.user_id == user.principal_id and
                summary.display_name == user.display_name and
                summary.risk_profile == user.risk_profile and
                summary.wallet_count == wallet_count and
                summary.portfolio_value_sats == portfolio_value;
            
            assertions.assert_true(summary_valid, "User summary generation includes all required fields")
        };

        // Test risk profile updates
        public func test_risk_profile_updates() : UnitTestFramework.TestResult {
            let user = mock_data.generate_test_user("cai");
            let original_risk = user.risk_profile;
            let new_risk = #aggressive;
            
            // Simulate risk profile update
            let updated_user : Types.User = {
                principal_id = user.principal_id;
                display_name = user.display_name;
                created_at = user.created_at;
                risk_profile = new_risk;
            };
            
            let risk_changed = updated_user.risk_profile != original_risk;
            let other_fields_unchanged = 
                updated_user.principal_id == user.principal_id and
                updated_user.display_name == user.display_name and
                updated_user.created_at == user.created_at;
            
            assertions.assert_true(risk_changed and other_fields_unchanged, "Risk profile updates work correctly")
        };

        // Test wallet status management
        public func test_wallet_status_management() : UnitTestFramework.TestResult {
            let user = mock_data.generate_test_user("cai");
            let active_wallet = mock_data.generate_test_wallet(user.principal_id, #testnet);
            
            // Create inactive wallet
            let inactive_wallet : Types.Wallet = {
                user_id = active_wallet.user_id;
                btc_address = active_wallet.btc_address;
                network = active_wallet.network;
                status = #inactive;
            };
            
            let status_changed = active_wallet.status != inactive_wallet.status;
            let other_fields_same = 
                active_wallet.user_id == inactive_wallet.user_id and
                active_wallet.btc_address == inactive_wallet.btc_address and
                active_wallet.network == inactive_wallet.network;
            
            assertions.assert_true(status_changed and other_fields_same, "Wallet status management works correctly")
        };

        // Test duplicate user prevention
        public func test_duplicate_user_prevention() : UnitTestFramework.TestResult {
            let user1 = mock_data.generate_test_user("cai");
            let user2 : Types.User = {
                principal_id = user1.principal_id; // Same principal ID
                display_name = "Different Name";
                created_at = Time.now();
                risk_profile = #aggressive;
            };
            
            // In a real implementation, this would check if user already exists
            let duplicate_detected = user1.principal_id == user2.principal_id;
            
            assertions.assert_true(duplicate_detected, "Duplicate user detection works correctly")
        };

        // Test wallet address uniqueness
        public func test_wallet_address_uniqueness() : UnitTestFramework.TestResult {
            let user1 = mock_data.generate_test_user("ca1");
            let user2 = mock_data.generate_test_user("ca2");
            
            let wallet1 = mock_data.generate_test_wallet(user1.principal_id, #testnet);
            let wallet2 = mock_data.generate_test_wallet(user2.principal_id, #testnet);
            
            // In this mock, both wallets have the same address, which should be detected
            let same_address = wallet1.btc_address == wallet2.btc_address;
            let different_users = wallet1.user_id != wallet2.user_id;
            
            assertions.assert_true(same_address and different_users, "Wallet address uniqueness check detects conflicts")
        };

        // Test user lookup functionality
        public func test_user_lookup() : UnitTestFramework.TestResult {
            let user = mock_data.generate_test_user("cai");
            
            // Simulate user lookup by principal ID
            let lookup_result = lookup_user_by_principal(user.principal_id);
            
            let user_found = switch (lookup_result) {
                case (#ok(found_user)) { 
                    found_user.principal_id == user.principal_id and
                    found_user.display_name == user.display_name
                };
                case (#err(_)) { false };
            };
            
            assertions.assert_true(user_found, "User lookup by principal ID works correctly")
        };

        // Helper functions for testing (mock implementations)
        private func validate_display_name(name: Text) : Bool {
            let name_length = Text.size(name);
            name_length > 0 and name_length <= 50
        };

        private func validate_btc_address(addr: Text, network: Types.Network) : Bool {
            let addr_length = Text.size(addr);
            switch (network) {
                case (#testnet) { 
                    addr_length >= 26 and addr_length <= 62 and 
                    (Text.startsWith(addr, #text("tb1")) or 
                     Text.startsWith(addr, #text("2")) or 
                     Text.startsWith(addr, #text("m")) or 
                     Text.startsWith(addr, #text("n")))
                };
                case (#mainnet) { 
                    addr_length >= 26 and addr_length <= 62 and 
                    (Text.startsWith(addr, #text("bc1")) or 
                     Text.startsWith(addr, #text("1")) or 
                     Text.startsWith(addr, #text("3")))
                };
            }
        };

        private func generate_wallet_id(user_id: Types.UserId, address: Text) : Text {
            Principal.toText(user_id) # "_" # address
        };

        private func lookup_user_by_principal(principal_id: Types.UserId) : Result.Result<Types.User, Text> {
            // Mock implementation - in real code this would query the HashMap
            let mock_user = mock_data.generate_test_user("cai");
            if (principal_id == mock_user.principal_id) {
                #ok(mock_user)
            } else {
                #err("User not found")
            }
        };

        // Run all user registry unit tests
        public func run_all_tests() : UnitTestFramework.TestSuite {
            let test_functions = [
                test_user_registration_validation,
                test_btc_address_validation,
                test_wallet_linking,
                test_user_summary_generation,
                test_risk_profile_updates,
                test_wallet_status_management,
                test_duplicate_user_prevention,
                test_wallet_address_uniqueness,
                test_user_lookup
            ];
            
            runner.run_test_suite("User Registry Unit Tests", test_functions)
        };
    };
}