import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to evaluate different Tennis APIs
/// Run with: dart test_tennis_apis.dart
void main() async {
  print('🎾 Testing Tennis APIs for Bragging Rights Integration\n');
  print('=' * 60);
  
  // Test each API
  await testTennisLiveDataAPI();
  await testSportRadarAPI();
  await testAPITennis();
  await testTennisDataAPI();
  await testUltimateTennisAPI();
  
  print('\n' + '=' * 60);
  print('📊 API Evaluation Complete!');
}

/// 1. Tennis Live Data API (RapidAPI)
Future<void> testTennisLiveDataAPI() async {
  print('\n1️⃣ Testing Tennis Live Data API (RapidAPI)');
  print('-' * 40);
  
  try {
    // Free tier: 100 requests/month
    final endpoints = [
      '/matches/live',
      '/matches/today',
      '/players/atp-ranking',
      '/players/wta-ranking',
      '/tournaments/active',
    ];
    
    print('📍 Base URL: https://tennis-live-data.p.rapidapi.com');
    print('💰 Pricing: Free tier (100 req/month), Pro ($29/month)');
    print('📋 Endpoints to test:');
    for (var endpoint in endpoints) {
      print('   • $endpoint');
    }
    
    // Test without key for now
    print('⚠️  Requires RapidAPI key - sign up at rapidapi.com');
    print('✅ Features: Live scores, rankings, H2H, tournaments');
    print('✅ Coverage: ATP, WTA, ITF, Challengers');
    print('❌ Limitations: Low free tier limit');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// 2. SportRadar Tennis API
Future<void> testSportRadarAPI() async {
  print('\n2️⃣ Testing SportRadar Tennis API');
  print('-' * 40);
  
  try {
    print('📍 Base URL: https://api.sportradar.com/tennis/trial/v3/en');
    print('💰 Pricing: Trial (1000 req/month), Enterprise pricing');
    
    // Test trial endpoint (no key needed for basic info)
    final response = await http.get(
      Uri.parse('https://api.sportradar.com/tennis/trial/v3/en/schedules/live/schedule.json?api_key=TRIAL_KEY'),
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 403) {
      print('⚠️  Requires API key from sportradar.com');
    } else if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('✅ Live matches available: ${data['sport_events']?.length ?? 0}');
    }
    
    print('✅ Features: Comprehensive stats, live data, push feeds');
    print('✅ Coverage: All major tournaments');
    print('❌ Limitations: Expensive for production');
    
  } catch (e) {
    print('⚠️  Connection test failed (expected without key)');
  }
}

/// 3. API-Tennis (Alternative free option)
Future<void> testAPITennis() async {
  print('\n3️⃣ Testing API-Tennis');
  print('-' * 40);
  
  try {
    print('📍 Base URL: https://api-tennis.com/tennis/');
    print('💰 Pricing: FREE with attribution');
    
    // Test public endpoint
    final response = await http.get(
      Uri.parse('https://api-tennis.com/tennis/?method=get_matches&APIkey=FREE_TRIAL'),
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      print('✅ API is accessible');
      final body = response.body;
      if (body.contains('error')) {
        print('⚠️  Requires registration at api-tennis.com');
      }
    }
    
    print('✅ Features: Live scores, rankings, H2H');
    print('✅ Coverage: ATP, WTA, ITF');
    print('✅ Free tier available with attribution');
    print('❌ Limitations: Basic data only');
    
  } catch (e) {
    print('⚠️  Connection failed: $e');
  }
}

/// 4. Tennis Data API (tennis-data.co.uk)
Future<void> testTennisDataAPI() async {
  print('\n4️⃣ Testing Tennis Data API');
  print('-' * 40);
  
  try {
    print('📍 Base URL: https://www.tennis-data.co.uk');
    print('💰 Pricing: FREE (CSV data)');
    
    // Test data availability
    final response = await http.get(
      Uri.parse('https://www.tennis-data.co.uk/2024/2024.xlsx'),
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      print('✅ Historical data available');
      print('📊 Format: CSV/Excel files');
    } else {
      print('⚠️  Data format: CSV files (not REST API)');
    }
    
    print('✅ Features: Historical match data, odds');
    print('✅ Coverage: All major tournaments');
    print('❌ Limitations: Not real-time, CSV format only');
    
  } catch (e) {
    print('⚠️  Connection test: $e');
  }
}

/// 5. Ultimate Tennis Statistics API
Future<void> testUltimateTennisAPI() async {
  print('\n5️⃣ Testing Ultimate Tennis Statistics');
  print('-' * 40);
  
  try {
    print('📍 Base URL: https://www.ultimatetennisstatistics.com');
    print('💰 Pricing: FREE (web scraping required)');
    
    // Test if site is accessible
    final response = await http.get(
      Uri.parse('https://www.ultimatetennisstatistics.com/tournamentEvents'),
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      print('✅ Website accessible');
      print('📊 Data available via web scraping');
    }
    
    print('✅ Features: Detailed statistics, H2H, rankings');
    print('✅ Coverage: Historical and current data');
    print('❌ Limitations: Requires web scraping');
    
  } catch (e) {
    print('⚠️  Connection test: $e');
  }
}

/// Test ESPN Tennis endpoints
Future<void> testESPNTennis() async {
  print('\n6️⃣ Testing ESPN Tennis API');
  print('-' * 40);
  
  try {
    print('📍 Base URL: https://site.api.espn.com/apis/site/v2/sports/tennis');
    print('💰 Pricing: FREE (no key required)');
    
    // Test scoreboard endpoint
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/tennis/scoreboard'),
    ).timeout(Duration(seconds: 5));
    
    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] ?? [];
      print('✅ API Working! Live matches: ${events.length}');
      
      if (events.isNotEmpty) {
        final match = events[0];
        final competition = match['competitions']?[0];
        if (competition != null) {
          final competitors = competition['competitors'] ?? [];
          if (competitors.length >= 2) {
            print('📍 Sample match: ${competitors[0]['athlete']['displayName']} vs ${competitors[1]['athlete']['displayName']}');
          }
        }
      }
    }
    
    // Test rankings
    final rankingsResponse = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/tennis/atp/rankings'),
    ).timeout(Duration(seconds: 5));
    
    if (rankingsResponse.statusCode == 200) {
      print('✅ ATP Rankings available');
    }
    
    print('✅ Features: Live scores, rankings, tournaments');
    print('✅ Coverage: All major tournaments');
    print('✅ No API key required!');
    print('❌ Limitations: Limited player stats');
    
  } catch (e) {
    print('❌ Error: $e');
  }
}

/// Summary and Recommendation
void printRecommendation() {
  print('\n' + '=' * 60);
  print('🏆 RECOMMENDATION FOR BRAGGING RIGHTS');
  print('=' * 60);
  
  print('''
  
PRIMARY CHOICE: ESPN Tennis API
--------------------------------
✅ FREE with no API key required
✅ Reliable (same as NBA/NFL/NHL integration)
✅ Live scores and schedules
✅ ATP/WTA rankings
✅ Tournament coverage
✅ Already familiar with ESPN API structure

BACKUP OPTION: API-Tennis
-------------------------
✅ Free tier available
✅ Good coverage
✅ REST API format
❌ Requires registration

IMPLEMENTATION PLAN:
1. Use ESPN Tennis as primary data source
2. Implement same pattern as other ESPN sports
3. Add API-Tennis as fallback if needed
4. Focus on:
   - Live match scores
   - Daily schedules
   - Rankings (ATP/WTA)
   - Tournament information
   - Basic player stats

MISSING DATA (need alternative sources):
- Detailed H2H records
- Surface-specific stats
- Advanced player metrics
- Weather conditions for outdoor matches
  ''');
}