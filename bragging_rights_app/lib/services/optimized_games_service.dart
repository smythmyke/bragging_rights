import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import '../models/user_preferences.dart';
import 'user_preferences_service.dart';
import 'edge/sports/espn_nfl_service.dart';
import 'edge/sports/espn_nba_service.dart';
import 'edge/sports/espn_nhl_service.dart';
import 'edge/sports/espn_mlb_service.dart';
import 'game_odds_enrichment_service.dart';
import 'odds_api_service.dart';

/// Optimized games service with intelligent loading and timeframe categorization
class OptimizedGamesService {
  static final OptimizedGamesService _instance = OptimizedGamesService._internal();
  factory OptimizedGamesService() => _instance;
  OptimizedGamesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserPreferencesService _prefsService = UserPreferencesService();
  final GameOddsEnrichmentService _oddsService = GameOddsEnrichmentService();
  final OddsApiService _oddsApiService = OddsApiService();
  
  // Sport-specific services (ESPN as fallback)
  final EspnNflService _nflService = EspnNflService();
  final EspnNbaService _nbaService = EspnNbaService();
  final EspnNhlService _nhlService = EspnNhlService();
  final EspnMlbService _mlbService = EspnMlbService();
  
  // All available sports
  static const List<String> ALL_SPORTS = ['NFL', 'NBA', 'NHL', 'MLB'];
  
  // Feature flag for gradual rollout
  static const bool USE_OPTIMIZED_LOADING = true;
  
  // Optimization: Reduce initial load from 60 to 14 days
  static const int INITIAL_DAYS_AHEAD = 14;  // 2 weeks for quick load
  static const int EXTENDED_DAYS_AHEAD = 60; // Full range for background load
  
  // Cache for featured games
  final Map<String, List<GameModel>> _featuredGamesCache = {};
  DateTime? _lastFeaturedLoad;
  
  // Timeframe categories
  static const int MAX_GAMES_PER_TIMEFRAME = 4;

  /// Load featured games based on user preferences with timeframe categorization
  Future<List<GameModel>> loadFeaturedGames({
    bool forceRefresh = false,
  }) async {
    // Use cache if recent (5 minutes)
    if (!forceRefresh && 
        _lastFeaturedLoad != null &&
        DateTime.now().difference(_lastFeaturedLoad!).inMinutes < 5) {
      final cached = _getAllCachedGames();
      if (cached.isNotEmpty) {
        debugPrint('📱 Returning ${cached.length} cached featured games');
        return cached;
      }
    }

    if (!USE_OPTIMIZED_LOADING) {
      // Fallback to original method
      return _loadAllGames();
    }

    debugPrint('🎯 Loading featured games with optimization and timeframe categorization...');
    
    // Get user preferences
    final prefs = await _prefsService.getUserPreferences();
    final preferredSports = prefs.sportsToLoad;
    
    debugPrint('📊 User preferred sports: ${preferredSports.join(', ')}');
    debugPrint('📊 Loading ALL sports with ${INITIAL_DAYS_AHEAD}-day lookahead for faster startup');
    
    // Load games from ALL sports with reduced date range for faster startup
    final allGamesMap = <String, List<GameModel>>{};
    
    // Optimization: Load all sports in parallel instead of sequentially
    final sportFutures = <Future<MapEntry<String, List<GameModel>>>>[];
    
    for (final sport in ALL_SPORTS) {
      sportFutures.add(
        _loadSportGamesWithRange(sport: sport, daysAhead: INITIAL_DAYS_AHEAD)
          .then((games) => MapEntry(sport, games))
          .catchError((e) {
            debugPrint('❌ Error loading $sport games: $e');
            return MapEntry(sport, <GameModel>[]);
          })
      );
    }
    
    // Wait for all sports to load in parallel
    final results = await Future.wait(sportFutures);
    
    // Process results
    for (final entry in results) {
      if (entry.value.isNotEmpty) {
        allGamesMap[entry.key] = entry.value;
        debugPrint('✅ Loaded ${entry.value.length} ${entry.key} games');
      }
    }
    
    // Categorize games by timeframe
    final categorizedGames = _categorizeGamesByTimeframe(
      allGamesMap: allGamesMap,
      preferredSports: preferredSports,
    );
    
    // Cache the results
    _featuredGamesCache.clear();
    _featuredGamesCache.addAll(allGamesMap);
    _lastFeaturedLoad = DateTime.now();
    
    debugPrint('🏆 Loaded ${categorizedGames.length} total featured games across all timeframes');
    
    // Save to Firestore for offline access
    await _saveGamesToFirestore(categorizedGames);
    
    return categorizedGames;
  }
  
