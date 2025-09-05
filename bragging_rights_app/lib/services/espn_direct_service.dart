import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';
import 'ufc_event_service.dart';
import 'game_odds_enrichment_service.dart';
import 'game_cache_service.dart';

class ESPNDirectService {
  static const String baseUrl = 'https://site.api.espn.com/apis/site/v2/sports';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameOddsEnrichmentService _oddsEnrichmentService = GameOddsEnrichmentService();
  final GameCacheService _cacheService = GameCacheService();
  
  static const Map<String, String> sportEndpoints = {
    'MLB': 'baseball/mlb',
    'NFL': 'football/nfl',
    'NBA': 'basketball/nba', 
    'NHL': 'hockey/nhl',
    'UFC': 'mma/ufc',
    'BELLATOR': 'mma/bellator',
    'PFL': 'mma/pfl',
    'BOXING': 'boxing',
  };
  
  // Save game to Firestore (only updates if data has changed)
  Future<void> _saveGameToFirestore(GameModel game) async {
    try {
      final docRef = _firestore.collection('games').doc(game.id);
      final doc = await docRef.get();
      
      // Only update if game doesn't exist or if it's been more than 5 minutes since last update
      if (!doc.exists || 
          (doc.data()?['lastUpdated'] != null && 
           DateTime.now().difference((doc.data()!['lastUpdated'] as Timestamp).toDate()).inMinutes > 5)) {
        
        await docRef.set(game.toMap(), SetOptions(merge: true));
        print('Saved/Updated game ${game.id} to Firestore: ${game.gameTitle}');
      }
    } catch (e) {
      print('Error saving game to Firestore: $e');
      // Don't throw - we still want to return the game even if save fails
    }
  }
  
  // Save multiple games efficiently
  Future<void> _saveGamesToFirestore(List<GameModel> games) async {
    if (games.isEmpty) return;
    
    try {
      // Use batch write for better performance
      final batch = _firestore.batch();
      final now = DateTime.now();
      
      for (final game in games) {
        final docRef = _firestore.collection('games').doc(game.id);
        batch.set(docRef, game.toFirestore(), SetOptions(merge: true));
      }
      
      await batch.commit();
      print('Saved ${games.length} games to Firestore');
      
      // Enrich games with odds and auto-create pools
      print('🎲 Enriching games with odds and creating pools...');
      await _oddsEnrichmentService.enrichGamesWithOdds(games);
      
    } catch (e) {
      print('Error batch saving games to Firestore: $e');
      // Fall back to individual saves
      for (final game in games) {
        await _saveGameToFirestore(game);
      }
    }
  }
  
  // Fetch games for all sports with caching and parallel fetching
  Future<List<GameModel>> fetchAllGames({bool forceRefresh = false}) async {
    // Step 1: Return cached games immediately if available and not forcing refresh
    if (!forceRefresh) {
      final cachedGames = await _cacheService.getCachedGames();
      if (cachedGames != null && cachedGames.isNotEmpty) {
        print('⚡ Returning ${cachedGames.length} cached games immediately');
        // Still fetch fresh data in background
        _fetchAndUpdateGamesInBackground();
        return cachedGames;
      }
    }
    
    print('🔄 Fetching fresh games from ESPN API...');
    
    // Step 2: Fetch all sports in parallel for speed
    final futures = <Future<List<GameModel>>>[];
    
    for (final entry in sportEndpoints.entries) {
      futures.add(
        fetchSportGames(entry.key).catchError((e) {
          print('Error fetching ${entry.key}: $e');
          return <GameModel>[];
        })
      );
    }
    
    // Wait for all parallel fetches to complete
    final results = await Future.wait(futures);
    
    // Combine all games
    final allGames = <GameModel>[];
    for (final games in results) {
      allGames.addAll(games);
    }
    
    // Sort by game time
    allGames.sort((a, b) => a.gameTime.compareTo(b.gameTime));
    
    // Cache the games for instant loading next time
    await _cacheService.cacheGames(allGames);
    
    // Save to Firestore in background (don't wait)
    _saveGamesToFirestoreInBackground(allGames);
    
    print('✅ Fetched ${allGames.length} games total');
    return allGames;
  }
  
