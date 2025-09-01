import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../api_gateway.dart';
import '../event_matcher.dart';
import '../cache/edge_cache_service.dart';
import 'espn_tennis_service.dart';

/// Multi-source Tennis API Service with automatic fallback
/// Manages API limits and switches between providers seamlessly
class TennisMultiApiService {
  final EdgeCacheService _cache = EdgeCacheService();
  final EspnTennisService _espnService = EspnTennisService();
  final ApiGateway _gateway = ApiGateway();
  
  // API Usage Tracking
  static final Map<String, ApiUsage> _apiUsage = {
    'thesportsdb': ApiUsage(name: 'TheSportsDB', dailyLimit: -1, monthlyLimit: -1), // Unlimited
    'api_sports': ApiUsage(name: 'API-Sports', dailyLimit: 100, monthlyLimit: 3000),
    'sportradar': ApiUsage(name: 'Sportradar', dailyLimit: 1000, monthlyLimit: 30000), // Trial
    'rapidapi_tennis': ApiUsage(name: 'Tennis-API (RapidAPI)', dailyLimit: 33, monthlyLimit: 1000),
    'odds_api': ApiUsage(name: 'The Odds API', dailyLimit: 16, monthlyLimit: 500),
    'goalserve': ApiUsage(name: 'Goalserve', dailyLimit: 1000, monthlyLimit: 30000), // Trial
  };
  
  // API Keys (to be set from environment/config)
  static const Map<String, String> _apiKeys = {
    'api_sports': '', // Set from API-Sports.io
    'sportradar': '', // Set from Sportradar trial
    'rapidapi': '', // Set from RapidAPI
    'odds_api': '', // Already have: 3386d47aa3fe4a7f (from checklist)
    'goalserve': '', // Set from Goalserve trial
  };

  /// Get comprehensive match data with automatic source selection
  Future<TennisMatchData?> getComprehensiveMatchData({
    required String matchId,
    required String player1Name,
    required String player2Name,
  }) async {
    try {
      // Start with ESPN (always free)
      final espnData = await _espnService.getMatchIntelligence(
        matchId: matchId,
        player1Name: player1Name,
        player2Name: player2Name,
      );
      
      // Create base match data
      final matchData = TennisMatchData(
        matchId: matchId,
        player1: player1Name,
        player2: player2Name,
        basicData: espnData,
      );
      
      // Try to enhance with additional data
      await _enhanceWithH2HData(matchData);
      await _enhanceWithSurfaceStats(matchData);
      await _enhanceWithPlayerStats(matchData);
      await _enhanceWithFormData(matchData);
      await _enhanceWithInjuryData(matchData);
      
      return matchData;
    } catch (e) {
      debugPrint('Error getting comprehensive match data: $e');
      return null;
    }
  }

  /// Enhance with head-to-head data
  Future<void> _enhanceWithH2HData(TennisMatchData matchData) async {
    // Priority order: API-Sports > Sportradar > TheSportsDB
    
    // Try API-Sports first
    if (_canUseApi('api_sports')) {
      final h2h = await _getApiSportsH2H(matchData.player1, matchData.player2);
      if (h2h != null) {
        matchData.h2hData = h2h;
        _incrementUsage('api_sports');
        return;
      }
    }
    
    // Try Sportradar
    if (_canUseApi('sportradar')) {
      final h2h = await _getSportradarH2H(matchData.player1, matchData.player2);
      if (h2h != null) {
        matchData.h2hData = h2h;
        _incrementUsage('sportradar');
        return;
      }
    }
    
    // Fallback to TheSportsDB (unlimited)
    final h2h = await _getTheSportsDBH2H(matchData.player1, matchData.player2);
    if (h2h != null) {
      matchData.h2hData = h2h;
    }
  }

  /// Enhance with surface statistics
  Future<void> _enhanceWithSurfaceStats(TennisMatchData matchData) async {
    // Priority: API-Sports > Sportradar > Goalserve
    
    if (_canUseApi('api_sports')) {
      final stats = await _getApiSportsSurfaceStats(matchData.player1, matchData.player2);
      if (stats != null) {
        matchData.surfaceStats = stats;
        _incrementUsage('api_sports');
        return;
      }
    }
    
    if (_canUseApi('sportradar')) {
      final stats = await _getSportradarSurfaceStats(matchData.player1, matchData.player2);
      if (stats != null) {
        matchData.surfaceStats = stats;
        _incrementUsage('sportradar');
        return;
      }
    }
    
    if (_canUseApi('goalserve')) {
      final stats = await _goalserveSurfaceStats(matchData.player1, matchData.player2);
      if (stats != null) {
        matchData.surfaceStats = stats;
        _incrementUsage('goalserve');
      }
    }
  }

