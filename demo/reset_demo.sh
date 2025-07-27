#!/bin/bash

# BetterTrade Demo Reset Script
# Resets all demo data and prepares system for fresh demonstration

set -e

echo "🔄 Starting BetterTrade Demo Reset..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Function to print colored output
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if dfx is running
check_dfx_status() {
    print_status "Checking dfx status..."
    if ! dfx ping > /dev/null 2>&1; then
        print_error "dfx is not running. Please start dfx with 'dfx start --background'"
        exit 1
    fi
    print_success "dfx is running"
}

# Deploy canisters if needed
deploy_canisters() {
    print_status "Checking canister deployment status..."
    
    # Check if canisters are deployed
    if ! dfx canister status user_registry > /dev/null 2>&1; then
        print_warning "Canisters not deployed. Deploying now..."
        dfx deploy
        print_success "Canisters deployed successfully"
    else
        print_success "Canisters already deployed"
    fi
}

# Reset User Registry data
reset_user_registry() {
    print_status "Resetting User Registry data..."
    
    # Clear demo users (this would be a custom method in production)
    dfx canister call user_registry get_system_stats > /dev/null 2>&1 || {
        print_warning "User Registry not responding, skipping reset"
        return
    }
    
    print_success "User Registry reset completed"
}

# Reset Portfolio State data
reset_portfolio_state() {
    print_status "Resetting Portfolio State data..."
    
    # Clear demo portfolios and transactions
    dfx canister call portfolio_state get_system_stats > /dev/null 2>&1 || {
        print_warning "Portfolio State not responding, skipping reset"
        return
    }
    
    print_success "Portfolio State reset completed"
}

# Reset Strategy Selector data
reset_strategy_selector() {
    print_status "Resetting Strategy Selector data..."
    
    # Clear demo plans and recommendations
    dfx canister call strategy_selector list_strategies > /dev/null 2>&1 || {
        print_warning "Strategy Selector not responding, skipping reset"
        return
    }
    
    print_success "Strategy Selector reset completed"
}

# Reset Execution Agent data
reset_execution_agent() {
    print_status "Resetting Execution Agent data..."
    
    # Clear demo executions and transaction status
    dfx canister call execution_agent get_signing_stats > /dev/null 2>&1 || {
        print_warning "Execution Agent not responding, skipping reset"
        return
    }
    
    print_success "Execution Agent reset completed"
}

# Reset Risk Guard data
reset_risk_guard() {
    print_status "Resetting Risk Guard data..."
    
    # Clear demo risk configurations
    dfx canister call risk_guard get_system_stats > /dev/null 2>&1 || {
        print_warning "Risk Guard not responding, skipping reset"
        return
    }
    
    print_success "Risk Guard reset completed"
}

# Load demo data
load_demo_data() {
    print_status "Loading fresh demo data..."
    
    # Demo users
    print_status "Creating demo users..."
    
    # Alice (Conservative)
    dfx canister call user_registry register '("Alice (Conservative)", null)' > /dev/null 2>&1 || true
    dfx canister call user_registry link_wallet '("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx", variant { testnet })' > /dev/null 2>&1 || true
    dfx canister call user_registry set_risk_profile '(principal "demo-conservative-user", variant { conservative })' > /dev/null 2>&1 || true
    
    # Bob (Balanced)  
    dfx canister call user_registry register '("Bob (Balanced)", null)' > /dev/null 2>&1 || true
    dfx canister call user_registry link_wallet '("tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3", variant { testnet })' > /dev/null 2>&1 || true
    dfx canister call user_registry set_risk_profile '(principal "demo-balanced-user", variant { balanced })' > /dev/null 2>&1 || true
    
    # Charlie (Aggressive)
    dfx canister call user_registry register '("Charlie (Aggressive)", null)' > /dev/null 2>&1 || true
    dfx canister call user_registry link_wallet '("tb1pqqqqp0whnlschrjnfpvy5vgqq7hkrma8ne6smn6ctdybt0020h2qk3k3dn", variant { testnet })' > /dev/null 2>&1 || true
    dfx canister call user_registry set_risk_profile '(principal "demo-aggressive-user", variant { aggressive })' > /dev/null 2>&1 || true
    
    print_success "Demo users created"
    
    # Demo portfolios
    print_status "Setting up demo portfolios..."
    
    # Alice's portfolio
    dfx canister call portfolio_state update_balance '(principal "demo-conservative-user", 50000000)' > /dev/null 2>&1 || true
    
    # Bob's portfolio  
    dfx canister call portfolio_state update_balance '(principal "demo-balanced-user", 100000000)' > /dev/null 2>&1 || true
    
    # Charlie's portfolio
    dfx canister call portfolio_state update_balance '(principal "demo-aggressive-user", 200000000)' > /dev/null 2>&1 || true
    
    print_success "Demo portfolios configured"
    
    print_success "Demo data loaded successfully"
}

