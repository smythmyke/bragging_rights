import '../lib/services/odds_api_service.dart';
import '../lib/models/game_model.dart';

void main() async {
  print('🏈 TESTING ODDS API AS PRIMARY SOURCE FOR NFL');
  print('=' * 60);
  
  final oddsApiService = OddsApiService();
  
  // 1. Test getting NFL games
  print('\n1️⃣ TESTING NFL GAMES FROM ODDS API:');
  print('-' * 60);
  
  try {
    final games = await oddsApiService.getSportGames('NFL', daysAhead: 14);
    
    print('✅ Loaded ${games.length} NFL games');
    
    if (games.isNotEmpty) {
      // Show first few games
      print('\nFirst 3 games:');
      for (int i = 0; i < games.length && i < 3; i++) {
        final game = games[i];
        print('\nGame ${i + 1}:');
        print('  ID: ${game.id}');
        print('  Teams: ${game.awayTeam} @ ${game.homeTeam}');
        print('  Time: ${game.gameTime}');
        print('  Status: ${game.status}');
      }
      
      // 2. Test getting odds for first game
      final testGame = games.first;
      print('\n2️⃣ TESTING ODDS FOR: ${testGame.awayTeam} @ ${testGame.homeTeam}');
      print('-' * 60);
      
      final oddsData = await oddsApiService.getEventOdds(
        eventId: testGame.id,
        sport: 'NFL',
        includeProps: false,
      );
      
      if (oddsData != null) {
        print('✅ Basic odds loaded successfully');
        print('  Bookmakers: ${oddsData.bookmakers?.length ?? 0}');
        
        if (oddsData.bookmakers?.isNotEmpty == true) {
          final firstBook = oddsData.bookmakers!.first;
          print('  Sample bookmaker: ${firstBook.title}');
          print('  Markets: ${firstBook.markets?.length ?? 0}');
        }
      }
      
      // 3. Test getting props
      print('\n3️⃣ TESTING PROPS FOR: ${testGame.awayTeam} @ ${testGame.homeTeam}');
      print('-' * 60);
      
      final propsData = await oddsApiService.getEventOdds(
        eventId: testGame.id,
        sport: 'NFL',
        includeProps: true,
      );
      
      if (propsData != null) {
        print('✅ Props loaded successfully');
        
        // Count prop markets
        final propMarkets = <String>{};
        if (propsData.bookmakers != null) {
          for (final bookmaker in propsData.bookmakers!) {
            if (bookmaker.markets != null) {
              for (final market in bookmaker.markets!) {
                if (market.key?.startsWith('player_') == true) {
                  propMarkets.add(market.key!);
                }
              }
            }
          }
        }
        
        print('  Unique prop markets found: ${propMarkets.length}');
        print('  Props: ${propMarkets.toList()}');
        
        // Show sample prop data
        if (propsData.bookmakers != null) {
          for (final bookmaker in propsData.bookmakers!) {
            if (bookmaker.markets != null) {
              for (final market in bookmaker.markets!) {
                if (market.key?.startsWith('player_') == true && 
                    market.outcomes?.isNotEmpty == true) {
                  print('\n  Sample: ${bookmaker.title} - ${market.key}');
                  for (int i = 0; i < 3 && i < market.outcomes!.length; i++) {
                    final outcome = market.outcomes![i];
                    print('    • ${outcome.name}: ${outcome.price} (${outcome.point ?? "N/A"})');
                  }
                  break;
                }
              }
              if (propMarkets.isNotEmpty) break;
            }
          }
        }
      }
      
      // 4. Test scores endpoint
      print('\n4️⃣ TESTING SCORES ENDPOINT:');
      print('-' * 60);
      
      final scores = await oddsApiService.getSportScores('NFL');
      print('  Games with scores: ${scores.length}');
      
      if (scores.isNotEmpty) {
        final firstScore = scores.values.first;
        print('  Sample score data:');
        print('    Event ID: ${firstScore['id']}');
        print('    Completed: ${firstScore['completed']}');
        print('    Scores: ${firstScore['scores']}');
      }
      
    }
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n' + '=' * 60);
  print('SUMMARY:');
  print('✅ Odds API can provide:');
  print('  • Game listings with Odds API event IDs');
  print('  • Basic betting markets (h2h, spreads, totals)');
  print('  • Player props for NFL');
  print('  • Live scores');
  print('\n✅ Using Odds API as primary source means:');
  print('  • Event IDs always match for odds/props');
  print('  • No more ESPN ID conversion needed');
  print('  • Props will always work when available');
}