import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../firebase_options.dart';

/// Migration script to update existing MMA/UFC events in Firestore
/// with proper weight class and fighter image URLs from ESPN API
void main() async {
  print('🚀 Starting MMA events migration...');

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  final firestore = FirebaseFirestore.instance;

  try {
    // Query all MMA/UFC events
    final eventsQuery = await firestore
        .collection('games')
        .where('sport', whereIn: ['MMA', 'UFC'])
        .get();

    print('📊 Found ${eventsQuery.docs.length} MMA/UFC events to process');

    int updated = 0;
    int failed = 0;

    for (final doc in eventsQuery.docs) {
      final data = doc.data();
      final eventId = doc.id;
      final eventName = data['awayTeam'] ?? '';

      print('\n🥊 Processing event: $eventName (ID: $eventId)');

      // Check if event already has proper data
      final fights = data['fights'] as List<dynamic>? ?? [];
      bool needsUpdate = false;

      if (fights.isEmpty) {
        print('  ⚠️ No fights array found');
        needsUpdate = true;
      } else {
        // Check if any fight is missing weight class or image URLs
        for (final fight in fights) {
          final fightData = fight as Map<String, dynamic>;
          if (fightData['weightClass'] == null ||
              fightData['weightClass'] == 'Catchweight' ||
              fightData['fighter1ImageUrl'] == null ||
              fightData['fighter2ImageUrl'] == null) {
            needsUpdate = true;
            break;
          }
        }
      }

      if (!needsUpdate) {
        print('  ✅ Event already has complete data, skipping');
        continue;
      }

      // Extract ESPN event ID if available
      String? espnEventId;
      if (eventId.contains('_')) {
        espnEventId = eventId.split('_').last;
      }

      if (espnEventId == null) {
        print('  ❌ Cannot extract ESPN ID from: $eventId');
        failed++;
        continue;
      }

      print('  🔍 Fetching data from ESPN API for event ID: $espnEventId');

      // Fetch fight card data from ESPN
      try {
        final espnUrl = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/fightcenter/$espnEventId';
        final response = await http.get(Uri.parse(espnUrl));

        if (response.statusCode != 200) {
          print('  ❌ ESPN API returned ${response.statusCode}');
          failed++;
          continue;
        }

        final espnData = json.decode(response.body);
        final cards = espnData['cards'] as List<dynamic>? ?? [];

        if (cards.isEmpty) {
          print('  ⚠️ No fight cards found in ESPN data');
          failed++;
          continue;
        }

        // Process fights and extract proper data
        List<Map<String, dynamic>> updatedFights = [];

        for (final card in cards) {
          final competitions = card['competitions'] as List<dynamic>? ?? [];

          for (final comp in competitions) {
            final competitors = comp['competitors'] as List<dynamic>? ?? [];

            if (competitors.length != 2) continue;

            // Extract weight class
            final weightClass = comp['type']?['text'] ??
                              comp['type']?['abbreviation'] ??
                              comp['note'] ??
                              'TBD';

            // Extract fighter data
            final fighter1 = competitors[0];
            final fighter2 = competitors[1];

            final athlete1 = fighter1['athlete'] ?? {};
            final athlete2 = fighter2['athlete'] ?? {};

            final athlete1Id = athlete1['id']?.toString() ?? '';
            final athlete2Id = athlete2['id']?.toString() ?? '';

            final fighter1Name = athlete1['displayName'] ?? 'TBD';
            final fighter2Name = athlete2['displayName'] ?? 'TBD';

            // Get records
            final fighter1Record = fighter1['record'] ?? '';
            final fighter2Record = fighter2['record'] ?? '';

            // Build fight object with all data
            updatedFights.add({
              'id': '${eventId}_fight_${updatedFights.length}',
              'fighter1Name': fighter1Name,
              'fighter2Name': fighter2Name,
              'fighter1Id': athlete1Id,
              'fighter2Id': athlete2Id,
              'fighter1Record': fighter1Record,
              'fighter2Record': fighter2Record,
              'fighter1ImageUrl': athlete1Id.isNotEmpty
                  ? 'https://a.espncdn.com/i/headshots/mma/players/full/$athlete1Id.png'
                  : null,
              'fighter2ImageUrl': athlete2Id.isNotEmpty
                  ? 'https://a.espncdn.com/i/headshots/mma/players/full/$athlete2Id.png'
                  : null,
              'weightClass': weightClass,
              'cardPosition': comp['orderDetails']?['isMainCard'] == true ? 'main' : 'prelim',
              'fightOrder': comp['orderDetails']?['order'] ?? 999,
              'rounds': 3, // Default, could be 5 for main events
            });

            print('  ✅ Processed fight: $fighter1Name vs $fighter2Name ($weightClass)');
          }
        }

        if (updatedFights.isEmpty) {
          print('  ⚠️ No fights extracted from ESPN data');
          failed++;
          continue;
        }

        // Update Firestore document
        await firestore.collection('games').doc(eventId).update({
          'fights': updatedFights,
          'lastUpdated': FieldValue.serverTimestamp(),
          'dataSource': 'ESPN_MIGRATED',
        });

        print('  ✅ Successfully updated event with ${updatedFights.length} fights');
        updated++;

      } catch (e) {
        print('  ❌ Error processing event: $e');
        failed++;
      }
    }

    print('\n' + '=' * 50);
    print('🎯 Migration Complete!');
    print('   ✅ Updated: $updated events');
    print('   ❌ Failed: $failed events');
    print('   📊 Total: ${eventsQuery.docs.length} events');

  } catch (e) {
    print('❌ Fatal error during migration: $e');
  }
}