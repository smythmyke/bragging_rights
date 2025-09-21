import 'dart:io';

void main() {
  // Test the normalization and matching logic
  print('=== TESTING TEAM MATCHING LOGIC ===\n');

  // Test data
  final testCases = [
    {
      'espnHome': 'AFC Bournemouth',
      'espnAway': 'Newcastle United',
      'oddsHome': 'Bournemouth',
      'oddsAway': 'Newcastle',
    },
    {
      'espnHome': 'Manchester United',
      'espnAway': 'Manchester City',
      'oddsHome': 'Man United',
      'oddsAway': 'Man City',
    },
    {
      'espnHome': 'Wolverhampton Wanderers',
      'espnAway': 'West Ham United',
      'oddsHome': 'Wolves',
      'oddsAway': 'West Ham',
    },
    {
      'espnHome': 'Leicester City',
      'espnAway': 'Brighton & Hove Albion',
      'oddsHome': 'Leicester',
      'oddsAway': 'Brighton',
    },
  ];

  for (final testCase in testCases) {
    print('ESPN: ${testCase['espnAway']} @ ${testCase['espnHome']}');
    print('Odds: ${testCase['oddsAway']} @ ${testCase['oddsHome']}');

    // Normalize
    final espnHomeNorm = normalizeTeamName(testCase['espnHome']!);
    final espnAwayNorm = normalizeTeamName(testCase['espnAway']!);
    final oddsHomeNorm = normalizeTeamName(testCase['oddsHome']!);
    final oddsAwayNorm = normalizeTeamName(testCase['oddsAway']!);

    print('ESPN normalized: $espnAwayNorm @ $espnHomeNorm');
    print('Odds normalized: $oddsAwayNorm @ $oddsHomeNorm');

    // Check exact match
    final exactMatch = (espnHomeNorm == oddsHomeNorm && espnAwayNorm == oddsAwayNorm) ||
                      (espnHomeNorm == oddsAwayNorm && espnAwayNorm == oddsHomeNorm);

    if (exactMatch) {
      print('✅ EXACT MATCH!\n');
    } else {
      // Try fuzzy match
      final fuzzyHome = fuzzyTeamMatch(espnHomeNorm, oddsHomeNorm);
      final fuzzyAway = fuzzyTeamMatch(espnAwayNorm, oddsAwayNorm);
      final fuzzyHomeRev = fuzzyTeamMatch(espnHomeNorm, oddsAwayNorm);
      final fuzzyAwayRev = fuzzyTeamMatch(espnAwayNorm, oddsHomeNorm);

      if ((fuzzyHome && fuzzyAway) || (fuzzyHomeRev && fuzzyAwayRev)) {
        print('✅ FUZZY MATCH!');
        print('  Home fuzzy: $fuzzyHome, Away fuzzy: $fuzzyAway');
        print('  Reversed - Home: $fuzzyHomeRev, Away: $fuzzyAwayRev\n');
      } else {
        print('❌ NO MATCH\n');
      }
    }
  }
}

String normalizeTeamName(String team) {
  String normalized = team.toLowerCase().trim();

  // Soccer team normalizations (matching our implementation)
  if (normalized.contains('newcastle')) return 'newcastle';
  if (normalized.contains('bournemouth')) return 'bournemouth';
  if (normalized.contains('manchester united') || (normalized.contains('man united') && !normalized.contains('city'))) {
    return 'manchester united';
  }
  if (normalized.contains('manchester city') || normalized.contains('man city')) {
    return 'manchester city';
  }
  if (normalized.contains('west ham')) return 'west ham';
  if (normalized.contains('leicester')) return 'leicester';
  if (normalized.contains('wolverhampton') || normalized.contains('wolves')) return 'wolves';
  if (normalized.contains('brighton')) return 'brighton';
  if (normalized.contains('tottenham') || normalized.contains('spurs')) return 'tottenham';

  // Default normalization
  normalized = normalized
      .replaceAll(' and ', ' ')
      .replaceAll(' & ', ' ')
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  return normalized;
}

bool fuzzyTeamMatch(String team1, String team2) {
  if (team1 == team2) return true;

  // Contains check
  if (team1.length >= 4 && team2.length >= 4) {
    if (team1.contains(team2) || team2.contains(team1)) {
      return true;
    }
  }

  // Calculate similarity
  final similarity = calculateSimilarity(team1, team2);
  if (similarity >= 0.75) return true;

  return false;
}

double calculateSimilarity(String s1, String s2) {
  if (s1.isEmpty || s2.isEmpty) return 0.0;
  if (s1 == s2) return 1.0;

  final bigrams1 = getBigrams(s1);
  final bigrams2 = getBigrams(s2);

  if (bigrams1.isEmpty || bigrams2.isEmpty) return 0.0;

  final intersection = bigrams1.intersection(bigrams2).length;
  final union = bigrams1.union(bigrams2).length;

  return union > 0 ? intersection / union : 0.0;
}

Set<String> getBigrams(String str) {
  if (str.length < 2) return {str};

  final bigrams = <String>{};
  for (int i = 0; i < str.length - 1; i++) {
    bigrams.add(str.substring(i, i + 2));
  }
  return bigrams;
}