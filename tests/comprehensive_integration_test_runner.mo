import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Int "mo:base/Int";
import Float "mo:base/Float";

import IntegrationTestFramework "./integration_test_framework";
import EndToEndWorkflowTests "./end_to_end_workflow_test";
import BitcoinTestnetIntegrationTests "./bitcoin_testnet_integration_test";
import MultiAgentInteractionTests "./multi_agent_interaction_test";

// Comprehensive integration test runner for all BetterTrade integration tests
actor ComprehensiveIntegrationTestRunner {
    private let runner = IntegrationTestFramework.IntegrationTestRunner();

    // Run all integration test suites
    public func run_all_integration_tests() : async {
        total_passed: Nat;
        total_failed: Nat;
        total_time_ns: Int;
        suites: [IntegrationTestFramework.IntegrationTestSuite];
        overall_success_rate: Float;
    } {
        Debug.print("🚀 Starting Comprehensive Integration Test Suite for BetterTrade");
        Debug.print("================================================================");
        
        let start_time = Time.now();
        
        // Initialize test classes
        let end_to_end_tests = EndToEndWorkflowTests.EndToEndWorkflowTests();
        let bitcoin_testnet_tests = BitcoinTestnetIntegrationTests.BitcoinTestnetIntegrationTests();
        let multi_agent_tests = MultiAgentInteractionTests.MultiAgentInteractionTests();
        
        // Run all integration test suites
        let suites = [
            await end_to_end_tests.run_all_tests(),
            await bitcoin_testnet_tests.run_all_tests(),
            await multi_agent_tests.run_all_tests()
        ];
        
        // Calculate overall results
        var total_passed = 0;
        var total_failed = 0;
        var total_time = 0;
        
        for (suite in suites.vals()) {
            total_passed += suite.passed;
            total_failed += suite.failed;
            total_time += suite.total_time_ns;
        };
        
        let overall_time = Time.now() - start_time;
        let success_rate = if (total_passed + total_failed > 0) {
            Float.fromInt(total_passed) / Float.fromInt(total_passed + total_failed) * 100.0
        } else {
            0.0
        };
        
        Debug.print("================================================================");
        Debug.print("🏁 Comprehensive Integration Test Suite Results:");
        Debug.print("  ✅ Total Passed: " # Int.toText(total_passed));
        Debug.print("  ❌ Total Failed: " # Int.toText(total_failed));
        Debug.print("  📈 Success Rate: " # Float.toText(success_rate) # "%");
        Debug.print("  ⏱️  Total Time: " # Int.toText(overall_time) # "ns");
        Debug.print("================================================================");
        
        {
            total_passed = total_passed;
            total_failed = total_failed;
            total_time_ns = overall_time;
            suites = suites;
            overall_success_rate = success_rate;
        }
    };

    // Run specific test suite by name
    public func run_specific_test_suite(suite_name: Text) : async ?IntegrationTestFramework.IntegrationTestSuite {
        Debug.print("🎯 Running specific integration test suite: " # suite_name);
        
        switch (suite_name) {
            case ("end-to-end") {
                let tests = EndToEndWorkflowTests.EndToEndWorkflowTests();
                ?(await tests.run_all_tests())
            };
            case ("bitcoin-testnet") {
                let tests = BitcoinTestnetIntegrationTests.BitcoinTestnetIntegrationTests();
                ?(await tests.run_all_tests())
            };
            case ("multi-agent") {
                let tests = MultiAgentInteractionTests.MultiAgentInteractionTests();
                ?(await tests.run_all_tests())
            };
            case (_) {
                Debug.print("❌ Unknown test suite: " # suite_name);
                Debug.print("Available suites: end-to-end, bitcoin-testnet, multi-agent");
                null
            };
        }
    };

    // Run integration tests with custom configuration
    public func run_integration_tests_with_config(config: IntegrationTestConfig) : async {
        results: [IntegrationTestFramework.IntegrationTestSuite];
        summary: TestSummary;
    } {
        Debug.print("⚙️  Running integration tests with custom configuration");
        Debug.print("  Timeout: " # Int.toText(config.timeout_seconds) # "s");
        Debug.print("  Parallel execution: " # (if config.parallel_execution "enabled" else "disabled"));
        Debug.print("  Retry failed tests: " # (if config.retry_failed_tests "enabled" else "disabled"));
        
        let start_time = Time.now();
        var results : [IntegrationTestFramework.IntegrationTestSuite] = [];
        
        // Run tests based on configuration
        if (config.parallel_execution) {
            results := await run_tests_in_parallel(config);
        } else {
            results := await run_tests_sequentially(config);
        };
        
        // Retry failed tests if configured
        if (config.retry_failed_tests) {
            results := await retry_failed_tests(results, config);
        };
        
        let total_time = Time.now() - start_time;
        let summary = generate_test_summary(results, total_time);
        
        Debug.print("⚙️  Custom integration test run completed");
        print_test_summary(summary);
        
        { results = results; summary = summary }
    };

    // Generate comprehensive test report
    public func generate_integration_test_report() : async Text {
        let test_results = await run_all_integration_tests();
        
        var report = "# BetterTrade Integration Test Report\n\n";
        report := report # "Generated: " # Int.toText(Time.now()) # "\n\n";
        
        report := report # "## Overall Results\n";
        report := report # "- **Total Tests**: " # Int.toText(test_results.total_passed + test_results.total_failed) # "\n";
        report := report # "- **Passed**: " # Int.toText(test_results.total_passed) # "\n";
        report := report # "- **Failed**: " # Int.toText(test_results.total_failed) # "\n";
        report := report # "- **Success Rate**: " # Float.toText(test_results.overall_success_rate) # "%\n";
        report := report # "- **Total Execution Time**: " # Int.toText(test_results.total_time_ns) # "ns\n\n";
        
        report := report # "## Test Suite Details\n\n";
        
        for (suite in test_results.suites.vals()) {
            report := report # "### " # suite.name # "\n";
            report := report # "- **Passed**: " # Int.toText(suite.passed) # "\n";
            report := report # "- **Failed**: " # Int.toText(suite.failed) # "\n";
            report := report # "- **Execution Time**: " # Int.toText(suite.total_time_ns) # "ns\n\n";
            
            report := report # "#### Individual Tests\n";
            for (test in suite.tests.vals()) {
                let status = if (test.passed) "✅" else "❌";
                report := report # "- " # status # " **" # test.name # "**: " # test.message # "\n";
                report := report # "  - Steps: " # Int.toText(test.steps_completed) # "/" # Int.toText(test.total_steps) # "\n";
                report := report # "  - Time: " # Int.toText(test.execution_time_ns) # "ns\n";
            };
            report := report # "\n";
        };
        
        report := report # "## Recommendations\n\n";
        
        if (test_results.overall_success_rate < 90.0) {
            report := report # "⚠️  **Action Required**: Success rate below 90%. Review failed tests and address issues.\n\n";
        };
        
        if (test_results.total_time_ns > 60000000000) { // > 60 seconds
            report := report # "⚠️  **Performance**: Test execution time exceeds 60 seconds. Consider optimization.\n\n";
        };
        
        report := report # "## Next Steps\n\n";
        report := report # "1. Address any failed tests\n";
        report := report # "2. Monitor performance metrics\n";
        report := report # "3. Update test coverage as needed\n";
        report := report # "4. Schedule regular integration test runs\n";
        
        report
    };

    // Helper functions
    private func run_tests_in_parallel(config: IntegrationTestConfig) : async [IntegrationTestFramework.IntegrationTestSuite] {
        Debug.print("🔄 Running tests in parallel...");
        
        // Create test instances
        let end_to_end_tests = EndToEndWorkflowTests.EndToEndWorkflowTests();
        let bitcoin_testnet_tests = BitcoinTestnetIntegrationTests.BitcoinTestnetIntegrationTests();
        let multi_agent_tests = MultiAgentInteractionTests.MultiAgentInteractionTests();
        
        // Run tests concurrently
        let futures = [
            end_to_end_tests.run_all_tests(),
            bitcoin_testnet_tests.run_all_tests(),
            multi_agent_tests.run_all_tests()
        ];
        
        var results : [IntegrationTestFramework.IntegrationTestSuite] = [];
        for (future in futures.vals()) {
            let result = await future;
            results := Array.append(results, [result]);
        };
        
        results
    };

    private func run_tests_sequentially(config: IntegrationTestConfig) : async [IntegrationTestFramework.IntegrationTestSuite] {
        Debug.print("➡️  Running tests sequentially...");
        
        var results : [IntegrationTestFramework.IntegrationTestSuite] = [];
        
        // End-to-end tests
        let end_to_end_tests = EndToEndWorkflowTests.EndToEndWorkflowTests();
        let end_to_end_result = await end_to_end_tests.run_all_tests();
        results := Array.append(results, [end_to_end_result]);
        
        // Bitcoin testnet tests
        let bitcoin_testnet_tests = BitcoinTestnetIntegrationTests.BitcoinTestnetIntegrationTests();
        let bitcoin_result = await bitcoin_testnet_tests.run_all_tests();
        results := Array.append(results, [bitcoin_result]);
        
        // Multi-agent tests
        let multi_agent_tests = MultiAgentInteractionTests.MultiAgentInteractionTests();
        let multi_agent_result = await multi_agent_tests.run_all_tests();
        results := Array.append(results, [multi_agent_result]);
        
        results
    };

    private func retry_failed_tests(
        initial_results: [IntegrationTestFramework.IntegrationTestSuite],
        config: IntegrationTestConfig
    ) : async [IntegrationTestFramework.IntegrationTestSuite] {
        Debug.print("🔄 Retrying failed tests...");
        
        var final_results : [IntegrationTestFramework.IntegrationTestSuite] = [];
        
        for (suite in initial_results.vals()) {
            if (suite.failed > 0) {
                Debug.print("  Retrying suite: " # suite.name);
                // In a real implementation, would re-run only failed tests
                // For now, just return the original results
                final_results := Array.append(final_results, [suite]);
            } else {
                final_results := Array.append(final_results, [suite]);
            };
        };
        
        final_results
    };

    private func generate_test_summary(
        results: [IntegrationTestFramework.IntegrationTestSuite],
        total_time: Int
    ) : TestSummary {
        var total_passed = 0;
        var total_failed = 0;
        
        for (suite in results.vals()) {
            total_passed += suite.passed;
            total_failed += suite.failed;
        };
        
        let success_rate = if (total_passed + total_failed > 0) {
            Float.fromInt(total_passed) / Float.fromInt(total_passed + total_failed) * 100.0
        } else {
            0.0
        };
        
        {
            total_tests = total_passed + total_failed;
            passed_tests = total_passed;
            failed_tests = total_failed;
            success_rate = success_rate;
            execution_time_ns = total_time;
            suites_count = results.size();
        }
    };

    private func print_test_summary(summary: TestSummary) {
        Debug.print("📊 Test Summary:");
        Debug.print("  Total Tests: " # Int.toText(summary.total_tests));
        Debug.print("  Passed: " # Int.toText(summary.passed_tests));
        Debug.print("  Failed: " # Int.toText(summary.failed_tests));
        Debug.print("  Success Rate: " # Float.toText(summary.success_rate) # "%");
        Debug.print("  Execution Time: " # Int.toText(summary.execution_time_ns) # "ns");
        Debug.print("  Test Suites: " # Int.toText(summary.suites_count));
    };

    // Configuration and summary types
    public type IntegrationTestConfig = {
        timeout_seconds: Int;
        parallel_execution: Bool;
        retry_failed_tests: Bool;
        max_retries: Nat;
        verbose_output: Bool;
    };

    public type TestSummary = {
        total_tests: Nat;
        passed_tests: Nat;
        failed_tests: Nat;
        success_rate: Float;
        execution_time_ns: Int;
        suites_count: Nat;
    };

    // Default configuration
    public func get_default_config() : IntegrationTestConfig {
        {
            timeout_seconds = 300; // 5 minutes
            parallel_execution = true;
            retry_failed_tests = false;
            max_retries = 1;
            verbose_output = true;
        }
    };
}