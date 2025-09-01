import 'package:flutter/foundation.dart';
import 'edge/sports/espn_nba_service.dart';
import 'edge/sports/espn_nfl_service.dart';
import 'edge/sports/espn_nhl_service.dart';
import 'edge/sports/espn_mlb_service.dart';
import 'edge/sports/espn_tennis_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Free Odds Service - Fallback when The Odds API quota is exceeded
/// Uses ESPN odds data (embedded in game data) and other free sources
class FreeOddsService {
  // ESPN services for each sport
  final EspnNbaService _nbaService = EspnNbaService();
  final EspnNflService _nflService = EspnNflService();
  final EspnNhlService _nhlService = EspnNhlService();
  final EspnMlbService _mlbService = EspnMlbService();
  final EspnTennisService _tennisService = EspnTennisService();
  
  // Singleton instance
  static final FreeOddsService _instance = FreeOddsService._internal();
  factory FreeOddsService() => _instance;
  FreeOddsService._internal();
  
  /// Get free odds for a specific sport and match
  Future<Map<String, dynamic>?> getFreeOdds({
    required String sport,
    required String homeTeam,
    required String awayTeam,
    String? eventId,
  }) async {
    switch (sport.toLowerCase()) {
      case 'nba':
        return await _getNbaOdds(homeTeam, awayTeam);
      case 'nfl':
        return await _getNflOdds(homeTeam, awayTeam);
      case 'nhl':
        return await _getNhlOdds(homeTeam, awayTeam);
      case 'mlb':
        return await _getMlbOdds(homeTeam, awayTeam);
      case 'tennis':
        return await _getTennisOdds(homeTeam, awayTeam);
      case 'soccer':
        return await _getSoccerOdds(homeTeam, awayTeam);
      case 'mma':
      case 'ufc':
        return await _getMmaOdds(homeTeam, awayTeam, sport);
      case 'boxing':
        return await _getBoxingOdds(homeTeam, awayTeam);
      default:
        return await _getGenericEspnOdds(sport, homeTeam, awayTeam);
    }
  }
  
