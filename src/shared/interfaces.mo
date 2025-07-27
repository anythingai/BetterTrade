import Types "./types";
import Time "mo:base/Time";

module {
    // User Registry Interface
    public type UserRegistryInterface = actor {
        register: shared (display_name: Text, email_opt: ?Text) -> async Types.Result<Types.UserId, Types.ApiError>;
        link_wallet: shared (addr: Text, network: Types.Network) -> async Types.Result<Types.WalletId, Types.ApiError>;
        get_user: query (uid: Types.UserId) -> async Types.Result<Types.UserSummary, Types.ApiError>;
        set_risk_profile: shared (uid: Types.UserId, profile: Types.RiskLevel) -> async Types.Result<Bool, Types.ApiError>;
        get_user_wallets: query (uid: Types.UserId) -> async Types.Result<[Types.Wallet], Types.ApiError>;
        update_wallet_status: shared (wallet_id: Types.WalletId, status: Types.WalletStatus) -> async Types.Result<Bool, Types.ApiError>;
        get_wallet: query (wallet_id: Types.WalletId) -> async Types.Result<Types.Wallet, Types.ApiError>;
        get_all_users: query () -> async Types.Result<[Types.UserSummary], Types.ApiError>;
        get_system_stats: query () -> async {user_count: Nat; wallet_count: Nat; active_wallet_count: Nat};
    };

    // Portfolio State Interface
    public type PortfolioStateInterface = actor {
        update_balance: shared (uid: Types.UserId, amount_sats: Nat64) -> async Types.Result<Bool, Types.ApiError>;
        get_portfolio: query (uid: Types.UserId) -> async Types.Result<Types.PortfolioSummary, Types.ApiError>;
        record_transaction: shared (uid: Types.UserId, tx: Types.TxRecord) -> async Types.Result<Types.TxId, Types.ApiError>;
        get_transaction_history: query (uid: Types.UserId) -> async Types.Result<[Types.TxRecord], Types.ApiError>;
        update_position: shared (uid: Types.UserId, position: Types.Position) -> async Types.Result<Bool, Types.ApiError>;
        
        // UTXO management methods
        add_utxo: shared (uid: Types.UserId, utxo: Types.UTXO) -> async Types.Result<Bool, Types.ApiError>;
        update_utxo_confirmations: shared (txid: Text, confirmations: Nat32, block_height: ?Nat32) -> async Types.Result<Bool, Types.ApiError>;
        mark_utxo_spent: shared (txid: Text, vout: Nat32, spent_in_tx: Text) -> async Types.Result<Bool, Types.ApiError>;
        get_utxos: query (uid: Types.UserId) -> async Types.Result<Types.UTXOSet, Types.ApiError>;
        detect_deposit: shared (uid: Types.UserId, address: Text, txid: Text, amount_sats: Nat64, confirmations: Nat32) -> async Types.Result<Bool, Types.ApiError>;
        get_pending_deposits: query (uid: Types.UserId) -> async Types.Result<[Types.DepositDetection], Types.ApiError>;
        
        // Transaction history and PnL tracking methods
        get_filtered_transaction_history: query (uid: Types.UserId, tx_type: ?Types.TxType, limit: ?Nat) -> async Types.Result<[Types.TxRecord], Types.ApiError>;
        get_detailed_portfolio: query (uid: Types.UserId) -> async Types.Result<Types.PortfolioSummary, Types.ApiError>;
        calculate_portfolio_summary: shared (uid: Types.UserId, current_btc_price: Float) -> async Types.Result<Types.PortfolioSummary, Types.ApiError>;
        get_transaction_stats: query (uid: Types.UserId) -> async Types.Result<{
            total_transactions: Nat;
            total_deposits: Nat64;
            total_withdrawals: Nat64;
            pending_transactions: Nat;
        }, Types.ApiError>;
        
        // Enhanced PnL tracking methods
        get_pnl_history: query (uid: Types.UserId, from_time: ?Time.Time, to_time: ?Time.Time) -> async Types.Result<{
            positions: [Types.Position];
            total_pnl: Float;
            realized_pnl: Float;
            unrealized_pnl: Float;
        }, Types.ApiError>;
        
        get_transaction_history_with_pnl: query (uid: Types.UserId) -> async Types.Result<[{
            transaction: Types.TxRecord;
            pnl_impact: Float;
            portfolio_value_before: Float;
            portfolio_value_after: Float;
        }], Types.ApiError>;
        
        calculate_performance_metrics: shared (uid: Types.UserId, current_btc_price: Float) -> async Types.Result<{
            total_return: Float;
            total_return_percentage: Float;
            best_performing_position: ?Types.Position;
            worst_performing_position: ?Types.Position;
            average_position_pnl: Float;
        }, Types.ApiError>;
    };

    // Strategy Selector Interface
    public type StrategySelectorInterface = actor {
        list_strategies: query () -> async Types.Result<[Types.StrategyTemplate], Types.ApiError>;
        recommend: shared (uid: Types.UserId, risk: Types.RiskLevel) -> async Types.Result<Types.StrategyPlan, Types.ApiError>;
        accept_plan: shared (uid: Types.UserId, plan_id: Types.PlanId) -> async Types.Result<Bool, Types.ApiError>;
        get_plan: query (plan_id: Types.PlanId) -> async Types.Result<Types.StrategyPlan, Types.ApiError>;
        
        // Enhanced plan management methods
        cancel_plan: shared (uid: Types.UserId, plan_id: Types.PlanId) -> async Types.Result<Bool, Types.ApiError>;
        get_user_active_plan: query (uid: Types.UserId) -> async Types.Result<?Types.StrategyPlan, Types.ApiError>;
        execute_approved_plan: shared (plan_id: Types.PlanId, execution_agent: ExecutionAgentInterface) -> async Types.Result<[Types.TxId], Types.ApiError>;
        validate_plan: query (plan_id: Types.PlanId) -> async Types.Result<{
            is_valid: Bool;
            validation_errors: [Text];
            can_execute: Bool;
        }, Types.ApiError>;
        
        // Audit and transparency methods
        get_audit_trail: query (limit: ?Nat) -> async Types.Result<[AuditEntry], Types.ApiError>;
        get_user_audit_trail: query (uid: Types.UserId, limit: ?Nat) -> async Types.Result<[AuditEntry], Types.ApiError>;
    };

    // Execution Agent Interface
    public type ExecutionAgentInterface = actor {
        execute_plan: shared (plan_id: Types.PlanId) -> async Types.Result<[Types.TxId], Types.ApiError>;
        get_tx_status: query (txid: Types.TxId) -> async Types.Result<Types.TxStatus, Types.ApiError>;
        cancel_execution: shared (plan_id: Types.PlanId) -> async Types.Result<Bool, Types.ApiError>;
    };
// Market Monitor Interface
    public type MarketMonitorInterface = actor {
        refresh_rates: shared () -> async Types.Result<Text, Types.ApiError>;
        latest_rates: query () -> async Types.Result<[Types.MarketSnapshot], Types.ApiError>;
    };
// Sentiment Agent Interface
    public type SentimentAgentInterface = actor {
        refresh_sentiment: shared () -> async Types.Result<Float, Types.ApiError>;
        latest_sentiment: query () -> async Types.Result<Float, Types.ApiError>;
    };

    // Risk Guard Interface
    public type RiskGuardInterface = actor {
        set_guard: shared (uid: Types.UserId, cfg: Types.RiskGuardConfig) -> async Types.Result<Bool, Types.ApiError>;
        get_guard: query (uid: Types.UserId) -> async Types.Result<?Types.RiskGuardConfig, Types.ApiError>;
        evaluate_portfolio: shared (uid: Types.UserId) -> async Types.Result<[Types.ProtectiveIntent], Types.ApiError>;
        trigger_protection: shared (uid: Types.UserId, action: Types.ProtectiveAction) -> async Types.Result<Bool, Types.ApiError>;
    };

    // Inter-canister communication types
    public type CanisterPrincipal = Principal;
    
    public type CanisterRegistry = {
        user_registry: CanisterPrincipal;
        portfolio_state: CanisterPrincipal;
        strategy_selector: CanisterPrincipal;
        execution_agent: CanisterPrincipal;
        risk_guard: CanisterPrincipal;
    };

    // Event types for inter-canister communication
    public type SystemEvent = {
        #user_registered: Types.UserId;
        #wallet_linked: (Types.UserId, Types.WalletId);
        #deposit_detected: (Types.UserId, Nat64);
        #strategy_recommended: (Types.UserId, Types.PlanId);
        #strategy_approved: (Types.UserId, Types.PlanId);
        #execution_started: Types.PlanId;
        #execution_completed: (Types.PlanId, [Types.TxId]);
        #risk_threshold_breached: (Types.UserId, Types.ProtectiveIntent);
    };

    // Audit trail for transparency
    public type AuditEntry = {
        timestamp: Time.Time;
        canister: Text;
        action: Text;
        user_id: ?Types.UserId;
        transaction_id: ?Types.TxId;
        details: Text;
    };
}