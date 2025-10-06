import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// BR Currency Service - Free tier virtual currency management
/// Handles daily bonuses, streaks, referrals, and transactions
class BRCurrencyService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // BR Currency Amounts
  static const int DAILY_BONUS_AMOUNT = 50;
  static const int STREAK_BONUS_AMOUNT = 100; // At 7-day streak
  static const int REFERRAL_BONUS_AMOUNT = 200;
  static const int AD_WATCH_AMOUNT = 25;
  static const int MAX_ADS_PER_DAY = 5;

  /// Get user's current BR balance
  Future<int> getBalance(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return 0;
      return (doc.data()?['brBalance'] ?? 0) as int;
    } catch (e) {
      debugPrint('Error getting BR balance: $e');
      return 0;
    }
  }

  /// Check if user can claim daily bonus
  Future<bool> canClaimDailyBonus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return true; // First time user

      final data = doc.data()!;
      final lastBonus = data['lastDailyBonus'] as Timestamp?;

      if (lastBonus == null) return true;

      // Check if last bonus was claimed today
      final today = _getTodayDateString();
      final lastBonusDate = _getDateString(lastBonus.toDate());

      return today != lastBonusDate;
    } catch (e) {
      debugPrint('Error checking daily bonus eligibility: $e');
      return false;
    }
  }

  /// Claim daily login bonus (50 BR + streak tracking)
  Future<BRTransactionResult> claimDailyBonus(String userId) async {
    try {
      // Check eligibility
      final canClaim = await canClaimDailyBonus(userId);
      if (!canClaim) {
        return BRTransactionResult(
          success: false,
          message: 'Daily bonus already claimed today',
        );
      }

      final userRef = _firestore.collection('users').doc(userId);
      final doc = await userRef.get();

      if (!doc.exists) {
        return BRTransactionResult(
          success: false,
          message: 'User not found',
        );
      }

      final data = doc.data()!;
      final currentBalance = (data['brBalance'] ?? 0) as int;
      final currentStreak = (data['loginStreak'] ?? 0) as int;
      final longestStreak = (data['longestLoginStreak'] ?? 0) as int;
      final lastLoginDate = data['lastLoginDate'] as String?;

      // Calculate new streak
      final today = _getTodayDateString();
      final yesterday = _getYesterdayDateString();
      int newStreak;
      bool streakBonusEarned = false;

      if (lastLoginDate == yesterday) {
        // Consecutive day - increment streak
        newStreak = currentStreak + 1;
      } else {
        // Streak broken or first login - start fresh
        newStreak = 1;
      }

      // Check for 7-day streak bonus
      if (newStreak == 7) {
        streakBonusEarned = true;
        newStreak = 0; // Reset streak after bonus
      }

      // Calculate total BR to award
      int totalBR = DAILY_BONUS_AMOUNT;
      if (streakBonusEarned) {
        totalBR += STREAK_BONUS_AMOUNT;
      }

      final newBalance = currentBalance + totalBR;
      final newLongestStreak = newStreak > longestStreak ? newStreak : longestStreak;

      // Update user document
      await userRef.update({
        'brBalance': newBalance,
        'totalBrEarned': FieldValue.increment(totalBR),
        'lastDailyBonus': FieldValue.serverTimestamp(),
        'lastLoginDate': today,
        'loginStreak': newStreak,
        'longestLoginStreak': newLongestStreak,
      });

      // Create transaction record for daily bonus
      await _createTransaction(
        userId: userId,
        type: 'earn',
        source: 'daily_bonus',
        amount: DAILY_BONUS_AMOUNT,
        balanceBefore: currentBalance,
        balanceAfter: currentBalance + DAILY_BONUS_AMOUNT,
        metadata: {
          'streak': newStreak,
          'loginDate': today,
        },
      );

      // Create transaction record for streak bonus if earned
      if (streakBonusEarned) {
        await _createTransaction(
          userId: userId,
          type: 'earn',
          source: 'streak_bonus',
          amount: STREAK_BONUS_AMOUNT,
          balanceBefore: currentBalance + DAILY_BONUS_AMOUNT,
          balanceAfter: newBalance,
          metadata: {
            'streakCompleted': 7,
            'loginDate': today,
          },
        );
      }

      return BRTransactionResult(
        success: true,
        amount: totalBR,
        newBalance: newBalance,
        message: streakBonusEarned
            ? 'Claimed $DAILY_BONUS_AMOUNT BR + $STREAK_BONUS_AMOUNT BR streak bonus!'
            : 'Claimed $DAILY_BONUS_AMOUNT BR daily bonus!',
        metadata: {
          'streak': newStreak,
          'streakBonusEarned': streakBonusEarned,
        },
      );
    } catch (e) {
      debugPrint('Error claiming daily bonus: $e');
      return BRTransactionResult(
        success: false,
        message: 'Failed to claim daily bonus: $e',
      );
    }
  }

  /// Award referral bonus when friend signs up
  Future<BRTransactionResult> awardReferralBonus({
    required String referrerId,
    required String referredUserId,
    required String referredUsername,
  }) async {
    try {
      final userRef = _firestore.collection('users').doc(referrerId);
      final doc = await userRef.get();

      if (!doc.exists) {
        return BRTransactionResult(
          success: false,
          message: 'Referrer not found',
        );
      }

      final data = doc.data()!;
      final currentBalance = (data['brBalance'] ?? 0) as int;
      final newBalance = currentBalance + REFERRAL_BONUS_AMOUNT;

      // Update referrer balance
      await userRef.update({
        'brBalance': newBalance,
        'totalBrEarned': FieldValue.increment(REFERRAL_BONUS_AMOUNT),
      });

      // Create transaction record
      await _createTransaction(
        userId: referrerId,
        type: 'earn',
        source: 'referral',
        amount: REFERRAL_BONUS_AMOUNT,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        metadata: {
          'referredUserId': referredUserId,
          'referredUsername': referredUsername,
        },
      );

      return BRTransactionResult(
        success: true,
        amount: REFERRAL_BONUS_AMOUNT,
        newBalance: newBalance,
        message: 'Earned $REFERRAL_BONUS_AMOUNT BR for referring $referredUsername!',
      );
    } catch (e) {
      debugPrint('Error awarding referral bonus: $e');
      return BRTransactionResult(
        success: false,
        message: 'Failed to award referral bonus: $e',
      );
    }
  }

  /// Award BR for watching video ad (max 5/day)
  Future<BRTransactionResult> awardAdReward(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final doc = await userRef.get();

      if (!doc.exists) {
        return BRTransactionResult(
          success: false,
          message: 'User not found',
        );
      }

      final data = doc.data()!;
      final adsWatchedToday = (data['adsWatchedToday'] ?? 0) as int;
      final lastAdWatchDate = data['lastAdWatchDate'] as String?;
      final today = _getTodayDateString();

      // Reset counter if it's a new day
      int updatedAdsWatched = adsWatchedToday;
      if (lastAdWatchDate != today) {
        updatedAdsWatched = 0;
      }

      // Check daily limit
      if (updatedAdsWatched >= MAX_ADS_PER_DAY) {
        return BRTransactionResult(
          success: false,
          message: 'Daily ad limit reached ($MAX_ADS_PER_DAY/day)',
        );
      }

      final currentBalance = (data['brBalance'] ?? 0) as int;
      final newBalance = currentBalance + AD_WATCH_AMOUNT;

      // Update user document
      await userRef.update({
        'brBalance': newBalance,
        'totalBrEarned': FieldValue.increment(AD_WATCH_AMOUNT),
        'adsWatchedToday': updatedAdsWatched + 1,
        'lastAdWatchDate': today,
      });

      // Create transaction record
      await _createTransaction(
        userId: userId,
        type: 'earn',
        source: 'ad_watch',
        amount: AD_WATCH_AMOUNT,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        metadata: {
          'adsWatchedToday': updatedAdsWatched + 1,
          'date': today,
        },
      );

      return BRTransactionResult(
        success: true,
        amount: AD_WATCH_AMOUNT,
        newBalance: newBalance,
        message: 'Earned $AD_WATCH_AMOUNT BR! (${updatedAdsWatched + 1}/$MAX_ADS_PER_DAY today)',
      );
    } catch (e) {
      debugPrint('Error awarding ad reward: $e');
      return BRTransactionResult(
        success: false,
        message: 'Failed to award ad reward: $e',
      );
    }
  }

  /// Spend BR currency (e.g., pool entry)
  Future<BRTransactionResult> spendBR({
    required String userId,
    required int amount,
    required String source,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      if (amount <= 0) {
        return BRTransactionResult(
          success: false,
          message: 'Invalid amount',
        );
      }

      final userRef = _firestore.collection('users').doc(userId);
      final doc = await userRef.get();

      if (!doc.exists) {
        return BRTransactionResult(
          success: false,
          message: 'User not found',
        );
      }

      final data = doc.data()!;
      final currentBalance = (data['brBalance'] ?? 0) as int;

      // Check sufficient balance
      if (currentBalance < amount) {
        return BRTransactionResult(
          success: false,
          message: 'Insufficient BR balance',
          metadata: {
            'required': amount,
            'available': currentBalance,
            'shortfall': amount - currentBalance,
          },
        );
      }

      final newBalance = currentBalance - amount;

      // Update user document
      await userRef.update({
        'brBalance': newBalance,
        'totalBrSpent': FieldValue.increment(amount),
      });

      // Create transaction record
      await _createTransaction(
        userId: userId,
        type: 'spend',
        source: source,
        amount: amount,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        metadata: metadata,
      );

      return BRTransactionResult(
        success: true,
        amount: amount,
        newBalance: newBalance,
        message: 'Spent $amount BR',
      );
    } catch (e) {
      debugPrint('Error spending BR: $e');
      return BRTransactionResult(
        success: false,
        message: 'Failed to spend BR: $e',
      );
    }
  }

  /// Get user's login streak info
  Future<StreakInfo> getStreakInfo(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) {
        return StreakInfo(
          currentStreak: 0,
          longestStreak: 0,
          daysUntilBonus: 7,
        );
      }

      final data = doc.data()!;
      final currentStreak = (data['loginStreak'] ?? 0) as int;
      final longestStreak = (data['longestLoginStreak'] ?? 0) as int;
      final daysUntilBonus = 7 - currentStreak;

      return StreakInfo(
        currentStreak: currentStreak,
        longestStreak: longestStreak,
        daysUntilBonus: daysUntilBonus > 0 ? daysUntilBonus : 0,
      );
    } catch (e) {
      debugPrint('Error getting streak info: $e');
      return StreakInfo(
        currentStreak: 0,
        longestStreak: 0,
        daysUntilBonus: 7,
      );
    }
  }

  /// Get user's transaction history
  Future<List<BRTransaction>> getTransactionHistory({
    required String userId,
    int limit = 50,
  }) async {
    try {
      final snapshot = await _firestore
          .collection('br_transactions')
          .where('userId', isEqualTo: userId)
          .orderBy('timestamp', descending: true)
          .limit(limit)
          .get();

      return snapshot.docs
          .map((doc) => BRTransaction.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting transaction history: $e');
      return [];
    }
  }

  /// Create BR transaction record
  Future<void> _createTransaction({
    required String userId,
    required String type,
    required String source,
    required int amount,
    required int balanceBefore,
    required int balanceAfter,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      await _firestore.collection('br_transactions').add({
        'userId': userId,
        'type': type,
        'source': source,
        'amount': amount,
        'balanceBefore': balanceBefore,
        'balanceAfter': balanceAfter,
        'metadata': metadata ?? {},
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating transaction: $e');
      // Don't throw - transaction record is for audit, not critical
    }
  }

  /// Get today's date as YYYY-MM-DD string
  String _getTodayDateString() {
    final now = DateTime.now();
    return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
  }

  /// Get yesterday's date as YYYY-MM-DD string
  String _getYesterdayDateString() {
    final yesterday = DateTime.now().subtract(const Duration(days: 1));
    return '${yesterday.year}-${yesterday.month.toString().padLeft(2, '0')}-${yesterday.day.toString().padLeft(2, '0')}';
  }

  /// Convert DateTime to YYYY-MM-DD string
  String _getDateString(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }

  /// Generate unique referral code for user
  String generateReferralCode(String userId) {
    // Use first 8 characters of userId + random suffix
    final prefix = userId.length > 6 ? userId.substring(0, 6) : userId;
    final timestamp = DateTime.now().millisecondsSinceEpoch.toString();
    final suffix = timestamp.substring(timestamp.length - 3);
    return '${prefix.toUpperCase()}$suffix';
  }
}

/// Result of a BR currency transaction
class BRTransactionResult {
  final bool success;
  final String message;
  final int? amount;
  final int? newBalance;
  final Map<String, dynamic>? metadata;

  BRTransactionResult({
    required this.success,
    required this.message,
    this.amount,
    this.newBalance,
    this.metadata,
  });
}

/// User's login streak information
class StreakInfo {
  final int currentStreak;
  final int longestStreak;
  final int daysUntilBonus;

  StreakInfo({
    required this.currentStreak,
    required this.longestStreak,
    required this.daysUntilBonus,
  });
}

/// BR Transaction record
class BRTransaction {
  final String id;
  final String userId;
  final String type; // 'earn' or 'spend'
  final String source; // 'daily_bonus', 'referral', 'pool_entry', etc.
  final int amount;
  final int balanceBefore;
  final int balanceAfter;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;

  BRTransaction({
    required this.id,
    required this.userId,
    required this.type,
    required this.source,
    required this.amount,
    required this.balanceBefore,
    required this.balanceAfter,
    required this.metadata,
    required this.timestamp,
  });

  factory BRTransaction.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;

    return BRTransaction(
      id: doc.id,
      userId: data['userId'] ?? '',
      type: data['type'] ?? '',
      source: data['source'] ?? '',
      amount: (data['amount'] ?? 0) as int,
      balanceBefore: (data['balanceBefore'] ?? 0) as int,
      balanceAfter: (data['balanceAfter'] ?? 0) as int,
      metadata: data['metadata'] ?? {},
      timestamp: (data['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'type': type,
      'source': source,
      'amount': amount,
      'balanceBefore': balanceBefore,
      'balanceAfter': balanceAfter,
      'metadata': metadata,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  /// User-friendly source description
  String get sourceDescription {
    switch (source) {
      case 'daily_bonus':
        return 'Daily Login Bonus';
      case 'streak_bonus':
        return '7-Day Streak Bonus';
      case 'referral':
        return 'Friend Referral';
      case 'ad_watch':
        return 'Video Ad Reward';
      case 'achievement':
        return 'Achievement Unlocked';
      case 'pool_entry':
        return 'Pool Entry Fee';
      case 'admin_grant':
        return 'Admin Grant';
      case 'admin_deduct':
        return 'Admin Deduction';
      default:
        return source;
    }
  }

  /// Get daily bonus status for UI display
  Future<Map<String, dynamic>> getDailyBonusStatus(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();

      if (!doc.exists) {
        return {
          'canClaim': true,
          'currentStreak': 0,
          'longestStreak': 0,
          'nextBonusAt': null,
        };
      }

      final data = doc.data()!;
      final lastBonus = data['lastDailyBonus'] as Timestamp?;
      final currentStreak = (data['loginStreak'] ?? 0) as int;
      final longestStreak = (data['longestLoginStreak'] ?? 0) as int;

      bool canClaim = true;
      DateTime? nextBonusAt;

      if (lastBonus != null) {
        final today = _getTodayDateString();
        final lastBonusDate = _getDateString(lastBonus.toDate());

        if (today == lastBonusDate) {
          // Already claimed today
          canClaim = false;
          // Next bonus is tomorrow at midnight
          final now = DateTime.now();
          nextBonusAt = DateTime(now.year, now.month, now.day + 1);
        }
      }

      return {
        'canClaim': canClaim,
        'currentStreak': currentStreak,
        'longestStreak': longestStreak,
        'nextBonusAt': nextBonusAt,
      };
    } catch (e) {
      debugPrint('Error getting daily bonus status: $e');
      return {
        'canClaim': false,
        'currentStreak': 0,
        'longestStreak': 0,
        'nextBonusAt': null,
      };
    }
  }

  /// Claim daily bonus with simplified map return (for UI convenience)
  Future<Map<String, dynamic>> claimDailyBonusAsMap(String userId) async {
    final result = await claimDailyBonus(userId);

    return {
      'success': result.success,
      'message': result.message,
      'amount': result.amount ?? 0,
      'newBalance': result.newBalance ?? 0,
      'streakBonus': result.metadata?['streakBonusEarned'] ?? false,
      'newStreak': result.metadata?['streak'] ?? 1,
    };
  }
}
