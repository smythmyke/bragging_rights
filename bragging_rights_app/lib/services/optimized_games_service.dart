import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/game_model.dart';
import '../models/user_preferences.dart';
import 'user_preferences_service.dart';
import 'edge/sports/espn_nfl_service.dart';
import 'edge/sports/espn_nba_service.dart';
import 'edge/sports/espn_nhl_service.dart';
import 'edge/sports/espn_mlb_service.dart';
import 'game_odds_enrichment_service.dart';
import 'odds_api_service.dart';
import 'firestore_cache_service.dart';
import 'live_score_update_service.dart';
import 'mma_id_fix.dart';

/// Optimized games service with intelligent loading and timeframe categorization
class OptimizedGamesService {
  static final OptimizedGamesService _instance = OptimizedGamesService._internal();
  factory OptimizedGamesService() => _instance;
  OptimizedGamesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserPreferencesService _prefsService = UserPreferencesService();
  final GameOddsEnrichmentService _oddsService = GameOddsEnrichmentService();
  final OddsApiService _oddsApiService = OddsApiService();
  final FirestoreCacheService _cacheService = FirestoreCacheService();
  final LiveScoreUpdateService _liveScoreService = LiveScoreUpdateService();

  // Sport-specific services (ESPN as fallback)
  final EspnNflService _nflService = EspnNflService();
  final EspnNbaService _nbaService = EspnNbaService();
  final EspnNhlService _nhlService = EspnNhlService();
  final EspnMlbService _mlbService = EspnMlbService();
  
