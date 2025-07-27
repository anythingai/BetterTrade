# BetterTrade API Documentation

## Overview

BetterTrade is a multi-agent Bitcoin DeFi copilot system built on the Internet Computer Protocol (ICP). The system consists of five specialized canisters that work together to provide automated yield strategies for Bitcoin holders.

### System Architecture

```
┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐
│   User Registry │    │ Portfolio State │    │Strategy Selector│
│                 │    │                 │    │                 │
│ • User mgmt     │    │ • Balance track │    │ • Strategy rec  │
│ • Wallet link   │    │ • Transaction   │    │ • Plan approval │
│ • Risk profile  │    │ • UTXO mgmt     │    │ • Scoring algo  │
└─────────────────┘    └─────────────────┘    └─────────────────┘
         │                       │                       │
         └───────────────────────┼───────────────────────┘
                                 │
         ┌─────────────────┐    ┌─────────────────┐
         │ Execution Agent │    │   Risk Guard    │
         │                 │    │                 │
         │ • TX building   │    │ • Risk monitor  │
         │ • t-ECDSA sign  │    │ • Protection    │
         │ • Broadcasting  │    │ • Alerts        │
         └─────────────────┘    └─────────────────┘
```

### Base URL
- **Local Development**: `http://127.0.0.1:4943`
- **IC Mainnet**: `https://ic0.app`
- **IC Testnet**: `https://testnet.dfinity.network`

### Authentication
All API calls require Internet Identity authentication or use the caller's Principal ID for authorization.

---

## User Registry Canister

The User Registry manages user accounts, wallet connections, and risk profiles.

### Canister ID
- **Local**: `rdmx6-jaaaa-aaaah-qdrya-cai`
- **Production**: TBD

### Methods

#### `register(display_name: Text, email_opt: ?Text) -> Result<UserId, ApiError>`

Register a new user account.

**Parameters:**
- `display_name`: User's display name (1-50 characters)
- `email_opt`: Optional email address

**Returns:**
- `UserId`: Principal ID of the registered user
- `ApiError`: Error if registration fails

**Example:**
```javascript
// Candid
dfx canister call user_registry register '("Alice Smith", null)'

// Response
(variant { ok = principal "rdmx6-jaaaa-aaaah-qdrya-cai" })
```

**Errors:**
- `invalid_input`: Display name invalid or user already exists
- `internal_error`: System error during registration

---

#### `link_wallet(addr: Text, network: Network) -> Result<WalletId, ApiError>`

Link a Bitcoin wallet address to the user's account.

**Parameters:**
- `addr`: Bitcoin address (testnet or mainnet format)
- `network`: `#testnet` or `#mainnet`

**Returns:**
- `WalletId`: Unique wallet identifier
- `ApiError`: Error if linking fails

**Example:**
```javascript
// Candid
dfx canister call user_registry link_wallet '("tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx", variant { testnet })'

// Response
(variant { ok = "user123:tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx" })
```

**Validation:**
- Testnet addresses: Must start with `tb1`, `2`, `m`, or `n`
- Mainnet addresses: Must start with `bc1`, `3`, or `1`
- Address length: 26-62 characters

---

#### `set_risk_profile(uid: UserId, profile: RiskLevel) -> Result<Bool, ApiError>`

Set user's risk tolerance level.

**Parameters:**
- `uid`: User's Principal ID
- `profile`: `#conservative`, `#balanced`, or `#aggressive`

**Returns:**
- `Bool`: Success status
- `ApiError`: Error if update fails

**Example:**
```javascript
// Candid
dfx canister call user_registry set_risk_profile '(principal "rdmx6-jaaaa-aaaah-qdrya-cai", variant { conservative })'

// Response
(variant { ok = true })
```

**Authorization:**
- Only the user themselves can update their risk profile

---

#### `get_user(uid: UserId) -> Result<UserSummary, ApiError>` (Query)

Retrieve user information and summary.

**Parameters:**
- `uid`: User's Principal ID

**Returns:**
- `UserSummary`: User details and portfolio summary
- `ApiError`: Error if user not found

**Example:**
```javascript
// Candid
dfx canister call user_registry get_user '(principal "rdmx6-jaaaa-aaaah-qdrya-cai")'

// Response
(variant { 
  ok = record {
    user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
    display_name = "Alice Smith";
    risk_profile = variant { conservative };
    wallet_count = 1;
    portfolio_value_sats = 50000000;
  }
})
```

