@echo off
echo Applying MMA ID Fix...
echo.
echo This script will guide you through applying the fix manually.
echo.
echo STEP 1: Open lib/services/optimized_games_service.dart
echo.
echo STEP 2: Add this import after line 15:
echo   import 'mma_id_fix.dart';
echo.
echo STEP 3: Find the _groupByTimeWindows method (around line 1242)
echo.
echo STEP 4: Replace these lines:
echo   final safeId = ...
echo   final groupedEvent = GameModel(
echo     id: safeId,
echo     espnId: null,
echo.
echo WITH:
echo   final ids = MMAIdFix.getEventIds(sport, eventFights.first.gameTime, eventName);
echo   final groupedEvent = GameModel(
echo     id: ids['id']!,
echo     espnId: ids['espnId'],
echo.
echo STEP 5: Save the file
echo.
echo STEP 6: Hot reload the app (press 'r' in the flutter run terminal)
echo.
pause