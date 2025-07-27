# Strategy Plan Approval System Implementation

## Overview

This document describes the implementation of the strategy plan approval system for BetterTrade, which provides a secure workflow for users to approve and execute investment strategies with proper locking mechanisms and audit trails.

## Features Implemented

### 1. Strategy Plan Creation and Storage

- **Enhanced Plan Management**: Plans are stored with comprehensive metadata including creation time, status, and rationale
- **Plan Status Tracking**: Plans progress through states: `pending` → `approved` → `executed` or `failed`
- **Allocation Management**: Each plan contains detailed allocations across multiple venues with amounts and percentages

### 2. User Approval Workflow with Plan Locking

- **Single Active Plan Policy**: Users can only have one approved or executed plan at a time
- **Plan Locking**: Prevents users from approving multiple strategies simultaneously
- **Authorization Checks**: Only plan owners can approve or cancel their plans
- **Status Validation**: Plans can only be approved from pending status

### 3. Inter-Canister Communication for Plan Execution

- **Execution Agent Integration**: Strategy selector communicates with execution agent for plan execution
- **Optimistic Updates**: Plan status is updated optimistically during execution
- **Error Recovery**: Plan status is reverted if execution fails
- **Transaction Tracking**: Execution results include transaction IDs for monitoring

### 4. Comprehensive Audit Trail

- **Action Logging**: All plan operations (approval, cancellation, execution) are logged
- **Transparency**: Audit entries include timestamp, canister, action, user, and details
- **User-Specific Trails**: Users can query their own audit history
- **System-Wide Monitoring**: Administrators can view complete audit trails

## API Methods

### Core Plan Management

```motoko
// Accept a pending plan (with locking validation)
accept_plan(uid: UserId, plan_id: PlanId) : async Result<Bool, ApiError>

// Cancel an approved or pending plan
cancel_plan(uid: UserId, plan_id: PlanId) : async Result<Bool, ApiError>

// Get user's currently active (approved/executed) plan
get_user_active_plan(uid: UserId) : async Result<?StrategyPlan, ApiError>

// Validate plan integrity and executability
validate_plan(plan_id: PlanId) : async Result<ValidationResult, ApiError>
```

### Inter-Canister Communication

```motoko
// Execute an approved plan via execution agent
execute_approved_plan(plan_id: PlanId, execution_agent: ExecutionAgentInterface) : async Result<[TxId], ApiError>
```

### Audit and Transparency

```motoko
// Get system-wide audit trail
get_audit_trail(limit: ?Nat) : async Result<[AuditEntry], ApiError>

// Get user-specific audit trail
get_user_audit_trail(uid: UserId, limit: ?Nat) : async Result<[AuditEntry], ApiError>
```

## Implementation Details

### Plan Locking Mechanism

The system enforces that users can only have one active strategy at a time:

```motoko
// Check for existing approved/executed plans
let existing_approved_plans = plans.vals() 
    |> Iter.filter(_, func(p: StrategyPlan) : Bool { 
        p.user_id == uid and (p.status == #approved or p.status == #executed)
    })
    |> Iter.toArray(_);

if (existing_approved_plans.size() > 0) {
    return #err(#invalid_input("User already has an active strategy plan"));
};
```

### Audit Trail Implementation

All significant actions are logged with comprehensive context:

```motoko
private func log_audit_event(action: Text, user_id: ?UserId, transaction_id: ?TxId, details: Text) : async () {
    let entry : AuditEntry = {
        timestamp = Time.now();
        canister = "strategy_selector";
        action = action;
        user_id = user_id;
        transaction_id = transaction_id;
        details = details;
    };
    
    let key = Int.toText(entry.timestamp) # "_" # action;
    audit_entries.put(key, entry);
};
```

### Error Recovery in Execution

The system handles execution failures gracefully:

```motoko
try {
    let execution_result = await execution_agent.execute_plan(plan_id);
    // Handle success...
} catch (e) {
    // Revert plan status on inter-canister call failure
    let reverted_plan = { /* ... */ status = #approved; /* ... */ };
    plans.put(plan_id, reverted_plan);
    
    await log_audit_event("strategy_plan_execution_error", ?plan.user_id, null, 
        "Plan execution error: inter-canister call failed");
    #err(#internal_error("Failed to communicate with execution agent"))
}
```

