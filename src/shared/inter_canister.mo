import Types "./types";
import Interfaces "./interfaces";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";

module {
    // Event-driven communication types
    public type EventBus = {
        var subscribers: [(Text, EventHandler)];
        var event_history: [EventRecord];
    };

    public type EventHandler = (Interfaces.SystemEvent) -> async ();

    public type EventRecord = {
        id: Text;
        event: Interfaces.SystemEvent;
        timestamp: Time.Time;
        source_canister: Principal;
        processed_by: [Principal];
    };

    // Communication protocol types
    public type CommunicationProtocol = {
        #synchronous;
        #asynchronous;
        #event_driven;
    };

    public type InterCanisterCall<T> = {
        target_canister: Principal;
        method_name: Text;
        payload: T;
        protocol: CommunicationProtocol;
        retry_count: Nat;
        timeout_ms: Nat;
        correlation_id: Text;
    };

    public type CallResult<T> = {
        #success: T;
        #error: CallError;
        #timeout;
        #retry_exhausted;
    };

    public type CallError = {
        code: Nat;
        message: Text;
        canister: Principal;
        method: Text;
    };

    // Audit trail types
    public type AuditLogger = {
        var entries: [Interfaces.AuditEntry];
        var max_entries: Nat;
    };

    // Strategy execution flow coordination
    public type ExecutionFlow = {
        plan_id: Types.PlanId;
        user_id: Types.UserId;
        current_step: ExecutionStep;
        steps_completed: [ExecutionStep];
        started_at: Time.Time;
        status: ExecutionFlowStatus;
    };

    public type ExecutionStep = {
        #validate_plan;
        #check_portfolio;
        #construct_transaction;
        #sign_transaction;
        #broadcast_transaction;
        #update_portfolio;
        #notify_completion;
    };

    public type ExecutionFlowStatus = {
        #pending;
        #in_progress;
        #completed;
        #failed: Text;
        #cancelled;
    };

    // Agent communication coordinator
    public class AgentCommunicator(canister_registry: Interfaces.CanisterRegistry) {
        private var audit_logger = AuditLogger {
            var entries = [];
            var max_entries = 1000;
        };

        private var event_bus = EventBus {
            var subscribers = [];
            var event_history = [];
        };

        private var active_flows: [ExecutionFlow] = [];

        // Core communication methods
        public func call_user_registry<T>(method: Text, payload: T) : async CallResult<T> {
            await make_inter_canister_call(canister_registry.user_registry, method, payload, #synchronous);
        };

        public func call_portfolio_state<T>(method: Text, payload: T) : async CallResult<T> {
            await make_inter_canister_call(canister_registry.portfolio_state, method, payload, #synchronous);
        };

        public func call_strategy_selector<T>(method: Text, payload: T) : async CallResult<T> {
            await make_inter_canister_call(canister_registry.strategy_selector, method, payload, #synchronous);
        };

        public func call_execution_agent<T>(method: Text, payload: T) : async CallResult<T> {
            await make_inter_canister_call(canister_registry.execution_agent, method, payload, #asynchronous);
        };

        public func call_risk_guard<T>(method: Text, payload: T) : async CallResult<T> {
            await make_inter_canister_call(canister_registry.risk_guard, method, payload, #event_driven);
        };

        // Generic inter-canister call handler
        private func make_inter_canister_call<T>(
            target: Principal,
            method: Text,
            payload: T,
            protocol: CommunicationProtocol
        ) : async CallResult<T> {
            let correlation_id = generate_correlation_id();
            
            // Log the call attempt
            log_audit_entry({
                timestamp = Time.now();
                canister = Principal.toText(target);
                action = "inter_canister_call_start";
                user_id = null;
                transaction_id = null;
                details = "Method: " # method # ", Protocol: " # debug_show(protocol) # ", CorrelationId: " # correlation_id;
            });

            try {
                switch (protocol) {
                    case (#synchronous) {
                        let result = await execute_synchronous_call(target, method, payload, correlation_id);
                        log_call_completion(target, method, correlation_id, true);
                        result;
                    };
                    case (#asynchronous) {
                        let result = await execute_asynchronous_call(target, method, payload, correlation_id);
                        log_call_completion(target, method, correlation_id, true);
                        result;
                    };
                    case (#event_driven) {
                        let result = await execute_event_driven_call(target, method, payload, correlation_id);
                        log_call_completion(target, method, correlation_id, true);
                        result;
                    };
                };
            } catch (error) {
                log_call_completion(target, method, correlation_id, false);
                #error({
                    code = 500;
                    message = "Inter-canister call failed: " # debug_show(error);
                    canister = target;
                    method = method;
                });
            };
        };

        // Synchronous call execution with immediate response
        private func execute_synchronous_call<T>(
            target: Principal,
            method: Text,
            payload: T,
            correlation_id: Text
        ) : async CallResult<T> {
            // This would be implemented with actual canister calls
            // For now, we'll simulate the structure
            #success(payload); // Placeholder
        };

        // Asynchronous call execution with callback handling
        private func execute_asynchronous_call<T>(
            target: Principal,
            method: Text,
            payload: T,
            correlation_id: Text
        ) : async CallResult<T> {
            // This would be implemented with actual canister calls and callback handling
            // For now, we'll simulate the structure
            #success(payload); // Placeholder
        };

        // Event-driven call execution through event bus
        private func execute_event_driven_call<T>(
            target: Principal,
            method: Text,
            payload: T,
            correlation_id: Text
        ) : async CallResult<T> {
            // This would publish events to the event bus
            // For now, we'll simulate the structure
            #success(payload); // Placeholder
        };

        // Event bus management
        public func subscribe_to_events(event_type: Text, handler: EventHandler) : () {
            let new_subscribers = Buffer.fromArray<(Text, EventHandler)>(event_bus.subscribers);
            new_subscribers.add((event_type, handler));
            event_bus.subscribers := Buffer.toArray(new_subscribers);
        };

        public func publish_event(event: Interfaces.SystemEvent, source: Principal) : async () {
            let event_record = {
                id = generate_correlation_id();
                event = event;
                timestamp = Time.now();
                source_canister = source;
                processed_by = [];
            };

            // Add to event history
            let history_buffer = Buffer.fromArray<EventRecord>(event_bus.event_history);
            history_buffer.add(event_record);
            event_bus.event_history := Buffer.toArray(history_buffer);

            // Notify subscribers
            for ((event_type, handler) in event_bus.subscribers.vals()) {
                try {
                    await handler(event);
                } catch (error) {
                    log_audit_entry({
                        timestamp = Time.now();
                        canister = Principal.toText(source);
                        action = "event_handler_error";
                        user_id = null;
                        transaction_id = null;
                        details = "Event: " # event_type # ", Error: " # debug_show(error);
                    });
                };
            };

            // Log event publication
            log_audit_entry({
                timestamp = Time.now();
                canister = Principal.toText(source);
                action = "event_published";
                user_id = null;
                transaction_id = null;
                details = "Event: " # debug_show(event) # ", EventId: " # event_record.id;
            });
        };

        // Strategy execution flow coordination
        public func start_execution_flow(plan_id: Types.PlanId, user_id: Types.UserId) : async Types.Result<Text, Types.ApiError> {
            let flow = {
                plan_id = plan_id;
                user_id = user_id;
                current_step = #validate_plan;
                steps_completed = [];
                started_at = Time.now();
                status = #pending;
            };

            let flows_buffer = Buffer.fromArray<ExecutionFlow>(active_flows);
            flows_buffer.add(flow);
            active_flows := Buffer.toArray(flows_buffer);

            log_audit_entry({
                timestamp = Time.now();
                canister = "agent_communicator";
                action = "execution_flow_started";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "PlanId: " # plan_id # ", InitialStep: validate_plan";
            });

            #ok("Execution flow started for plan: " # plan_id);
        };

        public func advance_execution_flow(plan_id: Types.PlanId, completed_step: ExecutionStep) : async Types.Result<ExecutionStep, Types.ApiError> {
            // Find and update the flow
            let flows_buffer = Buffer.fromArray<ExecutionFlow>(active_flows);
            var flow_index: ?Nat = null;
            var updated_flow: ?ExecutionFlow = null;

            for (i in flows_buffer.keys()) {
                if (flows_buffer.get(i).plan_id == plan_id) {
                    flow_index := ?i;
                    let current_flow = flows_buffer.get(i);
                    
                    let next_step = get_next_execution_step(completed_step);
                    let completed_steps_buffer = Buffer.fromArray<ExecutionStep>(current_flow.steps_completed);
                    completed_steps_buffer.add(completed_step);

                    updated_flow := ?{
                        plan_id = current_flow.plan_id;
                        user_id = current_flow.user_id;
                        current_step = next_step;
                        steps_completed = Buffer.toArray(completed_steps_buffer);
                        started_at = current_flow.started_at;
                        status = if (next_step == #notify_completion) #completed else #in_progress;
                    };
                    break;
                };
            };

            switch (flow_index, updated_flow) {
                case (?index, ?flow) {
                    flows_buffer.put(index, flow);
                    active_flows := Buffer.toArray(flows_buffer);

                    log_audit_entry({
                        timestamp = Time.now();
                        canister = "agent_communicator";
                        action = "execution_flow_advanced";
                        user_id = ?flow.user_id;
                        transaction_id = ?plan_id;
                        details = "CompletedStep: " # debug_show(completed_step) # ", NextStep: " # debug_show(flow.current_step);
                    });

                    #ok(flow.current_step);
                };
                case (_, _) {
                    #err(#not_found);
                };
            };
        };

        private func get_next_execution_step(current: ExecutionStep) : ExecutionStep {
            switch (current) {
                case (#validate_plan) #check_portfolio;
                case (#check_portfolio) #construct_transaction;
                case (#construct_transaction) #sign_transaction;
                case (#sign_transaction) #broadcast_transaction;
                case (#broadcast_transaction) #update_portfolio;
                case (#update_portfolio) #notify_completion;
                case (#notify_completion) #notify_completion; // Terminal state
            };
        };

        // Audit trail management
        public func log_audit_entry(entry: Interfaces.AuditEntry) : () {
            let entries_buffer = Buffer.fromArray<Interfaces.AuditEntry>(audit_logger.entries);
            entries_buffer.add(entry);

            // Maintain max entries limit
            if (entries_buffer.size() > audit_logger.max_entries) {
                let excess = entries_buffer.size() - audit_logger.max_entries;
                for (i in Array.range(0, excess - 1)) {
                    ignore entries_buffer.remove(0);
                };
            };

            audit_logger.entries := Buffer.toArray(entries_buffer);
        };

        public func get_audit_trail(limit: ?Nat) : [Interfaces.AuditEntry] {
            let entry_limit = switch (limit) {
                case (?l) if (l < audit_logger.entries.size()) l;
                case (_) audit_logger.entries.size();
            };

            let start_index = if (audit_logger.entries.size() > entry_limit) {
                audit_logger.entries.size() - entry_limit;
            } else {
                0;
            };

            Array.tabulate<Interfaces.AuditEntry>(entry_limit, func(i) {
                audit_logger.entries[start_index + i];
            });
        };

        public func get_user_audit_trail(user_id: Types.UserId, limit: ?Nat) : [Interfaces.AuditEntry] {
            let user_entries = Array.filter<Interfaces.AuditEntry>(audit_logger.entries, func(entry) {
                switch (entry.user_id) {
                    case (?uid) uid == user_id;
                    case (null) false;
                };
            });

            let entry_limit = switch (limit) {
                case (?l) if (l < user_entries.size()) l;
                case (_) user_entries.size();
            };

            let start_index = if (user_entries.size() > entry_limit) {
                user_entries.size() - entry_limit;
            } else {
                0;
            };

            Array.tabulate<Interfaces.AuditEntry>(entry_limit, func(i) {
                user_entries[start_index + i];
            });
        };

        // Utility functions
        private func generate_correlation_id() : Text {
            let timestamp = Time.now();
            let random_suffix = Int.abs(timestamp) % 10000;
            "corr_" # Int.toText(timestamp) # "_" # Nat.toText(random_suffix);
        };

        private func log_call_completion(target: Principal, method: Text, correlation_id: Text, success: Bool) : () {
            log_audit_entry({
                timestamp = Time.now();
                canister = Principal.toText(target);
                action = if (success) "inter_canister_call_success" else "inter_canister_call_failure";
                user_id = null;
                transaction_id = null;
                details = "Method: " # method # ", CorrelationId: " # correlation_id;
            });
        };

        // Health check and monitoring
        public func get_communication_stats() : {
            active_flows: Nat;
            total_audit_entries: Nat;
            event_subscribers: Nat;
            event_history_size: Nat;
        } {
            {
                active_flows = active_flows.size();
                total_audit_entries = audit_logger.entries.size();
                event_subscribers = event_bus.subscribers.size();
                event_history_size = event_bus.event_history.size();
            };
        };

        public func get_active_execution_flows() : [ExecutionFlow] {
            Array.filter<ExecutionFlow>(active_flows, func(flow) {
                flow.status == #in_progress or flow.status == #pending;
            });
        };
    };
}