@echo off
echo ========================================
echo Bragging Rights - Firebase Setup
echo ========================================
echo.

echo Step 1: Login to Firebase (if not already logged in)
firebase login

echo.
echo Step 2: Configure Firebase for Flutter app
cd /d "C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\bragging_rights_app"

echo.
echo Configuring FlutterFire...
echo Project ID: bragging-rights-ea6e1
echo.

REM Run flutterfire configure with your project
C:\Users\smyth\AppData\Local\Pub\Cache\bin\flutterfire configure --project=bragging-rights-ea6e1 --platforms=android --android-package-name=com.braggingrights.bragging_rights_app

echo.
echo ========================================
echo Firebase configuration complete!
echo ========================================
pause