@echo off
echo === Running flutter pub get ===
call flutter pub get
if %errorlevel% neq 0 exit /b %errorlevel%

echo.
echo === Running dart format ===
call dart format .
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
