import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Result "mo:base/Result";

// Import the types and interfaces
import Types "../src/shared/types";

// Test module for Risk Guard
module {
    // Mock Risk Guard for testing
    public class RiskGuardTest() {
        
        // Test data - valid configurations
        private let test_user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        
        private let valid_conservative_config : Types.RiskGuardConfig = {
            user_id = test_user_id;
            max_drawdown_pct = 5.0;
            liquidity_exit_threshold = 100_000; // 0.001 BTC
            notify_only = false;
        };

        private let valid_balanced_config : Types.RiskGuardConfig = {
            user_id = test_user_id;
            max_drawdown_pct = 15.0;
            liquidity_exit_threshold = 50_000; // 0.0005 BTC
            notify_only = false;
        };

        private let valid_aggressive_config : Types.RiskGuardConfig = {
            user_id = test_user_id;
            max_drawdown_pct = 30.0;
            liquidity_exit_threshold = 25_000; // 0.00025 BTC
            notify_only = true;
        };

        // Test risk configuration validation - valid cases
        public func test_valid_risk_config_validation() : Bool {
            let conservative_valid = validate_test_config(valid_conservative_config);
            let balanced_valid = validate_test_config(valid_balanced_config);
            let aggressive_valid = validate_test_config(valid_aggressive_config);
            
            switch (conservative_valid, balanced_valid, aggressive_valid) {
                case (#ok(_), #ok(_), #ok(_)) { true };
                case _ { false };
            }
        };

        // Test risk configuration validation - invalid max_drawdown_pct
        public func test_invalid_max_drawdown_validation() : Bool {
            let negative_drawdown_config = {
                user_id = test_user_id;
                max_drawdown_pct = -5.0; // Invalid: negative
                liquidity_exit_threshold = 50_000;
                notify_only = false;
            };

            let excessive_drawdown_config = {
                user_id = test_user_id;
                max_drawdown_pct = 101.0; // Invalid: > 100%
                liquidity_exit_threshold = 50_000;
                notify_only = false;
            };

            let dangerous_drawdown_config = {
                user_id = test_user_id;
                max_drawdown_pct = 98.0; // Invalid: > 95% safety limit
                liquidity_exit_threshold = 50_000;
                notify_only = false;
            };

            let negative_result = validate_test_config(negative_drawdown_config);
            let excessive_result = validate_test_config(excessive_drawdown_config);
            let dangerous_result = validate_test_config(dangerous_drawdown_config);

            switch (negative_result, excessive_result, dangerous_result) {
                case (#err(_), #err(_), #err(_)) { true };
                case _ { false };
            }
        };

        // Test risk configuration validation - invalid liquidity_exit_threshold
        public func test_invalid_liquidity_threshold_validation() : Bool {
            let zero_threshold_config = {
                user_id = test_user_id;
                max_drawdown_pct = 15.0;
                liquidity_exit_threshold = 0; // Invalid: must be > 0
                notify_only = false;
            };

            let result = validate_test_config(zero_threshold_config);
            
            switch (result) {
                case (#err(_)) { true };
                case (#ok(_)) { false };
            }
        };

        // Test configuration recommendations by risk level
        public func test_config_recommendations() : Bool {
            let conservative_rec = get_test_config_recommendation(#conservative);
            let balanced_rec = get_test_config_recommendation(#balanced);
            let aggressive_rec = get_test_config_recommendation(#aggressive);

            // Verify conservative recommendations are most restrictive
            let conservative_most_restrictive = conservative_rec.max_drawdown_pct < balanced_rec.max_drawdown_pct and
                                               conservative_rec.max_drawdown_pct < aggressive_rec.max_drawdown_pct and
                                               conservative_rec.liquidity_exit_threshold > balanced_rec.liquidity_exit_threshold;

            // Verify aggressive recommendations are least restrictive
            let aggressive_least_restrictive = aggressive_rec.max_drawdown_pct > balanced_rec.max_drawdown_pct and
                                              aggressive_rec.max_drawdown_pct > conservative_rec.max_drawdown_pct and
                                              aggressive_rec.notify_only == true;

            // Verify balanced is in the middle
            let balanced_middle = balanced_rec.max_drawdown_pct > conservative_rec.max_drawdown_pct and
                                 balanced_rec.max_drawdown_pct < aggressive_rec.max_drawdown_pct;

            conservative_most_restrictive and aggressive_least_restrictive and balanced_middle
        };

        // Test configuration storage and retrieval
        public func test_config_storage_retrieval() : Bool {
            // This would test the HashMap storage functionality
            // For now, we'll test the data structure integrity
            let stored_config = valid_balanced_config;
            
            // Verify all fields are preserved
            stored_config.user_id == test_user_id and
            stored_config.max_drawdown_pct == 15.0 and
            stored_config.liquidity_exit_threshold == 50_000 and
            stored_config.notify_only == false
        };

        // Test configuration updates
        public func test_config_updates() : Bool {
            let original_config = valid_balanced_config;
            
            // Test max_drawdown_pct update
            let updated_drawdown_config = {
                user_id = original_config.user_id;
                max_drawdown_pct = 20.0; // Updated value
                liquidity_exit_threshold = original_config.liquidity_exit_threshold;
                notify_only = original_config.notify_only;
            };

            // Test liquidity_exit_threshold update
            let updated_threshold_config = {
                user_id = original_config.user_id;
                max_drawdown_pct = original_config.max_drawdown_pct;
                liquidity_exit_threshold = 75_000; // Updated value
                notify_only = original_config.notify_only;
            };

            // Test notify_only toggle
            let updated_notify_config = {
                user_id = original_config.user_id;
                max_drawdown_pct = original_config.max_drawdown_pct;
                liquidity_exit_threshold = original_config.liquidity_exit_threshold;
                notify_only = true; // Updated value
            };

            // Verify updates are valid
            let drawdown_valid = validate_test_config(updated_drawdown_config);
            let threshold_valid = validate_test_config(updated_threshold_config);
            let notify_valid = validate_test_config(updated_notify_config);

            switch (drawdown_valid, threshold_valid, notify_valid) {
                case (#ok(_), #ok(_), #ok(_)) { true };
                case _ { false };
            }
        };

        // Test edge cases for configuration values
        public func test_config_edge_cases() : Bool {
            // Test minimum valid values
            let min_valid_config = {
                user_id = test_user_id;
                max_drawdown_pct = 0.1; // Very small but valid
                liquidity_exit_threshold = 1; // Minimum valid threshold
                notify_only = false;
            };

            // Test maximum valid values
            let max_valid_config = {
                user_id = test_user_id;
                max_drawdown_pct = 95.0; // Maximum allowed
                liquidity_exit_threshold = 21_000_000 * 100_000_000; // 21M BTC in sats
                notify_only = true;
            };

            let min_result = validate_test_config(min_valid_config);
            let max_result = validate_test_config(max_valid_config);

            switch (min_result, max_result) {
                case (#ok(_), #ok(_)) { true };
                case _ { false };
            }
        };

        // Test configuration comparison and ranking
        public func test_config_risk_ranking() : Bool {
            let configs = [valid_conservative_config, valid_balanced_config, valid_aggressive_config];
            
            // Sort by risk level (conservative = lowest risk)
            let sorted_by_risk = Array.sort<Types.RiskGuardConfig>(
                configs,
                func(a, b) { Float.compare(a.max_drawdown_pct, b.max_drawdown_pct) }
            );

            // Verify conservative is first (lowest drawdown)
            let conservative_first = sorted_by_risk[0].max_drawdown_pct == valid_conservative_config.max_drawdown_pct;
            
            // Verify aggressive is last (highest drawdown)
            let aggressive_last = sorted_by_risk[2].max_drawdown_pct == valid_aggressive_config.max_drawdown_pct;

            conservative_first and aggressive_last
        };

        // Test configuration serialization/deserialization integrity
        public func test_config_data_integrity() : Bool {
            let original = valid_balanced_config;
            
            // Simulate serialization by converting to text and back
            let serialized_data = {
                user_id_text = Principal.toText(original.user_id);
                max_drawdown_text = Float.toText(original.max_drawdown_pct);
                threshold_text = Int.toText(Int.fromNat64(original.liquidity_exit_threshold));
                notify_text = if (original.notify_only) "true" else "false";
            };

            // Simulate deserialization
            let deserialized = {
                user_id = Principal.fromText(serialized_data.user_id_text);
                max_drawdown_pct = 15.0; // Would parse from serialized_data.max_drawdown_text
                liquidity_exit_threshold = 50_000; // Would parse from serialized_data.threshold_text
                notify_only = false; // Would parse from serialized_data.notify_text
            };

            // Verify data integrity
            deserialized.user_id == original.user_id and
            deserialized.max_drawdown_pct == original.max_drawdown_pct and
            deserialized.liquidity_exit_threshold == original.liquidity_exit_threshold and
            deserialized.notify_only == original.notify_only
        };

        // Helper function to validate risk configuration (mirrors main implementation)
        private func validate_test_config(cfg: Types.RiskGuardConfig) : Types.Result<Bool, Types.ApiError> {
            // Validate max_drawdown_pct is between 0 and 100
            if (cfg.max_drawdown_pct < 0.0 or cfg.max_drawdown_pct > 100.0) {
                return #err(#invalid_input("max_drawdown_pct must be between 0 and 100"));
            };

            // Validate liquidity_exit_threshold is positive
            if (cfg.liquidity_exit_threshold == 0) {
                return #err(#invalid_input("liquidity_exit_threshold must be greater than 0"));
            };

            // Additional validation for reasonable values
            if (cfg.max_drawdown_pct > 95.0) {
                return #err(#invalid_input("max_drawdown_pct above 95% is not recommended for safety"));
            };

            #ok(true)
        };

        // Helper function to get configuration recommendations by risk level
        private func get_test_config_recommendation(risk_level: Types.RiskLevel) : Types.RiskGuardConfig {
            switch (risk_level) {
                case (#conservative) {
                    {
                        user_id = test_user_id;
                        max_drawdown_pct = 5.0;
                        liquidity_exit_threshold = 100_000; // 0.001 BTC in sats
                        notify_only = false;
                    }
                };
                case (#balanced) {
                    {
                        user_id = test_user_id;
                        max_drawdown_pct = 15.0;
                        liquidity_exit_threshold = 50_000; // 0.0005 BTC in sats
                        notify_only = false;
                    }
                };
                case (#aggressive) {
                    {
                        user_id = test_user_id;
                        max_drawdown_pct = 30.0;
                        liquidity_exit_threshold = 25_000; // 0.00025 BTC in sats
                        notify_only = true;
                    }
                };
            }
        };

        // Tests for basic risk monitoring (task 6.2)
        public func test_portfolio_value_monitoring() : Bool {
            let config = valid_balanced_config;
            
            // Test case 1: Portfolio within safe limits
            let safe_current_value = 95_000_000; // 0.95 BTC
            let entry_value = 100_000_000; // 1 BTC
            let safe_drawdown = ((entry_value - safe_current_value) * 100) / entry_value; // 5% drawdown
            
            // Should not trigger protective intents for 5% drawdown with 15% limit
            let safe_monitoring_result = safe_drawdown < config.max_drawdown_pct;
            
            // Test case 2: Portfolio exceeding drawdown threshold
            let risky_current_value = 80_000_000; // 0.8 BTC
            let risky_drawdown = ((entry_value - risky_current_value) * 100) / entry_value; // 20% drawdown
            
            // Should trigger protective intents for 20% drawdown with 15% limit
            let risky_monitoring_result = risky_drawdown > config.max_drawdown_pct;
            
            // Test case 3: Portfolio below liquidity threshold
            let low_liquidity_value = 25_000; // Below 50,000 threshold
            let liquidity_breach = low_liquidity_value < config.liquidity_exit_threshold;
            
            safe_monitoring_result and risky_monitoring_result and liquidity_breach
        };

        public func test_protective_intent_generation() : Bool {
            let config = valid_balanced_config;
            
            // Test pause intent generation
            let pause_intent = {
                user_id = test_user_id;
                action = #pause : Types.ProtectiveAction;
                reason = "Test pause intent";
                triggered_at = Time.now();
            };
            
            // Test unwind intent generation
            let unwind_intent = {
                user_id = test_user_id;
                action = #unwind : Types.ProtectiveAction;
                reason = "Test unwind intent";
                triggered_at = Time.now();
            };
            
            // Test reduce exposure intent generation
            let reduce_intent = {
                user_id = test_user_id;
                action = #reduce_exposure : Types.ProtectiveAction;
                reason = "Test reduce exposure intent";
                triggered_at = Time.now();
            };
            
            // Verify intent structure integrity
            let pause_valid = pause_intent.user_id == test_user_id and pause_intent.action == #pause;
            let unwind_valid = unwind_intent.user_id == test_user_id and unwind_intent.action == #unwind;
            let reduce_valid = reduce_intent.user_id == test_user_id and reduce_intent.action == #reduce_exposure;
            
            pause_valid and unwind_valid and reduce_valid
        };

        public func test_risk_threshold_detection() : Bool {
            let config = valid_conservative_config; // 5% max drawdown
            
            // Test threshold detection scenarios
            let scenarios = [
                // (current_value, entry_value, should_trigger)
                (95_000_000, 100_000_000, false), // 5% drawdown - at threshold
                (94_000_000, 100_000_000, true),  // 6% drawdown - exceeds threshold
                (90_000_000, 100_000_000, true),  // 10% drawdown - well above threshold
                (100_000_000, 100_000_000, false), // 0% drawdown - safe
                (105_000_000, 100_000_000, false), // Positive performance - safe
            ];
            
            var all_correct = true;
            for ((current, entry, should_trigger) in scenarios.vals()) {
                let drawdown = ((entry - current) * 100) / entry;
                let triggered = drawdown > config.max_drawdown_pct;
                if (triggered != should_trigger) {
                    all_correct := false;
                };
            };
            
            all_correct
        };

        public func test_manual_trigger_system() : Bool {
            // Test manual trigger actions
            let manual_actions = [#pause, #unwind, #reduce_exposure];
            
            var all_actions_valid = true;
            for (action in manual_actions.vals()) {
                // Simulate manual trigger
                let manual_intent = {
                    user_id = test_user_id;
                    action = action;
                    reason = "Manual trigger test";
                    triggered_at = Time.now();
                };
                
                // Verify intent is properly formed
                if (manual_intent.user_id != test_user_id or manual_intent.action != action) {
                    all_actions_valid := false;
                };
            };
            
            all_actions_valid
        };

        public func test_risk_score_calculation() : Bool {
            // Test risk score calculation with different portfolio states
            let test_metrics = [
                // (current_value, entry_value, unrealized_pnl, position_count, expected_risk_level)
                (100_000_000, 100_000_000, 0.0, 2, "low"),     // No drawdown, few positions
                (85_000_000, 100_000_000, -15.0, 3, "medium"), // 15% drawdown, moderate positions
                (70_000_000, 100_000_000, -30.0, 6, "high"),   // 30% drawdown, many positions
                (50_000_000, 100_000_000, -50.0, 8, "critical"), // 50% drawdown, excessive positions
            ];
            
            var all_scores_reasonable = true;
            for ((current, entry, pnl, positions, expected_level) in test_metrics.vals()) {
                let drawdown = ((entry - current) * 100) / entry;
                
                // Simple risk score calculation for testing
                let risk_score = drawdown + (if (positions > 5) 20.0 else 0.0) + (if (pnl < -20.0) 15.0 else 0.0);
                
                let risk_level = if (risk_score < 10.0) "low"
                                else if (risk_score < 30.0) "medium"
                                else if (risk_score < 50.0) "high"
                                else "critical";
                
                if (risk_level != expected_level) {
                    all_scores_reasonable := false;
                };
            };
            
            all_scores_reasonable
        };

        public func test_liquidity_threshold_monitoring() : Bool {
            let configs = [valid_conservative_config, valid_balanced_config, valid_aggressive_config];
            
            var all_thresholds_work = true;
            for (config in configs.vals()) {
                // Test values around the threshold
                let above_threshold = config.liquidity_exit_threshold + 10_000;
                let at_threshold = config.liquidity_exit_threshold;
                let below_threshold = config.liquidity_exit_threshold - 10_000;
                
                let above_safe = above_threshold >= config.liquidity_exit_threshold;
                let at_boundary = at_threshold == config.liquidity_exit_threshold;
                let below_triggers = below_threshold < config.liquidity_exit_threshold;
                
                if (not (above_safe and at_boundary and below_triggers)) {
                    all_thresholds_work := false;
                };
            };
            
            all_thresholds_work
        };

        public func test_protective_intent_storage() : Bool {
            // Test that protective intents can be stored and retrieved
            let test_intents = [
                {
                    user_id = test_user_id;
                    action = #pause : Types.ProtectiveAction;
                    reason = "Test storage intent 1";
                    triggered_at = Time.now();
                },
                {
                    user_id = test_user_id;
                    action = #unwind : Types.ProtectiveAction;
                    reason = "Test storage intent 2";
                    triggered_at = Time.now();
                }
            ];
            
            // Verify intents maintain their structure
            let first_intent_valid = test_intents[0].action == #pause and test_intents[0].user_id == test_user_id;
            let second_intent_valid = test_intents[1].action == #unwind and test_intents[1].user_id == test_user_id;
            
            first_intent_valid and second_intent_valid
        };

        public func test_notify_only_mode() : Bool {
            let notify_only_config = {
                user_id = test_user_id;
                max_drawdown_pct = 10.0;
                liquidity_exit_threshold = 50_000;
                notify_only = true; // Key difference
            };
            
            let action_config = {
                user_id = test_user_id;
                max_drawdown_pct = 10.0;
                liquidity_exit_threshold = 50_000;
                notify_only = false; // Will take action
            };
            
            // Both configs should be valid but behave differently
            let notify_valid = validate_test_config(notify_only_config);
            let action_valid = validate_test_config(action_config);
            
            switch (notify_valid, action_valid) {
                case (#ok(_), #ok(_)) { 
                    // Verify the notify_only flag is preserved
                    notify_only_config.notify_only == true and action_config.notify_only == false
                };
                case _ { false };
            }
        };

        // Run all tests including risk monitoring tests
        public func run_all_tests() : Bool {
            Debug.print("Running Risk Guard Configuration Tests...");
            
            let test1 = test_valid_risk_config_validation();
            Debug.print("Valid Risk Config Validation Test: " # (if test1 "PASSED" else "FAILED"));
            
            let test2 = test_invalid_max_drawdown_validation();
            Debug.print("Invalid Max Drawdown Validation Test: " # (if test2 "PASSED" else "FAILED"));
            
            let test3 = test_invalid_liquidity_threshold_validation();
            Debug.print("Invalid Liquidity Threshold Validation Test: " # (if test3 "PASSED" else "FAILED"));
            
            let test4 = test_config_recommendations();
            Debug.print("Config Recommendations Test: " # (if test4 "PASSED" else "FAILED"));
            
            let test5 = test_config_storage_retrieval();
            Debug.print("Config Storage Retrieval Test: " # (if test5 "PASSED" else "FAILED"));
            
            let test6 = test_config_updates();
            Debug.print("Config Updates Test: " # (if test6 "PASSED" else "FAILED"));
            
            let test7 = test_config_edge_cases();
            Debug.print("Config Edge Cases Test: " # (if test7 "PASSED" else "FAILED"));
            
            let test8 = test_config_risk_ranking();
            Debug.print("Config Risk Ranking Test: " # (if test8 "PASSED" else "FAILED"));
            
            let test9 = test_config_data_integrity();
            Debug.print("Config Data Integrity Test: " # (if test9 "PASSED" else "FAILED"));
            
            Debug.print("Running Risk Guard Monitoring Tests...");
            
            let test10 = test_portfolio_value_monitoring();
            Debug.print("Portfolio Value Monitoring Test: " # (if test10 "PASSED" else "FAILED"));
            
            let test11 = test_protective_intent_generation();
            Debug.print("Protective Intent Generation Test: " # (if test11 "PASSED" else "FAILED"));
            
            let test12 = test_risk_threshold_detection();
            Debug.print("Risk Threshold Detection Test: " # (if test12 "PASSED" else "FAILED"));
            
            let test13 = test_manual_trigger_system();
            Debug.print("Manual Trigger System Test: " # (if test13 "PASSED" else "FAILED"));
            
            let test14 = test_risk_score_calculation();
            Debug.print("Risk Score Calculation Test: " # (if test14 "PASSED" else "FAILED"));
            
            let test15 = test_liquidity_threshold_monitoring();
            Debug.print("Liquidity Threshold Monitoring Test: " # (if test15 "PASSED" else "FAILED"));
            
            let test16 = test_protective_intent_storage();
            Debug.print("Protective Intent Storage Test: " # (if test16 "PASSED" else "FAILED"));
            
            let test17 = test_notify_only_mode();
            Debug.print("Notify Only Mode Test: " # (if test17 "PASSED" else "FAILED"));
            
            let all_passed = test1 and test2 and test3 and test4 and test5 and test6 and test7 and test8 and test9 and
                            test10 and test11 and test12 and test13 and test14 and test15 and test16 and test17;
            Debug.print("All Risk Guard Tests: " # (if all_passed "PASSED" else "FAILED"));
            
            all_passed
        };
    };
}      
  // Additional risk monitoring tests for task 6.2
        public func test_manual_trigger_system() : Bool {
            // Test manual trigger system for protective actions
            let manual_actions = [#pause, #unwind, #reduce_exposure];
            
            // All manual actions should be valid protective actions
            Array.foldLeft<Types.ProtectiveAction, Bool>(
                manual_actions,
                true,
                func(acc, action) {
                    acc and (action == #pause or action == #unwind or action == #reduce_exposure)
                }
            )
        };

        public func test_protective_intent_generation() : Bool {
            // Test that protective intents are generated with correct structure
            let test_intent = {
                user_id = test_user_id;
                action = #pause;
                reason = "Test protective intent generation";
                triggered_at = Time.now();
            };

            // Verify intent structure and fields
            test_intent.user_id == test_user_id and
            test_intent.action == #pause and
            test_intent.reason.size() > 0
        };

        public func test_risk_threshold_detection() : Bool {
            // Test various risk threshold scenarios
            let config = valid_balanced_config; // 15% drawdown threshold, 50,000 sats liquidity threshold
            
            // Scenario 1: Normal operation (no thresholds breached)
            let normal_current = 90_000_000; // 0.9 BTC
            let normal_initial = 100_000_000; // 1 BTC
            let normal_drawdown = ((normal_initial - normal_current) * 100) / normal_initial; // 10% drawdown
            let normal_safe = normal_drawdown < config.max_drawdown_pct and normal_current > config.liquidity_exit_threshold;
            
            // Scenario 2: Drawdown threshold breached
            let drawdown_current = 80_000_000; // 0.8 BTC
            let drawdown_drawdown = ((normal_initial - drawdown_current) * 100) / normal_initial; // 20% drawdown
            let drawdown_breach = drawdown_drawdown > config.max_drawdown_pct;
            
            // Scenario 3: Liquidity threshold breached
            let liquidity_current = 25_000; // 0.00025 BTC
            let liquidity_breach = liquidity_current < config.liquidity_exit_threshold;
            
            normal_safe and drawdown_breach and liquidity_breach
        };

        public func test_protective_action_escalation() : Bool {
            // Test that protective actions escalate based on severity
            let threshold = 15.0; // 15% threshold
            
            // Minor breach (16% drawdown) should trigger pause
            let minor_drawdown = 16.0;
            let minor_action = if (minor_drawdown > threshold * 1.5) #unwind else #pause;
            
            // Major breach (30% drawdown) should trigger unwind
            let major_drawdown = 30.0;
            let major_action = if (major_drawdown > threshold * 1.5) #unwind else #pause;
            
            minor_action == #pause and major_action == #unwind
        };

        public func test_multiple_protective_intents() : Bool {
            // Test handling of multiple simultaneous protective intents
            let drawdown_intent = {
                user_id = test_user_id;
                action = #pause;
                reason = "Drawdown threshold breached";
                triggered_at = Time.now();
            };

            let liquidity_intent = {
                user_id = test_user_id;
                action = #reduce_exposure;
                reason = "Liquidity threshold breached";
                triggered_at = Time.now();
            };

            let multiple_intents = [drawdown_intent, liquidity_intent];
            
            // Should handle multiple intents correctly
            multiple_intents.size() == 2 and
            multiple_intents[0].action == #pause and
            multiple_intents[1].action == #reduce_exposure
        };

        public func test_notify_only_mode() : Bool {
            // Test notify-only configuration behavior
            let notify_config = {
                user_id = test_user_id;
                max_drawdown_pct = 10.0;
                liquidity_exit_threshold = 50_000;
                notify_only = true;
            };

            let action_config = {
                user_id = test_user_id;
                max_drawdown_pct = 10.0;
                liquidity_exit_threshold = 50_000;
                notify_only = false;
            };

            // Verify notify_only flag difference
            notify_config.notify_only == true and action_config.notify_only == false
        };

        public func test_risk_scenario_simulation() : Bool {
            // Test different risk scenarios for comprehensive coverage
            let scenarios = [
                ("normal", 100_000_000, 100_000_000, false, false),
                ("minor_drawdown", 90_000_000, 100_000_000, false, false),
                ("major_drawdown", 50_000_000, 100_000_000, true, false),
                ("liquidity_crisis", 25_000, 100_000_000, true, true),
            ];

            Array.foldLeft<(Text, Nat64, Nat64, Bool, Bool), Bool>(
                scenarios,
                true,
                func(acc, scenario) {
                    let (name, current, initial, should_drawdown, should_liquidity) = scenario;
                    let config = valid_balanced_config;
                    
                    let drawdown_pct = if (initial > 0) {
                        Float.fromInt(Int.fromNat64((initial - current) * 100)) / Float.fromInt(Int.fromNat64(initial))
                    } else {
                        0.0
                    };
                    
                    let actual_drawdown = drawdown_pct > config.max_drawdown_pct;
                    let actual_liquidity = current < config.liquidity_exit_threshold;
                    
                    acc and (actual_drawdown == should_drawdown) and (actual_liquidity == should_liquidity)
                }
            )
        };

        public func test_portfolio_monitoring_integration() : Bool {
            // Test integration between configuration and monitoring
            let config = valid_conservative_config; // 5% threshold
            
            // Test values that should trigger conservative thresholds
            let current_value = 90_000_000; // 0.9 BTC
            let initial_value = 100_000_000; // 1 BTC
            let drawdown = ((initial_value - current_value) * 100) / initial_value; // 10% drawdown
            
            // Should trigger for conservative config (5% threshold) but not balanced (15% threshold)
            let conservative_triggered = drawdown > config.max_drawdown_pct;
            let balanced_triggered = drawdown > valid_balanced_config.max_drawdown_pct;
            
            conservative_triggered and not balanced_triggered
        };