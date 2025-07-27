#!/bin/bash

# BetterTrade Monitoring Dashboard
# Real-time system health and performance monitoring

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
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
    echo "  --refresh <seconds>   Refresh interval (default: 30)"
    echo "  --compact            Compact display mode"
    echo "  --json               Output in JSON format"
    echo "  --once               Run once and exit"
    echo "  --help               Show this help message"
}

# Parse arguments
ENVIRONMENT=""
REFRESH_INTERVAL=30
COMPACT_MODE=false
JSON_OUTPUT=false
RUN_ONCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --refresh)
            REFRESH_INTERVAL="$2"
            shift 2
            ;;
        --compact)
            COMPACT_MODE=true
            shift
            ;;
        --json)
            JSON_OUTPUT=true
            shift
            ;;
        --once)
            RUN_ONCE=true
            shift
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

# Canister list
CANISTERS=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")

# Get canister health
get_canister_health() {
    local canister=$1
    local health_data
    
    health_data=$(dfx canister --network "$ENVIRONMENT" call "$canister" health_check 2>/dev/null || echo "ERROR")
    
    if [[ "$health_data" == "ERROR" ]]; then
        echo "UNHEALTHY"
    else
        # Parse health status from response (simplified)
        if echo "$health_data" | grep -q '"healthy"'; then
            echo "HEALTHY"
        elif echo "$health_data" | grep -q '"degraded"'; then
            echo "DEGRADED"
        else
            echo "UNKNOWN"
        fi
    fi
}

# Get canister metrics
get_canister_metrics() {
    local canister=$1
    
    dfx canister --network "$ENVIRONMENT" call "$canister" get_metrics 2>/dev/null || echo "ERROR"
}

# Get system status
get_system_status() {
    local canister=$1
    
    dfx canister --network "$ENVIRONMENT" call "$canister" get_status 2>/dev/null || echo "ERROR"
}

# Display dashboard header
display_header() {
    if [[ "$JSON_OUTPUT" == "false" ]]; then
        clear
        echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║                          BetterTrade Monitoring Dashboard                     ║${NC}"
        echo -e "${CYAN}╠══════════════════════════════════════════════════════════════════════════════╣${NC}"
        echo -e "${CYAN}║${NC} Environment: ${YELLOW}$ENVIRONMENT${NC}                    Last Update: ${BLUE}$(date)${NC} ${CYAN}║${NC}"
        echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
        echo ""
    fi
}

# Display canister status
display_canister_status() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "{"
        echo "  \"timestamp\": \"$(date -u +"%Y-%m-%dT%H:%M:%SZ")\","
        echo "  \"environment\": \"$ENVIRONMENT\","
        echo "  \"canisters\": ["
    else
        echo -e "${MAGENTA}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${MAGENTA}│                              CANISTER STATUS                               │${NC}"
        echo -e "${MAGENTA}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
        printf "${MAGENTA}│${NC} %-20s %-12s %-15s %-25s ${MAGENTA}│${NC}\n" "CANISTER" "STATUS" "HEALTH" "LAST CHECK"
        echo -e "${MAGENTA}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
    fi
    
    local first_canister=true
    for canister in "${CANISTERS[@]}"; do
        local health_status
        local canister_id
        local last_check
        
        health_status=$(get_canister_health "$canister")
        canister_id=$(dfx canister --network "$ENVIRONMENT" id "$canister" 2>/dev/null || echo "NOT_DEPLOYED")
        last_check=$(date +"%H:%M:%S")
        
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            if [[ "$first_canister" == "false" ]]; then
                echo ","
            fi
            echo "    {"
            echo "      \"name\": \"$canister\","
            echo "      \"id\": \"$canister_id\","
            echo "      \"health\": \"$health_status\","
            echo "      \"last_check\": \"$last_check\""
            echo -n "    }"
            first_canister=false
        else
            # Color code health status
            local health_color
            case "$health_status" in
                "HEALTHY") health_color="${GREEN}" ;;
                "DEGRADED") health_color="${YELLOW}" ;;
                "UNHEALTHY") health_color="${RED}" ;;
                *) health_color="${NC}" ;;
            esac
            
            local status_color
            if [[ "$canister_id" == "NOT_DEPLOYED" ]]; then
                status_color="${RED}"
            else
                status_color="${GREEN}"
            fi
            
            printf "${MAGENTA}│${NC} %-20s ${status_color}%-12s${NC} ${health_color}%-15s${NC} %-25s ${MAGENTA}│${NC}\n" \
                "$canister" \
                "$(if [[ "$canister_id" == "NOT_DEPLOYED" ]]; then echo "NOT_DEPLOYED"; else echo "RUNNING"; fi)" \
                "$health_status" \
                "$last_check"
        fi
    done
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo ""
        echo "  ],"
    else
        echo -e "${MAGENTA}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
}

