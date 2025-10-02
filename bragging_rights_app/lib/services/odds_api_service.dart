import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'odds_quota_manager.dart';
import '../models/game_model.dart';

/// Season type for sports (preseason, regular season, playoffs, etc.)
enum SportSeasonType {
  preseason,
  regularSeason,
  playoffs,
  postseason,
  futures,
}

/// Date range for determining which endpoint to use
class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  /// Check if a date falls within this range
  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }
}

/// Sport endpoint configuration for multi-endpoint support
/// Allows different API endpoints for preseason, regular season, etc.
class SportEndpoint {
  final String key;
  final SportSeasonType type;
  final int priority; // Lower number = checked first
  final String? label; // UI badge text (null = no badge)
  final DateRange? dateRange;

  const SportEndpoint({
    required this.key,
    required this.type,
    required this.priority,
    this.label,
    this.dateRange,
  });

  /// Check if this endpoint applies to a given date
  bool appliesToDate(DateTime date) {
    if (dateRange == null) return true; // No date restriction
    return dateRange!.contains(date);
  }
}

/// The Odds API Service
/// Provides betting odds for all supported sports
/// API Key from .env file (500 requests/month initially, upgradeable)
/// Now integrated with quota management system
/// Supports multi-endpoint queries for preseason/regular season/playoffs
class OddsApiService {
  static const String _baseUrl = 'https://api.the-odds-api.com/v4';
  static String _apiKey = dotenv.env['ODDS_API_KEY'] ?? '';
  
  // Quota manager instance
  final OddsQuotaManager _quotaManager = OddsQuotaManager();
  bool _isInitialized = false;
  
  // Singleton instance
  static final OddsApiService _instance = OddsApiService._internal();
  factory OddsApiService() => _instance;
  OddsApiService._internal();
  
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

  /// Get all applicable endpoints for a sport
  /// Returns endpoints sorted by priority (preseason first, then regular season)
  /// If gameDate is provided, filters to only endpoints applicable to that date
  List<SportEndpoint> _getEndpointsForSport(String sport, {DateTime? gameDate}) {
    final endpoints = _sportEndpoints[sport.toLowerCase()];

    if (endpoints == null || endpoints.isEmpty) {
      // Fallback to legacy single-endpoint mapping
      final legacyKey = _sportKeys[sport.toLowerCase()];
      if (legacyKey != null) {
        return [
          SportEndpoint(
            key: legacyKey,
            type: SportSeasonType.regularSeason,
            priority: 1,
            label: null,
            dateRange: null,
          ),
        ];
      }
      return [];
    }

    // Filter by date if provided
    if (gameDate != null) {
      final filtered = endpoints.where((e) => e.appliesToDate(gameDate)).toList();
      if (filtered.isNotEmpty) {
        // Sort by priority
        filtered.sort((a, b) => a.priority.compareTo(b.priority));
        debugPrint('📅 Filtered endpoints for ${sport} on ${gameDate.toIso8601String()}: ${filtered.map((e) => e.key).join(", ")}');
        return filtered;
      }
    }

    // Return all endpoints sorted by priority
    final sorted = List<SportEndpoint>.from(endpoints);
    sorted.sort((a, b) => a.priority.compareTo(b.priority));
    return sorted;
  }

  // Legacy sport keys mapping (single endpoint per sport)
  // Kept for backward compatibility with sports not yet configured for multi-endpoint
  static const Map<String, String> _sportKeys = {
    'nba': 'basketball_nba', // Legacy - will use _sportEndpoints instead
    'nfl': 'americanfootball_nfl',
    'nhl': 'icehockey_nhl',
    'mlb': 'baseball_mlb',
    'mma': 'mma_mixed_martial_arts',
    'ufc': 'mma_mixed_martial_arts',  // UFC uses same API endpoint
    'bellator': 'mma_mixed_martial_arts',  // Bellator uses same API endpoint
    'pfl': 'mma_mixed_martial_arts',  // PFL uses same API endpoint
    'invicta': 'mma_mixed_martial_arts',  // Invicta FC uses same API endpoint
    'one': 'mma_mixed_martial_arts',  // ONE Championship uses same API endpoint
    'boxing': 'boxing_boxing',
    'tennis': 'tennis_atp_french_open', // Default to major tournament
    'soccer': 'soccer_epl', // Premier League as default
    'golf': 'golf_pga_championship',
    'ncaab': 'basketball_ncaab',
    'ncaaf': 'americanfootball_ncaaf',
  };

