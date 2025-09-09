import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';

/// ESPN MLB API Service
/// Provides comprehensive MLB data including scores, pitchers, stats, and ballpark factors
class EspnMlbService {
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();
  
  static const String _baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb';
  
  /// Get today's MLB games
  Future<EspnMlbScoreboard?> getTodaysGames() async {
    final today = DateTime.now().toIso8601String().split('T')[0];
    
    return await _cache.getCachedData<EspnMlbScoreboard>(
      collection: 'games',
      documentId: 'mlb_espn_$today',
      dataType: 'scores',
      sport: 'mlb',
      gameState: {'source': 'espn'},
      fetchFunction: () async {
        debugPrint('⚾ Fetching MLB games from ESPN...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN MLB data received: ${data['events']?.length ?? 0} games');
          return EspnMlbScoreboard.fromJson(data);
        }
        throw Exception('ESPN MLB API error: ${response.statusCode}');
      },
    );
  }
  
  /// Get MLB games for date range (up to 60 days)
  Future<EspnMlbScoreboard?> getGamesForDateRange({int daysAhead = 60}) async {
    final now = DateTime.now();
    final endDate = now.add(Duration(days: daysAhead));
    final startStr = '${now.year}${now.month.toString().padLeft(2, '0')}${now.day.toString().padLeft(2, '0')}';
    final endStr = '${endDate.year}${endDate.month.toString().padLeft(2, '0')}${endDate.day.toString().padLeft(2, '0')}';
    
    return await _cache.getCachedData<EspnMlbScoreboard>(
      collection: 'games',
      documentId: 'mlb_espn_range_${startStr}_$endStr',
      dataType: 'scores',
      sport: 'mlb',
      gameState: {'source': 'espn', 'range': '$daysAhead days'},
      fetchFunction: () async {
        debugPrint('⚾ Fetching MLB games from ESPN for next $daysAhead days...');
        
        final response = await http.get(
          Uri.parse('$_baseUrl/scoreboard?dates=$startStr-$endStr'),
          headers: {'Accept': 'application/json'},
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          debugPrint('✅ ESPN MLB data received: ${data['events']?.length ?? 0} games for next $daysAhead days');
          return EspnMlbScoreboard.fromJson(data);
        }
        throw Exception('ESPN MLB API error: ${response.statusCode}');
      },
    );
  }

  /// Get MLB teams
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
      debugPrint('Error fetching MLB teams: $e');
    }
    return null;
  }

  /// Get MLB news
  Future<EspnMlbNews?> getNews({int limit = 10}) async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/news?limit=$limit'),
        headers: {'Accept': 'application/json'},
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return EspnMlbNews.fromJson(data);
      }
    } catch (e) {
      debugPrint('Error fetching MLB news: $e');
    }
    return null;
  }

  /// Get comprehensive game intelligence for Edge feature
  Future<Map<String, dynamic>> getGameIntelligence({
    required String homeTeam,
    required String awayTeam,
  }) async {
    debugPrint('⚾ Gathering MLB intelligence for $homeTeam vs $awayTeam');
    
    final intelligence = <String, dynamic>{
      'odds': {},
      'startingPitchers': {},
      'bullpen': {},
      'weather': {},
      'ballparkFactors': {},
      'recentForm': {},
      'headToHead': {},
      'injuries': [],
      'keyStats': {},
    };

    try {
      // Get current games
      final scoreboard = await getTodaysGames();
      if (scoreboard != null) {
        // Find the specific game
        final game = _findGame(scoreboard, homeTeam, awayTeam);
        if (game != null) {
          // Extract crucial MLB data
          if (game['competitions']?.isNotEmpty ?? false) {
            final competition = game['competitions'][0];
            
            // Extract odds
            final odds = competition['odds'];
            if (odds != null && odds.isNotEmpty) {
              intelligence['odds'] = {
                'spread': odds[0]['details'] ?? 'N/A',
                'overUnder': odds[0]['overUnder'] ?? 0,
                'moneyline': {
                  'home': odds[0]['homeTeamOdds']?['moneyLine'] ?? 'N/A',
                  'away': odds[0]['awayTeamOdds']?['moneyLine'] ?? 'N/A',
                },
              };
            }
            
            // Extract weather (important for MLB)
            final weather = competition['weather'];
            if (weather != null) {
              intelligence['weather'] = {
                'temperature': weather['temperature'] ?? 'Unknown',
                'conditions': weather['displayValue'] ?? 'Unknown',
                'wind': _parseWindForBaseball(weather['wind']),
                'humidity': weather['humidity'] ?? 'Unknown',
                'impact': _calculateBaseballWeatherImpact(weather),
              };
            }
            
            // Extract starting pitchers (CRUCIAL for MLB)
            final probables = competition['probables'];
            if (probables != null && probables.isNotEmpty) {
              for (final probable in probables) {
                final isHome = probable['homeAway'] == 'home';
                final pitcher = probable['athlete'];
                if (pitcher != null) {
                  final teamKey = isHome ? 'home' : 'away';
                  intelligence['startingPitchers'][teamKey] = {
                    'name': pitcher['fullName'] ?? 'TBD',
                    'id': pitcher['id'],
                    'stats': _extractPitcherStats(pitcher),
                    'handedness': pitcher['position']?['abbreviation'] ?? 'R',
                  };
                }
              }
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
                  'last10': _extractRecord(records, 'last-ten-games'),
                  'streak': team['streak'] ?? 0,
                };
              }
              
              // Get team statistics
              final stats = team['statistics'] ?? [];
              intelligence['keyStats'][teamKey] = _parseTeamStats(stats);
              
              // Get lineup if available
              final lineup = team['lineup'];
              if (lineup != null && lineup.isNotEmpty) {
                intelligence['keyStats'][teamKey]['battingOrder'] = 
                  lineup.take(3).map((p) => p['athlete']?['fullName'] ?? 'Unknown').toList();
              }
            }
            
            // Extract ballpark information
            final venue = competition['venue'];
            if (venue != null) {
              intelligence['ballparkFactors'] = {
                'name': venue['fullName'] ?? 'Unknown',
                'city': venue['address']?['city'] ?? 'Unknown',
                'capacity': venue['capacity'] ?? 0,
                'surface': venue['grass'] ?? true ? 'Grass' : 'Turf',
                'factors': _getBallparkFactors(venue['id']),
              };
            }
            
            // Extract game situation
            final situation = competition['situation'];
            if (situation != null) {
              intelligence['gameSituation'] = {
                'inning': situation['currentInning'] ?? 1,
                'outs': situation['outs'] ?? 0,
                'balls': situation['balls'] ?? 0,
                'strikes': situation['strikes'] ?? 0,
                'onBase': {
                  'first': situation['onFirst'] ?? false,
                  'second': situation['onSecond'] ?? false,
                  'third': situation['onThird'] ?? false,
                },
              };
            }
          }
          
          // Extract injuries from notes
          final notes = game['competitions']?[0]?['notes'] ?? [];
          for (final note in notes) {
            if (note['headline']?.toLowerCase().contains('il') ?? false ||
                note['headline']?.toLowerCase().contains('injured') ?? false ||
                note['headline']?.toLowerCase().contains('dtd') ?? false) {
              intelligence['injuries'].add({
                'note': note['headline'],
                'type': 'game_note',
              });
            }
          }
        }
      }

      // Get team-specific news for injury reports and updates
      final news = await getNews(limit: 20);
      if (news != null) {
        for (final article in news.articles) {
          final headline = article.headline.toLowerCase();
          
          // Check for pitcher updates
          if ((headline.contains(homeTeam.toLowerCase()) || 
               headline.contains(awayTeam.toLowerCase())) &&
              (headline.contains('pitcher') || 
               headline.contains('start') ||
               headline.contains('bullpen'))) {
            intelligence['pitcherNews'] ??= [];
            intelligence['pitcherNews'].add({
              'headline': article.headline,
              'description': article.description,
            });
          }
          
          // Check for injuries
          if ((headline.contains(homeTeam.toLowerCase()) || 
               headline.contains(awayTeam.toLowerCase())) &&
              (headline.contains('injury') || 
               headline.contains('il') ||
               headline.contains('disabled'))) {
            intelligence['injuries'].add({
              'headline': article.headline,
              'description': article.description,
              'type': 'news',
            });
          }
        }
      }

      // Add MLB-specific insights
      intelligence['insights'] = _generateMlbInsights(intelligence);

    } catch (e) {
      debugPrint('Error gathering MLB intelligence: $e');
    }

    return intelligence;
  }

  /// Find specific game in scoreboard
  Map<String, dynamic>? _findGame(
    EspnMlbScoreboard scoreboard,
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

  /// Parse wind for baseball impact
  Map<String, dynamic> _parseWindForBaseball(dynamic wind) {
    if (wind == null) return {'speed': 0, 'direction': 'Unknown', 'impact': 'None'};
    
    final windStr = wind.toString();
    final speed = int.tryParse(windStr.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    
    String direction = 'Unknown';
    String impact = 'Minimal';
    
    if (windStr.toLowerCase().contains('out')) {
      direction = 'Out';
      impact = speed > 10 ? 'Favors hitters (fly balls carry)' : 'Slight hitter advantage';
    } else if (windStr.toLowerCase().contains('in')) {
      direction = 'In';
      impact = speed > 10 ? 'Favors pitchers (fly balls held up)' : 'Slight pitcher advantage';
    } else if (windStr.toLowerCase().contains('l-r') || windStr.toLowerCase().contains('left')) {
      direction = 'Left to Right';
      impact = 'May affect left-handed hitters';
    } else if (windStr.toLowerCase().contains('r-l') || windStr.toLowerCase().contains('right')) {
      direction = 'Right to Left';
      impact = 'May affect right-handed hitters';
    }
    
    return {
      'speed': speed,
      'direction': direction,
      'impact': impact,
    };
  }

  /// Calculate weather impact on baseball
  String _calculateBaseballWeatherImpact(Map<String, dynamic> weather) {
    final temp = int.tryParse(weather['temperature']?.toString() ?? '72') ?? 72;
    final wind = _parseWindForBaseball(weather['wind']);
    final windSpeed = wind['speed'] as int;
    
    // Temperature effects
    String tempImpact = '';
    if (temp > 90) {
      tempImpact = 'Hot weather - ball carries further';
    } else if (temp < 50) {
      tempImpact = 'Cold weather - ball doesn\'t carry';
    }
    
    // Wind effects
    String windImpact = wind['impact'] as String;
    
    // Combined impact
    if (tempImpact.isNotEmpty && windSpeed > 10) {
      return 'HIGH - $tempImpact, $windImpact';
    } else if (tempImpact.isNotEmpty || windSpeed > 10) {
      return 'MEDIUM - ${tempImpact.isNotEmpty ? tempImpact : windImpact}';
    }
    
    return 'LOW - Minimal weather impact';
  }

  /// Extract pitcher statistics
  Map<String, dynamic> _extractPitcherStats(Map<String, dynamic> pitcher) {
    final stats = pitcher['statistics'] ?? [];
    final parsed = <String, dynamic>{};
    
    for (final stat in stats) {
      final name = stat['name'] ?? '';
      final value = stat['displayValue'] ?? stat['value'] ?? 0;
      
      if (name == 'era') {
        parsed['era'] = value;
      } else if (name == 'wins') {
        parsed['wins'] = value;
      } else if (name == 'losses') {
        parsed['losses'] = value;
      } else if (name == 'whip') {
        parsed['whip'] = value;
      } else if (name == 'strikeouts') {
        parsed['strikeouts'] = value;
      }
    }
    
    // Add default ERA if not found
    if (parsed['era'] == null) {
      parsed['era'] = 'N/A';
    }
    
    return parsed;
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
      
      // Key MLB stats
      if (name.contains('battingAverage')) {
        parsed['battingAverage'] = value;
      } else if (name.contains('era')) {
        parsed['teamEra'] = value;
      } else if (name.contains('runs')) {
        parsed['runsPerGame'] = value;
      } else if (name.contains('homeRuns')) {
        parsed['homeRuns'] = value;
      } else if (name.contains('stolenBases')) {
        parsed['stolenBases'] = value;
      } else if (name.contains('onBase')) {
        parsed['obp'] = value;
      }
    }
    
    return parsed;
  }

  /// Get ballpark factors (simplified - would need real data)
  Map<String, dynamic> _getBallparkFactors(String? venueId) {
    // Simplified ballpark factors - in production, this would come from a database
    final hittersParks = ['3289', '15', '2680']; // Coors, Yankees, Camden
    final pitchersParks = ['2395', '2671', '3313']; // Petco, Oakland, Marlins
    
    if (venueId != null) {
      if (hittersParks.contains(venueId)) {
        return {
          'type': 'Hitters Park',
          'runFactor': 1.15,
          'description': 'Favors offense - expect higher scoring',
        };
      } else if (pitchersParks.contains(venueId)) {
        return {
          'type': 'Pitchers Park',
          'runFactor': 0.85,
          'description': 'Favors pitching - expect lower scoring',
        };
      }
    }
    
    return {
      'type': 'Neutral',
      'runFactor': 1.0,
      'description': 'Balanced park',
    };
  }

  /// Generate MLB-specific insights
  List<Map<String, dynamic>> _generateMlbInsights(Map<String, dynamic> intelligence) {
    final insights = <Map<String, dynamic>>[];
    
    // Starting pitcher analysis (most important in MLB)
    final homePitcher = intelligence['startingPitchers']?['home'];
    final awayPitcher = intelligence['startingPitchers']?['away'];
    
    if (homePitcher != null && homePitcher['stats']?['era'] != null) {
      final era = double.tryParse(homePitcher['stats']['era'].toString()) ?? 99.0;
      if (era < 3.0) {
        insights.add({
          'category': 'pitching',
          'insight': 'Elite home starter: ${homePitcher['name']} (${era} ERA)',
          'confidence': 0.90,
          'impact': 'high',
        });
      } else if (era > 5.0) {
        insights.add({
          'category': 'pitching',
          'insight': 'Struggling home starter: ${homePitcher['name']} (${era} ERA)',
          'confidence': 0.85,
          'impact': 'high',
        });
      }
    }
    
    // Weather and wind impact
    final weather = intelligence['weather'] ?? {};
    if (weather['wind'] != null) {
      final wind = weather['wind'] as Map<String, dynamic>;
      if (wind['direction'] == 'Out' && (wind['speed'] as int) > 10) {
        insights.add({
          'category': 'weather',
          'insight': 'Wind blowing out at ${wind['speed']} mph - favor overs',
          'confidence': 0.80,
          'impact': 'high',
        });
      } else if (wind['direction'] == 'In' && (wind['speed'] as int) > 10) {
        insights.add({
          'category': 'weather',
          'insight': 'Wind blowing in at ${wind['speed']} mph - favor unders',
          'confidence': 0.80,
          'impact': 'high',
        });
      }
    }
    
    // Ballpark factor
    final ballpark = intelligence['ballparkFactors'] ?? {};
    if (ballpark['type'] == 'Hitters Park') {
      insights.add({
        'category': 'ballpark',
        'insight': '${ballpark['name']} favors hitters',
        'confidence': 0.75,
        'impact': 'medium',
      });
    } else if (ballpark['type'] == 'Pitchers Park') {
      insights.add({
        'category': 'ballpark',
        'insight': '${ballpark['name']} favors pitchers',
        'confidence': 0.75,
        'impact': 'medium',
      });
    }
    
    // Recent form
    final homeForm = intelligence['recentForm']?['home'] ?? {};
    if (homeForm['last10'] != null) {
      final parts = homeForm['last10'].split('-');
      if (parts.length == 2) {
        final wins = int.tryParse(parts[0]) ?? 0;
        if (wins >= 7) {
          insights.add({
            'category': 'momentum',
            'insight': 'Home team hot: ${homeForm['last10']} last 10',
            'confidence': 0.70,
            'impact': 'medium',
          });
        } else if (wins <= 3) {
          insights.add({
            'category': 'momentum',
            'insight': 'Home team cold: ${homeForm['last10']} last 10',
            'confidence': 0.70,
            'impact': 'medium',
          });
        }
      }
    }
    
    // Day vs Night game
    final hour = DateTime.now().hour;
    if (hour < 16) {
      insights.add({
        'category': 'timing',
        'insight': 'Day game - check day/night splits',
        'confidence': 0.60,
        'impact': 'low',
      });
    }
    
    return insights;
  }
}

