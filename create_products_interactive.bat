@echo off
echo ============================================================
echo Google Play In-App Products Manager
echo ============================================================
echo.
echo This will open a browser window for authentication.
echo Please log in with your Google account that has access to
echo the Google Play Console for your app.
echo.
echo After authentication, the script will create your in-app products.
echo.
pause

python create_products_oauth.py