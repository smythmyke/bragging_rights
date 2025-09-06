// Quick test script to diagnose odds issues
// Run with: dart test_odds_quick.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== QUICK ODDS DIAGNOSTIC TEST ===\n');
  
  // Test 1: Check The Odds API
  await testTheOddsApi();
  
  // Test 2: Check ESPN API for NFL
  await testEspnNfl();
  
  // Test 3: Find Tampa Bay game specifically
  await findTampaBayGame();
}

Future<void> testTheOddsApi() async {
  print('1. Testing The Odds API...');
  
  const apiKey = '8c91c8f26a8b948c17f4f1f816ee8373'; // Your API key
  const url = 'https://api.the-odds-api.com/v4/sports/americanfootball_nfl/odds?apiKey=$apiKey&regions=us&markets=h2h,spreads,totals';
  
  try {
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      if (data is List && data.isNotEmpty) {
        print('  ✅ The Odds API is working!');
        print('  Found ${data.length} NFL games with odds');
        
        // Look for Tampa Bay game
        for (final game in data) {
          final homeTeam = game['home_team'] ?? '';
          final awayTeam = game['away_team'] ?? '';
          if (homeTeam.contains('Atlanta') || awayTeam.contains('Tampa')) {
            print('  Found game: $awayTeam @ $homeTeam');
            final bookmakers = game['bookmakers'] ?? [];
            if (bookmakers.isNotEmpty) {
              print('    Has odds from ${bookmakers.length} bookmakers');
            }
          }
        }
      } else {
        print('  ⚠️ The Odds API returned empty data');
      }
    } else if (response.statusCode == 401) {
      print('  ❌ API key is invalid');
    } else if (response.statusCode == 429) {
      print('  ❌ API quota exceeded');
    } else {
      print('  ❌ API error: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ Network error: $e');
  }
  
  print('');
}

Future<void> testEspnNfl() async {
  print('2. Testing ESPN NFL API...');
  
  const url = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard';
  
  try {
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      print('  ✅ ESPN API is working!');
      print('  Found ${events.length} NFL games');
      
      // Check for odds in games
      int gamesWithOdds = 0;
      for (final event in events) {
        final competitions = event['competitions'] ?? [];
        if (competitions.isNotEmpty) {
          final competition = competitions[0];
          final odds = competition['odds'];
          if (odds != null && odds.isNotEmpty) {
            gamesWithOdds++;
          }
        }
      }
      
      print('  Games with odds data: $gamesWithOdds/${events.length}');
    } else {
      print('  ❌ ESPN API error: ${response.statusCode}');
    }
  } catch (e) {
    print('  ❌ Network error: $e');
  }
  
  print('');
}

Future<void> findTampaBayGame() async {
  print('3. Looking for Tampa Bay @ Atlanta game specifically...');
  
  const url = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard';
  
  try {
    final response = await http.get(Uri.parse(url));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      
      for (final event in events) {
        final name = event['name'] ?? '';
        final competitions = event['competitions'] ?? [];
        
        if (name.contains('Tampa') || name.contains('Atlanta') || 
            name.contains('Buccaneers') || name.contains('Falcons')) {
          print('  ✅ Found game: $name');
          print('     Event ID: ${event['id']}');
          print('     Status: ${event['status']?['type']?['description']}');
          
          if (competitions.isNotEmpty) {
            final competition = competitions[0];
            final competitors = competition['competitors'] ?? [];
            
            if (competitors.length >= 2) {
              final home = competitors[0]['team']?['displayName'] ?? 'Unknown';
              final away = competitors[1]['team']?['displayName'] ?? 'Unknown';
              print('     Teams: $away @ $home');
            }
            
            // Check for odds
            final odds = competition['odds'];
            if (odds != null && odds.isNotEmpty) {
              print('     ✅ Has odds data in ESPN');
              final firstOdds = odds[0];
              print('       Provider: ${firstOdds['provider']?['name']}');
              print('       Spread: ${firstOdds['details']}');
              print('       O/U: ${firstOdds['overUnder']}');
            } else {
              print('     ❌ No odds data in ESPN');
            }
          }
          
          return;
        }
      }
      
      print('  ❌ Tampa Bay @ Atlanta game not found in ESPN data');
    }
  } catch (e) {
    print('  ❌ Error: $e');
  }
}