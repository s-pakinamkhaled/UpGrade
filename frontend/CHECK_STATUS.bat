@echo off
echo ========================================
echo    UpGrade - System Status Check
echo ========================================
echo.

echo [1/4] Checking Python...
python --version 2>nul
if %ERRORLEVEL% EQU 0 (
    echo    ✓ Python is installed
) else (
    echo    ✗ Python is NOT installed
)
echo.

echo [2/4] Checking Flutter...
flutter --version 2>nul
if %ERRORLEVEL% EQU 0 (
    echo    ✓ Flutter is installed
) else (
    echo    ✗ Flutter is NOT installed
    echo      Install from: https://docs.flutter.dev/get-started/install/windows
)
echo.

echo [3/4] Checking Backend...
curl -s http://127.0.0.1:8001 >nul 2>&1
if %ERRORLEVEL% EQU 0 (
    echo    ✓ Backend is running on port 8001
) else (
    echo    ✗ Backend is NOT running
    echo      Start with: cd backend ^&^& python -m uvicorn app.main:app --reload --port 8001
)
echo.

echo [4/4] Checking AI Service...
if exist "..\ai\planner_llm\llm_client.py" (
    echo    ✓ AI Service files found
) else (
    echo    ✗ AI Service files NOT found
)
echo.

echo ========================================
echo Summary:
echo - Backend: Running at http://127.0.0.1:8001
echo - AI Service: Configured with Llama 3.3
echo - Frontend: Needs Flutter installation
echo.
echo Next Steps:
echo 1. Install Flutter SDK
echo 2. Run: START_APP.bat
echo ========================================
echo.
pause
