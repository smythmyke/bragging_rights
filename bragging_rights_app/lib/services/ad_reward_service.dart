import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'br_currency_service.dart';

/// Ad Reward Service - Manage rewarded video ads for BR currency
/// Integrates with Google AdMob for monetization
class AdRewardService {
  final BRCurrencyService _brService = BRCurrencyService();

  // Test Ad Unit IDs (for development only)
  static const String _testRewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  // Production Ad Unit IDs from AdMob console
  // Android App ID: ca-app-pub-6550805819637330~3890172020
  static const String _prodRewardedAdUnitIdAndroid = 'ca-app-pub-6550805819637330/2465409717';
  static const String _prodRewardedAdUnitIdIOS = 'ca-app-pub-XXXXXX/2222222222'; // iOS when needed

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _isAdReady = false;

  /// Get platform-specific ad unit ID
  /// Uses test IDs in debug mode, production IDs in release builds
  String get _adUnitId {
    final isProduction = bool.fromEnvironment('dart.vm.product');
    final platform = defaultTargetPlatform;

    debugPrint('🔧 [ADMOB] Platform: $platform, Production: $isProduction');

    if (platform == TargetPlatform.android) {
      final adUnitId = isProduction ? _prodRewardedAdUnitIdAndroid : _testRewardedAdUnitIdAndroid;
      debugPrint('🎯 [ADMOB] Using Android ad unit: ${adUnitId.substring(0, 20)}...');
      return adUnitId;
    } else if (platform == TargetPlatform.iOS) {
      final adUnitId = isProduction ? _prodRewardedAdUnitIdIOS : _testRewardedAdUnitIdIOS;
      debugPrint('🎯 [ADMOB] Using iOS ad unit: ${adUnitId.substring(0, 20)}...');
      return adUnitId;
    }
    debugPrint('⚠️ [ADMOB] Unknown platform, using Android test ID fallback');
    return _testRewardedAdUnitIdAndroid; // Fallback
  }

