import 'package:flutter/material.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

class AdHelper {
  // Production Ad Unit IDs from AdMob
  // Native Ad (متقدمة مدمجة مع المحتوى)
  static const String nativeAdUnitId = 'ca-app-pub-9118481973136364/5278674929';
  
  // Rewarded Ad (بيني بمكافأة)
  static const String rewardedAdUnitId = 'ca-app-pub-9118481973136364/9988076121';
  
  // Rewarded Interstitial Ad (بيني بمكافأة - نوع متقدم)
  static const String rewardedInterstitialAdUnitId = 'ca-app-pub-9118481973136364/9988076121';
  
  // Interstitial Ad (فتح التطبيق/القراءة)
  static const String interstitialAdUnitId = 'ca-app-pub-9118481973136364/4200740430';
  
  // Banner Ad (بانر)
  static const String bannerAdUnitId = 'ca-app-pub-9118481973136364/4182033918';

  // Initialize AdMob
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
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

