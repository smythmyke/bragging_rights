import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import 'odds_api_service.dart';
import 'pool_auto_generator.dart';
import 'free_odds_service.dart';

/// Service that enriches games with odds data and auto-creates pools
class GameOddsEnrichmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final OddsApiService _oddsService = OddsApiService();
  final PoolAutoGenerator _poolGenerator = PoolAutoGenerator();
  final FreeOddsService _freeOddsService = FreeOddsService();
  
  // Cache for tracking last odds fetch time per game
  static final Map<String, DateTime> _lastOddsFetchTime = {};
  static const Duration _oddsFetchDebounce = Duration(seconds: 30);
  
  // Track ongoing fetch operations to prevent duplicates
  static final Map<String, Future<void>> _ongoingFetches = {};
  
  /// Enrich a game with odds data and create pools
  Future<void> enrichGameWithOdds(GameModel game) async {
    try {
      debugPrint('🎲 ========== ENRICH GAME WITH ODDS CALLED ==========');
      debugPrint('🎲 Game: ${game.awayTeam} @ ${game.homeTeam}');
      debugPrint('🎲 Sport: ${game.sport}');
      debugPrint('🎲 Status: ${game.status}');
      debugPrint('🎲 Days until game: ${game.gameTime.difference(DateTime.now()).inDays}');

      // Skip if game is not scheduled or too far in future
      if (game.status != 'scheduled') {
        debugPrint('🎲 ❌ Skipping - game status is not scheduled: ${game.status}');
        return;
      }
      if (game.gameTime.difference(DateTime.now()).inDays > 7) {
        debugPrint('🎲 ❌ Skipping - game is more than 7 days away');
        return;
      }
      
      // Check if there's already an ongoing fetch for this game
      if (_ongoingFetches.containsKey(game.id)) {
        debugPrint('⏳ Already fetching odds for ${game.id} - waiting for existing fetch');
        await _ongoingFetches[game.id];
        return;
      }
      
      // Debounce: Check if we've fetched odds for this game recently
      final lastFetch = _lastOddsFetchTime[game.id];
      if (lastFetch != null && 
          DateTime.now().difference(lastFetch) < _oddsFetchDebounce) {
        debugPrint('⏳ Skipping odds fetch for ${game.id} - fetched ${DateTime.now().difference(lastFetch).inSeconds}s ago');
        return;
      }
      
      // Create and store the fetch operation
      final fetchOperation = _performOddsFetch(game);
      _ongoingFetches[game.id] = fetchOperation;
      
      try {
        await fetchOperation;
      } finally {
        _ongoingFetches.remove(game.id);
      }
    } catch (e) {
      debugPrint('Error enriching game with odds: $e');
    }
  }
  
  Future<void> _performOddsFetch(GameModel game) async {
    try {
      // Update last fetch time
      _lastOddsFetchTime[game.id] = DateTime.now();
      
      // Fetch odds from SportsGameOdds API
      final odds = await _fetchOddsForGame(game);
      
      if (odds != null && odds.isNotEmpty) {
        // Determine what odds are available
        final hasMoneyline = odds.containsKey('moneyline');
        final hasSpread = odds.containsKey('spread');
        final hasTotal = odds.containsKey('total');
        
        // Save whatever odds we have
        await _firestore.collection('games').doc(game.id).update({
          'odds': odds,
          'oddsAvailable': {
            'moneyline': hasMoneyline,
            'spread': hasSpread,
            'total': hasTotal,
          },
          'oddsLastUpdated': FieldValue.serverTimestamp(),
        });
        
        debugPrint('✅ Added odds to game ${game.id}: ${game.awayTeam} @ ${game.homeTeam}');
        debugPrint('   Available: ML=$hasMoneyline, Spread=$hasSpread, Total=$hasTotal');
      } else {
        debugPrint('📊 ❌ No odds returned from API');
        debugPrint('📊 This could mean:');
        debugPrint('📊   1. No matching game found');
        debugPrint('📊   2. Sport key not recognized');
        debugPrint('📊   3. Team name mismatch');

        // No odds at all - still save the game but mark odds as unavailable
        await _firestore.collection('games').doc(game.id).update({
          'oddsAvailable': {
            'moneyline': false,
            'spread': false,
            'total': false,
          },
          'oddsLastUpdated': FieldValue.serverTimestamp(),
        });

        debugPrint('📊 ⚠️ Marked game as having no odds: ${game.awayTeam} @ ${game.homeTeam}');
      }

      debugPrint('📊 ========== ODDS FETCH END ==========');
      
      // Auto-create pools for this game
      await _poolGenerator.generateGamePools(
        game: game,
      );
      
    } catch (e) {
      debugPrint('Error enriching game with odds: $e');
    }
  }
  
  /// Fetch odds from SportsGameOdds API with FreeOddsService fallback
  Future<Map<String, dynamic>?> _fetchOddsForGame(GameModel game) async {
    try {
      // Try The Odds API first (now with correct API key from .env)
      debugPrint('📊 ========== ODDS FETCH START ==========');
      debugPrint('📊 Game: ${game.awayTeam} @ ${game.homeTeam}');
      debugPrint('📊 Sport: ${game.sport} (will be lowercased to: ${game.sport.toLowerCase()})');
      debugPrint('📊 Game ID: ${game.id}');
      debugPrint('📊 Game Time: ${game.gameTime}');
      debugPrint('📊 Attempting to fetch odds from The Odds API...');

      final odds = await _oddsService.getMatchOdds(
        sport: game.sport.toLowerCase(),
        homeTeam: game.homeTeam,
        awayTeam: game.awayTeam,
      );

      debugPrint('📊 Odds API response received: ${odds != null ? "SUCCESS" : "NULL"}');
      
      if (odds != null && odds.isNotEmpty) {
        debugPrint('📊 ✅ Got odds from The Odds API');
        debugPrint('📊 Raw odds response keys: ${odds.keys.toList()}');
        debugPrint('📊 Full odds response: $odds');

        // Extract the odds from the response and convert to standard format
        final oddsData = odds['odds'] ?? {};
        debugPrint('📊 Extracted odds data: $oddsData');

        final h2h = oddsData['h2h'] ?? {};
        final spreads = oddsData['spreads'] ?? {};
        final totals = oddsData['totals'] ?? {};

        debugPrint('📊 h2h (moneyline): $h2h');
        debugPrint('📊 spreads: $spreads');
        debugPrint('📊 totals: $totals');

        final standardOdds = <String, dynamic>{};

        // Convert h2h (moneyline) odds - fixed to access nested structure correctly
        if (h2h.isNotEmpty) {
          final homeOdds = h2h['home'];
          final awayOdds = h2h['away'];

          if (homeOdds != null && awayOdds != null) {
            // Check if odds is a map with 'odds' field or a direct number
            final homeOddsValue = (homeOdds is Map) ? homeOdds['odds'] : homeOdds;
            final awayOddsValue = (awayOdds is Map) ? awayOdds['odds'] : awayOdds;

            if (homeOddsValue != null && awayOddsValue != null) {
              standardOdds['moneyline'] = {
                'home': homeOddsValue,
                'away': awayOddsValue,
              };
              debugPrint('   Added moneyline: home=$homeOddsValue, away=$awayOddsValue');
            }
          }
        }

        // Convert spread odds
        if (spreads.isNotEmpty && spreads['outcomes'] != null) {
          final spreadOutcomes = spreads['outcomes'] as List;
          if (spreadOutcomes.isNotEmpty) {
            final homeSpread = spreadOutcomes.firstWhere(
              (o) => o['name'] == odds['home_team'],
              orElse: () => spreadOutcomes.first,
            );
            final awaySpread = spreadOutcomes.firstWhere(
              (o) => o['name'] == odds['away_team'],
              orElse: () => spreadOutcomes.last,
            );

            standardOdds['spread'] = {
              'points': homeSpread['point'] ?? 0,
              'homeOdds': homeSpread['price'] ?? -110,
              'awayOdds': awaySpread['price'] ?? -110,
            };
            debugPrint('   Added spread: points=${homeSpread['point']}');
          }
        }

        // Convert totals odds
        if (totals.isNotEmpty && totals['outcomes'] != null) {
          final totalOutcomes = totals['outcomes'] as List;
          if (totalOutcomes.isNotEmpty) {
            final overOutcome = totalOutcomes.firstWhere(
              (o) => o['name'] == 'Over',
              orElse: () => totalOutcomes.first,
            );
            final underOutcome = totalOutcomes.firstWhere(
              (o) => o['name'] == 'Under',
              orElse: () => totalOutcomes.last,
            );

            standardOdds['total'] = {
              'points': overOutcome['point'] ?? 0,
              'overOdds': overOutcome['price'] ?? -110,
              'underOdds': underOutcome['price'] ?? -110,
            };
            debugPrint('   Added total: points=${overOutcome['point']}');
          }
        }

        debugPrint('   Final standardOdds: $standardOdds');
        return standardOdds.isNotEmpty ? standardOdds : null;
      }
      
      // Fall back to FreeOddsService (ESPN) if The Odds API doesn't have data
      debugPrint('📊 Fetching odds from ESPN for ${game.awayTeam} @ ${game.homeTeam}');
      final freeOdds = await _freeOddsService.getFreeOdds(
        sport: game.sport.toLowerCase(),
        homeTeam: game.homeTeam,
        awayTeam: game.awayTeam,
        eventId: game.id,
      );
      
      if (freeOdds != null && freeOdds.isNotEmpty) {
        debugPrint('✅ Got odds from FreeOddsService (ESPN)');
        // Convert to standard format if needed
        final standardOdds = {
          'moneyline': {
            'home': freeOdds['moneylineHome'],
            'away': freeOdds['moneylineAway'],
          },
          'spread': freeOdds['spread'] != null ? {
            'points': freeOdds['spread'],
            'homeOdds': freeOdds['spreadHomeOdds'] ?? -110,
            'awayOdds': freeOdds['spreadAwayOdds'] ?? -110,
          } : null,
          'total': freeOdds['total'] != null ? {
            'points': freeOdds['total'],
            'overOdds': freeOdds['overOdds'] ?? -110,
            'underOdds': freeOdds['underOdds'] ?? -110,
          } : null,
          'source': 'espn',  // Track the source
        };
        return standardOdds;
      }
      
      debugPrint('❌ No odds available from any source for ${game.awayTeam} @ ${game.homeTeam}');
      return null;
    } catch (e) {
      debugPrint('Error fetching odds: $e');
      return null;
    }
  }
  
  /// Batch enrich multiple games
  Future<void> enrichGamesWithOdds(List<GameModel> games) async {
    debugPrint('🎲 Enriching ${games.length} games with odds...');
    
    // Process in small batches to avoid rate limits
    const batchSize = 5;
    for (int i = 0; i < games.length; i += batchSize) {
      final batch = games.skip(i).take(batchSize).toList();
      
      await Future.wait(
        batch.map((game) => enrichGameWithOdds(game)),
      );
      
      // Small delay between batches to respect rate limits
      if (i + batchSize < games.length) {
        await Future.delayed(const Duration(seconds: 1));
      }
    }
    
    debugPrint('✅ Finished enriching games with odds');
  }
}