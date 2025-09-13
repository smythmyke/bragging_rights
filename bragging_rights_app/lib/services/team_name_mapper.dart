/// Team Name Mapping Service
/// Maps team names between different API sources (ESPN, TheSportsDB, Odds API)
class TeamNameMapper {
  static final TeamNameMapper _instance = TeamNameMapper._internal();
  factory TeamNameMapper() => _instance;
  TeamNameMapper._internal();
  
  // ESPN to TheSportsDB mappings
  final Map<String, Map<String, String>> _teamMappings = {
    'nba': {
      // ESPN Name -> TheSportsDB Name
      'LA Lakers': 'Los Angeles Lakers',
      'LA Clippers': 'Los Angeles Clippers',
      'GS Warriors': 'Golden State Warriors',
      'NY Knicks': 'New York Knicks',
      'NO Pelicans': 'New Orleans Pelicans',
      'SA Spurs': 'San Antonio Spurs',
      'OKC Thunder': 'Oklahoma City Thunder',
      // Add more mappings as needed
    },
    'nfl': {
      'LA Rams': 'Los Angeles Rams',
      'LA Chargers': 'Los Angeles Chargers',
      'NY Giants': 'New York Giants',
      'NY Jets': 'New York Jets',
      'TB Buccaneers': 'Tampa Bay Buccaneers',
      'SF 49ers': 'San Francisco 49ers',
      'KC Chiefs': 'Kansas City Chiefs',
      'LV Raiders': 'Las Vegas Raiders',
      'NO Saints': 'New Orleans Saints',
      // Add more mappings as needed
    },
    'mlb': {
      'NY Yankees': 'New York Yankees',
      'NY Mets': 'New York Mets',
      'LA Dodgers': 'Los Angeles Dodgers',
      'LA Angels': 'Los Angeles Angels',
      'SF Giants': 'San Francisco Giants',
      'SD Padres': 'San Diego Padres',
      'TB Rays': 'Tampa Bay Rays',
      'KC Royals': 'Kansas City Royals',
      // Add more mappings as needed
    },
    'nhl': {
      'NY Rangers': 'New York Rangers',
      'NY Islanders': 'New York Islanders',
      'LA Kings': 'Los Angeles Kings',
      'SJ Sharks': 'San Jose Sharks',
      'TB Lightning': 'Tampa Bay Lightning',
      'VGK': 'Vegas Golden Knights',
      'NJ Devils': 'New Jersey Devils',
      // Add more mappings as needed
    },
    'soccer': {
      // Premier League
      'Man United': 'Manchester United',
      'Man City': 'Manchester City',
      'Spurs': 'Tottenham Hotspur',
      'Leicester': 'Leicester City',
      'Newcastle': 'Newcastle United',
      'West Ham': 'West Ham United',
      'Wolves': 'Wolverhampton Wanderers',
      'Brighton': 'Brighton & Hove Albion',
      
      // La Liga
      'Atletico': 'Atletico Madrid',
      'Real': 'Real Madrid',
      'Barca': 'Barcelona',
      'Athletic': 'Athletic Bilbao',
      'Real Sociedad': 'Real Sociedad',
      
      // MLS
      'LAFC': 'Los Angeles FC',
      'LA Galaxy': 'Los Angeles Galaxy',
      'NYC FC': 'New York City FC',
      'NY Red Bulls': 'New York Red Bulls',
      'Atlanta': 'Atlanta United',
      'Inter Miami': 'Inter Miami CF',
      'DC United': 'D.C. United',
      'Orlando': 'Orlando City',
      'Portland': 'Portland Timbers',
      'Seattle': 'Seattle Sounders',
      // Add more mappings as needed
    },
  };
  
  // Common abbreviations across all sports
  final Map<String, String> _commonAbbreviations = {
    'St.': 'Saint',
    'Ft.': 'Fort',
    'Mt.': 'Mount',
    'N.': 'North',
    'S.': 'South',
    'E.': 'East',
    'W.': 'West',
  };
  
  /// Get the mapped team name for API lookup
  String getMappedName({
    required String teamName,
    required String sport,
    required String targetApi,
  }) {
    final sportLower = sport.toLowerCase();
    String sportKey = _getSportKey(sportLower);
    
    // First check if there's a direct mapping
    if (_teamMappings.containsKey(sportKey)) {
      final mappings = _teamMappings[sportKey]!;
      if (mappings.containsKey(teamName)) {
        return mappings[teamName]!;
      }
      
      // Check reverse mapping
      for (final entry in mappings.entries) {
        if (entry.value == teamName) {
          return entry.key;
        }
      }
    }
    
    // Apply common transformations
    String normalized = teamName;
    
    // Expand abbreviations
    _commonAbbreviations.forEach((abbr, full) {
      normalized = normalized.replaceAll(abbr, full);
    });
    
    // Remove common suffixes for sports
    if (sportKey == 'soccer') {
      normalized = normalized
        .replaceAll(' FC', '')
        .replaceAll(' CF', '')
        .replaceAll(' SC', '')
        .replaceAll(' United', '')
        .replaceAll(' City', '')
        .trim();
    }
    
    return normalized;
  }
  
