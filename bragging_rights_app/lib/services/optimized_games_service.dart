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

/// Optimized games service with intelligent loading
class OptimizedGamesService {
  static final OptimizedGamesService _instance = OptimizedGamesService._internal();
  factory OptimizedGamesService() => _instance;
  OptimizedGamesService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final UserPreferencesService _prefsService = UserPreferencesService();
  final GameOddsEnrichmentService _oddsService = GameOddsEnrichmentService();
  
  // Sport-specific services
  final EspnNflService _nflService = EspnNflService();
  final EspnNbaService _nbaService = EspnNbaService();
  final EspnNhlService _nhlService = EspnNhlService();
  final EspnMlbService _mlbService = EspnMlbService();
  
  // Feature flag for gradual rollout
  static const bool USE_OPTIMIZED_LOADING = true;
  
  // Cache for featured games
  final Map<String, List<GameModel>> _featuredGamesCache = {};
  DateTime? _lastFeaturedLoad;

  /// Load featured games based on user preferences
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

    debugPrint('🎯 Loading featured games with optimization...');
    
    // Get user preferences
    final prefs = await _prefsService.getUserPreferences();
    final sportsToLoad = prefs.sportsToLoad;
    final maxPerSport = prefs.maxGamesPerSport;
    
    debugPrint('📊 Loading sports: ${sportsToLoad.join(', ')} (max $maxPerSport per sport)');
    
    final allGames = <GameModel>[];
    
    // Load games for each preferred sport
    for (final sport in sportsToLoad) {
      try {
        final sportGames = await _loadSportGames(
          sport: sport,
          limit: maxPerSport,
        );
        allGames.addAll(sportGames);
        
        // Cache by sport
        _featuredGamesCache[sport] = sportGames;
        
        debugPrint('✅ Loaded ${sportGames.length} $sport games');
      } catch (e) {
        debugPrint('❌ Error loading $sport games: $e');
      }
    }
    
    // Sort by priority
    allGames.sort((a, b) {
      final priorityA = _prefsService.calculateGamePriority(
        homeTeam: a.homeTeam,
        awayTeam: a.awayTeam,
        status: a.status,
        gameTime: a.gameTime,
      );
      final priorityB = _prefsService.calculateGamePriority(
        homeTeam: b.homeTeam,
        awayTeam: b.awayTeam,
        status: b.status,
        gameTime: b.gameTime,
      );
      return priorityB.compareTo(priorityA);
    });
    
    _lastFeaturedLoad = DateTime.now();
    
    debugPrint('🏆 Loaded ${allGames.length} total featured games');
    
    // Save to Firestore for offline access
    await _saveGamesToFirestore(allGames);
    
    return allGames;
  }

  /// Load games for a specific sport with limit
  Future<List<GameModel>> _loadSportGames({
    required String sport,
    required int limit,
  }) async {
    switch (sport.toLowerCase()) {
      case 'nfl':
      case 'football':
        return _loadNflGames(limit);
      case 'nba':
      case 'basketball':
        return _loadNbaGames(limit);
      case 'nhl':
      case 'hockey':
        return _loadNhlGames(limit);
      case 'mlb':
      case 'baseball':
        return _loadMlbGames(limit);
      default:
        return [];
    }
  }

  /// Load NFL games with limit
  Future<List<GameModel>> _loadNflGames(int limit) async {
    final scoreboard = await _nflService.getTodaysGames();
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    final events = scoreboard.events.take(limit * 2); // Get extra to filter
    
    for (final event in events) {
      if (games.length >= limit) break;
      
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

  /// Load NBA games with limit
  Future<List<GameModel>> _loadNbaGames(int limit) async {
    final scoreboard = await _nbaService.getTodaysGames();
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    final events = scoreboard.events.take(limit * 2);
    
    for (final event in events) {
      if (games.length >= limit) break;
      
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

  /// Load NHL games with limit
  Future<List<GameModel>> _loadNhlGames(int limit) async {
    final scoreboard = await _nhlService.getTodaysGames();
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    final events = scoreboard.events.take(limit * 2);
    
    for (final event in events) {
      if (games.length >= limit) break;
      
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

  /// Load MLB games with limit
  Future<List<GameModel>> _loadMlbGames(int limit) async {
    final scoreboard = await _mlbService.getTodaysGames();
    if (scoreboard == null) return [];
    
    final games = <GameModel>[];
    final events = scoreboard.events.take(limit * 2);
    
    for (final event in events) {
      if (games.length >= limit) break;
      
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
  GameModel? _convertEspnEventToGame(dynamic event, String sport) {
    if (event is! Map<String, dynamic>) return null;
    
    try {
      final competition = event['competitions']?[0];
      if (competition == null) return null;
      
      final competitors = competition['competitors'] ?? [];
      if (competitors.length < 2) return null;
      
      // Extract team info
      final homeTeam = competitors[0]['team']?['displayName'] ?? '';
      final awayTeam = competitors[1]['team']?['displayName'] ?? '';
      final homeScore = competitors[0]['score'] != null 
          ? int.tryParse(competitors[0]['score'].toString()) 
          : null;
      final awayScore = competitors[1]['score'] != null 
          ? int.tryParse(competitors[1]['score'].toString()) 
          : null;
      
      // Extract game info
      final dateStr = event['date'] ?? competition['date'];
      final gameTime = DateTime.tryParse(dateStr ?? '') ?? DateTime.now();
      
      // Determine status
      final statusType = event['status']?['type']?['name'] ?? '';
      String status = 'scheduled';
      if (statusType == 'STATUS_FINAL') {
        status = 'final';
      } else if (statusType == 'STATUS_IN_PROGRESS') {
        status = 'live';
      }
      
      return GameModel(
        id: event['id'] ?? '${sport}_${DateTime.now().millisecondsSinceEpoch}',
        sport: sport,
        homeTeam: homeTeam,
        awayTeam: awayTeam,
        gameTime: gameTime,
        status: status,
        homeScore: homeScore,
        awayScore: awayScore,
        venue: competition['venue']?['fullName'],
        broadcast: competition['broadcasts']?[0]?['names']?[0],
        odds: null, // Will be enriched on-demand
      );
    } catch (e) {
      debugPrint('Error converting ESPN event: $e');
      return null;
    }
  }

  /// Load more games for a specific sport (pagination)
  Future<List<GameModel>> loadMoreGames({
    required String sport,
    required int offset,
    int limit = 10,
  }) async {
    debugPrint('📄 Loading more $sport games (offset: $offset, limit: $limit)');
    
    // For now, just get all and slice
    // TODO: Implement proper pagination with ESPN API
    final allSportGames = await _loadSportGames(
      sport: sport,
      limit: offset + limit,
    );
    
    if (allSportGames.length <= offset) {
      return [];
    }
    
    return allSportGames.skip(offset).take(limit).toList();
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
}