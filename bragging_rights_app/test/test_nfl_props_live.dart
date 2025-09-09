import 'package:http/http.dart' as http;
import 'dart:convert';

// Test NFL props to see if they're available from The Odds API
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🏈 TESTING NFL PROPS AVAILABILITY');
  print('=' * 50);
  
  // Step 1: Get NFL events
  print('\n1️⃣ Getting NFL events...');
  final eventsUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events?apiKey=$apiKey';
  
  try {
    final eventsResponse = await http.get(Uri.parse(eventsUrl));
    
    if (eventsResponse.statusCode != 200) {
      print('❌ Failed to get events: ${eventsResponse.statusCode}');
      return;
    }
    
    final events = json.decode(eventsResponse.body) as List;
    print('✅ Found ${events.length} NFL events\n');
    
    if (events.isEmpty) {
      print('No NFL events available');
      return;
    }
    
    // Step 2: Test first event for props
    final event = events.first;
    final eventId = event['id'];
    final homeTeam = event['home_team'];
    final awayTeam = event['away_team'];
    
    print('2️⃣ Testing props for: $awayTeam @ $homeTeam');
    print('   Event ID: $eventId\n');
    
    // Step 3: Request with prop markets
    final propsUrl = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/events/$eventId/odds?'
        'apiKey=$apiKey'
        '&regions=us'
        '&markets=h2h,spreads,totals,player_pass_tds,player_pass_yds,player_rush_yds,player_receptions,player_reception_yds'
        '&oddsFormat=american';
    
    print('3️⃣ Requesting props data...');
    final propsResponse = await http.get(Uri.parse(propsUrl));
    
    if (propsResponse.statusCode == 200) {
      final data = json.decode(propsResponse.body);
      final bookmakers = data['bookmakers'] ?? [];
      
      print('✅ Got data from ${bookmakers.length} bookmakers\n');
      
      // Analyze markets
      final allMarkets = <String>{};
      final propMarkets = <String>{};
      
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        for (final market in markets) {
          final key = market['key'];
          allMarkets.add(key);
          if (key.toString().startsWith('player_')) {
            propMarkets.add(key);
          }
        }
      }
      
      print('📊 MARKET ANALYSIS:');
      print('   All markets: ${allMarkets.toList()}');
      print('   Prop markets: ${propMarkets.toList()}');
      
      if (propMarkets.isNotEmpty) {
        print('\n✅ NFL PROPS ARE AVAILABLE!');
        
        // Show sample player data
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] ?? [];
          for (final market in markets) {
            if (market['key'].toString().startsWith('player_')) {
              final outcomes = market['outcomes'] ?? [];
              if (outcomes.isNotEmpty) {
                print('\n📍 ${bookmaker['title']} - ${market['key']}:');
                for (int i = 0; i < outcomes.length && i < 3; i++) {
                  final outcome = outcomes[i];
                  print('   • ${outcome['name']}: ${outcome['price']} (${outcome['point'] ?? "N/A"})');
                }
                break;
              }
            }
          }
          if (propMarkets.isNotEmpty) break;
        }
      } else {
        print('\n⚠️  NO PROPS AVAILABLE for this game');
        print('This could mean:');
        print('  - Props not yet posted for this game');
        print('  - Game is too far in the future');
        print('  - Already started/completed');
      }
      
    } else {
      print('❌ Failed to get props: ${propsResponse.statusCode}');
      if (propsResponse.statusCode == 422) {
        print('   Invalid event ID (event may be expired)');
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('\n' + '=' * 50);
  print('Test complete');
}