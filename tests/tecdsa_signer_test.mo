import Debug "mo:base/Debug";
import Result "mo:base/Result";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Text "mo:base/Text";
import Principal "mo:base/Principal";
import Time "mo:base/Time";

// Import modules to test
import TECDSASigner "../src/execution_agent/tecdsa_signer";
import BitcoinTx "../src/execution_agent/bitcoin_tx";
import Types "../src/shared/types";
import Utils "../src/shared/utils";
import Config "../src/shared/config";

module {
    // Test utilities
    public func assert(condition: Bool, message: Text) {
        if (not condition) {
            Debug.print("ASSERTION FAILED: " # message);
        } else {
            Debug.print("✓ " # message);
        }
    };

    public func assertEqual<T>(actual: T, expected: T, message: Text, eq: (T, T) -> Bool) {
        if (eq(actual, expected)) {
            Debug.print("✓ " # message);
        } else {
            Debug.print("ASSERTION FAILED: " # message # " - values not equal");
        }
    };

    // Mock data for testing
    public func createMockUser() : Types.UserId {
        Principal.fromText("rdmx6-jaaaa-aaaaa-aaadq-cai")
    };

    public func createMockUTXO() : Types.UTXO {
        {
            txid = "abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab";
            vout = 0;
            amount_sats = 1_000_000; // 0.01 BTC
            address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
            confirmations = 6;
            block_height = ?800000;
            spent = false;
            spent_in_tx = null;
        }
    };

    public func createMockTransaction() : BitcoinTx.RawTransaction {
        {
            version = 2;
            inputs = [{
                txid = "abcd1234567890abcdef1234567890abcdef1234567890abcdef1234567890ab";
                vout = 0;
                amount_sats = 1_000_000;
                script_sig = null;
            }];
            outputs = [{
                address = "tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3q0sL5k7";
                amount_sats = 990_000; // 0.0099 BTC (minus fee)
            }];
            locktime = 0;
        }
    };

    // Test suite for TECDSASigner
    public func runTests() : async () {
        Debug.print("=== Running t-ECDSA Signer Tests ===");
        
        await testKeyIdGeneration();
        await testDerivationPathGeneration();
        await testSignatureValidation();
        await testDERSignatureCreation();
        await testSigningAuthorization();
        await testSigningContextCreation();
        await testBitcoinAddressGeneration();
        await testSignatureHashing();
        await testErrorHandling();
        
        Debug.print("=== t-ECDSA Signer Tests Complete ===");
    };

    // Test key ID generation for different environments
    public func testKeyIdGeneration() : async () {
        Debug.print("\n--- Testing Key ID Generation ---");
        
        let signer = TECDSASigner.TECDSASigner();
        
        // Test local environment
        Config.setEnvironment(#local);
        let local_key = signer.getKeyId();
        assertEqual(local_key.name, "dfx_test_key", "Local key ID should be dfx_test_key", Text.equal);
        assertEqual(local_key.curve, #secp256k1, "Key curve should be secp256k1", func(a, b) { a == b });
        
        // Test testnet environment
        Config.setEnvironment(#testnet);
        let testnet_key = signer.getKeyId();
        assertEqual(testnet_key.name, "test_key_1", "Testnet key ID should be test_key_1", Text.equal);
        
        // Test mainnet environment
        Config.setEnvironment(#mainnet);
        let mainnet_key = signer.getKeyId();
        assertEqual(mainnet_key.name, "key_1", "Mainnet key ID should be key_1", Text.equal);
        
        // Reset to local for other tests
        Config.setEnvironment(#local);
    };

    // Test derivation path generation
    public func testDerivationPathGeneration() : async () {
        Debug.print("\n--- Testing Derivation Path Generation ---");
        
        let signer = TECDSASigner.TECDSASigner();
        let user_id = createMockUser();
        
        let derivation_path = signer.generateDerivationPath(user_id);
        
        assert(derivation_path.size() == 2, "Derivation path should have 2 components");
        
        let user_blob = Principal.toBlob(user_id);
        let expected_path_component = Blob.fromArray([0x00, 0x00, 0x00, 0x01]);
        
        assertEqual(derivation_path[0], user_blob, "First component should be user principal blob", Blob.equal);
        assertEqual(derivation_path[1], expected_path_component, "Second component should be BIP44 path", Blob.equal);
    };

    // Test signature validation
    public func testSignatureValidation() : async () {
        Debug.print("\n--- Testing Signature Validation ---");
        
        // Test valid signature
        let valid_r = Blob.fromArray(Array.freeze(Array.init<Nat8>(32, 0x01)));
        let valid_s = Blob.fromArray(Array.freeze(Array.init<Nat8>(32, 0x02)));
        let valid_signature: TECDSASigner.BitcoinSignature = {
            r = valid_r;
            s = valid_s;
            recovery_id = 0;
        };
        
        assert(TECDSASigner.isValidSignature(valid_signature), "Valid signature should pass validation");
        
        // Test invalid signature (wrong size)
        let invalid_r = Blob.fromArray([0x01, 0x02, 0x03]); // Too short
        let invalid_signature: TECDSASigner.BitcoinSignature = {
            r = invalid_r;
            s = valid_s;
            recovery_id = 0;
        };
        
        assert(not TECDSASigner.isValidSignature(invalid_signature), "Invalid signature should fail validation");
        
        // Test signature with invalid recovery ID
        let invalid_recovery_signature: TECDSASigner.BitcoinSignature = {
            r = valid_r;
            s = valid_s;
            recovery_id = 5; // Should be < 4
        };
        
        assert(not TECDSASigner.isValidSignature(invalid_recovery_signature), "Signature with invalid recovery ID should fail");
    };

    // Test DER signature creation
    public func testDERSignatureCreation() : async () {
        Debug.print("\n--- Testing DER Signature Creation ---");
        
        let signer = TECDSASigner.TECDSASigner();
        
        let r_bytes = Array.freeze(Array.init<Nat8>(32, 0x01));
        let s_bytes = Array.freeze(Array.init<Nat8>(32, 0x02));
        let signature: TECDSASigner.BitcoinSignature = {
            r = Blob.fromArray(r_bytes);
            s = Blob.fromArray(s_bytes);
            recovery_id = 0;
        };
        
        let der_signature = signer.createDERSignature(signature, 0x01);
        let der_bytes = Blob.toArray(der_signature);
        
        assert(der_bytes.size() > 64, "DER signature should be longer than raw signature");
        assert(der_bytes[0] == 0x30, "DER signature should start with 0x30");
        assert(der_bytes[der_bytes.size() - 1] == 0x01, "DER signature should end with sighash type");
    };

    // Test signing authorization
    public func testSigningAuthorization() : async () {
        Debug.print("\n--- Testing Signing Authorization ---");
        
        let signer = TECDSASigner.TECDSASigner();
        let user_id = createMockUser();
        
        // Test valid authorization
        let valid_auth = signer.authorizeSigningForUser(user_id, user_id, 1_000_000);
        switch (valid_auth) {
            case (#ok(authorized)) {
                assert(authorized, "Valid authorization should succeed");
            };
            case (#err(_)) {
                assert(false, "Valid authorization should not fail");
            };
        };
        
        // Test unauthorized caller
        let different_user = Principal.fromText("rrkah-fqaaa-aaaaa-aaaaq-cai");
        let invalid_auth = signer.authorizeSigningForUser(user_id, different_user, 1_000_000);
        switch (invalid_auth) {
            case (#ok(_)) {
                assert(false, "Unauthorized caller should fail");
            };
            case (#err(msg)) {
                assert(Text.contains(msg, #text "Unauthorized"), "Should return unauthorized error");
            };
        };
        
        // Test zero amount
        let zero_amount_auth = signer.authorizeSigningForUser(user_id, user_id, 0);
        switch (zero_amount_auth) {
            case (#ok(_)) {
                assert(false, "Zero amount should fail");
            };
            case (#err(msg)) {
                assert(Text.contains(msg, #text "cannot be zero"), "Should return zero amount error");
            };
        };
        
        // Test amount exceeding limit
        let excessive_amount_auth = signer.authorizeSigningForUser(user_id, user_id, 200_000_000); // 2 BTC
        switch (excessive_amount_auth) {
            case (#ok(_)) {
                assert(false, "Excessive amount should fail");
            };
            case (#err(msg)) {
                assert(Text.contains(msg, #text "exceeds limit"), "Should return limit exceeded error");
            };
        };
    };

    // Test signing context creation
    public func testSigningContextCreation() : async () {
        Debug.print("\n--- Testing Signing Context Creation ---");
        
        let signer = TECDSASigner.TECDSASigner();
        let mock_tx = createMockTransaction();
        let mock_utxo = createMockUTXO();
        
        let context: TECDSASigner.SigningContext = {
            tx = mock_tx;
            input_index = 0;
            utxo = mock_utxo;
            sighash_type = 0x01;
        };
        
        // Test signature hash creation
        let sig_hash = signer.createSigHash(context);
        let hash_bytes = Blob.toArray(sig_hash);
        
        assert(hash_bytes.size() == 32, "Signature hash should be 32 bytes");
        assert(not Array.equal<Nat8>(hash_bytes, Array.freeze(Array.init<Nat8>(32, 0)), Nat8.equal), "Signature hash should not be all zeros");
    };

    // Test Bitcoin address generation
    public func testBitcoinAddressGeneration() : async () {
        Debug.print("\n--- Testing Bitcoin Address Generation ---");
        
        let signer = TECDSASigner.TECDSASigner();
        let mock_pubkey = Blob.fromArray(Array.freeze(Array.init<Nat8>(33, 0x02))); // Compressed pubkey
        
        // Test testnet address
        let testnet_address = signer.createBitcoinAddress(mock_pubkey, #testnet);
        assert(Text.startsWith(testnet_address, #text "tb1q"), "Testnet address should start with tb1q");
        
        // Test mainnet address
        let mainnet_address = signer.createBitcoinAddress(mock_pubkey, #mainnet);
        assert(Text.startsWith(mainnet_address, #text "bc1q"), "Mainnet address should start with bc1q");
        
        // Test address determinism
        let address1 = signer.createBitcoinAddress(mock_pubkey, #testnet);
        let address2 = signer.createBitcoinAddress(mock_pubkey, #testnet);
        assertEqual(address1, address2, "Same pubkey should generate same address", Text.equal);
    };

    // Test signature hash creation
    public func testSignatureHashing() : async () {
        Debug.print("\n--- Testing Signature Hash Creation ---");
        
        let signer = TECDSASigner.TECDSASigner();
        let mock_tx = createMockTransaction();
        let mock_utxo = createMockUTXO();
        
        let context1: TECDSASigner.SigningContext = {
            tx = mock_tx;
            input_index = 0;
            utxo = mock_utxo;
            sighash_type = 0x01;
        };
        
        let context2: TECDSASigner.SigningContext = {
            tx = mock_tx;
            input_index = 0;
            utxo = mock_utxo;
            sighash_type = 0x02; // Different sighash type
        };
        
        let hash1 = signer.createSigHash(context1);
        let hash2 = signer.createSigHash(context2);
        
        assert(not Blob.equal(hash1, hash2), "Different sighash types should produce different hashes");
        
        // Test hash determinism
        let hash1_repeat = signer.createSigHash(context1);
        assert(Blob.equal(hash1, hash1_repeat), "Same context should produce same hash");
    };

    // Test error handling scenarios
    public func testErrorHandling() : async () {
        Debug.print("\n--- Testing Error Handling ---");
        
        let signer = TECDSASigner.TECDSASigner();
        
        // Test signature hex conversion
        let valid_signature: TECDSASigner.BitcoinSignature = {
            r = Blob.fromArray([0x01, 0x02, 0x03, 0x04]);
            s = Blob.fromArray([0x05, 0x06, 0x07, 0x08]);
            recovery_id = 0;
        };
        
        let hex_signature = TECDSASigner.signatureToHex(valid_signature);
        assert(Text.size(hex_signature) == 16, "Hex signature should be correct length"); // 8 bytes = 16 hex chars
        assert(Text.startsWith(hex_signature, #text "01020304"), "Hex signature should start correctly");
        
        // Test utility functions
        let test_bytes = [0x01, 0x23, 0x45, 0x67, 0x89, 0xAB, 0xCD, 0xEF];
        let hex_string = Utils.bytesToHex(test_bytes);
        assertEqual(hex_string, "0123456789abcdef", "Bytes to hex conversion should be correct", Text.equal);
        
        let converted_back = Utils.hexToBytes(hex_string);
        assert(Array.equal<Nat8>(test_bytes, converted_back, Nat8.equal), "Hex to bytes conversion should be reversible");
    };

    // Integration test with mock t-ECDSA calls
    public func testMockSigningIntegration() : async () {
        Debug.print("\n--- Testing Mock Signing Integration ---");
        
        let signer = TECDSASigner.TECDSASigner();
        let user_id = createMockUser();
        let mock_tx = createMockTransaction();
        let mock_utxos = [createMockUTXO()];
        
        // Note: This test would normally call the actual t-ECDSA signing
        // For unit testing, we're testing the structure and validation
        
        // Test authorization
        let auth_result = signer.authorizeSigningForUser(user_id, user_id, 990_000);
        switch (auth_result) {
            case (#ok(_)) {
                Debug.print("✓ Authorization successful for mock signing");
            };
            case (#err(msg)) {
                Debug.print("Authorization failed: " # msg);
            };
        };
        
        // Test signing context creation
        let context: TECDSASigner.SigningContext = {
            tx = mock_tx;
            input_index = 0;
            utxo = mock_utxos[0];
            sighash_type = 0x01;
        };
        
        let sig_hash = signer.createSigHash(context);
        assert(Blob.toArray(sig_hash).size() == 32, "Signature hash should be 32 bytes for integration test");
        
        Debug.print("✓ Mock signing integration test completed");
    };
}