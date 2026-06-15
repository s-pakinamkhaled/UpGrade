# Soak test - steady moderate load for a long period (default: 2000 users x 30 min)
# Usage: .\load_tests\run_soak.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command locust -ErrorAction SilentlyContinue)) {
    pip install -r requirements-load.txt
}

New-Item -ItemType Directory -Force -Path "load_tests/reports" | Out-Null

$env:LOCUST_TEST_TYPE = "soak"
$env:ENABLE_AI_TASKS = "false"

if (-not $env:SOAK_USERS) { $env:SOAK_USERS = "2000" }
$users = $env:SOAK_USERS
$mins = if ($env:SOAK_DURATION_MINUTES) { $env:SOAK_DURATION_MINUTES } else { "30" }
Write-Host "Soak test - $users users for $mins minutes (core API only)"

locust -f load_tests/locustfile.py `
    --host http://127.0.0.1:8001 `
    --headless `
    --html load_tests/reports/soak_$(Get-Date -Format 'yyyyMMdd_HHmmss').html `
    --csv load_tests/reports/soak_$(Get-Date -Format 'yyyyMMdd_HHmmss')
