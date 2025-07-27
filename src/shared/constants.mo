module {
    // Bitcoin network constants
    public let BITCOIN_CONFIRMATIONS_REQUIRED : Nat32 = 3;
    public let SATOSHIS_PER_BTC : Nat64 = 100_000_000;
    
    // Risk level constants
    public let CONSERVATIVE_MAX_RISK : Float = 0.3;
    public let BALANCED_MAX_RISK : Float = 0.6;
    public let AGGRESSIVE_MAX_RISK : Float = 1.0;
    
    // Strategy constants
    public let MIN_DEPOSIT_SATS : Nat64 = 1_000_000; // 0.01 BTC minimum
    public let MAX_STRATEGY_ALLOCATIONS : Nat = 5;
    
    // Risk guard constants
    public let DEFAULT_MAX_DRAWDOWN : Float = 20.0; // 20%
    public let MIN_LIQUIDITY_THRESHOLD : Nat64 = 100_000; // 0.001 BTC
    
    // Transaction constants
    public let TX_TIMEOUT_SECONDS : Int = 3600; // 1 hour
    public let MAX_RETRY_ATTEMPTS : Nat = 3;
    
    // API rate limiting
    public let MAX_REQUESTS_PER_MINUTE : Nat = 60;
    public let CACHE_TTL_SECONDS : Int = 300; // 5 minutes
    
    // System limits
    public let MAX_USERS_PER_CANISTER : Nat = 10_000;
    public let MAX_TRANSACTIONS_PER_USER : Nat = 1_000;
    
    // Error messages
    public let ERROR_INSUFFICIENT_BALANCE : Text = "Insufficient balance for operation";
    public let ERROR_INVALID_ADDRESS : Text = "Invalid Bitcoin address format";
    public let ERROR_USER_NOT_FOUND : Text = "User not found";
    public let ERROR_STRATEGY_NOT_FOUND : Text = "Strategy not found";
    public let ERROR_PLAN_NOT_FOUND : Text = "Strategy plan not found";
    public let ERROR_UNAUTHORIZED : Text = "Unauthorized access";
}