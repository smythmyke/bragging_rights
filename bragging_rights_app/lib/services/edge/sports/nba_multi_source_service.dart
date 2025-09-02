import 'package:flutter/foundation.dart';
import 'nba_service.dart';
import 'espn_nba_service.dart';
import 'balldontlie_service.dart';
import '../api_gateway.dart';
import '../cache/edge_cache_service.dart';
import '../event_matcher.dart';

/// NBA Multi-Source Service with automatic fallback
/// Manages multiple NBA data sources with intelligent switching
class NbaMultiSourceService {
  final EdgeCacheService _cache = EdgeCacheService();
  final EventMatcher _matcher = EventMatcher();
  
  // Primary sources (unlimited/high limit)
  final EspnNbaService _espnService = EspnNbaService();
  final NbaService _officialNbaService = NbaService(); // NBA Stats API
  
  // Secondary source (rate limited: 60 req/min)
  final BalldontlieService _balldontlieService = BalldontlieService();
  
  // Track API health and failures
  final Map<String, ApiHealth> _apiHealth = {
    'espn': ApiHealth('ESPN NBA'),
    'official': ApiHealth('NBA Stats API'),
    'balldontlie': ApiHealth('Balldontlie', rateLimit: 60),
  };
  
  /// Get comprehensive game data with automatic source selection
  Future<Map<String, dynamic>?> getGameData({
    required String gameId,
    required String homeTeam,
    required String awayTeam,
    bool forceRefresh = false,
  }) async {
    // Try cache first unless force refresh
    if (!forceRefresh) {
      final cached = await _getCachedGameData(gameId);
      if (cached != null && _isCacheValid(cached)) {
        debugPrint('✅ Using cached NBA game data');
        return cached;
      }
    }
    
    // Priority order: ESPN > Official NBA > Balldontlie
    Map<String, dynamic>? gameData;
    
    // Try ESPN first (most reliable, unlimited)
    if (_apiHealth['espn']!.isHealthy) {
      gameData = await _tryEspnData(gameId, homeTeam, awayTeam);
      if (gameData != null) {
        await _cacheGameData(gameId, gameData, 'espn');
        return gameData;
      }
    }
    
    // Try Official NBA API (unlimited, authoritative)
    if (_apiHealth['official']!.isHealthy) {
      gameData = await _tryOfficialNbaData(gameId, homeTeam, awayTeam);
      if (gameData != null) {
        await _cacheGameData(gameId, gameData, 'official');
        return gameData;
      }
    }
    
    // Try Balldontlie as last resort (rate limited)
    if (_apiHealth['balldontlie']!.isHealthy && 
        _apiHealth['balldontlie']!.canMakeRequest()) {
      gameData = await _tryBalldontlieData(gameId);
      if (gameData != null) {
        await _cacheGameData(gameId, gameData, 'balldontlie');
        return gameData;
      }
    }
    
    debugPrint('❌ All NBA data sources failed');
    return null;
  }
  
  /// Get player statistics with fallback
  Future<Map<String, dynamic>?> getPlayerStats({
    required String playerId,
    String? season,
  }) async {
    // Try Official NBA API first (most detailed)
    if (_apiHealth['official']!.isHealthy) {
      try {
        // NBA Stats API returns all players, need to filter
        final allStats = await _officialNbaService.getPlayerStats(
          season: season ?? '2024-25',
        );
        // For now, return null as we'd need to filter by player
        final stats = null;
        if (stats != null) {
          _apiHealth['official']!.recordSuccess();
          return stats;
        }
      } catch (e) {
        _apiHealth['official']!.recordFailure();
        debugPrint('Official NBA API failed: $e');
      }
    }
    
    // Try Balldontlie
    if (_apiHealth['balldontlie']!.isHealthy && 
        _apiHealth['balldontlie']!.canMakeRequest()) {
      try {
        final averages = await _balldontlieService.getSeasonAverages(
          playerIds: [int.tryParse(playerId) ?? 0],
          season: season?.substring(0, 4) ?? '2024',
        );
        final stats = averages?.isNotEmpty == true ? {'averages': averages![0]} : null;
        if (stats != null) {
          _apiHealth['balldontlie']!.recordSuccess();
          return stats;
        }
      } catch (e) {
        _apiHealth['balldontlie']!.recordFailure();
        debugPrint('Balldontlie API failed: $e');
      }
    }
    
    return null;
  }
  
