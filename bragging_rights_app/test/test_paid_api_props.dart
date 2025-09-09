import 'package:http/http.dart' as http;
import 'dart:convert';

// Test prop markets with the PAID API key
void main() async {
  // Using the paid API key directly
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🔍 Testing Prop Markets with PAID API Key\n');
  print('=' * 50);
  print('API Key: ${apiKey.substring(0, 8)}...${apiKey.substring(apiKey.length - 4)}');
  print('=' * 50);
  
  // Test NFL prop markets
  print('\n📊 Testing NFL Player Props\n');
  
  final nflProps = [
    'player_pass_tds',
    'player_pass_yds',
    'player_rush_yds',
    'player_reception_yds',
    'player_receptions',
  ];
  
  for (final prop in nflProps) {
    await testPropMarket('americanfootball_nfl', prop, apiKey);
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  // Test NBA prop markets
  print('\n📊 Testing NBA Player Props\n');
  
  final nbaProps = [
    'player_points',
    'player_rebounds',
    'player_assists',
    'player_threes',
    'player_points_rebounds_assists',
  ];
  
  for (final prop in nbaProps) {
    await testPropMarket('basketball_nba', prop, apiKey);
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  // Test alternate lines
  print('\n📊 Testing Alternate Lines\n');
  
  final alternates = [
    'alternate_spreads',
    'alternate_totals',
  ];
  
  for (final alt in alternates) {
    await testPropMarket('americanfootball_nfl', alt, apiKey);
    await Future.delayed(Duration(milliseconds: 500));
  }
  
  print('\n' + '=' * 50);
  print('✅ Testing complete!');
}

Future<void> testPropMarket(String sport, String market, String apiKey) async {
  print('Testing $market...');
  
  final url = 'https://api.the-odds-api.com/v4/sports/$sport/odds/?'
      'apiKey=$apiKey'
      '&regions=us'
      '&markets=$market'
      '&oddsFormat=american';
  
  try {
    final response = await http.get(Uri.parse(url));
    
    print('  Response code: ${response.statusCode}');
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      
      if (data.isEmpty) {
        print('  ⚠️  Empty response - no games available');
        return;
      }
      
      // Check if we actually got prop data
      final game = data.first;
      final bookmakers = game['bookmakers'] ?? [];
      
      bool foundProps = false;
      for (final bookmaker in bookmakers) {
        final markets = bookmaker['markets'] ?? [];
        
        for (final mkt in markets) {
          if (mkt['key'] == market) {
            foundProps = true;
            final outcomes = mkt['outcomes'] ?? [];
            
            print('  ✅ SUCCESS! Found ${outcomes.length} outcomes');
            print('  📚 Bookmaker: ${bookmaker['title']}');
            
            // Show first 3 outcomes as examples
            print('  📋 Sample outcomes:');
            for (int i = 0; i < outcomes.length && i < 3; i++) {
              final outcome = outcomes[i];
              final name = outcome['name'];
              final price = outcome['price'];
              final point = outcome['point'];
              
              if (point != null) {
                print('     • $name: $price (Line: $point)');
              } else {
                print('     • $name: $price');
              }
            }
            
            if (outcomes.length > 3) {
              print('     ... and ${outcomes.length - 3} more');
            }
            
            break;
          }
        }
        
        if (foundProps) break;
      }
      
      if (!foundProps) {
        print('  ⚠️  Request succeeded but no $market data in response');
        print('  Available markets: ${bookmakers.isNotEmpty ? bookmakers[0]['markets'].map((m) => m['key']).join(', ') : 'none'}');
      }
      
    } else if (response.statusCode == 422) {
      print('  ❌ BLOCKED - This market requires a higher tier API plan');
      
      // Parse error message if available
      try {
        final error = json.decode(response.body);
        if (error['message'] != null) {
          print('  Error: ${error['message']}');
        }
      } catch (_) {}
      
    } else if (response.statusCode == 401) {
      print('  ❌ UNAUTHORIZED - API key issue');
    } else {
      print('  ❌ Error: ${response.statusCode}');
      print('  Body: ${response.body.substring(0, 200)}...');
    }
    
  } catch (e) {
    print('  ❌ Exception: $e');
  }
}