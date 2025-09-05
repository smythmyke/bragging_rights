import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// SportsGameOdds API Service
/// Provides betting odds for all supported sports
/// API Key: 40b75921e9a3d1cd6957325bf0731811
class SportsGameOddsService {
  static const String _baseUrl = 'https://api.sportsgameodds.com/v1';
  static const String _apiKey = '40b75921e9a3d1cd6957325bf0731811';
  
  // Singleton instance
  static final SportsGameOddsService _instance = SportsGameOddsService._internal();
  factory SportsGameOddsService() => _instance;
  SportsGameOddsService._internal();
  
  // Sport ID mapping for SportsGameOdds API
  static const Map<String, String> _sportIds = {
    'nba': 'basketball_nba',
    'nfl': 'football_nfl',
    'nhl': 'hockey_nhl',
    'mlb': 'baseball_mlb',
    'mma': 'mma_ufc',
    'boxing': 'boxing',
    'tennis': 'tennis',
    'soccer': 'soccer',
    'golf': 'golf',
    'ncaab': 'basketball_ncaab',
    'ncaaf': 'football_ncaaf',
  };
  
  /// Get events and odds for a specific sport
  Future<List<Map<String, dynamic>>?> getSportEvents({
    required String sport,
    bool liveOnly = false,
  }) async {
    try {
      final sportId = _sportIds[sport.toLowerCase()] ?? sport.toLowerCase();
      
      // Build URL with query parameters
      final uri = Uri.parse('$_baseUrl/events').replace(
        queryParameters: {
          'sport': sportId,
          if (liveOnly) 'live': 'true',
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] ?? data ?? [];
        debugPrint('✅ Found ${events.length} events for $sport');
        return List<Map<String, dynamic>>.from(events);
      } else if (response.statusCode == 429) {
        debugPrint('⚠️ Rate limit exceeded for SportsGameOdds API');
        return null;
      } else {
        debugPrint('❌ Failed to get events: ${response.statusCode}');
        debugPrint('Response: ${response.body}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching sport events: $e');
      return null;
    }
  }
  
  /// Get odds for a specific game
  Future<Map<String, dynamic>?> getGameOdds({
    required String gameId,
    String markets = 'h2h,spreads,totals',
  }) async {
    try {
      final uri = Uri.parse('$_baseUrl/events/$gameId/odds').replace(
        queryParameters: {
          'markets': markets,
        },
      );
      
      final response = await http.get(
        uri,
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data;
      } else if (response.statusCode == 429) {
        debugPrint('⚠️ Rate limit exceeded for game odds');
        return null;
      } else {
        debugPrint('❌ Failed to get game odds: ${response.statusCode}');
        return null;
      }
    } catch (e) {
      debugPrint('Error fetching game odds: $e');
      return null;
    }
  }
  
  /// Find and get odds for a match by team names
  Future<Map<String, dynamic>?> findMatchOdds({
    required String sport,
    required String homeTeam,
    required String awayTeam,
  }) async {
    try {
      // Get all events for the sport
      final events = await getSportEvents(sport: sport);
      
      if (events == null || events.isEmpty) {
        debugPrint('No events found for $sport');
        return null;
      }
      
      // Find matching event
      for (final event in events) {
        final eventHome = (event['home_team'] ?? event['homeTeam'] ?? '').toString().toLowerCase();
        final eventAway = (event['away_team'] ?? event['awayTeam'] ?? '').toString().toLowerCase();
        
        final homeTeamLower = homeTeam.toLowerCase();
        final awayTeamLower = awayTeam.toLowerCase();
        
        // Flexible matching - check if names contain each other
        bool homeMatch = eventHome.contains(homeTeamLower) || 
                         homeTeamLower.contains(eventHome) ||
                         _fuzzyMatch(eventHome, homeTeamLower);
        bool awayMatch = eventAway.contains(awayTeamLower) || 
                         awayTeamLower.contains(eventAway) ||
                         _fuzzyMatch(eventAway, awayTeamLower);
        
        if (homeMatch && awayMatch) {
          return _extractOddsFromEvent(event);
        }
      }
      
      debugPrint('No matching event found for $awayTeam @ $homeTeam');
      return null;
      
    } catch (e) {
      debugPrint('Error finding match odds: $e');
      return null;
    }
  }
  
  /// Fuzzy matching for team names
  bool _fuzzyMatch(String name1, String name2) {
    // Remove common words and compare
    final commonWords = ['fc', 'united', 'city', 'town', 'athletic', 'club', 'state'];
    
    String clean1 = name1.toLowerCase();
    String clean2 = name2.toLowerCase();
    
    for (final word in commonWords) {
      clean1 = clean1.replaceAll(word, '').trim();
      clean2 = clean2.replaceAll(word, '').trim();
    }
    
    // Check if core names match
    return clean1.contains(clean2) || clean2.contains(clean1);
  }
  
  /// Extract odds data from event
  Map<String, dynamic> _extractOddsFromEvent(Map<String, dynamic> event) {
    final odds = <String, dynamic>{};
    
    // Extract bookmaker odds
    final bookmakers = event['bookmakers'] ?? event['odds'] ?? [];
    
    if (bookmakers is List && bookmakers.isNotEmpty) {
      // Get best odds from all bookmakers
      double? bestHomeML;
      double? bestAwayML;
      double? bestSpread;
      double? bestSpreadOdds;
      double? bestTotal;
      double? bestOverOdds;
      double? bestUnderOdds;
      
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        
        for (final market in markets) {
          final marketKey = market['key'] ?? market['type'] ?? '';
          final outcomes = market['outcomes'] ?? [];
          
          if (marketKey == 'h2h' || marketKey == 'moneyline') {
            for (final outcome in outcomes) {
              final name = outcome['name']?.toString().toLowerCase() ?? '';
              final price = _parseOdds(outcome['price']);
              
              if (name.contains('home') && (bestHomeML == null || price > bestHomeML)) {
                bestHomeML = price;
              }
              if (name.contains('away') && (bestAwayML == null || price > bestAwayML)) {
                bestAwayML = price;
              }
            }
          } else if (marketKey == 'spreads' || marketKey == 'spread') {
            for (final outcome in outcomes) {
              final point = outcome['point']?.toDouble() ?? 0.0;
              final price = _parseOdds(outcome['price']);
              
              if (outcome['name']?.toString().toLowerCase().contains('home') == true) {
                bestSpread = point;
                bestSpreadOdds = price;
              }
            }
          } else if (marketKey == 'totals' || marketKey == 'total') {
            for (final outcome in outcomes) {
              final name = outcome['name']?.toString().toLowerCase() ?? '';
              final point = outcome['point']?.toDouble() ?? 0.0;
              final price = _parseOdds(outcome['price']);
              
              if (name.contains('over')) {
                bestTotal = point;
                bestOverOdds = price;
              } else if (name.contains('under')) {
                bestUnderOdds = price;
              }
            }
          }
        }
      }
      
      // Build odds object
      if (bestHomeML != null || bestAwayML != null) {
        odds['moneyline'] = {
          'home': bestHomeML ?? -110,
          'away': bestAwayML ?? -110,
        };
      }
      
      if (bestSpread != null) {
        odds['spread'] = {
          'line': bestSpread,
          'homeOdds': bestSpreadOdds ?? -110,
          'awayOdds': -110, // Default if not found
        };
      }
      
      if (bestTotal != null) {
        odds['total'] = {
          'line': bestTotal,
          'overOdds': bestOverOdds ?? -110,
          'underOdds': bestUnderOdds ?? -110,
        };
      }
    }
    
    // Add event metadata
    odds['eventId'] = event['id'] ?? event['game_id'];
    odds['commence_time'] = event['commence_time'] ?? event['start_time'];
    odds['home_team'] = event['home_team'] ?? event['homeTeam'];
    odds['away_team'] = event['away_team'] ?? event['awayTeam'];
    odds['bookmaker_count'] = (bookmakers as List?)?.length ?? 0;
    
    return odds;
  }
  
  /// Parse odds to American format
  double _parseOdds(dynamic odds) {
    if (odds == null) return -110;
    
    if (odds is num) {
      // Already in American format
      if (odds > 0 || odds < -50) {
        return odds.toDouble();
      }
      // Decimal odds - convert to American
      if (odds > 1 && odds < 50) {
        if (odds >= 2.0) {
          return (odds - 1) * 100;
        } else {
          return -100 / (odds - 1);
        }
      }
    }
    
    if (odds is String) {
      final parsed = double.tryParse(odds);
      if (parsed != null) {
        return _parseOdds(parsed);
      }
    }
    
    return -110; // Default odds
  }
  
  /// Check API usage and limits
  Future<Map<String, dynamic>?> checkUsage() async {
    try {
      final response = await http.get(
        Uri.parse('$_baseUrl/account/usage'),
        headers: {
          'x-api-key': _apiKey,
          'Content-Type': 'application/json',
        },
      );
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        debugPrint('📊 API Usage: ${data['requests_used']}/${data['requests_limit']} requests');
        debugPrint('📊 Objects: ${data['objects_used']}/${data['objects_limit']}');
        return data;
      }
      
      return null;
    } catch (e) {
      debugPrint('Error checking API usage: $e');
      return null;
    }
  }
}