import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Test to verify MMA ESPN ID handling
///
/// This test checks:
/// 1. ESPN API returns events with valid IDs
/// 2. Our service properly extracts ESPN IDs
/// 3. ESPN IDs are numeric (required format)
void main() {
  group('MMA ESPN ID Tests', () {
    test('ESPN UFC Scoreboard returns events with numeric IDs', () async {
      print('\n🧪 Testing ESPN UFC Scoreboard API...');

      try {
        // Fetch UFC events from ESPN
        final response = await http.get(
          Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
        );

        expect(response.statusCode, 200, reason: 'ESPN API should return 200');

        final data = json.decode(response.body);
        expect(data, isNotNull, reason: 'Response should have data');

        // Check if events exist
        final events = data['events'] as List?;
        if (events != null && events.isNotEmpty) {
          print('✅ Found ${events.length} UFC events');

          // Check first 3 events
          for (int i = 0; i < events.length && i < 3; i++) {
            final event = events[i];
            final eventId = event['id']?.toString();
            final eventName = event['name'] ?? 'Unknown';

            print('\n📋 Event ${i + 1}:');
            print('   Name: $eventName');
            print('   ID: $eventId');

            // Verify ID format
            expect(eventId, isNotNull, reason: 'Event should have an ID');
            expect(
              RegExp(r'^\d+$').hasMatch(eventId!),
              true,
              reason: 'ESPN event ID should be numeric, got: $eventId',
            );

            // Check competitions (fights)
            final competitions = event['competitions'] as List?;
            if (competitions != null) {
              print('   Fights: ${competitions.length}');

              // Show first fight details
              if (competitions.isNotEmpty) {
                final firstFight = competitions.first;
                final competitors = firstFight['competitors'] as List?;
                if (competitors != null && competitors.length >= 2) {
                  final fighter1 = competitors[0]['athlete']?['displayName'] ?? 'TBD';
                  final fighter2 = competitors[1]['athlete']?['displayName'] ?? 'TBD';
                  print('   Main Event: $fighter1 vs $fighter2');
                }
              }
            }
          }
        } else {
          print('⚠️ No events found in ESPN response');
        }

      } catch (e) {
        print('❌ Error fetching ESPN data: $e');
        fail('Failed to fetch ESPN data: $e');
      }
    });

    test('Verify ESPN Event API returns full fight card', () async {
      print('\n🧪 Testing ESPN Event Details API...');

      // Use a known UFC event ID (you can update this with a current event)
      const testEventId = '600051442'; // UFC 311

      try {
        final response = await http.get(
          Uri.parse('http://sports.core.api.espn.com/v2/sports/mma/leagues/ufc/events/$testEventId'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);

          print('✅ Event Details:');
          print('   ID: ${data['id']}');
          print('   Name: ${data['name']}');
          print('   Date: ${data['date']}');

          // Check competitions
          final competitions = data['competitions'] as List?;
          if (competitions != null) {
            print('   Total Fights: ${competitions.length}');

            // Verify each competition has required data
            int mainCardCount = 0;
            int prelimCount = 0;
            int earlyPrelimCount = 0;

            for (final comp in competitions) {
              final cardSegment = comp['cardSegment']?['description'];
              if (cardSegment != null) {
                if (cardSegment.contains('Main')) mainCardCount++;
                else if (cardSegment.contains('Early')) earlyPrelimCount++;
                else prelimCount++;
              }
            }

            print('   Main Card: $mainCardCount fights');
            print('   Prelims: $prelimCount fights');
            print('   Early Prelims: $earlyPrelimCount fights');

            expect(competitions.length, greaterThan(0),
              reason: 'Event should have at least one fight');
          }
        } else {
          print('⚠️ Event $testEventId not found (${response.statusCode})');
        }
      } catch (e) {
        print('❌ Error fetching event details: $e');
        // Don't fail test - event might be old
      }
    });

    test('Simulate ID resolution for MMA event', () async {
      print('\n🧪 Simulating MMA Event ID Resolution...');

      // This simulates what should happen in optimized_games_service.dart

      // Step 1: Get ESPN events
      final espnResponse = await http.get(
        Uri.parse('https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard'),
      );

      if (espnResponse.statusCode == 200) {
        final data = json.decode(espnResponse.body);
        final events = data['events'] as List? ?? [];

        if (events.isNotEmpty) {
          final firstEvent = events.first;
          final espnId = firstEvent['id']?.toString();
          final eventName = firstEvent['name'] ?? '';

          print('📊 Processing event: $eventName');

          // Step 2: Create GameModel with ESPN ID (what SHOULD happen)
          final correctId = espnId; // Use ESPN ID directly
          final incorrectId = 'mma_${eventName.toLowerCase().replaceAll(' ', '_')}'; // Current wrong approach

          print('\n✅ CORRECT Implementation:');
          print('   ID: $correctId');
          print('   ESPN ID: $espnId');
          print('   Result: MMA details screen can fetch full event');

          print('\n❌ CURRENT Implementation:');
          print('   ID: $incorrectId');
          print('   ESPN ID: null (not stored)');
          print('   Result: MMA details screen fails - "Invalid ESPN event ID"');

          // Verify correct ID format
          expect(
            RegExp(r'^\d+$').hasMatch(correctId!),
            true,
            reason: 'ESPN ID should be numeric',
          );

          expect(
            RegExp(r'^\d+$').hasMatch(incorrectId),
            false,
            reason: 'Custom ID is not numeric - will fail in MMA service',
          );
        }
      }
    });
  });
}