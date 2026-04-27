# Deploy Privacy Policy to Firebase Hosting
# Run this script from the project root folder

Write-Host "============================================" -ForegroundColor Cyan
Write-Host "  Deploying Privacy Policy to Firebase" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""

# Check if Firebase CLI is installed
$firebase = Get-Command firebase -ErrorAction SilentlyContinue
if (-not $firebase) {
    Write-Host "Firebase CLI not found. Installing..." -ForegroundColor Yellow
    npm install -g firebase-tools
    if ($LASTEXITCODE -ne 0) {
        Write-Host ""
        Write-Host "ERROR: Failed to install Firebase CLI." -ForegroundColor Red
        Write-Host "Please install it manually: npm install -g firebase-tools" -ForegroundColor Yellow
        exit 1
    }
}

Write-Host ""
Write-Host "Step 1: Login to Firebase (if not already logged in)" -ForegroundColor Green
firebase login

Write-Host ""
Write-Host "Step 2: Deploying to Firebase Hosting..." -ForegroundColor Green
firebase deploy --only hosting

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "  SUCCESS! Privacy page deployed!" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Your privacy policy is now live at:" -ForegroundColor Cyan
    Write-Host "https://upgrade-aa19f.firebaseapp.com/privacy" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Use this URL in Google Cloud Console:" -ForegroundColor Cyan
    Write-Host "Application privacy policy link" -ForegroundColor White
    Write-Host ""
} else {
    Write-Host ""
    Write-Host "Deployment failed. Please check the error above." -ForegroundColor Red
}
