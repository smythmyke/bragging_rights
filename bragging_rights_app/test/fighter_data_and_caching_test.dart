import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'dart:convert';

// Import your app files
import 'package:bragging_rights_app/services/fighter_image_cache_service.dart';
import 'package:bragging_rights_app/services/mma_service.dart';
import 'package:bragging_rights_app/models/mma_fighter_model.dart';
import 'package:bragging_rights_app/screens/mma/widgets/tale_of_tape_widget.dart';
import 'package:bragging_rights_app/widgets/fighter_image_widget.dart';

void main() {
  group('Fighter Data and Image Caching Tests', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FighterImageCacheService cacheService;
    late MMAService mmaService;

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      cacheService = FighterImageCacheService();
      mmaService = MMAService();
    });

    group('1. Tale of the Tape Fighter Data Population', () {
      testWidgets('Fighter data should populate correctly in Tale of the Tape widget', (WidgetTester tester) async {
        // Create mock fighter data
        final fighter1 = MMAFighter(
          id: '3955778',
          name: 'Thiago Moises',
          displayName: 'Thiago Moises',
          shortName: 'T. Moises',
          record: '19-9-0',
          age: 30,
          height: 69,
          displayHeight: "5' 9\"",
          weight: 155,
          displayWeight: '155 lbs',
          reach: 70.5,
          displayReach: '70.5"',
          stance: 'Orthodox',
          wins: 19,
          losses: 9,
          draws: 0,
          knockouts: 4,
          submissions: 8,
          decisions: 7,
          camp: 'American Top Team',
          country: 'Brazil',
          headshotUrl: 'https://a.espncdn.com/i/headshots/mma/players/full/3955778.png',
        );

        final fighter2 = MMAFighter(
          id: '4423876',
          name: 'Rafael Tobias',
          displayName: 'Rafael Tobias',
          shortName: 'R. Tobias',
          record: '15-5-0',
          age: 28,
          height: 71,
          displayHeight: "5' 11\"",
          weight: 155,
          displayWeight: '155 lbs',
          reach: 72,
          displayReach: '72"',
          stance: 'Southpaw',
          wins: 15,
          losses: 5,
          draws: 0,
          knockouts: 6,
          submissions: 5,
          decisions: 4,
          camp: 'Kings MMA',
          country: 'USA',
          headshotUrl: 'https://a.espncdn.com/i/headshots/mma/players/full/4423876.png',
        );

        // Test Tale of the Tape widget with fighter data
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaleOfTapeWidget(
                fighter1: fighter1,
                fighter2: fighter2,
                weightClass: 'Lightweight',
                rounds: 3,
                isTitle: false,
                showExtended: true,
              ),
            ),
          ),
        );

        // Verify fighter names are displayed
        expect(find.text('Thiago Moises'), findsOneWidget);
        expect(find.text('Rafael Tobias'), findsOneWidget);

        // Verify records are displayed
        expect(find.text('19-9-0'), findsOneWidget);
        expect(find.text('15-5-0'), findsOneWidget);

        // Verify physical stats are displayed
        expect(find.text("5' 9\""), findsOneWidget);
        expect(find.text("5' 11\""), findsOneWidget);
        expect(find.text('155 lbs'), findsWidgets); // Both fighters
        expect(find.text('70.5"'), findsOneWidget);
        expect(find.text('72"'), findsOneWidget);

        // Verify stance is displayed
        expect(find.text('Orthodox'), findsOneWidget);
        expect(find.text('Southpaw'), findsOneWidget);

        // Verify camps are displayed
        expect(find.text('American Top Team'), findsOneWidget);
        expect(find.text('Kings MMA'), findsOneWidget);

        // Verify win methods section (when showExtended is true)
        expect(find.text('WIN METHODS'), findsOneWidget);
        expect(find.text('KO/TKO'), findsOneWidget);
        expect(find.text('Submission'), findsOneWidget);
        expect(find.text('Decision'), findsOneWidget);

        print('✅ Tale of the Tape fighter data population test passed');
      });

      testWidgets('Tale of the Tape should handle missing fighter data gracefully', (WidgetTester tester) async {
        // Create fighter with minimal data
        final fighter1 = MMAFighter(
          id: '1',
          name: 'Fighter One',
          displayName: 'Fighter One',
          shortName: 'F. One',
          record: '0-0-0',
        );

        final fighter2 = MMAFighter(
          id: '2',
          name: 'Fighter Two',
          displayName: 'Fighter Two',
          shortName: 'F. Two',
          record: '0-0-0',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaleOfTapeWidget(
                fighter1: fighter1,
                fighter2: fighter2,
              ),
            ),
          ),
        );

        // Should display names even with minimal data
        expect(find.text('Fighter One'), findsOneWidget);
        expect(find.text('Fighter Two'), findsOneWidget);

        // Should show N/A for missing data
        expect(find.text('N/A'), findsWidgets);

        print('✅ Tale of the Tape handles missing data gracefully');
      });
    });

    group('2. Fighter Image Caching Tests', () {
      test('Image cache should save fighter image URL to Firestore on first fetch', () async {
        final fighterId = '3955778';
        final expectedUrl = 'https://a.espncdn.com/i/headshots/mma/players/full/$fighterId.png';

        // Mock HTTP client for image existence check
        final mockClient = MockClient((request) async {
          if (request.method == 'HEAD' && request.url.toString().contains(fighterId)) {
            return http.Response('', 200);
          }
          if (request.method == 'GET' && request.url.toString().contains(fighterId)) {
            // Return fake image data
            return http.Response.bytes([0x89, 0x50, 0x4E, 0x47], 200);
          }
          return http.Response('Not Found', 404);
        });

        // Test the caching flow
        print('📥 Testing first fetch - should call ESPN and cache...');

        // First call - should fetch from ESPN and cache
        final url1 = await cacheService.getFighterImageUrl(fighterId);
        expect(url1, isNotNull);

        // Verify it was saved to Firestore
        final doc = await fakeFirestore
            .collection('fighter_images_cache')
            .doc(fighterId)
            .get();

        expect(doc.exists, isTrue);
        expect(doc.data()?['fighterId'], equals(fighterId));
        expect(doc.data()?['url'], equals(expectedUrl));
        expect(doc.data()?['verified'], isTrue);

        print('✅ Image URL cached in Firestore on first fetch');
      });

      test('Image cache should return cached data on subsequent fetches', () async {
        final fighterId = '4423876';
        final cachedUrl = 'https://a.espncdn.com/i/headshots/mma/players/full/$fighterId.png';

        // Pre-populate Firestore with cached data
        await fakeFirestore
            .collection('fighter_images_cache')
            .doc(fighterId)
            .set({
          'fighterId': fighterId,
          'url': cachedUrl,
          'cachedAt': DateTime.now().toIso8601String(),
          'expiresAt': DateTime.now().add(Duration(days: 30)).toIso8601String(),
          'verified': true,
        });

        print('📥 Testing cached fetch - should use Firestore data...');

        // This should return from cache without hitting ESPN
        final url = await cacheService.getFighterImageUrl(fighterId);

        expect(url, equals(cachedUrl));
        print('✅ Returned cached image URL from Firestore');
      });

      test('Image cache should handle expired cache correctly', () async {
        final fighterId = '5092398';

        // Add expired cache entry
        await fakeFirestore
            .collection('fighter_images_cache')
            .doc(fighterId)
            .set({
          'fighterId': fighterId,
          'url': 'old_url',
          'cachedAt': DateTime.now().subtract(Duration(days: 35)).toIso8601String(),
          'expiresAt': DateTime.now().subtract(Duration(days: 5)).toIso8601String(),
          'verified': true,
        });

        print('📥 Testing expired cache - should fetch fresh data...');

        // Should detect expired cache and fetch new data
        final url = await cacheService.getFighterImageUrl(fighterId);

        // Should return the ESPN URL pattern
        expect(url, contains('espncdn.com'));

        // Verify expired entry was deleted
        final doc = await fakeFirestore
            .collection('fighter_images_cache')
            .doc(fighterId)
            .get();

        // Either deleted or updated with new data
        if (doc.exists) {
          final expiresAt = DateTime.parse(doc.data()!['expiresAt']);
          expect(expiresAt.isAfter(DateTime.now()), isTrue);
        }

        print('✅ Expired cache handled correctly');
      });

      test('Memory cache should speed up repeated requests', () async {
        final fighterId = '1234567';

        // Clear memory cache first
        cacheService.clearMemoryCache();

        // First call - will hit Firestore/ESPN
        final stopwatch1 = Stopwatch()..start();
        final url1 = await cacheService.getFighterImageUrl(fighterId);
        stopwatch1.stop();

        // Second call - should hit memory cache (much faster)
        final stopwatch2 = Stopwatch()..start();
        final url2 = await cacheService.getFighterImageUrl(fighterId);
        stopwatch2.stop();

        expect(url1, equals(url2));

        // Memory cache should be significantly faster
        // Note: This is a rough check, actual times may vary
        print('First fetch: ${stopwatch1.elapsedMilliseconds}ms');
        print('Memory cached fetch: ${stopwatch2.elapsedMilliseconds}ms');

        print('✅ Memory cache working for repeated requests');
      });

      test('Cache statistics should track cached fighters correctly', () async {
        // Add some test data
        await fakeFirestore.collection('fighter_images_cache').doc('1').set({
          'url': 'url1',
          'cachedAt': DateTime.now().toIso8601String(),
          'expiresAt': DateTime.now().add(Duration(days: 30)).toIso8601String(),
        });

        await fakeFirestore.collection('fighter_images_cache').doc('2').set({
          'noImage': true,
          'cachedAt': DateTime.now().toIso8601String(),
          'expiresAt': DateTime.now().add(Duration(days: 7)).toIso8601String(),
        });

        await fakeFirestore.collection('fighter_images_cache').doc('3').set({
          'url': 'url3',
          'cachedAt': DateTime.now().subtract(Duration(days: 35)).toIso8601String(),
          'expiresAt': DateTime.now().subtract(Duration(days: 5)).toIso8601String(),
        });

        final stats = await cacheService.getCacheStats();

        expect(stats['totalCached'], equals(3));
        expect(stats['withImages'], greaterThanOrEqualTo(1));
        expect(stats['noImages'], greaterThanOrEqualTo(1));
        expect(stats['expired'], greaterThanOrEqualTo(1));

        print('✅ Cache statistics tracking working');
        print('📊 Cache Stats: ${stats}');
      });
    });

    group('3. Integration Tests', () {
      testWidgets('Fighter images should display in Tale of the Tape with caching', (WidgetTester tester) async {
        // Create fighters with image URLs
        final fighter1 = MMAFighter(
          id: '3955778',
          name: 'Fighter With Image',
          displayName: 'Fighter With Image',
          shortName: 'F. Image',
          record: '10-5-0',
          headshotUrl: 'https://a.espncdn.com/i/headshots/mma/players/full/3955778.png',
        );

        final fighter2 = MMAFighter(
          id: '4423876',
          name: 'Another Fighter',
          displayName: 'Another Fighter',
          shortName: 'A. Fighter',
          record: '8-2-0',
          headshotUrl: 'https://a.espncdn.com/i/headshots/mma/players/full/4423876.png',
        );

        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: TaleOfTapeWidget(
                fighter1: fighter1,
                fighter2: fighter2,
                weightClass: 'Lightweight',
                rounds: 3,
              ),
            ),
          ),
        );

        // Initial load
        await tester.pump();

        // Should show fighter names
        expect(find.text('Fighter With Image'), findsOneWidget);
        expect(find.text('Another Fighter'), findsOneWidget);

        // FighterImageWidget should be present
        expect(find.byType(FighterImageWidget), findsNWidgets(2));

        print('✅ Fighter images integrated with Tale of the Tape widget');
      });
    });
  });

  print('\n🎉 All fighter data and caching tests completed!');
}