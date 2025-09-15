import 'package:flutter_test/flutter_test.dart';
import 'package:bragging_rights_app/services/team_logo_service.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

void main() {
  group('NFL Team Logo Tests', () {
    final logoService = TeamLogoService();

    test('Test ESPN NFL API endpoint directly', () async {
      try {
        print('\n🔍 Testing ESPN NFL API directly...');
        final response = await http.get(
          Uri.parse('https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams'),
        );

        if (response.statusCode == 200) {
          final data = json.decode(response.body);
          final teams = data['sports']?[0]?['leagues']?[0]?['teams'] ?? [];

          print('✅ ESPN API returned ${teams.length} NFL teams');

          // Print first 5 teams for verification
          for (int i = 0; i < 5 && i < teams.length; i++) {
            final team = teams[i]['team'];
            print('  - ${team['displayName']}: ${team['logos']?[0]?['href'] ?? 'No logo'}');
          }
        } else {
          print('❌ ESPN API failed with status ${response.statusCode}');
        }
      } catch (e) {
        print('❌ Error accessing ESPN API: $e');
      }
    });

    test('Test TeamLogoService with popular NFL teams', () async {
      final testTeams = [
        'Kansas City Chiefs',
        'Chiefs',
        'Dallas Cowboys',
        'Cowboys',
        'Green Bay Packers',
        'New England Patriots',
        'San Francisco 49ers',
        'Buffalo Bills',
      ];

      print('\n🔍 Testing TeamLogoService for NFL teams...');

      for (final teamName in testTeams) {
        print('\nTesting: $teamName');

        // Test with 'NFL' sport
        var logo = await logoService.getTeamLogo(
          teamName: teamName,
          sport: 'NFL',
          league: 'NFL',
        );

        if (logo != null) {
          print('  ✅ Found with sport="NFL": ${logo.logoUrl}');
        } else {
          print('  ❌ Not found with sport="NFL"');
        }

        // Test with 'nfl' lowercase
        logo = await logoService.getTeamLogo(
          teamName: teamName,
          sport: 'nfl',
          league: 'NFL',
        );

        if (logo != null) {
          print('  ✅ Found with sport="nfl": ${logo.logoUrl}');
        } else {
          print('  ❌ Not found with sport="nfl"');
        }

        // Test with 'football'
        logo = await logoService.getTeamLogo(
          teamName: teamName,
          sport: 'football',
          league: 'NFL',
        );

        if (logo != null) {
          print('  ✅ Found with sport="football": ${logo.logoUrl}');
        } else {
          print('  ❌ Not found with sport="football"');
        }
      }
    });

    test('Test team name variations', () async {
      print('\n🔍 Testing different team name formats...');

      final variations = [
        ['Kansas City Chiefs', 'Chiefs', 'Kansas City', 'KC'],
        ['Dallas Cowboys', 'Cowboys', 'Dallas', 'DAL'],
        ['New England Patriots', 'Patriots', 'New England', 'NE'],
      ];

      for (final teamVariations in variations) {
        print('\nBase team: ${teamVariations[0]}');
        for (final variation in teamVariations) {
          final logo = await logoService.getTeamLogo(
            teamName: variation,
            sport: 'NFL',
            league: 'NFL',
          );

          print('  "$variation": ${logo != null ? '✅ Found' : '❌ Not found'}');
        }
      }
    });

    test('Debug exact flow for bet selection screen', () async {
      print('\n🔍 Simulating bet selection screen flow...');

      // Simulate what bet_selection_screen does
      final sport = 'NFL';
      final homeTeam = 'Kansas City Chiefs';
      final awayTeam = 'Buffalo Bills';

      print('Sport: $sport');
      print('Home Team: $homeTeam');
      print('Away Team: $awayTeam');

      // Determine league (same logic as bet_selection_screen)
      String? league;
      final sportLower = sport.toLowerCase();

      if (sportLower.contains('soccer')) {
        league = 'EPL';
      } else if (sportLower.contains('nfl')) {
        league = 'NFL';
      } else if (sportLower.contains('nba')) {
        league = 'NBA';
      } else if (sportLower.contains('mlb')) {
        league = 'MLB';
      } else if (sportLower.contains('nhl')) {
        league = 'NHL';
      }

      print('Determined league: $league');

      // Try to fetch logos
      print('\nFetching home team logo...');
      final homeLogo = await logoService.getTeamLogo(
        teamName: homeTeam,
        sport: sport,
        league: league,
      );

      if (homeLogo != null) {
        print('✅ Home logo found: ${homeLogo.logoUrl}');
        print('   ESPN ID: ${homeLogo.espnId}');
        print('   Display Name: ${homeLogo.displayName}');
      } else {
        print('❌ Home logo not found');
      }

      print('\nFetching away team logo...');
      final awayLogo = await logoService.getTeamLogo(
        teamName: awayTeam,
        sport: sport,
        league: league,
      );

      if (awayLogo != null) {
        print('✅ Away logo found: ${awayLogo.logoUrl}');
        print('   ESPN ID: ${awayLogo.espnId}');
        print('   Display Name: ${awayLogo.displayName}');
      } else {
        print('❌ Away logo not found');
      }
    });
  });
}