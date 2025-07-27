import Debug "mo:base/Debug";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Array "mo:base/Array";
import Types "../shared/types";

// Mock portfolio state canister for testing
import PortfolioState "./main";

// Test utilities
module {
    public func assertEqual<T>(actual: T, expected: T, message: Text) {
        if (actual != expected) {
            Debug.print("FAIL: " # message);
            Debug.print("Expected: " # debug_show(expected));
            Debug.print("Actual: " # debug_show(actual));
        } else {
            Debug.print("PASS: " # message);
        }
    };

    public func assertTrue(condition: Bool, message: Text) {
        if (not condition) {
            Debug.print("FAIL: " # message);
        } else {
            Debug.print("PASS: " # message);
        }
    };

    // Test data
    public let TEST_USER_ID = Principal.fromText("rdmx6-jaaaa-aaaah-qcaiq-cai");
    public let TEST_ADDRESS = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
    public let TEST_TXID = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456";
    
    public func createTestUTXO(txid: Text, vout: Nat32, amount: Nat64, confirmations: Nat32) : Types.UTXO {
        {
            txid = txid;
            vout = vout;
            amount_sats = amount;
            address = TEST_ADDRESS;
            confirmations = confirmations;
            block_height = if (confirmations > 0) { ?800000 } else { null };
            spent = false;
            spent_in_tx = null;
        }
    };
}

// Test runner
public func runTests() : async () {
    Debug.print("=== Portfolio State UTXO Tests ===");
    
    await testAddUTXO();
    await testGetUTXOs();
    await testUpdateConfirmations();
    await testMarkUTXOSpent();
    await testDepositDetection();
    await testBalanceCalculation();
    
    Debug.print("=== Tests Complete ===");
};

// Test adding UTXOs
func testAddUTXO() : async () {
    Debug.print("\n--- Test: Add UTXO ---");
    
    let portfolio = await PortfolioState.PortfolioState();
    let utxo = createTestUTXO(TEST_TXID, 0, 100000000, 1); // 1 BTC with 1 confirmation
    
    let result = await portfolio.add_utxo(TEST_USER_ID, utxo);
    
    switch (result) {
        case (#ok(success)) {
            assertTrue(success, "Should successfully add UTXO");
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to add UTXO: " # debug_show(error));
        };
    };
    
    // Test adding duplicate UTXO should fail
    let duplicate_result = await portfolio.add_utxo(TEST_USER_ID, utxo);
    switch (duplicate_result) {
        case (#ok(_)) {
            Debug.print("FAIL: Should not allow duplicate UTXO");
        };
        case (#err(#invalid_input(_))) {
            Debug.print("PASS: Correctly rejected duplicate UTXO");
        };
        case (#err(error)) {
            Debug.print("FAIL: Unexpected error: " # debug_show(error));
        };
    };
};

// Test getting UTXOs
func testGetUTXOs() : async () {
    Debug.print("\n--- Test: Get UTXOs ---");
    
    let portfolio = await PortfolioState.PortfolioState();
    let utxo1 = createTestUTXO(TEST_TXID, 0, 50000000, 3); // 0.5 BTC with 3 confirmations
    let utxo2 = createTestUTXO(TEST_TXID, 1, 25000000, 0); // 0.25 BTC unconfirmed
    
    ignore await portfolio.add_utxo(TEST_USER_ID, utxo1);
    ignore await portfolio.add_utxo(TEST_USER_ID, utxo2);
    
    let result = await portfolio.get_utxos(TEST_USER_ID);
    
    switch (result) {
        case (#ok(utxo_set)) {
            assertEqual(utxo_set.utxos.size(), 2, "Should have 2 UTXOs");
            assertEqual(utxo_set.total_balance, 75000000, "Total balance should be 0.75 BTC");
            assertEqual(utxo_set.confirmed_balance, 50000000, "Confirmed balance should be 0.5 BTC");
            assertTrue(utxo_set.user_id == TEST_USER_ID, "Should have correct user ID");
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to get UTXOs: " # debug_show(error));
        };
    };
};

// Test updating UTXO confirmations
func testUpdateConfirmations() : async () {
    Debug.print("\n--- Test: Update UTXO Confirmations ---");
    
    let portfolio = await PortfolioState.PortfolioState();
    let utxo = createTestUTXO(TEST_TXID, 0, 100000000, 0); // Unconfirmed
    
    ignore await portfolio.add_utxo(TEST_USER_ID, utxo);
    
    // Update confirmations
    let update_result = await portfolio.update_utxo_confirmations(TEST_TXID, 6, ?800001);
    
    switch (update_result) {
        case (#ok(success)) {
            assertTrue(success, "Should successfully update confirmations");
            
            // Verify the update
            let utxo_result = await portfolio.get_utxos(TEST_USER_ID);
            switch (utxo_result) {
                case (#ok(utxo_set)) {
                    let updated_utxo = utxo_set.utxos[0];
                    assertEqual(updated_utxo.confirmations, 6, "Should have 6 confirmations");
                    assertEqual(updated_utxo.block_height, ?800001, "Should have correct block height");
                    assertEqual(utxo_set.confirmed_balance, 100000000, "Should now be confirmed");
                };
                case (#err(error)) {
                    Debug.print("FAIL: Failed to get updated UTXOs: " # debug_show(error));
                };
            };
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to update confirmations: " # debug_show(error));
        };
    };
};

// Test marking UTXO as spent
func testMarkUTXOSpent() : async () {
    Debug.print("\n--- Test: Mark UTXO Spent ---");
    
    let portfolio = await PortfolioState.PortfolioState();
    let utxo = createTestUTXO(TEST_TXID, 0, 100000000, 3);
    
    ignore await portfolio.add_utxo(TEST_USER_ID, utxo);
    
    let spend_txid = "spent123456789abcdef";
    let spend_result = await portfolio.mark_utxo_spent(TEST_TXID, 0, spend_txid);
    
    switch (spend_result) {
        case (#ok(success)) {
            assertTrue(success, "Should successfully mark UTXO as spent");
            
            // Verify the UTXO is marked as spent and balance updated
            let utxo_result = await portfolio.get_utxos(TEST_USER_ID);
            switch (utxo_result) {
                case (#ok(utxo_set)) {
                    let spent_utxo = utxo_set.utxos[0];
                    assertTrue(spent_utxo.spent, "UTXO should be marked as spent");
                    assertEqual(spent_utxo.spent_in_tx, ?spend_txid, "Should have correct spending transaction");
                    assertEqual(utxo_set.total_balance, 0, "Total balance should be 0 after spending");
                    assertEqual(utxo_set.confirmed_balance, 0, "Confirmed balance should be 0 after spending");
                };
                case (#err(error)) {
                    Debug.print("FAIL: Failed to get UTXOs after spending: " # debug_show(error));
                };
            };
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to mark UTXO as spent: " # debug_show(error));
        };
    };
};

// Test deposit detection
func testDepositDetection() : async () {
    Debug.print("\n--- Test: Deposit Detection ---");
    
    let portfolio = await PortfolioState.PortfolioState();
    
    let detect_result = await portfolio.detect_deposit(
        TEST_USER_ID, 
        TEST_ADDRESS, 
        TEST_TXID, 
        50000000, 
        0
    );
    
    switch (detect_result) {
        case (#ok(success)) {
            assertTrue(success, "Should successfully detect deposit");
            
            // Check pending deposits
            let pending_result = await portfolio.get_pending_deposits(TEST_USER_ID);
            switch (pending_result) {
                case (#ok(deposits)) {
                    assertEqual(deposits.size(), 1, "Should have 1 pending deposit");
                    let deposit = deposits[0];
                    assertEqual(deposit.txid, TEST_TXID, "Should have correct transaction ID");
                    assertEqual(deposit.amount_sats, 50000000, "Should have correct amount");
                    assertEqual(deposit.confirmations, 0, "Should be unconfirmed");
                    assertTrue(not deposit.processed, "Should not be processed yet");
                };
                case (#err(error)) {
                    Debug.print("FAIL: Failed to get pending deposits: " # debug_show(error));
                };
            };
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to detect deposit: " # debug_show(error));
        };
    };
    
    // Test updating deposit confirmations
    let update_result = await portfolio.detect_deposit(
        TEST_USER_ID, 
        TEST_ADDRESS, 
        TEST_TXID, 
        50000000, 
        3
    );
    
    switch (update_result) {
        case (#ok(_)) {
            let pending_result = await portfolio.get_pending_deposits(TEST_USER_ID);
            switch (pending_result) {
                case (#ok(deposits)) {
                    let deposit = deposits[0];
                    assertEqual(deposit.confirmations, 3, "Should have updated confirmations");
                };
                case (#err(error)) {
                    Debug.print("FAIL: Failed to get updated deposits: " # debug_show(error));
                };
            };
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to update deposit: " # debug_show(error));
        };
    };
};

// Test balance calculation
func testBalanceCalculation() : async () {
    Debug.print("\n--- Test: Balance Calculation ---");
    
    let portfolio = await PortfolioState.PortfolioState();
    
    // Add multiple UTXOs with different confirmation states
    let utxo1 = createTestUTXO("tx1", 0, 100000000, 6); // 1 BTC confirmed
    let utxo2 = createTestUTXO("tx2", 0, 50000000, 0);  // 0.5 BTC unconfirmed
    let utxo3 = createTestUTXO("tx3", 0, 25000000, 3);  // 0.25 BTC confirmed
    
    ignore await portfolio.add_utxo(TEST_USER_ID, utxo1);
    ignore await portfolio.add_utxo(TEST_USER_ID, utxo2);
    ignore await portfolio.add_utxo(TEST_USER_ID, utxo3);
    
    let portfolio_result = await portfolio.get_portfolio(TEST_USER_ID);
    
    switch (portfolio_result) {
        case (#ok(portfolio_summary)) {
            assertEqual(portfolio_summary.total_balance_sats, 125000000, "Confirmed balance should be 1.25 BTC");
            assertTrue(portfolio_summary.user_id == TEST_USER_ID, "Should have correct user ID");
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to get portfolio: " # debug_show(error));
        };
    };
    
    // Test with empty portfolio
    let empty_user = Principal.fromText("rrkah-fqaaa-aaaah-qcaiq-cai");
    let empty_result = await portfolio.get_portfolio(empty_user);
    
    switch (empty_result) {
        case (#ok(empty_portfolio)) {
            assertEqual(empty_portfolio.total_balance_sats, 0, "Empty portfolio should have 0 balance");
        };
        case (#err(error)) {
            Debug.print("FAIL: Failed to get empty portfolio: " # debug_show(error));
        };
    };
};