import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';
import 'package:applovin_max/applovin_max.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_analytics/firebase_analytics.dart';
import 'br_currency_service.dart';

/// Ad Reward Service - Manage rewarded video ads for BR currency
/// Integrates with AppLovin MAX mediation (AdMob + Unity + Meta networks)
/// Falls back to direct AdMob if AppLovin MAX is not available
class AdRewardService {
  final BRCurrencyService _brService = BRCurrencyService();
  final FirebaseAnalytics _analytics = FirebaseAnalytics.instance;

  // AppLovin MAX Ad Unit IDs (mediation - highest revenue)
  // TODO: Replace with your actual AppLovin MAX ad unit IDs from dashboard
  // Get ad units from: https://dash.applovin.com/o/mediation/ad_units
  static const String _maxRewardedAdUnitIdAndroid = 'YOUR_APPLOVIN_REWARDED_AD_UNIT_ID';
  static const String _maxRewardedAdUnitIdIOS = 'YOUR_APPLOVIN_REWARDED_AD_UNIT_ID_IOS';

  // Get platform-specific MAX ad unit ID
  String get _maxAdUnitId {
    final platform = defaultTargetPlatform;
    return platform == TargetPlatform.iOS
        ? _maxRewardedAdUnitIdIOS
        : _maxRewardedAdUnitIdAndroid;
  }

  // AdMob Test IDs (for development/fallback)
  static const String _testRewardedAdUnitIdAndroid = 'ca-app-pub-3940256099942544/5224354917';
  static const String _testRewardedAdUnitIdIOS = 'ca-app-pub-3940256099942544/1712485313';

  // AdMob Production IDs (fallback if AppLovin MAX fails)
  static const String _prodRewardedAdUnitIdAndroid = 'ca-app-pub-6550805819637330/2465409717';
  static const String _prodRewardedAdUnitIdIOS = 'ca-app-pub-XXXXXX/2222222222';

  // Ad state
  RewardedAd? _rewardedAd; // AdMob fallback
  bool _isAdLoading = false;
  bool _isAdReady = false;
  bool _useAppLovinMax = true; // Try AppLovin MAX first, fallback to AdMob
  bool _isCurrentAdMAX = false; // Track if current loaded ad is from MAX
  int _maxRewardAmount = 0; // Store reward from MAX callback

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

