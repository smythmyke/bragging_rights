import 'package:flutter/foundation.dart';
import '../api_gateway.dart';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';

/// ESPN NBA Service - Primary NBA data source
/// Using ESPN's free API that actually works
class EspnNbaService {
  final ApiGateway _gateway = ApiGateway();
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();
  
  static const String _apiName = 'espn';
  
  // ESPN NBA endpoints
  static const String _scoreboardEndpoint = '/basketball/nba/scoreboard';
  static const String _teamsEndpoint = '/basketball/nba/teams';
  static const String _newsEndpoint = '/basketball/nba/news';
  static const String _standingsEndpoint = '/basketball/nba/standings';
  static const String _scheduleEndpoint = '/basketball/nba/schedule';

  /// Get today's NBA games from ESPN (with caching)
  Future<EspnScoreboard?> getTodaysGames() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    return await _cache.getCachedData<EspnScoreboard>(
      collection: 'games',
      documentId: 'nba_$today',
      dataType: 'scores',
      sport: 'nba',
      gameState: {'status': 'live'}, // Will use appropriate TTL
      fetchFunction: () async {
        debugPrint('🏀 Fetching NBA games from ESPN API...');
        
        final response = await _gateway.request(
          apiName: _apiName,
          endpoint: _scoreboardEndpoint,
          queryParams: {
            'dates': today.replaceAll('-', ''),
          },
        );

        if (response.data != null) {
          debugPrint('✅ ESPN NBA data received');
          return EspnScoreboard.fromJson(response.data);
        }
        throw Exception('No data from ESPN');
      },
    );
  }
  
  /// Get NBA games for date range (up to 60 days)
  Future<EspnScoreboard?> getGamesForDateRange({int daysAhead = 60}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
    
    return await _cache.getCachedData<EspnScoreboard>(
      collection: 'games',
      documentId: 'nba_range_${startStr}_$endStr',
      dataType: 'scores',
      sport: 'nba',
      gameState: {'source': 'espn', 'range': '$daysAhead days'},
      fetchFunction: () async {
        debugPrint('🏀 Fetching NBA games from ESPN for next $daysAhead days...');
        
        final response = await _gateway.request(
          apiName: _apiName,
          endpoint: _scoreboardEndpoint,
          queryParams: {
            'dates': '$startStr-$endStr',
          },
        );

        if (response.data != null) {
          debugPrint('✅ ESPN NBA data received: ${response.data['events']?.length ?? 0} games for next $daysAhead days');
          return EspnScoreboard.fromJson(response.data);
        }
        throw Exception('No data from ESPN');
      },
    );
  }

  /// Get NBA teams
  Future<EspnTeams?> getTeams() async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _teamsEndpoint,
      );

      if (response.data != null) {
        return EspnTeams.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching ESPN teams: $e');
    }
    return null;
  }

  /// Get NBA news
  Future<EspnNews?> getNews({int limit = 10}) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _newsEndpoint,
        queryParams: {'limit': limit.toString()},
      );

      if (response.data != null) {
        return EspnNews.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching ESPN news: $e');
    }
    return null;
  }

  /// Get NBA standings
  Future<EspnStandings?> getStandings() async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _standingsEndpoint,
      );

      if (response.data != null) {
        return EspnStandings.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching ESPN standings: $e');
    }
    return null;
  }

  /// Get game details for a specific game
  Future<Map<String, dynamic>?> getGameDetails(String gameId) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: '/basketball/nba/game',
        queryParams: {'gameId': gameId},
      );

      if (response.data != null) {
        return response.data;
      }
    } catch (e) {
      debugPrint('Error fetching game details: $e');
    }
    return null;
  }

  /// Get Edge intelligence for an ESPN NBA game
  Future<Map<String, dynamic>> getGameIntelligence({
    required String gameId,
    required String homeTeam,
    required String awayTeam,
  }) async {
    debugPrint('🧠 Gathering ESPN intelligence for $homeTeam vs $awayTeam...');
    
    final intelligence = <String, dynamic>{
      'gameId': gameId,
      'source': 'ESPN',
      'analysis': {},
      'keyFactors': [],
      'news': [],
    };

    // Fetch multiple data points in parallel
    final futures = <Future>[];

    // Get today's games for context
    futures.add(getTodaysGames().then((data) {
      if (data != null) {
        intelligence['analysis']['scoreboard'] = data.toMap();
        intelligence['keyFactors'].add({
          'type': 'live_scores',
          'data': _extractGameInfo(data, homeTeam, awayTeam),
        });
      }
    }).catchError((e) {
      debugPrint('Error getting scoreboard: $e');
    }));

    // Get recent news
    futures.add(getNews(limit: 5).then((data) {
      if (data != null) {
        intelligence['news'] = _filterRelevantNews(data, homeTeam, awayTeam);
      }
    }).catchError((e) {
      debugPrint('Error getting news: $e');
    }));

    // Get standings for playoff context
    futures.add(getStandings().then((data) {
      if (data != null) {
        intelligence['analysis']['standings'] = data.toMap();
        intelligence['keyFactors'].add({
          'type': 'playoff_race',
          'data': _analyzeStandingsImpact(data, homeTeam, awayTeam),
        });
      }
    }).catchError((e) {
      debugPrint('Error getting standings: $e');
    }));

    await Future.wait(futures);

    return intelligence;
  }

  /// Extract relevant game information
  Map<String, dynamic> _extractGameInfo(
    EspnScoreboard scoreboard,
    String homeTeam,
    String awayTeam,
  ) {
    // Find the specific game
    for (final event in scoreboard.events) {
      final home = event['competitions']?[0]?['competitors']?[0]?['team']?['displayName'];
      final away = event['competitions']?[0]?['competitors']?[1]?['team']?['displayName'];
      
      if (_matcher.normalizeTeamName(home ?? '') == _matcher.normalizeTeamName(homeTeam) ||
          _matcher.normalizeTeamName(away ?? '') == _matcher.normalizeTeamName(awayTeam)) {
        return {
          'found': true,
          'status': event['status']?['type']?['description'],
          'homeScore': event['competitions']?[0]?['competitors']?[0]?['score'],
          'awayScore': event['competitions']?[0]?['competitors']?[1]?['score'],
          'odds': event['competitions']?[0]?['odds'],
        };
      }
    }
    
    return {'found': false};
  }

  /// Filter news relevant to teams
  List<Map<String, dynamic>> _filterRelevantNews(
    EspnNews news,
    String homeTeam,
    String awayTeam,
  ) {
    final relevant = <Map<String, dynamic>>[];
    final homeNorm = _matcher.normalizeTeamName(homeTeam).toLowerCase();
    final awayNorm = _matcher.normalizeTeamName(awayTeam).toLowerCase();

    for (final article in news.articles) {
      final headline = article['headline']?.toString().toLowerCase() ?? '';
      final description = article['description']?.toString().toLowerCase() ?? '';
      
      if (headline.contains(homeNorm) || 
          headline.contains(awayNorm) ||
          description.contains(homeNorm) || 
          description.contains(awayNorm)) {
        relevant.add({
          'headline': article['headline'],
          'description': article['description'],
          'published': article['published'],
          'relevance': 'high',
        });
      }
    }

    return relevant;
  }

  /// Analyze standings impact
  Map<String, dynamic> _analyzeStandingsImpact(
    EspnStandings standings,
    String homeTeam,
    String awayTeam,
  ) {
    // TODO: Parse standings and determine playoff implications
    return {
      'playoffImplications': 'Analysis pending',
      'divisionRivalry': false,
      'conferenceStanding': 'TBD',
    };
  }
}

