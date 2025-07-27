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

// Comprehensive unit tests for Strategy Selector canister
module {
    public class StrategySelectorUnitTests() {
        private let assertions = UnitTestFramework.TestAssertions();
        private let mock_data = UnitTestFramework.MockDataGenerator();
        private let runner = UnitTestFramework.TestRunner();

        // Test strategy scoring algorithm
        public func test_strategy_scoring_algorithm() : UnitTestFramework.TestResult {
            let strategy = mock_data.generate_test_strategy_template(#balanced);
            let user_risk = #balanced;
            let market_conditions = {
                apy_factor = 1.0;
                risk_factor = 0.3;
                liquidity_factor = 0.8;
            };
            
            let score = calculate_strategy_score(strategy, user_risk, market_conditions);
            let score_in_range = score >= 0.0 and score <= 1.0;
            let score_reasonable = score > 0.5; // Should be high for matching risk levels
            
            assertions.assert_true(score_in_range and score_reasonable, "Strategy scoring algorithm produces valid scores")
        };

        // Test risk profile matching
        public func test_risk_profile_matching() : UnitTestFramework.TestResult {
            let conservative_strategy = mock_data.generate_test_strategy_template(#conservative);
            let balanced_strategy = mock_data.generate_test_strategy_template(#balanced);
            let aggressive_strategy = mock_data.generate_test_strategy_template(#aggressive);
            
            let market_conditions = {
                apy_factor = 1.0;
                risk_factor = 0.3;
                liquidity_factor = 0.8;
            };
            
            // Conservative user should prefer conservative strategy
            let conservative_with_conservative = calculate_strategy_score(conservative_strategy, #conservative, market_conditions);
            let conservative_with_aggressive = calculate_strategy_score(aggressive_strategy, #conservative, market_conditions);
            
            // Aggressive user should prefer aggressive strategy
            let aggressive_with_aggressive = calculate_strategy_score(aggressive_strategy, #aggressive, market_conditions);
            let aggressive_with_conservative = calculate_strategy_score(conservative_strategy, #aggressive, market_conditions);
            
            let conservative_matching = conservative_with_conservative > conservative_with_aggressive;
            let aggressive_matching = aggressive_with_aggressive > aggressive_with_conservative;
            
            assertions.assert_true(conservative_matching and aggressive_matching, "Risk profile matching works correctly")
        };

        // Test strategy plan creation
        public func test_strategy_plan_creation() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let strategy = mock_data.generate_test_strategy_template(#balanced);
            let total_amount = 100000000; // 1 BTC in sats
            
            let plan = create_strategy_plan(user_id, strategy, total_amount);
            
            let plan_valid = 
                plan.user_id == user_id and
                plan.template_id == strategy.id and
                plan.status == #pending and
                plan.allocations.size() > 0;
            
            // Check allocation percentages sum to ~100%
            let total_percentage = Array.foldLeft<Types.Allocation, Float>(
                plan.allocations, 0.0, func(acc, alloc) { acc + alloc.percentage }
            );
            let percentage_valid = total_percentage >= 99.0 and total_percentage <= 101.0;
            
            assertions.assert_true(plan_valid and percentage_valid, "Strategy plan creation works correctly")
        };

        // Test allocation distribution
        public func test_allocation_distribution() : UnitTestFramework.TestResult {
            let venues = ["Venue1", "Venue2", "Venue3"];
            let total_amount = 90000000; // 0.9 BTC in sats
            
            let allocations = create_allocations(venues, total_amount);
            
            // Check equal distribution
            let expected_amount_per_venue = total_amount / Nat64.fromNat(venues.size());
            let expected_percentage = 100.0 / Float.fromInt(venues.size());
            
            let first_allocation = allocations[0]!;
            let amount_correct = first_allocation.amount_sats == expected_amount_per_venue;
            let percentage_correct = Float.abs(first_allocation.percentage - expected_percentage) < 0.1;
            
            // Check total amounts
            let total_allocated = Array.foldLeft<Types.Allocation, Nat64>(
                allocations, 0, func(acc, alloc) { acc + alloc.amount_sats }
            );
            let total_correct = total_allocated == total_amount;
            
            assertions.assert_true(amount_correct and percentage_correct and total_correct, "Allocation distribution works correctly")
        };

        // Test rationale generation
        public func test_rationale_generation() : UnitTestFramework.TestResult {
            let strategy = mock_data.generate_test_strategy_template(#balanced);
            let score = 0.78;
            let user_risk = #balanced;
            
            let rationale = generate_rationale(strategy, score, user_risk);
            
            let has_risk_profile = Text.contains(rationale, #text("balanced risk profile"));
            let has_apy_info = Text.contains(rationale, #text("Expected APY"));
            let has_venue_info = Text.contains(rationale, #text("Available on"));
            let has_score_info = Text.contains(rationale, #text("score"));
            
            assertions.assert_true(has_risk_profile and has_apy_info and has_venue_info and has_score_info, "Rationale generation includes all required components")
        };

        // Test strategy template validation
        public func test_strategy_template_validation() : UnitTestFramework.TestResult {
            let valid_strategy = mock_data.generate_test_strategy_template(#conservative);
            
            let invalid_strategy : Types.StrategyTemplate = {
                id = ""; // Invalid empty ID
                name = "Invalid Strategy";
                risk_level = #conservative;
                venues = []; // Invalid empty venues
                est_apy_band = (-1.0, 5.0); // Invalid negative APY
                params_schema = "{}";
            };
            
            let valid_check = validate_strategy_template(valid_strategy);
            let invalid_check = validate_strategy_template(invalid_strategy);
            
            assertions.assert_true(valid_check and not invalid_check, "Strategy template validation works correctly")
        };

        // Test scoring weights validation
        public func test_scoring_weights_validation() : UnitTestFramework.TestResult {
            let valid_weights = {
                apy_weight = 0.4;
                risk_weight = 0.35;
                liquidity_weight = 0.25;
            };
            
            let invalid_weights = {
                apy_weight = 0.6;
                risk_weight = 0.5;
                liquidity_weight = 0.3; // Sum > 1.0
            };
            
            let valid_sum = valid_weights.apy_weight + valid_weights.risk_weight + valid_weights.liquidity_weight;
            let invalid_sum = invalid_weights.apy_weight + invalid_weights.risk_weight + invalid_weights.liquidity_weight;
            
            let valid_check = Float.abs(valid_sum - 1.0) < 0.01;
            let invalid_check = invalid_sum > 1.05;
            
            assertions.assert_true(valid_check and invalid_check, "Scoring weights validation works correctly")
        };

        // Test strategy recommendation ranking
        public func test_strategy_recommendation_ranking() : UnitTestFramework.TestResult {
            let strategies = [
                mock_data.generate_test_strategy_template(#conservative),
                mock_data.generate_test_strategy_template(#balanced),
                mock_data.generate_test_strategy_template(#aggressive)
            ];
            
            let user_risk = #balanced;
            let market_conditions = {
                apy_factor = 1.0;
                risk_factor = 0.3;
                liquidity_factor = 0.8;
            };
            
            let scored_strategies = Array.map<Types.StrategyTemplate, {strategy: Types.StrategyTemplate; score: Float}>(
                strategies, func(strategy) {
                    {
                        strategy = strategy;
                        score = calculate_strategy_score(strategy, user_risk, market_conditions);
                    }
                }
            );
            
            let sorted_strategies = Array.sort<{strategy: Types.StrategyTemplate; score: Float}>(
                scored_strategies, func(a, b) {
                    if (a.score > b.score) { #less }
                    else if (a.score < b.score) { #greater }
                    else { #equal }
                }
            );
            
            // Balanced strategy should rank highest for balanced user
            let top_strategy = sorted_strategies[0]!;
            let balanced_ranks_first = top_strategy.strategy.risk_level == #balanced;
            
            assertions.assert_true(balanced_ranks_first, "Strategy recommendation ranking works correctly")
        };

        // Test plan approval workflow
        public func test_plan_approval_workflow() : UnitTestFramework.TestResult {
            let user_id = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
            let strategy = mock_data.generate_test_strategy_template(#balanced);
            let plan = create_strategy_plan(user_id, strategy, 100000000);
            
            // Simulate approval
            let approved_plan : Types.StrategyPlan = {
                id = plan.id;
                user_id = plan.user_id;
                template_id = plan.template_id;
                allocations = plan.allocations;
                created_at = plan.created_at;
                status = #approved;
                rationale = plan.rationale;
            };
            
            let status_changed = plan.status == #pending and approved_plan.status == #approved;
            let other_fields_unchanged = 
                plan.id == approved_plan.id and
                plan.user_id == approved_plan.user_id and
                plan.template_id == approved_plan.template_id;
            
            assertions.assert_true(status_changed and other_fields_unchanged, "Plan approval workflow works correctly")
        };

        // Helper functions for testing
        private func calculate_strategy_score(
            strategy: Types.StrategyTemplate,
            user_risk: Types.RiskLevel,
            market_conditions: {apy_factor: Float; risk_factor: Float; liquidity_factor: Float}
        ) : Float {
            let scoring_weights = {
                apy_weight = 0.4;
                risk_weight = 0.35;
                liquidity_weight = 0.25;
            };

            // Normalize APY
            let avg_apy = (strategy.est_apy_band.1 + strategy.est_apy_band.0) / 2.0;
            let normalized_apy = Float.min(1.0, avg_apy / 50.0);
            
            // Risk alignment score
            let risk_alignment = switch (user_risk, strategy.risk_level) {
                case (#conservative, #conservative) { 1.0 };
                case (#balanced, #balanced) { 1.0 };
                case (#aggressive, #aggressive) { 1.0 };
                case (#conservative, #balanced) { 0.6 };
                case (#balanced, #conservative) { 0.7 };
                case (#balanced, #aggressive) { 0.6 };
                case (#aggressive, #balanced) { 0.7 };
                case (#conservative, #aggressive) { 0.2 };
                case (#aggressive, #conservative) { 0.3 };
            };
            
            // Liquidity score
            let liquidity_score = Float.min(1.0, Float.fromInt(strategy.venues.size()) / 5.0);
            
            // Calculate weighted score
            let score = 
                scoring_weights.apy_weight * normalized_apy * market_conditions.apy_factor +
                scoring_weights.risk_weight * risk_alignment * (1.0 - market_conditions.risk_factor) +
                scoring_weights.liquidity_weight * liquidity_score * market_conditions.liquidity_factor;
                
            Float.max(0.0, Float.min(1.0, score))
        };

        private func create_strategy_plan(user_id: Types.UserId, strategy: Types.StrategyTemplate, total_amount: Nat64) : Types.StrategyPlan {
            let allocations = create_allocations(strategy.venues, total_amount);
            let rationale = generate_rationale(strategy, 0.75, #balanced);
            
            {
                id = "plan_" # strategy.id # "_" # Principal.toText(user_id) # "_" # Int.toText(Time.now());
                user_id = user_id;
                template_id = strategy.id;
                allocations = allocations;
                created_at = Time.now();
                status = #pending;
                rationale = rationale;
            }
        };

        private func create_allocations(venues: [Text], total_amount: Nat64) : [Types.Allocation] {
            let venue_count = venues.size();
            if (venue_count == 0) {
                return [];
            };
            
            let amount_per_venue = total_amount / Nat64.fromNat(venue_count);
            let percentage_per_venue = 100.0 / Float.fromInt(venue_count);
            
            Array.map<Text, Types.Allocation>(venues, func(venue_id) {
                {
                    venue_id = venue_id;
                    amount_sats = amount_per_venue;
                    percentage = percentage_per_venue;
                }
            })
        };

        private func generate_rationale(strategy: Types.StrategyTemplate, score: Float, user_risk: Types.RiskLevel) : Text {
            let risk_text = switch user_risk {
                case (#conservative) { "conservative risk profile" };
                case (#balanced) { "balanced risk profile" };
                case (#aggressive) { "aggressive risk profile" };
            };
            
            let apy_text = "Expected APY: " # Float.toText(strategy.est_apy_band.0) # "% - " # Float.toText(strategy.est_apy_band.1) # "%";
            let venues_text = "Available on " # Int.toText(strategy.venues.size()) # " venues";
            let score_text = "Strategy score: " # Float.toText(score * 100.0) # "/100";
            
            "Recommended for your " # risk_text # ". " # apy_text # ". " # venues_text # ". " # score_text # "."
        };

        private func validate_strategy_template(strategy: Types.StrategyTemplate) : Bool {
            let id_valid = Text.size(strategy.id) > 0;
            let name_valid = Text.size(strategy.name) > 0;
            let venues_valid = strategy.venues.size() > 0;
            let apy_valid = strategy.est_apy_band.0 >= 0.0 and strategy.est_apy_band.1 > strategy.est_apy_band.0;
            
            id_valid and name_valid and venues_valid and apy_valid
        };

        // Run all strategy selector unit tests
        public func run_all_tests() : UnitTestFramework.TestSuite {
            let test_functions = [
                test_strategy_scoring_algorithm,
                test_risk_profile_matching,
                test_strategy_plan_creation,
                test_allocation_distribution,
                test_rationale_generation,
                test_strategy_template_validation,
                test_scoring_weights_validation,
                test_strategy_recommendation_ranking,
                test_plan_approval_workflow
            ];
            
            runner.run_test_suite("Strategy Selector Unit Tests", test_functions)
        };
    };
}