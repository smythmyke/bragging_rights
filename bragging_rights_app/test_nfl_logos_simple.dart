import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  print('🔍 NFL Logo Diagnostic Test');
  print('=' * 50);

  // Test 1: Check ESPN API directly
  print('\n1. Testing ESPN NFL API endpoint...');
  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final teams = data['sports']?[0]?['leagues']?[0]?['teams'] ?? [];

      print('✅ ESPN API Success! Found ${teams.length} NFL teams');

      // Show a few teams with logos
      print('\nSample teams with logos:');
      final sampleTeams = ['Chiefs', 'Cowboys', 'Patriots', 'Bills', '49ers'];

      for (final team in teams.take(32)) {
        final teamData = team['team'];
        final displayName = teamData['displayName'];

        // Check if it's one of our sample teams
        for (final sample in sampleTeams) {
          if (displayName.contains(sample)) {
            final logoUrl = teamData['logos']?[0]?['href'] ?? 'No logo';
            print('  ✅ $displayName:');
            print('     Logo: $logoUrl');
            break;
          }
        }
      }
    } else {
      print('❌ ESPN API failed with status ${response.statusCode}');
      print('Response: ${response.body}');
    }
  } catch (e) {
    print('❌ Error accessing ESPN API: $e');
  }

  // Test 2: Check what the API returns for specific team searches
  print('\n2. Testing specific team name formats...');

  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final teams = data['sports']?[0]?['leagues']?[0]?['teams'] ?? [];

      // Test different name formats
      final testNames = [
        'Kansas City Chiefs',
        'Chiefs',
        'Kansas City',
        'Buffalo Bills',
        'Bills',
        'Buffalo',
      ];

      print('\nMatching team names:');
      for (final testName in testNames) {
        var found = false;
        for (final team in teams) {
          final teamData = team['team'];
          final displayName = teamData['displayName'] ?? '';
          final shortName = teamData['shortDisplayName'] ?? '';
          final abbreviation = teamData['abbreviation'] ?? '';
          final location = teamData['location'] ?? '';
          final name = teamData['name'] ?? '';

          if (displayName.toLowerCase() == testName.toLowerCase() ||
              shortName.toLowerCase() == testName.toLowerCase() ||
              abbreviation.toLowerCase() == testName.toLowerCase() ||
              location.toLowerCase() == testName.toLowerCase() ||
              name.toLowerCase() == testName.toLowerCase() ||
              displayName.toLowerCase().contains(testName.toLowerCase()) ||
              testName.toLowerCase().contains(displayName.toLowerCase())) {
            print('  ✅ "$testName" matches: $displayName');
            found = true;
            break;
          }
        }
        if (!found) {
          print('  ❌ "$testName" - no match found');
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  // Test 3: Check the endpoint structure
  print('\n3. Analyzing ESPN API response structure...');

  try {
    final response = await http.get(
      Uri.parse('https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams'),
    );

    if (response.statusCode == 200) {
      final data = json.decode(response.body);

      print('\nAPI Structure:');
      print('  - Top level keys: ${data.keys.toList()}');

      if (data['sports'] != null) {
        final sport = data['sports'][0];
        print('  - Sport name: ${sport['name']}');

        if (sport['leagues'] != null) {
          final league = sport['leagues'][0];
          print('  - League name: ${league['name']}');
          print('  - League abbreviation: ${league['abbreviation']}');

          final teams = league['teams'] ?? [];
          if (teams.isNotEmpty) {
            final firstTeam = teams[0]['team'];
            print('\n  Sample team data structure:');
            print('    - displayName: ${firstTeam['displayName']}');
            print('    - shortDisplayName: ${firstTeam['shortDisplayName']}');
            print('    - abbreviation: ${firstTeam['abbreviation']}');
            print('    - location: ${firstTeam['location']}');
            print('    - name: ${firstTeam['name']}');
            print('    - id: ${firstTeam['id']}');
            print('    - logos: ${firstTeam['logos']?.length ?? 0} logos available');
          }
        }
      }
    }
  } catch (e) {
    print('❌ Error: $e');
  }

  print('\n' + '=' * 50);
  print('Test complete!');
}