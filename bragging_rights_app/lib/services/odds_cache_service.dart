import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import 'odds_api_service.dart';
import 'odds_quota_manager.dart';

/// Conservative caching service for Odds API data
/// Implements time-based cache tiers to minimize API quota usage
///
/// Cache Tiers:
/// - Tier 1 (7+ days): 14 day cache
/// - Tier 2 (1-7 days): 7 day cache
/// - Tier 3 (0-24 hours): 6 hour cache
/// - Tier 4 (Live): Never refresh
/// - Tier 5 (Completed): Never refresh
class OddsCacheService {
  static final OddsCacheService _instance = OddsCacheService._internal();
  factory OddsCacheService() => _instance;
  OddsCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OddsApiService _oddsApiService = OddsApiService();
  final OddsQuotaManager _quotaManager = OddsQuotaManager();

  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (!_isInitialized) {
      await _quotaManager.initialize();
      await _oddsApiService.ensureInitialized();
      _isInitialized = true;
      debugPrint('✅ OddsCacheService initialized');
    }
  }

  /// Get odds for a game with intelligent caching
  /// This is the main entry point - replaces direct OddsApiService.getMatchOdds() calls
  Future<Map<String, dynamic>?> getOddsForGame({
    required String gameId,
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required DateTime gameTime,
    required String status,
  }) async {
    try {
      await initialize();

      debugPrint('🎯 OddsCacheService.getOddsForGame called');
      debugPrint('   Game ID: $gameId');
      debugPrint('   Sport: $sport');
      debugPrint('   Game: $awayTeam @ $homeTeam');
      debugPrint('   Time: ${gameTime.toIso8601String()}');
      debugPrint('   Status: $status');

      // Step 1: Check if game is live or completed (never fetch odds)
      if (_isGameLiveOrCompleted(status)) {
        debugPrint('   ⏸️ Game is live/completed - returning cached odds only');
        return await _getCachedOddsFromFirestore(gameId);
      }

      // Step 2: Calculate cache tier based on time to game
      final timeToGame = gameTime.difference(DateTime.now());
      final tier = _determineCacheTier(timeToGame, status);
      final cacheDuration = _getCacheDuration(tier);

      debugPrint('   📊 Cache Tier: $tier');
      debugPrint('   ⏱️ Time to game: ${timeToGame.inHours} hours');
      debugPrint('   🕐 Cache duration: ${_formatDuration(cacheDuration)}');

      // Step 3: Check Firestore for cached odds
      final cachedData = await _getGameDataFromFirestore(gameId);

      if (cachedData != null && cachedData['oddsLastFetched'] != null) {
        final oddsLastFetched = (cachedData['oddsLastFetched'] as Timestamp).toDate();
        final cacheAge = DateTime.now().difference(oddsLastFetched);

        debugPrint('   📦 Found cached odds (age: ${_formatDuration(cacheAge)})');

        // Check if cache is still fresh
        if (cacheAge <= cacheDuration) {
          debugPrint('   ✅ Cache is fresh - using cached odds');
          return cachedData['odds'] as Map<String, dynamic>?;
        } else {
          debugPrint('   ⚠️ Cache is stale (${_formatDuration(cacheAge)} > ${_formatDuration(cacheDuration)})');
        }
      } else {
        debugPrint('   📭 No cached odds found');
      }

      // Step 4: Check quota before fetching
      if (!_quotaManager.canMakeRequest(sport)) {
        debugPrint('   ❌ Quota exceeded for $sport');

        // Return stale cache if available
        if (cachedData != null && cachedData['odds'] != null) {
          debugPrint('   ⚠️ Using stale cached odds due to quota limit');
          return cachedData['odds'] as Map<String, dynamic>?;
        }

        debugPrint('   ❌ No cached odds available - returning null');
        return null;
      }

      // Step 5: Fetch fresh odds from API
      debugPrint('   📡 Fetching fresh odds from Odds API...');
      final oddsData = await _oddsApiService.getMatchOdds(
        sport: sport,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        gameDate: gameTime,
      );

      if (oddsData != null) {
        debugPrint('   ✅ Odds fetched successfully');

        // Step 6: Save to Firestore cache
        await _saveOddsToFirestore(
          gameId: gameId,
          oddsData: oddsData,
          tier: tier,
        );

        // Step 7: Record quota usage
        await _quotaManager.recordUsage(sport);

        return oddsData['odds'] as Map<String, dynamic>?;
      } else {
        debugPrint('   ⚠️ No odds returned from API');

        // Return stale cache if available
        if (cachedData != null && cachedData['odds'] != null) {
          debugPrint('   ⚠️ Falling back to stale cached odds');
          return cachedData['odds'] as Map<String, dynamic>?;
        }

        return null;
      }

    } catch (e) {
      debugPrint('❌ Error in OddsCacheService.getOddsForGame: $e');

      // Try to return cached odds on error
      try {
        final cachedData = await _getGameDataFromFirestore(gameId);
        if (cachedData != null && cachedData['odds'] != null) {
          debugPrint('   ⚠️ Returning cached odds due to error');
          return cachedData['odds'] as Map<String, dynamic>?;
        }
      } catch (e2) {
        debugPrint('❌ Error retrieving cached odds: $e2');
      }

      return null;
    }
  }

  /// Check if game is live or completed (never fetch odds)
  bool _isGameLiveOrCompleted(String status) {
    final statusLower = status.toLowerCase();
    return statusLower == 'live' ||
           statusLower == 'in_progress' ||
           statusLower == 'active' ||
           statusLower == 'final' ||
           statusLower == 'completed' ||
           statusLower.contains('quarter') ||
           statusLower.contains('half') ||
           statusLower.contains('period') ||
           statusLower.contains('inning');
  }

  /// Determine cache tier based on time to game and status
  int _determineCacheTier(Duration timeToGame, String status) {
    // Tier 4: Live/In-Progress (NEVER refresh)
    if (status.toLowerCase() == 'live' ||
        status.toLowerCase() == 'in_progress' ||
        status.toLowerCase() == 'active') {
      return 4;
    }

    // Tier 5: Completed (NEVER refresh)
    if (status.toLowerCase() == 'final' ||
        status.toLowerCase() == 'completed') {
      return 5;
    }

    // Tier 3: Game Day (0-24 hours before)
    if (timeToGame.inHours >= 0 && timeToGame.inHours <= 24) {
      return 3;
    }

    // Tier 2: This Week (1-7 days before)
    if (timeToGame.inDays > 0 && timeToGame.inDays <= 7) {
      return 2;
    }

    // Tier 1: Far Future (7+ days before)
    return 1;
  }

  /// Get cache duration based on tier
  Duration _getCacheDuration(int tier) {
    switch (tier) {
      case 1: return const Duration(days: 14);       // Far future
      case 2: return const Duration(days: 7);        // This week
      case 3: return const Duration(hours: 6);       // Game day
      case 4: return const Duration(days: 36500);    // Live (never)
      case 5: return const Duration(days: 36500);    // Completed (never)
      default: return const Duration(days: 7);
    }
  }

  /// Get cached odds from Firestore
  Future<Map<String, dynamic>?> _getCachedOddsFromFirestore(String gameId) async {
    try {
      final doc = await _firestore.collection('games').doc(gameId).get();
      if (doc.exists) {
        final data = doc.data();
        return data?['odds'] as Map<String, dynamic>?;
      }
      return null;
    } catch (e) {
      debugPrint('Error getting cached odds: $e');
      return null;
    }
  }

  /// Get full game data from Firestore
  Future<Map<String, dynamic>?> _getGameDataFromFirestore(String gameId) async {
    try {
      final doc = await _firestore.collection('games').doc(gameId).get();
      if (doc.exists) {
        return doc.data();
      }
      return null;
    } catch (e) {
      debugPrint('Error getting game data: $e');
      return null;
    }
  }

  /// Save odds to Firestore with metadata
  Future<void> _saveOddsToFirestore({
    required String gameId,
    required Map<String, dynamic> oddsData,
    required int tier,
  }) async {
    try {
      final updateData = <String, dynamic>{
        'odds': oddsData['odds'],
        'oddsLastFetched': FieldValue.serverTimestamp(),
        'oddsSource': 'odds_api',
        'oddsCacheTier': tier,
      };

      // If Odds API provides gameTime (commence_time), use it as source of truth
      if (oddsData['commence_time'] != null) {
        try {
          final gameTime = DateTime.parse(oddsData['commence_time']);
          updateData['gameTime'] = Timestamp.fromDate(gameTime);
          updateData['gameTimeSource'] = 'odds_api';
          debugPrint('   ✅ Saved gameTime from Odds API: ${gameTime.toIso8601String()}');
        } catch (e) {
          debugPrint('   ⚠️ Error parsing commence_time: $e');
        }
      }

      await _firestore.collection('games').doc(gameId).set(
        updateData,
        SetOptions(merge: true),
      );

      debugPrint('   💾 Saved odds to Firestore (tier: $tier)');
    } catch (e) {
      debugPrint('❌ Error saving odds to Firestore: $e');
    }
  }

  /// Format duration for logging
  String _formatDuration(Duration duration) {
    if (duration.inDays > 0) {
      return '${duration.inDays} days';
    } else if (duration.inHours > 0) {
      return '${duration.inHours} hours';
    } else if (duration.inMinutes > 0) {
      return '${duration.inMinutes} minutes';
    } else {
      return '${duration.inSeconds} seconds';
    }
  }

  /// Get cache statistics for a game
  Future<Map<String, dynamic>> getCacheStats(String gameId) async {
    try {
      final data = await _getGameDataFromFirestore(gameId);

      if (data == null) {
        return {
          'cached': false,
          'message': 'No cache data available'
        };
      }

      final oddsLastFetched = data['oddsLastFetched'] as Timestamp?;
      final gameTime = data['gameTime'] as Timestamp?;
      final gameTimeSource = data['gameTimeSource'] as String?;
      final oddsCacheTier = data['oddsCacheTier'] as int?;
      final oddsSource = data['oddsSource'] as String?;

      if (oddsLastFetched == null) {
        return {
          'cached': false,
          'message': 'No odds cached yet'
        };
      }

      final cacheAge = DateTime.now().difference(oddsLastFetched.toDate());

      return {
        'cached': true,
        'oddsLastFetched': oddsLastFetched.toDate().toIso8601String(),
        'cacheAge': _formatDuration(cacheAge),
        'cacheAgeSeconds': cacheAge.inSeconds,
        'tier': oddsCacheTier,
        'oddsSource': oddsSource,
        'gameTime': gameTime?.toDate().toIso8601String(),
        'gameTimeSource': gameTimeSource,
      };
    } catch (e) {
      return {
        'error': e.toString()
      };
    }
  }

  /// Clear odds cache for a specific game
  Future<void> clearGameOddsCache(String gameId) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'odds': FieldValue.delete(),
        'oddsLastFetched': FieldValue.delete(),
        'oddsSource': FieldValue.delete(),
        'oddsCacheTier': FieldValue.delete(),
      });
      debugPrint('🗑️ Cleared odds cache for game: $gameId');
    } catch (e) {
      debugPrint('❌ Error clearing odds cache: $e');
    }
  }

  /// Clear all expired odds caches
  Future<void> clearExpiredCaches() async {
    try {
      final now = DateTime.now();
      final snapshot = await _firestore
          .collection('games')
          .where('oddsLastFetched', isNotNull: true)
          .get();

      int clearedCount = 0;

      for (final doc in snapshot.docs) {
        final data = doc.data();
        final oddsLastFetched = (data['oddsLastFetched'] as Timestamp?)?.toDate();
        final gameTime = (data['gameTime'] as Timestamp?)?.toDate();
        final status = data['status'] as String? ?? 'scheduled';

        if (oddsLastFetched == null || gameTime == null) continue;

        final timeToGame = gameTime.difference(now);
        final tier = _determineCacheTier(timeToGame, status);
        final cacheDuration = _getCacheDuration(tier);
        final cacheAge = now.difference(oddsLastFetched);

        // Clear if cache is stale and game is not live/completed
        if (cacheAge > cacheDuration && tier < 4) {
          await clearGameOddsCache(doc.id);
          clearedCount++;
        }
      }

      debugPrint('🗑️ Cleared $clearedCount expired odds caches');
    } catch (e) {
      debugPrint('❌ Error clearing expired caches: $e');
    }
  }
}
