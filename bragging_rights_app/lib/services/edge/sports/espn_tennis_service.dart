import 'package:flutter/foundation.dart';
import '../api_gateway.dart';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';

/// ESPN Tennis API Service
/// Provides tennis match data, rankings, and intelligence
class EspnTennisService {
  final ApiGateway _gateway = ApiGateway();
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();

  /// Get today's tennis matches
  Future<TennisScoreboard?> getScoreboard() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      return await _cache.getCachedData<TennisScoreboard>(
        collection: 'tennis_matches',
        documentId: 'tennis_$today',
        dataType: 'scoreboard',
        sport: 'tennis',
        gameState: {'date': today},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/scoreboard',
            queryParams: {'limit': '50'},
          );
          
          if (response != null && response['events'] != null) {
            return TennisScoreboard.fromJson(response);
          }
          return null;
        },
      );
    } catch (e) {
      debugPrint('Error fetching tennis scoreboard: $e');
      return null;
    }
  }

  /// Get ATP rankings
  Future<Map<String, dynamic>?> getATPRankings() async {
    try {
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_rankings',
        documentId: 'atp_rankings',
        dataType: 'rankings',
        sport: 'tennis',
        gameState: {'type': 'atp'},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/atp/rankings',
          );
          return response;
        },
      );
    } catch (e) {
      debugPrint('Error fetching ATP rankings: $e');
      return null;
    }
  }

  /// Get WTA rankings
  Future<Map<String, dynamic>?> getWTARankings() async {
    try {
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_rankings',
        documentId: 'wta_rankings',
        dataType: 'rankings',
        sport: 'tennis',
        gameState: {'type': 'wta'},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/wta/rankings',
          );
          return response;
        },
      );
    } catch (e) {
      debugPrint('Error fetching WTA rankings: $e');
      return null;
    }
  }

  /// Get match details
  Future<Map<String, dynamic>?> getMatchDetails(String matchId) async {
    try {
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_matches',
        documentId: 'match_$matchId',
        dataType: 'match_details',
        sport: 'tennis',
        gameState: {'matchId': matchId},
        fetchFunction: () async {
          final response = await _gateway.request(
            apiName: 'espn',
            endpoint: '/tennis/match',
            queryParams: {'event': matchId},
          );
          return response;
        },
      );
    } catch (e) {
      debugPrint('Error fetching match details: $e');
      return null;
    }
  }

  /// Get tennis news
  Future<List<Map<String, dynamic>>?> getNews() async {
    try {
      final response = await _gateway.request(
        apiName: 'espn',
        endpoint: '/tennis/news',
        queryParams: {'limit': '10'},
      );
      
      if (response != null && response['articles'] != null) {
        return List<Map<String, dynamic>>.from(response['articles']);
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching tennis news: $e');
      return null;
    }
  }

  /// Get match intelligence for betting insights
  Future<Map<String, dynamic>> getMatchIntelligence({
    required String matchId,
    required String player1Name,
    required String player2Name,
  }) async {
    try {
      final intelligence = <String, dynamic>{
        'matchId': matchId,
        'player1': player1Name,
        'player2': player2Name,
        'insights': [],
        'data': {},
      };

      // Fetch match details
      final matchDetails = await getMatchDetails(matchId);
      if (matchDetails != null) {
        intelligence['data']['matchDetails'] = matchDetails;
        
        // Extract tournament info
        final tournament = matchDetails['tournament']?['name'] ?? 'Unknown';
        final surface = _determineSurface(tournament);
        
        intelligence['insights'].add({
          'type': 'tournament',
          'text': 'Playing at $tournament on $surface court',
          'impact': 'medium',
        });
      }

      // Fetch rankings for comparison
      final [atpRankings, wtaRankings] = await Future.wait([
        getATPRankings(),
        getWTARankings(),
      ]);

      // Find player rankings
      final p1Ranking = _findPlayerRanking(player1Name, atpRankings, wtaRankings);
      final p2Ranking = _findPlayerRanking(player2Name, atpRankings, wtaRankings);

      if (p1Ranking != null && p2Ranking != null) {
        final rankDiff = (p1Ranking - p2Ranking).abs();
        String rankingInsight;
        
        if (rankDiff <= 5) {
          rankingInsight = 'Evenly matched players (rankings within 5 spots)';
        } else if (p1Ranking < p2Ranking) {
          rankingInsight = '$player1Name ranked #$p1Ranking, significantly higher than $player2Name (#$p2Ranking)';
        } else {
          rankingInsight = '$player2Name ranked #$p2Ranking, significantly higher than $player1Name (#$p1Ranking)';
        }
        
        intelligence['insights'].add({
          'type': 'ranking',
          'text': rankingInsight,
          'impact': rankDiff > 20 ? 'high' : 'medium',
        });
      }

      // Add mock H2H data (would need separate source in production)
      intelligence['insights'].add({
        'type': 'h2h',
        'text': _generateMockH2H(player1Name, player2Name),
        'impact': 'medium',
      });

      // Add surface preference insight
      intelligence['insights'].add({
        'type': 'surface',
        'text': _generateSurfaceInsight(player1Name, player2Name, _determineSurface('current')),
        'impact': 'high',
      });

      // Recent form analysis
      intelligence['insights'].add({
        'type': 'form',
        'text': _generateFormInsight(player1Name, player2Name),
        'impact': 'medium',
      });

      return intelligence;
    } catch (e) {
      debugPrint('Error generating match intelligence: $e');
      return {
        'error': 'Failed to generate intelligence',
        'matchId': matchId,
      };
    }
  }

  // Helper methods
  String _determineSurface(String tournament) {
    final lowerTournament = tournament.toLowerCase();
    
    if (lowerTournament.contains('wimbledon')) return 'grass';
    if (lowerTournament.contains('french') || lowerTournament.contains('roland')) return 'clay';
    if (lowerTournament.contains('us open') || lowerTournament.contains('australian')) return 'hard';
    if (lowerTournament.contains('indoor')) return 'indoor hard';
    
    // Default to hard court for most tournaments
    return 'hard';
  }

  int? _findPlayerRanking(String playerName, Map<String, dynamic>? atpRankings, Map<String, dynamic>? wtaRankings) {
    // Check ATP rankings
    if (atpRankings != null) {
      final competitors = atpRankings['rankings']?['competitors'] ?? [];
      for (var i = 0; i < competitors.length; i++) {
        final athlete = competitors[i]['athlete'];
        if (athlete != null && athlete['displayName'] == playerName) {
          return competitors[i]['rank'] ?? (i + 1);
        }
      }
    }
    
    // Check WTA rankings
    if (wtaRankings != null) {
      final competitors = wtaRankings['rankings']?['competitors'] ?? [];
      for (var i = 0; i < competitors.length; i++) {
        final athlete = competitors[i]['athlete'];
        if (athlete != null && athlete['displayName'] == playerName) {
          return competitors[i]['rank'] ?? (i + 1);
        }
      }
    }
    
    return null;
  }

  String _generateMockH2H(String player1, String player2) {
    // In production, would fetch real H2H data
    final hash = (player1.hashCode + player2.hashCode).abs();
    final p1Wins = 3 + (hash % 5);
    final p2Wins = 2 + (hash % 4);
    
    if (p1Wins > p2Wins) {
      return '$player1 leads head-to-head $p1Wins-$p2Wins';
    } else if (p2Wins > p1Wins) {
      return '$player2 leads head-to-head $p2Wins-$p1Wins';
    }
    return 'Even head-to-head record at $p1Wins-$p2Wins';
  }

  String _generateSurfaceInsight(String player1, String player2, String surface) {
    // Mock surface performance data
    final p1Hash = player1.hashCode.abs();
    final p2Hash = player2.hashCode.abs();
    
    final p1SurfaceStrength = (p1Hash % 100) / 100;
    final p2SurfaceStrength = (p2Hash % 100) / 100;
    
    if (p1SurfaceStrength > p2SurfaceStrength + 0.2) {
      return '$player1 excels on $surface courts';
    } else if (p2SurfaceStrength > p1SurfaceStrength + 0.2) {
      return '$player2 has advantage on $surface surface';
    }
    return 'Both players perform similarly on $surface courts';
  }

  String _generateFormInsight(String player1, String player2) {
    // Mock recent form data
    final now = DateTime.now();
    final seed = now.day + now.month;
    
    final p1Form = 2 + (seed % 4); // Wins in last 5
    final p2Form = 1 + ((seed + 1) % 4);
    
    if (p1Form > p2Form) {
      return '$player1 in better form ($p1Form wins in last 5 matches)';
    } else if (p2Form > p1Form) {
      return '$player2 showing strong form ($p2Form recent victories)';
    }
    return 'Both players showing similar recent form';
  }
}

