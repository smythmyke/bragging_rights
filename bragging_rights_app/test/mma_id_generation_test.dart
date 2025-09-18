import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test to understand why MMA events still have custom IDs
/// This simulates the exact flow in optimized_games_service.dart
void main() {
  group('MMA ID Generation Test', () {
    test('Simulate complete MMA event creation flow', () async {
      print('\n🔍 TESTING MMA EVENT ID GENERATION FLOW\n');
      print('=' * 60);

      // Step 1: Fetch ESPN MMA Events
      print('\n📋 STEP 1: Fetching ESPN MMA Events');
      print('-' * 40);

      final espnResponse = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
      );

      if (espnResponse.statusCode != 200) {
        print('❌ Failed to fetch ESPN events');
        return;
      }

      final espnData = json.decode(espnResponse.body);
      final espnEvents = espnData['events'] as List? ?? [];

      if (espnEvents.isEmpty) {
        print('⚠️ No ESPN events available');
        return;
      }

      final espnEvent = espnEvents.first;
      print('✅ ESPN Event found:');
      print('   Name: ${espnEvent['name']}');
      print('   ID: ${espnEvent['id']}');
      print('   ID Type: ${espnEvent['id'].runtimeType}');

      // Step 2: Fetch Odds API MMA fights
      print('\n📋 STEP 2: Fetching Odds API MMA Fights');
      print('-' * 40);

      final oddsResponse = await http.get(
        Uri.parse('https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events?apiKey=51434300fd8bc16e4b57de822b1d4323'),
      );

      if (oddsResponse.statusCode != 200) {
        print('❌ Failed to fetch Odds API fights');
        return;
      }

      final oddsFights = json.decode(oddsResponse.body) as List;
      print('✅ Odds API returned ${oddsFights.length} individual fights');

      if (oddsFights.isNotEmpty) {
        final firstFight = oddsFights.first;
        print('   Example fight:');
        print('   ID: ${firstFight['id']}');
        print('   Fighters: ${firstFight['away_team']} vs ${firstFight['home_team']}');
      }

      // Step 3: Simulate the grouping logic
      print('\n📋 STEP 3: Simulating Event Grouping Logic');
      print('-' * 40);

      // This simulates what happens in _groupCombatSportsByEvent
      final sport = 'MMA';
      final eventName = espnEvent['name'] ?? 'UFC Event';

      // OLD CODE (creates custom ID):
      final safeIdOld = '${sport.toLowerCase()}_${eventName.toLowerCase()
        .replaceAll(' ', '_')
        .replaceAll('/', '_')
        .replaceAll(':', '')
        .replaceAll('.', '')
        .replaceAll('\'', '')
        .replaceAll('vs', 'v')}';

      print('\n❌ OLD IMPLEMENTATION:');
      print('   Generated ID: $safeIdOld');
      print('   ESPN ID stored: null');
      print('   Result: Invalid ID for MMA service');

      // NEW CODE (should use ESPN ID for MMA):
      final espnEventId = espnEvent['id']?.toString();
      final eventIdNew = (sport.toUpperCase() == 'MMA' && espnEventId != null)
          ? espnEventId
          : safeIdOld;

      print('\n✅ NEW IMPLEMENTATION:');
      print('   Generated ID: $eventIdNew');
      print('   ESPN ID stored: $espnEventId');
      print('   Result: Valid ESPN ID for MMA service');

      // Step 4: Check what's happening in the actual flow
      print('\n📋 STEP 4: Analyzing the Issue');
      print('-' * 40);

      print('\nPOSSIBLE REASONS FOR FAILURE:');
      print('1. ❓ ESPN events might not be fetched successfully');
      print('2. ❓ ESPN event ID might be null or missing');
      print('3. ❓ The fix might not be deployed/hot-reloaded');
      print('4. ❓ Events might be cached with old IDs');
      print('5. ❓ The matching logic might not find ESPN events');

      // Step 5: Verify the fix is correct
      print('\n📋 STEP 5: Verifying Fix Logic');
      print('-' * 40);

      // Test with actual event ID from logs
      const loggedId = 'mma_szymon_bajor_v_ricardo_prasel';
      final isValidEspnId = RegExp(r'^\d+$').hasMatch(loggedId);

      print('Event ID from logs: $loggedId');
      print('Is valid ESPN ID: $isValidEspnId');

      if (!isValidEspnId) {
        print('\n🚨 CONFIRMED: The app is still using custom IDs!');
        print('   This means either:');
        print('   a) The fix isn\'t applied yet (needs rebuild/restart)');
        print('   b) ESPN events aren\'t being fetched/matched');
        print('   c) Events are cached with old IDs');
      }

      // Step 6: Test ESPN event fetching
      print('\n📋 STEP 6: Testing ESPN Event Fetching');
      print('-' * 40);

      // Check if we can fetch ESPN events for MMA
      try {
        final testResponse = await http.get(
          Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
        );

        if (testResponse.statusCode == 200) {
          final testData = json.decode(testResponse.body);
          final testEvents = testData['events'] as List? ?? [];

          print('✅ ESPN MMA API is working');
          print('   Events available: ${testEvents.length}');

          for (int i = 0; i < testEvents.length && i < 3; i++) {
            final evt = testEvents[i];
            print('   Event ${i+1}: ${evt['name']} (ID: ${evt['id']})');
          }
        } else {
          print('❌ ESPN MMA API returned status: ${testResponse.statusCode}');
        }
      } catch (e) {
        print('❌ Error fetching ESPN events: $e');
      }
    });

    test('Check if fights match ESPN events', () async {
      print('\n🔍 TESTING FIGHT MATCHING LOGIC\n');
      print('=' * 60);

      // Get ESPN events
      final espnResponse = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
      );

      if (espnResponse.statusCode == 200) {
        final espnData = json.decode(espnResponse.body);
        final espnEvents = espnData['events'] as List? ?? [];

        if (espnEvents.isNotEmpty) {
          final event = espnEvents.first;
          print('ESPN Event: ${event['name']}');

          // Get competitions (fights) for this event
          final competitions = event['competitions'] as List? ?? [];
          print('Fights in ESPN event: ${competitions.length}');

          if (competitions.isNotEmpty) {
            // Get first fight details
            final firstComp = competitions.first;
            final competitors = firstComp['competitors'] as List? ?? [];

            if (competitors.length >= 2) {
              final fighter1 = competitors[0]['athlete']?['displayName'] ?? 'Unknown';
              final fighter2 = competitors[1]['athlete']?['displayName'] ?? 'Unknown';

              print('\nFirst fight in ESPN event:');
              print('  $fighter1 vs $fighter2');

              // Now check if Odds API has matching fights
              final oddsResponse = await http.get(
                Uri.parse('https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events?apiKey=51434300fd8bc16e4b57de822b1d4323'),
              );

              if (oddsResponse.statusCode == 200) {
                final oddsFights = json.decode(oddsResponse.body) as List;

                print('\nSearching for match in Odds API...');
                bool foundMatch = false;

                for (final fight in oddsFights) {
                  final oddsF1 = fight['away_team']?.toString().toLowerCase() ?? '';
                  final oddsF2 = fight['home_team']?.toString().toLowerCase() ?? '';

                  if (_fightersMatch(fighter1, fighter2, oddsF1, oddsF2)) {
                    print('✅ MATCH FOUND in Odds API!');
                    print('   ESPN: $fighter1 vs $fighter2');
                    print('   Odds: ${fight['away_team']} vs ${fight['home_team']}');
                    foundMatch = true;
                    break;
                  }
                }

                if (!foundMatch) {
                  print('❌ No match found in Odds API');
                  print('   This could explain why ESPN IDs aren\'t being used');
                }
              }
            }
          }
        }
      }
    });
  });
}

// Helper function to match fighter names
bool _fightersMatch(String espnF1, String espnF2, String oddsF1, String oddsF2) {
  final espn1Lower = espnF1.toLowerCase();
  final espn2Lower = espnF2.toLowerCase();

  // Check both normal and reversed order
  return (oddsF1.contains(espn1Lower.split(' ').last) ||
          oddsF2.contains(espn2Lower.split(' ').last)) ||
         (oddsF1.contains(espn2Lower.split(' ').last) ||
          oddsF2.contains(espn1Lower.split(' ').last));
}