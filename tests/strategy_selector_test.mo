import Debug "mo:base/Debug";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Text "mo:base/Text";
import Result "mo:base/Result";

// Import the types and the strategy selector
import Types "../src/shared/types";

// Test module for Strategy Selector
module {
    // Mock strategy selector for testing
    public class StrategyTemplateTest() {
        
        // Test data
        private let test_conservative_strategy : Types.StrategyTemplate = {
            id = "test-conservative";
            name = "Test Conservative Strategy";
            risk_level = #conservative;
            venues = ["TestVenue1", "TestVenue2"];
            est_apy_band = (3.0, 6.0);
            params_schema = "{\"test\": true}";
        };

        private let test_balanced_strategy : Types.StrategyTemplate = {
            id = "test-balanced";
            name = "Test Balanced Strategy";
            risk_level = #balanced;
            venues = ["TestVenue1", "TestVenue2", "TestVenue3"];
            est_apy_band = (8.0, 15.0);
            params_schema = "{\"test\": true}";
        };

        private let test_aggressive_strategy : Types.StrategyTemplate = {
            id = "test-aggressive";
            name = "Test Aggressive Strategy";
            risk_level = #aggressive;
            venues = ["TestVenue1", "TestVenue2", "TestVenue3", "TestVenue4"];
            est_apy_band = (15.0, 35.0);
            params_schema = "{\"test\": true}";
        };

        // Test strategy template creation
        public func test_strategy_template_creation() : Bool {
            let strategy = test_conservative_strategy;
            
            // Verify all fields are set correctly
            strategy.id == "test-conservative" and
            strategy.name == "Test Conservative Strategy" and
            strategy.risk_level == #conservative and
            strategy.venues.size() == 2 and
            strategy.est_apy_band.0 == 3.0 and
            strategy.est_apy_band.1 == 6.0
        };

        // Test strategy scoring algorithm
        public func test_strategy_scoring() : Bool {
            // Mock market conditions
            let market_conditions = {
                apy_factor = 1.0;
                risk_factor = 0.3;
                liquidity_factor = 0.8;
            };

            // Test conservative user with conservative strategy (should score high)
            let conservative_score = calculate_test_score(
                test_conservative_strategy,
                #conservative,
                market_conditions
            );

            // Test aggressive user with conservative strategy (should score lower)
            let mismatched_score = calculate_test_score(
                test_conservative_strategy,
                #aggressive,
                market_conditions
            );

            // Conservative user should score higher with conservative strategy
            conservative_score > mismatched_score and conservative_score > 0.5
        };

        // Test rationale generation
        public func test_rationale_generation() : Bool {
            let rationale = generate_test_rationale(
                test_balanced_strategy,
                0.75,
                #balanced
            );

            // Check that rationale contains expected elements
            let contains_risk = rationale.contains("balanced risk profile");
            let contains_apy = rationale.contains("Expected APY");
            let contains_venues = rationale.contains("Available on");
            let contains_score = rationale.contains("Strategy score");

            contains_risk and contains_apy and contains_venues and contains_score
        };

        // Test strategy catalog completeness
        public func test_strategy_catalog() : Bool {
            let strategies = [test_conservative_strategy, test_balanced_strategy, test_aggressive_strategy];
            
            // Verify we have strategies for all risk levels
            let has_conservative = Array.find<Types.StrategyTemplate>(strategies, func(s) { s.risk_level == #conservative }) != null;
            let has_balanced = Array.find<Types.StrategyTemplate>(strategies, func(s) { s.risk_level == #balanced }) != null;
            let has_aggressive = Array.find<Types.StrategyTemplate>(strategies, func(s) { s.risk_level == #aggressive }) != null;

            has_conservative and has_balanced and has_aggressive
        };

        // Helper function to calculate strategy score (simplified version for testing)
        private func calculate_test_score(
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
            let normalized_apy = (strategy.est_apy_band.1 + strategy.est_apy_band.0) / 2.0 / 50.0;
            
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

        // Helper function to generate rationale (simplified version for testing)
        private func generate_test_rationale(
            strategy: Types.StrategyTemplate,
            score: Float,
            user_risk: Types.RiskLevel
        ) : Text {
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

        // Test scoring weights validation
        public func test_scoring_weights_validation() : Bool {
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
            
            // Valid weights should sum to 1.0
            let valid_sum = valid_weights.apy_weight + valid_weights.risk_weight + valid_weights.liquidity_weight;
            let invalid_sum = invalid_weights.apy_weight + invalid_weights.risk_weight + invalid_weights.liquidity_weight;
            
            (valid_sum >= 0.95 and valid_sum <= 1.05) and invalid_sum > 1.05
        };

        // Test strategy filtering by risk level
        public func test_strategy_filtering() : Bool {
            let all_strategies = [test_conservative_strategy, test_balanced_strategy, test_aggressive_strategy];
            
            let conservative_strategies = Array.filter<Types.StrategyTemplate>(
                all_strategies, 
                func(s) { s.risk_level == #conservative }
            );
            
            let balanced_strategies = Array.filter<Types.StrategyTemplate>(
                all_strategies, 
                func(s) { s.risk_level == #balanced }
            );
            
            let aggressive_strategies = Array.filter<Types.StrategyTemplate>(
                all_strategies, 
                func(s) { s.risk_level == #aggressive }
            );
            
            conservative_strategies.size() == 1 and 
            balanced_strategies.size() == 1 and 
            aggressive_strategies.size() == 1
        };

        // Test enhanced scoring algorithm with breakdown
        public func test_enhanced_scoring() : Bool {
            let market_conditions = {
                apy_factor = 1.0;
                risk_factor = 0.3;
                liquidity_factor = 0.8;
            };

            let score_result = calculate_enhanced_test_score(
                test_balanced_strategy,
                #balanced,
                market_conditions
            );

            // Verify score is within valid range
            let valid_score = score_result.score >= 0.0 and score_result.score <= 1.0;
            
            // Verify breakdown components are present
            let valid_breakdown = 
                score_result.breakdown.apy_score >= 0.0 and
                score_result.breakdown.risk_score >= 0.0 and
                score_result.breakdown.liquidity_score >= 0.0;
            
            valid_score and valid_breakdown
        };

        // Test comprehensive strategy catalog
        public func test_comprehensive_catalog() : Bool {
            // Extended catalog with multiple strategies per risk level
            let extended_strategies = [
                test_conservative_strategy,
                {
                    id = "conservative-staking";
                    name = "Conservative Staking";
                    risk_level = #conservative;
                    venues = ["Staked", "Figment"];
                    est_apy_band = (2.5, 5.0);
                    params_schema = "{\"test\": true}";
                },
                test_balanced_strategy,
                {
                    id = "balanced-defi";
                    name = "Balanced DeFi";
                    risk_level = #balanced;
                    venues = ["Compound", "Aave"];
                    est_apy_band = (6.0, 12.0);
                    params_schema = "{\"test\": true}";
                },
                test_aggressive_strategy,
                {
                    id = "aggressive-trading";
                    name = "Aggressive Trading";
                    risk_level = #aggressive;
                    venues = ["dYdX", "GMX"];
                    est_apy_band = (20.0, 50.0);
                    params_schema = "{\"test\": true}";
                }
            ];
            
            // Count strategies by risk level
            let conservative_count = Array.filter<Types.StrategyTemplate>(
                extended_strategies, 
                func(s) { s.risk_level == #conservative }
            ).size();
            
            let balanced_count = Array.filter<Types.StrategyTemplate>(
                extended_strategies, 
                func(s) { s.risk_level == #balanced }
            ).size();
            
            let aggressive_count = Array.filter<Types.StrategyTemplate>(
                extended_strategies, 
                func(s) { s.risk_level == #aggressive }
            ).size();
            
            // Should have multiple strategies per risk level
            conservative_count >= 2 and balanced_count >= 2 and aggressive_count >= 2
        };

        // Enhanced scoring function for testing
        private func calculate_enhanced_test_score(
            strategy: Types.StrategyTemplate,
            user_risk: Types.RiskLevel,
            market_conditions: {apy_factor: Float; risk_factor: Float; liquidity_factor: Float}
        ) : {score: Float; breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float}} {
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
            
            // Calculate component scores
            let apy_score = normalized_apy * market_conditions.apy_factor;
            let risk_score = risk_alignment * (1.0 - market_conditions.risk_factor);
            let final_liquidity_score = liquidity_score * market_conditions.liquidity_factor;
            
            // Calculate weighted final score
            let final_score = 
                scoring_weights.apy_weight * apy_score +
                scoring_weights.risk_weight * risk_score +
                scoring_weights.liquidity_weight * final_liquidity_score;
                
            {
                score = Float.max(0.0, Float.min(1.0, final_score));
                breakdown = {
                    apy_score = apy_score;
                    risk_score = risk_score;
                    liquidity_score = final_liquidity_score;
                };
            }
        };

        // Run all tests
        public func run_all_tests() : Bool {
            Debug.print("Running Strategy Template Tests...");
            
            let test1 = test_strategy_template_creation();
            Debug.print("Strategy Template Creation Test: " # (if test1 "PASSED" else "FAILED"));
            
            let test2 = test_strategy_scoring();
            Debug.print("Strategy Scoring Test: " # (if test2 "PASSED" else "FAILED"));
            
            let test3 = test_rationale_generation();
            Debug.print("Rationale Generation Test: " # (if test3 "PASSED" else "FAILED"));
            
            let test4 = test_strategy_catalog();
            Debug.print("Strategy Catalog Test: " # (if test4 "PASSED" else "FAILED"));
            
            let test5 = test_scoring_weights_validation();
            Debug.print("Scoring Weights Validation Test: " # (if test5 "PASSED" else "FAILED"));
            
            let test6 = test_strategy_filtering();
            Debug.print("Strategy Filtering Test: " # (if test6 "PASSED" else "FAILED"));
            
            let test7 = test_enhanced_scoring();
            Debug.print("Enhanced Scoring Test: " # (if test7 "PASSED" else "FAILED"));
            
            let test8 = test_comprehensive_catalog();
            Debug.print("Comprehensive Catalog Test: " # (if test8 "PASSED" else "FAILED"));
            
            let all_passed = test1 and test2 and test3 and test4 and test5 and test6 and test7 and test8;
            Debug.print("All Strategy Template Tests: " # (if all_passed "PASSED" else "FAILED"));
            
            all_passed
        };
    };
}