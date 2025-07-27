@echo off
REM BetterTrade Build Script for Windows

echo 🏗️  Building BetterTrade project...

REM Check dependencies
echo 🔍 Checking dependencies...

where dfx >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ dfx is not installed. Please install dfx first
    exit /b 1
)

where node >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ Node.js is not installed. Please install Node.js first
    exit /b 1
)

where npm >nul 2>nul
if %errorlevel% neq 0 (
    echo ❌ npm is not installed. Please install npm first
    exit /b 1
)

echo ✅ All dependencies found

REM Build frontend
echo 📦 Building frontend...
cd frontend

if not exist "node_modules" (
    echo    Installing frontend dependencies...
    npm install
)

echo    Compiling TypeScript and bundling...
npm run build

cd ..
echo ✅ Frontend build complete

REM Start local replica if needed
dfx ping local >nul 2>nul
if %errorlevel% neq 0 (
    echo    Starting local replica for validation...
    start /b dfx start --clean
    timeout /t 5 /nobreak >nul
)

REM Validate each canister
echo 🔍 Validating Motoko code...
dfx build portfolio_state
dfx build user_registry
dfx build strategy_selector
dfx build execution_agent
dfx build risk_guard

echo ✅ All Motoko code validated

REM Generate Candid interfaces
echo 📋 Generating Candid interfaces...
dfx generate

echo ✅ Candid interfaces generated
echo 🎉 Build completed successfully!
echo.
echo Next steps:
echo    • For local development: scripts\setup-local.bat
echo    • For testnet deployment: scripts\deploy-testnet.bat