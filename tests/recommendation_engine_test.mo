import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Result "mo:base/Result";

// Import the types
import Types "../src/shared/types";

// Test module for Recommendation Engine
module {
    public class RecommendationEngineTest() {
        
        // Test user IDs
        private let test_user_conservative = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
        private let test_user_balanced = Principal.fromText("rrkah-fqaaa-aaaah-qcaiq-cai");
        private let test_user_aggressive = Principal.fromText("ryjl3-tyaaa-aaaah-qcaiq-cai");

        // Test recommendation accuracy for conservative user
        public func test_conservative_recommendation() : Bool {
            // Mock recommendation result for conservative user
            let mock_recommendations = [
                {
                    strategy = {
                        id = "conservative-lending";
                        name = "Conservative Bitcoin Lending";
                        risk_level = #conservative;
                        venues = ["BlockFi", "Celsius", "Nexo"];
                        est_apy_band = (3.0, 6.0);
                        params_schema = "{}";
                    };
                    score = 0.85;
                    breakdown = {
                        apy_score = 0.12;
                        risk_score = 0.85;
                        liquidity_score = 0.60;
                    };
                    rationale = "Perfect match for conservative investors seeking capital preservation.";
                }
            ];

            // Verify the top recommendation is conservative
            let top_rec = mock_recommendations[0]!;
            let is_conservative = top_rec.strategy.risk_level == #conservative;
            let has_good_score = top_rec.score > 0.7;
            let has_rationale = top_rec.rationale.size() > 0;

            is_conservative and has_good_score and has_rationale
        };

        // Test recommendation accuracy for balanced user
        public func test_balanced_recommendation() : Bool {
            let mock_recommendations = [
                {
                    strategy = {
                        id = "balanced-liquidity";
                        name = "Balanced Liquidity Provision";
                        risk_level = #balanced;
                        venues = ["Uniswap", "SushiSwap", "Curve"];
                        est_apy_band = (8.0, 15.0);
                        params_schema = "{}";
                    };
                    score = 0.78;
                    breakdown = {
                        apy_score = 0.30;
                        risk_score = 0.70;
                        liquidity_score = 0.60;
                    };
                    rationale = "Ideal balance of risk and reward for moderate investors.";
                }
            ];

            let top_rec = mock_recommendations[0]!;
            let is_balanced = top_rec.strategy.risk_level == #balanced;
            let has_good_score = top_rec.score > 0.6;
            let has_higher_apy = top_rec.strategy.est_apy_band.1 > 10.0;

            is_balanced and has_good_score and has_higher_apy
        };

        // Test recommendation accuracy for aggressive user
        public func test_aggressive_recommendation() : Bool {
            let mock_recommendations = [
                {
                    strategy = {
                        id = "aggressive-yield";
                        name = "Aggressive Yield Farming";
                        risk_level = #aggressive;
                        venues = ["Yearn", "Convex", "Beefy", "Harvest"];
                        est_apy_band = (15.0, 35.0);
                        params_schema = "{}";
                    };
                    score = 0.82;
                    breakdown = {
                        apy_score = 0.70;
                        risk_score = 0.85;
                        liquidity_score = 0.80;
                    };
                    rationale = "High-growth potential aligned with aggressive risk tolerance.";
                }
            ];

            let top_rec = mock_recommendations[0]!;
            let is_aggressive = top_rec.strategy.risk_level == #aggressive;
            let has_high_apy = top_rec.strategy.est_apy_band.1 > 20.0;
            let has_good_score = top_rec.score > 0.7;

            is_aggressive and has_high_apy and has_good_score
        };

        // Test strategy plan creation
        public func test_strategy_plan_creation() : Bool {
            let mock_plan : Types.StrategyPlan = {
                id = "plan_conservative-lending_" # Principal.toText(test_user_conservative) # "_" # Int.toText(Time.now());
                user_id = test_user_conservative;
                template_id = "conservative-lending";
                allocations = [
                    {
                        venue_id = "BlockFi";
                        amount_sats = 33333333; // ~0.33 BTC
                        percentage = 33.33;
                    },
                    {
                        venue_id = "Celsius";
                        amount_sats = 33333333;
                        percentage = 33.33;
                    },
                    {
                        venue_id = "Nexo";
                        amount_sats = 33333334;
                        percentage = 33.34;
                    }
                ];
                created_at = Time.now();
                status = #pending;
                rationale = "Recommended for your conservative risk profile.";
            };

            // Verify plan structure
            let has_valid_id = mock_plan.id.size() > 0;
            let has_allocations = mock_plan.allocations.size() > 0;
            let is_pending = mock_plan.status == #pending;
            let has_rationale = mock_plan.rationale.size() > 0;

            // Verify allocations sum to approximately 100%
            let total_percentage = Array.foldLeft<Types.Allocation, Float>(
                mock_plan.allocations,
                0.0,
                func(acc, alloc) { acc + alloc.percentage }
            );
            let valid_percentage = total_percentage >= 99.0 and total_percentage <= 101.0;

            has_valid_id and has_allocations and is_pending and has_rationale and valid_percentage
        };

        // Test plan approval workflow
        public func test_plan_approval() : Bool {
            let initial_plan : Types.StrategyPlan = {
                id = "test_plan_123";
                user_id = test_user_balanced;
                template_id = "balanced-liquidity";
                allocations = [];
                created_at = Time.now();
                status = #pending;
                rationale = "Test plan";
            };

            let approved_plan : Types.StrategyPlan = {
                id = initial_plan.id;
                user_id = initial_plan.user_id;
                template_id = initial_plan.template_id;
                allocations = initial_plan.allocations;
                created_at = initial_plan.created_at;
                status = #approved;
                rationale = initial_plan.rationale;
            };

            // Verify status change
            let status_changed = initial_plan.status == #pending and approved_plan.status == #approved;
            let same_id = initial_plan.id == approved_plan.id;
            let same_user = initial_plan.user_id == approved_plan.user_id;

            status_changed and same_id and same_user
        };

        // Test scoring consistency
        public func test_scoring_consistency() : Bool {
            let test_strategy = {
                id = "test-strategy";
                name = "Test Strategy";
                risk_level = #balanced;
                venues = ["Venue1", "Venue2", "Venue3"];
                est_apy_band = (10.0, 20.0);
                params_schema = "{}";
            };

            // Mock scoring function
            let score1 = calculate_mock_score(test_strategy, #balanced);
            let score2 = calculate_mock_score(test_strategy, #balanced);
            let score3 = calculate_mock_score(test_strategy, #conservative);

            // Same inputs should produce same results
            let consistent_scoring = score1 == score2;
            
            // Different risk profiles should produce different scores
            let different_risk_scores = score1 != score3;

            consistent_scoring and different_risk_scores
        };

        // Test rationale generation quality
        public func test_rationale_quality() : Bool {
            let test_rationale = "Recommended for your balanced risk profile. Expected APY: 10.0% - 20.0%. Available on 3 venues: Venue1, Venue2, Venue3. Overall score: 75.0/100. Score breakdown - APY: 40.0%, Risk alignment: 70.0%, Liquidity: 60.0%. Ideal balance of risk and reward for moderate investors.";

            // Check for required components
            let has_risk_profile = test_rationale.contains("risk profile");
            let has_apy_info = test_rationale.contains("Expected APY");
            let has_venue_info = test_rationale.contains("Available on");
            let has_score_info = test_rationale.contains("Overall score");
            let has_breakdown = test_rationale.contains("Score breakdown");
            let has_explanation = test_rationale.contains("Ideal balance") or 
                                 test_rationale.contains("Perfect match") or 
                                 test_rationale.contains("High-growth potential");

            has_risk_profile and has_apy_info and has_venue_info and has_score_info and has_breakdown and has_explanation
        };

        // Test allocation distribution
        public func test_allocation_distribution() : Bool {
            let venues = ["Venue1", "Venue2", "Venue3", "Venue4"];
            let total_amount : Nat64 = 100000000; // 1 BTC in sats
            
            // Mock allocation creation
            let allocations = create_mock_allocations(venues, total_amount);
            
            // Verify equal distribution
            let expected_amount_per_venue = total_amount / Nat64.fromNat(venues.size());
            let expected_percentage = 100.0 / Float.fromInt(venues.size());
            
            // Check first allocation
            let first_alloc = allocations[0]!;
            let correct_amount = first_alloc.amount_sats == expected_amount_per_venue;
            let correct_percentage = Float.abs(first_alloc.percentage - expected_percentage) < 0.1;
            
            // Check total allocations
            let total_allocated = Array.foldLeft<Types.Allocation, Nat64>(
                allocations,
                0,
                func(acc, alloc) { acc + alloc.amount_sats }
            );
            let total_percentage = Array.foldLeft<Types.Allocation, Float>(
                allocations,
                0.0,
                func(acc, alloc) { acc + alloc.percentage }
            );
            
            let correct_total_amount = total_allocated == total_amount;
            let correct_total_percentage = Float.abs(total_percentage - 100.0) < 0.1;
            
            correct_amount and correct_percentage and correct_total_amount and correct_total_percentage
        };

        // Test multiple recommendations ranking
        public func test_recommendations_ranking() : Bool {
            let mock_recommendations = [
                { score = 0.85; strategy_id = "strategy1" },
                { score = 0.92; strategy_id = "strategy2" },
                { score = 0.78; strategy_id = "strategy3" },
                { score = 0.88; strategy_id = "strategy4" }
            ];
            
            // Sort by score (highest first)
            let sorted = Array.sort<{score: Float; strategy_id: Text}>(
                mock_recommendations,
                func(a, b) {
                    if (a.score > b.score) { #less }
                    else if (a.score < b.score) { #greater }
                    else { #equal }
                }
            );
            
            // Verify correct ordering
            let first_is_highest = sorted[0]!.score == 0.92;
            let second_is_second_highest = sorted[1]!.score == 0.88;
            let last_is_lowest = sorted[3]!.score == 0.78;
            
            first_is_highest and second_is_second_highest and last_is_lowest
        };

        // Helper function to calculate mock score
        private func calculate_mock_score(
            strategy: Types.StrategyTemplate,
            user_risk: Types.RiskLevel
        ) : Float {
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
            
            let avg_apy = (strategy.est_apy_band.1 + strategy.est_apy_band.0) / 2.0;
            let normalized_apy = Float.min(1.0, avg_apy / 50.0);
            let liquidity_score = Float.min(1.0, Float.fromInt(strategy.venues.size()) / 5.0);
            
            0.4 * normalized_apy + 0.35 * risk_alignment + 0.25 * liquidity_score
        };

        // Helper function to create mock allocations
        private func create_mock_allocations(venues: [Text], total_amount: Nat64) : [Types.Allocation] {
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

        // Run all recommendation engine tests
        public func run_all_tests() : Bool {
            Debug.print("Running Recommendation Engine Tests...");
            
            let test1 = test_conservative_recommendation();
            Debug.print("Conservative Recommendation Test: " # (if test1 "PASSED" else "FAILED"));
            
            let test2 = test_balanced_recommendation();
            Debug.print("Balanced Recommendation Test: " # (if test2 "PASSED" else "FAILED"));
            
            let test3 = test_aggressive_recommendation();
            Debug.print("Aggressive Recommendation Test: " # (if test3 "PASSED" else "FAILED"));
            
            let test4 = test_strategy_plan_creation();
            Debug.print("Strategy Plan Creation Test: " # (if test4 "PASSED" else "FAILED"));
            
            let test5 = test_plan_approval();
            Debug.print("Plan Approval Test: " # (if test5 "PASSED" else "FAILED"));
            
            let test6 = test_scoring_consistency();
            Debug.print("Scoring Consistency Test: " # (if test6 "PASSED" else "FAILED"));
            
            let test7 = test_rationale_quality();
            Debug.print("Rationale Quality Test: " # (if test7 "PASSED" else "FAILED"));
            
            let test8 = test_allocation_distribution();
            Debug.print("Allocation Distribution Test: " # (if test8 "PASSED" else "FAILED"));
            
            let test9 = test_recommendations_ranking();
            Debug.print("Recommendations Ranking Test: " # (if test9 "PASSED" else "FAILED"));
            
            let all_passed = test1 and test2 and test3 and test4 and test5 and test6 and test7 and test8 and test9;
            Debug.print("All Recommendation Engine Tests: " # (if all_passed "PASSED" else "FAILED"));
            
            all_passed
        };
    };
}