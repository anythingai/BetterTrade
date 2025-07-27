#!/bin/bash

# BetterTrade System Health Monitor
# Continuous health monitoring with alerting

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_FILE="$SCRIPT_DIR/config/monitoring.json"
LOG_FILE="$PROJECT_ROOT/logs/health-monitor.log"

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_with_timestamp() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOG_FILE"
}

log_info() {
    log_with_timestamp "INFO: $1"
}

log_warning() {
    log_with_timestamp "WARNING: $1"
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    log_with_timestamp "ERROR: $1"
    echo -e "${RED}[ERROR]${NC} $1"
}

log_success() {
    log_with_timestamp "SUCCESS: $1"
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

# Usage function
usage() {
    echo "Usage: $0 <environment> [options]"
    echo ""
    echo "Environments:"
    echo "  local     - Monitor local deployment"
    echo "  testnet   - Monitor testnet deployment"
    echo "  mainnet   - Monitor mainnet deployment"
    echo ""
    echo "Options:"
    echo "  --interval <seconds>  Health check interval (default: 60)"
    echo "  --daemon             Run as daemon process"
    echo "  --once               Run health check once and exit"
    echo "  --alert-only         Only show alerts, suppress normal output"
    echo "  --config <file>      Use custom configuration file"
    echo "  --help               Show this help message"
}

# Parse arguments
ENVIRONMENT=""
CHECK_INTERVAL=60
DAEMON_MODE=false
RUN_ONCE=false
ALERT_ONLY=false
CUSTOM_CONFIG=""

while [[ $# -gt 0 ]]; do
    case $1 in
        --interval)
            CHECK_INTERVAL="$2"
            shift 2
            ;;
        --daemon)
            DAEMON_MODE=true
            shift
            ;;
        --once)
            RUN_ONCE=true
            shift
            ;;
        --alert-only)
            ALERT_ONLY=true
            shift
            ;;
        --config)
            CUSTOM_CONFIG="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        local|testnet|mainnet)
            ENVIRONMENT=$1
            shift
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment is required"
    usage
    exit 1
fi

# Use custom config if provided
if [[ -n "$CUSTOM_CONFIG" ]]; then
    CONFIG_FILE="$CUSTOM_CONFIG"
fi

# Check if config file exists
if [[ ! -f "$CONFIG_FILE" ]]; then
    log_error "Configuration file not found: $CONFIG_FILE"
    exit 1
fi

# Canister list
CANISTERS=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")

# Health check function
check_canister_health() {
    local canister=$1
    local start_time=$(date +%s%N)
    
    # Try to call health check endpoint
    local health_response
    health_response=$(timeout 10 dfx canister --network "$ENVIRONMENT" call "$canister" health_check 2>/dev/null)
    local call_result=$?
    
    local end_time=$(date +%s%N)
    local response_time_ms=$(( (end_time - start_time) / 1000000 ))
    
    if [[ $call_result -eq 0 ]]; then
        # Parse health status from response
        local status="UNKNOWN"
        if echo "$health_response" | grep -q '"healthy"'; then
            status="HEALTHY"
        elif echo "$health_response" | grep -q '"degraded"'; then
            status="DEGRADED"
        elif echo "$health_response" | grep -q '"unhealthy"'; then
            status="UNHEALTHY"
        fi
        
        echo "$status:$response_time_ms"
    else
        echo "UNREACHABLE:$response_time_ms"
    fi
}

# Get canister metrics
get_canister_metrics() {
    local canister=$1
    
    timeout 10 dfx canister --network "$ENVIRONMENT" call "$canister" get_metrics 2>/dev/null || echo "ERROR"
}

# Check cycle balance
check_cycle_balance() {
    local canister=$1
    
    local status_output
    status_output=$(dfx canister --network "$ENVIRONMENT" status "$canister" 2>/dev/null)
    
    if [[ $? -eq 0 ]]; then
        local cycles
        cycles=$(echo "$status_output" | grep -o '[0-9,]*_cycles' | tr -d ',' | tr -d '_cycles' | head -1)
        echo "${cycles:-0}"
    else
        echo "0"
    fi
}

# Alert function
send_alert() {
    local severity=$1
    local message=$2
    local canister=$3
    
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local alert_message="[$severity] $message"
    
    if [[ -n "$canister" ]]; then
        alert_message="[$severity] [$canister] $message"
    fi
    
    # Log alert
    log_with_timestamp "ALERT: $alert_message"
    
    # Console alert
    case "$severity" in
        "CRITICAL")
            echo -e "${RED}🚨 CRITICAL ALERT: $message${NC}"
            ;;
        "ERROR")
            echo -e "${RED}❌ ERROR: $message${NC}"
            ;;
        "WARNING")
            echo -e "${YELLOW}⚠️  WARNING: $message${NC}"
            ;;
    esac
    
    # TODO: Implement webhook/email alerting based on config
}

