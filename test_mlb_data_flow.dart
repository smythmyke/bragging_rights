/// Test script to diagnose MLB data flow issues
///
/// This test will help us understand:
/// 1. Where games are being stored
/// 2. What format the IDs are in
/// 3. Why ESPN IDs aren't being saved
///
/// To run this test:
/// 1. Save this file in your project root
/// 2. Run: dart test_mlb_data_flow.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== MLB DATA FLOW TEST ===\n');

  // Test 1: Check if we can fetch MLB data from ESPN
  await testEspnApi();

  // Test 2: Check what IDs are returned
  await testIdFormats();

  // Test 3: Simulate the conversion process
  await testGameConversion();
}

Future<void> testEspnApi() async {
  print('TEST 1: ESPN API Connection');
  print('-' * 40);

  try {
    final url = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard';
    print('Fetching from: $url');

    final response = await http.get(Uri.parse(url));
    print('Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] as List?;

      if (events != null && events.isNotEmpty) {
        print('✅ Found ${events.length} MLB games\n');

        // Show first game details
        final firstGame = events[0];
        print('First game details:');
        print('  ID: ${firstGame['id']}');
        print('  ID Type: ${firstGame['id'].runtimeType}');
        print('  Name: ${firstGame['name']}');
        print('  Date: ${firstGame['date']}');

        // Check competition structure
        final competition = firstGame['competitions']?[0];
        if (competition != null) {
          final competitors = competition['competitors'] as List;
          print('\nTeams:');
          for (final team in competitors) {
            print('  ${team['homeAway']}: ${team['team']['displayName']}');
          }
        }
      } else {
        print('❌ No events found in response');
      }
    } else {
      print('❌ API request failed');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n');
}

Future<void> testIdFormats() async {
  print('TEST 2: ID Format Analysis');
  print('-' * 40);

  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard')
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] as List;

      print('Analyzing ID formats from ${events.length} games:\n');

      final idTypes = <String, int>{};
      final sampleIds = <String>[];

      for (final event in events) {
        final id = event['id'];
        final idStr = id.toString();

        // Categorize ID format
        String format;
        if (id is int || (id is String && RegExp(r'^\d+$').hasMatch(idStr))) {
          format = 'Numeric (ESPN format)';
        } else if (idStr.length == 32 && RegExp(r'^[a-f0-9]+$').hasMatch(idStr)) {
          format = 'MD5 Hash (Old format)';
        } else {
          format = 'Other';
        }

        idTypes[format] = (idTypes[format] ?? 0) + 1;

        if (sampleIds.length < 3) {
          sampleIds.add(idStr);
        }
      }

      print('ID Format Distribution:');
      idTypes.forEach((format, count) {
        print('  $format: $count games');
      });

      print('\nSample IDs:');
      for (final id in sampleIds) {
        print('  $id (length: ${id.length})');
      }

      // Check for specific game
      print('\nLooking for Atlanta Braves vs Washington Nationals:');
      for (final event in events) {
        final name = event['name'] ?? '';
        if (name.contains('Braves') && name.contains('Nationals')) {
          print('  Found: ${event['name']}');
          print('  ESPN ID: ${event['id']}');
          break;
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n');
}

Future<void> testGameConversion() async {
  print('TEST 3: Game Conversion Simulation');
  print('-' * 40);

  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard')
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] as List;

      if (events.isNotEmpty) {
        final event = events[0];
        print('Converting first game:\n');

        // Simulate the conversion process
        final espnId = event['id']?.toString();
        final gameTime = DateTime.parse(event['date'] ?? DateTime.now().toIso8601String());
        final sport = 'MLB';

        final internalId = espnId != null
            ? '${sport.toLowerCase()}_${espnId}_${gameTime.millisecondsSinceEpoch}'
            : '${sport}_${DateTime.now().millisecondsSinceEpoch}';

        print('Input event ID: ${event['id']}');
        print('ESPN ID extracted: $espnId');
        print('Internal ID generated: $internalId');

        // Check what would be stored
        print('\nWhat would be stored:');
        print('  id: $internalId');
        print('  espnId: $espnId');
        print('  sport: $sport');

        // Simulate retrieval
        print('\nSimulating retrieval:');
        if (espnId != null) {
          print('  ✅ ESPN ID available for API calls: $espnId');
        } else {
          print('  ❌ ESPN ID is null, API calls will fail');
        }

        // Check for the problematic ID
        print('\nChecking for problematic ID pattern:');
        final problematicId = 'b57e123101e4d592a1725d80fed2dc75';
        print('  Old format ID: $problematicId');
        print('  Length: ${problematicId.length}');
        print('  Pattern: MD5 hash (32 hex characters)');
        print('  This format is NOT from ESPN API');
        print('  Likely source: Old cache or manual generation');
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n');
}

// Helper function to simulate GameModel creation
Map<String, dynamic> createGameModel(Map<String, dynamic> event, String sport) {
  final competition = event['competitions']?[0];
  final competitors = competition?['competitors'] as List? ?? [];

  final homeTeam = competitors.firstWhere(
    (c) => c['homeAway'] == 'home',
    orElse: () => {'team': {'displayName': 'Unknown'}},
  );

  final awayTeam = competitors.firstWhere(
    (c) => c['homeAway'] == 'away',
    orElse: () => {'team': {'displayName': 'Unknown'}},
  );

  final espnId = event['id']?.toString();
  final gameTime = DateTime.parse(event['date'] ?? DateTime.now().toIso8601String());

  final internalId = espnId != null
      ? '${sport.toLowerCase()}_${espnId}_${gameTime.millisecondsSinceEpoch}'
      : '${sport}_${DateTime.now().millisecondsSinceEpoch}';

  return {
    'id': internalId,
    'espnId': espnId,
    'sport': sport,
    'homeTeam': homeTeam['team']['displayName'],
    'awayTeam': awayTeam['team']['displayName'],
    'gameTime': gameTime.toIso8601String(),
  };
}

void analyzeGameData() {
  print('\n=== ANALYSIS ===');
  print('-' * 40);

  print('''
The issue appears to be:

1. ESPN API returns numeric IDs (e.g., "401697155")
2. Your app has games with MD5 hash IDs (e.g., "b57e123101e4d592a1725d80fed2dc75")
3. These MD5 IDs are NOT from ESPN - they're from old cached data

The MD5 format suggests these games were either:
- Created by a different API service
- Generated manually in the past
- Cached from a previous version of the app

Solution:
1. Clear all cached games in Firestore
2. Force fresh fetch from ESPN API
3. Ensure new games use ESPN's numeric IDs

The workaround added will:
- Detect old MD5 format IDs
- Match games by team names
- Find the correct ESPN ID dynamically
''');
}