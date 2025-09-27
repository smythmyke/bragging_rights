import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';
import '../../api_call_tracker.dart';

/// ESPN NFL API Service
/// Provides comprehensive NFL data including scores, stats, injuries, and odds
class EspnNflService {
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();
  
  static const String _baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl';
  
  /// Get today's NFL games
  Future<EspnNflScoreboard?> getTodaysGames() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    return await _cache.getCachedData<EspnNflScoreboard>(
      collection: 'games',
      documentId: 'nfl_espn_$today',
      dataType: 'scores',
      sport: 'nfl',
      gameState: {'source': 'espn'},
      fetchFunction: () async {
        debugPrint('🏈 Fetching NFL games from ESPN...');
        APICallTracker.logAPICall('ESPN', 'NFL Scoreboard', details: 'Today\'s games');

        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN NFL data received: ${data['events']?.length ?? 0} games');
          return EspnNflScoreboard.fromJson(data);
        }
        throw Exception('ESPN NFL API error: ${response.statusCode}');
      },
    );
  }
  
  /// Get NFL games for date range (up to 60 days)
  Future<EspnNflScoreboard?> getGamesForDateRange({int daysAhead = 60}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
    
    return await _cache.getCachedData<EspnNflScoreboard>(
      collection: 'games',
      documentId: 'nfl_espn_range_${startStr}_$endStr',
      dataType: 'scores',
      sport: 'nfl',
      gameState: {'source': 'espn', 'range': '$daysAhead days'},
      fetchFunction: () async {
        debugPrint('🏈 Fetching NFL games from ESPN for next $daysAhead days...');
        APICallTracker.logAPICall('ESPN', 'NFL Scoreboard Range', details: 'Next $daysAhead days');

        // ESPN API supports date ranges with dates parameter
        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard?dates=$startStr-$endStr'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN NFL data received: ${data['events']?.length ?? 0} games for next $daysAhead days');
          return EspnNflScoreboard.fromJson(data);
        }
        throw Exception('ESPN NFL API error: ${response.statusCode}');
      },
    );
  }

  /// Get NFL teams
  Future<Map<String, dynamic>?> getTeams() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/teams'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        return json.decode(response.body);
      }
    } catch (e) {
      debugPrint('Error fetching NFL teams: $e');
    }
    return null;
  }

  /// Get NFL news
  Future<EspnNflNews?> getNews({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/news?limit=$limit'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EspnNflNews.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching NFL news: $e');
    }
    return null;
  }

  /// Get comprehensive game intelligence for Edge feature
  Future<Map<String, dynamic>> getGameIntelligence({
    required String homeTeam,
    required String awayTeam,
  }) async {
    debugPrint('🏈 Gathering NFL intelligence for $homeTeam vs $awayTeam');
    
    final intelligence = <String, dynamic>{
      'odds': {},
      'injuries': [],
      'recentForm': {},
      'weather': {},
      'keyMatchups': [],
      'teamStats': {},
    };

    try {
      // Get current games
      final scoreboard = await getTodaysGames();
      if (scoreboard != null) {
        // Find the specific game
        final game = _findGame(scoreboard, homeTeam, awayTeam);
        if (game != null) {
          // Extract odds
          if (game['competitions']?.isNotEmpty ?? false) {
            final competition = game['competitions'][0];
            final odds = competition['odds'];
            if (odds != null && odds.isNotEmpty) {
              intelligence['odds'] = {
                'spread': odds[0]['details'] ?? 'N/A',
                'overUnder': odds[0]['overUnder'] ?? 0,
                'homeTeamOdds': odds[0]['homeTeamOdds'] ?? {},
                'awayTeamOdds': odds[0]['awayTeamOdds'] ?? {},
              };
            }
            
            // Extract weather (crucial for NFL)
            final weather = competition['weather'];
            if (weather != null) {
              intelligence['weather'] = {
                'temperature': weather['temperature'] ?? 'Unknown',
                'conditions': weather['displayValue'] ?? 'Unknown',
                'wind': weather['wind'] ?? 'Unknown',
                'precipitation': weather['precipitation'] ?? 0,
                'impact': _calculateWeatherImpact(weather),
              };
            }
            
            // Extract team records and recent form
            final competitors = competition['competitors'] ?? [];
            for (final team in competitors) {
              final isHome = team['homeAway'] == 'home';
              final teamKey = isHome ? 'home' : 'away';
              
              // Get records
              final records = team['records'] ?? [];
              if (records.isNotEmpty) {
                final overall = records.firstWhere(
                  (r) => r['type'] == 'total',
                  orElse: () => {},
                );
                
                intelligence['recentForm'][teamKey] = {
                  'record': overall['summary'] ?? '0-0',
                  'homeRecord': _extractRecord(records, 'home'),
                  'awayRecord': _extractRecord(records, 'road'),
                  'streak': team['streak'] ?? 0,
                  'divisionRecord': _extractRecord(records, 'division'),
                };
              }
              
              // Get team statistics
              final stats = team['statistics'] ?? [];
              intelligence['teamStats'][teamKey] = _parseTeamStats(stats);
            }
          }
          
          // Extract injuries from notes or headlines
          final notes = game['competitions']?[0]?['notes'] ?? [];
          for (final note in notes) {
            if (note['headline']?.toLowerCase().contains('questionable') ?? false ||
                note['headline']?.toLowerCase().contains('out') ?? false ||
                note['headline']?.toLowerCase().contains('doubtful') ?? false) {
              intelligence['injuries'].add({
                'note': note['headline'],
                'type': 'game_note',
              });
            }
          }
        }
      }

      // Get team-specific news for injury reports
      final news = await getNews(limit: 20);
      if (news != null) {
        for (final article in news.articles) {
          final headline = article.headline.toLowerCase();
          if ((headline.contains(homeTeam.toLowerCase()) || 
               headline.contains(awayTeam.toLowerCase())) &&
              (headline.contains('injury') || 
               headline.contains('questionable') ||
               headline.contains('doubtful') ||
               headline.contains('out'))) {
            intelligence['injuries'].add({
              'headline': article.headline,
              'description': article.description,
              'type': 'news',
            });
          }
        }
      }

      // Add key matchups (QB vs Defense, etc.)
      intelligence['keyMatchups'] = _analyzeKeyMatchups(intelligence);
      
      // Add NFL-specific insights
      intelligence['insights'] = _generateNflInsights(intelligence);

    } catch (e) {
      debugPrint('Error gathering NFL intelligence: $e');
    }

    return intelligence;
  }

  /// Find specific game in scoreboard
  Map<String, dynamic>? _findGame(
    EspnNflScoreboard scoreboard,
    String homeTeam,
    String awayTeam,
  ) {
    for (final event in scoreboard.events) {
      final competitors = event['competitions']?[0]?['competitors'] ?? [];
      if (competitors.length >= 2) {
        final home = competitors.firstWhere(
          (c) => c['homeAway'] == 'home',
          orElse: () => {},
        );
        final away = competitors.firstWhere(
          (c) => c['homeAway'] == 'away',
          orElse: () => {},
        );
        
        final homeName = home['team']?['displayName'] ?? '';
        final awayName = away['team']?['displayName'] ?? '';
        
        if (_matcher.normalizeTeamName(homeName) == _matcher.normalizeTeamName(homeTeam) &&
            _matcher.normalizeTeamName(awayName) == _matcher.normalizeTeamName(awayTeam)) {
          return event;
        }
      }
    }
    return null;
  }

  /// Calculate weather impact on game
  String _calculateWeatherImpact(Map<String, dynamic> weather) {
    final temp = int.tryParse(weather['temperature']?.toString() ?? '70') ?? 70;
    final windSpeed = int.tryParse(
      weather['wind']?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '0'
    ) ?? 0;
    final precipitation = weather['precipitation'] ?? 0;
    
    // High impact conditions
    if (temp < 32) return 'HIGH - Freezing conditions affect passing game';
    if (windSpeed > 20) return 'HIGH - Strong winds affect kicking and passing';
    if (precipitation > 50) return 'HIGH - Rain/snow affects ball handling';
    
    // Medium impact
    if (temp < 40) return 'MEDIUM - Cold weather may affect offense';
    if (windSpeed > 15) return 'MEDIUM - Moderate wind may affect kicks';
    if (precipitation > 25) return 'MEDIUM - Light precipitation possible';
    
    // Low impact
    if (windSpeed > 10) return 'LOW - Slight breeze';
    
    return 'MINIMAL - Good weather conditions';
  }

  /// Extract specific record type
  String _extractRecord(List<dynamic> records, String type) {
    final record = records.firstWhere(
      (r) => r['type'] == type,
      orElse: () => {'summary': '0-0'},
    );
    return record['summary'] ?? '0-0';
  }

  /// Parse team statistics
  Map<String, dynamic> _parseTeamStats(List<dynamic> stats) {
    final parsed = <String, dynamic>{};
    
    for (final stat in stats) {
      final name = stat['name'] ?? '';
      final value = stat['displayValue'] ?? stat['value'] ?? 0;
      
      // Key NFL stats
      if (name.contains('yardsPerGame')) {
        parsed['yardsPerGame'] = value;
      } else if (name.contains('pointsPerGame')) {
        parsed['pointsPerGame'] = value;
      } else if (name.contains('turnovers')) {
        parsed['turnovers'] = value;
      } else if (name.contains('penalties')) {
        parsed['penalties'] = value;
      } else if (name.contains('thirdDown')) {
        parsed['thirdDownPct'] = value;
      } else if (name.contains('redZone')) {
        parsed['redZonePct'] = value;
      }
    }
    
    return parsed;
  }

  /// Analyze key matchups
  List<Map<String, dynamic>> _analyzeKeyMatchups(Map<String, dynamic> intelligence) {
    final matchups = <Map<String, dynamic>>[];
    
    // Analyze offensive vs defensive matchups
    final homeStats = intelligence['teamStats']['home'] ?? {};
    final awayStats = intelligence['teamStats']['away'] ?? {};
    
    // Passing offense vs passing defense
    if (homeStats['yardsPerGame'] != null) {
      matchups.add({
        'type': 'offensive_efficiency',
        'description': 'Home offense averaging ${homeStats['yardsPerGame']} yards/game',
        'impact': homeStats['yardsPerGame'] > 350 ? 'high' : 'medium',
      });
    }
    
    // Red zone efficiency
    if (homeStats['redZonePct'] != null) {
      matchups.add({
        'type': 'red_zone',
        'description': 'Red zone efficiency: ${homeStats['redZonePct']}',
        'impact': 'medium',
      });
    }
    
    // Weather impact on specific matchups
    final weather = intelligence['weather'] ?? {};
    if (weather['impact']?.contains('HIGH') ?? false) {
      matchups.add({
        'type': 'weather',
        'description': weather['impact'],
        'impact': 'high',
      });
    }
    
    return matchups;
  }

  /// Generate NFL-specific insights
  List<Map<String, dynamic>> _generateNflInsights(Map<String, dynamic> intelligence) {
    final insights = <Map<String, dynamic>>[];
    
    // Weather insights
    final weather = intelligence['weather'] ?? {};
    if (weather['impact']?.contains('HIGH') ?? false) {
      insights.add({
        'category': 'weather',
        'insight': 'Severe weather conditions - favor running game and under',
        'confidence': 0.85,
      });
    }
    
    // Home field advantage
    final homeForm = intelligence['recentForm']?['home'] ?? {};
    if (homeForm['homeRecord'] != null) {
      final parts = homeForm['homeRecord'].split('-');
      if (parts.length == 2) {
        final wins = int.tryParse(parts[0]) ?? 0;
        final losses = int.tryParse(parts[1]) ?? 0;
        if (wins > losses * 2) {
          insights.add({
            'category': 'home_advantage',
            'insight': 'Strong home record (${homeForm['homeRecord']})',
            'confidence': 0.75,
          });
        }
      }
    }
    
    // Division games (higher intensity)
    if (homeForm['divisionRecord'] != null) {
      insights.add({
        'category': 'division_rivalry',
        'insight': 'Division game - expect higher intensity',
        'confidence': 0.70,
      });
    }
    
    // Injury impact
    if (intelligence['injuries']?.isNotEmpty ?? false) {
      insights.add({
        'category': 'injuries',
        'insight': '${intelligence['injuries'].length} injury concerns reported',
        'confidence': 0.80,
      });
    }
    
    return insights;
  }
}

