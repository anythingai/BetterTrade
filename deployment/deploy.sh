#!/bin/bash

# BetterTrade Enhanced Deployment Script
# Supports local, testnet, and mainnet deployments with state migration

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
CONFIG_DIR="$SCRIPT_DIR/config"
ENVIRONMENTS_CONFIG="$CONFIG_DIR/environments.json"
CANISTER_CONFIG="$CONFIG_DIR/canister-config.json"

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

# Usage function
usage() {
    echo "Usage: $0 [OPTIONS] <environment>"
    echo ""
    echo "Environments:"
    echo "  local     - Deploy to local replica"
    echo "  testnet   - Deploy to ICP testnet"
    echo "  mainnet   - Deploy to ICP mainnet"
    echo ""
    echo "Options:"
    echo "  --upgrade         Perform upgrade deployment (preserve state)"
    echo "  --reinstall       Perform reinstall deployment (reset state)"
    echo "  --skip-frontend   Skip frontend deployment"
    echo "  --skip-build      Skip build step"
    echo "  --dry-run         Show what would be deployed without executing"
    echo "  --help            Show this help message"
    echo ""
    echo "Examples:"
    echo "  $0 local"
    echo "  $0 --upgrade testnet"
    echo "  $0 --reinstall --skip-frontend mainnet"
}

# Parse command line arguments
ENVIRONMENT=""
UPGRADE_MODE=""
SKIP_FRONTEND=false
SKIP_BUILD=false
DRY_RUN=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --upgrade)
            UPGRADE_MODE="upgrade"
            shift
            ;;
        --reinstall)
            UPGRADE_MODE="reinstall"
            shift
            ;;
        --skip-frontend)
            SKIP_FRONTEND=true
            shift
            ;;
        --skip-build)
            SKIP_BUILD=true
            shift
            ;;
        --dry-run)
            DRY_RUN=true
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

# Validate environment
if [[ -z "$ENVIRONMENT" ]]; then
    log_error "Environment is required"
    usage
    exit 1
fi

# Load environment configuration
if [[ ! -f "$ENVIRONMENTS_CONFIG" ]]; then
    log_error "Environment configuration not found: $ENVIRONMENTS_CONFIG"
    exit 1
fi

# Extract environment config using jq or python
get_config() {
    local key=$1
    if command -v jq &> /dev/null; then
        jq -r ".${ENVIRONMENT}.${key}" "$ENVIRONMENTS_CONFIG"
    else
        python3 -c "import json; config=json.load(open('$ENVIRONMENTS_CONFIG')); print(config['$ENVIRONMENT']['$key'])"
    fi
}

NETWORK=$(get_config "network")
REPLICA_URL=$(get_config "replica_url")
BITCOIN_NETWORK=$(get_config "bitcoin_network")
DEFAULT_UPGRADE_MODE=$(get_config "upgrade_mode")

# Set upgrade mode if not specified
if [[ -z "$UPGRADE_MODE" ]]; then
    UPGRADE_MODE="$DEFAULT_UPGRADE_MODE"
fi

log_info "🚀 Starting BetterTrade deployment"
log_info "Environment: $ENVIRONMENT"
log_info "Network: $NETWORK"
log_info "Upgrade Mode: $UPGRADE_MODE"
log_info "Bitcoin Network: $BITCOIN_NETWORK"

if [[ "$DRY_RUN" == "true" ]]; then
    log_warning "DRY RUN MODE - No actual deployment will occur"
fi

# Pre-deployment checks
log_info "🔍 Running pre-deployment checks..."

# Check dfx installation
if ! command -v dfx &> /dev/null; then
    log_error "dfx is not installed. Please install dfx first:"
    echo "   sh -ci \"\$(curl -fsSL https://sdk.dfinity.org/install.sh)\""
    exit 1
fi

