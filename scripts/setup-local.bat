@echo off
REM BetterTrade Local Development Setup Script for Windows

echo 🚀 Setting up BetterTrade local development environment...

REM Check if dfx is installed
where dfx >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ dfx is not installed. Please install dfx first
    exit /b 1
)

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed. Please install Node.js first
    exit /b 1
)

REM Start local replica
echo 📡 Starting local ICP replica...
start /b dfx start --clean
timeout /t 10 /nobreak >nul

REM Deploy canisters
echo 🏗️  Deploying canisters...

echo    Deploying portfolio_state canister...
dfx deploy portfolio_state

echo    Deploying user_registry canister...
dfx deploy user_registry

echo    Deploying strategy_selector canister...
dfx deploy strategy_selector

echo    Deploying execution_agent canister...
dfx deploy execution_agent

echo    Deploying risk_guard canister...
dfx deploy risk_guard

REM Build and deploy frontend
echo    Building frontend...
cd frontend
npm install
npm run build
cd ..

echo    Deploying frontend canister...
dfx deploy frontend

REM Generate candid interfaces
echo 📋 Generating Candid interfaces...
dfx generate

echo ✅ Local development environment setup complete!
echo.

REM Get canister IDs
for /f "tokens=*" %%i in ('dfx canister id frontend') do set FRONTEND_ID=%%i
for /f "tokens=*" %%i in ('dfx canister id __Candid_UI') do set CANDID_ID=%%i

echo 🌐 Frontend URL: http://localhost:4943/?canisterId=%FRONTEND_ID%
echo 🔧 Candid UI: http://localhost:4943/?canisterId=%CANDID_ID%
echo.
echo 📊 Canister IDs:

for /f "tokens=*" %%i in ('dfx canister id user_registry') do echo    User Registry: %%i
for /f "tokens=*" %%i in ('dfx canister id portfolio_state') do echo    Portfolio State: %%i
for /f "tokens=*" %%i in ('dfx canister id strategy_selector') do echo    Strategy Selector: %%i
for /f "tokens=*" %%i in ('dfx canister id execution_agent') do echo    Execution Agent: %%i
for /f "tokens=*" %%i in ('dfx canister id risk_guard') do echo    Risk Guard: %%i
for /f "tokens=*" %%i in ('dfx canister id frontend') do echo    Frontend: %%i