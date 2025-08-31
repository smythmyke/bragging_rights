import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/game_model.dart';

class ESPNDirectService {
  static const String baseUrl = 'https://site.api.espn.com/apis/site/v2/sports';
  
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
  
  // Fetch games for all sports
  Future<List<GameModel>> fetchAllGames() async {
    final allGames = <GameModel>[];
    
    for (final entry in sportEndpoints.entries) {
      try {
        final games = await fetchSportGames(entry.key);
        allGames.addAll(games);
      } catch (e) {
        print('Error fetching ${entry.key}: $e');
      }
    }
    
    // Sort by game time
    allGames.sort((a, b) => a.gameTime.compareTo(b.gameTime));
    
    return allGames;
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
      if (sport == 'UFC' || sport == 'BELLATOR' || sport == 'PFL' || sport == 'BOXING') {
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
        print('Returning ${games.length} $sport games');
        return games;
      }
    } catch (e) {
      print('Error fetching $sport games: $e');
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
        final eventName = event['name'] ?? '';
        if (eventName.contains(' vs ') || eventName.contains(' vs. ')) {
          final parts = eventName.split(RegExp(r' vs\.? '));
          if (parts.length >= 2) {
            awayTeam = parts[0].trim();
            homeTeam = parts[1].trim();
          }
        }
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