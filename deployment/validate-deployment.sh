#!/bin/bash

# BetterTrade Deployment Validation Script
# Comprehensive testing suite for post-deployment validation

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

# Test result tracking
TESTS_PASSED=0
TESTS_FAILED=0
FAILED_TESTS=()

# Test execution function
run_test() {
    local test_name="$1"
    local test_command="$2"
    
    log_info "Running test: $test_name"
    
    if eval "$test_command"; then
        log_success "✅ $test_name"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "❌ $test_name"
        FAILED_TESTS+=("$test_name")
        ((TESTS_FAILED++))
        return 1
    fi
}

# Usage function
usage() {
    echo "Usage: $0 <environment> [options]"
    echo ""
    echo "Environments:"
    echo "  local     - Validate local deployment"
    echo "  testnet   - Validate testnet deployment"
    echo "  mainnet   - Validate mainnet deployment"
    echo ""
    echo "Options:"
    echo "  --skip-integration    Skip integration tests"
    echo "  --skip-performance    Skip performance tests"
    echo "  --verbose            Enable verbose output"
    echo "  --help               Show this help message"
}

# Parse arguments
ENVIRONMENT=""
SKIP_INTEGRATION=false
SKIP_PERFORMANCE=false
VERBOSE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --skip-integration)
            SKIP_INTEGRATION=true
            shift
            ;;
        --skip-performance)
            SKIP_PERFORMANCE=true
            shift
            ;;
        --verbose)
            VERBOSE=true
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

log_info "🧪 Starting deployment validation for $ENVIRONMENT"

# Test 1: Canister Deployment Verification
test_canister_deployment() {
    local canisters=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard" "frontend")
    
    for canister in "${canisters[@]}"; do
        local canister_id
        canister_id=$(dfx canister --network "$ENVIRONMENT" id "$canister" 2>/dev/null)
        
        if [[ -z "$canister_id" ]]; then
            log_error "Canister $canister not deployed"
            return 1
        fi
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "$canister: $canister_id"
        fi
    done
    
    return 0
}

# Test 2: Health Check Validation
test_health_checks() {
    local canisters=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")
    
    for canister in "${canisters[@]}"; do
        if ! timeout 10 dfx canister --network "$ENVIRONMENT" call "$canister" health_check 2>/dev/null; then
            log_error "Health check failed for $canister"
            return 1
        fi
    done
    
    return 0
}

# Test 3: Inter-Canister Communication
test_inter_canister_communication() {
    # Test user registry -> portfolio state communication
    if ! dfx canister --network "$ENVIRONMENT" call user_registry test_portfolio_connection 2>/dev/null; then
        log_error "User registry cannot communicate with portfolio state"
        return 1
    fi
    
    # Test strategy selector -> user registry communication
    if ! dfx canister --network "$ENVIRONMENT" call strategy_selector test_user_registry_connection 2>/dev/null; then
        log_error "Strategy selector cannot communicate with user registry"
        return 1
    fi
    
    # Test execution agent -> strategy selector communication
    if ! dfx canister --network "$ENVIRONMENT" call execution_agent test_strategy_selector_connection 2>/dev/null; then
        log_error "Execution agent cannot communicate with strategy selector"
        return 1
    fi
    
    return 0
}

# Test 4: Data Consistency Validation
test_data_consistency() {
    local canisters=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")
    
    for canister in "${canisters[@]}"; do
        if ! dfx canister --network "$ENVIRONMENT" call "$canister" validate_state 2>/dev/null; then
            log_error "Data consistency check failed for $canister"
            return 1
        fi
    done
    
    return 0
}

# Test 5: Basic Functionality Tests
test_basic_functionality() {
    # Test user registration
    local test_principal="2vxsx-fae"
    if ! dfx canister --network "$ENVIRONMENT" call user_registry register "(\"test_user\", null)" 2>/dev/null; then
        log_error "User registration test failed"
        return 1
    fi
    
    # Test strategy listing
    if ! dfx canister --network "$ENVIRONMENT" call strategy_selector list_strategies 2>/dev/null; then
        log_error "Strategy listing test failed"
        return 1
    fi
    
    # Test portfolio query (should handle non-existent user gracefully)
    if ! dfx canister --network "$ENVIRONMENT" call portfolio_state get_portfolio "(\"test_user_id\")" 2>/dev/null; then
        log_error "Portfolio query test failed"
        return 1
    fi
    
    return 0
}

# Test 6: Security Validation
test_security() {
    # Test unauthorized access prevention
    local canisters=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")
    
    for canister in "${canisters[@]}"; do
        # Try to call admin functions without proper authorization
        if dfx canister --network "$ENVIRONMENT" call "$canister" admin_reset 2>/dev/null; then
            log_error "Security test failed: unauthorized admin access allowed for $canister"
            return 1
        fi
    done
    
    return 0
}

