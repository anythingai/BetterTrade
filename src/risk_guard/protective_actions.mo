import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Float "mo:base/Float";
import Int "mo:base/Int";
import Array "mo:base/Array";
import Iter "mo:base/Iter";

import Types "../shared/types";
import Interfaces "../shared/interfaces";
import Utils "../shared/utils";
import Logging "../shared/logging";

module {
    public type UserId = Types.UserId;
    public type ProtectiveIntent = Types.ProtectiveIntent;
    public type ApiError = Types.ApiError;
    public type Result<T, E> = Result.Result<T, E>;

    public type ActionExecution = {
        action_id: Text;
        user_id: UserId;
        intent: ProtectiveIntent;
        status: ActionStatus;
        initiated_at: Time.Time;
        completed_at: ?Time.Time;
        transaction_ids: [Text];
        error_message: ?Text;
        amount_affected: ?Nat64;
    };

    public type ActionStatus = {
        #pending;
        #in_progress;
        #completed;
        #failed;
        #cancelled;
    };

    public type ActionResult = {
        action_id: Text;
        success: Bool;
        transaction_ids: [Text];
        amount_processed: Nat64;
        message: Text;
    };

    public type EmergencyStop = {
        user_id: UserId;
        reason: Text;
        timestamp: Time.Time;
        active: Bool;
    };

    public class ProtectiveActionSystem() {
        private stable var action_executions_stable : [(Text, ActionExecution)] = [];
        private var action_executions = HashMap.fromIter<Text, ActionExecution>(
            action_executions_stable.vals(), 0, Text.equal, Text.hash
        );

        private stable var emergency_stops_stable : [(UserId, EmergencyStop)] = [];
        private var emergency_stops = HashMap.fromIter<UserId, EmergencyStop>(
            emergency_stops_stable.vals(), 0, Principal.equal, Principal.hash
        );

        private stable var action_counter : Nat = 0;

        // System upgrade hooks
        system func preupgrade() {
            action_executions_stable := action_executions.entries() |> Iter.toArray(_);
            emergency_stops_stable := emergency_stops.entries() |> Iter.toArray(_);
        };

        system func postupgrade() {
            action_executions_stable := [];
            emergency_stops_stable := [];
        };

        // Public interface methods

        public func execute_protective_action(
            user_id: UserId, 
            intent: ProtectiveIntent,
            execution_agent: Interfaces.ExecutionAgentInterface,
            portfolio_state: Interfaces.PortfolioStateInterface
        ) : async Result<ActionResult, ApiError> {
            
            // Check for emergency stop
            switch (emergency_stops.get(user_id)) {
                case (?stop) {
                    if (stop.active) {
                        return #err(#invalid_input("Emergency stop active for user - manual intervention required"));
                    };
                };
                case (null) { /* No emergency stop */ };
            };

            // Generate action ID
            action_counter += 1;
            let action_id = "action_" # Int.toText(Time.now()) # "_" # Nat.toText(action_counter);

            // Create action execution record
            let action_execution : ActionExecution = {
                action_id = action_id;
                user_id = user_id;
                intent = intent;
                status = #pending;
                initiated_at = Time.now();
                completed_at = null;
                transaction_ids = [];
                error_message = null;
                amount_affected = null;
            };
            action_executions.put(action_id, action_execution);

            Logging.log_info("🛡️ Executing protective action: " # debug_show(intent) # " for user: " # Principal.toText(user_id));

            // Execute the specific protective action
            let result = switch (intent) {
                case (#pause) { 
                    await execute_pause_action(user_id, action_id, execution_agent)
                };
                case (#unwind_partial(percentage)) { 
                    await execute_partial_unwind(user_id, action_id, percentage, execution_agent, portfolio_state)
                };
                case (#unwind_full) { 
                    await execute_full_unwind(user_id, action_id, execution_agent, portfolio_state)
                };
                case (#notify_only) { 
                    await execute_notification_only(user_id, action_id)
                };
                case (#emergency_stop) { 
                    await execute_emergency_stop(user_id, action_id)
                };
            };

            // Update action execution status
            switch (result) {
                case (#ok(action_result)) {
                    let updated_execution = {
                        action_execution with
                        status = #completed;
                        completed_at = ?Time.now();
                        transaction_ids = action_result.transaction_ids;
                        amount_affected = ?action_result.amount_processed;
                    };
                    action_executions.put(action_id, updated_execution);
                    
                    Logging.log_info("✅ Protective action completed successfully: " # action_id);
                    #ok(action_result)
                };
                case (#err(error)) {
                    let updated_execution = {
                        action_execution with
                        status = #failed;
                        completed_at = ?Time.now();
                        error_message = ?debug_show(error);
                    };
                    action_executions.put(action_id, updated_execution);
                    
                    Logging.log_error("❌ Protective action failed: " # action_id # " - " # debug_show(error));
                    #err(error)
                };
            };
        };

        public func get_action_status(action_id: Text) : Result<ActionExecution, ApiError> {
            switch (action_executions.get(action_id)) {
                case (?execution) { #ok(execution) };
                case (null) { #err(#not_found("Action execution not found")) };
            }
        };

        public func get_user_actions(user_id: UserId) : [ActionExecution] {
            action_executions.vals()
                |> Iter.filter(_, func(execution: ActionExecution) : Bool { 
                    execution.user_id == user_id 
                })
                |> Iter.toArray(_)
        };

        public func cancel_pending_actions(user_id: UserId) : Result<Nat, ApiError> {
            var cancelled_count = 0;
            
            for ((action_id, execution) in action_executions.entries()) {
                if (execution.user_id == user_id and execution.status == #pending) {
                    let updated_execution = {
                        execution with
                        status = #cancelled;
                        completed_at = ?Time.now();
                    };
                    action_executions.put(action_id, updated_execution);
                    cancelled_count += 1;
                };
            };

            Logging.log_info("🚫 Cancelled " # Nat.toText(cancelled_count) # " pending actions for user: " # Principal.toText(user_id));
            #ok(cancelled_count)
        };

        public func set_emergency_stop(user_id: UserId, reason: Text) : Result<Bool, ApiError> {
            let emergency_stop : EmergencyStop = {
                user_id = user_id;
                reason = reason;
                timestamp = Time.now();
                active = true;
            };
            emergency_stops.put(user_id, emergency_stop);
            
            // Cancel all pending actions
            ignore cancel_pending_actions(user_id);
            
            Logging.log_warning("🚨 Emergency stop activated for user: " # Principal.toText(user_id) # " - " # reason);
            #ok(true)
        };

        public func clear_emergency_stop(user_id: UserId) : Result<Bool, ApiError> {
            switch (emergency_stops.get(user_id)) {
                case (?stop) {
                    let updated_stop = { stop with active = false };
                    emergency_stops.put(user_id, updated_stop);
                    
                    Logging.log_info("✅ Emergency stop cleared for user: " # Principal.toText(user_id));
                    #ok(true)
                };
                case (null) { #err(#not_found("No emergency stop found for user")) };
            }
        };

        // Private implementation methods

        private func execute_pause_action(
            user_id: UserId, 
            action_id: Text,
            execution_agent: Interfaces.ExecutionAgentInterface
        ) : async Result<ActionResult, ApiError> {
            
            // Update action status
            switch (action_executions.get(action_id)) {
                case (?execution) {
                    let updated = { execution with status = #in_progress };
                    action_executions.put(action_id, updated);
                };
                case (null) { /* Should not happen */ };
            };

            // Pause all active strategies for the user
            let pause_result = await execution_agent.pause_user_strategies(user_id);
            
            switch (pause_result) {
                case (#ok(paused_count)) {
                    let result : ActionResult = {
                        action_id = action_id;
                        success = true;
                        transaction_ids = [];
                        amount_processed = 0;
                        message = "Paused " # Nat.toText(paused_count) # " active strategies";
                    };
                    #ok(result)
                };
                case (#err(error)) {
                    #err(#internal_error("Failed to pause strategies: " # debug_show(error)))
                };
            }
        };

        private func execute_partial_unwind(
            user_id: UserId, 
            action_id: Text,
            percentage: Float,
            execution_agent: Interfaces.ExecutionAgentInterface,
            portfolio_state: Interfaces.PortfolioStateInterface
        ) : async Result<ActionResult, ApiError> {
            
            // Validate percentage
            if (percentage <= 0.0 or percentage > 1.0) {
                return #err(#invalid_input("Unwind percentage must be between 0 and 100%"));
            };

            // Update action status
            switch (action_executions.get(action_id)) {
                case (?execution) {
                    let updated = { execution with status = #in_progress };
                    action_executions.put(action_id, updated);
                };
                case (null) { /* Should not happen */ };
            };

            // Get current portfolio
            let portfolio_result = await portfolio_state.get_portfolio(user_id);
            let portfolio = switch (portfolio_result) {
                case (#ok(p)) { p };
                case (#err(e)) { 
                    return #err(#internal_error("Failed to get portfolio: " # debug_show(e)));
                };
            };

            // Calculate amount to unwind
            let total_balance = portfolio.total_balance_sats;
            let unwind_amount = Float.toInt(Float.fromInt(Int.abs(Int.fromNat64(total_balance))) * percentage);
            let unwind_sats = Int.abs(unwind_amount);

            // Execute partial unwind
            let unwind_result = await execution_agent.unwind_positions(user_id, Nat64.fromNat(Int.abs(unwind_sats)));
            
            switch (unwind_result) {
                case (#ok(tx_ids)) {
                    let result : ActionResult = {
                        action_id = action_id;
                        success = true;
                        transaction_ids = tx_ids;
                        amount_processed = Nat64.fromNat(Int.abs(unwind_sats));
                        message = "Unwound " # Float.toText(percentage * 100.0) # "% of portfolio (" # 
                                 Nat64.toText(Nat64.fromNat(Int.abs(unwind_sats))) # " sats)";
                    };
                    #ok(result)
                };
                case (#err(error)) {
                    #err(#internal_error("Failed to unwind positions: " # debug_show(error)))
                };
            }
        };

        private func execute_full_unwind(
            user_id: UserId, 
            action_id: Text,
            execution_agent: Interfaces.ExecutionAgentInterface,
            portfolio_state: Interfaces.PortfolioStateInterface
        ) : async Result<ActionResult, ApiError> {
            
            // Update action status
            switch (action_executions.get(action_id)) {
                case (?execution) {
                    let updated = { execution with status = #in_progress };
                    action_executions.put(action_id, updated);
                };
                case (null) { /* Should not happen */ };
            };

            // Get current portfolio
            let portfolio_result = await portfolio_state.get_portfolio(user_id);
            let portfolio = switch (portfolio_result) {
                case (#ok(p)) { p };
                case (#err(e)) { 
                    return #err(#internal_error("Failed to get portfolio: " # debug_show(e)));
                };
            };

            let total_balance = portfolio.total_balance_sats;

            // Execute full unwind
            let unwind_result = await execution_agent.emergency_withdraw_all(user_id);
            
            switch (unwind_result) {
                case (#ok(tx_ids)) {
                    let result : ActionResult = {
                        action_id = action_id;
                        success = true;
                        transaction_ids = tx_ids;
                        amount_processed = total_balance;
                        message = "Emergency withdrawal of all funds completed (" # 
                                 Nat64.toText(total_balance) # " sats)";
                    };
                    #ok(result)
                };
                case (#err(error)) {
                    #err(#internal_error("Failed to execute emergency withdrawal: " # debug_show(error)))
                };
            }
        };

        private func execute_notification_only(
            user_id: UserId, 
            action_id: Text
        ) : async Result<ActionResult, ApiError> {
            
            // Update action status
            switch (action_executions.get(action_id)) {
                case (?execution) {
                    let updated = { execution with status = #in_progress };
                    action_executions.put(action_id, updated);
                };
                case (null) { /* Should not happen */ };
            };

            // This is just a notification action - no actual protective action taken
            let result : ActionResult = {
                action_id = action_id;
                success = true;
                transaction_ids = [];
                amount_processed = 0;
                message = "Risk threshold notification sent - no protective action taken";
            };
            
            #ok(result)
        };

        private func execute_emergency_stop(
            user_id: UserId, 
            action_id: Text
        ) : async Result<ActionResult, ApiError> {
            
            // Set emergency stop
            let stop_result = set_emergency_stop(user_id, "Automatic emergency stop triggered by risk monitoring");
            
            switch (stop_result) {
                case (#ok(_)) {
                    let result : ActionResult = {
                        action_id = action_id;
                        success = true;
                        transaction_ids = [];
                        amount_processed = 0;
                        message = "Emergency stop activated - all trading halted for user";
                    };
                    #ok(result)
                };
                case (#err(error)) {
                    #err(error)
                };
            }
        };

        // Query methods

        public query func get_action_statistics() : {
            total_actions: Nat;
            completed_actions: Nat;
            failed_actions: Nat;
            pending_actions: Nat;
            emergency_stops_active: Nat;
        } {
            let all_actions = action_executions.vals() |> Iter.toArray(_);
            let completed = Array.filter(all_actions, func(a: ActionExecution) : Bool { a.status == #completed }).size();
            let failed = Array.filter(all_actions, func(a: ActionExecution) : Bool { a.status == #failed }).size();
            let pending = Array.filter(all_actions, func(a: ActionExecution) : Bool { a.status == #pending }).size();
            
            let active_stops = emergency_stops.vals()
                |> Iter.filter(_, func(stop: EmergencyStop) : Bool { stop.active })
                |> Iter.size(_);

            {
                total_actions = all_actions.size();
                completed_actions = completed;
                failed_actions = failed;
                pending_actions = pending;
                emergency_stops_active = active_stops;
            }
        };

        public query func is_emergency_stop_active(user_id: UserId) : Bool {
            switch (emergency_stops.get(user_id)) {
                case (?stop) { stop.active };
                case (null) { false };
            }
        };

        public query func get_recent_actions(limit: ?Nat) : [ActionExecution] {
            let action_limit = switch (limit) {
                case (?l) { l };
                case (null) { 10 };
            };

            let sorted_actions = action_executions.vals()
                |> Iter.toArray(_)
                |> Array.sort(_, func(a: ActionExecution, b: ActionExecution) : {#less; #equal; #greater} {
                    if (a.initiated_at > b.initiated_at) { #less }
                    else if (a.initiated_at < b.initiated_at) { #greater }
                    else { #equal }
                });

            if (sorted_actions.size() <= action_limit) {
                sorted_actions
            } else {
                Array.subArray(sorted_actions, 0, action_limit)
            }
        };
    }
}