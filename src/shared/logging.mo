// BetterTrade Structured Logging Module
// Provides consistent logging across all canisters

import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import Debug "mo:base/Debug";
import Principal "mo:base/Principal";

module {
    // Log levels
    public type LogLevel = {
        #DEBUG;
        #INFO;
        #WARN;
        #ERROR;
        #CRITICAL;
    };

    // Log entry structure
    public type LogEntry = {
        timestamp: Int;
        level: LogLevel;
        canister: Text;
        function_name: Text;
        message: Text;
        context: ?Text;
        user_id: ?Text;
        transaction_id: ?Text;
        error_code: ?Text;
    };

    // Logger configuration
    public type LoggerConfig = {
        canister_name: Text;
        min_level: LogLevel;
        max_entries: Nat;
        enable_debug: Bool;
    };

    // Logger class
    public class Logger(config: LoggerConfig) {
        private var log_buffer = Buffer.Buffer<LogEntry>(config.max_entries);
        private let canister_name = config.canister_name;
        private let min_level = config.min_level;
        private let max_entries = config.max_entries;
        private let enable_debug = config.enable_debug;

        // Convert log level to numeric value for comparison
        private func level_to_number(level: LogLevel) : Nat {
            switch (level) {
                case (#DEBUG) 0;
                case (#INFO) 1;
                case (#WARN) 2;
                case (#ERROR) 3;
                case (#CRITICAL) 4;
            }
        };

        // Convert log level to string
        private func level_to_string(level: LogLevel) : Text {
            switch (level) {
                case (#DEBUG) "DEBUG";
                case (#INFO) "INFO";
                case (#WARN) "WARN";
                case (#ERROR) "ERROR";
                case (#CRITICAL) "CRITICAL";
            }
        };

        // Check if log level should be recorded
        private func should_log(level: LogLevel) : Bool {
            if (level == #DEBUG and not enable_debug) {
                return false;
            };
            level_to_number(level) >= level_to_number(min_level)
        };

        // Add log entry
        private func add_entry(
            level: LogLevel,
            function_name: Text,
            message: Text,
            context: ?Text,
            user_id: ?Text,
            transaction_id: ?Text,
            error_code: ?Text
        ) {
            if (not should_log(level)) {
                return;
            };

            let entry: LogEntry = {
                timestamp = Time.now();
                level = level;
                canister = canister_name;
                function_name = function_name;
                message = message;
                context = context;
                user_id = user_id;
                transaction_id = transaction_id;
                error_code = error_code;
            };

            // Add to buffer
            log_buffer.add(entry);

            // Maintain buffer size limit
            if (log_buffer.size() > max_entries) {
                ignore log_buffer.remove(0);
            };

            // Also output to debug console for development
            if (enable_debug) {
                let log_line = format_log_entry(entry);
                Debug.print(log_line);
            };
        };

        // Format log entry for display
        private func format_log_entry(entry: LogEntry) : Text {
            let timestamp_str = Int.toText(entry.timestamp);
            let level_str = level_to_string(entry.level);
            
            var formatted = "[" # timestamp_str # "] " # level_str # " [" # entry.canister # "::" # entry.function_name # "] " # entry.message;
            
            switch (entry.context) {
                case (?ctx) formatted := formatted # " | Context: " # ctx;
                case null {};
            };
            
            switch (entry.user_id) {
                case (?uid) formatted := formatted # " | User: " # uid;
                case null {};
            };
            
            switch (entry.transaction_id) {
                case (?txid) formatted := formatted # " | TX: " # txid;
                case null {};
            };
            
            switch (entry.error_code) {
                case (?code) formatted := formatted # " | Error: " # code;
                case null {};
            };
            
            formatted
        };

        // Public logging methods
        public func debug(function_name: Text, message: Text, context: ?Text) {
            add_entry(#DEBUG, function_name, message, context, null, null, null);
        };

        public func info(function_name: Text, message: Text, context: ?Text) {
            add_entry(#INFO, function_name, message, context, null, null, null);
        };

        public func warn(function_name: Text, message: Text, context: ?Text) {
            add_entry(#WARN, function_name, message, context, null, null, null);
        };

        public func error(function_name: Text, message: Text, error_code: ?Text, context: ?Text) {
            add_entry(#ERROR, function_name, message, context, null, null, error_code);
        };

        public func critical(function_name: Text, message: Text, error_code: ?Text, context: ?Text) {
            add_entry(#CRITICAL, function_name, message, context, null, null, error_code);
        };

        // Contextual logging with user and transaction info
        public func log_user_action(
            level: LogLevel,
            function_name: Text,
            message: Text,
            user_id: Text,
            transaction_id: ?Text,
            context: ?Text
        ) {
            add_entry(level, function_name, message, context, ?user_id, transaction_id, null);
        };

        public func log_transaction(
            level: LogLevel,
            function_name: Text,
            message: Text,
            transaction_id: Text,
            user_id: ?Text,
            context: ?Text
        ) {
            add_entry(level, function_name, message, context, user_id, ?transaction_id, null);
        };

        public func log_error_with_context(
            function_name: Text,
            message: Text,
            error_code: Text,
            user_id: ?Text,
            transaction_id: ?Text,
            context: ?Text
        ) {
            add_entry(#ERROR, function_name, message, context, user_id, transaction_id, ?error_code);
        };

        // Get recent logs
        public func get_logs(count: ?Nat) : [LogEntry] {
            let requested_count = switch (count) {
                case (?c) if (c <= log_buffer.size()) c else log_buffer.size();
                case null log_buffer.size();
            };
            
            let start_index = if (log_buffer.size() > requested_count) {
                log_buffer.size() - requested_count
            } else {
                0
            };
            
            let result = Buffer.Buffer<LogEntry>(requested_count);
            var i = start_index;
            while (i < log_buffer.size()) {
                result.add(log_buffer.get(i));
                i += 1;
            };
            
            Buffer.toArray(result)
        };

        // Get logs by level
        public func get_logs_by_level(level: LogLevel, count: ?Nat) : [LogEntry] {
            let all_logs = get_logs(null);
            let filtered = Array.filter<LogEntry>(all_logs, func(entry) = entry.level == level);
            
            switch (count) {
                case (?c) {
                    if (filtered.size() <= c) {
                        filtered
                    } else {
                        Array.subArray(filtered, filtered.size() - c, c)
                    }
                };
                case null filtered;
            }
        };

        // Get logs for specific user
        public func get_user_logs(user_id: Text, count: ?Nat) : [LogEntry] {
            let all_logs = get_logs(null);
            let filtered = Array.filter<LogEntry>(all_logs, func(entry) = 
                switch (entry.user_id) {
                    case (?uid) uid == user_id;
                    case null false;
                }
            );
            
            switch (count) {
                case (?c) {
                    if (filtered.size() <= c) {
                        filtered
                    } else {
                        Array.subArray(filtered, filtered.size() - c, c)
                    }
                };
                case null filtered;
            }
        };

        // Clear logs (admin function)
        public func clear_logs() {
            log_buffer.clear();
            info("clear_logs", "Log buffer cleared", null);
        };

        // Get log statistics
        public func get_log_stats() : {
            total_entries: Nat;
            debug_count: Nat;
            info_count: Nat;
            warn_count: Nat;
            error_count: Nat;
            critical_count: Nat;
        } {
            let all_logs = get_logs(null);
            var debug_count = 0;
            var info_count = 0;
            var warn_count = 0;
            var error_count = 0;
            var critical_count = 0;
            
            for (entry in all_logs.vals()) {
                switch (entry.level) {
                    case (#DEBUG) debug_count += 1;
                    case (#INFO) info_count += 1;
                    case (#WARN) warn_count += 1;
                    case (#ERROR) error_count += 1;
                    case (#CRITICAL) critical_count += 1;
                }
            };
            
            {
                total_entries = all_logs.size();
                debug_count = debug_count;
                info_count = info_count;
                warn_count = warn_count;
                error_count = error_count;
                critical_count = critical_count;
            }
        };
    };

    // Utility functions for common logging patterns
    public func create_production_logger(canister_name: Text) : Logger {
        Logger({
            canister_name = canister_name;
            min_level = #INFO;
            max_entries = 1000;
            enable_debug = false;
        })
    };

    public func create_development_logger(canister_name: Text) : Logger {
        Logger({
            canister_name = canister_name;
            min_level = #DEBUG;
            max_entries = 500;
            enable_debug = true;
        })
    };

    public func create_custom_logger(canister_name: Text, min_level: LogLevel, max_entries: Nat, enable_debug: Bool) : Logger {
        Logger({
            canister_name = canister_name;
            min_level = min_level;
            max_entries = max_entries;
            enable_debug = enable_debug;
        })
    };
}