@echo off
echo Setting Firebase Functions Configuration Variables...
echo.

REM Set API keys as Firebase Functions config
firebase functions:config:set ^
  api.balldontlie="978b1ba9-9847-40cc-93d1-abca911cf822" ^
  api.news="3386d47aa3fe4a7f8375643727fa5afe" ^
  api.odds="a07a990fba881f317ae71ea131cc8223" ^
  api.sportsdb="3"

echo.
echo Configuration set! Now deploy the functions:
echo firebase deploy --only functions
echo.
pause