  /// Categorize games by timeframe with user preferences prioritized
  List<GameModel> _categorizeGamesByTimeframe({
    required Map<String, List<GameModel>> allGamesMap,
    required List<String> preferredSports,
  }) {
    final now = DateTime.now();
    final categorizedGames = <GameModel>[];
    
    // Create lists for each timeframe
    final liveGames = <GameModel>[];
    final startingSoonGames = <GameModel>[]; // Within 3 hours
    final todayGames = <GameModel>[];
    final thisWeekGames = <GameModel>[];
    final upcomingGames = <GameModel>[]; // Next 60 days
    
    // Categorize all games
    allGamesMap.forEach((sport, games) {
      for (final game in games) {
        if (game.isLive) {
          liveGames.add(game);
        } else {
          final hoursUntilGame = game.gameTime.difference(now).inHours;
          final daysUntilGame = game.gameTime.difference(now).inDays;
          
          if (hoursUntilGame <= 3 && hoursUntilGame >= 0) {
            startingSoonGames.add(game);
          } else if (game.gameTime.day == now.day && 
                     game.gameTime.month == now.month &&
                     game.gameTime.year == now.year) {
            todayGames.add(game);
          } else if (daysUntilGame <= 7 && daysUntilGame >= 0) {
            thisWeekGames.add(game);
          } else if (daysUntilGame <= 60 && daysUntilGame >= 0) {
            upcomingGames.add(game);
          }
        }
      }
    });
    
    // Sort each category with user preferences first
    final sortWithPreferences = (List<GameModel> games) {
      games.sort((a, b) {
        // Check if sports are in user preferences
        final aPreferred = preferredSports.contains(a.sport.toUpperCase());
        final bPreferred = preferredSports.contains(b.sport.toUpperCase());
        
        // Preferred sports come first
        if (aPreferred && !bPreferred) return -1;
        if (!aPreferred && bPreferred) return 1;
        
        // Within same preference tier, sort by game time
        return a.gameTime.compareTo(b.gameTime);
      });
    };
    
    // Sort each timeframe
    sortWithPreferences(liveGames);
    sortWithPreferences(startingSoonGames);
    sortWithPreferences(todayGames);
    sortWithPreferences(thisWeekGames);
    sortWithPreferences(upcomingGames);
    
    // Add games respecting the max limit per timeframe
    categorizedGames.addAll(liveGames.take(MAX_GAMES_PER_TIMEFRAME));
    categorizedGames.addAll(startingSoonGames.take(MAX_GAMES_PER_TIMEFRAME));
    categorizedGames.addAll(todayGames.take(MAX_GAMES_PER_TIMEFRAME));
    categorizedGames.addAll(thisWeekGames.take(MAX_GAMES_PER_TIMEFRAME));
    categorizedGames.addAll(upcomingGames.take(MAX_GAMES_PER_TIMEFRAME));
    
    debugPrint('📊 Categorized games:');
    debugPrint('  - Live: ${liveGames.length} games (showing ${liveGames.take(MAX_GAMES_PER_TIMEFRAME).length})');
    debugPrint('  - Starting Soon: ${startingSoonGames.length} games (showing ${startingSoonGames.take(MAX_GAMES_PER_TIMEFRAME).length})');
    debugPrint('  - Today: ${todayGames.length} games (showing ${todayGames.take(MAX_GAMES_PER_TIMEFRAME).length})');
    debugPrint('  - This Week: ${thisWeekGames.length} games (showing ${thisWeekGames.take(MAX_GAMES_PER_TIMEFRAME).length})');
    debugPrint('  - Upcoming: ${upcomingGames.length} games (showing ${upcomingGames.take(MAX_GAMES_PER_TIMEFRAME).length})');
    
    return categorizedGames;
  }

