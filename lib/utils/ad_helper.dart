import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // Test Ad Unit IDs from AdMob (for testing only)
  // Native Ad (متقدمة مدمجة مع المحتوى)
  static const String nativeAdUnitId = 'ca-app-pub-3940256099942544/2247696110';
  
  // Rewarded Ad (بيني بمكافأة)
  static const String rewardedAdUnitId = 'ca-app-pub-3940256099942544/5224354917';
  
  // Rewarded Interstitial Ad (بيني بمكافأة - نوع متقدم)
  static const String rewardedInterstitialAdUnitId = 'ca-app-pub-3940256099942544/5354046379';
  
  // Interstitial Ad (فتح التطبيق/القراءة)
  static const String interstitialAdUnitId = 'ca-app-pub-3940256099942544/1033173712';
  
  // Banner Ad (بانر)
  static const String bannerAdUnitId = 'ca-app-pub-3940256099942544/6300978111';

  // App Open Ad (إعلان فتح التطبيق)
  static const String appOpenAdUnitId = 'ca-app-pub-3940256099942544/3419835294';
  
  // Static reference to App Open Ad
  static AppOpenAd? _appOpenAd;
  static bool _isAppOpenAdReady = false;
  static bool _isShowingAppOpenAd = false;

  // Initialize AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    debugPrint('✅ AdMob initialized');
  }
  
  // Load App Open Ad
  static void loadAppOpenAd({
    Function()? onAdLoaded,
    Function(LoadAdError)? onAdFailedToLoad,
  }) {
    if (_isAppOpenAdReady || _isShowingAppOpenAd) {
      debugPrint('⚠️ App Open Ad already loaded or showing');
      return;
    }
    
    debugPrint('📱 Loading App Open Ad...');
    AppOpenAd.load(
      adUnitId: appOpenAdUnitId,
      request: const AdRequest(),
      orientation: 1, // 1 = portrait, 2 = landscape
      adLoadCallback: AppOpenAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ App Open Ad loaded successfully');
          _appOpenAd = ad;
          _isAppOpenAdReady = true;
          onAdLoaded?.call();
          
          ad.fullScreenContentCallback = FullScreenContentCallback(
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('📱 App Open Ad dismissed');
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdReady = false;
              _isShowingAppOpenAd = false;
              // Load next ad
              loadAppOpenAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ App Open Ad failed to show: $error');
              ad.dispose();
              _appOpenAd = null;
              _isAppOpenAdReady = false;
              _isShowingAppOpenAd = false;
              // Load next ad
              loadAppOpenAd();
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ App Open Ad failed to load: $error');
          debugPrint('❌ Error code: ${error.code}');
          debugPrint('❌ Error domain: ${error.domain}');
          debugPrint('❌ Error message: ${error.message}');
          
          // Check if it's a network error
          final isNetworkError = error.code == 0 || 
                                 error.message.toLowerCase().contains('network') ||
                                 error.message.toLowerCase().contains('timeout') ||
                                 error.message.toLowerCase().contains('connection');
          
          if (isNetworkError) {
            debugPrint('⚠️ Network error detected - will retry with longer delay');
          }
          
          _isAppOpenAdReady = false;
          onAdFailedToLoad?.call(error);
        },
      ),
    );
  }
  
  // Show App Open Ad
  static void showAppOpenAd() {
    if (_appOpenAd == null || !_isAppOpenAdReady || _isShowingAppOpenAd) {
      debugPrint('⚠️ App Open Ad not ready to show');
      return;
    }
    
    debugPrint('🎬 Showing App Open Ad...');
    _isShowingAppOpenAd = true;
    _appOpenAd!.show();
  }
  
  // Check if App Open Ad is ready
  static bool isAppOpenAdReady() {
    return _isAppOpenAdReady && _appOpenAd != null;
  }

  // Create Native Ad
  static NativeAd createNativeAd({
    required Function(NativeAd ad) onAdLoaded,
    required Function(LoadAdError error) onAdFailedToLoad,
  }) {
    return NativeAd(
      adUnitId: nativeAdUnitId,
      factoryId: 'nativeAdFactory',
      request: const AdRequest(),
      listener: NativeAdListener(
        onAdLoaded: (ad) => onAdLoaded(ad as NativeAd),
        onAdFailedToLoad: (ad, error) {
          debugPrint('❌ [AD LOADING] Native Ad failed to load: $error');
          debugPrint('❌ [AD LOADING] Error code: ${error.code}');
          debugPrint('❌ [AD LOADING] Error message: ${error.message}');
          ad.dispose();
          onAdFailedToLoad(error);
        },
      ),
    )..load();
  }

  // Create Rewarded Ad
  static RewardedAd? createRewardedAd({
    required Function(RewardedAd ad) onAdLoaded,
    required Function(LoadAdError error) onAdFailedToLoad,
    required Function(RewardedAd ad, RewardItem reward) onUserEarnedReward,
  }) {
    RewardedAd? rewardedAd;
    RewardedAd.load(
      adUnitId: rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          rewardedAd = ad;
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ [AD LOADING] Rewarded Ad failed to load: $error');
          debugPrint('❌ [AD LOADING] Error code: ${error.code}');
          debugPrint('❌ [AD LOADING] Error message: ${error.message}');
          onAdFailedToLoad(error);
        },
      ),
    );
    return rewardedAd;
  }

  // Create Interstitial Ad
  static InterstitialAd? createInterstitialAd({
    required Function(InterstitialAd ad) onAdLoaded,
    required Function(LoadAdError error) onAdFailedToLoad,
    required VoidCallback onAdClosed,
  }) {
    InterstitialAd? interstitialAd;
    InterstitialAd.load(
      adUnitId: interstitialAdUnitId,
      request: const AdRequest(),
      adLoadCallback: InterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          interstitialAd = ad;
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ [AD LOADING] Interstitial Ad failed to load: $error');
          debugPrint('❌ [AD LOADING] Error code: ${error.code}');
          debugPrint('❌ [AD LOADING] Error message: ${error.message}');
          onAdFailedToLoad(error);
        },
      ),
    );
    return interstitialAd;
  }

  // Create Rewarded Interstitial Ad
  static void createRewardedInterstitialAd({
    required Function(RewardedInterstitialAd ad) onAdLoaded,
    required Function(LoadAdError error) onAdFailedToLoad,
  }) {
    RewardedInterstitialAd.load(
      adUnitId: rewardedInterstitialAdUnitId,
      request: const AdRequest(),
      rewardedInterstitialAdLoadCallback: RewardedInterstitialAdLoadCallback(
        onAdLoaded: (ad) {
          onAdLoaded(ad);
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ [AD LOADING] Rewarded Interstitial Ad failed to load: $error');
          debugPrint('❌ [AD LOADING] Error code: ${error.code}');
          debugPrint('❌ [AD LOADING] Error message: ${error.message}');
          onAdFailedToLoad(error);
        },
      ),
    );
  }

  // Create Banner Ad
  static BannerAd createBannerAd({
    required Function(BannerAd ad) onAdLoaded,
    required Function(BannerAd ad, LoadAdError error) onAdFailedToLoad,
    AdSize? adSize,
  }) {
    return BannerAd(
      adUnitId: bannerAdUnitId,
      size: adSize ?? AdSize.banner,
      request: const AdRequest(),
      listener: BannerAdListener(
        onAdLoaded: (ad) => onAdLoaded(ad as BannerAd),
        onAdFailedToLoad: (ad, error) {
          ad.dispose();
          onAdFailedToLoad(ad as BannerAd, error);
        },
      ),
    )..load();
  }
}