  // Background fetch and update
  Future<void> _fetchAndUpdateGamesInBackground() async {
    try {
      print('🔄 Background refresh starting...');
      final freshGames = await fetchAllGames(forceRefresh: true);
      print('✅ Background refresh complete: ${freshGames.length} games');
    } catch (e) {
      print('Error in background refresh: $e');
    }
  }
  
  // Save to Firestore without blocking UI
  Future<void> _saveGamesToFirestoreInBackground(List<GameModel> games) async {
    try {
      await _saveGamesToFirestore(games);
      // Also enrich with odds in background
      _oddsEnrichmentService.enrichGamesWithOdds(games);
    } catch (e) {
      print('Error saving to Firestore in background: $e');
    }
  }
  
  // Fetch games for a specific sport
  Future<List<GameModel>> fetchSportGames(String sport) async {
    try {
      // Use specialized UFC service for UFC events
      // Note: We still check for 'UFC' sport since that's what comes from sportEndpoints
      if (sport == 'UFC') {
        final ufcService = UfcEventService();
        final ufcEvents = await ufcService.fetchUpcomingUfcEvents(days: 60);
        final gameModels = ufcService.convertToGameModels(ufcEvents);
        print('Fetched ${gameModels.length} UFC events with proper names');
        
        // Save UFC games to Firestore
        if (gameModels.isNotEmpty) {
          await _saveGamesToFirestore(gameModels);
        }
        
        return gameModels;
      }
      
      final endpoint = sportEndpoints[sport];
      if (endpoint == null) {
        print('No endpoint for sport: $sport');
        return [];
      }
      
      // For MMA/UFC and Boxing, fetch a wider date range since events are less frequent
      String url;
      if (sport == 'BELLATOR' || sport == 'PFL' || sport == 'BOXING') {
        final now = DateTime.now();
        final endDate = now.add(Duration(days: 60)); // Look 60 days ahead for combat sports to catch all events
        final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
        final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
        url = '$baseUrl/$endpoint/scoreboard?dates=$startStr-$endStr';
        print('Fetching $sport events for next 60 days from: $url');
      } else {
        url = '$baseUrl/$endpoint/scoreboard';
        print('Fetching $sport games from: $url');
      }
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] ?? [];
        print('Found ${events.length} $sport events');
        
        // Log if no events found for combat sports
        if (events.isEmpty && (sport == 'UFC' || sport == 'BELLATOR' || sport == 'PFL' || sport == 'BOXING')) {
          print('No $sport events scheduled in the next 60 days');
        }
        
        final games = <GameModel>[];
        for (final event in events) {
          try {
            final game = _parseESPNEvent(event, sport);
            games.add(game);
            print('Added $sport game: ${game.awayTeam} @ ${game.homeTeam}');
          } catch (e) {
            print('Error parsing $sport event: $e');
          }
        }
        
        // Save games to Firestore
        if (games.isNotEmpty) {
          await _saveGamesToFirestore(games);
        }
        
        print('Returning ${games.length} $sport games');
        return games;
      }
    } catch (e, stackTrace) {
      print('Error fetching $sport games: $e');
      print('Stack trace: $stackTrace');
    }
    
    return [];
  }
  
  // Fetch games for a date range
  Future<List<GameModel>> fetchGamesForDateRange(String sport, DateTime startDate, DateTime endDate) async {
    try {
      final endpoint = sportEndpoints[sport];
      if (endpoint == null) return [];
      
      final startStr = '${startDate.year}${startDate.month.toString().padLeft(2, '0')}${startDate.day.toString().padLeft(2, '0')}';
      final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
      
      final url = '$baseUrl/$endpoint/scoreboard?dates=$startStr-$endStr';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] ?? [];
        
        final games = <GameModel>[];
        for (final event in events) {
          try {
            final game = _parseESPNEvent(event, sport);
            games.add(game);
          } catch (e) {
            print('Error parsing event: $e');
          }
        }
        return games;
      }
    } catch (e) {
      print('Error fetching $sport games for date range: $e');
    }
    
    return [];
  }
  
  // Check if this is an individual sport (MMA, Boxing, Tennis, Golf)
  bool _isIndividualSport(String sport) {
    return ['UFC', 'BELLATOR', 'PFL', 'MMA', 'BOXING', 'TENNIS', 'GOLF'].contains(sport.toUpperCase());
  }

  // Parse ESPN event to GameModel
  GameModel _parseESPNEvent(Map<String, dynamic> event, String sport) {
    final competition = event['competitions']?[0] ?? {};
    final competitors = competition['competitors'] ?? [];
    
    // Get teams or fighters/athletes
    String homeTeam = 'TBD';
    String awayTeam = 'TBD';
    int? homeScore;
    int? awayScore;
    String? homeTeamLogo;
    String? awayTeamLogo;
    
    // Handle individual sports differently
    if (_isIndividualSport(sport)) {
      // For UFC/MMA, preserve the full event name
      final fullEventName = event['name'] ?? '';
      String? ufcEventName;
      
      // Extract UFC event name (e.g., "UFC 310", "UFC Fight Night")
      if (sport == 'UFC' || sport == 'BELLATOR' || sport == 'PFL') {
        // Check if event has season/week info which often contains the event name
        final season = event['season']?['name'] ?? '';
        final week = competition['notes']?[0]?['text'] ?? '';
        
        // Try to extract event name from various sources
        if (fullEventName.contains('UFC')) {
          // Extract UFC event number or type from the full name
          final ufcMatch = RegExp(r'UFC\s+(\d+|Fight Night|on ESPN|on ABC)').firstMatch(fullEventName);
          if (ufcMatch != null) {
            ufcEventName = ufcMatch.group(0);
          }
        } else if (sport == 'BELLATOR' && fullEventName.contains('Bellator')) {
          final bellatorMatch = RegExp(r'Bellator\s+\d+').firstMatch(fullEventName);
          if (bellatorMatch != null) {
            ufcEventName = bellatorMatch.group(0);
          }
        } else if (sport == 'PFL' && fullEventName.contains('PFL')) {
          final pflMatch = RegExp(r'PFL\s+\d+').firstMatch(fullEventName);
          if (pflMatch != null) {
            ufcEventName = pflMatch.group(0);
          }
        }
        
        // If we couldn't extract event name, use the sport as prefix
        if (ufcEventName == null) {
          ufcEventName = sport;
        }
      }
      
      // For individual sports, competitors are athletes not teams
      // They use "order" field (1 or 2) instead of homeAway
      for (final competitor in competitors) {
        final order = competitor['order'] ?? 0;
        final athlete = competitor['athlete'] ?? {};
        final name = athlete['displayName'] ?? 
                     athlete['fullName'] ?? 
                     athlete['shortName'] ?? 'TBD';
        final score = competitor['score'] != null ? int.tryParse(competitor['score']) : null;
        final flag = athlete['flag']?['href'] ?? '';
        final record = competitor['records']?[0]?['summary'] ?? '';
        
        // In individual sports, order 1 is typically the first fighter/athlete listed
        // We'll treat order 1 as "away" and order 2 as "home" for consistency
        if (order == 1) {
          awayTeam = name;  // First fighter/athlete
          awayScore = score;
          awayTeamLogo = flag;
        } else if (order == 2) {
          homeTeam = name;  // Second fighter/athlete (vs.)
          homeScore = score;
          homeTeamLogo = flag;
        }
      }
      
      // If only one competitor or no competitors yet (TBD matchups)
      if (competitors.length == 1) {
        if (homeTeam == 'TBD') {
          homeTeam = 'TBD';
        } else if (awayTeam == 'TBD') {
          awayTeam = 'TBD';
        }
      } else if (competitors.isEmpty) {
        // Check event name for fighter/athlete names
        if (fullEventName.contains(' vs ') || fullEventName.contains(' vs. ')) {
          final parts = fullEventName.split(RegExp(r' vs\.? '));
          if (parts.length >= 2) {
            awayTeam = parts[0].trim();
            homeTeam = parts[1].trim();
          }
        }
      }
      
      // For UFC/MMA events, prepend the event name to the display
      if (ufcEventName != null && awayTeam != 'TBD' && homeTeam != 'TBD') {
        // Store event name in awayTeam field as "UFC 310: Fighter1"
        awayTeam = '$ufcEventName: $awayTeam';
      }
    } else {
      // Team sports
      for (final competitor in competitors) {
        final isHome = competitor['homeAway'] == 'home';
        final teamName = competitor['team']?['displayName'] ?? 
                        competitor['team']?['shortDisplayName'] ?? 
                        competitor['team']?['abbreviation'] ?? 'TBD';
        final score = competitor['score'] != null ? int.tryParse(competitor['score']) : null;
        final logo = competitor['team']?['logo'] ?? '';
        
        if (isHome) {
          homeTeam = teamName;
          homeScore = score;
          homeTeamLogo = logo;
        } else {
          awayTeam = teamName;
          awayScore = score;
          awayTeamLogo = logo;
        }
      }
    }
    
    // Get status
    final statusData = event['status'] ?? {};
    final statusType = statusData['type'] ?? {};
    String status = 'scheduled';
    String? period;
    String? timeRemaining;
    
    if (statusType['name'] == 'STATUS_FINAL') {
      status = 'final';
    } else if (statusType['name'] == 'STATUS_IN_PROGRESS') {
      status = 'live';
      period = statusData['period']?.toString();
      timeRemaining = statusData['displayClock'];
    }
    
    // Get odds if available
    Map<String, dynamic>? odds;
    final oddsData = competition['odds'];
    if (oddsData != null && oddsData.isNotEmpty) {
      final firstOdds = oddsData[0];
      odds = {
        'spread': firstOdds['details'],
        'overUnder': firstOdds['overUnder'],
      };
    }
    
    return GameModel(
      id: event['id'] ?? DateTime.now().millisecondsSinceEpoch.toString(),
      sport: sport,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      gameTime: DateTime.parse(event['date']).toLocal(),
      status: status,
      homeScore: homeScore,
      awayScore: awayScore,
      period: period,
      timeRemaining: timeRemaining,
      odds: odds,
      venue: competition['venue']?['fullName'],
      broadcast: competition['broadcasts']?.isNotEmpty == true 
        ? competition['broadcasts'][0]['names']?.join(', ')
        : null,
      homeTeamLogo: homeTeamLogo,
      awayTeamLogo: awayTeamLogo,
    );
  }
  
  // Get live games only
  Future<List<GameModel>> getLiveGames() async {
    final allGames = await fetchAllGames();
    return allGames.where((game) => game.status == 'live').toList();
  }
  
  // Get upcoming games (next 7 days)
  Future<List<GameModel>> getUpcomingGames({int days = 7}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: days));
    final games = <GameModel>[];
    
    for (final sport in sportEndpoints.keys) {
      final sportGames = await fetchGamesForDateRange(sport, now, endDate);
      games.addAll(sportGames);
    }
    
    // Filter out past games and sort
    final upcomingGames = games
      .where((game) => game.gameTime.isAfter(now))
      .toList()
      ..sort((a, b) => a.gameTime.compareTo(b.gameTime));
    
    return upcomingGames;
  }
  
  // Get today's games
  Future<List<GameModel>> getTodaysGames() async {
    final allGames = await fetchAllGames();
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final todayEnd = todayStart.add(Duration(days: 1));
    
    return allGames.where((game) => 
      game.gameTime.isAfter(todayStart) && 
      game.gameTime.isBefore(todayEnd)
    ).toList();
  }
}