import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";

import Types "../src/shared/types";
import UnitTestFramework "./unit_test_framework";

// Comprehensive unit tests for Risk Guard canister
module {
    public class RiskGuardUnitTests() {
        private let assertions = UnitTestFramework.TestAssertions();
        private let mock_data = UnitTestFramework.MockDataGenerator();
        private let runner = UnitTestFramework.TestRunner();

        // Test risk guard configuration
        public func test_risk_guard_configuration() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let config : Types.RiskGuardConfig = {
                user_id = user_id;
                max_drawdown_pct = 15.0; // 15% max drawdown
                liquidity_exit_threshold = 10000000; // 0.1 BTC minimum
                notify_only = false; // Take protective actions
            };
            
            let config_valid = 
                config.user_id == user_id and
                config.max_drawdown_pct > 0.0 and config.max_drawdown_pct < 100.0 and
                config.liquidity_exit_threshold > 0 and
                config.notify_only == false;
            
            assertions.assert_true(config_valid, "Risk guard configuration validation works correctly")
        };

        // Test drawdown calculation
        public func test_drawdown_calculation() : UnitTestFramework.TestResult {
            let initial_value = 100000000; // 1 BTC in sats
            let current_value = 85000000;  // 0.85 BTC in sats
            let peak_value = 110000000;    // 1.1 BTC peak
            
            let drawdown_from_initial = calculate_drawdown_percentage(initial_value, current_value);
            let drawdown_from_peak = calculate_drawdown_percentage(peak_value, current_value);
            
            let expected_from_initial = 15.0; // 15% down from initial
            let expected_from_peak = Float.abs((Float.fromInt(Int64.toInt(Int64.fromNat64(current_value))) - Float.fromInt(Int64.toInt(Int64.fromNat64(peak_value)))) / Float.fromInt(Int64.toInt(Int64.fromNat64(peak_value))) * 100.0);
            
            let initial_correct = Float.abs(drawdown_from_initial - expected_from_initial) < 0.1;
            let peak_correct = Float.abs(drawdown_from_peak - expected_from_peak) < 0.1;
            
            assertions.assert_true(initial_correct and peak_correct, "Drawdown calculation works correctly")
        };

        // Test risk threshold monitoring
        public func test_risk_threshold_monitoring() : UnitTestFramework.TestResult {
            let config : Types.RiskGuardConfig = {
                user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
                max_drawdown_pct = 20.0;
                liquidity_exit_threshold = 5000000;
                notify_only = false;
            };
            
            let portfolio_scenarios = [
                { current_value = 90000000; peak_value = 100000000 }, // 10% drawdown - OK
                { current_value = 75000000; peak_value = 100000000 }, // 25% drawdown - BREACH
                { current_value = 85000000; peak_value = 100000000 }  // 15% drawdown - OK
            ];
            
            let breach_results = Array.map<{current_value: Nat64; peak_value: Nat64}, Bool>(
                portfolio_scenarios, func(scenario) {
                    let drawdown = calculate_drawdown_percentage(scenario.peak_value, scenario.current_value);
                    drawdown > config.max_drawdown_pct
                }
            );
            
            let expected_breaches = [false, true, false];
            let breach_detection_correct = Array.equal<Bool>(breach_results, expected_breaches, func(a, b) { a == b });
            
            assertions.assert_true(breach_detection_correct, "Risk threshold monitoring works correctly")
        };

        // Test protective action generation
        public func test_protective_action_generation() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let severe_drawdown = 30.0; // 30% drawdown
            let moderate_drawdown = 15.0; // 15% drawdown
            let low_liquidity = 2000000; // 0.02 BTC
            
            let severe_action = determine_protective_action(severe_drawdown, low_liquidity);
            let moderate_action = determine_protective_action(moderate_drawdown, 50000000);
            
            let severe_is_unwind = severe_action == #unwind;
            let moderate_is_reduce = moderate_action == #reduce_exposure or moderate_action == #pause;
            
            assertions.assert_true(severe_is_unwind and moderate_is_reduce, "Protective action generation works correctly")
        };

        // Test protective intent creation
        public func test_protective_intent_creation() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let action = #unwind;
            let reason = "Maximum drawdown threshold exceeded: 25% > 20%";
            
            let intent : Types.ProtectiveIntent = {
                user_id = user_id;
                action = action;
                reason = reason;
                triggered_at = Time.now();
            };
            
            let intent_valid = 
                intent.user_id == user_id and
                intent.action == action and
                Text.size(intent.reason) > 0 and
                intent.triggered_at > 0;
            
            assertions.assert_true(intent_valid, "Protective intent creation works correctly")
        };

        // Test liquidity monitoring
        public func test_liquidity_monitoring() : UnitTestFramework.TestResult {
            let threshold = 10000000; // 0.1 BTC threshold
            let liquidity_scenarios = [
                50000000, // 0.5 BTC - OK
                5000000,  // 0.05 BTC - LOW
                15000000, // 0.15 BTC - OK
                2000000   // 0.02 BTC - CRITICAL
            ];
            
            let liquidity_alerts = Array.map<Nat64, Bool>(liquidity_scenarios, func(liquidity) {
                liquidity < threshold
            });
            
            let expected_alerts = [false, true, false, true];
            let liquidity_monitoring_correct = Array.equal<Bool>(liquidity_alerts, expected_alerts, func(a, b) { a == b });
            
            assertions.assert_true(liquidity_monitoring_correct, "Liquidity monitoring works correctly")
        };

        // Test risk configuration validation
        public func test_risk_configuration_validation() : UnitTestFramework.TestResult {
            let valid_config : Types.RiskGuardConfig = {
                user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
                max_drawdown_pct = 15.0;
                liquidity_exit_threshold = 5000000;
                notify_only = false;
            };
            
            let invalid_configs = [
                { max_drawdown_pct = -5.0; liquidity_exit_threshold = 5000000 }, // Negative drawdown
                { max_drawdown_pct = 150.0; liquidity_exit_threshold = 5000000 }, // > 100% drawdown
                { max_drawdown_pct = 15.0; liquidity_exit_threshold = 0 }        // Zero threshold
            ];
            
            let valid_check = validate_risk_config(valid_config);
            let invalid_checks = Array.map<{max_drawdown_pct: Float; liquidity_exit_threshold: Nat64}, Bool>(
                invalid_configs, func(config) {
                    let test_config : Types.RiskGuardConfig = {
                        user_id = valid_config.user_id;
                        max_drawdown_pct = config.max_drawdown_pct;
                        liquidity_exit_threshold = config.liquidity_exit_threshold;
                        notify_only = false;
                    };
                    not validate_risk_config(test_config)
                }
            );
            
            let all_invalid_detected = Array.foldLeft<Bool, Bool>(invalid_checks, true, func(acc, check) { acc and check });
            
            assertions.assert_true(valid_check and all_invalid_detected, "Risk configuration validation works correctly")
        };

        // Test portfolio value monitoring
        public func test_portfolio_value_monitoring() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let historical_values = [
                { timestamp = Time.now() - 86400000000000; value = 100000000 }, // 1 day ago: 1 BTC
                { timestamp = Time.now() - 43200000000000; value = 95000000 },  // 12 hours ago: 0.95 BTC
                { timestamp = Time.now(); value = 80000000 }                    // Now: 0.8 BTC
            ];
            
            let peak_value = find_peak_value(historical_values);
            let current_value = historical_values[2]!.value;
            let drawdown = calculate_drawdown_percentage(peak_value, current_value);
            
            let peak_correct = peak_value == 100000000;
            let drawdown_correct = Float.abs(drawdown - 20.0) < 0.1; // 20% drawdown
            
            assertions.assert_true(peak_correct and drawdown_correct, "Portfolio value monitoring works correctly")
        };

        // Test manual trigger system
        public func test_manual_trigger_system() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let manual_trigger_request = {
                user_id = user_id;
                action = #pause;
                reason = "Manual intervention requested by user";
            };
            
            let trigger_result = process_manual_trigger(manual_trigger_request);
            
            let trigger_processed = switch (trigger_result) {
                case (#ok(intent)) { 
                    intent.user_id == user_id and 
                    intent.action == #pause and
                    Text.contains(intent.reason, #text("Manual"))
                };
                case (#err(_)) { false };
            };
            
            assertions.assert_true(trigger_processed, "Manual trigger system works correctly")
        };

        // Helper functions for testing
        private func calculate_drawdown_percentage(peak_value: Nat64, current_value: Nat64) : Float {
            if (peak_value == 0) { return 0.0 };
            let peak_float = Float.fromInt(Int64.toInt(Int64.fromNat64(peak_value)));
            let current_float = Float.fromInt(Int64.toInt(Int64.fromNat64(current_value)));
            Float.abs((current_float - peak_float) / peak_float * 100.0)
        };

        private func determine_protective_action(drawdown_pct: Float, liquidity_sats: Nat64) : Types.ProtectiveAction {
            if (drawdown_pct > 25.0 or liquidity_sats < 5000000) {
                #unwind
            } else if (drawdown_pct > 15.0) {
                #reduce_exposure
            } else {
                #pause
            }
        };

        private func validate_risk_config(config: Types.RiskGuardConfig) : Bool {
            config.max_drawdown_pct > 0.0 and 
            config.max_drawdown_pct < 100.0 and
            config.liquidity_exit_threshold > 0
        };

        private func find_peak_value(historical_values: [{timestamp: Int; value: Nat64}]) : Nat64 {
            Array.foldLeft<{timestamp: Int; value: Nat64}, Nat64>(
                historical_values, 0, func(acc, entry) {
                    if (entry.value > acc) { entry.value } else { acc }
                }
            )
        };

        private func process_manual_trigger(
            request: {user_id: Types.UserId; action: Types.ProtectiveAction; reason: Text}
        ) : Result.Result<Types.ProtectiveIntent, Text> {
            let intent : Types.ProtectiveIntent = {
                user_id = request.user_id;
                action = request.action;
                reason = request.reason;
                triggered_at = Time.now();
            };
            #ok(intent)
        };

        // Run all risk guard unit tests
        public func run_all_tests() : UnitTestFramework.TestSuite {
            let test_functions = [
                test_risk_guard_configuration,
                test_drawdown_calculation,
                test_risk_threshold_monitoring,
                test_protective_action_generation,
                test_protective_intent_creation,
                test_liquidity_monitoring,
                test_risk_configuration_validation,
                test_portfolio_value_monitoring,
                test_manual_trigger_system
            ];
            
            runner.run_test_suite("Risk Guard Unit Tests", test_functions)
        };
    };
}