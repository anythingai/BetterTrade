import Principal "mo:base/Principal";

module {
    // Canister configuration for inter-canister communication
    public type CanisterConfig = {
        user_registry_id: ?Principal;
        portfolio_state_id: ?Principal;
        strategy_selector_id: ?Principal;
        execution_agent_id: ?Principal;
        risk_guard_id: ?Principal;
    };

    // Environment configuration
    public type Environment = {
        #local;
        #testnet;
        #mainnet;
    };

    // Network endpoints and configuration
    public let BITCOIN_TESTNET_ENDPOINT = "https://testnet.bitcoin.org";
    public let BITCOIN_MAINNET_ENDPOINT = "https://bitcoin.org";
    
    // ICP Bitcoin API configuration
    public let ICP_BITCOIN_API_CYCLES = 10_000_000_000; // 10B cycles for Bitcoin API calls
    
    // Default canister configuration (will be updated during deployment)
    public var CANISTER_CONFIG : CanisterConfig = {
        user_registry_id = null;
        portfolio_state_id = null;
        strategy_selector_id = null;
        execution_agent_id = null;
        risk_guard_id = null;
    };

    // Current environment (set during deployment)
    public var CURRENT_ENVIRONMENT : Environment = #local;

    // Update canister configuration
    public func updateCanisterConfig(config: CanisterConfig) {
        CANISTER_CONFIG := config;
    };

    // Update environment
    public func setEnvironment(env: Environment) {
        CURRENT_ENVIRONMENT := env;
    };

    // Get Bitcoin network based on environment
    public func getBitcoinNetwork() : {#mainnet; #testnet; #regtest} {
        switch (CURRENT_ENVIRONMENT) {
            case (#local) { #regtest };
            case (#testnet) { #testnet };
            case (#mainnet) { #mainnet };
        }
    };

    // Get appropriate Bitcoin endpoint
    public func getBitcoinEndpoint() : Text {
        switch (CURRENT_ENVIRONMENT) {
            case (#local) { "http://localhost:18444" };
            case (#testnet) { BITCOIN_TESTNET_ENDPOINT };
            case (#mainnet) { BITCOIN_MAINNET_ENDPOINT };
        }
    };
}