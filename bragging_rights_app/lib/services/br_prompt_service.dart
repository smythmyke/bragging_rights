import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../widgets/br_prompts/br_earn_prompts.dart';
import 'br_currency_service.dart';

/// Service to manage when and how BR earning prompts are shown
/// Conservative approach: max once per session for each trigger
class BRPromptService {
  static const String _lastDailyLoginKey = 'last_daily_login_prompt';
  static const int LOW_BR_THRESHOLD = 25; // Show low balance prompt below this

  // Session tracking (resets when app restarts)
  static bool _hasShownLowBalanceThisSession = false;
  static bool _hasShownDailyLoginThisSession = false;
  static bool _hasShownPostLossThisSession = false;

  /// Check and show daily login prompt
  /// Shows once per day on first app open
  static Future<void> checkDailyLogin(BuildContext context) async {
    if (_hasShownDailyLoginThisSession) return;

    final prefs = await SharedPreferences.getInstance();
    final lastShown = prefs.getString(_lastDailyLoginKey);
    final today = DateTime.now().toIso8601String().split('T')[0]; // YYYY-MM-DD

    // Only show once per day
    if (lastShown == today) return;

    // Check if ads are available
    final adsRemaining = await _getAdsRemainingToday();
    if (adsRemaining == 0) return; // No ads available

    _hasShownDailyLoginThisSession = true;

    // Wait a bit after app starts (let UI settle)
    await Future.delayed(const Duration(seconds: 2));

    if (!context.mounted) return;

    final maxBR = adsRemaining * BRCurrencyService.AD_WATCH_AMOUNT;
    await BREarnPrompts.showDailyLoginSheet(
      context,
      adsAvailable: adsRemaining,
      maxBRToday: maxBR,
    );

    // Mark as shown today
    await prefs.setString(_lastDailyLoginKey, today);
  }

  /// Check and show low balance banner
  /// Triggered when BR balance drops below threshold
  static Future<void> checkLowBalance(
    BuildContext context,
    int currentBalance,
  ) async {
    if (_hasShownLowBalanceThisSession) return;
    if (currentBalance >= LOW_BR_THRESHOLD) return;

    // Check if ads are available
    final adsRemaining = await _getAdsRemainingToday();
    if (adsRemaining == 0) return; // Can't earn more today

    _hasShownLowBalanceThisSession = true;

    if (!context.mounted) return;

    BREarnPrompts.showLowBalanceBanner(context);
  }

  /// Show insufficient funds dialog
  /// Triggered when user tries to place bet but doesn't have enough BR
  /// Always shows (not session-limited) since it's blocking a user action
  static Future<bool> showInsufficientFunds(
    BuildContext context, {
    required int currentBalance,
    required int requiredAmount,
  }) async {
    final shortfall = requiredAmount - currentBalance;

    // Check if watching ads could help
    final adsRemaining = await _getAdsRemainingToday();
    final canEarnEnough = (adsRemaining * BRCurrencyService.AD_WATCH_AMOUNT) >= shortfall;

    // Show dialog even if they can't earn enough (they can still buy BR)
    return await BREarnPrompts.showInsufficientFundsDialog(
      context,
      currentBalance: currentBalance,
      required_amount: requiredAmount,
      shortfall: shortfall,
    );
  }

  /// Show post-loss floating card
  /// Triggered after user loses a bet
  static Future<void> showPostLoss(
    BuildContext context, {
    required int brLost,
  }) async {
    if (_hasShownPostLossThisSession) return;

    // Check if ads are available
    final adsRemaining = await _getAdsRemainingToday();
    if (adsRemaining == 0) return; // Can't earn more today

    _hasShownPostLossThisSession = true;

    if (!context.mounted) return;

    BREarnPrompts.showPostLossCard(
      context,
      brLost: brLost,
    );
  }

  /// Get number of ads remaining today for current user
  static Future<int> _getAdsRemainingToday() async {
    // TODO: Query user document to get actual adsWatchedToday
    // For now, return max available (will be implemented when integrated with user service)
    return BRCurrencyService.MAX_ADS_PER_DAY;
  }

  /// Reset session flags (call this when user navigates or after showing prompts)
  static void resetSessionFlags() {
    _hasShownLowBalanceThisSession = false;
    _hasShownDailyLoginThisSession = false;
    _hasShownPostLossThisSession = false;
  }

  /// Reset only low balance flag (so it can be shown again in same session if needed)
  static void resetLowBalanceFlag() {
    _hasShownLowBalanceThisSession = false;
  }

  /// Reset only post-loss flag
  static void resetPostLossFlag() {
    _hasShownPostLossThisSession = false;
  }
}
