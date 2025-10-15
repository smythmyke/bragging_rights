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
import '../utils/mma_debug_logger.dart';
import 'api_call_tracker.dart';

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
  static const List<String> ALL_SPORTS = ['NFL', 'NCAAF', 'NBA', 'NCAAB', 'NHL', 'MLB', 'BOXING', 'MMA', 'SOCCER', 'TENNIS'];
  
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
    
    // Optimization: Load all sports in parallel with slight delays to avoid rate limits
    final sportFutures = <Future<MapEntry<String, List<GameModel>>>>[];

    for (int i = 0; i < ALL_SPORTS.length; i++) {
      final sport = ALL_SPORTS[i];
      // Add 100ms delay between each sport start to reduce API pressure
      final delay = Duration(milliseconds: i * 100);

      sportFutures.add(
        Future.delayed(delay).then((_) =>
          _loadSportGamesWithRange(sport: sport, daysAhead: INITIAL_DAYS_AHEAD)
            .then((games) => MapEntry(sport, games))
            .catchError((e) {
              debugPrint('❌ Error loading $sport games: $e');
              return MapEntry(sport, <GameModel>[]);
            })
        )
      );
    }

    // Wait for all sports to load in parallel (with staggered starts)
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

    // Get list of all sports that have games (not just featured)
    final allAvailableSports = allGamesMap.keys
        .where((sport) => allGamesMap[sport]!.isNotEmpty)
        .toList()..sort();

    debugPrint('📊 All sports with games: $allAvailableSports');

    // Create a flat list of ALL games for accurate counting
    final allGamesFlat = <GameModel>[];
    allGamesMap.forEach((sport, games) {
      allGamesFlat.addAll(games);
    });

    // Save to Firestore in parallel WITHOUT blocking the return
    // This allows UI to update while caching happens in background
    _saveAllGamesInParallel(allGamesMap);

    return {
      'games': categorizedGames,  // Limited featured games for display
      'allGames': allGamesFlat,    // ALL games within 14-day window
      'allGamesMap': allGamesMap,  // Games organized by sport for counting
      'allSports': allAvailableSports,
    };
  }

  /// Save all sports' games to Firestore in parallel without blocking
  Future<void> _saveAllGamesInParallel(Map<String, List<GameModel>> allGamesMap) async {
    if (allGamesMap.isEmpty) return;

    debugPrint('💾 Starting parallel Firestore save for ${allGamesMap.length} sports...');

    // Create futures for all sports
    final saveFutures = allGamesMap.entries.map((entry) {
      return _saveGamesToFirestore(entry.value, sport: entry.key)
          .catchError((e) {
            debugPrint('❌ Error saving ${entry.key} to Firestore: $e');
          });
    }).toList();

    // Wait for all saves to complete in parallel
    await Future.wait(saveFutures);
    debugPrint('✅ Parallel Firestore save completed for ${allGamesMap.length} sports');
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
          final now = DateTime.now();

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
            final updatedGame = GameModel(
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
            );

            // Add ALL games to list (including final games)
            // This ensures final games are saved to Firestore to trigger bet settlement
            updatedGames.add(updatedGame);
          } else {
            // No score data - check if game is in the past
            if (game.gameTime.isBefore(now) && game.status != 'live') {
              debugPrint('🚫 Filtering out past $sport game: ${game.awayTeam} @ ${game.homeTeam} at ${game.gameTime}');
              continue; // Skip past games without scores
            }
            updatedGames.add(game);
          }
          }

          // Group combat sports by event before saving
          if (sport.toUpperCase() == 'MMA' || sport.toUpperCase() == 'BOXING') {
            debugPrint('🥊 Applying grouping to $sport with ${updatedGames.length} fights');
            finalGames = await _groupCombatSportsByEvent(updatedGames, sport);
            debugPrint('✅ Grouped into ${finalGames.length} events for Firestore');
          } else {
            finalGames = updatedGames;
          }
        }

        // Save ALL games to Firestore (including final games)
        // This ensures Cloud Functions can detect status changes and settle bets
        await _saveGamesToFirestore(finalGames, sport: sport);
        debugPrint('💾 Saved ${finalGames.length} games to Firestore (including final games)');

        // NOW filter for UI display - don't show old completed games
        final gamesToDisplay = finalGames.where((game) {
          if (game.status == 'final') {
            // Show completed games for 4 hours after finish
            final hoursSinceEnd = DateTime.now().difference(game.gameTime).inHours;
            if (hoursSinceEnd >= 4) {
              debugPrint('🚫 Hiding old completed game from UI: ${game.awayTeam} @ ${game.homeTeam} (${hoursSinceEnd}h ago)');
              return false;
            }
          }
          return true; // Show all non-final games and recent final games
        }).toList();

        debugPrint('📱 Returning ${gamesToDisplay.length} games to UI (filtered from ${finalGames.length})');
        return gamesToDisplay;
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
    final now = DateTime.now();

    for (final event in scoreboard.events) {
      try {
        final game = await _convertEspnEventToGame(event, 'NFL');
        if (game != null) {
          // Filter out past games - only include games that haven't started yet or are currently live
          if (game.gameTime.isAfter(now) || game.status == 'live') {
            games.add(game);
          } else {
            debugPrint('🚫 Filtering out past NFL game: ${game.awayTeam} @ ${game.homeTeam} at ${game.gameTime}');
          }
        }
      } catch (e) {
        debugPrint('Error converting NFL event: $e');
      }
    }

    debugPrint('✅ NFL: Kept ${games.length} future/live games from ${scoreboard.events.length} total ESPN events');
    return games;
  }

  /// Load NBA games with configurable date range
  Future<List<GameModel>> _loadNbaGamesWithRange({int daysAhead = INITIAL_DAYS_AHEAD}) async {
    final scoreboard = await _nbaService.getGamesForDateRange(daysAhead: daysAhead);
    if (scoreboard == null) return [];

    final games = <GameModel>[];
    final now = DateTime.now();
    final cutoffDate = now.add(Duration(days: daysAhead));

    for (final event in scoreboard.events) {
      try {
        final game = await _convertEspnEventToGame(event, 'NBA');
        if (game != null) {
          // Filter: only include games that are (1) not in the past AND (2) within the date range
          if ((game.gameTime.isAfter(now) || game.status == 'live') &&
              game.gameTime.isBefore(cutoffDate)) {
            games.add(game);
          } else if (game.gameTime.isAfter(cutoffDate)) {
            debugPrint('🚫 Filtering out NBA game beyond ${daysAhead}-day window: ${game.awayTeam} @ ${game.homeTeam} at ${game.gameTime}');
          } else {
            debugPrint('🚫 Filtering out past NBA game: ${game.awayTeam} @ ${game.homeTeam} at ${game.gameTime}');
          }
        }
      } catch (e) {
        debugPrint('Error converting NBA event: $e');
      }
    }

    debugPrint('✅ NBA: Kept ${games.length} future/live games within $daysAhead days from ${scoreboard.events.length} total ESPN events');
    return games;
  }

  /// Load NHL games with configurable date range
  Future<List<GameModel>> _loadNhlGamesWithRange({int daysAhead = INITIAL_DAYS_AHEAD}) async {
    final scoreboard = await _nhlService.getGamesForDateRange(daysAhead: daysAhead);
    if (scoreboard == null) return [];

    final games = <GameModel>[];
    final now = DateTime.now();

    for (final event in scoreboard.events) {
      try {
        final game = await _convertEspnEventToGame(event, 'NHL');
        if (game != null) {
          // Filter out past games - only include games that haven't started yet or are currently live
          if (game.gameTime.isAfter(now) || game.status == 'live') {
            games.add(game);
          } else {
            debugPrint('🚫 Filtering out past NHL game: ${game.awayTeam} @ ${game.homeTeam} at ${game.gameTime}');
          }
        }
      } catch (e) {
        debugPrint('Error converting NHL event: $e');
      }
    }

    debugPrint('✅ NHL: Kept ${games.length} future/live games from ${scoreboard.events.length} total ESPN events');
    return games;
  }

  /// NBA game classification result
  /// Holds classification details for NBA games
  ({
    String seasonType,
    String? seasonLabel,
    String? exhibitionType,
  })? _classifyNbaGame(Map<String, dynamic> event, Map<String, dynamic> competition) {
    try {
      debugPrint('🏀 [NBA CLASSIFICATION] Starting classification...');

      // Extract season data from ESPN - it's at the EVENT level, not competition
      final season = event['season'];
      if (season == null) {
        debugPrint('🏀 [NBA CLASSIFICATION] ⚠️ No season data found in event');
        return null;
      }

      final seasonType = season['type'];
      debugPrint('🏀 [NBA CLASSIFICATION] ESPN season.type = $seasonType');

      // Default classification
      String gameSeasonType = 'regularSeason';
      String? gameSeasonLabel;
      String? gameExhibitionType;

      // Classify based on ESPN season.type
      // 1 = Preseason, 2 = Regular Season, 3 = Playoffs
      if (seasonType == 1) {
        debugPrint('🏀 [NBA CLASSIFICATION] Detected PRESEASON game');
        gameSeasonType = 'preseason';

        // Check if this is an exhibition game (non-NBA teams)
        final competitors = competition['competitors'] ?? [];
        debugPrint('🏀 [NBA CLASSIFICATION] Checking ${competitors.length} competitors for exhibition status');

        if (competitors.length >= 2) {
          // Safely find home/away competitors
          final homeCompetitor = competitors.firstWhere(
            (c) => c['homeAway'] == 'home',
            orElse: () => null,
          );
          final awayCompetitor = competitors.firstWhere(
            (c) => c['homeAway'] == 'away',
            orElse: () => null,
          );

          // If we couldn't find home/away, skip classification
          if (homeCompetitor == null || awayCompetitor == null) {
            debugPrint('🏀 [NBA CLASSIFICATION] ⚠️ Could not determine home/away competitors');
            return null;
          }

          final homeTeamId = homeCompetitor['team']?['id'];
          final awayTeamId = awayCompetitor['team']?['id'];

          // NBA team IDs are in range 1-30
          // International/G-League teams have IDs > 100000
          final homeId = int.tryParse(homeTeamId?.toString() ?? '0') ?? 0;
          final awayId = int.tryParse(awayTeamId?.toString() ?? '0') ?? 0;

          debugPrint('🏀 [NBA CLASSIFICATION] Team IDs - Home: $homeId, Away: $awayId');

          if (homeId > 30 || awayId > 30) {
            // This is an exhibition game
            gameExhibitionType = 'International';
            gameSeasonLabel = 'PRESEASON EXHIBITION';
            debugPrint('🏀 [NBA CLASSIFICATION] ✨ EXHIBITION game detected (non-NBA team)');

            // Check competition notes for more specific type
            final notes = competition['notes']?.toString().toLowerCase() ?? '';
            if (notes.contains('global games')) {
              gameExhibitionType = 'Global Games';
              debugPrint('🏀 [NBA CLASSIFICATION] 🌍 Global Games detected');
            }
          } else {
            // Regular NBA preseason game
            gameSeasonLabel = 'PRESEASON';
            debugPrint('🏀 [NBA CLASSIFICATION] 🔶 Regular NBA preseason game');
          }
        }
      } else if (seasonType == 3) {
        debugPrint('🏀 [NBA CLASSIFICATION] Detected PLAYOFFS game');
        gameSeasonType = 'playoffs';
        gameSeasonLabel = 'PLAYOFFS';
      } else if (seasonType == 2) {
        debugPrint('🏀 [NBA CLASSIFICATION] Detected REGULAR SEASON game');
        gameSeasonType = 'regularSeason';
        // No label for regular season (default)
      }

      debugPrint('🏀 [NBA CLASSIFICATION] ✅ FINAL: seasonType="$gameSeasonType", seasonLabel="$gameSeasonLabel", exhibitionType="$gameExhibitionType"');

      return (
        seasonType: gameSeasonType,
        seasonLabel: gameSeasonLabel,
        exhibitionType: gameExhibitionType,
      );
    } catch (e) {
      debugPrint('🏀 [NBA CLASSIFICATION] ❌ Error: $e');
      debugPrint('🏀 [NBA CLASSIFICATION] Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Check if odds are available for an NBA game
  /// Tries both preseason and regular season endpoints
  /// Returns a Map with 'hasOdds' (bool) and 'sportKey' (String?) or null
  Future<Map<String, dynamic>?> _checkNbaOddsAvailability({
    required String homeTeam,
    required String awayTeam,
    required DateTime gameDate,
  }) async {
    try {
      debugPrint('🎲 [NBA ODDS CHECK] Starting odds availability check...');
      debugPrint('🎲 [NBA ODDS CHECK] Game: $awayTeam @ $homeTeam');
      debugPrint('🎲 [NBA ODDS CHECK] Date: ${gameDate.toLocal()}');

      // Use existing OddsApiService method which checks multiple endpoints
      final oddsResult = await _oddsApiService.findOddsApiEventId(
        sport: 'nba',
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        gameDate: gameDate,
      );

      final hasOdds = oddsResult != null;
      final sportKey = oddsResult?['sportKey'];

      if (hasOdds) {
        debugPrint('🎲 [NBA ODDS CHECK] ✅ ODDS AVAILABLE - Event ID: ${oddsResult!['eventId']}, Sport Key: $sportKey');
      } else {
        debugPrint('🎲 [NBA ODDS CHECK] ❌ NO ODDS AVAILABLE');
        debugPrint('🎲 [NBA ODDS CHECK] This likely means:');
        debugPrint('🎲 [NBA ODDS CHECK]   - Game is too far in the future (>2 weeks)');
        debugPrint('🎲 [NBA ODDS CHECK]   - Or this is an exhibition game with no betting lines');
      }

      return {
        'hasOdds': hasOdds,
        'sportKey': sportKey,
      };
    } catch (e) {
      debugPrint('🎲 [NBA ODDS CHECK] ❌ Error checking odds: $e');
      debugPrint('🎲 [NBA ODDS CHECK] Stack trace: ${StackTrace.current}');
      return null;
    }
  }

  /// Load MLB games with configurable date range
  Future<List<GameModel>> _loadMlbGamesWithRange({int daysAhead = INITIAL_DAYS_AHEAD}) async {
    final scoreboard = await _mlbService.getGamesForDateRange(daysAhead: daysAhead);
    if (scoreboard == null) return [];

    final games = <GameModel>[];
    final now = DateTime.now();

    for (final event in scoreboard.events) {
      try {
        final game = await _convertEspnEventToGame(event, 'MLB');
        if (game != null) {
          // Filter out past games - only include games that haven't started yet or are currently live
          if (game.gameTime.isAfter(now) || game.status == 'live') {
            games.add(game);
          } else {
            debugPrint('🚫 Filtering out past MLB game: ${game.awayTeam} @ ${game.homeTeam} at ${game.gameTime}');
          }
        }
      } catch (e) {
        debugPrint('Error converting MLB event: $e');
      }
    }

    debugPrint('✅ MLB: Kept ${games.length} future/live games from ${scoreboard.events.length} total ESPN events');
    return games;
  }

  /// Convert ESPN event to GameModel
  Future<GameModel?> _convertEspnEventToGame(Map<String, dynamic> event, String sport) async {
    try {
      // Add detailed logging for MMA events
      if (sport.toUpperCase() == 'MMA') {
        debugPrint('🥊 Processing MMA event:');
        debugPrint('   Event ID: ${event['id']}');
        debugPrint('   Event name: ${event['name']}');
        debugPrint('   Event short name: ${event['shortName']}');
        debugPrint('   Competitions count: ${event['competitions']?.length ?? 0}');
      }

      final competition = event['competitions']?[0];
      if (competition == null) {
        if (sport.toUpperCase() == 'MMA') {
          debugPrint('   ❌ No competition found in MMA event');
        }
        return null;
      }

      final competitors = competition['competitors'] ?? [];
      if (sport.toUpperCase() == 'MMA') {
        debugPrint('   Competitors count: ${competitors.length}');
        if (competitors.isNotEmpty) {
          debugPrint('   Competitors structure: ${competitors.map((c) => c['team']?['displayName'] ?? 'Unknown').toList()}');
        }
      }

      if (competitors.length < 2) {
        if (sport.toUpperCase() == 'MMA') {
          debugPrint('   ❌ Not enough competitors (${competitors.length} < 2)');
        }
        return null;
      }

      // Find home and away teams - with safety checks
      // Use try-catch to handle any potential index errors
      dynamic homeTeam;
      dynamic awayTeam;

      try {
        homeTeam = competitors.firstWhere(
          (c) => c['homeAway'] == 'home',
          orElse: () => competitors[0],
        );
        awayTeam = competitors.firstWhere(
          (c) => c['homeAway'] == 'away',
          orElse: () => competitors[1],
        );
      } catch (e) {
        debugPrint('   ⚠️ Error accessing competitors: $e');
        return null;
      }

      if (homeTeam == null || awayTeam == null) {
        if (sport.toUpperCase() == 'MMA') {
          debugPrint('   ❌ Could not determine home/away teams');
        }
        return null;
      }

      // Check if team data is valid
      if (homeTeam['team'] == null || awayTeam['team'] == null) {
        debugPrint('   ⚠️ Team data is incomplete or null');
        return null;
      }

      // Filter out TBD games (playoff matchups not yet determined)
      final homeTeamName = homeTeam['team']?['displayName']?.toString() ?? '';
      final awayTeamName = awayTeam['team']?['displayName']?.toString() ?? '';

      if (homeTeamName.toUpperCase() == 'TBD' ||
          awayTeamName.toUpperCase() == 'TBD' ||
          homeTeamName.contains('/') || // e.g., "Tigers/Mariners"
          awayTeamName.contains('/')) {
        debugPrint('   🚫 Filtering out TBD/undetermined playoff game: $awayTeamName @ $homeTeamName');
        return null;
      }
      
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

      // NBA-specific classification and odds checking
      String? seasonType;
      String? seasonLabel;
      String? exhibitionType;
      bool? hasOdds;
      String? oddsApiSportKey; // Declare at function level so it's accessible

      if (sport.toUpperCase() == 'NBA') {
        final classification = _classifyNbaGame(event, competition);
        if (classification != null) {
          seasonType = classification.seasonType;
          seasonLabel = classification.seasonLabel;
          exhibitionType = classification.exhibitionType;
        }

        // Check odds availability for NBA games
        // Only check for scheduled games (not live or final)
        if (!isLive && !isFinal) {
          final oddsCheckResult = await _checkNbaOddsAvailability(
            homeTeam: homeTeam['team']?['displayName'] ?? 'Home Team',
            awayTeam: awayTeam['team']?['displayName'] ?? 'Away Team',
            gameDate: gameTime,
          );
          hasOdds = oddsCheckResult?['hasOdds'] ?? false;
          oddsApiSportKey = oddsCheckResult?['sportKey'];
        }
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
        seasonType: seasonType,
        seasonLabel: seasonLabel,
        exhibitionType: exhibitionType,
        hasOdds: hasOdds,
        oddsApiSportKey: oddsApiSportKey,
      );
    } catch (e, stackTrace) {
      debugPrint('❌ Error converting ESPN event: $e');
      if (sport.toUpperCase() == 'MMA') {
        debugPrint('   Event data that caused error:');
        debugPrint('   Event ID: ${event['id']}');
        debugPrint('   Event name: ${event['name']}');
        debugPrint('   Stack trace: $stackTrace');
      }
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

        // Check if Canelo vs Crawford is in cached data (debugging)
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
    debugPrint('🥊 Processing $sport events...');

    // Fetch ESPN events for the sport - these are our primary source
    final espnEvents = await _fetchESPNEvents(sport);

    if (espnEvents.isEmpty) {
      debugPrint('No ESPN events found');
      // If we have odds fights but no ESPN events, group by time
      if (fights.isNotEmpty) {
        debugPrint('Falling back to time-based grouping for ${fights.length} fights');
        return _groupByTimeWindows(fights, sport);
      }
      return [];
    }

    debugPrint('📡 Found ${espnEvents.length} ESPN events');

    // Filter out past events
    final now = DateTime.now();
    final pastCutoff = now.subtract(const Duration(hours: 24));

    final List<GameModel> groupedEvents = [];
    final Set<String> usedFightIds = {};

    // Create events from ESPN data, enhance with odds when available
    for (final espnEvent in espnEvents) {
      // Parse event date
      DateTime? eventDate;
      if (espnEvent['date'] != null) {
        try {
          eventDate = DateTime.parse(espnEvent['date']);
          if (eventDate.isBefore(pastCutoff)) {
            debugPrint('Skipping past event: ${espnEvent['name']}');
            continue;
          }
        } catch (e) {
          debugPrint('Error parsing date for ${espnEvent['name']}: $e');
        }
      }

      final espnFights = espnEvent['fights'] ?? [];
      if (espnFights.isEmpty) continue;

      final eventName = espnEvent['name'] ?? 'Unknown Event';
      final promotion = espnEvent['league'] ?? espnEvent['promotion'] ?? sport.toUpperCase();

      // Determine main event from ESPN data (last fight is typically main event)
      final mainEventFight = espnFights.last;
      final mainFighter1 = mainEventFight['fighter1'] ?? 'TBD';
      final mainFighter2 = mainEventFight['fighter2'] ?? 'TBD';

      debugPrint('🎯 Creating event: $eventName');
      debugPrint('   Promotion: $promotion');
      debugPrint('   Total fights: ${espnFights.length}');
      debugPrint('   Main Event: $mainFighter1 vs $mainFighter2');

      // Try to match with odds data for enhanced information
      final matchedOddsFights = <GameModel>[];
      Map<String, dynamic>? mainEventOdds;

      if (fights.isNotEmpty) {
        for (final espnFight in espnFights) {
          final espnF1 = (espnFight['fighter1'] ?? '').toLowerCase();
          final espnF2 = (espnFight['fighter2'] ?? '').toLowerCase();

          // Find matching fight in Odds API data
          for (final oddsFight in fights) {
            if (usedFightIds.contains(oddsFight.id)) continue;

            final oddsF1 = oddsFight.awayTeam.toLowerCase();
            final oddsF2 = oddsFight.homeTeam.toLowerCase();

            if (_fightersMatch(espnF1, espnF2, oddsF1, oddsF2)) {
              matchedOddsFights.add(oddsFight);
              usedFightIds.add(oddsFight.id);

              // Check if this is the main event
              if (espnFight == mainEventFight) {
                mainEventOdds = {
                  'homeTeam': oddsFight.homeTeam,
                  'awayTeam': oddsFight.awayTeam,
                  'odds': oddsFight.odds,
                  'gameTime': oddsFight.gameTime,
                };
              }
              break;
            }
          }
        }
      }

      // Use odds data for main event if available, otherwise use ESPN data
      final homeTeam = mainEventOdds?['homeTeam'] ?? mainFighter2;
      final awayTeam = mainEventOdds?['awayTeam'] ?? mainFighter1;
      final gameTime = mainEventOdds?['gameTime'] ?? eventDate ?? DateTime.now().add(const Duration(days: 7));

      // Create safe Firestore ID
      final espnEventId = espnEvent['id']?.toString();
      final safeId = '${sport.toLowerCase()}_${eventName.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('/', '_')
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('vs', 'v')}';

      final eventId = espnEventId ?? safeId;

      // Build fights list with all ESPN fights, enhanced with odds where available
      final allFights = <Map<String, dynamic>>[];
      for (int i = 0; i < espnFights.length; i++) {
        final espnFight = espnFights[i];
        final fighter1 = espnFight['fighter1'] ?? 'TBD';
        final fighter2 = espnFight['fighter2'] ?? 'TBD';

        // Find matching odds fight if any
        GameModel? matchingOddsFight;
        for (final oddsFight in matchedOddsFights) {
          if (_fightersMatch(fighter1.toLowerCase(), fighter2.toLowerCase(),
              oddsFight.awayTeam.toLowerCase(), oddsFight.homeTeam.toLowerCase())) {
            matchingOddsFight = oddsFight;
            break;
          }
        }

        // ESPN returns fights with main event LAST, so we need to reverse the order
        // Main event should be fightOrder 1, co-main should be 2, etc.
        final reversedIndex = espnFights.length - i;

        // Determine card position based on position in the array
        // Last 5 fights are typically main card, with last fight being main event
        String cardPosition = 'prelim';
        if (i >= espnFights.length - 5) {
          cardPosition = 'main';
        }
        if (i < 4 && espnFights.length > 10) {
          // First few fights might be early prelims for larger cards
          cardPosition = 'early';
        }

        allFights.add({
          'id': matchingOddsFight?.id ?? 'espn_${eventId}_$i',
          'fighter1': matchingOddsFight?.awayTeam ?? fighter1,
          'fighter2': matchingOddsFight?.homeTeam ?? fighter2,
          'fighter1Id': espnFight['fighter1Id'],
          'fighter2Id': espnFight['fighter2Id'],
          'fighter1ImageUrl': espnFight['fighter1ImageUrl'],
          'fighter2ImageUrl': espnFight['fighter2ImageUrl'],
          'fighter1Record': espnFight['fighter1Record'] ?? '',
          'fighter2Record': espnFight['fighter2Record'] ?? '',
          'weightClass': espnFight['weightClass'] ?? '',
          'rounds': espnFight['rounds'] ?? 3,
          'time': matchingOddsFight?.gameTime.toIso8601String() ?? gameTime.toIso8601String(),
          'odds': matchingOddsFight?.odds,
          'cardPosition': cardPosition,
          'fightOrder': reversedIndex,  // Main event = 1, co-main = 2, etc.
        });
      }

      final groupedEvent = GameModel(
        id: eventId,
        espnId: espnEventId,
        sport: sport.toUpperCase(),
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        gameTime: gameTime,
        status: 'scheduled',
        venue: espnEvent['venue'],
        broadcast: null,
        league: promotion,
        homeTeamLogo: null,
        awayTeamLogo: null,
        isCombatSport: true,
        totalFights: espnFights.length,
        mainEventFighters: '$awayTeam vs $homeTeam',
        eventName: eventName,
        fights: allFights,
      );

      groupedEvents.add(groupedEvent);
    }

    // Sort events by date
    groupedEvents.sort((a, b) => a.gameTime.compareTo(b.gameTime));

    debugPrint('✅ Created ${groupedEvents.length} events from ESPN data');
    return groupedEvents;
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

      // TEMPORARY: Force cache refresh for NBA to enable classification system
      if (sport.toUpperCase() == 'NBA') {
        debugPrint('🏀 [NBA CACHE] ⚠️ Bypassing cache to fetch fresh data with season classification');
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

    // Count final games
    final finalGamesCount = games.where((g) => g.status == 'final').length;

    for (final game in games) {
      final docRef = _firestore.collection('games').doc(game.id);

      // CRITICAL: Check existing game status to log transitions
      DocumentSnapshot? existingDoc;
      String? previousStatus;
      try {
        existingDoc = await docRef.get();
        if (existingDoc.exists) {
          final existingData = existingDoc.data() as Map<String, dynamic>?;
          previousStatus = existingData?['status'] as String?;
        }
      } catch (e) {
        debugPrint('⚠️ Could not check existing game status: $e');
      }

      final data = game.toMap();
      data['cacheTimestamp'] = timestamp;
      if (sport != null) {
        data['sport'] = sport.toUpperCase();
      }

      // LOG: Status transitions
      if (previousStatus != null && previousStatus != game.status) {
        debugPrint('🔄 [STATUS CHANGE] Game ${game.id}');
        debugPrint('   Sport: ${sport?.toUpperCase()}');
        debugPrint('   Teams: ${game.awayTeam} @ ${game.homeTeam}');
        debugPrint('   Status Transition: $previousStatus → ${game.status}');
        if (game.status == 'final') {
          debugPrint('   Score: ${game.awayScore} - ${game.homeScore}');
          debugPrint('   ⚠️ CRITICAL: Status changed to FINAL - should trigger bet settlement!');
        }
      }

      // LOG: Final games being saved
      if (game.status == 'final') {
        if (previousStatus == null) {
          debugPrint('💾 [FIRESTORE] Saving NEW FINAL game: ${game.id}');
          debugPrint('   Sport: ${sport?.toUpperCase()}');
          debugPrint('   Teams: ${game.awayTeam} @ ${game.homeTeam}');
          debugPrint('   Score: ${game.awayScore} - ${game.homeScore}');
          debugPrint('   Status: ${game.status}');
          debugPrint('   ⚠️ WARNING: Game created with status=final (no transition)');
          debugPrint('   This may NOT trigger Cloud Function if trigger expects status change!');
        } else if (previousStatus == 'final') {
          debugPrint('💾 [FIRESTORE] Re-saving FINAL game: ${game.id} (already final)');
        }
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
      if (finalGamesCount > 0) {
        debugPrint('   ⚠️ Including $finalGamesCount FINAL games that should trigger bet settlement');
      }
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
      final List<Map<String, dynamic>> allEvents = [];

      if (sportLower == 'mma') {
        // Generate date range for MMA events (today to 14 days out - 2 weeks)
        final now = DateTime.now();
        final endDate = now.add(Duration(days: 14));
        final dateRange = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
            '-${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';

        // Try multiple MMA promotions with date range
        final promotions = [
          {'name': 'UFC', 'url': 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard?dates=$dateRange'},
          {'name': 'PFL', 'url': 'https://site.api.espn.com/apis/site/v2/sports/mma/pfl/scoreboard?dates=$dateRange'},
          {'name': 'Bellator', 'url': 'https://site.api.espn.com/apis/site/v2/sports/mma/bellator/scoreboard?dates=$dateRange'},
        ];

        for (final promotion in promotions) {
          try {
            final events = await _fetchPromotionEvents(promotion['url']!, promotion['name']!);
            allEvents.addAll(events);
          } catch (e) {
            debugPrint('Error fetching ${promotion['name']} events: $e');
          }
        }
        return allEvents;
      } else if (sportLower == 'boxing') {
        // Generate date range for Boxing events (today to 14 days out - 2 weeks)
        final now = DateTime.now();
        final endDate = now.add(Duration(days: 14));
        final dateRange = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}'
            '-${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';

        final events = await _fetchPromotionEvents(
          'https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard?dates=$dateRange',
          'Boxing'
        );
        return events;
      } else {
        return [];
      }
    } catch (e) {
      debugPrint('Error fetching ESPN events: $e');
      return [];
    }
  }

  /// Fetch events for a specific promotion
  Future<List<Map<String, dynamic>>> _fetchPromotionEvents(String url, String defaultLeague) async {
    try {
      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        debugPrint('ESPN API error for $defaultLeague: ${response.statusCode}');
        return [];
      }

      final data = json.decode(response.body);
      final events = data['events'] ?? [];

      // Get the league information for proper display
      final leagueInfo = data['leagues'] != null && (data['leagues'] as List).isNotEmpty
          ? data['leagues'][0]
          : null;
      final leagueName = leagueInfo?['displayName'] ?? defaultLeague;

      final List<Map<String, dynamic>> processedEvents = [];

      for (final event in events) {
        final competitions = event['competitions'] ?? [];
        final fights = <Map<String, dynamic>>[];

        for (final comp in competitions) {
          final competitors = comp['competitors'] ?? [];
          if (competitors.length >= 2) {
            // Get athlete IDs for image URLs
            final athlete1Id = competitors[0]['id'] ?? '';
            final athlete2Id = competitors[1]['id'] ?? '';

            // Extract weight class from competition type
            final weightClass = comp['type']?['text'] ??
                              comp['type']?['abbreviation'] ??
                              comp['note'] ?? '';

            // Get records
            final record1 = competitors[0]['records']?[0]?['summary'] ?? '';
            final record2 = competitors[1]['records']?[0]?['summary'] ?? '';

            fights.add({
              'fighter1': competitors[0]['athlete']?['displayName'] ?? '',
              'fighter2': competitors[1]['athlete']?['displayName'] ?? '',
              'fighter1Id': athlete1Id,
              'fighter2Id': athlete2Id,
              'fighter1ImageUrl': athlete1Id.isNotEmpty
                  ? 'https://a.espncdn.com/i/headshots/mma/players/full/$athlete1Id.png'
                  : null,
              'fighter2ImageUrl': athlete2Id.isNotEmpty
                  ? 'https://a.espncdn.com/i/headshots/mma/players/full/$athlete2Id.png'
                  : null,
              'fighter1Record': record1,
              'fighter2Record': record2,
              'weightClass': weightClass,
              'rounds': comp['format']?['regulation']?['periods'] ?? 3,
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
            'league': leagueName,  // Add league for proper display
            'promotion': leagueName,  // Also store as promotion
          });
        }
      }

      debugPrint('📡 Fetched ${processedEvents.length} $leagueName events');
      return processedEvents;

    } catch (e) {
      debugPrint('Error fetching $defaultLeague events: $e');
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
    MMADebugLogger.logWarning('Using time-based grouping fallback', details: {
      'sport': sport,
      'fightsCount': fights.length,
      'reason': 'No ESPN event data available',
    });

    const windowHours = 6; // 6-hour window for same event
    final Map<String, List<GameModel>> groups = {};
    final now = DateTime.now();
    final pastCutoff = now.subtract(const Duration(hours: 24)); // Allow recently completed events

    for (final fight in fights) {
      // Skip fights that are too far in the past
      if (fight.gameTime.isBefore(pastCutoff)) {
        debugPrint('Skipping past fight: ${fight.awayTeam} vs ${fight.homeTeam} on ${fight.gameTime}');
        continue;
      }

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

      // Double-check that the event is not too far in the past
      if (eventFights.first.gameTime.isBefore(pastCutoff)) {
        continue;
      }

      // Sort fights by importance and time to find the actual main event
      eventFights.sort((a, b) {
        // First sort by importance score
        final scoreA = _getFightImportance(a);
        final scoreB = _getFightImportance(b);
        if (scoreA != scoreB) {
          return scoreB.compareTo(scoreA); // Higher score first
        }
        // Then by time (later fights are usually more important)
        return b.gameTime.compareTo(a.gameTime);
      });

      // Log the selection process
      debugPrint('🎯 Selecting main event from ${eventFights.length} fights in time window');
      for (int i = 0; i < eventFights.length; i++) {
        final f = eventFights[i];
        final score = _getFightImportance(f);
        debugPrint('  [$i] ${f.awayTeam} vs ${f.homeTeam} - Score: $score, Time: ${f.gameTime}');
      }

      // Select main event - now the first after sorting by importance
      final mainEvent = eventFights.first;
      debugPrint('  ✅ Selected: ${mainEvent.awayTeam} vs ${mainEvent.homeTeam}');

      final fighterNames = '${mainEvent.awayTeam} vs ${mainEvent.homeTeam}';

      // For MMA/Boxing, create a proper event name with promotion
      String eventName;
      String promotion;
      if (sport.toUpperCase() == 'MMA') {
        // Try to get promotion from the league field of any fight in the group
        // The league field contains sport_title from Odds API (e.g., "UFC", "PFL", "Bellator MMA")
        promotion = mainEvent.league ?? 'MMA';

        // Clean up the promotion name
        if (promotion.toLowerCase().contains('bellator')) {
          promotion = 'Bellator';
        } else if (promotion.toLowerCase().contains('pfl')) {
          promotion = 'PFL';
        } else if (promotion.toLowerCase().contains('ufc')) {
          promotion = 'UFC';
        } else if (promotion.toLowerCase().contains('one')) {
          promotion = 'ONE';
        }

        // Generate event name with date
        final dateStr = eventFights.first.gameTime.toLocal().toString().split(' ')[0];
        eventName = '$promotion Event - $dateStr';
      } else if (sport.toUpperCase() == 'BOXING') {
        promotion = 'Boxing';
        final dateStr = eventFights.first.gameTime.toLocal().toString().split(' ')[0];
        eventName = 'Boxing Card - $dateStr';
      } else {
        promotion = sport.toUpperCase();
        eventName = fighterNames;
      }

      // CRITICAL FIX: Generate appropriate IDs based on sport type
      // For MMA: numeric pseudo-ESPN IDs, for Boxing: string IDs
      final ids = MMAIdFix.getEventIds(sport, eventFights.first.gameTime, fighterNames);

      final groupedEvent = GameModel(
        id: ids['id']!,
        espnId: ids['espnId'],  // Pseudo-ESPN ID for MMA, null for others
        sport: sport.toUpperCase(),
        homeTeam: mainEvent.homeTeam,  // Keep actual fighter name
        awayTeam: mainEvent.awayTeam,  // Keep actual fighter name
        gameTime: eventFights.first.gameTime,
        status: mainEvent.status,
        venue: mainEvent.venue,
        broadcast: mainEvent.broadcast,
        league: promotion,  // Store promotion (UFC/PFL/Bellator/Boxing)
        homeTeamLogo: mainEvent.homeTeamLogo,
        awayTeamLogo: mainEvent.awayTeamLogo,
        isCombatSport: true,
        totalFights: eventFights.length,
        mainEventFighters: fighterNames,  // Use actual fighter names
        eventName: eventName,  // Store the full event name separately
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

  /// Clear OLD cache for a specific sport (games older than 7 days)
  /// This preserves recent games, active pools, and user data
  Future<void> clearSportCache(String sport) async {
    try {
      debugPrint('🗑️ Clearing OLD cache for $sport (games >7 days old)...');

      // Clear in-memory cache
      _featuredGamesCache[sport.toUpperCase()]?.clear();

      // Only clear games older than 7 days
      final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));

      final batch = _firestore.batch();
      final querySnapshot = await _firestore
          .collection('games')
          .where('sport', isEqualTo: sport.toUpperCase())
          .where('gameTime', isLessThan: Timestamp.fromDate(sevenDaysAgo))
          .get();

      int deleteCount = 0;
      for (final doc in querySnapshot.docs) {
        batch.delete(doc.reference);
        deleteCount++;
      }

      // Don't clear metadata - it's useful for tracking
      // batch.delete(_firestore.collection('game_cache_meta').doc(sport.toLowerCase()));

      if (deleteCount > 0) {
        await batch.commit();
        debugPrint('✅ Cleared $deleteCount old $sport games (>7 days)');
      } else {
        debugPrint('✅ No old $sport games to clear');
      }
    } catch (e) {
      debugPrint('Error clearing old cache for $sport: $e');
    }
  }

  /// Clean up resources
  void dispose() {
    debugPrint('OptimizedGamesService: Disposing resources');
    _featuredGamesCache.clear();
    _lastFeaturedLoad = null;
  }
}