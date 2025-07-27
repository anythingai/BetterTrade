import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Text "mo:base/Text";
import Result "mo:base/Result";
import Principal "mo:base/Principal";

import Types "../src/shared/types";
import IntegrationTestFramework "./integration_test_framework";

// End-to-end workflow integration tests
module {
    public class EndToEndWorkflowTests() {
        private let runner = IntegrationTestFramework.IntegrationTestRunner();
        private let communicator = IntegrationTestFramework.MockInterCanisterCommunicator();
        private let data_generator = IntegrationTestFramework.IntegrationTestDataGenerator();
        private let validator = IntegrationTestFramework.WorkflowValidator();

        // Test complete user onboarding workflow
        public func test_complete_user_onboarding_workflow(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 5;
            var steps_completed = 0;
            
            let test_user = context.test_users[0]!;
            
            // Step 1: Register user
            let registration_result = await communicator.mock_register_user(test_user);
            let registration_success = switch (registration_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (registration_success) { steps_completed += 1 };
            
            // Step 2: Link wallet
            let test_wallet = context.test_wallets[0]!;
            let wallet_result = await communicator.mock_link_wallet(test_user.principal_id, test_wallet);
            let wallet_success = switch (wallet_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (wallet_success) { steps_completed += 1 };
            
            // Step 3: Detect deposit
            let deposit_scenario = data_generator.generate_test_deposit_scenario(test_user);
            let deposit_result = await communicator.mock_detect_deposit(test_user.principal_id, deposit_scenario.deposit_amount);
            let deposit_success = switch (deposit_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (deposit_success) { steps_completed += 1 };
            
            // Step 4: Update portfolio state
            let portfolio_result = await communicator.mock_update_portfolio(test_user.principal_id, []);
            let portfolio_success = switch (portfolio_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (portfolio_success) { steps_completed += 1 };
            
            // Step 5: Validate complete workflow
            let final_wallet = test_wallet;
            let workflow_validation = validator.validate_user_onboarding_workflow(test_user, final_wallet, deposit_result);
            if (workflow_validation.valid) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Complete user onboarding workflow executed successfully"
            } else {
                "User onboarding workflow failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Test complete strategy recommendation and approval workflow
        public func test_strategy_recommendation_workflow(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 4;
            var steps_completed = 0;
            
            let test_user = context.test_users[1]!; // Balanced risk user
            
            // Step 1: Request strategy recommendation
            let recommendation_result = await communicator.mock_recommend_strategy(test_user.principal_id, test_user.risk_profile);
            let recommendation_success = switch (recommendation_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (recommendation_success) { steps_completed += 1 };
            
            // Step 2: Validate recommendation matches user risk profile
            let recommended_plan = switch (recommendation_result) {
                case (#ok(plan)) { plan };
                case (#err(_)) { 
                    return {
                        passed = false;
                        message = "Failed to get strategy recommendation";
                        steps_completed = steps_completed;
                        total_steps = total_steps;
                    };
                };
            };
            
            let strategy_scenario = data_generator.generate_test_strategy_scenario(test_user);
            let recommendation_valid = recommended_plan.template_id == strategy_scenario.recommended_strategy_id;
            if (recommendation_valid) { steps_completed += 1 };
            
            // Step 3: Approve strategy plan
            let approved_plan : Types.StrategyPlan = {
                id = recommended_plan.id;
                user_id = recommended_plan.user_id;
                template_id = recommended_plan.template_id;
                allocations = recommended_plan.allocations;
                created_at = recommended_plan.created_at;
                status = #approved;
                rationale = recommended_plan.rationale;
            };
            
            let approval_valid = approved_plan.status == #approved;
            if (approval_valid) { steps_completed += 1 };
            
            // Step 4: Validate complete workflow
            let workflow_validation = validator.validate_strategy_recommendation_workflow(test_user, recommended_plan, approved_plan);
            if (workflow_validation.valid) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Strategy recommendation workflow executed successfully"
            } else {
                "Strategy recommendation workflow failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Test complete strategy execution workflow
        public func test_strategy_execution_workflow(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 5;
            var steps_completed = 0;
            
            let test_user = context.test_users[2]!; // Aggressive risk user
            
            // Step 1: Create approved strategy plan
            let approved_plan : Types.StrategyPlan = {
                id = "test_execution_plan";
                user_id = test_user.principal_id;
                template_id = "integration-aggressive";
                allocations = [
                    { venue_id = "TestVenue1"; amount_sats = 25000000; percentage = 25.0 },
                    { venue_id = "TestVenue2"; amount_sats = 25000000; percentage = 25.0 },
                    { venue_id = "TestVenue3"; amount_sats = 25000000; percentage = 25.0 },
                    { venue_id = "TestVenue4"; amount_sats = 25000000; percentage = 25.0 }
                ];
                created_at = Time.now();
                status = #approved;
                rationale = "Test execution workflow";
            };
            steps_completed += 1;
            
            // Step 2: Execute strategy
            let execution_result = await communicator.mock_execute_strategy(approved_plan);
            let execution_success = switch (execution_result) {
                case (#ok(tx_ids)) { tx_ids.size() > 0 };
                case (#err(_)) { false };
            };
            if (execution_success) { steps_completed += 1 };
            
            // Step 3: Get transaction IDs
            let tx_ids = switch (execution_result) {
                case (#ok(ids)) { ids };
                case (#err(_)) { [] };
            };
            
            let tx_count_valid = tx_ids.size() == approved_plan.allocations.size();
            if (tx_count_valid) { steps_completed += 1 };
            
            // Step 4: Update portfolio state
            let portfolio_result = await communicator.mock_update_portfolio(test_user.principal_id, tx_ids);
            let portfolio_success = switch (portfolio_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (portfolio_success) { steps_completed += 1 };
            
            // Step 5: Validate complete execution workflow
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
            
            let workflow_validation = validator.validate_execution_workflow(approved_plan, execution_result, portfolio_summary);
            if (workflow_validation.valid) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Strategy execution workflow executed successfully"
            } else {
                "Strategy execution workflow failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Test complete risk monitoring workflow
        public func test_risk_monitoring_workflow(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 4;
            var steps_completed = 0;
            
            let test_user = context.test_users[0]!;
            
            // Step 1: Create portfolio with positions
            let portfolio : Types.PortfolioSummary = {
                user_id = test_user.principal_id;
                total_balance_sats = 80000000; // 0.8 BTC (down from 1 BTC)
                total_value_usd = 33600.0; // Down from $42,000
                positions = [
                    {
                        user_id = test_user.principal_id;
                        venue_id = "TestVenue1";
                        amount_sats = 40000000;
                        entry_price = 42000.0;
                        current_value = 40000.0; // Price dropped
                        pnl = -2000.0; // Loss
                    },
                    {
                        user_id = test_user.principal_id;
                        venue_id = "TestVenue2";
                        amount_sats = 40000000;
                        entry_price = 42000.0;
                        current_value = 40000.0;
                        pnl = -2000.0; // Loss
                    }
                ];
                pnl_24h = -4000.0; // Total loss
                active_strategy = ?"integration-conservative";
            };
            steps_completed += 1;
            
            // Step 2: Monitor risk
            let risk_result = await communicator.mock_monitor_risk(test_user.principal_id, portfolio);
            let risk_monitoring_success = switch (risk_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (risk_monitoring_success) { steps_completed += 1 };
            
            // Step 3: Check for protective actions
            let protective_intent = switch (risk_result) {
                case (#ok(intent_opt)) { intent_opt };
                case (#err(_)) { null };
            };
            
            // For this test scenario, no protective action should be triggered
            let no_action_needed = protective_intent == null;
            if (no_action_needed) { steps_completed += 1 };
            
            // Step 4: Validate risk monitoring workflow
            let risk_monitoring_valid = risk_monitoring_success and no_action_needed;
            if (risk_monitoring_valid) { steps_completed += 1 };
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Risk monitoring workflow executed successfully"
            } else {
                "Risk monitoring workflow failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Test complete multi-agent interaction workflow
        public func test_multi_agent_interaction_workflow(context: IntegrationTestFramework.TestContext) : async {passed: Bool; message: Text; steps_completed: Nat; total_steps: Nat} {
            let total_steps = 8;
            var steps_completed = 0;
            
            let test_user = context.test_users[1]!; // Balanced risk user
            
            // Step 1: User registration (User Registry)
            let registration_result = await communicator.mock_register_user(test_user);
            let registration_success = switch (registration_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (registration_success) { steps_completed += 1 };
            
            // Step 2: Wallet linking (User Registry)
            let test_wallet = context.test_wallets[1]!;
            let wallet_result = await communicator.mock_link_wallet(test_user.principal_id, test_wallet);
            let wallet_success = switch (wallet_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (wallet_success) { steps_completed += 1 };
            
            // Step 3: Deposit detection (Portfolio State)
            let deposit_result = await communicator.mock_detect_deposit(test_user.principal_id, 100000000);
            let deposit_success = switch (deposit_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (deposit_success) { steps_completed += 1 };
            
            // Step 4: Strategy recommendation (Strategy Selector)
            let recommendation_result = await communicator.mock_recommend_strategy(test_user.principal_id, test_user.risk_profile);
            let recommendation_success = switch (recommendation_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (recommendation_success) { steps_completed += 1 };
            
            // Step 5: Strategy approval (Strategy Selector)
            let recommended_plan = switch (recommendation_result) {
                case (#ok(plan)) { plan };
                case (#err(_)) { 
                    return {
                        passed = false;
                        message = "Failed to get strategy recommendation";
                        steps_completed = steps_completed;
                        total_steps = total_steps;
                    };
                };
            };
            
            let approved_plan : Types.StrategyPlan = {
                id = recommended_plan.id;
                user_id = recommended_plan.user_id;
                template_id = recommended_plan.template_id;
                allocations = recommended_plan.allocations;
                created_at = recommended_plan.created_at;
                status = #approved;
                rationale = recommended_plan.rationale;
            };
            steps_completed += 1;
            
            // Step 6: Strategy execution (Execution Agent)
            let execution_result = await communicator.mock_execute_strategy(approved_plan);
            let execution_success = switch (execution_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (execution_success) { steps_completed += 1 };
            
            // Step 7: Portfolio update (Portfolio State)
            let tx_ids = switch (execution_result) {
                case (#ok(ids)) { ids };
                case (#err(_)) { [] };
            };
            
            let portfolio_result = await communicator.mock_update_portfolio(test_user.principal_id, tx_ids);
            let portfolio_success = switch (portfolio_result) {
                case (#ok(_)) { true };
                case (#err(_)) { false };
            };
            if (portfolio_success) { steps_completed += 1 };
            
            // Step 8: Risk monitoring (Risk Guard)
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
            
            let all_steps_passed = steps_completed == total_steps;
            let message = if (all_steps_passed) {
                "Multi-agent interaction workflow executed successfully across all canisters"
            } else {
                "Multi-agent interaction workflow failed at step " # Int.toText(steps_completed + 1)
            };
            
            {
                passed = all_steps_passed;
                message = message;
                steps_completed = steps_completed;
                total_steps = total_steps;
            }
        };

        // Run all end-to-end workflow tests
        public func run_all_tests() : async IntegrationTestFramework.IntegrationTestSuite {
            let test_functions = [
                ("Complete User Onboarding Workflow", test_complete_user_onboarding_workflow),
                ("Strategy Recommendation Workflow", test_strategy_recommendation_workflow),
                ("Strategy Execution Workflow", test_strategy_execution_workflow),
                ("Risk Monitoring Workflow", test_risk_monitoring_workflow),
                ("Multi-Agent Interaction Workflow", test_multi_agent_interaction_workflow)
            ];
            
            await runner.run_integration_test_suite("End-to-End Workflow Tests", test_functions)
        };
    };
}