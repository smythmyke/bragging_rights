import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/welcome_back_data.dart';

/// Service to fetch Welcome Back overlay data
class WelcomeBackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  /// Fetch welcome back data for current user
  Future<WelcomeBackData?> getWelcomeBackData() async {
    try {
      print('📊 WelcomeBackService: Starting data fetch...');

      final user = _auth.currentUser;
      if (user == null) {
        print('❌ WelcomeBackService: No current user');
        return null;
      }

      print('✅ WelcomeBackService: User ID: ${user.uid}');

      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (!userDoc.exists) {
        print('❌ WelcomeBackService: User document does not exist');
        return null;
      }

      print('✅ WelcomeBackService: User document found');

      final userData = userDoc.data()!;

      // Get last login timestamp
      final lastLogin = (userData['lastLoginAt'] as Timestamp?)?.toDate() ?? DateTime.now();

      // Get snapshot data for comparison
      final oldBalance = userData['lastSeenBalance'] ?? 0;
      final oldGlobalRank = userData['lastSeenGlobalRank'] ?? 999;
      final oldFriendsRank = userData['lastSeenFriendsRank'] ?? 999;

      // Get current wallet balance (with permission error handling)
      int newBalance = 0;
      try {
        final walletDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('wallet')
            .doc('current')
            .get();
        newBalance = walletDoc.data()?['balance'] ?? 0;
        print('✅ WelcomeBackService: Wallet balance loaded: $newBalance BR');
      } catch (e) {
        print('⚠️ WelcomeBackService: Wallet permission denied or not found, using default balance');
        newBalance = 0;
      }

      // Get current stats (with permission error handling)
      int totalBets = 0;
      int wins = 0;
      int losses = 0;
      double winRate = 0.0;
      int currentStreak = 0;
      int totalProfit = 0;

      try {
        final statsDoc = await _firestore
            .collection('users')
            .doc(user.uid)
            .collection('stats')
            .doc('overall')
            .get();

        final stats = statsDoc.data() ?? {};
        totalBets = stats['totalBets'] ?? 0;
        wins = stats['wins'] ?? 0;
        losses = stats['losses'] ?? 0;
        winRate = stats['winRate']?.toDouble() ?? 0.0;
        currentStreak = stats['currentStreak'] ?? 0;
        totalProfit = stats['totalProfit'] ?? 0;
        print('✅ WelcomeBackService: Stats loaded successfully');
      } catch (e) {
        print('⚠️ WelcomeBackService: Stats permission denied or not found, using defaults');
        // Use default values (already set above)
      }

      // Get settled bets since last login
      final settledBets = await _getSettledBetsSinceLastLogin(user.uid, lastLogin);

      // Get current ranks (mock data for now - implement leaderboard service later)
      final newGlobalRank = await _getGlobalRank(user.uid);
      final newFriendsRank = await _getFriendsRank(user.uid);

      // Get friends passed
      final friendsPassed = await _getFriendsPassed(user.uid, oldFriendsRank, newFriendsRank);

      // Get active bets count
      final activeBetsCount = await _getActiveBetsCount(user.uid);

      print('✅ WelcomeBackService: Data compiled successfully');
      print('   - Balance: $oldBalance → $newBalance');
      print('   - Settled bets: ${settledBets.length}');
      print('   - Active bets: $activeBetsCount');
      print('   - Stats: $wins-$losses ($winRate%)');

      final welcomeData = WelcomeBackData(
        lastLoginAt: lastLogin,
        oldBalance: oldBalance,
        newBalance: newBalance,
        settledBets: settledBets,
        oldGlobalRank: oldGlobalRank,
        newGlobalRank: newGlobalRank,
        oldFriendsRank: oldFriendsRank,
        newFriendsRank: newFriendsRank,
        friendsPassed: friendsPassed,
        activeBetsCount: activeBetsCount,
        totalBets: totalBets,
        wins: wins,
        losses: losses,
        winRate: winRate,
        currentStreak: currentStreak,
        totalProfit: totalProfit,
      );

      print('🎉 WelcomeBackService: Returning data!');
      return welcomeData;
    } catch (e) {
      print('❌ Error fetching welcome back data: $e');
      print('Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Get bets settled since last login
  Future<List<SettledBet>> _getSettledBetsSinceLastLogin(
    String userId,
    DateTime lastLogin,
  ) async {
    try {
      // Query bets that were settled after last login
      final betsQuery = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bets')
          .where('status', isEqualTo: 'settled')
          .where('settledAt', isGreaterThan: Timestamp.fromDate(lastLogin))
          .orderBy('settledAt', descending: true)
          .limit(5) // Show max 5 bets
          .get();

      return betsQuery.docs
          .map((doc) => SettledBet.fromFirestore(doc))
          .toList();
    } catch (e) {
      print('Error fetching settled bets: $e');
      return [];
    }
  }

  /// Get global rank (mock implementation - replace with real leaderboard service)
  Future<int> _getGlobalRank(String userId) async {
    try {
      // TODO: Implement real global leaderboard ranking
      // For now, return a mock rank based on total profit
      final statsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('overall')
          .get();

      final totalProfit = statsDoc.data()?['totalProfit'] ?? 0;

      // Mock ranking based on profit
      if (totalProfit > 5000) return 38;
      if (totalProfit > 2000) return 75;
      if (totalProfit > 1000) return 150;
      return 250;
    } catch (e) {
      return 999;
    }
  }

  /// Get friends rank (mock implementation)
  Future<int> _getFriendsRank(String userId) async {
    try {
      // TODO: Implement real friends leaderboard ranking
      final statsDoc = await _firestore
          .collection('users')
          .doc(userId)
          .collection('stats')
          .doc('overall')
          .get();

      final totalProfit = statsDoc.data()?['totalProfit'] ?? 0;

      // Mock ranking
      if (totalProfit > 2000) return 2;
      if (totalProfit > 1000) return 3;
      return 5;
    } catch (e) {
      return 999;
    }
  }

  /// Get list of friends user passed in ranking
  Future<List<String>> _getFriendsPassed(
    String userId,
    int oldRank,
    int newRank,
  ) async {
    try {
      if (newRank >= oldRank) return []; // Didn't improve rank

      // TODO: Query friends who are now ranked below user but were above before
      // For now, return mock data
      if (newRank < oldRank) {
        return ['Mike']; // Mock friend name
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  /// Get count of active (pending) bets
  Future<int> _getActiveBetsCount(String userId) async {
    try {
      final activeBets = await _firestore
          .collection('users')
          .doc(userId)
          .collection('bets')
          .where('status', isEqualTo: 'pending')
          .count()
          .get();

      return activeBets.count ?? 0;
    } catch (e) {
      print('Error getting active bets count: $e');
      return 0;
    }
  }

  /// Update user's last login data (call after overlay is dismissed)
  Future<void> updateLastLoginData({
    required String userId,
    required int currentBalance,
    required int globalRank,
    required int friendsRank,
  }) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'lastLoginAt': FieldValue.serverTimestamp(),
        'lastSeenBalance': currentBalance,
        'lastSeenGlobalRank': globalRank,
        'lastSeenFriendsRank': friendsRank,
      });
    } catch (e) {
      print('Error updating last login data: $e');
    }
  }

  /// Check if user should see welcome back overlay
  /// (Shows every time user opens the app)
  Future<bool> shouldShowWelcomeBack(String userId) async {
    try {
      final userDoc = await _firestore.collection('users').doc(userId).get();
      if (!userDoc.exists) return false;

      // Always show the overlay on app launch
      return true;
    } catch (e) {
      return false;
    }
  }
}
