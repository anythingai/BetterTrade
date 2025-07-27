#!/bin/bash

# BetterTrade Testnet Deployment Script

echo "🚀 Deploying BetterTrade to ICP testnet..."

# Check if dfx is installed
if ! command -v dfx &> /dev/null; then
    echo "❌ dfx is not installed. Please install dfx first:"
    echo "   sh -ci \"\$(curl -fsSL https://sdk.dfinity.org/install.sh)\""
    exit 1
fi

# Check if user has cycles
echo "💰 Checking cycles balance..."
dfx wallet --network testnet balance

# Build frontend
echo "🏗️  Building frontend..."
cd frontend
npm install
npm run build
cd ..

# Deploy canisters to testnet in dependency order
echo "📡 Deploying to testnet..."

echo "   Deploying portfolio_state canister..."
dfx deploy --network testnet portfolio_state

echo "   Deploying user_registry canister..."
dfx deploy --network testnet user_registry

echo "   Deploying strategy_selector canister..."
dfx deploy --network testnet strategy_selector

echo "   Deploying execution_agent canister..."
dfx deploy --network testnet execution_agent

echo "   Deploying risk_guard canister..."
dfx deploy --network testnet risk_guard

echo "   Deploying frontend canister..."
dfx deploy --network testnet frontend

# Generate candid interfaces
echo "📋 Generating Candid interfaces..."
dfx generate --network testnet

echo "✅ Testnet deployment complete!"
echo ""
echo "🌐 Frontend URL: https://$(dfx canister --network testnet id frontend).ic0.app"
echo ""
echo "📊 Testnet Canister IDs:"
echo "   User Registry: $(dfx canister --network testnet id user_registry)"
echo "   Portfolio State: $(dfx canister --network testnet id portfolio_state)"
echo "   Strategy Selector: $(dfx canister --network testnet id strategy_selector)"
echo "   Execution Agent: $(dfx canister --network testnet id execution_agent)"
echo "   Risk Guard: $(dfx canister --network testnet id risk_guard)"
echo "   Frontend: $(dfx canister --network testnet id frontend)"