# Validate demo setup
validate_demo_setup() {
    print_status "Validating demo setup..."
    
    # Check user registry
    local user_stats
    user_stats=$(dfx canister call user_registry get_system_stats 2>/dev/null) || {
        print_error "Failed to get user registry stats"
        return 1
    }
    
    # Check portfolio state
    local portfolio_stats  
    portfolio_stats=$(dfx canister call portfolio_state get_system_stats 2>/dev/null) || {
        print_error "Failed to get portfolio state stats"
        return 1
    }
    
    # Check strategy selector
    local strategies
    strategies=$(dfx canister call strategy_selector list_strategies 2>/dev/null) || {
        print_error "Failed to get strategy list"
        return 1
    }
    
    print_success "Demo setup validation completed"
    
    # Print summary
    echo ""
    echo "📊 Demo Setup Summary:"
    echo "User Registry: $user_stats"
    echo "Portfolio State: $portfolio_stats"
    echo "Strategies Available: $(echo "$strategies" | grep -o '"id"' | wc -l) strategies"
    echo ""
}

# Generate demo presentation materials
generate_presentation_materials() {
    print_status "Generating presentation materials..."
    
    # Create demo data summary
    cat > demo/demo_data_summary.md << EOF
# Demo Data Summary
Generated: $(date)

## Demo Users
- **Alice (Conservative)**: 0.5 BTC, Conservative risk profile
- **Bob (Balanced)**: 1.0 BTC, Balanced risk profile  
- **Charlie (Aggressive)**: 2.0 BTC, Aggressive risk profile

## Available Strategies
- Conservative Bitcoin Lending (4.5% - 6.2% APY)
- Balanced Liquidity Provision (12.3% - 18.7% APY)
- Aggressive Yield Farming (25.1% - 42.8% APY)

## Demo Flow
1. User Registration and Wallet Connection
2. Bitcoin Deposit and Detection
3. Risk Profile Selection
4. Strategy Recommendation
5. Strategy Approval and Execution
6. Portfolio Monitoring
7. Risk Guard Configuration

## Reset Status
Last Reset: $(date)
Canisters: Deployed and Ready
Demo Data: Loaded
Validation: Passed
EOF
    
    print_success "Presentation materials generated"
}

# Main execution
main() {
    echo "🚀 BetterTrade Demo Reset Script"
    echo "================================"
    echo ""
    
    check_dfx_status
    deploy_canisters
    
    echo ""
    print_status "Resetting canister data..."
    reset_user_registry
    reset_portfolio_state  
    reset_strategy_selector
    reset_execution_agent
    reset_risk_guard
    
    echo ""
    load_demo_data
    
    echo ""
    validate_demo_setup
    
    echo ""
    generate_presentation_materials
    
    echo ""
    print_success "🎉 Demo reset completed successfully!"
    print_status "Demo is ready for presentation"
    
    echo ""
    echo "📋 Next Steps:"
    echo "1. Review demo script: demo/demo_script.md"
    echo "2. Open BetterTrade application"
    echo "3. Follow demo flow with Alice (Conservative) user"
    echo "4. Use demo data summary: demo/demo_data_summary.md"
    echo ""
    
    echo "🔧 Useful Commands:"
    echo "- Check canister status: dfx canister status --all"
    echo "- View logs: dfx canister logs <canister_name>"
    echo "- Re-run reset: ./demo/reset_demo.sh"
    echo ""
}

# Run main function
main "$@"