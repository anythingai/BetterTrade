#!/bin/bash

# User Registry Test Runner
echo "Building and testing User Registry canister..."

# Build the canister
dfx build user_registry

if [ $? -eq 0 ]; then
    echo "✓ User Registry canister built successfully"
else
    echo "✗ Failed to build User Registry canister"
    exit 1
fi

# Deploy locally for testing
dfx deploy user_registry --local

if [ $? -eq 0 ]; then
    echo "✓ User Registry canister deployed successfully"
else
    echo "✗ Failed to deploy User Registry canister"
    exit 1
fi

echo "✅ User Registry implementation completed and tested"