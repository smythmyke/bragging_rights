@echo off
echo ========================================
echo Deploying Firestore Security Rules for Bragging Rights
echo ========================================

REM Check if Firebase CLI is available
where firebase >nul 2>nul
if %errorlevel% neq 0 (
    echo ERROR: Firebase CLI not found. Installing...
    call npm install -g firebase-tools
    if %errorlevel% neq 0 (
        echo Failed to install Firebase CLI. Please install manually.
        pause
        exit /b 1
    )
)

REM Check if firestore.rules exists
if not exist "firestore.rules" (
    echo ERROR: firestore.rules file not found in current directory
    pause
    exit /b 1
)

REM Create backup of current rules
echo Creating backup of current rules...
for /f "tokens=2 delims==" %%I in ('wmic os get localdatetime /value') do set datetime=%%I
set datetime=%datetime:~0,8%_%datetime:~8,6%
firebase firestore:rules:get > firestore.rules.backup.%datetime%.txt 2>nul

REM Deploy the rules
echo.
echo Deploying rules to Firebase...
firebase deploy --only firestore:rules

if %errorlevel% equ 0 (
    echo.
    echo ========================================
    echo SUCCESS: Firestore security rules deployed!
    echo ========================================
    echo.
    echo Rules Summary:
    echo   - Users can only read/write their own data
    echo   - Wallet balances are read-only (server-managed)
    echo   - Bets require sufficient balance and game not started
    echo   - Pools have controlled join mechanics  
    echo   - Transactions are read-only for users
    echo   - Leaderboards are publicly readable
    echo.
    echo IMPORTANT NOTES:
    echo   1. Test thoroughly in development first
    echo   2. Monitor Firebase Console for rule violations
    echo   3. Set up admin custom claims for admin users
    echo   4. Implement Cloud Functions for secure wallet operations
    echo.
    echo Next steps:
    echo   1. Test rules in Firebase Console Simulator
    echo   2. Monitor security rule denials in Firebase Console
    echo   3. Set up Cloud Functions for secure operations
) else (
    echo.
    echo ERROR: Failed to deploy rules. Check your Firebase configuration.
    echo Make sure you're logged in: firebase login
)

echo.
pause