# UpGrade - Run Frontend (Flutter)
# Requires: Flutter SDK (https://flutter.dev)

Set-Location $PSScriptRoot\frontend

if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter not found. Install Flutter and add it to PATH." -ForegroundColor Red
    exit 1
}

flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Starting Flutter app. Choose a device when prompted (e.g. Chrome, Windows)." -ForegroundColor Green
flutter run