---

#### `get_user_wallets(uid: UserId) -> Result<[Wallet], ApiError>` (Query)

Get all wallets linked to a user account.

**Parameters:**
- `uid`: User's Principal ID

**Returns:**
- `[Wallet]`: Array of linked wallets
- `ApiError`: Error if user not found

**Example:**
```javascript
// Response
(variant { 
  ok = vec {
    record {
      user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
      btc_address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
      network = variant { testnet };
      status = variant { active };
    }
  }
})
```

---

## Portfolio State Canister

The Portfolio State canister tracks user balances, transactions, UTXOs, and positions.

### Canister ID
- **Local**: `rrkah-fqaaa-aaaah-qdrya-cai`
- **Production**: TBD

### Methods

#### `get_portfolio(uid: UserId) -> Result<PortfolioSummary, ApiError>` (Query)

Get comprehensive portfolio information for a user.

**Parameters:**
- `uid`: User's Principal ID

**Returns:**
- `PortfolioSummary`: Complete portfolio overview
- `ApiError`: Error if user not found

**Example:**
```javascript
// Candid
dfx canister call portfolio_state get_portfolio '(principal "rdmx6-jaaaa-aaaah-qdrya-cai")'

// Response
(variant { 
  ok = record {
    user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
    total_balance_sats = 50000000;
    available_balance_sats = 10000000;
    allocated_balance_sats = 40000000;
    total_pnl_sats = 1000000;
    active_strategies = 1;
    position_count = 3;
  }
})
```

---

#### `get_utxos(uid: UserId) -> Result<UTXOSet, ApiError>` (Query)

Retrieve user's unspent transaction outputs (UTXOs).

**Parameters:**
- `uid`: User's Principal ID

**Returns:**
- `UTXOSet`: Collection of UTXOs with metadata
- `ApiError`: Error if user not found

**Example:**
```javascript
// Response
(variant { 
  ok = record {
    user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
    utxos = vec {
      record {
        txid = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456";
        vout = 0;
        amount_sats = 25000000;
        address = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx";
        confirmations = 6;
        block_height = opt 800000;
        spent = false;
        spent_in_tx = null;
      }
    };
    total_balance = 50000000;
    confirmed_balance = 50000000;
    last_updated = 1640995200000000000;
  }
})
```

---

#### `get_transaction_history(uid: UserId) -> Result<[TxRecord], ApiError>` (Query)

Get user's transaction history.

**Parameters:**
- `uid`: User's Principal ID

**Returns:**
- `[TxRecord]`: Array of transaction records
- `ApiError`: Error if user not found

**Example:**
```javascript
// Response
(variant { 
  ok = vec {
    record {
      txid = "a1b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef123456";
      user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
      tx_type = variant { deposit };
      amount_sats = 50000000;
      fee_sats = 1000;
      status = variant { confirmed };
      confirmed_height = opt 800000;
      timestamp = 1640995200000000000;
    }
  }
})
```

---

#### `record_transaction(uid: UserId, tx: TxRecord) -> Result<TxId, ApiError>`

Record a new transaction in the user's history.

**Parameters:**
- `uid`: User's Principal ID
- `tx`: Transaction record to store

**Returns:**
- `TxId`: Transaction identifier
- `ApiError`: Error if recording fails

**Authorization:**
- Only system canisters can record transactions

---

## Strategy Selector Canister

The Strategy Selector provides strategy recommendations and plan management.

### Canister ID
- **Local**: `ryjl3-tyaaa-aaaah-qdrya-cai`
- **Production**: TBD

### Methods

#### `list_strategies() -> Result<[StrategyTemplate], ApiError>` (Query)

Get all available strategy templates.

**Returns:**
- `[StrategyTemplate]`: Array of strategy templates
- `ApiError`: System error

**Example:**
```javascript
// Candid
dfx canister call strategy_selector list_strategies

// Response
(variant { 
  ok = vec {
    record {
      id = "conservative-lending";
      name = "Conservative Bitcoin Lending";
      risk_level = variant { conservative };
      venues = vec { "BlockFi"; "Celsius"; "Nexo" };
      est_apy_band = record { 4.5; 6.2 };
      params_schema = "{\"min_amount\": 0.01, \"max_allocation\": 0.8}";
    }
  }
})
```

