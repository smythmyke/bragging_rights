import 'package:http/http.dart' as http;
import 'dart:convert';

// Test the EVENT-SPECIFIC endpoint for prop markets as per The Odds API support
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🔍 Testing EVENT-SPECIFIC Endpoint for Props\n');
  print('Based on support email: Props available via /events/{id}/odds\n');
  print('=' * 50);
  
  // Step 1: Get list of NFL events
  print('\n1️⃣ Getting NFL events...\n');
  
  final eventsUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events?'
      'apiKey=$apiKey';
  
  try {
    final eventsResponse = await http.get(Uri.parse(eventsUrl));
    
    if (eventsResponse.statusCode != 200) {
      print('❌ Failed to get events: ${eventsResponse.statusCode}');
      return;
    }
    
    final events = json.decode(eventsResponse.body) as List;
    print('✅ Found ${events.length} NFL events\n');
    
    if (events.isEmpty) {
      print('No events available');
      return;
    }
    
    // Test first 2 events
    for (int i = 0; i < events.length && i < 2; i++) {
      final event = events[i];
      final eventId = event['id'];
      final homeTeam = event['home_team'];
      final awayTeam = event['away_team'];
      
      print('\n' + '=' * 50);
      print('📊 Event ${i+1}: $awayTeam @ $homeTeam');
      print('Event ID: $eventId');
      print('=' * 50);
      
      // Step 2: Test different market combinations for this event
      await testEventMarkets(eventId, apiKey);
      
      // Add delay to avoid rate limiting
      await Future.delayed(Duration(seconds: 1));
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n' + '=' * 50);
  print('✅ Testing complete!');
}

Future<void> testEventMarkets(String eventId, String apiKey) async {
  // Test 1: Basic markets
  print('\n📌 Test 1: Basic markets (h2h, spreads, totals)');
  await testMarketSet(
    eventId, 
    apiKey, 
    'h2h,spreads,totals',
    'Basic markets'
  );
  
  // Test 2: Player props - Passing
  print('\n📌 Test 2: Player passing props');
  await testMarketSet(
    eventId,
    apiKey,
    'player_pass_tds,player_pass_yds,player_pass_attempts',
    'Passing props'
  );
  
  // Test 3: Player props - Rushing
  print('\n📌 Test 3: Player rushing props');
  await testMarketSet(
    eventId,
    apiKey,
    'player_rush_yds,player_rush_attempts,player_rush_tds',
    'Rushing props'
  );
  
  // Test 4: Player props - Receiving
  print('\n📌 Test 4: Player receiving props');
  await testMarketSet(
    eventId,
    apiKey,
    'player_reception_yds,player_receptions',
    'Receiving props'
  );
  
  // Test 5: Alternate lines
  print('\n📌 Test 5: Alternate lines');
  await testMarketSet(
    eventId,
    apiKey,
    'alternate_spreads,alternate_totals',
    'Alternate lines'
  );
  
  // Test 6: All markets together
  print('\n📌 Test 6: Query without specifying markets (get all available)');
  final allUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events/$eventId/odds?'
      'apiKey=$apiKey'
      '&regions=us'
      '&oddsFormat=american';
  
  try {
    final response = await http.get(Uri.parse(allUrl));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final bookmakers = data['bookmakers'] ?? [];
      
      // Collect all unique markets
      final allMarkets = <String>{};
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        for (final market in markets) {
          allMarkets.add(market['key']);
        }
      }
      
      if (allMarkets.isNotEmpty) {
        print('✅ ALL AVAILABLE MARKETS:');
        for (final market in allMarkets) {
          print('   • $market');
          
          // Show sample data for prop markets
          if (market.contains('player')) {
            for (final bookmaker in bookmakers) {
              final markets = bookmaker['markets'] ?? [];
              final marketData = markets.firstWhere(
                (m) => m['key'] == market,
                orElse: () => null,
              );
              
              if (marketData != null) {
                final outcomes = marketData['outcomes'] ?? [];
                if (outcomes.isNotEmpty) {
                  print('     Sample from ${bookmaker['title']}:');
                  for (int j = 0; j < outcomes.length && j < 2; j++) {
                    final outcome = outcomes[j];
                    print('       - ${outcome['name']}: ${outcome['price']} ${outcome['point'] != null ? "(${outcome['point']})" : ""}');
                  }
                  break;
                }
              }
            }
          }
        }
      } else {
        print('⚠️  No markets found');
      }
    } else {
      print('❌ Error: ${response.statusCode}');
      if (response.statusCode == 422) {
        final error = json.decode(response.body);
        print('   Message: ${error['message']}');
      }
    }
  } catch (e) {
    print('❌ Exception: $e');
  }
}

Future<void> testMarketSet(
  String eventId, 
  String apiKey, 
  String markets,
  String description,
) async {
  final url = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events/$eventId/odds?'
      'apiKey=$apiKey'
      '&regions=us'
      '&markets=$markets'
      '&oddsFormat=american';
  
  try {
    final response = await http.get(Uri.parse(url));
    
    print('  Status: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final bookmakers = data['bookmakers'] ?? [];
      
      // Collect found markets
      final foundMarkets = <String>{};
      for (final bookmaker in bookmakers) {
        final mkts = bookmaker['markets'] ?? [];
        for (final market in mkts) {
          foundMarkets.add(market['key']);
        }
      }
      
      if (foundMarkets.isNotEmpty) {
        print('  ✅ SUCCESS! Found markets: ${foundMarkets.join(', ')}');
        
        // Show bookmakers that have these markets
        final bookmakerNames = bookmakers
            .where((b) => (b['markets'] ?? []).isNotEmpty)
            .map((b) => b['title'])
            .take(3)
            .join(', ');
        print('  📚 Available from: $bookmakerNames');
      } else {
        print('  ⚠️  Request succeeded but no $description in response');
      }
    } else if (response.statusCode == 422) {
      print('  ❌ Not available: $markets');
      final error = json.decode(response.body);
      if (error['message'] != null) {
        print('     Error: ${error['message']}');
      }
    } else {
      print('  ❌ Error: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ Exception: $e');
  }
  
  await Future.delayed(Duration(milliseconds: 300));
}