  /// Get NBA odds from ESPN
  Future<Map<String, dynamic>?> _getNbaOdds(String home, String away) async {
    try {
      final scoreboard = await _nbaService.getScoreboard();
      if (scoreboard == null) return null;
      
      // Find matching game
      for (final game in scoreboard.games) {
        if (_teamsMatch(game.homeTeam, home) && _teamsMatch(game.awayTeam, away)) {
          return _extractOddsFromGame(game.toMap());
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting NBA odds: $e');
      return null;
    }
  }
  
  /// Get NFL odds from ESPN
  Future<Map<String, dynamic>?> _getNflOdds(String home, String away) async {
    try {
      final games = await _nflService.getTodaysGames();
      if (games == null) return null;
      
      // Find matching game
      for (final game in games) {
        if (_teamsMatch(game['homeTeam'], home) && _teamsMatch(game['awayTeam'], away)) {
          return _extractOddsFromGame(game);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting NFL odds: $e');
      return null;
    }
  }
  
  /// Get NHL odds from ESPN
  Future<Map<String, dynamic>?> _getNhlOdds(String home, String away) async {
    try {
      final scoreboard = await _nhlService.getScoreboard();
      if (scoreboard == null) return null;
      
      // Find matching game
      for (final game in scoreboard['games'] ?? []) {
        if (_teamsMatch(game['homeTeam'], home) && _teamsMatch(game['awayTeam'], away)) {
          return _extractOddsFromGame(game);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting NHL odds: $e');
      return null;
    }
  }
  
  /// Get MLB odds from ESPN
  Future<Map<String, dynamic>?> _getMlbOdds(String home, String away) async {
    try {
      final scoreboard = await _mlbService.getScoreboard();
      if (scoreboard == null) return null;
      
      // Find matching game
      for (final game in scoreboard['games'] ?? []) {
        if (_teamsMatch(game['homeTeam'], home) && _teamsMatch(game['awayTeam'], away)) {
          return _extractOddsFromGame(game);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting MLB odds: $e');
      return null;
    }
  }
  
  /// Get Tennis odds from ESPN
  Future<Map<String, dynamic>?> _getTennisOdds(String player1, String player2) async {
    try {
      final scoreboard = await _tennisService.getScoreboard();
      if (scoreboard == null) return null;
      
      // Find matching match
      for (final match in scoreboard.matches) {
        final p1 = match.player1['name'] ?? '';
        final p2 = match.player2['name'] ?? '';
        
        if ((_teamsMatch(p1, player1) && _teamsMatch(p2, player2)) ||
            (_teamsMatch(p1, player2) && _teamsMatch(p2, player1))) {
          return _extractOddsFromGame(match.toMap());
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting Tennis odds: $e');
      return null;
    }
  }
  
  /// Get MMA/UFC odds from ESPN
  Future<Map<String, dynamic>?> _getMmaOdds(String fighter1, String fighter2, String promotion) async {
    try {
      // Determine the promotion endpoint
      final promotionPath = promotion.toLowerCase() == 'bellator' ? 'bellator' :
                           promotion.toLowerCase() == 'pfl' ? 'pfl' :
                           promotion.toLowerCase() == 'one' ? 'one' :
                           'ufc'; // Default to UFC
      
      final response = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/$promotionPath/scoreboard'),
      );
      
      if (response.statusCode != 200) return null;
      
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      // Find matching fight
      for (final event in events) {
        final competition = event['competitions']?[0];
        if (competition == null) continue;
        
        final competitors = competition['competitors'] ?? [];
        if (competitors.length < 2) continue;
        
        final f1 = competitors[0]['athlete']?['displayName'] ?? '';
        final f2 = competitors[1]['athlete']?['displayName'] ?? '';
        
        if (_teamsMatch(f1, fighter1) && _teamsMatch(f2, fighter2) ||
            _teamsMatch(f1, fighter2) && _teamsMatch(f2, fighter1)) {
          return _extractOddsFromEspnEvent(event);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting MMA odds: $e');
      return null;
    }
  }
  
  /// Get Boxing odds from ESPN
  Future<Map<String, dynamic>?> _getBoxingOdds(String fighter1, String fighter2) async {
    try {
      final response = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/boxing/boxing/scoreboard'),
      );
      
      if (response.statusCode != 200) return null;
      
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      // Find matching fight
      for (final event in events) {
        final competition = event['competitions']?[0];
        if (competition == null) continue;
        
        final competitors = competition['competitors'] ?? [];
        if (competitors.length < 2) continue;
        
        final f1 = competitors[0]['athlete']?['displayName'] ?? '';
        final f2 = competitors[1]['athlete']?['displayName'] ?? '';
        
        if (_teamsMatch(f1, fighter1) && _teamsMatch(f2, fighter2) ||
            _teamsMatch(f1, fighter2) && _teamsMatch(f2, fighter1)) {
          return _extractOddsFromEspnEvent(event);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting Boxing odds: $e');
      return null;
    }
  }
  
  /// Get Soccer odds from ESPN
  Future<Map<String, dynamic>?> _getSoccerOdds(String home, String away) async {
    try {
      // ESPN Soccer endpoint
      final response = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/soccer/all/scoreboard'),
      );
      
      if (response.statusCode != 200) return null;
      
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      // Find matching game
      for (final event in events) {
        final competition = event['competitions']?[0];
        if (competition == null) continue;
        
        final competitors = competition['competitors'] ?? [];
        if (competitors.length < 2) continue;
        
        final homeTeam = competitors[0]['team']?['displayName'] ?? '';
        final awayTeam = competitors[1]['team']?['displayName'] ?? '';
        
        if (_teamsMatch(homeTeam, home) && _teamsMatch(awayTeam, away)) {
          return _extractOddsFromEspnEvent(event);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting Soccer odds: $e');
      return null;
    }
  }
  
  /// Get generic ESPN odds for any sport
  Future<Map<String, dynamic>?> _getGenericEspnOdds(
    String sport,
    String home,
    String away,
  ) async {
    try {
      // Try generic ESPN endpoint
      final response = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/$sport/scoreboard'),
      );
      
      if (response.statusCode != 200) return null;
      
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      // Find matching game
      for (final event in events) {
        final competition = event['competitions']?[0];
        if (competition == null) continue;
        
        final competitors = competition['competitors'] ?? [];
        if (competitors.length < 2) continue;
        
        final homeTeam = competitors[0]['team']?['displayName'] ?? 
                         competitors[0]['athlete']?['displayName'] ?? '';
        final awayTeam = competitors[1]['team']?['displayName'] ?? 
                         competitors[1]['athlete']?['displayName'] ?? '';
        
        if (_teamsMatch(homeTeam, home) && _teamsMatch(awayTeam, away)) {
          return _extractOddsFromEspnEvent(event);
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('Error getting generic ESPN odds: $e');
      return null;
    }
  }
  
  /// Extract odds from game data
  Map<String, dynamic> _extractOddsFromGame(Map<String, dynamic> game) {
    final odds = <String, dynamic>{
      'source': 'ESPN',
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    
    // Check for odds in game data
    if (game['odds'] != null) {
      odds.addAll(game['odds'] as Map<String, dynamic>);
    }
    
    // Check for competition odds
    if (game['competitions'] != null) {
      final competitions = game['competitions'] as List;
      if (competitions.isNotEmpty) {
        final competition = competitions[0];
        if (competition['odds'] != null) {
          final compOdds = competition['odds'] as List;
          if (compOdds.isNotEmpty) {
            odds['details'] = compOdds[0];
            
            // Extract specific values
            if (compOdds[0]['details'] != null) {
              odds['spread'] = compOdds[0]['details'];
            }
            if (compOdds[0]['overUnder'] != null) {
              odds['total'] = compOdds[0]['overUnder'];
            }
          }
        }
      }
    }
    
    // Check for betting data
    if (game['pickcenter'] != null) {
      final pickcenter = game['pickcenter'] as List;
      if (pickcenter.isNotEmpty) {
        odds['betting'] = pickcenter[0];
      }
    }
    
    return odds;
  }
  
  /// Extract odds from ESPN event structure
  Map<String, dynamic> _extractOddsFromEspnEvent(Map<String, dynamic> event) {
    final odds = <String, dynamic>{
      'source': 'ESPN',
      'eventId': event['id'],
      'lastUpdated': DateTime.now().toIso8601String(),
    };
    
    final competition = event['competitions']?[0];
    if (competition == null) return odds;
    
    // Get odds array
    final oddsArray = competition['odds'];
    if (oddsArray != null && oddsArray is List && oddsArray.isNotEmpty) {
      final primaryOdds = oddsArray[0];
      
      // Provider info
      odds['provider'] = primaryOdds['provider']?['name'] ?? 'ESPN Bet';
      
      // Spread
      if (primaryOdds['details'] != null) {
        odds['spread'] = primaryOdds['details'];
      }
      
      // Over/Under
      if (primaryOdds['overUnder'] != null) {
        odds['total'] = primaryOdds['overUnder'];
      }
      
      // Moneyline
      if (primaryOdds['awayTeamOdds'] != null) {
        odds['awayMoneyline'] = primaryOdds['awayTeamOdds']['moneyLine'];
      }
      if (primaryOdds['homeTeamOdds'] != null) {
        odds['homeMoneyline'] = primaryOdds['homeTeamOdds']['moneyLine'];
      }
    }
    
    // Get predicted score if available
    if (competition['predictor'] != null) {
      odds['prediction'] = {
        'homeScore': competition['predictor']['homeTeam']?['score'],
        'awayScore': competition['predictor']['awayTeam']?['score'],
      };
    }
    
    // Get win probabilities if available
    if (competition['situation'] != null) {
      final situation = competition['situation'];
      if (situation['lastPlay'] != null) {
        odds['winProbability'] = {
          'home': situation['lastPlay']['probability']?['homeWinPercentage'],
          'away': situation['lastPlay']['probability']?['awayWinPercentage'],
        };
      }
    }
    
    return odds;
  }
  
  /// Check if team names match (fuzzy matching)
  bool _teamsMatch(String? team1, String? team2) {
    if (team1 == null || team2 == null) return false;
    
    final t1 = team1.toLowerCase().trim();
    final t2 = team2.toLowerCase().trim();
    
    // Exact match
    if (t1 == t2) return true;
    
    // Contains match
    if (t1.contains(t2) || t2.contains(t1)) return true;
    
    // Last word match (for city + team name)
    final t1Words = t1.split(' ');
    final t2Words = t2.split(' ');
    
    if (t1Words.isNotEmpty && t2Words.isNotEmpty) {
      if (t1Words.last == t2Words.last) return true;
    }
    
    return false;
  }
  
  /// Get all available free odds for a sport
  Future<List<Map<String, dynamic>>> getAllFreeOdds(String sport) async {
    try {
      final response = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/${sport.toLowerCase()}/scoreboard'),
      );
      
      if (response.statusCode != 200) return [];
      
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      final allOdds = <Map<String, dynamic>>[];
      
      for (final event in events) {
        final odds = _extractOddsFromEspnEvent(event);
        if (odds.isNotEmpty) {
          // Add team names
          final competition = event['competitions']?[0];
          if (competition != null) {
            final competitors = competition['competitors'] ?? [];
            if (competitors.length >= 2) {
              odds['homeTeam'] = competitors[0]['team']?['displayName'] ?? 
                                 competitors[0]['athlete']?['displayName'];
              odds['awayTeam'] = competitors[1]['team']?['displayName'] ?? 
                                 competitors[1]['athlete']?['displayName'];
              odds['gameTime'] = event['date'];
              odds['status'] = competition['status']?['type']?['name'];
            }
          }
          
          allOdds.add(odds);
        }
      }
      
      return allOdds;
    } catch (e) {
      debugPrint('Error getting all free odds: $e');
      return [];
    }
  }
  
  /// Check if free odds are available for a sport
  Future<bool> hasOddsAvailable(String sport) async {
    final odds = await getAllFreeOdds(sport);
    return odds.isNotEmpty;
  }
}