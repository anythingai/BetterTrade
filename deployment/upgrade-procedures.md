# BetterTrade Upgrade Procedures

## Overview

This document outlines the procedures for upgrading BetterTrade canisters while preserving state and ensuring system consistency. The upgrade process includes pre-upgrade hooks, state migration, and post-upgrade validation.

## Upgrade Types

### 1. Hot Upgrade (Recommended)
- Preserves all stable memory and state
- Zero downtime for users
- Requires careful state migration planning

### 2. Reinstall Upgrade
- Resets all state to initial values
- Used for major breaking changes
- Requires data backup and restoration

## Pre-Upgrade Checklist

### System Health Check
- [ ] Verify all canisters are healthy
- [ ] Check inter-canister communication
- [ ] Validate Bitcoin network connectivity
- [ ] Confirm adequate cycles balance

### Backup Procedures
- [ ] Export user registry data
- [ ] Backup portfolio states
- [ ] Save strategy configurations
- [ ] Archive transaction history

### Testing Requirements
- [ ] Run full test suite on new code
- [ ] Validate state migration scripts
- [ ] Test rollback procedures
- [ ] Verify canister dependencies

## Upgrade Sequence

### Phase 1: Core Data Canisters
1. **Portfolio State Canister**
   - Contains critical user balance data
   - Requires careful UTXO state migration
   - Must maintain transaction history integrity

2. **User Registry Canister**
   - User account and wallet mappings
   - Risk profile configurations
   - Authentication state preservation

### Phase 2: Agent Canisters
3. **Strategy Selector Canister**
   - Strategy templates and recommendations
   - Scoring algorithm updates
   - Plan approval state

4. **Execution Agent Canister**
   - Pending transaction state
   - Signing key references
   - Bitcoin network integration

5. **Risk Guard Canister**
   - Risk monitoring configurations
   - Alert thresholds and history
   - Protective action state

### Phase 3: Frontend
6. **Frontend Canister**
   - UI assets and configuration
   - Canister ID references
   - User interface updates

## State Migration Procedures

### Portfolio State Migration

```motoko
// Pre-upgrade hook
system func preupgrade() {
    // Serialize stable variables
    stable_users := Iter.toArray(users.entries());
    stable_portfolios := Iter.toArray(portfolios.entries());
    stable_transactions := Iter.toArray(transactions.entries());
    stable_utxos := Iter.toArray(utxos.entries());
}

// Post-upgrade hook
system func postupgrade() {
    // Deserialize and migrate data
    users := HashMap.fromIter(stable_users.vals(), stable_users.size(), Text.equal, Text.hash);
    portfolios := HashMap.fromIter(stable_portfolios.vals(), stable_portfolios.size(), Text.equal, Text.hash);
    
    // Run migration hooks
    migrate_portfolio_schema();
    update_transaction_format();
    validate_utxo_consistency();
}
```

### User Registry Migration

```motoko
system func preupgrade() {
    stable_users := Iter.toArray(users.entries());
    stable_wallets := Iter.toArray(wallets.entries());
    stable_risk_profiles := Iter.toArray(risk_profiles.entries());
}

system func postupgrade() {
    users := HashMap.fromIter(stable_users.vals(), stable_users.size(), Principal.equal, Principal.hash);
    wallets := HashMap.fromIter(stable_wallets.vals(), stable_wallets.size(), Text.equal, Text.hash);
    
    // Migration hooks
    migrate_user_schema();
    update_wallet_format();
    validate_user_consistency();
}
```

## Rollback Procedures

### Automatic Rollback Triggers
- Health check failures after upgrade
- Inter-canister communication errors
- Critical functionality failures
- Data consistency violations

### Manual Rollback Process
1. Stop new user interactions
2. Revert to previous canister version
3. Restore backed-up state data
4. Validate system functionality
5. Resume normal operations

### Rollback Script
```bash
#!/bin/bash
# Emergency rollback script

ENVIRONMENT=$1
BACKUP_VERSION=$2

echo "🚨 Initiating emergency rollback for $ENVIRONMENT"

# Stop frontend to prevent new interactions
dfx canister --network $ENVIRONMENT stop frontend

# Rollback canisters in reverse order
ROLLBACK_ORDER=("risk_guard" "execution_agent" "strategy_selector" "user_registry" "portfolio_state")

for canister in "${ROLLBACK_ORDER[@]}"; do
    echo "Rolling back $canister to version $BACKUP_VERSION"
    dfx canister --network $ENVIRONMENT install --mode reinstall $canister --wasm "backups/${canister}-${BACKUP_VERSION}.wasm"
done

# Restore state from backups
./restore-state.sh $ENVIRONMENT $BACKUP_VERSION

# Restart frontend
dfx canister --network $ENVIRONMENT start frontend

echo "✅ Rollback completed"
```

## Validation Procedures

### Post-Upgrade Health Checks

