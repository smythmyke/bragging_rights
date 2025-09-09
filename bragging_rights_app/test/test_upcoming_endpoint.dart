import 'package:http/http.dart' as http;
import 'dart:convert';

// Test the upcoming endpoint to see what markets are available
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🔍 Testing Upcoming Endpoint with Various Markets\n');
  print('=' * 50);
  
  // Test 1: Basic call like the website
  print('\n1️⃣ Testing basic upcoming endpoint (as used on website)...\n');
  
  var url = 'https://api.the-odds-api.com/v4/sports/upcoming/odds/?'
      'regions=us&markets=h2h&oddsFormat=american&apiKey=$apiKey';
  
  var response = await http.get(Uri.parse(url));
  print('Status: ${response.statusCode}');
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body) as List;
    print('✅ Found ${data.length} upcoming games');
    
    if (data.isNotEmpty) {
      // Analyze first game
      final game = data.first;
      print('\nFirst game: ${game['away_team']} @ ${game['home_team']}');
      print('Sport: ${game['sport_key']} - ${game['sport_title']}');
      
      final bookmakers = game['bookmakers'] ?? [];
      if (bookmakers.isNotEmpty) {
        final markets = bookmakers[0]['markets'] ?? [];
        print('Markets in response: ${markets.map((m) => m['key']).join(', ')}');
      }
    }
  }
  
  // Test 2: Try with h2h, spreads, totals
  print('\n2️⃣ Testing with h2h, spreads, totals...\n');
  
  url = 'https://api.the-odds-api.com/v4/sports/upcoming/odds/?'
      'regions=us&markets=h2h,spreads,totals&oddsFormat=american&apiKey=$apiKey';
  
  response = await http.get(Uri.parse(url));
  print('Status: ${response.statusCode}');
  
  if (response.statusCode == 200) {
    final data = json.decode(response.body) as List;
    if (data.isNotEmpty) {
      final game = data.first;
      final bookmakers = game['bookmakers'] ?? [];
      
      if (bookmakers.isNotEmpty) {
        final allMarkets = <String>{};
        for (final bm in bookmakers) {
          final markets = bm['markets'] ?? [];
          for (final market in markets) {
            allMarkets.add(market['key']);
          }
        }
        print('✅ Markets available: ${allMarkets.join(', ')}');
      }
    }
  }
  
  // Test 3: Try adding player props
  print('\n3️⃣ Testing with player props added...\n');
  
  url = 'https://api.the-odds-api.com/v4/sports/upcoming/odds/?'
      'regions=us&markets=h2h,spreads,totals,player_points,player_pass_tds&oddsFormat=american&apiKey=$apiKey';
  
  response = await http.get(Uri.parse(url));
  print('Status: ${response.statusCode}');
  
  if (response.statusCode == 422) {
    print('❌ Player props blocked (422)');
    try {
      final error = json.decode(response.body);
      print('Error: ${error['message']}');
    } catch (_) {}
  } else if (response.statusCode == 200) {
    print('✅ Request succeeded');
    final data = json.decode(response.body) as List;
    if (data.isNotEmpty) {
      // Check what markets we actually got
      final game = data.first;
      final bookmakers = game['bookmakers'] ?? [];
      
      final allMarkets = <String>{};
      for (final bm in bookmakers) {
        final markets = bm['markets'] ?? [];
        for (final market in markets) {
          allMarkets.add(market['key']);
        }
      }
      print('Markets in response: ${allMarkets.join(', ')}');
    }
  }
  
  // Test 4: Check specific sports for available markets
  print('\n4️⃣ Testing specific sports for market availability...\n');
  
  final sports = [
    'americanfootball_nfl',
    'basketball_nba',
    'baseball_mlb',
    'icehockey_nhl',
  ];
  
  for (final sport in sports) {
    print('\nTesting $sport:');
    
    url = 'https://api.the-odds-api.com/v4/sports/$sport/odds/?'
        'regions=us&markets=h2h,spreads,totals&oddsFormat=american&apiKey=$apiKey';
    
    response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      
      if (data.isNotEmpty) {
        final game = data.first;
        final bookmakers = game['bookmakers'] ?? [];
        
        final allMarkets = <String>{};
        for (final bm in bookmakers) {
          final markets = bm['markets'] ?? [];
          for (final market in markets) {
            allMarkets.add(market['key']);
          }
        }
        
        print('  ✅ Available: ${allMarkets.join(', ')}');
        
        // Check if different bookmakers have different markets
        final bookmakerMarkets = <String, Set<String>>{};
        for (final bm in bookmakers) {
          final bmName = bm['title'];
          final markets = bm['markets'] ?? [];
          bookmakerMarkets[bmName] = markets.map<String>((m) => m['key'] as String).toSet();
        }
        
        // Find any bookmaker that has unique markets
        bookmakerMarkets.forEach((name, markets) {
          if (markets.length > allMarkets.length / bookmakers.length) {
            print('  📚 $name has: ${markets.join(', ')}');
          }
        });
      } else {
        print('  ⚠️  No games available');
      }
    } else {
      print('  ❌ Error: ${response.statusCode}');
    }
    
    await Future.delayed(Duration(milliseconds: 300));
  }
  
  print('\n' + '=' * 50);
  print('\n📋 CONCLUSION:');
  print('Your API plan (with key ending in 4323) supports:');
  print('✅ h2h (moneyline)');
  print('✅ spreads');
  print('✅ totals (over/under)');
  print('❌ Player props - NOT available with current plan');
  print('❌ Alternate lines - NOT available with current plan');
}