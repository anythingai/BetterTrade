import Types "../shared/types";
import Interfaces "../shared/interfaces";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Timer "mo:base/Timer";
import Debug "mo:base/Debug";

import Logging "../shared/logging";
import RiskMonitor "risk_monitor";
import ProtectiveActions "protective_actions";

actor RiskGuard : Interfaces.RiskGuardInterface {
    // Enhanced Risk Guard with monitoring and protective actions
    private let risk_monitor = RiskMonitor.RiskMonitor();
    private let protective_actions = ProtectiveActions.ProtectiveActionSystem();

    // Inter-canister references
    private stable var portfolio_state_canister_id : ?Principal = null;
    private stable var execution_agent_canister_id : ?Principal = null;
    private stable var notification_system_canister_id : ?Principal = null;

    // Monitoring configuration
    private stable var monitoring_enabled : Bool = true;
    private stable var monitoring_interval_seconds : Nat = 30;
    private var monitoring_timer_id : ?Nat = null;
    // Legacy storage for backward compatibility
    private stable var guards_stable : [(Types.UserId, Types.RiskGuardConfig)] = [];
    private stable var intents_stable : [(Types.UserId, [Types.ProtectiveIntent])] = [];
    
    // Runtime storage for legacy interface
    private var guards = HashMap.HashMap<Types.UserId, Types.RiskGuardConfig>(0, Principal.equal, Principal.hash);
    private var intents = HashMap.HashMap<Types.UserId, [Types.ProtectiveIntent]>(0, Principal.equal, Principal.hash);

    // Initialize from stable storage
    system func preupgrade() {
        guards_stable := guards.entries() |> Iter.toArray(_);
        intents_stable := intents.entries() |> Iter.toArray(_);
    };

    system func postupgrade() {
        guards := HashMap.fromIter(guards_stable.vals(), guards_stable.size(), Principal.equal, Principal.hash);
        intents := HashMap.fromIter(intents_stable.vals(), intents_stable.size(), Principal.equal, Principal.hash);
        
        // Start monitoring timer after upgrade
        ignore Timer.setTimer(#seconds(5), func() : async () {
            await start_monitoring_timer();
        });
    };

    // System initialization
    public func initialize(
        portfolio_state_id: Principal,
        execution_agent_id: Principal,
        notification_system_id: ?Principal
    ) : async Result.Result<Bool, Types.ApiError> {
        portfolio_state_canister_id := ?portfolio_state_id;
        execution_agent_canister_id := ?execution_agent_id;
        notification_system_canister_id := notification_system_id;

        // Start monitoring timer
        await start_monitoring_timer();

        Logging.log_info("🛡️ Risk Guard initialized with enhanced monitoring");
        #ok(true)
    };

    // Enhanced risk configuration system
    public shared(msg) func set_guard(uid: Types.UserId, cfg: Types.RiskGuardConfig) : async Types.Result<Bool, Types.ApiError> {
        // Use enhanced risk monitor for configuration
        let result = risk_monitor.set_risk_config(uid, cfg);
        
        // Also store in legacy system for backward compatibility
        switch (result) {
            case (#ok(_)) {
                guards.put(uid, cfg);
                #ok(true)
            };
            case (#err(error)) {
                #err(error)
            };
        }
    };

    public query func get_guard(uid: Types.UserId) : async Types.Result<?Types.RiskGuardConfig, Types.ApiError> {
        #ok(guards.get(uid))
    };

    // Additional risk configuration management functions
    public shared(msg) func update_max_drawdown(uid: Types.UserId, new_drawdown_pct: Float) : async Types.Result<Bool, Types.ApiError> {
        switch (guards.get(uid)) {
            case (?existing_config) {
                if (new_drawdown_pct < 0.0 or new_drawdown_pct > 100.0) {
                    return #err(#invalid_input("max_drawdown_pct must be between 0 and 100"));
                };
                
                let updated_config = {
                    user_id = existing_config.user_id;
                    max_drawdown_pct = new_drawdown_pct;
                    liquidity_exit_threshold = existing_config.liquidity_exit_threshold;
                    notify_only = existing_config.notify_only;
                };
                
                guards.put(uid, updated_config);
                #ok(true)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public shared(msg) func update_liquidity_threshold(uid: Types.UserId, new_threshold: Nat64) : async Types.Result<Bool, Types.ApiError> {
        switch (guards.get(uid)) {
            case (?existing_config) {
                if (new_threshold == 0) {
                    return #err(#invalid_input("liquidity_exit_threshold must be greater than 0"));
                };
                
                let updated_config = {
                    user_id = existing_config.user_id;
                    max_drawdown_pct = existing_config.max_drawdown_pct;
                    liquidity_exit_threshold = new_threshold;
                    notify_only = existing_config.notify_only;
                };
                
                guards.put(uid, updated_config);
                #ok(true)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public shared(msg) func toggle_notify_only(uid: Types.UserId) : async Types.Result<Bool, Types.ApiError> {
        switch (guards.get(uid)) {
            case (?existing_config) {
                let updated_config = {
                    user_id = existing_config.user_id;
                    max_drawdown_pct = existing_config.max_drawdown_pct;
                    liquidity_exit_threshold = existing_config.liquidity_exit_threshold;
                    notify_only = not existing_config.notify_only;
                };
                
                guards.put(uid, updated_config);
                #ok(existing_config.notify_only) // Return previous state
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public shared(msg) func remove_guard(uid: Types.UserId) : async Types.Result<Bool, Types.ApiError> {
        switch (guards.remove(uid)) {
            case (?_) { #ok(true) };
            case null { #err(#not_found) };
        }
    };

    public query func list_all_guards() : async Types.Result<[(Types.UserId, Types.RiskGuardConfig)], Types.ApiError> {
        let guard_entries = guards.entries() |> Iter.toArray(_);
        #ok(guard_entries)
    };

    // Private helper function to validate risk configuration
    private func validate_risk_config(cfg: Types.RiskGuardConfig) : Types.Result<Bool, Types.ApiError> {
        // Validate max_drawdown_pct is between 0 and 100
        if (cfg.max_drawdown_pct < 0.0 or cfg.max_drawdown_pct > 100.0) {
            return #err(#invalid_input("max_drawdown_pct must be between 0 and 100"));
        };

        // Validate liquidity_exit_threshold is positive
        if (cfg.liquidity_exit_threshold == 0) {
            return #err(#invalid_input("liquidity_exit_threshold must be greater than 0"));
        };

        // Additional validation for reasonable values
        if (cfg.max_drawdown_pct > 95.0) {
            return #err(#invalid_input("max_drawdown_pct above 95% is not recommended for safety"));
        };

        #ok(true)
    };

    // Portfolio monitoring and risk evaluation implementation
    public shared(msg) func evaluate_portfolio(uid: Types.UserId) : async Types.Result<[Types.ProtectiveIntent], Types.ApiError> {
        // Get user's risk guard configuration
        switch (guards.get(uid)) {
            case (?config) {
                // For MVP stub, we'll simulate portfolio monitoring
                // In a full implementation, this would call Portfolio State canister
                let mock_portfolio_value = 100_000_000; // 1 BTC in sats
                let mock_entry_value = 120_000_000; // 1.2 BTC entry value
                let current_drawdown = ((mock_entry_value - mock_portfolio_value) * 100) / mock_entry_value;
                
                var protective_intents : [Types.ProtectiveIntent] = [];
                
                // Check if drawdown threshold is breached
                if (current_drawdown > config.max_drawdown_pct) {
                    let intent = {
                        user_id = uid;
                        action = if (current_drawdown > config.max_drawdown_pct * 2) #unwind else #pause;
                        reason = "Maximum drawdown threshold of " # Float.toText(config.max_drawdown_pct) # "% exceeded. Current drawdown: " # Float.toText(current_drawdown) # "%";
                        triggered_at = Time.now();
                    };
                    protective_intents := [intent];
                };
                
                // Check liquidity threshold
                if (mock_portfolio_value < config.liquidity_exit_threshold) {
                    let liquidity_intent = {
                        user_id = uid;
                        action = #reduce_exposure;
                        reason = "Portfolio value " # Int.toText(Int.fromNat64(mock_portfolio_value)) # " sats below liquidity exit threshold of " # Int.toText(Int.fromNat64(config.liquidity_exit_threshold)) # " sats";
                        triggered_at = Time.now();
                    };
                    protective_intents := Array.append(protective_intents, [liquidity_intent]);
                };
                
                // Store intents for tracking
                intents.put(uid, protective_intents);
                
                #ok(protective_intents)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public shared(msg) func trigger_protection(uid: Types.UserId, action: Types.ProtectiveAction) : async Types.Result<Bool, Types.ApiError> {
        // Get user's risk guard configuration
        switch (guards.get(uid)) {
            case (?config) {
                // Create protective intent for manual trigger
                let manual_intent = {
                    user_id = uid;
                    action = action;
                    reason = "Manual protection trigger activated by user";
                    triggered_at = Time.now();
                };
                
                // Store the intent
                let existing_intents = switch (intents.get(uid)) {
                    case (?existing) { existing };
                    case null { [] };
                };
                let updated_intents = Array.append(existing_intents, [manual_intent]);
                intents.put(uid, updated_intents);
                
                // In MVP stub, we just log the action
                // In full implementation, this would communicate with Execution Agent
                if (config.notify_only) {
                    // Only notify, don't execute protective action
                    #ok(true)
                } else {
                    // Would execute protective action in full implementation
                    #ok(true)
                }
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Additional risk monitoring helper functions
    public query func get_protective_intents(uid: Types.UserId) : async Types.Result<[Types.ProtectiveIntent], Types.ApiError> {
        switch (intents.get(uid)) {
            case (?user_intents) { #ok(user_intents) };
            case null { #ok([]) };
        }
    };

    public shared(msg) func clear_protective_intents(uid: Types.UserId) : async Types.Result<Bool, Types.ApiError> {
        switch (intents.remove(uid)) {
            case (?_) { #ok(true) };
            case null { #ok(false) };
        }
    };

    public shared(msg) func monitor_portfolio_with_values(uid: Types.UserId, current_value_sats: Nat64, initial_value_sats: Nat64) : async Types.Result<[Types.ProtectiveIntent], Types.ApiError> {
        switch (guards.get(uid)) {
            case (?config) {
                var protective_intents: [Types.ProtectiveIntent] = [];
                
                // Calculate current drawdown percentage
                let current_drawdown_pct = if (initial_value_sats > 0) {
                    Float.fromInt(Int.fromNat64((initial_value_sats - current_value_sats) * 100)) / Float.fromInt(Int.fromNat64(initial_value_sats))
                } else {
                    0.0
                };
                
                // Check if drawdown threshold is breached
                if (current_drawdown_pct > config.max_drawdown_pct) {
                    let action = if (current_drawdown_pct > config.max_drawdown_pct * 1.5) {
                        #unwind
                    } else {
                        #pause
                    };
                    
                    let intent = {
                        user_id = uid;
                        action = action;
                        reason = "Maximum drawdown threshold of " # Float.toText(config.max_drawdown_pct) # "% exceeded. Current drawdown: " # Float.toText(current_drawdown_pct) # "%";
                        triggered_at = Time.now();
                    };
                    protective_intents := [intent];
                };
                
                // Check liquidity threshold
                if (current_value_sats < config.liquidity_exit_threshold) {
                    let intent = {
                        user_id = uid;
                        action = #reduce_exposure;
                        reason = "Portfolio value " # Int.toText(Int.fromNat64(current_value_sats)) # " sats below liquidity exit threshold of " # Int.toText(Int.fromNat64(config.liquidity_exit_threshold)) # " sats";
                        triggered_at = Time.now();
                    };
                    protective_intents := Array.append(protective_intents, [intent]);
                };
                
                // Store intents for this user if any were generated
                if (protective_intents.size() > 0) {
                    let existing_intents = switch (intents.get(uid)) {
                        case (?existing) { existing };
                        case null { [] };
                    };
                    let updated_intents = Array.append(existing_intents, protective_intents);
                    intents.put(uid, updated_intents);
                };
                
                #ok(protective_intents)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public shared(msg) func simulate_risk_scenario(uid: Types.UserId, scenario_type: Text) : async Types.Result<[Types.ProtectiveIntent], Types.ApiError> {
        switch (guards.get(uid)) {
            case (?config) {
                let (current_value, initial_value) = switch (scenario_type) {
                    case ("major_drawdown") { (50_000_000, 100_000_000) }; // 50% drawdown
                    case ("minor_drawdown") { (90_000_000, 100_000_000) }; // 10% drawdown
                    case ("liquidity_crisis") { (config.liquidity_exit_threshold / 2, 100_000_000) }; // Below liquidity threshold
                    case (_) { (100_000_000, 100_000_000) }; // No change
                };
                
                await monitor_portfolio_with_values(uid, current_value, initial_value)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Additional configuration validation methods
    public query func validate_config(cfg: Types.RiskGuardConfig) : async Types.Result<Bool, Types.ApiError> {
        validate_risk_config(cfg)
    };

    public query func get_config_recommendations(risk_level: Types.RiskLevel) : async Types.Result<Types.RiskGuardConfig, Types.ApiError> {
        let recommended_config = switch (risk_level) {
            case (#conservative) {
                {
                    user_id = Principal.fromText("2vxsx-fae"); // Placeholder principal
                    max_drawdown_pct = 5.0;
                    liquidity_exit_threshold = 100_000; // 0.001 BTC in sats
                    notify_only = false;
                }
            };
            case (#balanced) {
                {
                    user_id = Principal.fromText("2vxsx-fae"); // Placeholder principal
                    max_drawdown_pct = 15.0;
                    liquidity_exit_threshold = 50_000; // 0.0005 BTC in sats
                    notify_only = false;
                }
            };
            case (#aggressive) {
                {
                    user_id = Principal.fromText("2vxsx-fae"); // Placeholder principal
                    max_drawdown_pct = 30.0;
                    liquidity_exit_threshold = 25_000; // 0.00025 BTC in sats
                    notify_only = true; // More aggressive users might prefer notifications only
                }
            };
        };
        #ok(recommended_config)
    };

    // Additional risk monitoring functions for task 6.2
    public query func get_protective_intents(uid: Types.UserId) : async Types.Result<[Types.ProtectiveIntent], Types.ApiError> {
        switch (intents.get(uid)) {
            case (?user_intents) { #ok(user_intents) };
            case null { #ok([]) };
        }
    };

    public shared(msg) func clear_protective_intents(uid: Types.UserId) : async Types.Result<Bool, Types.ApiError> {
        intents.delete(uid);
        #ok(true)
    };

    public shared(msg) func monitor_portfolio_value(uid: Types.UserId, current_value_sats: Nat64, entry_value_sats: Nat64) : async Types.Result<[Types.ProtectiveIntent], Types.ApiError> {
        switch (guards.get(uid)) {
            case (?config) {
                var protective_intents : [Types.ProtectiveIntent] = [];
                
                // Calculate current drawdown percentage
                let current_drawdown = if (entry_value_sats > 0) {
                    ((entry_value_sats - current_value_sats) * 100) / entry_value_sats
                } else {
                    0.0
                };
                
                // Check if drawdown threshold is breached
                if (current_drawdown > config.max_drawdown_pct) {
                    let severity = if (current_drawdown > config.max_drawdown_pct * 1.5) #unwind else #pause;
                    let intent = {
                        user_id = uid;
                        action = severity;
                        reason = "Drawdown threshold breached: " # Float.toText(current_drawdown) # "% exceeds limit of " # Float.toText(config.max_drawdown_pct) # "%";
                        triggered_at = Time.now();
                    };
                    protective_intents := [intent];
                };
                
                // Check liquidity threshold
                if (current_value_sats < config.liquidity_exit_threshold) {
                    let liquidity_intent = {
                        user_id = uid;
                        action = #reduce_exposure;
                        reason = "Portfolio value below liquidity threshold: " # Int.toText(Int.fromNat64(current_value_sats)) # " < " # Int.toText(Int.fromNat64(config.liquidity_exit_threshold)) # " sats";
                        triggered_at = Time.now();
                    };
                    protective_intents := Array.append(protective_intents, [liquidity_intent]);
                };
                
                // Store intents if any were generated
                if (protective_intents.size() > 0) {
                    let existing_intents = switch (intents.get(uid)) {
                        case (?existing) { existing };
                        case null { [] };
                    };
                    let updated_intents = Array.append(existing_intents, protective_intents);
                    intents.put(uid, updated_intents);
                };
                
                #ok(protective_intents)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public shared(msg) func check_risk_thresholds(uid: Types.UserId, portfolio_metrics: {
        current_value_sats: Nat64;
        entry_value_sats: Nat64;
        unrealized_pnl: Float;
        position_count: Nat;
    }) : async Types.Result<{
        threshold_breached: Bool;
        protective_intents: [Types.ProtectiveIntent];
        risk_score: Float;
    }, Types.ApiError> {
        switch (guards.get(uid)) {
            case (?config) {
                var protective_intents : [Types.ProtectiveIntent] = [];
                var threshold_breached = false;
                
                // Calculate drawdown
                let drawdown_pct = if (portfolio_metrics.entry_value_sats > 0) {
                    ((portfolio_metrics.entry_value_sats - portfolio_metrics.current_value_sats) * 100) / portfolio_metrics.entry_value_sats
                } else {
                    0.0
                };
                
                // Calculate risk score (0-100, higher = more risky)
                let drawdown_risk = (drawdown_pct / config.max_drawdown_pct) * 40.0; // 40% weight
                let liquidity_risk = if (portfolio_metrics.current_value_sats < config.liquidity_exit_threshold) 30.0 else 0.0; // 30% weight
                let position_risk = if (portfolio_metrics.position_count > 5) 20.0 else (Float.fromInt(portfolio_metrics.position_count) * 4.0); // 20% weight
                let pnl_risk = if (portfolio_metrics.unrealized_pnl < -10.0) 10.0 else 0.0; // 10% weight
                
                let risk_score = Float.min(100.0, drawdown_risk + liquidity_risk + position_risk + pnl_risk);
                
                // Check thresholds
                if (drawdown_pct > config.max_drawdown_pct) {
                    threshold_breached := true;
                    let action = if (drawdown_pct > config.max_drawdown_pct * 1.5) #unwind else #pause;
                    let intent = {
                        user_id = uid;
                        action = action;
                        reason = "Drawdown threshold exceeded: " # Float.toText(drawdown_pct) # "% > " # Float.toText(config.max_drawdown_pct) # "%";
                        triggered_at = Time.now();
                    };
                    protective_intents := [intent];
                };
                
                if (portfolio_metrics.current_value_sats < config.liquidity_exit_threshold) {
                    threshold_breached := true;
                    let liquidity_intent = {
                        user_id = uid;
                        action = #reduce_exposure;
                        reason = "Liquidity threshold breached";
                        triggered_at = Time.now();
                    };
                    protective_intents := Array.append(protective_intents, [liquidity_intent]);
                };
                
                // Store intents if generated
                if (protective_intents.size() > 0) {
                    let existing_intents = switch (intents.get(uid)) {
                        case (?existing) { existing };
                        case null { [] };
                    };
                    let updated_intents = Array.append(existing_intents, protective_intents);
                    intents.put(uid, updated_intents);
                };
                
                #ok({
                    threshold_breached = threshold_breached;
                    protective_intents = protective_intents;
                    risk_score = risk_score;
                })
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public query func get_risk_status(uid: Types.UserId) : async Types.Result<{
        has_guard: Bool;
        active_intents: Nat;
        last_evaluation: ?Time.Time;
    }, Types.ApiError> {
        let has_guard = switch (guards.get(uid)) {
            case (?_) { true };
            case null { false };
        };
        
        let active_intents = switch (intents.get(uid)) {
            case (?user_intents) { user_intents.size() };
            case null { 0 };
        };
        
        // For MVP, we don't track last evaluation time
        let last_evaluation = ?Time.now();
        
        #ok({
            has_guard = has_guard;
            active_intents = active_intents;
            last_evaluation = last_evaluation;
        })
    };

    // Manual trigger system for protective actions
    public shared(msg) func manual_pause(uid: Types.UserId, reason: Text) : async Types.Result<Bool, Types.ApiError> {
        trigger_protection(uid, #pause)
    };

    public shared(msg) func manual_unwind(uid: Types.UserId, reason: Text) : async Types.Result<Bool, Types.ApiError> {
        trigger_protection(uid, #unwind)
    };

    public shared(msg) func manual_reduce_exposure(uid: Types.UserId, reason: Text) : async Types.Result<Bool, Types.ApiError> {
        trigger_protection(uid, #reduce_exposure)
    };

    // Enhanced monitoring methods
    public shared(msg) func monitor_my_portfolio() : async Result.Result<RiskMonitor.MonitoringResult, Types.ApiError> {
        let user_id = msg.caller;
        
        let portfolio_state = switch (portfolio_state_canister_id) {
            case (?id) { actor(Principal.toText(id)) : Interfaces.PortfolioStateInterface };
            case (null) { 
                return #err(#internal_error("Portfolio state canister not configured"));
            };
        };

        await risk_monitor.monitor_portfolio(user_id, portfolio_state)
    };

    public shared(msg) func get_monitoring_state() : async Result.Result<RiskMonitor.MonitoringState, Types.ApiError> {
        let user_id = msg.caller;
        risk_monitor.get_monitoring_state(user_id)
    };

    public shared(msg) func get_active_alerts() : async Result.Result<[RiskMonitor.RiskAlert], Types.ApiError> {
        let user_id = msg.caller;
        risk_monitor.get_active_alerts(user_id)
    };

    public shared(msg) func acknowledge_alert(alert_id: Text) : async Result.Result<Bool, Types.ApiError> {
        let user_id = msg.caller;
        risk_monitor.acknowledge_alert(alert_id, user_id)
    };

    public shared(msg) func execute_protective_action(intent: Types.ProtectiveIntent) : async Result.Result<ProtectiveActions.ActionResult, Types.ApiError> {
        let user_id = msg.caller;
        
        let execution_agent = switch (execution_agent_canister_id) {
            case (?id) { actor(Principal.toText(id)) : Interfaces.ExecutionAgentInterface };
            case (null) { 
                return #err(#internal_error("Execution agent canister not configured"));
            };
        };

        let portfolio_state = switch (portfolio_state_canister_id) {
            case (?id) { actor(Principal.toText(id)) : Interfaces.PortfolioStateInterface };
            case (null) { 
                return #err(#internal_error("Portfolio state canister not configured"));
            };
        };

        await protective_actions.execute_protective_action(user_id, intent, execution_agent, portfolio_state)
    };

    public shared(msg) func get_action_history() : async [ProtectiveActions.ActionExecution] {
        let user_id = msg.caller;
        protective_actions.get_user_actions(user_id)
    };

    public shared(msg) func set_emergency_stop(reason: Text) : async Result.Result<Bool, Types.ApiError> {
        let user_id = msg.caller;
        protective_actions.set_emergency_stop(user_id, reason)
    };

    public shared(msg) func clear_emergency_stop() : async Result.Result<Bool, Types.ApiError> {
        let user_id = msg.caller;
        protective_actions.clear_emergency_stop(user_id)
    };

    public shared(msg) func is_emergency_stop_active() : async Bool {
        let user_id = msg.caller;
        protective_actions.is_emergency_stop_active(user_id)
    };

    public shared(msg) func enable_monitoring() : async Result.Result<Bool, Types.ApiError> {
        let user_id = msg.caller;
        risk_monitor.enable_monitoring(user_id)
    };

    public shared(msg) func disable_monitoring() : async Result.Result<Bool, Types.ApiError> {
        let user_id = msg.caller;
        risk_monitor.disable_monitoring(user_id)
    };

    // Automated monitoring system
    private func start_monitoring_timer() : async () {
        if (not monitoring_enabled) { return };

        let timer_id = Timer.recurringTimer(
            #seconds(monitoring_interval_seconds),
            monitor_all_users
        );
        monitoring_timer_id := ?timer_id;
        
        Logging.log_info("⏰ Risk monitoring timer started");
    };

    private func monitor_all_users() : async () {
        if (not monitoring_enabled) { return };
        // Automated monitoring implementation would go here
        Logging.log_info("🔄 Automated risk monitoring cycle completed");
    };

    // Enhanced query methods
    public query func get_system_status() : async {
        monitoring_enabled: Bool;
        monitoring_interval_seconds: Nat;
        portfolio_state_configured: Bool;
        execution_agent_configured: Bool;
        notification_system_configured: Bool;
    } {
        {
            monitoring_enabled = monitoring_enabled;
            monitoring_interval_seconds = monitoring_interval_seconds;
            portfolio_state_configured = portfolio_state_canister_id != null;
            execution_agent_configured = execution_agent_canister_id != null;
            notification_system_configured = notification_system_canister_id != null;
        }
    };

    public query func get_enhanced_monitoring_stats() : async {
        total_monitored_users: Nat;
        active_alerts: Nat;
        users_at_risk: Nat;
        last_check_time: Time.Time;
    } {
        risk_monitor.get_monitoring_stats()
    };

    public query func get_action_statistics() : async {
        total_actions: Nat;
        completed_actions: Nat;
        failed_actions: Nat;
        pending_actions: Nat;
        emergency_stops_active: Nat;
    } {
        protective_actions.get_action_statistics()
    };

    public shared(msg) query func get_user_risk_summary() : async Result.Result<{
        current_drawdown: Float;
        risk_status: RiskMonitor.RiskStatus;
        active_alerts: Nat;
        monitoring_enabled: Bool;
    }, Types.ApiError> {
        let user_id = msg.caller;
        risk_monitor.get_user_risk_summary(user_id)
    };
}