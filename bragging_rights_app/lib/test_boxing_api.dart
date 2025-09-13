import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'services/odds_api_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load environment variables
  await dotenv.load(fileName: ".env");
  
  print('Testing Boxing API for Canelo vs Crawford...\n');
  
  final oddsService = OddsApiService();
  await oddsService.ensureInitialized();
  
  try {
    // Get boxing events
    final events = await oddsService.getSportEvents('boxing');
    
    if (events == null || events.isEmpty) {
      print('❌ No boxing events returned from API');
      return;
    }
    
    print('✅ Found ${events.length} boxing events\n');
    
    // Look for Canelo vs Crawford
    bool foundFight = false;
    for (final event in events) {
      final homeTeam = event['home_team'] ?? '';
      final awayTeam = event['away_team'] ?? '';
      
      if (homeTeam.toLowerCase().contains('canelo') || 
          homeTeam.toLowerCase().contains('álvarez') ||
          awayTeam.toLowerCase().contains('crawford')) {
        print('🎯 FOUND THE FIGHT!');
        print('Event ID: ${event['id']}');
        print('Home: $homeTeam');
        print('Away: $awayTeam');
        print('Time: ${event['commence_time']}');
        print('Sport Title: ${event['sport_title']}');
        print('Full event data: $event\n');
        foundFight = true;
      }
    }
    
    if (!foundFight) {
      print('⚠️ Canelo vs Crawford not found in the events');
      print('\nShowing first 5 boxing events:');
      for (int i = 0; i < 5 && i < events.length; i++) {
        final event = events[i];
        print('${i+1}. ${event['away_team']} vs ${event['home_team']} - ${event['commence_time']}');
      }
    }
    
    // Now test converting to GameModel
    print('\n\nTesting conversion to GameModel...');
    final games = await oddsService.getSportGames('boxing', daysAhead: 14);
    print('✅ Converted ${games.length} boxing events to GameModel\n');
    
    for (final game in games) {
      if (game.homeTeam.toLowerCase().contains('canelo') || 
          game.awayTeam.toLowerCase().contains('crawford')) {
        print('🎯 FOUND IN GAMEMODEL:');
        print('ID: ${game.id}');
        print('${game.awayTeam} @ ${game.homeTeam}');
        print('Time: ${game.gameTime}');
        print('Sport: ${game.sport}');
        print('League: ${game.league}');
        break;
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
}