---

#### `recommend(uid: UserId, risk: RiskLevel) -> Result<StrategyPlan, ApiError>`

Get personalized strategy recommendation for a user.

**Parameters:**
- `uid`: User's Principal ID
- `risk`: User's risk tolerance level

**Returns:**
- `StrategyPlan`: Recommended strategy with allocations
- `ApiError`: Error if recommendation fails

**Example:**
```javascript
// Candid
dfx canister call strategy_selector recommend '(principal "rdmx6-jaaaa-aaaah-qdrya-cai", variant { conservative })'

// Response
(variant { 
  ok = record {
    id = "plan_conservative-lending_rdmx6-jaaaa-aaaah-qdrya-cai_1640995200";
    user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
    template_id = "conservative-lending";
    allocations = vec {
      record {
        venue_id = "BlockFi";
        amount_sats = 13333333;
        percentage = 33.33;
      };
      record {
        venue_id = "Celsius";
        amount_sats = 13333333;
        percentage = 33.33;
      };
      record {
        venue_id = "Nexo";
        amount_sats = 13333334;
        percentage = 33.34;
      };
    };
    created_at = 1640995200000000000;
    status = variant { pending };
    rationale = "Recommended for your conservative risk profile. Expected APY: 4.5% - 6.2%. Available on 3 venues: BlockFi, Celsius, Nexo. Overall score: 82/100. Perfect match for conservative investors seeking capital preservation.";
  }
})
```

**Scoring Algorithm:**
The recommendation engine uses a weighted scoring system:
- **APY Weight**: 40% - Higher expected returns score better
- **Risk Weight**: 35% - Alignment with user's risk profile
- **Liquidity Weight**: 25% - Venue diversity and liquidity

---

#### `accept_plan(uid: UserId, plan_id: PlanId) -> Result<Bool, ApiError>`

Approve a strategy plan for execution.

**Parameters:**
- `uid`: User's Principal ID
- `plan_id`: Strategy plan identifier

**Returns:**
- `Bool`: Success status
- `ApiError`: Error if approval fails

**Example:**
```javascript
// Candid
dfx canister call strategy_selector accept_plan '(principal "rdmx6-jaaaa-aaaah-qdrya-cai", "plan_conservative-lending_rdmx6-jaaaa-aaaah-qdrya-cai_1640995200")'

// Response
(variant { ok = true })
```

**Plan Locking:**
- Users can only have one approved plan at a time
- Existing approved plans must be cancelled before approving new ones

---

#### `get_plan(plan_id: PlanId) -> Result<StrategyPlan, ApiError>` (Query)

Retrieve a specific strategy plan.

**Parameters:**
- `plan_id`: Strategy plan identifier

**Returns:**
- `StrategyPlan`: Plan details and status
- `ApiError`: Error if plan not found

---

## Execution Agent Canister

The Execution Agent handles Bitcoin transaction construction, signing, and broadcasting.

### Canister ID
- **Local**: `renrk-eyaaa-aaaah-qdrya-cai`
- **Production**: TBD

### Methods

#### `execute_plan(plan_id: PlanId) -> Result<[TxId], ApiError>`

Execute an approved strategy plan by creating and broadcasting Bitcoin transactions.

**Parameters:**
- `plan_id`: Approved strategy plan identifier

**Returns:**
- `[TxId]`: Array of transaction IDs created
- `ApiError`: Error if execution fails

**Example:**
```javascript
// Candid
dfx canister call execution_agent execute_plan '("plan_conservative-lending_rdmx6-jaaaa-aaaah-qdrya-cai_1640995200")'

// Response
(variant { 
  ok = vec { 
    "b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567" 
  }
})
```

**Process:**
1. Retrieve strategy plan from Strategy Selector
2. Get user's UTXOs from Portfolio State
3. Construct Bitcoin transaction with proper allocations
4. Sign transaction using threshold ECDSA
5. Broadcast to Bitcoin network
6. Update portfolio state with new transaction

---

#### `get_tx_status(txid: TxId) -> Result<TxStatus, ApiError>` (Query)

Check the confirmation status of a transaction.

**Parameters:**
- `txid`: Bitcoin transaction ID

