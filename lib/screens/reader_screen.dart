import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:epub_view/epub_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:path_provider/path_provider.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

import '../models/novel.dart';
import '../utils/ad_helper.dart';
import '../utils/pdf_downloader.dart';

enum ReaderThemeMode { light, sepia, dark }

class ReaderScreen extends StatefulWidget {
  final Novel novel;
  const ReaderScreen({super.key, required this.novel});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  EpubController? _controller;
  PdfViewerController? _pdfController;
  bool _chromeVisible = true;
  double _fontSize = 20;
  ReaderThemeMode _themeMode = ReaderThemeMode.sepia;
  bool _isLoading = true;
  String? _errorMessage;
  int? _lastChapterIndex; // Track last chapter to detect chapter completion
  bool _isPdf = false; // Track if file is PDF
  Uint8List? _pdfBytes; // Store PDF bytes
  bool _isDownloading = false; // Track if downloading from URL
  double _downloadProgress = 0.0; // Download progress (0.0 - 1.0)
  bool _downloadCancelled = false; // Track if download was cancelled

  final ScreenshotController _screenshot = ScreenshotController();
  late AudioPlayer _audioPlayer;
  bool isPlaying = false;
  SharedPreferences? _prefs;
  InterstitialAd? _interstitialAd;
  RewardedAd? _rewardedAd;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isInterstitialAdReady = false;
  bool _isRewardedInterstitialAdReady = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _loadSettings();
    // Load book first, then load ads after book is successfully loaded
    _initReader();
    // Note: Ad loading will be triggered after book is loaded in _initReader
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    // Load music state preference (but don't auto-play)
    // User must manually toggle music on/off
  }

  @override
  void dispose() {
    // Stop music before disposing
    if (isPlaying) {
      _audioPlayer.stop();
    }
    _audioPlayer.dispose();
    _controller?.dispose();
    _pdfController?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    super.dispose();
  }

  /// Load book (PDF or EPUB) from URL
  Future<void> _loadFromUrl() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _isDownloading = true;
      _downloadProgress = 0.0;
      _downloadCancelled = false;
      _errorMessage = null;
    });

    try {
      final downloadUrl = widget.novel.downloadUrl!;
      final novelTitle = widget.novel.title;
      
      // Determine file type from URL
      final urlLower = downloadUrl.toLowerCase();
      final isPdfFile = urlLower.endsWith('.pdf');
      final fileExtension = isPdfFile ? 'pdf' : 'epub';
      
      debugPrint("📥 [DOWNLOAD] Starting download for: $novelTitle");
      debugPrint("📥 [DOWNLOAD] URL: $downloadUrl");
      debugPrint("📥 [DOWNLOAD] File type: $fileExtension");
      
      // Check if already cached
      final cachedPath = await PdfDownloader.getCachedPdfPath(novelTitle);
      if (cachedPath != null) {
        debugPrint("✅ [DOWNLOAD] File found in cache: $cachedPath");
        final file = File(cachedPath);
        final bytes = await file.readAsBytes();
        
        if (!mounted) return;
        
        if (isPdfFile) {
          setState(() {
            _isPdf = true;
            _pdfBytes = bytes;
            _isDownloading = false;
            _isLoading = false;
          });
          // Initialize PDF viewer
          _pdfController = PdfViewerController();
        } else {
          // Handle EPUB
          setState(() {
            _isPdf = false;
            _isDownloading = false;
            _isLoading = false;
          });
          // Parse EPUB
          final epubBook = await EpubDocument.openData(bytes);
          _controller = EpubController(
            document: Future.value(epubBook),
            epubCfi: _prefs?.getString('cfi_$novelTitle'),
          );
        }
        return;
      }
      
      // Download from URL
      debugPrint("📥 [DOWNLOAD] Downloading from URL...");
      final bytes = await PdfDownloader.downloadBookFromUrl(
        downloadUrl,
        novelTitle,
        fileExtension,
        onProgress: (progress) {
          if (mounted && !_downloadCancelled) {
            setState(() {
              _downloadProgress = progress;
            });
          }
        },
        onCancel: () {
          if (mounted) {
            setState(() {
              _downloadCancelled = true;
            });
          }
        },
      );
      
      if (_downloadCancelled) {
        debugPrint("⚠️ [DOWNLOAD] Download cancelled by user");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _isDownloading = false;
          });
        }
        return;
      }
      
      if (bytes == null) {
        throw Exception('فشل تحميل الملف');
      }
      
      debugPrint("✅ [DOWNLOAD] Download completed: ${bytes.length} bytes");
      
      if (!mounted) return;
      
      if (isPdfFile) {
        setState(() {
          _isPdf = true;
          _pdfBytes = bytes;
          _isDownloading = false;
          _isLoading = false;
          _downloadProgress = 1.0;
        });
        // Initialize PDF viewer
        _pdfController = PdfViewerController();
      } else {
        // Handle EPUB
        setState(() {
          _isPdf = false;
          _isDownloading = false;
          _isLoading = false;
          _downloadProgress = 1.0;
        });
        // Parse EPUB
        final epubBook = await EpubDocument.openData(bytes);
        _controller = EpubController(
          document: Future.value(epubBook),
          epubCfi: _prefs?.getString('cfi_$novelTitle'),
        );
      }
      
    } catch (e) {
      debugPrint("❌ [DOWNLOAD] Error: $e");
      if (!mounted) return;
      
      final locale = Localizations.localeOf(context);
      final isAr = locale.languageCode == 'ar';
      final isRu = locale.languageCode == 'ru';
      
      String errorMsg;
      if (isAr) {
        errorMsg = '❌ فشل تحميل الرواية\n\n'
            'الرواية: ${widget.novel.title}\n\n'
            '${e.toString()}\n\n'
            'يرجى التحقق من اتصال الإنترنت والمحاولة مرة أخرى';
      } else if (isRu) {
        errorMsg = '❌ Ошибка загрузки романа\n\n'
            'Роман: ${widget.novel.title}\n\n'
            '${e.toString()}';
      } else {
        errorMsg = '❌ Failed to download novel\n\n'
            'Novel: ${widget.novel.title}\n\n'
            '${e.toString()}';
      }
      
      setState(() {
        _isLoading = false;
        _isDownloading = false;
        _errorMessage = errorMsg;
      });
    }
  }

  Future<void> _initReader() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    // Step 1: Load settings (independent of book loading)
    try {
      _prefs = await SharedPreferences.getInstance();
      if (!mounted) return;
      setState(() {
        _fontSize = _prefs?.getDouble('f_size') ?? 20;
        _themeMode = ReaderThemeMode.values[_prefs?.getInt('t_mode') ?? 1];
      });
    } catch (e) {
      debugPrint('⚠️ Warning: Error loading settings: $e');
      // Continue even if settings fail
    }

    // Step 2: Load file from assets or download from URL (CRITICAL - must succeed)
    // Check if this is an Arabic novel with download URL
    final isArabicNovel = widget.novel.downloadUrl != null && 
                          widget.novel.downloadUrl!.isNotEmpty;
    
    if (isArabicNovel) {
      // Arabic novel - download from URL
      await _loadFromUrl();
      return;
    }
    
    // English/Russian novel - load from assets
    // Check if file is PDF or EPUB
    final assetPath = widget.novel.assetFilePath;
    
    // Force specific novels to be read as EPUB (regardless of extension)
    final forcedEpubNovels = [
      'الحرب والسلم',
      'الحرب والسلم الكتاب الأول',
      'الحرب والسلم الكتاب الثاني',
      'الحرب والسلم الكتاب الثالث',
      'الحرب والسلم الكتاب الرابع',
      'حِكَم النَّبي مُحَمَّد',
      'بدائع الخيال',
      'اعترافات تولستوي',
      'إنجيل تولستوي وديانته',
      'مملكة جهنم والخمر',
    ];
    
    // Force specific file paths to be read as EPUB
    final forcedEpubPaths = [
      'al7rb1.epub',
      'al7rb2.epub',
      'al7rb3.epub',
      'al7rb4.epub',
      'moh.epub',
      'bda2a.epub',
      'a3trafat.epub',
      'engel.epub',
      'jhanam.epub',
    ];
    
    final isForcedEpubByTitle = forcedEpubNovels.contains(widget.novel.title);
    final isForcedEpubByPath = forcedEpubPaths.any((path) => assetPath.contains(path));
    
    // Determine file type: force EPUB for specific novels, otherwise check extension
    if (isForcedEpubByTitle || isForcedEpubByPath) {
      _isPdf = false; // Force EPUB
      debugPrint("🔒 [BOOK LOADING] Forcing EPUB format for: ${widget.novel.title}");
      debugPrint("🔒 [BOOK LOADING] File path: $assetPath");
    } else {
      _isPdf = assetPath.toLowerCase().endsWith('.pdf');
    }
    
    debugPrint("📚 [BOOK LOADING] Starting ${_isPdf ? 'PDF' : 'EPUB'} file load...");
    debugPrint("📚 [BOOK LOADING] Novel: ${widget.novel.title}");

    // Validate path before attempting to load
    debugPrint("📚 [BOOK LOADING] Asset path: '$assetPath'");

    if (assetPath.isEmpty) {
      debugPrint("❌ [BOOK LOADING] ERROR: Asset path is empty!");
      debugPrint("❌ [BOOK LOADING] Novel title: ${widget.novel.title}");
      if (!mounted) return;
      final locale = Localizations.localeOf(context);
      final isAr = locale.languageCode == 'ar';
      final isRu = locale.languageCode == 'ru';

      String errorMsg;
      if (isAr) {
        errorMsg = '❌ خطأ: مسار الملف فارغ\n\nالرواية: ${widget.novel.title}';
      } else if (isRu) {
        errorMsg =
            '❌ Ошибка: путь к файлу пуст\n\nРоман: ${widget.novel.title}';
      } else {
        errorMsg =
            '❌ Error: File path is empty\n\nNovel: ${widget.novel.title}';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });
      return;
    }

    debugPrint("📚 [BOOK LOADING] Asset path validated: '$assetPath'");
    debugPrint("📚 [BOOK LOADING] Attempting to load from rootBundle...");

    ByteData bytes;
    try {
      bytes = await rootBundle.load(assetPath);
      debugPrint("✅ [BOOK LOADING] ${_isPdf ? 'PDF' : 'EPUB'} file loaded successfully!");
      debugPrint("✅ [BOOK LOADING] File size: ${bytes.lengthInBytes} bytes");
      
      // Additional validation for EPUB files
      if (!_isPdf && bytes.lengthInBytes == 0) {
        throw Exception("EPUB file is empty");
      }
      
      // Check if EPUB file starts with correct signature (ZIP file signature)
      if (!_isPdf) {
        final signature = bytes.buffer.asUint8List().take(4).toList();
        final isValidEpub = signature[0] == 0x50 && signature[1] == 0x4B && 
                           (signature[2] == 0x03 || signature[2] == 0x05 || signature[2] == 0x07) &&
                           (signature[3] == 0x04 || signature[3] == 0x06 || signature[3] == 0x08);
        if (!isValidEpub) {
          debugPrint("⚠️ [BOOK LOADING] EPUB file signature check failed");
          debugPrint("⚠️ [BOOK LOADING] First 4 bytes: ${signature.map((b) => '0x${b.toRadixString(16).padLeft(2, '0')}').join(' ')}");
        } else {
          debugPrint("✅ [BOOK LOADING] EPUB file signature validated");
        }
      }
    } catch (loadError) {
      debugPrint("❌ [BOOK LOADING] ERROR loading ${_isPdf ? 'PDF' : 'EPUB'} file!");
      debugPrint("❌ [BOOK LOADING] Error type: ${loadError.runtimeType}");
      debugPrint("❌ [BOOK LOADING] Error message: $loadError");
      debugPrint("❌ [BOOK LOADING] Attempted path: '$assetPath'");
      debugPrint("❌ [BOOK LOADING] Novel title: ${widget.novel.title}");

      // Check for specific error types
      final errorString = loadError.toString().toLowerCase();
      if (errorString.contains('unable to load asset') ||
          errorString.contains('not found') ||
          errorString.contains('asset not found')) {
        debugPrint(
          "❌ [BOOK LOADING] DIAGNOSIS: Asset file not found in bundle",
        );
        debugPrint("❌ [BOOK LOADING] Please check:");
        debugPrint("   1. File exists in assets/books/ folder");
        debugPrint(
          "   2. pubspec.yaml includes 'assets/books/' in assets section",
        );
        debugPrint("   3. Run 'flutter pub get' and rebuild the app");
        debugPrint("   4. Path matches exactly (case-sensitive): '$assetPath'");
      } else {
        debugPrint("❌ [BOOK LOADING] DIAGNOSIS: Unknown error loading asset");
      }

      // This is a path/asset issue - file not found
      if (!mounted) return;
      final locale = Localizations.localeOf(context);
      final isAr = locale.languageCode == 'ar';
      final isRu = locale.languageCode == 'ru';

      String errorMsg;
      if (isAr) {
        errorMsg =
            '❌ الملف غير موجود في التطبيق\n\n'
            'الرواية: ${widget.novel.title}\n'
            'المسار: ${widget.novel.assetFilePath}\n\n'
            'يرجى التحقق من أن الملف موجود في مجلد assets/books/';
      } else if (isRu) {
        errorMsg =
            '❌ Файл не найден в приложении\n\n'
            'Роман: ${widget.novel.title}\n'
            'Путь: ${widget.novel.assetFilePath}\n\n'
            'Пожалуйста, убедитесь, что файл находится в папке assets/books/';
      } else {
        errorMsg =
            '❌ File not found in app\n\n'
            'Novel: ${widget.novel.title}\n'
            'Path: ${widget.novel.assetFilePath}\n\n'
            'Please ensure the file exists in assets/books/ folder';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });
      return; // Stop here - cannot proceed without file
    }

    // Step 3: Convert ByteData to Uint8List correctly
    debugPrint("📚 [BOOK LOADING] Converting ByteData to Uint8List...");
    Uint8List fileBytes;
    try {
      fileBytes = bytes.buffer.asUint8List();
      debugPrint("✅ [BOOK LOADING] Converted to Uint8List successfully!");
      debugPrint("✅ [BOOK LOADING] Uint8List size: ${fileBytes.length} bytes");
    } catch (conversionError) {
      debugPrint("❌ Error converting ByteData to Uint8List: $conversionError");
      if (!mounted) return;
      final locale = Localizations.localeOf(context);
      final isAr = locale.languageCode == 'ar';
      final isRu = locale.languageCode == 'ru';

      String errorMsg;
      if (isAr) {
        errorMsg = '❌ خطأ في معالجة الملف\n\nالرواية: ${widget.novel.title}';
      } else if (isRu) {
        errorMsg = '❌ Ошибка обработки файла\n\nРоман: ${widget.novel.title}';
      } else {
        errorMsg = '❌ Error processing file\n\nNovel: ${widget.novel.title}';
      }

      setState(() {
        _isLoading = false;
        _errorMessage = errorMsg;
      });
      return;
    }

    // Step 4: Handle PDF or EPUB differently
    if (_isPdf) {
      // Handle PDF
      debugPrint("📚 [BOOK LOADING] Processing PDF file...");
      try {
        _pdfBytes = fileBytes;
        _pdfController = PdfViewerController();
        debugPrint("✅ [BOOK LOADING] PDF controller created successfully!");
      } catch (parseError) {
        debugPrint("❌ Error processing PDF: $parseError");
        if (!mounted) return;
        final locale = Localizations.localeOf(context);
        final isAr = locale.languageCode == 'ar';
        final isRu = locale.languageCode == 'ru';

        String errorMsg;
        if (isAr) {
          errorMsg = '❌ حدث خطأ في قراءة الملف\n\nالرواية: ${widget.novel.title}';
        } else if (isRu) {
          errorMsg = '❌ Произошла ошибка при чтении файла\n\nРоман: ${widget.novel.title}';
        } else {
          errorMsg = '❌ Error reading file\n\nNovel: ${widget.novel.title}';
        }

        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
        return;
      }
    } else {
      // Handle EPUB
      debugPrint("📚 [BOOK LOADING] Parsing EPUB document...");
      final initialCfi = _prefs?.getString('cfi_${widget.novel.title}');
      debugPrint("📚 [BOOK LOADING] Initial CFI: ${initialCfi ?? 'null'}");

      try {
        // Validate EPUB file before parsing
        if (fileBytes.isEmpty) {
          throw Exception("EPUB file is empty");
        }
        
        debugPrint("📚 [BOOK LOADING] EPUB file bytes: ${fileBytes.length} bytes");
        debugPrint("📚 [BOOK LOADING] First 10 bytes: ${fileBytes.take(10).map((b) => b.toRadixString(16).padLeft(2, '0')).join(' ')}");
        
        // EpubDocument.openData returns a Future<EpubBook>
        // EpubController expects Future<EpubBook>, so we pass the Future directly
        debugPrint("📚 [BOOK LOADING] Starting EPUB document parsing...");
        
        // Create the document future
        final documentFuture = EpubDocument.openData(fileBytes);
        debugPrint("📚 [BOOK LOADING] EPUB document parsing started...");

        // Wait for document to be ready before creating controller
        // This ensures we catch any parsing errors early
        final epubBook = await documentFuture.timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            throw TimeoutException("EPUB parsing timed out after 30 seconds");
          },
        );
        
        debugPrint("✅ [BOOK LOADING] EPUB document parsed successfully!");
        try {
          final title = epubBook.Title ?? 'Unknown';
          final chaptersCount = epubBook.Chapters?.length ?? 0;
          debugPrint("✅ [BOOK LOADING] EPUB title: $title");
          debugPrint("✅ [BOOK LOADING] EPUB chapters: $chaptersCount");
        } catch (e) {
          debugPrint("⚠️ [BOOK LOADING] Could not read EPUB metadata: $e");
          // Continue even if metadata reading fails
        }

        // Create controller with the parsed book
        _controller = EpubController(
          document: Future.value(epubBook),
          epubCfi: initialCfi,
        );
        debugPrint("✅ [BOOK LOADING] EPUB controller created successfully!");
      } catch (parseError) {
        debugPrint("❌ Error parsing EPUB document: $parseError");
        debugPrint("❌ File size: ${fileBytes.length} bytes");
        debugPrint("❌ Error type: ${parseError.runtimeType}");
        if (parseError is Error) {
          debugPrint("❌ Stack trace: ${parseError.stackTrace}");
        }

        // This is a parsing/corruption issue
        if (!mounted) return;
      final locale = Localizations.localeOf(context);
      final isAr = locale.languageCode == 'ar';
      final isRu = locale.languageCode == 'ru';

      String errorMsg;
      if (parseError.toString().contains('corrupt') ||
          parseError.toString().contains('invalid')) {
        if (isAr) {
          errorMsg =
              '❌ الملف تالف أو غير صالح\n\n'
              'الرواية: ${widget.novel.title}\n'
              'يرجى التحقق من الملف أو إعادة تثبيت التطبيق';
        } else if (isRu) {
          errorMsg =
              '❌ Файл повреждён или недействителен\n\n'
              'Роман: ${widget.novel.title}\n'
              'Пожалуйста, проверьте файл или переустановите приложение';
        } else {
          errorMsg =
              '❌ File is corrupted or invalid\n\n'
              'Novel: ${widget.novel.title}\n'
              'Please check the file or reinstall the app';
        }
      } else {
        if (isAr) {
          errorMsg =
              '❌ حدث خطأ في قراءة الرواية\n\n'
              'الرواية: ${widget.novel.title}\n'
              'الملف قد يكون تالفاً';
        } else if (isRu) {
          errorMsg =
              '❌ Произошла ошибка при чтении романа\n\n'
              'Роман: ${widget.novel.title}\n'
              'Файл может быть повреждён';
        } else {
          errorMsg =
              '❌ Error reading book\n\n'
              'Novel: ${widget.novel.title}\n'
              'The file may be corrupted';
        }
      }

        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
        return; // Stop here - cannot proceed without valid controller
      }
    }

    // Step 5: Add CFI listener for EPUB ONLY after controller is created and ready
    if (!_isPdf) {
      // Wait a bit to ensure controller is fully initialized
      await Future.delayed(const Duration(milliseconds: 100));

      if (!mounted || _controller == null) return;

      try {
        _controller!.currentValueListenable.addListener(_saveProgress);
        debugPrint("✅ CFI progress listener added");
      } catch (e) {
        debugPrint('⚠️ Warning: Error adding CFI listener: $e');
        // Continue even if listener fails - not critical
      }
    }

    // Step 6: Mark book as loaded successfully
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      _errorMessage = null;
    });
    debugPrint("✅✅✅ [BOOK LOADING] Book loaded successfully! ✅✅✅");
    debugPrint("✅ [BOOK LOADING] Novel: ${widget.novel.title}");
    debugPrint("✅ [BOOK LOADING] Controller ready: ${_controller != null}");

    // Step 7: Load ads AFTER book is successfully loaded
    // This ensures ad failures don't affect book loading
    debugPrint("📢 [AD LOADING] Starting ad loading (non-blocking)...");
    _loadInterstitialAd();
    _loadRewardedAd();
    _loadRewardedInterstitialAd();

    // Show ad after a delay (non-blocking)
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        debugPrint("📢 [AD LOADING] Attempting to show interstitial ad...");
        _waitAndShowInterstitialAd();
      }
    });
  }

  // Separate method for saving progress (CFI listener callback)
  void _saveProgress() async {
    if (_controller == null || _prefs == null) return;

    try {
      final cfi = _controller!.generateEpubCfi();
      if (cfi != null && cfi.isNotEmpty) {
        await _prefs!.setString('cfi_${widget.novel.title}', cfi);

        // Calculate and save progress based on CFI position
        // Since we can't easily parse CFI to get exact position, we use a simple approach:
        // If CFI exists and has been updated, mark as "in progress" (set to a small value like 0.1)
        // This indicates the user has started reading
        try {
          final existingProgress =
              _prefs?.getDouble('progress_${widget.novel.title}') ?? 0.0;
          // Only update if we haven't set a higher progress yet
          // This prevents progress from being reset to a lower value
          if (existingProgress < 0.1) {
            await _prefs!.setDouble('progress_${widget.novel.title}', 0.1);
          }
        } catch (e) {
          debugPrint('⚠️ Warning: Error calculating progress: $e');
        }
      }
    } catch (e) {
      debugPrint('⚠️ Warning: Error saving progress: $e');
      // Don't throw - this is not critical
    }
  }

  void _loadInterstitialAd() {
    debugPrint('📢 [AD LOADING] Loading Interstitial Ad...');
    AdHelper.createInterstitialAd(
      onAdLoaded: (ad) {
        debugPrint('✅✅✅ [AD LOADING] Interstitial Ad loaded successfully! ✅✅✅');
        if (mounted) {
          setState(() {
            _interstitialAd = ad;
            _isInterstitialAdReady = true;
          });
        }
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            debugPrint('📢 Interstitial Ad dismissed');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isInterstitialAdReady = false;
              });
            }
            _loadInterstitialAd(); // Load next ad
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint('❌ Interstitial Ad failed to show: $error');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isInterstitialAdReady = false;
              });
            }
            _loadInterstitialAd(); // Load next ad
          },
        );
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ [AD LOADING] Interstitial ad failed to load: $error');
        debugPrint('❌ [AD LOADING] Error code: ${error.code}');
        debugPrint('❌ [AD LOADING] Error message: ${error.message}');

        // Check if it's a network error
        final isNetworkError =
            error.code == 0 ||
            error.message.toLowerCase().contains('network') ||
            error.message.toLowerCase().contains('timeout') ||
            error.message.toLowerCase().contains('connection');

        if (isNetworkError) {
          debugPrint(
            '⚠️ [AD LOADING] Network error detected - will retry with longer delay',
          );
        }

        if (mounted) {
          setState(() {
            _isInterstitialAdReady = false;
          });
        }

        // Retry with longer delay for network errors
        final delaySeconds = isNetworkError ? 10 : 5;
        Future.delayed(Duration(seconds: delaySeconds), () {
          if (mounted) {
            debugPrint('🔄 [AD LOADING] Retrying to load Interstitial ad...');
            _loadInterstitialAd();
          }
        });
      },
      onAdClosed: () {
        debugPrint('📢 Interstitial Ad closed');
        if (mounted) {
          setState(() {
            _isInterstitialAdReady = false;
          });
        }
        _loadInterstitialAd(); // Load next ad
      },
    );
  }

  void _waitAndShowInterstitialAd() async {
    // Wait for ad to load (max 5 seconds)
    int attempts = 0;
    const maxAttempts = 25; // 25 * 200ms = 5 seconds

    while (attempts < maxAttempts) {
      await Future.delayed(const Duration(milliseconds: 200));
      if (!mounted) return;

      if (_isInterstitialAdReady && _interstitialAd != null) {
        debugPrint('✅ Interstitial Ad is ready, showing...');
        _showInterstitialAd();
        return;
      }
      attempts++;
    }

    // If ad didn't load in time, log it
    debugPrint(
      '⚠️ Interstitial Ad not ready after 5 seconds. Status: ready=$_isInterstitialAdReady, ad=${_interstitialAd != null}',
    );
  }

  void _showInterstitialAd() {
    if (_interstitialAd != null && _isInterstitialAdReady && mounted) {
      debugPrint('🎬 Showing Interstitial Ad...');
      _interstitialAd!.show();
      if (mounted) {
        setState(() {
          _isInterstitialAdReady = false;
        });
      }
    } else {
      debugPrint(
        '⚠️ Cannot show Interstitial Ad: ad=${_interstitialAd != null}, ready=$_isInterstitialAdReady, mounted=$mounted',
      );
    }
  }

  void _loadRewardedAd() {
    AdHelper.createRewardedAd(
      onAdLoaded: (ad) {
        _rewardedAd = ad;
        _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            ad.dispose();
            _loadRewardedAd(); // Load next ad
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            ad.dispose();
            _loadRewardedAd(); // Load next ad
          },
        );
      },
      onAdFailedToLoad: (error) {
        debugPrint('Rewarded ad failed to load: $error');
      },
      onUserEarnedReward: (ad, reward) {
        // Give user reward (e.g., remove ads for session, unlock feature)
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                widget.novel.title.contains('الجريمة') ||
                        widget.novel.title.contains('Crime')
                    ? 'شكراً لك! استمتع بالقراءة بدون إعلانات'
                    : 'Thank you! Enjoy ad-free reading',
              ),
              backgroundColor: Colors.green,
            ),
          );
        }
      },
    );
  }

  void _loadRewardedInterstitialAd() {
    debugPrint('📢 Loading Rewarded Interstitial Ad...');
    AdHelper.createRewardedInterstitialAd(
      onAdLoaded: (ad) {
        debugPrint('✅ Rewarded Interstitial Ad loaded successfully!');
        if (mounted) {
          setState(() {
            _rewardedInterstitialAd = ad;
            _isRewardedInterstitialAdReady = true;
          });
        }
        _rewardedInterstitialAd!.fullScreenContentCallback =
            FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('📢 Rewarded Interstitial Ad dismissed');
                ad.dispose();
                if (mounted) {
                  setState(() {
                    _isRewardedInterstitialAdReady = false;
                  });
                }
                _loadRewardedInterstitialAd(); // Load next ad
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ Rewarded Interstitial Ad failed to show: $error');
                ad.dispose();
                if (mounted) {
                  setState(() {
                    _isRewardedInterstitialAdReady = false;
                  });
                }
                _loadRewardedInterstitialAd(); // Load next ad
              },
            );
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ Rewarded Interstitial Ad failed to load: $error');
        if (mounted) {
          setState(() {
            _isRewardedInterstitialAdReady = false;
          });
        }
      },
    );
  }

  void _showRewardedInterstitialAd() {
    if (_rewardedInterstitialAd != null &&
        _isRewardedInterstitialAdReady &&
        mounted) {
      debugPrint('🎬 Showing Rewarded Interstitial Ad...');
      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('🎁 User earned reward: ${reward.amount} ${reward.type}');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  widget.novel.title.contains('الجريمة') ||
                          widget.novel.title.contains('Crime')
                      ? 'شكراً لك! حصلت على المكافأة'
                      : 'Thank you! You earned a reward',
                ),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
      if (mounted) {
        setState(() {
          _isRewardedInterstitialAdReady = false;
        });
      }
    } else {
      debugPrint(
        '⚠️ Cannot show Rewarded Interstitial Ad: ad=${_rewardedInterstitialAd != null}, ready=$_isRewardedInterstitialAdReady, mounted=$mounted',
      );
      _loadRewardedInterstitialAd();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري تحميل الإعلان... / Loading ad...'),
          ),
        );
      }
    }
  }


  // --- تم إصلاح هذه الدالة بالكامل ---
  void _openSearch() async {
    if (_controller == null) return;

    // 2. انتظر المستند أولاً
    final document = await _controller!.document;

    // 3. استخدم الحرف الكبير Chapters (الذي نجح معك)
    final chapters = document.Chapters ?? [];

    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: _getBgColor(),
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.8,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Column(
          children: [
            const Padding(
              padding: EdgeInsets.all(16.0),
              child: Text(
                "الفصول",
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: chapters.length,
                itemBuilder: (context, i) {
                  // Fix: Use chapters[i] instead of chapters[0] to show correct chapter title
                  final chapter = i < chapters.length ? chapters[i] : null;
                  return ListTile(
                    title: Text(
                      chapter?.Title ?? "فصل ${i + 1}",
                      style: TextStyle(
                        color: _themeMode == ReaderThemeMode.dark
                            ? Colors.white
                            : Colors.black,
                      ),
                    ),
                    onTap: () async {
                      final previousChapter = _lastChapterIndex;
                      _lastChapterIndex = i;
                      await _controller!.scrollTo(
                        index: i,
                      ); // نستخدم متغير الحلقة i كفهرس للفصل

                      // Check if widget is still mounted before using context
                      if (!mounted) return;
                      Navigator.pop(this.context);

                      // Show rewarded interstitial ad when completing a chapter
                      // (moving from one chapter to another)
                      if (previousChapter != null && previousChapter != i) {
                        Future.delayed(const Duration(milliseconds: 1000), () {
                          if (mounted) {
                            _showRewardedInterstitialAd();
                          }
                        });
                      }
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _shareSelectedTextAsImage() async {
    if (!mounted) return;
    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    final TextEditingController qController = TextEditingController();

    // محاولة قراءة النص المنسوخ من Clipboard أولاً
    String? clipboardText;
    try {
      final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
      clipboardText = clipboardData?.text?.trim();
      if (clipboardText != null && clipboardText.isNotEmpty) {
        // إذا وجد نص في الحافظة، ضعه في حقل النص مباشرة
        qController.text = clipboardText;
      }
    } catch (e) {
      debugPrint('Error reading clipboard: $e');
    }

    // Check if widget is still mounted before using context
    if (!mounted) return;
    // عرض dialog للكتابة أو اللصق
    final String? result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(isAr ? 'مشاركة النص كصورة' : 'Share Text as Image'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              isAr
                  ? 'حدد النص من الكتاب واضغط "نسخ"، ثم الصق هنا أو اكتب نصك المخصص'
                  : 'Select text from the book and press "Copy", then paste here or type your custom text',
              style: Theme.of(context).textTheme.bodySmall,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: qController,
              maxLines: 8,
              minLines: 4,
              autofocus: clipboardText == null || clipboardText.isEmpty,
              decoration: InputDecoration(
                hintText: isAr
                    ? 'الصق النص هنا أو اكتب...'
                    : 'Paste text here or type...',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  icon: const Icon(Icons.paste),
                  tooltip: isAr ? 'لصق من الحافظة' : 'Paste from clipboard',
                  onPressed: () async {
                    try {
                      final clipboardData = await Clipboard.getData(
                        Clipboard.kTextPlain,
                      );
                      if (clipboardData?.text != null) {
                        qController.text = clipboardData!.text!;
                        // Move cursor to end
                        qController.selection = TextSelection.fromPosition(
                          TextPosition(offset: qController.text.length),
                        );
                      }
                    } catch (e) {
                      debugPrint('Error pasting from clipboard: $e');
                    }
                  },
                ),
              ),
            ),
            if (clipboardText != null && clipboardText.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text(
                  isAr
                      ? '✓ تم لصق النص من الحافظة'
                      : '✓ Text pasted from clipboard',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.green,
                    fontSize: 12,
                  ),
                ),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(isAr ? 'إلغاء' : 'Cancel'),
          ),
          FilledButton.icon(
            onPressed: () {
              final text = qController.text.trim();
              if (text.isNotEmpty) {
                Navigator.pop(context, text);
              } else {
                // Show error if text is empty
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      isAr
                          ? 'يرجى إدخال نص للمشاركة'
                          : 'Please enter text to share',
                    ),
                    duration: const Duration(seconds: 2),
                  ),
                );
              }
            },
            icon: const Icon(Icons.share),
            label: Text(isAr ? 'إنشاء صورة ومشاركة' : 'Create & Share Image'),
          ),
        ],
      ),
    );

    if (result != null && result.isNotEmpty) {
      await _createAndShareImage(result);
    }
  }

  Future<void> _createAndShareImage(String text) async {
    if (!mounted) return;

    final isAr = Localizations.localeOf(context).languageCode == 'ar';

    // إظهار loading indicator
    if (!mounted) return;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );

    try {
      final image = await _screenshot.captureFromWidget(
        Container(
          width: MediaQuery.of(context).size.width * 0.9,
          padding: const EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: _getBgColor(),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: _themeMode == ReaderThemeMode.dark
                  ? Colors.white24
                  : Colors.black12,
              width: 2,
            ),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(
                Icons.format_quote_rounded,
                size: 48,
                color: _themeMode == ReaderThemeMode.dark
                    ? Colors.white70
                    : Colors.black54,
              ),
              const SizedBox(height: 24),
              Text(
                text,
                textAlign: TextAlign.center,
                style: GoogleFonts.playfairDisplay(
                  fontSize: 24,
                  height: 1.6,
                  color: _themeMode == ReaderThemeMode.dark
                      ? Colors.white
                      : Colors.black87,
                ),
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: _themeMode == ReaderThemeMode.dark
                      ? Colors.white12
                      : Colors.black12,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '- ${widget.novel.title}',
                  style: GoogleFonts.playfairDisplay(
                    fontSize: 16,
                    fontStyle: FontStyle.italic,
                    color: _themeMode == ReaderThemeMode.dark
                        ? Colors.white70
                        : Colors.black54,
                  ),
                ),
              ),
            ],
          ),
        ),
        pixelRatio: 3.0,
      );

      if (!mounted) return;
      Navigator.pop(context); // إغلاق loading indicator

      final temp = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final path = '${temp.path}/quote_$timestamp.png';
      await File(path).writeAsBytes(image);

      if (!mounted) return;
      final result = await Share.shareXFiles(
        [XFile(path)],
        text: isAr
            ? 'اقتباس من ${widget.novel.title}'
            : 'Quote from ${widget.novel.title}',
      );

      // Show rewarded interstitial ad after sharing quote
      if (result.status == ShareResultStatus.success) {
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showRewardedInterstitialAd();
          }
        });
      }
    } catch (e) {
      if (!mounted) return;
      Navigator.pop(context); // إغلاق loading indicator
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            isAr ? 'حدث خطأ أثناء إنشاء الصورة' : 'Error creating image',
          ),
        ),
      );
      debugPrint('Error creating image: $e');
    }
  }

  /// Build loading screen with download progress for Arabic novels
  Widget _buildLoadingScreen() {
    final locale = Localizations.localeOf(context);
    final isAr = locale.languageCode == 'ar';
    final isRu = locale.languageCode == 'ru';
    
    if (_isDownloading) {
      // Show download progress
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 24),
              Text(
                isAr
                    ? '📥 جاري تحميل الرواية...'
                    : isRu
                        ? '📥 Загрузка романа...'
                        : '📥 Downloading novel...',
                style: Theme.of(context).textTheme.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: _downloadProgress,
                minHeight: 8,
              ),
              const SizedBox(height: 16),
              Text(
                '${(_downloadProgress * 100).toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 24),
              TextButton.icon(
                onPressed: () {
                  setState(() {
                    _downloadCancelled = true;
                    _isDownloading = false;
                    _isLoading = false;
                  });
                  Navigator.pop(context);
                },
                icon: const Icon(Icons.cancel),
                label: Text(
                  isAr ? 'إلغاء' : isRu ? 'Отмена' : 'Cancel',
                ),
              ),
            ],
          ),
        ),
      );
    }
    
    // Regular loading
    return const Center(child: CircularProgressIndicator());
  }

  void _showSettings() {
    // Show interstitial ad when opening settings
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _showInterstitialAd();
      }
    });

    final isAr = Localizations.localeOf(context).languageCode == 'ar';
    showModalBottomSheet(
      context: context,
      backgroundColor: _getBgColor(),
      builder: (context) => StatefulBuilder(
        builder: (context, setST) => Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Slider(
                value: _fontSize,
                min: 16,
                max: 32,
                onChanged: (v) {
                  setState(() => _fontSize = v);
                  setST(() => _fontSize = v);
                  _prefs?.setDouble('f_size', v);
                },
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _circleTheme(ReaderThemeMode.light, Colors.white),
                  _circleTheme(ReaderThemeMode.sepia, const Color(0xFFF4ECD8)),
                  _circleTheme(ReaderThemeMode.dark, const Color(0xFF1A1A1A)),
                ],
              ),
              SwitchListTile(
                title: Text(isAr ? "الموسيقى" : "Music"),
                value: isPlaying,
                onChanged: (v) async {
                  // Update UI immediately
                  setST(() {
                    isPlaying = v;
                  });
                  // Then toggle the music
                  if (v) {
                    // User wants to play music
                    try {
                      await _audioPlayer.setReleaseMode(ReleaseMode.loop);
                      await _audioPlayer.setVolume(0.5);
                      await _audioPlayer.play(AssetSource('music/chopin_nocturne.mp3'));
                      debugPrint('🎵 Music started playing');
                      await _prefs?.setBool('music_playing', true);
                    } catch (e) {
                      debugPrint('❌ Error playing music: $e');
                      setST(() {
                        isPlaying = false;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              isAr ? 'حدث خطأ في تشغيل الموسيقى' : 'Error playing music',
                            ),
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    }
                  } else {
                    // User wants to pause music
                    try {
                      await _audioPlayer.pause();
                      debugPrint('🎵 Music paused');
                      await _prefs?.setBool('music_playing', false);
                    } catch (e) {
                      debugPrint('❌ Error pausing music: $e');
                    }
                  }
                  // Update main state as well
                  if (mounted) {
                    setState(() {
                      isPlaying = v;
                    });
                  }
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _circleTheme(ReaderThemeMode mode, Color color) {
    return GestureDetector(
      onTap: () {
        setState(() => _themeMode = mode);
        _prefs?.setInt('t_mode', mode.index);
        Navigator.pop(context);
      },
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: _themeMode == mode ? Colors.blue : Colors.grey,
          ),
        ),
      ),
    );
  }

  Color _getBgColor() {
    if (_themeMode == ReaderThemeMode.dark) return const Color(0xFF121212);
    if (_themeMode == ReaderThemeMode.sepia) return const Color(0xFFF4ECD8);
    return Colors.white;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _getBgColor(),
      appBar: _chromeVisible
          ? AppBar(
              title: Text(widget.novel.title),
              actions: [
                IconButton(
                  icon: const Icon(Icons.search),
                  tooltip: Localizations.localeOf(context).languageCode == 'ar'
                      ? 'بحث'
                      : 'Search',
                  onPressed: _openSearch,
                ),
                IconButton(
                  icon: const Icon(Icons.share),
                  tooltip: Localizations.localeOf(context).languageCode == 'ar'
                      ? 'مشاركة النص المحدد'
                      : 'Share Selected Text',
                  onPressed: _shareSelectedTextAsImage,
                ),
                IconButton(
                  icon: const Icon(Icons.tune),
                  tooltip: Localizations.localeOf(context).languageCode == 'ar'
                      ? 'إعدادات'
                      : 'Settings',
                  onPressed: _showSettings,
                ),
              ],
            )
          : null,
      body: _isLoading
          ? _buildLoadingScreen()
          : _errorMessage != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 64,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _errorMessage!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 24),
                    Builder(
                      builder: (context) {
                        final locale = Localizations.localeOf(context);
                        String retryText;
                        if (locale.languageCode == 'ar') {
                          retryText = 'إعادة المحاولة';
                        } else if (locale.languageCode == 'ru') {
                          retryText = 'Повторить попытку';
                        } else {
                          retryText = 'Retry';
                        }
                        return ElevatedButton.icon(
                          onPressed: () => _initReader(),
                          icon: const Icon(Icons.refresh),
                          label: Text(retryText),
                        );
                      },
                    ),
                  ],
                ),
              ),
            )
          : (_controller == null && !_isPdf) || (_isPdf && _pdfBytes == null)
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              children: [
                // Show PDF or EPUB based on file type
                _isPdf
                    ? Container(
                        color: _getBgColor(),
                        child: SfPdfViewer.memory(
                          _pdfBytes!,
                          controller: _pdfController,
                          onDocumentLoadFailed: (PdfDocumentLoadFailedDetails details) {
                            debugPrint("❌ PDF load failed: ${details.error}");
                            if (mounted) {
                              setState(() {
                                _isLoading = false;
                                _errorMessage = '❌ خطأ في تحميل ملف PDF\n\nالرواية: ${widget.novel.title}';
                              });
                            }
                          },
                        ),
                      )
                    : EpubView(
                        controller: _controller!,
                        builders: EpubViewBuilders<DefaultBuilderOptions>(
                          options: DefaultBuilderOptions(
                            textStyle: GoogleFonts.amiri(
                              fontSize: _fontSize,
                              color: _themeMode == ReaderThemeMode.dark
                                  ? Colors.white
                                  : Colors.black87,
                            ),
                          ),
                        ),
                      ),
                // Floating button to toggle chrome visibility
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: FloatingActionButton.small(
                    onPressed: () =>
                        setState(() => _chromeVisible = !_chromeVisible),
                    tooltip: _chromeVisible
                        ? (Localizations.localeOf(context).languageCode == 'ar'
                              ? 'إخفاء القوائم'
                              : 'Hide UI')
                        : (Localizations.localeOf(context).languageCode == 'ar'
                              ? 'إظهار القوائم'
                              : 'Show UI'),
                    child: Icon(
                      _chromeVisible ? Icons.fullscreen : Icons.fullscreen_exit,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
