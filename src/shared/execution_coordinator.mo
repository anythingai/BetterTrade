import Types "./types";
import Interfaces "./interfaces";
import InterCanister "./inter_canister";
import Time "mo:base/Time";
import Principal "mo:base/Principal";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";

module {
    // Strategy execution coordination
    public class ExecutionCoordinator(
        canister_registry: Interfaces.CanisterRegistry,
        communicator: InterCanister.AgentCommunicator
    ) {
        
        // Coordinate the full strategy execution flow
        public func execute_strategy_plan(plan_id: Types.PlanId, user_id: Types.UserId) : async Types.Result<[Types.TxId], Types.ApiError> {
            // Start execution flow tracking
            switch (await communicator.start_execution_flow(plan_id, user_id)) {
                case (#err(error)) return #err(error);
                case (#ok(_)) {};
            };

            // Step 1: Validate plan with Strategy Selector
            switch (await validate_plan_step(plan_id, user_id)) {
                case (#err(error)) return #err(error);
                case (#ok(_)) {};
            };

            // Step 2: Check portfolio state
            switch (await check_portfolio_step(plan_id, user_id)) {
                case (#err(error)) return #err(error);
                case (#ok(_)) {};
            };

            // Step 3: Execute with Execution Agent
            switch (await execute_transaction_step(plan_id, user_id)) {
                case (#err(error)) return #err(error);
                case (#ok(tx_ids)) {
                    // Step 4: Update portfolio state
                    switch (await update_portfolio_step(plan_id, user_id, tx_ids)) {
                        case (#err(error)) return #err(error);
                        case (#ok(_)) {};
                    };

                    // Step 5: Notify completion
                    await notify_completion_step(plan_id, user_id, tx_ids);
                    
                    return #ok(tx_ids);
                };
            };
        };

        // Step 1: Validate plan with Strategy Selector
        private func validate_plan_step(plan_id: Types.PlanId, user_id: Types.UserId) : async Types.Result<(), Types.ApiError> {
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "execution_coordinator";
                action = "validate_plan_start";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "Validating strategy plan with Strategy Selector";
            });

            // Call Strategy Selector to validate plan
            let validation_result = await communicator.call_strategy_selector("validate_plan", plan_id);
            
            switch (validation_result) {
                case (#success(result)) {
                    // Advance execution flow
                    ignore await communicator.advance_execution_flow(plan_id, #validate_plan);
                    
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "validate_plan_success";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Plan validation completed successfully";
                    });

                    // Publish event
                    await communicator.publish_event(
                        #strategy_approved(user_id, plan_id),
                        Principal.fromText("execution_coordinator")
                    );

                    #ok(());
                };
                case (#error(error)) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "validate_plan_error";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Plan validation failed: " # error.message;
                    });
                    #err(#internal_error("Plan validation failed: " # error.message));
                };
                case (_) {
                    #err(#internal_error("Plan validation timeout or retry exhausted"));
                };
            };
        };

        // Step 2: Check portfolio state
        private func check_portfolio_step(plan_id: Types.PlanId, user_id: Types.UserId) : async Types.Result<(), Types.ApiError> {
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "execution_coordinator";
                action = "check_portfolio_start";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "Checking portfolio state before execution";
            });

            // Call Portfolio State to get current portfolio
            let portfolio_result = await communicator.call_portfolio_state("get_portfolio", user_id);
            
            switch (portfolio_result) {
                case (#success(portfolio)) {
                    // Advance execution flow
                    ignore await communicator.advance_execution_flow(plan_id, #check_portfolio);
                    
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "check_portfolio_success";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Portfolio check completed - Balance: " # Nat64.toText(portfolio.total_balance_sats) # " sats";
                    });

                    #ok(());
                };
                case (#error(error)) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "check_portfolio_error";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Portfolio check failed: " # error.message;
                    });
                    #err(#internal_error("Portfolio check failed: " # error.message));
                };
                case (_) {
                    #err(#internal_error("Portfolio check timeout or retry exhausted"));
                };
            };
        };

        // Step 3: Execute transaction with Execution Agent
        private func execute_transaction_step(plan_id: Types.PlanId, user_id: Types.UserId) : async Types.Result<[Types.TxId], Types.ApiError> {
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "execution_coordinator";
                action = "execute_transaction_start";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "Starting transaction execution with Execution Agent";
            });

            // Advance to construct transaction step
            ignore await communicator.advance_execution_flow(plan_id, #check_portfolio);

            // Call Execution Agent to execute plan
            let execution_result = await communicator.call_execution_agent("execute_plan", plan_id);
            
            switch (execution_result) {
                case (#success(tx_ids)) {
                    // Advance through signing and broadcasting steps
                    ignore await communicator.advance_execution_flow(plan_id, #construct_transaction);
                    ignore await communicator.advance_execution_flow(plan_id, #sign_transaction);
                    ignore await communicator.advance_execution_flow(plan_id, #broadcast_transaction);
                    
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "execute_transaction_success";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Transaction execution completed - TxIds: " # debug_show(tx_ids);
                    });

                    // Publish execution started event
                    await communicator.publish_event(
                        #execution_started(plan_id),
                        Principal.fromText("execution_coordinator")
                    );

                    #ok(tx_ids);
                };
                case (#error(error)) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "execute_transaction_error";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Transaction execution failed: " # error.message;
                    });
                    #err(#internal_error("Transaction execution failed: " # error.message));
                };
                case (_) {
                    #err(#internal_error("Transaction execution timeout or retry exhausted"));
                };
            };
        };

        // Step 4: Update portfolio state
        private func update_portfolio_step(plan_id: Types.PlanId, user_id: Types.UserId, tx_ids: [Types.TxId]) : async Types.Result<(), Types.ApiError> {
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "execution_coordinator";
                action = "update_portfolio_start";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "Updating portfolio state after execution";
            });

            // Create transaction records for each tx_id
            for (tx_id in tx_ids.vals()) {
                let tx_record = {
                    txid = tx_id;
                    user_id = user_id;
                    tx_type = #strategy_execute;
                    amount_sats = 0; // This would be filled with actual amounts
                    fee_sats = 0; // This would be filled with actual fees
                    status = #pending;
                    confirmed_height = null;
                    timestamp = Time.now();
                };

                let record_result = await communicator.call_portfolio_state("record_transaction", (user_id, tx_record));
                
                switch (record_result) {
                    case (#success(_)) {
                        communicator.log_audit_entry({
                            timestamp = Time.now();
                            canister = "execution_coordinator";
                            action = "transaction_recorded";
                            user_id = ?user_id;
                            transaction_id = ?tx_id;
                            details = "Transaction record created for tx_id: " # tx_id;
                        });
                    };
                    case (#error(error)) {
                        communicator.log_audit_entry({
                            timestamp = Time.now();
                            canister = "execution_coordinator";
                            action = "transaction_record_error";
                            user_id = ?user_id;
                            transaction_id = ?tx_id;
                            details = "Failed to record transaction: " # error.message;
                        });
                    };
                    case (_) {
                        communicator.log_audit_entry({
                            timestamp = Time.now();
                            canister = "execution_coordinator";
                            action = "transaction_record_timeout";
                            user_id = ?user_id;
                            transaction_id = ?tx_id;
                            details = "Timeout recording transaction: " # tx_id;
                        });
                    };
                };
            };

            // Advance execution flow
            ignore await communicator.advance_execution_flow(plan_id, #update_portfolio);

            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "execution_coordinator";
                action = "update_portfolio_success";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "Portfolio state updated successfully";
            });

            #ok(());
        };

        // Step 5: Notify completion
        private func notify_completion_step(plan_id: Types.PlanId, user_id: Types.UserId, tx_ids: [Types.TxId]) : async () {
            // Advance to final step
            ignore await communicator.advance_execution_flow(plan_id, #notify_completion);

            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "execution_coordinator";
                action = "execution_completed";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "Strategy execution flow completed successfully";
            });

            // Publish completion event
            await communicator.publish_event(
                #execution_completed(plan_id, tx_ids),
                Principal.fromText("execution_coordinator")
            );

            // Notify Risk Guard to monitor the new positions
            let risk_check_result = await communicator.call_risk_guard("evaluate_portfolio", user_id);
            
            switch (risk_check_result) {
                case (#success(protective_intents)) {
                    if (protective_intents.size() > 0) {
                        communicator.log_audit_entry({
                            timestamp = Time.now();
                            canister = "execution_coordinator";
                            action = "risk_alert_triggered";
                            user_id = ?user_id;
                            transaction_id = ?plan_id;
                            details = "Risk Guard detected " # Nat.toText(protective_intents.size()) # " protective intents";
                        });

                        // Publish risk threshold breach events
                        for (intent in protective_intents.vals()) {
                            await communicator.publish_event(
                                #risk_threshold_breached(user_id, intent),
                                Principal.fromText("execution_coordinator")
                            );
                        };
                    };
                };
                case (_) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "risk_check_failed";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Failed to check risk status after execution";
                    });
                };
            };
        };

        // Error recovery and rollback mechanisms
        public func handle_execution_failure(plan_id: Types.PlanId, user_id: Types.UserId, error: Text) : async () {
            communicator.log_audit_entry({
                timestamp = Time.now();
                canister = "execution_coordinator";
                action = "execution_failure_handling";
                user_id = ?user_id;
                transaction_id = ?plan_id;
                details = "Handling execution failure: " # error;
            });

            // Attempt to cancel any pending operations
            let cancel_result = await communicator.call_execution_agent("cancel_execution", plan_id);
            
            switch (cancel_result) {
                case (#success(_)) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "execution_cancelled";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Execution successfully cancelled";
                    });
                };
                case (_) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "execution_cancel_failed";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Failed to cancel execution";
                    });
                };
            };

            // Reset plan status in Strategy Selector
            let reset_result = await communicator.call_strategy_selector("cancel_plan", (user_id, plan_id));
            
            switch (reset_result) {
                case (#success(_)) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "plan_reset";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Plan status reset to cancelled";
                    });
                };
                case (_) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "execution_coordinator";
                        action = "plan_reset_failed";
                        user_id = ?user_id;
                        transaction_id = ?plan_id;
                        details = "Failed to reset plan status";
                    });
                };
            };
        };

        // Health monitoring for execution flows
        public func monitor_execution_health() : async {
            active_flows: Nat;
            stalled_flows: Nat;
            completed_flows_last_hour: Nat;
            failed_flows_last_hour: Nat;
        } {
            let stats = communicator.get_communication_stats();
            let active_flows = communicator.get_active_execution_flows();
            
            // Count stalled flows (running for more than 10 minutes)
            let current_time = Time.now();
            let stall_threshold = 10 * 60 * 1_000_000_000; // 10 minutes in nanoseconds
            
            var stalled_count = 0;
            for (flow in active_flows.vals()) {
                if (current_time - flow.started_at > stall_threshold) {
                    stalled_count += 1;
                };
            };

            // Get recent audit entries to count completions and failures
            let recent_entries = communicator.get_audit_trail(?100);
            let hour_ago = current_time - (60 * 60 * 1_000_000_000); // 1 hour in nanoseconds
            
            var completed_count = 0;
            var failed_count = 0;
            
            for (entry in recent_entries.vals()) {
                if (entry.timestamp > hour_ago) {
                    if (entry.action == "execution_completed") {
                        completed_count += 1;
                    } else if (entry.action == "execution_failure_handling") {
                        failed_count += 1;
                    };
                };
            };

            {
                active_flows = stats.active_flows;
                stalled_flows = stalled_count;
                completed_flows_last_hour = completed_count;
                failed_flows_last_hour = failed_count;
            };
        };
    };
}