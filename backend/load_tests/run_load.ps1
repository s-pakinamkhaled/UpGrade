# Normal load test - sustainable concurrent users (default peak: 2000)
# Usage: .\load_tests\run_load.ps1
# Prerequisite: backend running on port 8001

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command locust -ErrorAction SilentlyContinue)) {
    Write-Host "Installing locust..."
    pip install -r requirements-load.txt
}

New-Item -ItemType Directory -Force -Path "load_tests/reports" | Out-Null

$env:LOCUST_TEST_TYPE = "load"
$env:ENABLE_AI_TASKS = "false"
if (-not $env:LOAD_PEAK_USERS) { $env:LOAD_PEAK_USERS = "2000" }

$peak = $env:LOAD_PEAK_USERS
Write-Host "Load test starting - peak users: $peak (core API only, no Groq)"
Write-Host "Open http://localhost:8089 for Locust UI, or wait for headless run..."

locust -f load_tests/locustfile.py `
    --host http://127.0.0.1:8001 `
    --headless `
    --html load_tests/reports/load_$(Get-Date -Format 'yyyyMMdd_HHmmss').html `
    --csv load_tests/reports/load_$(Get-Date -Format 'yyyyMMdd_HHmmss')
