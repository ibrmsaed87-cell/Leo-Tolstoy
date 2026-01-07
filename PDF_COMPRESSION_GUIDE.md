# دليل ضغط ملفات PDF لتقليل حجم التطبيق

## 📊 ملخص الملفات الكبيرة التي تحتاج ضغط:
- `anakatya2.pdf`: 12.11 MB
- `anakatya1.pdf`: 10.52 MB
- `alb3th.pdf`: 9.25 MB
- `msr3.pdf`: 7.81 MB
- `al7kayat.pdf`: 6.65 MB
- `trig.pdf`: 6.05 MB
- وغيرها...

---

## 🛠️ الطريقة 1: استخدام Ghostscript (الأفضل - مجاني ومفتوح المصدر)

### التثبيت على Windows:

1. **تحميل Ghostscript:**
   - اذهب إلى: https://www.ghostscript.com/download/gsdnld.html
   - حمّل النسخة المناسبة لنظامك (64-bit أو 32-bit)
   - ثبت البرنامج

2. **التحقق من التثبيت:**
   ```powershell
   gs --version
   ```

3. **ضغط ملف PDF واحد:**
   ```powershell
   gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile="compressed_output.pdf" "input.pdf"
   ```

4. **ضغط جميع ملفات PDF في مجلد:**
   ```powershell
   # انتقل إلى مجلد الكتب العربية
   cd assets\books\ar
   
   # ضغط جميع ملفات PDF
   Get-ChildItem -Filter "*.pdf" | ForEach-Object {
       $inputFile = $_.FullName
       $outputFile = $_.DirectoryName + "\compressed_" + $_.Name
       Write-Host "Compressing: $($_.Name)"
       gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile="$outputFile" "$inputFile"
   }
   ```

### مستويات الضغط في Ghostscript:

- **`/screen`**: أقل جودة، أصغر حجم (72 DPI)
- **`/ebook`**: جودة متوسطة، حجم معقول (150 DPI) ⭐ **موصى به**
- **`/printer`**: جودة عالية (300 DPI)
- **`/prepress`**: أعلى جودة (300 DPI، بدون ضغط)

### مثال بسيط لضغط ملف واحد:
```powershell
# ضغط anakatya1.pdf
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile="anakatya1_compressed.pdf" "anakatya1.pdf"
```

---

## 🛠️ الطريقة 2: استخدام أدوات GUI (سهلة الاستخدام)

### أ) PDF24 Creator (مجاني):
1. حمّل من: https://tools.pdf24.org/en/creator
2. افتح الملف
3. File → Save As → اختر "Optimize PDF"
4. احفظ الملف المضغوط

### ب) SmallPDF (أونلاين):
1. اذهب إلى: https://smallpdf.com/compress-pdf
2. ارفع الملف
3. اختر مستوى الضغط
4. حمّل الملف المضغوط

### ج) Adobe Acrobat (مدفوع):
1. افتح PDF في Acrobat
2. File → Save As Other → Optimized PDF
3. اختر إعدادات الضغط
4. احفظ

---

## 🛠️ الطريقة 3: استخدام Python (للأتمتة)

### تثبيت المكتبات:
```bash
pip install PyPDF2 pypdf
```

### سكريبت Python لضغط PDF:
```python
from pypdf import PdfWriter, PdfReader
import os

def compress_pdf(input_path, output_path):
    reader = PdfReader(input_path)
    writer = PdfWriter()
    
    for page in reader.pages:
        page.compress_content_streams()
        writer.add_page(page)
    
    with open(output_path, 'wb') as f:
        writer.write(f)
    
    # حساب نسبة الضغط
    original_size = os.path.getsize(input_path)
    compressed_size = os.path.getsize(output_path)
    reduction = (1 - compressed_size / original_size) * 100
    print(f"Compressed: {input_path}")
    print(f"Original: {original_size / 1024 / 1024:.2f} MB")
    print(f"Compressed: {compressed_size / 1024 / 1024:.2f} MB")
    print(f"Reduction: {reduction:.1f}%")
    print("-" * 50)

# ضغط جميع ملفات PDF في مجلد
import glob

pdf_files = glob.glob("assets/books/ar/*.pdf")
for pdf_file in pdf_files:
    output_file = pdf_file.replace(".pdf", "_compressed.pdf")
    compress_pdf(pdf_file, output_file)
```

---

## 🛠️ الطريقة 4: سكريبت PowerShell جاهز

