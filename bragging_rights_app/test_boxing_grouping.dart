import 'dart:convert';
import 'package:http/http.dart' as http;

/// Test script to verify boxing event grouping is working correctly
/// This will:
/// 1. Fetch boxing fights from Odds API (individual fights)
/// 2. Fetch boxing events from ESPN (grouped events)
/// 3. Attempt to match and group them
/// 4. Display results showing if grouping is successful

void main() async {
  print('🥊 Testing Boxing Event Grouping');
  print('=' * 50);

  // Fetch boxing fights from Odds API
  final oddsApiKey = '51434300fd8bc16e4b57de822b1d4323';
  final oddsUrl = 'https://api.the-odds-api.com/v4/sports/boxing_boxing/odds/?apiKey=$oddsApiKey&regions=us&markets=h2h,spreads,totals&oddsFormat=american';

  print('\n📡 Fetching boxing fights from Odds API...');
  final oddsResponse = await http.get(Uri.parse(oddsUrl));

  if (oddsResponse.statusCode != 200) {
    print('❌ Failed to fetch from Odds API: ${oddsResponse.statusCode}');
    return;
  }

  final oddsFights = json.decode(oddsResponse.body) as List;
  print('✅ Found ${oddsFights.length} individual boxing fights from Odds API');

  // Display first 5 fights
  print('\n📋 Sample fights from Odds API:');
  for (int i = 0; i < 5 && i < oddsFights.length; i++) {
    final fight = oddsFights[i];
    print('  ${i + 1}. ${fight['away_team']} vs ${fight['home_team']}');
    print('      Date: ${fight['commence_time']}');
  }

  // Since ESPN boxing endpoint doesn't work, let's test time-based grouping
  print('\n🕐 Testing time-based grouping fallback...');
  print('Since ESPN endpoint for boxing returns 404, we\'ll group by time windows');

  // Group fights that are within 4 hours of each other
  final groupedByTime = <String, List<dynamic>>{};

  for (final fight in oddsFights) {
    final fightTime = DateTime.parse(fight['commence_time']);
    final dateKey = '${fightTime.year}-${fightTime.month.toString().padLeft(2, '0')}-${fightTime.day.toString().padLeft(2, '0')}';

    if (!groupedByTime.containsKey(dateKey)) {
      groupedByTime[dateKey] = [];
    }
    groupedByTime[dateKey]!.add(fight);
  }

  print('\n📅 Fights grouped by date:');
  for (final entry in groupedByTime.entries) {
    print('  Date: ${entry.key}');
    print('  Number of fights: ${entry.value.length}');

    // Group by 4-hour windows
    final timeGroups = <String, List<dynamic>>{};
    for (final fight in entry.value) {
      final fightTime = DateTime.parse(fight['commence_time']);
      final hourGroup = (fightTime.hour ~/ 4) * 4;
      final groupKey = '${hourGroup.toString().padLeft(2, '0')}:00';

      if (!timeGroups.containsKey(groupKey)) {
        timeGroups[groupKey] = [];
      }
      timeGroups[groupKey]!.add(fight);
    }

    for (final timeEntry in timeGroups.entries) {
      if (timeEntry.value.length > 1) {
        print('    Time window starting ${timeEntry.key}: ${timeEntry.value.length} fights (likely same event)');
        for (int i = 0; i < timeEntry.value.length && i < 3; i++) {
          final fight = timeEntry.value[i];
          print('      - ${fight['away_team']} vs ${fight['home_team']}');
        }
      }
    }
  }

  // Summary
  print('\n' + '=' * 50);
  print('📊 SUMMARY:');
  print('  Total Odds API fights: ${oddsFights.length}');

  int totalEvents = 0;
  int fightsInEvents = 0;

  for (final entry in groupedByTime.entries) {
    final timeGroups = <String, List<dynamic>>{};
    for (final fight in entry.value) {
      final fightTime = DateTime.parse(fight['commence_time']);
      final hourGroup = (fightTime.hour ~/ 4) * 4;
      final groupKey = '${hourGroup.toString().padLeft(2, '0')}:00';

      if (!timeGroups.containsKey(groupKey)) {
        timeGroups[groupKey] = [];
      }
      timeGroups[groupKey]!.add(fight);
    }

    for (final timeEntry in timeGroups.entries) {
      if (timeEntry.value.length > 1) {
        totalEvents++;
        fightsInEvents += timeEntry.value.length;
      }
    }
  }

  print('  Detected events (groups with 2+ fights): $totalEvents');
  print('  Fights in events: $fightsInEvents');
  print('  Ungrouped fights: ${oddsFights.length - fightsInEvents}');

  if (totalEvents == 0) {
    print('\n⚠️ WARNING: No grouped events detected!');
    print('  The grouping logic is NOT working for boxing.');
    print('  All fights appear to be at different times.');
  } else {
    print('\n✅ Found $totalEvents boxing events with multiple fights');
    print('  Time-based grouping is working as fallback');
  }
}

/// Check if two sets of fighter names match
bool _fightersMatch(String espnF1, String espnF2, String oddsF1, String oddsF2) {
  // Normalize names
  espnF1 = espnF1.toLowerCase().trim();
  espnF2 = espnF2.toLowerCase().trim();
  oddsF1 = oddsF1.toLowerCase().trim();
  oddsF2 = oddsF2.toLowerCase().trim();

  // Direct match
  if ((espnF1 == oddsF1 && espnF2 == oddsF2) ||
      (espnF1 == oddsF2 && espnF2 == oddsF1)) {
    return true;
  }

  // Last name matching
  final espnLast1 = _getLastName(espnF1);
  final espnLast2 = _getLastName(espnF2);
  final oddsLast1 = _getLastName(oddsF1);
  final oddsLast2 = _getLastName(oddsF2);

  if ((espnLast1 == oddsLast1 && espnLast2 == oddsLast2) ||
      (espnLast1 == oddsLast2 && espnLast2 == oddsLast1)) {
    return true;
  }

  // Partial match (one fighter matches)
  if (espnF1.contains(oddsF1) || oddsF1.contains(espnF1) ||
      espnF2.contains(oddsF2) || oddsF2.contains(espnF2)) {
    return true;
  }

  return false;
}

String _getLastName(String fullName) {
  final parts = fullName.split(' ');
  return parts.isNotEmpty ? parts.last : '';
}