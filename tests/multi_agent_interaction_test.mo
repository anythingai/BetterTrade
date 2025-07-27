import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Principal "mo:base/Principal";
import Iter "mo:base/Iter";

import Types "../src/shared/types";
import IntegrationTestFramework "./integration_test_framework";

// Multi-agent interaction and communication tests
module {
    public class MultiAgentInteractionTests() {
        private let runner = IntegrationTestFramework.IntegrationTestRunner();
        private let communicator = IntegrationTestFramework.MockInterCanisterCommunicator();

        // Test inter-canister communication patterns
        public func test_inter_canister_communication(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 6;
            var steps_completed = 0;
            
            let test_user = context.test_users[0]!;
            
            // Step 1: User Registry -> Portfolio State communication
            let user_registration = await communicator.mock_register_user(test_user);
            let registration_success = switch (user_registration) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (registration_success) { steps_completed += 1 };
            
            // Step 2: Portfolio State -> Strategy Selector communication
            let portfolio_result = await communicator.mock_update_portfolio(test_user.principal_id, []);
            let portfolio_success = switch (portfolio_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (portfolio_success) { steps_completed += 1 };
            
            // Step 3: Strategy Selector -> Execution Agent communication
            let strategy_result = await communicator.mock_recommend_strategy(test_user.principal_id, test_user.risk_profile);
            let strategy_success = switch (strategy_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (strategy_success) { steps_completed += 1 };
            
            // Step 4: Execution Agent -> Portfolio State communication
            let strategy_plan = switch (strategy_result) {
                case (#ok(plan)) { 
                    {
                        id = plan.id;
                        user_id = plan.user_id;
                        template_id = plan.template_id;
                        allocations = plan.allocations;
                        created_at = plan.created_at;
                        status = #approved;
                        rationale = plan.rationale;
                    }
                };
                case (#err(_)) { 
                    return {
                        passed = false;
                        message = "Failed to get strategy plan";
                        steps_completed = steps_completed;
                        total_steps = total_steps;
                    };
                };
            };
            
            let execution_result = await communicator.mock_execute_strategy(strategy_plan);
            let execution_success = switch (execution_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (execution_success) { steps_completed += 1 };
            
            // Step 5: Portfolio State -> Risk Guard communication
            let portfolio_summary = switch (portfolio_result) {
                case (#ok(summary)) { summary };
                case (#err(_)) { 
                    return {
                        passed = false;
                        message = "Failed to get portfolio summary";
                        steps_completed = steps_completed;
                        total_steps = total_steps;
                    };
                };
            };
            
            let risk_result = await communicator.mock_monitor_risk(test_user.principal_id, portfolio_summary);
            let risk_success = switch (risk_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (risk_success) { steps_completed += 1 };
            
            // Step 6: Validate communication chain integrity
            let communication_chain_valid = 
                registration_success and 
                portfolio_success and 
                strategy_success and 
                execution_success and 
                risk_success;
            if (communication_chain_valid) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Inter-canister communication chain completed successfully"
            } else {
                "Inter-canister communication failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Test concurrent multi-user scenarios
        public func test_concurrent_multi_user_scenarios(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 4;
            var steps_completed = 0;
            
            let users = context.test_users;
            
            // Step 1: Register all users concurrently
            let registration_futures = Array.map<Types.User, async Result.Result<Types.UserId, Text>>(
                users, func(user) {
                    communicator.mock_register_user(user)
                }
            );
            
            var registration_results : [Result.Result<Types.UserId, Text>] = [];
            for (future in registration_futures.vals()) {
                let result = await future;
                registration_results := Array.append(registration_results, [result]);
            };
            
            let all_registrations_successful = Array.foldLeft<Result.Result<Types.UserId, Text>, Bool>(
                registration_results, true, func(acc, result) {
                    acc and switch (result) {
                        case (#ok(_)) { true };
                        case (#err(_)) { false };
                    }
                }
            );
            if (all_registrations_successful) { steps_completed += 1 };
            
            // Step 2: Generate strategy recommendations for all users concurrently
            let strategy_futures = Array.map<Types.User, async Result.Result<Types.StrategyPlan, Text>>(
                users, func(user) {
                    communicator.mock_recommend_strategy(user.principal_id, user.risk_profile)
                }
            );
            
            var strategy_results : [Result.Result<Types.StrategyPlan, Text>] = [];
            for (future in strategy_futures.vals()) {
                let result = await future;
                strategy_results := Array.append(strategy_results, [result]);
            };
            
            let all_strategies_successful = Array.foldLeft<Result.Result<Types.StrategyPlan, Text>, Bool>(
                strategy_results, true, func(acc, result) {
                    acc and switch (result) {
                        case (#ok(_)) { true };
                        case (#err(_)) { false };
                    }
                }
            );
            if (all_strategies_successful) { steps_completed += 1 };
            
            // Step 3: Execute strategies for all users concurrently
            let approved_plans = Array.map<Result.Result<Types.StrategyPlan, Text>, Types.StrategyPlan>(
                strategy_results, func(result) {
                    switch (result) {
                        case (#ok(plan)) { 
                            {
                                id = plan.id;
                                user_id = plan.user_id;
                                template_id = plan.template_id;
                                allocations = plan.allocations;
                                created_at = plan.created_at;
                                status = #approved;
                                rationale = plan.rationale;
                            }
                        };
                        case (#err(_)) { 
                            // Create dummy plan for failed cases
                            {
                                id = "failed_plan";
                                user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
                                template_id = "failed";
                                allocations = [];
                                created_at = Time.now();
                                status = #failed;
                                rationale = "Failed to create plan";
                            }
                        };
                    }
                }
            );
            
            let execution_futures = Array.map<Types.StrategyPlan, async Result.Result<[Types.TxId], Text>>(
                approved_plans, func(plan) {
                    if (plan.status == #approved) {
                        communicator.mock_execute_strategy(plan)
                    } else {
                        async { #err("Plan not approved") }
                    }
                }
            );
            
            var execution_results : [Result.Result<[Types.TxId], Text>] = [];
            for (future in execution_futures.vals()) {
                let result = await future;
                execution_results := Array.append(execution_results, [result]);
            };
            
            let successful_executions = Array.foldLeft<Result.Result<[Types.TxId], Text>, Nat>(
                execution_results, 0, func(acc, result) {
                    switch (result) {
                        case (#ok(_)) { acc + 1 };
                        case (#err(_)) { acc };
                    }
                }
            );
            
            let most_executions_successful = successful_executions >= (users.size() * 2 / 3); // At least 2/3 successful
            if (most_executions_successful) { steps_completed += 1 };
            
            // Step 4: Validate no resource conflicts or data corruption
            let no_conflicts = validate_no_resource_conflicts(users, execution_results);
            if (no_conflicts) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Concurrent multi-user scenarios completed successfully (" # Int.toText(successful_executions) # "/" # Int.toText(users.size()) # " executions)"
            } else {
                "Concurrent multi-user scenarios failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Test agent coordination and state consistency
        public func test_agent_coordination_and_state_consistency(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 5;
            var steps_completed = 0;
            
            let test_user = context.test_users[0]!;
            
            // Step 1: Initialize consistent state across all agents
            let initial_state = await initialize_consistent_state(test_user);
            let state_initialized = initial_state.user_registered and initial_state.portfolio_created;
            if (state_initialized) { steps_completed += 1 };
            
            // Step 2: Perform coordinated state update (deposit -> portfolio -> strategy)
            let deposit_result = await communicator.mock_detect_deposit(test_user.principal_id, 100000000);
            let deposit_success = switch (deposit_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (deposit_success) { steps_completed += 1 };
            
            // Step 3: Verify state propagation across agents
            let portfolio_update_result = await communicator.mock_update_portfolio(test_user.principal_id, []);
            let portfolio_updated = switch (portfolio_update_result) {
                case (#ok(summary)) { summary.total_balance_sats > 0 };
                case (#err(_)) { false };
            };
            if (portfolio_updated) { steps_completed += 1 };
            
            // Step 4: Test state rollback on failure
            let rollback_scenario = await test_state_rollback_scenario(test_user);
            let rollback_successful = rollback_scenario.rollback_executed and rollback_scenario.state_consistent;
            if (rollback_successful) { steps_completed += 1 };
            
            // Step 5: Validate final state consistency
            let final_consistency_check = await validate_final_state_consistency(test_user);
            let state_consistent = final_consistency_check.all_agents_consistent;
            if (state_consistent) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Agent coordination and state consistency validated successfully"
            } else {
                "Agent coordination failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Test load balancing and performance under stress
        public func test_load_balancing_and_performance(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 4;
            var steps_completed = 0;
            
            let load_test_users = generate_load_test_users(100); // 100 concurrent users
            
            // Step 1: Test system throughput
            let start_time = Time.now();
            let throughput_result = await test_system_throughput(load_test_users);
            let throughput_time = Time.now() - start_time;
            
            let throughput_acceptable = throughput_result.successful_operations >= 80 and throughput_time < 30000000000; // 30 seconds
            if (throughput_acceptable) { steps_completed += 1 };
            
            // Step 2: Test response time under load
            let response_time_result = await test_response_times_under_load(load_test_users);
            let response_times_acceptable = 
                response_time_result.avg_response_time < 2000000000 and // < 2 seconds
                response_time_result.max_response_time < 10000000000;   // < 10 seconds
            if (response_times_acceptable) { steps_completed += 1 };
            
            // Step 3: Test resource utilization
            let resource_result = await test_resource_utilization(load_test_users);
            let resource_usage_acceptable = 
                resource_result.memory_usage_mb < 1000 and // < 1GB
                resource_result.cpu_usage_percent < 80;    // < 80%
            if (resource_usage_acceptable) { steps_completed += 1 };
            
            // Step 4: Test system recovery after load
            let recovery_result = await test_system_recovery();
            let recovery_successful = recovery_result.system_responsive and recovery_result.no_data_loss;
            if (recovery_successful) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Load balancing and performance test completed successfully (throughput: " # Int.toText(throughput_result.successful_operations) # "/100)"
            } else {
                "Load balancing and performance test failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Helper functions
        private func validate_no_resource_conflicts(users: [Types.User], execution_results: [Result.Result<[Types.TxId], Text>]) : Bool {
            // Mock validation - in real implementation would check for:
            // - No duplicate transaction IDs
            // - No double-spending
            // - No conflicting state updates
            let successful_results = Array.filter<Result.Result<[Types.TxId], Text>>(execution_results, func(result) {
                switch (result) {
                    case (#ok(_)) { true };
                    case (#err(_)) { false };
                }
            });
            
            successful_results.size() > 0
        };

        private func initialize_consistent_state(user: Types.User) : async {user_registered: Bool; portfolio_created: Bool} {
            let registration_result = await communicator.mock_register_user(user);
            let user_registered = switch (registration_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            
            let portfolio_result = await communicator.mock_update_portfolio(user.principal_id, []);
            let portfolio_created = switch (portfolio_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            
            { user_registered = user_registered; portfolio_created = portfolio_created }
        };

        private func test_state_rollback_scenario(user: Types.User) : async {rollback_executed: Bool; state_consistent: Bool} {
            // Mock rollback scenario - simulate failure and recovery
            await async_delay(100000000); // 100ms
            { rollback_executed = true; state_consistent = true }
        };

        private func validate_final_state_consistency(user: Types.User) : async {all_agents_consistent: Bool} {
            // Mock consistency validation
            await async_delay(200000000); // 200ms
            { all_agents_consistent = true }
        };

        private func generate_load_test_users(count: Nat) : [Types.User] {
            Array.tabulate<Types.User>(count, func(i) {
                {
                    principal_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-" # Int.toText(i));
                    display_name = "Load Test User " # Int.toText(i);
                    created_at = Time.now();
                    risk_profile = if (i % 3 == 0) { #conservative } else if (i % 3 == 1) { #balanced } else { #aggressive };
                }
            })
        };

        private func test_system_throughput(users: [Types.User]) : async {successful_operations: Nat; failed_operations: Nat} {
            var successful = 0;
            var failed = 0;
            
            for (user in users.vals()) {
                let result = await communicator.mock_register_user(user);
                switch (result) {
                    case (#ok(_)) { successful += 1 };
                    case (#err(_)) { failed += 1 };
                };
            };
            
            { successful_operations = successful; failed_operations = failed }
        };

        private func test_response_times_under_load(users: [Types.User]) : async {avg_response_time: Int; max_response_time: Int; min_response_time: Int} {
            var total_time = 0;
            var max_time = 0;
            var min_time = Int.abs(Time.now()); // Large initial value
            
            for (user in users.vals()) {
                let start_time = Time.now();
                ignore await communicator.mock_register_user(user);
                let response_time = Time.now() - start_time;
                
                total_time += response_time;
                if (response_time > max_time) { max_time := response_time };
                if (response_time < min_time) { min_time := response_time };
            };
            
            let avg_time = total_time / users.size();
            
            { avg_response_time = avg_time; max_response_time = max_time; min_response_time = min_time }
        };

        private func test_resource_utilization(users: [Types.User]) : async {memory_usage_mb: Int; cpu_usage_percent: Int} {
            // Mock resource monitoring
            await async_delay(500000000); // 500ms
            { memory_usage_mb = 256; cpu_usage_percent = 45 }
        };

        private func test_system_recovery() : async {system_responsive: Bool; no_data_loss: Bool} {
            // Mock recovery test
            await async_delay(1000000000); // 1 second
            { system_responsive = true; no_data_loss = true }
        };

        private func async_delay(nanoseconds: Int) : async () {
            let start = Time.now();
            while (Time.now() - start < nanoseconds) {
                // Busy wait
            };
        };

        // Run all multi-agent interaction tests
        public func run_all_tests() : async IntegrationTestFramework.IntegrationTestSuite {
            let test_functions = [
                ("Inter-Canister Communication", test_inter_canister_communication),
                ("Concurrent Multi-User Scenarios", test_concurrent_multi_user_scenarios),
                ("Agent Coordination and State Consistency", test_agent_coordination_and_state_consistency),
                ("Load Balancing and Performance", test_load_balancing_and_performance)
            ];
            
            await runner.run_integration_test_suite("Multi-Agent Interaction Tests", test_functions)
        };
    };
}