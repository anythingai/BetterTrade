#!/bin/bash

# Inter-Canister Communication Test Runner
# This script runs the inter-canister communication tests

echo "🚀 Starting Inter-Canister Communication Tests..."

# Check if moc (Motoko compiler) is available
if ! command -v moc &> /dev/null; then
    echo "❌ Motoko compiler (moc) not found. Please install dfx and Motoko SDK."
    exit 1
fi

# Run the main test suite
echo "📋 Running main test suite..."
moc -r inter_canister_communication_test.mo

if [ $? -eq 0 ]; then
    echo "✅ Main test suite passed!"
else
    echo "❌ Main test suite failed!"
    exit 1
fi

# Run performance tests
echo "📊 Running performance tests..."
moc -r -c "import Tests \"./inter_canister_communication_test\"; ignore Tests.run_performance_tests()"

if [ $? -eq 0 ]; then
    echo "✅ Performance tests passed!"
else
    echo "❌ Performance tests failed!"
    exit 1
fi

echo "🎉 All Inter-Canister Communication tests completed successfully!"