**Returns:**
- `TxStatus`: Current transaction status
- `ApiError`: Error if transaction not found

**Example:**
```javascript
// Candid
dfx canister call execution_agent get_tx_status '("b2c3d4e5f6789012345678901234567890abcdef1234567890abcdef1234567")'

// Response
(variant { ok = variant { confirmed } })
```

**Status Types:**
- `#pending`: Transaction broadcast but not confirmed
- `#confirmed`: Transaction confirmed on Bitcoin network
- `#failed`: Transaction failed or rejected

---

#### `get_user_bitcoin_address(user_id: UserId, network: Network) -> Result<Text, ApiError>`

Generate a Bitcoin address for the user using threshold ECDSA.

**Parameters:**
- `user_id`: User's Principal ID
- `network`: Target Bitcoin network

**Returns:**
- `Text`: Generated Bitcoin address
- `ApiError`: Error if generation fails

**Example:**
```javascript
// Candid
dfx canister call execution_agent get_user_bitcoin_address '(principal "rdmx6-jaaaa-aaaah-qdrya-cai", variant { testnet })'

// Response
(variant { ok = "tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx" })
```

**Security:**
- Uses ICP's threshold ECDSA for secure key generation
- No private keys stored locally
- Deterministic address generation per user

---

## Risk Guard Canister

The Risk Guard monitors portfolios and triggers protective actions.

### Canister ID
- **Local**: `rno2w-sqaaa-aaaah-qdrya-cai`
- **Production**: TBD

### Methods

#### `set_guard(uid: UserId, cfg: RiskGuardConfig) -> Result<Bool, ApiError>`

Configure risk protection parameters for a user.

**Parameters:**
- `uid`: User's Principal ID
- `cfg`: Risk guard configuration

**Returns:**
- `Bool`: Success status
- `ApiError`: Error if configuration fails

**Example:**
```javascript
// Candid
dfx canister call risk_guard set_guard '(
  principal "rdmx6-jaaaa-aaaah-qdrya-cai",
  record {
    user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
    max_drawdown_pct = 5.0;
    liquidity_exit_threshold = 5000000;
    notify_only = false;
  }
)'

// Response
(variant { ok = true })
```

**Configuration Parameters:**
- `max_drawdown_pct`: Maximum portfolio loss percentage (1-50%)
- `liquidity_exit_threshold`: Minimum balance in satoshis for liquidity
- `notify_only`: If true, only send alerts without taking action

---

#### `evaluate_portfolio(uid: UserId) -> Result<[ProtectiveIntent], ApiError>`

Evaluate user's portfolio for risk threshold breaches.

**Parameters:**
- `uid`: User's Principal ID

**Returns:**
- `[ProtectiveIntent]`: Array of recommended protective actions
- `ApiError`: Error if evaluation fails

**Example:**
```javascript
// Candid
dfx canister call risk_guard evaluate_portfolio '(principal "rdmx6-jaaaa-aaaah-qdrya-cai")'

// Response
(variant { 
  ok = vec {
    record {
      user_id = principal "rdmx6-jaaaa-aaaah-qdrya-cai";
      action = variant { pause };
      reason = "Portfolio down 5.2% from peak. Maximum drawdown threshold (5%) breached.";
      triggered_at = 1640995200000000000;
    }
  }
})
```

**Protective Actions:**
- `#pause`: Stop new strategy allocations
- `#unwind`: Exit current positions gradually
- `#reduce_exposure`: Reduce position sizes by 50%

---

#### `get_guard(uid: UserId) -> Result<?RiskGuardConfig, ApiError>` (Query)

Retrieve user's current risk guard configuration.

**Parameters:**
- `uid`: User's Principal ID

**Returns:**
- `?RiskGuardConfig`: Current configuration or null if not set
- `ApiError`: Error if user not found

---

## Data Types Reference

### Core Types

#### `UserId`
```motoko
public type UserId = Principal;
```
User identifier using Internet Computer Principal.

#### `RiskLevel`
```motoko
public type RiskLevel = {
    #conservative;  // Low risk, stable returns
    #balanced;      // Moderate risk, balanced returns
    #aggressive;    // High risk, high potential returns
};
```

#### `Network`
```motoko
public type Network = {
    #mainnet;   // Bitcoin mainnet
    #testnet;   // Bitcoin testnet
};
```

