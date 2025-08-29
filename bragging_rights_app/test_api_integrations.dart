import 'dart:convert';
import 'package:http/http.dart' as http;

// Test all API integrations
void main() async {
  print('🏀 Testing API Integrations for Bragging Rights\n');
  
  // Test NBA API (Balldontlie)
  await testNBA();
  
  // Test NHL API  
  await testNHL();
  
  // Test NFL API (ESPN)
  await testNFL();
  
  // Test MLB API (ESPN)
  await testMLB();
  
  // Test MMA API (ESPN)
  await testMMA();
  
  // Test Boxing API (ESPN)
  await testBoxing();
  
  // Test The Odds API
  await testOddsAPI();
  
  print('\n✅ All API tests completed!');
}

Future<void> testNBA() async {
  print('\n🏀 Testing NBA API (Balldontlie)...');
  try {
    final response = await http.get(
      Uri.parse('https://api.balldontlie.io/v1/games?seasons[]=2024&per_page=5'),
      headers: {'Authorization': '978b1ba9-9847-40cc-93d1-abca911cf822'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('  ✅ NBA API working - Found ${data['meta']['total_count']} games');
    } else {
      print('  ❌ NBA API failed: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ NBA API error: $e');
  }
}

Future<void> testNHL() async {
  print('\n🏒 Testing NHL API...');
  try {
    final response = await http.get(
      Uri.parse('https://api-web.nhle.com/v1/schedule/now'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('  ✅ NHL API working - Schedule data retrieved');
    } else {
      print('  ❌ NHL API failed: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ NHL API error: $e');
  }
}

Future<void> testNFL() async {
  print('\n🏈 Testing NFL API (ESPN)...');
  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      print('  ✅ NFL API working - Found ${events.length} games');
    } else {
      print('  ❌ NFL API failed: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ NFL API error: $e');
  }
}

Future<void> testMLB() async {
  print('\n⚾ Testing MLB API (ESPN)...');
  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      print('  ✅ MLB API working - Found ${events.length} games');
    } else {
      print('  ❌ MLB API failed: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ MLB API error: $e');
  }
}

Future<void> testMMA() async {
  print('\n🥊 Testing MMA API (ESPN)...');
  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      print('  ✅ MMA API working - Found ${events.length} events');
    } else {
      print('  ❌ MMA API failed: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ MMA API error: $e');
  }
}

Future<void> testBoxing() async {
  print('\n🥊 Testing Boxing API (ESPN)...');
  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard'),
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      print('  ✅ Boxing API working - Found ${events.length} events');
    } else {
      print('  ❌ Boxing API failed: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ Boxing API error: $e');
  }
}

Future<void> testOddsAPI() async {
  print('\n💰 Testing The Odds API...');
  try {
    final response = await http.get(
      Uri.parse('https://api.the-odds-api.com/v4/sports?apiKey=a07a990fba881f317ae71ea131cc8223'),
    );
    
    if (response.statusCode == 200) {
      final sports = json.decode(response.body) as List;
      final inSeason = sports.where((s) => s['active'] == true).length;
      print('  ✅ Odds API working - $inSeason sports in season');
      
      // Check quota
      final remaining = response.headers['x-requests-remaining'];
      final used = response.headers['x-requests-used'];
      print('  📊 Quota: $used used, $remaining remaining');
    } else {
      print('  ❌ Odds API failed: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ Odds API error: $e');
  }
}