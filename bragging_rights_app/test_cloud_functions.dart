import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'lib/services/cloud_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  
  print('🚀 Testing Cloud Functions API Proxy\n');
  
  // Sign in anonymously for testing
  try {
    await FirebaseAuth.instance.signInAnonymously();
    print('✅ Authenticated successfully\n');
  } catch (e) {
    print('❌ Authentication failed: $e');
    return;
  }
  
  final cloudApi = CloudApiService();
  
  // Test NBA API
  print('🏀 Testing NBA Games API...');
  try {
    final games = await cloudApi.getNBAGames(season: 2024, perPage: 5);
    print('✅ NBA API working - Found ${games['meta']?['total_count']} games');
  } catch (e) {
    print('❌ NBA API failed: $e');
  }
  
  // Test NHL API
  print('\n🏒 Testing NHL Schedule API...');
  try {
    final schedule = await cloudApi.getNHLSchedule();
    print('✅ NHL API working - Schedule retrieved');
  } catch (e) {
    print('❌ NHL API failed: $e');
  }
  
  // Test ESPN API
  print('\n🏈 Testing ESPN NFL API...');
  try {
    final scoreboard = await cloudApi.getESPNScoreboard(sport: 'nfl');
    final events = scoreboard['events'] ?? [];
    print('✅ ESPN API working - Found ${events.length} games');
  } catch (e) {
    print('❌ ESPN API failed: $e');
  }
  
  // Test Odds API
  print('\n💰 Testing Odds API...');
  try {
    final oddsData = await cloudApi.getOdds(sport: 'basketball_nba');
    final odds = oddsData['odds'] as List;
    final quota = oddsData['quota'];
    print('✅ Odds API working - Found ${odds.length} games with odds');
    print('   Quota: ${quota['used']} used, ${quota['remaining']} remaining');
  } catch (e) {
    print('❌ Odds API failed: $e');
  }
  
  // Test Sports in Season
  print('\n🏅 Testing Sports in Season API...');
  try {
    final sports = await cloudApi.getSportsInSeason();
    print('✅ Found ${sports.length} sports currently in season');
    for (var sport in sports.take(5)) {
      print('   - ${sport['title']}');
    }
  } catch (e) {
    print('❌ Sports in Season API failed: $e');
  }
  
  // Test News API
  print('\n📰 Testing News API...');
  try {
    final news = await cloudApi.getSportsNews(sport: 'NBA', query: 'Lakers');
    final articles = news['articles'] as List;
    print('✅ News API working - Found ${articles.length} articles');
    if (articles.isNotEmpty) {
      print('   Latest: ${articles[0]['title']}');
    }
  } catch (e) {
    print('❌ News API failed: $e');
  }
  
  print('\n✅ Cloud Functions test complete!');
  print('\n📝 Next steps:');
  print('1. Run: set_firebase_config.bat');
  print('2. Deploy: firebase deploy --only functions');
  print('3. Test again to verify deployment');
}