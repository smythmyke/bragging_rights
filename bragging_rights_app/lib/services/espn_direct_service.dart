import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/game_model.dart';
import 'game_odds_enrichment_service.dart';
import 'game_cache_service.dart';

class ESPNDirectService {
  static const String baseUrl = 'https://site.api.espn.com/apis/site/v2/sports';
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GameOddsEnrichmentService _oddsEnrichmentService = GameOddsEnrichmentService();
  final GameCacheService _cacheService = GameCacheService();
  
  // Throttle background refreshes to prevent duplicate API calls
  static DateTime? _lastBackgroundRefresh;
  static const Duration _backgroundRefreshInterval = Duration(minutes: 30);
  
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

  // Cache for fighter IDs to avoid repeated searches
  final Map<String, String> _fighterIdCache = {};

  // Search for fighter ID by name using ESPN search API
  Future<String?> _searchFighterIdByName(String fighterName) async {
    if (fighterName.isEmpty || fighterName == 'TBD') {
      return null;
    }

    // Check in-memory cache first
    if (_fighterIdCache.containsKey(fighterName)) {
      return _fighterIdCache[fighterName];
    }

    // Check Firestore cache
    try {
      final doc = await _firestore
          .collection('fighter_id_lookups')
          .doc(fighterName.toLowerCase().replaceAll(' ', '_'))
          .get();

      if (doc.exists && doc.data() != null) {
        final fighterId = doc.data()!['fighterId']?.toString();
        if (fighterId != null) {
          print('✅ Found cached fighter ID for "$fighterName": $fighterId');
          _fighterIdCache[fighterName] = fighterId;
          return fighterId;
        }
      }
    } catch (e) {
      print('Error checking fighter ID cache: $e');
    }

    try {
      final searchUrl = 'https://site.web.api.espn.com/apis/search/v2'
          '?query=${Uri.encodeComponent(fighterName)}'
          '&limit=5&sport=mma';

      final response = await http.get(Uri.parse(searchUrl));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final results = data['results'] ?? [];

        for (final result in results) {
          if (result['type'] == 'player') {
            final contents = result['contents'] ?? [];
            for (final player in contents) {
              final displayName = player['displayName']?.toString() ?? '';

              // Check for exact or close match
              if (displayName.toLowerCase() == fighterName.toLowerCase() ||
                  displayName.toLowerCase().contains(fighterName.toLowerCase()) ||
                  fighterName.toLowerCase().contains(displayName.toLowerCase())) {

                // Extract ID from UID (format: s:3301~a:XXXXXX)
                final uid = player['uid']?.toString() ?? '';
                final idMatch = RegExp(r'a:(\d+)').firstMatch(uid);
                if (idMatch != null) {
                  final fighterId = idMatch.group(1)!;
                  print('✅ Found fighter ID for "$fighterName": $fighterId ($displayName)');
                  _fighterIdCache[fighterName] = fighterId;

                  // Also cache the actual display name to handle variations
                  _fighterIdCache[displayName] = fighterId;

                  // Save to Firestore for persistent caching
                  try {
                    await _firestore
                        .collection('fighter_id_lookups')
                        .doc(fighterName.toLowerCase().replaceAll(' ', '_'))
                        .set({
                      'fighterName': fighterName,
                      'displayName': displayName,
                      'fighterId': fighterId,
                      'timestamp': FieldValue.serverTimestamp(),
                    });

                    // Also save under the display name if different
                    if (displayName.toLowerCase() != fighterName.toLowerCase()) {
                      await _firestore
                          .collection('fighter_id_lookups')
                          .doc(displayName.toLowerCase().replaceAll(' ', '_'))
                          .set({
                        'fighterName': displayName,
                        'displayName': displayName,
                        'fighterId': fighterId,
                        'timestamp': FieldValue.serverTimestamp(),
                      });
                    }
                  } catch (e) {
                    print('Error saving fighter ID to cache: $e');
                  }

                  return fighterId;
                }
              }
            }
          }
        }
      }

      print('⚠️ Could not find fighter ID for: $fighterName');
      return null;
    } catch (e) {
      print('Error searching for fighter "$fighterName": $e');
      return null;
    }
  }

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
      
      // DISABLED: Automatic odds enrichment to reduce API calls
      // Odds will be fetched on-demand when user navigates to betting screen
      // print('🎲 Enriching games with odds and creating pools...');
      // await _oddsEnrichmentService.enrichGamesWithOdds(games);
      
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
  
  // Background fetch and update with throttling
  Future<void> _fetchAndUpdateGamesInBackground() async {
    // Check if we should throttle this refresh
    if (_lastBackgroundRefresh != null) {
      final timeSinceLastRefresh = DateTime.now().difference(_lastBackgroundRefresh!);
      if (timeSinceLastRefresh < _backgroundRefreshInterval) {
        print('⏳ Skipping background refresh - last refresh was ${timeSinceLastRefresh.inMinutes} minutes ago');
        return;
      }
    }
    
    try {
      _lastBackgroundRefresh = DateTime.now();
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
      // DISABLED: Automatic odds enrichment to reduce API calls
      // Odds will be fetched on-demand when user navigates to betting screen
      // _oddsEnrichmentService.enrichGamesWithOdds(games);
    } catch (e) {
      print('Error saving to Firestore in background: $e');
    }
  }
  
  // Fetch games for a specific sport
  Future<List<GameModel>> fetchSportGames(String sport) async {
    try {
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
            final game = await _parseESPNEvent(event, sport);
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
            final game = await _parseESPNEvent(event, sport);
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
    return ['UFC', 'BELLATOR', 'PFL', 'BOXING', 'TENNIS', 'GOLF'].contains(sport.toUpperCase());
  }

  // Parse ESPN event to GameModel
  Future<GameModel> _parseESPNEvent(Map<String, dynamic> event, String sport) async {
    // For UFC/combat sports, parse all fights on the card
    if (sport == 'UFC' || sport == 'BELLATOR' || sport == 'PFL' || sport == 'BOXING') {
      final fullEventName = event['name'] ?? '';
      print('🥊 Processing combat sport ($sport) event: $fullEventName');
      print('📝 Full ESPN event name: "$fullEventName"');
      print('📝 Event ID: ${event['id']}');
      final competitions = event['competitions'] ?? [];
      
      // Parse ALL competitions into fight objects
      List<Map<String, dynamic>> fights = [];
      final totalFights = competitions.length;
      
      for (int i = 0; i < competitions.length; i++) {
        final comp = competitions[i];
        final competitors = comp['competitors'] ?? [];
        
        if (competitors.length >= 2) {
          final fighter1 = competitors[0]['athlete'] ?? {};
          final fighter2 = competitors[1]['athlete'] ?? {};
          
          // Determine fight position based on index (last = main event)
          final reversedIndex = totalFights - i - 1;
          String cardPosition;
          int rounds;
          
          if (reversedIndex == 0) {
            cardPosition = 'Main Event';
            rounds = 5;
          } else if (reversedIndex == 1) {
            cardPosition = 'Co-Main Event';
            rounds = 3;
          } else if (reversedIndex < 5) {
            cardPosition = 'Main Card';
            rounds = 3;
          } else {
            cardPosition = 'Preliminaries';
            rounds = 3;
          }
          
          // Extract fighter IDs properly, keeping them null if not available
          String? fighter1Id = fighter1['id']?.toString();
          String? fighter2Id = fighter2['id']?.toString();
          final fighter1Name = fighter1['displayName'] ?? 'TBD';
          final fighter2Name = fighter2['displayName'] ?? 'TBD';

          // If fighter IDs are missing, try to search for them by name
          if ((fighter1Id == null || fighter1Id.isEmpty) && fighter1Name != 'TBD') {
            print('🔍 Searching for fighter ID: $fighter1Name');
            fighter1Id = await _searchFighterIdByName(fighter1Name);
          }

          if ((fighter2Id == null || fighter2Id.isEmpty) && fighter2Name != 'TBD') {
            print('🔍 Searching for fighter ID: $fighter2Name');
            fighter2Id = await _searchFighterIdByName(fighter2Name);
          }

          fights.add({
            'id': comp['id']?.toString() ?? 'fight_$i',
            'fighter1Id': fighter1Id ?? '', // Keep empty if still no ID found
            'fighter2Id': fighter2Id ?? '', // Keep empty if still no ID found
            'fighter1Name': fighter1Name,
            'fighter2Name': fighter2Name,
            'fighter1Record': fighter1['record'] ?? '',
            'fighter2Record': fighter2['record'] ?? '',
            'weightClass': comp['notes']?[0]?['text'] ?? 'Catchweight',
            'rounds': rounds,
            'cardPosition': cardPosition,
            'fightOrder': reversedIndex + 1,
          });
        }
      }
      
      // Extract main event fighters for display
      String? mainEventFighters;
      if (fights.isNotEmpty) {
        final mainFight = fights.last;
        mainEventFighters = "${mainFight['fighter1Name']} vs ${mainFight['fighter2Name']}";
      }
      
      // Get the LAST competition for scoring (main event)
      final mainCompetition = competitions.isNotEmpty ? competitions.last : {};
      final mainCompetitors = mainCompetition['competitors'] ?? [];
      
      // Get scores if fight is complete
      int? homeScore;
      int? awayScore;
      if (mainCompetitors.length >= 2) {
        homeScore = mainCompetitors[0]['score'] != null ? 
                   int.tryParse(mainCompetitors[0]['score'].toString()) : null;
        awayScore = mainCompetitors[1]['score'] != null ?
                   int.tryParse(mainCompetitors[1]['score'].toString()) : null;
      }
      
      // Get venue
      String? venue;
      if (competitions.isNotEmpty) {
        venue = competitions[0]['venue']?['fullName'];
      }
      
      // Get status
      final statusData = event['status'] ?? {};
      final statusType = statusData['type'] ?? {};
      String status = 'scheduled';
      if (statusType['name'] == 'STATUS_IN_PROGRESS') {
        status = 'live';
      } else if (statusType['name'] == 'STATUS_FINAL') {
        status = 'final';
      }
      
      // Get date/time
      final dateStr = event['date'] ?? '';
      DateTime gameTime;
      try {
        gameTime = DateTime.parse(dateStr);
      } catch (e) {
        gameTime = DateTime.now();
      }
      
      return GameModel(
        id: event['id']?.toString() ?? DateTime.now().millisecondsSinceEpoch.toString(),
        sport: sport,
        homeTeam: '',  // Empty for combat sports
        awayTeam: fullEventName,  // Full event name with main event fighters
        gameTime: gameTime,
        status: status,
        homeScore: homeScore,
        awayScore: awayScore,
        venue: venue,
        league: sport,
        fights: fights,
        isCombatSport: true,
        totalFights: fights.length,
        mainEventFighters: mainEventFighters,
      );
    }
    
    // Original logic for non-combat sports
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
      // For non-combat individual sports (tennis, golf)
      final fullEventName = event['name'] ?? '';
      
      // For individual sports, competitors are athletes not teams
      // They use "order" field (1 or 2) instead of homeAway
      final athleteList = [];
      for (final competitor in competitors) {
        final order = competitor['order'] ?? 0;
        final athlete = competitor['athlete'] ?? {};
        final name = athlete['displayName'] ?? 
                     athlete['fullName'] ?? 
                     athlete['shortName'] ?? 'TBD';
        final score = competitor['score'] != null ? int.tryParse(competitor['score']) : null;
        final flag = athlete['flag']?['href'] ?? '';
        final record = competitor['records']?[0]?['summary'] ?? '';
        
        athleteList.add({
          'order': order,
          'name': name,
          'score': score,
          'flag': flag,
          'record': record,
        });
      }
      
      // Sort by order to ensure consistent ordering
      athleteList.sort((a, b) => (a['order'] as int).compareTo(b['order'] as int));
      
      // For MMA/Boxing, the LAST fight is the main event
      // ESPN typically lists fights in reverse order (main event first)
      // So we need to check if this is the main competition
      bool isMainEvent = false;
      final competitions = event['competitions'] ?? [];
      if (competitions.isNotEmpty) {
        // Check if this is the first competition (usually main event for combat sports)
        isMainEvent = competition == competitions[0];
      }
      
      // Assign fighters based on order
      if (athleteList.length >= 2) {
        final fighter1 = athleteList[0];
        final fighter2 = athleteList[1];
        
        awayTeam = fighter1['name'];
        awayScore = fighter1['score'];
        awayTeamLogo = fighter1['flag'];
        
        homeTeam = fighter2['name'];
        homeScore = fighter2['score'];
        homeTeamLogo = fighter2['flag'];
      } else if (athleteList.length == 1) {
        awayTeam = athleteList[0]['name'];
        awayScore = athleteList[0]['score'];
        awayTeamLogo = athleteList[0]['flag'];
        homeTeam = 'TBD';
      }
      
      // For combat sports, use the full event name from ESPN directly
      // ESPN already provides perfectly formatted names like "UFC Fight Night: Imavov vs. Borralho"
      // Note: This shouldn't be reached since we return early for combat sports above
      if (sport == 'UFC' || sport == 'BELLATOR' || sport == 'PFL' || sport == 'BOXING') {
        awayTeam = fullEventName;
        homeTeam = '';  // Clear homeTeam for combat sports display
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