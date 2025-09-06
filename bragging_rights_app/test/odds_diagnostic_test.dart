import 'package:flutter_test/flutter_test.dart';
import 'package:bragging_rights_app/services/sports_game_odds_service.dart';
import 'package:bragging_rights_app/services/free_odds_service.dart';
import 'package:bragging_rights_app/services/sports_api_service.dart';
import 'package:bragging_rights_app/services/game_odds_enrichment_service.dart';
import 'package:bragging_rights_app/models/game_model.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

void main() {
  group('Odds Data Pipeline Diagnostic Tests', () {
    late SportsGameOddsService oddsService;
    late FreeOddsService freeOddsService;
    late SportsApiService sportsApiService;
    late GameOddsEnrichmentService enrichmentService;
    
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      
      // Initialize services
      oddsService = SportsGameOddsService();
      freeOddsService = FreeOddsService();
      sportsApiService = SportsApiService();
      enrichmentService = GameOddsEnrichmentService();
    });

    test('1. Test The Odds API directly for NFL', () async {
      print('\n=== Testing The Odds API for NFL ===');
      
      try {
        // Test with Tampa Bay Buccaneers @ Atlanta Falcons
        final odds = await oddsService.findMatchOdds(
          sport: 'nfl',
          homeTeam: 'Atlanta Falcons',
          awayTeam: 'Tampa Bay Buccaneers',
        );
        
        if (odds != null && odds.isNotEmpty) {
          print('✅ The Odds API returned data:');
          print('   Moneyline: ${odds['moneyline']}');
          print('   Spread: ${odds['spread']}');
          print('   Total: ${odds['total']}');
        } else {
          print('❌ The Odds API returned no data');
          print('   This could mean:');
          print('   - API key is invalid or quota exceeded');
          print('   - Game not found in API');
          print('   - API is down');
        }
      } catch (e) {
        print('❌ The Odds API error: $e');
      }
    });

    test('2. Test FreeOddsService (ESPN) fallback', () async {
      print('\n=== Testing FreeOddsService (ESPN) for NFL ===');
      
      try {
        final odds = await freeOddsService.getFreeOdds(
          sport: 'nfl',
          homeTeam: 'Atlanta Falcons',
          awayTeam: 'Tampa Bay Buccaneers',
          eventId: 'test_event_id',
        );
        
        if (odds != null && odds.isNotEmpty) {
          print('✅ FreeOddsService returned data:');
          print('   Moneyline Home: ${odds['moneylineHome']}');
          print('   Moneyline Away: ${odds['moneylineAway']}');
          print('   Spread: ${odds['spread']}');
          print('   Total: ${odds['total']}');
        } else {
          print('❌ FreeOddsService returned no data');
          print('   ESPN may not have odds for this game');
        }
      } catch (e) {
        print('❌ FreeOddsService error: $e');
      }
    });

    test('3. Test complete odds enrichment pipeline', () async {
      print('\n=== Testing Complete Odds Enrichment Pipeline ===');
      
      // Create a test game
      final testGame = GameModel(
        id: 'test_tampa_atlanta',
        sport: 'NFL',
        homeTeam: 'Atlanta Falcons',
        awayTeam: 'Tampa Bay Buccaneers',
        gameTime: DateTime.now().add(Duration(hours: 2)),
        status: 'scheduled',
      );
      
      try {
        await enrichmentService.enrichGameWithOdds(testGame);
        print('✅ Enrichment pipeline completed');
        print('   Check Firestore for saved odds');
      } catch (e) {
        print('❌ Enrichment pipeline error: $e');
      }
    });

    test('4. Test all NFL games odds retrieval', () async {
      print('\n=== Testing All NFL Games Odds ===');
      
      try {
        // Get all today's NFL games
        final games = await sportsApiService.getTodaysGames('NFL');
        
        print('Found ${games.length} NFL games today');
        
        for (final game in games.take(3)) { // Test first 3 games
          print('\nGame: ${game.awayTeam} @ ${game.homeTeam}');
          
          // Try The Odds API
          final theOddsApiResult = await oddsService.findMatchOdds(
            sport: 'nfl',
            homeTeam: game.homeTeam,
            awayTeam: game.awayTeam,
          );
          
          if (theOddsApiResult != null && theOddsApiResult.isNotEmpty) {
            print('  ✅ The Odds API: Has odds');
          } else {
            print('  ❌ The Odds API: No odds');
          }
          
          // Try FreeOddsService
          final freeOddsResult = await freeOddsService.getFreeOdds(
            sport: 'nfl',
            homeTeam: game.homeTeam,
            awayTeam: game.awayTeam,
            eventId: game.id,
          );
          
          if (freeOddsResult != null && freeOddsResult.isNotEmpty) {
            print('  ✅ FreeOddsService: Has odds');
          } else {
            print('  ❌ FreeOddsService: No odds');
          }
          
          // Check Firestore
          final oddsFromFirestore = await sportsApiService.getGameOdds(game.id);
          if (oddsFromFirestore != null) {
            print('  ✅ Firestore: Has cached odds');
          } else {
            print('  ❌ Firestore: No cached odds');
          }
        }
      } catch (e) {
        print('❌ Error testing NFL games: $e');
      }
    });

    test('5. Diagnose betting page data flow', () async {
      print('\n=== Diagnosing Betting Page Data Flow ===');
      
      // Simulate what happens when betting page loads
      print('1. Betting page loads for game: Tampa Bay @ Atlanta');
      
      // Step 1: Check if game exists
      final games = await sportsApiService.getTodaysGames('NFL');
      final tampaGame = games.firstWhere(
        (g) => g.homeTeam.contains('Atlanta') && g.awayTeam.contains('Tampa'),
        orElse: () => GameModel(
          id: 'not_found',
          sport: 'NFL',
          homeTeam: 'Not Found',
          awayTeam: 'Not Found',
          gameTime: DateTime.now(),
          status: 'unknown',
        ),
      );
      
      if (tampaGame.id != 'not_found') {
        print('  ✅ Game found in system');
        
        // Step 2: Try to get odds
        print('\n2. Attempting to fetch odds...');
        final odds = await sportsApiService.getGameOdds(tampaGame.id);
        
        if (odds != null) {
          print('  ✅ Odds retrieved successfully');
          print('     Home Moneyline: ${odds.homeMoneyline}');
          print('     Away Moneyline: ${odds.awayMoneyline}');
          print('     Spread: ${odds.spread}');
          print('     Total: ${odds.totalPoints}');
        } else {
          print('  ❌ No odds available');
          print('     Betting page will show mock data or empty state');
        }
      } else {
        print('  ❌ Game not found in system');
        print('     This would cause betting page to fail');
      }
    });

    test('6. Test API keys and configuration', () async {
      print('\n=== Testing API Configuration ===');
      
      // Test The Odds API key
      print('Testing The Odds API key...');
      try {
        final testResult = await oddsService.testApiConnection();
        if (testResult) {
          print('  ✅ The Odds API key is valid');
        } else {
          print('  ❌ The Odds API key is invalid or quota exceeded');
        }
      } catch (e) {
        print('  ❌ Error testing API: $e');
      }
      
      // Test ESPN endpoints (no key required)
      print('\nTesting ESPN endpoints...');
      try {
        final allOdds = await freeOddsService.getAllFreeOdds('nfl');
        if (allOdds.isNotEmpty) {
          print('  ✅ ESPN API is accessible');
          print('     Found ${allOdds.length} games with odds');
        } else {
          print('  ⚠️ ESPN API accessible but no odds available');
        }
      } catch (e) {
        print('  ❌ ESPN API error: $e');
      }
    });
  });
}