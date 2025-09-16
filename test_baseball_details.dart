/// Test script to verify baseball game details data flow
///
/// To test:
/// 1. Run the app: flutter run
/// 2. Navigate to All Games screen
/// 3. Find an MLB game and click on it
/// 4. Check the console output for the following:
///
/// Expected Console Output:
/// ```
/// === BASEBALL DETAILS TEST START ===
/// Game ID: [should be a valid ID like 401697155]
/// Sport: MLB
/// Teams: [Away Team] @ [Home Team]
/// Fetching summary from: https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=[ID]
/// Summary response status: 200
/// Summary data keys: [should include 'boxscore']
/// ✅ Box score data found
///   - Teams in boxscore: 2
///   - Team: [Team Name]
///     - Stat group: batting
///     - Stat group: pitching
///
/// Fetching scoreboard from: https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard
/// Scoreboard response status: 200
/// Total events in scoreboard: [number]
/// ✅ Found matching game! (or ❌ Game ID not found)
///   - Probables (pitchers): [0-2]
///   - Weather: [temp]°F, [conditions]
///   - Competitors: 2
/// === BASEBALL DETAILS TEST END ===
/// ```
///
/// Common Issues to Check:
///
/// 1. **No Box Score Data**
///    - Game might not have started yet
///    - Game ID might be invalid
///    - API might be down
///
/// 2. **Game Not Found in Scoreboard**
///    - Game might be from a different day
///    - Game ID format might be wrong
///    - Game might be postponed/cancelled
///
/// 3. **No Pitchers Data**
///    - Game might have already started
///    - Pitchers not announced yet
///    - Spring training or special game
///
/// 4. **Missing Weather Data**
///    - Indoor stadium (dome/retractable roof)
///    - Game not today
///    - Data not available yet

import 'package:http/http.dart' as http;
import 'dart:convert';

void main() async {
  // Test with a sample game ID
  const testGameId = '401697155'; // Replace with actual game ID

  print('Testing ESPN MLB API endpoints...\n');

  // Test Summary API
  print('1. Testing Summary API:');
  final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=$testGameId';

  try {
    final response = await http.get(Uri.parse(summaryUrl));
    print('   Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      print('   ✅ Success!');
      print('   Keys: ${data.keys.toList()}');

      if (data['boxscore'] != null) {
        final teams = data['boxscore']['teams'] as List;
        print('   Teams: ${teams.length}');
        for (final team in teams) {
          print('     - ${team['team']['displayName']}');
        }
      }
    } else {
      print('   ❌ Failed: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }

  print('\n2. Testing Scoreboard API:');
  final scoreboardUrl = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard';

  try {
    final response = await http.get(Uri.parse(scoreboardUrl));
    print('   Status: ${response.statusCode}');

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final events = data['events'] as List;
      print('   ✅ Success!');
      print('   Games today: ${events.length}');

      // Show first 3 games as examples
      for (int i = 0; i < events.length && i < 3; i++) {
        final event = events[i];
        final competition = event['competitions'][0];
        final competitors = competition['competitors'];

        print('   Game ${i + 1}:');
        print('     ID: ${event['id']}');
        print('     ${competitors[1]['team']['abbreviation']} @ ${competitors[0]['team']['abbreviation']}');
      }
    } else {
      print('   ❌ Failed: ${response.statusCode}');
    }
  } catch (e) {
    print('   ❌ Error: $e');
  }
}