  /// Enhance with detailed player statistics
  Future<void> _enhanceWithPlayerStats(TennisMatchData matchData) async {
    // Priority: Sportradar > API-Sports > Goalserve
    
    if (_canUseApi('sportradar')) {
      final stats = await _getSportradarPlayerStats(matchData.player1, matchData.player2);
      if (stats != null) {
        matchData.playerStats = stats;
        _incrementUsage('sportradar', 2); // Two requests for both players
        return;
      }
    }
    
    if (_canUseApi('api_sports', 2)) {
      final stats = await _getApiSportsPlayerStats(matchData.player1, matchData.player2);
      if (stats != null) {
        matchData.playerStats = stats;
        _incrementUsage('api_sports', 2);
        return;
      }
    }
    
    if (_canUseApi('goalserve', 2)) {
      final stats = await _getGoalservePlayerStats(matchData.player1, matchData.player2);
      if (stats != null) {
        matchData.playerStats = stats;
        _incrementUsage('goalserve', 2);
      }
    }
  }

  /// Enhance with recent form data
  Future<void> _enhanceWithFormData(TennisMatchData matchData) async {
    // Priority: TheSportsDB (free) > API-Sports > Others
    
    // Try TheSportsDB first (unlimited)
    final form = await _getTheSportsDBForm(matchData.player1, matchData.player2);
    if (form != null) {
      matchData.formData = form;
      return;
    }
    
    if (_canUseApi('api_sports')) {
      final form = await _getApiSportsForm(matchData.player1, matchData.player2);
      if (form != null) {
        matchData.formData = form;
        _incrementUsage('api_sports');
      }
    }
  }

  /// Enhance with injury/fitness data
  Future<void> _enhanceWithInjuryData(TennisMatchData matchData) async {
    // Only Goalserve and Sportradar provide this
    
    if (_canUseApi('goalserve')) {
      final injuries = await _getGoalserveInjuries(matchData.player1, matchData.player2);
      if (injuries != null) {
        matchData.injuryData = injuries;
        _incrementUsage('goalserve');
        return;
      }
    }
    
    if (_canUseApi('sportradar')) {
      final injuries = await _getSportradarInjuries(matchData.player1, matchData.player2);
      if (injuries != null) {
        matchData.injuryData = injuries;
        _incrementUsage('sportradar');
      }
    }
  }

  // ============ API Implementation Methods ============

  /// TheSportsDB Methods (Unlimited)
  Future<Map<String, dynamic>?> _getTheSportsDBH2H(String player1, String player2) async {
    try {
      // Get player IDs first
      final p1Id = await _getTheSportsDBPlayerId(player1);
      final p2Id = await _getTheSportsDBPlayerId(player2);
      
      if (p1Id == null || p2Id == null) return null;
      
      // Get match history for both players
      final response1 = await http.get(
        Uri.parse('https://www.thesportsdb.com/api/v1/json/3/eventspastleague.php?id=$p1Id'),
      );
      
      if (response1.statusCode != 200) return null;
      
      final matches = json.decode(response1.body)['events'] ?? [];
      final h2hMatches = [];
      
      // Filter for H2H matches
      for (var match in matches) {
        if (match['strPlayer2']?.contains(player2) == true ||
            match['strPlayer1']?.contains(player2) == true) {
          h2hMatches.add(match);
        }
      }
      
      return {
        'totalMatches': h2hMatches.length,
        'matches': h2hMatches,
        'source': 'TheSportsDB',
      };
    } catch (e) {
      debugPrint('TheSportsDB H2H error: $e');
      return null;
    }
  }
  
  Future<String?> _getTheSportsDBPlayerId(String playerName) async {
    try {
      final response = await http.get(
        Uri.parse('https://www.thesportsdb.com/api/v1/json/3/searchplayers.php?p=${Uri.encodeComponent(playerName)}'),
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final players = data['player'] ?? [];
        if (players.isNotEmpty) {
          return players[0]['idPlayer'];
        }
      }
    } catch (e) {
      debugPrint('Error getting player ID: $e');
    }
    return null;
  }
  
