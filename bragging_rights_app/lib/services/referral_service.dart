import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:share_plus/share_plus.dart';
import 'br_currency_service.dart';

/// Referral Service - Manage user referrals and viral growth
class ReferralService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BRCurrencyService _brService = BRCurrencyService();

  /// Initialize referral code for new user
  Future<String> initializeReferralCode(String userId) async {
    try {
      final userRef = _firestore.collection('users').doc(userId);
      final doc = await userRef.get();

      if (!doc.exists) {
        throw Exception('User not found');
      }

      // Check if user already has a referral code
      final existingCode = doc.data()?['referralCode'] as String?;
      if (existingCode != null && existingCode.isNotEmpty) {
        return existingCode;
      }

      // Generate new referral code
      final code = _brService.generateReferralCode(userId);

      // Save to user document
      await userRef.update({
        'referralCode': code,
      });

      debugPrint('✅ Generated referral code for user $userId: $code');
      return code;
    } catch (e) {
      debugPrint('Error initializing referral code: $e');
      rethrow;
    }
  }

  /// Get user's referral code
  Future<String?> getReferralCode(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return null;
      return doc.data()?['referralCode'] as String?;
    } catch (e) {
      debugPrint('Error getting referral code: $e');
      return null;
    }
  }

  /// Validate referral code and get referrer info
  Future<ReferrerInfo?> validateReferralCode(String code) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('referralCode', isEqualTo: code.toUpperCase())
          .limit(1)
          .get();

      if (snapshot.docs.isEmpty) {
        return null; // Invalid code
      }

      final doc = snapshot.docs.first;
      final data = doc.data();

      return ReferrerInfo(
        userId: doc.id,
        username: data['username'] ?? 'Unknown',
        referralCode: code.toUpperCase(),
      );
    } catch (e) {
      debugPrint('Error validating referral code: $e');
      return null;
    }
  }

  /// Apply referral code to new user (called during signup)
  Future<ReferralResult> applyReferralCode({
    required String newUserId,
    required String newUsername,
    required String referralCode,
  }) async {
    try {
      // Validate referral code
      final referrerInfo = await validateReferralCode(referralCode);
      if (referrerInfo == null) {
        return ReferralResult(
          success: false,
          message: 'Invalid referral code',
        );
      }

      // Prevent self-referral
      if (referrerInfo.userId == newUserId) {
        return ReferralResult(
          success: false,
          message: 'Cannot use your own referral code',
        );
      }

      // Check if new user already has a referrer
      final newUserDoc = await _firestore.collection('users').doc(newUserId).get();
      if (newUserDoc.exists && newUserDoc.data()?['referredBy'] != null) {
        return ReferralResult(
          success: false,
          message: 'Referral code already applied',
        );
      }

      // Mark new user as referred
      await _firestore.collection('users').doc(newUserId).update({
        'referredBy': referrerInfo.userId,
        'referredByCode': referralCode.toUpperCase(),
      });

      // Award 200 BR to referrer
      final result = await _brService.awardReferralBonus(
        referrerId: referrerInfo.userId,
        referredUserId: newUserId,
        referredUsername: newUsername,
      );

      if (result.success) {
        debugPrint('✅ Referral successful: ${referrerInfo.username} referred $newUsername');
        return ReferralResult(
          success: true,
          message: '${referrerInfo.username} earned 200 BR for referring you!',
          referrerInfo: referrerInfo,
        );
      } else {
        return ReferralResult(
          success: false,
          message: 'Failed to award referral bonus',
        );
      }
    } catch (e) {
      debugPrint('Error applying referral code: $e');
      return ReferralResult(
        success: false,
        message: 'Error applying referral code: $e',
      );
    }
  }

  /// Get count of users referred by this user
  Future<int> getReferralCount(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .count()
          .get();

      return snapshot.count ?? 0;
    } catch (e) {
      debugPrint('Error getting referral count: $e');
      return 0;
    }
  }

  /// Get list of users referred by this user
  Future<List<ReferredUser>> getReferredUsers(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .where('referredBy', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .limit(50)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return ReferredUser(
          userId: doc.id,
          username: data['username'] ?? 'Unknown',
          joinedAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList();
    } catch (e) {
      debugPrint('Error getting referred users: $e');
      return [];
    }
  }

  /// Share referral code via native share sheet
  Future<void> shareReferralCode({
    required String referralCode,
    required String username,
  }) async {
    try {
      final message = '''
Join me on Bragging Rights - the ultimate sports prediction app!

Use my referral code: $referralCode

We both earn rewards when you sign up!

Download now: https://braggingrights.app
''';

      await Share.share(
        message,
        subject: '$username invited you to Bragging Rights',
      );

      debugPrint('📤 Shared referral code: $referralCode');
    } catch (e) {
      debugPrint('Error sharing referral code: $e');
      rethrow;
    }
  }

  /// Get referral stats for user dashboard
  Future<ReferralStats> getReferralStats(String userId) async {
    try {
      final referralCount = await getReferralCount(userId);
      final referralCode = await getReferralCode(userId);

      // Calculate total BR earned from referrals
      // Query br_transactions for referral earnings
      final transactionsSnapshot = await _firestore
          .collection('br_transactions')
          .where('userId', isEqualTo: userId)
          .where('source', isEqualTo: 'referral')
          .get();

      int totalBrEarned = 0;
      for (final doc in transactionsSnapshot.docs) {
        totalBrEarned += (doc.data()['amount'] ?? 0) as int;
      }

      return ReferralStats(
        referralCode: referralCode ?? '',
        totalReferrals: referralCount,
        totalBrEarned: totalBrEarned,
        potentialBr: referralCount * BRCurrencyService.REFERRAL_BONUS_AMOUNT,
      );
    } catch (e) {
      debugPrint('Error getting referral stats: $e');
      return ReferralStats(
        referralCode: '',
        totalReferrals: 0,
        totalBrEarned: 0,
        potentialBr: 0,
      );
    }
  }

  /// Check if user was referred (for welcome bonus, etc.)
  Future<bool> wasReferred(String userId) async {
    try {
      final doc = await _firestore.collection('users').doc(userId).get();
      if (!doc.exists) return false;
      return doc.data()?['referredBy'] != null;
    } catch (e) {
      debugPrint('Error checking referral status: $e');
      return false;
    }
  }
}

/// Information about a referrer
class ReferrerInfo {
  final String userId;
  final String username;
  final String referralCode;

  ReferrerInfo({
    required this.userId,
    required this.username,
    required this.referralCode,
  });
}

/// Result of applying a referral code
class ReferralResult {
  final bool success;
  final String message;
  final ReferrerInfo? referrerInfo;

  ReferralResult({
    required this.success,
    required this.message,
    this.referrerInfo,
  });
}

/// User who was referred
class ReferredUser {
  final String userId;
  final String username;
  final DateTime joinedAt;

  ReferredUser({
    required this.userId,
    required this.username,
    required this.joinedAt,
  });
}

/// Referral statistics for user dashboard
class ReferralStats {
  final String referralCode;
  final int totalReferrals;
  final int totalBrEarned;
  final int potentialBr;

  ReferralStats({
    required this.referralCode,
    required this.totalReferrals,
    required this.totalBrEarned,
    required this.potentialBr,
  });

  /// Calculate BR per referral average
  double get averageBrPerReferral {
    if (totalReferrals == 0) return 0;
    return totalBrEarned / totalReferrals;
  }
}
