@echo off
echo ========================================
echo   FIGHTER DATA AND CACHING TESTS
echo ========================================
echo.

cd /d "C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\bragging_rights_app"

echo Running fighter data and image caching tests...
echo.

flutter test test/fighter_data_and_caching_test.dart --reporter expanded

echo.
echo ========================================
echo   TEST EXECUTION COMPLETE
echo ========================================
echo.

pause