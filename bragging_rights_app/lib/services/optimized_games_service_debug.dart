// Temporary debug version of key methods to trace the issue

import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';

class OptimizedGamesServiceDebugger {
  /// Test ESPN event fetching with debug output
  static Future<void> testESPNEventFetching() async {
    debugPrint('\n' + '=' * 60);
    debugPrint('🔍 TESTING ESPN EVENT FETCHING FOR MMA');
    debugPrint('=' * 60);

    try {
      final url = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard';
      debugPrint('\n📡 Fetching from: $url');

      final response = await http.get(Uri.parse(url));
      debugPrint('   Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('   ❌ Failed to fetch ESPN events');
        return;
      }

      final data = json.decode(response.body);
      final events = data['events'] ?? [];

      debugPrint('\n📊 ESPN API Response:');
      debugPrint('   Total events: ${events.length}');

      for (int i = 0; i < events.length && i < 3; i++) {
        final event = events[i];
        final eventId = event['id'];
        final eventName = event['name'] ?? 'Unknown';

        debugPrint('\n   Event ${i+1}: $eventName');
        debugPrint('      ID: $eventId (Type: ${eventId.runtimeType})');
        debugPrint('      ID is String? ${eventId is String}');
        debugPrint('      ID toString: ${eventId.toString()}');

        final competitions = event['competitions'] ?? [];
        debugPrint('      Fights: ${competitions.length}');

        if (competitions.isNotEmpty) {
          final comp = competitions.first;
          final competitors = comp['competitors'] ?? [];
          if (competitors.length >= 2) {
            final fighter1 = competitors[0]['athlete']?['displayName'] ?? 'Unknown';
            final fighter2 = competitors[1]['athlete']?['displayName'] ?? 'Unknown';
            debugPrint('      First fight: $fighter1 vs $fighter2');
          }
        }
      }
    } catch (e, stack) {
      debugPrint('\n❌ Error fetching ESPN events: $e');
      debugPrint('Stack trace:\n$stack');
    }
  }

  /// Test Odds API fetching with debug output
  static Future<void> testOddsAPIFetching() async {
    debugPrint('\n' + '=' * 60);
    debugPrint('🔍 TESTING ODDS API FETCHING FOR MMA');
    debugPrint('=' * 60);

    try {
      final url = 'https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events?apiKey=51434300fd8bc16e4b57de822b1d4323';
      debugPrint('\n📡 Fetching from Odds API...');

      final response = await http.get(Uri.parse(url));
      debugPrint('   Response status: ${response.statusCode}');

      if (response.statusCode != 200) {
        debugPrint('   ❌ Failed to fetch Odds API fights');
        return;
      }

      final fights = json.decode(response.body) as List;
      debugPrint('\n📊 Odds API Response:');
      debugPrint('   Total fights: ${fights.length}');

      for (int i = 0; i < fights.length && i < 5; i++) {
        final fight = fights[i];
        debugPrint('\n   Fight ${i+1}:');
        debugPrint('      ID: ${fight['id']}');
        debugPrint('      ${fight['away_team']} vs ${fight['home_team']}');
        debugPrint('      Time: ${fight['commence_time']}');
      }
    } catch (e, stack) {
      debugPrint('\n❌ Error fetching Odds API: $e');
      debugPrint('Stack trace:\n$stack');
    }
  }

  /// Test the matching logic
  static Future<void> testMatchingLogic() async {
    debugPrint('\n' + '=' * 60);
    debugPrint('🔍 TESTING FIGHT MATCHING LOGIC');
    debugPrint('=' * 60);

    // Get ESPN events
    final espnResponse = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
    );

    // Get Odds API fights
    final oddsResponse = await http.get(
      Uri.parse('https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events?apiKey=51434300fd8bc16e4b57de822b1d4323'),
    );

    if (espnResponse.statusCode != 200 || oddsResponse.statusCode != 200) {
      debugPrint('❌ Failed to fetch data');
      return;
    }

    final espnData = json.decode(espnResponse.body);
    final espnEvents = espnData['events'] ?? [];
    final oddsFights = json.decode(oddsResponse.body) as List;

    if (espnEvents.isEmpty) {
      debugPrint('⚠️ No ESPN events available');
      return;
    }

    final espnEvent = espnEvents.first;
    debugPrint('\n📋 Attempting to match fights for: ${espnEvent['name']}');
    debugPrint('   ESPN Event ID: ${espnEvent['id']}');

    final competitions = espnEvent['competitions'] ?? [];
    int matchCount = 0;
    int noMatchCount = 0;

    for (final comp in competitions) {
      final competitors = comp['competitors'] ?? [];
      if (competitors.length >= 2) {
        final espnF1 = competitors[0]['athlete']?['displayName'] ?? '';
        final espnF2 = competitors[1]['athlete']?['displayName'] ?? '';

        debugPrint('\n   Looking for: $espnF1 vs $espnF2');

        bool found = false;
        for (final oddsFight in oddsFights) {
          final oddsF1 = oddsFight['away_team']?.toString() ?? '';
          final oddsF2 = oddsFight['home_team']?.toString() ?? '';

          if (_fightersMatch(espnF1, espnF2, oddsF1, oddsF2)) {
            debugPrint('      ✅ MATCH: $oddsF1 vs $oddsF2');
            matchCount++;
            found = true;
            break;
          }
        }

        if (!found) {
          debugPrint('      ❌ NO MATCH FOUND');
          noMatchCount++;
        }
      }
    }

    debugPrint('\n📊 MATCHING RESULTS:');
    debugPrint('   Matched: $matchCount fights');
    debugPrint('   Not matched: $noMatchCount fights');

    if (matchCount > 0) {
      debugPrint('\n✅ Would use ESPN ID: ${espnEvent['id']}');
    } else {
      debugPrint('\n❌ Would fall back to custom ID');
    }
  }

  /// Helper function to match fighter names
  static bool _fightersMatch(String espnF1, String espnF2, String oddsF1, String oddsF2) {
    final espn1Lower = espnF1.toLowerCase();
    final espn2Lower = espnF2.toLowerCase();
    final odds1Lower = oddsF1.toLowerCase();
    final odds2Lower = oddsF2.toLowerCase();

    // Try exact match first
    if ((espn1Lower == odds1Lower && espn2Lower == odds2Lower) ||
        (espn1Lower == odds2Lower && espn2Lower == odds1Lower)) {
      return true;
    }

    // Try last name matching
    final espn1Last = espn1Lower.split(' ').last;
    final espn2Last = espn2Lower.split(' ').last;

    return (odds1Lower.contains(espn1Last) && odds2Lower.contains(espn2Last)) ||
           (odds1Lower.contains(espn2Last) && odds2Lower.contains(espn1Last));
  }

  /// Run all debug tests
  static Future<void> runAllTests() async {
    await testESPNEventFetching();
    await testOddsAPIFetching();
    await testMatchingLogic();

    debugPrint('\n' + '=' * 60);
    debugPrint('🏁 DEBUG TESTING COMPLETE');
    debugPrint('=' * 60);
  }
}