// ESPN Data Models

class EspnScoreboard {
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic> league;

  EspnScoreboard({required this.events, required this.league});

  factory EspnScoreboard.fromJson(Map<String, dynamic> json) {
    return EspnScoreboard(
      events: List<Map<String, dynamic>>.from(json['events'] ?? []),
      league: json['leagues']?[0] ?? {},
    );
  }

  Map<String, dynamic> toMap() => {
    'events': events,
    'league': league,
  };

  Map<String, dynamic> toJson() {
    return {
      'events': events,
      'league': league,
    };
  }
}

class EspnTeams {
  final List<Map<String, dynamic>> teams;

  EspnTeams({required this.teams});

  factory EspnTeams.fromJson(Map<String, dynamic> json) {
    final teamsData = <Map<String, dynamic>>[];
    final sports = json['sports'] as List? ?? [];
    
    if (sports.isNotEmpty) {
      final leagues = sports[0]['leagues'] as List? ?? [];
      if (leagues.isNotEmpty) {
        final teams = leagues[0]['teams'] as List? ?? [];
        for (final team in teams) {
          teamsData.add(team['team'] as Map<String, dynamic>);
        }
      }
    }
    
    return EspnTeams(teams: teamsData);
  }

  Map<String, dynamic> toMap() => {'teams': teams};
}

class EspnNews {
  final List<Map<String, dynamic>> articles;

  EspnNews({required this.articles});

  factory EspnNews.fromJson(Map<String, dynamic> json) {
    return EspnNews(
      articles: List<Map<String, dynamic>>.from(json['articles'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {'articles': articles};
}

class EspnStandings {
  final List<Map<String, dynamic>> standings;

  EspnStandings({required this.standings});

  factory EspnStandings.fromJson(Map<String, dynamic> json) {
    // ESPN standings have complex structure, simplified here
    return EspnStandings(
      standings: List<Map<String, dynamic>>.from(json['standings'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {'standings': standings};
}