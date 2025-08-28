import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('🏒 Testing NHL Edge APIs Integration');
  print('=' * 50);
  
  // Test 1: NHL Official API
  await testNhlOfficialApi();
  
  // Test 2: ESPN NHL API  
  await testEspnNhlApi();
  
  print('\n✅ All NHL API tests complete!');
}

Future<void> testNhlOfficialApi() async {
  print('\n1. NHL Official API Test:');
  print('-' * 30);
  
  try {
    // Get today's games
    final today = DateTime.now();
    final dateStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';
    
    final url = 'https://api-web.nhle.com/v1/schedule/$dateStr';
    print('   Fetching: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'BraggingRights/1.0'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final gameWeek = data['gameWeek'] as List? ?? [];
      
      int totalGames = 0;
      for (final day in gameWeek) {
        final games = day['games'] as List? ?? [];
        totalGames += games.length;
        
        for (final game in games) {
          final homeTeam = game['homeTeam']?['placeName']?['default'] ?? 'Unknown';
          final awayTeam = game['awayTeam']?['placeName']?['default'] ?? 'Unknown';
          final gameState = game['gameState'] ?? 'Unknown';
          
          print('   🏒 $awayTeam @ $homeTeam - $gameState');
        }
      }
      
      print('   ✅ Success! Found $totalGames games this week');
    } else {
      print('   ❌ Failed with status: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}

Future<void> testEspnNhlApi() async {
  print('\n2. ESPN NHL API Test:');
  print('-' * 30);
  
  try {
    final url = 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard';
    print('   Fetching: $url');
    
    final response = await http.get(
      Uri.parse(url),
      headers: {'User-Agent': 'BraggingRights/1.0'},
    );
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] as List? ?? [];
      
      print('   Found ${events.length} games today');
      
      for (final event in events.take(5)) {
        final name = event['name'] ?? 'Unknown';
        final status = event['status']?['type']?['state'] ?? 'Unknown';
        
        // Get scores if available
        final competitions = event['competitions'] as List? ?? [];
        if (competitions.isNotEmpty) {
          final competition = competitions.first;
          final competitors = competition['competitors'] as List? ?? [];
          
          if (competitors.length >= 2) {
            final home = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => {});
            final away = competitors.firstWhere((c) => c['homeAway'] == 'away', orElse: () => {});
            
            final homeScore = home['score'] ?? '0';
            final awayScore = away['score'] ?? '0';
            
            print('   🏒 $name [$awayScore-$homeScore] - $status');
          } else {
            print('   🏒 $name - $status');
          }
        }
      }
      
      print('   ✅ ESPN NHL API working!');
    } else {
      print('   ❌ Failed with status: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}