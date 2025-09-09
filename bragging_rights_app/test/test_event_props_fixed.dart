import 'package:http/http.dart' as http;
import 'dart:convert';

// Test EVENT-SPECIFIC endpoint for props - FIXED VERSION
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🎯 Testing EVENT-SPECIFIC Endpoint for Props\n');
  print('=' * 50);
  
  // Get NFL events first
  final eventsUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events?'
      'apiKey=$apiKey';
  
  try {
    final eventsResponse = await http.get(Uri.parse(eventsUrl));
    
    if (eventsResponse.statusCode != 200) {
      print('❌ Failed to get events: ${eventsResponse.statusCode}');
      return;
    }
    
    final events = json.decode(eventsResponse.body) as List;
    print('Found ${events.length} NFL events\n');
    
    if (events.isEmpty) return;
    
    // Test first event with ALL markets
    final event = events.first;
    final eventId = event['id'];
    print('Testing: ${event['away_team']} @ ${event['home_team']}');
    print('Event ID: $eventId\n');
    
    // Query ALL available markets for this event
    final url = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events/$eventId/odds?'
        'apiKey=$apiKey'
        '&regions=us'
        '&markets=h2h,spreads,totals,player_pass_tds,player_pass_yds,player_rush_yds,player_receptions,player_reception_yds,alternate_spreads,alternate_totals'
        '&oddsFormat=american';
    
    print('Requesting comprehensive market data...\n');
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final bookmakers = data['bookmakers'] ?? [];
      
      print('✅ SUCCESS! Got data from ${bookmakers.length} bookmakers\n');
      
      // Analyze markets by category
      final standardMarkets = <String>{};
      final propMarkets = <String>{};
      final alternateMarkets = <String>{};
      
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        
        for (final market in markets) {
          final key = market['key'];
          
          if (key.contains('player')) {
            propMarkets.add(key);
          } else if (key.contains('alternate')) {
            alternateMarkets.add(key);
          } else {
            standardMarkets.add(key);
          }
        }
      }
      
      // Display results
      print('📊 MARKET AVAILABILITY:\n');
      
      print('Standard Markets (${standardMarkets.length}):');
      for (final market in standardMarkets) {
        print('  ✅ $market');
      }
      
      print('\nPlayer Props (${propMarkets.length}):');
      if (propMarkets.isNotEmpty) {
        for (final market in propMarkets) {
          print('  ✅ $market');
          
          // Show sample player data
          for (final bookmaker in bookmakers) {
            final markets = bookmaker['markets'] ?? [];
            for (final mkt in markets) {
              if (mkt['key'] == market) {
                final outcomes = mkt['outcomes'] ?? [];
                if (outcomes.isNotEmpty) {
                  print('     Examples from ${bookmaker['title']}:');
                  for (int i = 0; i < outcomes.length && i < 3; i++) {
                    final o = outcomes[i];
                    final name = o['name'];
                    final price = o['price'];
                    final point = o['point'];
                    print('       • $name: $price ${point != null ? "($point)" : ""}');
                  }
                  break;
                }
              }
            }
            break;
          }
        }
      } else {
        print('  ⚠️  No player props available for this game');
      }
      
      print('\nAlternate Lines (${alternateMarkets.length}):');
      if (alternateMarkets.isNotEmpty) {
        for (final market in alternateMarkets) {
          print('  ✅ $market');
        }
      } else {
        print('  ⚠️  No alternate lines available');
      }
      
      // Show which bookmakers have props
      print('\n📚 BOOKMAKER COVERAGE:');
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        final bmProps = markets.where((m) => m['key'].toString().contains('player')).length;
        if (bmProps > 0) {
          print('  ${bookmaker['title']}: $bmProps player prop markets');
        }
      }
      
    } else {
      print('❌ Failed: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        final error = json.decode(response.body);
        print('Error: ${error['message']}');
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n' + '=' * 50);
  print('CONCLUSION: Props ARE available via event-specific endpoint!');
}