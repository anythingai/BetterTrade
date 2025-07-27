import Types "../src/shared/types";
import Interfaces "../src/shared/interfaces";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Array "mo:base/Array";
import HashMap "mo:base/HashMap";
import Result "mo:base/Result";
import Debug "mo:base/Debug";
import Text "mo:base/Text";
import Nat64 "mo:base/Nat64";
import Float "mo:base/Float";

// Demo Scenario Module for BetterTrade Hackathon MVP
// Provides scripted demo walkthrough with test data and reset functionality

module DemoScenario {
    
    // Demo user profiles for consistent demonstrations
    public type DemoUser = {
        principal_id: Principal;
        display_name: Text;
        risk_profile: Types.RiskLevel;
        btc_address: Text;
        initial_balance_sats: Nat64;
    };
    
    // Demo strategy execution results
    public type DemoExecution = {
        user_id: Types.UserId;
        strategy_id: Text;
        txid: Types.TxId;
        amount_sats: Nat64;
        expected_apy: Float;
        status: Types.TxStatus;
    };
    
    // Demo state for presentations
    public type DemoState = {
        users: [DemoUser];
        executions: [DemoExecution];
        current_step: Nat;
        demo_started_at: Int;
    };
    
    // Predefined demo users with different risk profiles
    public let demo_users: [DemoUser] = [
        {
            principal_id = Principal.fromText("demo-conservative-user");
            display_name = "Alice (Conservative)";
            risk_profile = #conservative;
            btc_address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
            initial_balance_sats = 50000000; // 0.5 BTC
        },
        {
            principal_id = Principal.fromText("demo-balanced-user");
            display_name = "Bob (Balanced)";
            risk_profile = #balanced;
            btc_address = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3";
            initial_balance_sats = 100000000; // 1.0 BTC
        },
        {
            principal_id = Principal.fromText("demo-aggressive-user");
            display_name = "Charlie (Aggressive)";
            risk_profile = #aggressive;
            btc_address = "tb1pqqqqp0whnlschrjnfpvy5vgqq7hkrma8ne6smn6ctdybt0020h2qk3k3dn";
            initial_balance_sats = 200000000; // 2.0 BTC
        }
    ];
    
    // Demo strategy templates with realistic data
    public let demo_strategies: [Types.StrategyTemplate] = [
        {
            id = "demo-conservative-lending";
            name = "Conservative Bitcoin Lending";
            risk_level = #conservative;
            venues = ["BlockFi", "Celsius", "Nexo"];
            est_apy_band = (4.5, 6.2);
            params_schema = "{\"min_amount\": 0.01, \"max_allocation\": 0.8}";
        },
        {
            id = "demo-balanced-liquidity";
            name = "Balanced Liquidity Provision";
            risk_level = #balanced;
            venues = ["Uniswap", "SushiSwap", "Curve"];
            est_apy_band = (12.3, 18.7);
            params_schema = "{\"min_amount\": 0.05, \"max_allocation\": 0.6}";
        },
        {
            id = "demo-aggressive-yield";
            name = "Aggressive Yield Farming";
            risk_level = #aggressive;
            venues = ["Yearn", "Convex", "Beefy"];
            est_apy_band = (25.1, 42.8);
            params_schema = "{\"min_amount\": 0.1, \"max_allocation\": 0.4}";
        }
    ];
    
    // Generate mock UTXOs for demo users
    public func generate_demo_utxos(user: DemoUser) : [Types.UTXO] {
        let utxo_count = if (user.initial_balance_sats <= 50000000) { 2 }
                        else if (user.initial_balance_sats <= 100000000) { 3 }
                        else { 4 };
        
        let amount_per_utxo = user.initial_balance_sats / Nat64.fromNat(utxo_count);
        
        Array.tabulate<Types.UTXO>(utxo_count, func(i) {
            {
                txid = "demo_utxo_" # Principal.toText(user.principal_id) # "_" # Nat.toText(i);
                vout = Nat32.fromNat(i);
                amount_sats = amount_per_utxo;
                address = user.btc_address;
                confirmations = 6;
                block_height = ?(800000 + Nat32.fromNat(i));
                spent = false;
                spent_in_tx = null;
            }
        })
    };
    
