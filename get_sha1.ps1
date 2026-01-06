# PowerShell script to get SHA-1 from keystore
# Usage: .\get_sha1.ps1

Write-Host "Getting SHA-1 from keystore..." -ForegroundColor Green
Write-Host ""

$keystorePath = "android\app\upload-keystore.jks"
$alias = "upload"
$storepass = "dostoevsky2024"
$keypass = "dostoevsky2024"

# Check if Java is available
$javaPath = Get-Command java -ErrorAction SilentlyContinue
if (-not $javaPath) {
    Write-Host "Error: Java is not found in PATH" -ForegroundColor Red
    Write-Host "Please install Java JDK or add it to PATH" -ForegroundColor Yellow
    exit 1
}

# Check if keystore exists
if (-not (Test-Path $keystorePath)) {
    Write-Host "Error: Keystore file not found at: $keystorePath" -ForegroundColor Red
    exit 1
}

Write-Host "Keystore found. Extracting SHA-1..." -ForegroundColor Yellow
Write-Host ""

# Try to find keytool
$keytoolPath = $null
$possiblePaths = @(
    "$env:JAVA_HOME\bin\keytool.exe",
    "$env:ProgramFiles\Java\*\bin\keytool.exe",
    "$env:ProgramFiles(x86)\Java\*\bin\keytool.exe"
)

foreach ($path in $possiblePaths) {
    $resolved = Resolve-Path $path -ErrorAction SilentlyContinue
    if ($resolved) {
        $keytoolPath = $resolved[0].Path
        break
    }
}

if (-not $keytoolPath) {
    # Try to find keytool in PATH
    $keytoolCmd = Get-Command keytool -ErrorAction SilentlyContinue
    if ($keytoolCmd) {
        $keytoolPath = $keytoolCmd.Path
    }
}

if (-not $keytoolPath) {
    Write-Host "Error: keytool not found" -ForegroundColor Red
    Write-Host ""
    Write-Host "Please use one of these methods:" -ForegroundColor Yellow
    Write-Host "1. Use Android Studio: Gradle > Tasks > android > signingReport" -ForegroundColor Cyan
    Write-Host "2. Use command: cd android && gradlew signingReport" -ForegroundColor Cyan
    Write-Host "3. Install Java JDK and add it to PATH" -ForegroundColor Cyan
    exit 1
}

# Run keytool
Write-Host "Using keytool: $keytoolPath" -ForegroundColor Gray
Write-Host ""

try {
    $output = & $keytoolPath -list -v -keystore $keystorePath -alias $alias -storepass $storepass -keypass $keypass 2>&1
    
    # Extract SHA1
    $sha1Line = $output | Select-String -Pattern "SHA1:"
    if ($sha1Line) {
        $sha1 = ($sha1Line -split "SHA1:")[1].Trim()
        Write-Host "=" * 60 -ForegroundColor Green
        Write-Host "SHA-1 Fingerprint:" -ForegroundColor Green
        Write-Host $sha1 -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "=" * 60 -ForegroundColor Green
        Write-Host ""
        Write-Host "Copy this SHA-1 and add it to Firebase Console:" -ForegroundColor Yellow
        Write-Host "1. Go to: https://console.firebase.google.com/" -ForegroundColor Cyan
        Write-Host "2. Select project: audible-43582" -ForegroundColor Cyan
        Write-Host "3. Go to Project Settings > Your apps > com.spinel.dostoevsky" -ForegroundColor Cyan
        Write-Host "4. Add fingerprint in 'SHA certificate fingerprints' section" -ForegroundColor Cyan
        Write-Host ""
        
        # Copy to clipboard if possible
        try {
            $sha1 | Set-Clipboard
            Write-Host "SHA-1 has been copied to clipboard!" -ForegroundColor Green
        } catch {
            Write-Host "Could not copy to clipboard. Please copy manually." -ForegroundColor Yellow
        }
    } else {
        Write-Host "Error: Could not extract SHA-1 from keystore output" -ForegroundColor Red
        Write-Host "Output:" -ForegroundColor Yellow
        $output
    }
} catch {
    Write-Host "Error running keytool: $_" -ForegroundColor Red
    Write-Host ""
    Write-Host "Alternative method:" -ForegroundColor Yellow
    Write-Host "cd android" -ForegroundColor Cyan
    Write-Host "gradlew signingReport" -ForegroundColor Cyan
}