#### `ApiError`
```motoko
public type ApiError = {
    #not_found;                    // Resource not found
    #unauthorized;                 // Access denied
    #invalid_input: Text;          // Invalid parameters
    #internal_error: Text;         // System error
};
```

### Strategy Types

#### `StrategyTemplate`
```motoko
public type StrategyTemplate = {
    id: Text;                      // Unique strategy identifier
    name: Text;                    // Human-readable name
    risk_level: RiskLevel;         // Target risk level
    venues: [Text];                // Available execution venues
    est_apy_band: (Float, Float);  // Expected APY range
    params_schema: Text;           // JSON schema for parameters
};
```

#### `StrategyPlan`
```motoko
public type StrategyPlan = {
    id: PlanId;                    // Unique plan identifier
    user_id: UserId;               // Plan owner
    template_id: Text;             // Strategy template used
    allocations: [Allocation];     // Venue allocations
    created_at: Time.Time;         // Creation timestamp
    status: PlanStatus;            // Current status
    rationale: Text;               // Recommendation explanation
};
```

#### `Allocation`
```motoko
public type Allocation = {
    venue_id: Text;                // Target venue identifier
    amount_sats: Nat64;            // Amount in satoshis
    percentage: Float;             // Percentage of total allocation
};
```

### Portfolio Types

#### `PortfolioSummary`
```motoko
public type PortfolioSummary = {
    user_id: UserId;               // Portfolio owner
    total_balance_sats: Nat64;     // Total balance in satoshis
    available_balance_sats: Nat64; // Available for new strategies
    allocated_balance_sats: Nat64; // Currently allocated amount
    total_pnl_sats: Nat64;         // Total profit/loss
    active_strategies: Nat;        // Number of active strategies
    position_count: Nat;           // Number of positions
};
```

#### `Position`
```motoko
public type Position = {
    user_id: UserId;               // Position owner
    venue_id: Text;                // Venue identifier
    amount_sats: Nat64;            // Position size in satoshis
    entry_price: Float;            // Entry price in USD
    current_value: Float;          // Current value in USD
    pnl: Float;                    // Profit/loss in USD
};
```

#### `UTXO`
```motoko
public type UTXO = {
    txid: Text;                    // Transaction ID
    vout: Nat32;                   // Output index
    amount_sats: Nat64;            // Amount in satoshis
    address: Text;                 // Bitcoin address
    confirmations: Nat32;          // Number of confirmations
    block_height: ?Nat32;          // Block height if confirmed
    spent: Bool;                   // Whether UTXO is spent
    spent_in_tx: ?Text;            // Transaction that spent this UTXO
};
```

### Transaction Types

#### `TxRecord`
```motoko
public type TxRecord = {
    txid: Text;                    // Bitcoin transaction ID
    user_id: UserId;               // Transaction owner
    tx_type: TxType;               // Transaction type
    amount_sats: Nat64;            // Amount in satoshis
    fee_sats: Nat64;               // Transaction fee
    status: TxStatus;              // Current status
    confirmed_height: ?Nat32;      // Confirmation block height
    timestamp: Time.Time;          // Transaction timestamp
};
```

#### `TxType`
```motoko
public type TxType = {
    #deposit;          // Incoming Bitcoin deposit
    #withdraw;         // Outgoing Bitcoin withdrawal
    #strategy_execute; // Strategy execution transaction
    #rebalance;        // Portfolio rebalancing
};
```

#### `TxStatus`
```motoko
public type TxStatus = {
    #pending;          // Transaction pending confirmation
    #confirmed;        // Transaction confirmed
    #failed;           // Transaction failed
};
```

---

## Error Handling

### Common Error Patterns

#### Authentication Errors
```javascript
// Unauthorized access
{
  "err": {
    "unauthorized": null
  }
}
```

#### Validation Errors
```javascript
// Invalid input parameters
{
  "err": {
    "invalid_input": "Display name must be between 1 and 50 characters"
  }
}
```

#### System Errors
```javascript
// Internal system error
{
  "err": {
    "internal_error": "Failed to connect to Bitcoin network"
  }
}
```

### Error Recovery

