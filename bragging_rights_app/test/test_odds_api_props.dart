import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Test script to explore prop bet markets from The Odds API
void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['ODDS_API_KEY'] ?? '';
  
  if (apiKey.isEmpty) {
    print('❌ No API key found in .env file');
    return;
  }
  
  print('🔍 Testing The Odds API for Prop Bet Markets\n');
  print('=' * 50);
  
  // Test different sports and their available prop markets
  final sports = [
    {'key': 'americanfootball_nfl', 'name': 'NFL'},
    {'key': 'basketball_nba', 'name': 'NBA'},
    {'key': 'baseball_mlb', 'name': 'MLB'},
    {'key': 'icehockey_nhl', 'name': 'NHL'},
  ];
  
  // Common prop markets to test
  final propMarkets = [
    // Player props
    'player_pass_tds',           // NFL: Passing touchdowns
    'player_pass_yds',           // NFL: Passing yards
    'player_rush_yds',           // NFL: Rushing yards
    'player_receptions',         // NFL: Receptions
    'player_reception_yds',      // NFL: Receiving yards
    'player_points',             // NBA: Points
    'player_rebounds',           // NBA: Rebounds
    'player_assists',            // NBA: Assists
    'player_threes',            // NBA: Three pointers made
    'player_blocks',            // NBA: Blocks
    'player_steals',            // NBA: Steals
    'player_points_rebounds',   // NBA: Points + Rebounds
    'player_points_assists',    // NBA: Points + Assists
    'player_rebounds_assists',  // NBA: Rebounds + Assists
    'player_hits',              // MLB: Hits
    'player_home_runs',         // MLB: Home runs
    'player_total_bases',       // MLB: Total bases
    'player_rbis',              // MLB: RBIs
    'player_strikeouts',        // MLB: Strikeouts (pitcher)
    'player_goals',             // NHL: Goals
    'player_shots_on_goal',     // NHL: Shots on goal
    
    // Team props
    'team_totals',              // Team total points
    'alternate_spreads',        // Alternative spread lines
    'alternate_totals',         // Alternative total lines
    
    // Game props  
    'btts',                     // Both teams to score
    'draw_no_bet',             // Draw no bet
    'double_chance',           // Double chance
  ];
  
  for (final sport in sports) {
    print('\n📊 Testing ${sport['name']} (${sport['key']})');
    print('-' * 40);
    
    // First, get a sample game
    final gamesUrl = 'https://api.the-odds-api.com/v4/sports/${sport['key']}/odds/?'
        'apiKey=$apiKey&regions=us&markets=h2h&oddsFormat=american';
    
    try {
      final gamesResponse = await http.get(Uri.parse(gamesUrl));
      
      if (gamesResponse.statusCode != 200) {
        print('❌ Failed to get games: ${gamesResponse.statusCode}');
        continue;
      }
      
      final games = json.decode(gamesResponse.body) as List;
      
      if (games.isEmpty) {
        print('⚠️  No games available');
        continue;
      }
      
      final game = games.first;
      print('✅ Found game: ${game['away_team']} @ ${game['home_team']}');
      print('   Game ID: ${game['id']}');
      print('   Commence time: ${game['commence_time']}');
      
      // Now test different prop markets for this game
      print('\n   Testing prop markets:');
      
      final availableProps = <String>[];
      
      // Test each prop market
      for (final market in propMarkets) {
        final propUrl = 'https://api.the-odds-api.com/v4/sports/${sport['key']}/odds/?'
            'apiKey=$apiKey&regions=us&markets=$market&oddsFormat=american';
        
        final propResponse = await http.get(Uri.parse(propUrl));
        
        if (propResponse.statusCode == 200) {
          final propData = json.decode(propResponse.body) as List;
          
          if (propData.isNotEmpty) {
            // Check if any game has this market
            bool hasMarket = false;
            for (final g in propData) {
              final bookmakers = g['bookmakers'] ?? [];
              for (final bookmaker in bookmakers) {
                final markets = bookmaker['markets'] ?? [];
                if (markets.any((m) => m['key'] == market)) {
                  hasMarket = true;
                  availableProps.add(market);
                  
                  // Get sample data for this market
                  final marketData = markets.firstWhere((m) => m['key'] == market);
                  final outcomes = marketData['outcomes'] ?? [];
                  
                  print('   ✅ $market - ${outcomes.length} outcomes');
                  
                  // Show first few outcomes as examples
                  for (int i = 0; i < outcomes.length && i < 3; i++) {
                    final outcome = outcomes[i];
                    print('      - ${outcome['name']}: ${outcome['price']} (${outcome['point'] ?? 'N/A'} points)');
                  }
                  
                  break;
                }
              }
              if (hasMarket) break;
            }
            
            if (!hasMarket) {
              print('   ❌ $market - No data');
            }
          } else {
            print('   ❌ $market - No data');
          }
        } else {
          print('   ❌ $market - API error: ${propResponse.statusCode}');
        }
        
        // Small delay to avoid rate limiting
        await Future.delayed(Duration(milliseconds: 500));
      }
      
      if (availableProps.isNotEmpty) {
        print('\n   📋 Summary: Found ${availableProps.length} prop markets:');
        for (final prop in availableProps) {
          print('      • $prop');
        }
      } else {
        print('\n   ⚠️  No prop markets available for ${sport['name']}');
      }
      
    } catch (e) {
      print('❌ Error testing ${sport['name']}: $e');
    }
    
    // Delay between sports to avoid rate limiting
    await Future.delayed(Duration(seconds: 1));
  }
  
  print('\n' + '=' * 50);
  print('✅ Testing complete!');
}