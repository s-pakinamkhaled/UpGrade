# AI endpoint load test - includes Groq chat + planner (low concurrency recommended)
# Usage: .\load_tests\run_ai_load.ps1
# Requires GROQ_API_KEY in backend/.env and backend running.

$ErrorActionPreference = "Stop"
Set-Location (Split-Path $PSScriptRoot -Parent)

if (-not (Get-Command locust -ErrorAction SilentlyContinue)) {
    pip install -r requirements-load.txt
}

New-Item -ItemType Directory -Force -Path "load_tests/reports" | Out-Null

$env:LOCUST_TEST_TYPE = "load"
$env:ENABLE_AI_TASKS = "true"
$env:LOAD_PEAK_USERS = if ($env:LOAD_PEAK_USERS) { $env:LOAD_PEAK_USERS } else { "10" }
$env:LOAD_HOLD_SECONDS = if ($env:LOAD_HOLD_SECONDS) { $env:LOAD_HOLD_SECONDS } else { "120" }

Write-Host "AI load test - peak $($env:LOAD_PEAK_USERS) users (Groq enabled, keep concurrency low)"

locust -f load_tests/locustfile.py `
    --host http://127.0.0.1:8001 `
    --headless `
    --html load_tests/reports/ai_load_$(Get-Date -Format 'yyyyMMdd_HHmmss').html `
    --csv load_tests/reports/ai_load_$(Get-Date -Format 'yyyyMMdd_HHmmss')
