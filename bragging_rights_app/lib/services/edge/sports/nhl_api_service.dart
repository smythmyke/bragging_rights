import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';

/// Official NHL API Service
/// Uses the new NHL API (api-web.nhle.com)
class NhlApiService {
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();
  
  static const String _baseUrl = 'https://api-web.nhle.com/v1';
  
  // NHL API endpoints
  static const String _scoreboardEndpoint = '/scoreboard/now';
  static const String _standingsEndpoint = '/standings/now';
  static const String _scheduleEndpoint = '/schedule';
  
  /// Get current NHL scoreboard (with caching)
  Future<NhlScoreboard?> getScoreboard() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    return await _cache.getCachedData<NhlScoreboard>(
      collection: 'games',
      documentId: 'nhl_official_$today',
      dataType: 'scores',
      sport: 'nhl',
      gameState: {'status': 'live'},
      fetchFunction: () async {
        debugPrint('🏒 Fetching NHL scoreboard from official API...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl$_scoreboardEndpoint'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ NHL API data received');
          return NhlScoreboard.fromJson(data);
        }
        throw Exception('NHL API error: ${response.statusCode}');
      },
    );
  }

  /// Get game details for a specific game
  Future<Map<String, dynamic>?> getGameDetails(int gameId) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/gamecenter/$gameId/landing'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching NHL game details: $e');
    }
    return null;
  }

  /// Get NHL standings
  Future<Map<String, dynamic>?> getStandings() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl$_standingsEndpoint'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching NHL standings: $e');
    }
    return null;
  }

  /// Get Edge intelligence for an NHL game
  Future<Map<String, dynamic>> getGameIntelligence({
    required String gameId,
    required String homeTeam,
    required String awayTeam,
  }) async {
    debugPrint('🧠 Gathering NHL intelligence for $homeTeam vs $awayTeam...');
    
    final intelligence = <String, dynamic>{
      'gameId': gameId,
      'source': 'NHL Official',
      'analysis': {},
      'keyFactors': [],
    };

    // Fetch multiple data points in parallel
    final futures = <Future>[];

    // Get current scoreboard
    futures.add(getScoreboard().then((data) {
      if (data != null) {
        intelligence['analysis']['scoreboard'] = data.toMap();
        intelligence['keyFactors'].add({
          'type': 'live_scores',
          'data': _extractGameInfo(data, homeTeam, awayTeam),
        });
        
        // Add period-specific analysis for hockey
        final gameInfo = _extractGameInfo(data, homeTeam, awayTeam);
        if (gameInfo['found'] == true) {
          intelligence['keyFactors'].add({
            'type': 'period_analysis',
            'data': _analyzePeriod(gameInfo),
          });
        }
      }
    }).catchError((e) {
      debugPrint('Error getting NHL scoreboard: $e');
    }));

    // Get standings for playoff context
    futures.add(getStandings().then((data) {
      if (data != null) {
        intelligence['analysis']['standings'] = data;
        intelligence['keyFactors'].add({
          'type': 'playoff_race',
          'data': _analyzePlayoffImplications(data, homeTeam, awayTeam),
        });
      }
    }).catchError((e) {
      debugPrint('Error getting NHL standings: $e');
    }));

    await Future.wait(futures);

    return intelligence;
  }

  /// Extract relevant game information
  Map<String, dynamic> _extractGameInfo(
    NhlScoreboard scoreboard,
    String homeTeam,
    String awayTeam,
  ) {
    // Find the specific game
    for (final gameDate in scoreboard.gamesByDate) {
      for (final game in gameDate.games) {
        final home = game.homeTeam['name']['default'] ?? '';
        final away = game.awayTeam['name']['default'] ?? '';
        
        if (_matcher.normalizeTeamName(home) == _matcher.normalizeTeamName(homeTeam) ||
            _matcher.normalizeTeamName(away) == _matcher.normalizeTeamName(awayTeam)) {
          return {
            'found': true,
            'gameId': game.id,
            'gameState': game.gameState,
            'period': game.period ?? 0,
            'clock': game.clock ?? '',
            'homeTeam': home,
            'awayTeam': away,
            'homeScore': game.homeTeam['score'] ?? 0,
            'awayScore': game.awayTeam['score'] ?? 0,
            'venue': game.venue['default'] ?? '',
            'startTime': game.startTimeUTC,
          };
        }
      }
    }
    
    return {'found': false};
  }

  /// Analyze period-specific factors for hockey
  Map<String, dynamic> _analyzePeriod(Map<String, dynamic> gameInfo) {
    final period = gameInfo['period'] ?? 0;
    final homeScore = gameInfo['homeScore'] ?? 0;
    final awayScore = gameInfo['awayScore'] ?? 0;
    final diff = (homeScore - awayScore).abs();
    
    // Hockey-specific analysis
    if (period == 3 && diff <= 1) {
      return {
        'situation': 'clutch_time',
        'description': 'Third period, one-goal game',
        'impact': 'high',
      };
    } else if (period >= 4) {
      return {
        'situation': 'overtime',
        'description': 'Overtime/Shootout',
        'impact': 'critical',
      };
    } else if (diff >= 4) {
      return {
        'situation': 'blowout',
        'description': 'Game likely decided',
        'impact': 'low',
      };
    }
    
    return {
      'situation': 'normal',
      'description': 'Regular play',
      'impact': 'medium',
    };
  }

  /// Analyze playoff implications
  Map<String, dynamic> _analyzePlayoffImplications(
    Map<String, dynamic> standings,
    String homeTeam,
    String awayTeam,
  ) {
    // Basic playoff analysis
    // Would need to parse standings structure for detailed analysis
    return {
      'playoffRelevance': 'Regular season game',
      'divisionRival': _areDivisionRivals(homeTeam, awayTeam),
      'importance': 'medium',
    };
  }

  /// Check if teams are division rivals
  bool _areDivisionRivals(String team1, String team2) {
    // NHL divisions
    final divisions = {
      'Atlantic': ['Bruins', 'Sabres', 'Red Wings', 'Panthers', 'Canadiens', 
                   'Senators', 'Lightning', 'Maple Leafs'],
      'Metropolitan': ['Hurricanes', 'Blue Jackets', 'Devils', 'Islanders', 
                       'Rangers', 'Flyers', 'Penguins', 'Capitals'],
      'Central': ['Avalanche', 'Blackhawks', 'Stars', 'Wild', 'Predators',
                  'Blues', 'Jets', 'Utah'],
      'Pacific': ['Ducks', 'Flames', 'Oilers', 'Kings', 'Kraken', 
                  'Sharks', 'Canucks', 'Golden Knights'],
    };
    
    for (final division in divisions.values) {
      bool hasTeam1 = false;
      bool hasTeam2 = false;
      
      for (final teamName in division) {
        if (team1.contains(teamName)) hasTeam1 = true;
        if (team2.contains(teamName)) hasTeam2 = true;
      }
      
      if (hasTeam1 && hasTeam2) return true;
    }
    
    return false;
  }
}

