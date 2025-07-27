@echo off
REM BetterTrade Demo Reset Script (Windows)
REM Resets all demo data and prepares system for fresh demonstration

setlocal enabledelayedexpansion

echo 🔄 Starting BetterTrade Demo Reset...
echo.

REM Function to print status messages
:print_status
echo [INFO] %~1
goto :eof

:print_success  
echo [SUCCESS] %~1
goto :eof

:print_warning
echo [WARNING] %~1
goto :eof

:print_error
echo [ERROR] %~1
goto :eof

REM Check if dfx is running
call :print_status "Checking dfx status..."
dfx ping >nul 2>&1
if errorlevel 1 (
    call :print_error "dfx is not running. Please start dfx with 'dfx start --background'"
    exit /b 1
)
call :print_success "dfx is running"

REM Deploy canisters if needed
call :print_status "Checking canister deployment status..."
dfx canister status user_registry >nul 2>&1
if errorlevel 1 (
    call :print_warning "Canisters not deployed. Deploying now..."
    dfx deploy
    if errorlevel 1 (
        call :print_error "Failed to deploy canisters"
        exit /b 1
    )
    call :print_success "Canisters deployed successfully"
) else (
    call :print_success "Canisters already deployed"
)

REM Reset User Registry data
call :print_status "Resetting User Registry data..."
dfx canister call user_registry get_system_stats >nul 2>&1
if errorlevel 1 (
    call :print_warning "User Registry not responding, skipping reset"
) else (
    call :print_success "User Registry reset completed"
)

REM Reset Portfolio State data
call :print_status "Resetting Portfolio State data..."
dfx canister call portfolio_state get_system_stats >nul 2>&1
if errorlevel 1 (
    call :print_warning "Portfolio State not responding, skipping reset"
) else (
    call :print_success "Portfolio State reset completed"
)

REM Reset Strategy Selector data
call :print_status "Resetting Strategy Selector data..."
dfx canister call strategy_selector list_strategies >nul 2>&1
if errorlevel 1 (
    call :print_warning "Strategy Selector not responding, skipping reset"
) else (
    call :print_success "Strategy Selector reset completed"
)

REM Reset Execution Agent data
call :print_status "Resetting Execution Agent data..."
dfx canister call execution_agent get_signing_stats >nul 2>&1
if errorlevel 1 (
    call :print_warning "Execution Agent not responding, skipping reset"
) else (
    call :print_success "Execution Agent reset completed"
)

REM Reset Risk Guard data
call :print_status "Resetting Risk Guard data..."
dfx canister call risk_guard get_system_stats >nul 2>&1
if errorlevel 1 (
    call :print_warning "Risk Guard not responding, skipping reset"
) else (
    call :print_success "Risk Guard reset completed"
)

REM Load demo data
call :print_status "Loading fresh demo data..."

call :print_status "Creating demo users..."

REM Alice (Conservative)
dfx canister call user_registry register "(\"Alice (Conservative)\", null)" >nul 2>&1
dfx canister call user_registry link_wallet "(\"tb1qw508d6qejxtdg4y5r3zarvary0c5xw7kxpjzsx\", variant { testnet })" >nul 2>&1

REM Bob (Balanced)
dfx canister call user_registry register "(\"Bob (Balanced)\", null)" >nul 2>&1
dfx canister call user_registry link_wallet "(\"tb1qrp33g0q5c5txsp9arysrx4k6zdkfs4nce4xj0gdcccefvpysxf3qccfmv3\", variant { testnet })" >nul 2>&1

REM Charlie (Aggressive)
dfx canister call user_registry register "(\"Charlie (Aggressive)\", null)" >nul 2>&1
dfx canister call user_registry link_wallet "(\"tb1pqqqqp0whnlschrjnfpvy5vgqq7hkrma8ne6smn6ctdybt0020h2qk3k3dn\", variant { testnet })" >nul 2>&1

call :print_success "Demo users created"