# Display system metrics
display_system_metrics() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "  \"metrics\": {"
    else
        echo -e "${BLUE}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${BLUE}│                              SYSTEM METRICS                                │${NC}"
        echo -e "${BLUE}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
    fi
    
    # Get portfolio state metrics
    local portfolio_metrics
    portfolio_metrics=$(get_canister_metrics "portfolio_state")
    
    if [[ "$portfolio_metrics" != "ERROR" ]]; then
        # Parse metrics (simplified - would need proper JSON parsing)
        local portfolio_count
        local transaction_count
        local total_balance
        
        portfolio_count=$(echo "$portfolio_metrics" | grep -o 'portfolio_count = [0-9]*' | grep -o '[0-9]*' || echo "0")
        transaction_count=$(echo "$portfolio_metrics" | grep -o 'transaction_count = [0-9]*' | grep -o '[0-9]*' || echo "0")
        total_balance=$(echo "$portfolio_metrics" | grep -o 'total_balance = [0-9.]*' | grep -o '[0-9.]*' || echo "0.0")
        
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo "    \"portfolio_count\": $portfolio_count,"
            echo "    \"transaction_count\": $transaction_count,"
            echo "    \"total_balance\": $total_balance"
        else
            printf "${BLUE}│${NC} %-30s: %-43s ${BLUE}│${NC}\n" "Active Portfolios" "$portfolio_count"
            printf "${BLUE}│${NC} %-30s: %-43s ${BLUE}│${NC}\n" "Total Transactions" "$transaction_count"
            printf "${BLUE}│${NC} %-30s: %-43s ${BLUE}│${NC}\n" "Total Balance (BTC)" "$total_balance"
        fi
    else
        if [[ "$JSON_OUTPUT" == "true" ]]; then
            echo "    \"error\": \"Unable to fetch metrics\""
        else
            printf "${BLUE}│${NC} %-74s ${BLUE}│${NC}\n" "Unable to fetch system metrics"
        fi
    fi
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "  },"
    else
        echo -e "${BLUE}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
}

# Display performance data
display_performance() {
    if [[ "$COMPACT_MODE" == "true" ]]; then
        return
    fi
    
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "  \"performance\": {"
        echo "    \"note\": \"Performance data would be displayed here\""
        echo "  }"
    else
        echo -e "${YELLOW}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
        echo -e "${YELLOW}│                            PERFORMANCE DATA                                │${NC}"
        echo -e "${YELLOW}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
        printf "${YELLOW}│${NC} %-74s ${YELLOW}│${NC}\n" "Performance monitoring data would be displayed here"
        printf "${YELLOW}│${NC} %-74s ${YELLOW}│${NC}\n" "- Function call latencies"
        printf "${YELLOW}│${NC} %-74s ${YELLOW}│${NC}\n" "- Success rates"
        printf "${YELLOW}│${NC} %-74s ${YELLOW}│${NC}\n" "- Error rates"
        echo -e "${YELLOW}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
        echo ""
    fi
}

# Display alerts
display_alerts() {
    if [[ "$JSON_OUTPUT" == "true" ]]; then
        echo "}"
        return
    fi
    
    echo -e "${RED}┌─────────────────────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${RED}│                                 ALERTS                                     │${NC}"
    echo -e "${RED}├─────────────────────────────────────────────────────────────────────────────┤${NC}"
    
    local has_alerts=false
    
    # Check for unhealthy canisters
    for canister in "${CANISTERS[@]}"; do
        local health_status
        health_status=$(get_canister_health "$canister")
        
        if [[ "$health_status" != "HEALTHY" ]]; then
            printf "${RED}│${NC} ${RED}⚠${NC}  %-69s ${RED}│${NC}\n" "$canister is $health_status"
            has_alerts=true
        fi
    done
    
    if [[ "$has_alerts" == "false" ]]; then
        printf "${RED}│${NC} %-74s ${RED}│${NC}\n" "No active alerts"
    fi
    
    echo -e "${RED}└─────────────────────────────────────────────────────────────────────────────┘${NC}"
}

# Main monitoring loop
monitor_system() {
    while true; do
        display_header
        display_canister_status
        display_system_metrics
        display_performance
        display_alerts
        
        if [[ "$RUN_ONCE" == "true" ]]; then
            break
        fi
        
        if [[ "$JSON_OUTPUT" == "false" ]]; then
            echo -e "${CYAN}Press Ctrl+C to exit. Refreshing in $REFRESH_INTERVAL seconds...${NC}"
        fi
        
        sleep "$REFRESH_INTERVAL"
    done
}

# Check dependencies
if ! command -v dfx &> /dev/null; then
    log_error "dfx is not installed or not in PATH"
    exit 1
fi

# Start monitoring
log_info "Starting BetterTrade monitoring dashboard for $ENVIRONMENT"
log_info "Refresh interval: $REFRESH_INTERVAL seconds"

if [[ "$JSON_OUTPUT" == "false" ]]; then
    log_info "Press Ctrl+C to exit"
    echo ""
fi

monitor_system