  /// Load games for a specific sport with date range
  /// Try Odds API first (primary), fall back to ESPN if needed
  Future<List<GameModel>> _loadSportGamesWithRange({
    required String sport,
    int daysAhead = INITIAL_DAYS_AHEAD,
  }) async {
    try {
      // TRY ODDS API FIRST (Primary source)
      debugPrint('🎯 Attempting to load $sport games from Odds API...');
      final oddsApiGames = await _oddsApiService.getSportGames(
        sport, 
        daysAhead: daysAhead
      );
      
      if (oddsApiGames.isNotEmpty) {
        debugPrint('✅ Loaded ${oddsApiGames.length} $sport games from Odds API');
        
        // Update scores if available
        final scores = await _oddsApiService.getSportScores(sport);
        final updatedGames = <GameModel>[];
        for (final game in oddsApiGames) {
          final scoreData = scores[game.id];
          if (scoreData != null && scoreData['scores'] != null) {
            // Create updated game with score data
            updatedGames.add(GameModel(
              id: game.id,
              sport: game.sport,
              homeTeam: game.homeTeam,
              awayTeam: game.awayTeam,
              gameTime: game.gameTime,
              status: scoreData['completed'] == true ? 'final' : 'live',
              homeScore: scoreData['scores']?['home_team'],
              awayScore: scoreData['scores']?['away_team'],
              league: game.league,
              venue: game.venue,
              broadcast: game.broadcast,
              homeTeamLogo: game.homeTeamLogo,
              awayTeamLogo: game.awayTeamLogo,
            ));
          } else {
            updatedGames.add(game);
          }
        }
        
        return updatedGames;
      }
      
      debugPrint('⚠️ No games from Odds API, falling back to ESPN...');
    } catch (e) {
      debugPrint('❌ Odds API failed for $sport: $e');
      debugPrint('📺 Falling back to ESPN...');
    }
    
    // FALL BACK TO ESPN
    switch (sport.toLowerCase()) {
      case 'nfl':
      case 'football':
        return _loadNflGamesWithRange(daysAhead: daysAhead);
      case 'nba':
      case 'basketball':
        return _loadNbaGamesWithRange(daysAhead: daysAhead);
      case 'nhl':
      case 'hockey':
        return _loadNhlGamesWithRange(daysAhead: daysAhead);
      case 'mlb':
      case 'baseball':
        return _loadMlbGamesWithRange(daysAhead: daysAhead);
      default:
        return [];
    }
  }

  /// Load NFL games with configurable date range
  Future<List<GameModel>> _loadNflGamesWithRange({int daysAhead = INITIAL_DAYS_AHEAD}) async {
    final scoreboard = await _nflService.getGamesForDateRange(daysAhead: daysAhead);
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    
    for (final event in scoreboard.events) {
      try {
        final game = _convertEspnEventToGame(event, 'NFL');
        if (game != null) {
          games.add(game);
        }
      } catch (e) {
        debugPrint('Error converting NFL event: $e');
      }
    }
    
    return games;
  }

  /// Load NBA games with configurable date range
  Future<List<GameModel>> _loadNbaGamesWithRange({int daysAhead = INITIAL_DAYS_AHEAD}) async {
    final scoreboard = await _nbaService.getGamesForDateRange(daysAhead: daysAhead);
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    
    for (final event in scoreboard.events) {
      try {
        final game = _convertEspnEventToGame(event, 'NBA');
        if (game != null) {
          games.add(game);
        }
      } catch (e) {
        debugPrint('Error converting NBA event: $e');
      }
    }
    
    return games;
  }

  /// Load NHL games with configurable date range
  Future<List<GameModel>> _loadNhlGamesWithRange({int daysAhead = INITIAL_DAYS_AHEAD}) async {
    final scoreboard = await _nhlService.getGamesForDateRange(daysAhead: daysAhead);
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    
    for (final event in scoreboard.events) {
      try {
        final game = _convertEspnEventToGame(event, 'NHL');
        if (game != null) {
          games.add(game);
        }
      } catch (e) {
        debugPrint('Error converting NHL event: $e');
      }
    }
    
    return games;
  }

  /// Load MLB games with configurable date range
  Future<List<GameModel>> _loadMlbGamesWithRange({int daysAhead = INITIAL_DAYS_AHEAD}) async {
    final scoreboard = await _mlbService.getGamesForDateRange(daysAhead: daysAhead);
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    
    for (final event in scoreboard.events) {
      try {
        final game = _convertEspnEventToGame(event, 'MLB');
        if (game != null) {
          games.add(game);
        }
      } catch (e) {
        debugPrint('Error converting MLB event: $e');
      }
    }
    
    return games;
  }

