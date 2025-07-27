#!/bin/bash

# Deploy BetterTrade to local replica
echo "🚀 Deploying BetterTrade to local replica..."

# Start local replica if not running
echo "📡 Starting local replica..."
dfx start --background --clean

# Build frontend
echo "🏗️  Building frontend..."
cd frontend && npm install && npm run build && cd ..

# Deploy canisters in dependency order
echo "📦 Deploying canisters..."

# Deploy core data canisters first
dfx deploy portfolio_state --network local
dfx deploy user_registry --network local

# Deploy agent canisters
dfx deploy strategy_selector --network local
dfx deploy execution_agent --network local
dfx deploy risk_guard --network local

# Deploy frontend
dfx deploy frontend --network local

# Get canister IDs
echo "📋 Canister IDs:"
echo "User Registry: $(dfx canister id user_registry --network local)"
echo "Portfolio State: $(dfx canister id portfolio_state --network local)"
echo "Strategy Selector: $(dfx canister id strategy_selector --network local)"
echo "Execution Agent: $(dfx canister id execution_agent --network local)"
echo "Risk Guard: $(dfx canister id risk_guard --network local)"
echo "Frontend: $(dfx canister id frontend --network local)"

echo "✅ Deployment complete!"
echo "🌐 Frontend URL: http://localhost:4943/?canisterId=$(dfx canister id frontend --network local)"