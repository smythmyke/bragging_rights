import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import 'firestore_cache_service.dart';
import 'live_score_update_service.dart';
import 'optimized_games_service.dart';

/// Enhanced games service using the new intelligent caching strategy
/// This service coordinates between Firestore cache, live updates, and API calls
class GamesServiceV2 {
  static final GamesServiceV2 _instance = GamesServiceV2._internal();
  factory GamesServiceV2() => _instance;
  GamesServiceV2._internal();

  final FirestoreCacheService _cacheService = FirestoreCacheService();
  final LiveScoreUpdateService _liveScoreService = LiveScoreUpdateService();
  final OptimizedGamesService _optimizedService = OptimizedGamesService();

  // Track initialization
  bool _isInitialized = false;

  /// Initialize the service
  Future<void> initialize() async {
    if (_isInitialized) return;

    debugPrint('🚀 Initializing GamesServiceV2 with intelligent caching');

    // Start automatic live score updates
    _liveScoreService.startAutomaticUpdates();

    _isInitialized = true;
  }

  /// Get games for a specific time period with intelligent caching
  /// This is the main entry point for all game data requests
  Future<List<GameModel>> getGamesForPeriod({
    required String period,
    required String sport,
    bool forceRefresh = false,
  }) async {
    debugPrint('📱 GamesServiceV2: Getting $sport games for $period');

    // Use the new caching service
    final games = await _cacheService.getGamesForPeriod(
      period: period,
      sport: sport,
      forceRefresh: forceRefresh,
    );

    debugPrint('✅ Returned ${games.length} $sport games for $period');
    return games;
  }

  /// Get all games for today across all sports
  Future<Map<String, List<GameModel>>> getTodayGamesAllSports() async {
    final result = <String, List<GameModel>>{};

    // Load games for each sport in parallel
    final futures = <Future<void>>[];

    for (final sport in OptimizedGamesService.ALL_SPORTS) {
      futures.add(
        getGamesForPeriod(
          period: 'today',
          sport: sport,
        ).then((games) {
          if (games.isNotEmpty) {
            result[sport] = games;
          }
        }).catchError((e) {
          debugPrint('Error loading $sport games: $e');
        })
      );
    }

    await Future.wait(futures);

    debugPrint('📊 Today\'s games loaded - ${result.keys.length} sports with games');
    return result;
  }

  /// Get featured games with smart categorization
  Future<Map<String, dynamic>> getFeaturedGames({bool forceRefresh = false}) async {
    // Delegate to optimized service for now
    // This could be enhanced with the new caching strategy
    return await _optimizedService.loadFeaturedGames(forceRefresh: forceRefresh);
  }

  /// Get games for a specific sport without date filtering
  Future<List<GameModel>> getAllGamesForSport(String sport) async {
    debugPrint('🎯 Getting all games for $sport');

    // First try cache with longer validity (1 hour for full listings)
    final games = await _cacheService.getGamesForPeriod(
      period: 'all',  // Special period for no date filtering
      sport: sport,
      forceRefresh: false,
    );

    // If no cached games, fetch from API
    if (games.isEmpty) {
      debugPrint('📡 No cached games, fetching from API');
      return await _optimizedService.loadAllGamesForSport(sport);
    }

    return games;
  }

  /// Watch live game scores with real-time updates
  Stream<Map<String, dynamic>> watchLiveGameScore(String gameId) {
    return _liveScoreService.watchLiveGameScore(gameId);
  }

  /// Get all currently live games
  Future<List<GameModel>> getLiveGames() async {
    return await _liveScoreService.getAllLiveGames();
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    await _cacheService.clearAllCaches();
    _optimizedService.clearCache();
    debugPrint('🗑️ All caches cleared');
  }

  /// Get cache statistics for monitoring
  Future<Map<String, dynamic>> getCacheStats() async {
    return await _cacheService.getCacheStats();
  }

  /// Clean up resources
  void dispose() {
    _liveScoreService.stopAutomaticUpdates();
    _optimizedService.dispose();
    debugPrint('GamesServiceV2: Disposed resources');
  }
}

/// Extension to convert period names to date ranges
extension PeriodExtensions on String {
  DateRange toDateRange() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    switch (toLowerCase()) {
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
      case 'all':
        // Special case for no date filtering
        return DateRange(
          start: today.subtract(const Duration(days: 365)),
          end: today.add(const Duration(days: 365)),
        );
      default:
        // Default to this week
        return DateRange(
          start: today,
          end: today.add(const Duration(days: 7)),
        );
    }
  }
}