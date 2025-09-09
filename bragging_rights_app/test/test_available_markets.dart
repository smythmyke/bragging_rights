import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Test what markets are actually available with current API plan
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
  
  print('🔍 Testing Available Markets in The Odds API\n');
  print('=' * 50);
  
  // Test all standard markets that should be available
  final standardMarkets = [
    'h2h',                  // Moneyline
    'spreads',              // Point spreads
    'totals',               // Over/Under
    'outrights',            // Outrights/Futures
    'h2h_lay',              // Lay betting
    'spreads_lay',          // Lay spreads
    'totals_lay',           // Lay totals
    'alternate_spreads',    // Alternative spreads
    'alternate_totals',     // Alternative totals
    'btts',                 // Both teams to score
    'draw_no_bet',          // Draw no bet
    'double_chance',        // Double chance
  ];
  
  print('Testing standard markets for NFL...\n');
  
  for (final market in standardMarkets) {
    await testMarket('americanfootball_nfl', market, apiKey);
    await Future.delayed(Duration(milliseconds: 200)); // Rate limiting
  }
  
  // Now test combinations
  print('\n\nTesting market combinations...\n');
  
  final combinations = [
    'h2h,spreads',
    'h2h,spreads,totals',
    'spreads,totals',
    'h2h,totals',
  ];
  
  for (final combo in combinations) {
    print('Testing: $combo');
    final url = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/odds/?'
        'apiKey=$apiKey&regions=us&markets=$combo&oddsFormat=american';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        if (data.isNotEmpty) {
          final game = data.first;
          final bookmakers = game['bookmakers'] ?? [];
          
          if (bookmakers.isNotEmpty) {
            final bookmaker = bookmakers.first;
            final markets = bookmaker['markets'] ?? [];
            
            print('   ✅ Success! Found ${markets.length} markets:');
            for (final market in markets) {
              final outcomes = market['outcomes'] ?? [];
              print('      • ${market['key']} (${outcomes.length} outcomes)');
            }
          }
        }
      } else {
        print('   ❌ Error: ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Exception: $e');
    }
    
    await Future.delayed(Duration(milliseconds: 300));
  }
  
  print('\n' + '=' * 50);
  print('✅ Testing complete!');
}

Future<void> testMarket(String sport, String market, String apiKey) async {
  final url = 'https://api.the-odds-api.com/v4/sports/$sport/odds/?'
      'apiKey=$apiKey&regions=us&markets=$market&oddsFormat=american';
  
  try {
    final response = await http.get(Uri.parse(url));
    
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
            
            final marketData = markets.firstWhere((m) => m['key'] == market);
            final outcomes = marketData['outcomes'] ?? [];
            
            print('✅ $market - Available (${outcomes.length} outcomes)');
            
            // Show sample outcome
            if (outcomes.isNotEmpty) {
              final sample = outcomes.first;
              print('   Sample: ${sample['name']} @ ${sample['price']}');
            }
            break;
          }
        }
        
        if (!hasMarket) {
          print('⚠️  $market - Accepted but no data');
        }
      } else {
        print('⚠️  $market - Empty response');
      }
    } else if (response.statusCode == 422) {
      print('❌ $market - Not available (422)');
    } else {
      print('❌ $market - Error: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ $market - Exception: $e');
  }
}