# Comprehensive health check
run_health_check() {
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local overall_healthy=true
    local alerts=()
    
    if [[ "$ALERT_ONLY" == "false" ]]; then
        log_info "Starting health check for $ENVIRONMENT environment"
    fi
    
    # Check each canister
    for canister in "${CANISTERS[@]}"; do
        local health_result
        health_result=$(check_canister_health "$canister")
        
        local health_status=$(echo "$health_result" | cut -d':' -f1)
        local response_time=$(echo "$health_result" | cut -d':' -f2)
        
        # Check health status
        case "$health_status" in
            "HEALTHY")
                if [[ "$ALERT_ONLY" == "false" ]]; then
                    log_success "$canister is healthy (${response_time}ms)"
                fi
                ;;
            "DEGRADED")
                overall_healthy=false
                send_alert "WARNING" "$canister is degraded (response time: ${response_time}ms)" "$canister"
                ;;
            "UNHEALTHY")
                overall_healthy=false
                send_alert "ERROR" "$canister is unhealthy (response time: ${response_time}ms)" "$canister"
                ;;
            "UNREACHABLE")
                overall_healthy=false
                send_alert "CRITICAL" "$canister is unreachable" "$canister"
                ;;
        esac
        
        # Check response time threshold (5 seconds)
        if [[ "$response_time" -gt 5000 && "$health_status" != "UNREACHABLE" ]]; then
            send_alert "WARNING" "$canister response time is high: ${response_time}ms" "$canister"
        fi
        
        # Check cycle balance (only for non-local environments)
        if [[ "$ENVIRONMENT" != "local" ]]; then
            local cycle_balance
            cycle_balance=$(check_cycle_balance "$canister")
            
            # Alert if balance is below 1T cycles
            if [[ "$cycle_balance" -lt 1000000000000 && "$cycle_balance" -gt 0 ]]; then
                send_alert "WARNING" "$canister has low cycle balance: $cycle_balance cycles" "$canister"
            fi
        fi
    done
    
    # Check inter-canister connectivity
    if [[ "$ALERT_ONLY" == "false" ]]; then
        log_info "Checking inter-canister connectivity..."
    fi
    
    # Test portfolio_state connectivity
    if timeout 10 dfx canister --network "$ENVIRONMENT" call portfolio_state test_connectivity &>/dev/null; then
        if [[ "$ALERT_ONLY" == "false" ]]; then
            log_success "Inter-canister connectivity test passed"
        fi
    else
        overall_healthy=false
        send_alert "ERROR" "Inter-canister connectivity test failed"
    fi
    
    # Overall system status
    if [[ "$overall_healthy" == "true" ]]; then
        if [[ "$ALERT_ONLY" == "false" ]]; then
            log_success "All systems healthy at $timestamp"
        fi
    else
        send_alert "ERROR" "System health check failed - one or more components are unhealthy"
    fi
    
    # Log metrics summary
    if [[ "$ALERT_ONLY" == "false" ]]; then
        local portfolio_metrics
        portfolio_metrics=$(get_canister_metrics "portfolio_state")
        
        if [[ "$portfolio_metrics" != "ERROR" ]]; then
            log_info "System metrics collected successfully"
        else
            log_warning "Failed to collect system metrics"
        fi
    fi
}

# Daemon mode function
run_daemon() {
    log_info "Starting health monitor daemon for $ENVIRONMENT (interval: ${CHECK_INTERVAL}s)"
    
    # Create PID file
    local pid_file="$PROJECT_ROOT/logs/health-monitor-$ENVIRONMENT.pid"
    echo $$ > "$pid_file"
    
    # Cleanup function
    cleanup() {
        log_info "Shutting down health monitor daemon"
        rm -f "$pid_file"
        exit 0
    }
    
    # Set up signal handlers
    trap cleanup SIGTERM SIGINT
    
    while true; do
        run_health_check
        sleep "$CHECK_INTERVAL"
    done
}

# Main execution
log_info "BetterTrade Health Monitor starting for $ENVIRONMENT"

# Check dependencies
if ! command -v dfx &> /dev/null; then
    log_error "dfx is not installed or not in PATH"
    exit 1
fi

# Check if environment is accessible
if ! dfx ping "$ENVIRONMENT" &>/dev/null && [[ "$ENVIRONMENT" != "local" ]]; then
    log_error "Cannot connect to $ENVIRONMENT network"
    exit 1
fi

# Run health check
if [[ "$RUN_ONCE" == "true" ]]; then
    run_health_check
elif [[ "$DAEMON_MODE" == "true" ]]; then
    run_daemon
else
    # Interactive mode
    while true; do
        run_health_check
        
        echo ""
        echo -e "${BLUE}Press Ctrl+C to exit, or wait ${CHECK_INTERVAL}s for next check...${NC}"
        
        sleep "$CHECK_INTERVAL"
    done
fi