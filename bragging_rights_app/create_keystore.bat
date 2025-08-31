@echo off
echo Creating Release Keystore for Bragging Rights App
echo ==================================================
echo.
echo This will create a keystore for signing your app for Google Play
echo.
echo IMPORTANT: Save the password you enter! You'll need it for all future updates.
echo.

cd android\app

echo Creating keystore with following details:
echo Alias: bragging_rights
echo Validity: 10000 days
echo.

keytool -genkey -v -keystore bragging-rights-release.keystore -alias bragging_rights -keyalg RSA -keysize 2048 -validity 10000

echo.
echo Keystore created successfully!
echo Location: android\app\bragging-rights-release.keystore
echo.
echo IMPORTANT: Back up this keystore file! If you lose it, you cannot update your app.
pause