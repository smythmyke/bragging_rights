import 'package:flutter/foundation.dart';
import '../api_gateway.dart';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';

/// ESPN NHL Service - NHL data from ESPN
class EspnNhlService {
  final ApiGateway _gateway = ApiGateway();
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();
  
  static const String _apiName = 'espn';
  
  // ESPN NHL endpoints
  static const String _scoreboardEndpoint = '/hockey/nhl/scoreboard';
  static const String _teamsEndpoint = '/hockey/nhl/teams';
  static const String _newsEndpoint = '/hockey/nhl/news';
  static const String _standingsEndpoint = '/hockey/nhl/standings';
  
  /// Get today's NHL games from ESPN (with caching)
  Future<EspnNhlScoreboard?> getTodaysGames() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    return await _cache.getCachedData<EspnNhlScoreboard>(
      collection: 'games',
      documentId: 'nhl_$today',
      dataType: 'scores',
      sport: 'nhl',
      gameState: {'status': 'live'},
      fetchFunction: () async {
        debugPrint('🏒 Fetching NHL games from ESPN API...');
        
        final response = await _gateway.request(
          apiName: _apiName,
          endpoint: _scoreboardEndpoint,
          queryParams: {
            'dates': today.replaceAll('-', ''),
          },
        );

        if (response.data != null) {
          debugPrint('✅ ESPN NHL data received');
          return EspnNhlScoreboard.fromJson(response.data);
        }
        throw Exception('No data from ESPN NHL');
      },
    );
  }
  
  /// Get NHL games for date range (up to 60 days)
  Future<EspnNhlScoreboard?> getGamesForDateRange({int daysAhead = 60}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
    
    return await _cache.getCachedData<EspnNhlScoreboard>(
      collection: 'games',
      documentId: 'nhl_range_${startStr}_$endStr',
      dataType: 'scores',
      sport: 'nhl',
      gameState: {'source': 'espn', 'range': '$daysAhead days'},
      fetchFunction: () async {
        debugPrint('🏒 Fetching NHL games from ESPN for next $daysAhead days...');
        
        final response = await _gateway.request(
          apiName: _apiName,
          endpoint: _scoreboardEndpoint,
          queryParams: {
            'dates': '$startStr-$endStr',
          },
        );

        if (response.data != null) {
          debugPrint('✅ ESPN NHL data received: ${response.data['events']?.length ?? 0} games for next $daysAhead days');
          return EspnNhlScoreboard.fromJson(response.data);
        }
        throw Exception('No data from ESPN NHL');
      },
    );
  }

  /// Get NHL teams
  Future<Map<String, dynamic>?> getTeams() async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _teamsEndpoint,
      );
      return response.data;
    } catch (e) {
      debugPrint('Error fetching ESPN NHL teams: $e');
    }
    return null;
  }

  /// Get NHL news
  Future<EspnNhlNews?> getNews({int limit = 10}) async {
    try {
      final response = await _gateway.request(
        apiName: _apiName,
        endpoint: _newsEndpoint,
        queryParams: {'limit': limit.toString()},
      );

      if (response.data != null) {
        return EspnNhlNews.fromJson(response.data);
      }
    } catch (e) {
      debugPrint('Error fetching ESPN NHL news: $e');
    }
    return null;
  }

  /// Get Edge intelligence for an ESPN NHL game
  Future<Map<String, dynamic>> getGameIntelligence({
    required String gameId,
    required String homeTeam,
    required String awayTeam,
  }) async {
    debugPrint('🧠 Gathering ESPN NHL intelligence for $homeTeam vs $awayTeam...');
    
    final intelligence = <String, dynamic>{
      'gameId': gameId,
      'source': 'ESPN NHL',
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
      debugPrint('Error getting NHL scoreboard: $e');
    }));

    // Get recent news
    futures.add(getNews(limit: 5).then((data) {
      if (data != null) {
        intelligence['news'] = _filterRelevantNews(data, homeTeam, awayTeam);
      }
    }).catchError((e) {
      debugPrint('Error getting NHL news: $e');
    }));

    await Future.wait(futures);

    return intelligence;
  }

  /// Extract relevant game information
  Map<String, dynamic> _extractGameInfo(
    EspnNhlScoreboard scoreboard,
    String homeTeam,
    String awayTeam,
  ) {
    // Find the specific game
    for (final event in scoreboard.events) {
      final competitions = event['competitions'] as List? ?? [];
      if (competitions.isEmpty) continue;
      
      final competition = competitions.first as Map<String, dynamic>;
      final competitors = competition['competitors'] as List? ?? [];
      
      for (final competitor in competitors) {
        final team = competitor['team'] as Map<String, dynamic>? ?? {};
        final displayName = team['displayName'] ?? '';
        
        if (_matcher.normalizeTeamName(displayName) == _matcher.normalizeTeamName(homeTeam) ||
            _matcher.normalizeTeamName(displayName) == _matcher.normalizeTeamName(awayTeam)) {
          return {
            'found': true,
            'status': event['status']?['type']?['description'],
            'period': event['status']?['period'] ?? 0,
            'clock': event['status']?['displayClock'] ?? '',
            'homeScore': _getScore(competitors, true),
            'awayScore': _getScore(competitors, false),
          };
        }
      }
    }
    
    return {'found': false};
  }

  /// Get score for home or away team
  String _getScore(List<dynamic> competitors, bool isHome) {
    for (final competitor in competitors) {
      if ((competitor['homeAway'] == 'home') == isHome) {
        return competitor['score'] ?? '0';
      }
    }
    return '0';
  }

  /// Filter news relevant to teams
  List<Map<String, dynamic>> _filterRelevantNews(
    EspnNhlNews news,
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
}

// ESPN NHL Data Models

class EspnNhlScoreboard {
  final List<Map<String, dynamic>> events;
  final Map<String, dynamic> league;

  EspnNhlScoreboard({required this.events, required this.league});

  factory EspnNhlScoreboard.fromJson(Map<String, dynamic> json) {
    return EspnNhlScoreboard(
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

class EspnNhlNews {
  final List<Map<String, dynamic>> articles;

  EspnNhlNews({required this.articles});

  factory EspnNhlNews.fromJson(Map<String, dynamic> json) {
    return EspnNhlNews(
      articles: List<Map<String, dynamic>>.from(json['articles'] ?? []),
    );
  }

  Map<String, dynamic> toMap() => {'articles': articles};
}