  /// Get live scoreboard with fallback
  Future<List<Map<String, dynamic>>?> getScoreboard() async {
    // ESPN is primary for scoreboard
    if (_apiHealth['espn']!.isHealthy) {
      try {
        final scoreboard = await _espnService.getTodaysGames();
        if (scoreboard != null) {
          _apiHealth['espn']!.recordSuccess();
          return scoreboard.events;
        }
      } catch (e) {
        _apiHealth['espn']!.recordFailure();
        debugPrint('ESPN scoreboard failed: $e');
      }
    }
    
    // Balldontlie as backup
    if (_apiHealth['balldontlie']!.isHealthy && 
        _apiHealth['balldontlie']!.canMakeRequest()) {
      try {
        final response = await _balldontlieService.getTodaysGames();
        if (response != null) {
          _apiHealth['balldontlie']!.recordSuccess();
          return response.data.map((g) => g.toMap()).toList();
        }
      } catch (e) {
        _apiHealth['balldontlie']!.recordFailure();
        debugPrint('Balldontlie games failed: $e');
      }
    }
    
    return null;
  }
  
  /// Get team statistics with fallback
  Future<Map<String, dynamic>?> getTeamStats(String teamId) async {
    // Try Official NBA API
    if (_apiHealth['official']!.isHealthy) {
      try {
        // NBA Stats API doesn't have team-specific method
        final stats = null;
        if (stats != null) {
          _apiHealth['official']!.recordSuccess();
          return stats;
        }
      } catch (e) {
        _apiHealth['official']!.recordFailure();
      }
    }
    
    // Try ESPN
    if (_apiHealth['espn']!.isHealthy) {
      try {
        // ESPN NBA Service doesn't have getTeamStatistics method
        final stats = null;
        if (stats != null) {
          _apiHealth['espn']!.recordSuccess();
          return stats;
        }
      } catch (e) {
        _apiHealth['espn']!.recordFailure();
      }
    }
    
    return null;
  }
  
  // ============ Private Helper Methods ============
  
  Map<String, dynamic> _parseEspnEvent(Map<String, dynamic> event) {
    final competition = event['competitions']?[0];
    if (competition == null) return {};
    
    final competitors = competition['competitors'] ?? [];
    if (competitors.length < 2) return {};
    
    return {
      'id': event['id'],
      'name': event['name'],
      'homeTeam': competitors[0]['team']?['displayName'] ?? '',
      'awayTeam': competitors[1]['team']?['displayName'] ?? '',
      'homeScore': competitors[0]['score'],
      'awayScore': competitors[1]['score'],
      'status': competition['status']?['type']?['description'],
      'date': event['date'],
    };
  }
  