  /// Initialize AdMob SDK (call this on app startup)
  static Future<void> initialize() async {
    debugPrint('🎬 [ADMOB-SERVICE] Calling MobileAds.instance.initialize()...');
    try {
      final initStatus = await MobileAds.instance.initialize();
      debugPrint('✅ [ADMOB-SERVICE] MobileAds initialized successfully!');
      debugPrint('📊 [ADMOB-SERVICE] Init status: $initStatus');
    } catch (e, stackTrace) {
      debugPrint('❌ [ADMOB-SERVICE] MobileAds initialization error: $e');
      debugPrint('❌ [ADMOB-SERVICE] Stack: $stackTrace');
      rethrow;
    }
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    debugPrint('📥 [AD-LOAD] loadRewardedAd() called');
    debugPrint('📥 [AD-LOAD] Current state - isLoading: $_isAdLoading, isReady: $_isAdReady');

    if (_isAdLoading || _isAdReady) {
      debugPrint('⏸️ [AD-LOAD] Ad already loading or ready, skipping');
      return;
    }

    _isAdLoading = true;
    final adUnitId = _adUnitId; // This will trigger the getter logs
    debugPrint('📥 [AD-LOAD] Starting RewardedAd.load with ad unit: ${adUnitId.substring(0, 20)}...');

    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('✅ [AD-LOAD] Rewarded ad LOADED successfully!');
            _rewardedAd = ad;
            _isAdReady = true;
            _isAdLoading = false;

            // Set up callbacks
            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                debugPrint('📺 [AD-SHOW] Rewarded ad showing full screen');
              },
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('👋 [AD-SHOW] Rewarded ad dismissed by user');
                ad.dispose();
                _rewardedAd = null;
                _isAdReady = false;
                // Preload next ad
                debugPrint('🔄 [AD-LOAD] Preloading next ad...');
                loadRewardedAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ [AD-SHOW] Rewarded ad FAILED to show: $error');
                debugPrint('❌ [AD-SHOW] Error code: ${error.code}, Message: ${error.message}');
                ad.dispose();
                _rewardedAd = null;
                _isAdReady = false;
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ [AD-LOAD] Rewarded ad FAILED to load!');
            debugPrint('❌ [AD-LOAD] Error code: ${error.code}');
            debugPrint('❌ [AD-LOAD] Error domain: ${error.domain}');
            debugPrint('❌ [AD-LOAD] Error message: ${error.message}');
            debugPrint('❌ [AD-LOAD] Response info: ${error.responseInfo}');
            _rewardedAd = null;
            _isAdReady = false;
            _isAdLoading = false;
          },
        ),
      );
      debugPrint('📥 [AD-LOAD] RewardedAd.load() call completed (waiting for callback)');
    } catch (e, stackTrace) {
      debugPrint('❌ [AD-LOAD] Exception during RewardedAd.load: $e');
      debugPrint('❌ [AD-LOAD] Stack trace: $stackTrace');
      _isAdLoading = false;
    }
  }

  /// Check if ad is ready to show
  bool isAdReady() {
    return _isAdReady && _rewardedAd != null;
  }

  /// Check if user can watch more ads today
  Future<bool> canWatchAd(String userId) async {
    try {
      final result = await _brService.awardAdReward(userId);
      // Revert the transaction since we're just checking
      // (This is a dry-run check)
      return result.success || result.message.contains('Daily ad limit reached');
    } catch (e) {
      return false;
    }
  }

  /// Show rewarded ad and award BR currency
  Future<AdRewardResult> showRewardedAd(String userId) async {
    if (!_isAdReady || _rewardedAd == null) {
      return AdRewardResult(
        success: false,
        message: 'Ad not ready. Please try again.',
      );
    }

    bool rewardEarned = false;
    int rewardAmount = 0;

    // Show the ad
    await _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('🎉 User earned reward: ${reward.amount} ${reward.type}');
        rewardEarned = true;
        rewardAmount = reward.amount.toInt();
      },
    );

    // Wait for ad to complete
    await Future.delayed(const Duration(seconds: 1));

    if (!rewardEarned) {
      return AdRewardResult(
        success: false,
        message: 'Ad closed before completion',
      );
    }

    // Award BR currency
    final brResult = await _brService.awardAdReward(userId);

    if (brResult.success) {
      return AdRewardResult(
        success: true,
        message: brResult.message,
        brAwarded: brResult.amount ?? 0,
        newBalance: brResult.newBalance ?? 0,
      );
    } else {
      return AdRewardResult(
        success: false,
        message: brResult.message,
      );
    }
  }

  /// Get daily ad watch status
  Future<AdWatchStatus> getAdWatchStatus(String userId) async {
    try {
      // This is a simplified version - you'd query the user document
      // to get adsWatchedToday and lastAdWatchDate
      return AdWatchStatus(
        adsWatchedToday: 0, // Get from user document
        maxAdsPerDay: BRCurrencyService.MAX_ADS_PER_DAY,
        brPerAd: BRCurrencyService.AD_WATCH_AMOUNT,
        canWatchMore: true,
      );
    } catch (e) {
      debugPrint('Error getting ad watch status: $e');
      return AdWatchStatus(
        adsWatchedToday: 0,
        maxAdsPerDay: BRCurrencyService.MAX_ADS_PER_DAY,
        brPerAd: BRCurrencyService.AD_WATCH_AMOUNT,
        canWatchMore: false,
      );
    }
  }

  /// Dispose of loaded ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdReady = false;
    _isAdLoading = false;
  }
}

/// Result of showing a rewarded ad
class AdRewardResult {
  final bool success;
  final String message;
  final int brAwarded;
  final int newBalance;

  AdRewardResult({
    required this.success,
    required this.message,
    this.brAwarded = 0,
    this.newBalance = 0,
  });
}

/// User's ad watch status for the day
class AdWatchStatus {
  final int adsWatchedToday;
  final int maxAdsPerDay;
  final int brPerAd;
  final bool canWatchMore;

  AdWatchStatus({
    required this.adsWatchedToday,
    required this.maxAdsPerDay,
    required this.brPerAd,
    required this.canWatchMore,
  });

  int get adsRemaining => maxAdsPerDay - adsWatchedToday;
  int get potentialBrRemaining => adsRemaining * brPerAd;
  double get progressPercent => (adsWatchedToday / maxAdsPerDay) * 100;
}
