import Time "mo:base/Time";
import Text "mo:base/Text";
import Nat32 "mo:base/Nat32";
import Nat8 "mo:base/Nat8";
import Nat64 "mo:base/Nat64";
import Array "mo:base/Array";
import Blob "mo:base/Blob";
import Random "mo:base/Random";
import Char "mo:base/Char";
import Iter "mo:base/Iter";

module {
    // Generate unique IDs
    public func generateId(prefix: Text) : Text {
        let timestamp = Time.now();
        prefix # "_" # Int.toText(timestamp)
    };

    // Validate Bitcoin address format (basic validation)
    public func isValidBitcoinAddress(address: Text) : Bool {
        let length = Text.size(address);
        // Basic length check for Bitcoin addresses
        (length >= 26 and length <= 35) or (length >= 42 and length <= 62)
    };

    // Convert satoshis to BTC
    public func satsToBtc(sats: Nat64) : Float {
        Float.fromInt64(Int64.fromNat64(sats)) / 100_000_000.0
    };

    // Convert BTC to satoshis
    public func btcToSats(btc: Float) : Nat64 {
        Int64.toNat64(Float.toInt64(btc * 100_000_000.0))
    };

    // Calculate percentage change
    public func percentageChange(old_value: Float, new_value: Float) : Float {
        if (old_value == 0.0) { 0.0 }
        else { ((new_value - old_value) / old_value) * 100.0 }
    };

    // Format timestamp for display
    public func formatTimestamp(timestamp: Time.Time) : Text {
        // Simple timestamp formatting - in production would use proper date formatting
        Int.toText(timestamp)
    };

    // Validate risk level
    public func isValidRiskLevel(level: Text) : Bool {
        level == "conservative" or level == "balanced" or level == "aggressive"
    };

    // Calculate strategy score (placeholder algorithm)
    public func calculateStrategyScore(apy: Float, risk_factor: Float, liquidity_score: Float) : Float {
        let w1 = 0.4; // APY weight
        let w2 = 0.3; // Risk weight (inverted)
        let w3 = 0.3; // Liquidity weight
        
        w1 * (apy / 100.0) + w2 * (1.0 - risk_factor) + w3 * liquidity_score
    };

    // Cryptographic utility functions for t-ECDSA integration
    
    // SHA256 hash function (simplified implementation for MVP)
    public func sha256(data: Blob) : Blob {
        // This is a placeholder implementation for MVP
        // In production, would use proper SHA256 implementation
        let input_bytes = Blob.toArray(data);
        let hash_bytes = Array.tabulate<Nat8>(32, func(i) {
            let sum = Array.foldLeft<Nat8, Nat>(input_bytes, 0, func(acc, byte) { acc + Nat8.toNat(byte) });
            Nat8.fromNat((sum + i) % 256)
        });
        Blob.fromArray(hash_bytes)
    };

    // Convert bytes to hexadecimal string
    public func bytesToHex(bytes: [Nat8]) : Text {
        let hex_chars = "0123456789abcdef";
        var result = "";
        for (byte in bytes.vals()) {
            let high = Nat8.toNat(byte / 16);
            let low = Nat8.toNat(byte % 16);
            result := result # Text.fromChar(Text.toArray(hex_chars)[high]) # Text.fromChar(Text.toArray(hex_chars)[low]);
        };
        result
    };

    // Convert hexadecimal string to bytes
    public func hexToBytes(hex: Text) : [Nat8] {
        let hex_chars = Text.toArray(hex);
        let result_size = hex_chars.size() / 2;
        Array.tabulate<Nat8>(result_size, func(i) {
            let high_char = hex_chars[i * 2];
            let low_char = hex_chars[i * 2 + 1];
            let high_val = hexCharToNat8(high_char);
            let low_val = hexCharToNat8(low_char);
            high_val * 16 + low_val
        })
    };

    // Convert hex character to Nat8
    private func hexCharToNat8(c: Char) : Nat8 {
        let char_code = Char.toNat32(c);
        if (char_code >= 48 and char_code <= 57) { // '0'-'9'
            Nat8.fromNat32(char_code - 48)
        } else if (char_code >= 97 and char_code <= 102) { // 'a'-'f'
            Nat8.fromNat32(char_code - 97 + 10)
        } else if (char_code >= 65 and char_code <= 70) { // 'A'-'F'
            Nat8.fromNat32(char_code - 65 + 10)
        } else {
            0 // Invalid hex character
        }
    };

    // Convert Nat32 to bytes (big-endian)
    public func nat32ToBytes(n: Nat32) : [Nat8] {
        [
            Nat8.fromNat32((n >> 24) & 0xFF),
            Nat8.fromNat32((n >> 16) & 0xFF),
            Nat8.fromNat32((n >> 8) & 0xFF),
            Nat8.fromNat32(n & 0xFF)
        ]
    };

    // Convert Nat64 to bytes (big-endian)
    public func nat64ToBytes(n: Nat64) : [Nat8] {
        [
            Nat8.fromNat64((n >> 56) & 0xFF),
            Nat8.fromNat64((n >> 48) & 0xFF),
            Nat8.fromNat64((n >> 40) & 0xFF),
            Nat8.fromNat64((n >> 32) & 0xFF),
            Nat8.fromNat64((n >> 24) & 0xFF),
            Nat8.fromNat64((n >> 16) & 0xFF),
            Nat8.fromNat64((n >> 8) & 0xFF),
            Nat8.fromNat64(n & 0xFF)
        ]
    };

    // Convert Nat to bytes (variable length, big-endian)
    public func natToBytes(n: Nat) : [Nat8] {
        if (n == 0) { [0] }
        else {
            var temp = n;
            var bytes: [Nat8] = [];
            while (temp > 0) {
                bytes := [Nat8.fromNat(temp % 256)] # bytes;
                temp := temp / 256;
            };
            bytes
        }
    };

    // Validate ECDSA signature format
    public func isValidECDSASignature(r: Blob, s: Blob) : Bool {
        let r_bytes = Blob.toArray(r);
        let s_bytes = Blob.toArray(s);
        
        // Basic validation: both r and s should be 32 bytes
        r_bytes.size() == 32 and s_bytes.size() == 32 and
        not (Array.equal<Nat8>(r_bytes, Array.freeze(Array.init<Nat8>(32, 0)), Nat8.equal)) and
        not (Array.equal<Nat8>(s_bytes, Array.freeze(Array.init<Nat8>(32, 0)), Nat8.equal))
    };

    // Validate hexadecimal string format
    public func isValidHexString(hex: Text) : Bool {
        let chars = Text.toArray(hex);
        Array.foldLeft<Char, Bool>(chars, true, func(acc, c) {
            acc and (
                (c >= '0' and c <= '9') or
                (c >= 'a' and c <= 'f') or
                (c >= 'A' and c <= 'F')
            )
        })
    };
}