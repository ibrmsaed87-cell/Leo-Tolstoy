import 'dart:io';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:crypto/crypto.dart';
import 'dart:convert';

/// Service for downloading and caching PDF and EPUB files from URLs
class PdfDownloader {
  static const String _cacheDirName = 'downloaded_books';
  static const int _maxFileSize = 100 * 1024 * 1024; // 100 MB

  /// Get the cache directory for Arabic books
  static Future<Directory> _getCacheDirectory() async {
    final appDir = await getApplicationDocumentsDirectory();
    final cacheDir = Directory('${appDir.path}/$_cacheDirName');
    if (!await cacheDir.exists()) {
      await cacheDir.create(recursive: true);
    }
    return cacheDir;
  }

  /// Generate a hash from the novel title for file naming
  static String _getFileNameHash(String novelTitle) {
    final bytes = utf8.encode(novelTitle);
    final hash = sha256.convert(bytes);
    return hash.toString().substring(0, 16);
  }

  /// Get the cached file path for a novel (PDF or EPUB)
  static Future<String?> getCachedPdfPath(String novelTitle) async {
    try {
      final cacheDir = await _getCacheDirectory();
      // Try PDF first (for backward compatibility)
      final pdfFileName = '${_getFileNameHash(novelTitle)}.pdf';
      final pdfFile = File('${cacheDir.path}/$pdfFileName');
      if (await pdfFile.exists()) {
        return pdfFile.path;
      }
      // Try EPUB
      final epubFileName = '${_getFileNameHash(novelTitle)}.epub';
      final epubFile = File('${cacheDir.path}/$epubFileName');
      if (await epubFile.exists()) {
        return epubFile.path;
      }
      return null;
    } catch (e) {
      print('Error getting cached file path: $e');
      return null;
    }
  }