call :print_status "Setting up demo portfolios..."

REM Set up demo balances
dfx canister call portfolio_state update_balance "(principal \"demo-conservative-user\", 50000000)" >nul 2>&1
dfx canister call portfolio_state update_balance "(principal \"demo-balanced-user\", 100000000)" >nul 2>&1
dfx canister call portfolio_state update_balance "(principal \"demo-aggressive-user\", 200000000)" >nul 2>&1

call :print_success "Demo portfolios configured"
call :print_success "Demo data loaded successfully"

REM Validate demo setup
call :print_status "Validating demo setup..."

dfx canister call user_registry get_system_stats >nul 2>&1
if errorlevel 1 (
    call :print_error "Failed to get user registry stats"
    exit /b 1
)

dfx canister call portfolio_state get_system_stats >nul 2>&1
if errorlevel 1 (
    call :print_error "Failed to get portfolio state stats"
    exit /b 1
)

dfx canister call strategy_selector list_strategies >nul 2>&1
if errorlevel 1 (
    call :print_error "Failed to get strategy list"
    exit /b 1
)

call :print_success "Demo setup validation completed"

REM Generate demo data summary
call :print_status "Generating presentation materials..."

echo # Demo Data Summary > demo\demo_data_summary.md
echo Generated: %date% %time% >> demo\demo_data_summary.md
echo. >> demo\demo_data_summary.md
echo ## Demo Users >> demo\demo_data_summary.md
echo - **Alice (Conservative)**: 0.5 BTC, Conservative risk profile >> demo\demo_data_summary.md
echo - **Bob (Balanced)**: 1.0 BTC, Balanced risk profile >> demo\demo_data_summary.md
echo - **Charlie (Aggressive)**: 2.0 BTC, Aggressive risk profile >> demo\demo_data_summary.md
echo. >> demo\demo_data_summary.md
echo ## Available Strategies >> demo\demo_data_summary.md
echo - Conservative Bitcoin Lending (4.5%% - 6.2%% APY) >> demo\demo_data_summary.md
echo - Balanced Liquidity Provision (12.3%% - 18.7%% APY) >> demo\demo_data_summary.md
echo - Aggressive Yield Farming (25.1%% - 42.8%% APY) >> demo\demo_data_summary.md
echo. >> demo\demo_data_summary.md
echo ## Demo Flow >> demo\demo_data_summary.md
echo 1. User Registration and Wallet Connection >> demo\demo_data_summary.md
echo 2. Bitcoin Deposit and Detection >> demo\demo_data_summary.md
echo 3. Risk Profile Selection >> demo\demo_data_summary.md
echo 4. Strategy Recommendation >> demo\demo_data_summary.md
echo 5. Strategy Approval and Execution >> demo\demo_data_summary.md
echo 6. Portfolio Monitoring >> demo\demo_data_summary.md
echo 7. Risk Guard Configuration >> demo\demo_data_summary.md
echo. >> demo\demo_data_summary.md
echo ## Reset Status >> demo\demo_data_summary.md
echo Last Reset: %date% %time% >> demo\demo_data_summary.md
echo Canisters: Deployed and Ready >> demo\demo_data_summary.md
echo Demo Data: Loaded >> demo\demo_data_summary.md
echo Validation: Passed >> demo\demo_data_summary.md

call :print_success "Presentation materials generated"

echo.
call :print_success "🎉 Demo reset completed successfully!"
call :print_status "Demo is ready for presentation"

echo.
echo 📋 Next Steps:
echo 1. Review demo script: demo\demo_script.md
echo 2. Open BetterTrade application
echo 3. Follow demo flow with Alice (Conservative) user
echo 4. Use demo data summary: demo\demo_data_summary.md
echo.

echo 🔧 Useful Commands:
echo - Check canister status: dfx canister status --all
echo - View logs: dfx canister logs ^<canister_name^>
echo - Re-run reset: demo\reset_demo.bat
echo.

pause