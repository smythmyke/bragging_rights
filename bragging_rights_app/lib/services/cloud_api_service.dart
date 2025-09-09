import 'package:cloud_functions/cloud_functions.dart';

/// Service for calling Cloud Function API proxies
/// This replaces direct API calls with secure server-side proxies
class CloudApiService {
  static final CloudApiService _instance = CloudApiService._internal();
  factory CloudApiService() => _instance;
  CloudApiService._internal();

  final FirebaseFunctions _functions = FirebaseFunctions.instance;

  // ============================================
  // NBA API CALLS
  // ============================================

  /// Get NBA games from Balldontlie API
  Future<Map<String, dynamic>> getNBAGames({
    int? season,
    int page = 1,
    int perPage = 25,
  }) async {
    try {
      final callable = _functions.httpsCallable('getNBAGames');
      final result = await callable.call({
        'season': season ?? DateTime.now().year,
        'page': page,
        'perPage': perPage,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error calling getNBAGames: $e');
      throw e;
    }
  }

  /// Get NBA player statistics
  Future<Map<String, dynamic>> getNBAStats({
    required int playerId,
    int? season,
  }) async {
    try {
      final callable = _functions.httpsCallable('getNBAStats');
      final result = await callable.call({
        'playerId': playerId,
        'season': season ?? DateTime.now().year,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error calling getNBAStats: $e');
      throw e;
    }
  }

  // ============================================
  // ODDS API CALLS
  // ============================================

  /// Get betting odds for a specific sport
  Future<Map<String, dynamic>> getOdds({
    required String sport,
    String markets = 'h2h',
    String bookmakers = 'draftkings',
  }) async {
    try {
      final callable = _functions.httpsCallable('getOdds');
      final result = await callable.call({
        'sport': sport,
        'markets': markets,
        'bookmakers': bookmakers,
      });
      
      // Handle both List and Map return types
      final data = result.data;
      if (data is List) {
        // If API returns a List (e.g., for NFL), wrap it in a Map
        return {'events': data};
      } else if (data is Map<String, dynamic>) {
        return data;
      } else {
        print('Unexpected odds data type: ${data.runtimeType}');
        return {};
      }
    } catch (e) {
      print('Error calling getOdds: $e');
      throw e;
    }
  }

  /// Get list of sports currently in season
  Future<List<dynamic>> getSportsInSeason() async {
    try {
      final callable = _functions.httpsCallable('getSportsInSeason');
      final result = await callable.call();
      return result.data as List<dynamic>;
    } catch (e) {
      print('Error calling getSportsInSeason: $e');
      throw e;
    }
  }

  // ============================================
  // NEWS API CALLS
  // ============================================

  /// Get sports news articles
  Future<Map<String, dynamic>> getSportsNews({
    String? query,
    required String sport,
  }) async {
    try {
      final callable = _functions.httpsCallable('getSportsNews');
      final result = await callable.call({
        'query': query,
        'sport': sport,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error calling getSportsNews: $e');
      throw e;
    }
  }

  // ============================================
  // ESPN API CALLS (No auth required)
  // ============================================

  /// Get ESPN scoreboard for a sport
  Future<Map<String, dynamic>> getESPNScoreboard({
    required String sport,
  }) async {
    try {
      final callable = _functions.httpsCallable('getESPNScoreboard');
      final result = await callable.call({
        'sport': sport,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error calling getESPNScoreboard: $e');
      throw e;
    }
  }

  // ============================================
  // NHL API CALLS (No auth required)
  // ============================================

  /// Get NHL schedule
  Future<Map<String, dynamic>> getNHLSchedule({
    String? date,
  }) async {
    try {
      final callable = _functions.httpsCallable('getNHLSchedule');
      final result = await callable.call({
        if (date != null) 'date': date,
      });
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error calling getNHLSchedule: $e');
      throw e;
    }
  }

  // ============================================
  // TENNIS API CALLS (Future)
  // ============================================

  /// Get tennis matches (placeholder for future implementation)
  Future<Map<String, dynamic>> getTennisMatches() async {
    try {
      final callable = _functions.httpsCallable('getTennisMatches');
      final result = await callable.call();
      return result.data as Map<String, dynamic>;
    } catch (e) {
      print('Error calling getTennisMatches: $e');
      throw e;
    }
  }

  // ============================================
  // UTILITY METHODS
  // ============================================

  /// Convert sport name to API format
  String getSportApiKey(String sport) {
    final sportMappings = {
      'NBA': 'basketball_nba',
      'NFL': 'americanfootball_nfl',
      'NHL': 'icehockey_nhl',
      'MLB': 'baseball_mlb',
      'MMA': 'mma_mixed_martial_arts',
      'Boxing': 'boxing_boxing',
      'Tennis': 'tennis_atp_french_open',
      'Soccer': 'soccer_usa_mls',
    };
    return sportMappings[sport] ?? sport.toLowerCase();
  }
}