import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:math';
import 'dart:async';

import '../models/novel.dart';
import 'reader_screen.dart';
import 'war_and_peace_parts_screen.dart';
import 'anna_karenina_parts_screen.dart';
import 'favorites_screen.dart';
import 'login_screen.dart';
import '../main.dart';
import '../utils/tolstoy_quotes.dart';
import '../utils/novel_ratings.dart';
import '../utils/share_helper.dart';
import '../utils/ad_helper.dart';
import '../utils/auth_service.dart';
import '../widgets/comments_section.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.languageCode,
    required this.onDarkModeChanged,
    required this.isDarkMode,
  });

  final String languageCode; // 'ar' | 'en' | 'ru'
  final Function(bool) onDarkModeChanged;
  final bool isDarkMode;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late SharedPreferences _prefs;
  Set<String> _favoriteIds = {};
  bool _isLoading = true;

  // Helper method to get localized text
  String _getText(String arabic, String english, String russian) {
    if (widget.languageCode == 'ar') return arabic;
    if (widget.languageCode == 'ru') return russian;
    return english;
  }

  NativeAd? _nativeAd;
  bool _isNativeAdLoaded = false;
  List<NativeAd?> _nativeAds =
      []; // Multiple native ads for showing after every 5 novels
  List<bool> _nativeAdsLoaded = []; // Track which ads are loaded
  InterstitialAd? _interstitialAd;
  bool _isInterstitialAdReady = false;
  RewardedInterstitialAd? _rewardedInterstitialAd;
  bool _isRewardedInterstitialAdReady = false;
  bool _isSignedIn = false;
  String? _userName;
  String? _userPhotoUrl;
  bool _hasShownOpeningAd = false;

  static const List<Novel> _arabicNovels = [
    Novel(
      title: 'الحرب والسلم',
      assetFilePath: 'assets/books/ar/al7rb1.epub',
      coverAssetPath: 'assets/covers/war_and_peace.png',
      downloadUrl: 'http://spinel.info/pdfapi/al7rb1.pdf',
    ),
    Novel(
      title: 'حِكَم النَّبي مُحَمَّد',
      assetFilePath: 'assets/books/ar/moh.epub',
      coverAssetPath: 'assets/covers/moh.png',
      downloadUrl: 'http://spinel.info/pdfapi/moh.pdf',
    ),
    Novel(
      title: 'بدائع الخيال',
      assetFilePath: 'assets/books/ar/bda2a.epub',
      coverAssetPath: 'assets/covers/bda2a.png',
      downloadUrl: 'http://spinel.info/pdfapi/bda2a.pdf',
    ),
    Novel(
      title: 'اعترافات تولستوي',
      assetFilePath: 'assets/books/ar/a3trafat.epub',
      coverAssetPath: 'assets/covers/a3trafat.png',
      downloadUrl: 'http://spinel.info/pdfapi/a3trafat.pdf',
    ),
    Novel(
      title: 'إنجيل تولستوي وديانته',
      assetFilePath: 'assets/books/ar/engel.epub',
      coverAssetPath: 'assets/covers/engel.png',
      downloadUrl: 'http://spinel.info/pdfapi/engel.pdf',
    ),
    Novel(
      title: 'مملكة جهنم والخمر',
      assetFilePath: 'assets/books/ar/jhanam.epub',
      coverAssetPath: 'assets/covers/jhanam.png',
      downloadUrl: 'http://spinel.info/pdfapi/jhanam.pdf',
    ),
    Novel(
      title: 'انا كاتيا',
      assetFilePath: 'assets/books/ar/anakatya1.pdf',
      coverAssetPath: 'assets/covers/anna_karenina.png',
      downloadUrl: 'http://spinel.info/pdfapi/anakatya1.pdf',
    ),
    Novel(
      title: 'البعث',
      assetFilePath: 'assets/books/ar/alb3th.pdf',
      coverAssetPath: 'assets/covers/alb3th.png',
      downloadUrl: 'http://spinel.info/pdfapi/alb3th.pdf',
    ),
    Novel(
      title: 'مصرع إيفان إيليتش',
      assetFilePath: 'assets/books/ar/msr3.pdf',
      coverAssetPath: 'assets/covers/msr3.png',
      downloadUrl: 'http://spinel.info/pdfapi/msr3.pdf',
    ),
    Novel(
      title: 'حكايات شعبية',
      assetFilePath: 'assets/books/ar/al7kayat.pdf',
      coverAssetPath: 'assets/covers/al7kayat.png',
      downloadUrl: 'http://spinel.info/pdfapi/al7kayat.pdf',
    ),
    Novel(
      title: 'نهاية حب',
      assetFilePath: 'assets/books/ar/nhaya.pdf',
      coverAssetPath: 'assets/covers/nhaya.png',
      downloadUrl: 'http://spinel.info/pdfapi/nhaya.pdf',
    ),
    Novel(
      title: 'كتاب طريق الحياة',
      assetFilePath: 'assets/books/ar/trig.pdf',
      coverAssetPath: 'assets/covers/trig.png',
      downloadUrl: 'http://spinel.info/pdfapi/trig.pdf',
    ),
    Novel(
      title: 'سوناتة لكروتزر',
      assetFilePath: 'assets/books/ar/sw.pdf',
      coverAssetPath: 'assets/covers/sw.png',
      downloadUrl: 'http://spinel.info/pdfapi/sw.pdf',
    ),
    Novel(
      title: 'ماذا علينا أن نفعل',
      assetFilePath: 'assets/books/ar/maza.pdf',
      coverAssetPath: 'assets/covers/maza.png',
      downloadUrl: 'http://spinel.info/pdfapi/maza.pdf',
    ),
    Novel(
      title: 'ما هو الفن',
      assetFilePath: 'assets/books/ar/alfn.pdf',
      coverAssetPath: 'assets/covers/alfn.png',
      downloadUrl: 'http://spinel.info/pdfapi/alfn.pdf',
    ),
    Novel(
      title: 'القوزاق',
      assetFilePath: 'assets/books/ar/gwazg.pdf',
      coverAssetPath: 'assets/covers/gwazg.png',
      downloadUrl: 'http://spinel.info/pdfapi/gwazg.pdf',
    ),
    Novel(
      title: 'السعادة الزوجية',
      assetFilePath: 'assets/books/ar/als3ada.pdf',
      coverAssetPath: 'assets/covers/als3ada.png',
      downloadUrl: 'http://spinel.info/pdfapi/als3ada.pdf',
    ),
    Novel(
      title: 'عن الحياة',
      assetFilePath: 'assets/books/ar/al7yah.pdf',
      coverAssetPath: 'assets/covers/al7yah.png',
      downloadUrl: 'http://spinel.info/pdfapi/al7yah.pdf',
    ),
    Novel(
      title: 'في الدين والعقل والفلسفة',
      assetFilePath: 'assets/books/ar/aldeen.pdf',
      coverAssetPath: 'assets/covers/aldeen.png',
      downloadUrl: 'http://spinel.info/pdfapi/aldeen.pdf',
    ),
    Novel(
      title: 'لحن كرويتزر',
      assetFilePath: 'assets/books/ar/kr.pdf',
      coverAssetPath: 'assets/covers/kr.png',
      downloadUrl: 'http://spinel.info/pdfapi/kr.pdf',
    ),
    Novel(
      title: 'السيد والخادم',
      assetFilePath: 'assets/books/ar/alseed.pdf',
      coverAssetPath: 'assets/covers/alseed.png',
      downloadUrl: 'http://spinel.info/pdfapi/alseed.pdf',
    ),
    Novel(
      title: 'الشيطان',
      assetFilePath: 'assets/books/ar/alshitan.pdf',
      coverAssetPath: 'assets/covers/alshitan.png',
      downloadUrl: 'http://spinel.info/pdfapi/alshitan.pdf',
    ),
    Novel(
      title: 'العجوزان',
      assetFilePath: 'assets/books/ar/al3jwzan.pdf',
      coverAssetPath: 'assets/covers/al3jwzan.png',
      downloadUrl: 'http://spinel.info/pdfapi/al3jwzan.pdf',
    ),
    Novel(
      title: 'العلم والاخلاق والسياسة',
      assetFilePath: 'assets/books/ar/al3lm.pdf',
      coverAssetPath: 'assets/covers/al3lm.png',
      downloadUrl: 'http://spinel.info/pdfapi/al3lm.pdf',
    ),
    Novel(
      title: 'سعادة الاسرة',
      assetFilePath: 'assets/books/ar/sa3ada.pdf',
      coverAssetPath: 'assets/covers/sa3ada.png',
      downloadUrl: 'http://spinel.info/pdfapi/sa3ada.pdf',
    ),
    Novel(
      title: 'السلطة والحرية',
      assetFilePath: 'assets/books/ar/alsolta.pdf',
      coverAssetPath: 'assets/covers/alsolta.png',
      downloadUrl: 'http://spinel.info/pdfapi/alsolta.pdf',
    ),
  ];

  static const List<Novel> _englishNovels = [
    Novel(
      title: 'War and Peace',
      assetFilePath: 'assets/books/en/war_and_peace.epub',
      coverAssetPath: 'assets/covers/war_and_peace.png',
    ),
    Novel(
      title: 'Anna Karenina',
      assetFilePath: 'assets/books/en/anna_karenina.epub',
      coverAssetPath: 'assets/covers/anna_karenina.png',
    ),
    Novel(
      title: 'Resurrection',
      assetFilePath: 'assets/books/en/resurrection.epub',
      coverAssetPath: 'assets/covers/resurrection.png',
    ),
    Novel(
      title: 'The Kreutzer Sonata',
      assetFilePath: 'assets/books/en/the_kreutzer_sonata.epub',
      coverAssetPath: 'assets/covers/the_kreutzer_sonata.png',
    ),
    Novel(
      title: 'Master and Man',
      assetFilePath: 'assets/books/en/master_and_man.epub',
      coverAssetPath: 'assets/covers/master_and_man.png',
    ),
    Novel(
      title: 'Father Sergius',
      assetFilePath: 'assets/books/en/father_sergius.epub',
      coverAssetPath: 'assets/covers/father_sergius.png',
    ),
    Novel(
      title: 'The Devil',
      assetFilePath: 'assets/books/en/devil.epub',
      coverAssetPath: 'assets/covers/devil.png',
    ),
    Novel(
      title: 'The Forged Coupon',
      assetFilePath: 'assets/books/en/the_forged_coupon.epub',
      coverAssetPath: 'assets/covers/the_forged_coupon.png',
    ),
    Novel(
      title: 'Katia',
      assetFilePath: 'assets/books/en/katia.epub',
      coverAssetPath: 'assets/covers/katia.png',
    ),
    Novel(
      title: 'Childhood',
      assetFilePath: 'assets/books/en/childhood.epub',
      coverAssetPath: 'assets/covers/childhood.png',
    ),
    Novel(
      title: 'Boyhood',
      assetFilePath: 'assets/books/en/boyhood.epub',
      coverAssetPath: 'assets/covers/boyhood.png',
    ),
    Novel(
      title: 'Youth',
      assetFilePath: 'assets/books/en/youth.epub',
      coverAssetPath: 'assets/covers/youth.png',
    ),
    Novel(
      title: 'The Kingdom of God Is Within You',
      assetFilePath: 'assets/books/en/the_kingdom.epub',
      coverAssetPath: 'assets/covers/the_kingdom.png',
    ),
    Novel(
      title: 'My Religion',
      assetFilePath: 'assets/books/en/my_religion.epub',
      coverAssetPath: 'assets/covers/my_religion.png',
    ),
    Novel(
      title: 'What Is Art?',
      assetFilePath: 'assets/books/en/art.epub',
      coverAssetPath: 'assets/covers/art.png',
    ),
    Novel(
      title: 'A Letter to a Hindu',
      assetFilePath: 'assets/books/en/letter_hindu.epub',
      coverAssetPath: 'assets/covers/letter_hindu.png',
    ),
    Novel(
      title: 'Bethink Yourselves!',
      assetFilePath: 'assets/books/en/yourselves.epub',
      coverAssetPath: 'assets/covers/yourselves.png',
    ),
    Novel(
      title: 'What to Do?',
      assetFilePath: 'assets/books/en/thoughts.epub',
      coverAssetPath: 'assets/covers/thoughts.png',
    ),
    Novel(
      title: 'Tolstoy on Shakespeare',
      assetFilePath: 'assets/books/en/shakespeare.epub',
      coverAssetPath: 'assets/covers/shakespeare.png',
    ),
    Novel(
      title: 'Sevastopol Sketches',
      assetFilePath: 'assets/books/en/sevastopol.epub',
      coverAssetPath: 'assets/covers/sevastopol.png',
    ),
    Novel(
      title: 'What Men Live By',
      assetFilePath: 'assets/books/en/men_live.epub',
      coverAssetPath: 'assets/covers/men_live.png',
    ),
    Novel(
      title: 'The Power of Darkness',
      assetFilePath: 'assets/books/en/power_darkness.epub',
      coverAssetPath: 'assets/covers/power_darkness.png',
    ),
    Novel(
      title: 'The Light Shines in Darkness',
      assetFilePath: 'assets/books/en/shines_darkness.epub',
      coverAssetPath: 'assets/covers/shines_darkness.png',
    ),
    Novel(
      title: 'Fruits of Culture',
      assetFilePath: 'assets/books/en/fruits_culture.epub',
      coverAssetPath: 'assets/covers/fruits_culture.png',
    ),
    Novel(
      title: 'A Russian Proprietor and Other Stories',
      assetFilePath: 'assets/books/en/russian_proprietor.epub',
      coverAssetPath: 'assets/covers/russian_proprietor.png',
    ),
    Novel(
      title: 'The Invaders and Other Stories',
      assetFilePath: 'assets/books/en/invaders.epub',
      coverAssetPath: 'assets/covers/invaders.png',
    ),
  ];

  static const List<Novel> _russianNovels = [
    Novel(
      title: 'Том 1. Детство, Отрочество, Юность',
      assetFilePath: 'assets/books/ru/1.epub',
      coverAssetPath: 'assets/covers/r1.png',
    ),
    Novel(
      title: 'Том 2. Произведения 1852-1856 гг',
      assetFilePath: 'assets/books/ru/2.epub',
      coverAssetPath: 'assets/covers/r2.png',
    ),
    Novel(
      title: 'Том 3. Произведения 1857-1863 гг',
      assetFilePath: 'assets/books/ru/3.epub',
      coverAssetPath: 'assets/covers/r3.png',
    ),
    Novel(
      title: 'Том 4. Война и мир',
      assetFilePath: 'assets/books/ru/4.epub',
      coverAssetPath: 'assets/covers/r4.png',
    ),
    Novel(
      title: 'Том 5. Война и мир',
      assetFilePath: 'assets/books/ru/5.epub',
      coverAssetPath: 'assets/covers/r5.png',
    ),
    Novel(
      title: 'Том 6. Война и мир',
      assetFilePath: 'assets/books/ru/6.epub',
      coverAssetPath: 'assets/covers/r6.png',
    ),
    Novel(
      title: 'Том 7. Война и мир',
      assetFilePath: 'assets/books/ru/7.epub',
      coverAssetPath: 'assets/covers/r7.png',
    ),
    Novel(
      title: 'Том 8. Анна Каренина',
      assetFilePath: 'assets/books/ru/8.epub',
      coverAssetPath: 'assets/covers/r8.png',
    ),
    Novel(
      title: 'Том 9. Анна Каренина',
      assetFilePath: 'assets/books/ru/9.epub',
      coverAssetPath: 'assets/covers/r9.png',
    ),
    Novel(
      title: 'Том 10. Произведения 1872-1886 гг',
      assetFilePath: 'assets/books/ru/10.epub',
      coverAssetPath: 'assets/covers/r10.png',
    ),
    Novel(
      title: 'Том 11. Драматические произведения 1864-1910 гг',
      assetFilePath: 'assets/books/ru/11.epub',
      coverAssetPath: 'assets/covers/r11.png',
    ),
    Novel(
      title: 'Том 12. Произведения 1885-1902 гг',
      assetFilePath: 'assets/books/ru/12.epub',
      coverAssetPath: 'assets/covers/r12.png',
    ),
    Novel(
      title: 'Том 13. Воскресение',
      assetFilePath: 'assets/books/ru/13.epub',
      coverAssetPath: 'assets/covers/r13.png',
    ),
    Novel(
      title: 'Том 14. Произведения 1903-1910 гг',
      assetFilePath: 'assets/books/ru/14.epub',
      coverAssetPath: 'assets/covers/r14.png',
    ),
    Novel(
      title: 'Том 15. Статьи о литературе и искусстве',
      assetFilePath: 'assets/books/ru/15.epub',
      coverAssetPath: 'assets/covers/r15.png',
    ),
    Novel(
      title: 'Том 16. Избранные публицистические статьи',
      assetFilePath: 'assets/books/ru/16.epub',
      coverAssetPath: 'assets/covers/r16.png',
    ),
    Novel(
      title: 'Том 17. Избранные публицистические статьи',
      assetFilePath: 'assets/books/ru/17.epub',
      coverAssetPath: 'assets/covers/r17.png',
    ),
    Novel(
      title: 'Том 18. Избранные письма 1842-1881',
      assetFilePath: 'assets/books/ru/18.epub',
      coverAssetPath: 'assets/covers/r18.png',
    ),
    Novel(
      title: 'Том 19. Избранные письма 1882-1899',
      assetFilePath: 'assets/books/ru/19.epub',
      coverAssetPath: 'assets/covers/r19.png',
    ),
    Novel(
      title: 'Том 20. Избранные письма 1900-1910',
      assetFilePath: 'assets/books/ru/20.epub',
      coverAssetPath: 'assets/covers/r20.png',
    ),
    Novel(
      title: 'Том 21. Избранные дневники 1847-1894',
      assetFilePath: 'assets/books/ru/21.epub',
      coverAssetPath: 'assets/covers/r21.png',
    ),
    Novel(
      title: 'Том 22. Избранные дневники 1895-1910',
      assetFilePath: 'assets/books/ru/22.epub',
      coverAssetPath: 'assets/covers/r22.png',
    ),
  ];

  @override
  void initState() {
    super.initState();
    _loadFavorites();
    _checkAuthStatus();
    // Wait a bit to ensure AdMob is fully initialized before loading ads
    Future.delayed(const Duration(milliseconds: 1000), () {
      if (mounted) {
        debugPrint('📢 [HOME SCREEN] Starting to load ads...');
        _loadInterstitialAd();
        _loadRewardedInterstitialAd();
        _loadNativeAd();
        _loadMultipleNativeAds();
      }
    });
    // Show ad when app opens (after ad is loaded, handled in _loadInterstitialAd)
  }

  void _loadNativeAd() {
    _nativeAd = AdHelper.createNativeAd(
      onAdLoaded: (ad) {
        debugPrint('✅ Native Ad loaded successfully');
        if (mounted) {
          setState(() {
            _nativeAd = ad;
            _isNativeAdLoaded = true;
          });
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ Native Ad failed to load: $error');
        debugPrint('❌ Error code: ${error.code}');
        debugPrint('❌ Error message: ${error.message}');
        if (mounted) {
          setState(() {
            _isNativeAdLoaded = false;
          });
        }
        // Retry loading after a delay
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted && !_isNativeAdLoaded) {
            debugPrint('🔄 Retrying to load Native Ad...');
            _loadNativeAd();
          }
        });
      },
    );
  }

  void _loadMultipleNativeAds() {
    final novels = widget.languageCode == 'ar'
        ? _arabicNovels
        : widget.languageCode == 'ru'
        ? _russianNovels
        : _englishNovels;

    // Calculate how many native ads we need (after every 5 novels)
    final numberOfAds = (novels.length / 5).ceil();
    debugPrint('📢 [HOME SCREEN] Loading $numberOfAds native ads for grid...');

    // Initialize lists
    _nativeAds = List<NativeAd?>.filled(numberOfAds, null);
    _nativeAdsLoaded = List<bool>.filled(numberOfAds, false);

    // Load each native ad
    for (int i = 0; i < numberOfAds; i++) {
      _loadNativeAdAtIndex(i);
    }
  }

  void _loadNativeAdAtIndex(int index) {
    AdHelper.createNativeAd(
      onAdLoaded: (loadedAd) {
        debugPrint('✅ Native Ad #$index loaded successfully');
        if (mounted) {
          setState(() {
            if (index < _nativeAds.length) {
              _nativeAds[index] = loadedAd;
              _nativeAdsLoaded[index] = true;
            }
          });
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ Native Ad #$index failed to load: $error');
        if (mounted) {
          setState(() {
            if (index < _nativeAdsLoaded.length) {
              _nativeAdsLoaded[index] = false;
            }
          });
        }
        // Retry loading after a delay
        Future.delayed(const Duration(seconds: 10), () {
          if (mounted &&
              index < _nativeAdsLoaded.length &&
              !_nativeAdsLoaded[index]) {
            debugPrint('🔄 Retrying to load Native Ad #$index...');
            _loadNativeAdAtIndex(index);
          }
        });
      },
    );
  }

  void _loadRewardedInterstitialAd() {
    AdHelper.createRewardedInterstitialAd(
      onAdLoaded: (ad) {
        setState(() {
          _rewardedInterstitialAd = ad;
          _isRewardedInterstitialAdReady = true;
        });
        _rewardedInterstitialAd!.fullScreenContentCallback =
            FullScreenContentCallback(
              onAdDismissedFullScreenContent: (ad) {
                ad.dispose();
                setState(() {
                  _isRewardedInterstitialAdReady = false;
                });
                _loadRewardedInterstitialAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                ad.dispose();
                setState(() {
                  _isRewardedInterstitialAdReady = false;
                });
                _loadRewardedInterstitialAd();
              },
            );
      },
      onAdFailedToLoad: (error) {
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
      _rewardedInterstitialAd!.show(
        onUserEarnedReward: (ad, reward) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  _getText(
                    'شكراً لك! حصلت على المكافأة',
                    'Thank you! You earned a reward',
                    'Спасибо! Вы получили награду',
                  ),
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
    }
  }

  Future<void> _checkAuthStatus() async {
    final signedIn = await AuthService.isSignedIn();
    if (signedIn) {
      _userName = await AuthService.getUserName();
      _userPhotoUrl = await AuthService.getUserPhotoUrl();
    }
    if (mounted) {
      setState(() {
        _isSignedIn = signedIn;
      });
    }
  }

  void _loadInterstitialAd() {
    debugPrint('📢 [HOME SCREEN] Loading Interstitial Ad...');
    AdHelper.createInterstitialAd(
      onAdLoaded: (ad) {
        debugPrint(
          '✅✅✅ [HOME SCREEN] Interstitial Ad loaded successfully! ✅✅✅',
        );
        if (mounted) {
          setState(() {
            _interstitialAd = ad;
            _isInterstitialAdReady = true;
          });
        }
        _interstitialAd!.fullScreenContentCallback = FullScreenContentCallback(
          onAdDismissedFullScreenContent: (ad) {
            debugPrint('📢 [HOME SCREEN] Interstitial Ad dismissed');
            ad.dispose();
            if (mounted) {
              setState(() {
                _isInterstitialAdReady = false;
              });
            }
            _loadInterstitialAd();
          },
          onAdFailedToShowFullScreenContent: (ad, error) {
            debugPrint(
              '❌ [HOME SCREEN] Interstitial Ad failed to show: $error',
            );
            ad.dispose();
            if (mounted) {
              setState(() {
                _isInterstitialAdReady = false;
              });
            }
            _loadInterstitialAd();
          },
        );

        // Show opening ad if it hasn't been shown yet and ad is ready
        if (!_hasShownOpeningAd && mounted) {
          // Wait a bit for UI to be ready, then show the ad
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted &&
                !_hasShownOpeningAd &&
                _isInterstitialAdReady &&
                _interstitialAd != null) {
              debugPrint('🎬 [HOME SCREEN] Showing opening ad...');
              _showOpeningAd();
            }
          });
        }
      },
      onAdFailedToLoad: (error) {
        debugPrint('❌ [HOME SCREEN] Interstitial ad failed to load');
        debugPrint('❌ [HOME SCREEN] Error code: ${error.code}');
        debugPrint('❌ [HOME SCREEN] Error domain: ${error.domain}');
        debugPrint('❌ [HOME SCREEN] Error message: ${error.message}');
        debugPrint('❌ [HOME SCREEN] Response info: ${error.responseInfo}');

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

        setState(() {
          _isInterstitialAdReady = false;
        });

        // Use longer delay for network errors
        final delaySeconds = isNetworkError ? 10 : 5;

        // Retry loading after a delay (only if opening ad hasn't been shown yet)
        if (!_hasShownOpeningAd) {
          Future.delayed(Duration(seconds: delaySeconds), () {
            if (mounted && !_hasShownOpeningAd) {
              debugPrint('🔄 [AD LOADING] Retrying to load opening ad...');
              _loadInterstitialAd();
            }
          });
        } else {
          // If opening ad was already shown, just retry for future use
          Future.delayed(Duration(seconds: delaySeconds), () {
            if (mounted) {
              _loadInterstitialAd();
            }
          });
        }
      },
      onAdClosed: () {
        setState(() {
          _isInterstitialAdReady = false;
        });
        _loadInterstitialAd();
      },
    );
  }

  void _showOpeningAd() {
    if (_interstitialAd != null &&
        _isInterstitialAdReady &&
        mounted &&
        !_hasShownOpeningAd) {
      debugPrint('✅ Opening ad is ready, showing now...');
      _hasShownOpeningAd = true;
      _interstitialAd!.show();
      setState(() {
        _isInterstitialAdReady = false;
      });
      // Load next ad for future use
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) {
          _loadInterstitialAd();
        }
      });
    } else {
      debugPrint(
        '⚠️ Cannot show opening ad: ad=${_interstitialAd != null}, ready=$_isInterstitialAdReady, mounted=$mounted, shown=$_hasShownOpeningAd',
      );
    }
  }

  Future<void> _showInterstitialAdOnBookClick() async {
    debugPrint(
      '📢 [HOME SCREEN] Attempting to show Interstitial Ad on book click...',
    );
    debugPrint(
      '📢 [HOME SCREEN] Ad status: ad=${_interstitialAd != null}, ready=$_isInterstitialAdReady, mounted=$mounted',
    );

    if (_interstitialAd != null && _isInterstitialAdReady && mounted) {
      debugPrint('✅ [HOME SCREEN] Interstitial Ad is ready, showing...');
      // Create a Completer to wait for ad dismissal
      final completer = Completer<void>();
      final currentAd = _interstitialAd;

      // Set up callback to complete when ad is dismissed
      currentAd!.fullScreenContentCallback = FullScreenContentCallback(
        onAdDismissedFullScreenContent: (ad) {
          debugPrint(
            '📢 [HOME SCREEN] Interstitial Ad dismissed after book click',
          );
          ad.dispose();
          if (mounted) {
            setState(() {
              _isInterstitialAdReady = false;
            });
          }
          _loadInterstitialAd();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
        onAdFailedToShowFullScreenContent: (ad, error) {
          debugPrint('❌ [HOME SCREEN] Interstitial Ad failed to show: $error');
          ad.dispose();
          if (mounted) {
            setState(() {
              _isInterstitialAdReady = false;
            });
          }
          _loadInterstitialAd();
          if (!completer.isCompleted) {
            completer.complete();
          }
        },
      );

      currentAd.show();
      if (mounted) {
        setState(() {
          _isInterstitialAdReady = false;
        });
      }

      // Wait for ad to be dismissed (max 30 seconds timeout)
      await completer.future
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () {
              debugPrint('⚠️ [HOME SCREEN] Ad timeout - continuing navigation');
            },
          )
          .catchError((error) {
            debugPrint('⚠️ [HOME SCREEN] Error waiting for ad: $error');
          });
    } else {
      debugPrint(
        '⚠️ [HOME SCREEN] Interstitial Ad not ready, continuing without ad',
      );
    }
    // Continue navigation whether ad was shown or not
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Ensure data is loaded when returning to this screen
    if (_isLoading) {
      _loadFavorites();
    }
    // Reload Native Ad if not loaded
    if (!_isNativeAdLoaded && _nativeAd == null) {
      _loadNativeAd();
    }
  }

  Future<void> _refreshData() async {
    await _loadFavorites();
  }

  @override
  void dispose() {
    _nativeAd?.dispose();
    for (var ad in _nativeAds) {
      ad?.dispose();
    }
    _interstitialAd?.dispose();
    _rewardedInterstitialAd?.dispose();
    super.dispose();
  }

  Future<void> _loadFavorites() async {
    try {
      _prefs = await SharedPreferences.getInstance();
      if (mounted) {
        setState(() {
          _favoriteIds = _prefs.getStringList('favorites')?.toSet() ?? {};
          _isLoading = false;
        });
        debugPrint('✅ Favorites loaded. Count: ${_favoriteIds.length}');
        debugPrint('✅ Language: ${widget.languageCode}');
        final novels = widget.languageCode == 'ar'
            ? _arabicNovels
            : widget.languageCode == 'ru'
            ? _russianNovels
            : _englishNovels;
        debugPrint('✅ Novels count: ${novels.length}');
        debugPrint('✅ Language: ${widget.languageCode}');
        if (novels.isNotEmpty) {
          debugPrint('✅ First novel: ${novels.first.title}');
          debugPrint('✅ First novel path: ${novels.first.assetFilePath}');
        }
      }
    } catch (e) {
      debugPrint('❌ Error loading favorites: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _toggleFavorite(Novel novel) async {
    final wasFavorite = _favoriteIds.contains(novel.assetFilePath);
    setState(() {
      if (wasFavorite) {
        _favoriteIds.remove(novel.assetFilePath);
      } else {
        _favoriteIds.add(novel.assetFilePath);
      }
    });
    await _prefs.setStringList('favorites', _favoriteIds.toList());

    // Show rewarded interstitial ad when adding to favorites (not when removing)
    if (!wasFavorite) {
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _showRewardedInterstitialAd();
        }
      });
    }
  }

  bool _isFavorite(Novel novel) {
    return _favoriteIds.contains(novel.assetFilePath);
  }

  List<Novel> get _favoriteNovels {
    final allNovels = widget.languageCode == 'ar'
        ? _arabicNovels
        : widget.languageCode == 'ru'
        ? _russianNovels
        : _englishNovels;
    return allNovels.where((n) => _isFavorite(n)).toList();
  }

  List<Novel> get _quickFavorites {
    final favorites = _favoriteNovels;
    return favorites.length > 3 ? favorites.take(3).toList() : favorites;
  }

  double _getProgress(String novelTitle) {
    if (!_isLoading) {
      return _prefs.getDouble('progress_$novelTitle') ?? 0.0;
    }
    return 0.0;
  }

  Future<void> _surpriseMe() async {
    final novels = widget.languageCode == 'ar'
        ? _arabicNovels
        : widget.languageCode == 'ru'
        ? _russianNovels
        : _englishNovels;
    if (novels.isEmpty) return;
    final random = Random();
    final randomNovel = novels[random.nextInt(novels.length)];
    // Show rewarded interstitial ad before opening random novel
    _showRewardedInterstitialAd();
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => ReaderScreen(novel: randomNovel)),
      );
    }
  }

  Future<void> _showLanguageDialog() async {
    final isAr = widget.languageCode == 'ar';
    final isRu = widget.languageCode == 'ru';
    final shouldChange = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text(
          isAr
              ? 'تغيير اللغة؟'
              : isRu
              ? 'Изменить язык?'
              : 'Change Language?',
        ),
        content: Text(
          isAr
              ? 'هل تود العودة لشاشة اختيار اللغة؟'
              : isRu
              ? 'Вернуться к выбору языка?'
              : 'Return to language selection?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(_getText('إلغاء', 'Cancel', 'Отмена')),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(_getText('تأكيد', 'Confirm', 'Подтвердить')),
          ),
        ],
      ),
    );

    if (shouldChange == true && mounted) {
      await _prefs.remove('language_code');
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const TolstoyReaderApp()),
        (_) => false,
      );
    }
  }

  Widget _buildQuoteOfTheDay(BuildContext context, bool isAr, ThemeData theme) {
    final quote = TolstoyQuotes.getQuoteOfTheDayByLanguage(widget.languageCode);
    final sepiaColor = const Color(0xFFF4ECD8);

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: sepiaColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.brown.shade300, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.format_quote_rounded,
                color: Colors.brown.shade700,
                size: 28,
              ),
              const SizedBox(width: 8),
              Text(
                _getText('اقتباس اليوم', 'Quote of the Day', 'Цитата дня'),
                style: GoogleFonts.playfairDisplay(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.brown.shade800,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          SelectableText(
            quote['quote']!,
            style: GoogleFonts.playfairDisplay(
              fontSize: 16,
              height: 1.6,
              color: Colors.brown.shade900,
              fontStyle: FontStyle.italic,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.share_rounded,
                  color: Colors.brown.shade700,
                  size: 20,
                ),
                onPressed: () async {
                  await ShareHelper.shareTextAsImage(
                    context: context,
                    text: quote['quote']!,
                    source: quote['source']!,
                    isArabic: isAr,
                  );
                  // Show rewarded interstitial ad after sharing quote
                  Future.delayed(const Duration(milliseconds: 500), () {
                    if (mounted) {
                      _showRewardedInterstitialAd();
                    }
                  });
                },
                tooltip: _getText(
                  'مشاركة كصورة',
                  'Share as Image',
                  'Поделиться как изображение',
                ),
              ),
              Expanded(
                child: Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '- ${quote['source']}',
                    style: GoogleFonts.playfairDisplay(
                      fontSize: 14,
                      color: Colors.brown.shade700,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickFavorites(
    BuildContext context,
    bool isAr,
    ThemeData theme,
  ) {
    final quickFavs = _quickFavorites;
    if (quickFavs.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
          child: Text(
            _getText(
              'مفضلاتك السريعة',
              'Your Quick Favorites',
              'Ваши быстрые избранные',
            ),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        SizedBox(
          height: 180,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: quickFavs.length,
            itemBuilder: (context, index) {
              final novel = quickFavs[index];
              return Container(
                width: 120,
                margin: const EdgeInsets.only(right: 12),
                child: InkWell(
                  onTap: () async {
                    await _showInterstitialAdOnBookClick();
                    if (mounted) {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ReaderScreen(novel: novel),
                        ),
                      );
                    }
                  },
                  borderRadius: BorderRadius.circular(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.15),
                                blurRadius: 8,
                                offset: const Offset(0, 3),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset(
                              novel.coverAssetPath,
                              fit: BoxFit.cover,
                              width: double.infinity,
                              errorBuilder: (context, error, stackTrace) =>
                                  Container(
                                    color: theme
                                        .colorScheme
                                        .surfaceContainerHighest,
                                    child: Icon(
                                      Icons.book,
                                      size: 30,
                                      color: theme.colorScheme.primary,
                                    ),
                                  ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        novel.title,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.labelSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _shareApp() async {
    final isAr = widget.languageCode == 'ar';
    final appUrl =
        'https://play.google.com/store/apps/details?id=com.spinel.tolstoy';
    await Share.share(
      isAr
          ? 'تحميل تطبيق روائع دوستويفسكي - مكتبة روايات فيودور دوستويفسكي الكاملة\n\n$appUrl'
          : 'Download Tolstoy Novels App - Complete library of Leo Tolstoy\'s novels\n\n$appUrl',
      subject: _getText('روائع تولستوي', 'Tolstoy Novels', 'Романы Толстого'),
    );

    // Show rewarded interstitial ad after sharing
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        _showRewardedInterstitialAd();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final novels = widget.languageCode == 'ar'
        ? _arabicNovels
        : widget.languageCode == 'ru'
        ? _russianNovels
        : _englishNovels;

    // Debug: Log novels count to help diagnose display issues
    debugPrint(
      '📚 HomeScreen build - Language: ${widget.languageCode}, Novels count: ${novels.length}',
    );
    if (novels.isEmpty) {
      debugPrint('⚠️ WARNING: Novels list is empty!');
    }

    final theme = Theme.of(context);
    final isAr = widget.languageCode == 'ar';

    return Scaffold(
      backgroundColor: theme.colorScheme.surface,
      drawer: _buildDrawer(context, isAr, theme),
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 2,
        centerTitle: true,
        title: Text(
          _getText('مكتبة تولستوي', 'Tolstoy Library', 'Библиотека Толстого'),
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: _refreshData,
        child: novels.isEmpty
            ? Center(
                child: Text(
                  _getText(
                    'لا توجد روايات',
                    'No novels available',
                    'Нет доступных романов',
                  ),
                  style: theme.textTheme.titleMedium,
                ),
              )
            : CustomScrollView(
                slivers: [
                  // Quote of the Day
                  SliverToBoxAdapter(
                    child: _buildQuoteOfTheDay(context, isAr, theme),
                  ),
                  // Native Ad (always show to prevent layout jumps)
                  SliverToBoxAdapter(child: _buildNativeAd(context, theme)),
                  // Quick Favorites (if any)
                  if (_quickFavorites.isNotEmpty)
                    SliverToBoxAdapter(
                      child: _buildQuickFavorites(context, isAr, theme),
                    ),
                  // Continue Reading Section
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Text(
                        _getText(
                          "واصل القراءة",
                          "Continue Reading",
                          "Продолжить чтение",
                        ),
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
                  // Russian title above novels (only for Russian language)
                  if (widget.languageCode == 'ru')
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'Собрание сочинений в пятнадцати томах',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                            fontSize: 20,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  // Novels Grid with Native Ads after every 5 novels
                  SliverPadding(
                    padding: const EdgeInsets.all(16),
                    sliver: SliverGrid(
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            mainAxisSpacing: 20,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.65,
                          ),
                      delegate: SliverChildBuilderDelegate((context, index) {
                        // Calculate if this index should be a native ad
                        // Native ads appear after positions 4, 9, 14, 19, etc. (after every 5 novels)
                        // So native ad positions are: 5, 11, 17, 23, etc.
                        final novelIndex = _getNovelIndexFromGridIndex(index);
                        final adIndex = _getAdIndexFromGridIndex(index);

                        if (adIndex != null) {
                          // This is a native ad position
                          if (adIndex < _nativeAds.length &&
                              adIndex < _nativeAdsLoaded.length &&
                              _nativeAdsLoaded[adIndex] &&
                              _nativeAds[adIndex] != null) {
                            return _buildGridNativeAd(context, theme, adIndex);
                          } else {
                            // Ad not loaded yet, show placeholder
                            return const SizedBox.shrink();
                          }
                        } else if (novelIndex != null &&
                            novelIndex < novels.length) {
                          // This is a novel position
                          final novel = novels[novelIndex];
                          return _NovelCard(
                            novel: novel,
                            languageCode: widget.languageCode,
                            isFavorite: _isFavorite(novel),
                            rating: NovelRatings.getRating(novel.title),
                            progress: _getProgress(novel.title),
                            onTap: () async {
                              debugPrint('📖 Opening novel: ${novel.title}');
                              debugPrint(
                                '📖 Novel path: ${novel.assetFilePath}',
                              );

                              // Check if this is "الحرب والسلم" in Arabic
                              if (novel.title == 'الحرب والسلم' &&
                                  widget.languageCode == 'ar') {
                                // Open parts screen for War and Peace
                                await _showInterstitialAdOnBookClick();
                                if (mounted) {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const WarAndPeacePartsScreen(),
                                        ),
                                      )
                                      .then((_) {
                                        _refreshData();
                                      });
                                }
                              } else if (novel.title == 'انا كاتيا' &&
                                  widget.languageCode == 'ar') {
                                // Open parts screen for Anna Karenina
                                await _showInterstitialAdOnBookClick();
                                if (mounted) {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              const AnnaKareninaPartsScreen(),
                                        ),
                                      )
                                      .then((_) {
                                        _refreshData();
                                      });
                                }
                              } else {
                                // Open reader screen directly for other books
                                await _showInterstitialAdOnBookClick();
                                if (mounted) {
                                  Navigator.of(context)
                                      .push(
                                        MaterialPageRoute(
                                          builder: (_) =>
                                              ReaderScreen(novel: novel),
                                        ),
                                      )
                                      .then((_) {
                                        // Refresh data when returning from reader
                                        _refreshData();
                                      });
                                }
                              }
                            },
                            onFavoriteTap: () => _toggleFavorite(novel),
                          );
                        } else {
                          return const SizedBox.shrink();
                        }
                      }, childCount: _calculateTotalGridItems(novels.length)),
                    ),
                  ),
                  // Comments Section (after all novels)
                  SliverToBoxAdapter(
                    child: CommentsSection(
                      key: ValueKey(
                        _isSignedIn,
                      ), // Rebuild when auth state changes
                      isArabic: isAr,
                      onCommentPosted: () {
                        // Show rewarded interstitial ad after posting comment
                        // This is a good place for maximum revenue
                        _showRewardedInterstitialAd();
                      },
                    ),
                  ),
                ],
              ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _surpriseMe,
        icon: const Icon(Icons.auto_awesome_rounded),
        label: Text(_getText('مفاجئني', 'Surprise Me', 'Удиви меня')),
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: theme.colorScheme.outlineVariant,
                width: 0.5,
              ),
            ),
          ),
          child: Text(
            _getText(
              'جميع الروايات محملة مسبقاً',
              'All novels are pre-loaded',
              'романы предзагружены',
            ),
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context, bool isAr, ThemeData theme) {
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          DrawerHeader(
            decoration: BoxDecoration(
              color: theme.colorScheme.primaryContainer,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (_isSignedIn &&
                    _userPhotoUrl != null &&
                    _userPhotoUrl!.isNotEmpty)
                  CircleAvatar(
                    radius: 30,
                    backgroundImage: NetworkImage(_userPhotoUrl!),
                  )
                else if (_isSignedIn)
                  CircleAvatar(
                    radius: 30,
                    backgroundColor: theme.colorScheme.primary,
                    child: Text(
                      _userName?.isNotEmpty == true
                          ? _userName![0].toUpperCase()
                          : 'U',
                      style: TextStyle(
                        color: theme.colorScheme.onPrimary,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Text(
                  _isSignedIn
                      ? (_userName ??
                            _getText('مستخدم', 'User', 'Пользователь'))
                      : _getText(
                          'روائع تولستوي',
                          'Tolstoy Library',
                          'Библиотека Достоевского',
                        ),
                  style: theme.textTheme.titleLarge?.copyWith(
                    color: theme.colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          // Login/Logout
          if (!_isSignedIn)
            ListTile(
              leading: Icon(
                Icons.login_rounded,
                color: theme.colorScheme.primary,
              ),
              title: Text(_getText('تسجيل الدخول', 'Sign In', 'Войти')),
              onTap: () async {
                Navigator.pop(context);
                final success = await Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LoginScreen(
                      onLoginSuccess: (success) {
                        if (success) {
                          _checkAuthStatus();
                          Navigator.pop(context);
                        }
                      },
                    ),
                  ),
                );
                if (success == true) {
                  _checkAuthStatus();
                }
              },
            )
          else
            ListTile(
              leading: Icon(
                Icons.logout_rounded,
                color: theme.colorScheme.error,
              ),
              title: Text(_getText('تسجيل الخروج', 'Sign Out', 'Выйти')),
              onTap: () async {
                Navigator.pop(context);
                await AuthService.signOut();
                _checkAuthStatus();
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        _getText('تم تسجيل الخروج', 'Signed out', 'Вы вышли'),
                      ),
                    ),
                  );
                }
              },
            ),
          const Divider(),
          ListTile(
            leading: Icon(
              Icons.favorite_rounded,
              color: theme.colorScheme.primary,
            ),
            title: Text(_getText('المفضلة', 'Favorites', 'Избранное')),
            subtitle: Text(
              '${_favoriteNovels.length} ${_getText('رواية', 'novels', 'романов')}',
              style: theme.textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.pop(context);
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => FavoritesScreen(
                    favoriteNovels: _favoriteNovels,
                    isAr: isAr,
                    onRemoveFavorite: (novel) => _toggleFavorite(novel),
                  ),
                ),
              );
            },
          ),
          const Divider(),
          // Dark Mode Toggle
          SwitchListTile(
            secondary: Icon(
              widget.isDarkMode
                  ? Icons.dark_mode_rounded
                  : Icons.light_mode_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(_getText('الوضع الليلي', 'Dark Mode', 'Тёмный режим')),
            value: widget.isDarkMode,
            onChanged: widget.onDarkModeChanged,
          ),
          const Divider(),
          // Google Play Link
          ListTile(
            leading: Icon(Icons.star_rounded, color: Colors.amber),
            title: Text(
              _getText(
                'قيم التطبيق على Google Play',
                'Rate App on Google Play',
                'Оценить приложение в Google Play',
              ),
            ),
            onTap: () async {
              Navigator.pop(context);
              const url =
                  'https://play.google.com/store/apps/details?id=com.spinel.tolstoy';
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _getText(
                        'لا يمكن فتح الرابط',
                        'Could not open link',
                        'He удалось открыть ссылку',
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.share_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(
              _getText('مشاركة التطبيق', 'Share App', 'Поделиться приложением'),
            ),
            onTap: () {
              Navigator.pop(context);
              _shareApp();
            },
          ),
          ListTile(
            leading: Icon(
              Icons.store_rounded,
              color: theme.colorScheme.primary,
            ),
            title: Text(
              _getText(
                'للمزيد من الروايات زورو صفحتنا على متجر بلاي',
                'Visit our Play Store page for more novels',
                'Посетите нашу страницу в Play Store для большего количества романов',
              ),
            ),
            onTap: () async {
              Navigator.pop(context);
              const url =
                  'https://play.google.com/store/apps/dev?id=7189513262046406321';
              final uri = Uri.parse(url);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                if (!mounted) return;
                ScaffoldMessenger.of(this.context).showSnackBar(
                  SnackBar(
                    content: Text(
                      _getText(
                        'لا يمكن فتح الرابط',
                        'Could not open link',
                        'He удалось открыть ссылку',
                      ),
                    ),
                  ),
                );
              }
            },
          ),
          ListTile(
            leading: Icon(
              Icons.translate_rounded,
              color: theme.colorScheme.onSurfaceVariant,
            ),
            title: Text(_getText('الإعدادات', 'Settings', 'Настройки')),
            subtitle: Text(
              _getText('تغيير اللغة', 'Change Language', 'Изменить язык'),
              style: theme.textTheme.bodySmall,
            ),
            onTap: () {
              Navigator.pop(context);
              _showLanguageDialog();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildNativeAd(BuildContext context, ThemeData theme) {
    // Always return a container to prevent layout jumps
    // The container will be empty until ad loads
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: _isNativeAdLoaded && _nativeAd != null
          ? const EdgeInsets.all(12)
          : EdgeInsets.zero,
      decoration: _isNativeAdLoaded && _nativeAd != null
          ? BoxDecoration(
              color: theme.colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: theme.colorScheme.outlineVariant,
                width: 1,
              ),
            )
          : null,
      child: _isNativeAdLoaded && _nativeAd != null
          ? AdWidget(ad: _nativeAd!)
          : const SizedBox.shrink(),
    );
  }

  Widget _buildGridNativeAd(
    BuildContext context,
    ThemeData theme,
    int adIndex,
  ) {
    if (adIndex >= _nativeAds.length ||
        adIndex >= _nativeAdsLoaded.length ||
        !_nativeAdsLoaded[adIndex] ||
        _nativeAds[adIndex] == null) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: theme.colorScheme.outlineVariant, width: 1),
      ),
      child: AdWidget(ad: _nativeAds[adIndex]!),
    );
  }

  // Calculate total grid items (novels + native ads)
  int _calculateTotalGridItems(int novelCount) {
    // Native ads appear after every 5 novels
    // So if we have 25 novels, we need ads after positions 5, 10, 15, 20, 25
    // That's 5 ads, so total items = 25 + 5 = 30
    final numberOfAds = (novelCount / 5).floor();
    return novelCount + numberOfAds;
  }

  // Get novel index from grid index, or null if it's an ad position
  int? _getNovelIndexFromGridIndex(int gridIndex) {
    // Pattern:
    // Positions 0-4: novels 0-4
    // Position 5: ad 0
    // Positions 6-10: novels 5-9
    // Position 11: ad 1
    // Positions 12-16: novels 10-14
    // Position 17: ad 2
    // etc.

    // Check if this is an ad position
    // Ad positions: 5, 11, 17, 23, etc.
    // Formula: (gridIndex - 5) % 6 == 0 and gridIndex >= 5
    if (gridIndex >= 5 && (gridIndex - 5) % 6 == 0) {
      return null; // This is an ad position
    }

    // Calculate novel index
    // For positions before first ad (0-4): novelIndex = gridIndex
    // For positions after first ad: we need to subtract the number of ads before this position
    if (gridIndex < 5) {
      return gridIndex;
    }

    // Count how many ads appear before this position
    final adsBefore = ((gridIndex - 5) ~/ 6) + 1;
    final novelIndex = gridIndex - adsBefore;

    return novelIndex;
  }

  // Get ad index from grid index, or null if it's a novel position
  int? _getAdIndexFromGridIndex(int gridIndex) {
    // Ad positions are: 5, 11, 17, 23, etc.
    // Pattern: (gridIndex - 5) % 6 == 0 and gridIndex >= 5
    if (gridIndex >= 5 && (gridIndex - 5) % 6 == 0) {
      // Calculate which ad this is (0, 1, 2, 3, ...)
      return (gridIndex - 5) ~/ 6;
    }
    return null;
  }
}

class _NovelCard extends StatelessWidget {
  const _NovelCard({
    required this.novel,
    required this.onTap,
    required this.languageCode,
    required this.isFavorite,
    required this.onFavoriteTap,
    required this.rating,
    required this.progress,
  });

  final Novel novel;
  final VoidCallback onTap;
  final String languageCode;
  final bool isFavorite;
  final VoidCallback onFavoriteTap;
  final double rating;
  final double progress;

  // Helper method to get localized text
  String _getText(String arabic, String english, String russian) {
    if (languageCode == 'ar') return arabic;
    if (languageCode == 'ru') return russian;
    return english;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: theme.colorScheme.surface,
        ),
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(16),
                      child: Image.asset(
                        novel.coverAssetPath,
                        fit: BoxFit.cover,
                        width: double.infinity,
                        errorBuilder: (context, error, stackTrace) => Container(
                          color: theme.colorScheme.surfaceContainerHighest,
                          child: Icon(
                            Icons.book,
                            size: 40,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        novel.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.star_rounded,
                            size: 14,
                            color: Colors.amber.shade700,
                          ),
                          const SizedBox(width: 2),
                          Text(
                            rating.toStringAsFixed(1),
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: LinearProgressIndicator(
                    value: progress.clamp(0.0, 1.0),
                    minHeight: 5,
                    backgroundColor: theme.colorScheme.surfaceContainerHighest,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      theme.colorScheme.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      progress > 0
                          ? '${(progress * 100).toInt()}% ${_getText("اكتمل", "Done", "Готово")}'
                          : _getText('لم يبدأ', 'Not Started', 'He начато'),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                        fontSize: 10,
                      ),
                    ),
                    if (progress > 0)
                      Icon(
                        Icons.check_circle_outline,
                        size: 12,
                        color: theme.colorScheme.primary,
                      ),
                  ],
                ),
              ],
            ),
            Positioned(
              top: 8,
              right: 8,
              child: IconButton(
                icon: Icon(
                  isFavorite
                      ? Icons.favorite_rounded
                      : Icons.favorite_border_rounded,
                ),
                color: isFavorite ? Colors.red : theme.colorScheme.onSurface,
                onPressed: onFavoriteTap,
                style: IconButton.styleFrom(
                  backgroundColor: theme.colorScheme.surface,
                  padding: const EdgeInsets.all(4),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
