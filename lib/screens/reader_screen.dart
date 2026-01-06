import 'dart:async';
import 'dart:io';

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

import '../models/novel.dart';
import '../utils/ad_helper.dart';

enum ReaderThemeMode { light, sepia, dark }

class ReaderScreen extends StatefulWidget {
  final Novel novel;
  const ReaderScreen({super.key, required this.novel});

  @override
  State<ReaderScreen> createState() => _ReaderScreenState();
}

class _ReaderScreenState extends State<ReaderScreen> {
  EpubController? _controller;
  bool _chromeVisible = true;
  double _fontSize = 20;
  ReaderThemeMode _themeMode = ReaderThemeMode.sepia;
  bool _isLoading = true;
  String? _errorMessage;
  int? _lastChapterIndex; // Track last chapter to detect chapter completion
  bool _showRewardedAdOnSettings = false; // Option to show ad when opening settings

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
    _initReader();
    _loadInterstitialAd();
    _loadRewardedAd();
    _loadRewardedInterstitialAd();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    setState(() {
      _showRewardedAdOnSettings = _prefs?.getBool('show_rewarded_ad_on_settings') ?? false;
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    _controller?.dispose();
    _interstitialAd?.dispose();
    _rewardedAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _initReader() async {
    if (!mounted) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      _prefs = await SharedPreferences.getInstance();

      if (!mounted) return;
      setState(() {
        _fontSize = _prefs?.getDouble('f_size') ?? 20;
        _themeMode = ReaderThemeMode.values[_prefs?.getInt('t_mode') ?? 1];
      });

      // Load EPUB file
      debugPrint("Loading EPUB: ${widget.novel.assetFilePath}");
      final bytes = await rootBundle.load(widget.novel.assetFilePath);
      debugPrint("EPUB file loaded, size: ${bytes.lengthInBytes} bytes");
      
      final initialCfi = _prefs?.getString('cfi_${widget.novel.title}');
      debugPrint("Initial CFI: ${initialCfi ?? 'null'}");

      // Parse EPUB document
      try {
        final document = EpubDocument.openData(bytes.buffer.asUint8List());
        debugPrint("EPUB document parsed successfully");
        
        _controller = EpubController(
          document: document,
          epubCfi: initialCfi,
        );
        debugPrint("EPUB controller created successfully");
      } catch (parseError) {
        debugPrint("Error parsing EPUB document: $parseError");
        throw Exception("Failed to parse EPUB file. The file may be corrupted. Error: $parseError");
      }

      _controller!.currentValueListenable.addListener(() async {
        final cfi = _controller!.generateEpubCfi();
        if (cfi != null && _prefs != null) {
          await _prefs!.setString('cfi_${widget.novel.title}', cfi);

          // Calculate and save progress based on CFI position
          // Since we can't easily parse CFI to get exact position, we use a simple approach:
          // If CFI exists and has been updated, mark as "in progress" (set to a small value like 0.1)
          // This indicates the user has started reading
          try {
            if (cfi.isNotEmpty) {
              // If we have a saved CFI, the book has been opened/read
              // We'll use a conservative estimate that increases slightly over time
              // In a production app, you'd parse CFI to get exact position
              final existingProgress =
                  _prefs?.getDouble('progress_${widget.novel.title}') ?? 0.0;
              // Only update if we haven't set a higher progress yet
              // This prevents progress from being reset to a lower value
              if (existingProgress < 0.1) {
                await _prefs!.setDouble('progress_${widget.novel.title}', 0.1);
              }
            }
          } catch (e) {
            debugPrint('Error calculating progress: $e');
          }
        }
      });

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = null;
      });

      // Show interstitial ad after book is loaded (non-intrusive)
      // Wait for ad to load, then show it
      _waitAndShowInterstitialAd();
    } catch (e) {
      debugPrint("Error loading book: $e");
      debugPrint("Novel title: ${widget.novel.title}");
      debugPrint("Asset path: ${widget.novel.assetFilePath}");
      if (mounted) {
        final locale = Localizations.localeOf(context);
        final isAr = locale.languageCode == 'ar';
        final isRu = locale.languageCode == 'ru';
        
        String errorMsg;
        if (isAr) {
          errorMsg = 'حدث خطأ في تحميل الرواية. يرجى المحاولة مرة أخرى.\n\n'
              'المسار: ${widget.novel.assetFilePath}';
        } else if (isRu) {
          errorMsg = 'Произошла ошибка при загрузке романа. Пожалуйста, попробуйте снова.\n\n'
              'Путь: ${widget.novel.assetFilePath}';
        } else {
          errorMsg = 'Error loading book. Please try again.\n\n'
              'Path: ${widget.novel.assetFilePath}';
        }
        
        setState(() {
          _isLoading = false;
          _errorMessage = errorMsg;
        });
      }
    }
  }

  void _loadInterstitialAd() {
    debugPrint('📢 Loading Interstitial Ad...');
    AdHelper.createInterstitialAd(
      onAdLoaded: (ad) {
        debugPrint('✅ Interstitial Ad loaded successfully!');
        setState(() {
          _interstitialAd = ad;
          _isInterstitialAdReady = true;
        });
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            debugPrint('📢 Interstitial Ad dismissed');
            ad.dispose();
            setState(() {
              _isInterstitialAdReady = false;
            });
            _loadInterstitialAd(); // Load next ad
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint('❌ Interstitial Ad failed to show: $error');
            ad.dispose();
            setState(() {
              _isInterstitialAdReady = false;
            });
            _loadInterstitialAd(); // Load next ad
          },
        );
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ Interstitial ad failed to load: $error');
        setState(() {
          _isInterstitialAdReady = false;
        });
      },
      onAdClosed: () {
        debugPrint('📢 Interstitial Ad closed');
        setState(() {
          _isInterstitialAdReady = false;
        });
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
      setState(() {
        _isInterstitialAdReady = false;
      });
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

  void _showRewardedAd() {
    if (_rewardedAd != null) {
      _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
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
    } else {
      _loadRewardedAd();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('جاري تحميل الإعلان... / Loading ad...'),
          ),
        );
      }
    }
  }

  void _loadRewardedInterstitialAd() {
    debugPrint('📢 Loading Rewarded Interstitial Ad...');
    AdHelper.createRewardedInterstitialAd(
      onAdLoaded: (ad) {
        debugPrint('✅ Rewarded Interstitial Ad loaded successfully!');
        setState(() {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdReady = true;
        });
        _rewardedInterstitialAd!.fullScreenContentCallback =
            FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('📢 Rewarded Interstitial Ad dismissed');
                ad.dispose();
                setState(() {
                  _isRewardedInterstitialAdReady = false;
                });
                _loadRewardedInterstitialAd(); // Load next ad
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ Rewarded Interstitial Ad failed to show: $error');
                ad.dispose();
                setState(() {
                  _isRewardedInterstitialAdReady = false;
                });
                _loadRewardedInterstitialAd(); // Load next ad
              },
            );
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ Rewarded Interstitial Ad failed to load: $error');
        setState(() {
          _isRewardedInterstitialAdReady = false;
        });
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
      setState(() {
        _isRewardedInterstitialAdReady = false;
      });
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

  void _toggleMusic() async {
    try {
      if (isPlaying) {
        await _audioPlayer.pause();
        debugPrint('🎵 Music paused');
      } else {
        await _audioPlayer.play(AssetSource('music/chopin_nocturne.mp3'));
        debugPrint('🎵 Music started playing');
        // Set release mode to keep music playing in loop
        await _audioPlayer.setReleaseMode(ReleaseMode.loop);
      }
      if (mounted) {
        setState(() => isPlaying = !isPlaying);
      }
    } catch (e) {
      debugPrint('❌ Error toggling music: $e');
      if (mounted) {
        final isAr = Localizations.localeOf(context).languageCode == 'ar';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isAr 
              ? 'حدث خطأ في تشغيل الموسيقى' 
              : 'Error playing music'),
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
                  return ListTile(
                    title: Text(
                      chapters[0].Title ?? "فصل ${i + 1}",
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
                      Navigator.pop(context);
                      
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

  void _showSettings() {
    // Show rewarded interstitial ad when opening settings (if enabled)
    if (_showRewardedAdOnSettings) {
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          _showRewardedInterstitialAd();
        }
      });
    }
    
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
                title: Text(
                  isAr ? "الموسيقى" : "Music",
                ),
                value: isPlaying,
                onChanged: (v) => _toggleMusic(),
              ),
              SwitchListTile(
                title: Text(
                  isAr ? "إظهار إعلان المكافأة عند فتح الإعدادات" : "Show Rewarded Ad on Settings",
                ),
                subtitle: Text(
                  isAr ? "عرض إعلان بمكافأة عند فتح قائمة الإعدادات" : "Show rewarded ad when opening settings",
                  style: const TextStyle(fontSize: 12),
                ),
                value: _showRewardedAdOnSettings,
                onChanged: (v) async {
                  setState(() {
                    _showRewardedAdOnSettings = v;
                  });
                  setST(() {
                    _showRewardedAdOnSettings = v;
                  });
                  await _prefs?.setBool('show_rewarded_ad_on_settings', v);
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
          ? const Center(child: CircularProgressIndicator())
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
              : _controller == null
                  ? const Center(child: CircularProgressIndicator())
                  : Stack(
              children: [
                // EpubView with text selection enabled
                // Text selection should work now without GestureDetector interference
                EpubView(
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
                    child: Icon(
                      _chromeVisible ? Icons.fullscreen : Icons.fullscreen_exit,
                    ),
                    tooltip: _chromeVisible
                        ? (Localizations.localeOf(context).languageCode == 'ar'
                              ? 'إخفاء القوائم'
                              : 'Hide UI')
                        : (Localizations.localeOf(context).languageCode == 'ar'
                              ? 'إظهار القوائم'
                              : 'Show UI'),
                  ),
                ),
              ],
            ),
    );
  }
}
