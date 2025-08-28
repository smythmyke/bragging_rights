import 'package:flutter/foundation.dart';

class EventMatcher {
  static final EventMatcher _instance = EventMatcher._internal();
  factory EventMatcher() => _instance;
  EventMatcher._internal();

  // Team name normalization maps
  final Map<String, List<String>> _teamAliases = {
    // NBA
    'Los Angeles Lakers': ['Lakers', 'LAL', 'LA Lakers'],
    'Los Angeles Clippers': ['Clippers', 'LAC', 'LA Clippers'],
    'Golden State Warriors': ['Warriors', 'GSW', 'GS Warriors'],
    'Boston Celtics': ['Celtics', 'BOS', 'Boston'],
    'Brooklyn Nets': ['Nets', 'BKN', 'Brooklyn'],
    'New York Knicks': ['Knicks', 'NYK', 'NY Knicks'],
    'Philadelphia 76ers': ['76ers', 'Sixers', 'PHI', 'Philadelphia'],
    'Toronto Raptors': ['Raptors', 'TOR', 'Toronto'],
    'Chicago Bulls': ['Bulls', 'CHI', 'Chicago'],
    'Milwaukee Bucks': ['Bucks', 'MIL', 'Milwaukee'],
    
    // NFL
    'New England Patriots': ['Patriots', 'NE', 'New England', 'Pats'],
    'New York Giants': ['Giants', 'NYG', 'NY Giants'],
    'New York Jets': ['Jets', 'NYJ', 'NY Jets'],
    'Los Angeles Rams': ['Rams', 'LAR', 'LA Rams'],
    'Los Angeles Chargers': ['Chargers', 'LAC', 'LA Chargers'],
    'San Francisco 49ers': ['49ers', 'Niners', 'SF', 'San Francisco'],
    'Kansas City Chiefs': ['Chiefs', 'KC', 'Kansas City'],
    'Tampa Bay Buccaneers': ['Buccaneers', 'Bucs', 'TB', 'Tampa Bay'],
    
    // MLB
    'New York Yankees': ['Yankees', 'NYY', 'NY Yankees', 'Yanks'],
    'New York Mets': ['Mets', 'NYM', 'NY Mets'],
    'Los Angeles Dodgers': ['Dodgers', 'LAD', 'LA Dodgers'],
    'Los Angeles Angels': ['Angels', 'LAA', 'LA Angels', 'Anaheim Angels'],
    'Boston Red Sox': ['Red Sox', 'BOS', 'Boston', 'Sox'],
    'Chicago White Sox': ['White Sox', 'CWS', 'Chicago Sox'],
    'Chicago Cubs': ['Cubs', 'CHC', 'Chicago'],
    
    // NHL
    'New York Rangers': ['Rangers', 'NYR', 'NY Rangers'],
    'New York Islanders': ['Islanders', 'NYI', 'NY Islanders', 'Isles'],
    'Los Angeles Kings': ['Kings', 'LAK', 'LA Kings'],
    'Tampa Bay Lightning': ['Lightning', 'TBL', 'Tampa Bay', 'Bolts'],
    'Vegas Golden Knights': ['Golden Knights', 'VGK', 'Vegas', 'Knights'],
  };

  // Player name variations
  final Map<String, List<String>> _playerAliases = {
    'LeBron James': ['LeBron', 'L. James', 'James, LeBron', 'King James'],
    'Giannis Antetokounmpo': ['Giannis', 'G. Antetokounmpo', 'Greek Freak'],
    'Stephen Curry': ['Steph Curry', 'S. Curry', 'Curry, Stephen'],
    'Kevin Durant': ['KD', 'K. Durant', 'Durant, Kevin'],
    'Patrick Mahomes': ['Mahomes', 'P. Mahomes', 'Pat Mahomes'],
    'Tom Brady': ['Brady', 'T. Brady', 'TB12'],
  };

  /// Match an event across different API data sources
  Future<EventMatch> matchEvent({
    required String eventId,
    required DateTime eventDate,
    required String homeTeam,
    required String awayTeam,
    required String sport,
    Map<String, dynamic>? additionalData,
  }) async {
    final normalizedHome = normalizeTeamName(homeTeam);
    final normalizedAway = normalizeTeamName(awayTeam);
    
    final match = EventMatch(
      eventId: eventId,
      eventDate: eventDate,
      homeTeam: normalizedHome,
      awayTeam: normalizedAway,
      sport: sport.toLowerCase(),
      matchConfidence: 1.0,
    );

    // Generate search terms for this event
    match.searchTerms = _generateSearchTerms(match);
    
    // Generate API-specific identifiers
    match.apiIdentifiers = _generateApiIdentifiers(match);

    return match;
  }

