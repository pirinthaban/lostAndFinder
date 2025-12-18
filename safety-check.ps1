# Safety Check Script
# Run this before pushing to GitHub

Write-Host "🔍 Checking for sensitive files..." -ForegroundColor Cyan

$sensitiveFiles = @(
    "android\key.properties",
    "android\app\google-services.json",
    "ios\Runner\GoogleService-Info.plist",
    ".env",
    "android\upload-keystore.jks",
    "android\app\upload-keystore.jks"
)

$foundSensitive = $false

foreach ($file in $sensitiveFiles) {
    if (Test-Path $file) {
        Write-Host "⚠️  WARNING: Found sensitive file: $file" -ForegroundColor Red
        $foundSensitive = $true
    }
}

if (-not $foundSensitive) {
    Write-Host "✅ No sensitive files found - SAFE!" -ForegroundColor Green
}

Write-Host ""
Write-Host "📋 Checking .gitignore..." -ForegroundColor Cyan

if (Test-Path ".gitignore") {
    $gitignoreContent = Get-Content ".gitignore" -Raw
    
    $requiredPatterns = @("key.properties", "google-services.json", "*.jks", "*.keystore", ".env")
    $allFound = $true
    
    foreach ($pattern in $requiredPatterns) {
        if ($gitignoreContent -match [regex]::Escape($pattern)) {
            Write-Host "  ✅ $pattern is ignored" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $pattern is NOT ignored!" -ForegroundColor Red
            $allFound = $false
        }
    }
    
    if ($allFound) {
        Write-Host "✅ .gitignore is properly configured!" -ForegroundColor Green
    }
} else {
    Write-Host "❌ .gitignore not found!" -ForegroundColor Red
}

Write-Host ""
Write-Host "🔍 Checking firebase_options.dart for real keys..." -ForegroundColor Cyan

if (Test-Path "lib\firebase_options.dart") {
    $firebaseContent = Get-Content "lib\firebase_options.dart" -Raw
    
    # Check for placeholder values
    if ($firebaseContent -match "REPLACE_WITH_YOUR" -or $firebaseContent -match "your-project-id") {
        Write-Host "✅ firebase_options.dart has placeholder values - SAFE!" -ForegroundColor Green
    } elseif ($firebaseContent -match "AIza[a-zA-Z0-9_-]{35}") {
        Write-Host "⚠️  WARNING: firebase_options.dart may contain real API key!" -ForegroundColor Yellow
        Write-Host "   This is OK if it is public (Firebase keys are rate-limited)" -ForegroundColor Yellow
    }
}

Write-Host ""
Write-Host "📋 Files to update before publishing:" -ForegroundColor Cyan
Write-Host "  1. Replace YOUR_USERNAME in README.md" -ForegroundColor White
Write-Host "  2. Replace YOUR_USERNAME in pubspec.yaml" -ForegroundColor White
Write-Host "  3. Replace YOUR_USERNAME in CHANGELOG.md" -ForegroundColor White
Write-Host "  4. (Optional) Replace email in SECURITY.md" -ForegroundColor White

Write-Host ""
if (-not $foundSensitive) {
    Write-Host "✅ READY TO PUBLISH!" -ForegroundColor Green -BackgroundColor Black
    Write-Host ""
    Write-Host "Next: Run these commands:" -ForegroundColor Cyan
    Write-Host "  git init" -ForegroundColor White
    Write-Host "  git add ." -ForegroundColor White
    Write-Host "  git commit -m `"Initial commit`"" -ForegroundColor White
    Write-Host "  git remote add origin https://github.com/YOUR_USERNAME/FindBack.git" -ForegroundColor White
    Write-Host "  git push -u origin main" -ForegroundColor White
} else {
    Write-Host "⚠️  Remove sensitive files before publishing!" -ForegroundColor Red
}
