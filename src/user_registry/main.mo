import Types "../shared/types";
import Interfaces "../shared/interfaces";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Debug "mo:base/Debug";

actor UserRegistry : Interfaces.UserRegistryInterface {
    // Stable storage for upgrades
    private stable var users_stable : [(Types.UserId, Types.User)] = [];
    private stable var wallets_stable : [(Types.WalletId, Types.Wallet)] = [];
    private stable var user_wallets_stable : [(Types.UserId, [Types.WalletId])] = [];
    
    // Runtime storage
    private var users = HashMap.HashMap<Types.UserId, Types.User>(0, Principal.equal, Principal.hash);
    private var wallets = HashMap.HashMap<Types.WalletId, Types.Wallet>(0, Text.equal, Text.hash);
    private var user_wallets = HashMap.HashMap<Types.UserId, [Types.WalletId]>(0, Principal.equal, Principal.hash);

    // Initialize from stable storage
    system func preupgrade() {
        users_stable := users.entries() |> Iter.toArray(_);
        wallets_stable := wallets.entries() |> Iter.toArray(_);
        user_wallets_stable := user_wallets.entries() |> Iter.toArray(_);
    };

    system func postupgrade() {
        users := HashMap.fromIter(users_stable.vals(), users_stable.size(), Principal.equal, Principal.hash);
        wallets := HashMap.fromIter(wallets_stable.vals(), wallets_stable.size(), Text.equal, Text.hash);
        user_wallets := HashMap.fromIter(user_wallets_stable.vals(), user_wallets_stable.size(), Principal.equal, Principal.hash);
    };

    // Helper functions
    private func validate_display_name(name: Text) : Bool {
        let name_length = Text.size(name);
        name_length > 0 and name_length <= 50
    };

    private func validate_btc_address(addr: Text, network: Types.Network) : Bool {
        // Basic validation - in production would use proper Bitcoin address validation
        let addr_length = Text.size(addr);
        switch (network) {
            case (#testnet) { 
                addr_length >= 26 and addr_length <= 62 and 
                (Text.startsWith(addr, #text("tb1")) or Text.startsWith(addr, #text("2")) or Text.startsWith(addr, #text("m")) or Text.startsWith(addr, #text("n")))
            };
            case (#mainnet) { 
                addr_length >= 26 and addr_length <= 62 and 
                (Text.startsWith(addr, #text("bc1")) or Text.startsWith(addr, #text("3")) or Text.startsWith(addr, #text("1")))
            };
        }
    };

    private func generate_wallet_id(user_id: Types.UserId, addr: Text) : Types.WalletId {
        Principal.toText(user_id) # ":" # addr
    };

    // User registration with principal ID mapping
    public shared(msg) func register(display_name: Text, email_opt: ?Text) : async Types.Result<Types.UserId, Types.ApiError> {
        let caller = msg.caller;
        
        // Validate input
        if (not validate_display_name(display_name)) {
            return #err(#invalid_input("Display name must be between 1 and 50 characters"));
        };

        // Check if user already exists
        switch (users.get(caller)) {
            case (?existing_user) {
                return #err(#invalid_input("User already registered"));
            };
            case null {};
        };

        // Create new user
        let new_user : Types.User = {
            principal_id = caller;
            display_name = display_name;
            created_at = Time.now();
            risk_profile = #conservative; // Default risk profile
        };

        // Store user
        users.put(caller, new_user);
        user_wallets.put(caller, []);

        Debug.print("User registered: " # Principal.toText(caller) # " with name: " # display_name);
        #ok(caller)
    };

    // Wallet linking for testnet Bitcoin addresses
    public shared(msg) func link_wallet(addr: Text, network: Types.Network) : async Types.Result<Types.WalletId, Types.ApiError> {
        let caller = msg.caller;
        
        // Check if user exists
        switch (users.get(caller)) {
            case null {
                return #err(#not_found);
            };
            case (?user) {};
        };

        // Validate Bitcoin address
        if (not validate_btc_address(addr, network)) {
            return #err(#invalid_input("Invalid Bitcoin address for specified network"));
        };

        // Generate wallet ID
        let wallet_id = generate_wallet_id(caller, addr);

        // Check if wallet already exists
        switch (wallets.get(wallet_id)) {
            case (?existing_wallet) {
                return #err(#invalid_input("Wallet already linked"));
            };
            case null {};
        };

        // Create new wallet
        let new_wallet : Types.Wallet = {
            user_id = caller;
            btc_address = addr;
            network = network;
            status = #active;
        };

        // Store wallet
        wallets.put(wallet_id, new_wallet);

        // Update user's wallet list
        let current_wallets = switch (user_wallets.get(caller)) {
            case (?wallets_list) { wallets_list };
            case null { [] };
        };
        let updated_wallets = Array.append(current_wallets, [wallet_id]);
        user_wallets.put(caller, updated_wallets);

        Debug.print("Wallet linked: " # wallet_id # " for user: " # Principal.toText(caller));
        #ok(wallet_id)
    };

    // User lookup and summary functions
    public query func get_user(uid: Types.UserId) : async Types.Result<Types.UserSummary, Types.ApiError> {
        switch (users.get(uid)) {
            case null {
                #err(#not_found)
            };
            case (?user) {
                let wallet_count = switch (user_wallets.get(uid)) {
                    case (?wallets_list) { wallets_list.size() };
                    case null { 0 };
                };

                let summary : Types.UserSummary = {
                    user_id = uid;
                    display_name = user.display_name;
                    risk_profile = user.risk_profile;
                    wallet_count = wallet_count;
                    portfolio_value_sats = 0; // Will be updated by Portfolio State canister
                };
                #ok(summary)
            };
        }
    };

    // Risk profile setting and retrieval
    public shared(msg) func set_risk_profile(uid: Types.UserId, profile: Types.RiskLevel) : async Types.Result<Bool, Types.ApiError> {
        let caller = msg.caller;
        
        // Only allow users to set their own risk profile or admin access
        if (caller != uid) {
            return #err(#unauthorized);
        };

        switch (users.get(uid)) {
            case null {
                #err(#not_found)
            };
            case (?user) {
                let updated_user : Types.User = {
                    principal_id = user.principal_id;
                    display_name = user.display_name;
                    created_at = user.created_at;
                    risk_profile = profile;
                };
                users.put(uid, updated_user);
                Debug.print("Risk profile updated for user: " # Principal.toText(uid) # " to: " # debug_show(profile));
                #ok(true)
            };
        }
    };

    // Get user's wallets
    public query func get_user_wallets(uid: Types.UserId) : async Types.Result<[Types.Wallet], Types.ApiError> {
        switch (user_wallets.get(uid)) {
            case null {
                #err(#not_found)
            };
            case (?wallet_ids) {
                let user_wallet_list = Array.mapFilter<Types.WalletId, Types.Wallet>(
                    wallet_ids,
                    func(wallet_id: Types.WalletId) : ?Types.Wallet {
                        wallets.get(wallet_id)
                    }
                );
                #ok(user_wallet_list)
            };
        }
    };

    // Wallet status management
    public shared(msg) func update_wallet_status(wallet_id: Types.WalletId, status: Types.WalletStatus) : async Types.Result<Bool, Types.ApiError> {
        let caller = msg.caller;
        
        switch (wallets.get(wallet_id)) {
            case null {
                #err(#not_found)
            };
            case (?wallet) {
                // Only allow wallet owner to update status
                if (caller != wallet.user_id) {
                    return #err(#unauthorized);
                };

                let updated_wallet : Types.Wallet = {
                    user_id = wallet.user_id;
                    btc_address = wallet.btc_address;
                    network = wallet.network;
                    status = status;
                };
                wallets.put(wallet_id, updated_wallet);
                Debug.print("Wallet status updated: " # wallet_id # " to: " # debug_show(status));
                #ok(true)
            };
        }
    };

    // Get wallet by ID
    public query func get_wallet(wallet_id: Types.WalletId) : async Types.Result<Types.Wallet, Types.ApiError> {
        switch (wallets.get(wallet_id)) {
            case null {
                #err(#not_found)
            };
            case (?wallet) {
                #ok(wallet)
            };
        }
    };

    // Admin functions for system management
    public query func get_all_users() : async Types.Result<[Types.UserSummary], Types.ApiError> {
        let user_summaries = Array.map<(Types.UserId, Types.User), Types.UserSummary>(
            users.entries() |> Iter.toArray(_),
            func((uid, user): (Types.UserId, Types.User)) : Types.UserSummary {
                let wallet_count = switch (user_wallets.get(uid)) {
                    case (?wallets_list) { wallets_list.size() };
                    case null { 0 };
                };
                {
                    user_id = uid;
                    display_name = user.display_name;
                    risk_profile = user.risk_profile;
                    wallet_count = wallet_count;
                    portfolio_value_sats = 0; // Will be updated by Portfolio State canister
                }
            }
        );
        #ok(user_summaries)
    };

    // System stats for monitoring
    public query func get_system_stats() : async {user_count: Nat; wallet_count: Nat; active_wallet_count: Nat} {
        let active_wallets = wallets.vals() |> Iter.filter(_, func(w: Types.Wallet) : Bool { w.status == #active }) |> Iter.toArray(_);
        {
            user_count = users.size();
            wallet_count = wallets.size();
            active_wallet_count = active_wallets.size();
        }
    };
}