/// Tennis scoreboard model
class TennisScoreboard {
  final List<TennisMatch> matches;
  final List<Map<String, dynamic>> leagues;
  final DateTime lastUpdated;

  TennisScoreboard({
    required this.matches,
    required this.leagues,
    required this.lastUpdated,
  });

  factory TennisScoreboard.fromJson(Map<String, dynamic> json) {
    final events = json['events'] ?? [];
    final matches = <TennisMatch>[];
    
    for (var event in events) {
      try {
        matches.add(TennisMatch.fromJson(event));
      } catch (e) {
        debugPrint('Error parsing tennis match: $e');
      }
    }

    return TennisScoreboard(
      matches: matches,
      leagues: List<Map<String, dynamic>>.from(json['leagues'] ?? []),
      lastUpdated: DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'matches': matches.map((m) => m.toMap()).toList(),
      'leagues': leagues,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }
}

/// Tennis match model
class TennisMatch {
  final String id;
  final String name;
  final String? tournament;
  final String status;
  final DateTime? date;
  final Map<String, dynamic> player1;
  final Map<String, dynamic> player2;
  final Map<String, dynamic>? score;
  final Map<String, dynamic>? odds;

  TennisMatch({
    required this.id,
    required this.name,
    this.tournament,
    required this.status,
    this.date,
    required this.player1,
    required this.player2,
    this.score,
    this.odds,
  });

