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
        
        // Save to Firestore cache
        await _saveGamesToFirestore(updatedGames, sport: sport);
        
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
        processedGames = _groupCombatSportsByEvent(games);
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
            // Create new game with updated scores
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

  /// Group MMA/Boxing fights by event (e.g., UFC 311, Bellator 300)
  List<GameModel> _groupCombatSportsByEvent(List<GameModel> fights) {
    if (fights.isEmpty) return fights;
    
    debugPrint('🥊 Grouping ${fights.length} combat sports fights into events...');
    
    // Group fights by date and extract event name
    final Map<String, List<GameModel>> eventGroups = {};
    
    for (final fight in fights) {
      // Extract event name from the fight
      String eventName = _extractEventName(fight);
      
      if (!eventGroups.containsKey(eventName)) {
        eventGroups[eventName] = [];
      }
      eventGroups[eventName]!.add(fight);
    }
    
    debugPrint('📦 Created ${eventGroups.length} event groups from ${fights.length} fights');
    
    // Create a single GameModel for each event
    final List<GameModel> groupedEvents = [];
    
    for (final entry in eventGroups.entries) {
      final eventName = entry.key;
      final eventFights = entry.value;
      
      if (eventFights.isEmpty) continue;
      
      // Sort fights by importance (main event first)
      eventFights.sort((a, b) {
        // Main events typically have championship or bigger names
        final aImportance = _getFightImportance(a);
        final bImportance = _getFightImportance(b);
        return bImportance.compareTo(aImportance);
      });
      
      // Use the first fight (main event) as the base
      final mainEvent = eventFights.first;
      final totalFights = eventFights.length;
      
      debugPrint('🎯 Event: $eventName with $totalFights fights');
      debugPrint('   Main Event: ${mainEvent.awayTeam} vs ${mainEvent.homeTeam}');
      
      // Create a grouped event model
      final groupedEvent = GameModel(
        id: '${mainEvent.sport.toLowerCase()}_${eventName.toLowerCase().replaceAll(' ', '_')}',
        sport: mainEvent.sport,
        homeTeam: mainEvent.homeTeam, // Main event fighter 2
        awayTeam: mainEvent.awayTeam, // Main event fighter 1
        gameTime: mainEvent.gameTime,
        status: mainEvent.status,
        venue: mainEvent.venue,
        broadcast: mainEvent.broadcast,
        league: eventName,
        homeTeamLogo: mainEvent.homeTeamLogo,
        awayTeamLogo: mainEvent.awayTeamLogo,
        isCombatSport: true,
        totalFights: totalFights,
        mainEventFighters: '${mainEvent.awayTeam} vs ${mainEvent.homeTeam}',
        fights: eventFights.map((f) => {
          'id': f.id,
          'fighter1': f.awayTeam,
          'fighter2': f.homeTeam,
          'time': f.gameTime.toIso8601String(),
        }).toList(),
      );
      
      groupedEvents.add(groupedEvent);
    }
    
    // Sort events by date
    groupedEvents.sort((a, b) => a.gameTime.compareTo(b.gameTime));
    
    debugPrint('✅ Grouped into ${groupedEvents.length} events');
    
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
  
  /// Clean up resources
  void dispose() {
    debugPrint('OptimizedGamesService: Disposing resources');
    _featuredGamesCache.clear();
    _lastFeaturedLoad = null;
  }
}