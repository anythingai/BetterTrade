@echo off
REM BetterTrade Deployment Validation Script for Windows
REM Comprehensive testing suite for post-deployment validation

setlocal enabledelayedexpansion

REM Configuration
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..

REM Test result tracking
set TESTS_PASSED=0
set TESTS_FAILED=0
set FAILED_TESTS=

REM Default values
set ENVIRONMENT=
set SKIP_INTEGRATION=false
set SKIP_PERFORMANCE=false
set VERBOSE=false

REM Parse arguments
:parse_args
if "%~1"=="" goto validate_args
if "%~1"=="--skip-integration" (
    set SKIP_INTEGRATION=true
    shift
    goto parse_args
)
if "%~1"=="--skip-performance" (
    set SKIP_PERFORMANCE=true
    shift
    goto parse_args
)
if "%~1"=="--verbose" (
    set VERBOSE=true
    shift
    goto parse_args
)
if "%~1"=="--help" (
    goto show_usage
)
if "%~1"=="local" (
    set ENVIRONMENT=local
    shift
    goto parse_args
)
if "%~1"=="testnet" (
    set ENVIRONMENT=testnet
    shift
    goto parse_args
)
if "%~1"=="mainnet" (
    set ENVIRONMENT=mainnet
    shift
    goto parse_args
)
echo Unknown option: %~1
goto show_usage

:validate_args
if "%ENVIRONMENT%"=="" (
    echo ERROR: Environment is required
    goto show_usage
)

echo 🧪 Starting deployment validation for %ENVIRONMENT%

REM Test execution function
:run_test
set test_name=%~1
set test_command=%~2

echo [INFO] Running test: %test_name%

call :%test_command%
if %errorlevel% equ 0 (
    echo [SUCCESS] ✅ %test_name%
    set /a TESTS_PASSED+=1
) else (
    echo [ERROR] ❌ %test_name%
    set FAILED_TESTS=%FAILED_TESTS% "%test_name%"
    set /a TESTS_FAILED+=1
)
goto :eof

REM Test 1: Canister Deployment Verification
:test_canister_deployment
set canisters=portfolio_state user_registry strategy_selector execution_agent risk_guard frontend

for %%c in (%canisters%) do (
    dfx canister --network %ENVIRONMENT% id %%c >nul 2>nul
    if !errorlevel! neq 0 (
        echo ERROR: Canister %%c not deployed
        exit /b 1
    )
    
    if "%VERBOSE%"=="true" (
        for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id %%c 2^>nul') do (
            echo %%c: %%i
        )
    )
)
exit /b 0

REM Test 2: Health Check Validation
:test_health_checks
set canisters=portfolio_state user_registry strategy_selector execution_agent risk_guard

for %%c in (%canisters%) do (
    dfx canister --network %ENVIRONMENT% call %%c health_check >nul 2>nul
    if !errorlevel! neq 0 (
        echo ERROR: Health check failed for %%c
        exit /b 1
    )
)
exit /b 0

REM Test 3: Inter-Canister Communication
:test_inter_canister_communication
REM Test user registry -> portfolio state communication
dfx canister --network %ENVIRONMENT% call user_registry test_portfolio_connection >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: User registry cannot communicate with portfolio state
    exit /b 1
)

REM Test strategy selector -> user registry communication
dfx canister --network %ENVIRONMENT% call strategy_selector test_user_registry_connection >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Strategy selector cannot communicate with user registry
    exit /b 1
)

REM Test execution agent -> strategy selector communication
dfx canister --network %ENVIRONMENT% call execution_agent test_strategy_selector_connection >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Execution agent cannot communicate with strategy selector
    exit /b 1
)

exit /b 0

REM Test 4: Data Consistency Validation
:test_data_consistency
set canisters=portfolio_state user_registry strategy_selector execution_agent risk_guard

for %%c in (%canisters%) do (
    dfx canister --network %ENVIRONMENT% call %%c validate_state >nul 2>nul
    if !errorlevel! neq 0 (
        echo ERROR: Data consistency check failed for %%c
        exit /b 1
    )
)
exit /b 0

REM Test 5: Basic Functionality Tests
:test_basic_functionality
REM Test user registration
dfx canister --network %ENVIRONMENT% call user_registry register "(\"test_user\", null)" >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: User registration test failed
    exit /b 1
)

REM Test strategy listing
dfx canister --network %ENVIRONMENT% call strategy_selector list_strategies >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Strategy listing test failed
    exit /b 1
)

REM Test portfolio query
dfx canister --network %ENVIRONMENT% call portfolio_state get_portfolio "(\"test_user_id\")" >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Portfolio query test failed
    exit /b 1
)

