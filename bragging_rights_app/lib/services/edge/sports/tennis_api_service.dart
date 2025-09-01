import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';

/// Tennis API Service using Tennis Live Data API
/// Free tier available with 1000 requests/month
class TennisApiService {
  final EventMatcher _matcher = EventMatcher();
  final EdgeCacheService _cache = EdgeCacheService();
  
  // Using Tennis Live Data API (free tier)
  static const String _baseUrl = 'https://tennis-live-data.p.rapidapi.com';
  static const String _apiKey = 'YOUR_RAPIDAPI_KEY'; // Need to get from RapidAPI
  
  // Alternative: Using SportRadar Tennis API (trial available)
  static const String _altBaseUrl = 'https://api.sportradar.com/tennis/trial/v3/en';
  
  /// Get today's matches across all tournaments
  Future<List<Map<String, dynamic>>?> getTodaysMatches() async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      
      // Try cache first
      final cached = await _cache.getCachedData<List<Map<String, dynamic>>>(
        collection: 'tennis_matches',
        documentId: 'tennis_$today',
        dataType: 'matches',
        sport: 'tennis',
        gameState: {'status': 'scheduled'},
        fetchFunction: () => _fetchTodaysMatches(today),
      );
      
      return cached;
    } catch (e) {
      debugPrint('Error getting today\'s tennis matches: $e');
      return null;
    }
  }
  
  Future<List<Map<String, dynamic>>> _fetchTodaysMatches(String date) async {
    try {
      // For now, return mock data until API key is obtained
      // In production, this would call the actual API
      return _getMockMatches();
    } catch (e) {
      debugPrint('Error fetching tennis matches: $e');
      return [];
    }
  }
  
  /// Get ATP rankings
  Future<List<Map<String, dynamic>>?> getATPRankings() async {
    try {
      return await _cache.getCachedData<List<Map<String, dynamic>>>(
        collection: 'tennis_rankings',
        documentId: 'atp_rankings',
        dataType: 'rankings',
        sport: 'tennis',
        gameState: {'type': 'atp'},
        fetchFunction: _fetchATPRankings,
      );
    } catch (e) {
      debugPrint('Error getting ATP rankings: $e');
      return null;
    }
  }
  
  /// Get WTA rankings
  Future<List<Map<String, dynamic>>?> getWTARankings() async {
    try {
      return await _cache.getCachedData<List<Map<String, dynamic>>>(
        collection: 'tennis_rankings',
        documentId: 'wta_rankings',
        dataType: 'rankings',
        sport: 'tennis',
        gameState: {'type': 'wta'},
        fetchFunction: _fetchWTARankings,
      );
    } catch (e) {
      debugPrint('Error getting WTA rankings: $e');
      return null;
    }
  }
  
  /// Get player statistics
  Future<Map<String, dynamic>?> getPlayerStats(String playerId) async {
    try {
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_players',
        documentId: 'player_$playerId',
        dataType: 'stats',
        sport: 'tennis',
        gameState: {'playerId': playerId},
        fetchFunction: () => _fetchPlayerStats(playerId),
      );
    } catch (e) {
      debugPrint('Error getting player stats: $e');
      return null;
    }
  }
  
  /// Get head-to-head record between two players
  Future<Map<String, dynamic>?> getHeadToHead(String player1Id, String player2Id) async {
    try {
      final key = 'h2h_${player1Id}_$player2Id';
      return await _cache.getCachedData<Map<String, dynamic>>(
        collection: 'tennis_h2h',
        documentId: key,
        dataType: 'head_to_head',
        sport: 'tennis',
        gameState: {'players': [player1Id, player2Id]},
        fetchFunction: () => _fetchHeadToHead(player1Id, player2Id),
      );
    } catch (e) {
      debugPrint('Error getting head-to-head: $e');
      return null;
    }
  }
  
  /// Get active tournaments
  Future<List<Map<String, dynamic>>?> getActiveTournaments() async {
    try {
      return await _cache.getCachedData<List<Map<String, dynamic>>>(
        collection: 'tennis_tournaments',
        documentId: 'active_tournaments',
        dataType: 'tournaments',
        sport: 'tennis',
        gameState: {'status': 'active'},
        fetchFunction: _fetchActiveTournaments,
      );
    } catch (e) {
      debugPrint('Error getting tournaments: $e');
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
      
      // Gather data in parallel
      final results = await Future.wait([
        getPlayerStats(player1Name),
        getPlayerStats(player2Name),
        getHeadToHead(player1Name, player2Name),
      ]);
      
      final player1Stats = results[0];
      final player2Stats = results[1];
      final h2h = results[2];
      
      // Add surface analysis
      if (player1Stats != null && player2Stats != null) {
        intelligence['data']['player1Stats'] = player1Stats;
        intelligence['data']['player2Stats'] = player2Stats;
        
        // Surface performance comparison
        final surface = _getCurrentSurface(matchId);
        if (surface != null) {
          intelligence['insights'].add({
            'type': 'surface',
            'text': _analyzeSurfacePerformance(player1Stats, player2Stats, surface),
            'impact': 'high',
          });
        }
        
        // Recent form analysis
        intelligence['insights'].add({
          'type': 'form',
          'text': _analyzeRecentForm(player1Stats, player2Stats),
          'impact': 'medium',
        });
      }
      
      // Head-to-head insights
      if (h2h != null) {
        intelligence['data']['headToHead'] = h2h;
        intelligence['insights'].add({
          'type': 'h2h',
          'text': _analyzeHeadToHead(h2h, player1Name, player2Name),
          'impact': 'high',
        });
      }
      
      // Ranking comparison
      intelligence['insights'].add({
        'type': 'ranking',
        'text': await _analyzeRankings(player1Name, player2Name),
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
  
  // Helper methods for analysis
  String? _getCurrentSurface(String matchId) {
    // In production, would fetch from match details
    // Common surfaces: hard, clay, grass, indoor
    return 'hard';
  }
  
  String _analyzeSurfacePerformance(
    Map<String, dynamic> p1Stats,
    Map<String, dynamic> p2Stats,
    String surface,
  ) {
    // Analyze win rates on specific surface
    final p1SurfaceWinRate = p1Stats['surfaces']?[surface]?['winRate'] ?? 0.5;
    final p2SurfaceWinRate = p2Stats['surfaces']?[surface]?['winRate'] ?? 0.5;
    
    if (p1SurfaceWinRate > p2SurfaceWinRate + 0.1) {
      return '${p1Stats['name']} has significant advantage on $surface (${(p1SurfaceWinRate * 100).toInt()}% win rate)';
    } else if (p2SurfaceWinRate > p1SurfaceWinRate + 0.1) {
      return '${p2Stats['name']} excels on $surface (${(p2SurfaceWinRate * 100).toInt()}% win rate)';
    }
    return 'Both players have similar performance on $surface courts';
  }
  
  String _analyzeRecentForm(
    Map<String, dynamic> p1Stats,
    Map<String, dynamic> p2Stats,
  ) {
    final p1Recent = p1Stats['recentMatches']?['wins'] ?? 0;
    final p2Recent = p2Stats['recentMatches']?['wins'] ?? 0;
    
    if (p1Recent > p2Recent) {
      return '${p1Stats['name']} in better form with $p1Recent wins in last 5 matches';
    } else if (p2Recent > p1Recent) {
      return '${p2Stats['name']} showing strong form with $p2Recent recent wins';
    }
    return 'Both players showing similar recent form';
  }
  
  String _analyzeHeadToHead(
    Map<String, dynamic> h2h,
    String player1,
    String player2,
  ) {
    final p1Wins = h2h['player1Wins'] ?? 0;
    final p2Wins = h2h['player2Wins'] ?? 0;
    
    if (p1Wins > p2Wins) {
      return '$player1 leads head-to-head $p1Wins-$p2Wins';
    } else if (p2Wins > p1Wins) {
      return '$player2 dominates rivalry $p2Wins-$p1Wins';
    }
    return 'Even head-to-head record at $p1Wins-$p2Wins';
  }
  
  Future<String> _analyzeRankings(String player1, String player2) async {
    // Would fetch actual rankings
    return 'Ranking analysis between $player1 and $player2';
  }
  
  // API fetch methods (would connect to real API)
  Future<List<Map<String, dynamic>>> _fetchATPRankings() async {
    // Mock data for development
    return [
      {'rank': 1, 'player': 'Novak Djokovic', 'points': 11055},
      {'rank': 2, 'player': 'Carlos Alcaraz', 'points': 8855},
      {'rank': 3, 'player': 'Daniil Medvedev', 'points': 7555},
    ];
  }
  
  Future<List<Map<String, dynamic>>> _fetchWTARankings() async {
    // Mock data for development
    return [
      {'rank': 1, 'player': 'Iga Swiatek', 'points': 10485},
      {'rank': 2, 'player': 'Aryna Sabalenka', 'points': 8905},
      {'rank': 3, 'player': 'Coco Gauff', 'points': 7200},
    ];
  }
  
  Future<Map<String, dynamic>> _fetchPlayerStats(String playerId) async {
    // Mock data for development
    return {
      'playerId': playerId,
      'name': playerId,
      'ranking': 5,
      'age': 28,
      'country': 'USA',
      'surfaces': {
        'hard': {'matches': 50, 'wins': 35, 'winRate': 0.70},
        'clay': {'matches': 30, 'wins': 18, 'winRate': 0.60},
        'grass': {'matches': 20, 'wins': 14, 'winRate': 0.70},
      },
      'recentMatches': {
        'played': 5,
        'wins': 3,
        'losses': 2,
      },
      'stats': {
        'aces': 245,
        'doubleFaults': 89,
        'firstServePercentage': 0.65,
        'breakPointsSaved': 0.72,
      },
    };
  }
  
  Future<Map<String, dynamic>> _fetchHeadToHead(String player1Id, String player2Id) async {
    // Mock data for development
    return {
      'player1': player1Id,
      'player2': player2Id,
      'totalMatches': 8,
      'player1Wins': 5,
      'player2Wins': 3,
      'lastMeeting': '2024-11-15',
      'surfaceBreakdown': {
        'hard': {'p1': 3, 'p2': 1},
        'clay': {'p1': 1, 'p2': 2},
        'grass': {'p1': 1, 'p2': 0},
      },
    };
  }
  
  Future<List<Map<String, dynamic>>> _fetchActiveTournaments() async {
    // Mock data for development
    return [
      {
        'id': 'us-open-2025',
        'name': 'US Open',
        'category': 'Grand Slam',
        'surface': 'hard',
        'location': 'New York, USA',
        'startDate': '2025-08-26',
        'endDate': '2025-09-08',
        'prizeMoney': 65000000,
      },
      {
        'id': 'cincinnati-2025',
        'name': 'Cincinnati Masters',
        'category': 'Masters 1000',
        'surface': 'hard',
        'location': 'Cincinnati, USA',
        'startDate': '2025-08-11',
        'endDate': '2025-08-18',
        'prizeMoney': 6280880,
      },
    ];
  }
  
  List<Map<String, dynamic>> _getMockMatches() {
    return [
      {
        'id': 'match_001',
        'tournament': 'US Open',
        'round': 'Quarter Final',
        'surface': 'hard',
        'player1': {
          'name': 'Carlos Alcaraz',
          'ranking': 2,
          'country': 'ESP',
          'seed': 2,
        },
        'player2': {
          'name': 'Daniil Medvedev',
          'ranking': 3,
          'country': 'RUS',
          'seed': 3,
        },
        'scheduledTime': DateTime.now().add(Duration(hours: 2)).toIso8601String(),
        'court': 'Arthur Ashe Stadium',
        'status': 'scheduled',
        'odds': {
          'player1': -140,
          'player2': +120,
        },
      },
      {
        'id': 'match_002',
        'tournament': 'US Open',
        'round': 'Quarter Final',
        'surface': 'hard',
        'player1': {
          'name': 'Iga Swiatek',
          'ranking': 1,
          'country': 'POL',
          'seed': 1,
        },
        'player2': {
          'name': 'Coco Gauff',
          'ranking': 6,
          'country': 'USA',
          'seed': 6,
        },
        'scheduledTime': DateTime.now().add(Duration(hours: 4)).toIso8601String(),
        'court': 'Arthur Ashe Stadium',
        'status': 'scheduled',
        'odds': {
          'player1': -180,
          'player2': +150,
        },
      },
    ];
  }
}

/// Tennis-specific data models
class TennisMatch {
  final String id;
  final String tournament;
  final String round;
  final String surface;
  final Map<String, dynamic> player1;
  final Map<String, dynamic> player2;
  final String status;
  final DateTime? scheduledTime;
  final Map<String, dynamic>? score;
  final Map<String, dynamic>? odds;
  
  TennisMatch({
    required this.id,
    required this.tournament,
    required this.round,
    required this.surface,
    required this.player1,
    required this.player2,
    required this.status,
    this.scheduledTime,
    this.score,
    this.odds,
  });
  
  factory TennisMatch.fromJson(Map<String, dynamic> json) {
    return TennisMatch(
      id: json['id'] ?? '',
      tournament: json['tournament'] ?? '',
      round: json['round'] ?? '',
      surface: json['surface'] ?? 'hard',
      player1: json['player1'] ?? {},
      player2: json['player2'] ?? {},
      status: json['status'] ?? 'scheduled',
      scheduledTime: json['scheduledTime'] != null 
        ? DateTime.parse(json['scheduledTime'])
        : null,
      score: json['score'],
      odds: json['odds'],
    );
  }
  
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'tournament': tournament,
      'round': round,
      'surface': surface,
      'player1': player1,
      'player2': player2,
      'status': status,
      'scheduledTime': scheduledTime?.toIso8601String(),
      'score': score,
      'odds': odds,
    };
  }
}

class TennisPlayer {
  final String id;
  final String name;
  final int ranking;
  final String country;
  final Map<String, dynamic> stats;
  final Map<String, dynamic> surfaceStats;
  
  TennisPlayer({
    required this.id,
    required this.name,
    required this.ranking,
    required this.country,
    required this.stats,
    required this.surfaceStats,
  });
  
  factory TennisPlayer.fromJson(Map<String, dynamic> json) {
    return TennisPlayer(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      ranking: json['ranking'] ?? 0,
      country: json['country'] ?? '',
      stats: json['stats'] ?? {},
      surfaceStats: json['surfaces'] ?? {},
    );
  }
}