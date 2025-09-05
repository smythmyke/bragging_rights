import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';
import 'sports_game_odds_service.dart';
import 'pool_auto_generator.dart';

/// Service that enriches games with odds data and auto-creates pools
class GameOddsEnrichmentService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final SportsGameOddsService _oddsService = SportsGameOddsService();
  final PoolAutoGenerator _poolGenerator = PoolAutoGenerator();
  
  /// Enrich a game with odds data and create pools
  Future<void> enrichGameWithOdds(GameModel game) async {
    try {
      // Skip if game is not scheduled or too far in future
      if (game.status != 'scheduled') return;
      if (game.gameTime.difference(DateTime.now()).inDays > 7) return;
      
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
        // No odds at all - still save the game but mark odds as unavailable
        await _firestore.collection('games').doc(game.id).update({
          'oddsAvailable': {
            'moneyline': false,
            'spread': false,
            'total': false,
          },
          'oddsLastUpdated': FieldValue.serverTimestamp(),
        });
        
        debugPrint('⚠️ No odds available for game ${game.id}: ${game.awayTeam} @ ${game.homeTeam}');
      }
      
      // Auto-create pools for this game
      await _poolGenerator.generateGamePools(
        game: game,
      );
      
    } catch (e) {
      debugPrint('Error enriching game with odds: $e');
    }
  }
  
  /// Fetch odds from SportsGameOdds API
  Future<Map<String, dynamic>?> _fetchOddsForGame(GameModel game) async {
    try {
      // Use the new findMatchOdds method which handles matching internally
      final odds = await _oddsService.findMatchOdds(
        sport: game.sport.toLowerCase(),
        homeTeam: game.homeTeam,
        awayTeam: game.awayTeam,
      );
      
      return odds;
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