import Time "mo:base/Time";
import Principal "mo:base/Principal";

module {
    // Core ID types
    public type UserId = Principal;
    public type WalletId = Text;
    public type PlanId = Text;
    public type TxId = Text;

    // Risk levels
    public type RiskLevel = {
        #conservative;
        #balanced;
        #aggressive;
    };

    // Network types
    public type Network = {
        #mainnet;
        #testnet;
    };

    // User entity
    public type User = {
        principal_id: Principal;
        display_name: Text;
        created_at: Time.Time;
        risk_profile: RiskLevel;
    };

    // Wallet entity
    public type Wallet = {
        user_id: UserId;
        btc_address: Text;
        network: Network;
        status: WalletStatus;
    };

    public type WalletStatus = {
        #active;
        #inactive;
    };

    // Strategy types
    public type StrategyTemplate = {
        id: Text;
        name: Text;
        risk_level: RiskLevel;
        venues: [Text];
        est_apy_band: (Float, Float);
        params_schema: Text; // JSON schema
    };

    public type StrategyPlan = {
        id: PlanId;
        user_id: UserId;
        template_id: Text;
        allocations: [Allocation];
        created_at: Time.Time;
        status: PlanStatus;
        rationale: Text;
    };

    public type PlanStatus = {
        #pending;
        #approved;
        #executed;
        #failed;
    };

    public type Allocation = {
        venue_id: Text;
        amount_sats: Nat64;
        percentage: Float;
    };

    // Portfolio types
    public type Position = {
        user_id: UserId;
        venue_id: Text;
        amount_sats: Nat64;
        entry_price: Float;
        current_value: Float;
        pnl: Float;
    };

    public type PortfolioSummary = {
        user_id: UserId;
        total_balance_sats: Nat64;
        total_value_usd: Float;
        positions: [Position];
        pnl_24h: Float;
        active_strategy: ?Text;
    };

    // Transaction types
    public type TxRecord = {
        txid: Text;
        user_id: UserId;
        tx_type: TxType;
        amount_sats: Nat64;
        fee_sats: Nat64;
        status: TxStatus;
        confirmed_height: ?Nat32;
        timestamp: Time.Time;
    };

    public type TxType = {
        #deposit;
        #withdraw;
        #strategy_execute;
        #rebalance;
    };

    public type TxStatus = {
        #pending;
        #confirmed;
        #failed;
    };

    // Risk Guard types
    public type RiskGuardConfig = {
        user_id: UserId;
        max_drawdown_pct: Float;
        liquidity_exit_threshold: Nat64;
        notify_only: Bool;
    };

    public type ProtectiveIntent = {
        user_id: UserId;
        action: ProtectiveAction;
        reason: Text;
        triggered_at: Time.Time;
    };

    public type ProtectiveAction = {
        #pause;
        #unwind;
        #reduce_exposure;
    };

    // User summaries for queries
    public type UserSummary = {
        user_id: UserId;
        display_name: Text;
        risk_profile: RiskLevel;
        wallet_count: Nat;
        portfolio_value_sats: Nat64;
    };

    // UTXO types for Bitcoin tracking
    public type UTXO = {
        txid: Text;
        vout: Nat32;
        amount_sats: Nat64;
        address: Text;
        confirmations: Nat32;
        block_height: ?Nat32;
        spent: Bool;
        spent_in_tx: ?Text;
    };

    public type UTXOSet = {
        user_id: UserId;
        utxos: [UTXO];
        total_balance: Nat64;
        confirmed_balance: Nat64; // UTXOs with >= 1 confirmation
        last_updated: Time.Time;
    };

    public type DepositDetection = {
        user_id: UserId;
        address: Text;
        txid: Text;
        amount_sats: Nat64;
        confirmations: Nat32;
        detected_at: Time.Time;
        processed: Bool;
    };

    // API Response types
    public type Result<T, E> = {
        #ok: T;
        #err: E;
    };

    public type ApiError = {
        #not_found;
        #unauthorized;
        #invalid_input: Text;
        #internal_error: Text;
    };
}