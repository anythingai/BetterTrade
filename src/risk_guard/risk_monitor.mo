import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Array "mo:base/Array";

import Types "../shared/types";
import Interfaces "../shared/interfaces";
import Utils "../shared/utils";
import Logging "../shared/logging";

module {
    public type UserId = Types.UserId;
    public type RiskGuardConfig = Types.RiskGuardConfig;
    public type PortfolioSummary = Types.PortfolioSummary;
    public type ApiError = Types.ApiError;
    public type Result<T, E> = Result.Result<T, E>;

    public type MonitoringState = {
        user_id: UserId;
        last_check: Time.Time;
        current_drawdown: Float;
        peak_value: Float;
        current_value: Float;
        risk_level: Types.RiskLevel;
        active_alerts: [RiskAlert];
        monitoring_enabled: Bool;
    };

    public type RiskAlert = {
        alert_id: Text;
        user_id: UserId;
        alert_type: RiskAlertType;
        severity: AlertSeverity;
        message: Text;
        timestamp: Time.Time;
        acknowledged: Bool;
    };

    public type RiskAlertType = {
        #drawdown_warning;
        #drawdown_critical;
        #liquidity_low;
        #volatility_high;
        #position_concentration;
    };

    public type AlertSeverity = {
        #info;
        #warning;
        #critical;
        #emergency;
    };

    public type MonitoringResult = {
        user_id: UserId;
        current_status: RiskStatus;
        drawdown_pct: Float;
        alerts_generated: [RiskAlert];
        actions_recommended: [Types.ProtectiveIntent];
        next_check_time: Time.Time;
    };

    public type RiskStatus = {
        #safe;
        #warning;
        #critical;
        #emergency;
    };

    public class RiskMonitor() {
        private stable var user_risk_configs : [(UserId, RiskGuardConfig)] = [];
        private var risk_configs = HashMap.fromIter<UserId, RiskGuardConfig>(
            user_risk_configs.vals(), 0, Principal.equal, Principal.hash
        );

        private stable var monitoring_states_stable : [(UserId, MonitoringState)] = [];
        private var monitoring_states = HashMap.fromIter<UserId, MonitoringState>(
            monitoring_states_stable.vals(), 0, Principal.equal, Principal.hash
        );

        private stable var risk_alerts_stable : [(Text, RiskAlert)] = [];
        private var risk_alerts = HashMap.fromIter<Text, RiskAlert>(
            risk_alerts_stable.vals(), 0, Text.equal, Text.hash
        );

        // Configuration constants
        private let DEFAULT_CHECK_INTERVAL_MS : Int = 30_000; // 30 seconds
        private let DRAWDOWN_WARNING_THRESHOLD : Float = 0.05; // 5%
        private let DRAWDOWN_CRITICAL_THRESHOLD : Float = 0.08; // 8%
        private let HIGH_VOLATILITY_THRESHOLD : Float = 0.20; // 20%

        // System upgrade hooks
        system func preupgrade() {
            user_risk_configs := risk_configs.entries() |> Iter.toArray(_);
            monitoring_states_stable := monitoring_states.entries() |> Iter.toArray(_);
            risk_alerts_stable := risk_alerts.entries() |> Iter.toArray(_);
        };

        system func postupgrade() {
            user_risk_configs := [];
            monitoring_states_stable := [];
            risk_alerts_stable := [];
        };

        // Public interface methods

        public func set_risk_config(user_id: UserId, config: RiskGuardConfig) : Result<Bool, ApiError> {
            // Validate configuration
            if (config.max_drawdown_pct <= 0.0 or config.max_drawdown_pct > 1.0) {
                return #err(#invalid_input("Max drawdown must be between 0 and 100%"));
            };

            risk_configs.put(user_id, config);
            
            // Initialize monitoring state if not exists
            switch (monitoring_states.get(user_id)) {
                case (null) {
                    let initial_state : MonitoringState = {
                        user_id = user_id;
                        last_check = Time.now();
                        current_drawdown = 0.0;
                        peak_value = 0.0;
                        current_value = 0.0;
                        risk_level = #conservative;
                        active_alerts = [];
                        monitoring_enabled = true;
                    };
                    monitoring_states.put(user_id, initial_state);
                };
                case (?existing) {
                    // Update existing state
                    let updated_state = {
                        existing with
                        monitoring_enabled = true;
                    };
                    monitoring_states.put(user_id, updated_state);
                };
            };

            Logging.log_info("🛡️ Risk monitoring configured for user: " # Principal.toText(user_id));
            #ok(true)
        };

        public func get_risk_config(user_id: UserId) : Result<RiskGuardConfig, ApiError> {
            switch (risk_configs.get(user_id)) {
                case (?config) { #ok(config) };
                case (null) { #err(#not_found("Risk configuration not found for user")) };
            }
        };

        public func monitor_portfolio(user_id: UserId, portfolio_state: Interfaces.PortfolioStateInterface) : async Result<MonitoringResult, ApiError> {
            // Get user's risk configuration
            let config = switch (risk_configs.get(user_id)) {
                case (?c) { c };
                case (null) { 
                    return #err(#not_found("Risk configuration not found for user"));
                };
            };

            // Get current portfolio data
            let portfolio_result = await portfolio_state.get_portfolio(user_id);
            let portfolio = switch (portfolio_result) {
                case (#ok(p)) { p };
                case (#err(e)) { 
                    return #err(#internal_error("Failed to get portfolio data: " # debug_show(e)));
                };
            };

            // Get current monitoring state
            let current_state = switch (monitoring_states.get(user_id)) {
                case (?state) { state };
                case (null) {
                    // Initialize new monitoring state
                    let initial_state : MonitoringState = {
                        user_id = user_id;
                        last_check = Time.now();
                        current_drawdown = 0.0;
                        peak_value = portfolio.total_value_usd;
                        current_value = portfolio.total_value_usd;
                        risk_level = #conservative;
                        active_alerts = [];
                        monitoring_enabled = true;
                    };
                    monitoring_states.put(user_id, initial_state);
                    initial_state
                };
            };

            // Calculate current drawdown
            let current_value = portfolio.total_value_usd;
            let peak_value = Float.max(current_state.peak_value, current_value);
            let drawdown = if (peak_value > 0.0) {
                (peak_value - current_value) / peak_value
            } else { 0.0 };

            // Determine risk status
            let risk_status = determine_risk_status(drawdown, config);
            
            // Generate alerts if needed
            let new_alerts = generate_risk_alerts(user_id, drawdown, risk_status, config);
            
            // Store new alerts
            for (alert in new_alerts.vals()) {
                risk_alerts.put(alert.alert_id, alert);
            };

            // Determine recommended actions
            let recommended_actions = determine_protective_actions(drawdown, risk_status, config);

            // Update monitoring state
            let updated_state : MonitoringState = {
                user_id = user_id;
                last_check = Time.now();
                current_drawdown = drawdown;
                peak_value = peak_value;
                current_value = current_value;
                risk_level = portfolio.risk_level;
                active_alerts = Array.append(current_state.active_alerts, new_alerts);
                monitoring_enabled = current_state.monitoring_enabled;
            };
            monitoring_states.put(user_id, updated_state);

            // Log monitoring result
            Logging.log_info("🔍 Portfolio monitored - User: " # Principal.toText(user_id) # 
                           ", Drawdown: " # Float.toText(drawdown * 100.0) # "%" #
                           ", Status: " # debug_show(risk_status));

            let result : MonitoringResult = {
                user_id = user_id;
                current_status = risk_status;
                drawdown_pct = drawdown;
                alerts_generated = new_alerts;
                actions_recommended = recommended_actions;
                next_check_time = Time.now() + DEFAULT_CHECK_INTERVAL_MS;
            };

            #ok(result)
        };

        public func get_monitoring_state(user_id: UserId) : Result<MonitoringState, ApiError> {
            switch (monitoring_states.get(user_id)) {
                case (?state) { #ok(state) };
                case (null) { #err(#not_found("Monitoring state not found for user")) };
            }
        };

        public func get_active_alerts(user_id: UserId) : Result<[RiskAlert], ApiError> {
            let user_alerts = risk_alerts.vals() 
                |> Iter.filter(_, func(alert: RiskAlert) : Bool { 
                    alert.user_id == user_id and not alert.acknowledged 
                })
                |> Iter.toArray(_);
            #ok(user_alerts)
        };

        public func acknowledge_alert(alert_id: Text, user_id: UserId) : Result<Bool, ApiError> {
            switch (risk_alerts.get(alert_id)) {
                case (?alert) {
                    if (alert.user_id != user_id) {
                        return #err(#unauthorized("Cannot acknowledge alert for different user"));
                    };
                    
                    let updated_alert = { alert with acknowledged = true };
                    risk_alerts.put(alert_id, updated_alert);
                    #ok(true)
                };
                case (null) { #err(#not_found("Alert not found")) };
            }
        };

        public func enable_monitoring(user_id: UserId) : Result<Bool, ApiError> {
            switch (monitoring_states.get(user_id)) {
                case (?state) {
                    let updated_state = { state with monitoring_enabled = true };
                    monitoring_states.put(user_id, updated_state);
                    #ok(true)
                };
                case (null) { #err(#not_found("Monitoring state not found for user")) };
            }
        };

        public func disable_monitoring(user_id: UserId) : Result<Bool, ApiError> {
            switch (monitoring_states.get(user_id)) {
                case (?state) {
                    let updated_state = { state with monitoring_enabled = false };
                    monitoring_states.put(user_id, updated_state);
                    #ok(true)
                };
                case (null) { #err(#not_found("Monitoring state not found for user")) };
            }
        };

        // Private helper methods

        private func determine_risk_status(drawdown: Float, config: RiskGuardConfig) : RiskStatus {
            if (drawdown >= config.max_drawdown_pct) {
                #emergency
            } else if (drawdown >= DRAWDOWN_CRITICAL_THRESHOLD) {
                #critical
            } else if (drawdown >= DRAWDOWN_WARNING_THRESHOLD) {
                #warning
            } else {
                #safe
            }
        };

        private func generate_risk_alerts(user_id: UserId, drawdown: Float, status: RiskStatus, config: RiskGuardConfig) : [RiskAlert] {
            var alerts : [RiskAlert] = [];
            let timestamp = Time.now();

            switch (status) {
                case (#warning) {
                    let alert : RiskAlert = {
                        alert_id = generate_alert_id(user_id, timestamp);
                        user_id = user_id;
                        alert_type = #drawdown_warning;
                        severity = #warning;
                        message = "Portfolio drawdown at " # Float.toText(drawdown * 100.0) # "% - approaching risk threshold";
                        timestamp = timestamp;
                        acknowledged = false;
                    };
                    alerts := Array.append(alerts, [alert]);
                };
                case (#critical) {
                    let alert : RiskAlert = {
                        alert_id = generate_alert_id(user_id, timestamp);
                        user_id = user_id;
                        alert_type = #drawdown_critical;
                        severity = #critical;
                        message = "Critical drawdown at " # Float.toText(drawdown * 100.0) # "% - protective actions recommended";
                        timestamp = timestamp;
                        acknowledged = false;
                    };
                    alerts := Array.append(alerts, [alert]);
                };
                case (#emergency) {
                    let alert : RiskAlert = {
                        alert_id = generate_alert_id(user_id, timestamp);
                        user_id = user_id;
                        alert_type = #drawdown_critical;
                        severity = #emergency;
                        message = "Emergency: Maximum drawdown exceeded at " # Float.toText(drawdown * 100.0) # "% - immediate action required";
                        timestamp = timestamp;
                        acknowledged = false;
                    };
                    alerts := Array.append(alerts, [alert]);
                };
                case (#safe) { /* No alerts needed */ };
            };

            alerts
        };

        private func determine_protective_actions(drawdown: Float, status: RiskStatus, config: RiskGuardConfig) : [Types.ProtectiveIntent] {
            switch (status) {
                case (#warning) { [#notify_only] };
                case (#critical) { [#unwind_partial(0.25)] }; // Unwind 25%
                case (#emergency) { [#unwind_full] };
                case (#safe) { [] };
            }
        };

        private func generate_alert_id(user_id: UserId, timestamp: Time.Time) : Text {
            let user_text = Principal.toText(user_id);
            let time_text = Int.toText(timestamp);
            "alert_" # user_text # "_" # time_text
        };

        // Query methods for monitoring statistics

        public query func get_monitoring_stats() : {
            total_monitored_users: Nat;
            active_alerts: Nat;
            users_at_risk: Nat;
            last_check_time: Time.Time;
        } {
            let total_users = monitoring_states.size();
            let active_alert_count = risk_alerts.vals() 
                |> Iter.filter(_, func(alert: RiskAlert) : Bool { not alert.acknowledged })
                |> Iter.size(_);
            
            let at_risk_users = monitoring_states.vals()
                |> Iter.filter(_, func(state: MonitoringState) : Bool { 
                    state.current_drawdown > DRAWDOWN_WARNING_THRESHOLD 
                })
                |> Iter.size(_);

            {
                total_monitored_users = total_users;
                active_alerts = active_alert_count;
                users_at_risk = at_risk_users;
                last_check_time = Time.now();
            }
        };

        public query func get_user_risk_summary(user_id: UserId) : Result<{
            current_drawdown: Float;
            risk_status: RiskStatus;
            active_alerts: Nat;
            monitoring_enabled: Bool;
        }, ApiError> {
            switch (monitoring_states.get(user_id)) {
                case (?state) {
                    let config = switch (risk_configs.get(user_id)) {
                        case (?c) { c };
                        case (null) { 
                            return #err(#not_found("Risk configuration not found"));
                        };
                    };

                    let status = determine_risk_status(state.current_drawdown, config);
                    let alert_count = Array.filter(state.active_alerts, func(alert: RiskAlert) : Bool { 
                        not alert.acknowledged 
                    }).size();

                    #ok({
                        current_drawdown = state.current_drawdown;
                        risk_status = status;
                        active_alerts = alert_count;
                        monitoring_enabled = state.monitoring_enabled;
                    })
                };
                case (null) { #err(#not_found("Monitoring state not found for user")) };
            }
        };
    }
}