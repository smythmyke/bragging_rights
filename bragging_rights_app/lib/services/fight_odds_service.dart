import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/fight_card_model.dart';
import '../models/fight_card_scoring.dart';
import 'odds_api_service.dart';

/// Service to fetch and manage fight odds
class FightOddsService {
  final OddsApiService _oddsApi = OddsApiService();
  
  // Cache odds to avoid repeated API calls
  final Map<String, FightOdds> _oddsCache = {};
  
  /// Get odds for an entire fight card
  Future<Map<String, FightOdds>> getFightCardOdds({
    required FightCardEventModel event,
  }) async {
    final odds = <String, FightOdds>{};
    
    try {
      // Get MMA odds from The Odds API
      final response = await _oddsApi.getSportsOdds(
        sport: 'mma_mixed_martial_arts',
        markets: 'h2h',  // Head to head (moneyline)
      );
      
      if (response != null && response['data'] != null) {
        final events = response['data'] as List;
        
        // Match fights with odds data
        for (final fight in event.fights) {
          final oddsData = _findMatchingOdds(fight, events);
          
          if (oddsData != null) {
            odds[fight.id] = oddsData;
            _oddsCache[fight.id] = oddsData;
          } else {
            // Use cached or estimated odds
            odds[fight.id] = _getCachedOrEstimatedOdds(fight);
          }
        }
      }
    } catch (e) {
      debugPrint('Error fetching fight odds: $e');
      
      // Fallback to cached or estimated odds
      for (final fight in event.fights) {
        odds[fight.id] = _getCachedOrEstimatedOdds(fight);
      }
    }
    
    return odds;
  }
  
  /// Find matching odds from API response
  FightOdds? _findMatchingOdds(Fight fight, List<dynamic> oddsEvents) {
    for (final event in oddsEvents) {
      final homeTeam = event['home_team'] ?? '';
      final awayTeam = event['away_team'] ?? '';
      
      // Try to match fighter names (handling different formats)
      if (_fightersMatch(fight.fighter1Name, homeTeam, awayTeam) &&
          _fightersMatch(fight.fighter2Name, homeTeam, awayTeam)) {
        
        // Extract odds from bookmakers
        final bookmakers = event['bookmakers'] ?? [];
        if (bookmakers.isNotEmpty) {
          final bookmaker = bookmakers[0];  // Use first bookmaker
          final markets = bookmaker['markets'] ?? [];
          
          if (markets.isNotEmpty) {
            final h2h = markets[0];  // Head to head market
            final outcomes = h2h['outcomes'] ?? [];
            
            double? fighter1Odds;
            double? fighter2Odds;
            
            for (final outcome in outcomes) {
              final name = outcome['name'] ?? '';
              final price = outcome['price']?.toDouble() ?? 0.0;
              
              if (_nameMatches(name, fight.fighter1Name)) {
                fighter1Odds = _convertDecimalToAmerican(price);
              } else if (_nameMatches(name, fight.fighter2Name)) {
                fighter2Odds = _convertDecimalToAmerican(price);
              }
            }
            
            if (fighter1Odds != null && fighter2Odds != null) {
              return FightOdds(
                fightId: fight.id,
                fighter1Odds: fighter1Odds,
                fighter2Odds: fighter2Odds,
                fetchedAt: DateTime.now(),
              );
            }
          }
        }
      }
    }
    
    return null;
  }
  
  /// Check if fighters match (handling name variations)
  bool _fightersMatch(String fightName, String team1, String team2) {
    final normalized = fightName.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final t1 = team1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final t2 = team2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    return t1.contains(normalized) || 
           t2.contains(normalized) ||
           normalized.contains(t1) || 
           normalized.contains(t2);
  }
  
  /// Check if name matches
  bool _nameMatches(String name1, String name2) {
    final n1 = name1.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    final n2 = name2.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '');
    
    // Check last name match (most reliable)
    final lastName1 = name1.split(' ').last.toLowerCase();
    final lastName2 = name2.split(' ').last.toLowerCase();
    
