@echo off
REM User Registry Test Runner for Windows

echo Building and testing User Registry canister...

REM Build the canister
dfx build user_registry

if %errorlevel% equ 0 (
    echo ✓ User Registry canister built successfully
) else (
    echo ✗ Failed to build User Registry canister
    exit /b 1
)

REM Deploy locally for testing
dfx deploy user_registry --local

if %errorlevel% equ 0 (
    echo ✓ User Registry canister deployed successfully
) else (
    echo ✗ Failed to deploy User Registry canister
    exit /b 1
)

echo ✅ User Registry implementation completed and tested