  // Multi-endpoint sport configurations
  // Sports with preseason, playoffs, or multiple seasons
  static final Map<String, List<SportEndpoint>> _sportEndpoints = {
    'nba': [
      SportEndpoint(
        key: 'basketball_nba_preseason',
        type: SportSeasonType.preseason,
        priority: 1, // Check preseason first
        label: 'PRESEASON',
        dateRange: DateRange(
          start: DateTime(2025, 10, 1),
          end: DateTime(2025, 10, 15),
        ),
      ),
      SportEndpoint(
        key: 'basketball_nba',
        type: SportSeasonType.regularSeason,
        priority: 2, // Check regular season second
        label: null, // No badge for regular season
        dateRange: DateRange(
          start: DateTime(2025, 10, 15),
          end: DateTime(2026, 6, 30),
        ),
      ),
    ],
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
            // NBA props not currently available from API
            // Only h2h and totals are supported
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
            // NHL props not currently available from API
            // Only h2h and totals are supported
            break;
          case 'mma':
          case 'ufc':
          case 'bellator':
          case 'pfl':
          case 'invicta':
          case 'one':
            // MMA/UFC props not currently available from API
            // Only h2h (winner) market is supported
            break;
          case 'boxing':
            // Boxing props not currently available from API
            // Only h2h (winner) market is supported
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
      
      // Handle 422 specifically - invalid event ID, don't retry
      if (response.statusCode == 422) {
        debugPrint('⚠️ Invalid event ID $eventId - event may be expired or ID format incorrect');
        return {};  // Return empty data instead of null to prevent retries
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
      'bookmakers': data['bookmakers'] ?? [], // Keep original bookmakers array
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
    
    // Debug logging for props
    if (result['propMarkets'].isNotEmpty) {
      debugPrint('📊 Found prop markets: ${result['propMarkets']}');
    }
    
    return result;
  }
  
  /// Get all events for a sport
  Future<List<Map<String, dynamic>>?> getSportEvents(String sport, {int? daysAhead}) async {
    try {
      // Ensure initialization
      await ensureInitialized();

      String sportKey = _sportKeys[sport.toLowerCase()] ?? sport;

      // Add date range parameters if daysAhead is specified
      String url = '$_baseUrl/sports/$sportKey/events?apiKey=$_apiKey';
      if (daysAhead != null) {
        final now = DateTime.now().toUtc();
        final endDate = now.add(Duration(days: daysAhead));
        url += '&commenceTimeFrom=${now.toIso8601String()}';
        url += '&commenceTimeTo=${endDate.toIso8601String()}';
        debugPrint('📅 Fetching $sport events for next $daysAhead days');
      }

      debugPrint('📡 Fetching events for $sport');

      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        debugPrint('✅ Found ${data.length} events for $sport');

        // Debug first few events to see sport_title
        if (data.isNotEmpty) {
          debugPrint('First event sport_title: "${data.first['sport_title']}"');
        }

        return data.cast<Map<String, dynamic>>();
      }
      
      debugPrint('❌ Failed to get events: ${response.statusCode}');
      return null;
      
    } catch (e) {
      debugPrint('Error fetching events: $e');
      return null;
    }
  }
  
  /// Get games for a sport converted to GameModel format
  /// This can be used as the primary source for game listings
  Future<List<GameModel>> getSportGames(String sport, {int? daysAhead}) async {
    try {
      // Pass daysAhead to getSportEvents for API-level filtering
      final events = await getSportEvents(sport, daysAhead: daysAhead);
      if (events == null || events.isEmpty) {
        return [];
      }

      final games = <GameModel>[];
      final now = DateTime.now();
      // Still keep client-side filtering as a safety check
      final cutoffDate = daysAhead != null
          ? now.add(Duration(days: daysAhead))
          : null;
      
      // Debug: Log boxing events specifically
      if (sport.toLowerCase() == 'boxing') {
        debugPrint('🥊 Boxing events received: ${events.length}');
        for (final event in events) {
          final homeTeam = event['home_team'] ?? '';
          final awayTeam = event['away_team'] ?? '';
          if (homeTeam.toLowerCase().contains('canelo') || 
              awayTeam.toLowerCase().contains('crawford')) {
            debugPrint('🎯 FOUND CANELO/CRAWFORD: $awayTeam vs $homeTeam');
            debugPrint('   Event ID: ${event['id']}');
            debugPrint('   Time: ${event['commence_time']}');
          }
        }
      }
      
      for (final event in events) {
        try {
          final gameTime = DateTime.parse(event['commence_time']);
          
          // Filter by date range if specified
          if (cutoffDate != null && gameTime.isAfter(cutoffDate)) {
            continue;
          }
          
          // Convert Odds API event to GameModel
          // Determine actual sport from sport_title for MMA/UFC detection
          String actualSport = sport.toUpperCase();
          final sportTitle = event['sport_title'] ?? '';
          
          // Check if it's actually MMA/UFC based on the sport_title
          if (sportTitle.toLowerCase().contains('ufc') || 
              sportTitle.toLowerCase().contains('mma') ||
              sportTitle.toLowerCase().contains('mixed martial') ||
              sportTitle.toLowerCase().contains('bellator') ||
              sportTitle.toLowerCase().contains('pfl') ||
              sportTitle.toLowerCase().contains('one championship')) {
            actualSport = 'MMA';
          } else if (sportTitle.toLowerCase().contains('boxing')) {
            actualSport = 'BOXING';
          }
          
          final game = GameModel(
            id: event['id'], // Use Odds API event ID
            sport: actualSport,
            homeTeam: event['home_team'] ?? '',
            awayTeam: event['away_team'] ?? '',
            gameTime: gameTime,
            status: 'scheduled', // Will be updated from scores endpoint
            league: event['sport_title'] ?? sport.toUpperCase(),
            // These fields will be null but can be enhanced with ESPN data later
            venue: null,
            broadcast: null,
            homeTeamLogo: null,
            awayTeamLogo: null,
          );
          
          games.add(game);
        } catch (e) {
          debugPrint('Error parsing event: $e');
          continue;
        }
      }
      
      // Sort by game time
      games.sort((a, b) => a.gameTime.compareTo(b.gameTime));
      
      debugPrint('📊 Converted ${games.length} $sport events to GameModel');
      return games;
    } catch (e) {
      debugPrint('❌ Error getting sport games: $e');
      return [];
    }
  }
  
