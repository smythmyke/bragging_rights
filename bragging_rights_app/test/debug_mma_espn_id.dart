import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Debug test to understand why MMA events aren't using ESPN IDs
void main() {
  test('Debug MMA ESPN ID issue', () async {
    print('\n' + '=' * 80);
    print('🔍 DEBUGGING MMA ESPN ID ISSUE');
    print('=' * 80);

    // Step 1: Check ESPN API
    print('\n📡 STEP 1: Checking ESPN MMA API...');
    print('-' * 60);

    final espnResponse = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
    );

    if (espnResponse.statusCode != 200) {
      print('❌ ESPN API failed with status: ${espnResponse.statusCode}');
      return;
    }

    final espnData = json.decode(espnResponse.body);
    final espnEvents = espnData['events'] as List? ?? [];

    print('✅ ESPN API working');
    print('   Events returned: ${espnEvents.length}');

    if (espnEvents.isEmpty) {
      print('⚠️ No ESPN events available');
      return;
    }

    final espnEvent = espnEvents.first;
    final espnEventId = espnEvent['id'];
    final espnEventName = espnEvent['name'] ?? 'Unknown';

    print('\n📋 First ESPN Event:');
    print('   Name: $espnEventName');
    print('   ID: $espnEventId');
    print('   ID Type: ${espnEventId.runtimeType}');
    print('   ID is null? ${espnEventId == null}');
    print('   ID toString: ${espnEventId?.toString() ?? "null"}');

    // Step 2: Check Odds API
    print('\n📡 STEP 2: Checking Odds API...');
    print('-' * 60);

    final oddsResponse = await http.get(
      Uri.parse('https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events?apiKey=51434300fd8bc16e4b57de822b1d4323'),
    );

    if (oddsResponse.statusCode != 200) {
      print('❌ Odds API failed with status: ${oddsResponse.statusCode}');
      return;
    }

    final oddsFights = json.decode(oddsResponse.body) as List;
    print('✅ Odds API working');
    print('   Fights returned: ${oddsFights.length}');

    // Step 3: Analyze ESPN event structure
    print('\n📊 STEP 3: Analyzing ESPN Event Structure...');
    print('-' * 60);

    final competitions = espnEvent['competitions'] as List? ?? [];
    print('Competitions (fights) in ESPN event: ${competitions.length}');

    final espnFighters = <String>[];
    for (int i = 0; i < competitions.length && i < 5; i++) {
      final comp = competitions[i];
      final competitors = comp['competitors'] as List? ?? [];

      if (competitors.length >= 2) {
        final fighter1 = competitors[0]['athlete']?['displayName'] ?? 'Unknown';
        final fighter2 = competitors[1]['athlete']?['displayName'] ?? 'Unknown';
        print('   Fight ${i+1}: $fighter1 vs $fighter2');
        espnFighters.add('$fighter1|$fighter2');
      }
    }

    // Step 4: Check if Odds API has matching fights
    print('\n🔍 STEP 4: Checking for Matches Between APIs...');
    print('-' * 60);

    int matchCount = 0;
    int noMatchCount = 0;

    for (final espnFightStr in espnFighters) {
      final parts = espnFightStr.split('|');
      final espnF1 = parts[0];
      final espnF2 = parts[1];

      print('\nLooking for ESPN fight: $espnF1 vs $espnF2');

      bool found = false;
      for (final oddsFight in oddsFights) {
        final oddsF1 = oddsFight['away_team']?.toString() ?? '';
        final oddsF2 = oddsFight['home_team']?.toString() ?? '';

        // Check exact match
        if (_exactMatch(espnF1, espnF2, oddsF1, oddsF2)) {
          print('  ✅ EXACT MATCH: $oddsF1 vs $oddsF2');
          matchCount++;
          found = true;
          break;
        }

        // Check last name match
        if (_lastNameMatch(espnF1, espnF2, oddsF1, oddsF2)) {
          print('  ✅ LAST NAME MATCH: $oddsF1 vs $oddsF2');
          matchCount++;
          found = true;
          break;
        }
      }

      if (!found) {
        print('  ❌ NO MATCH FOUND');
        noMatchCount++;

        // Show potential matches
        print('  Potential matches in Odds API:');
        for (final oddsFight in oddsFights) {
          final oddsF1 = oddsFight['away_team']?.toString() ?? '';
          final oddsF2 = oddsFight['home_team']?.toString() ?? '';

          if (_fuzzyMatch(espnF1, espnF2, oddsF1, oddsF2)) {
            print('    - $oddsF1 vs $oddsF2 (fuzzy match)');
          }
        }
      }
    }

    // Step 5: Analyze the results
    print('\n📊 STEP 5: Analysis Results');
    print('-' * 60);

    print('Match Statistics:');
    print('  ✅ Matched fights: $matchCount');
    print('  ❌ Unmatched fights: $noMatchCount');

    if (matchCount > 0) {
      print('\n✅ SHOULD USE ESPN ID: $espnEventId');
      print('   This is a valid numeric ID for the MMA service');
    } else {
      print('\n❌ WOULD FALL BACK TO CUSTOM ID');
      print('   No fights matched, so event would get custom ID');
    }

    // Step 6: Simulate the ID generation logic
    print('\n🔧 STEP 6: Simulating ID Generation Logic');
    print('-' * 60);

    final sport = 'MMA';
    final safeId = '${sport.toLowerCase()}_${espnEventName.toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('/', '_')
      .replaceAll(':', '')
      .replaceAll('.', '')
      .replaceAll('\'', '')
      .replaceAll('vs', 'v')}';

    print('Sport: $sport');
    print('Sport uppercase: ${sport.toUpperCase()}');
    print('Is MMA? ${sport.toUpperCase() == 'MMA'}');
    print('ESPN Event ID: $espnEventId');
    print('ESPN ID is not null? ${espnEventId != null}');
    print('Safe ID (fallback): $safeId');

    final shouldUseEspnId = (sport.toUpperCase() == 'MMA' && espnEventId != null);
    final finalId = shouldUseEspnId ? espnEventId.toString() : safeId;

    print('\nLogic evaluation:');
    print('  Should use ESPN ID? $shouldUseEspnId');
    print('  FINAL ID: $finalId');

    if (finalId == espnEventId.toString()) {
      print('\n✅ SUCCESS: Would use ESPN ID!');
    } else {
      print('\n❌ FAILURE: Would use custom ID instead of ESPN ID');
    }

    // Step 7: Final diagnosis
    print('\n🩺 FINAL DIAGNOSIS');
    print('-' * 60);

    if (matchCount == 0) {
      print('❌ PROBLEM IDENTIFIED: No fights are matching between ESPN and Odds API');
      print('   This causes the event to be skipped in _groupCombatSportsByEvent');
      print('   The unmatched fights then get grouped by time windows');
      print('   Time-based grouping creates custom IDs, not ESPN IDs');
      print('\nSOLUTION: Fix the fighter name matching logic or handle unmatched ESPN events');
    } else if (espnEventId == null) {
      print('❌ PROBLEM IDENTIFIED: ESPN event has null ID');
      print('   This would cause fallback to custom ID even with matches');
      print('\nSOLUTION: Investigate why ESPN API returns null IDs');
    } else {
      print('✅ No obvious problems found');
      print('   The issue might be in the actual implementation');
      print('   Check if the fix is actually deployed/reloaded');
    }
  });
}

