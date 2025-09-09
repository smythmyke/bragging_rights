import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

// Test to find available MMA sport keys
void main() async {
  // Load environment variables
  await dotenv.load(fileName: '.env');
  final apiKey = dotenv.env['ODDS_API_KEY'] ?? '';
  
  if (apiKey.isEmpty) {
    print('❌ No API key found in .env file');
    return;
  }
  
  print('🔍 Testing Available Sports for MMA/Combat Sports\n');
  print('=' * 60);
  
  try {
    // Get all available sports
    final sportsUrl = 'https://api.the-odds-api.com/v4/sports/?apiKey=$apiKey';
    final response = await http.get(Uri.parse(sportsUrl));
    
    if (response.statusCode == 200) {
      final sports = json.decode(response.body) as List;
      
      print('✅ Found ${sports.length} total sports\n');
      
      // Filter for combat sports (MMA, Boxing)
      final combatSports = sports.where((sport) {
        final key = sport['key']?.toString().toLowerCase() ?? '';
        final title = sport['title']?.toString().toLowerCase() ?? '';
        
        return key.contains('mma') || 
               key.contains('ufc') || 
               key.contains('boxing') ||
               key.contains('bellator') ||
               key.contains('pfl') ||
               title.contains('mma') ||
               title.contains('ufc') ||
               title.contains('boxing') ||
               title.contains('bellator') ||
               title.contains('pfl');
      }).toList();
      
      print('🥊 COMBAT SPORTS FOUND (${combatSports.length}):\n');
      
      for (final sport in combatSports) {
        final key = sport['key'] ?? 'N/A';
        final title = sport['title'] ?? 'N/A';
        final group = sport['group'] ?? 'N/A';
        final active = sport['active'] ?? false;
        final hasOutrights = sport['has_outrights'] ?? false;
        
        print('📍 Key: $key');
        print('   Title: $title');
        print('   Group: $group');
        print('   Active: $active');
        print('   Has Outrights: $hasOutrights');
        print('');
      }
      
      // Test a few MMA events to see what's available
      print('\n🎯 TESTING MMA EVENT AVAILABILITY:\n');
      
      final mmaKeys = combatSports.map((s) => s['key'] as String).toList();
      
      for (final sportKey in mmaKeys.take(3)) { // Test first 3
        try {
          final eventsUrl = 'https://api.the-odds-api.com/v4/sports/$sportKey/events?apiKey=$apiKey';
          final eventResponse = await http.get(Uri.parse(eventsUrl));
          
          if (eventResponse.statusCode == 200) {
            final events = json.decode(eventResponse.body) as List;
            print('🔸 $sportKey: ${events.length} upcoming events');
            
            if (events.isNotEmpty) {
              final event = events.first;
              print('   Example: ${event['away_team']} vs ${event['home_team']}');
              print('   Date: ${event['commence_time']}');
            }
          } else {
            print('🔸 $sportKey: API error ${eventResponse.statusCode}');
          }
        } catch (e) {
          print('🔸 $sportKey: Error - $e');
        }
        print('');
      }
      
    } else {
      print('❌ Failed to get sports list: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        final error = json.decode(response.body);
        print('Error: ${error['message']}');
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('=' * 60);
  print('🏁 Test Complete');
}