# UpGrade Frontend Startup Script
Write-Host "========================================" -ForegroundColor Cyan
Write-Host "   UpGrade Frontend - Starting..." -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Check if Flutter is installed
$flutterCheck = Get-Command flutter -ErrorAction SilentlyContinue
if (-not $flutterCheck) {
    Write-Host "ERROR: Flutter is not installed or not in PATH" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please install Flutter from:" -ForegroundColor Yellow
    Write-Host "https://docs.flutter.dev/get-started/install/windows" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Quick install with Chocolatey:" -ForegroundColor Green
    Write-Host "  choco install flutter" -ForegroundColor Green
    Write-Host ""
    Read-Host "Press Enter to exit"
    exit 1
}

Write-Host "Flutter found! Version:" -ForegroundColor Green
flutter --version

Write-Host "`nInstalling dependencies..." -ForegroundColor Yellow
flutter pub get

Write-Host "`nStarting Flutter app in Chrome..." -ForegroundColor Green
Write-Host "Press Ctrl+C to stop the app" -ForegroundColor Yellow
Write-Host ""

flutter run -d chrome