    // Generate demo transaction history
    public func generate_demo_transactions(user: DemoUser) : [Types.TxRecord] {
        [
            {
                txid = "demo_deposit_" # Principal.toText(user.principal_id);
                user_id = user.principal_id;
                tx_type = #deposit;
                amount_sats = user.initial_balance_sats;
                fee_sats = 1000;
                status = #confirmed;
                confirmed_height = ?799950;
                timestamp = Time.now() - 86400000000000; // 1 day ago
            }
        ]
    };
    
    // Create demo strategy plan for user
    public func create_demo_strategy_plan(user: DemoUser, strategy: Types.StrategyTemplate) : Types.StrategyPlan {
        let plan_id = "demo_plan_" # Principal.toText(user.principal_id) # "_" # strategy.id;
        let allocation_amount = user.initial_balance_sats * 80 / 100; // 80% allocation
        
        let allocations = Array.map<Text, Types.Allocation>(strategy.venues, func(venue) {
            {
                venue_id = venue;
                amount_sats = allocation_amount / Nat64.fromNat(strategy.venues.size());
                percentage = 80.0 / Float.fromInt(strategy.venues.size());
            }
        });
        
        {
            id = plan_id;
            user_id = user.principal_id;
            template_id = strategy.id;
            allocations = allocations;
            created_at = Time.now();
            status = #pending;
            rationale = "Demo strategy recommendation for " # user.display_name # 
                       " with " # debug_show(user.risk_profile) # " risk profile. " #
                       "Expected APY: " # Float.toText(strategy.est_apy_band.0) # "% - " # 
                       Float.toText(strategy.est_apy_band.1) # "%. " #
                       "Diversified across " # Nat.toText(strategy.venues.size()) # " venues.";
        }
    };
    
    // Demo execution results with realistic transaction IDs
    public func create_demo_execution(user: DemoUser, strategy: Types.StrategyTemplate) : DemoExecution {
        {
            user_id = user.principal_id;
            strategy_id = strategy.id;
            txid = "demo_tx_" # Principal.toText(user.principal_id) # "_" # strategy.id;
            amount_sats = user.initial_balance_sats * 80 / 100;
            expected_apy = (strategy.est_apy_band.0 + strategy.est_apy_band.1) / 2.0;
            status = #confirmed;
        }
    };
    
    // Demo portfolio positions after strategy execution
    public func create_demo_positions(user: DemoUser, strategy: Types.StrategyTemplate) : [Types.Position] {
        let allocation_amount = user.initial_balance_sats * 80 / 100;
        let amount_per_venue = allocation_amount / Nat64.fromNat(strategy.venues.size());
        
        Array.map<Text, Types.Position>(strategy.venues, func(venue) {
            {
                user_id = user.principal_id;
                venue_id = venue;
                amount_sats = amount_per_venue;
                entry_price = 45000.0; // Mock BTC price at entry
                current_value = Float.fromInt64(Int64.fromNat64(amount_per_venue)) * 1.05; // 5% gain
                pnl = Float.fromInt64(Int64.fromNat64(amount_per_venue)) * 0.05; // 5% profit
            }
        })
    };
    
