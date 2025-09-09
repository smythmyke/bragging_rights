import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Simple test script to explore prop bet markets from The Odds API
void main() async {
  // Read API key from .env file
  final envFile = File('.env');
  if (!envFile.existsSync()) {
    print('❌ .env file not found');
    return;
  }
  
  final envContents = await envFile.readAsString();
  final apiKeyMatch = RegExp(r'ODDS_API_KEY=(.+)').firstMatch(envContents);
  
  if (apiKeyMatch == null) {
    print('❌ ODDS_API_KEY not found in .env file');
    return;
  }
  
  final apiKey = apiKeyMatch.group(1)!.trim();
  
  print('🔍 Testing The Odds API for Prop Bet Markets\n');
  print('=' * 50);
  
  // Test NFL first as it typically has the most prop markets
  await testSportProps('americanfootball_nfl', 'NFL', apiKey);
  
  print('\n' + '=' * 50);
  print('✅ Testing complete!');
}

Future<void> testSportProps(String sportKey, String sportName, String apiKey) async {
  print('\n📊 Testing $sportName ($sportKey)');
  print('-' * 40);
  
  // First, get available games with standard markets
  final gamesUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/odds/?'
      'apiKey=$apiKey&regions=us&markets=h2h&oddsFormat=american';
  
  try {
    final gamesResponse = await http.get(Uri.parse(gamesUrl));
    
    if (gamesResponse.statusCode != 200) {
      print('❌ Failed to get games: ${gamesResponse.statusCode}');
      return;
    }
    
    final games = json.decode(gamesResponse.body) as List;
    
    if (games.isEmpty) {
      print('⚠️  No games available');
      return;
    }
    
    final game = games.first;
    print('✅ Found game: ${game['away_team']} @ ${game['home_team']}');
    print('   Game ID: ${game['id']}');
    
    // According to The Odds API documentation, prop markets should be requested separately
    // Let's try different market combinations
    print('\n📋 Testing different market combinations:');
    
    // Test 1: Try all markets at once
    print('\n1. Testing all markets together...');
    final allMarketsUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/odds/?'
        'apiKey=$apiKey&regions=us&oddsFormat=american';
    
    final allResponse = await http.get(Uri.parse(allMarketsUrl));
    if (allResponse.statusCode == 200) {
      final allData = json.decode(allResponse.body) as List;
      if (allData.isNotEmpty) {
        final firstGame = allData.first;
        final bookmakers = firstGame['bookmakers'] ?? [];
        
        // Collect all unique market keys
        final marketKeys = <String>{};
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] ?? [];
          for (final market in markets) {
            marketKeys.add(market['key']);
          }
        }
        
        print('   ✅ Found ${marketKeys.length} market types:');
        for (final key in marketKeys) {
          print('      • $key');
        }
      }
    }
    
    // Test 2: Check event-specific props endpoint (if available)
    print('\n2. Testing event-specific endpoint...');
    final eventId = game['id'];
    final eventUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/events/$eventId/odds?'
        'apiKey=$apiKey&regions=us&oddsFormat=american';
    
    final eventResponse = await http.get(Uri.parse(eventUrl));
    if (eventResponse.statusCode == 200) {
      final eventData = json.decode(eventResponse.body);
      print('   ✅ Event endpoint accessible');
      
      final bookmakers = eventData['bookmakers'] ?? [];
      final marketKeys = <String>{};
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        for (final market in markets) {
          marketKeys.add(market['key']);
        }
      }
      
      if (marketKeys.isNotEmpty) {
        print('   Found ${marketKeys.length} markets for this event:');
        for (final key in marketKeys) {
          print('      • $key');
        }
      }
    } else if (eventResponse.statusCode == 404) {
      print('   ⚠️  Event endpoint not available (404)');
    } else {
      print('   ❌ Event endpoint error: ${eventResponse.statusCode}');
    }
    
    // Test 3: Try specific prop market parameters
    print('\n3. Testing specific market parameters...');
    
    // NFL-specific prop markets based on API documentation
    final nflProps = [
      'player_pass_tds',
      'player_pass_yds', 
      'player_rush_yds',
      'player_receptions',
      'alternate_spreads',
      'alternate_totals',
    ];
    
    for (final prop in nflProps) {
      final propUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/odds/?'
          'apiKey=$apiKey&regions=us&markets=$prop&oddsFormat=american';
      
      final propResponse = await http.get(Uri.parse(propUrl));
      
      if (propResponse.statusCode == 200) {
        final propData = json.decode(propResponse.body) as List;
        
        if (propData.isNotEmpty) {
          // Check if any game actually has this market
          bool foundMarket = false;
          for (final g in propData) {
            final bookmakers = g['bookmakers'] ?? [];
            for (final bookmaker in bookmakers) {
              final markets = bookmaker['markets'] ?? [];
              if (markets.any((m) => m['key'] == prop)) {
                foundMarket = true;
                print('   ✅ $prop - Available');
                
                // Show sample data
                final market = markets.firstWhere((m) => m['key'] == prop);
                final outcomes = market['outcomes'] ?? [];
                if (outcomes.isNotEmpty) {
                  print('      Sample outcomes:');
                  for (int i = 0; i < outcomes.length && i < 2; i++) {
                    final o = outcomes[i];
                    print('        - ${o['name']}: ${o['price']} ${o['point'] != null ? "(${o['point']})" : ""}');
                  }
                }
                break;
              }
            }
            if (foundMarket) break;
          }
          
          if (!foundMarket) {
            print('   ⚠️  $prop - No data in response');
          }
        } else {
          print('   ⚠️  $prop - Empty response');
        }
      } else {
        print('   ❌ $prop - Error: ${propResponse.statusCode}');
      }
      
      // Small delay to avoid rate limiting
      await Future.delayed(Duration(milliseconds: 300));
    }
    
  } catch (e) {
    print('❌ Error testing $sportName: $e');
  }
}