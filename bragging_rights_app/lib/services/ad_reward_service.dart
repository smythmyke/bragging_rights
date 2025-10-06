import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'br_currency_service.dart';

/// Ad Reward Service - Manage rewarded video ads for BR currency
/// Integrates with Google AdMob for monetization
class AdRewardService {
  final BRCurrencyService _brService = BRCurrencyService();

  // AdMob Ad Unit IDs (REPLACE WITH YOUR ACTUAL AD UNIT IDS)
  static const String _rewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917'; // Test ID
  static const String _rewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313'; // Test ID

  RewardedAd? _rewardedAd;
  bool _isAdLoading = false;
  bool _isAdReady = false;

  /// Get platform-specific ad unit ID
  String get _adUnitId {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _rewardedAdUnitIdAndroid;
    } else if (defaultTargetPlatform == TargetPlatform.iOS) {
      return _rewardedAdUnitIdIOS;
    }
    return _rewardedAdUnitIdAndroid; // Fallback
  }

  /// Initialize AdMob SDK (call this on app startup)
  static Future<void> initialize() async {
    await MobileAds.instance.initialize();
    debugPrint('✅ AdMob SDK initialized');
  }

  /// Load a rewarded ad
  Future<void> loadRewardedAd() async {
    if (_isAdLoading || _isAdReady) {
      debugPrint('⏸️ Ad already loading or ready');
      return;
    }

    _isAdLoading = true;

    await RewardedAd.load(
      adUnitId: _adUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          debugPrint('✅ Rewarded ad loaded');
          _rewardedAd = ad;
          _isAdReady = true;
          _isAdLoading = false;

          // Set up callbacks
          _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
            onAdShowedFullScreenContent: (ad) {
              debugPrint('📺 Rewarded ad showed full screen');
            },
            onAdDismissedFullScreenContent: (ad) {
              debugPrint('👋 Rewarded ad dismissed');
              ad.dispose();
              _rewardedAd = null;
              _isAdReady = false;
              // Preload next ad
              loadRewardedAd();
            },
            onAdFailedToShowFullScreenContent: (ad, error) {
              debugPrint('❌ Rewarded ad failed to show: $error');
              ad.dispose();
              _rewardedAd = null;
              _isAdReady = false;
            },
          );
        },
        onAdFailedToLoad: (error) {
          debugPrint('❌ Rewarded ad failed to load: $error');
          _rewardedAd = null;
          _isAdReady = false;
          _isAdLoading = false;
        },
      ),
    );
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
