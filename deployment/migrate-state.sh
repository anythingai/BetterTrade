#!/bin/bash

# BetterTrade State Migration Utility
# Handles state migration between canister versions

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
BACKUP_DIR="$PROJECT_ROOT/backups"

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
    echo "Usage: $0 <command> <environment> [options]"
    echo ""
    echo "Commands:"
    echo "  backup     - Create state backup before migration"
    echo "  migrate    - Perform state migration"
    echo "  restore    - Restore state from backup"
    echo "  validate   - Validate migrated state"
    echo ""
    echo "Environments:"
    echo "  local      - Local replica"
    echo "  testnet    - ICP testnet"
    echo "  mainnet    - ICP mainnet"
    echo ""
    echo "Options:"
    echo "  --version <version>    Specify backup version"
    echo "  --canister <name>      Target specific canister"
    echo "  --dry-run             Show what would be done"
    echo "  --force               Force operation without confirmation"
    echo ""
    echo "Examples:"
    echo "  $0 backup local"
    echo "  $0 migrate testnet --version v1.2.0"
    echo "  $0 restore local --version v1.1.0 --canister portfolio_state"
}

# Parse arguments
COMMAND=""
ENVIRONMENT=""
VERSION=""
TARGET_CANISTER=""
DRY_RUN=false
FORCE=false

while [[ $# -gt 0 ]]; do
    case $1 in
        backup|migrate|restore|validate)
            COMMAND=$1
            shift
            ;;
        local|testnet|mainnet)
            ENVIRONMENT=$1
            shift
            ;;
        --version)
            VERSION="$2"
            shift 2
            ;;
        --canister)
            TARGET_CANISTER="$2"
            shift 2
            ;;
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --force)
            FORCE=true
            shift
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate arguments
if [[ -z "$COMMAND" || -z "$ENVIRONMENT" ]]; then
    log_error "Command and environment are required"
    usage
    exit 1
fi

# Set default version if not provided
if [[ -z "$VERSION" ]]; then
    VERSION=$(date +"%Y%m%d_%H%M%S")
fi

# Create backup directory if it doesn't exist
mkdir -p "$BACKUP_DIR"

# Canister list
CANISTERS=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")

# Filter canisters if specific canister is targeted
if [[ -n "$TARGET_CANISTER" ]]; then
    CANISTERS=("$TARGET_CANISTER")
fi

# Backup function
backup_state() {
    log_info "🗄️  Creating state backup for $ENVIRONMENT (version: $VERSION)"
    
    local backup_path="$BACKUP_DIR/$ENVIRONMENT/$VERSION"
    mkdir -p "$backup_path"
    
    for canister in "${CANISTERS[@]}"; do
        log_info "Backing up $canister state..."
        
        if [[ "$DRY_RUN" == "false" ]]; then
            # Export canister state
            local state_file="$backup_path/${canister}_state.json"
            
            # Call canister export function
            if dfx canister --network "$ENVIRONMENT" call "$canister" export_state > "$state_file" 2>/dev/null; then
                log_success "✅ $canister state backed up"
            else
                log_warning "⚠️  $canister state backup failed (may not support export)"
            fi
            
            # Backup canister WASM
            local wasm_file="$backup_path/${canister}.wasm"
            if dfx canister --network "$ENVIRONMENT" call "$canister" __get_candid > /dev/null 2>&1; then
                # This is a simplified approach - in practice, you'd need to extract the WASM
                touch "$wasm_file"
                log_info "WASM backup placeholder created for $canister"
            fi
        else
            log_info "Would backup $canister state to $backup_path"
        fi
    done
    
    # Create backup metadata
    if [[ "$DRY_RUN" == "false" ]]; then
        cat > "$backup_path/metadata.json" << EOF
{
  "environment": "$ENVIRONMENT",
  "version": "$VERSION",
  "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "canisters": $(printf '%s\n' "${CANISTERS[@]}" | jq -R . | jq -s .),
  "dfx_version": "$(dfx --version | grep -o '[0-9]\+\.[0-9]\+\.[0-9]\+')"
}
EOF
        log_success "✅ Backup metadata created"
    fi
    
    log_success "🎉 State backup completed: $backup_path"
}

# Migration function
migrate_state() {
    log_info "🔄 Starting state migration for $ENVIRONMENT"
    
    # Check if backup exists
    local backup_path="$BACKUP_DIR/$ENVIRONMENT/$VERSION"
    if [[ ! -d "$backup_path" && "$DRY_RUN" == "false" ]]; then
        log_error "Backup not found: $backup_path"
        log_info "Run backup command first: $0 backup $ENVIRONMENT --version $VERSION"
        exit 1
    fi
    
    for canister in "${CANISTERS[@]}"; do
        log_info "Migrating $canister state..."
        
        if [[ "$DRY_RUN" == "false" ]]; then
            # Call canister migration function
            if dfx canister --network "$ENVIRONMENT" call "$canister" migrate_state "(\"$VERSION\")" 2>/dev/null; then
                log_success "✅ $canister state migrated"
            else
                log_warning "⚠️  $canister migration failed or not needed"
            fi
            
            # Validate migration
            if dfx canister --network "$ENVIRONMENT" call "$canister" validate_state 2>/dev/null; then
                log_success "✅ $canister state validation passed"
            else
                log_error "❌ $canister state validation failed"
                return 1
            fi
        else
            log_info "Would migrate $canister state"
        fi
    done
    
    log_success "🎉 State migration completed"
}

