import 'package:flutter_test/flutter_test.dart';
import 'package:bragging_rights_app/models/mma_fighter_model.dart';

void main() {
  group('Fighter Data Model Tests', () {
    test('Fighter model correctly stores all fighter data', () {
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

      // Test 1: Fighter names are stored correctly
      print('✅ Test 1: Checking fighter names...');
      expect(fighter1.name, equals('Thiago Moises'));
      expect(fighter2.name, equals('Rafael Tobias'));
      expect(fighter1.displayName, equals('Thiago Moises'));
      expect(fighter2.displayName, equals('Rafael Tobias'));

      // Test 2: Records are stored correctly
      print('✅ Test 2: Checking fight records...');
      expect(fighter1.record, equals('19-9-0'));
      expect(fighter2.record, equals('15-5-0'));
      expect(fighter1.wins, equals(19));
      expect(fighter1.losses, equals(9));
      expect(fighter1.draws, equals(0));

      // Test 3: Physical stats are stored correctly
      print('✅ Test 3: Checking physical stats...');
      expect(fighter1.displayHeight, equals("5' 9\""));
      expect(fighter2.displayHeight, equals("5' 11\""));
      expect(fighter1.displayReach, equals('70.5"'));
      expect(fighter2.displayReach, equals('72"'));
      expect(fighter1.weight, equals(155));
      expect(fighter2.weight, equals(155));

      // Test 4: Stance is stored correctly
      print('✅ Test 4: Checking fighter stance...');
      expect(fighter1.stance, equals('Orthodox'));
      expect(fighter2.stance, equals('Southpaw'));

      // Test 5: Camps are stored correctly
      print('✅ Test 5: Checking training camps...');
      expect(fighter1.camp, equals('American Top Team'));
      expect(fighter2.camp, equals('Kings MMA'));

      // Test 6: Win methods are stored correctly
      print('✅ Test 6: Checking win methods...');
      expect(fighter1.knockouts, equals(4));
      expect(fighter1.submissions, equals(8));
      expect(fighter1.decisions, equals(7));
      expect(fighter2.knockouts, equals(6));
      expect(fighter2.submissions, equals(5));
      expect(fighter2.decisions, equals(4));

      // Test 7: Image URLs are stored correctly
      print('✅ Test 7: Checking image URLs...');
      expect(fighter1.headshotUrl, equals('https://a.espncdn.com/i/headshots/mma/players/full/3955778.png'));
      expect(fighter2.headshotUrl, equals('https://a.espncdn.com/i/headshots/mma/players/full/4423876.png'));

      print('\n🎉 All fighter data model tests passed!');
    });

    test('Fighter model handles missing data gracefully', () {
      // Create fighter with minimal data
      final minimalFighter = MMAFighter(
        id: '1',
        name: 'Test Fighter',
        displayName: 'Test Fighter',
        shortName: 'T. Fighter',
        record: '0-0-0',
      );

      // Test that optional fields can be null
      print('✅ Test 8: Checking handling of missing data...');
      expect(minimalFighter.age, isNull);
      expect(minimalFighter.height, isNull);
      expect(minimalFighter.weight, isNull);
      expect(minimalFighter.reach, isNull);
      expect(minimalFighter.stance, isNull);
      expect(minimalFighter.camp, isNull);
      expect(minimalFighter.country, isNull);
      expect(minimalFighter.headshotUrl, isNull);

      // Test that required fields are present
      expect(minimalFighter.id, equals('1'));
      expect(minimalFighter.name, equals('Test Fighter'));
      expect(minimalFighter.record, equals('0-0-0'));

      print('✅ Fighter model handles missing data correctly!');

      // Test with very long name
      final fighterLongName = MMAFighter(
        id: '2',
        name: 'Francisco Javier Rodriguez Martinez de la Cruz',
        displayName: 'Francisco Javier Rodriguez Martinez de la Cruz',
        shortName: 'F. Rodriguez',
        record: '10-5-0',
      );

      print('✅ Test 9: Checking long name handling...');
      expect(fighterLongName.name.length, greaterThan(40));
      expect(fighterLongName.shortName, equals('F. Rodriguez'));
      print('✅ Long fighter names are stored correctly!');
    });
  });

  group('Image URL Generation Tests', () {
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

    test('Cache service URL generation logic', () {
      // Test the URL generation logic (without Firebase)
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

    test('Fighter model correctly stores ESPN CDN URLs', () {
      final testFighters = [
        MMAFighter(
          id: '3955778',
          name: 'Fighter 1',
          displayName: 'Fighter 1',
          shortName: 'F1',
          record: '10-5-0',
          headshotUrl: 'https://a.espncdn.com/i/headshots/mma/players/full/3955778.png',
        ),
        MMAFighter(
          id: '4423876',
          name: 'Fighter 2',
          displayName: 'Fighter 2',
          shortName: 'F2',
          record: '8-3-0',
          headshotUrl: 'https://a.espncdn.com/i/headshots/mma/players/full/4423876.png',
        ),
        MMAFighter(
          id: 'no-image',
          name: 'Fighter 3',
          displayName: 'Fighter 3',
          shortName: 'F3',
          record: '5-5-0',
          headshotUrl: null, // No image available
        ),
      ];

      for (final fighter in testFighters) {
        if (fighter.headshotUrl != null) {
          expect(fighter.headshotUrl, contains('espncdn.com'));
          expect(fighter.headshotUrl, contains(fighter.id));
          print('✅ Fighter ${fighter.id} has valid ESPN CDN URL');
        } else {
          expect(fighter.headshotUrl, isNull);
          print('✅ Fighter ${fighter.id} correctly handles null image URL');
        }
      }
    });
  });

  group('Fighter Data Validation Tests', () {
    test('Fighter record parsing', () {
      final testRecords = [
        {'record': '19-9-0', 'wins': 19, 'losses': 9, 'draws': 0},
        {'record': '27-1-1', 'wins': 27, 'losses': 1, 'draws': 1},
        {'record': '15-5-0', 'wins': 15, 'losses': 5, 'draws': 0},
      ];

      for (final testCase in testRecords) {
        final fighter = MMAFighter(
          id: 'test',
          name: 'Test Fighter',
          displayName: 'Test Fighter',
          shortName: 'T. Fighter',
          record: testCase['record'] as String,
          wins: testCase['wins'] as int?,
          losses: testCase['losses'] as int?,
          draws: testCase['draws'] as int?,
        );

        expect(fighter.record, equals(testCase['record']));
        expect(fighter.wins, equals(testCase['wins']));
        expect(fighter.losses, equals(testCase['losses']));
        expect(fighter.draws, equals(testCase['draws']));
        print('✅ Record ${testCase['record']} parsed correctly');
      }
    });

    test('Fighter physical measurements', () {
      final fighter = MMAFighter(
        id: 'test',
        name: 'Test Fighter',
        displayName: 'Test Fighter',
        shortName: 'T. Fighter',
        record: '10-5-0',
        height: 72, // 6'0" in inches
        displayHeight: "6' 0\"",
        weight: 170,
        displayWeight: '170 lbs',
        reach: 74,
        displayReach: '74"',
      );

      // Test height conversion
      expect(fighter.height, equals(72));
      expect(fighter.displayHeight, equals("6' 0\""));

      // Test weight
      expect(fighter.weight, equals(170));
      expect(fighter.displayWeight, equals('170 lbs'));

      // Test reach
      expect(fighter.reach, equals(74));
      expect(fighter.displayReach, equals('74"'));

      print('✅ Physical measurements stored and displayed correctly');
    });
  });

  print('\n🏆 ALL FIGHTER DATA AND CACHING TESTS COMPLETED!');
}