```bash
#!/bin/bash
# Post-upgrade validation script

ENVIRONMENT=$1
CANISTERS=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")

echo "🔍 Running post-upgrade validation..."

for canister in "${CANISTERS[@]}"; do
    echo "Checking $canister health..."
    
    # Health check
    if ! dfx canister --network $ENVIRONMENT call $canister health_check; then
        echo "❌ Health check failed for $canister"
        exit 1
    fi
    
    # Data consistency check
    if ! dfx canister --network $ENVIRONMENT call $canister validate_state; then
        echo "❌ State validation failed for $canister"
        exit 1
    fi
done

# Inter-canister communication test
echo "Testing inter-canister communication..."
if ! dfx canister --network $ENVIRONMENT call strategy_selector test_portfolio_connection; then
    echo "❌ Inter-canister communication failed"
    exit 1
fi

echo "✅ All validation checks passed"
```

### Data Integrity Validation

```motoko
// Data consistency validation function
public func validate_state() : async Bool {
    // Check user count consistency
    let user_count = users.size();
    let portfolio_count = portfolios.size();
    
    if (user_count != portfolio_count) {
        return false;
    };
    
    // Validate transaction history integrity
    for ((user_id, transactions) in transaction_history.entries()) {
        if (not users.get(user_id)) {
            return false; // Orphaned transactions
        };
    };
    
    // Validate UTXO consistency
    var total_utxo_value : Nat64 = 0;
    for ((utxo_id, utxo) in utxos.entries()) {
        total_utxo_value += utxo.value;
    };
    
    var total_portfolio_value : Nat64 = 0;
    for ((user_id, portfolio) in portfolios.entries()) {
        total_portfolio_value += portfolio.total_balance;
    };
    
    return total_utxo_value == total_portfolio_value;
}
```

## Monitoring During Upgrades

### Key Metrics to Monitor
- Canister cycle consumption
- Memory usage patterns
- Inter-canister call latency
- Bitcoin network connectivity
- User transaction success rates

### Alert Thresholds
- Memory usage > 80% of allocation
- Cycle balance < 1T cycles
- Health check response time > 10s
- Transaction failure rate > 5%

### Monitoring Dashboard
```bash
#!/bin/bash
# Upgrade monitoring script

ENVIRONMENT=$1

while true; do
    echo "=== Upgrade Monitoring Dashboard ==="
    echo "Timestamp: $(date)"
    
    for canister in portfolio_state user_registry strategy_selector execution_agent risk_guard; do
        # Get canister status
        STATUS=$(dfx canister --network $ENVIRONMENT status $canister 2>/dev/null || echo "ERROR")
        echo "$canister: $STATUS"
        
        # Check cycles
        CYCLES=$(dfx canister --network $ENVIRONMENT status $canister | grep -o '[0-9,]*_cycles' || echo "0_cycles")
        echo "  Cycles: $CYCLES"
        
        # Health check
        if dfx canister --network $ENVIRONMENT call $canister health_check &>/dev/null; then
            echo "  Health: ✅ OK"
        else
            echo "  Health: ❌ FAILED"
        fi
    done
    
    echo "=========================="
    sleep 30
done
```

## Emergency Procedures

### Critical Failure Response
1. **Immediate Actions**
   - Stop all user-facing operations
   - Isolate affected canisters
   - Activate incident response team

2. **Assessment Phase**
   - Identify root cause
   - Assess data integrity
   - Determine rollback necessity

3. **Recovery Actions**
   - Execute rollback if required
   - Restore from backups
   - Validate system functionality

4. **Post-Incident**
   - Document lessons learned
   - Update procedures
   - Implement preventive measures

### Contact Information
- **Primary On-Call**: [Emergency Contact]
- **Backup On-Call**: [Secondary Contact]
- **Incident Channel**: #bitsight-incidents
- **Escalation Path**: [Management Contact]

## Best Practices

### Before Upgrade
- Test migration scripts thoroughly
- Backup all critical state data
- Coordinate with team members
- Schedule during low-usage periods

### During Upgrade
- Monitor system health continuously
- Validate each step before proceeding
- Keep rollback procedures ready
- Communicate status to stakeholders

### After Upgrade
- Run comprehensive validation tests
- Monitor system performance
- Document any issues encountered
- Update procedures based on experience

## Automation Scripts

### Automated Upgrade Script
```bash
#!/bin/bash
# Automated upgrade with safety checks

ENVIRONMENT=$1
NEW_VERSION=$2

# Pre-upgrade backup
./backup-state.sh $ENVIRONMENT

# Run upgrade
./deployment/deploy.sh --upgrade $ENVIRONMENT

# Validate upgrade
if ./validate-upgrade.sh $ENVIRONMENT; then
    echo "✅ Upgrade successful"
    ./cleanup-backups.sh $ENVIRONMENT
else
    echo "❌ Upgrade failed, initiating rollback"
    ./rollback.sh $ENVIRONMENT
    exit 1
fi
```

This comprehensive upgrade procedure ensures safe, reliable upgrades while maintaining system integrity and user data consistency.