# Restore function
restore_state() {
    log_info "🔙 Restoring state from backup for $ENVIRONMENT (version: $VERSION)"
    
    local backup_path="$BACKUP_DIR/$ENVIRONMENT/$VERSION"
    
    # Check if backup exists
    if [[ ! -d "$backup_path" ]]; then
        log_error "Backup not found: $backup_path"
        exit 1
    fi
    
    # Confirmation prompt
    if [[ "$FORCE" == "false" ]]; then
        echo -n "This will overwrite current state. Are you sure? (y/N): "
        read -r confirmation
        if [[ "$confirmation" != "y" && "$confirmation" != "Y" ]]; then
            log_info "Restore cancelled"
            exit 0
        fi
    fi
    
    for canister in "${CANISTERS[@]}"; do
        log_info "Restoring $canister state..."
        
        local state_file="$backup_path/${canister}_state.json"
        
        if [[ -f "$state_file" && "$DRY_RUN" == "false" ]]; then
            # Call canister restore function
            if dfx canister --network "$ENVIRONMENT" call "$canister" restore_state "$(cat "$state_file")" 2>/dev/null; then
                log_success "✅ $canister state restored"
            else
                log_error "❌ $canister state restore failed"
                return 1
            fi
        elif [[ "$DRY_RUN" == "true" ]]; then
            log_info "Would restore $canister state from $state_file"
        else
            log_warning "⚠️  State file not found for $canister: $state_file"
        fi
    done
    
    log_success "🎉 State restore completed"
}

# Validation function
validate_state() {
    log_info "🔍 Validating state consistency for $ENVIRONMENT"
    
    local validation_passed=true
    
    for canister in "${CANISTERS[@]}"; do
        log_info "Validating $canister state..."
        
        if [[ "$DRY_RUN" == "false" ]]; then
            if dfx canister --network "$ENVIRONMENT" call "$canister" validate_state 2>/dev/null; then
                log_success "✅ $canister state validation passed"
            else
                log_error "❌ $canister state validation failed"
                validation_passed=false
            fi
            
            # Additional consistency checks
            if dfx canister --network "$ENVIRONMENT" call "$canister" health_check 2>/dev/null; then
                log_success "✅ $canister health check passed"
            else
                log_error "❌ $canister health check failed"
                validation_passed=false
            fi
        else
            log_info "Would validate $canister state"
        fi
    done
    
    # Cross-canister consistency checks
    if [[ "$DRY_RUN" == "false" ]]; then
        log_info "Running cross-canister consistency checks..."
        
        # Check user count consistency between user_registry and portfolio_state
        local user_count_registry
        local user_count_portfolio
        
        user_count_registry=$(dfx canister --network "$ENVIRONMENT" call user_registry get_user_count 2>/dev/null | grep -o '[0-9]\+' || echo "0")
        user_count_portfolio=$(dfx canister --network "$ENVIRONMENT" call portfolio_state get_portfolio_count 2>/dev/null | grep -o '[0-9]\+' || echo "0")
        
        if [[ "$user_count_registry" == "$user_count_portfolio" ]]; then
            log_success "✅ User count consistency check passed ($user_count_registry users)"
        else
            log_error "❌ User count mismatch: registry=$user_count_registry, portfolio=$user_count_portfolio"
            validation_passed=false
        fi
    fi
    
    if [[ "$validation_passed" == "true" ]]; then
        log_success "🎉 All state validation checks passed"
        return 0
    else
        log_error "❌ State validation failed"
        return 1
    fi
}

# List available backups
list_backups() {
    log_info "📋 Available backups for $ENVIRONMENT:"
    
    local env_backup_dir="$BACKUP_DIR/$ENVIRONMENT"
    
    if [[ -d "$env_backup_dir" ]]; then
        for backup in "$env_backup_dir"/*; do
            if [[ -d "$backup" ]]; then
                local backup_name=$(basename "$backup")
                local metadata_file="$backup/metadata.json"
                
                if [[ -f "$metadata_file" ]]; then
                    local timestamp
                    timestamp=$(jq -r '.timestamp' "$metadata_file" 2>/dev/null || echo "Unknown")
                    log_info "  $backup_name (created: $timestamp)"
                else
                    log_info "  $backup_name (no metadata)"
                fi
            fi
        done
    else
        log_info "  No backups found"
    fi
}

# Main execution
case "$COMMAND" in
    backup)
        backup_state
        ;;
    migrate)
        migrate_state
        ;;
    restore)
        restore_state
        ;;
    validate)
        validate_state
        ;;
    list)
        list_backups
        ;;
    *)
        log_error "Unknown command: $COMMAND"
        usage
        exit 1
        ;;
esac