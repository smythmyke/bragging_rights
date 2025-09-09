import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';

// Test to find available MMA sport keys
void main() async {
  // Try to get API key from environment or use a placeholder
  String apiKey = Platform.environment['ODDS_API_KEY'] ?? ''; 
  
  // If no env var, read from .env file manually
  if (apiKey.isEmpty) {
    try {
      final envFile = File('.env');
      if (await envFile.exists()) {
        final content = await envFile.readAsString();
        final lines = content.split('\n');
        for (final line in lines) {
          if (line.startsWith('ODDS_API_KEY=')) {
            apiKey = line.split('=')[1].trim();
            break;
          }
        }
      }
    } catch (e) {
      print('Could not read .env file: $e');
    }
  }
  
  if (apiKey.isEmpty) {
    print('❌ No API key found. Please set ODDS_API_KEY environment variable');
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
      
    } else {
      print('❌ Failed to get sports list: ${response.statusCode}');
      if (response.body.isNotEmpty) {
        try {
          final error = json.decode(response.body);
          print('Error: ${error['message']}');
        } catch (e) {
          print('Error body: ${response.body}');
        }
      }
    }
    
  } catch (e) {
    print('❌ Error: $e');
  }
  
  print('=' * 60);
  print('🏁 Test Complete');
}