import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/mini_game_model.dart';

/// Service for managing mini-games, leaderboards, and user stats
class MiniGamesService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Get all active mini-games for the current week
  Stream<List<MiniGameModel>> getActiveGames() {
    return _firestore
        .collection('mini-games')
        .where('active', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id;
        return MiniGameModel.fromMap(data);
      }).toList();
    });
  }

  /// Get a specific game by ID
  Future<MiniGameModel?> getGame(String gameId) async {
    final doc = await _firestore.collection('mini-games').doc(gameId).get();
    if (!doc.exists) return null;

    final data = doc.data()!;
    data['id'] = doc.id;
    return MiniGameModel.fromMap(data);
  }

  /// Get current week's leaderboard for a game
  Stream<GameLeaderboard?> getGameLeaderboard(String gameId) {
    // Get current week number
    final now = DateTime.now();
    final weekNumber = _getWeekNumber(now);
    final leaderboardId = '${gameId}_week_$weekNumber';

    return _firestore
        .collection('leaderboards')
        .doc(leaderboardId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data()!;
      data['id'] = snapshot.id;
      return GameLeaderboard.fromMap(data);
    });
  }

  /// Submit a score to the leaderboard
  Future<bool> submitScore({
    required String gameId,
    required int score,
    required String username,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final now = DateTime.now();
      final weekNumber = _getWeekNumber(now);
      final leaderboardId = '${gameId}_week_$weekNumber';

      final entry = LeaderboardEntry(
        userId: user.uid,
        username: username,
        score: score,
        timestamp: now,
      );

      // Get or create leaderboard
      final leaderboardRef = _firestore.collection('leaderboards').doc(leaderboardId);
      final leaderboardDoc = await leaderboardRef.get();

      if (!leaderboardDoc.exists) {
        // Create new leaderboard for this week
        final weekStart = _getWeekStart(now);
        final weekEnd = weekStart.add(const Duration(days: 7));

        await leaderboardRef.set({
          'gameId': gameId,
          'weekStart': Timestamp.fromDate(weekStart),
          'weekEnd': Timestamp.fromDate(weekEnd),
          'scores': [entry.toMap()],
          'active': true,
        });
      } else {
        // Add score to existing leaderboard
        await leaderboardRef.update({
          'scores': FieldValue.arrayUnion([entry.toMap()]),
        });
      }

      // Update user stats
      await _updateUserStats(gameId, score);

      return true;
    } catch (e) {
      print('Error submitting score: $e');
      return false;
    }
  }

  /// Get user statistics for a specific game
  Stream<UserGameStats?> getUserGameStats(String gameId) {
    final user = _auth.currentUser;
    if (user == null) return Stream.value(null);

    return _firestore
        .collection('user-stats')
        .doc(user.uid)
        .collection('games')
        .doc(gameId)
        .snapshots()
        .map((snapshot) {
      if (!snapshot.exists) return null;

      final data = snapshot.data()!;
      data['userId'] = user.uid;
      data['gameId'] = gameId;
      return UserGameStats.fromMap(data);
    });
  }

  /// Deduct BR for playing a game (5 BR entry fee)
  Future<bool> deductEntryFee() async {
    final user = _auth.currentUser;
    if (user == null) return false;

    try {
      final userRef = _firestore.collection('users').doc(user.uid);
      final userDoc = await userRef.get();

      if (!userDoc.exists) return false;

      final currentBR = userDoc.data()?['braggingRights'] ?? 0;

      if (currentBR < 5) {
        return false; // Not enough BR
      }

      await userRef.update({
        'braggingRights': FieldValue.increment(-5),
      });

      return true;
    } catch (e) {
      print('Error deducting entry fee: $e');
      return false;
    }
  }

  /// Update user statistics after playing
  Future<void> _updateUserStats(String gameId, int score) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final statsRef = _firestore
        .collection('user-stats')
        .doc(user.uid)
        .collection('games')
        .doc(gameId);

    final statsDoc = await statsRef.get();

    if (!statsDoc.exists) {
      // Create new stats
      await statsRef.set({
        'attempts': 1,
        'bestScore': score,
        'brSpent': 5,
        'lastPlayed': Timestamp.now(),
      });
    } else {
      // Update existing stats
      final currentBest = statsDoc.data()?['bestScore'] ?? 0;
      final newBest = score > currentBest ? score : currentBest;

      await statsRef.update({
        'attempts': FieldValue.increment(1),
        'bestScore': newBest,
        'brSpent': FieldValue.increment(5),
        'lastPlayed': Timestamp.now(),
      });
    }
  }

  /// Get user's current BR balance
  Future<int> getUserBRBalance() async {
    final user = _auth.currentUser;
    if (user == null) return 0;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      return userDoc.data()?['braggingRights'] ?? 0;
    } catch (e) {
      print('Error getting BR balance: $e');
      return 0;
    }
  }

  /// Get week number from date
  int _getWeekNumber(DateTime date) {
    final firstDayOfYear = DateTime(date.year, 1, 1);
    final daysSinceFirstDay = date.difference(firstDayOfYear).inDays;
    return (daysSinceFirstDay / 7).floor() + 1;
  }

  /// Get start of the week (Monday 00:00:00)
  DateTime _getWeekStart(DateTime date) {
    final weekday = date.weekday;
    final daysToSubtract = weekday - 1; // Monday is 1
    final weekStart = date.subtract(Duration(days: daysToSubtract));
    return DateTime(weekStart.year, weekStart.month, weekStart.day);
  }

  /// Get user's rank in the leaderboard
  Future<int?> getUserRank(String gameId) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    try {
      final now = DateTime.now();
      final weekNumber = _getWeekNumber(now);
      final leaderboardId = '${gameId}_week_$weekNumber';

      final leaderboardDoc = await _firestore
          .collection('leaderboards')
          .doc(leaderboardId)
          .get();

      if (!leaderboardDoc.exists) return null;

      final data = leaderboardDoc.data()!;
      data['id'] = leaderboardDoc.id;
      final leaderboard = GameLeaderboard.fromMap(data);

      final sortedScores = leaderboard.getSortedScores();

      // Find user's best score
      final userScores = sortedScores
          .where((entry) => entry.userId == user.uid)
          .toList();

      if (userScores.isEmpty) return null;

      final userBestScore = userScores.first.score;

      // Find rank by counting how many unique users have better scores
      final betterScores = sortedScores
          .where((entry) => entry.score > userBestScore)
          .map((entry) => entry.userId)
          .toSet()
          .length;

      return betterScores + 1;
    } catch (e) {
      print('Error getting user rank: $e');
      return null;
    }
  }
}
