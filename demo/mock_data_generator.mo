import Types "../src/shared/types";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Principal "mo:base/Principal";
import Float "mo:base/Float";
import Nat64 "mo:base/Nat64";
import Nat32 "mo:base/Nat32";
import Text "mo:base/Text";
import Random "mo:base/Random";
import Iter "mo:base/Iter";

// Mock Data Generator for BetterTrade Demo
// Generates consistent, realistic test data for demonstrations

module MockDataGenerator {
    
    // Seed for consistent data generation across demo runs
    private let DEMO_SEED : Nat = 12345;
    
    // Mock Bitcoin addresses for different networks
    public let TESTNET_ADDRESSES : [Text] = [
        "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
        "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3",
        "tb1pqqqqp0whnlschrjnfpvy5vgqq7hkrma8ne6smn6ctdybt0020h2qk3k3dn",
        "tb1q9u62588spffmq4dzjxsr5l297znf3z6j5p2688",
        "tb1qm90ugl4d48jv8n6e5t9ln6t9zlpm5th68x4f8g"
    ];
    
    public let MAINNET_ADDRESSES : [Text] = [
        "bc1qw508d6qejxtdg4y5r3zarvary0c5xw7kv8f3t4",
        "bc1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3",
        "bc1pqqqqp0whnlschrjnfpvy5vgqq7hkrma8ne6smn6ctdybt0020h2qsyj7rjq",
        "bc1q9u62588spffmq4dzjxsr5l297znf3z6j5p2688",
        "bc1qm90ugl4d48jv8n6e5t9ln6t9zlpm5th68x4f8g"
    ];
    
    // Mock transaction IDs with realistic format
    public let MOCK_TXIDS : [Text] = [
        "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456",
        "b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567",
        "c3d4e5f6789012345678901234567890abcdef1234567890abcdef12345678",
        "d4e5f6789012345678901234567890abcdef1234567890abcdef123456789",
        "e5f6789012345678901234567890abcdef1234567890abcdef1234567890"
    ];
    
    // Mock venue names for strategy allocations
    public let LENDING_VENUES : [Text] = [
        "BlockFi", "Celsius", "Nexo", "Ledn", "Hodlnaut", "Vauld", "CoinLoan"
    ];
    
    public let LIQUIDITY_VENUES : [Text] = [
        "Uniswap", "SushiSwap", "Curve", "Balancer", "PancakeSwap", "1inch", "dYdX"
    ];
    
    public let YIELD_VENUES : [Text] = [
        "Yearn", "Convex", "Beefy", "Harvest", "Badger", "Pickle", "Alpha"
    ];
    