  /// Normalize team name to standard format
  String normalizeTeamName(String teamName) {
    final cleaned = teamName.trim();
    
    // Check if it's already a standard name
    if (_teamAliases.containsKey(cleaned)) {
      return cleaned;
    }

    // Check aliases
    for (final entry in _teamAliases.entries) {
      if (entry.value.any((alias) => 
        alias.toLowerCase() == cleaned.toLowerCase())) {
        return entry.key;
      }
    }

    // Return original if no match found
    return cleaned;
  }

  /// Normalize player name
  String _normalizePlayerName(String playerName) {
    final cleaned = playerName.trim();
    
    // Check if it's already a standard name
    if (_playerAliases.containsKey(cleaned)) {
      return cleaned;
    }

    // Check aliases
    for (final entry in _playerAliases.entries) {
      if (entry.value.any((alias) => 
        alias.toLowerCase() == cleaned.toLowerCase())) {
        return entry.key;
      }
    }

    return cleaned;
  }

  /// Generate search terms for finding related content
  List<String> _generateSearchTerms(EventMatch match) {
    final terms = <String>[];
    
    // Team-based terms
    terms.add('${match.homeTeam} vs ${match.awayTeam}');
    terms.add('${match.awayTeam} at ${match.homeTeam}');
    
    // Add team aliases
    final homeAliases = _teamAliases[match.homeTeam] ?? [match.homeTeam];
    final awayAliases = _teamAliases[match.awayTeam] ?? [match.awayTeam];
    
    for (final home in homeAliases) {
      for (final away in awayAliases) {
        terms.add('$home $away');
        terms.add('$home vs $away');
      }
    }

    // Sport-specific terms
    switch (match.sport) {
      case 'nba':
      case 'basketball':
        terms.add('${match.homeTeam} basketball');
        terms.add('NBA ${match.homeTeam}');
        break;
      case 'nfl':
      case 'football':
        terms.add('${match.homeTeam} football');
        terms.add('NFL ${match.homeTeam}');
        break;
      case 'mlb':
      case 'baseball':
        terms.add('${match.homeTeam} baseball');
        terms.add('MLB ${match.homeTeam}');
        break;
      case 'nhl':
      case 'hockey':
        terms.add('${match.homeTeam} hockey');
        terms.add('NHL ${match.homeTeam}');
        break;
    }

    return terms;
  }

  /// Generate API-specific identifiers
  Map<String, String> _generateApiIdentifiers(EventMatch match) {
    final identifiers = <String, String>{};
    
    // ESPN format
    identifiers['espn'] = '${match.sport}/${_formatDate(match.eventDate)}';
    
    // Sports-specific formats
    switch (match.sport) {
      case 'nba':
        identifiers['nba_stats'] = _generateNbaGameId(match);
        break;
      case 'nfl':
        identifiers['nfl'] = _generateNflGameId(match);
        break;
      case 'mlb':
        identifiers['mlb_stats'] = _generateMlbGameId(match);
        break;
      case 'nhl':
        identifiers['nhl_api'] = _generateNhlGameId(match);
        break;
    }

    return identifiers;
  }

  /// Format date for API calls
  String _formatDate(DateTime date) {
    return '${date.year}${date.month.toString().padLeft(2, '0')}'
           '${date.day.toString().padLeft(2, '0')}';
  }

  /// Generate NBA game ID format
  String _generateNbaGameId(EventMatch match) {
    // NBA format: 0022300XXX (season + game number)
    final season = match.eventDate.month >= 10 ? 
      match.eventDate.year : match.eventDate.year - 1;
    return '002${season % 100}00001'; // Placeholder - needs actual game number
  }

  /// Generate NFL game ID format  
  String _generateNflGameId(EventMatch match) {
    // NFL format: YYYY_WEEK_AWAY_HOME
    final week = _calculateNflWeek(match.eventDate);
    final awayCode = _getTeamCode(match.awayTeam);
    final homeCode = _getTeamCode(match.homeTeam);
    return '${match.eventDate.year}_${week}_${awayCode}_${homeCode}';
  }

  /// Generate MLB game ID format
  String _generateMlbGameId(EventMatch match) {
    // MLB format: YYYY/MM/DD/awaymlb-homemlb-1
    final dateStr = '${match.eventDate.year}/'
                   '${match.eventDate.month.toString().padLeft(2, '0')}/'
                   '${match.eventDate.day.toString().padLeft(2, '0')}';
    final awayCode = _getTeamCode(match.awayTeam).toLowerCase();
    final homeCode = _getTeamCode(match.homeTeam).toLowerCase();
    return '$dateStr/${awayCode}mlb-${homeCode}mlb-1';
  }