# Check dfx version compatibility
DFX_VERSION=$(dfx --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')
log_info "dfx version: $DFX_VERSION"

# Check network connectivity
if [[ "$ENVIRONMENT" != "local" ]]; then
    log_info "Checking network connectivity to $REPLICA_URL..."
    if ! curl -s --max-time 10 "$REPLICA_URL/api/v2/status" > /dev/null; then
        log_error "Cannot connect to $REPLICA_URL"
        exit 1
    fi
fi

# Start local replica if needed
if [[ "$ENVIRONMENT" == "local" ]]; then
    log_info "📡 Starting local replica..."
    if ! dfx ping local &> /dev/null; then
        if [[ "$DRY_RUN" == "false" ]]; then
            dfx start --clean --background
            sleep 5
        else
            log_info "Would start local replica"
        fi
    else
        log_info "Local replica already running"
    fi
fi

# Build project
if [[ "$SKIP_BUILD" == "false" ]]; then
    log_info "🏗️  Building project..."
    if [[ "$DRY_RUN" == "false" ]]; then
        cd "$PROJECT_ROOT"
        ./build.sh
    else
        log_info "Would build project"
    fi
fi

# Load deployment order
if command -v jq &> /dev/null; then
    DEPLOYMENT_ORDER=($(jq -r '.deployment_order[]' "$CANISTER_CONFIG"))
else
    DEPLOYMENT_ORDER=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard" "frontend")
fi

# Deploy canisters
log_info "📦 Deploying canisters in dependency order..."

for canister in "${DEPLOYMENT_ORDER[@]}"; do
    if [[ "$canister" == "frontend" && "$SKIP_FRONTEND" == "true" ]]; then
        log_info "Skipping frontend deployment"
        continue
    fi
    
    log_info "Deploying $canister..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        # Set environment variables for canister
        export BITSIGHT_ENVIRONMENT="$ENVIRONMENT"
        export BITSIGHT_BITCOIN_NETWORK="$BITCOIN_NETWORK"
        export BITSIGHT_REPLICA_URL="$REPLICA_URL"
        
        # Deploy with appropriate mode
        if [[ "$UPGRADE_MODE" == "upgrade" ]]; then
            dfx deploy --network "$NETWORK" --mode upgrade "$canister"
        else
            dfx deploy --network "$NETWORK" --mode reinstall "$canister"
        fi
        
        # Run post-deployment health check
        log_info "Running health check for $canister..."
        if ! timeout 30 dfx canister --network "$NETWORK" call "$canister" health_check 2>/dev/null; then
            log_warning "Health check failed for $canister (this may be expected for some canisters)"
        fi
    else
        log_info "Would deploy $canister with mode $UPGRADE_MODE"
    fi
done

# Generate Candid interfaces
log_info "📋 Generating Candid interfaces..."
if [[ "$DRY_RUN" == "false" ]]; then
    dfx generate --network "$NETWORK"
fi

# Post-deployment validation
log_info "✅ Running post-deployment validation..."

if [[ "$DRY_RUN" == "false" ]]; then
    # Get canister IDs
    log_info "📊 Deployed Canister IDs:"
    for canister in "${DEPLOYMENT_ORDER[@]}"; do
        if [[ "$canister" == "frontend" && "$SKIP_FRONTEND" == "true" ]]; then
            continue
        fi
        
        CANISTER_ID=$(dfx canister --network "$NETWORK" id "$canister" 2>/dev/null || echo "Not deployed")
        log_info "  $canister: $CANISTER_ID"
    done
    
    # Display access URLs
    if [[ "$ENVIRONMENT" == "local" ]]; then
        FRONTEND_ID=$(dfx canister --network "$NETWORK" id frontend 2>/dev/null || echo "")
        if [[ -n "$FRONTEND_ID" && "$SKIP_FRONTEND" == "false" ]]; then
            log_success "🌐 Frontend URL: http://localhost:4943/?canisterId=$FRONTEND_ID"
        fi
        log_success "🔧 Candid UI: http://localhost:4943/?canisterId=$(dfx canister --network "$NETWORK" id __Candid_UI 2>/dev/null || echo "")"
    else
        FRONTEND_ID=$(dfx canister --network "$NETWORK" id frontend 2>/dev/null || echo "")
        if [[ -n "$FRONTEND_ID" && "$SKIP_FRONTEND" == "false" ]]; then
            log_success "🌐 Frontend URL: https://$FRONTEND_ID.ic0.app"
        fi
    fi
fi

# Save deployment info
DEPLOYMENT_INFO_FILE="$PROJECT_ROOT/deployment-info-$ENVIRONMENT.json"
if [[ "$DRY_RUN" == "false" ]]; then
    log_info "💾 Saving deployment information to $DEPLOYMENT_INFO_FILE"
    
    cat > "$DEPLOYMENT_INFO_FILE" << EOF
{
  "environment": "$ENVIRONMENT",
  "network": "$NETWORK",
  "deployment_time": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "upgrade_mode": "$UPGRADE_MODE",
  "bitcoin_network": "$BITCOIN_NETWORK",
  "dfx_version": "$DFX_VERSION",
  "canister_ids": {
EOF
    
    first=true
    for canister in "${DEPLOYMENT_ORDER[@]}"; do
        if [[ "$canister" == "frontend" && "$SKIP_FRONTEND" == "true" ]]; then
            continue
        fi
        
        CANISTER_ID=$(dfx canister --network "$NETWORK" id "$canister" 2>/dev/null || echo "")
        if [[ -n "$CANISTER_ID" ]]; then
            if [[ "$first" == "false" ]]; then
                echo "," >> "$DEPLOYMENT_INFO_FILE"
            fi
            echo "    \"$canister\": \"$CANISTER_ID\"" >> "$DEPLOYMENT_INFO_FILE"
            first=false
        fi
    done
    
    cat >> "$DEPLOYMENT_INFO_FILE" << EOF
  }
}
EOF
fi

log_success "🎉 Deployment completed successfully!"

if [[ "$ENVIRONMENT" != "local" ]]; then
    log_info "💡 Next steps:"
    log_info "  • Monitor canister health and performance"
    log_info "  • Run integration tests against deployed canisters"
    log_info "  • Update frontend configuration with new canister IDs"
fi