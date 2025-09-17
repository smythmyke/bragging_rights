import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import 'game_cache_service.dart';

/// Firestore-based caching service that provides shared caching across all users
/// with intelligent freshness rules and lightweight live score updates
class FirestoreCacheService {
  static final FirestoreCacheService _instance = FirestoreCacheService._internal();
  factory FirestoreCacheService() => _instance;
  FirestoreCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameCacheService _localCache = GameCacheService();

  // Rate limiting for API calls
  static final Map<String, DateTime> _lastApiCall = {};
  static const Map<String, Duration> _rateLimits = {
    'NFL': Duration(minutes: 5),
    'NBA': Duration(minutes: 5),
    'MLB': Duration(minutes: 10),
    'NHL': Duration(minutes: 10),
    'SOCCER': Duration(minutes: 15),
    'MMA': Duration(minutes: 30),
    'BOXING': Duration(minutes: 30),
    'LIVE_SCORES': Duration(seconds: 30),
  };

  /// Get freshness interval based on game status and proximity
  static Duration getFreshnessInterval(GameModel game) {
    final now = DateTime.now();
    final timeToGame = game.gameTime.difference(now);

    // Completed games rarely change
    if (game.status.toLowerCase() == 'completed' ||
        game.status.toLowerCase() == 'final') {
      return const Duration(days: 7);
    }

    // Live games need frequent score updates only
    if (game.status.toLowerCase() == 'in_progress' ||
        game.status.toLowerCase() == 'live') {
      return const Duration(seconds: 30);
    }

    // Scheduled games based on proximity
    if (timeToGame.isNegative) {
      // Game should have started but status not updated
      return const Duration(minutes: 1);
    } else if (timeToGame.inHours <= 1) {
      // About to start
      return const Duration(minutes: 5);
    } else if (timeToGame.inHours <= 24) {
      // Today's games
      return const Duration(hours: 1);
    } else if (timeToGame.inDays <= 7) {
      // This week
      return const Duration(hours: 6);
    } else {
      // Future games
      return const Duration(days: 1);
    }
  }

  /// Check if API call can be made based on rate limits
  bool _canMakeApiCall(String type) {
    final lastCall = _lastApiCall[type];
    if (lastCall == null) return true;

    final limit = _rateLimits[type] ?? const Duration(minutes: 5);
    return DateTime.now().difference(lastCall) >= limit;
  }

  /// Record API call for rate limiting
  void _recordApiCall(String type) {
    _lastApiCall[type] = DateTime.now();
  }

  /// Get games for a specific time period with intelligent caching
  Future<List<GameModel>> getGamesForPeriod({
    required String period,
    required String sport,
    bool forceRefresh = false,
  }) async {
    debugPrint('🎯 Getting $sport games for period: $period');

    // Step 1: Define date range based on period
    final dateRange = _getDateRangeForPeriod(period);

    // Step 2: Try local cache first (fastest)
    if (!forceRefresh) {
      final localGames = await _localCache.getCachedGames();
      if (localGames != null && localGames.isNotEmpty) {
        final filteredGames = _filterGamesByPeriodAndSport(
          localGames,
          dateRange,
          sport
        );
        if (filteredGames.isNotEmpty) {
          debugPrint('⚡ Returned ${filteredGames.length} games from local cache');

          // Background refresh if needed
          _refreshInBackground(period, sport);
          return filteredGames;
        }
      }
    }

    // Step 3: Query Firestore for games
    final firestoreGames = await _queryFirestoreGames(
      sport: sport,
      startDate: dateRange.start,
      endDate: dateRange.end,
    );

    // Step 4: Check staleness and separate by type
    final liveGames = <GameModel>[];
    final staleGames = <GameModel>[];
    final freshGames = <GameModel>[];

    for (final game in firestoreGames) {
      if (_isLiveGame(game)) {
        liveGames.add(game);
      } else if (_isStale(game)) {
        staleGames.add(game);
      } else {
        freshGames.add(game);
      }
    }

    debugPrint('📊 Game status - Fresh: ${freshGames.length}, Live: ${liveGames.length}, Stale: ${staleGames.length}');

    // Step 5: Update live game scores if needed (lightweight)
    if (liveGames.isNotEmpty && _canMakeApiCall('LIVE_SCORES')) {
      await _updateLiveScores(liveGames);
      _recordApiCall('LIVE_SCORES');
    }

    // Step 6: Refresh stale games if needed
    if (staleGames.isNotEmpty && _canMakeApiCall(sport)) {
      await _refreshStaleGames(staleGames, sport);
      _recordApiCall(sport);
    }

    // Step 7: Combine all games and cache locally
    final allGames = [...freshGames, ...liveGames, ...staleGames];
    await _localCache.cacheGames(allGames);

    return allGames;
  }

