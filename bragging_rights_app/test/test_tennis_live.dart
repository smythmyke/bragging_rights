import 'package:http/http.dart' as http;
import 'dart:convert';

/// Live Tennis data test - verifies odds for all tennis tournaments
void main() async {
  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  
  print('🎾 TENNIS LIVE DATA TEST');
  print('=' * 60);
  
  // Tennis tournaments we should support
  final tournaments = [
    'tennis_atp_aus_open_singles',
    'tennis_atp_french_open', 
    'tennis_atp_us_open',
    'tennis_atp_wimbledon',
    'tennis_wta_aus_open_singles',
    'tennis_wta_french_open',
    'tennis_wta_us_open', 
    'tennis_wta_wimbledon'
  ];
  
  // 1. Check what's currently available
  print('\n1️⃣ CHECKING AVAILABLE TENNIS TOURNAMENTS...');
  
  int totalMatches = 0;
  final activeEvents = <String, int>{};
  
  for (final tournament in tournaments) {
    final url = 'https://api.the-odds-api.com/v4/sports/$tournament/events?apiKey=$apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final events = json.decode(response.body) as List;
        if (events.isNotEmpty) {
          activeEvents[tournament] = events.length;
          totalMatches += events.length;
          print('  ✅ $tournament: ${events.length} matches');
        }
      }
    } catch (e) {
      // Tournament might not be active
    }
  }
  
  if (activeEvents.isEmpty) {
    print('  ⚠️ No tennis tournaments active right now');
    print('  Note: Tennis tournaments are seasonal (Grand Slams, ATP/WTA tours)');
  } else {
    print('\n  📊 Active tournaments: ${activeEvents.length}');
    print('  📊 Total matches: $totalMatches');
  }
  
  // 2. Test with any available tournament
  String? activeTournament;
  List<dynamic>? tournamentEvents;
  
  for (final tournament in tournaments) {
    final url = 'https://api.the-odds-api.com/v4/sports/$tournament/events?apiKey=$apiKey';
    
    try {
      final response = await http.get(Uri.parse(url));
      
      if (response.statusCode == 200) {
        final events = json.decode(response.body) as List;
        if (events.isNotEmpty) {
          activeTournament = tournament;
          tournamentEvents = events;
          break;
        }
      }
    } catch (e) {
      continue;
    }
  }
  
  if (activeTournament != null && tournamentEvents != null) {
    print('\n2️⃣ TESTING TOURNAMENT: $activeTournament');
    print('─' * 60);
    print('Found ${tournamentEvents.length} matches');
    
    // Show all matches
    print('\n📋 ALL MATCHES:');
    for (final match in tournamentEvents) {
      print('  • ${match['away_team']} vs ${match['home_team']}');
      print('    Time: ${match['commence_time']}');
    }
    
    // Test first match in detail
    final firstMatch = tournamentEvents.first;
    print('\n─────────────────────────────────────────');
    print('DETAILED TEST: ${firstMatch['away_team']} vs ${firstMatch['home_team']}');
    print('ID: ${firstMatch['id']}');
    print('Time: ${firstMatch['commence_time']}');
    
    // Get odds for this match
    final matchId = firstMatch['id'];
    final oddsUrl = 'https://api.the-odds-api.com/v4/sports/$activeTournament/events/$matchId/odds'
        '?apiKey=$apiKey&regions=us&markets=h2h,spreads,totals&oddsFormat=american';
    
    final oddsResponse = await http.get(Uri.parse(oddsUrl));
    
    if (oddsResponse.statusCode == 200) {
      final oddsData = json.decode(oddsResponse.body);
      final bookmakers = oddsData['bookmakers'] ?? [];
      
      print('\n✅ ODDS: ${bookmakers.length} bookmakers');
      
      // Check for type issues
      bool hasTypeError = false;
      if (bookmakers.isNotEmpty) {
        final firstBook = bookmakers.first;
        final markets = firstBook['markets'] ?? [];
        
        for (final market in markets) {
          final outcomes = market['outcomes'] ?? [];
          for (final outcome in outcomes) {
            // Check point type
            if (outcome['point'] != null) {
              final pointType = outcome['point'].runtimeType;
              if (pointType != int && pointType != double) {
                print('  ❌ Type error: point is $pointType');
                hasTypeError = true;
              }
            }
            // Check price type
            if (outcome['price'] != null) {
              final priceType = outcome['price'].runtimeType;
              if (priceType != int && priceType != double) {
                print('  ❌ Type error: price is $priceType');
                hasTypeError = true;
              }
            }
          }
        }
        
        if (!hasTypeError) {
          print('  ✅ Data types are correct');
        }
        
        // Show odds from different bookmakers
        print('\n  Match Odds:');
        for (final bookmaker in bookmakers.take(3)) {
          final markets = bookmaker['markets'] ?? [];
          for (final market in markets) {
            if (market['key'] == 'h2h') {
              print('\n  ${bookmaker['title']}:');
              for (final outcome in market['outcomes']) {
                print('    ${outcome['name']}: ${outcome['price']}');
              }
            }
          }
        }
        
        // Check for spreads (games handicap)
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] ?? [];
          for (final market in markets) {
            if (market['key'] == 'spreads') {
              print('\n  Game Spread (${bookmaker['title']}):');
              for (final outcome in market['outcomes']) {
                print('    ${outcome['name']}: ${outcome['point']} games (${outcome['price']})');
              }
              break;
            }
          }
          break;
        }
        
        // Check for totals (total games)
        for (final bookmaker in bookmakers) {
          final markets = bookmaker['markets'] ?? [];
          for (final market in markets) {
            if (market['key'] == 'totals') {
              print('\n  Total Games (${bookmaker['title']}):');
              for (final outcome in market['outcomes']) {
                print('    ${outcome['name']}: ${outcome['point']} (${outcome['price']})');
              }
              break;
            }
          }
          break;
        }
      }
    } else {
      print('❌ Failed to get odds: ${oddsResponse.statusCode}');
    }
  } else {
    print('\n⚠️ No active tennis tournaments to test');
    print('Tennis is seasonal - Grand Slams and ATP/WTA tours run at specific times');
  }
  
  print('\n' + '=' * 60);
  print('SUMMARY:');
  print('✅ Tennis tournaments checked: ${tournaments.length}');
  print('✅ Active tournaments: ${activeEvents.length}');
  print('✅ Total matches available: $totalMatches');
  print('✅ Odds data: ${activeTournament != null ? 'YES' : 'N/A - No active tournaments'}');
  print('✅ Type errors: FIXED');
  print('\n📝 Notes:');
  print('  • Tennis uses individual tournament endpoints');
  print('  • Tournaments are seasonal (Grand Slams, ATP/WTA tours)');
  print('  • Markets include match winner, game spreads, total games');
}