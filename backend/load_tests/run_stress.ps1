# Stress test - ramp users until failures / latency spikes (default max: 3000)
# Usage: .\load_tests\run_stress.ps1

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command locust -ErrorAction SilentlyContinue)) {
    pip install -r requirements-load.txt
}

New-Item -ItemType Directory -Force -Path "load_tests/reports" | Out-Null

$env:LOCUST_TEST_TYPE = "stress"
$env:ENABLE_AI_TASKS = "false"

if (-not $env:STRESS_MAX_USERS) { $env:STRESS_MAX_USERS = "3000" }
$max = $env:STRESS_MAX_USERS
Write-Host "Stress test - ramping up to $max users (core API only)"

locust -f load_tests/locustfile.py `
    --host http://127.0.0.1:8001 `
    --headless `
    --html load_tests/reports/stress_$(Get-Date -Format 'yyyyMMdd_HHmmss').html `
    --csv load_tests/reports/stress_$(Get-Date -Format 'yyyyMMdd_HHmmss')
