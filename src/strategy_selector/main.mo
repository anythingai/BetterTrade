import Types "../shared/types";
import Interfaces "../shared/interfaces";
import InterCanister "../shared/inter_canister";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Text "mo:base/Text";
import Debug "mo:base/Debug";
import Int "mo:base/Int";

actor StrategySelector : Interfaces.StrategySelectorInterface {
    // Stable storage for upgrades
    private stable var strategies_stable : [(Text, Types.StrategyTemplate)] = [];
    private stable var plans_stable : [(Types.PlanId, Types.StrategyPlan)] = [];
    
    // Runtime storage
    private var strategies = HashMap.HashMap<Text, Types.StrategyTemplate>(0, Text.equal, Text.hash);
    private var plans = HashMap.HashMap<Types.PlanId, Types.StrategyPlan>(0, Text.equal, Text.hash);
    
    // Audit trail storage
    private stable var audit_entries_stable : [Interfaces.AuditEntry] = [];
    private var audit_entries = HashMap.HashMap<Text, Interfaces.AuditEntry>(0, Text.equal, Text.hash);
    
    // Inter-canister communication setup
    private let canister_registry : Interfaces.CanisterRegistry = {
        user_registry = Principal.fromText("rdmx6-jaaaa-aaaah-qdrya-cai");
        portfolio_state = Principal.fromText("rrkah-fqaaa-aaaah-qdrya-cai");
        strategy_selector = Principal.fromActor(StrategySelector);
        execution_agent = Principal.fromText("renrk-eyaaa-aaaah-qdrya-cai");
        risk_guard = Principal.fromText("rno2w-sqaaa-aaaah-qdrya-cai");
    };
    
    private let communicator = InterCanister.AgentCommunicator(canister_registry);
    
    // Strategy scoring weights - configurable
    private stable var scoring_weights = {
        apy_weight = 0.4;
        risk_weight = 0.35;
        liquidity_weight = 0.25;
    };

    // Strategy template management
    private stable var next_template_id : Nat = 0;

    // Initialize from stable storage
    system func preupgrade() {
        strategies_stable := strategies.entries() |> Iter.toArray(_);
        plans_stable := plans.entries() |> Iter.toArray(_);
        audit_entries_stable := audit_entries.vals() |> Iter.toArray(_);
    };

    system func postupgrade() {
        strategies := HashMap.fromIter(strategies_stable.vals(), strategies_stable.size(), Text.equal, Text.hash);
        plans := HashMap.fromIter(plans_stable.vals(), plans_stable.size(), Text.equal, Text.hash);
        
        // Initialize audit entries from stable storage
        audit_entries := HashMap.HashMap<Text, Interfaces.AuditEntry>(0, Text.equal, Text.hash);
        for (entry in audit_entries_stable.vals()) {
            let key = Int.toText(entry.timestamp) # "_" # entry.action;
            audit_entries.put(key, entry);
        };
        
        initialize_default_strategies();
    };

    // Initialize on first deployment
    system func init() {
        initialize_default_strategies();
    };

    // Initialize default strategy templates
    private func initialize_default_strategies() {
        // Only initialize if strategies are empty
        if (strategies.size() > 0) {
            return;
        };

        let conservative_lending : Types.StrategyTemplate = {
            id = "conservative-lending";
            name = "Conservative Bitcoin Lending";
            risk_level = #conservative;
            venues = ["BlockFi", "Celsius", "Nexo", "Ledn"];
            est_apy_band = (3.0, 6.0);
            params_schema = "{\"min_amount\": 0.01, \"max_allocation\": 0.8, \"preferred_duration\": \"flexible\", \"compound_frequency\": \"monthly\"}";
        };

        let conservative_staking : Types.StrategyTemplate = {
            id = "conservative-staking";
            name = "Conservative Bitcoin Staking";
            risk_level = #conservative;
            venues = ["Staked", "Figment", "Coinbase"];
            est_apy_band = (2.5, 5.0);
            params_schema = "{\"min_amount\": 0.005, \"max_allocation\": 0.9, \"lock_period\": \"none\"}";
        };

        let balanced_liquidity : Types.StrategyTemplate = {
            id = "balanced-liquidity";
            name = "Balanced Liquidity Provision";
            risk_level = #balanced;
            venues = ["Uniswap", "SushiSwap", "Curve", "Balancer"];
            est_apy_band = (8.0, 15.0);
            params_schema = "{\"min_amount\": 0.05, \"max_allocation\": 0.6, \"impermanent_loss_tolerance\": 0.1, \"rebalance_frequency\": \"weekly\"}";
        };

        let balanced_defi : Types.StrategyTemplate = {
            id = "balanced-defi";
            name = "Balanced DeFi Strategies";
            risk_level = #balanced;
            venues = ["Compound", "Aave", "MakerDAO"];
            est_apy_band = (6.0, 12.0);
            params_schema = "{\"min_amount\": 0.02, \"max_allocation\": 0.7, \"leverage_ratio\": 1.5}";
        };

        let aggressive_yield : Types.StrategyTemplate = {
            id = "aggressive-yield";
            name = "Aggressive Yield Farming";
            risk_level = #aggressive;
            venues = ["Yearn", "Convex", "Beefy", "Harvest"];
            est_apy_band = (15.0, 35.0);
            params_schema = "{\"min_amount\": 0.1, \"max_allocation\": 0.4, \"leverage_tolerance\": 2.0, \"auto_compound\": true}";
        };

        let aggressive_trading : Types.StrategyTemplate = {
            id = "aggressive-trading";
            name = "Aggressive Trading Strategies";
            risk_level = #aggressive;
            venues = ["dYdX", "GMX", "Perpetual Protocol"];
            est_apy_band = (20.0, 50.0);
            params_schema = "{\"min_amount\": 0.2, \"max_allocation\": 0.3, \"max_leverage\": 3.0, \"stop_loss\": 0.15}";
        };

        // Add all strategies to the catalog
        strategies.put(conservative_lending.id, conservative_lending);
        strategies.put(conservative_staking.id, conservative_staking);
        strategies.put(balanced_liquidity.id, balanced_liquidity);
        strategies.put(balanced_defi.id, balanced_defi);
        strategies.put(aggressive_yield.id, aggressive_yield);
        strategies.put(aggressive_trading.id, aggressive_trading);
    };

    // Enhanced strategy scoring algorithm with configurable weights
    private func calculate_strategy_score(
        strategy: Types.StrategyTemplate,
        user_risk: Types.RiskLevel,
        market_conditions: {apy_factor: Float; risk_factor: Float; liquidity_factor: Float}
    ) : {score: Float; breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float}} {
        // Normalize APY (assume max APY of 50% for normalization)
        let avg_apy = (strategy.est_apy_band.1 + strategy.est_apy_band.0) / 2.0;
        let normalized_apy = Float.min(1.0, avg_apy / 50.0);
        
        // Risk alignment score (higher when strategy risk matches user risk)
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
        
        // Liquidity score based on venue count and diversity
        let venue_count = strategy.venues.size();
        let liquidity_score = Float.min(1.0, Float.fromInt(venue_count) / 5.0);
        
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

    // Get default market conditions (can be enhanced with real market data later)
    private func get_default_market_conditions() : {apy_factor: Float; risk_factor: Float; liquidity_factor: Float} {
        {
            apy_factor = 1.0;      // Normal APY conditions
            risk_factor = 0.3;     // Moderate market risk
            liquidity_factor = 0.8; // Good liquidity conditions
        }
    };

    // Generate unique plan ID
    private func generate_plan_id(uid: Types.UserId, strategy_id: Text) : Types.PlanId {
        let timestamp = Int.toText(Time.now());
        let user_text = Principal.toText(uid);
        "plan_" # strategy_id # "_" # user_text # "_" # timestamp
    };

    // Create allocations based on strategy template
    private func create_allocations(strategy: Types.StrategyTemplate, total_amount_sats: Nat64) : [Types.Allocation] {
        let venue_count = strategy.venues.size();
        if (venue_count == 0) {
            return [];
        };
        
        // Equal allocation across all venues for now
        let amount_per_venue = total_amount_sats / Nat64.fromNat(venue_count);
        let percentage_per_venue = 100.0 / Float.fromInt(venue_count);
        
        Array.map<Text, Types.Allocation>(strategy.venues, func(venue_id) {
            {
                venue_id = venue_id;
                amount_sats = amount_per_venue;
                percentage = percentage_per_venue;
            }
        })
    };

    // Generate detailed rationale for strategy recommendation
    private func generate_rationale(
        strategy: Types.StrategyTemplate,
        score_result: {score: Float; breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float}},
        user_risk: Types.RiskLevel
    ) : Text {
        let risk_text = switch user_risk {
            case (#conservative) { "conservative risk profile" };
            case (#balanced) { "balanced risk profile" };
            case (#aggressive) { "aggressive risk profile" };
        };
        
        let apy_text = "Expected APY: " # Float.toText(strategy.est_apy_band.0) # "% - " # Float.toText(strategy.est_apy_band.1) # "%";
        let venues_text = "Available on " # Int.toText(strategy.venues.size()) # " venues: " # Text.join(", ", strategy.venues.vals());
        let score_text = "Overall score: " # Float.toText(score_result.score * 100.0) # "/100";
        
        // Add breakdown explanation
        let breakdown_text = "Score breakdown - APY: " # 
            Float.toText(score_result.breakdown.apy_score * 100.0) # "%, Risk alignment: " #
            Float.toText(score_result.breakdown.risk_score * 100.0) # "%, Liquidity: " #
            Float.toText(score_result.breakdown.liquidity_score * 100.0) # "%";
        
        // Risk alignment explanation
        let alignment_text = switch (user_risk, strategy.risk_level) {
            case (#conservative, #conservative) { "Perfect match for conservative investors seeking capital preservation." };
            case (#balanced, #balanced) { "Ideal balance of risk and reward for moderate investors." };
            case (#aggressive, #aggressive) { "High-growth potential aligned with aggressive risk tolerance." };
            case (#conservative, #balanced) { "Slightly higher risk but still suitable for conservative portfolios." };
            case (#balanced, #conservative) { "Lower risk option that fits well within balanced allocation." };
            case (#balanced, #aggressive) { "Higher risk component for diversified balanced portfolio." };
            case (#aggressive, #balanced) { "Moderate risk option to balance aggressive portfolio." };
            case (#conservative, #aggressive) { "High risk - consider smaller allocation or alternative strategies." };
            case (#aggressive, #conservative) { "Low risk option for portfolio stability." };
        };
        
        "Recommended for your " # risk_text # ". " # apy_text # ". " # venues_text # ". " # 
        score_text # ". " # breakdown_text # ". " # alignment_text
    };

    // Initialize strategies on first call if empty
    private func ensure_strategies_initialized() {
        if (strategies.size() == 0) {
            initialize_default_strategies();
        };
    };

    // Strategy template management methods
    public query func list_strategies() : async Types.Result<[Types.StrategyTemplate], Types.ApiError> {
        ensure_strategies_initialized();
        let strategy_list = strategies.vals() |> Iter.toArray(_);
        #ok(strategy_list)
    };

    public query func get_strategy(strategy_id: Text) : async Types.Result<Types.StrategyTemplate, Types.ApiError> {
        ensure_strategies_initialized();
        switch (strategies.get(strategy_id)) {
            case (?strategy) { #ok(strategy) };
            case null { #err(#not_found) };
        }
    };

    public query func list_strategies_by_risk(risk_level: Types.RiskLevel) : async Types.Result<[Types.StrategyTemplate], Types.ApiError> {
        ensure_strategies_initialized();
        let filtered_strategies = strategies.vals() 
            |> Iter.filter(_, func(s: Types.StrategyTemplate) : Bool { s.risk_level == risk_level })
            |> Iter.toArray(_);
        #ok(filtered_strategies)
    };

    public query func get_scoring_weights() : async {apy_weight: Float; risk_weight: Float; liquidity_weight: Float} {
        scoring_weights
    };

    public shared(msg) func update_scoring_weights(
        apy_weight: Float, 
        risk_weight: Float, 
        liquidity_weight: Float
    ) : async Types.Result<Bool, Types.ApiError> {
        // Validate weights sum to approximately 1.0
        let total_weight = apy_weight + risk_weight + liquidity_weight;
        if (total_weight < 0.95 or total_weight > 1.05) {
            return #err(#invalid_input("Weights must sum to approximately 1.0"));
        };

        // Validate individual weights are positive
        if (apy_weight < 0.0 or risk_weight < 0.0 or liquidity_weight < 0.0) {
            return #err(#invalid_input("All weights must be positive"));
        };

        scoring_weights := {
            apy_weight = apy_weight;
            risk_weight = risk_weight;
            liquidity_weight = liquidity_weight;
        };
        #ok(true)
    };

    // Recommendation engine implementation
    public shared(msg) func recommend(uid: Types.UserId, risk: Types.RiskLevel) : async Types.Result<Types.StrategyPlan, Types.ApiError> {
        ensure_strategies_initialized();
        
        // Get all strategies and score them for the user's risk profile
        let all_strategies = strategies.vals() |> Iter.toArray(_);
        let market_conditions = get_default_market_conditions();
        
        // Score all strategies and create scored recommendations
        let scored_strategies = Array.map<Types.StrategyTemplate, {
            strategy: Types.StrategyTemplate;
            score: Float;
            breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float};
            rationale: Text;
        }>(all_strategies, func(strategy) {
            let score_result = calculate_strategy_score(strategy, risk, market_conditions);
            let rationale = generate_rationale(strategy, score_result, risk);
            {
                strategy = strategy;
                score = score_result.score;
                breakdown = score_result.breakdown;
                rationale = rationale;
            }
        });
        
        // Sort by score (highest first)
        let sorted_strategies = Array.sort<{
            strategy: Types.StrategyTemplate;
            score: Float;
            breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float};
            rationale: Text;
        }>(scored_strategies, func(a, b) {
            if (a.score > b.score) { #less }
            else if (a.score < b.score) { #greater }
            else { #equal }
        });
        
        // Get the top recommendation
        switch (sorted_strategies[0]) {
            case (?top_recommendation) {
                // Create strategy plan with allocations
                let plan_id = generate_plan_id(uid, top_recommendation.strategy.id);
                let allocations = create_allocations(top_recommendation.strategy, 100000000); // 1 BTC in sats as default
                
                let strategy_plan : Types.StrategyPlan = {
                    id = plan_id;
                    user_id = uid;
                    template_id = top_recommendation.strategy.id;
                    allocations = allocations;
                    created_at = Time.now();
                    status = #pending;
                    rationale = top_recommendation.rationale;
                };
                
                // Store the plan
                plans.put(plan_id, strategy_plan);
                
                // Log recommendation event
                await log_audit_event("strategy_recommended", ?uid, ?plan_id, 
                    "Strategy " # top_recommendation.strategy.id # " recommended with score " # Float.toText(top_recommendation.score));
                
                // Publish strategy recommended event
                await communicator.publish_event(
                    #strategy_recommended(uid, plan_id),
                    Principal.fromActor(StrategySelector)
                );
                
                #ok(strategy_plan)
            };
            case null {
                #err(#internal_error("No strategies available for recommendation"))
            };
        }
    };

    // Test method for strategy scoring (useful for testing and debugging)
    public query func test_strategy_scoring(
        strategy_id: Text,
        user_risk: Types.RiskLevel
    ) : async Types.Result<{
        strategy: Types.StrategyTemplate;
        score: Float;
        breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float};
        rationale: Text;
    }, Types.ApiError> {
        ensure_strategies_initialized();
        
        switch (strategies.get(strategy_id)) {
            case (?strategy) {
                let market_conditions = get_default_market_conditions();
                let score_result = calculate_strategy_score(strategy, user_risk, market_conditions);
                let rationale = generate_rationale(strategy, score_result, user_risk);
                
                #ok({
                    strategy = strategy;
                    score = score_result.score;
                    breakdown = score_result.breakdown;
                    rationale = rationale;
                })
            };
            case null { #err(#not_found) };
        }
    };

    // Get multiple strategy recommendations with scores
    public shared(msg) func get_recommendations(uid: Types.UserId, risk: Types.RiskLevel, limit: ?Nat) : async Types.Result<[{
        strategy: Types.StrategyTemplate;
        score: Float;
        breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float};
        rationale: Text;
    }], Types.ApiError> {
        ensure_strategies_initialized();
        
        let all_strategies = strategies.vals() |> Iter.toArray(_);
        let market_conditions = get_default_market_conditions();
        let max_results = switch (limit) {
            case (?l) { l };
            case null { 5 }; // Default to top 5
        };
        
        // Score all strategies
        let scored_strategies = Array.map<Types.StrategyTemplate, {
            strategy: Types.StrategyTemplate;
            score: Float;
            breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float};
            rationale: Text;
        }>(all_strategies, func(strategy) {
            let score_result = calculate_strategy_score(strategy, risk, market_conditions);
            let rationale = generate_rationale(strategy, score_result, risk);
            {
                strategy = strategy;
                score = score_result.score;
                breakdown = score_result.breakdown;
                rationale = rationale;
            }
        });
        
        // Sort by score (highest first)
        let sorted_strategies = Array.sort<{
            strategy: Types.StrategyTemplate;
            score: Float;
            breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float};
            rationale: Text;
        }>(scored_strategies, func(a, b) {
            if (a.score > b.score) { #less }
            else if (a.score < b.score) { #greater }
            else { #equal }
        });
        
        // Return top N results
        let result_count = Int.min(max_results, sorted_strategies.size());
        let top_recommendations = Array.tabulate<{
            strategy: Types.StrategyTemplate;
            score: Float;
            breakdown: {apy_score: Float; risk_score: Float; liquidity_score: Float};
            rationale: Text;
        }>(result_count, func(i) {
            sorted_strategies[i]!
        });
        
        #ok(top_recommendations)
    };

    // Enhanced plan approval system with locking and inter-canister communication
    public shared(msg) func accept_plan(uid: Types.UserId, plan_id: Types.PlanId) : async Types.Result<Bool, Types.ApiError> {
        switch (plans.get(plan_id)) {
            case (?plan) {
                // Verify the plan belongs to the user
                if (plan.user_id != uid) {
                    return #err(#unauthorized);
                };
                
                // Verify the plan is in pending status
                if (plan.status != #pending) {
                    return #err(#invalid_input("Plan is not in pending status"));
                };
                
                // Check if user has any other approved plans (plan locking)
                let existing_approved_plans = plans.vals() 
                    |> Iter.filter(_, func(p: Types.StrategyPlan) : Bool { 
                        p.user_id == uid and (p.status == #approved or p.status == #executed)
                    })
                    |> Iter.toArray(_);
                
                if (existing_approved_plans.size() > 0) {
                    return #err(#invalid_input("User already has an active strategy plan. Please cancel or complete the existing plan first."));
                };
                
                // Update plan status to approved with timestamp
                let updated_plan = {
                    id = plan.id;
                    user_id = plan.user_id;
                    template_id = plan.template_id;
                    allocations = plan.allocations;
                    created_at = plan.created_at;
                    status = #approved;
                    rationale = plan.rationale;
                };
                
                plans.put(plan_id, updated_plan);
                
                // Log the approval for audit trail
                await log_audit_event("strategy_plan_approved", ?uid, null, "Plan " # plan_id # " approved by user");
                
                // Publish strategy approved event
                await communicator.publish_event(
                    #strategy_approved(uid, plan_id),
                    Principal.fromActor(StrategySelector)
                );
                
                #ok(true)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public query func get_plan(plan_id: Types.PlanId) : async Types.Result<Types.StrategyPlan, Types.ApiError> {
        switch (plans.get(plan_id)) {
            case (?plan) { #ok(plan) };
            case null { #err(#not_found) };
        }
    };

    // Additional utility methods for plan management
    public query func get_user_plans(uid: Types.UserId) : async Types.Result<[Types.StrategyPlan], Types.ApiError> {
        let user_plans = plans.vals() 
            |> Iter.filter(_, func(plan: Types.StrategyPlan) : Bool { plan.user_id == uid })
            |> Iter.toArray(_);
        #ok(user_plans)
    };

    public query func get_plans_by_status(status: Types.PlanStatus) : async Types.Result<[Types.StrategyPlan], Types.ApiError> {
        let filtered_plans = plans.vals() 
            |> Iter.filter(_, func(plan: Types.StrategyPlan) : Bool { plan.status == status })
            |> Iter.toArray(_);
        #ok(filtered_plans)
    };

    // Enhanced audit logging function with inter-canister communication
    private func log_audit_event(action: Text, user_id: ?Types.UserId, transaction_id: ?Types.TxId, details: Text) : async () {
        let entry : Interfaces.AuditEntry = {
            timestamp = Time.now();
            canister = "strategy_selector";
            action = action;
            user_id = user_id;
            transaction_id = transaction_id;
            details = details;
        };
        
        let key = Int.toText(entry.timestamp) # "_" # action;
        audit_entries.put(key, entry);
        
        // Also log to the inter-canister communicator for centralized audit trail
        communicator.log_audit_entry(entry);
    };

    // Plan cancellation method
    public shared(msg) func cancel_plan(uid: Types.UserId, plan_id: Types.PlanId) : async Types.Result<Bool, Types.ApiError> {
        switch (plans.get(plan_id)) {
            case (?plan) {
                // Verify the plan belongs to the user
                if (plan.user_id != uid) {
                    return #err(#unauthorized);
                };
                
                // Only allow cancellation of pending or approved plans
                if (plan.status != #pending and plan.status != #approved) {
                    return #err(#invalid_input("Cannot cancel plan in current status"));
                };
                
                // Update plan status to failed (cancelled)
                let updated_plan = {
                    id = plan.id;
                    user_id = plan.user_id;
                    template_id = plan.template_id;
                    allocations = plan.allocations;
                    created_at = plan.created_at;
                    status = #failed;
                    rationale = plan.rationale # " [CANCELLED BY USER]";
                };
                
                plans.put(plan_id, updated_plan);
                
                // Log the cancellation
                await log_audit_event("strategy_plan_cancelled", ?uid, null, "Plan " # plan_id # " cancelled by user");
                
                #ok(true)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Get user's active (approved or executed) plan
    public query func get_user_active_plan(uid: Types.UserId) : async Types.Result<?Types.StrategyPlan, Types.ApiError> {
        let active_plans = plans.vals() 
            |> Iter.filter(_, func(plan: Types.StrategyPlan) : Bool { 
                plan.user_id == uid and (plan.status == #approved or plan.status == #executed)
            })
            |> Iter.toArray(_);
        
        switch (active_plans.size()) {
            case (0) { #ok(null) };
            case (1) { #ok(?active_plans[0]!) };
            case (_) { 
                // This shouldn't happen due to plan locking, but handle gracefully
                #ok(?active_plans[0]!)
            };
        }
    };

    // Inter-canister communication for plan execution
    public shared(msg) func execute_approved_plan(plan_id: Types.PlanId, execution_agent: Interfaces.ExecutionAgentInterface) : async Types.Result<[Types.TxId], Types.ApiError> {
        switch (plans.get(plan_id)) {
            case (?plan) {
                // Verify the plan is approved
                if (plan.status != #approved) {
                    return #err(#invalid_input("Plan is not in approved status"));
                };
                
                // Update plan status to executed (optimistically)
                let updated_plan = {
                    id = plan.id;
                    user_id = plan.user_id;
                    template_id = plan.template_id;
                    allocations = plan.allocations;
                    created_at = plan.created_at;
                    status = #executed;
                    rationale = plan.rationale;
                };
                
                plans.put(plan_id, updated_plan);
                
                // Call execution agent
                try {
                    let execution_result = await execution_agent.execute_plan(plan_id);
                    
                    switch (execution_result) {
                        case (#ok(tx_ids)) {
                            // Log successful execution
                            await log_audit_event("strategy_plan_executed", ?plan.user_id, null, 
                                "Plan " # plan_id # " executed successfully with " # Int.toText(tx_ids.size()) # " transactions");
                            #ok(tx_ids)
                        };
                        case (#err(error)) {
                            // Revert plan status back to approved on execution failure
                            let reverted_plan = {
                                id = plan.id;
                                user_id = plan.user_id;
                                template_id = plan.template_id;
                                allocations = plan.allocations;
                                created_at = plan.created_at;
                                status = #approved;
                                rationale = plan.rationale;
                            };
                            plans.put(plan_id, reverted_plan);
                            
                            await log_audit_event("strategy_plan_execution_failed", ?plan.user_id, null, 
                                "Plan " # plan_id # " execution failed");
                            #err(error)
                        };
                    }
                } catch (e) {
                    // Revert plan status on inter-canister call failure
                    let reverted_plan = {
                        id = plan.id;
                        user_id = plan.user_id;
                        template_id = plan.template_id;
                        allocations = plan.allocations;
                        created_at = plan.created_at;
                        status = #approved;
                        rationale = plan.rationale;
                    };
                    plans.put(plan_id, reverted_plan);
                    
                    await log_audit_event("strategy_plan_execution_error", ?plan.user_id, null, 
                        "Plan " # plan_id # " execution error: inter-canister call failed");
                    #err(#internal_error("Failed to communicate with execution agent"))
                }
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Get audit trail for transparency
    public query func get_audit_trail(limit: ?Nat) : async Types.Result<[Interfaces.AuditEntry], Types.ApiError> {
        let max_entries = switch (limit) {
            case (?l) { l };
            case null { 100 }; // Default limit
        };
        
        let all_entries = audit_entries.vals() |> Iter.toArray(_);
        
        // Sort by timestamp (most recent first)
        let sorted_entries = Array.sort<Interfaces.AuditEntry>(all_entries, func(a, b) {
            if (a.timestamp > b.timestamp) { #less }
            else if (a.timestamp < b.timestamp) { #greater }
            else { #equal }
        });
        
        let result_count = Int.min(max_entries, sorted_entries.size());
        let limited_entries = Array.tabulate<Interfaces.AuditEntry>(result_count, func(i) {
            sorted_entries[i]!
        });
        
        #ok(limited_entries)
    };

    // Get user-specific audit trail
    public query func get_user_audit_trail(uid: Types.UserId, limit: ?Nat) : async Types.Result<[Interfaces.AuditEntry], Types.ApiError> {
        let max_entries = switch (limit) {
            case (?l) { l };
            case null { 50 }; // Default limit for user-specific
        };
        
        let user_entries = audit_entries.vals() 
            |> Iter.filter(_, func(entry: Interfaces.AuditEntry) : Bool { 
                switch (entry.user_id) {
                    case (?user_id) { user_id == uid };
                    case null { false };
                }
            })
            |> Iter.toArray(_);
        
        // Sort by timestamp (most recent first)
        let sorted_entries = Array.sort<Interfaces.AuditEntry>(user_entries, func(a, b) {
            if (a.timestamp > b.timestamp) { #less }
            else if (a.timestamp < b.timestamp) { #greater }
            else { #equal }
        });
        
        let result_count = Int.min(max_entries, sorted_entries.size());
        let limited_entries = Array.tabulate<Interfaces.AuditEntry>(result_count, func(i) {
            sorted_entries[i]!
        });
        
        #ok(limited_entries)
    };

    // Plan validation method
    public query func validate_plan(plan_id: Types.PlanId) : async Types.Result<{
        is_valid: Bool;
        validation_errors: [Text];
        can_execute: Bool;
    }, Types.ApiError> {
        switch (plans.get(plan_id)) {
            case (?plan) {
                var errors : [Text] = [];
                var is_valid = true;
                var can_execute = false;
                
                // Check if strategy template still exists
                switch (strategies.get(plan.template_id)) {
                    case null { 
                        errors := Array.append(errors, ["Strategy template no longer exists"]);
                        is_valid := false;
                    };
                    case (?_) { /* Template exists */ };
                };
                
                // Check allocations
                if (plan.allocations.size() == 0) {
                    errors := Array.append(errors, ["No allocations defined"]);
                    is_valid := false;
                };
                
                // Validate allocation percentages sum to reasonable total
                var total_percentage : Float = 0.0;
                for (allocation in plan.allocations.vals()) {
                    total_percentage += allocation.percentage;
                    if (allocation.amount_sats == 0) {
                        errors := Array.append(errors, ["Zero amount allocation found"]);
                        is_valid := false;
                    };
                };
                
                if (total_percentage < 95.0 or total_percentage > 105.0) {
                    errors := Array.append(errors, ["Allocation percentages don't sum to 100%"]);
                    is_valid := false;
                };
                
                // Check if plan can be executed
                can_execute := is_valid and plan.status == #approved;
                
                #ok({
                    is_valid = is_valid;
                    validation_errors = errors;
                    can_execute = can_execute;
                })
            };
            case null {
                #err(#not_found)
            };
        }
    };
}    // Plan
 validation method for inter-canister communication
    public query func validate_plan(plan_id: Types.PlanId) : async Types.Result<{
        is_valid: Bool;
        validation_errors: [Text];
        can_execute: Bool;
    }, Types.ApiError> {
        switch (plans.get(plan_id)) {
            case (?plan) {
                var validation_errors: [Text] = [];
                var is_valid = true;
                var can_execute = true;
                
                // Check plan status
                if (plan.status != #approved) {
                    validation_errors := Array.append(validation_errors, ["Plan is not in approved status"]);
                    can_execute := false;
                };
                
                // Check if allocations are valid
                if (plan.allocations.size() == 0) {
                    validation_errors := Array.append(validation_errors, ["Plan has no allocations"]);
                    is_valid := false;
                    can_execute := false;
                };
                
                // Check if strategy template still exists
                switch (strategies.get(plan.template_id)) {
                    case (null) {
                        validation_errors := Array.append(validation_errors, ["Strategy template no longer exists"]);
                        is_valid := false;
                        can_execute := false;
                    };
                    case (?_) {};
                };
                
                // Check allocation percentages sum to reasonable amount
                var total_percentage: Float = 0.0;
                for (allocation in plan.allocations.vals()) {
                    total_percentage += allocation.percentage;
                };
                
                if (total_percentage < 95.0 or total_percentage > 105.0) {
                    validation_errors := Array.append(validation_errors, ["Allocation percentages don't sum to 100%"]);
                    is_valid := false;
                };
                
                #ok({
                    is_valid = is_valid;
                    validation_errors = validation_errors;
                    can_execute = can_execute;
                })
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Audit trail methods for transparency
    public query func get_audit_trail(limit: ?Nat) : async Types.Result<[Interfaces.AuditEntry], Types.ApiError> {
        let entries = communicator.get_audit_trail(limit);
        #ok(entries)
    };

    public query func get_user_audit_trail(uid: Types.UserId, limit: ?Nat) : async Types.Result<[Interfaces.AuditEntry], Types.ApiError> {
        let entries = communicator.get_user_audit_trail(uid, limit);
        #ok(entries)
    };

    // System health and monitoring
    public query func get_system_stats() : async {
        total_strategies: Nat;
        total_plans: Nat;
        pending_plans: Nat;
        approved_plans: Nat;
        executed_plans: Nat;
        failed_plans: Nat;
        communication_stats: {
            active_flows: Nat;
            total_audit_entries: Nat;
            event_subscribers: Nat;
            event_history_size: Nat;
        };
    } {
        let pending_count = plans.vals() |> Iter.filter(_, func(p: Types.StrategyPlan) : Bool { p.status == #pending }) |> Iter.size(_);
        let approved_count = plans.vals() |> Iter.filter(_, func(p: Types.StrategyPlan) : Bool { p.status == #approved }) |> Iter.size(_);
        let executed_count = plans.vals() |> Iter.filter(_, func(p: Types.StrategyPlan) : Bool { p.status == #executed }) |> Iter.size(_);
        let failed_count = plans.vals() |> Iter.filter(_, func(p: Types.StrategyPlan) : Bool { p.status == #failed }) |> Iter.size(_);
        
        {
            total_strategies = strategies.size();
            total_plans = plans.size();
            pending_plans = pending_count;
            approved_plans = approved_count;
            executed_plans = executed_count;
            failed_plans = failed_count;
            communication_stats = communicator.get_communication_stats();
        }
    };

    // Event subscription for inter-canister communication
    public func subscribe_to_portfolio_updates() : async () {
        let portfolio_update_handler = func(event: Interfaces.SystemEvent) : async () {
            switch (event) {
                case (#deposit_detected(user_id, amount)) {
                    await log_audit_event("portfolio_deposit_detected", ?user_id, null, 
                        "Deposit of " # Nat64.toText(amount) # " sats detected for user");
                };
                case (#execution_completed(plan_id, tx_ids)) {
                    // Update plan status to executed if it exists
                    switch (plans.get(plan_id)) {
                        case (?plan) {
                            let updated_plan = {
                                id = plan.id;
                                user_id = plan.user_id;
                                template_id = plan.template_id;
                                allocations = plan.allocations;
                                created_at = plan.created_at;
                                status = #executed;
                                rationale = plan.rationale;
                            };
                            plans.put(plan_id, updated_plan);
                            
                            await log_audit_event("plan_execution_confirmed", ?plan.user_id, ?plan_id,
                                "Plan execution confirmed with " # Int.toText(tx_ids.size()) # " transactions");
                        };
                        case null {};
                    };
                };
                case (_) {};
            };
        };
        
        communicator.subscribe_to_events("portfolio_updates", portfolio_update_handler);
        communicator.subscribe_to_events("execution_updates", portfolio_update_handler);
    };

    // Initialize event subscriptions on startup
    system func init() {
        initialize_default_strategies();
        ignore subscribe_to_portfolio_updates();
    };
}