bool _exactMatch(String espnF1, String espnF2, String oddsF1, String oddsF2) {
  final e1 = espnF1.toLowerCase();
  final e2 = espnF2.toLowerCase();
  final o1 = oddsF1.toLowerCase();
  final o2 = oddsF2.toLowerCase();

  return (e1 == o1 && e2 == o2) || (e1 == o2 && e2 == o1);
}

bool _lastNameMatch(String espnF1, String espnF2, String oddsF1, String oddsF2) {
  final e1Last = espnF1.toLowerCase().split(' ').last;
  final e2Last = espnF2.toLowerCase().split(' ').last;
  final o1 = oddsF1.toLowerCase();
  final o2 = oddsF2.toLowerCase();

  return (o1.contains(e1Last) && o2.contains(e2Last)) ||
         (o1.contains(e2Last) && o2.contains(e1Last));
}

bool _fuzzyMatch(String espnF1, String espnF2, String oddsF1, String oddsF2) {
  final e1Parts = espnF1.toLowerCase().split(' ');
  final e2Parts = espnF2.toLowerCase().split(' ');
  final o1 = oddsF1.toLowerCase();
  final o2 = oddsF2.toLowerCase();

  // Check if any part of the names match
  for (final part in e1Parts) {
    if (o1.contains(part) || o2.contains(part)) return true;
  }
  for (final part in e2Parts) {
    if (o1.contains(part) || o2.contains(part)) return true;
  }

  return false;
}