  /// Convert ESPN event to GameModel
  GameModel? _convertEspnEventToGame(Map<String, dynamic> event, String sport) {
    try {
      final competition = event['competitions']?[0];
      if (competition == null) return null;
      
      final competitors = competition['competitors'] ?? [];
      if (competitors.length < 2) return null;
      
      // Find home and away teams
      final homeTeam = competitors.firstWhere(
        (c) => c['homeAway'] == 'home',
        orElse: () => competitors[0],
      );
      final awayTeam = competitors.firstWhere(
        (c) => c['homeAway'] == 'away',
        orElse: () => competitors[1],
      );
      
      // Parse game time
      final dateStr = competition['date'] ?? event['date'];
      final gameTime = DateTime.parse(dateStr).toLocal();
      
      // Determine status
      final status = competition['status']?['type']?['name'] ?? 'scheduled';
      final isLive = status.toLowerCase().contains('in progress') || 
                     status.toLowerCase().contains('halftime');
      final isFinal = status.toLowerCase().contains('final');
      
      return GameModel(
        id: event['id'] ?? '${sport}_${DateTime.now().millisecondsSinceEpoch}',
        sport: sport,
        homeTeam: homeTeam['team']?['displayName'] ?? 'Home Team',
        awayTeam: awayTeam['team']?['displayName'] ?? 'Away Team',
        homeScore: int.tryParse(homeTeam['score']?.toString() ?? '0'),
        awayScore: int.tryParse(awayTeam['score']?.toString() ?? '0'),
        gameTime: gameTime,
        status: isLive ? 'live' : (isFinal ? 'final' : 'scheduled'),
        venue: competition['venue']?['fullName'],
        odds: null, // Will be enriched on demand
      );
    } catch (e) {
      debugPrint('Error converting ESPN event: $e');
      return null;
    }
  }

  /// Load more games for a specific sport (for pagination)
  Future<List<GameModel>> loadMoreGames({
    required String sport,
    required int offset,
    required int limit,
  }) async {
    // Get cached games for the sport
    final cachedSportGames = _featuredGamesCache[sport.toUpperCase()] ?? [];
    
    // If we don't have enough cached, try to load more
    if (cachedSportGames.length <= offset) {
      debugPrint('⚠️ No more games available for $sport');
      return [];
    }
    
    // Return the requested slice
    final endIndex = (offset + limit).clamp(0, cachedSportGames.length);
    return cachedSportGames.sublist(offset, endIndex);
  }

  /// Enrich a specific game with odds on-demand
  Future<void> enrichGameOnDemand(String gameId) async {
    debugPrint('💰 Enriching game $gameId with odds on-demand');
    
    try {
      // Get the game from Firestore
      final gameDoc = await _firestore.collection('games').doc(gameId).get();
      
      if (!gameDoc.exists) {
        debugPrint('Game $gameId not found in Firestore');
        return;
      }
      
      final game = GameModel.fromFirestore(gameDoc);
      
      // Check if odds are recent (5 minutes for live, 30 minutes for scheduled)
      if (game.odds != null && game.odds!['lastUpdated'] != null) {
        final lastUpdated = DateTime.parse(game.odds!['lastUpdated']);
        final maxAge = game.status == 'live' 
            ? const Duration(minutes: 5) 
            : const Duration(minutes: 30);
        
        if (DateTime.now().difference(lastUpdated) < maxAge) {
          debugPrint('✅ Game odds are recent, skipping enrichment');
          return;
        }
      }
      
      // Enrich with fresh odds
      await _oddsService.enrichGameWithOdds(game);
      
      debugPrint('✅ Game $gameId enriched with odds');
    } catch (e) {
      debugPrint('Error enriching game on-demand: $e');
    }
  }

  /// Save games to Firestore
  Future<void> _saveGamesToFirestore(List<GameModel> games) async {
    final batch = _firestore.batch();
    
    for (final game in games) {
      final docRef = _firestore.collection('games').doc(game.id);
      batch.set(docRef, game.toMap(), SetOptions(merge: true));
    }
    
    try {
      await batch.commit();
      debugPrint('💾 Saved ${games.length} games to Firestore');
    } catch (e) {
      debugPrint('Error saving games to Firestore: $e');
    }
  }

  /// Get all cached featured games
  List<GameModel> _getAllCachedGames() {
    final allGames = <GameModel>[];
    _featuredGamesCache.values.forEach((sportGames) {
      allGames.addAll(sportGames);
    });
    
    // Re-categorize cached games
    if (allGames.isNotEmpty) {
      final prefs = _prefsService.getCachedPreferences();
      final preferredSports = prefs?.sportsToLoad ?? [];
      
      return _categorizeGamesByTimeframe(
        allGamesMap: _featuredGamesCache,
        preferredSports: preferredSports,
      );
    }
    
    return allGames;
  }

  /// Clear cache
  void clearCache() {
    _featuredGamesCache.clear();
    _lastFeaturedLoad = null;
  }

  /// Original method for fallback
  Future<List<GameModel>> _loadAllGames() async {
    debugPrint('⚠️ Using original unoptimized loading method');
    // This would be the original implementation
    // Keeping it as fallback for safety
    return [];
  }
  
  /// Clean up resources
  void dispose() {
    debugPrint('OptimizedGamesService: Disposing resources');
    _featuredGamesCache.clear();
    _lastFeaturedLoad = null;
  }
}