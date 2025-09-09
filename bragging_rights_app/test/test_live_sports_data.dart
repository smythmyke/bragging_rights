import '../lib/services/odds_api_service.dart';
import '../lib/services/optimized_games_service.dart';
import '../lib/models/game_model.dart';

/// Comprehensive live data test for all sports
/// Tests the full data flow as the app uses it
void main() async {
  print('🏆 COMPREHENSIVE LIVE SPORTS DATA TEST');
  print('=' * 60);
  
  final oddsApiService = OddsApiService();
  final gamesService = OptimizedGamesService();
  
  // Sports to test
  final sports = {
    'MLB': '⚾',
    'NFL': '🏈', 
    'NBA': '🏀',
    'NHL': '🏒',
    'MMA': '🥊',
    'Boxing': '🥊',
    'Tennis': '🎾',
  };
  
  for (final entry in sports.entries) {
    final sport = entry.key;
    final emoji = entry.value;
    
    print('\n$emoji TESTING $sport');
    print('-' * 60);
    
    try {
      // 1. Test game retrieval (as Games page does)
      print('\n1️⃣ Getting games from OptimizedGamesService...');
      final games = await gamesService.getGamesForSport(sport);
      print('   ✅ Found ${games.length} $sport games');
      
      if (games.isEmpty) {
        print('   ⚠️ No games available for $sport');
        continue;
      }
      
      // Show first game details
      final firstGame = games.first;
      print('\n   First game:');
      print('   • ID: ${firstGame.id}');
      print('   • Teams: ${firstGame.awayTeam} @ ${firstGame.homeTeam}');
      print('   • Time: ${firstGame.gameTime}');
      print('   • Status: ${firstGame.status}');
      
      // 2. Test betting data retrieval (as BetSelection screen does)
      print('\n2️⃣ Getting betting data...');
      final oddsData = await oddsApiService.getEventOdds(
        eventId: firstGame.id,
        sport: sport,
        includeProps: true,
      );
      
      if (oddsData != null) {
        final bookmakers = oddsData['bookmakers'] as List? ?? [];
        print('   ✅ Found ${bookmakers.length} bookmakers');
        
        // Count markets
        final marketTypes = <String>{};
        final propMarkets = <String>{};
        
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] as List? ?? [];
          for (final market in markets) {
            final key = market['key'] as String;
            marketTypes.add(key);
            
            // Check for props
            if (key.startsWith('player_') || 
                key.startsWith('batter_') || 
                key.startsWith('pitcher_')) {
              propMarkets.add(key);
            }
          }
        }
        
        print('\n   📊 Market Analysis:');
        print('   • Basic markets: ${marketTypes.contains('h2h') ? '✅' : '❌'} Moneyline, ${marketTypes.contains('spreads') ? '✅' : '❌'} Spread, ${marketTypes.contains('totals') ? '✅' : '❌'} Total');
        print('   • Prop markets: ${propMarkets.length} types');
        if (propMarkets.isNotEmpty) {
          print('   • Props available: ${propMarkets.take(3).join(', ')}${propMarkets.length > 3 ? '...' : ''}');
        }
        
        // Test for type issues
        print('\n3️⃣ Testing data types...');
        bool hasTypeIssues = false;
        
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] as List? ?? [];
          for (final market in markets) {
            final outcomes = market['outcomes'] as List? ?? [];
            for (final outcome in outcomes) {
              // Check point field type
              if (outcome['point'] != null) {
                final point = outcome['point'];
                if (point is! num) {
                  print('   ❌ Type error: point is ${point.runtimeType} instead of num');
                  hasTypeIssues = true;
                }
              }
              // Check price field type
              if (outcome['price'] != null) {
                final price = outcome['price'];
                if (price is! num) {
                  print('   ❌ Type error: price is ${price.runtimeType} instead of num');
                  hasTypeIssues = true;
                }
              }
            }
          }
        }
        
        if (!hasTypeIssues) {
          print('   ✅ All data types correct');
        }
        
      } else {
        print('   ❌ No odds data available');
      }
      
      // 4. Test live scores
      print('\n4️⃣ Getting live scores...');
      final scores = await oddsApiService.getSportScores(sport);
      print('   ✅ Found ${scores.length} games with scores');
      
    } catch (e, stackTrace) {
      print('   ❌ Error testing $sport: $e');
      print('   Stack: ${stackTrace.toString().split('\n').first}');
    }
  }
  
  print('\n' + '=' * 60);
  print('🎯 TEST SUMMARY');
  print('=' * 60);
  print('\n✅ What should be working:');
  print('  • Game listings from Odds API');
  print('  • Basic betting markets (moneyline, spread, total)');
  print('  • Player props when available');
  print('  • Live scores');
  print('\n⚠️ Known issues fixed:');
  print('  • Type casting for point/price fields');
  print('  • ESPN to Odds API event ID conversion');
  print('\n📝 Notes:');
  print('  • Props availability varies by sport and game');
  print('  • Some sports may have no games in off-season');
}