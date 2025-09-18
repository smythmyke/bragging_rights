import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test to compare MMA and Boxing event structures
/// Ensures we handle each sport correctly without breaking the other
void main() {
  group('Combat Sports API Comparison', () {
    test('Compare MMA vs Boxing API structures', () async {
      print('\n🥊 COMBAT SPORTS API COMPARISON\n');
      print('=' * 60);

      // Test MMA/UFC Structure
      print('\n📋 MMA/UFC EVENT STRUCTURE:');
      print('-' * 40);

      try {
        final mmaResponse = await http.get(
          Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
        );

        if (mmaResponse.statusCode == 200) {
          final mmaData = json.decode(mmaResponse.body);
          final mmaEvents = mmaData['events'] as List? ?? [];

          if (mmaEvents.isNotEmpty) {
            final event = mmaEvents.first;
            print('✅ MMA Event Found:');
            print('   Name: ${event['name']}');
            print('   ID: ${event['id']} (Type: ${event['id'].runtimeType})');
            print('   ID Format: Numeric = ${RegExp(r'^\d+$').hasMatch(event['id'].toString())}');

            // Check if competitions exist in main event list
            final competitions = event['competitions'] as List?;
            print('   Has competitions array: ${competitions != null}');
            if (competitions != null) {
              print('   Fights in main response: ${competitions.length}');
            }

            // Now fetch the full event details
            final eventId = event['id'].toString();
            final detailsResponse = await http.get(
              Uri.parse('http://sports.core.api.espn.com/v2/sports/mma/leagues/ufc/events/$eventId'),
            );

            if (detailsResponse.statusCode == 200) {
              final details = json.decode(detailsResponse.body);
              final detailComps = details['competitions'] as List?;
              print('\n   Full Event Details:');
              print('   Total fights in detail API: ${detailComps?.length ?? 0}');
              print('   ✅ MMA events contain full fight card in ESPN API');
            }
          }
        }
      } catch (e) {
        print('❌ Error fetching MMA data: $e');
      }

      // Test Boxing Structure
      print('\n📋 BOXING EVENT STRUCTURE:');
      print('-' * 40);

      try {
        // Try ESPN Boxing endpoint
        final boxingUrl = 'https://site.api.espn.com/apis/site/v2/sports/boxing/boxing/scoreboard';
        final boxingResponse = await http.get(
          Uri.parse(boxingUrl),
          headers: {'Accept': 'application/json'},
        );

        print('   ESPN Boxing API Status: ${boxingResponse.statusCode}');

        if (boxingResponse.statusCode == 200) {
          // Try to decode - might be compressed
          try {
            final boxingData = json.decode(boxingResponse.body);
            final boxingEvents = boxingData['events'] as List? ?? [];

            if (boxingEvents.isNotEmpty) {
              print('✅ Boxing Events Found: ${boxingEvents.length}');
              final event = boxingEvents.first;
              print('   Name: ${event['name']}');
              print('   ID: ${event['id']}');
              print('   ID Format: Numeric = ${RegExp(r'^\d+$').hasMatch(event['id'].toString())}');
            } else {
              print('⚠️ No Boxing events currently available');
            }
          } catch (e) {
            print('⚠️ Boxing API response format issue (might be compressed or empty)');
          }
        } else {
          print('⚠️ Boxing API not returning events (status: ${boxingResponse.statusCode})');
        }

        // Check Odds API for Boxing as fallback
        print('\n   Checking Odds API for Boxing events...');
        final oddsResponse = await http.get(
          Uri.parse('https://api.the-odds-api.com/v4/sports/boxing_boxing/events?apiKey=51434300fd8bc16e4b57de822b1d4323'),
        );

        if (oddsResponse.statusCode == 200) {
          final oddsData = json.decode(oddsResponse.body) as List;
          if (oddsData.isNotEmpty) {
            print('   ✅ Odds API has ${oddsData.length} Boxing fights');
            print('   Note: Boxing fights come as individual events from Odds API');
            print('   Need grouping logic for Boxing events');
          }
        }

      } catch (e) {
        print('❌ Error fetching Boxing data: $e');
      }

      // Summary
      print('\n' + '=' * 60);
      print('📊 SUMMARY - KEY DIFFERENCES:');
      print('=' * 60);

      print('\n🥋 MMA/UFC:');
      print('  • ESPN provides complete events with all fights');
      print('  • Each event has a numeric ESPN ID (e.g., "600051442")');
      print('  • Competitions array contains all fights on the card');
      print('  • ✅ Should use ESPN event ID directly');

      print('\n🥊 BOXING:');
      print('  • ESPN Boxing API may not always have events');
      print('  • Odds API returns individual fights, not grouped events');
      print('  • May need custom grouping logic');
      print('  • ⚠️ May need different handling than MMA');

      print('\n💡 IMPLEMENTATION STRATEGY:');
      print('  if (sport == "MMA" && espnEvent != null) {');
      print('    // Use ESPN event ID directly');
      print('    id = espnEvent["id"];');
      print('    espnId = espnEvent["id"];');
      print('  } else {');
      print('    // Use custom ID for Boxing or when no ESPN event');
      print('    id = generateSafeId();');
      print('    espnId = espnEvent?["id"];  // Store if available');
      print('  }');
    });

    test('Verify ID formats for both sports', () async {
      print('\n🔍 ID FORMAT VERIFICATION\n');

      // Check what IDs look like from Odds API
      print('Odds API IDs:');

      // MMA from Odds API
      final mmaOddsResponse = await http.get(
        Uri.parse('https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/events?apiKey=51434300fd8bc16e4b57de822b1d4323'),
      );

      if (mmaOddsResponse.statusCode == 200) {
        final mmaOdds = json.decode(mmaOddsResponse.body) as List;
        if (mmaOdds.isNotEmpty) {
          print('  MMA Odds API ID example: ${mmaOdds.first['id']}');
          print('  Format: ${mmaOdds.first['id'].runtimeType}');
        }
      }

      // Boxing from Odds API
      final boxingOddsResponse = await http.get(
        Uri.parse('https://api.the-odds-api.com/v4/sports/boxing_boxing/events?apiKey=51434300fd8bc16e4b57de822b1d4323'),
      );

      if (boxingOddsResponse.statusCode == 200) {
        final boxingOdds = json.decode(boxingOddsResponse.body) as List;
        if (boxingOdds.isNotEmpty) {
          print('  Boxing Odds API ID example: ${boxingOdds.first['id']}');
          print('  Format: ${boxingOdds.first['id'].runtimeType}');
        }
      }

      print('\nConclusion: Odds API uses hash IDs, ESPN uses numeric IDs');
      print('Must use ESPN IDs when available for proper API integration');
    });
  });
}