1. **Retry Logic**: Implement exponential backoff for transient errors
2. **Fallback Strategies**: Use cached data when real-time data unavailable
3. **User Feedback**: Provide clear error messages and suggested actions
4. **Monitoring**: Log errors for system health monitoring

---

## Rate Limits and Quotas

### Query Limits
- **User queries**: 100 requests/minute per user
- **System queries**: 1000 requests/minute per canister
- **Heavy operations**: 10 requests/minute (portfolio calculations)

### Transaction Limits
- **Strategy executions**: 5 per day per user
- **Plan approvals**: 10 per day per user
- **Risk guard updates**: 20 per day per user

### Storage Limits
- **Transaction history**: 1000 records per user
- **UTXO tracking**: 100 UTXOs per user
- **Audit entries**: 10,000 entries per canister

---

## SDK Examples

### JavaScript/TypeScript

```typescript
import { Actor, HttpAgent } from '@dfinity/agent';
import { idlFactory } from './declarations/user_registry';

// Initialize agent
const agent = new HttpAgent({ host: 'http://127.0.0.1:4943' });
const userRegistry = Actor.createActor(idlFactory, {
  agent,
  canisterId: 'rdmx6-jaaaa-aaaah-qdrya-cai',
});

// Register user
async function registerUser(displayName: string) {
  try {
    const result = await userRegistry.register(displayName, []);
    if ('ok' in result) {
      console.log('User registered:', result.ok);
      return result.ok;
    } else {
      console.error('Registration failed:', result.err);
      throw new Error(result.err);
    }
  } catch (error) {
    console.error('Network error:', error);
    throw error;
  }
}

// Get portfolio
async function getPortfolio(userId: Principal) {
  try {
    const result = await portfolioState.get_portfolio(userId);
    if ('ok' in result) {
      return result.ok;
    } else {
      throw new Error(result.err);
    }
  } catch (error) {
    console.error('Failed to get portfolio:', error);
    throw error;
  }
}
```

### Python

```python
from ic.client import Client
from ic.identity import Identity
from ic.agent import Agent

# Initialize client
identity = Identity()
client = Client(url="http://127.0.0.1:4943")
agent = Agent(identity, client)

# User Registry canister
user_registry = agent.get_canister("rdmx6-jaaaa-aaaah-qdrya-cai")

# Register user
def register_user(display_name: str):
    try:
        result = user_registry.call("register", display_name, None)
        if "ok" in result:
            print(f"User registered: {result['ok']}")
            return result["ok"]
        else:
            raise Exception(result["err"])
    except Exception as e:
        print(f"Registration failed: {e}")
        raise

# Get strategy recommendations
def get_recommendations(user_id, risk_level):
    strategy_selector = agent.get_canister("ryjl3-tyaaa-aaaah-qdrya-cai")
    result = strategy_selector.call("recommend", user_id, {"risk_level": risk_level})
    return result
```

---

## Integration Examples

### Frontend Integration

```typescript
// React component for strategy selection
import React, { useState, useEffect } from 'react';
import { useAuth } from './auth-context';
import { strategySelector } from './canisters';

export const StrategySelector: React.FC = () => {
  const { user } = useAuth();
  const [strategies, setStrategies] = useState([]);
  const [loading, setLoading] = useState(false);

  useEffect(() => {
    loadStrategies();
  }, [user]);

  const loadStrategies = async () => {
    if (!user) return;
    
    setLoading(true);
    try {
      const result = await strategySelector.get_recommendations(
        user.principal, 
        user.riskProfile, 
        [3] // limit to 3 recommendations
      );
      
      if ('ok' in result) {
        setStrategies(result.ok);
      }
    } catch (error) {
      console.error('Failed to load strategies:', error);
    } finally {
      setLoading(false);
    }
  };

  const approveStrategy = async (planId: string) => {
    try {
      const result = await strategySelector.accept_plan(user.principal, planId);
      if ('ok' in result) {
        // Redirect to execution page
        window.location.href = `/execute/${planId}`;
      }
    } catch (error) {
      console.error('Failed to approve strategy:', error);
    }
  };

  if (loading) return <div>Loading strategies...</div>;

  return (
    <div className="strategy-selector">
      <h2>Recommended Strategies</h2>
      {strategies.map((strategy) => (
        <div key={strategy.id} className="strategy-card">
          <h3>{strategy.strategy.name}</h3>
          <p>Expected APY: {strategy.strategy.est_apy_band[0]}% - {strategy.strategy.est_apy_band[1]}%</p>
          <p>Score: {Math.round(strategy.score * 100)}/100</p>
          <p>{strategy.rationale}</p>
          <button onClick={() => approveStrategy(strategy.id)}>
            Approve Strategy
          </button>
        </div>
      ))}
    </div>
  );
};
```

