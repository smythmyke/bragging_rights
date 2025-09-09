import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Final test to determine exactly what prop markets we can access
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
  
  print('🔍 Testing Prop Markets with Your API Plan\n');
  print('=' * 50);
  
  // Based on documentation, these SHOULD be available prop markets
  final propMarkets = {
    'NFL': [
      'player_pass_tds',
      'player_points',
      'alternate_spreads',
      'alternate_totals',
    ],
    'NBA': [
      'player_points',
      'player_rebounds',
      'player_assists',
    ],
  };
  
  // Test NFL props
  print('\n📊 Testing NFL Props\n');
  for (final market in propMarkets['NFL']!) {
    await testSpecificMarket('americanfootball_nfl', 'NFL', market, apiKey);
    await Future.delayed(Duration(milliseconds: 300));
  }
  
  // Test NBA props
  print('\n📊 Testing NBA Props\n');
  for (final market in propMarkets['NBA']!) {
    await testSpecificMarket('basketball_nba', 'NBA', market, apiKey);
    await Future.delayed(Duration(milliseconds: 300));
  }
  
  // Test event-specific endpoint (alternative approach)
  print('\n📊 Testing Event-Specific Endpoint\n');
  await testEventEndpoint('americanfootball_nfl', apiKey);
  
  print('\n' + '=' * 50);
  print('\n📋 SUMMARY:\n');
  print('Your API plan supports:');
  print('✅ h2h (moneyline)');
  print('✅ spreads');
  print('✅ totals (over/under)');
  print('❌ Player props (requires paid plan)');
  print('❌ Alternate lines (requires paid plan)');
  print('\nTo enable prop bets, you would need to upgrade your API plan.');
  print('Visit: https://the-odds-api.com/#get-access');
}

Future<void> testSpecificMarket(
    String sportKey, String sportName, String market, String apiKey) async {
  
  print('Testing $market...');
  
  // First try with just the prop market
  var url = 'https://api.the-odds-api.com/v4/sports/$sportKey/odds/?'
      'apiKey=$apiKey&regions=us&markets=$market&oddsFormat=american';
  
  try {
    var response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      if (data.isNotEmpty) {
        // Check if market actually exists in response
        final game = data.first;
        final bookmakers = game['bookmakers'] ?? [];
        
        bool hasMarket = false;
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] ?? [];
          if (markets.any((m) => m['key'] == market)) {
            hasMarket = true;
            print('  ✅ $market - AVAILABLE!');
            
            // Show sample data
            final marketData = markets.firstWhere((m) => m['key'] == market);
            final outcomes = marketData['outcomes'] ?? [];
            if (outcomes.isNotEmpty && outcomes.length <= 3) {
              print('     Sample outcomes:');
              for (final outcome in outcomes) {
                print('       • ${outcome['name']}: ${outcome['price']}');
              }
            }
            return;
          }
        }
        
        if (!hasMarket) {
          print('  ⚠️  $market - Accepted but no data returned');
        }
      } else {
        print('  ⚠️  $market - Empty response');
      }
    } else if (response.statusCode == 422) {
      print('  ❌ $market - Not available (requires upgraded plan)');
    } else {
      print('  ❌ $market - Error: ${response.statusCode}');
    }
    
    // Try combining with basic markets
    print('     Trying combined with h2h...');
    url = 'https://api.the-odds-api.com/v4/sports/$sportKey/odds/?'
        'apiKey=$apiKey&regions=us&markets=h2h,$market&oddsFormat=american';
    
    response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      if (data.isNotEmpty) {
        final game = data.first;
        final bookmakers = game['bookmakers'] ?? [];
        
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] ?? [];
          if (markets.any((m) => m['key'] == market)) {
            print('     ✅ Works when combined with h2h!');
            return;
          }
        }
        print('     ❌ Still no prop data when combined');
      }
    } else if (response.statusCode == 422) {
      print('     ❌ Still blocked when combined');
    }
    
  } catch (e) {
    print('  ❌ Exception: $e');
  }
}

Future<void> testEventEndpoint(String sportKey, String apiKey) async {
  print('Getting events for $sportKey...');
  
  // First get an event ID
  final eventsUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/odds/?'
      'apiKey=$apiKey&regions=us&markets=h2h&oddsFormat=american';
  
  try {
    final eventsResponse = await http.get(Uri.parse(eventsUrl));
    
    if (eventsResponse.statusCode == 200) {
      final events = json.decode(eventsResponse.body) as List;
      
      if (events.isNotEmpty) {
        final event = events.first;
        final eventId = event['id'];
        
        print('  Found event: ${event['away_team']} @ ${event['home_team']}');
        print('  Event ID: $eventId');
        
        // Now try the event-specific endpoint
        final eventUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/events/$eventId/odds?'
            'apiKey=$apiKey&regions=us&oddsFormat=american';
        
        print('  Testing event endpoint...');
        final eventResponse = await http.get(Uri.parse(eventUrl));
        
        if (eventResponse.statusCode == 200) {
          final eventData = json.decode(eventResponse.body);
          final bookmakers = eventData['bookmakers'] ?? [];
          
          // Collect all unique markets
          final allMarkets = <String>{};
          for (final bookmaker in bookmakers) {
            final markets = bookmaker['markets'] ?? [];
            for (final market in markets) {
              allMarkets.add(market['key']);
            }
          }
          
          print('  ✅ Event endpoint works!');
          print('  Available markets: ${allMarkets.join(', ')}');
          
          // Check for any prop markets
          final propMarkets = allMarkets.where((m) => 
            m.contains('player') || 
            m.contains('alternate') ||
            m.contains('team_totals') ||
            m.contains('btts')
          ).toList();
          
          if (propMarkets.isNotEmpty) {
            print('  🎯 Found prop markets: ${propMarkets.join(', ')}');
          } else {
            print('  ℹ️  No prop markets found (only basic markets available)');
          }
        } else {
          print('  ❌ Event endpoint error: ${eventResponse.statusCode}');
        }
      }
    }
  } catch (e) {
    print('  ❌ Exception: $e');
  }
}