# Test 7: Performance Validation
test_performance() {
    if [[ "$SKIP_PERFORMANCE" == "true" ]]; then
        log_info "Skipping performance tests"
        return 0
    fi
    
    # Test response times for critical functions
    local start_time
    local end_time
    local duration
    
    # Health check response time
    start_time=$(date +%s%N)
    dfx canister --network "$ENVIRONMENT" call portfolio_state health_check >/dev/null 2>&1
    end_time=$(date +%s%N)
    duration=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
    
    if [[ $duration -gt 5000 ]]; then # 5 second threshold
        log_error "Health check response time too slow: ${duration}ms"
        return 1
    fi
    
    if [[ "$VERBOSE" == "true" ]]; then
        log_info "Health check response time: ${duration}ms"
    fi
    
    return 0
}

# Test 8: Integration Tests
test_integration() {
    if [[ "$SKIP_INTEGRATION" == "true" ]]; then
        log_info "Skipping integration tests"
        return 0
    fi
    
    # Run comprehensive integration test
    cd "$PROJECT_ROOT"
    if ! dfx canister --network "$ENVIRONMENT" call portfolio_state run_integration_test 2>/dev/null; then
        log_error "Integration test failed"
        return 1
    fi
    
    return 0
}

# Test 9: Frontend Accessibility
test_frontend() {
    if [[ "$ENVIRONMENT" == "local" ]]; then
        local frontend_id
        frontend_id=$(dfx canister --network "$ENVIRONMENT" id frontend 2>/dev/null)
        
        if [[ -n "$frontend_id" ]]; then
            local frontend_url="http://localhost:4943/?canisterId=$frontend_id"
            
            # Test if frontend is accessible
            if ! curl -s --max-time 10 "$frontend_url" >/dev/null; then
                log_error "Frontend not accessible at $frontend_url"
                return 1
            fi
            
            if [[ "$VERBOSE" == "true" ]]; then
                log_info "Frontend accessible at $frontend_url"
            fi
        fi
    else
        local frontend_id
        frontend_id=$(dfx canister --network "$ENVIRONMENT" id frontend 2>/dev/null)
        
        if [[ -n "$frontend_id" ]]; then
            local frontend_url="https://$frontend_id.ic0.app"
            
            # Test if frontend is accessible
            if ! curl -s --max-time 30 "$frontend_url" >/dev/null; then
                log_error "Frontend not accessible at $frontend_url"
                return 1
            fi
            
            if [[ "$VERBOSE" == "true" ]]; then
                log_info "Frontend accessible at $frontend_url"
            fi
        fi
    fi
    
    return 0
}

# Test 10: Cycle Balance Validation
test_cycle_balance() {
    if [[ "$ENVIRONMENT" == "local" ]]; then
        log_info "Skipping cycle balance check for local environment"
        return 0
    fi
    
    local canisters=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard" "frontend")
    local min_cycles=1000000000000 # 1T cycles minimum
    
    for canister in "${canisters[@]}"; do
        local status_output
        status_output=$(dfx canister --network "$ENVIRONMENT" status "$canister" 2>/dev/null)
        
        local cycles
        cycles=$(echo "$status_output" | grep -o '[0-9,]*_cycles' | tr -d ',' | tr -d '_cycles')
        
        if [[ -n "$cycles" && "$cycles" -lt "$min_cycles" ]]; then
            log_warning "Low cycle balance for $canister: $cycles cycles"
        fi
        
        if [[ "$VERBOSE" == "true" ]]; then
            log_info "$canister cycle balance: $cycles cycles"
        fi
    done
    
    return 0
}

# Run all tests
log_info "🚀 Starting validation tests..."

run_test "Canister Deployment Verification" "test_canister_deployment"
run_test "Health Check Validation" "test_health_checks"
run_test "Inter-Canister Communication" "test_inter_canister_communication"
run_test "Data Consistency Validation" "test_data_consistency"
run_test "Basic Functionality Tests" "test_basic_functionality"
run_test "Security Validation" "test_security"
run_test "Performance Validation" "test_performance"
run_test "Integration Tests" "test_integration"
run_test "Frontend Accessibility" "test_frontend"
run_test "Cycle Balance Validation" "test_cycle_balance"

# Summary
echo ""
log_info "📊 Validation Summary"
log_info "Tests Passed: $TESTS_PASSED"
log_info "Tests Failed: $TESTS_FAILED"

if [[ $TESTS_FAILED -gt 0 ]]; then
    log_error "Failed Tests:"
    for test in "${FAILED_TESTS[@]}"; do
        log_error "  - $test"
    done
    
    log_error "❌ Deployment validation FAILED"
    exit 1
else
    log_success "✅ All validation tests PASSED"
    log_success "🎉 Deployment is ready for production use"
fi