    // Generate mock UTXO set for a user
    public func generateMockUTXOs(
        user_id: Types.UserId,
        total_amount_sats: Nat64,
        utxo_count: Nat,
        network: Types.Network
    ) : [Types.UTXO] {
        let addresses = switch (network) {
            case (#testnet) { TESTNET_ADDRESSES };
            case (#mainnet) { MAINNET_ADDRESSES };
        };
        
        let amount_per_utxo = total_amount_sats / Nat64.fromNat(utxo_count);
        let user_text = Principal.toText(user_id);
        
        Array.tabulate<Types.UTXO>(utxo_count, func(i) {
            let address_index = i % addresses.size();
            let txid_index = i % MOCK_TXIDS.size();
            
            {
                txid = MOCK_TXIDS[txid_index]!;
                vout = Nat32.fromNat(i);
                amount_sats = if (i == utxo_count - 1) {
                    // Last UTXO gets remainder to ensure exact total
                    total_amount_sats - (amount_per_utxo * Nat64.fromNat(utxo_count - 1))
                } else {
                    amount_per_utxo
                };
                address = addresses[address_index]!;
                confirmations = 6 + Nat32.fromNat(i); // Varying confirmations
                block_height = ?(800000 + Nat32.fromNat(i * 10));
                spent = false;
                spent_in_tx = null;
            }
        })
    };
    
    // Generate mock transaction history
    public func generateMockTransactionHistory(
        user_id: Types.UserId,
        transaction_count: Nat,
        start_time: Int
    ) : [Types.TxRecord] {
        let user_text = Principal.toText(user_id);
        let time_interval = 86400000000000; // 1 day in nanoseconds
        
        Array.tabulate<Types.TxRecord>(transaction_count, func(i) {
            let tx_types : [Types.TxType] = [#deposit, #withdraw, #strategy_execute, #rebalance];
            let statuses : [Types.TxStatus] = [#confirmed, #confirmed, #pending];
            
            let tx_type = tx_types[i % tx_types.size()]!;
            let status = statuses[i % statuses.size()]!;
            let txid_index = i % MOCK_TXIDS.size();
            
            let amount_sats = switch (tx_type) {
                case (#deposit) { 50000000 + Nat64.fromNat(i * 10000000) }; // 0.5+ BTC
                case (#withdraw) { 25000000 + Nat64.fromNat(i * 5000000) }; // 0.25+ BTC
                case (#strategy_execute) { 40000000 + Nat64.fromNat(i * 8000000) }; // 0.4+ BTC
                case (#rebalance) { 10000000 + Nat64.fromNat(i * 2000000) }; // 0.1+ BTC
            };
            
            {
                txid = MOCK_TXIDS[txid_index]!;
                user_id = user_id;
                tx_type = tx_type;
                amount_sats = amount_sats;
                fee_sats = 1000 + Nat64.fromNat(i * 500); // Variable fees
                status = status;
                confirmed_height = if (status == #confirmed) { ?(800000 + Nat32.fromNat(i * 5)) } else { null };
                timestamp = start_time + Int.fromNat(i) * time_interval;
            }
        })
    };
    
    // Generate mock portfolio positions
    public func generateMockPositions(
        user_id: Types.UserId,
        strategy_template: Types.StrategyTemplate,
        total_allocated_sats: Nat64,
        performance_multiplier: Float
    ) : [Types.Position] {
        let venues = strategy_template.venues;
        let amount_per_venue = total_allocated_sats / Nat64.fromNat(venues.size());
        let base_btc_price = 45000.0; // Mock BTC price
        
        Array.mapWithIndex<Text, Types.Position>(venues, func(venue, i) {
            let amount_sats = if (i == venues.size() - 1) {
                // Last position gets remainder
                total_allocated_sats - (amount_per_venue * Nat64.fromNat(venues.size() - 1))
            } else {
                amount_per_venue
            };
            
            let entry_value = Float.fromInt64(Int64.fromNat64(amount_sats)) / 100000000.0 * base_btc_price;
            let current_multiplier = performance_multiplier + (Float.fromInt(i) * 0.01); // Slight variation per venue
            let current_value = entry_value * current_multiplier;
            let pnl = current_value - entry_value;
            
            {
                user_id = user_id;
                venue_id = venue;
                amount_sats = amount_sats;
                entry_price = base_btc_price;
                current_value = current_value;
                pnl = pnl;
            }
        })
    };
    
    // Generate mock strategy plans with realistic allocations
    public func generateMockStrategyPlan(
        user_id: Types.UserId,
        strategy_template: Types.StrategyTemplate,
        total_amount_sats: Nat64,
        allocation_percentage: Float
    ) : Types.StrategyPlan {
        let plan_id = "mock_plan_" # Principal.toText(user_id) # "_" # strategy_template.id;
        let allocated_amount = Nat64.fromNat(Float.toInt(Float.fromInt64(Int64.fromNat64(total_amount_sats)) * allocation_percentage / 100.0));
        
        let allocations = Array.map<Text, Types.Allocation>(strategy_template.venues, func(venue) {
            let venue_amount = allocated_amount / Nat64.fromNat(strategy_template.venues.size());
            let venue_percentage = allocation_percentage / Float.fromInt(strategy_template.venues.size());
            
            {
                venue_id = venue;
                amount_sats = venue_amount;
                percentage = venue_percentage;
            }
        });
        
        let avg_apy = (strategy_template.est_apy_band.0 + strategy_template.est_apy_band.1) / 2.0;
        let rationale = "Mock strategy plan for " # debug_show(strategy_template.risk_level) # 
                       " risk profile. Expected APY: " # Float.toText(avg_apy) # "%. " #
                       "Allocated across " # Nat.toText(strategy_template.venues.size()) # " venues: " #
                       Text.join(", ", strategy_template.venues.vals()) # ".";
        
        {
            id = plan_id;
            user_id = user_id;
            template_id = strategy_template.id;
            allocations = allocations;
            created_at = Time.now();
            status = #pending;
            rationale = rationale;
        }
    };
    
    // Generate mock risk guard configurations
    public func generateMockRiskGuard(
        user_id: Types.UserId,
        risk_profile: Types.RiskLevel,
        portfolio_value_sats: Nat64
    ) : Types.RiskGuardConfig {
        let (max_drawdown, liquidity_threshold, notify_only) = switch (risk_profile) {
            case (#conservative) { (5.0, portfolio_value_sats / 20, false) }; // 5% drawdown, 5% liquidity
            case (#balanced) { (10.0, portfolio_value_sats / 10, false) }; // 10% drawdown, 10% liquidity
            case (#aggressive) { (20.0, portfolio_value_sats / 5, true) }; // 20% drawdown, 20% liquidity
        };
        
        {
            user_id = user_id;
            max_drawdown_pct = max_drawdown;
            liquidity_exit_threshold = liquidity_threshold;
            notify_only = notify_only;
        }
    };
    
    // Generate mock market data for strategy scoring
    public func generateMockMarketConditions(volatility_level: {#low; #medium; #high}) : {
        apy_factor: Float;
        risk_factor: Float;
        liquidity_factor: Float;
        btc_price: Float;
        market_sentiment: Text;
    } {
        switch (volatility_level) {
            case (#low) {
                {
                    apy_factor = 1.0;
                    risk_factor = 0.2;
                    liquidity_factor = 0.9;
                    btc_price = 45000.0;
                    market_sentiment = "Stable market conditions with low volatility";
                }
            };
            case (#medium) {
                {
                    apy_factor = 1.1;
                    risk_factor = 0.4;
                    liquidity_factor = 0.7;
                    btc_price = 42000.0;
                    market_sentiment = "Moderate volatility with mixed signals";
                }
            };
            case (#high) {
                {
                    apy_factor = 1.3;
                    risk_factor = 0.7;
                    liquidity_factor = 0.5;
                    btc_price = 38000.0;
                    market_sentiment = "High volatility with increased risk";
                }
            };
        }
    };
    
    // Generate mock audit entries for transparency
    public func generateMockAuditEntries(
        canister_name: Text,
        entry_count: Nat,
        start_time: Int
    ) : [Types.AuditEntry] {
        let actions = [
            "user_registered", "wallet_linked", "strategy_recommended", 
            "plan_approved", "transaction_signed", "position_updated",
            "risk_threshold_checked", "portfolio_rebalanced"
        ];
        
        let time_interval = 3600000000000; // 1 hour in nanoseconds
        
        Array.tabulate<Types.AuditEntry>(entry_count, func(i) {
            let action = actions[i % actions.size()]!;
            let mock_user_id = Principal.fromText("mock-user-" # Nat.toText(i % 3));
            let mock_tx_id = if (i % 3 == 0) { ?MOCK_TXIDS[i % MOCK_TXIDS.size()]! } else { null };
            
            {
                timestamp = start_time + Int.fromNat(i) * time_interval;
                canister = canister_name;
                action = action;
                user_id = ?mock_user_id;
                transaction_id = mock_tx_id;
                details = "Mock " # action # " event for demonstration purposes";
            }
        })
    };
    
    // Generate comprehensive mock dataset for full demo
    public func generateFullMockDataset() : {
        users: [(Types.UserId, Types.User)];
        wallets: [(Types.WalletId, Types.Wallet)];
        portfolios: [(Types.UserId, Types.PortfolioSummary)];
        utxos: [(Types.UserId, [Types.UTXO])];
        transactions: [(Types.UserId, [Types.TxRecord])];
        positions: [(Types.UserId, [Types.Position])];
        strategy_plans: [Types.StrategyPlan];
        risk_guards: [Types.RiskGuardConfig];
        audit_entries: [Types.AuditEntry];
    } {
        let current_time = Time.now();
        let day_ago = current_time - 86400000000000;
        
        // Mock users
        let mock_users : [(Types.UserId, Types.User)] = [
            (
                Principal.fromText("mock-conservative-user"),
                {
                    principal_id = Principal.fromText("mock-conservative-user");
                    display_name = "Alice (Conservative)";
                    created_at = day_ago;
                    risk_profile = #conservative;
                }
            ),
            (
                Principal.fromText("mock-balanced-user"),
                {
                    principal_id = Principal.fromText("mock-balanced-user");
                    display_name = "Bob (Balanced)";
                    created_at = day_ago;
                    risk_profile = #balanced;
                }
            ),
            (
                Principal.fromText("mock-aggressive-user"),
                {
                    principal_id = Principal.fromText("mock-aggressive-user");
                    display_name = "Charlie (Aggressive)";
                    created_at = day_ago;
                    risk_profile = #aggressive;
                }
            )
        ];
        
        // Mock wallets
        let mock_wallets : [(Types.WalletId, Types.Wallet)] = [
            (
                "mock-conservative-user:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                {
                    user_id = Principal.fromText("mock-conservative-user");
                    btc_address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
                    network = #testnet;
                    status = #active;
                }
            ),
            (
                "mock-balanced-user:tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3",
                {
                    user_id = Principal.fromText("mock-balanced-user");
                    btc_address = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3";
                    network = #testnet;
                    status = #active;
                }
            ),
            (
                "mock-aggressive-user:tb1pqqqqp0whnlschrjnfpvy5vgqq7hkrma8ne6smn6ctdybt0020h2qk3k3dn",
                {
                    user_id = Principal.fromText("mock-aggressive-user");
                    btc_address = "tb1pqqqqp0whnlschrjnfpvy5vgqq7hkrma8ne6smn6ctdybt0020h2qk3k3dn";
                    network = #testnet;
                    status = #active;
                }
            )
        ];
        
        // Generate other mock data using helper functions
        let conservative_user = Principal.fromText("mock-conservative-user");
        let balanced_user = Principal.fromText("mock-balanced-user");
        let aggressive_user = Principal.fromText("mock-aggressive-user");
        
        let mock_portfolios : [(Types.UserId, Types.PortfolioSummary)] = [
            (conservative_user, {
                user_id = conservative_user;
                total_balance_sats = 50000000;
                available_balance_sats = 10000000;
                allocated_balance_sats = 40000000;
                total_pnl_sats = 1000000;
                active_strategies = 1;
                position_count = 3;
            }),
            (balanced_user, {
                user_id = balanced_user;
                total_balance_sats = 100000000;
                available_balance_sats = 20000000;
                allocated_balance_sats = 80000000;
                total_pnl_sats = 3000000;
                active_strategies = 1;
                position_count = 3;
            }),
            (aggressive_user, {
                user_id = aggressive_user;
                total_balance_sats = 200000000;
                available_balance_sats = 40000000;
                allocated_balance_sats = 160000000;
                total_pnl_sats = 8000000;
                active_strategies = 1;
                position_count = 3;
            })
        ];
        
        let mock_utxos = [
            (conservative_user, generateMockUTXOs(conservative_user, 50000000, 2, #testnet)),
            (balanced_user, generateMockUTXOs(balanced_user, 100000000, 3, #testnet)),
            (aggressive_user, generateMockUTXOs(aggressive_user, 200000000, 4, #testnet))
        ];
        
        let mock_transactions = [
            (conservative_user, generateMockTransactionHistory(conservative_user, 3, day_ago)),
            (balanced_user, generateMockTransactionHistory(balanced_user, 4, day_ago)),
            (aggressive_user, generateMockTransactionHistory(aggressive_user, 5, day_ago))
        ];
        
        // Mock strategy templates for position generation
        let conservative_strategy = {
            id = "mock-conservative-lending";
            name = "Conservative Bitcoin Lending";
            risk_level = #conservative;
            venues = ["BlockFi", "Celsius", "Nexo"];
            est_apy_band = (4.5, 6.2);
            params_schema = "{}";
        };
        
        let balanced_strategy = {
            id = "mock-balanced-liquidity";
            name = "Balanced Liquidity Provision";
            risk_level = #balanced;
            venues = ["Uniswap", "SushiSwap", "Curve"];
            est_apy_band = (12.3, 18.7);
            params_schema = "{}";
        };
        
        let aggressive_strategy = {
            id = "mock-aggressive-yield";
            name = "Aggressive Yield Farming";
            risk_level = #aggressive;
            venues = ["Yearn", "Convex", "Beefy"];
            est_apy_band = (25.1, 42.8);
            params_schema = "{}";
        };
        
        let mock_positions = [
            (conservative_user, generateMockPositions(conservative_user, conservative_strategy, 40000000, 1.02)),
            (balanced_user, generateMockPositions(balanced_user, balanced_strategy, 80000000, 1.05)),
            (aggressive_user, generateMockPositions(aggressive_user, aggressive_strategy, 160000000, 1.08))
        ];
        
        let mock_strategy_plans = [
            generateMockStrategyPlan(conservative_user, conservative_strategy, 50000000, 80.0),
            generateMockStrategyPlan(balanced_user, balanced_strategy, 100000000, 80.0),
            generateMockStrategyPlan(aggressive_user, aggressive_strategy, 200000000, 80.0)
        ];
        
        let mock_risk_guards = [
            generateMockRiskGuard(conservative_user, #conservative, 50000000),
            generateMockRiskGuard(balanced_user, #balanced, 100000000),
            generateMockRiskGuard(aggressive_user, #aggressive, 200000000)
        ];
        
        let mock_audit_entries = Array.flatten<Types.AuditEntry>([
            generateMockAuditEntries("user_registry", 5, day_ago),
            generateMockAuditEntries("strategy_selector", 5, day_ago),
            generateMockAuditEntries("execution_agent", 5, day_ago),
            generateMockAuditEntries("portfolio_state", 5, day_ago),
            generateMockAuditEntries("risk_guard", 5, day_ago)
        ]);
        
        {
            users = mock_users;
            wallets = mock_wallets;
            portfolios = mock_portfolios;
            utxos = mock_utxos;
            transactions = mock_transactions;
            positions = mock_positions;
            strategy_plans = mock_strategy_plans;
            risk_guards = mock_risk_guards;
            audit_entries = mock_audit_entries;
        }
    };
    
    // Utility function to create deterministic randomness for consistent demos
    public func createDeterministicRandom(seed: Nat) : {
        nextFloat: () -> Float;
        nextNat: (max: Nat) -> Nat;
        nextBool: () -> Bool;
    } {
        var current_seed = seed;
        
        let nextFloat = func() : Float {
            current_seed := (current_seed * 1103515245 + 12345) % (2 ** 31);
            Float.fromInt(current_seed) / Float.fromInt(2 ** 31)
        };
        
        let nextNat = func(max: Nat) : Nat {
            let f = nextFloat();
            Int.abs(Float.toInt(f * Float.fromInt(max))) % max
        };
        
        let nextBool = func() : Bool {
            nextFloat() > 0.5
        };
        
        { nextFloat = nextFloat; nextNat = nextNat; nextBool = nextBool }
    };
}