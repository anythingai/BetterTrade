# BetterTrade - Bitcoin DeFi Copilot

BetterTrade is a multi-agent system built on the Internet Computer Protocol (ICP) that provides automated Bitcoin DeFi yield strategies through specialized cooperating on-chain AI agents.

## Project Structure

```
├── dfx.json                    # ICP project configuration
├── frontend/                   # React frontend application
│   ├── src/
│   │   ├── index.tsx          # Frontend entry point
│   │   ├── App.tsx            # Main React component
│   │   └── index.html         # HTML template
│   ├── package.json           # Frontend dependencies
│   ├── tsconfig.json          # TypeScript configuration
│   └── webpack.config.js      # Webpack build configuration
└── src/                       # Backend canisters
    ├── shared/                # Shared types and interfaces
    │   ├── types.mo           # Core data types
    │   ├── interfaces.mo      # Inter-canister interfaces
    │   ├── utils.mo           # Utility functions
    │   └── constants.mo       # System constants
    ├── user_registry/         # User management canister
    │   └── main.mo
    ├── portfolio_state/       # Portfolio tracking canister
    │   └── main.mo
    ├── strategy_selector/     # Strategy recommendation canister
    │   └── main.mo
    ├── execution_agent/       # Transaction execution canister
    │   └── main.mo
    └── risk_guard/           # Risk monitoring canister
        └── main.mo
```

## Architecture Overview

### Multi-Agent System

BetterTrade consists of specialized agents deployed as ICP canisters:

1. **User Registry** - Manages user accounts, wallet linking, and preferences
2. **Portfolio State** - Tracks balances, positions, and transaction history
3. **Strategy Selector** - Recommends yield strategies based on risk profiles
4. **Execution Agent** - Constructs and executes Bitcoin transactions using t-ECDSA
5. **Risk Guard** - Monitors portfolios and triggers protective actions

### Key Features

- **Trustless Bitcoin Integration** - Uses ICP's native Bitcoin API and threshold ECDSA
- **Multi-Agent Cooperation** - Agents communicate via inter-canister calls with audit trails
- **Risk Management** - Configurable risk guards with automatic protective actions
- **Transparent Decision Making** - Explainable AI with decision rationale logging
- **Extensible Architecture** - Modular design for easy addition of new agents and strategies

## Development Setup

### Prerequisites

- [DFX](https://internetcomputer.org/docs/current/developer-docs/setup/install/) (Internet Computer SDK)
- [Node.js](https://nodejs.org/) (v16 or later)
- [npm](https://www.npmjs.com/) or [yarn](https://yarnpkg.com/)

### Quick Start

1. **Build the entire project:**

   ```bash
   # Linux/Mac
   ./build.sh
   
   # Windows
   build.bat
   ```

2. **Set up local development environment:**

   ```bash
   # Linux/Mac
   ./scripts/setup-local.sh
   
   # Windows
   scripts\setup-local.bat
   ```

3. **Access the application:**
   - Frontend: `http://localhost:4943/?canisterId=<frontend-canister-id>`
   - Candid UI: `http://localhost:4943/?canisterId=<candid-ui-canister-id>`

### Manual Development Steps

1. Start the local ICP replica:

   ```bash
   dfx start --background
   ```

2. Deploy the canisters:

   ```bash
   dfx deploy
   ```

3. Install frontend dependencies:

   ```bash
   cd frontend
   npm install
   ```

4. Build and serve frontend:

   ```bash
   npm run build
   ```

### Testnet Deployment

Deploy to ICP testnet:

```bash
# Linux/Mac
./scripts/deploy-testnet.sh

# Windows
scripts\deploy-testnet.bat
```

### Testing

Run canister validation:

```bash
dfx build
```

Run frontend tests:

```bash
cd frontend
npm test
```

## Core Data Types

### User Management

- `User` - User profile with risk preferences
- `Wallet` - Bitcoin wallet associations
- `UserSummary` - User overview for queries

### Strategy System

- `StrategyTemplate` - Predefined strategy configurations
- `StrategyPlan` - User-specific strategy recommendations
- `Allocation` - Strategy fund allocation details

### Portfolio Tracking

- `Position` - Individual investment positions
- `PortfolioSummary` - Complete portfolio overview
- `TxRecord` - Transaction history records

### Risk Management

- `RiskGuardConfig` - User risk protection settings
- `ProtectiveIntent` - Automated protection actions

## Inter-Canister Communication

All agents communicate through well-defined interfaces with:

- Type-safe inter-canister calls
- Audit trail logging
- Error handling and recovery
- Event-driven architecture

## Security Features

- **Threshold ECDSA** - Distributed Bitcoin transaction signing
- **Principal-based Authentication** - ICP identity system
- **Stable Memory** - Upgrade-safe data persistence
- **Input Validation** - Comprehensive data validation
- **Access Control** - Role-based permissions