// NHL Data Models

class NhlScoreboard {
  final String focusedDate;
  final List<NhlGameDate> gamesByDate;

  NhlScoreboard({
    required this.focusedDate,
    required this.gamesByDate,
  });

  factory NhlScoreboard.fromJson(Map<String, dynamic> json) {
    final gamesByDate = <NhlGameDate>[];
    
    for (final dateData in json['gamesByDate'] ?? []) {
      gamesByDate.add(NhlGameDate.fromJson(dateData));
    }
    
    return NhlScoreboard(
      focusedDate: json['focusedDate'] ?? '',
      gamesByDate: gamesByDate,
    );
  }

  Map<String, dynamic> toMap() => {
    'focusedDate': focusedDate,
    'gamesByDate': gamesByDate.map((g) => g.toMap()).toList(),
  };
}

class NhlGameDate {
  final String date;
  final List<NhlGame> games;

  NhlGameDate({required this.date, required this.games});

  factory NhlGameDate.fromJson(Map<String, dynamic> json) {
    final games = <NhlGame>[];
    
    for (final gameData in json['games'] ?? []) {
      games.add(NhlGame.fromJson(gameData));
    }
    
    return NhlGameDate(
      date: json['date'] ?? '',
      games: games,
    );
  }

  Map<String, dynamic> toMap() => {
    'date': date,
    'games': games.map((g) => g.toMap()).toList(),
  };
}

class NhlGame {
  final int id;
  final String gameState;
  final String startTimeUTC;
  final Map<String, dynamic> venue;
  final Map<String, dynamic> homeTeam;
  final Map<String, dynamic> awayTeam;
  final int? period;
  final String? clock;

  NhlGame({
    required this.id,
    required this.gameState,
    required this.startTimeUTC,
    required this.venue,
    required this.homeTeam,
    required this.awayTeam,
    this.period,
    this.clock,
  });

  factory NhlGame.fromJson(Map<String, dynamic> json) {
    return NhlGame(
      id: json['id'] ?? 0,
      gameState: json['gameState'] ?? 'FUT',
      startTimeUTC: json['startTimeUTC'] ?? '',
      venue: json['venue'] ?? {},
      homeTeam: json['homeTeam'] ?? {},
      awayTeam: json['awayTeam'] ?? {},
      period: json['period'],
      clock: json['clock'],
    );
  }

  Map<String, dynamic> toMap() => {
    'id': id,
    'gameState': gameState,
    'startTimeUTC': startTimeUTC,
    'venue': venue,
    'homeTeam': homeTeam,
    'awayTeam': awayTeam,
    'period': period,
    'clock': clock,
  };
}