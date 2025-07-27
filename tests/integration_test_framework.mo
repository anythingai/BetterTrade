import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

import Types "../src/shared/types";
import Interfaces "../src/shared/interfaces";

// Integration test framework for multi-canister workflows
module {
    // Integration test result types
    public type IntegrationTestResult = {
        name: Text;
        passed: Bool;
        message: Text;
        execution_time_ns: Int;
        steps_completed: Nat;
        total_steps: Nat;
    };

    public type IntegrationTestSuite = {
        name: Text;
        tests: [IntegrationTestResult];
        passed: Nat;
        failed: Nat;
        total_time_ns: Int;
    };

    // Mock canister registry for testing
    public type MockCanisterRegistry = {
        user_registry: Principal;
        portfolio_state: Principal;
        strategy_selector: Principal;
        execution_agent: Principal;
        risk_guard: Principal;
    };

    // Integration test context
    public type TestContext = {
        registry: MockCanisterRegistry;
        test_users: [Types.User];
        test_wallets: [Types.Wallet];
        test_strategies: [Types.StrategyTemplate];
        current_time: Int;
    };

    // Integration test runner
    public class IntegrationTestRunner() {
        
        // Initialize test context with mock data
        public func initialize_test_context() : TestContext {
            let mock_registry : MockCanisterRegistry = {
                user_registry = Principal.fromText("rdmx6-jaaaa-aaaah-qdrya-cai");
                portfolio_state = Principal.fromText("rrkah-fqaaa-aaaah-qdrya-cai");
                strategy_selector = Principal.fromText("ryjl3-tyaaa-aaaah-qdrya-cai");
                execution_agent = Principal.fromText("renrk-eyaaa-aaaah-qdrya-cai");
                risk_guard = Principal.fromText("rno2w-sqaaa-aaaah-qdrya-cai");
            };
            
            let test_users = [
                {
                    principal_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-ca1");
                    display_name = "Integration Test User 1";
                    created_at = Time.now();
                    risk_profile = #conservative;
                },
                {
                    principal_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-ca2");
                    display_name = "Integration Test User 2";
                    created_at = Time.now();
                    risk_profile = #balanced;
                },
                {
                    principal_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-ca3");
                    display_name = "Integration Test User 3";
                    created_at = Time.now();
                    risk_profile = #aggressive;
                }
            ];
            
            let test_wallets = Array.map<Types.User, Types.Wallet>(test_users, func(user) {
                {
                    user_id = user.principal_id;
                    btc_address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                    network = #testnet;
                    status = #active;
                }
            });
            
            let test_strategies = [
                {
                    id = "integration-conservative";
                    name = "Integration Conservative Strategy";
                    risk_level = #conservative;
                    venues = ["TestVenue1", "TestVenue2"];
                    est_apy_band = (3.0, 6.0);
                    params_schema = "{}";
                },
                {
                    id = "integration-balanced";
                    name = "Integration Balanced Strategy";
                    risk_level = #balanced;
                    venues = ["TestVenue1", "TestVenue2", "TestVenue3"];
                    est_apy_band = (8.0, 15.0);
                    params_schema = "{}";
                },
                {
                    id = "integration-aggressive";
                    name = "Integration Aggressive Strategy";
                    risk_level = #aggressive;
                    venues = ["TestVenue1", "TestVenue2", "TestVenue3", "TestVenue4"];
                    est_apy_band = (15.0, 35.0);
                    params_schema = "{}";
                }
            ];
            
            {
                registry = mock_registry;
                test_users = test_users;
                test_wallets = test_wallets;
                test_strategies = test_strategies;
                current_time = Time.now();
            }
        };

        // Run integration test with step tracking
        public func run_integration_test(
            name: Text,
            test_function: (TestContext) -> async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat}
        ) : async IntegrationTestResult {
            let start_time = Time.now();
            let context = initialize_test_context();
            
            Debug.print("🔗 Running integration test: " # name);
            
            let result = await test_function(context);
            let execution_time = Time.now() - start_time;
            
            let test_result = {
                name = name;
                passed = result.passed;
                message = if (result.passed) "✅ " # result.message else "❌ " # result.message;
                execution_time_ns = execution_time;
                steps_completed = result.steps_completed;
                total_steps = result.total_steps;
            };
            
            Debug.print("  " # test_result.message);
            Debug.print("  Steps: " # Int.toText(result.steps_completed) # "/" # Int.toText(result.total_steps));
            Debug.print("  Time: " # Int.toText(execution_time) # "ns");
            Debug.print("");
            
            test_result
        };

        // Run integration test suite
        public func run_integration_test_suite(
            suite_name: Text,
            test_functions: [(Text, (TestContext) -> async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat})]
        ) : async IntegrationTestSuite {
            let start_time = Time.now();
            Debug.print("🔗 Running integration test suite: " # suite_name);
            Debug.print("================================================");
            
            var results : [IntegrationTestResult] = [];
            
            for ((test_name, test_function) in test_functions.vals()) {
                let result = await run_integration_test(test_name, test_function);
                results := Array.append(results, [result]);
            };
            
            let passed_count = Array.foldLeft<IntegrationTestResult, Nat>(results, 0, func(acc, result) {
                if (result.passed) { acc + 1 } else { acc }
            });
            
            let failed_count = results.size() - passed_count;
            let total_time = Time.now() - start_time;
            
            Debug.print("================================================");
            Debug.print("📊 Integration suite '" # suite_name # "' completed:");
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
    };

    // Mock inter-canister communication helpers
    public class MockInterCanisterCommunicator() {
        
        // Mock user registration call
        public func mock_register_user(user: Types.User) : async Result.Result<Types.UserId, Text> {
            // Simulate network delay
            await async_delay(100000000); // 100ms
            
            if (Text.size(user.display_name) > 0) {
                #ok(user.principal_id)
            } else {
                #err("Invalid display name")
            }
        };

        // Mock wallet linking call
        public func mock_link_wallet(user_id: Types.UserId, wallet: Types.Wallet) : async Result.Result<Types.WalletId, Text> {
            await async_delay(50000000); // 50ms
            
            if (wallet.user_id == user_id) {
                #ok(Principal.toText(user_id) # "_" # wallet.btc_address)
            } else {
                #err("User ID mismatch")
            }
        };

        // Mock deposit detection
        public func mock_detect_deposit(user_id: Types.UserId, amount_sats: Nat64) : async Result.Result<Types.TxId, Text> {
            await async_delay(200000000); // 200ms
            
            if (amount_sats > 0) {
                #ok("deposit_tx_" # Principal.toText(user_id) # "_" # Int.toText(Time.now()))
            } else {
                #err("Invalid deposit amount")
            }
        };

        // Mock strategy recommendation
        public func mock_recommend_strategy(user_id: Types.UserId, risk_profile: Types.RiskLevel) : async Result.Result<Types.StrategyPlan, Text> {
            await async_delay(300000000); // 300ms
            
            let strategy_id = switch (risk_profile) {
                case (#conservative) { "integration-conservative" };
                case (#balanced) { "integration-balanced" };
                case (#aggressive) { "integration-aggressive" };
            };
            
            let plan : Types.StrategyPlan = {
                id = "plan_" # strategy_id # "_" # Principal.toText(user_id);
                user_id = user_id;
                template_id = strategy_id;
                allocations = [
                    { venue_id = "TestVenue1"; amount_sats = 50000000; percentage = 50.0 },
                    { venue_id = "TestVenue2"; amount_sats = 50000000; percentage = 50.0 }
                ];
                created_at = Time.now();
                status = #pending;
                rationale = "Mock strategy recommendation for integration testing";
            };
            
            #ok(plan)
        };

        // Mock strategy execution
        public func mock_execute_strategy(plan: Types.StrategyPlan) : async Result.Result<[Types.TxId], Text> {
            await async_delay(500000000); // 500ms
            
            if (plan.status == #approved) {
                let tx_ids = Array.map<Types.Allocation, Types.TxId>(plan.allocations, func(alloc) {
                    "exec_tx_" # alloc.venue_id # "_" # Int.toText(Time.now())
                });
                #ok(tx_ids)
            } else {
                #err("Strategy plan not approved")
            }
        };

        // Mock portfolio update
        public func mock_update_portfolio(user_id: Types.UserId, tx_ids: [Types.TxId]) : async Result.Result<Types.PortfolioSummary, Text> {
            await async_delay(150000000); // 150ms
            
            let portfolio : Types.PortfolioSummary = {
                user_id = user_id;
                total_balance_sats = 100000000; // 1 BTC
                total_value_usd = 42000.0;
                positions = [
                    {
                        user_id = user_id;
                        venue_id = "TestVenue1";
                        amount_sats = 50000000;
                        entry_price = 40000.0;
                        current_value = 42000.0;
                        pnl = 2500.0;
                    }
                ];
                pnl_24h = 2500.0;
                active_strategy = ?"integration-balanced";
            };
            
            #ok(portfolio)
        };

        // Mock risk monitoring
        public func mock_monitor_risk(user_id: Types.UserId, portfolio: Types.PortfolioSummary) : async Result.Result<?Types.ProtectiveIntent, Text> {
            await async_delay(100000000); // 100ms
            
            // Simulate risk check - no action needed for test scenario
            #ok(null)
        };

        // Helper function to simulate async delay
        private func async_delay(nanoseconds: Int) : async () {
            let start = Time.now();
            while (Time.now() - start < nanoseconds) {
                // Busy wait to simulate processing time
            };
        };
    };

    // Test data generators for integration tests
    public class IntegrationTestDataGenerator() {
        
        public func generate_test_deposit_scenario(user: Types.User) : {
            deposit_amount: Nat64;
            expected_confirmations: Nat32;
            expected_tx_id: Text;
        } {
            {
                deposit_amount = 100000000; // 1 BTC
                expected_confirmations = 6;
                expected_tx_id = "test_deposit_" # Principal.toText(user.principal_id);
            }
        };

        public func generate_test_strategy_scenario(user: Types.User) : {
            recommended_strategy_id: Text;
            expected_allocations: Nat;
            expected_total_percentage: Float;
        } {
            let strategy_id = switch (user.risk_profile) {
                case (#conservative) { "integration-conservative" };
                case (#balanced) { "integration-balanced" };
                case (#aggressive) { "integration-aggressive" };
            };
            
            let expected_allocations = switch (user.risk_profile) {
                case (#conservative) { 2 };
                case (#balanced) { 3 };
                case (#aggressive) { 4 };
            };
            
            {
                recommended_strategy_id = strategy_id;
                expected_allocations = expected_allocations;
                expected_total_percentage = 100.0;
            }
        };

        public func generate_test_execution_scenario(plan: Types.StrategyPlan) : {
            expected_tx_count: Nat;
            expected_total_amount: Nat64;
            expected_venues: [Text];
        } {
            let total_amount = Array.foldLeft<Types.Allocation, Nat64>(
                plan.allocations, 0, func(acc, alloc) { acc + alloc.amount_sats }
            );
            
            let venues = Array.map<Types.Allocation, Text>(plan.allocations, func(alloc) {
                alloc.venue_id
            });
            
            {
                expected_tx_count = plan.allocations.size();
                expected_total_amount = total_amount;
                expected_venues = venues;
            }
        };
    };

    // Workflow validation helpers
    public class WorkflowValidator() {
        
        public func validate_user_onboarding_workflow(
            initial_user: Types.User,
            final_wallet: Types.Wallet,
            deposit_result: Result.Result<Types.TxId, Text>
        ) : {valid: Bool; message: Text} {
            let user_valid = Text.size(initial_user.display_name) > 0;
            let wallet_valid = final_wallet.user_id == initial_user.principal_id and final_wallet.status == #active;
            let deposit_valid = switch (deposit_result) {
                case (#ok(tx_id)) { Text.size(tx_id) > 0 };
                case (#err(_)) { false };
            };
            
            let all_valid = user_valid and wallet_valid and deposit_valid;
            let message = if (all_valid) {
                "User onboarding workflow completed successfully"
            } else {
                "User onboarding workflow failed: " #
                (if (not user_valid) "invalid user, " else "") #
                (if (not wallet_valid) "invalid wallet, " else "") #
                (if (not deposit_valid) "invalid deposit" else "")
            };
            
            {valid = all_valid; message = message}
        };

        public func validate_strategy_recommendation_workflow(
            user: Types.User,
            recommended_plan: Types.StrategyPlan,
            approved_plan: Types.StrategyPlan
        ) : {valid: Bool; message: Text} {
            let user_match = recommended_plan.user_id == user.principal_id;
            let plan_approved = approved_plan.status == #approved;
            let same_plan = recommended_plan.id == approved_plan.id;
            let allocations_valid = approved_plan.allocations.size() > 0;
            
            let all_valid = user_match and plan_approved and same_plan and allocations_valid;
            let message = if (all_valid) {
                "Strategy recommendation workflow completed successfully"
            } else {
                "Strategy recommendation workflow failed"
            };
            
            {valid = all_valid; message = message}
        };

        public func validate_execution_workflow(
            approved_plan: Types.StrategyPlan,
            execution_result: Result.Result<[Types.TxId], Text>,
            portfolio_update: Types.PortfolioSummary
        ) : {valid: Bool; message: Text} {
            let execution_success = switch (execution_result) {
                case (#ok(tx_ids)) { tx_ids.size() > 0 };
                case (#err(_)) { false };
            };
            
            let portfolio_updated = portfolio_update.active_strategy != null;
            let positions_created = portfolio_update.positions.size() > 0;
            
            let all_valid = execution_success and portfolio_updated and positions_created;
            let message = if (all_valid) {
                "Execution workflow completed successfully"
            } else {
                "Execution workflow failed"
            };
            
            {valid = all_valid; message = message}
        };
    };
}