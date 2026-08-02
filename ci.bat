@echo off
echo === Running flutter pub get ===
call flutter pub get
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo === Checking dart format ===
call dart format --output=none --set-exit-if-changed lib test scripts
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo === Running flutter analyze ===
call flutter analyze
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo === Running flutter test ===
call flutter test
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo === All checks completed successfully! ===
pause
