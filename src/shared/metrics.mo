// BetterTrade Performance Metrics Collection Module
// Tracks system performance and health metrics

import Time "mo:base/Time";
import Text "mo:base/Text";
import Array "mo:base/Array";
import Buffer "mo:base/Buffer";
import HashMap "mo:base/HashMap";
import Iter "mo:base/Iter";
import Int "mo:base/Int";
import Float "mo:base/Float";
import Debug "mo:base/Debug";

module {
    // Metric types
    public type MetricType = {
        #COUNTER;      // Monotonically increasing value
        #GAUGE;        // Current value that can go up or down
        #HISTOGRAM;    // Distribution of values
        #TIMER;        // Duration measurements
    };

    // Metric value
    public type MetricValue = {
        #Counter: Nat;
        #Gauge: Float;
        #Histogram: [Float];
        #Timer: Int; // nanoseconds
    };

    // Metric entry
    public type Metric = {
        name: Text;
        metric_type: MetricType;
        value: MetricValue;
        timestamp: Int;
        labels: [(Text, Text)];
    };

    // Performance measurement
    public type PerformanceMeasurement = {
        function_name: Text;
        duration_ns: Int;
        timestamp: Int;
        success: Bool;
        error_code: ?Text;
    };

    // System health status
    public type HealthStatus = {
        #HEALTHY;
        #DEGRADED;
        #UNHEALTHY;
        #CRITICAL;
    };

    // Health check result
    public type HealthCheck = {
        component: Text;
        status: HealthStatus;
        message: Text;
        timestamp: Int;
        response_time_ms: ?Int;
    };

    // Metrics collector class
    public class MetricsCollector(canister_name: Text) {
        private var metrics = HashMap.HashMap<Text, Metric>(100, Text.equal, Text.hash);
        private var performance_buffer = Buffer.Buffer<PerformanceMeasurement>(1000);
        private var health_checks = HashMap.HashMap<Text, HealthCheck>(50, Text.equal, Text.hash);
        private let canister = canister_name;

        // Counter operations
        public func increment_counter(name: Text, labels: [(Text, Text)]) {
            let key = name # "_" # format_labels(labels);
            let current_value = switch (metrics.get(key)) {
                case (?metric) {
                    switch (metric.value) {
                        case (#Counter(count)) count;
                        case (_) 0;
                    }
                };
                case null 0;
            };

            let new_metric: Metric = {
                name = name;
                metric_type = #COUNTER;
                value = #Counter(current_value + 1);
                timestamp = Time.now();
                labels = labels;
            };

            metrics.put(key, new_metric);
        };

        public func add_to_counter(name: Text, value: Nat, labels: [(Text, Text)]) {
            let key = name # "_" # format_labels(labels);
            let current_value = switch (metrics.get(key)) {
                case (?metric) {
                    switch (metric.value) {
                        case (#Counter(count)) count;
                        case (_) 0;
                    }
                };
                case null 0;
            };

            let new_metric: Metric = {
                name = name;
                metric_type = #COUNTER;
                value = #Counter(current_value + value);
                timestamp = Time.now();
                labels = labels;
            };

            metrics.put(key, new_metric);
        };

        // Gauge operations
        public func set_gauge(name: Text, value: Float, labels: [(Text, Text)]) {
            let key = name # "_" # format_labels(labels);
            let new_metric: Metric = {
                name = name;
                metric_type = #GAUGE;
                value = #Gauge(value);
                timestamp = Time.now();
                labels = labels;
            };

            metrics.put(key, new_metric);
        };

        // Timer operations
        public func record_timer(name: Text, duration_ns: Int, labels: [(Text, Text)]) {
            let key = name # "_" # format_labels(labels);
            let new_metric: Metric = {
                name = name;
                metric_type = #TIMER;
                value = #Timer(duration_ns);
                timestamp = Time.now();
                labels = labels;
            };

            metrics.put(key, new_metric);
        };

        // Performance measurement
        public func start_timer() : Int {
            Time.now()
        };

        public func end_timer(start_time: Int, function_name: Text, success: Bool, error_code: ?Text) {
            let duration = Time.now() - start_time;
            let measurement: PerformanceMeasurement = {
                function_name = function_name;
                duration_ns = duration;
                timestamp = Time.now();
                success = success;
                error_code = error_code;
            };

            performance_buffer.add(measurement);

            // Maintain buffer size
            if (performance_buffer.size() > 1000) {
                ignore performance_buffer.remove(0);
            };

            // Record as timer metric
            let labels = [
                ("function", function_name),
                ("success", if (success) "true" else "false"),
                ("canister", canister)
            ];
            record_timer("function_duration", duration, labels);
        };

        // Health check operations
        public func record_health_check(component: Text, status: HealthStatus, message: Text, response_time_ms: ?Int) {
            let health_check: HealthCheck = {
                component = component;
                status = status;
                message = message;
                timestamp = Time.now();
                response_time_ms = response_time_ms;
            };

            health_checks.put(component, health_check);

            // Record as gauge metric
            let status_value = switch (status) {
                case (#HEALTHY) 1.0;
                case (#DEGRADED) 0.75;
                case (#UNHEALTHY) 0.5;
                case (#CRITICAL) 0.0;
            };

            set_gauge("health_status", status_value, [("component", component), ("canister", canister)]);
        };

        // Utility functions
        private func format_labels(labels: [(Text, Text)]) : Text {
            let label_strings = Array.map<(Text, Text), Text>(labels, func((key, value)) = key # "=" # value);
            Text.join(",", label_strings.vals())
        };

        // Get metrics
        public func get_metrics() : [Metric] {
            Iter.toArray(metrics.vals())
        };

        public func get_metric(name: Text, labels: [(Text, Text)]) : ?Metric {
            let key = name # "_" # format_labels(labels);
            metrics.get(key)
        };

        public func get_performance_measurements(count: ?Nat) : [PerformanceMeasurement] {
            let requested_count = switch (count) {
                case (?c) if (c <= performance_buffer.size()) c else performance_buffer.size();
                case null performance_buffer.size();
            };

            let start_index = if (performance_buffer.size() > requested_count) {
                performance_buffer.size() - requested_count
            } else {
                0
            };

            let result = Buffer.Buffer<PerformanceMeasurement>(requested_count);
            var i = start_index;
            while (i < performance_buffer.size()) {
                result.add(performance_buffer.get(i));
                i += 1;
            };

            Buffer.toArray(result)
        };

        public func get_health_checks() : [HealthCheck] {
            Iter.toArray(health_checks.vals())
        };

        public func get_health_check(component: Text) : ?HealthCheck {
            health_checks.get(component)
        };

        // Performance statistics
        public func get_performance_stats(function_name: ?Text) : {
            total_calls: Nat;
            success_rate: Float;
            avg_duration_ms: Float;
            min_duration_ms: Float;
            max_duration_ms: Float;
            p95_duration_ms: Float;
        } {
            let measurements = get_performance_measurements(null);
            let filtered = switch (function_name) {
                case (?fname) Array.filter<PerformanceMeasurement>(measurements, func(m) = m.function_name == fname);
                case null measurements;
            };

            if (filtered.size() == 0) {
                return {
                    total_calls = 0;
                    success_rate = 0.0;
                    avg_duration_ms = 0.0;
                    min_duration_ms = 0.0;
                    max_duration_ms = 0.0;
                    p95_duration_ms = 0.0;
                };
            };

            let total_calls = filtered.size();
            let successful_calls = Array.filter<PerformanceMeasurement>(filtered, func(m) = m.success).size();
            let success_rate = Float.fromInt(successful_calls) / Float.fromInt(total_calls);

            let durations_ms = Array.map<PerformanceMeasurement, Float>(filtered, func(m) = 
                Float.fromInt(m.duration_ns) / 1_000_000.0
            );

            let total_duration = Array.foldLeft<Float, Float>(durations_ms, 0.0, func(acc, d) = acc + d);
            let avg_duration_ms = total_duration / Float.fromInt(durations_ms.size());

            let sorted_durations = Array.sort<Float>(durations_ms, Float.compare);
            let min_duration_ms = sorted_durations[0];
            let max_duration_ms = sorted_durations[sorted_durations.size() - 1];

            let p95_index = Int.abs(Float.toInt(Float.fromInt(sorted_durations.size()) * 0.95));
            let p95_duration_ms = if (p95_index < sorted_durations.size()) {
                sorted_durations[p95_index]
            } else {
                max_duration_ms
            };

            {
                total_calls = total_calls;
                success_rate = success_rate;
                avg_duration_ms = avg_duration_ms;
                min_duration_ms = min_duration_ms;
                max_duration_ms = max_duration_ms;
                p95_duration_ms = p95_duration_ms;
            }
        };

        // System health summary
        public func get_system_health() : {
            overall_status: HealthStatus;
            healthy_components: Nat;
            total_components: Nat;
            critical_issues: [Text];
        } {
            let all_health_checks = get_health_checks();
            let total_components = all_health_checks.size();

            var healthy_count = 0;
            var critical_issues = Buffer.Buffer<Text>(10);
            var worst_status = #HEALTHY;

            for (check in all_health_checks.vals()) {
                switch (check.status) {
                    case (#HEALTHY) healthy_count += 1;
                    case (#DEGRADED) {
                        if (worst_status == #HEALTHY) worst_status := #DEGRADED;
                    };
                    case (#UNHEALTHY) {
                        if (worst_status == #HEALTHY or worst_status == #DEGRADED) worst_status := #UNHEALTHY;
                    };
                    case (#CRITICAL) {
                        worst_status := #CRITICAL;
                        critical_issues.add(check.component # ": " # check.message);
                    };
                }
            };

            {
                overall_status = worst_status;
                healthy_components = healthy_count;
                total_components = total_components;
                critical_issues = Buffer.toArray(critical_issues);
            }
        };

        // Clear old metrics (maintenance function)
        public func clear_old_metrics(older_than_ns: Int) {
            let current_time = Time.now();
            let cutoff_time = current_time - older_than_ns;

            let entries_to_remove = Buffer.Buffer<Text>(100);
            for ((key, metric) in metrics.entries()) {
                if (metric.timestamp < cutoff_time) {
                    entries_to_remove.add(key);
                };
            };

            for (key in entries_to_remove.vals()) {
                metrics.delete(key);
            };

            // Clear old performance measurements
            let new_performance_buffer = Buffer.Buffer<PerformanceMeasurement>(1000);
            for (measurement in performance_buffer.vals()) {
                if (measurement.timestamp >= cutoff_time) {
                    new_performance_buffer.add(measurement);
                };
            };
            performance_buffer := new_performance_buffer;
        };
    };

    // Common metrics for BetterTrade system
    public let COMMON_METRICS = {
        // User metrics
        USER_REGISTRATIONS = "user_registrations_total";
        ACTIVE_USERS = "active_users";
        USER_DEPOSITS = "user_deposits_total";
        USER_WITHDRAWALS = "user_withdrawals_total";

        // Transaction metrics
        TRANSACTIONS_PROCESSED = "transactions_processed_total";
        TRANSACTION_FAILURES = "transaction_failures_total";
        TRANSACTION_DURATION = "transaction_duration";
        BITCOIN_CONFIRMATIONS = "bitcoin_confirmations";

        // Strategy metrics
        STRATEGY_RECOMMENDATIONS = "strategy_recommendations_total";
        STRATEGY_EXECUTIONS = "strategy_executions_total";
        STRATEGY_PERFORMANCE = "strategy_performance";

        // System metrics
        CANISTER_CYCLES = "canister_cycles";
        MEMORY_USAGE = "memory_usage_bytes";
        INTER_CANISTER_CALLS = "inter_canister_calls_total";
        API_REQUESTS = "api_requests_total";
        ERROR_RATE = "error_rate";

        // Health metrics
        HEALTH_CHECK_DURATION = "health_check_duration";
        COMPONENT_STATUS = "component_status";
    };
}