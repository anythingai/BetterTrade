@echo off
REM BetterTrade Enhanced Deployment Script for Windows
REM Supports local, testnet, and mainnet deployments with state migration

setlocal enabledelayedexpansion

REM Configuration
set SCRIPT_DIR=%~dp0
set PROJECT_ROOT=%SCRIPT_DIR%..
set CONFIG_DIR=%SCRIPT_DIR%config
set ENVIRONMENTS_CONFIG=%CONFIG_DIR%\environments.json
set CANISTER_CONFIG=%CONFIG_DIR%\canister-config.json

REM Default values
set ENVIRONMENT=
set UPGRADE_MODE=
set SKIP_FRONTEND=false
set SKIP_BUILD=false
set DRY_RUN=false

REM Parse command line arguments
:parse_args
if "%~1"=="" goto validate_args
if "%~1"=="--upgrade" (
    set UPGRADE_MODE=upgrade
    shift
    goto parse_args
)
if "%~1"=="--reinstall" (
    set UPGRADE_MODE=reinstall
    shift
    goto parse_args
)
if "%~1"=="--skip-frontend" (
    set SKIP_FRONTEND=true
    shift
    goto parse_args
)
if "%~1"=="--skip-build" (
    set SKIP_BUILD=true
    shift
    goto parse_args
)
if "%~1"=="--dry-run" (
    set DRY_RUN=true
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

REM Set default upgrade mode based on environment
if "%UPGRADE_MODE%"=="" (
    if "%ENVIRONMENT%"=="local" (
        set UPGRADE_MODE=reinstall
    ) else (
        set UPGRADE_MODE=upgrade
    )
)

echo 🚀 Starting BetterTrade deployment
echo Environment: %ENVIRONMENT%
echo Upgrade Mode: %UPGRADE_MODE%

if "%DRY_RUN%"=="true" (
    echo WARNING: DRY RUN MODE - No actual deployment will occur
)

REM Pre-deployment checks
echo 🔍 Running pre-deployment checks...

REM Check dfx installation
where dfx >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: dfx is not installed. Please install dfx first
    exit /b 1
)

REM Check dfx version
for /f "tokens=*" %%i in ('dfx --version') do set DFX_VERSION=%%i
echo dfx version: %DFX_VERSION%

REM Start local replica if needed
if "%ENVIRONMENT%"=="local" (
    echo 📡 Starting local replica...
    dfx ping local >nul 2>nul
    if %errorlevel% neq 0 (
        if "%DRY_RUN%"=="false" (
            start /b dfx start --clean
            timeout /t 10 /nobreak >nul
        ) else (
            echo Would start local replica
        )
    ) else (
        echo Local replica already running
    )
)

REM Build project
if "%SKIP_BUILD%"=="false" (
    echo 🏗️  Building project...
    if "%DRY_RUN%"=="false" (
        cd /d "%PROJECT_ROOT%"
        call build.bat
    ) else (
        echo Would build project
    )
)

REM Deploy canisters in order
echo 📦 Deploying canisters in dependency order...

set DEPLOYMENT_ORDER=portfolio_state user_registry strategy_selector execution_agent risk_guard frontend

for %%c in (%DEPLOYMENT_ORDER%) do (
    if "%%c"=="frontend" if "%SKIP_FRONTEND%"=="true" (
        echo Skipping frontend deployment
    ) else (
        echo Deploying %%c...
        
        if "%DRY_RUN%"=="false" (
            REM Set environment variables
            set BITSIGHT_ENVIRONMENT=%ENVIRONMENT%
            
            REM Deploy with appropriate mode
            if "%UPGRADE_MODE%"=="upgrade" (
                dfx deploy --network %ENVIRONMENT% --mode upgrade %%c
            ) else (
                dfx deploy --network %ENVIRONMENT% --mode reinstall %%c
            )
            
            REM Run health check
            echo Running health check for %%c...
            dfx canister --network %ENVIRONMENT% call %%c health_check >nul 2>nul || (
                echo WARNING: Health check failed for %%c
            )
        ) else (
            echo Would deploy %%c with mode %UPGRADE_MODE%
        )
    )
)