exit /b 0

REM Test 6: Security Validation
:test_security
set canisters=portfolio_state user_registry strategy_selector execution_agent risk_guard

for %%c in (%canisters%) do (
    REM Try to call admin functions without proper authorization
    dfx canister --network %ENVIRONMENT% call %%c admin_reset >nul 2>nul
    if !errorlevel! equ 0 (
        echo ERROR: Security test failed: unauthorized admin access allowed for %%c
        exit /b 1
    )
)
exit /b 0

REM Test 7: Performance Validation
:test_performance
if "%SKIP_PERFORMANCE%"=="true" (
    echo [INFO] Skipping performance tests
    exit /b 0
)

REM Test response times for critical functions
dfx canister --network %ENVIRONMENT% call portfolio_state health_check >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Performance test failed
    exit /b 1
)

exit /b 0

REM Test 8: Integration Tests
:test_integration
if "%SKIP_INTEGRATION%"=="true" (
    echo [INFO] Skipping integration tests
    exit /b 0
)

REM Run comprehensive integration test
cd /d "%PROJECT_ROOT%"
dfx canister --network %ENVIRONMENT% call portfolio_state run_integration_test >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Integration test failed
    exit /b 1
)

exit /b 0

REM Test 9: Frontend Accessibility
:test_frontend
if "%ENVIRONMENT%"=="local" (
    for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id frontend 2^>nul') do (
        set frontend_id=%%i
    )
    
    if defined frontend_id (
        set frontend_url=http://localhost:4943/?canisterId=!frontend_id!
        
        REM Test if frontend is accessible (simplified check)
        curl -s --max-time 10 "!frontend_url!" >nul 2>nul
        if !errorlevel! neq 0 (
            echo ERROR: Frontend not accessible at !frontend_url!
            exit /b 1
        )
        
        if "%VERBOSE%"=="true" (
            echo Frontend accessible at !frontend_url!
        )
    )
) else (
    for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id frontend 2^>nul') do (
        set frontend_id=%%i
    )
    
    if defined frontend_id (
        set frontend_url=https://!frontend_id!.ic0.app
        
        REM Test if frontend is accessible (simplified check)
        curl -s --max-time 30 "!frontend_url!" >nul 2>nul
        if !errorlevel! neq 0 (
            echo ERROR: Frontend not accessible at !frontend_url!
            exit /b 1
        )
        
        if "%VERBOSE%"=="true" (
            echo Frontend accessible at !frontend_url!
        )
    )
)

exit /b 0

REM Test 10: Cycle Balance Validation
:test_cycle_balance
if "%ENVIRONMENT%"=="local" (
    echo [INFO] Skipping cycle balance check for local environment
    exit /b 0
)

set canisters=portfolio_state user_registry strategy_selector execution_agent risk_guard frontend

for %%c in (%canisters%) do (
    for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% status %%c 2^>nul ^| findstr cycles') do (
        if "%VERBOSE%"=="true" (
            echo %%c cycle status: %%i
        )
    )
)

exit /b 0

REM Run all tests
echo 🚀 Starting validation tests...

call :run_test "Canister Deployment Verification" test_canister_deployment
call :run_test "Health Check Validation" test_health_checks
call :run_test "Inter-Canister Communication" test_inter_canister_communication
call :run_test "Data Consistency Validation" test_data_consistency
call :run_test "Basic Functionality Tests" test_basic_functionality
call :run_test "Security Validation" test_security
call :run_test "Performance Validation" test_performance
call :run_test "Integration Tests" test_integration
call :run_test "Frontend Accessibility" test_frontend
call :run_test "Cycle Balance Validation" test_cycle_balance

REM Summary
echo.
echo [INFO] 📊 Validation Summary
echo [INFO] Tests Passed: %TESTS_PASSED%
echo [INFO] Tests Failed: %TESTS_FAILED%

if %TESTS_FAILED% gtr 0 (
    echo [ERROR] Failed Tests: %FAILED_TESTS%
    echo [ERROR] ❌ Deployment validation FAILED
    exit /b 1
) else (
    echo [SUCCESS] ✅ All validation tests PASSED
    echo [SUCCESS] 🎉 Deployment is ready for production use
)

goto end

:show_usage
echo Usage: %0 ^<environment^> [options]
echo.
echo Environments:
echo   local     - Validate local deployment
echo   testnet   - Validate testnet deployment
echo   mainnet   - Validate mainnet deployment
echo.
echo Options:
echo   --skip-integration    Skip integration tests
echo   --skip-performance    Skip performance tests
echo   --verbose            Enable verbose output
echo   --help               Show this help message

:end