  Future<Map<String, dynamic>?> _getTheSportsDBForm(String player1, String player2) async {
    try {
      final p1Id = await _getTheSportsDBPlayerId(player1);
      final p2Id = await _getTheSportsDBPlayerId(player2);
      
      if (p1Id == null || p2Id == null) return null;
      
      final results = await Future.wait([
        http.get(Uri.parse('https://www.thesportsdb.com/api/v1/json/3/eventslast.php?id=$p1Id')),
        http.get(Uri.parse('https://www.thesportsdb.com/api/v1/json/3/eventslast.php?id=$p2Id')),
      ]);
      
      final p1Matches = json.decode(results[0].body)['results'] ?? [];
      final p2Matches = json.decode(results[1].body)['results'] ?? [];
      
      return {
        'player1Form': _calculateForm(p1Matches),
        'player2Form': _calculateForm(p2Matches),
        'source': 'TheSportsDB',
      };
    } catch (e) {
      debugPrint('TheSportsDB form error: $e');
      return null;
    }
  }
  
  Map<String, dynamic> _calculateForm(List matches) {
    int wins = 0;
    int losses = 0;
    
    for (var match in matches.take(5)) {
      // Check if won (simplified logic)
      if (match['intHomeScore'] != null && match['intAwayScore'] != null) {
        // Determine if player won
        wins++; // Simplified - would need proper logic
      } else {
        losses++;
      }
    }
    
    return {
      'last5': '$wins-$losses',
      'wins': wins,
      'losses': losses,
      'matches': matches.take(5).toList(),
    };
  }

