# UpGrade - Run Whole Project
# Starts backend in a new window, then runs frontend in this window.

$root = $PSScriptRoot
$backendPath = Join-Path $root "backend"

# ---- 1) Start Backend in a new window ----
$backendCmd = @"
Set-Location '$backendPath'
if (Get-Command python -ErrorAction SilentlyContinue) {
    python -m pip install -r requirements.txt 2>$null
    python -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
} elseif (Get-Command py -ErrorAction SilentlyContinue) {
    py -m pip install -r requirements.txt 2>$null
    py -m uvicorn app.main:app --reload --host 0.0.0.0 --port 8001
} else {
    Write-Host 'Python not found. Install from https://www.python.org/' -ForegroundColor Red
    pause
}
"@

Start-Process powershell -ArgumentList "-NoExit", "-Command", $backendCmd
Write-Host "Backend starting in new window (http://127.0.0.1:8001) ..." -ForegroundColor Green
Start-Sleep -Seconds 3

# ---- 2) Run Frontend in this window ----
Set-Location "$root\frontend"
if (!(Get-Command flutter -ErrorAction SilentlyContinue)) {
    Write-Host "Flutter not found. Install from https://flutter.dev" -ForegroundColor Red
    exit 1
}
flutter pub get
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
Write-Host "Starting Flutter app. Pick a device (e.g. Chrome, Windows)." -ForegroundColor Green
flutter run
