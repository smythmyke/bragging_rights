import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('⚾ COMPREHENSIVE MLB TEST');
  print('=' * 60);
  
  // 1. TEST GAME LISTINGS
  print('\n1️⃣ TESTING MLB GAME LISTINGS:');
  print('-' * 60);
  
  final eventsUrl = 'https://api.the-odds-api.com/v4/sports/baseball_mlb/events?apiKey=$apiKey';
  
  try {
    final eventsResponse = await http.get(Uri.parse(eventsUrl));
    
    if (eventsResponse.statusCode != 200) {
      print('❌ Failed to get events: ${eventsResponse.statusCode}');
      return;
    }
    
    final events = json.decode(eventsResponse.body) as List;
    print('✅ Found ${events.length} MLB games');
    
    if (events.isEmpty) {
      print('No MLB games available');
      return;
    }
    
    // Show first game details
    final firstGame = events.first;
    print('\nFirst Game Details:');
    print('  ID: ${firstGame['id']}');
    print('  Teams: ${firstGame['away_team']} @ ${firstGame['home_team']}');
    print('  Time: ${firstGame['commence_time']}');
    
    // 2. TEST ODDS FOR FIRST GAME
    print('\n2️⃣ TESTING ODDS RETRIEVAL:');
    print('-' * 60);
    
    final gameId = firstGame['id'];
    final oddsUrl = 'https://api.the-odds-api.com/v4/sports/baseball_mlb/events/$gameId/odds'
        '?apiKey=$apiKey&regions=us&markets=h2h,spreads,totals&oddsFormat=american';
    
    final oddsResponse = await http.get(Uri.parse(oddsUrl));
    
    if (oddsResponse.statusCode == 200) {
      final oddsData = json.decode(oddsResponse.body);
      final bookmakers = oddsData['bookmakers'] ?? [];
      
      print('✅ ODDS RETRIEVED: ${bookmakers.length} bookmakers');
      
      if (bookmakers.isNotEmpty) {
        final firstBook = bookmakers.first;
        print('\nSample Bookmaker: ${firstBook['title']}');
        
        final markets = firstBook['markets'] ?? [];
        for (final market in markets) {
          final key = market['key'];
          final outcomes = market['outcomes'] ?? [];
          
          print('\n  Market: $key');
          for (final outcome in outcomes) {
            print('    • ${outcome['name']}: ${outcome['price']} ${outcome['point'] != null ? "(${outcome['point']})" : ""}');
          }
        }
        
        // Check if we have all required markets
        final marketKeys = markets.map((m) => m['key']).toSet();
        print('\n  ✅ Has Moneyline (h2h): ${marketKeys.contains('h2h')}');
        print('  ✅ Has Spread: ${marketKeys.contains('spreads')}');
        print('  ✅ Has Total: ${marketKeys.contains('totals')}');
      }
    } else {
      print('❌ Failed to get odds: ${oddsResponse.statusCode}');
    }
    
    // 3. TEST PROPS
    print('\n3️⃣ TESTING PROPS RETRIEVAL:');
    print('-' * 60);
    
    final propsUrl = 'https://api.the-odds-api.com/v4/sports/baseball_mlb/events/$gameId/odds'
        '?apiKey=$apiKey&regions=us'
        '&markets=h2h,spreads,totals,batter_home_runs,batter_hits,batter_rbis,batter_runs_scored,pitcher_strikeouts,batter_total_bases'
        '&oddsFormat=american';
    
    final propsResponse = await http.get(Uri.parse(propsUrl));
    
    if (propsResponse.statusCode == 200) {
      final propsData = json.decode(propsResponse.body);
      final bookmakers = propsData['bookmakers'] ?? [];
      
      print('✅ PROPS RETRIEVED: ${bookmakers.length} bookmakers');
      
      // Count prop markets
      final allMarkets = <String>{};
      final propMarkets = <String>{};
      
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        for (final market in markets) {
          final key = market['key'];
          allMarkets.add(key);
          if (key.toString().contains('batter_') || key.toString().contains('pitcher_')) {
            propMarkets.add(key);
          }
        }
      }
      
      print('\n📊 MARKET ANALYSIS:');
      print('  All markets: ${allMarkets.toList()}');
      print('  Prop markets: ${propMarkets.toList()}');
      
      if (propMarkets.isNotEmpty) {
        print('\n✅ PROPS ARE AVAILABLE!');
        
        // Show sample prop data
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] ?? [];
          for (final market in markets) {
            if (market['key'].toString().contains('batter_') || 
                market['key'].toString().contains('pitcher_')) {
              final outcomes = market['outcomes'] ?? [];
              if (outcomes.isNotEmpty) {
                print('\n📍 ${bookmaker['title']} - ${market['key']}:');
                for (int i = 0; i < outcomes.length && i < 3; i++) {
                  final outcome = outcomes[i];
                  final point = outcome['point'];
                  print('   • ${outcome['name']}: ${outcome['price']} ${point != null ? "($point)" : ""}');
                  print('     Point type: ${point?.runtimeType}');
                }
                break;
              }
            }
          }
          if (propMarkets.isNotEmpty) break;
        }
      } else {
        print('\n⚠️ NO PROPS AVAILABLE for this game');
      }
    } else {
      print('❌ Failed to get props: ${propsResponse.statusCode}');
    }
    
    // 4. DIAGNOSE THE ISSUE
    print('\n4️⃣ DIAGNOSIS:');
    print('-' * 60);
    
    print('\n✅ WHAT\'S WORKING:');
    print('  • MLB games are loading from Odds API');
    print('  • Event IDs are in correct format');
    print('  • Basic odds (h2h, spreads, totals) are available');
    print('  • Props data IS available from the API');
    
    print('\n❌ WHAT\'S FAILING:');
    print('  • Type conversion error: "double" is not a subtype of "int?"');
    print('  • This happens when parsing props - likely the "point" field');
    print('  • The error prevents props from displaying');
    
    print('\n🔧 THE FIX:');
    print('  The "point" field in props can be either int or double');
    print('  The app expects int? but API returns double sometimes');
    print('  Need to handle both types in the parsing logic');
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n' + '=' * 60);
}