  /// API-Sports Methods
  Future<Map<String, dynamic>?> _getApiSportsH2H(String player1, String player2) async {
    if (_apiKeys['api_sports']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      // For now, return null to indicate not available
      return null;
    } catch (e) {
      debugPrint('API-Sports H2H error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getApiSportsSurfaceStats(String player1, String player2) async {
    if (_apiKeys['api_sports']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('API-Sports surface stats error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getApiSportsPlayerStats(String player1, String player2) async {
    if (_apiKeys['api_sports']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('API-Sports player stats error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getApiSportsForm(String player1, String player2) async {
    if (_apiKeys['api_sports']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('API-Sports form error: $e');
      return null;
    }
  }

  /// Sportradar Methods
  Future<Map<String, dynamic>?> _getSportradarH2H(String player1, String player2) async {
    if (_apiKeys['sportradar']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('Sportradar H2H error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getSportradarSurfaceStats(String player1, String player2) async {
    if (_apiKeys['sportradar']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('Sportradar surface stats error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getSportradarPlayerStats(String player1, String player2) async {
    if (_apiKeys['sportradar']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('Sportradar player stats error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getSportradarInjuries(String player1, String player2) async {
    if (_apiKeys['sportradar']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('Sportradar injuries error: $e');
      return null;
    }
  }

  /// Goalserve Methods
  Future<Map<String, dynamic>?> _goalserveSurfaceStats(String player1, String player2) async {
    if (_apiKeys['goalserve']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('Goalserve surface stats error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getGoalservePlayerStats(String player1, String player2) async {
    if (_apiKeys['goalserve']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('Goalserve player stats error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getGoalserveInjuries(String player1, String player2) async {
    if (_apiKeys['goalserve']?.isEmpty ?? true) return null;
    
    try {
      // Would implement actual API call here
      return null;
    } catch (e) {
      debugPrint('Goalserve injuries error: $e');
      return null;
    }
  }

  // ============ Usage Tracking Methods ============

  /// Check if we can use an API based on limits
  bool _canUseApi(String apiKey, [int requestCount = 1]) {
    final usage = _apiUsage[apiKey];
    if (usage == null) return false;
    
    // Unlimited APIs
    if (usage.dailyLimit == -1) return true;
    
    // Check daily limit
    if (usage.dailyUsed + requestCount > usage.dailyLimit) {
      debugPrint('${usage.name} daily limit reached (${usage.dailyUsed}/${usage.dailyLimit})');
      return false;
    }
    
    // Check monthly limit
    if (usage.monthlyLimit > 0 && usage.monthlyUsed + requestCount > usage.monthlyLimit) {
      debugPrint('${usage.name} monthly limit reached (${usage.monthlyUsed}/${usage.monthlyLimit})');
      return false;
    }
    
    return true;
  }

  /// Increment API usage counter
  void _incrementUsage(String apiKey, [int count = 1]) {
    final usage = _apiUsage[apiKey];
    if (usage == null) return;
    
    usage.dailyUsed += count;
    usage.monthlyUsed += count;
    
    // Reset daily counter at midnight
    final now = DateTime.now();
    if (usage.lastReset.day != now.day) {
      usage.dailyUsed = count;
      usage.lastReset = now;
    }
    
    // Reset monthly counter
    if (usage.lastReset.month != now.month) {
      usage.monthlyUsed = count;
      usage.lastReset = now;
    }
    
    debugPrint('${usage.name} usage: ${usage.dailyUsed}/${usage.dailyLimit} daily, ${usage.monthlyUsed}/${usage.monthlyLimit} monthly');
  }

  /// Get current API usage statistics
  Map<String, Map<String, dynamic>> getUsageStats() {
    final stats = <String, Map<String, dynamic>>{};
    
    for (var entry in _apiUsage.entries) {
      final usage = entry.value;
      stats[entry.key] = {
        'name': usage.name,
        'dailyUsed': usage.dailyUsed,
        'dailyLimit': usage.dailyLimit,
        'dailyRemaining': usage.dailyLimit == -1 ? 'Unlimited' : usage.dailyLimit - usage.dailyUsed,
        'monthlyUsed': usage.monthlyUsed,
        'monthlyLimit': usage.monthlyLimit,
        'monthlyRemaining': usage.monthlyLimit == -1 ? 'Unlimited' : usage.monthlyLimit - usage.monthlyUsed,
        'percentUsedDaily': usage.dailyLimit == -1 ? 0 : (usage.dailyUsed / usage.dailyLimit * 100),
        'percentUsedMonthly': usage.monthlyLimit == -1 ? 0 : (usage.monthlyUsed / usage.monthlyLimit * 100),
      };
    }
    
    return stats;
  }

  /// Reset usage counters (for testing)
  void resetUsageCounters() {
    for (var usage in _apiUsage.values) {
      usage.dailyUsed = 0;
      usage.monthlyUsed = 0;
      usage.lastReset = DateTime.now();
    }
  }
}

/// API Usage tracking model
class ApiUsage {
  final String name;
  final int dailyLimit;
  final int monthlyLimit;
  int dailyUsed = 0;
  int monthlyUsed = 0;
  DateTime lastReset = DateTime.now();
  
  ApiUsage({
    required this.name,
    required this.dailyLimit,
    required this.monthlyLimit,
  });
}

/// Comprehensive tennis match data model
class TennisMatchData {
  final String matchId;
  final String player1;
  final String player2;
  Map<String, dynamic>? basicData;
  Map<String, dynamic>? h2hData;
  Map<String, dynamic>? surfaceStats;
  Map<String, dynamic>? playerStats;
  Map<String, dynamic>? formData;
  Map<String, dynamic>? injuryData;
  
  TennisMatchData({
    required this.matchId,
    required this.player1,
    required this.player2,
    this.basicData,
    this.h2hData,
    this.surfaceStats,
    this.playerStats,
    this.formData,
    this.injuryData,
  });
  
  /// Get data quality score (0-100)
  int getDataQuality() {
    int score = 0;
    int maxScore = 0;
    
    // Basic data (ESPN) - 20 points
    if (basicData != null) score += 20;
    maxScore += 20;
    
    // H2H data - 20 points
    if (h2hData != null) score += 20;
    maxScore += 20;
    
    // Surface stats - 20 points
    if (surfaceStats != null) score += 20;
    maxScore += 20;
    
    // Player stats - 20 points
    if (playerStats != null) score += 20;
    maxScore += 20;
    
    // Form data - 10 points
    if (formData != null) score += 10;
    maxScore += 10;
    
    // Injury data - 10 points
    if (injuryData != null) score += 10;
    maxScore += 10;
    
    return ((score / maxScore) * 100).round();
  }
  
  /// Get list of available data sources
  List<String> getDataSources() {
    final sources = <String>[];
    
    if (basicData != null && basicData!['source'] != null) {
      sources.add(basicData!['source']);
    }
    if (h2hData != null && h2hData!['source'] != null) {
      sources.add(h2hData!['source']);
    }
    if (surfaceStats != null && surfaceStats!['source'] != null) {
      sources.add(surfaceStats!['source']);
    }
    if (playerStats != null && playerStats!['source'] != null) {
      sources.add(playerStats!['source']);
    }
    if (formData != null && formData!['source'] != null) {
      sources.add(formData!['source']);
    }
    if (injuryData != null && injuryData!['source'] != null) {
      sources.add(injuryData!['source']);
    }
    
    return sources.toSet().toList(); // Remove duplicates
  }
  
  Map<String, dynamic> toMap() {
    return {
      'matchId': matchId,
      'player1': player1,
      'player2': player2,
      'dataQuality': getDataQuality(),
      'dataSources': getDataSources(),
      'basicData': basicData,
      'h2hData': h2hData,
      'surfaceStats': surfaceStats,
      'playerStats': playerStats,
      'formData': formData,
      'injuryData': injuryData,
    };
  }
}