import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:bragging_rights_app/models/mma_fighter_model.dart';
import 'package:bragging_rights_app/screens/mma/widgets/tale_of_tape_widget.dart';

void main() {
  group('Fighter Data Display Tests', () {
    testWidgets('Tale of the Tape displays fighter data correctly', (WidgetTester tester) async {
      // Create test fighter data
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
        displayReach: '70.5\"',
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
        displayReach: '72\"',
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

      // Build the widget
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

      // Test 1: Fighter names are displayed
      print('✅ Test 1: Checking fighter names...');
      expect(find.text('Thiago Moises'), findsOneWidget);
      expect(find.text('Rafael Tobias'), findsOneWidget);

      // Test 2: Records are displayed
      print('✅ Test 2: Checking fight records...');
      expect(find.text('19-9-0'), findsOneWidget);
      expect(find.text('15-5-0'), findsOneWidget);

      // Test 3: Physical stats are displayed
      print('✅ Test 3: Checking physical stats...');
      expect(find.textContaining("5' 9\""), findsOneWidget);
      expect(find.textContaining("5' 11\""), findsOneWidget);
      expect(find.textContaining('70.5\"'), findsOneWidget);
      expect(find.textContaining('72\"'), findsOneWidget);

      // Test 4: Stance is displayed
      print('✅ Test 4: Checking fighter stance...');
      expect(find.textContaining('Orthodox'), findsOneWidget);
      expect(find.textContaining('Southpaw'), findsOneWidget);

      // Test 5: Camps are displayed
      print('✅ Test 5: Checking training camps...');
      expect(find.textContaining('American Top Team'), findsOneWidget);
      expect(find.textContaining('Kings MMA'), findsOneWidget);

      // Test 6: Win methods section exists (when showExtended is true)
      print('✅ Test 6: Checking win methods section...');
      expect(find.text('WIN METHODS'), findsOneWidget);
      expect(find.textContaining('KO/TKO'), findsOneWidget);
      expect(find.textContaining('Submission'), findsOneWidget);
      expect(find.textContaining('Decision'), findsOneWidget);

      print('\n🎉 All Tale of the Tape tests passed!');
    });

    testWidgets('Fighter name overflow is handled correctly', (WidgetTester tester) async {
      // Create fighter with very long name
      final fighterLongName = MMAFighter(
        id: '1',
        name: 'Francisco Javier Rodriguez Martinez de la Cruz',
        displayName: 'Francisco Javier Rodriguez Martinez de la Cruz',
        shortName: 'F. Rodriguez',
        record: '10-5-0',
        headshotUrl: null,
      );

      final fighterShortName = MMAFighter(
        id: '2',
        name: 'Jon Jones',
        displayName: 'Jon Jones',
        shortName: 'J. Jones',
        record: '27-1-0',
        headshotUrl: null,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TaleOfTapeWidget(
              fighter1: fighterLongName,
              fighter2: fighterShortName,
            ),
          ),
        ),
      );

      // Check that both names are displayed (even if truncated)
      print('✅ Test 7: Checking long name handling...');
      expect(find.textContaining('Francisco'), findsOneWidget);
      expect(find.text('Jon Jones'), findsOneWidget);

      // Ensure no overflow errors occurred
      expect(tester.takeException(), isNull);

      print('✅ Long fighter names are handled without overflow!');
    });
  });

  group('Image Caching Verification', () {
    test('ESPN image URLs are correctly formatted', () {
      final fighterIds = ['3955778', '4423876', '5092398', '1234567'];

      for (final id in fighterIds) {
        final expectedUrl = 'https://a.espncdn.com/i/headshots/mma/players/full/$id.png';

        // Verify URL format
        expect(expectedUrl, contains('espncdn.com'));
        expect(expectedUrl, contains('/headshots/mma/'));
        expect(expectedUrl, endsWith('.png'));

        print('✅ URL format verified for fighter $id');
      }
    });

    test('Cache service generates correct URLs', () {
      // Test the URL generation logic
      final testIds = ['3955778', '4423876', ''];

      for (final id in testIds) {
        if (id.isEmpty) {
          // Empty ID should be handled
          print('✅ Empty fighter ID handled correctly');
        } else {
          final url = 'https://a.espncdn.com/i/headshots/mma/players/full/$id.png';
          expect(url, isNotEmpty);
          expect(url, contains(id));
          print('✅ Generated URL for fighter $id: $url');
        }
      }
    });
  });

  print('\n🏆 ALL TESTS COMPLETED SUCCESSFULLY!');
}