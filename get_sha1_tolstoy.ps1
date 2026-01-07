# Script to get SHA-1 fingerprint for Tolstoy app
# This script extracts SHA-1 from the keystore file

$keystorePath = "android\app\upload-keystore.jks"
$alias = "upload"
$storepass = "dostoevsky2024"
$keypass = "dostoevsky2024"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SHA-1 Fingerprint Extractor" -ForegroundColor Cyan
Write-Host "  App: Tolstoy" -ForegroundColor Cyan
Write-Host "  Package: com.spinel.tolstoy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# Try to find Java
$javaPath = $null

# Common Java locations
$javaLocations = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "$env:ProgramFiles\Java\*\bin\keytool.exe",
    "$env:ProgramFiles(x86)\Java\*\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jbr\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jre\bin\keytool.exe",
    "$env:ANDROID_HOME\jbr\bin\keytool.exe",
    "$env:ANDROID_HOME\jre\bin\keytool.exe"
)

foreach ($location in $javaLocations) {
    $expanded = $location -replace '\*', '*'
    $found = Get-ChildItem -Path $expanded -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($found) {
        $javaPath = $found.FullName
        break
    }
}

if (-not $javaPath) {
    Write-Host "❌ Java keytool not found automatically." -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run this command manually:" -ForegroundColor Yellow
    Write-Host "keytool -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $keypass" -ForegroundColor White
    Write-Host ""
    Write-Host "Or find Java installation and use:" -ForegroundColor Yellow
    Write-Host "<JAVA_PATH>\bin\keytool -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $keypass" -ForegroundColor White
    exit 1
}

Write-Host "✅ Found keytool at: $javaPath" -ForegroundColor Green
Write-Host ""

# Check if keystore exists
if (-not (Test-Path $keystorePath)) {
    Write-Host "❌ Keystore file not found at: $keystorePath" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Extracting SHA-1 fingerprint..." -ForegroundColor Cyan
Write-Host ""

# Run keytool command
try {
    $output = & $javaPath -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $keypass 2>&1
    
    # Display full output
    Write-Host $output
    
    # Extract SHA-1
    $sha1Line = $output | Select-String -Pattern "SHA1:"
    $sha1Match = $null
    if ($sha1Line) {
        $sha1Match = ($sha1Line -split "SHA1:")[1].Trim()
    }
    
    if ($sha1Match) {
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  SHA-1 Fingerprint:" -ForegroundColor Green
        Write-Host "  $sha1Match" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "📝 Copy this SHA-1 and add it to:" -ForegroundColor Cyan
        Write-Host "   1. Firebase Console > Project Settings > Your apps > com.spinel.tolstoy" -ForegroundColor Cyan
        Write-Host "   2. Google Cloud Console > APIs & Services > Credentials" -ForegroundColor Cyan
        Write-Host ""
    } else {
        Write-Host ""
        Write-Host "⚠️ Could not extract SHA-1 automatically. Please check the output above." -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error running keytool: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run this command manually:" -ForegroundColor Yellow
    Write-Host "$javaPath -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $keypass" -ForegroundColor White
}

