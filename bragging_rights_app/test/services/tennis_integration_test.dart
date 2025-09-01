import 'package:flutter_test/flutter_test.dart';
import 'package:bragging_rights_app/services/edge/sports/espn_tennis_service.dart';
import 'package:bragging_rights_app/services/edge/sports/tennis_multi_api_service.dart';
import 'package:bragging_rights_app/services/free_odds_service.dart';
import 'package:bragging_rights_app/models/enhanced_game_model.dart';
import 'package:bragging_rights_app/models/participant_model.dart';

void main() {
  group('Tennis Integration Tests - Live Data', () {
    late EspnTennisService espnService;
    late TennisMultiApiService multiApiService;
    late FreeOddsService freeOddsService;

    setUp(() {
      espnService = EspnTennisService();
      multiApiService = TennisMultiApiService();
      freeOddsService = FreeOddsService();
    });

    test('ESPN Tennis Service - Get Live Scoreboard', () async {
      print('\n=== Testing ESPN Tennis Live Scoreboard ===');
      
      final scoreboard = await espnService.getScoreboard();
      
      expect(scoreboard, isNotNull, 
        reason: 'ESPN Tennis API should return scoreboard data');
      
      if (scoreboard != null) {
        print('Leagues: ${scoreboard.leagues.length} active tournaments');
        print('Total Matches: ${scoreboard.matches.length}');
        
        if (scoreboard.matches.isNotEmpty) {
          final match = scoreboard.matches.first;
          print('\nFirst Match:');
          print('  ${match.player1['name']} vs ${match.player2['name']}');
          print('  Status: ${match.status}');
          print('  Score: ${match.score}');
          
          // Verify data structure
          expect(match.player1['name'], isNotNull);
          expect(match.player2['name'], isNotNull);
          expect(match.status, isNotNull);
        }
      }
    });

    test('ESPN Tennis Service - Get ATP Rankings', () async {
      print('\n=== Testing ATP Rankings ===');
      
      final rankings = await espnService.getATPRankings();
      
      expect(rankings, isNotNull,
        reason: 'Should retrieve ATP rankings');
      
      if (rankings != null) {
        final competitors = rankings['rankings']?['competitors'] as List?;
        if (competitors != null && competitors.isNotEmpty) {
          print('Top 5 ATP Players:');
          for (int i = 0; i < 5 && i < competitors.length; i++) {
            final player = competitors[i];
            final athlete = player['athlete'];
            print('  #${player['rank']}: ${athlete['displayName']}');
          }
        }
      }
    });

    test('ESPN Tennis Service - Get WTA Rankings', () async {
      print('\n=== Testing WTA Rankings ===');
      
      final rankings = await espnService.getWTARankings();
      
      expect(rankings, isNotNull,
        reason: 'Should retrieve WTA rankings');
      
      if (rankings != null) {
        final competitors = rankings['rankings']?['competitors'] as List?;
        if (competitors != null && competitors.isNotEmpty) {
          print('Top 5 WTA Players:');
          for (int i = 0; i < 5 && i < competitors.length; i++) {
            final player = competitors[i];
            final athlete = player['athlete'];
            print('  #${player['rank']}: ${athlete['displayName']}');
          }
        }
      }
    });

    test('Tennis Multi-API Service - Get Matches with Fallback', () async {
      print('\n=== Testing Multi-API Service ===');
      
      final matches = await multiApiService.getTennisMatches();
      
      expect(matches, isNotNull,
        reason: 'Multi-API service should return matches');
      
      print('Retrieved ${matches.length} matches from multi-source');
      
      if (matches.isNotEmpty) {
        final match = matches.first;
        print('\nSample Match:');
        print('  Players: ${match['player1']} vs ${match['player2']}');
        print('  Tournament: ${match['tournament']}');
        print('  Status: ${match['status']}');
        print('  Source: ${match['source']}');
      }
    });

    test('Enhanced Game Model - Tennis Participant Display', () async {
      print('\n=== Testing Tennis Participant Display ===');
      
      // Create test tennis match with individual participants
      final game = EnhancedGameModel(
        id: 'test-tennis-1',
        sport: 'tennis',
        homeParticipant: Participant.individual(
          id: 'djokovic',
          name: 'Novak Djokovic',
          ranking: 1,
          country: '🇷🇸',
        ),
        awayParticipant: Participant.individual(
          id: 'alcaraz',
          name: 'Carlos Alcaraz',
          ranking: 2,
          country: '🇪🇸',
        ),
        gameTime: DateTime.now().add(Duration(hours: 2)),
        status: 'scheduled',
        venue: 'Centre Court, Wimbledon',
        tournament: 'Wimbledon',
        round: 'Finals',
      );
      
      // Verify participant display
      expect(game.homeParticipant.isIndividualSport, isTrue,
        reason: 'Tennis should be recognized as individual sport');
      expect(game.awayParticipant.isIndividualSport, isTrue);
      
      expect(game.versusText, equals('vs'),
        reason: 'Individual sports should show "vs" not "@"');
      
      expect(game.homeParticipant.displayName, equals('Novak Djokovic'));
      expect(game.homeParticipant.ranking, equals(1));
      expect(game.homeParticipant.country, equals('🇷🇸'));
      
      print('Participant Display Test:');
      print('  Home: ${game.homeParticipant.displayName} (#${game.homeParticipant.ranking})');
      print('  Away: ${game.awayParticipant.displayName} (#${game.awayParticipant.ranking})');
      print('  Versus Text: ${game.versusText}');
      print('  Short Title: ${game.shortTitle}');
    });

    test('Free Odds Service - Tennis Fallback', () async {
      print('\n=== Testing Free Odds Fallback for Tennis ===');
      
      final odds = await freeOddsService.getFreeOdds(
        sport: 'tennis',
        homeTeam: 'Djokovic',
        awayTeam: 'Alcaraz',
      );
      
      if (odds != null) {
        print('Free Odds Retrieved:');
        print('  Source: ${odds['source']}');
        print('  Provider: ${odds['provider'] ?? 'ESPN'}');
        
        if (odds['spread'] != null) {
          print('  Spread: ${odds['spread']}');
        }
        if (odds['homeMoneyline'] != null) {
          print('  Home ML: ${odds['homeMoneyline']}');
        }
        if (odds['awayMoneyline'] != null) {
          print('  Away ML: ${odds['awayMoneyline']}');
        }
      } else {
        print('No odds available (match may not be scheduled)');
      }
    });

    test('Tournament Coverage Test', () async {
      print('\n=== Testing Tournament Coverage ===');
      
      final scoreboard = await espnService.getScoreboard();
      
      if (scoreboard != null && scoreboard.leagues.isNotEmpty) {
        print('Active Tournaments:');
        final uniqueTournaments = <String>{};
        
        for (final league in scoreboard.leagues) {
          uniqueTournaments.add(league['name'] ?? 'Unknown');
        }
        
        for (final tournament in uniqueTournaments) {
          print('  - $tournament');
        }
        
        expect(uniqueTournaments.isNotEmpty, isTrue,
          reason: 'Should have at least one active tournament');
      }
    });

    test('Data Completeness Check', () async {
      print('\n=== Testing Data Completeness ===');
      
      final scoreboard = await espnService.getScoreboard();
      
      if (scoreboard != null && scoreboard.matches.isNotEmpty) {
        final match = scoreboard.matches.first;
        
        // Check what data is available
        print('Available Data Fields:');
        print('  ✓ Player Names: ${match.player1['name'] != null}');
        print('  ✓ Rankings: ${match.player1['rank'] != null}');
        print('  ✓ Status: ${match.status != null}');
        print('  ✓ Score: ${match.score != null}');
        print('  ✓ Tournament: ${scoreboard.leagues.isNotEmpty}');
        print('  ✓ Round: ${match.metadata?['round'] != null}');
        print('  ✓ Venue: ${match.venue != null}');
        
        // Note missing data
        print('\nMissing Data (need alternative sources):');
        print('  ✗ H2H Records');
        print('  ✗ Surface Statistics');
        print('  ✗ Recent Form (last 5 matches)');
        print('  ✗ Injury Status');
        
        print('\nFallback Strategy:');
        print('  - H2H: Use API-Sports.io when available');
        print('  - Surface Stats: Mock or use historical averages');
        print('  - Form: Calculate from recent match results');
        print('  - Injuries: Web scraping from tennis news sites');
      }
    });

    test('Performance Test - API Response Times', () async {
      print('\n=== Testing API Performance ===');
      
      final stopwatch = Stopwatch()..start();
      
      // Test ESPN response time
      stopwatch.reset();
      await espnService.getScoreboard();
      final espnTime = stopwatch.elapsedMilliseconds;
      print('ESPN Scoreboard: ${espnTime}ms');
      
      // Test rankings response time
      stopwatch.reset();
      await espnService.getATPRankings();
      final rankingsTime = stopwatch.elapsedMilliseconds;
      print('ATP Rankings: ${rankingsTime}ms');
      
      // Test multi-API service
      stopwatch.reset();
      await multiApiService.getTennisMatches();
      final multiApiTime = stopwatch.elapsedMilliseconds;
      print('Multi-API Service: ${multiApiTime}ms');
      
      // Test free odds
      stopwatch.reset();
      await freeOddsService.getAllFreeOdds('tennis');
      final oddsTime = stopwatch.elapsedMilliseconds;
      print('Free Odds Service: ${oddsTime}ms');
      
      // Performance assertions
      expect(espnTime, lessThan(5000),
        reason: 'ESPN should respond within 5 seconds');
      expect(rankingsTime, lessThan(5000),
        reason: 'Rankings should load within 5 seconds');
      
      print('\nTotal API calls: 4');
      print('Average response time: ${(espnTime + rankingsTime + multiApiTime + oddsTime) ~/ 4}ms');
    });
  });
}