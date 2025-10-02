/// Test script for multi-endpoint NBA preseason support
/// Run with: dart test_multi_endpoint.dart

import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  print('=' * 70);
  print('TESTING MULTI-ENDPOINT SEARCH LOGIC');
  print('=' * 70);

  final apiKey = '51434300fd8bc16e4b57de822b1d4323';
  final baseUrl = 'https://api.the-odds-api.com/v4';

  // Test Case 1: NBA Preseason Game (Oct 2)
  print('\n📍 Test 1: NBA Preseason - 76ers @ Knicks (Oct 2)');
  print('-' * 70);

  final gameDate = DateTime(2025, 10, 2);
  print('Game Date: ${gameDate.toIso8601String()}');

  // Simulate _getEndpointsForSport() logic
  final endpoints = [
    {
      'key': 'basketball_nba_preseason',
      'type': 'preseason',
      'priority': 1,
      'label': 'PRESEASON',
      'dateStart': DateTime(2025, 10, 1),
      'dateEnd': DateTime(2025, 10, 15),
    },
    {
      'key': 'basketball_nba',
      'type': 'regularSeason',
      'priority': 2,
      'label': null,
      'dateStart': DateTime(2025, 10, 15),
      'dateEnd': DateTime(2026, 6, 30),
    },
  ];

  // Filter by date
  final applicableEndpoints = endpoints.where((e) {
    final start = e['dateStart'] as DateTime;
    final end = e['dateEnd'] as DateTime;
    return gameDate.isAfter(start) && gameDate.isBefore(end);
  }).toList();

  print('\n🎯 Applicable endpoints for ${gameDate.toIso8601String()}:');
  for (final ep in applicableEndpoints) {
    print('   ✅ ${ep['key']} (${ep['type']}) [${ep['label'] ?? "no label"}]');
  }

  // Try each endpoint
  for (final ep in applicableEndpoints) {
    final key = ep['key'] as String;
    print('\n🔍 Checking endpoint: $key');

    final url = '$baseUrl/sports/$key/odds/?apiKey=$apiKey&regions=us&markets=h2h';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body) as List;
        print('   ✅ Found ${data.length} events');

        // Search for 76ers-Knicks
        for (final event in data) {
          final home = event['home_team'] ?? '';
          final away = event['away_team'] ?? '';

          if (home.toString().toLowerCase().contains('knicks') &&
              away.toString().toLowerCase().contains('76ers')) {
            print('\n   🎉 MATCH FOUND!');
            print('   Game: $away @ $home');
            print('   Event ID: ${event['id']}');
            print('   Commence Time: ${event['commence_time']}');
            print('   Sport Title: ${event['sport_title']}');
            print('   Bookmakers: ${event['bookmakers']?.length ?? 0}');

            // Extract sample odds
            if (event['bookmakers'] != null && (event['bookmakers'] as List).isNotEmpty) {
              final firstBook = event['bookmakers'][0];
              print('\n   📊 Sample Odds (${firstBook['title']}):');

              for (final market in firstBook['markets']) {
                print('      ${market['key']}:');
                for (final outcome in market['outcomes']) {
                  print('        - ${outcome['name']}: ${outcome['price']}${outcome['point'] != null ? " (${outcome['point']})" : ""}');
                }
              }
            }

            print('\n   ✅ Season Metadata:');
            print('      Type: ${ep['type']}');
            print('      Label: ${ep['label'] ?? "null"}');
            print('      Endpoint: $key');

            return; // Found it!
          }
        }

        print('   ❌ No match found in $key');
      } else {
        print('   ❌ API returned ${response.statusCode}');
      }
    } catch (e) {
      print('   ❌ Error: $e');
    }
  }

  print('\n' + '=' * 70);
  print('TEST COMPLETE');
  print('=' * 70);
}
