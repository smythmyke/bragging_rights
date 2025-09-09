import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'odds_quota_manager.dart';

/// The Odds API Service
/// Provides betting odds for all supported sports
/// API Key from .env file (500 requests/month initially, upgradeable)
/// Now integrated with quota management system
class OddsApiService {
  static const String _baseUrl = 'https://api.the-odds-api.com/v4';
  static String _apiKey = dotenv.env['ODDS_API_KEY'] ?? '';
  
  // Quota manager instance
  final OddsQuotaManager _quotaManager = OddsQuotaManager();
  bool _isInitialized = false;
  
  // Singleton instance
  static final OddsApiService _instance = OddsApiService._internal();
  factory OddsApiService() => _instance;
  OddsApiService._internal() {
    _initialize();
  }
  
  Future<void> _initialize() async {
    if (!_isInitialized) {
      await _quotaManager.initialize();
      _isInitialized = true;
    }
  }
  
  Future<void> ensureInitialized() async {
    if (!_isInitialized) {
      await _initialize();
    }
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
    // Ensure quota manager is initialized
    await ensureInitialized();
    return await _quotaManager.executeWithQuota<List<Map<String, dynamic>>>(
      sport: sport,
      apiCall: () async {
        // Get sport key
        String sportKey = _sportKeys[sport.toLowerCase()] ?? sport;
        debugPrint('🔑 Sport mapping: "$sport" -> "$sportKey"');
        
        // Special handling for tennis tournaments
        if (sport.toLowerCase() == 'tennis' && tournament != null) {
          sportKey = _tennisTournaments[tournament.toLowerCase()] ?? sportKey;
        }
        
        final url = '$_baseUrl/sports/$sportKey/odds/?'
            'apiKey=$_apiKey'
            '&regions=$regions'
            '&markets=$markets'
            '&oddsFormat=$oddsFormat';
        
        debugPrint('📡 Calling Odds API: $url');
        
        final response = await http.get(Uri.parse(url));
        
        if (response.statusCode == 200) {
          final data = json.decode(response.body) as List;
          debugPrint('✅ Found ${data.length} events with odds for $sport');
          return data.cast<Map<String, dynamic>>();
        }
        
        debugPrint('❌ Failed to get odds: ${response.statusCode}');
        debugPrint('Response body: ${response.body}');
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
      // Ensure initialization
      await ensureInitialized();
      
      debugPrint('🎯 OddsApiService.getMatchOdds called');
      debugPrint('   Sport: $sport');
      debugPrint('   Looking for: $awayTeam @ $homeTeam');
      
      // Get all events for the sport
      final events = await getSportOdds(sport: sport);
      
      if (events == null || events.isEmpty) {
        debugPrint('❌ No events found for $sport');
        return null;
      }
      
      debugPrint('✅ Found ${events.length} $sport events from API');
      
      // Log all available games for debugging
      debugPrint('📋 Available $sport games from API:');
      for (int i = 0; i < events.length && i < 5; i++) {
        final e = events[i];
        debugPrint('   ${i+1}. ${e['away_team']} @ ${e['home_team']}');
      }
      
      // Find matching event
      for (final event in events) {
        final eventHome = event['home_team']?.toString() ?? '';
        final eventAway = event['away_team']?.toString() ?? '';
        
        final eventHomeLower = eventHome.toLowerCase();
        final eventAwayLower = eventAway.toLowerCase();
        
        final homeNormalized = _normalizeTeamName(homeTeam);
        final awayNormalized = _normalizeTeamName(awayTeam);
        
        // Debug each comparison
        debugPrint('🔍 Comparing:');
        debugPrint('   API: $eventAway @ $eventHome');
        debugPrint('   Looking for: $awayTeam @ $homeTeam');
        debugPrint('   Normalized API: $eventAwayLower @ $eventHomeLower');
        debugPrint('   Normalized search: $awayNormalized @ $homeNormalized');
        
        // Check if this is our match
        final homeMatches = _teamsMatch(eventHomeLower, homeNormalized, sport);
        final awayMatches = _teamsMatch(eventAwayLower, awayNormalized, sport);
        
        debugPrint('   Home match: $homeMatches, Away match: $awayMatches');
        
        if (homeMatches && awayMatches) {
          debugPrint('✅ MATCH FOUND!');
          
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
      
      debugPrint('❌ No matching event found');
      debugPrint('   Was looking for: $awayTeam @ $homeTeam');
      debugPrint('   Sport: $sport');
      debugPrint('   Total events checked: ${events.length}');
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
    // Common MLB abbreviations and variations
    final mlbMap = {
      'diamondbacks': 'd-backs',
      'athletics': 'a\'s',
      'red sox': 'redsox',
      'white sox': 'whitesox',
    };
    
    var normalized = name
        .toLowerCase()
        .replaceAll('the ', '')
        .replaceAll(' fc', '')
        .replaceAll(' united', '')
        .replaceAll(' city', '')
        .replaceAll('st.', 'st')
        .replaceAll('saint', 'st')
        .trim();
    
    // Check for MLB specific mappings
    for (final entry in mlbMap.entries) {
      if (normalized.contains(entry.key)) {
        normalized = normalized.replaceAll(entry.key, entry.value);
      }
    }
    
    return normalized;
  }

  /// Check if team names match
  bool _teamsMatch(String eventTeam, String searchTeam, String sport) {
    // Direct match
    if (eventTeam.contains(searchTeam) || searchTeam.contains(eventTeam)) {
      return true;
    }
    
    // For MLB, be more flexible with city names and team names
    if (sport.toLowerCase() == 'mlb') {
      // Extract the last word (usually the team name)
      final eventParts = eventTeam.split(' ');
      final searchParts = searchTeam.split(' ');
      
      if (eventParts.isNotEmpty && searchParts.isNotEmpty) {
        final eventTeamName = eventParts.last;
        final searchTeamName = searchParts.last;
        
        // Check if team names match
        if (eventTeamName == searchTeamName) {
          return true;
        }
        
        // Check if one contains the other (for cases like "yankees" vs "ny yankees")
        if (eventTeam.contains(searchTeamName) || searchTeam.contains(eventTeamName)) {
          return true;
        }
        
        // Special cases for common MLB variations
        final mlbVariations = {
          'sox': ['redsox', 'whitesox', 'red sox', 'white sox'],
          'jays': ['bluejays', 'blue jays'],
          'cards': ['cardinals'],
          'backs': ['diamondbacks', 'd-backs', 'dbacks'],
          'a\'s': ['athletics', 'as'],
        };
        
        for (final entry in mlbVariations.entries) {
          if ((eventTeamName.contains(entry.key) || searchTeamName.contains(entry.key)) &&
              (entry.value.any((v) => eventTeam.contains(v)) || 
               entry.value.any((v) => searchTeam.contains(v)))) {
            return true;
          }
        }
      }
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
  
  /// Get event-specific odds including prop bets and alternate lines
  /// This endpoint supports player props and alternate markets
  Future<Map<String, dynamic>?> getEventOdds({
    required String sport,
    required String eventId,
    bool includeProps = true,
    bool includeAlternates = true,
  }) async {
    // Ensure initialization
    await ensureInitialized();
    
    try {
      // Build markets string based on requested data
      List<String> markets = ['h2h', 'spreads', 'totals'];
      
      if (includeProps) {
        // Add sport-specific prop markets
        switch (sport.toLowerCase()) {
          case 'nfl':
          case 'americanfootball_nfl':
            markets.addAll([
              'player_pass_tds',
              'player_pass_yds',
              'player_pass_attempts',
              'player_rush_yds',
              'player_rush_attempts',
              'player_rush_tds',
              'player_reception_yds',
              'player_receptions',
            ]);
            break;
          case 'nba':
          case 'basketball_nba':
            markets.addAll([
              'player_points',
              'player_rebounds',
              'player_assists',
              'player_threes',
              'player_blocks',
              'player_steals',
              'player_points_rebounds_assists',
              'player_double_double',
            ]);
            break;
          case 'mlb':
          case 'baseball_mlb':
            markets.addAll([
              'batter_home_runs',
              'batter_hits',
              'batter_rbis',
              'batter_runs_scored',
              'pitcher_strikeouts',
              'pitcher_hits_allowed',
              'batter_total_bases',
            ]);
            break;
          case 'nhl':
          case 'icehockey_nhl':
            markets.addAll([
              'player_goals',
              'player_assists',
              'player_points',
              'player_shots_on_goal',
              'player_blocked_shots',
            ]);
            break;
        }
      }
      
      if (includeAlternates) {
        markets.addAll(['alternate_spreads', 'alternate_totals']);
      }
      
      // Get sport key
      String sportKey = _sportKeys[sport.toLowerCase()] ?? sport;
      
      // Build URL for event-specific endpoint
      final url = '$_baseUrl/sports/$sportKey/events/$eventId/odds?'
          'apiKey=$_apiKey'
          '&regions=us'
          '&markets=${markets.join(',')}'
          '&oddsFormat=american';
      
      debugPrint('📡 Fetching event odds with props: $url');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        
        // Process and organize the odds data
        final processedData = _processEventOdds(data);
        
        debugPrint('✅ Got event odds with ${processedData['marketCount']} market types');
        return processedData;
      }
      
      debugPrint('❌ Failed to get event odds: ${response.statusCode}');
      return null;
      
    } catch (e) {
      debugPrint('Error fetching event odds: $e');
      return null;
    }
  }
  
  /// Process event odds data to organize by market type
  Map<String, dynamic> _processEventOdds(Map<String, dynamic> data) {
    final result = {
      'eventId': data['id'],
      'homeTeam': data['home_team'],
      'awayTeam': data['away_team'],
      'commenceTime': data['commence_time'],
      'bookmakers': data['bookmakers'] ?? [],
      'markets': <String, dynamic>{},
      'marketCount': 0,
    };
    
    // Organize markets by type
    final bookmakers = data['bookmakers'] ?? [];
    final marketTypes = <String>{};
    
    for (final bookmaker in bookmakers) {
      final markets = bookmaker['markets'] ?? [];
      
      for (final market in markets) {
        final key = market['key'];
        marketTypes.add(key);
        
        // Initialize market category if not exists
        if (!result['markets'].containsKey(key)) {
          result['markets'][key] = {
            'type': key,
            'bookmakers': [],
          };
        }
        
        // Add bookmaker data for this market
        result['markets'][key]['bookmakers'].add({
          'name': bookmaker['title'],
          'outcomes': market['outcomes'],
        });
      }
    }
    
    // Categorize markets
    result['standardMarkets'] = marketTypes.where((m) => 
      m == 'h2h' || m == 'spreads' || m == 'totals').toList();
    
    result['propMarkets'] = marketTypes.where((m) => 
      m.contains('player') || m.contains('batter') || m.contains('pitcher')).toList();
    
    result['alternateMarkets'] = marketTypes.where((m) => 
      m.contains('alternate')).toList();
    
    result['marketCount'] = marketTypes.length;
    
    return result;
  }
  
  /// Get all events for a sport
  Future<List<Map<String, dynamic>>?> getSportEvents(String sport) async {
    try {
      // Ensure initialization
      await ensureInitialized();
      
      String sportKey = _sportKeys[sport.toLowerCase()] ?? sport;
      
      final url = '$_baseUrl/sports/$sportKey/events?apiKey=$_apiKey';
      
      debugPrint('📡 Fetching events for $sport');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        debugPrint('✅ Found ${data.length} events for $sport');
        return data.cast<Map<String, dynamic>>();
      }
      
      debugPrint('❌ Failed to get events: ${response.statusCode}');
      return null;
      
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return null;
    }
  }
}