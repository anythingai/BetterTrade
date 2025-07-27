#!/bin/bash

# BetterTrade Build Script

set -e

echo "🏗️  Building BetterTrade project..."

# Function to print colored output
print_status() {
    echo -e "\033[1;34m$1\033[0m"
}

print_success() {
    echo -e "\033[1;32m$1\033[0m"
}

print_error() {
    echo -e "\033[1;31m$1\033[0m"
}

# Check dependencies
print_status "🔍 Checking dependencies..."

if ! command -v dfx &> /dev/null; then
    print_error "❌ dfx is not installed. Please install dfx first:"
    echo "   sh -ci \"\$(curl -fsSL https://sdk.dfinity.org/install.sh)\""
    exit 1
fi

if ! command -v node &> /dev/null; then
    print_error "❌ Node.js is not installed. Please install Node.js first."
    exit 1
fi

if ! command -v npm &> /dev/null; then
    print_error "❌ npm is not installed. Please install npm first."
    exit 1
fi

print_success "✅ All dependencies found"

# Build frontend
print_status "📦 Building frontend..."
cd frontend

if [ ! -d "node_modules" ]; then
    print_status "   Installing frontend dependencies..."
    npm install
fi

print_status "   Compiling TypeScript and bundling..."
npm run build

cd ..
print_success "✅ Frontend build complete"

# Validate Motoko code
print_status "🔍 Validating Motoko code..."

# Check if dfx.json is valid
if ! dfx ping local &> /dev/null; then
    print_status "   Starting local replica for validation..."
    dfx start --clean --background
    sleep 3
fi

# Validate each canister
canisters=("portfolio_state" "user_registry" "strategy_selector" "execution_agent" "risk_guard")

for canister in "${canisters[@]}"; do
    print_status "   Validating $canister..."
    if ! dfx build $canister &> /dev/null; then
        print_error "❌ Failed to build $canister"
        exit 1
    fi
done

print_success "✅ All Motoko code validated"

# Generate Candid interfaces
print_status "📋 Generating Candid interfaces..."
dfx generate

print_success "✅ Candid interfaces generated"

# Create deployment summary
print_status "📊 Build Summary:"
echo "   ✅ Frontend built and ready"
echo "   ✅ All canisters validated"
echo "   ✅ Candid interfaces generated"
echo "   ✅ Project ready for deployment"

print_success "🎉 Build completed successfully!"
echo ""
echo "Next steps:"
echo "   • For local development: ./scripts/setup-local.sh"
echo "   • For testnet deployment: ./scripts/deploy-testnet.sh"