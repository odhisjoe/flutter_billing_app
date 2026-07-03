# POS MASHINANI Automated Build and Deploy Script for Firebase Hosting
# Runs all necessary tasks to compile the release APK, copy it to the static assets directory, and deploy the web package.

# Stop on errors
$ErrorActionPreference = "Stop"

Write-Host "==============================================" -ForegroundColor Green
Write-Host "Starting POS MASHINANI Build & Deploy Pipeline" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green

# 1. Clean existing builds to avoid caching issues
Write-Host "`n[1/5] Cleaning previous build files..." -ForegroundColor Cyan
flutter clean

# 2. Build Android release APK
Write-Host "`n[2/5] Building Android Release APK..." -ForegroundColor Cyan
flutter build apk --release

# 3. Create destination directory if not exists, and copy APK
Write-Host "`n[3/5] Copying APK to web assets directory..." -ForegroundColor Cyan
if (-not (Test-Path "web")) {
    New-Item -ItemType Directory -Path "web" -Force | Out-Null
}
Copy-Item "build/app/outputs/flutter-apk/app-release.apk" "web/pos-mashinani.apk" -Force
Write-Host "Copied to web/pos-mashinani.apk" -ForegroundColor Green

# 4. Build Flutter Web release
Write-Host "`n[4/5] Building Flutter Web Release..." -ForegroundColor Cyan
flutter build web --release

# 5. Deploy to Firebase Hosting
Write-Host "`n[5/5] Deploying to Firebase Hosting..." -ForegroundColor Cyan
firebase deploy --only hosting

Write-Host "`n==============================================" -ForegroundColor Green
Write-Host "Deployment completed successfully!" -ForegroundColor Green
Write-Host "==============================================" -ForegroundColor Green
