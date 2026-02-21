@echo off
echo ========================================
echo    UpGrade Frontend - Starting...
echo ========================================
echo.

REM Check if Flutter is installed
where flutter >nul 2>&1
if %ERRORLEVEL% NEQ 0 (
    echo ERROR: Flutter is not installed or not in PATH
    echo.
    echo Please install Flutter from:
    echo https://docs.flutter.dev/get-started/install/windows
    echo.
    pause
    exit /b 1
)

echo Flutter found! Checking dependencies...
flutter pub get

echo.
echo Starting Flutter app in Chrome...
echo.
flutter run -d chrome

pause
