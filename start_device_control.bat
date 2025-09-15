@echo off
echo ==========================================
echo     Pixel Device Control Panel Setup
echo ==========================================
echo.

REM Check if Node.js is installed
where node >nul 2>nul
if %errorlevel% neq 0 (
    echo [ERROR] Node.js is not installed or not in PATH
    echo Please install Node.js from https://nodejs.org/
    pause
    exit /b 1
)

REM Check if ADB is installed
where adb >nul 2>nul
if %errorlevel% neq 0 (
    echo [WARNING] ADB is not installed or not in PATH
    echo Please install Android SDK Platform Tools
    echo Download from: https://developer.android.com/studio/releases/platform-tools
    echo.
)

REM Install dependencies if needed
if not exist node_modules (
    echo Installing dependencies...
    npm install express cors
    if %errorlevel% neq 0 (
        echo [ERROR] Failed to install dependencies
        pause
        exit /b 1
    )
)

REM Check device connection
echo.
echo Checking for connected devices...
adb devices

echo.
echo ==========================================
echo     Starting Device Control Server
echo ==========================================
echo.
echo Server will run on: http://localhost:5000
echo.
echo Press Ctrl+C to stop the server
echo.

REM Start the server
node device_control_server.js

pause