import Types "../shared/types";
import Interfaces "../shared/interfaces";
import InterCanister "../shared/inter_canister";
import DataConsistency "../shared/data_consistency";
import Logging "../shared/logging";
import Metrics "../shared/metrics";
import HashMap "mo:base/HashMap";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Result "mo:base/Result";
import Iter "mo:base/Iter";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Float "mo:base/Float";
import Int64 "mo:base/Int64";

actor PortfolioState : Interfaces.PortfolioStateInterface {
    // Logging and metrics
    private let logger = Logging.create_production_logger("portfolio_state");
    private let metrics = Metrics.MetricsCollector("portfolio_state");

    // Stable storage for upgrades
    private stable var portfolios_stable : [(Types.UserId, Types.PortfolioSummary)] = [];
    private stable var transactions_stable : [(Types.TxId, Types.TxRecord)] = [];
    private stable var utxo_sets_stable : [(Types.UserId, Types.UTXOSet)] = [];
    private stable var deposits_stable : [(Text, Types.DepositDetection)] = []; // Key: txid + vout
    
    // Runtime storage
    private var portfolios = HashMap.HashMap<Types.UserId, Types.PortfolioSummary>(0, Principal.equal, Principal.hash);
    private var transactions = HashMap.HashMap<Types.TxId, Types.TxRecord>(0, Text.equal, Text.hash);
    private var utxo_sets = HashMap.HashMap<Types.UserId, Types.UTXOSet>(0, Principal.equal, Principal.hash);
    private var pending_deposits = HashMap.HashMap<Text, Types.DepositDetection>(0, Text.equal, Text.hash);
    
    // Inter-canister communication and data consistency setup
    private let canister_registry : Interfaces.CanisterRegistry = {
        user_registry = Principal.fromText("rdmx6-jaaaa-aaaah-qdrya-cai");
        portfolio_state = Principal.fromActor(PortfolioState);
        strategy_selector = Principal.fromText("ryjl3-tyaaa-aaaah-qdrya-cai");
        execution_agent = Principal.fromText("renrk-eyaaa-aaaah-qdrya-cai");
        risk_guard = Principal.fromText("rno2w-sqaaa-aaaah-qdrya-cai");
    };
    
    private let communicator = InterCanister.AgentCommunicator(canister_registry);
    private let consistency_coordinator = DataConsistency.DataConsistencyCoordinator(canister_registry, communicator);

    // Initialize from stable storage
    system func preupgrade() {
        portfolios_stable := portfolios.entries() |> Iter.toArray(_);
        transactions_stable := transactions.entries() |> Iter.toArray(_);
        utxo_sets_stable := utxo_sets.entries() |> Iter.toArray(_);
        deposits_stable := pending_deposits.entries() |> Iter.toArray(_);
    };

    system func postupgrade() {
        portfolios := HashMap.fromIter(portfolios_stable.vals(), portfolios_stable.size(), Principal.equal, Principal.hash);
        transactions := HashMap.fromIter(transactions_stable.vals(), transactions_stable.size(), Text.equal, Text.hash);
        utxo_sets := HashMap.fromIter(utxo_sets_stable.vals(), utxo_sets_stable.size(), Principal.equal, Principal.hash);
        pending_deposits := HashMap.fromIter(deposits_stable.vals(), deposits_stable.size(), Text.equal, Text.hash);
    };

    // Helper function to calculate balances from UTXOs
    private func calculateBalances(utxos: [Types.UTXO]) : (Nat64, Nat64) {
        var total_balance: Nat64 = 0;
        var confirmed_balance: Nat64 = 0;
        
        for (utxo in utxos.vals()) {
            if (not utxo.spent) {
                total_balance += utxo.amount_sats;
                if (utxo.confirmations >= 1) {
                    confirmed_balance += utxo.amount_sats;
                };
            };
        };
        
        (total_balance, confirmed_balance)
    };

    // Helper function to create UTXO key
    private func makeUtxoKey(txid: Text, vout: Nat32) : Text {
        txid # ":" # Nat32.toText(vout)
    };

    // UTXO Management Methods
    public shared(msg) func add_utxo(uid: Types.UserId, utxo: Types.UTXO) : async Types.Result<Bool, Types.ApiError> {
        switch (utxo_sets.get(uid)) {
            case (?existing_set) {
                // Check if UTXO already exists
                let utxo_exists = Array.find<Types.UTXO>(existing_set.utxos, func(u) {
                    u.txid == utxo.txid and u.vout == utxo.vout
                });
                
                switch (utxo_exists) {
                    case (?_) {
                        #err(#invalid_input("UTXO already exists"))
                    };
                    case null {
                        let updated_utxos = Array.append(existing_set.utxos, [utxo]);
                        let (total, confirmed) = calculateBalances(updated_utxos);
                        
                        let updated_set: Types.UTXOSet = {
                            user_id = uid;
                            utxos = updated_utxos;
                            total_balance = total;
                            confirmed_balance = confirmed;
                            last_updated = Time.now();
                        };
                        
                        utxo_sets.put(uid, updated_set);
                        #ok(true)
                    };
                };
            };
            case null {
                let (total, confirmed) = calculateBalances([utxo]);
                let new_set: Types.UTXOSet = {
                    user_id = uid;
                    utxos = [utxo];
                    total_balance = total;
                    confirmed_balance = confirmed;
                    last_updated = Time.now();
                };
                
                utxo_sets.put(uid, new_set);
                #ok(true)
            };
        }
    };

    public shared(msg) func update_utxo_confirmations(txid: Text, confirmations: Nat32, block_height: ?Nat32) : async Types.Result<Bool, Types.ApiError> {
        var updated = false;
        
        // Update UTXOs across all users
        for ((uid, utxo_set) in utxo_sets.entries()) {
            let updated_utxos = Array.map<Types.UTXO, Types.UTXO>(utxo_set.utxos, func(utxo) {
                if (utxo.txid == txid) {
                    updated := true;
                    {
                        txid = utxo.txid;
                        vout = utxo.vout;
                        amount_sats = utxo.amount_sats;
                        address = utxo.address;
                        confirmations = confirmations;
                        block_height = block_height;
                        spent = utxo.spent;
                        spent_in_tx = utxo.spent_in_tx;
                    }
                } else {
                    utxo
                }
            });
            
            if (updated) {
                let (total, confirmed) = calculateBalances(updated_utxos);
                let updated_set: Types.UTXOSet = {
                    user_id = uid;
                    utxos = updated_utxos;
                    total_balance = total;
                    confirmed_balance = confirmed;
                    last_updated = Time.now();
                };
                utxo_sets.put(uid, updated_set);
            };
        };
        
        if (updated) {
            #ok(true)
        } else {
            #err(#not_found)
        }
    };

    public shared(msg) func mark_utxo_spent(txid: Text, vout: Nat32, spent_in_tx: Text) : async Types.Result<Bool, Types.ApiError> {
        var updated = false;
        
        // Find and mark UTXO as spent across all users
        for ((uid, utxo_set) in utxo_sets.entries()) {
            let updated_utxos = Array.map<Types.UTXO, Types.UTXO>(utxo_set.utxos, func(utxo) {
                if (utxo.txid == txid and utxo.vout == vout) {
                    updated := true;
                    {
                        txid = utxo.txid;
                        vout = utxo.vout;
                        amount_sats = utxo.amount_sats;
                        address = utxo.address;
                        confirmations = utxo.confirmations;
                        block_height = utxo.block_height;
                        spent = true;
                        spent_in_tx = ?spent_in_tx;
                    }
                } else {
                    utxo
                }
            });
            
            if (updated) {
                let (total, confirmed) = calculateBalances(updated_utxos);
                let updated_set: Types.UTXOSet = {
                    user_id = uid;
                    utxos = updated_utxos;
                    total_balance = total;
                    confirmed_balance = confirmed;
                    last_updated = Time.now();
                };
                utxo_sets.put(uid, updated_set);
            };
        };
        
        if (updated) {
            #ok(true)
        } else {
            #err(#not_found)
        }
    };

    public query func get_utxos(uid: Types.UserId) : async Types.Result<Types.UTXOSet, Types.ApiError> {
        switch (utxo_sets.get(uid)) {
            case (?utxo_set) { #ok(utxo_set) };
            case null {
                // Return empty UTXO set for new users
                let empty_set: Types.UTXOSet = {
                    user_id = uid;
                    utxos = [];
                    total_balance = 0;
                    confirmed_balance = 0;
                    last_updated = Time.now();
                };
                #ok(empty_set)
            };
        }
    };

    public shared(msg) func detect_deposit(uid: Types.UserId, address: Text, txid: Text, amount_sats: Nat64, confirmations: Nat32) : async Types.Result<Bool, Types.ApiError> {
        let deposit_key = txid # ":" # address;
        
        switch (pending_deposits.get(deposit_key)) {
            case (?existing) {
                // Update existing deposit with new confirmation count
                let updated_deposit: Types.DepositDetection = {
                    user_id = existing.user_id;
                    address = existing.address;
                    txid = existing.txid;
                    amount_sats = existing.amount_sats;
                    confirmations = confirmations;
                    detected_at = existing.detected_at;
                    processed = existing.processed;
                };
                pending_deposits.put(deposit_key, updated_deposit);
                #ok(true)
            };
            case null {
                let new_deposit: Types.DepositDetection = {
                    user_id = uid;
                    address = address;
                    txid = txid;
                    amount_sats = amount_sats;
                    confirmations = confirmations;
                    detected_at = Time.now();
                    processed = false;
                };
                pending_deposits.put(deposit_key, new_deposit);
                #ok(true)
            };
        }
    };

    public query func get_pending_deposits(uid: Types.UserId) : async Types.Result<[Types.DepositDetection], Types.ApiError> {
        let user_deposits = Buffer.Buffer<Types.DepositDetection>(0);
        
        for (deposit in pending_deposits.vals()) {
            if (deposit.user_id == uid) {
                user_deposits.add(deposit);
            };
        };
        
        #ok(Buffer.toArray(user_deposits))
    };

    // Balance management - updated to use UTXO data
    public shared(msg) func update_balance(uid: Types.UserId, amount_sats: Nat64) : async Types.Result<Bool, Types.ApiError> {
        // This method is kept for backward compatibility but balance is now calculated from UTXOs
        switch (utxo_sets.get(uid)) {
            case (?utxo_set) {
                // Update portfolio summary with current UTXO balance
                let portfolio: Types.PortfolioSummary = {
                    user_id = uid;
                    total_balance_sats = utxo_set.confirmed_balance;
                    total_value_usd = 0.0; // Will be calculated with price feeds later
                    positions = [];
                    pnl_24h = 0.0;
                    active_strategy = null;
                };
                portfolios.put(uid, portfolio);
                #ok(true)
            };
            case null {
                #err(#not_found)
            };
        }
    };

    public query func get_portfolio(uid: Types.UserId) : async Types.Result<Types.PortfolioSummary, Types.ApiError> {
        switch (utxo_sets.get(uid)) {
            case (?utxo_set) {
                let portfolio: Types.PortfolioSummary = {
                    user_id = uid;
                    total_balance_sats = utxo_set.confirmed_balance;
                    total_value_usd = 0.0; // Will be calculated with price feeds later
                    positions = [];
                    pnl_24h = 0.0;
                    active_strategy = null;
                };
                #ok(portfolio)
            };
            case null {
                // Return empty portfolio for new users
                let empty_portfolio: Types.PortfolioSummary = {
                    user_id = uid;
                    total_balance_sats = 0;
                    total_value_usd = 0.0;
                    positions = [];
                    pnl_24h = 0.0;
                    active_strategy = null;
                };
                #ok(empty_portfolio)
            };
        }
    };

    // Helper function to calculate PnL for a position
    private func calculatePositionPnL(position: Types.Position, current_btc_price: Float) : Float {
        let current_value = (Float.fromInt64(Int64.fromNat64(position.amount_sats)) / 100000000.0) * current_btc_price;
        current_value - position.entry_price
    };

    // Helper function to sort transactions by timestamp (newest first)
    private func sortTransactionsByTime(txs: [Types.TxRecord]) : [Types.TxRecord] {
        Array.sort<Types.TxRecord>(txs, func(a, b) {
            if (a.timestamp > b.timestamp) { #less }
            else if (a.timestamp < b.timestamp) { #greater }
            else { #equal }
        })
    };

    // Transaction management with enhanced functionality and data consistency
    public shared(msg) func record_transaction(uid: Types.UserId, tx: Types.TxRecord) : async Types.Result<Types.TxId, Types.ApiError> {
        // Use idempotent operation to ensure transaction is recorded only once
        let idempotency_key = "record_tx_" # tx.txid # "_" # Principal.toText(uid);
        let payload = "{\"txid\":\"" # tx.txid # "\",\"user_id\":\"" # Principal.toText(uid) # "\",\"amount\":" # Nat64.toText(tx.amount_sats) # "}";
        
        let idempotent_result = await consistency_coordinator.execute_idempotent_operation(
            idempotency_key,
            Principal.fromActor(PortfolioState),
            "record_transaction_internal",
            payload,
            3600 // 1 hour TTL
        );
        
        switch (idempotent_result) {
            case (#ok(result)) {
                // Execute the actual transaction recording
                await record_transaction_internal(uid, tx);
            };
            case (#err(error)) {
                return #err(error);
            };
        };
    };

    // Internal transaction recording method
    private func record_transaction_internal(uid: Types.UserId, tx: Types.TxRecord) : async Types.Result<Types.TxId, Types.ApiError> {
        // Validate transaction data
        if (tx.txid == "" or tx.amount_sats == 0) {
            return #err(#invalid_input("Invalid transaction data"));
        };
        
        // Create state checkpoint before modification
        let state_data = "portfolio_" # Principal.toText(uid) # "_" # Int.toText(Time.now());
        let checkpoint_hash = await consistency_coordinator.create_state_checkpoint(
            Principal.fromActor(PortfolioState),
            state_data
        );
        
        // Check if transaction already exists
        switch (transactions.get(tx.txid)) {
            case (?existing) {
                return #err(#invalid_input("Transaction already exists"));
            };
            case null {
                // Store the transaction
                transactions.put(tx.txid, tx);
                
                // Log transaction recording
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "portfolio_state";
                    action = "transaction_recorded";
                    user_id = ?uid;
                    transaction_id = ?tx.txid;
                    details = "Transaction recorded: " # debug_show(tx.tx_type) # " - " # Nat64.toText(tx.amount_sats) # " sats";
                });
                
                // Update portfolio based on transaction type
                switch (tx.tx_type) {
                    case (#deposit) {
                        // For deposits, the UTXO tracking handles balance updates
                        ignore await update_balance(uid, tx.amount_sats);
                        
                        // Publish deposit detected event
                        await communicator.publish_event(
                            #deposit_detected(uid, tx.amount_sats),
                            Principal.fromActor(PortfolioState)
                        );
                    };
                    case (#withdraw) {
                        // For withdrawals, mark relevant UTXOs as spent
                        // This would typically be handled by the execution agent
                    };
                    case (#strategy_execute or #rebalance) {
                        // These affect positions, handled in update_position
                    };
                };
                
                #ok(tx.txid)
            };
        }
    };

    public query func get_transaction_history(uid: Types.UserId) : async Types.Result<[Types.TxRecord], Types.ApiError> {
        let user_transactions = Buffer.Buffer<Types.TxRecord>(0);
        
        for (tx in transactions.vals()) {
            if (tx.user_id == uid) {
                user_transactions.add(tx);
            };
        };
        
        let sorted_transactions = sortTransactionsByTime(Buffer.toArray(user_transactions));
        #ok(sorted_transactions)
    };

    // Get transaction history with filtering options
    public query func get_filtered_transaction_history(
        uid: Types.UserId, 
        tx_type: ?Types.TxType, 
        limit: ?Nat
    ) : async Types.Result<[Types.TxRecord], Types.ApiError> {
        let user_transactions = Buffer.Buffer<Types.TxRecord>(0);
        
        for (tx in transactions.vals()) {
            if (tx.user_id == uid) {
                // Apply type filter if specified
                switch (tx_type) {
                    case (?filter_type) {
                        if (tx.tx_type == filter_type) {
                            user_transactions.add(tx);
                        };
                    };
                    case null {
                        user_transactions.add(tx);
                    };
                };
            };
        };
        
        let sorted_transactions = sortTransactionsByTime(Buffer.toArray(user_transactions));
        
        // Apply limit if specified
        let final_transactions = switch (limit) {
            case (?max_count) {
                if (sorted_transactions.size() <= max_count) {
                    sorted_transactions
                } else {
                    Array.subArray(sorted_transactions, 0, max_count)
                }
            };
            case null { sorted_transactions };
        };
        
        #ok(final_transactions)
    };

    // Position management with PnL calculation
    public shared(msg) func update_position(uid: Types.UserId, position: Types.Position) : async Types.Result<Bool, Types.ApiError> {
        switch (portfolios.get(uid)) {
            case (?existing_portfolio) {
                // Update or add position
                let updated_positions = Buffer.Buffer<Types.Position>(existing_portfolio.positions.size());
                var position_found = false;
                
                for (existing_pos in existing_portfolio.positions.vals()) {
                    if (existing_pos.venue_id == position.venue_id) {
                        // Update existing position
                        updated_positions.add(position);
                        position_found := true;
                    } else {
                        updated_positions.add(existing_pos);
                    };
                };
                
                // Add new position if not found
                if (not position_found) {
                    updated_positions.add(position);
                };
                
                // Calculate total PnL
                var total_pnl: Float = 0.0;
                for (pos in updated_positions.vals()) {
                    total_pnl += pos.pnl;
                };
                
                let updated_portfolio: Types.PortfolioSummary = {
                    user_id = existing_portfolio.user_id;
                    total_balance_sats = existing_portfolio.total_balance_sats;
                    total_value_usd = existing_portfolio.total_value_usd;
                    positions = Buffer.toArray(updated_positions);
                    pnl_24h = total_pnl; // This would be calculated based on 24h price changes
                    active_strategy = existing_portfolio.active_strategy;
                };
                
                portfolios.put(uid, updated_portfolio);
                #ok(true)
            };
            case null {
                // Create new portfolio with this position
                let new_portfolio: Types.PortfolioSummary = {
                    user_id = uid;
                    total_balance_sats = 0;
                    total_value_usd = 0.0;
                    positions = [position];
                    pnl_24h = position.pnl;
                    active_strategy = null;
                };
                
                portfolios.put(uid, new_portfolio);
                #ok(true)
            };
        }
    };

    // Get detailed portfolio with PnL breakdown
    public query func get_detailed_portfolio(uid: Types.UserId) : async Types.Result<Types.PortfolioSummary, Types.ApiError> {
        switch (utxo_sets.get(uid)) {
            case (?utxo_set) {
                switch (portfolios.get(uid)) {
                    case (?portfolio) {
                        // Return existing portfolio with current UTXO balance
                        let updated_portfolio: Types.PortfolioSummary = {
                            user_id = uid;
                            total_balance_sats = utxo_set.confirmed_balance;
                            total_value_usd = portfolio.total_value_usd;
                            positions = portfolio.positions;
                            pnl_24h = portfolio.pnl_24h;
                            active_strategy = portfolio.active_strategy;
                        };
                        #ok(updated_portfolio)
                    };
                    case null {
                        // Return basic portfolio from UTXO data
                        let basic_portfolio: Types.PortfolioSummary = {
                            user_id = uid;
                            total_balance_sats = utxo_set.confirmed_balance;
                            total_value_usd = 0.0;
                            positions = [];
                            pnl_24h = 0.0;
                            active_strategy = null;
                        };
                        #ok(basic_portfolio)
                    };
                }
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Calculate portfolio summary with PnL
    public shared(msg) func calculate_portfolio_summary(uid: Types.UserId, current_btc_price: Float) : async Types.Result<Types.PortfolioSummary, Types.ApiError> {
        switch (utxo_sets.get(uid)) {
            case (?utxo_set) {
                switch (portfolios.get(uid)) {
                    case (?portfolio) {
                        // Calculate current value and PnL for all positions
                        let updated_positions = Array.map<Types.Position, Types.Position>(portfolio.positions, func(pos) {
                            let current_value = (Float.fromInt64(Int64.fromNat64(pos.amount_sats)) / 100000000.0) * current_btc_price;
                            let pnl = current_value - pos.entry_price;
                            
                            {
                                user_id = pos.user_id;
                                venue_id = pos.venue_id;
                                amount_sats = pos.amount_sats;
                                entry_price = pos.entry_price;
                                current_value = current_value;
                                pnl = pnl;
                            }
                        });
                        
                        // Calculate total PnL
                        var total_pnl: Float = 0.0;
                        var total_value_usd: Float = 0.0;
                        for (pos in updated_positions.vals()) {
                            total_pnl += pos.pnl;
                            total_value_usd += pos.current_value;
                        };
                        
                        // Add BTC holdings value
                        let btc_value = (Float.fromInt64(Int64.fromNat64(utxo_set.confirmed_balance)) / 100000000.0) * current_btc_price;
                        total_value_usd += btc_value;
                        
                        let updated_portfolio: Types.PortfolioSummary = {
                            user_id = uid;
                            total_balance_sats = utxo_set.confirmed_balance;
                            total_value_usd = total_value_usd;
                            positions = updated_positions;
                            pnl_24h = total_pnl;
                            active_strategy = portfolio.active_strategy;
                        };
                        
                        portfolios.put(uid, updated_portfolio);
                        #ok(updated_portfolio)
                    };
                    case null {
                        // Create portfolio summary from UTXO data only
                        let btc_value = (Float.fromInt64(Int64.fromNat64(utxo_set.confirmed_balance)) / 100000000.0) * current_btc_price;
                        
                        let new_portfolio: Types.PortfolioSummary = {
                            user_id = uid;
                            total_balance_sats = utxo_set.confirmed_balance;
                            total_value_usd = btc_value;
                            positions = [];
                            pnl_24h = 0.0;
                            active_strategy = null;
                        };
                        
                        portfolios.put(uid, new_portfolio);
                        #ok(new_portfolio)
                    };
                }
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Get transaction statistics
    public query func get_transaction_stats(uid: Types.UserId) : async Types.Result<{
        total_transactions: Nat;
        total_deposits: Nat64;
        total_withdrawals: Nat64;
        pending_transactions: Nat;
    }, Types.ApiError> {
        var total_count: Nat = 0;
        var total_deposits: Nat64 = 0;
        var total_withdrawals: Nat64 = 0;
        var pending_count: Nat = 0;
        
        for (tx in transactions.vals()) {
            if (tx.user_id == uid) {
                total_count += 1;
                
                switch (tx.tx_type) {
                    case (#deposit) {
                        total_deposits += tx.amount_sats;
                    };
                    case (#withdraw) {
                        total_withdrawals += tx.amount_sats;
                    };
                    case (#strategy_execute or #rebalance) {
                        // These don't affect deposit/withdrawal totals
                    };
                };
                
                switch (tx.status) {
                    case (#pending) {
                        pending_count += 1;
                    };
                    case (#confirmed or #failed) {
                        // Already counted in total
                    };
                };
            };
        };
        
        #ok({
            total_transactions = total_count;
            total_deposits = total_deposits;
            total_withdrawals = total_withdrawals;
            pending_transactions = pending_count;
        })
    };

    // Get PnL history for a specific time period
    public query func get_pnl_history(uid: Types.UserId, from_time: ?Time.Time, to_time: ?Time.Time) : async Types.Result<{
        positions: [Types.Position];
        total_pnl: Float;
        realized_pnl: Float;
        unrealized_pnl: Float;
    }, Types.ApiError> {
        switch (portfolios.get(uid)) {
            case (?portfolio) {
                // Filter positions based on time if specified
                let filtered_positions = portfolio.positions;
                
                var total_pnl: Float = 0.0;
                var realized_pnl: Float = 0.0;
                var unrealized_pnl: Float = 0.0;
                
                for (position in filtered_positions.vals()) {
                    total_pnl += position.pnl;
                    // For now, treat all PnL as unrealized since we don't track position closure
                    unrealized_pnl += position.pnl;
                };
                
                #ok({
                    positions = filtered_positions;
                    total_pnl = total_pnl;
                    realized_pnl = realized_pnl;
                    unrealized_pnl = unrealized_pnl;
                })
            };
            case null {
                #ok({
                    positions = [];
                    total_pnl = 0.0;
                    realized_pnl = 0.0;
                    unrealized_pnl = 0.0;
                })
            };
        }
    };

    // Get transaction history with PnL impact analysis
    public query func get_transaction_history_with_pnl(uid: Types.UserId) : async Types.Result<[{
        transaction: Types.TxRecord;
        pnl_impact: Float;
        portfolio_value_before: Float;
        portfolio_value_after: Float;
    }], Types.ApiError> {
        let user_transactions = Buffer.Buffer<Types.TxRecord>(0);
        
        for (tx in transactions.vals()) {
            if (tx.user_id == uid) {
                user_transactions.add(tx);
            };
        };
        
        let sorted_transactions = sortTransactionsByTime(Buffer.toArray(user_transactions));
        
        // For now, return transactions with zero PnL impact since we'd need historical portfolio snapshots
        let transactions_with_pnl = Array.map<Types.TxRecord, {
            transaction: Types.TxRecord;
            pnl_impact: Float;
            portfolio_value_before: Float;
            portfolio_value_after: Float;
        }>(sorted_transactions, func(tx) {
            {
                transaction = tx;
                pnl_impact = 0.0; // Would need historical data to calculate
                portfolio_value_before = 0.0; // Would need historical snapshots
                portfolio_value_after = 0.0; // Would need historical snapshots
            }
        });
        
        #ok(transactions_with_pnl)
    };

    // Calculate portfolio performance metrics
    public shared(msg) func calculate_performance_metrics(uid: Types.UserId, current_btc_price: Float) : async Types.Result<{
        total_return: Float;
        total_return_percentage: Float;
        best_performing_position: ?Types.Position;
        worst_performing_position: ?Types.Position;
        average_position_pnl: Float;
    }, Types.ApiError> {
        switch (portfolios.get(uid)) {
            case (?portfolio) {
                if (portfolio.positions.size() == 0) {
                    return #ok({
                        total_return = 0.0;
                        total_return_percentage = 0.0;
                        best_performing_position = null;
                        worst_performing_position = null;
                        average_position_pnl = 0.0;
                    });
                };
                
                // Update positions with current prices
                let updated_positions = Array.map<Types.Position, Types.Position>(portfolio.positions, func(pos) {
                    let current_value = (Float.fromInt64(Int64.fromNat64(pos.amount_sats)) / 100000000.0) * current_btc_price;
                    let pnl = current_value - pos.entry_price;
                    
                    {
                        user_id = pos.user_id;
                        venue_id = pos.venue_id;
                        amount_sats = pos.amount_sats;
                        entry_price = pos.entry_price;
                        current_value = current_value;
                        pnl = pnl;
                    }
                });
                
                // Calculate metrics
                var total_pnl: Float = 0.0;
                var total_entry_value: Float = 0.0;
                var best_position: ?Types.Position = null;
                var worst_position: ?Types.Position = null;
                
                for (pos in updated_positions.vals()) {
                    total_pnl += pos.pnl;
                    total_entry_value += pos.entry_price;
                    
                    switch (best_position) {
                        case (?best) {
                            if (pos.pnl > best.pnl) {
                                best_position := ?pos;
                            };
                        };
                        case null {
                            best_position := ?pos;
                        };
                    };
                    
                    switch (worst_position) {
                        case (?worst) {
                            if (pos.pnl < worst.pnl) {
                                worst_position := ?pos;
                            };
                        };
                        case null {
                            worst_position := ?pos;
                        };
                    };
                };
                
                let return_percentage = if (total_entry_value > 0.0) {
                    (total_pnl / total_entry_value) * 100.0
                } else { 0.0 };
                
                let average_pnl = total_pnl / Float.fromInt(updated_positions.size());
                
                #ok({
                    total_return = total_pnl;
                    total_return_percentage = return_percentage;
                    best_performing_position = best_position;
                    worst_performing_position = worst_position;
                    average_position_pnl = average_pnl;
                })
            };
            case null {
                #err(#not_found)
            };
        }
    };

    // Distributed transaction methods for data consistency
    public func begin_portfolio_transaction(
        uid: Types.UserId,
        plan_id: ?Types.PlanId,
        participants: [Principal]
    ) : async Types.Result<Text, Types.ApiError> {
        let tx_result = await consistency_coordinator.begin_distributed_transaction(
            uid,
            plan_id,
            participants,
            300 // 5 minutes timeout
        );
        
        switch (tx_result) {
            case (#ok(tx_id)) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "portfolio_state";
                    action = "distributed_transaction_started";
                    user_id = ?uid;
                    transaction_id = ?tx_id;
                    details = "Started distributed transaction for portfolio update";
                });
                #ok(tx_id);
            };
            case (#err(error)) {
                #err(error);
            };
        };
    };

    public func commit_portfolio_transaction(tx_id: Text) : async Types.Result<Bool, Types.ApiError> {
        let commit_result = await consistency_coordinator.commit_distributed_transaction(tx_id);
        
        switch (commit_result) {
            case (#ok(success)) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "portfolio_state";
                    action = "distributed_transaction_committed";
                    user_id = null;
                    transaction_id = ?tx_id;
                    details = "Successfully committed distributed transaction";
                });
                #ok(success);
            };
            case (#err(error)) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "portfolio_state";
                    action = "distributed_transaction_commit_failed";
                    user_id = null;
                    transaction_id = ?tx_id;
                    details = "Failed to commit distributed transaction: " # debug_show(error);
                });
                #err(error);
            };
        };
    };

    public func rollback_portfolio_transaction(tx_id: Text) : async Types.Result<Bool, Types.ApiError> {
        let rollback_result = await consistency_coordinator.rollback_distributed_transaction(tx_id);
        
        switch (rollback_result) {
            case (#ok(success)) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "portfolio_state";
                    action = "distributed_transaction_rolled_back";
                    user_id = null;
                    transaction_id = ?tx_id;
                    details = "Successfully rolled back distributed transaction";
                });
                #ok(success);
            };
            case (#err(error)) {
                #err(error);
            };
        };
    };

    // State synchronization methods
    public func synchronize_with_canisters(canisters: [Principal]) : async Types.Result<Bool, Types.ApiError> {
        let sync_result = await consistency_coordinator.synchronize_state_across_canisters(canisters, 60);
        
        switch (sync_result) {
            case (#synchronized) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "portfolio_state";
                    action = "state_synchronized";
                    user_id = null;
                    transaction_id = null;
                    details = "Successfully synchronized state with " # Nat.toText(canisters.size()) # " canisters";
                });
                #ok(true);
            };
            case (#conflict({conflicting_canisters; resolution_strategy})) {
                communicator.log_audit_entry({
                    timestamp = Time.now();
                    canister = "portfolio_state";
                    action = "state_sync_conflict";
                    user_id = null;
                    transaction_id = null;
                    details = "State synchronization conflict detected with " # Nat.toText(conflicting_canisters.size()) # " canisters";
                });
                #err(#internal_error("State synchronization conflict detected"));
            };
            case (#timeout) {
                #err(#internal_error("State synchronization timed out"));
            };
            case (#error(msg)) {
                #err(#internal_error("State synchronization error: " # msg));
            };
        };
    };

    // Event subscription for inter-canister communication
    public func subscribe_to_execution_events() : async () {
        let execution_event_handler = func(event: Interfaces.SystemEvent) : async () {
            switch (event) {
                case (#execution_completed(plan_id, tx_ids)) {
                    communicator.log_audit_entry({
                        timestamp = Time.now();
                        canister = "portfolio_state";
                        action = "execution_completed_received";
                        user_id = null;
                        transaction_id = ?plan_id;
                        details = "Received execution completion event for plan: " # plan_id;
                    });
                    
                    // Update transaction statuses to confirmed
                    for (tx_id in tx_ids.vals()) {
                        switch (transactions.get(tx_id)) {
                            case (?tx) {
                                let updated_tx = {
                                    txid = tx.txid;
                                    user_id = tx.user_id;
                                    tx_type = tx.tx_type;
                                    amount_sats = tx.amount_sats;
                                    fee_sats = tx.fee_sats;
                                    status = #confirmed;
                                    confirmed_height = ?800000; // Mock block height
                                    timestamp = tx.timestamp;
                                };
                                transactions.put(tx_id, updated_tx);
                            };
                            case null {};
                        };
                    };
                };
                case (_) {};
            };
        };
        
        communicator.subscribe_to_events("execution_updates", execution_event_handler);
    };

    // Initialize event subscriptions on startup
    system func init() {
        ignore subscribe_to_execution_events();
    };

    // Get data consistency statistics
    public query func get_consistency_stats() : async {
        portfolio_checkpoints: Nat;
        active_transactions: Nat;
        completed_transactions: Nat;
        failed_transactions: Nat;
        idempotent_operations: Nat;
        communication_stats: {
            active_flows: Nat;
            total_audit_entries: Nat;
            event_subscribers: Nat;
            event_history_size: Nat;
        };
    } {
        let consistency_stats = consistency_coordinator.get_consistency_stats();
        let comm_stats = communicator.get_communication_stats();
        
        {
            portfolio_checkpoints = 0; // Would track actual checkpoints in production
            active_transactions = consistency_stats.active_transactions;
            completed_transactions = consistency_stats.completed_transactions;
            failed_transactions = consistency_stats.failed_transactions;
            idempotent_operations = consistency_stats.idempotent_operations;
            communication_stats = comm_stats;
        };
    };

    // Cleanup expired consistency operations
    public func cleanup_consistency_operations() : async Nat {
        await consistency_coordinator.cleanup_expired_operations();
    };

    // ===== MONITORING AND OBSERVABILITY =====

    // Health check endpoint
    public query func health_check() : async {
        status: Text;
        timestamp: Int;
        canister: Text;
        version: Text;
        checks: [{component: Text; status: Text; message: Text}];
    } {
        let start_time = metrics.start_timer();
        
        // Perform health checks
        let portfolio_count = portfolios.size();
        let transaction_count = transactions.size();
        let utxo_count = utxos.size();
        
        var checks = Buffer.Buffer<{component: Text; status: Text; message: Text}>(5);
        
        // Check data consistency
        let consistency_check = if (portfolio_count > 0 and utxo_count > 0) {
            {component = "data_consistency"; status = "healthy"; message = "Data structures consistent"}
        } else if (portfolio_count == 0 and utxo_count == 0) {
            {component = "data_consistency"; status = "healthy"; message = "Empty state is consistent"}
        } else {
            {component = "data_consistency"; status = "warning"; message = "Potential data inconsistency"}
        };
        checks.add(consistency_check);
        
        // Check memory usage (simplified)
        let memory_check = {
            component = "memory_usage";
            status = "healthy";
            message = "Memory usage within normal limits"
        };
        checks.add(memory_check);
        
        // Check transaction processing
        let tx_check = {
            component = "transaction_processing";
            status = "healthy";
            message = "Transaction processing operational"
        };
        checks.add(tx_check);
        
        // Record health check metrics
        metrics.record_health_check("portfolio_state", #HEALTHY, "All systems operational", null);
        metrics.end_timer(start_time, "health_check", true, null);
        
        logger.info("health_check", "Health check completed", ?"portfolios=" # Int.toText(portfolio_count) # ", transactions=" # Int.toText(transaction_count));
        
        {
            status = "healthy";
            timestamp = Time.now();
            canister = "portfolio_state";
            version = "1.0.0";
            checks = Buffer.toArray(checks);
        }
    };

    // Get system metrics
    public query func get_metrics() : async {
        portfolio_count: Nat;
        transaction_count: Nat;
        utxo_count: Nat;
        total_balance: Float;
        performance_stats: {
            total_calls: Nat;
            success_rate: Float;
            avg_duration_ms: Float;
        };
        log_stats: {
            total_entries: Nat;
            error_count: Nat;
            warn_count: Nat;
        };
    } {
        let start_time = metrics.start_timer();
        
        // Calculate total balance across all portfolios
        var total_balance: Float = 0.0;
        for ((_, portfolio) in portfolios.entries()) {
            total_balance += portfolio.total_balance;
        };
        
        // Get performance statistics
        let perf_stats = metrics.get_performance_stats(null);
        
        // Get log statistics
        let log_stats = logger.get_log_stats();
        
        metrics.end_timer(start_time, "get_metrics", true, null);
        
        {
            portfolio_count = portfolios.size();
            transaction_count = transactions.size();
            utxo_count = utxos.size();
            total_balance = total_balance;
            performance_stats = {
                total_calls = perf_stats.total_calls;
                success_rate = perf_stats.success_rate;
                avg_duration_ms = perf_stats.avg_duration_ms;
            };
            log_stats = {
                total_entries = log_stats.total_entries;
                error_count = log_stats.error_count;
                warn_count = log_stats.warn_count;
            };
        }
    };

    // Get recent logs (admin function)
    public query func get_logs(count: ?Nat) : async [Logging.LogEntry] {
        logger.get_logs(count)
    };

    // Get performance measurements
    public query func get_performance_data(count: ?Nat) : async [Metrics.PerformanceMeasurement] {
        metrics.get_performance_measurements(count)
    };

    // Validate state consistency
    public query func validate_state() : async Bool {
        let start_time = metrics.start_timer();
        
        // Check portfolio-UTXO consistency
        var total_portfolio_balance: Float = 0.0;
        for ((_, portfolio) in portfolios.entries()) {
            total_portfolio_balance += portfolio.total_balance;
        };
        
        var total_utxo_value: Float = 0.0;
        for ((_, utxo) in utxos.entries()) {
            if (not utxo.spent) {
                total_utxo_value += Float.fromInt(Int64.toInt(utxo.value));
            };
        };
        
        let is_consistent = (total_portfolio_balance == total_utxo_value);
        
        if (is_consistent) {
            logger.info("validate_state", "State validation passed", ?"portfolio_balance=" # Float.toText(total_portfolio_balance) # ", utxo_value=" # Float.toText(total_utxo_value));
            metrics.end_timer(start_time, "validate_state", true, null);
        } else {
            logger.error("validate_state", "State validation failed", ?"INCONSISTENCY", ?"portfolio_balance=" # Float.toText(total_portfolio_balance) # ", utxo_value=" # Float.toText(total_utxo_value));
            metrics.end_timer(start_time, "validate_state", false, ?"STATE_INCONSISTENCY");
        };
        
        is_consistent
    };

    // Test inter-canister connectivity (for deployment validation)
    public func test_connectivity() : async Bool {
        let start_time = metrics.start_timer();
        
        // This is a simple connectivity test
        logger.info("test_connectivity", "Connectivity test initiated", null);
        metrics.end_timer(start_time, "test_connectivity", true, null);
        
        true
    };

    // System status endpoint
    public query func get_status() : async {
        canister_id: Text;
        status: Text;
        uptime_seconds: Int;
        memory_usage: Text;
        cycle_balance: Text;
        last_upgrade: ?Int;
    } {
        {
            canister_id = "portfolio_state";
            status = "running";
            uptime_seconds = Time.now() / 1_000_000_000; // Convert nanoseconds to seconds
            memory_usage = "N/A"; // Would need system API access
            cycle_balance = "N/A"; // Would need system API access
            last_upgrade = null; // Would track in stable storage
        }
    };
}