## Security Features

### Authorization

- **User Ownership**: All plan operations verify that the caller owns the plan
- **Status Validation**: Operations are only allowed on plans in appropriate states
- **Principal-Based Access**: Uses ICP Principal IDs for secure user identification

### Data Integrity

- **Plan Validation**: Comprehensive validation of plan structure and allocations
- **Percentage Validation**: Ensures allocations sum to approximately 100%
- **Template Verification**: Validates that referenced strategy templates exist

### Audit Compliance

- **Immutable Logs**: Audit entries are append-only and timestamped
- **Complete Traceability**: Every plan state change is logged with context
- **User Privacy**: Users can only access their own audit trails

## Testing

### Integration Tests

The implementation includes comprehensive integration tests covering:

1. **Basic Approval Workflow**: Plan creation → approval → status verification
2. **Plan Locking**: Preventing multiple active plans per user
3. **Plan Cancellation**: Cancelling approved plans and status updates
4. **Authorization**: Preventing unauthorized access to plans
5. **Plan Validation**: Validating plan structure and executability
6. **Audit Trail**: Verifying audit entries are created correctly
7. **Active Plan Retrieval**: Getting user's current active plan

### Test Coverage

- ✅ Strategy plan approval workflow
- ✅ Plan locking mechanism
- ✅ Plan cancellation
- ✅ Unauthorized access prevention
- ✅ Plan validation
- ✅ Audit trail functionality
- ✅ Active plan retrieval

## Usage Examples

### Approving a Strategy Plan

```motoko
// User receives a recommendation
let recommendation = await strategy_selector.recommend(user_id, #balanced);
let plan = switch (recommendation) {
    case (#ok(p)) { p };
    case (#err(e)) { /* handle error */ };
};

// User approves the plan
let approval_result = await strategy_selector.accept_plan(user_id, plan.id);
switch (approval_result) {
    case (#ok(true)) { /* Plan approved successfully */ };
    case (#err(#invalid_input(msg))) { /* Handle validation error */ };
    case (#err(e)) { /* Handle other errors */ };
};
```

### Executing an Approved Plan

```motoko
// Get user's active plan
let active_plan = await strategy_selector.get_user_active_plan(user_id);
switch (active_plan) {
    case (#ok(?plan)) {
        // Execute the plan
        let execution_result = await strategy_selector.execute_approved_plan(
            plan.id, 
            execution_agent
        );
        switch (execution_result) {
            case (#ok(tx_ids)) { /* Execution successful */ };
            case (#err(e)) { /* Handle execution error */ };
        };
    };
    case (#ok(null)) { /* No active plan */ };
    case (#err(e)) { /* Handle error */ };
};
```

### Monitoring with Audit Trail

```motoko
// Get user's audit history
let audit_trail = await strategy_selector.get_user_audit_trail(user_id, ?10);
switch (audit_trail) {
    case (#ok(entries)) {
        for (entry in entries.vals()) {
            Debug.print("Action: " # entry.action # " at " # Int.toText(entry.timestamp));
        };
    };
    case (#err(e)) { /* Handle error */ };
};
```

## Requirements Satisfied

This implementation satisfies the following requirements from the specification:

### Requirement 3.1: Strategy Approval

- ✅ Users can approve recommended strategies
- ✅ Approved strategies are locked and ready for execution
- ✅ Plan status tracking through approval workflow

### Requirement 7.2: Transparent Decision Making

- ✅ Complete audit trail of all plan operations
- ✅ Explainable logs showing what changed and why
- ✅ User access to decision-making processes

## Future Enhancements

1. **Plan Modification**: Allow users to modify approved plans before execution
2. **Batch Operations**: Support for approving multiple plans with dependencies
3. **Scheduled Execution**: Time-based plan execution scheduling
4. **Risk Threshold Integration**: Automatic plan cancellation based on risk limits
5. **Multi-Signature Approval**: Support for plans requiring multiple approvals

## Conclusion

The strategy plan approval system provides a robust, secure, and transparent workflow for users to approve and execute investment strategies. The implementation includes comprehensive error handling, audit trails, and security measures while maintaining the flexibility needed for future enhancements.