  /// Get cached file path with specific extension
  static Future<String?> getCachedFilePath(String novelTitle, String extension) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = '${_getFileNameHash(novelTitle)}.$extension';
      final file = File('${cacheDir.path}/$fileName');
      if (await file.exists()) {
        return file.path;
      }
      return null;
    } catch (e) {
      print('Error getting cached file path: $e');
      return null;
    }
  }

  /// Check if PDF is cached locally
  static Future<bool> isPdfCached(String novelTitle) async {
    final cachedPath = await getCachedPdfPath(novelTitle);
    return cachedPath != null;
  }

  /// Download book (PDF or EPUB) from URL with progress callback
  static Future<Uint8List?> downloadBookFromUrl(
    String url,
    String novelTitle,
    String fileExtension, {
    Function(double progress)? onProgress,
    Function()? onCancel,
  }) async {
    http.Client? client;
    try {
      // Check internet connectivity
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        throw Exception('لا يوجد اتصال بالإنترنت');
      }

      // Check if already cached
      final cachedPath = await getCachedFilePath(novelTitle, fileExtension);
      if (cachedPath != null) {
        final file = File(cachedPath);
        final bytes = await file.readAsBytes();
        // Report 100% progress if cached
        if (onProgress != null) {
          onProgress(1.0);
        }
        return bytes;
      }

      // Download from URL using streamed request for progress tracking
      client = http.Client();
      final request = http.Request('GET', Uri.parse(url));
      if (fileExtension == 'pdf') {
        request.headers['Accept'] = 'application/pdf';
      } else if (fileExtension == 'epub') {
        request.headers['Accept'] = 'application/epub+zip';
      }
      
      final streamedResponse = await client.send(request).timeout(
        const Duration(minutes: 10),
        onTimeout: () {
          throw Exception('انتهت مهلة التحميل');
        },
      );

      if (streamedResponse.statusCode != 200) {
        throw Exception('فشل تحميل الملف: ${streamedResponse.statusCode}');
      }

      // Get content length for progress calculation
      final contentLength = streamedResponse.contentLength ?? 0;
      if (contentLength > _maxFileSize) {
        throw Exception('حجم الملف كبير جداً');
      }

      // Read stream in chunks and track progress
      final bytes = <int>[];
      int downloadedBytes = 0;
      int lastProgressPercent = -1; // Track last reported progress percentage
      int lastProgressUpdateBytes = 0; // Track bytes at last update
      
      await for (final chunk in streamedResponse.stream) {
        bytes.addAll(chunk);
        downloadedBytes += chunk.length;
        
        // Update progress if callback is provided
        if (onProgress != null && contentLength > 0) {
          final progress = downloadedBytes / contentLength;
          final progressPercent = (progress * 100).toInt();
          
          // Update progress if:
          // 1. Progress percentage changed (every 1%)
          // 2. Or at least 50KB downloaded since last update
          final bytesSinceLastUpdate = downloadedBytes - lastProgressUpdateBytes;
          if (progressPercent != lastProgressPercent || bytesSinceLastUpdate >= 50 * 1024) {
            onProgress(progress.clamp(0.0, 1.0));
            lastProgressPercent = progressPercent;
            lastProgressUpdateBytes = downloadedBytes;
          }
        } else if (onProgress != null && contentLength == 0) {
          // If content length is unknown, update every 50KB downloaded
          final bytesSinceLastUpdate = downloadedBytes - lastProgressUpdateBytes;
          if (bytesSinceLastUpdate >= 50 * 1024) {
            // Show indeterminate progress (oscillate between 30% and 70%)
            final indeterminateProgress = 0.3 + (downloadedBytes % (100 * 1024)) / (100 * 1024) * 0.4;
            onProgress(indeterminateProgress);
            lastProgressUpdateBytes = downloadedBytes;
          }
        }
      }

      final uint8List = Uint8List.fromList(bytes);

      // Validate file signature based on extension
      if (fileExtension == 'pdf') {
        if (uint8List.length < 4 || 
            uint8List[0] != 0x25 || // %
            uint8List[1] != 0x50 || // P
            uint8List[2] != 0x44 || // D
            uint8List[3] != 0x46) { // F
          throw Exception('الملف ليس ملف PDF صحيح');
        }
      } else if (fileExtension == 'epub') {
        // EPUB files are ZIP files, check ZIP signature
        if (uint8List.length < 4 || 
            uint8List[0] != 0x50 || // P
            uint8List[1] != 0x4B || // K
            (uint8List[2] != 0x03 && uint8List[2] != 0x05 && uint8List[2] != 0x07) ||
            (uint8List[3] != 0x04 && uint8List[3] != 0x06 && uint8List[3] != 0x08)) {
          throw Exception('الملف ليس ملف EPUB صحيح');
        }
      }

      // Report 100% progress before saving
      if (onProgress != null) {
        onProgress(1.0);
      }

      // Save to cache
      await _saveToCache(novelTitle, uint8List, fileExtension);

      return uint8List;
    } catch (e) {
      print('Error downloading PDF: $e');
      rethrow;
    } finally {
      client?.close();
    }
  }

  /// Save book bytes to cache
  static Future<void> _saveToCache(String novelTitle, Uint8List bytes, String extension) async {
    try {
      final cacheDir = await _getCacheDirectory();
      final fileName = '${_getFileNameHash(novelTitle)}.$extension';
      final file = File('${cacheDir.path}/$fileName');
      await file.writeAsBytes(bytes);
    } catch (e) {
      print('Error saving to cache: $e');
    }
  }

  /// Download PDF from URL with progress callback (backward compatibility)
  static Future<Uint8List?> downloadPdfFromUrl(
    String url,
    String novelTitle, {
    Function(double progress)? onProgress,
    Function()? onCancel,
  }) async {
    return downloadBookFromUrl(url, novelTitle, 'pdf', onProgress: onProgress, onCancel: onCancel);
  }

  /// Delete cached PDF
  static Future<bool> deleteCachedPdf(String novelTitle) async {
    try {
      final cachedPath = await getCachedPdfPath(novelTitle);
      if (cachedPath != null) {
        final file = File(cachedPath);
        await file.delete();
        return true;
      }
      return false;
    } catch (e) {
      print('Error deleting cached PDF: $e');
      return false;
    }
  }

  /// Get cached file size
  static Future<int?> getCachedFileSize(String novelTitle) async {
    try {
      final cachedPath = await getCachedPdfPath(novelTitle);
      if (cachedPath != null) {
        final file = File(cachedPath);
        return await file.length();
      }
      return null;
    } catch (e) {
      print('Error getting file size: $e');
      return null;
    }
  }

  /// Clear all cached PDFs
  static Future<void> clearAllCache() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (await cacheDir.exists()) {
        await cacheDir.delete(recursive: true);
        await cacheDir.create(recursive: true);
      }
    } catch (e) {
      print('Error clearing cache: $e');
    }
  }

  /// Get total cache size
  static Future<int> getTotalCacheSize() async {
    try {
      final cacheDir = await _getCacheDirectory();
      if (!await cacheDir.exists()) {
        return 0;
      }

      int totalSize = 0;
      await for (final entity in cacheDir.list()) {
        if (entity is File) {
          totalSize += await entity.length();
        }
      }
      return totalSize;
    } catch (e) {
      print('Error getting total cache size: $e');
      return 0;
    }
  }
}


