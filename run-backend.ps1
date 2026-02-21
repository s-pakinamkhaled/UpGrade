# UpGrade - Run Backend (FastAPI)
# Requires: Python 3.x with pip

Set-Location $PSScriptRoot\backend

if (!(Get-Command python -ErrorAction SilentlyContinue) -and !(Get-Command py -ErrorAction SilentlyContinue)) {
    Write-Host "Python not found. Install Python from https://www.python.org/ and ensure it's in PATH." -ForegroundColor Red
    exit 1
}

$pip = if (Get-Command py -ErrorAction SilentlyContinue) { "py -m pip" } else { "python -m pip" }
Invoke-Expression "$pip install -r requirements.txt"
if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }

Write-Host "Starting backend on http://127.0.0.1:8001" -ForegroundColor Green
$uvicorn = if (Get-Command py -ErrorAction SilentlyContinue) { "py -m uvicorn" } else { "python -m uvicorn" }
Invoke-Expression "$uvicorn app.main:app --reload --host 0.0.0.0 --port 8001"
