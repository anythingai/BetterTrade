import Types "../shared/types";
import Utils "../shared/utils";
import Constants "../shared/constants";
import Config "../shared/config";
import BitcoinTx "./bitcoin_tx";
import Result "mo:base/Result";
import Blob "mo:base/Blob";
import Array "mo:base/Array";
import Nat8 "mo:base/Nat8";
import Nat32 "mo:base/Nat32";
import Nat64 "mo:base/Nat64";
import Text "mo:base/Text";
import Option "mo:base/Option";
import Principal "mo:base/Principal";
import Time "mo:base/Time";
import Error "mo:base/Error";

module {
    // t-ECDSA key configuration
    public type ECDSAKeyId = {
        curve: {#secp256k1};
        name: Text;
    };

    // Signing request for t-ECDSA
    public type SigningRequest = {
        message_hash: Blob;
        derivation_path: [Blob];
        key_id: ECDSAKeyId;
    };

    // Signing response from t-ECDSA
    public type SigningResponse = {
        signature: Blob;
    };

    // Bitcoin signature components
    public type BitcoinSignature = {
        r: Blob;
        s: Blob;
        recovery_id: Nat8;
    };

    // Signing context for transaction inputs
    public type SigningContext = {
        tx: BitcoinTx.RawTransaction;
        input_index: Nat;
        utxo: Types.UTXO;
        sighash_type: Nat8; // SIGHASH_ALL = 0x01
    };

    // Signing result
    public type SigningResult = Result.Result<BitcoinTx.RawTransaction, Text>;

    // t-ECDSA Signer class
    public class TECDSASigner() {
        
        // Get the appropriate key ID based on environment
        public func getKeyId() : ECDSAKeyId {
            let key_name = switch (Config.CURRENT_ENVIRONMENT) {
                case (#local) { "dfx_test_key" };
                case (#testnet) { "test_key_1" };
                case (#mainnet) { "key_1" };
            };
            
            {
                curve = #secp256k1;
                name = key_name;
            }
        };

        // Generate derivation path for user's signing key
        public func generateDerivationPath(user_id: Types.UserId) : [Blob] {
            let user_principal_blob = Principal.toBlob(user_id);
            let path_component = Blob.fromArray([0x00, 0x00, 0x00, 0x01]); // BIP44 Bitcoin path component
            [user_principal_blob, path_component]
        };

        // Get public key for a user (for address generation)
        public func getPublicKey(user_id: Types.UserId) : async Result.Result<Blob, Text> {
            let key_id = getKeyId();
            let derivation_path = generateDerivationPath(user_id);
            
            // For MVP, return a deterministic public key based on user ID
            // In production, this would make an actual call to the management canister
            let user_bytes = Principal.toBlob(user_id);
            let deterministic_pubkey = Utils.sha256(user_bytes);
            #ok(deterministic_pubkey)
        };

        // Create Bitcoin address from public key
        public func createBitcoinAddress(public_key: Blob, network: Types.Network) : Text {
            // This is a simplified implementation for MVP
            // In production, would properly derive P2PKH or P2WPKH address from public key
            let prefix = switch (network) {
                case (#testnet) { "tb1q" };
                case (#mainnet) { "bc1q" };
            };
            
            // Generate a deterministic address based on public key
            let key_hash = Utils.sha256(public_key);
            let address_suffix = Utils.bytesToHex(Blob.toArray(key_hash));
            prefix # Text.take(address_suffix, 32) # "example" // Placeholder implementation
        };

        // Create signature hash for Bitcoin transaction input
        public func createSigHash(context: SigningContext) : Blob {
            // This is a simplified implementation of Bitcoin's signature hash algorithm
            // In production, would implement proper BIP143 (segwit) or legacy signature hash
            
            let tx = context.tx;
            let input_index = context.input_index;
            let sighash_type = context.sighash_type;
            
            // Serialize transaction components for hashing
            let version_bytes = Utils.nat32ToBytes(tx.version);
            let input_count_bytes = Utils.natToBytes(tx.inputs.size());
            let output_count_bytes = Utils.natToBytes(tx.outputs.size());
            let locktime_bytes = Utils.nat32ToBytes(tx.locktime);
            let sighash_bytes = [sighash_type];
            
            // Combine all components
            let combined_data = Array.flatten<Nat8>([
                version_bytes,
                input_count_bytes,
                output_count_bytes,
                locktime_bytes,
                sighash_bytes
            ]);
            
            // Double SHA256 hash (Bitcoin standard)
            let first_hash = Utils.sha256(Blob.fromArray(combined_data));
            Utils.sha256(first_hash)
        };

        // Sign a Bitcoin transaction input using t-ECDSA
        public func signTransactionInput(
            context: SigningContext,
            user_id: Types.UserId
        ) : async Result.Result<BitcoinSignature, Text> {
            
            let message_hash = createSigHash(context);
            let key_id = getKeyId();
            let derivation_path = generateDerivationPath(user_id);
            
            // For MVP, create a deterministic signature based on message hash and user ID
            // In production, this would make an actual call to the management canister
            let user_bytes = Principal.toBlob(user_id);
            let combined_data = Array.append(Blob.toArray(message_hash), Blob.toArray(user_bytes));
            let signature_hash = Utils.sha256(Blob.fromArray(combined_data));
            let signature_bytes = Blob.toArray(signature_hash);
            
            // Create deterministic r and s values (32 bytes each)
            let r_bytes = Array.take(signature_bytes, 32);
            let s_seed = Array.append(signature_bytes, [0x01]); // Add seed for s
            let s_hash = Utils.sha256(Blob.fromArray(s_seed));
            let s_bytes = Array.take(Blob.toArray(s_hash), 32);
            
            #ok({
                r = Blob.fromArray(r_bytes);
                s = Blob.fromArray(s_bytes);
                recovery_id = 0;
            })
        };

        // Create DER-encoded signature for Bitcoin transaction
        public func createDERSignature(signature: BitcoinSignature, sighash_type: Nat8) : Blob {
            // This is a simplified DER encoding implementation
            // In production, would implement proper DER encoding according to Bitcoin standards
            
            let r_bytes = Blob.toArray(signature.r);
            let s_bytes = Blob.toArray(signature.s);
            
            // DER signature format: 0x30 [total-length] 0x02 [R-length] [R] 0x02 [S-length] [S] [sighash-type]
            let der_header = [0x30];
            let r_header = [0x02, Nat8.fromNat(r_bytes.size())];
            let s_header = [0x02, Nat8.fromNat(s_bytes.size())];
            let sighash_suffix = [sighash_type];
            
            let total_length = r_header.size() + r_bytes.size() + s_header.size() + s_bytes.size();
            let length_byte = [Nat8.fromNat(total_length)];
            
            let der_signature = Array.flatten<Nat8>([
                der_header,
                length_byte,
                r_header,
                r_bytes,
                s_header,
                s_bytes,
                sighash_suffix
            ]);
            
            Blob.fromArray(der_signature)
        };

        // Sign all inputs of a Bitcoin transaction
        public func signTransaction(
            tx: BitcoinTx.RawTransaction,
            user_utxos: [Types.UTXO],
            user_id: Types.UserId
        ) : async SigningResult {
            
            // Create a mutable copy of the transaction
            var signed_inputs = Array.init<BitcoinTx.TxInput>(tx.inputs.size(), tx.inputs[0]);
            
            // Sign each input
            for (i in tx.inputs.keys()) {
                let input = tx.inputs[i];
                
                // Find the corresponding UTXO for this input
                let utxo_opt = Array.find<Types.UTXO>(user_utxos, func(utxo) {
                    utxo.txid == input.txid and utxo.vout == input.vout
                });
                
                let utxo = switch (utxo_opt) {
                    case (?u) { u };
                    case null {
                        return #err("UTXO not found for input " # Nat.toText(i) # ": " # input.txid # ":" # Nat32.toText(input.vout));
                    };
                };
                
                // Create signing context
                let context: SigningContext = {
                    tx = tx;
                    input_index = i;
                    utxo = utxo;
                    sighash_type = 0x01; // SIGHASH_ALL
                };
                
                // Sign the input
                let signature_result = await signTransactionInput(context, user_id);
                let signature = switch (signature_result) {
                    case (#ok(sig)) { sig };
                    case (#err(msg)) {
                        return #err("Failed to sign input " # Nat.toText(i) # ": " # msg);
                    };
                };
                
                // Create DER-encoded signature
                let der_signature = createDERSignature(signature, context.sighash_type);
                
                // Get public key for this user
                let pubkey_result = await getPublicKey(user_id);
                let pubkey = switch (pubkey_result) {
                    case (#ok(pk)) { pk };
                    case (#err(msg)) {
                        return #err("Failed to get public key for input " # Nat.toText(i) # ": " # msg);
                    };
                };
                
                // Create script_sig (signature + public key for P2PKH)
                let sig_bytes = Blob.toArray(der_signature);
                let pubkey_bytes = Blob.toArray(pubkey);
                let script_sig_bytes = Array.flatten<Nat8>([
                    [Nat8.fromNat(sig_bytes.size())], // Push signature
                    sig_bytes,
                    [Nat8.fromNat(pubkey_bytes.size())], // Push public key
                    pubkey_bytes
                ]);
                
                let script_sig = Blob.fromArray(script_sig_bytes);
                
                // Update the input with the signature
                signed_inputs[i] := {
                    txid = input.txid;
                    vout = input.vout;
                    amount_sats = input.amount_sats;
                    script_sig = ?script_sig;
                };
            };
            
            // Create the signed transaction
            let signed_tx: BitcoinTx.RawTransaction = {
                version = tx.version;
                inputs = Array.freeze(signed_inputs);
                outputs = tx.outputs;
                locktime = tx.locktime;
            };
            
            #ok(signed_tx)
        };

        // Validate signature (for testing purposes)
        public func validateSignature(
            signature: BitcoinSignature,
            message_hash: Blob,
            public_key: Blob
        ) : Bool {
            // This is a placeholder implementation for MVP
            // In production, would implement proper ECDSA signature verification
            signature.r != Blob.fromArray([]) and signature.s != Blob.fromArray([])
        };

        // Get signing authorization for a user (security check)
        public func authorizeSigningForUser(
            user_id: Types.UserId,
            caller: Principal,
            tx_amount: Nat64
        ) : Result.Result<Bool, Text> {
            
            // Basic authorization checks
            if (user_id != caller) {
                return #err("Unauthorized: caller is not the user");
            };
            
            if (tx_amount == 0) {
                return #err("Invalid transaction amount: cannot be zero");
            };
            
            if (tx_amount > 100_000_000) { // 1 BTC limit for MVP
                return #err("Transaction amount exceeds limit: " # Nat64.toText(tx_amount) # " sats");
            };
            
            #ok(true)
        };

        // Emergency key rotation (for security incidents)
        public func rotateUserKey(user_id: Types.UserId) : async Result.Result<Bool, Text> {
            // This would implement key rotation in production
            // For MVP, just return success
            #ok(true)
        };

        // Get signing statistics for monitoring
        public func getSigningStats() : {
            total_signatures: Nat;
            successful_signatures: Nat;
            failed_signatures: Nat;
            average_signing_time_ms: Nat;
        } {
            // Placeholder implementation for MVP
            {
                total_signatures = 0;
                successful_signatures = 0;
                failed_signatures = 0;
                average_signing_time_ms = 0;
            }
        };
    };

    // Utility functions for signature handling
    public func isValidSignature(signature: BitcoinSignature) : Bool {
        let r_bytes = Blob.toArray(signature.r);
        let s_bytes = Blob.toArray(signature.s);
        
        r_bytes.size() == 32 and s_bytes.size() == 32 and signature.recovery_id < 4
    };

    public func signatureToHex(signature: BitcoinSignature) : Text {
        let r_hex = Utils.bytesToHex(Blob.toArray(signature.r));
        let s_hex = Utils.bytesToHex(Blob.toArray(signature.s));
        r_hex # s_hex
    };
}