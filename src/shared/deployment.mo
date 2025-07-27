import Principal "mo:base/Principal";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Types "./types";
import Config "./config";

module {
    // Deployment configuration for canister management
    public type DeploymentConfig = {
        environment: Config.Environment;
        canister_ids: HashMap.HashMap<Text, Principal>;
        bitcoin_network: {#mainnet; #testnet; #regtest};
    };

    // Initialize deployment configuration
    public func initDeployment(env: Config.Environment) : DeploymentConfig {
        let canister_ids = HashMap.HashMap<Text, Principal>(0, func(a: Text, b: Text) : Bool { a == b }, func(t: Text) : Nat32 { 0 });
        
        let bitcoin_network = switch (env) {
            case (#local) { #regtest };
            case (#testnet) { #testnet };
            case (#mainnet) { #mainnet };
        };

        {
            environment = env;
            canister_ids = canister_ids;
            bitcoin_network = bitcoin_network;
        }
    };

    // Register canister ID after deployment
    public func registerCanister(config: DeploymentConfig, name: Text, principal: Principal) {
        config.canister_ids.put(name, principal);
    };

    // Get canister principal by name
    public func getCanisterPrincipal(config: DeploymentConfig, name: Text) : ?Principal {
        config.canister_ids.get(name)
    };

    // Validate all required canisters are deployed
    public func validateDeployment(config: DeploymentConfig) : Result.Result<Bool, Text> {
        let required_canisters = ["user_registry", "portfolio_state", "strategy_selector", "execution_agent", "risk_guard"];
        
        for (canister in required_canisters.vals()) {
            switch (config.canister_ids.get(canister)) {
                case (null) { return #err("Missing canister: " # canister) };
                case (?_) { /* continue */ };
            };
        };
        
        #ok(true)
    };

    // Get deployment status
    public func getDeploymentStatus(config: DeploymentConfig) : {
        environment: Config.Environment;
        bitcoin_network: {#mainnet; #testnet; #regtest};
        deployed_canisters: [(Text, Principal)];
        is_complete: Bool;
    } {
        let deployed = config.canister_ids.entries() |> Iter.toArray(_);
        let is_complete = switch (validateDeployment(config)) {
            case (#ok(_)) { true };
            case (#err(_)) { false };
        };

        {
            environment = config.environment;
            bitcoin_network = config.bitcoin_network;
            deployed_canisters = deployed;
            is_complete = is_complete;
        }
    };
}