  /// Generate NHL game ID format
  String _generateNhlGameId(EventMatch match) {
    // NHL format: YYYY020XXX (season + game number)
    final season = match.eventDate.month >= 10 ? 
      match.eventDate.year : match.eventDate.year - 1;
    return '${season}020001'; // Placeholder - needs actual game number
  }

  /// Calculate NFL week number
  int _calculateNflWeek(DateTime date) {
    // Simplified - actual calculation would need season start date
    final seasonStart = DateTime(date.year, 9, 7); // Approximate
    if (date.isBefore(seasonStart)) {
      return 0; // Preseason
    }
    final difference = date.difference(seasonStart).inDays;
    return (difference ~/ 7) + 1;
  }

  /// Get team abbreviation code
  String _getTeamCode(String teamName) {
    // This would map full names to abbreviations
    final codes = {
      'Los Angeles Lakers': 'LAL',
      'Boston Celtics': 'BOS',
      'New York Yankees': 'NYY',
      'New England Patriots': 'NE',
      // ... add all teams
    };
    return codes[teamName] ?? teamName.substring(0, 3).toUpperCase();
  }

  /// Calculate match confidence between two events
  double calculateMatchConfidence({
    required Map<String, dynamic> event1,
    required Map<String, dynamic> event2,
  }) {
    double confidence = 0.0;
    
    // Date matching (40% weight)
    final date1 = DateTime.parse(event1['date'].toString());
    final date2 = DateTime.parse(event2['date'].toString());
    final dateDiff = date1.difference(date2).abs();
    
    if (dateDiff.inHours < 1) {
      confidence += 0.4;
    } else if (dateDiff.inHours < 24) {
      confidence += 0.2;
    }

    // Team matching (40% weight)
    final home1 = normalizeTeamName(event1['homeTeam'].toString());
    final home2 = normalizeTeamName(event2['homeTeam'].toString());
    final away1 = normalizeTeamName(event1['awayTeam'].toString());
    final away2 = normalizeTeamName(event2['awayTeam'].toString());
    
    if (home1 == home2 && away1 == away2) {
      confidence += 0.4;
    } else if (home1 == home2 || away1 == away2) {
      confidence += 0.2;
    }

    // Sport matching (20% weight)
    final sport1 = event1['sport'].toString().toLowerCase();
    final sport2 = event2['sport'].toString().toLowerCase();
    
    if (sport1 == sport2) {
      confidence += 0.2;
    }

    return confidence;
  }

  /// Fuzzy string matching
  double _fuzzyMatch(String s1, String s2) {
    if (s1 == s2) return 1.0;
    
    final longer = s1.length > s2.length ? s1 : s2;
    final shorter = s1.length > s2.length ? s2 : s1;
    
    if (longer.isEmpty) return 1.0;
    
    final editDistance = _levenshteinDistance(longer, shorter);
    return (longer.length - editDistance) / longer.length.toDouble();
  }

  /// Calculate Levenshtein distance
  int _levenshteinDistance(String s1, String s2) {
    final m = s1.length;
    final n = s2.length;
    
    if (m == 0) return n;
    if (n == 0) return m;
    
    final d = List.generate(m + 1, (_) => List.filled(n + 1, 0));
    
    for (int i = 0; i <= m; i++) {
      d[i][0] = i;
    }
    
    for (int j = 0; j <= n; j++) {
      d[0][j] = j;
    }
    
    for (int i = 1; i <= m; i++) {
      for (int j = 1; j <= n; j++) {
        final cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        d[i][j] = [
          d[i - 1][j] + 1,      // deletion
          d[i][j - 1] + 1,      // insertion
          d[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }
    
    return d[m][n];
  }
}

/// Event match result
class EventMatch {
  final String eventId;
  final DateTime eventDate;
  final String homeTeam;
  final String awayTeam;
  final String sport;
  double matchConfidence;
  List<String> searchTerms = [];
  Map<String, String> apiIdentifiers = {};

  EventMatch({
    required this.eventId,
    required this.eventDate,
    required this.homeTeam,
    required this.awayTeam,
    required this.sport,
    required this.matchConfidence,
  });

  Map<String, dynamic> toMap() {
    return {
      'eventId': eventId,
      'eventDate': eventDate.toIso8601String(),
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'sport': sport,
      'matchConfidence': matchConfidence,
      'searchTerms': searchTerms,
      'apiIdentifiers': apiIdentifiers,
    };
  }
}