  /// Query Firestore for games
  Future<List<GameModel>> _queryFirestoreGames({
    required String sport,
    required DateTime startDate,
    required DateTime endDate,
  }) async {
    try {
      final query = _firestore
          .collection('games')
          .where('sport', isEqualTo: sport.toUpperCase())
          .where('gameTime', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
          .where('gameTime', isLessThanOrEqualTo: Timestamp.fromDate(endDate));

      final snapshot = await query.get();

      debugPrint('🔥 Found ${snapshot.docs.length} $sport games in Firestore');

      return snapshot.docs.map((doc) {
        final data = doc.data();
        data['id'] = doc.id; // Ensure ID is set

        // Add metadata timestamps if they exist
        data['lastFetched'] = data['lastFetched'];
        data['lastScoreUpdate'] = data['lastScoreUpdate'];

        return GameModel.fromMap(data);
      }).toList();
    } catch (e) {
      debugPrint('❌ Error querying Firestore: $e');
      return [];
    }
  }

  /// Save games to Firestore with timestamps
  Future<void> saveGamesToFirestore(List<GameModel> games, {String? sport}) async {
    if (games.isEmpty) return;

    final batch = _firestore.batch();
    final now = FieldValue.serverTimestamp();

    for (final game in games) {
      final docRef = _firestore.collection('games').doc(game.id);

      final data = game.toMap();
      data['lastFetched'] = now;
      data['sport'] = game.sport.toUpperCase();
      data['gameTime'] = Timestamp.fromDate(game.gameTime);

      // Add score update timestamp for live games
      if (_isLiveGame(game)) {
        data['lastScoreUpdate'] = now;
      }

      batch.set(docRef, data, SetOptions(merge: true));
    }

    try {
      await batch.commit();
      debugPrint('💾 Saved ${games.length} games to Firestore');
    } catch (e) {
      debugPrint('❌ Error saving to Firestore: $e');
    }
  }

  /// Update only scores for live games (lightweight)
  Future<void> _updateLiveScores(List<GameModel> liveGames) async {
    debugPrint('🔄 Updating scores for ${liveGames.length} live games');

    // TODO: Implement actual score fetching from ESPN
    // For now, we'll just update the timestamp
    final batch = _firestore.batch();

    for (final game in liveGames) {
      final docRef = _firestore.collection('games').doc(game.id);
      batch.update(docRef, {
        'lastScoreUpdate': FieldValue.serverTimestamp(),
        // In production, add actual score updates:
        // 'homeScore': updatedHomeScore,
        // 'awayScore': updatedAwayScore,
        // 'status': updatedStatus,
      });
    }

    try {
      await batch.commit();
      debugPrint('✅ Updated live scores');
    } catch (e) {
      debugPrint('❌ Error updating live scores: $e');
    }
  }

  /// Refresh stale games with full data
  Future<void> _refreshStaleGames(List<GameModel> staleGames, String sport) async {
    debugPrint('🔄 Refreshing ${staleGames.length} stale $sport games');

    // TODO: Implement actual API call to refresh games
    // For now, just update timestamps
    final batch = _firestore.batch();

    for (final game in staleGames) {
      final docRef = _firestore.collection('games').doc(game.id);
      batch.update(docRef, {
        'lastFetched': FieldValue.serverTimestamp(),
      });
    }

    try {
      await batch.commit();
      debugPrint('✅ Refreshed stale games');
    } catch (e) {
      debugPrint('❌ Error refreshing stale games: $e');
    }
  }

  /// Background refresh for potentially stale data
  void _refreshInBackground(String period, String sport) {
    Future.delayed(const Duration(milliseconds: 500), () async {
      if (_canMakeApiCall(sport)) {
        debugPrint('🔄 Background refresh for $sport games');
        // Implement background refresh logic
      }
    });
  }

  /// Check if a game is live
  bool _isLiveGame(GameModel game) {
    final status = game.status.toLowerCase();
    return status == 'in_progress' ||
           status == 'live' ||
           status == 'active' ||
           status.contains('quarter') ||
           status.contains('half') ||
           status.contains('period') ||
           status.contains('inning');
  }

  /// Check if game data is stale
  bool _isStale(GameModel game) {
    // If no lastFetched timestamp, consider stale
    if (game.toMap()['lastFetched'] == null) return true;

    final lastFetched = (game.toMap()['lastFetched'] as Timestamp?)?.toDate();
    if (lastFetched == null) return true;

    final freshnessInterval = getFreshnessInterval(game);
    final age = DateTime.now().difference(lastFetched);

    return age > freshnessInterval;
  }

  /// Get date range for period
  DateRange _getDateRangeForPeriod(String period) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (period.toLowerCase()) {
      case 'today':
        return DateRange(
          start: today,
          end: today.add(const Duration(days: 1)),
        );
      case 'tomorrow':
        return DateRange(
          start: today.add(const Duration(days: 1)),
          end: today.add(const Duration(days: 2)),
        );
      case 'this week':
      case 'week':
        return DateRange(
          start: today,
          end: today.add(const Duration(days: 7)),
        );
      case 'next week':
        return DateRange(
          start: today.add(const Duration(days: 7)),
          end: today.add(const Duration(days: 14)),
        );
      case 'this month':
      case 'month':
        return DateRange(
          start: today,
          end: today.add(const Duration(days: 30)),
        );
      default:
        // Default to this week
        return DateRange(
          start: today,
          end: today.add(const Duration(days: 7)),
        );
    }
  }