/// ESPN NFL Scoreboard model
class EspnNflScoreboard {
  final List<dynamic> events;
  final Map<String, dynamic> leagues;
  
  EspnNflScoreboard({
    required this.events,
    required this.leagues,
  });
  
  factory EspnNflScoreboard.fromJson(Map<String, dynamic> json) {
    return EspnNflScoreboard(
      events: json['events'] ?? [],
      leagues: json['leagues']?[0] ?? {},
    );
  }
  
  Map<String, dynamic> toJson() {
    return {
      'events': events,
      'leagues': leagues,
    };
  }
}

/// ESPN NFL News model
class EspnNflNews {
  final List<EspnNflArticle> articles;
  
  EspnNflNews({required this.articles});
  
  factory EspnNflNews.fromJson(Map<String, dynamic> json) {
    final articlesList = json['articles'] as List? ?? [];
    return EspnNflNews(
      articles: articlesList
          .map((a) => EspnNflArticle.fromJson(a))
          .toList(),
    );
  }
}

/// ESPN NFL Article model
class EspnNflArticle {
  final String headline;
  final String description;
  final String? link;
  final DateTime? published;
  
  EspnNflArticle({
    required this.headline,
    required this.description,
    this.link,
    this.published,
  });
  
  factory EspnNflArticle.fromJson(Map<String, dynamic> json) {
    return EspnNflArticle(
      headline: json['headline'] ?? '',
      description: json['description'] ?? '',
      link: json['links']?['web']?['href'],
      published: json['published'] != null 
          ? DateTime.tryParse(json['published'])
          : null,
    );
  }
}