@echo off
REM Inter-Canister Communication Test Runner for Windows
REM This script runs the inter-canister communication tests

echo 🚀 Starting Inter-Canister Communication Tests...

REM Check if moc (Motoko compiler) is available
where moc >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Motoko compiler (moc) not found. Please install dfx and Motoko SDK.
    exit /b 1
)

REM Run the main test suite
echo 📋 Running main test suite...
moc -r inter_canister_communication_test.mo

if %errorlevel% neq 0 (
    echo ❌ Main test suite failed!
    exit /b 1
)

echo ✅ Main test suite passed!

REM Run performance tests
echo 📊 Running performance tests...
moc -r -c "import Tests \"./inter_canister_communication_test\"; ignore Tests.run_performance_tests()"

if %errorlevel% neq 0 (
    echo ❌ Performance tests failed!
    exit /b 1
)

echo ✅ Performance tests passed!
echo 🎉 All Inter-Canister Communication tests completed successfully!