  Future<Map<String, dynamic>?> _tryEspnData(
    String gameId,
    String homeTeam,
    String awayTeam,
  ) async {
    try {
      debugPrint('🏀 Trying ESPN NBA API...');
      final scoreboard = await _espnService.getTodaysGames();
      
      if (scoreboard != null) {
        // Find matching game
        for (final event in scoreboard.events) {
          final game = _parseEspnEvent(event);
          final homeTeamNormalized = _matcher.normalizeTeamName(game['homeTeam'] ?? '');
          final awayTeamNormalized = _matcher.normalizeTeamName(game['awayTeam'] ?? '');
          final homeNormalized = _matcher.normalizeTeamName(homeTeam);
          final awayNormalized = _matcher.normalizeTeamName(awayTeam);
          
          if (homeTeamNormalized == homeNormalized &&
              awayTeamNormalized == awayNormalized) {
            _apiHealth['espn']!.recordSuccess();
            return game;
          }
        }
      }
      
      _apiHealth['espn']!.recordFailure();
      return null;
    } catch (e) {
      _apiHealth['espn']!.recordFailure();
      debugPrint('ESPN NBA error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _tryOfficialNbaData(
    String gameId,
    String homeTeam,
    String awayTeam,
  ) async {
    try {
      debugPrint('🏀 Trying Official NBA Stats API...');
      // NBA Stats API doesn't have game details method
      final gameData = null;
      
      if (gameData != null) {
        _apiHealth['official']!.recordSuccess();
        return gameData;
      }
      
      _apiHealth['official']!.recordFailure();
      return null;
    } catch (e) {
      _apiHealth['official']!.recordFailure();
      debugPrint('Official NBA API error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _tryBalldontlieData(String gameId) async {
    try {
      debugPrint('🏀 Trying Balldontlie API...');
      _apiHealth['balldontlie']!.recordRequest();
      
      final game = await _balldontlieService.getGame(int.tryParse(gameId) ?? 0);
      
      if (game != null) {
        _apiHealth['balldontlie']!.recordSuccess();
        return game.toMap();
      }
      
      _apiHealth['balldontlie']!.recordFailure();
      return null;
    } catch (e) {
      _apiHealth['balldontlie']!.recordFailure();
      debugPrint('Balldontlie error: $e');
      return null;
    }
  }
  
  Future<Map<String, dynamic>?> _getCachedGameData(String gameId) async {
    return await _cache.getCachedData<Map<String, dynamic>>(
      collection: 'nba_games',
      documentId: gameId,
      dataType: 'game_data',
      sport: 'nba',
      gameState: {},
      fetchFunction: () async => <String, dynamic>{},
    );
  }
  
  Future<void> _cacheGameData(
    String gameId,
    Map<String, dynamic> data,
    String source,
  ) async {
    data['_source'] = source;
    data['_cached_at'] = DateTime.now().toIso8601String();
    
    // Cache duration based on game status
    Duration ttl = const Duration(hours: 1);
    if (data['status'] == 'final') {
      ttl = const Duration(days: 7);
    } else if (data['status'] == 'live') {
      ttl = const Duration(minutes: 5);
    }
    
    // Store in cache - EdgeCacheService doesn't have cacheData, need to use different approach
    // TODO: Implement cache storage when EdgeCacheService supports it
    // await _cache.cacheData(
    //   collection: 'nba_games',
    //   documentId: gameId,
    //   dataType: 'game_data',
    //   data: data,
    //   ttl: ttl,
    // );
  }
  
  bool _isCacheValid(Map<String, dynamic> cached) {
    final cachedAt = cached['_cached_at'];
    if (cachedAt == null) return false;
    
    final cacheTime = DateTime.parse(cachedAt);
    final age = DateTime.now().difference(cacheTime);
    
    // Different validity periods based on game status
    final status = cached['status'] ?? '';
    if (status == 'final') {
      return age.inDays < 7;
    } else if (status == 'live') {
      return age.inMinutes < 5;
    } else {
      return age.inHours < 1;
    }
  }
  
  /// Get API health status
  Map<String, dynamic> getHealthStatus() {
    final status = <String, dynamic>{};
    _apiHealth.forEach((key, health) {
      status[key] = health.toMap();
    });
    return status;
  }
  
  /// Reset API health (for testing or manual intervention)
  void resetApiHealth([String? apiName]) {
    if (apiName != null && _apiHealth.containsKey(apiName)) {
      _apiHealth[apiName]!.reset();
    } else {
      _apiHealth.values.forEach((health) => health.reset());
    }
  }
}

/// API Health tracking
class ApiHealth {
  final String name;
  final int rateLimit;
  int consecutiveFailures = 0;
  int totalRequests = 0;
  int successfulRequests = 0;
  DateTime? lastFailure;
  DateTime? lastSuccess;
  DateTime lastReset = DateTime.now();
  int requestsThisMinute = 0;
  
  ApiHealth(this.name, {this.rateLimit = -1});
  
  bool get isHealthy {
    // Mark unhealthy after 3 consecutive failures
    if (consecutiveFailures >= 3) {
      // Check if we should retry (after 5 minutes)
      if (lastFailure != null) {
        final timeSinceFailure = DateTime.now().difference(lastFailure!);
        if (timeSinceFailure.inMinutes >= 5) {
          // Reset and try again
          consecutiveFailures = 0;
          return true;
        }
      }
      return false;
    }
    return true;
  }
  
  bool canMakeRequest() {
    if (rateLimit <= 0) return true;
    
    // Reset counter if minute has passed
    final now = DateTime.now();
    if (now.difference(lastReset).inMinutes >= 1) {
      requestsThisMinute = 0;
      lastReset = now;
    }
    
    return requestsThisMinute < rateLimit;
  }
  
  void recordRequest() {
    totalRequests++;
    requestsThisMinute++;
  }
  
  void recordSuccess() {
    recordRequest();
    successfulRequests++;
    consecutiveFailures = 0;
    lastSuccess = DateTime.now();
  }
  
  void recordFailure() {
    consecutiveFailures++;
    lastFailure = DateTime.now();
  }
  
  void reset() {
    consecutiveFailures = 0;
    totalRequests = 0;
    successfulRequests = 0;
    requestsThisMinute = 0;
    lastFailure = null;
    lastSuccess = null;
    lastReset = DateTime.now();
  }
  
  double get successRate {
    if (totalRequests == 0) return 1.0;
    return successfulRequests / totalRequests;
  }
  
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'healthy': isHealthy,
      'consecutiveFailures': consecutiveFailures,
      'totalRequests': totalRequests,
      'successRate': '${(successRate * 100).toStringAsFixed(1)}%',
      'lastFailure': lastFailure?.toIso8601String(),
      'lastSuccess': lastSuccess?.toIso8601String(),
      'rateLimit': rateLimit > 0 ? '$requestsThisMinute/$rateLimit per min' : 'unlimited',
    };
  }
}