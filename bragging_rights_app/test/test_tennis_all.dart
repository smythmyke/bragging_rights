import 'package:http/http.dart' as http;
import 'dart:convert';

/// Find ALL tennis events currently available
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🎾 SEARCHING ALL TENNIS EVENTS');
  print('=' * 60);
  
  // First, get all available sports
  print('\n1️⃣ GETTING ALL SPORTS LIST...');
  final sportsUrl = 'https://api.the-odds-api.com/v4/sports?apiKey=$apiKey';
  
  try {
    final sportsResponse = await http.get(Uri.parse(sportsUrl));
    
    if (sportsResponse.statusCode != 200) {
      print('❌ Failed to get sports: ${sportsResponse.statusCode}');
      return;
    }
    
    final sports = json.decode(sportsResponse.body) as List;
    
    // Find all tennis sports
    final tennisSports = sports.where((sport) => 
      sport['key'].toString().toLowerCase().contains('tennis')).toList();
    
    print('✅ Found ${tennisSports.length} tennis sports available');
    
    for (final sport in tennisSports) {
      print('\n  📌 ${sport['key']}');
      print('     Title: ${sport['title']}');
      print('     Active: ${sport['active']}');
      print('     Has Outrights: ${sport['has_outrights']}');
    }
    
    // Now check events for each tennis sport
    print('\n2️⃣ CHECKING EVENTS FOR EACH TENNIS SPORT...');
    print('-' * 60);
    
    int totalMatches = 0;
    
    for (final sport in tennisSports) {
      if (sport['active'] == true) {
        final sportKey = sport['key'];
        final eventsUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/events?apiKey=$apiKey';
        
        final eventsResponse = await http.get(Uri.parse(eventsUrl));
        
        if (eventsResponse.statusCode == 200) {
          final events = json.decode(eventsResponse.body) as List;
          
          if (events.isNotEmpty) {
            print('\n✅ ${sport['title']} ($sportKey):');
            print('   ${events.length} matches available!');
            totalMatches += events.length;
            
            // Show first 5 matches
            print('\n   First matches:');
            for (int i = 0; i < events.length && i < 5; i++) {
              final match = events[i];
              print('   • ${match['away_team']} vs ${match['home_team']}');
              print('     Time: ${match['commence_time']}');
            }
            
            // Test odds for first match
            if (events.isNotEmpty) {
              final firstMatch = events.first;
              final matchId = firstMatch['id'];
              
              print('\n   Testing odds for: ${firstMatch['away_team']} vs ${firstMatch['home_team']}');
              
              final oddsUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/events/$matchId/odds'
                  '?apiKey=$apiKey&regions=us&markets=h2h&oddsFormat=american';
              
              final oddsResponse = await http.get(Uri.parse(oddsUrl));
              
              if (oddsResponse.statusCode == 200) {
                final oddsData = json.decode(oddsResponse.body);
                final bookmakers = oddsData['bookmakers'] ?? [];
                print('   ✅ Odds available from ${bookmakers.length} bookmakers');
                
                if (bookmakers.isNotEmpty) {
                  final firstBook = bookmakers.first;
                  final markets = firstBook['markets'] ?? [];
                  if (markets.isNotEmpty) {
                    final h2h = markets.first;
                    print('\n   ${firstBook['title']} odds:');
                    for (final outcome in h2h['outcomes']) {
                      print('     ${outcome['name']}: ${outcome['price']}');
                    }
                  }
                }
              }
            }
          }
        }
      }
    }
    
    print('\n' + '=' * 60);
    print('SUMMARY:');
    print('✅ Tennis sports found: ${tennisSports.length}');
    print('✅ Total matches available: $totalMatches');
    
    if (totalMatches == 0) {
      print('\n⚠️ No tennis matches currently available');
      print('This could mean tournaments are between rounds or no events scheduled today');
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}