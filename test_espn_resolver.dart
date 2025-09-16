/// Test script for ESPN ID Resolver
///
/// This test will:
/// 1. Create a game with Odds API ID
/// 2. Try to resolve the ESPN ID
/// 3. Verify the resolution works
///
/// Run with: dart test_espn_resolver.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== ESPN ID RESOLVER TEST ===\n');

  // Test data - using the actual IDs from your logs
  final testGame = {
    'id': 'b57e123101e4d592a1725d80fed2dc75',  // Odds API hash ID
    'sport': 'MLB',
    'homeTeam': 'Washington Nationals',
    'awayTeam': 'Atlanta Braves',
    'gameTime': DateTime.now(),
  };

  print('Test Game:');
  print('  Odds API ID: ${testGame['id']}');
  print('  Teams: ${testGame['awayTeam']} @ ${testGame['homeTeam']}');
  print('  Sport: ${testGame['sport']}');
  print('\n');

  // Test 1: Check if this is an Odds API ID format
  testIdFormat(testGame['id'] as String);

  // Test 2: Fetch ESPN scoreboard and find matching game
  final espnId = await testEspnResolution(testGame);

  // Test 3: Verify ESPN ID works
  if (espnId != null) {
    await testEspnApiWithId(espnId);
  }

  // Test 4: Show resolution strategy
  showResolutionStrategy();
}

void testIdFormat(String id) {
  print('TEST 1: ID Format Analysis');
  print('-' * 40);

  final isOddsApiFormat = id.length == 32 && RegExp(r'^[a-f0-9]+$').hasMatch(id);
  final isEspnFormat = RegExp(r'^\d+$').hasMatch(id);

  print('  ID: $id');
  print('  Length: ${id.length} characters');
  print('  Is Odds API format (MD5): $isOddsApiFormat');
  print('  Is ESPN format (numeric): $isEspnFormat');

  if (isOddsApiFormat) {
    print('  ✅ Confirmed: This is an Odds API hash ID');
    print('  ⚠️ Needs resolution to ESPN ID for details page');
  }

  print('\n');
}

Future<String?> testEspnResolution(Map<String, dynamic> game) async {
  print('TEST 2: ESPN ID Resolution');
  print('-' * 40);

  try {
    // Fetch ESPN MLB scoreboard
    final url = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard';
    print('Fetching ESPN scoreboard...');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] as List? ?? [];

      print('✅ Found ${events.length} MLB games on ESPN\n');

      // Look for matching game
      print('Searching for: ${game['awayTeam']} @ ${game['homeTeam']}');

      for (final event in events) {
        final competition = event['competitions']?[0];
        if (competition == null) continue;

        final competitors = competition['competitors'] as List? ?? [];
        if (competitors.length < 2) continue;

        // Get team names
        final homeTeam = competitors.firstWhere(
          (c) => c['homeAway'] == 'home',
          orElse: () => {},
        )['team']?['displayName'] ?? '';

        final awayTeam = competitors.firstWhere(
          (c) => c['homeAway'] == 'away',
          orElse: () => {},
        )['team']?['displayName'] ?? '';

        // Debug output
        print('  Checking: $awayTeam @ $homeTeam');

        // Check for match (with normalization)
        if (teamsMatch(homeTeam, awayTeam, game['homeTeam'], game['awayTeam'])) {
          final espnId = event['id'].toString();
          print('\n✅ MATCH FOUND!');
          print('  ESPN ID: $espnId');
          print('  Event: $awayTeam @ $homeTeam');
          print('  Date: ${event['date']}');
          return espnId;
        }
      }

      print('\n❌ No match found');
      print('Possible reasons:');
      print('  - Game is not today');
      print('  - Team names don\'t match exactly');
      print('  - Game has been postponed/cancelled');
    } else {
      print('❌ ESPN API failed with status: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n');
  return null;
}

bool teamsMatch(String espnHome, String espnAway, String gameHome, String gameAway) {
  // Normalize team names
  String normalize(String team) {
    return team.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  final nEspnHome = normalize(espnHome);
  final nEspnAway = normalize(espnAway);
  final nGameHome = normalize(gameHome);
  final nGameAway = normalize(gameAway);

  // Check both orderings (in case home/away are swapped)
  return (nEspnHome == nGameHome && nEspnAway == nGameAway) ||
         (nEspnHome == nGameAway && nEspnAway == nGameHome);
}

Future<void> testEspnApiWithId(String espnId) async {
  print('TEST 3: Verify ESPN ID Works');
  print('-' * 40);

  try {
    final url = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=$espnId';
    print('Testing ESPN summary API with ID: $espnId');
    print('URL: $url\n');

    final response = await http.get(Uri.parse(url));

    print('Response status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print('✅ ESPN API call successful!');

      // Check what data is available
      print('\nAvailable data sections:');
      data.keys.forEach((key) {
        print('  - $key');
      });

      // Check for box score
      if (data['boxscore'] != null) {
        print('\n✅ Box score data available');
        final teams = data['boxscore']['teams'] as List? ?? [];
        for (final team in teams) {
          print('  - ${team['team']['displayName']}');
        }
      }

      // Check for game info
      if (data['gameInfo'] != null) {
        print('\n✅ Game info available');
      }
    } else {
      print('❌ ESPN API failed with status: ${response.statusCode}');
      print('This might mean:');
      print('  - Wrong ESPN ID');
      print('  - Game not found');
      print('  - API issue');
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n');
}

void showResolutionStrategy() {
  print('RESOLUTION STRATEGY SUMMARY');
  print('=' * 50);
  print('''
How the ESPN ID Resolver Works:

1. INPUT: Game with Odds API ID
   - ID: b57e123101e4d592a1725d80fed2dc75 (MD5 hash)
   - Has team names and game time

2. RESOLUTION PROCESS:
   a. Check if ESPN ID already exists (cached)
   b. If not, fetch ESPN scoreboard for the sport
   c. Match by team names (normalized)
   d. Optional: Verify date is close (within 24 hours)
   e. Return ESPN ID if match found

3. CACHING:
   - Store mapping in memory (fast)
   - Store in Firestore (persistent)
   - Update game with ESPN ID

4. USAGE:
   - Odds API ID → Game listings (more comprehensive)
   - ESPN ID → Game details (richer data)

5. BENEFITS:
   - Best of both APIs
   - Automatic resolution
   - Cached for performance
   - Fallback handling

6. IMPLEMENTATION:
   ```dart
   // In game details page
   final resolver = EspnIdResolverService();
   final espnId = await resolver.resolveEspnId(game);

   if (espnId != null) {
     // Use ESPN API for details
     fetchEspnDetails(espnId);
   } else {
     // Show limited info or error
     showLimitedDetails();
   }
   ```
''');
}