### سكريبت لضغط جميع ملفات PDF:
```powershell
# ضغط جميع ملفات PDF في مجلد assets/books/ar
$sourceDir = "assets\books\ar"
$backupDir = "assets\books\ar\backup"

# إنشاء مجلد backup
if (-not (Test-Path $backupDir)) {
    New-Item -ItemType Directory -Path $backupDir
}

# الحصول على جميع ملفات PDF
$pdfFiles = Get-ChildItem -Path $sourceDir -Filter "*.pdf" -File

foreach ($pdf in $pdfFiles) {
    $inputFile = $pdf.FullName
    $outputFile = Join-Path $sourceDir "compressed_$($pdf.Name)"
    $backupFile = Join-Path $backupDir $pdf.Name
    
    Write-Host "Processing: $($pdf.Name)" -ForegroundColor Cyan
    Write-Host "  Original size: $([math]::Round($pdf.Length / 1MB, 2)) MB" -ForegroundColor Yellow
    
    # نسخ احتياطي
    Copy-Item $inputFile $backupFile
    
    # ضغط الملف
    gs -sDEVICE=pdfwrite `
       -dCompatibilityLevel=1.4 `
       -dPDFSETTINGS=/ebook `
       -dNOPAUSE `
       -dQUIET `
       -dBATCH `
       -sOutputFile="$outputFile" `
       "$inputFile"
    
    if (Test-Path $outputFile) {
        $compressedSize = (Get-Item $outputFile).Length
        $reduction = (1 - $compressedSize / $pdf.Length) * 100
        Write-Host "  Compressed size: $([math]::Round($compressedSize / 1MB, 2)) MB" -ForegroundColor Green
        Write-Host "  Reduction: $([math]::Round($reduction, 1))%" -ForegroundColor Green
        
        # استبدال الملف الأصلي بالملف المضغوط
        Remove-Item $inputFile
        Rename-Item $outputFile $inputFile
    }
    Write-Host ""
}

Write-Host "✅ Compression completed!" -ForegroundColor Green
Write-Host "Backups saved in: $backupDir" -ForegroundColor Cyan
```

---

## 📋 خطوات العمل الموصى بها:

### الخطوة 1: إنشاء نسخة احتياطية
```powershell
# نسخ جميع ملفات PDF إلى مجلد backup
Copy-Item -Path "assets\books\ar\*.pdf" -Destination "assets\books\ar\backup\" -Recurse
```

### الخطوة 2: ضغط ملف تجريبي واحد
```powershell
# اختبر على ملف واحد أولاً
gs -sDEVICE=pdfwrite -dCompatibilityLevel=1.4 -dPDFSETTINGS=/ebook -dNOPAUSE -dQUIET -dBATCH -sOutputFile="test_compressed.pdf" "anakatya1.pdf"
```

### الخطوة 3: التحقق من الجودة
- افتح الملف المضغوط
- تأكد من أن النص واضح
- تأكد من أن الصور مقبولة

### الخطوة 4: ضغط جميع الملفات
- استخدم السكريبت أعلاه لضغط جميع الملفات

### الخطوة 5: إعادة بناء التطبيق
```powershell
flutter clean
flutter pub get
flutter build apk --release
```

---

## ⚠️ ملاحظات مهمة:

1. **احتفظ بنسخة احتياطية**: دائماً احتفظ بنسخة من الملفات الأصلية
2. **اختبر الجودة**: تأكد من أن الملفات المضغوطة قابلة للقراءة
3. **جرب مستويات مختلفة**: إذا كانت `/ebook` لا تعطيك النتيجة المطلوبة، جرب `/screen`
4. **تحقق من الحجم**: بعد الضغط، تحقق من حجم الملفات الجديدة

---

## 🎯 النتيجة المتوقعة:

بعد الضغط، يمكنك توقع:
- **تقليل الحجم بنسبة 30-60%** اعتماداً على محتوى PDF
- **تقليل حجم APK من ~283 MB إلى ~150-200 MB**
- **الحفاظ على جودة مقبولة للقراءة**

---

## 🔧 استكشاف الأخطاء:

### مشكلة: "gs is not recognized"
**الحل**: تأكد من تثبيت Ghostscript وإضافته إلى PATH

### مشكلة: الملف المضغوط أكبر من الأصلي
**الحل**: قد يكون الملف مضغوطاً بالفعل، جرب `/screen` بدلاً من `/ebook`

### مشكلة: فقدان جودة الصور
**الحل**: استخدم `/printer` بدلاً من `/ebook` (لكن الحجم سيكون أكبر)

---

## 📞 مساعدة إضافية:

إذا واجهت أي مشاكل، يمكنك:
1. التحقق من أن Ghostscript مثبت بشكل صحيح
2. تجربة أدوات GUI مثل PDF24
3. استخدام أدوات أونلاين مثل SmallPDF

