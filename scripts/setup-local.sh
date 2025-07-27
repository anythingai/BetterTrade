#!/bin/bash

# BetterTrade Local Development Setup Script

echo "🚀 Setting up BetterTrade local development environment..."

# Check if dfx is installed
if ! command -v dfx &> /dev/null; then
    echo "❌ dfx is not installed. Please install dfx first:"
    echo "   sh -ci \"\$(curl -fsSL https://sdk.dfinity.org/install.sh)\""
    exit 1
fi

# Check if Node.js is installed
if ! command -v node &> /dev/null; then
    echo "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

# Start local replica
echo "📡 Starting local ICP replica..."
dfx start --clean --background

# Wait for replica to be ready
echo "⏳ Waiting for replica to be ready..."
sleep 5

# Deploy canisters
echo "🏗️  Deploying canisters..."

# Deploy backend canisters in dependency order
echo "   Deploying portfolio_state canister..."
dfx deploy portfolio_state

echo "   Deploying user_registry canister..."
dfx deploy user_registry

echo "   Deploying strategy_selector canister..."
dfx deploy strategy_selector

echo "   Deploying execution_agent canister..."
dfx deploy execution_agent

echo "   Deploying risk_guard canister..."
dfx deploy risk_guard

# Build and deploy frontend
echo "   Building frontend..."
cd frontend
npm install
npm run build
cd ..

echo "   Deploying frontend canister..."
dfx deploy frontend

# Generate candid interfaces
echo "📋 Generating Candid interfaces..."
dfx generate

echo "✅ Local development environment setup complete!"
echo ""
echo "🌐 Frontend URL: http://localhost:4943/?canisterId=$(dfx canister id frontend)"
echo "🔧 Candid UI: http://localhost:4943/?canisterId=$(dfx canister id __Candid_UI)"
echo ""
echo "📊 Canister IDs:"
echo "   User Registry: $(dfx canister id user_registry)"
echo "   Portfolio State: $(dfx canister id portfolio_state)"
echo "   Strategy Selector: $(dfx canister id strategy_selector)"
echo "   Execution Agent: $(dfx canister id execution_agent)"
echo "   Risk Guard: $(dfx canister id risk_guard)"
echo "   Frontend: $(dfx canister id frontend)"