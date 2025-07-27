import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Principal "mo:base/Principal";
import Types "../src/shared/types";

// Comprehensive unit test framework for BetterTrade
module {
    // Test result types
    public type TestResult = {
        name: Text;
        passed: Bool;
        message: Text;
        execution_time_ns: Int;
    };

    public type TestSuite = {
        name: Text;
        tests: [TestResult];
        passed: Nat;
        failed: Nat;
        total_time_ns: Int;
    };

    // Test assertion helpers
    public class TestAssertions() {
        
        public func assert_true(condition: Bool, message: Text) : TestResult {
            let start_time = Time.now();
            let result = {
                name = "assert_true";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message;
                execution_time_ns = Time.now() - start_time;
            };
            result
        };

        public func assert_false(condition: Bool, message: Text) : TestResult {
            let start_time = Time.now();
            let result = {
                name = "assert_false";
                passed = not condition;
                message = if (not condition) "✅ " # message else "❌ " # message;
                execution_time_ns = Time.now() - start_time;
            };
            result
        };

        public func assert_equal<T>(actual: T, expected: T, compare: (T, T) -> Bool, message: Text) : TestResult {
            let start_time = Time.now();
            let condition = compare(actual, expected);
            let result = {
                name = "assert_equal";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message # " (values not equal)";
                execution_time_ns = Time.now() - start_time;
            };
            result
        };

        public func assert_not_equal<T>(actual: T, expected: T, compare: (T, T) -> Bool, message: Text) : TestResult {
            let start_time = Time.now();
            let condition = not compare(actual, expected);
            let result = {
                name = "assert_not_equal";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message # " (values are equal)";
                execution_time_ns = Time.now() - start_time;
            };
            result
        };

        public func assert_float_equal(actual: Float, expected: Float, tolerance: Float, message: Text) : TestResult {
            let start_time = Time.now();
            let condition = Float.abs(actual - expected) <= tolerance;
            let result = {
                name = "assert_float_equal";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message # " (actual: " # Float.toText(actual) # ", expected: " # Float.toText(expected) # ")";
                execution_time_ns = Time.now() - start_time;
            };
            result
        };

        public func assert_array_length<T>(array: [T], expected_length: Nat, message: Text) : TestResult {
            let start_time = Time.now();
            let actual_length = array.size();
            let condition = actual_length == expected_length;
            let result = {
                name = "assert_array_length";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message # " (actual: " # Int.toText(actual_length) # ", expected: " # Int.toText(expected_length) # ")";
                execution_time_ns = Time.now() - start_time;
            };
            result
        };

        public func assert_text_contains(text: Text, substring: Text, message: Text) : TestResult {
            let start_time = Time.now();
            let condition = Text.contains(text, #text(substring));
            let result = {
                name = "assert_text_contains";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message # " ('" # substring # "' not found in text)";
                execution_time_ns = Time.now() - start_time;
            };
            result
        };

        public func assert_result_ok<T, E>(result: Result.Result<T, E>, message: Text) : TestResult {
            let start_time = Time.now();
            let condition = switch (result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            let test_result = {
                name = "assert_result_ok";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message # " (result is error)";
                execution_time_ns = Time.now() - start_time;
            };
            test_result
        };

        public func assert_result_err<T, E>(result: Result.Result<T, E>, message: Text) : TestResult {
            let start_time = Time.now();
            let condition = switch (result) {
                case (#ok(_)) { false };
                case (#err(_)) { true };
            };
            let test_result = {
                name = "assert_result_err";
                passed = condition;
                message = if (condition) "✅ " # message else "❌ " # message # " (result is ok)";
                execution_time_ns = Time.now() - start_time;
            };
            test_result
        };
    };

    // Test runner class
    public class TestRunner() {
        
        public func run_test_suite(suite_name: Text, test_functions: [() -> TestResult]) : TestSuite {
            let start_time = Time.now();
            Debug.print("🧪 Running test suite: " # suite_name);
            
            let results = Array.map<() -> TestResult, TestResult>(test_functions, func(test_fn) {
                test_fn()
            });
            
            let passed_count = Array.foldLeft<TestResult, Nat>(results, 0, func(acc, result) {
                if (result.passed) { acc + 1 } else { acc }
            });
            
            let failed_count = results.size() - passed_count;
            let total_time = Time.now() - start_time;
            
            // Print individual test results
            for (result in results.vals()) {
                Debug.print("  " # result.message);
            };
            
            // Print suite summary
            Debug.print("📊 Suite '" # suite_name # "' completed:");
            Debug.print("  ✅ Passed: " # Int.toText(passed_count));
            Debug.print("  ❌ Failed: " # Int.toText(failed_count));
            Debug.print("  ⏱️  Total time: " # Int.toText(total_time) # "ns");
            Debug.print("");
            
            {
                name = suite_name;
                tests = results;
                passed = passed_count;
                failed = failed_count;
                total_time_ns = total_time;
            }
        };

        public func run_multiple_suites(suites: [TestSuite]) : {total_passed: Nat; total_failed: Nat; total_time_ns: Int} {
            Debug.print("🚀 Running comprehensive test suite...");
            Debug.print("==========================================");
            
            var total_passed = 0;
            var total_failed = 0;
            var total_time = 0;
            
            for (suite in suites.vals()) {
                total_passed += suite.passed;
                total_failed += suite.failed;
                total_time += suite.total_time_ns;
            };
            
            Debug.print("==========================================");
            Debug.print("🏁 Overall Results:");
            Debug.print("  ✅ Total Passed: " # Int.toText(total_passed));
            Debug.print("  ❌ Total Failed: " # Int.toText(total_failed));
            Debug.print("  ⏱️  Total Time: " # Int.toText(total_time) # "ns");
            Debug.print("  📈 Success Rate: " # Float.toText(Float.fromInt(total_passed) / Float.fromInt(total_passed + total_failed) * 100.0) # "%");
            
            {
                total_passed = total_passed;
                total_failed = total_failed;
                total_time_ns = total_time;
            }
        };
    };

    // Performance benchmark utilities
    public class PerformanceBenchmark() {
        
        public func benchmark_function<T>(name: Text, fn: () -> T, iterations: Nat) : {avg_time_ns: Int; min_time_ns: Int; max_time_ns: Int; total_time_ns: Int} {
            Debug.print("⚡ Benchmarking: " # name # " (" # Int.toText(iterations) # " iterations)");
            
            var total_time = 0;
            var min_time = Int.abs(Time.now()); // Initialize with large value
            var max_time = 0;
            
            for (i in Iter.range(0, iterations - 1)) {
                let start_time = Time.now();
                ignore fn();
                let execution_time = Time.now() - start_time;
                
                total_time += execution_time;
                if (execution_time < min_time) { min_time := execution_time };
                if (execution_time > max_time) { max_time := execution_time };
            };
            
            let avg_time = total_time / iterations;
            
            Debug.print("  📊 Average: " # Int.toText(avg_time) # "ns");
            Debug.print("  ⚡ Min: " # Int.toText(min_time) # "ns");
            Debug.print("  🐌 Max: " # Int.toText(max_time) # "ns");
            Debug.print("  🕐 Total: " # Int.toText(total_time) # "ns");
            Debug.print("");
            
            {
                avg_time_ns = avg_time;
                min_time_ns = min_time;
                max_time_ns = max_time;
                total_time_ns = total_time;
            }
        };

        public func benchmark_async_function<T>(name: Text, fn: () -> async T, iterations: Nat) : async {avg_time_ns: Int; min_time_ns: Int; max_time_ns: Int; total_time_ns: Int} {
            Debug.print("⚡ Benchmarking (async): " # name # " (" # Int.toText(iterations) # " iterations)");
            
            var total_time = 0;
            var min_time = Int.abs(Time.now());
            var max_time = 0;
            
            for (i in Iter.range(0, iterations - 1)) {
                let start_time = Time.now();
                ignore await fn();
                let execution_time = Time.now() - start_time;
                
                total_time += execution_time;
                if (execution_time < min_time) { min_time := execution_time };
                if (execution_time > max_time) { max_time := execution_time };
            };
            
            let avg_time = total_time / iterations;
            
            Debug.print("  📊 Average: " # Int.toText(avg_time) # "ns");
            Debug.print("  ⚡ Min: " # Int.toText(min_time) # "ns");
            Debug.print("  🐌 Max: " # Int.toText(max_time) # "ns");
            Debug.print("  🕐 Total: " # Int.toText(total_time) # "ns");
            Debug.print("");
            
            {
                avg_time_ns = avg_time;
                min_time_ns = min_time;
                max_time_ns = max_time;
                total_time_ns = total_time;
            }
        };
    };

    // Mock data generators
    public class MockDataGenerator() {
        
        public func generate_test_user(id_suffix: Text) : Types.User {
            {
                principal_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-" # id_suffix);
                display_name = "Test User " # id_suffix;
                created_at = Time.now();
                risk_profile = #balanced;
            }
        };

        public func generate_test_wallet(user_id: Types.UserId, network: Types.Network) : Types.Wallet {
            let address = switch (network) {
                case (#testnet) { "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx" };
                case (#mainnet) { "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kw508d6qejxtdg4y5r3zarvary0c5xw7kw5rljs90" };
            };
            
            {
                user_id = user_id;
                btc_address = address;
                network = network;
                status = #active;
            }
        };

        public func generate_test_strategy_template(risk_level: Types.RiskLevel) : Types.StrategyTemplate {
            let (id, name, venues, apy_band) = switch (risk_level) {
                case (#conservative) { 
                    ("conservative-lending", "Conservative Lending", ["BlockFi", "Celsius"], (3.0, 6.0))
                };
                case (#balanced) { 
                    ("balanced-liquidity", "Balanced Liquidity", ["Uniswap", "Curve", "Aave"], (8.0, 15.0))
                };
                case (#aggressive) { 
                    ("aggressive-yield", "Aggressive Yield", ["Yearn", "Convex", "Beefy", "Harvest"], (15.0, 35.0))
                };
            };
            
            {
                id = id;
                name = name;
                risk_level = risk_level;
                venues = venues;
                est_apy_band = apy_band;
                params_schema = "{}";
            }
        };

        public func generate_test_utxo(txid: Text, vout: Nat32, amount_sats: Nat64) : Types.UTXO {
            {
                txid = txid;
                vout = vout;
                amount_sats = amount_sats;
                address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                confirmations = 6;
                block_height = ?800000;
                spent = false;
                spent_in_tx = null;
            }
        };

        public func generate_test_transaction(user_id: Types.UserId, tx_type: Types.TxType, amount_sats: Nat64) : Types.TxRecord {
            {
                txid = "test_tx_" # Principal.toText(user_id) # "_" # Int.toText(Time.now());
                user_id = user_id;
                tx_type = tx_type;
                amount_sats = amount_sats;
                fee_sats = 1000; // 1000 sats fee
                status = #confirmed;
                confirmed_height = ?800000;
                timestamp = Time.now();
            }
        };
    };
}