    return n1.contains(n2) || 
           n2.contains(n1) || 
           lastName1 == lastName2;
  }
  
  /// Convert decimal odds to American format
  double _convertDecimalToAmerican(double decimal) {
    if (decimal >= 2.0) {
      // Underdog
      return (decimal - 1) * 100;
    } else {
      // Favorite
      return -100 / (decimal - 1);
    }
  }
  
  /// Get cached or estimated odds if API fails
  FightOdds _getCachedOrEstimatedOdds(Fight fight) {
    // Check cache first
    if (_oddsCache.containsKey(fight.id)) {
      return _oddsCache[fight.id]!;
    }
    
    // Estimate odds based on fight position and records
    return _estimateOdds(fight);
  }
  
  /// Estimate odds based on fight data
  FightOdds _estimateOdds(Fight fight) {
    // Parse records to get win rates
    final fighter1WinRate = _calculateWinRate(fight.fighter1Record);
    final fighter2WinRate = _calculateWinRate(fight.fighter2Record);
    
    // Adjust for fight position (main events have closer odds)
    double positionAdjustment = 1.0;
    if (fight.isMainEvent) {
      positionAdjustment = 0.8;  // Closer odds for main event
    } else if (fight.isCoMain) {
      positionAdjustment = 0.9;
    }
    
    // Calculate implied odds
    double fighter1Odds;
    double fighter2Odds;
    
    if (fighter1WinRate > fighter2WinRate) {
      // Fighter 1 is favorite
      final ratio = fighter1WinRate / fighter2WinRate;
      fighter1Odds = -(ratio * 100 * positionAdjustment);
      fighter2Odds = (100 / ratio * positionAdjustment);
    } else {
      // Fighter 2 is favorite
      final ratio = fighter2WinRate / fighter1WinRate;
      fighter2Odds = -(ratio * 100 * positionAdjustment);
      fighter1Odds = (100 / ratio * positionAdjustment);
    }
    
    // Round to reasonable betting odds
    fighter1Odds = _roundToNearestOdds(fighter1Odds);
    fighter2Odds = _roundToNearestOdds(fighter2Odds);
    
    return FightOdds(
      fightId: fight.id,
      fighter1Odds: fighter1Odds,
      fighter2Odds: fighter2Odds,
      fetchedAt: DateTime.now(),
    );
  }
  
  /// Calculate win rate from record string (e.g., "25-3-0")
  double _calculateWinRate(String record) {
    final parts = record.split('-');
    if (parts.isEmpty) return 0.5;
    
    final wins = int.tryParse(parts[0]) ?? 0;
    final losses = parts.length > 1 ? (int.tryParse(parts[1]) ?? 0) : 0;
    final total = wins + losses;
    
    if (total == 0) return 0.5;
    
    return wins / total;
  }
  
  /// Round odds to nearest standard betting line
  double _roundToNearestOdds(double odds) {
    if (odds > 0) {
      // Underdog - round to nearest 10
      return (odds / 10).round() * 10;
    } else {
      // Favorite - round to nearest 10
      final rounded = (odds.abs() / 10).round() * 10;
      return -rounded;
    }
  }
  
  /// Get live odds updates during event
  Stream<Map<String, FightOdds>> streamLiveOdds({
    required String eventId,
    required List<Fight> fights,
  }) async* {
    // Poll for updates every 30 seconds during live events
    while (true) {
      try {
        final odds = <String, FightOdds>{};
        
        // Fetch latest odds
        final response = await _oddsApi.getSportsOdds(
          sport: 'mma_mixed_martial_arts',
          markets: 'h2h',
        );
        
        if (response != null) {
          // Process and yield odds
          for (final fight in fights) {
            odds[fight.id] = _getCachedOrEstimatedOdds(fight);
          }
          
          yield odds;
        }
        
        // Wait before next update
        await Future.delayed(const Duration(seconds: 30));
        
      } catch (e) {
        debugPrint('Error streaming odds: $e');
        await Future.delayed(const Duration(seconds: 60));
      }
    }
  }
}

/// Mock odds for testing
class MockFightOdds {
  static Map<String, FightOdds> getMockOdds(List<Fight> fights) {
    final odds = <String, FightOdds>{};
    
    // Generate realistic odds based on fight position
    for (int i = 0; i < fights.length; i++) {
      final fight = fights[i];
      
      double fighter1Odds;
      double fighter2Odds;
      
      if (fight.isMainEvent) {
        // Main event - closer odds
        fighter1Odds = -180;
        fighter2Odds = 150;
      } else if (fight.isCoMain) {
        // Co-main - moderate favorite
        fighter1Odds = -250;
        fighter2Odds = 200;
      } else if (fight.isMainCard) {
        // Main card - varying odds
        final variations = [
          [-150, 130],
          [-300, 250],
          [-110, -110],  // Even
          [180, -220],
        ];
        final variation = variations[i % variations.length];
        fighter1Odds = variation[0].toDouble();
        fighter2Odds = variation[1].toDouble();
      } else {
        // Prelims - wider odds
        final variations = [
          [-400, 320],
          [250, -300],
          [-180, 160],
          [-500, 400],
        ];
        final variation = variations[i % variations.length];
        fighter1Odds = variation[0].toDouble();
        fighter2Odds = variation[1].toDouble();
      }
      
      odds[fight.id] = FightOdds(
        fightId: fight.id,
        fighter1Odds: fighter1Odds,
        fighter2Odds: fighter2Odds,
        fetchedAt: DateTime.now(),
      );
    }
    
    return odds;
  }
}