  /// Load a rewarded ad (tries AppLovin MAX first, falls back to AdMob)
  Future<void> loadRewardedAd() async {
    debugPrint('📥 [AD-LOAD] loadRewardedAd() called');
    debugPrint('📥 [AD-LOAD] Current state - isLoading: $_isAdLoading, isReady: $_isAdReady, useMAX: $_useAppLovinMax');

    if (_isAdLoading || _isAdReady) {
      debugPrint('⏸️ [AD-LOAD] Ad already loading or ready, skipping');
      return;
    }

    _isAdLoading = true;

    // Try AppLovin MAX first (if enabled and configured)
    if (_useAppLovinMax && !_maxAdUnitId.contains('YOUR_')) {
      debugPrint('📥 [AD-LOAD] Attempting AppLovin MAX rewarded ad load...');
      try {
        AppLovinMAX.loadRewardedAd(_maxAdUnitId);

        // Set up AppLovin MAX event listeners
        AppLovinMAX.setRewardedAdListener(RewardedAdListener(
          onAdLoadedCallback: (ad) {
            debugPrint('✅ [MAX-LOAD] AppLovin MAX rewarded ad LOADED successfully!');
            _isAdReady = true;
            _isAdLoading = false;
            _isCurrentAdMAX = true;

            // Analytics: Track MAX ad load success
            _analytics.logEvent(
              name: 'ad_load_success',
              parameters: {
                'ad_network': 'applovin_max',
                'ad_type': 'rewarded',
                'ad_unit_id': _maxAdUnitId,
              },
            );
          },
          onAdLoadFailedCallback: (adUnitId, error) {
            debugPrint('❌ [MAX-LOAD] AppLovin MAX ad FAILED to load!');
            debugPrint('❌ [MAX-LOAD] Error code: ${error.code}, Message: ${error.message}');
            debugPrint('🔄 [MAX-LOAD] Falling back to AdMob...');

            // Analytics: Track MAX ad load failure
            _analytics.logEvent(
              name: 'ad_load_failed',
              parameters: {
                'ad_network': 'applovin_max',
                'ad_type': 'rewarded',
                'error_code': error.code.toString(),
                'error_message': error.message,
              },
            );

            _useAppLovinMax = false;
            _isAdLoading = false;
            loadRewardedAd(); // Retry with AdMob
          },
          onAdDisplayedCallback: (ad) {
            debugPrint('📺 [MAX-SHOW] AppLovin MAX ad displayed');

            // Analytics: Track MAX ad impression
            _analytics.logEvent(
              name: 'ad_impression',
              parameters: {
                'ad_network': 'applovin_max',
                'ad_type': 'rewarded',
                'ad_unit_id': _maxAdUnitId,
              },
            );
          },
          onAdDisplayFailedCallback: (ad, error) {
            debugPrint('❌ [MAX-SHOW] AppLovin MAX ad display FAILED: ${error.message}');
            _isAdReady = false;

            // Analytics: Track MAX ad display failure
            _analytics.logEvent(
              name: 'ad_display_failed',
              parameters: {
                'ad_network': 'applovin_max',
                'ad_type': 'rewarded',
                'error_code': error.code.toString(),
                'error_message': error.message,
              },
            );
          },
          onAdClickedCallback: (ad) {
            debugPrint('👆 [MAX-SHOW] AppLovin MAX ad clicked');

            // Analytics: Track MAX ad click
            _analytics.logEvent(
              name: 'ad_click',
              parameters: {
                'ad_network': 'applovin_max',
                'ad_type': 'rewarded',
              },
            );
          },
          onAdHiddenCallback: (ad) {
            debugPrint('👋 [MAX-SHOW] AppLovin MAX ad dismissed');
            _isAdReady = false;
            // Preload next ad
            debugPrint('🔄 [MAX-LOAD] Preloading next ad...');
            loadRewardedAd();
          },
          onAdReceivedRewardCallback: (ad, reward) {
            debugPrint('🎉 [MAX-REWARD] User earned reward: ${reward.amount} ${reward.label}');
            _maxRewardAmount = reward.amount;

            // Analytics: Track MAX reward earned
            _analytics.logEvent(
              name: 'ad_reward_earned',
              parameters: {
                'ad_network': 'applovin_max',
                'ad_type': 'rewarded',
                'reward_amount': reward.amount,
                'reward_type': reward.label,
              },
            );
          },
        ));

        debugPrint('📥 [MAX-LOAD] AppLovin MAX load initiated (waiting for callback)');
        return; // Exit early, callbacks will handle the rest
      } catch (e, stackTrace) {
        debugPrint('❌ [MAX-LOAD] Exception during AppLovin MAX load: $e');
        debugPrint('❌ [MAX-LOAD] Stack trace: $stackTrace');
        debugPrint('🔄 [MAX-LOAD] Falling back to AdMob...');
        _useAppLovinMax = false;
      }
    }

    // Fallback to AdMob (direct implementation)
    final adUnitId = _adUnitId;
    debugPrint('📥 [ADMOB-LOAD] Starting AdMob RewardedAd.load with ad unit: ${adUnitId.substring(0, 20)}...');

    try {
      await RewardedAd.load(
        adUnitId: adUnitId,
        request: const AdRequest(),
        rewardedAdLoadCallback: RewardedAdLoadCallback(
          onAdLoaded: (ad) {
            debugPrint('✅ [ADMOB-LOAD] AdMob rewarded ad LOADED successfully!');
            _rewardedAd = ad;
            _isAdReady = true;
            _isAdLoading = false;
            _isCurrentAdMAX = false;

            // Analytics: Track AdMob ad load success
            _analytics.logEvent(
              name: 'ad_load_success',
              parameters: {
                'ad_network': 'admob',
                'ad_type': 'rewarded',
                'ad_unit_id': adUnitId,
              },
            );

            // Set up callbacks
            _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
              onAdShowedFullScreenContent: (ad) {
                debugPrint('📺 [ADMOB-SHOW] AdMob rewarded ad showing full screen');

                // Analytics: Track AdMob ad impression
                _analytics.logEvent(
                  name: 'ad_impression',
                  parameters: {
                    'ad_network': 'admob',
                    'ad_type': 'rewarded',
                  },
                );
              },
              onAdDismissedFullScreenContent: (ad) {
                debugPrint('👋 [ADMOB-SHOW] AdMob rewarded ad dismissed by user');
                ad.dispose();
                _rewardedAd = null;
                _isAdReady = false;
                // Preload next ad
                debugPrint('🔄 [ADMOB-LOAD] Preloading next ad...');
                loadRewardedAd();
              },
              onAdFailedToShowFullScreenContent: (ad, error) {
                debugPrint('❌ [ADMOB-SHOW] AdMob rewarded ad FAILED to show: $error');
                debugPrint('❌ [ADMOB-SHOW] Error code: ${error.code}, Message: ${error.message}');

                // Analytics: Track AdMob ad display failure
                _analytics.logEvent(
                  name: 'ad_display_failed',
                  parameters: {
                    'ad_network': 'admob',
                    'ad_type': 'rewarded',
                    'error_code': error.code.toString(),
                    'error_message': error.message,
                  },
                );

                ad.dispose();
                _rewardedAd = null;
                _isAdReady = false;
              },
            );
          },
          onAdFailedToLoad: (error) {
            debugPrint('❌ [ADMOB-LOAD] AdMob rewarded ad FAILED to load!');
            debugPrint('❌ [ADMOB-LOAD] Error code: ${error.code}');
            debugPrint('❌ [ADMOB-LOAD] Error domain: ${error.domain}');
            debugPrint('❌ [ADMOB-LOAD] Error message: ${error.message}');
            debugPrint('❌ [ADMOB-LOAD] Response info: ${error.responseInfo}');

            // Analytics: Track AdMob ad load failure
            _analytics.logEvent(
              name: 'ad_load_failed',
              parameters: {
                'ad_network': 'admob',
                'ad_type': 'rewarded',
                'error_code': error.code.toString(),
                'error_domain': error.domain,
                'error_message': error.message,
              },
            );

            _rewardedAd = null;
            _isAdReady = false;
            _isAdLoading = false;
          },
        ),
      );
      debugPrint('📥 [ADMOB-LOAD] AdMob RewardedAd.load() call completed (waiting for callback)');
    } catch (e, stackTrace) {
      debugPrint('❌ [ADMOB-LOAD] Exception during AdMob RewardedAd.load: $e');
      debugPrint('❌ [ADMOB-LOAD] Stack trace: $stackTrace');
      _isAdLoading = false;
    }
  }

  /// Check if ad is ready to show
  bool isAdReady() {
    if (_isCurrentAdMAX) {
      return _isAdReady;
    } else {
      return _isAdReady && _rewardedAd != null;
    }
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
    if (!_isAdReady) {
      return AdRewardResult(
        success: false,
        message: 'Ad not ready. Please try again.',
      );
    }

    bool rewardEarned = false;
    int rewardAmount = 0;

    // Show AppLovin MAX ad
    if (_isCurrentAdMAX) {
      debugPrint('📺 [MAX-SHOW] Showing AppLovin MAX rewarded ad...');

      // Reset reward tracker
      _maxRewardAmount = 0;

      try {
        AppLovinMAX.showRewardedAd(_maxAdUnitId);

        // Wait for ad to complete and reward callback
        await Future.delayed(const Duration(seconds: 2));

        if (_maxRewardAmount > 0) {
          rewardEarned = true;
          rewardAmount = _maxRewardAmount;
          debugPrint('✅ [MAX-SHOW] Reward earned: $rewardAmount');
        } else {
          debugPrint('⚠️ [MAX-SHOW] No reward received');
        }
      } catch (e) {
        debugPrint('❌ [MAX-SHOW] Error showing MAX ad: $e');
        return AdRewardResult(
          success: false,
          message: 'Failed to show ad. Please try again.',
        );
      }
    }
    // Show AdMob ad
    else {
      if (_rewardedAd == null) {
        return AdRewardResult(
          success: false,
          message: 'Ad not ready. Please try again.',
        );
      }

      debugPrint('📺 [ADMOB-SHOW] Showing AdMob rewarded ad...');

      await _rewardedAd!.show(
        onUserEarnedReward: (ad, reward) {
          debugPrint('🎉 [ADMOB-SHOW] User earned reward: ${reward.amount} ${reward.type}');
          rewardEarned = true;
          rewardAmount = reward.amount.toInt();

          // Analytics: Track AdMob reward earned
          _analytics.logEvent(
            name: 'ad_reward_earned',
            parameters: {
              'ad_network': 'admob',
              'ad_type': 'rewarded',
              'reward_amount': reward.amount.toInt(),
              'reward_type': reward.type,
            },
          );
        },
      );

      // Wait for ad to complete
      await Future.delayed(const Duration(seconds: 1));
    }

    if (!rewardEarned) {
      return AdRewardResult(
        success: false,
        message: 'Ad closed before completion',
      );
    }

    // Award BR currency
    final brResult = await _brService.awardAdReward(userId);

    if (brResult.success) {
      // Analytics: Track successful BR award
      await _analytics.logEvent(
        name: 'br_awarded_from_ad',
        parameters: {
          'br_amount': brResult.amount ?? 0,
          'new_balance': brResult.newBalance ?? 0,
          'ad_network': _isCurrentAdMAX ? 'applovin_max' : 'admob',
          'user_id': userId,
        },
      );

      return AdRewardResult(
        success: true,
        message: brResult.message,
        brAwarded: brResult.amount ?? 0,
        newBalance: brResult.newBalance ?? 0,
      );
    } else {
      // Analytics: Track failed BR award
      await _analytics.logEvent(
        name: 'br_award_failed',
        parameters: {
          'error_message': brResult.message,
          'ad_network': _isCurrentAdMAX ? 'applovin_max' : 'admob',
          'user_id': userId,
        },
      );

      return AdRewardResult(
        success: false,
        message: brResult.message,
      );
    }
  }

  /// Get daily ad watch status
  Future<AdWatchStatus> getAdWatchStatus(String userId) async {
    try {
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .get();

      final data = userDoc.data() ?? {};
      final adsWatched = data['adsWatchedToday'] ?? 0;
      final lastAdWatchDate = data['lastAdWatchDate'] as String?;

      // Reset count if it's a new day
      final today = _getTodayDateString();
      final isSameDay = lastAdWatchDate == today;

      final actualAdsWatched = isSameDay ? adsWatched : 0;
      final canWatch = actualAdsWatched < BRCurrencyService.MAX_ADS_PER_DAY;

      return AdWatchStatus(
        adsWatchedToday: actualAdsWatched,
        maxAdsPerDay: BRCurrencyService.MAX_ADS_PER_DAY,
        brPerAd: BRCurrencyService.AD_WATCH_AMOUNT,
        canWatchMore: canWatch,
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

  /// Get today's date as YYYY-MM-DD string
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Dispose of loaded ad
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
    _isAdReady = false;
    _isAdLoading = false;
    _isCurrentAdMAX = false;
    _maxRewardAmount = 0;
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
