# سكريبت PowerShell لضغط جميع ملفات PDF في مجلد assets/books/ar
# يتطلب تثبيت Ghostscript

param(
    [string]$SourceDir = "assets\books\ar",
    [string]$CompressionLevel = "ebook"  # screen, ebook, printer, prepress
)

Write-Host "========================================" -ForegroundColor Green
Write-Host "  PDF Compression Script" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# التحقق من وجود Ghostscript
$gsPath = Get-Command gs -ErrorAction SilentlyContinue
if (-not $gsPath) {
    Write-Host "❌ Error: Ghostscript not found!" -ForegroundColor Red
    Write-Host "Please install Ghostscript from: https://www.ghostscript.com/download/" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Or add Ghostscript to your PATH environment variable." -ForegroundColor Yellow
    exit 1
}

Write-Host "✅ Ghostscript found: $($gsPath.Source)" -ForegroundColor Green
Write-Host ""

# التحقق من وجود المجلد
if (-not (Test-Path $SourceDir)) {
    Write-Host "❌ Error: Directory not found: $SourceDir" -ForegroundColor Red
    exit 1
}

# إنشاء مجلد backup
$backupDir = Join-Path $SourceDir "backup_$(Get-Date -Format 'yyyyMMdd_HHmmss')"
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir | Out-Null
    Write-Host "📁 Created backup directory: $backupDir" -ForegroundColor Cyan
}

# الحصول على جميع ملفات PDF
$pdfFiles = Get-ChildItem -Path $SourceDir -Filter "*.pdf" -File | Where-Object { $_.Name -notlike "compressed_*" }

if ($pdfFiles.Count -eq 0) {
    Write-Host "❌ No PDF files found in: $SourceDir" -ForegroundColor Red
    exit 1
}

Write-Host "📚 Found $($pdfFiles.Count) PDF file(s) to compress" -ForegroundColor Cyan
Write-Host "Compression level: $CompressionLevel" -ForegroundColor Cyan
Write-Host ""

$totalOriginalSize = 0
$totalCompressedSize = 0
$successCount = 0
$failedCount = 0

foreach ($pdf in $pdfFiles) {
    $inputFile = $pdf.FullName
    $outputFile = Join-Path $pdf.DirectoryName "compressed_$($pdf.Name)"
    $backupFile = Join-Path $backupDir $pdf.Name
    
    $originalSize = $pdf.Length
    $totalOriginalSize += $originalSize
    
    Write-Host "Processing: $($pdf.Name)" -ForegroundColor White
    Write-Host "  Original size: $([math]::Round($originalSize / 1MB, 2)) MB" -ForegroundColor Yellow
    
    try {
        # نسخ احتياطي
        Copy-Item $inputFile $backupFile -Force
        
        # ضغط الملف
        $gsArgs = @(
            "-sDEVICE=pdfwrite",
            "-dCompatibilityLevel=1.4",
            "-dPDFSETTINGS=/$CompressionLevel",
            "-dNOPAUSE",
            "-dQUIET",
            "-dBATCH",
            "-sOutputFile=`"$outputFile`"",
            "`"$inputFile`""
        )
        
        $process = Start-Process -FilePath "gs" -ArgumentList $gsArgs -Wait -NoNewWindow -PassThru
        
        if ($process.ExitCode -eq 0 -and (Test-Path $outputFile)) {
            $compressedSize = (Get-Item $outputFile).Length
            $totalCompressedSize += $compressedSize
            $reduction = (1 - $compressedSize / $originalSize) * 100
            
            Write-Host "  ✅ Compressed size: $([math]::Round($compressedSize / 1MB, 2)) MB" -ForegroundColor Green
            Write-Host "  📉 Reduction: $([math]::Round($reduction, 1))%" -ForegroundColor Green
            
            # استبدال الملف الأصلي بالملف المضغوط
            Remove-Item $inputFile -Force
            Rename-Item $outputFile $inputFile
            
            $successCount++
        } else {
            Write-Host "  ❌ Compression failed!" -ForegroundColor Red
            $failedCount++
        }
    } catch {
        Write-Host "  ❌ Error: $_" -ForegroundColor Red
        $failedCount++
    }
    
    Write-Host ""
}

# ملخص النتائج
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Compression Summary" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host "Total files processed: $($pdfFiles.Count)" -ForegroundColor Cyan
Write-Host "✅ Successful: $successCount" -ForegroundColor Green
Write-Host "❌ Failed: $failedCount" -ForegroundColor $(if ($failedCount -gt 0) { "Red" } else { "Green" })
Write-Host ""
Write-Host "Original total size: $([math]::Round($totalOriginalSize / 1MB, 2)) MB" -ForegroundColor Yellow
Write-Host "Compressed total size: $([math]::Round($totalCompressedSize / 1MB, 2)) MB" -ForegroundColor Green
if ($totalOriginalSize -gt 0) {
    $totalReduction = (1 - $totalCompressedSize / $totalOriginalSize) * 100
    Write-Host "Total reduction: $([math]::Round($totalReduction, 1))%" -ForegroundColor Green
    Write-Host "Space saved: $([math]::Round(($totalOriginalSize - $totalCompressedSize) / 1MB, 2)) MB" -ForegroundColor Green
}
Write-Host ""
Write-Host "📁 Backups saved in: $backupDir" -ForegroundColor Cyan
Write-Host ""
Write-Host "✅ Done!" -ForegroundColor Green