    // Demo risk guard configurations
    public func create_demo_risk_guards(user: DemoUser) : Types.RiskGuardConfig {
        let max_drawdown = switch (user.risk_profile) {
            case (#conservative) { 5.0 }; // 5% max drawdown
            case (#balanced) { 10.0 }; // 10% max drawdown
            case (#aggressive) { 20.0 }; // 20% max drawdown
        };
        
        {
            user_id = user.principal_id;
            max_drawdown_pct = max_drawdown;
            liquidity_exit_threshold = user.initial_balance_sats / 10; // 10% of initial balance
            notify_only = user.risk_profile == #aggressive; // Aggressive users get notifications only
        }
    };
    
    // Generate comprehensive demo data set
    public func generate_complete_demo_data() : {
        users: [DemoUser];
        strategies: [Types.StrategyTemplate];
        utxos: [(Types.UserId, [Types.UTXO])];
        transactions: [(Types.UserId, [Types.TxRecord])];
        plans: [Types.StrategyPlan];
        executions: [DemoExecution];
        positions: [(Types.UserId, [Types.Position])];
        risk_guards: [Types.RiskGuardConfig];
    } {
        let users = demo_users;
        let strategies = demo_strategies;
        
        let utxos = Array.map<DemoUser, (Types.UserId, [Types.UTXO])>(users, func(user) {
            (user.principal_id, generate_demo_utxos(user))
        });
        
        let transactions = Array.map<DemoUser, (Types.UserId, [Types.TxRecord])>(users, func(user) {
            (user.principal_id, generate_demo_transactions(user))
        });
        
        let plans = Array.mapFilter<DemoUser, Types.StrategyPlan>(users, func(user) {
            let matching_strategy = Array.find<Types.StrategyTemplate>(strategies, func(s) {
                s.risk_level == user.risk_profile
            });
            switch (matching_strategy) {
                case (?strategy) { ?create_demo_strategy_plan(user, strategy) };
                case null { null };
            }
        });
        
        let executions = Array.mapFilter<DemoUser, DemoExecution>(users, func(user) {
            let matching_strategy = Array.find<Types.StrategyTemplate>(strategies, func(s) {
                s.risk_level == user.risk_profile
            });
            switch (matching_strategy) {
                case (?strategy) { ?create_demo_execution(user, strategy) };
                case null { null };
            }
        });
        
        let positions = Array.mapFilter<DemoUser, (Types.UserId, [Types.Position])>(users, func(user) {
            let matching_strategy = Array.find<Types.StrategyTemplate>(strategies, func(s) {
                s.risk_level == user.risk_profile
            });
            switch (matching_strategy) {
                case (?strategy) { ?(user.principal_id, create_demo_positions(user, strategy)) };
                case null { null };
            }
        });
        
        let risk_guards = Array.map<DemoUser, Types.RiskGuardConfig>(users, create_demo_risk_guards);
        
        {
            users = users;
            strategies = strategies;
            utxos = utxos;
            transactions = transactions;
            plans = plans;
            executions = executions;
            positions = positions;
            risk_guards = risk_guards;
        }
    };
    
    // Demo step definitions for scripted walkthrough
    public type DemoStep = {
        step_number: Nat;
        title: Text;
        description: Text;
        user_actions: [Text];
        expected_results: [Text];
        canister_calls: [Text];
    };
    
    public let demo_steps: [DemoStep] = [
        {
            step_number = 1;
            title = "User Registration and Wallet Connection";
            description = "Demonstrate user onboarding with wallet connection";
            user_actions = [
                "Visit BetterTrade application",
                "Connect Bitcoin wallet",
                "Register with display name 'Alice (Conservative)'",
                "Generate testnet Bitcoin address"
            ];
            expected_results = [
                "User successfully registered",
                "Testnet Bitcoin address generated: tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx",
                "Wallet linked to user account",
                "Dashboard shows 0 BTC balance"
            ];
            canister_calls = [
                "user_registry.register('Alice (Conservative)', null)",
                "user_registry.link_wallet('tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx', #testnet)",
                "execution_agent.get_user_bitcoin_address(user_id, #testnet)"
            ];
        },
        {
            step_number = 2;
            title = "Bitcoin Deposit and Balance Detection";
            description = "Show Bitcoin deposit detection and confirmation tracking";
            user_actions = [
                "Send 0.5 BTC to generated address",
                "Wait for transaction confirmation",
                "Check portfolio balance"
            ];
            expected_results = [
                "Deposit detected after 1 confirmation",
                "Portfolio balance updated to 0.5 BTC",
                "Transaction appears in history",
                "UTXOs available for strategy execution"
            ];
            canister_calls = [
                "portfolio_state.update_balance(user_id, 50000000)",
                "portfolio_state.record_transaction(user_id, deposit_tx)",
                "portfolio_state.get_portfolio(user_id)"
            ];
        },
        {
            step_number = 3;
            title = "Risk Profile Selection";
            description = "Demonstrate risk profile selection and strategy recommendation";
            user_actions = [
                "Navigate to risk profile selection",
                "Select 'Conservative' risk level",
                "View strategy recommendations"
            ];
            expected_results = [
                "Conservative strategies displayed",
                "Top recommendation: Conservative Bitcoin Lending",
                "Expected APY: 4.5% - 6.2%",
                "Detailed rationale provided"
            ];
            canister_calls = [
                "user_registry.set_risk_profile(user_id, #conservative)",
                "strategy_selector.recommend(user_id, #conservative)",
                "strategy_selector.get_recommendations(user_id, #conservative, ?3)"
            ];
        },
        {
            step_number = 4;
            title = "Strategy Approval and Execution";
            description = "Show strategy approval workflow and transaction execution";
            user_actions = [
                "Review recommended strategy details",
                "Approve strategy plan",
                "Monitor execution progress"
            ];
            expected_results = [
                "Strategy plan approved and locked",
                "Bitcoin transaction constructed and signed",
                "Transaction broadcast to testnet",
                "Transaction ID provided for tracking"
            ];
            canister_calls = [
                "strategy_selector.accept_plan(user_id, plan_id)",
                "execution_agent.execute_plan(plan_id)",
                "execution_agent.get_tx_status(txid)"
            ];
        },
        {
            step_number = 5;
            title = "Portfolio Monitoring and Performance";
            description = "Demonstrate portfolio dashboard and performance tracking";
            user_actions = [
                "View updated portfolio dashboard",
                "Check transaction history",
                "Monitor position performance"
            ];
            expected_results = [
                "Active strategy displayed",
                "Positions across 3 lending venues",
                "Real-time performance updates",
                "Transaction history with confirmations"
            ];
            canister_calls = [
                "portfolio_state.get_portfolio(user_id)",
                "portfolio_state.get_positions(user_id)",
                "portfolio_state.get_transaction_history(user_id)"
            ];
        },
        {
            step_number = 6;
            title = "Risk Guard Configuration";
            description = "Show risk protection setup and monitoring";
            user_actions = [
                "Configure maximum drawdown limit (5%)",
                "Enable risk monitoring",
                "Simulate market downturn"
            ];
            expected_results = [
                "Risk guard configured successfully",
                "Continuous portfolio monitoring active",
                "Alert triggered when threshold breached",
                "Protective actions recommended"
            ];
            canister_calls = [
                "risk_guard.set_guard(user_id, risk_config)",
                "risk_guard.get_guard(user_id)",
                "risk_guard.evaluate_portfolio(user_id)"
            ];
        }
    ];
    
    // Demo reset functionality for presentations
    public func reset_demo_state() : {
        users_cleared: Nat;
        transactions_cleared: Nat;
        plans_cleared: Nat;
        positions_cleared: Nat;
    } {
        // This would interface with actual canisters to clear demo data
        // For now, return mock reset statistics
        {
            users_cleared = demo_users.size();
            transactions_cleared = demo_users.size() * 2; // Deposit + execution per user
            plans_cleared = demo_users.size();
            positions_cleared = demo_users.size() * 3; // Average 3 positions per user
        }
    };
    
    // Get current demo step information
    public func get_demo_step(step_number: Nat) : ?DemoStep {
        Array.find<DemoStep>(demo_steps, func(step) {
            step.step_number == step_number
        })
    };
    
    // Get all demo steps for presentation planning
    public func get_all_demo_steps() : [DemoStep] {
        demo_steps
    };
    
    // Validate demo data consistency
    public func validate_demo_data() : {
        valid: Bool;
        errors: [Text];
        warnings: [Text];
    } {
        var errors: [Text] = [];
        var warnings: [Text] = [];
        
        // Validate user data
        if (demo_users.size() == 0) {
            errors := Array.append(errors, ["No demo users defined"]);
        };
        
        // Validate strategy data
        if (demo_strategies.size() == 0) {
            errors := Array.append(errors, ["No demo strategies defined"]);
        };
        
        // Check risk profile coverage
        let risk_levels = Array.map<DemoUser, Types.RiskLevel>(demo_users, func(u) { u.risk_profile });
        let has_conservative = Array.find<Types.RiskLevel>(risk_levels, func(r) { r == #conservative }) != null;
        let has_balanced = Array.find<Types.RiskLevel>(risk_levels, func(r) { r == #balanced }) != null;
        let has_aggressive = Array.find<Types.RiskLevel>(risk_levels, func(r) { r == #aggressive }) != null;
        
        if (not has_conservative) {
            warnings := Array.append(warnings, ["No conservative demo user defined"]);
        };
        if (not has_balanced) {
            warnings := Array.append(warnings, ["No balanced demo user defined"]);
        };
        if (not has_aggressive) {
            warnings := Array.append(warnings, ["No aggressive demo user defined"]);
        };
        
        {
            valid = errors.size() == 0;
            errors = errors;
            warnings = warnings;
        }
    };
}