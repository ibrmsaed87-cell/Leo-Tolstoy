# كيفية إصلاح خطأ SHA-1 في Firebase

## المشكلة
عند محاولة تسجيل الدخول بحساب Google، تظهر رسالة خطأ:
**"خطأ في الإعدادات: تأكد من إضافة SHA-1 في Firebase Console"**

## الحل

### الخطوة 1: الحصول على SHA-1 Fingerprint

#### الطريقة الأولى: استخدام Android Studio
1. افتح Android Studio
2. افتح المشروع: `android` folder
3. في الجانب الأيمن، افتح **Gradle** panel
4. اذهب إلى: `dostoyevsky_novels_app > Tasks > android > signingReport`
5. انقر نقراً مزدوجاً على `signingReport`
6. في نافذة Run، ابحث عن **SHA1** في قسم `Variant: release`
7. انسخ قيمة SHA1 (مثل: `AA:BB:CC:DD:EE:FF:...`)

#### الطريقة الثانية: استخدام Command Line
افتح Terminal في مجلد المشروع وقم بتشغيل:

**Windows:**
```bash
cd android
gradlew signingReport
```

**Mac/Linux:**
```bash
cd android
./gradlew signingReport
```

ابحث عن SHA1 في قسم `Variant: release`

#### الطريقة الثالثة: استخدام keytool مباشرة
```bash
keytool -list -v -keystore android/app/upload-keystore.jks -alias upload -storepass dostoevsky2024 -keypass dostoevsky2024
```

ابحث عن **SHA1** في المخرجات

### الخطوة 2: إضافة SHA-1 إلى Firebase Console

1. اذهب إلى [Firebase Console](https://console.firebase.google.com/)
2. اختر مشروعك: **audible-43582**
3. اذهب إلى **Project Settings** (⚙️ أيقونة الإعدادات)
4. في قسم **Your apps**، اختر تطبيق Android: **com.spinel.dostoevsky**
5. في قسم **SHA certificate fingerprints**، انقر على **Add fingerprint**
6. الصق قيمة SHA-1 التي حصلت عليها في الخطوة 1
7. انقر **Save**

### الخطوة 3: تحميل google-services.json المحدث

1. بعد إضافة SHA-1، انقر على **Download google-services.json**
2. استبدل الملف الموجود في: `android/app/google-services.json`
3. أعد بناء التطبيق:
   ```bash
   flutter clean
   flutter pub get
   flutter build appbundle --release
   ```

### الخطوة 4: اختبار تسجيل الدخول

1. شغّل التطبيق
2. جرّب تسجيل الدخول بحساب Google
3. يجب أن يعمل الآن بدون أخطاء

## ملاحظات مهمة

- **SHA-1 للـ Debug:** إذا كنت تختبر التطبيق في وضع التطوير، ستحتاج أيضاً إلى SHA-1 من debug keystore:
  ```bash
  keytool -list -v -keystore ~/.android/debug.keystore -alias androiddebugkey -storepass android -keypass android
  ```

- **SHA-256:** يمكنك أيضاً إضافة SHA-256 بنفس الطريقة (اختياري)

- **تأكد من Package Name:** يجب أن يكون Package Name في Firebase Console مطابقاً لـ: `com.spinel.dostoevsky`

## إذا استمرت المشكلة

1. تأكد من أن `google-services.json` محدث
2. تأكد من أن SHA-1 صحيح (بدون مسافات)
3. انتظر بضع دقائق بعد إضافة SHA-1 (قد يستغرق Firebase بعض الوقت)
4. أعد بناء التطبيق بالكامل (`flutter clean` ثم `flutter build`)