### Backend Integration

```typescript
// Express.js middleware for BetterTrade integration
import express from 'express';
import { Actor, HttpAgent } from '@dfinity/agent';

const app = express();

// Middleware to initialize canister actors
app.use(async (req, res, next) => {
  const agent = new HttpAgent({ host: process.env.IC_HOST });
  
  req.canisters = {
    userRegistry: Actor.createActor(userRegistryIdl, {
      agent,
      canisterId: process.env.USER_REGISTRY_CANISTER_ID,
    }),
    portfolioState: Actor.createActor(portfolioStateIdl, {
      agent,
      canisterId: process.env.PORTFOLIO_STATE_CANISTER_ID,
    }),
    // ... other canisters
  };
  
  next();
});

// API endpoint for portfolio data
app.get('/api/portfolio/:userId', async (req, res) => {
  try {
    const { userId } = req.params;
    const principal = Principal.fromText(userId);
    
    const portfolio = await req.canisters.portfolioState.get_portfolio(principal);
    
    if ('ok' in portfolio) {
      res.json(portfolio.ok);
    } else {
      res.status(404).json({ error: portfolio.err });
    }
  } catch (error) {
    res.status(500).json({ error: 'Internal server error' });
  }
});

// Webhook endpoint for transaction confirmations
app.post('/api/webhook/transaction-confirmed', async (req, res) => {
  const { txid, confirmations, blockHeight } = req.body;
  
  try {
    // Update transaction status in portfolio state
    await req.canisters.portfolioState.update_utxo_confirmations(
      txid,
      confirmations,
      [blockHeight]
    );
    
    res.json({ success: true });
  } catch (error) {
    res.status(500).json({ error: 'Failed to update transaction' });
  }
});
```

---

## Testing and Development

### Local Development Setup

```bash
# Start local replica
dfx start --background

# Deploy canisters
dfx deploy

# Run integration tests
npm run test:integration

# Generate type declarations
dfx generate
```

### Testing with Demo Data

```bash
# Reset demo environment
./demo/reset_demo.bat

# Load test users and data
dfx canister call user_registry register '("Test User", null)'
dfx canister call portfolio_state update_balance '(principal "test-user-id", 100000000)'

# Test strategy recommendation
dfx canister call strategy_selector recommend '(principal "test-user-id", variant { balanced })'
```

### Monitoring and Debugging

```bash
# View canister logs
dfx canister logs user_registry

# Check canister status
dfx canister status --all

# Monitor inter-canister calls
dfx canister call strategy_selector get_audit_trail '(opt 10)'
```

---

## Security Considerations

### Authentication
- All methods require valid Internet Identity authentication
- Principal-based authorization for user-specific operations
- Inter-canister calls use canister signatures

### Data Protection
- No private keys stored in canisters
- Threshold ECDSA for secure Bitcoin operations
- Encrypted inter-canister communication

### Input Validation
- All user inputs validated before processing
- Bitcoin address format validation
- Amount limits and sanity checks

### Rate Limiting
- Per-user rate limits on sensitive operations
- Canister-level quotas for resource protection
- Automatic throttling for suspicious activity

---

## Support and Resources

### Documentation
- [ICP Developer Documentation](https://internetcomputer.org/docs)
- [Motoko Language Guide](https://internetcomputer.org/docs/motoko)
- [Bitcoin Integration Guide](https://internetcomputer.org/bitcoin-integration)

### Community
- [Developer Forum](https://forum.dfinity.org)
- [Discord Community](https://discord.gg/cA7y6ezyE2)
- [GitHub Repository](https://github.com/bitsight-plus-plus)

### Support Channels
- **Technical Support**: support@bitsight-plus-plus.com
- **Bug Reports**: GitHub Issues
- **Feature Requests**: Community Forum

---

*Last Updated: January 2025*
*API Version: 1.0.0*
*Compatible with: ICP SDK 0.15.0+*