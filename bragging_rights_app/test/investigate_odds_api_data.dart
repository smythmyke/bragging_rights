import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🔍 INVESTIGATING ODDS API DATA STRUCTURE');
  print('=' * 60);
  
  // Test multiple sports
  final sports = ['americanfootball_nfl', 'baseball_mlb', 'basketball_nba', 'icehockey_nhl'];
  
  for (final sport in sports) {
    print('\n📊 SPORT: ${sport.toUpperCase()}');
    print('-' * 60);
    
    // 1. Get events endpoint (game schedule)
    print('\n1️⃣ EVENTS ENDPOINT (game schedule):');
    final eventsUrl = 'https://api.the-odds-api.com/v4/sports/$sport/events?apiKey=$apiKey';
    
    try {
      final eventsResponse = await http.get(Uri.parse(eventsUrl));
      if (eventsResponse.statusCode == 200) {
        final events = json.decode(eventsResponse.body) as List;
        
        if (events.isNotEmpty) {
          final sampleEvent = events.first;
          print('   Sample Event Data:');
          print('   - ID: ${sampleEvent['id']}');
          print('   - Sport: ${sampleEvent['sport_key']}');
          print('   - Title: ${sampleEvent['sport_title']}');
          print('   - Commence Time: ${sampleEvent['commence_time']}');
          print('   - Home Team: ${sampleEvent['home_team']}');
          print('   - Away Team: ${sampleEvent['away_team']}');
          print('   - All fields: ${sampleEvent.keys.toList()}');
          print('   Total Events: ${events.length}');
          
          // Check what's available vs what's missing
          print('\n   ✅ Available:');
          print('      - Unique event ID (UUID format)');
          print('      - Team names');
          print('      - Game time');
          print('      - Home/Away designation');
          
          print('\n   ❌ Missing (that ESPN provides):');
          print('      - Team logos/images');
          print('      - Team records (W-L)');
          print('      - League/Conference info');
          print('      - Venue/Stadium');
          print('      - TV broadcast info');
          print('      - Game status (scheduled/live/final)');
          print('      - Scores (for live/completed games)');
          
          // 2. Get odds for this event
          final eventId = sampleEvent['id'];
          print('\n2️⃣ ODDS ENDPOINT (betting lines):');
          final oddsUrl = 'https://api.the-odds-api.com/v4/sports/$sport/events/$eventId/odds'
              '?apiKey=$apiKey&regions=us&markets=h2h,spreads,totals&oddsFormat=american';
          
          final oddsResponse = await http.get(Uri.parse(oddsUrl));
          if (oddsResponse.statusCode == 200) {
            final oddsData = json.decode(oddsResponse.body);
            final bookmakers = oddsData['bookmakers'] ?? [];
            
            if (bookmakers.isNotEmpty) {
              print('   Bookmakers: ${bookmakers.length}');
              final sampleBook = bookmakers.first;
              print('   Sample: ${sampleBook['title']}');
              final markets = sampleBook['markets'] ?? [];
              print('   Markets available: ${markets.map((m) => m['key']).toList()}');
            }
          }
          
          // 3. Check scores endpoint
          print('\n3️⃣ SCORES ENDPOINT (live/final scores):');
          final scoresUrl = 'https://api.the-odds-api.com/v4/sports/$sport/scores'
              '?apiKey=$apiKey&daysFrom=1';
          
          final scoresResponse = await http.get(Uri.parse(scoresUrl));
          if (scoresResponse.statusCode == 200) {
            final scores = json.decode(scoresResponse.body) as List;
            
            if (scores.isNotEmpty) {
              final sampleScore = scores.first;
              print('   Sample Score Data:');
              print('   - ID: ${sampleScore['id']}');
              print('   - Completed: ${sampleScore['completed']}');
              print('   - Home Score: ${sampleScore['scores']?['home_team']}');
              print('   - Away Score: ${sampleScore['scores']?['away_team']}');
              print('   - Last Update: ${sampleScore['last_update']}');
              print('   Total Games with Scores: ${scores.length}');
            } else {
              print('   No games with scores available');
            }
          }
          
        } else {
          print('   No events available for this sport');
        }
      }
    } catch (e) {
      print('   Error: $e');
    }
  }
  
  print('\n' + '=' * 60);
  print('\n📋 SUMMARY - Can we use Odds API only?');
  print('-' * 60);
  
  print('\n✅ PROS of using Odds API only:');
  print('   • Single source of truth for games');
  print('   • Event IDs always match for odds/props');
  print('   • Real-time odds data');
  print('   • Live scores available');
  print('   • Consistent data structure across sports');
  print('   • No synchronization issues');
  
  print('\n❌ CONS of using Odds API only:');
  print('   • No team logos/images');
  print('   • No team records or standings');
  print('   • No venue information');
  print('   • No TV/streaming info');
  print('   • Limited historical data');
  print('   • API call limits (500/month free tier)');
  
  print('\n🎯 RECOMMENDATION:');
  print('   Use Odds API as primary source for:');
  print('   - Game listings (events endpoint)');
  print('   - Odds and props (odds endpoint)');
  print('   - Live scores (scores endpoint)');
  print('   ');
  print('   Optionally enhance with ESPN for:');
  print('   - Team logos (can be cached)');
  print('   - Team records (nice to have)');
  print('   - Venue info (nice to have)');
  
  print('\n' + '=' * 60);
}