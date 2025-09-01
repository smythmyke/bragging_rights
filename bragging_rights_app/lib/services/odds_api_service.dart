import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'odds_quota_manager.dart';

/// The Odds API Service
/// Provides betting odds for all supported sports
/// API Key: 3386d47aa3fe4a7f (500 requests/month)
/// Now integrated with quota management system
class OddsApiService {
  static const String _baseUrl = 'https://api.the-odds-api.com/v4';
  static const String _apiKey = '3386d47aa3fe4a7f';
  
  // Quota manager instance
  final OddsQuotaManager _quotaManager = OddsQuotaManager();
  
  // Singleton instance
  static final OddsApiService _instance = OddsApiService._internal();
  factory OddsApiService() => _instance;
  OddsApiService._internal() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    await _quotaManager.initialize();
  }
  
  // Sport keys mapping
  static const Map<String, String> _sportKeys = {
    'nba': 'basketball_nba',
    'nfl': 'americanfootball_nfl',
    'nhl': 'icehockey_nhl',
    'mlb': 'baseball_mlb',
    'mma': 'mma_mixed_martial_arts',
    'boxing': 'boxing_boxing',
    'tennis': 'tennis_atp_french_open', // Default to major tournament
    'soccer': 'soccer_epl', // Premier League as default
    'golf': 'golf_pga_championship',
    'ncaab': 'basketball_ncaab',
    'ncaaf': 'americanfootball_ncaaf',
  };
  
  // Tennis tournament keys
  static const Map<String, String> _tennisTournaments = {
    'australian_open': 'tennis_atp_aus_open',
    'french_open': 'tennis_atp_french_open',
    'wimbledon': 'tennis_atp_wimbledon',
    'us_open': 'tennis_atp_us_open',
    'atp': 'tennis_atp',
    'wta': 'tennis_wta',
  };

  /// Get available sports
  Future<List<Map<String, dynamic>>?> getAvailableSports() async {
    try {
      // This is a general request, not sport-specific
      if (!_quotaManager.canMakeRequest('general')) {
        debugPrint('⚠️ The Odds API quota exceeded');
        return null;
      }
      
      final url = '$_baseUrl/sports/?apiKey=$_apiKey';
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        await _quotaManager.recordUsage('general');
        final data = json.decode(response.body) as List;
        debugPrint('✅ Found ${data.length} available sports');
        return data.cast<Map<String, dynamic>>();
      }
      
      debugPrint('❌ Failed to get sports: ${response.statusCode}');
      return null;
    } catch (e) {
      debugPrint('Error fetching available sports: $e');
      return null;
    }
  }

  /// Get odds for a specific sport
  Future<List<Map<String, dynamic>>?> getSportOdds({
    required String sport,
    String? tournament,
    String regions = 'us',
    String markets = 'h2h,spreads,totals',
    String oddsFormat = 'american',
  }) async {
    return await _quotaManager.executeWithQuota<List<Map<String, dynamic>>>(
      sport: sport,
      apiCall: () async {
        // Get sport key
        String sportKey = _sportKeys[sport.toLowerCase()] ?? sport;
        
        // Special handling for tennis tournaments
        if (sport.toLowerCase() == 'tennis' && tournament != null) {
          sportKey = _tennisTournaments[tournament.toLowerCase()] ?? sportKey;
        }
        
        final url = '$_baseUrl/sports/$sportKey/odds/?'
            'apiKey=$_apiKey'
            '&regions=$regions'
            '&markets=$markets'
            '&oddsFormat=$oddsFormat';
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          debugPrint('✅ Found ${data.length} events with odds for $sport');
          return data.cast<Map<String, dynamic>>();
        }
        
        debugPrint('❌ Failed to get odds: ${response.statusCode}');
        return null;
      },
      getCached: null, // Could add caching here
    );
  }

  /// Get tennis match odds
  Future<Map<String, dynamic>?> getTennisOdds({
    required String player1,
    required String player2,
    String? tournament,
  }) async {
    try {
      // Get all tennis events
      final events = await getSportOdds(
        sport: 'tennis',
        tournament: tournament,
        markets: 'h2h,spreads,totals',
      );
      
      if (events == null || events.isEmpty) {
        debugPrint('No tennis events found');
        return null;
      }
      
      // Find matching event
      for (final event in events) {
        final homeTeam = event['home_team']?.toString().toLowerCase() ?? '';
        final awayTeam = event['away_team']?.toString().toLowerCase() ?? '';
        
        final p1Lower = player1.toLowerCase();
        final p2Lower = player2.toLowerCase();
        
        // Check if this is our match
        if ((homeTeam.contains(p1Lower) || homeTeam.contains(p2Lower)) &&
            (awayTeam.contains(p1Lower) || awayTeam.contains(p2Lower))) {
          
          // Extract odds data
          final bookmakers = event['bookmakers'] ?? [];
          final odds = _extractBestOdds(bookmakers);
          
          return {
            'eventId': event['id'],
            'commence_time': event['commence_time'],
            'home_team': event['home_team'],
            'away_team': event['away_team'],
            'odds': odds,
            'bookmaker_count': bookmakers.length,
            'sport_title': event['sport_title'],
          };
        }
      }
      
      debugPrint('No matching tennis event found for $player1 vs $player2');
      return null;
      
    } catch (e) {
      debugPrint('Error fetching tennis odds: $e');
      return null;
    }
  }

  /// Get odds for any match by team names
  Future<Map<String, dynamic>?> getMatchOdds({
    required String sport,
    required String homeTeam,
    required String awayTeam,
  }) async {
    try {
      // Get all events for the sport
      final events = await getSportOdds(sport: sport);
      
      if (events == null || events.isEmpty) {
        debugPrint('No events found for $sport');
        return null;
      }
      
      // Find matching event
      for (final event in events) {
        final eventHome = event['home_team']?.toString().toLowerCase() ?? '';
        final eventAway = event['away_team']?.toString().toLowerCase() ?? '';
        
        final homeNormalized = _normalizeTeamName(homeTeam);
        final awayNormalized = _normalizeTeamName(awayTeam);
        
        // Check if this is our match
        if (_teamsMatch(eventHome, homeNormalized) && 
            _teamsMatch(eventAway, awayNormalized)) {
          
          // Extract odds data
          final bookmakers = event['bookmakers'] ?? [];
          final odds = _extractBestOdds(bookmakers);
          
          return {
            'eventId': event['id'],
            'commence_time': event['commence_time'],
            'home_team': event['home_team'],
            'away_team': event['away_team'],
            'odds': odds,
            'bookmaker_count': bookmakers.length,
            'sport_title': event['sport_title'],
            'sport_key': event['sport_key'],
          };
        }
      }
      
      debugPrint('No matching event found for $homeTeam vs $awayTeam');
      return null;
      
    } catch (e) {
      debugPrint('Error fetching match odds: $e');
      return null;
    }
  }

  /// Extract best odds from bookmakers
  Map<String, dynamic> _extractBestOdds(List<dynamic> bookmakers) {
    final bestOdds = <String, dynamic>{
      'h2h': {},
      'spreads': {},
      'totals': {},
    };
    
    // Track best odds for each market
    double? bestHomeOdds;
    double? bestAwayOdds;
    String? bestHomeBook;
    String? bestAwayBook;
    
    for (final bookmaker in bookmakers) {
      final markets = bookmaker['markets'] ?? [];
      
      for (final market in markets) {
        final marketKey = market['key'];
        final outcomes = market['outcomes'] ?? [];
        
        if (marketKey == 'h2h') {
          // Head to head odds
          for (final outcome in outcomes) {
            final price = outcome['price'];
            final name = outcome['name'];
            
            if (price != null) {
              if (name == bookmaker['home_team'] || 
                  outcomes.indexOf(outcome) == 0) {
                // Home team odds
                if (bestHomeOdds == null || price > bestHomeOdds) {
                  bestHomeOdds = price.toDouble();
                  bestHomeBook = bookmaker['title'];
                }
              } else {
                // Away team odds
                if (bestAwayOdds == null || price > bestAwayOdds) {
                  bestAwayOdds = price.toDouble();
                  bestAwayBook = bookmaker['title'];
                }
              }
            }
          }
        } else if (marketKey == 'spreads') {
          // Spread betting
          bestOdds['spreads'] = {
            'bookmaker': bookmaker['title'],
            'outcomes': outcomes,
          };
        } else if (marketKey == 'totals') {
          // Over/under
          bestOdds['totals'] = {
            'bookmaker': bookmaker['title'],
            'outcomes': outcomes,
          };
        }
      }
    }
    
    // Set best H2H odds
    if (bestHomeOdds != null) {
      bestOdds['h2h']['home'] = {
        'odds': bestHomeOdds,
        'bookmaker': bestHomeBook,
      };
    }
    if (bestAwayOdds != null) {
      bestOdds['h2h']['away'] = {
        'odds': bestAwayOdds,
        'bookmaker': bestAwayBook,
      };
    }
    
    return bestOdds;
  }

  /// Normalize team name for matching
  String _normalizeTeamName(String name) {
    return name
        .toLowerCase()
        .replaceAll('the ', '')
        .replaceAll(' fc', '')
        .replaceAll(' united', '')
        .replaceAll(' city', '')
        .trim();
  }

  /// Check if team names match
  bool _teamsMatch(String eventTeam, String searchTeam) {
    // Direct match
    if (eventTeam.contains(searchTeam) || searchTeam.contains(eventTeam)) {
      return true;
    }
    
    // Check last name for individual sports
    final eventParts = eventTeam.split(' ');
    final searchParts = searchTeam.split(' ');
    
    if (eventParts.isNotEmpty && searchParts.isNotEmpty) {
      // Check if last names match (for tennis, golf, etc.)
      if (eventParts.last == searchParts.last) {
        return true;
      }
    }
    
    return false;
  }

  /// Get remaining API quota from quota manager
  int getRemainingQuota() => _quotaManager.getRemainingQuota();
  
  /// Get usage statistics from quota manager
  Map<String, dynamic> getUsageStats() => _quotaManager.getUsageStats();

  /// Get list of supported tennis tournaments
  List<String> getTennisTournaments() => _tennisTournaments.keys.toList();

  /// Get list of supported sports
  List<String> getSupportedSports() => _sportKeys.keys.toList();
}