  factory TennisMatch.fromJson(Map<String, dynamic> json) {
    final competition = json['competitions']?[0] ?? {};
    final competitors = competition['competitors'] ?? [];
    
    // Extract player info
    Map<String, dynamic> p1 = {};
    Map<String, dynamic> p2 = {};
    
    if (competitors.length >= 2) {
      final comp1 = competitors[0];
      final comp2 = competitors[1];
      
      p1 = {
        'id': comp1['id'],
        'name': comp1['athlete']?['displayName'] ?? 'Unknown',
        'country': comp1['athlete']?['flag']?['alt'] ?? '',
        'seed': comp1['curatedRank']?['current'],
        'score': comp1['score'],
        'winner': comp1['winner'] ?? false,
      };
      
      p2 = {
        'id': comp2['id'],
        'name': comp2['athlete']?['displayName'] ?? 'Unknown',
        'country': comp2['athlete']?['flag']?['alt'] ?? '',
        'seed': comp2['curatedRank']?['current'],
        'score': comp2['score'],
        'winner': comp2['winner'] ?? false,
      };
    }

    // Parse date
    DateTime? matchDate;
    if (json['date'] != null) {
      try {
        matchDate = DateTime.parse(json['date']);
      } catch (e) {
        debugPrint('Error parsing date: $e');
      }
    }

    // Extract score
    Map<String, dynamic>? scoreData;
    if (competition['score'] != null) {
      scoreData = {
        'displayScore': competition['score'],
        'sets': competition['sets'] ?? [],
      };
    }

    return TennisMatch(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      tournament: json['season']?['name'],
      status: competition['status']?['type']?['description'] ?? 'Scheduled',
      date: matchDate,
      player1: p1,
      player2: p2,
      score: scoreData,
      odds: competition['odds'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'tournament': tournament,
      'status': status,
      'date': date?.toIso8601String(),
      'player1': player1,
      'player2': player2,
      'score': score,
      'odds': odds,
    };
  }

  bool get isLive => status.toLowerCase().contains('in progress') || 
                     status.toLowerCase().contains('live');
  
  bool get isCompleted => status.toLowerCase().contains('final') || 
                          status.toLowerCase().contains('completed');
  
  bool get isScheduled => status.toLowerCase().contains('scheduled') || 
                          status.toLowerCase().contains('upcoming');
}