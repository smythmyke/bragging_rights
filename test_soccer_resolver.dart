// Test file to debug soccer resolver matching
// Run this with: dart test_soccer_resolver.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=== SOCCER ESPN RESOLVER TEST ===\n');

  await testEspnApi();
  await testTeamMatching();
}

Future<void> testEspnApi() async {
  print('STEP 1: Checking ESPN Premier League API');
  print('-' * 40);

  try {
    final url = 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard';
    print('Fetching: $url\n');

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] as List? ?? [];

      print('✅ Found ${events.length} games on ESPN\n');
      print('Games found:');
      print('-' * 40);

      for (int i = 0; i < events.length; i++) {
        final event = events[i];
        final competition = event['competitions']?[0];
        final competitors = competition?['competitors'] as List? ?? [];

        if (competitors.length >= 2) {
          // Find home and away teams
          Map<String, dynamic>? homeTeam;
          Map<String, dynamic>? awayTeam;

          for (final competitor in competitors) {
            if (competitor['homeAway'] == 'home') {
              homeTeam = competitor;
            } else if (competitor['homeAway'] == 'away') {
              awayTeam = competitor;
            }
          }

          final homeTeamName = homeTeam?['team']?['displayName'] ?? 'Unknown';
          final awayTeamName = awayTeam?['team']?['displayName'] ?? 'Unknown';
          final espnId = event['id'];
          final date = event['date'] ?? '';

          print('\nGame ${i + 1}:');
          print('  ESPN ID: $espnId');
          print('  Home: $homeTeamName');
          print('  Away: $awayTeamName');
          print('  Date: $date');

          // Check for our specific game
          if (homeTeamName.contains('Tottenham') || awayTeamName.contains('Tottenham')) {
            print('  🎯 FOUND TOTTENHAM!');
          }
          if (homeTeamName.contains('Brighton') || awayTeamName.contains('Brighton')) {
            print('  🎯 FOUND BRIGHTON!');
          }

          // Check if this is our game
          if ((homeTeamName.contains('Tottenham') && awayTeamName.contains('Brighton')) ||
              (homeTeamName.contains('Brighton') && awayTeamName.contains('Tottenham'))) {
            print('\n  ⭐⭐⭐ THIS IS OUR GAME! ⭐⭐⭐');
            print('  ESPN has it as: $awayTeamName @ $homeTeamName');
          }
        }
      }
    } else {
      print('❌ ESPN API returned status: ${response.statusCode}');
    }
  } catch (e) {
    print('❌ Error fetching ESPN games: $e');
  }
}

Future<void> testTeamMatching() async {
  print('\n\nSTEP 2: Testing Team Name Matching');
  print('-' * 40);

  // Our game data
  final ourHomeTeam = 'Tottenham Hotspur';
  final ourAwayTeam = 'Brighton and Hove Albion';

  print('Our game: $ourAwayTeam @ $ourHomeTeam');

  // Test normalization
  print('\nNormalization test:');
  print('  Tottenham Hotspur -> ${normalizeTeamName(ourHomeTeam)}');
  print('  Brighton and Hove Albion -> ${normalizeTeamName(ourAwayTeam)}');

  // Possible ESPN names
  final espnVariations = [
    ['Tottenham Hotspur', 'Brighton & Hove Albion'],
    ['Tottenham', 'Brighton'],
    ['Spurs', 'Brighton'],
    ['Tottenham Hotspur', 'Brighton'],
    ['Brighton & Hove Albion', 'Tottenham Hotspur'],  // Reversed
  ];

  print('\nTesting various ESPN name combinations:');
  for (final combo in espnVariations) {
    final espnHome = combo[0];
    final espnAway = combo[1];

    print('\n  ESPN: $espnAway @ $espnHome');

    final match1 = teamsMatch(espnHome, espnAway, ourHomeTeam, ourAwayTeam);
    final match2 = teamsMatch(espnHome, espnAway, ourAwayTeam, ourHomeTeam);

    if (match1) {
      print('  ✅ MATCH! (normal order)');
    } else if (match2) {
      print('  ✅ MATCH! (reversed order)');
    } else {
      print('  ❌ No match');
    }
  }
}

String normalizeTeamName(String team) {
  String normalized = team
      .toLowerCase()
      .replaceAll(' and ', ' ')  // Brighton and Hove -> Brighton Hove
      .replaceAll(' & ', ' ')     // Brighton & Hove -> Brighton Hove
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Remove special characters
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
      .trim();

  // For soccer teams, also create a shortened version
  if (normalized.contains('brighton')) {
    normalized = 'brighton';
  } else if (normalized.contains('tottenham')) {
    normalized = 'tottenham';
  }

  return normalized;
}

bool teamsMatch(String espnHome, String espnAway, String gameHome, String gameAway) {
  final normalizedEspnHome = normalizeTeamName(espnHome);
  final normalizedEspnAway = normalizeTeamName(espnAway);
  final normalizedGameHome = normalizeTeamName(gameHome);
  final normalizedGameAway = normalizeTeamName(gameAway);

  print('    Comparing: [$normalizedEspnHome, $normalizedEspnAway] vs [$normalizedGameHome, $normalizedGameAway]');

  // Check both normal order and reversed
  return (normalizedEspnHome == normalizedGameHome && normalizedEspnAway == normalizedGameAway) ||
         (normalizedEspnHome == normalizedGameAway && normalizedEspnAway == normalizedGameHome);
}