/// ESPN MLB Scoreboard model
class EspnMlbScoreboard {
  final List<dynamic> events;
  final Map<String, dynamic> leagues;
  
  EspnMlbScoreboard({
    required this.events,
    required this.leagues,
  });
  
  factory EspnMlbScoreboard.fromJson(Map<String, dynamic> json) {
    return EspnMlbScoreboard(
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

/// ESPN MLB News model
class EspnMlbNews {
  final List<EspnMlbArticle> articles;
  
  EspnMlbNews({required this.articles});
  
  factory EspnMlbNews.fromJson(Map<String, dynamic> json) {
    final articlesList = json['articles'] as List? ?? [];
    return EspnMlbNews(
      articles: articlesList
          .map((a) => EspnMlbArticle.fromJson(a))
          .toList(),
    );
  }
}

/// ESPN MLB Article model
class EspnMlbArticle {
  final String headline;
  final String description;
  final String? link;
  final DateTime? published;
  
  EspnMlbArticle({
    required this.headline,
    required this.description,
    this.link,
    this.published,
  });
  
  factory EspnMlbArticle.fromJson(Map<String, dynamic> json) {
    return EspnMlbArticle(
      headline: json['headline'] ?? '',
      description: json['description'] ?? '',
      link: json['links']?['web']?['href'],
      published: json['published'] != null 
          ? DateTime.tryParse(json['published'])
          : null,
    );
  }
}