REM Generate Candid interfaces
echo 📋 Generating Candid interfaces...
if "%DRY_RUN%"=="false" (
    dfx generate --network %ENVIRONMENT%
)

REM Post-deployment validation
echo ✅ Running post-deployment validation...

if "%DRY_RUN%"=="false" (
    echo 📊 Deployed Canister IDs:
    for %%c in (%DEPLOYMENT_ORDER%) do (
        if "%%c"=="frontend" if "%SKIP_FRONTEND%"=="true" (
            REM Skip frontend
        ) else (
            for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id %%c 2^>nul') do (
                echo   %%c: %%i
            )
        )
    )
    
    REM Display access URLs
    if "%ENVIRONMENT%"=="local" (
        for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id frontend 2^>nul') do (
            if "%SKIP_FRONTEND%"=="false" (
                echo 🌐 Frontend URL: http://localhost:4943/?canisterId=%%i
            )
        )
        for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id __Candid_UI 2^>nul') do (
            echo 🔧 Candid UI: http://localhost:4943/?canisterId=%%i
        )
    ) else (
        for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id frontend 2^>nul') do (
            if "%SKIP_FRONTEND%"=="false" (
                echo 🌐 Frontend URL: https://%%i.ic0.app
            )
        )
    )
)

REM Save deployment info
set DEPLOYMENT_INFO_FILE=%PROJECT_ROOT%\deployment-info-%ENVIRONMENT%.json
if "%DRY_RUN%"=="false" (
    echo 💾 Saving deployment information to %DEPLOYMENT_INFO_FILE%
    
    echo { > "%DEPLOYMENT_INFO_FILE%"
    echo   "environment": "%ENVIRONMENT%", >> "%DEPLOYMENT_INFO_FILE%"
    echo   "deployment_time": "%date% %time%", >> "%DEPLOYMENT_INFO_FILE%"
    echo   "upgrade_mode": "%UPGRADE_MODE%", >> "%DEPLOYMENT_INFO_FILE%"
    echo   "dfx_version": "%DFX_VERSION%", >> "%DEPLOYMENT_INFO_FILE%"
    echo   "canister_ids": { >> "%DEPLOYMENT_INFO_FILE%"
    
    set first=true
    for %%c in (%DEPLOYMENT_ORDER%) do (
        if "%%c"=="frontend" if "%SKIP_FRONTEND%"=="true" (
            REM Skip frontend
        ) else (
            for /f "tokens=*" %%i in ('dfx canister --network %ENVIRONMENT% id %%c 2^>nul') do (
                if "!first!"=="false" echo , >> "%DEPLOYMENT_INFO_FILE%"
                echo     "%%c": "%%i" >> "%DEPLOYMENT_INFO_FILE%"
                set first=false
            )
        )
    )
    
    echo   } >> "%DEPLOYMENT_INFO_FILE%"
    echo } >> "%DEPLOYMENT_INFO_FILE%"
)

echo 🎉 Deployment completed successfully!

if not "%ENVIRONMENT%"=="local" (
    echo 💡 Next steps:
    echo   • Monitor canister health and performance
    echo   • Run integration tests against deployed canisters
    echo   • Update frontend configuration with new canister IDs
)

goto end

:show_usage
echo Usage: %0 [OPTIONS] ^<environment^>
echo.
echo Environments:
echo   local     - Deploy to local replica
echo   testnet   - Deploy to ICP testnet
echo   mainnet   - Deploy to ICP mainnet
echo.
echo Options:
echo   --upgrade         Perform upgrade deployment (preserve state)
echo   --reinstall       Perform reinstall deployment (reset state)
echo   --skip-frontend   Skip frontend deployment
echo   --skip-build      Skip build step
echo   --dry-run         Show what would be deployed without executing
echo   --help            Show this help message
echo.
echo Examples:
echo   %0 local
echo   %0 --upgrade testnet
echo   %0 --reinstall --skip-frontend mainnet

:end