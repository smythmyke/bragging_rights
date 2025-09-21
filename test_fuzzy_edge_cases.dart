void main() {
  print('=== TESTING FUZZY MATCHING EDGE CASES ===\n');

  // Test fuzzy matching scenarios
  final fuzzyTests = [
    ['manchester united', 'manchester utd'],
    ['afc bournemouth', 'bournemouth fc'],
    ['newcastle united', 'newcastle utd'],
    ['nottingham forest', 'forest'],
    ['crystal palace', 'palace'],
    ['queens park rangers', 'qpr'],
    ['manchester united', 'man u'],
    ['tottenham hotspur', 'spurs'],
  ];

  for (final test in fuzzyTests) {
    final team1 = normalizeTeamName(test[0]);
    final team2 = normalizeTeamName(test[1]);

    print('Testing: "${test[0]}" vs "${test[1]}"');
    print('Normalized: "$team1" vs "$team2"');

    if (team1 == team2) {
      print('✅ Exact match after normalization\n');
    } else {
      final fuzzyMatch = fuzzyTeamMatch(team1, team2);
      final similarity = calculateSimilarity(team1, team2);

      print('Fuzzy match: ${fuzzyMatch ? "✅ YES" : "❌ NO"}');
      print('Similarity: ${(similarity * 100).toStringAsFixed(0)}%\n');
    }
  }
}

String normalizeTeamName(String team) {
  String normalized = team.toLowerCase().trim();

  // Soccer team normalizations
  if (normalized.contains('newcastle')) return 'newcastle';
  if (normalized.contains('bournemouth')) return 'bournemouth';
  if (normalized.contains('manchester united') || normalized.contains('man united') || normalized == 'man u') {
    return 'manchester united';
  }
  if (normalized.contains('manchester city') || normalized.contains('man city')) {
    return 'manchester city';
  }
  if (normalized.contains('nottingham forest') || normalized == 'forest') {
    return 'nottingham forest';
  }
  if (normalized.contains('crystal palace') || normalized == 'palace') {
    return 'crystal palace';
  }
  if (normalized.contains('queens park rangers') || normalized.contains('qpr')) {
    return 'qpr';
  }
  if (normalized.contains('tottenham') || normalized.contains('spurs')) {
    return 'tottenham';
  }

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

  // Word match check
  final words1 = team1.split(' ').where((w) => w.length > 2).toSet();
  final words2 = team2.split(' ').where((w) => w.length > 2).toSet();

  if (words1.isNotEmpty && words2.isNotEmpty) {
    final commonWords = words1.intersection(words2);
    for (final word in commonWords) {
      if (word != 'united' && word != 'city' && word != 'fc' && word.length > 3) {
        return true;
      }
    }
  }

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