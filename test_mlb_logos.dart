import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:bragging_rights_app/services/team_logo_service.dart';

void main() {
  group('MLB Team Logo Tests', () {
    late TeamLogoService logoService;

    setUp(() {
      logoService = TeamLogoService();
    });

    test('should fetch MLB team logo with correct parameters', () async {
      // Test common MLB teams
      final testTeams = [
        'New York Yankees',
        'Boston Red Sox',
        'Los Angeles Dodgers',
        'Houston Astros',
        'Atlanta Braves',
        'Chicago Cubs',
        'San Francisco Giants',
        'Philadelphia Phillies',
      ];

      for (final team in testTeams) {
        print('Testing logo fetch for: $team');

        final logoData = await logoService.getTeamLogo(
          teamName: team,
          sport: 'MLB',
        );

        // Verify logo data is returned
        expect(logoData, isNotNull, reason: 'Logo data should not be null for $team');

        if (logoData != null) {
          // Check that we have a valid logo URL
          expect(logoData.logoUrl, isNotNull, reason: 'Logo URL should not be null for $team');
          expect(logoData.logoUrl, isNotEmpty, reason: 'Logo URL should not be empty for $team');
          expect(logoData.logoUrl, startsWith('http'), reason: 'Logo URL should be valid for $team');

          // Check team colors are present
          expect(logoData.primaryColor, isNotNull, reason: 'Primary color should not be null for $team');
          expect(logoData.secondaryColor, isNotNull, reason: 'Secondary color should not be null for $team');

          print('  ✓ Logo URL: ${logoData.logoUrl}');
          print('  ✓ Primary Color: ${logoData.primaryColor}');
          print('  ✓ Secondary Color: ${logoData.secondaryColor}');
        }
      }
    });

    test('should handle team name variations', () async {
      // Test that different variations of team names work
      final variations = [
        ['Yankees', 'New York Yankees'],
        ['Red Sox', 'Boston Red Sox'],
        ['Dodgers', 'Los Angeles Dodgers'],
        ['Astros', 'Houston Astros'],
      ];

      for (final pair in variations) {
        final shortName = pair[0];
        final fullName = pair[1];

        print('Testing variation: $shortName vs $fullName');

        final shortLogo = await logoService.getTeamLogo(
          teamName: shortName,
          sport: 'MLB',
        );

        final fullLogo = await logoService.getTeamLogo(
          teamName: fullName,
          sport: 'MLB',
        );

        // Both should return valid logos
        expect(shortLogo, isNotNull, reason: 'Should find logo for $shortName');
        expect(fullLogo, isNotNull, reason: 'Should find logo for $fullName');

        // They should return the same logo URL
        if (shortLogo != null && fullLogo != null) {
          expect(shortLogo.logoUrl, equals(fullLogo.logoUrl),
            reason: '$shortName and $fullName should return the same logo');
        }
      }
    });

    test('should cache logo data', () async {
      const teamName = 'New York Yankees';
      const sport = 'MLB';

      // First fetch - from API
      final stopwatch = Stopwatch()..start();
      final firstFetch = await logoService.getTeamLogo(
        teamName: teamName,
        sport: sport,
      );
      stopwatch.stop();
      final firstFetchTime = stopwatch.elapsedMilliseconds;

      print('First fetch time: ${firstFetchTime}ms');
      expect(firstFetch, isNotNull);

      // Second fetch - should be from cache
      stopwatch.reset();
      stopwatch.start();
      final secondFetch = await logoService.getTeamLogo(
        teamName: teamName,
        sport: sport,
      );
      stopwatch.stop();
      final secondFetchTime = stopwatch.elapsedMilliseconds;

      print('Second fetch time: ${secondFetchTime}ms');
      expect(secondFetch, isNotNull);

      // Cache fetch should be significantly faster
      expect(secondFetchTime < firstFetchTime, isTrue,
        reason: 'Cached fetch should be faster than API fetch');

      // Both fetches should return the same data
      expect(firstFetch?.logoUrl, equals(secondFetch?.logoUrl));
    });

    test('should handle invalid team names gracefully', () async {
      final invalidTeams = [
        'Fake Team Name',
        'Not A Real Team',
        '',
      ];

      for (final team in invalidTeams) {
        print('Testing invalid team: "$team"');

        final logoData = await logoService.getTeamLogo(
          teamName: team,
          sport: 'MLB',
        );

        // Should return null or handle gracefully
        if (logoData == null) {
          print('  ✓ Correctly returned null for invalid team');
        } else {
          print('  ⚠ Returned data for invalid team (might be a fallback)');
        }

        // Should not throw an error
        expect(() async {
          await logoService.getTeamLogo(
            teamName: team,
            sport: 'MLB',
          );
        }, returnsNormally);
      }
    });
  });

  group('MLB Logo Widget Integration Tests', () {
    testWidgets('should display MLB logo in FutureBuilder', (WidgetTester tester) async {
      const teamName = 'New York Yankees';
      const sport = 'MLB';

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FutureBuilder(
              future: TeamLogoService().getTeamLogo(
                teamName: teamName,
                sport: sport,
              ),
              builder: (context, snapshot) {
                if (!snapshot.hasData || snapshot.data?.logoUrl == null) {
                  return const CircularProgressIndicator();
                }
                return Image.network(
                  snapshot.data!.logoUrl!,
                  width: 50,
                  height: 50,
                );
              },
            ),
          ),
        ),
      );

      // Initially should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for future to complete
      await tester.pumpAndSettle();

      // Should now show image
      expect(find.byType(Image), findsOneWidget);
    });
  });
}