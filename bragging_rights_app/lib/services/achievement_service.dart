import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'br_currency_service.dart';

/// Achievement Service - Gamification and rewards
class AchievementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BRCurrencyService _brService = BRCurrencyService();

  /// Check and award achievements after specific events
  Future<List<AchievementUnlocked>> checkAchievements({
    required String userId,
    required AchievementTrigger trigger,
    Map<String, dynamic>? metadata,
  }) async {
    final List<AchievementUnlocked> unlocked = [];

    try {
      // Get all active achievements for this trigger type
      final achievementsSnapshot = await _firestore
          .collection('achievements')
          .where('isActive', isEqualTo: true)
          .where('requirements.type', isEqualTo: trigger.name)
          .get();

      for (final achievementDoc in achievementsSnapshot.docs) {
        final achievement = Achievement.fromFirestore(achievementDoc);

        // Check user's progress for this achievement
        final progressDoc = await _firestore
            .collection('users')
            .doc(userId)
            .collection('achievements')
            .doc(achievement.id)
            .get();

        AchievementProgress progress;
        if (!progressDoc.exists) {
          // First time tracking this achievement
          progress = AchievementProgress(
            achievementId: achievement.id,
            userId: userId,
            progress: 0,
            target: achievement.requirements.count,
            completed: false,
          );
        } else {
          progress = AchievementProgress.fromFirestore(progressDoc);
        }

        // Skip if already completed
        if (progress.completed) continue;

        // Increment progress
        final newProgress = progress.progress + 1;
        final isCompleted = newProgress >= achievement.requirements.count;

        // Update progress
        await _firestore
            .collection('users')
            .doc(userId)
            .collection('achievements')
            .doc(achievement.id)
            .set({
          'achievementId': achievement.id,
          'userId': userId,
          'progress': newProgress,
          'target': achievement.requirements.count,
          'completed': isCompleted,
          'completedAt': isCompleted ? FieldValue.serverTimestamp() : null,
          'rewardClaimed': false,
          'rewardClaimedAt': null,
        });

        // If achievement unlocked, award BR
        if (isCompleted) {
          final brResult = await _brService.spendBR(
            userId: userId,
            amount: -achievement.rewardBR, // Negative = earn
            source: 'achievement',
            metadata: {
              'achievementId': achievement.id,
              'achievementTitle': achievement.title,
            },
          );

          // Mark reward as claimed
          await _firestore
              .collection('users')
              .doc(userId)
              .collection('achievements')
              .doc(achievement.id)
              .update({
            'rewardClaimed': true,
            'rewardClaimedAt': FieldValue.serverTimestamp(),
          });

          unlocked.add(AchievementUnlocked(
            achievement: achievement,
            brAwarded: achievement.rewardBR,
          ));

          debugPrint('🏆 Achievement unlocked: ${achievement.title} (+${achievement.rewardBR} BR)');
        }
      }
    } catch (e) {
      debugPrint('Error checking achievements: $e');
    }

    return unlocked;
  }

  /// Get user's achievement progress
  Future<List<AchievementProgress>> getUserAchievements(String userId) async {
    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(userId)
          .collection('achievements')
          .get();

      return snapshot.docs
          .map((doc) => AchievementProgress.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting user achievements: $e');
      return [];
    }
  }

  /// Get all available achievements
  Future<List<Achievement>> getAllAchievements() async {
    try {
      final snapshot = await _firestore
          .collection('achievements')
          .where('isActive', isEqualTo: true)
          .get();

      return snapshot.docs
          .map((doc) => Achievement.fromFirestore(doc))
          .toList();
    } catch (e) {
      debugPrint('Error getting achievements: $e');
      return [];
    }
  }

  /// Initialize default achievements (run once on app setup)
  Future<void> initializeDefaultAchievements() async {
    final defaultAchievements = [
      Achievement(
        id: 'first_win',
        title: 'First Victory',
        description: 'Win your first pool',
        icon: '🏆',
        rewardBR: 100,
        requirements: AchievementRequirement(
          type: AchievementTrigger.pool_win.name,
          count: 1,
        ),
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Achievement(
        id: 'hot_streak',
        title: 'Hot Streak',
        description: 'Win 5 pools in a row',
        icon: '🔥',
        rewardBR: 500,
        requirements: AchievementRequirement(
          type: AchievementTrigger.win_streak.name,
          count: 5,
        ),
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Achievement(
        id: 'underdog_master',
        title: 'Underdog Master',
        description: 'Win 10 pools by picking underdogs',
        icon: '🐶',
        rewardBR: 300,
        requirements: AchievementRequirement(
          type: AchievementTrigger.underdog_win.name,
          count: 10,
        ),
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Achievement(
        id: 'social_butterfly',
        title: 'Social Butterfly',
        description: 'Refer 5 friends to Bragging Rights',
        icon: '🦋',
        rewardBR: 250,
        requirements: AchievementRequirement(
          type: AchievementTrigger.referral.name,
          count: 5,
        ),
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Achievement(
        id: 'dedicated_player',
        title: 'Dedicated Player',
        description: 'Maintain a 30-day login streak',
        icon: '📅',
        rewardBR: 1000,
        requirements: AchievementRequirement(
          type: AchievementTrigger.login_streak.name,
          count: 30,
        ),
        isActive: true,
        createdAt: DateTime.now(),
      ),
      Achievement(
        id: 'pool_veteran',
        title: 'Pool Veteran',
        description: 'Enter 100 pools',
        icon: '🎯',
        rewardBR: 200,
        requirements: AchievementRequirement(
          type: AchievementTrigger.pool_entry.name,
          count: 100,
        ),
        isActive: true,
        createdAt: DateTime.now(),
      ),
    ];

    for (final achievement in defaultAchievements) {
      await _firestore
          .collection('achievements')
          .doc(achievement.id)
          .set(achievement.toMap(), SetOptions(merge: true));
    }

    debugPrint('✅ Initialized ${defaultAchievements.length} default achievements');
  }
}

/// Achievement trigger events
enum AchievementTrigger {
  pool_win,       // Won a pool
  pool_entry,     // Entered a pool
  underdog_win,   // Won by picking underdog
  win_streak,     // Consecutive wins
  referral,       // Referred a friend
  login_streak,   // Consecutive login days
  perfect_week,   // 100% picks correct in a week
}

/// Achievement definition
class Achievement {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int rewardBR;
  final AchievementRequirement requirements;
  final bool isActive;
  final DateTime createdAt;

  Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.rewardBR,
    required this.requirements,
    required this.isActive,
    required this.createdAt,
  });

  factory Achievement.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Achievement(
      id: doc.id,
      title: data['title'] ?? '',
      description: data['description'] ?? '',
      icon: data['icon'] ?? '🏆',
      rewardBR: (data['rewardBR'] ?? 0) as int,
      requirements: AchievementRequirement.fromMap(data['requirements'] ?? {}),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'icon': icon,
      'rewardBR': rewardBR,
      'requirements': requirements.toMap(),
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }
}

/// Achievement requirement definition
class AchievementRequirement {
  final String type; // AchievementTrigger name
  final int count;

  AchievementRequirement({
    required this.type,
    required this.count,
  });

  factory AchievementRequirement.fromMap(Map<String, dynamic> map) {
    return AchievementRequirement(
      type: map['type'] ?? '',
      count: (map['count'] ?? 0) as int,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'type': type,
      'count': count,
    };
  }
}

/// User's progress toward an achievement
class AchievementProgress {
  final String achievementId;
  final String userId;
  final int progress;
  final int target;
  final bool completed;
  final DateTime? completedAt;
  final bool rewardClaimed;
  final DateTime? rewardClaimedAt;

  AchievementProgress({
    required this.achievementId,
    required this.userId,
    required this.progress,
    required this.target,
    required this.completed,
    this.completedAt,
    this.rewardClaimed = false,
    this.rewardClaimedAt,
  });

  factory AchievementProgress.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return AchievementProgress(
      achievementId: data['achievementId'] ?? '',
      userId: data['userId'] ?? '',
      progress: (data['progress'] ?? 0) as int,
      target: (data['target'] ?? 0) as int,
      completed: data['completed'] ?? false,
      completedAt: (data['completedAt'] as Timestamp?)?.toDate(),
      rewardClaimed: data['rewardClaimed'] ?? false,
      rewardClaimedAt: (data['rewardClaimedAt'] as Timestamp?)?.toDate(),
    );
  }

  double get progressPercent {
    if (target == 0) return 0;
    return (progress / target) * 100;
  }

  int get remaining => target - progress;
}

/// Achievement unlock notification
class AchievementUnlocked {
  final Achievement achievement;
  final int brAwarded;

  AchievementUnlocked({
    required this.achievement,
    required this.brAwarded,
  });
}
