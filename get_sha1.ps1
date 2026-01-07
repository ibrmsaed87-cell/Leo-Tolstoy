# PowerShell script to get SHA-1 from keystore for Tolstoy app
# Usage: .\get_sha1.ps1

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  SHA-1 Fingerprint Extractor" -ForegroundColor Cyan
Write-Host "  App: Tolstoy" -ForegroundColor Cyan
Write-Host "  Package: com.spinel.tolstoy" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

$keystorePath = "android\app\upload-keystore.jks"
$alias = "upload"
$storepass = "dostoevsky2024"
$keypass = "dostoevsky2024"

# Try to find keytool
$keytoolPath = $null

# Check common Java locations
$locations = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jbr\bin\keytool.exe",
    "$env:LOCALAPPDATA\Android\Sdk\jre\bin\keytool.exe"
)

foreach ($loc in $locations) {
    if (Test-Path $loc) {
        $keytoolPath = $loc
        break
    }
}

# Try to find in Program Files
if (-not $keytoolPath) {
    $javaDirs = Get-ChildItem "$env:ProgramFiles\Java" -ErrorAction SilentlyContinue
    foreach ($dir in $javaDirs) {
        $kt = Join-Path $dir.FullName "bin\keytool.exe"
        if (Test-Path $kt) {
            $keytoolPath = $kt
            break
        }
    }
}

if (-not $keytoolPath) {
    Write-Host "❌ keytool not found automatically" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please run this command manually:" -ForegroundColor Yellow
    Write-Host "keytool -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $keypass" -ForegroundColor White
    Write-Host ""
    Write-Host "Or use Android Studio:" -ForegroundColor Yellow
    Write-Host "  Gradle > Tasks > android > signingReport" -ForegroundColor White
    exit 1
}

Write-Host "✅ Found keytool: $keytoolPath" -ForegroundColor Green
Write-Host ""

if (-not (Test-Path $keystorePath)) {
    Write-Host "❌ Keystore not found: $keystorePath" -ForegroundColor Red
    exit 1
}

Write-Host "📋 Extracting SHA-1..." -ForegroundColor Cyan
Write-Host ""

try {
    $result = & $keytoolPath -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $keypass 2>&1
    
    # Display output
    $result
    
    # Extract SHA-1
    $sha1Line = $result | Select-String -Pattern "SHA1:"
    if ($sha1Line) {
        $sha1 = ($sha1Line.ToString() -split "SHA1:")[1].Trim()
        Write-Host ""
        Write-Host "========================================" -ForegroundColor Green
        Write-Host "  SHA-1 Fingerprint:" -ForegroundColor Green
        Write-Host "  $sha1" -ForegroundColor Yellow
        Write-Host "========================================" -ForegroundColor Green
        Write-Host ""
        Write-Host "📝 Add this SHA-1 to Firebase Console:" -ForegroundColor Cyan
        Write-Host "   Project Settings > Your apps > com.spinel.tolstoy" -ForegroundColor White
        Write-Host ""
        
        # Try to copy to clipboard
        try {
            $sha1 | Set-Clipboard
            Write-Host "✅ SHA-1 copied to clipboard!" -ForegroundColor Green
        } catch {
            Write-Host "⚠️ Could not copy to clipboard" -ForegroundColor Yellow
        }
    } else {
        Write-Host ""
        Write-Host "⚠️ Could not extract SHA-1. Check output above." -ForegroundColor Yellow
    }
} catch {
    Write-Host "❌ Error: $_" -ForegroundColor Red
}