  /// Get team ID for logo service
  String getTeamId(String teamName, String sport) {
    // Generate a standardized ID
    String id = teamName.toLowerCase()
      .replaceAll(' ', '_')
      .replaceAll('.', '')
      .replaceAll('\'', '')
      .replaceAll('-', '_');
    
    // Sport-specific transformations
    final sportKey = _getSportKey(sport.toLowerCase());
    if (sportKey == 'soccer') {
      id = id
        .replaceAll('_fc', '')
        .replaceAll('_cf', '')
        .replaceAll('_sc', '')
        .replaceAll('_united', '')
        .replaceAll('_city', '');
    }
    
    return id;
  }
  
  /// Check if two team names likely refer to the same team
  bool areTeamsSame(String name1, String name2, String sport) {
    // Direct match
    if (name1.toLowerCase() == name2.toLowerCase()) return true;
    
    // Check mappings
    final mapped1 = getMappedName(teamName: name1, sport: sport, targetApi: 'thesportsdb');
    final mapped2 = getMappedName(teamName: name2, sport: sport, targetApi: 'thesportsdb');
    
    if (mapped1.toLowerCase() == mapped2.toLowerCase()) return true;
    
    // Fuzzy matching for partial names
    final normalized1 = _normalizeTeamName(name1, sport);
    final normalized2 = _normalizeTeamName(name2, sport);
    
    // Check if one contains the other (for city/team splits)
    if (normalized1.contains(normalized2) || normalized2.contains(normalized1)) {
      return true;
    }
    
    // Check Levenshtein distance for typos
    if (_calculateSimilarity(normalized1, normalized2) > 0.8) {
      return true;
    }
    
    return false;
  }
  
  String _getSportKey(String sport) {
    if (sport.contains('nba') || sport.contains('basketball')) return 'nba';
    if (sport.contains('nfl') || sport.contains('football') && !sport.contains('soccer')) return 'nfl';
    if (sport.contains('mlb') || sport.contains('baseball')) return 'mlb';
    if (sport.contains('nhl') || sport.contains('hockey')) return 'nhl';
    if (sport.contains('soccer') || sport.contains('football') || sport.contains('premier') || sport.contains('mls')) return 'soccer';
    return 'generic';
  }
  
  String _normalizeTeamName(String name, String sport) {
    String normalized = name.toLowerCase()
      .replaceAll(RegExp(r'[^\w\s]'), '') // Remove special characters
      .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
      .trim();
    
    // Remove common words
    final commonWords = ['the', 'fc', 'cf', 'sc', 'united', 'city', 'real', 'athletic'];
    for (final word in commonWords) {
      normalized = normalized.replaceAll(' $word', '').replaceAll('$word ', '');
    }
    
    return normalized;
  }
  
  double _calculateSimilarity(String s1, String s2) {
    if (s1 == s2) return 1.0;
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    
    // Simple Jaccard similarity based on words
    final words1 = s1.split(' ').toSet();
    final words2 = s2.split(' ').toSet();
    
    final intersection = words1.intersection(words2).length;
    final union = words1.union(words2).length;
    
    return union > 0 ? intersection / union : 0.0;
  }
  
  /// Add custom mapping at runtime
  void addMapping({
    required String sport,
    required String sourceName,
    required String targetName,
  }) {
    final sportKey = _getSportKey(sport.toLowerCase());
    _teamMappings[sportKey] ??= {};
    _teamMappings[sportKey]![sourceName] = targetName;
  }
  
  /// Get all known variations of a team name
  List<String> getTeamVariations(String teamName, String sport) {
    final variations = <String>{teamName};
    final sportKey = _getSportKey(sport.toLowerCase());
    
    // Add mapped names
    if (_teamMappings.containsKey(sportKey)) {
      final mappings = _teamMappings[sportKey]!;
      if (mappings.containsKey(teamName)) {
        variations.add(mappings[teamName]!);
      }
      for (final entry in mappings.entries) {
        if (entry.value == teamName) {
          variations.add(entry.key);
        }
      }
    }
    
    // Add common variations
    if (teamName.contains(' ')) {
      final parts = teamName.split(' ');
      // Add city only
      if (parts.length > 1) {
        variations.add(parts.first);
      }
      // Add team name only
      variations.add(parts.last);
    }
    
    return variations.toList();
  }
}