  // All available sports
  static const List<String> ALL_SPORTS = ['NFL', 'NBA', 'NHL', 'MLB', 'BOXING', 'MMA', 'SOCCER'];
  
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
  Future<Map<String, dynamic>> loadFeaturedGames({
    bool forceRefresh = false,
  }) async {
    // Use cache if recent (5 minutes)
    if (!forceRefresh && 
        _lastFeaturedLoad != null &&
        DateTime.now().difference(_lastFeaturedLoad!).inMinutes < 5) {
      final cached = _getAllCachedGames();
      if (cached.isNotEmpty) {
        debugPrint('📱 Returning ${cached.length} cached featured games');
        // Get all sports from cache
        final allSports = _featuredGamesCache.keys.where((sport) => 
          _featuredGamesCache[sport]!.isNotEmpty).toList();
        return {
          'games': cached,
          'allSports': allSports,
        };
      }
    }

    if (!USE_OPTIMIZED_LOADING) {
      // Fallback to original method
      final games = await _loadAllGames();
      final sports = <String>{};
      for (final game in games) {
        sports.add(game.sport.toUpperCase());
      }
      return {
        'games': games,
        'allSports': sports.toList()..sort(),
      };
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
    
    // Save to Firestore for offline access (save all games, not just categorized)
    for (final entry in allGamesMap.entries) {
      await _saveGamesToFirestore(entry.value, sport: entry.key);
    }
    
    // Get list of all sports that have games (not just featured)
    final allAvailableSports = allGamesMap.keys
        .where((sport) => allGamesMap[sport]!.isNotEmpty)
        .toList()..sort();
    
    debugPrint('📊 All sports with games: $allAvailableSports');
    
    return {
      'games': categorizedGames,
      'allSports': allAvailableSports,
    };
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
    
    // Debug: Check boxing games specifically
    if (allGamesMap.containsKey('BOXING')) {
      final boxingGames = allGamesMap['BOXING'] ?? [];
      debugPrint('🥊 Processing ${boxingGames.length} BOXING games for categorization');
      for (final game in boxingGames) {
        if (game.homeTeam.toLowerCase().contains('canelo') || 
            game.awayTeam.toLowerCase().contains('crawford')) {
          debugPrint('🎯 CATEGORIZING: ${game.awayTeam} vs ${game.homeTeam}');
          debugPrint('   Game Time: ${game.gameTime}');
          debugPrint('   Days until: ${game.gameTime.difference(now).inDays}');
          debugPrint('   Hours until: ${game.gameTime.difference(now).inHours}');
        }
      }
    }
    
    // Categorize all games
    allGamesMap.forEach((sport, games) {
      for (final game in games) {
        if (game.isLive) {
          liveGames.add(game);
        } else if (game.gameTime.isAfter(now)) { // Only future games
          final hoursUntilGame = game.gameTime.difference(now).inHours;
          final daysUntilGame = game.gameTime.difference(now).inDays;
          
          // Categorize without overlaps
          if (hoursUntilGame <= 3) {
            startingSoonGames.add(game);
          } else if (game.gameTime.day == now.day && 
                     game.gameTime.month == now.month &&
                     game.gameTime.year == now.year) {
            todayGames.add(game);
          } else if (daysUntilGame <= 7) {
            thisWeekGames.add(game);
          } else if (daysUntilGame <= 60) {
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
  /// Check Firestore cache first, then try Odds API, fall back to ESPN if needed
  Future<List<GameModel>> _loadSportGamesWithRange({
    required String sport,
    int daysAhead = INITIAL_DAYS_AHEAD,
  }) async {
    try {
      // CHECK FIRESTORE CACHE FIRST
      final cachedGames = await _getGamesFromFirestore(sport, maxAge: const Duration(hours: 2));
      if (cachedGames != null && cachedGames.isNotEmpty) {
        // Filter by date range if we have cached data
        final now = DateTime.now();
        final cutoffDate = now.add(Duration(days: daysAhead));
        final filteredGames = cachedGames.where((game) => 
          game.gameTime.isBefore(cutoffDate)
        ).toList();
        
        if (filteredGames.isNotEmpty) {
          debugPrint('✅ Using ${filteredGames.length} cached $sport games from Firestore');
          return filteredGames;
        }
      }
      
      // TRY ODDS API IF NO CACHE (Primary source)
      debugPrint('🎯 Attempting to load $sport games from Odds API...');
      final oddsApiGames = await _oddsApiService.getSportGames(
        sport, 
        daysAhead: daysAhead
      );
      
      if (oddsApiGames.isNotEmpty) {
        debugPrint('✅ Loaded ${oddsApiGames.length} $sport games from Odds API');
        
        // Update scores if available (skip for soccer due to format issues)
        List<GameModel> finalGames;
        if (sport.toLowerCase() == 'soccer') {
          debugPrint('⚠️ Skipping score updates for soccer (format incompatibility)');
          finalGames = oddsApiGames;
        } else {
          final scores = await _oddsApiService.getSportScores(sport);
          final updatedGames = <GameModel>[];
          for (final game in oddsApiGames) {
            final scoreData = scores[game.id];
          if (scoreData != null && scoreData['scores'] != null) {
            // Soccer scores might be in a different format
            int? homeScore;
            int? awayScore;

            try {
              // Try to get scores - handle both map and list structures
              final scoresData = scoreData['scores'];
              if (scoresData is List && scoresData.isNotEmpty) {
                // Soccer uses array of scores by period
                homeScore = 0;
                awayScore = 0;
                for (var i = 0; i < scoresData.length; i++) {
                  final period = scoresData[i];
                  if (period is Map) {
                    // Access home score
                    final homeData = period['home'];
                    if (homeData != null && homeData is Map) {
                      final points = homeData['points'];
                      if (points != null) {
                        homeScore = homeScore! + (int.tryParse(points.toString()) ?? 0);
                      }
                    }
                    // Access away score
                    final awayData = period['away'];
                    if (awayData != null && awayData is Map) {
                      final points = awayData['points'];
                      if (points != null) {
                        awayScore = awayScore! + (int.tryParse(points.toString()) ?? 0);
                      }
                    }
                  }
                }
              } else if (scoresData is Map) {
                // Standard format for other sports
                homeScore = scoresData['home_team'];
                awayScore = scoresData['away_team'];
              }
            } catch (e) {
              debugPrint('Error parsing scores for ${game.id}: $e');
            }

            // Create updated game with score data
            updatedGames.add(GameModel(
              id: game.id,
              sport: game.sport,
              homeTeam: game.homeTeam,
              awayTeam: game.awayTeam,
              gameTime: game.gameTime,
              status: scoreData['completed'] == true ? 'final' : 'live',
              homeScore: homeScore,
              awayScore: awayScore,
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

          // Group combat sports by event before returning
          if (sport.toUpperCase() == 'MMA' || sport.toUpperCase() == 'BOXING') {
            debugPrint('🥊 Applying grouping to $sport with ${updatedGames.length} fights');
            finalGames = await _groupCombatSportsByEvent(updatedGames, sport);
            debugPrint('✅ Grouped into ${finalGames.length} events for display');
          } else {
            finalGames = updatedGames;
          }
        }

        // Save to Firestore cache
        await _saveGamesToFirestore(finalGames, sport: sport);

        return finalGames;
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
      
      // Generate a unique ID for internal use and store ESPN ID separately
      final espnId = event['id']?.toString();
      final internalId = espnId != null
          ? '${sport.toLowerCase()}_${espnId}_${gameTime.millisecondsSinceEpoch}'
          : '${sport}_${DateTime.now().millisecondsSinceEpoch}';

      // Debug logging for MLB games
      if (sport == 'MLB') {
        debugPrint('🔍 Converting MLB game:');
        debugPrint('   ESPN ID from event: ${event['id']}');
        debugPrint('   ESPN ID stored: $espnId');
        debugPrint('   Internal ID: $internalId');
        debugPrint('   Teams: ${awayTeam['team']?['displayName']} @ ${homeTeam['team']?['displayName']}');
      }

      return GameModel(
        id: internalId,
        espnId: espnId, // Store the ESPN ID separately
        sport: sport,
        homeTeam: homeTeam['team']?['displayName'] ?? 'Home Team',
        awayTeam: awayTeam['team']?['displayName'] ?? 'Away Team',
        homeTeamLogo: homeTeam['team']?['logo'],
        awayTeamLogo: awayTeam['team']?['logo'],
        homeScore: int.tryParse(homeTeam['score']?.toString() ?? '0'),
        awayScore: int.tryParse(awayTeam['score']?.toString() ?? '0'),
        gameTime: gameTime,
        status: isLive ? 'live' : (isFinal ? 'final' : 'scheduled'),
        venue: competition['venue']?['fullName'],
        broadcast: competition['broadcasts']?[0]?['names']?[0],
        league: event['league']?['abbreviation'] ?? sport,
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

  /// Load ALL games for a specific sport (no date limit)
  Future<List<GameModel>> loadAllGamesForSport(String sport) async {
    debugPrint('\n🎯 Loading ALL games for $sport (no date limit)...');
    debugPrint('================================================');
    
    try {
      // CHECK FIRESTORE CACHE FIRST (30 min cache for full sport listings)
      final cachedGames = await _getGamesFromFirestore(sport, maxAge: const Duration(minutes: 30));
      if (cachedGames != null && cachedGames.isNotEmpty) {
        debugPrint('✅ Using ${cachedGames.length} cached $sport games from Firestore');
        
        // Check if Canelo vs Crawford is in cached data
        if (sport.toLowerCase() == 'boxing') {
          for (final game in cachedGames) {
            if (game.homeTeam.toLowerCase().contains('canelo') || 
                game.awayTeam.toLowerCase().contains('crawford')) {
              debugPrint('🥊 FOUND IN CACHE: ${game.awayTeam} vs ${game.homeTeam}');
            }
          }
        }
        return cachedGames;
      }
      
      // Load from Odds API without date limit if no cache
      debugPrint('📡 No valid cache, fetching from API...');
      final events = await _oddsApiService.getSportEvents(sport);
      if (events == null || events.isEmpty) {
        debugPrint('❌ No events returned from Odds API for $sport');
        return [];
      }
      
      debugPrint('✅ Got ${events.length} $sport events from API');

      // Debug: Show sport_title for first few events
      debugPrint('First few events sport_title values:');
      for (int i = 0; i < events.length && i < 3; i++) {
        debugPrint('  Event ${i+1}: sport_title="${events[i]['sport_title']}"');
      }
      
      // Convert to GameModel
      final games = <GameModel>[];
      for (final event in events) {
        try {
          final gameTime = DateTime.parse(event['commence_time']);
          
          // Determine actual sport from sport_title for MMA/UFC detection
          String actualSport = sport.toUpperCase();
          final sportTitle = event['sport_title'] ?? '';
          
          // Check if it's actually MMA/UFC based on the sport_title
          debugPrint('Sport detection - Original sport: $sport, sport_title: "$sportTitle"');
          if (sportTitle.toLowerCase().contains('ufc') ||
              sportTitle.toLowerCase().contains('mma') ||
              sportTitle.toLowerCase().contains('mixed martial') ||
              sportTitle.toLowerCase().contains('bellator') ||
              sportTitle.toLowerCase().contains('pfl') ||
              sportTitle.toLowerCase().contains('one championship')) {
            actualSport = 'MMA';
            debugPrint('  -> Detected as MMA based on sport_title');
          } else if (sportTitle.toLowerCase().contains('boxing')) {
            actualSport = 'BOXING';
            debugPrint('  -> Detected as BOXING based on sport_title');
          } else {
            debugPrint('  -> Keeping original sport: $actualSport');
          }
          
          final game = GameModel(
            id: event['id'],
            sport: actualSport,
            homeTeam: event['home_team'] ?? '',
            awayTeam: event['away_team'] ?? '',
            gameTime: gameTime,
            status: 'scheduled',
            league: event['sport_title'] ?? sport.toUpperCase(),
            venue: null,
            broadcast: null,
            homeTeamLogo: null,
            awayTeamLogo: null,
          );
          
          games.add(game);
          
          // Debug Canelo vs Crawford
          if (sport.toLowerCase() == 'boxing' && 
              (game.homeTeam.toLowerCase().contains('canelo') || 
               game.awayTeam.toLowerCase().contains('crawford'))) {
            debugPrint('🥊 FOUND IN SERVICE: ${game.awayTeam} vs ${game.homeTeam} at ${game.gameTime}');
          }
        } catch (e) {
          debugPrint('Error parsing event: $e');
        }
      }
      
      // Group combat sports by event
      List<GameModel> processedGames;
      if (sport.toUpperCase() == 'MMA' || sport.toUpperCase() == 'BOXING') {
        debugPrint('🥊 Processing combat sport: $sport with ${games.length} fights');
        processedGames = await _groupCombatSportsByEvent(games, sport);
        debugPrint('✅ Grouped into ${processedGames.length} events');
        for (int i = 0; i < processedGames.length && i < 3; i++) {
          final event = processedGames[i];
          debugPrint('  Event ${i+1}: ${event.awayTeam} vs ${event.homeTeam}');
          if (event.fights != null && event.fights!.isNotEmpty) {
            debugPrint('    Contains ${event.fights!.length} fights');
          }
        }
      } else {
        // Sort by game time for non-combat sports
        games.sort((a, b) => a.gameTime.compareTo(b.gameTime));
        processedGames = games;
      }

      debugPrint('📊 Processed ${processedGames.length} $sport events');
      
      // Update scores if available
      try {
        final scores = await _oddsApiService.getSportScores(sport);
        final updatedGames = <GameModel>[];
        for (final game in processedGames) {
          final scoreData = scores[game.id];
          if (scoreData != null && scoreData['scores'] != null) {
            // Soccer scores might be in a different format
            int? homeScore;
            int? awayScore;

            try {
              // Try to get scores - handle both map and list structures
              final scoresData = scoreData['scores'];
              if (scoresData is List && scoresData.isNotEmpty) {
                // Soccer uses array of scores by period
                homeScore = 0;
                awayScore = 0;
                for (var i = 0; i < scoresData.length; i++) {
                  final period = scoresData[i];
                  if (period is Map) {
                    // Access home score
                    final homeData = period['home'];
                    if (homeData != null && homeData is Map) {
                      final points = homeData['points'];
                      if (points != null) {
                        homeScore = homeScore! + (int.tryParse(points.toString()) ?? 0);
                      }
                    }
                    // Access away score
                    final awayData = period['away'];
                    if (awayData != null && awayData is Map) {
                      final points = awayData['points'];
                      if (points != null) {
                        awayScore = awayScore! + (int.tryParse(points.toString()) ?? 0);
                      }
                    }
                  }
                }
              } else if (scoresData is Map) {
                // Standard format for other sports
                homeScore = scoresData['home_team'];
                awayScore = scoresData['away_team'];
              }
            } catch (e) {
              debugPrint('Error parsing scores for ${game.id}: $e');
            }

            // Create new game with updated scores
            updatedGames.add(GameModel(
              id: game.id,
              sport: game.sport,
              homeTeam: game.homeTeam,
              awayTeam: game.awayTeam,
              gameTime: game.gameTime,
              status: scoreData['completed'] == true ? 'final' : 'live',
              homeScore: homeScore,
              awayScore: awayScore,
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
        // Save to Firestore cache before returning
        await _saveGamesToFirestore(updatedGames, sport: sport);
        return updatedGames;
      } catch (e) {
        debugPrint('Could not update scores: $e');
        // Save to Firestore cache even without scores
        await _saveGamesToFirestore(processedGames, sport: sport);
        return processedGames;
      }
    } catch (e) {
      debugPrint('❌ Error loading all games for $sport: $e');
      return [];
    }
  }

  /// Group MMA/Boxing fights by event using ESPN event structure
  Future<List<GameModel>> _groupCombatSportsByEvent(List<GameModel> fights, String sport) async {
    if (fights.isEmpty) return fights;

    debugPrint('🥊 Grouping ${fights.length} $sport fights into events...');

    try {
      // Fetch ESPN events for the sport
      final espnEvents = await _fetchESPNEvents(sport);

      if (espnEvents.isEmpty) {
        debugPrint('No ESPN events found, falling back to time-based grouping');
        return _groupByTimeWindows(fights, sport);
      }

      final List<GameModel> groupedEvents = [];
      final Set<String> usedFightIds = {};

      // Match fights to ESPN events
      for (final espnEvent in espnEvents) {
        final matchedFights = <GameModel>[];

        for (final espnFight in espnEvent['fights'] ?? []) {
          final espnFighter1 = (espnFight['fighter1'] ?? '').toLowerCase();
          final espnFighter2 = (espnFight['fighter2'] ?? '').toLowerCase();

          // Find matching fight in Odds API data
          for (final oddsFight in fights) {
            if (usedFightIds.contains(oddsFight.id)) continue;

            final oddsF1 = oddsFight.awayTeam.toLowerCase();
            final oddsF2 = oddsFight.homeTeam.toLowerCase();

            // Flexible name matching - check last names
            bool isMatch = _fightersMatch(espnFighter1, espnFighter2, oddsF1, oddsF2);

            if (isMatch) {
              matchedFights.add(oddsFight);
              usedFightIds.add(oddsFight.id);
              break;
            }
          }
        }

        if (matchedFights.isNotEmpty) {
          // Sort by time to find main event (usually last)
          matchedFights.sort((a, b) => a.gameTime.compareTo(b.gameTime));

          final mainEvent = matchedFights.last;
          final eventName = espnEvent['name'] ?? '${mainEvent.awayTeam} vs ${mainEvent.homeTeam}';

          // Create safe Firestore ID (only used for Boxing or when ESPN ID unavailable)
          final safeId = '${sport.toLowerCase()}_${eventName.toLowerCase()
            .replaceAll(' ', '_')
            .replaceAll('/', '_')
            .replaceAll(':', '')
            .replaceAll('.', '')
            .replaceAll('vs', 'v')}';

          // For MMA, use ESPN event ID directly; for Boxing use safe ID
          final espnEventId = espnEvent['id']?.toString();
          final eventId = (sport.toUpperCase() == 'MMA' && espnEventId != null)
              ? espnEventId
              : safeId;

          debugPrint('🎯 Event: $eventName with ${matchedFights.length} fights');
          debugPrint('   Main Event: ${mainEvent.awayTeam} vs ${mainEvent.homeTeam}');
          debugPrint('   Using ID: $eventId (ESPN: $espnEventId)');

          final groupedEvent = GameModel(
            id: eventId,
            espnId: espnEventId,  // Store ESPN ID for API calls
            sport: sport.toUpperCase(),
            homeTeam: mainEvent.homeTeam,
            awayTeam: mainEvent.awayTeam,
            gameTime: matchedFights.first.gameTime, // Event starts with first fight
            status: mainEvent.status,
            venue: espnEvent['venue'] ?? mainEvent.venue,
            broadcast: mainEvent.broadcast,
            league: eventName,
            homeTeamLogo: mainEvent.homeTeamLogo,
            awayTeamLogo: mainEvent.awayTeamLogo,
            isCombatSport: true,
            totalFights: matchedFights.length,
            mainEventFighters: '${mainEvent.awayTeam} vs ${mainEvent.homeTeam}',
            fights: matchedFights.map((f) => {
              'id': f.id,
              'fighter1': f.awayTeam,
              'fighter2': f.homeTeam,
              'time': f.gameTime.toIso8601String(),
              'odds': f.odds,
            }).toList(),
          );

          groupedEvents.add(groupedEvent);
        }
      }

      // Handle unmatched fights with time-based grouping
      final unmatchedFights = fights.where((f) => !usedFightIds.contains(f.id)).toList();
      if (unmatchedFights.isNotEmpty) {
        debugPrint('${unmatchedFights.length} unmatched fights, grouping by time windows');
        final timeGrouped = await _groupByTimeWindows(unmatchedFights, sport);
        groupedEvents.addAll(timeGrouped);
      }

      // Sort events by date
      groupedEvents.sort((a, b) => a.gameTime.compareTo(b.gameTime));

      debugPrint('✅ Grouped into ${groupedEvents.length} events');
      return groupedEvents;

    } catch (e) {
      debugPrint('Error grouping with ESPN data: $e');
      debugPrint('Falling back to time-based grouping');
      return _groupByTimeWindows(fights, sport);
    }
  }
  
  /// Extract event name from fight data
  String _extractEventName(GameModel fight) {
    // Try to extract from league field first
    if (fight.league != null && fight.league!.isNotEmpty) {
      // Check for UFC, Bellator, PFL patterns
      if (fight.league!.contains('UFC') || 
          fight.league!.contains('Bellator') || 
          fight.league!.contains('PFL') ||
          fight.league!.contains('ONE')) {
        return fight.league!;
      }
    }
    
    // For MMA, try to determine from venue or date
    if (fight.sport.toUpperCase() == 'MMA') {
      // Default to date-based grouping
      final dateStr = '${fight.gameTime.month}/${fight.gameTime.day}';
      return 'MMA Event $dateStr';
    }
    
    // For boxing, group by date
    if (fight.sport.toUpperCase() == 'BOXING') {
      final dateStr = '${fight.gameTime.month}/${fight.gameTime.day}';
      return 'Boxing Card $dateStr';
    }
    
    return 'Event';
  }
  
  /// Get fight importance score for sorting
  int _getFightImportance(GameModel fight) {
    int score = 0;
    
    // Check for championship keywords
    final title = '${fight.awayTeam} ${fight.homeTeam}'.toLowerCase();
    if (title.contains('championship') || title.contains('title')) {
      score += 100;
    }
    
    // Check for well-known fighters (you can expand this list)
    final knownFighters = [
      'jones', 'miocic', 'makhachev', 'poirier', 'mcgregor', 'adesanya',
      'volkanovski', 'oliveira', 'gaethje', 'canelo', 'crawford', 'fury',
      'usyk', 'joshua', 'wilder', 'spence', 'garcia', 'tsarukyan', 'hill',
      'prochazka', 'dvalishvili', 'nurmagomedov', 'holland'
    ];
    
    for (final fighter in knownFighters) {
      if (title.contains(fighter)) {
        score += 50;
      }
    }
    
    return score;
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

  /// Check Firestore cache for games by sport
  Future<List<GameModel>?> _getGamesFromFirestore(String sport, {Duration maxAge = const Duration(hours: 1)}) async {
    try {
      // TEMPORARY: Force cache refresh for MLB to get ESPN IDs
      if (sport.toUpperCase() == 'MLB') {
        debugPrint('⚠️ Bypassing cache for MLB to fetch fresh data with ESPN IDs');
        return null;
      }

      // TEMPORARY: Force cache refresh for MMA to get ESPN IDs
      if (sport.toUpperCase() == 'MMA') {
        debugPrint('⚠️ Bypassing cache for MMA to fetch fresh data with ESPN IDs');
        return null;
      }

      debugPrint('🔍 Checking Firestore cache for $sport games...');

      // Query games by sport with cache timestamp check
      final now = DateTime.now();
      final cutoffTime = now.subtract(maxAge);
      
      final querySnapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: sport.toUpperCase())
          .where('cacheTimestamp', isGreaterThan: cutoffTime.toIso8601String())
          .get();
      
      if (querySnapshot.docs.isEmpty) {
        debugPrint('❌ No cached $sport games found or cache expired');
        return null;
      }
      
      final games = querySnapshot.docs
          .map((doc) => GameModel.fromFirestore(doc))
          .toList();
      
      // IMPORTANT: Filter out past games (unless they're live)
      final pastCutoff = now.subtract(const Duration(hours: 6)); // Allow 6 hours for completed games
      final filteredGames = games.where((game) {
        // Keep live games
        if (game.status == 'live' || game.isLive) return true;
        // Keep future games
        if (game.gameTime.isAfter(now)) return true;
        // Keep recently completed games (within 6 hours)
        if (game.gameTime.isAfter(pastCutoff)) return true;
        // Filter out old games
        return false;
      }).toList();
      
      debugPrint('✅ Found ${games.length} cached $sport games, ${filteredGames.length} after filtering past games');
      return filteredGames.isEmpty ? null : filteredGames;
    } catch (e) {
      debugPrint('Error reading from Firestore cache: $e');
      return null;
    }
  }
  
  /// Save games to Firestore with cache timestamp
  Future<void> _saveGamesToFirestore(List<GameModel> games, {String? sport}) async {
    if (games.isEmpty) return;
    
    final batch = _firestore.batch();
    final timestamp = DateTime.now().toIso8601String();
    
    for (final game in games) {
      final docRef = _firestore.collection('games').doc(game.id);
      final data = game.toMap();
      data['cacheTimestamp'] = timestamp;
      if (sport != null) {
        data['sport'] = sport.toUpperCase();
      }

      // Debug log for MLB
      if (sport == 'MLB' && games.indexOf(game) < 3) { // Log first 3 MLB games
        debugPrint('📝 Saving MLB game to Firestore:');
        debugPrint('   Game ID: ${game.id}');
        debugPrint('   ESPN ID: ${game.espnId}');
        debugPrint('   Data contains espnId: ${data.containsKey('espnId')}');
        debugPrint('   Teams: ${game.awayTeam} @ ${game.homeTeam}');
      }

      batch.set(docRef, data, SetOptions(merge: true));
    }
    
    // Also save a sport cache metadata document
    if (sport != null) {
      final metaRef = _firestore.collection('game_cache_meta').doc(sport.toLowerCase());
      batch.set(metaRef, {
        'sport': sport.toUpperCase(),
        'lastUpdated': timestamp,
        'gameCount': games.length,
      }, SetOptions(merge: true));
    }
    
    try {
      await batch.commit();
      debugPrint('💾 Saved ${games.length} games to Firestore for $sport');
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
  
  /// Fetch ESPN events for combat sports
  Future<List<Map<String, dynamic>>> _fetchESPNEvents(String sport) async {
    try {
      final sportLower = sport.toLowerCase();
      String url;

      if (sportLower == 'mma') {
        url = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard';
      } else if (sportLower == 'boxing') {
        url = 'https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard';
      } else {
        return [];
      }

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('ESPN API error: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final events = data['events'] ?? [];

      final List<Map<String, dynamic>> processedEvents = [];

      for (final event in events) {
        final competitions = event['competitions'] ?? [];
        final fights = <Map<String, dynamic>>[];

        for (final comp in competitions) {
          final competitors = comp['competitors'] ?? [];
          if (competitors.length >= 2) {
            fights.add({
              'fighter1': competitors[0]['athlete']?['displayName'] ?? '',
              'fighter2': competitors[1]['athlete']?['displayName'] ?? '',
            });
          }
        }

        if (fights.isNotEmpty) {
          processedEvents.add({
            'id': event['id'],
            'name': event['name'] ?? '',
            'date': event['date'],
            'venue': event['venue']?['fullName'],
            'fights': fights,
          });
        }
      }

      debugPrint('📡 Fetched ${processedEvents.length} ESPN events for $sport');
      return processedEvents;

    } catch (e) {
      debugPrint('Error fetching ESPN events: $e');
      return [];
    }
  }

  /// Check if fighter names match between ESPN and Odds API
  bool _fightersMatch(String espnF1, String espnF2, String oddsF1, String oddsF2) {
    // Split names to get last names
    final espn1Parts = espnF1.split(' ');
    final espn2Parts = espnF2.split(' ');

    // Get last names (most reliable for matching)
    final espn1Last = espn1Parts.isNotEmpty ? espn1Parts.last : '';
    final espn2Last = espn2Parts.isNotEmpty ? espn2Parts.last : '';

    // Check both orientations
    if ((espn1Last.isNotEmpty && oddsF1.contains(espn1Last)) &&
        (espn2Last.isNotEmpty && oddsF2.contains(espn2Last))) {
      return true;
    }

    if ((espn1Last.isNotEmpty && oddsF2.contains(espn1Last)) &&
        (espn2Last.isNotEmpty && oddsF1.contains(espn2Last))) {
      return true;
    }

    // Try full name matching for shorter names
    if (espnF1.length <= 10 || espnF2.length <= 10) {
      if ((oddsF1.contains(espnF1) || espnF1.contains(oddsF1)) &&
          (oddsF2.contains(espnF2) || espnF2.contains(oddsF2))) {
        return true;
      }
    }

    return false;
  }

  /// Group fights by time windows as fallback
  List<GameModel> _groupByTimeWindows(List<GameModel> fights, String sport) {
    const windowHours = 6; // 6-hour window for same event
    final Map<String, List<GameModel>> groups = {};

    for (final fight in fights) {
      bool addedToGroup = false;

      for (final entry in groups.entries) {
        final groupTime = DateTime.parse(entry.key);
        final timeDiff = fight.gameTime.difference(groupTime).inHours.abs();

        if (timeDiff <= windowHours) {
          entry.value.add(fight);
          addedToGroup = true;
          break;
        }
      }

      if (!addedToGroup) {
        groups[fight.gameTime.toIso8601String()] = [fight];
      }
    }

    // Convert groups to events
    final List<GameModel> groupedEvents = [];

    for (final entry in groups.entries) {
      final eventFights = entry.value;
      if (eventFights.isEmpty) continue;

      // Sort by time - latest is usually main event
      eventFights.sort((a, b) => a.gameTime.compareTo(b.gameTime));

      final mainEvent = eventFights.last;
      final eventName = '${mainEvent.awayTeam} vs ${mainEvent.homeTeam}';

      // CRITICAL FIX: Generate appropriate IDs based on sport type
      // For MMA: numeric pseudo-ESPN IDs, for Boxing: string IDs
      final ids = MMAIdFix.getEventIds(sport, eventFights.first.gameTime, eventName);

      final groupedEvent = GameModel(
        id: ids['id']!,
        espnId: ids['espnId'],  // Pseudo-ESPN ID for MMA, null for others
        sport: sport.toUpperCase(),
        homeTeam: mainEvent.homeTeam,
        awayTeam: mainEvent.awayTeam,
        gameTime: eventFights.first.gameTime,
        status: mainEvent.status,
        venue: mainEvent.venue,
        broadcast: mainEvent.broadcast,
        league: eventName,
        homeTeamLogo: mainEvent.homeTeamLogo,
        awayTeamLogo: mainEvent.awayTeamLogo,
        isCombatSport: true,
        totalFights: eventFights.length,
        mainEventFighters: eventName,
        fights: eventFights.map((f) => {
          'id': f.id,
          'fighter1': f.awayTeam,
          'fighter2': f.homeTeam,
          'time': f.gameTime.toIso8601String(),
          'odds': f.odds,
        }).toList(),
      );

      groupedEvents.add(groupedEvent);
    }

    return groupedEvents;
  }

  /// Clear cache for a specific sport to force refresh
  Future<void> clearSportCache(String sport) async {
    try {
      debugPrint('🗑️ Clearing cache for $sport...');

      // Clear in-memory cache
      _featuredGamesCache[sport.toUpperCase()]?.clear();

      // Clear Firestore cache for this sport
      final batch = _firestore.batch();
      final querySnapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: sport.toUpperCase())
          .get();

      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
      }

      // Clear metadata
      batch.delete(_firestore.collection('game_cache_meta').doc(sport.toLowerCase()));

      await batch.commit();
      debugPrint('✅ Cache cleared for $sport');
    } catch (e) {
      debugPrint('Error clearing cache for $sport: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    debugPrint('OptimizedGamesService: Disposing resources');
    _featuredGamesCache.clear();
    _lastFeaturedLoad = null;
  }
}