  /// Filter games by period and sport
  List<GameModel> _filterGamesByPeriodAndSport(
    List<GameModel> games,
    DateRange dateRange,
    String sport,
  ) {
    return games.where((game) {
      final matchesSport = sport.toLowerCase() == 'all' ||
                          game.sport.toLowerCase() == sport.toLowerCase();
      final inDateRange = game.gameTime.isAfter(dateRange.start) &&
                          game.gameTime.isBefore(dateRange.end);
      return matchesSport && inDateRange;
    }).toList();
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _localCache.clearCache();
    _lastApiCall.clear();
    debugPrint('🗑️ All caches cleared');
  }

  /// Get cache statistics for monitoring
  Future<Map<String, dynamic>> getCacheStats() async {
    final localAge = await _localCache.getCacheAge();

    return {
      'localCacheAge': localAge?.inSeconds ?? -1,
      'rateLimitStatus': _lastApiCall.map((key, value) {
        final limit = _rateLimits[key] ?? const Duration(minutes: 5);
        final timeSinceCall = DateTime.now().difference(value);
        final canCall = timeSinceCall >= limit;
        return MapEntry(key, {
          'lastCall': value.toIso8601String(),
          'canCall': canCall,
          'nextAvailable': canCall
            ? 'now'
            : value.add(limit).toIso8601String(),
        });
      }),
    };
  }
}

/// Date range helper class
class DateRange {
  final DateTime start;
  final DateTime end;

  DateRange({required this.start, required this.end});
}