  /// Get live scores for a sport
  Future<Map<String, Map<String, dynamic>>> getSportScores(String sport) async {
    try {
      await ensureInitialized();
      
      String sportKey = _sportKeys[sport.toLowerCase()] ?? sport;
      
      // Get scores for games in the last day and next day
      final url = '$_baseUrl/sports/$sportKey/scores?apiKey=$_apiKey&daysFrom=1';
      
      debugPrint('📡 Fetching scores for $sport');
      
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        
        // Convert to map for easy lookup by event ID
        final scoresMap = <String, Map<String, dynamic>>{};
        for (final score in data) {
          scoresMap[score['id']] = score;
        }
        
        debugPrint('✅ Found scores for ${scoresMap.length} $sport games');
        return scoresMap;
      }
      
      debugPrint('❌ Failed to get scores: ${response.statusCode}');
      return {};
    } catch (e) {
      debugPrint('❌ Error getting scores: $e');
      return {};
    }
  }
  
  /// Find The Odds API event ID by matching team names
  Future<String?> findOddsApiEventId({
    required String sport,
    required String homeTeam,
    required String awayTeam,
  }) async {
    try {
      debugPrint('🔎 findOddsApiEventId called with:');
      debugPrint('   Sport: $sport');
      debugPrint('   Home Team: "$homeTeam"');
      debugPrint('   Away Team: "$awayTeam"');
      
      final events = await getSportEvents(sport);
      if (events == null || events.isEmpty) {
        debugPrint('❌ No events found for sport: $sport');
        return null;
      }
      
      debugPrint('📋 Found ${events.length} events for $sport');
      
      // Normalize team names for comparison
      final normalizedHome = _normalizeTeamName(homeTeam);
      final normalizedAway = _normalizeTeamName(awayTeam);
      
      debugPrint('🔍 Looking for match:');
      debugPrint('   Normalized Home: "$normalizedHome"');
      debugPrint('   Normalized Away: "$normalizedAway"');
      
      for (final event in events) {
        final apiHome = event['home_team'] ?? '';
        final apiAway = event['away_team'] ?? '';
        final eventHome = _normalizeTeamName(apiHome);
        final eventAway = _normalizeTeamName(apiAway);
        
        debugPrint('   Checking event: ${event['id']}');
        debugPrint('     API Teams: "$apiAway" @ "$apiHome"');
        debugPrint('     Normalized: "$eventAway" @ "$eventHome"');
        
        // Check if teams match (in either order)
        final homeMatches = eventHome.contains(normalizedHome) || normalizedHome.contains(eventHome);
        final awayMatches = eventAway.contains(normalizedAway) || normalizedAway.contains(eventAway);
        
        debugPrint('     Home match: $homeMatches, Away match: $awayMatches');
        
        if (homeMatches && awayMatches) {
          debugPrint('✅ Found matching event: ${event['id']} - $apiHome vs $apiAway');
          return event['id'];
        }
      }
      
      debugPrint('❌ No matching event found for "$awayTeam" @ "$homeTeam"');
      return null;
    } catch (e) {
      debugPrint('❌ Error finding event ID: $e');
      return null;
    }
  }
  
}