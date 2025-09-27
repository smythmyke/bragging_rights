import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for fetching and caching team logos from ESPN API
class TeamLogoService {
  static final TeamLogoService _instance = TeamLogoService._internal();
  factory TeamLogoService() => _instance;
  TeamLogoService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Memory cache for current session
  final Map<String, TeamLogoData> _memoryCache = {};

  // ESPN API endpoints by sport
  static const Map<String, String> _espnEndpoints = {
    // Soccer leagues
    'soccer': 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/teams',
    'soccer_epl': 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/teams',
    'soccer_laliga': 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/teams',
    'soccer_seriea': 'https://site.api.espn.com/apis/site/v2/sports/soccer/ita.1/teams',
    'soccer_bundesliga': 'https://site.api.espn.com/apis/site/v2/sports/soccer/ger.1/teams',
    'soccer_ligue1': 'https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1/teams',
    'soccer_mls': 'https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/teams',

    // American sports leagues
    'nfl': 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/teams',
    'mlb': 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/teams',
    'nba': 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/teams',
    'nhl': 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/teams',
  };

  // Team name variations for matching
  static const Map<String, List<String>> _teamNameVariations = {
    // Soccer teams
    'Manchester United': ['Man United', 'Man Utd', 'MUFC', 'Manchester Utd'],
    'Manchester City': ['Man City', 'MCFC', 'City'],
    'Tottenham Hotspur': ['Tottenham', 'Spurs', 'THFC'],
    'Wolverhampton Wanderers': ['Wolves', 'Wolverhampton'],
    'Brighton & Hove Albion': ['Brighton', 'Brighton and Hove Albion'],
    'Newcastle United': ['Newcastle', 'NUFC'],
    'West Ham United': ['West Ham', 'WHU'],
    'Leicester City': ['Leicester', 'LCFC'],
    'Nottingham Forest': ['Nott\'m Forest', 'Forest'],

    // NFL teams
    'New England Patriots': ['Patriots', 'NE', 'New England'],
    'Kansas City Chiefs': ['Chiefs', 'KC', 'Kansas City'],
    'Green Bay Packers': ['Packers', 'GB', 'Green Bay'],
    'San Francisco 49ers': ['49ers', 'SF', 'San Francisco', 'Niners'],
    'Dallas Cowboys': ['Cowboys', 'DAL', 'Dallas'],
    'Buffalo Bills': ['Bills', 'BUF', 'Buffalo'],
    'Philadelphia Eagles': ['Eagles', 'PHI', 'Philadelphia', 'Philly'],
    'Miami Dolphins': ['Dolphins', 'MIA', 'Miami'],
    'Los Angeles Rams': ['Rams', 'LAR', 'LA Rams'],
    'Los Angeles Chargers': ['Chargers', 'LAC', 'LA Chargers'],
    'Pittsburgh Steelers': ['Steelers', 'PIT', 'Pittsburgh'],
    'Baltimore Ravens': ['Ravens', 'BAL', 'Baltimore'],
    'Cleveland Browns': ['Browns', 'CLE', 'Cleveland'],
    'Cincinnati Bengals': ['Bengals', 'CIN', 'Cincinnati'],
    'New York Giants': ['Giants', 'NYG', 'NY Giants'],
    'New York Jets': ['Jets', 'NYJ', 'NY Jets'],
    'Las Vegas Raiders': ['Raiders', 'LV', 'Las Vegas', 'Vegas'],
    'Denver Broncos': ['Broncos', 'DEN', 'Denver'],
    'Seattle Seahawks': ['Seahawks', 'SEA', 'Seattle'],
    'Tampa Bay Buccaneers': ['Buccaneers', 'TB', 'Tampa Bay', 'Bucs'],
    'Tennessee Titans': ['Titans', 'TEN', 'Tennessee'],
    'Indianapolis Colts': ['Colts', 'IND', 'Indianapolis', 'Indy'],
    'Houston Texans': ['Texans', 'HOU', 'Houston'],
    'Jacksonville Jaguars': ['Jaguars', 'JAX', 'Jacksonville', 'Jags'],
    'Arizona Cardinals': ['Cardinals', 'ARI', 'Arizona'],
    'Atlanta Falcons': ['Falcons', 'ATL', 'Atlanta'],
    'Carolina Panthers': ['Panthers', 'CAR', 'Carolina'],
    'Chicago Bears': ['Bears', 'CHI', 'Chicago'],
    'Detroit Lions': ['Lions', 'DET', 'Detroit'],
    'Minnesota Vikings': ['Vikings', 'MIN', 'Minnesota'],
    'New Orleans Saints': ['Saints', 'NO', 'New Orleans'],
    'Washington Commanders': ['Commanders', 'WAS', 'Washington'],

    // MLB teams
    'New York Yankees': ['Yankees', 'NYY', 'NY Yankees'],
    'Los Angeles Dodgers': ['Dodgers', 'LAD', 'LA Dodgers'],
    'Boston Red Sox': ['Red Sox', 'BOS', 'Boston'],
    'Chicago Cubs': ['Cubs', 'CHC', 'Chicago'],
    'Chicago White Sox': ['White Sox', 'CWS', 'ChiSox'],
    'Houston Astros': ['Astros', 'HOU', 'Houston'],
    'Atlanta Braves': ['Braves', 'ATL', 'Atlanta'],
    'New York Mets': ['Mets', 'NYM', 'NY Mets'],
    'Philadelphia Phillies': ['Phillies', 'PHI', 'Philadelphia'],
    'San Francisco Giants': ['Giants', 'SF', 'San Francisco'],
    'San Diego Padres': ['Padres', 'SD', 'San Diego'],
    'St. Louis Cardinals': ['Cardinals', 'STL', 'St. Louis', 'St Louis'],
    'Tampa Bay Rays': ['Rays', 'TB', 'Tampa Bay'],
    'Toronto Blue Jays': ['Blue Jays', 'TOR', 'Toronto', 'Jays'],
    'Los Angeles Angels': ['Angels', 'LAA', 'LA Angels', 'Anaheim'],
    'Seattle Mariners': ['Mariners', 'SEA', 'Seattle'],
    'Texas Rangers': ['Rangers', 'TEX', 'Texas'],
    'Baltimore Orioles': ['Orioles', 'BAL', 'Baltimore', 'O\'s'],
    'Milwaukee Brewers': ['Brewers', 'MIL', 'Milwaukee'],
    'Minnesota Twins': ['Twins', 'MIN', 'Minnesota'],
    'Detroit Tigers': ['Tigers', 'DET', 'Detroit'],
    'Cleveland Guardians': ['Guardians', 'CLE', 'Cleveland'],
    'Kansas City Royals': ['Royals', 'KC', 'Kansas City'],
    'Cincinnati Reds': ['Reds', 'CIN', 'Cincinnati'],
    'Pittsburgh Pirates': ['Pirates', 'PIT', 'Pittsburgh'],
    'Oakland Athletics': ['Athletics', 'OAK', 'Oakland', 'A\'s'],
    'Arizona Diamondbacks': ['Diamondbacks', 'ARI', 'Arizona', 'D-backs'],
    'Colorado Rockies': ['Rockies', 'COL', 'Colorado'],
    'Miami Marlins': ['Marlins', 'MIA', 'Miami'],
    'Washington Nationals': ['Nationals', 'WAS', 'Washington', 'Nats'],

    // NBA teams
    'Los Angeles Lakers': ['Lakers', 'LAL', 'LA Lakers'],
    'Golden State Warriors': ['Warriors', 'GSW', 'Golden State', 'Dubs'],
    'Boston Celtics': ['Celtics', 'BOS', 'Boston'],
    'Miami Heat': ['Heat', 'MIA', 'Miami'],
    'Milwaukee Bucks': ['Bucks', 'MIL', 'Milwaukee'],
    'Phoenix Suns': ['Suns', 'PHX', 'Phoenix'],
    'Philadelphia 76ers': ['76ers', 'PHI', 'Philadelphia', 'Sixers'],
    'Brooklyn Nets': ['Nets', 'BKN', 'Brooklyn'],
    'Denver Nuggets': ['Nuggets', 'DEN', 'Denver'],
    'Los Angeles Clippers': ['Clippers', 'LAC', 'LA Clippers'],
    'Toronto Raptors': ['Raptors', 'TOR', 'Toronto'],
    'Dallas Mavericks': ['Mavericks', 'DAL', 'Dallas', 'Mavs'],
    'Utah Jazz': ['Jazz', 'UTA', 'Utah'],
    'Portland Trail Blazers': ['Trail Blazers', 'POR', 'Portland', 'Blazers'],
    'New York Knicks': ['Knicks', 'NYK', 'NY Knicks'],
    'Chicago Bulls': ['Bulls', 'CHI', 'Chicago'],
    'San Antonio Spurs': ['Spurs', 'SA', 'San Antonio'],
    'Atlanta Hawks': ['Hawks', 'ATL', 'Atlanta'],
    'Memphis Grizzlies': ['Grizzlies', 'MEM', 'Memphis'],
    'New Orleans Pelicans': ['Pelicans', 'NO', 'New Orleans'],
    'Sacramento Kings': ['Kings', 'SAC', 'Sacramento'],
    'Indiana Pacers': ['Pacers', 'IND', 'Indiana'],
    'Minnesota Timberwolves': ['Timberwolves', 'MIN', 'Minnesota', 'Wolves'],
    'Cleveland Cavaliers': ['Cavaliers', 'CLE', 'Cleveland', 'Cavs'],
    'Oklahoma City Thunder': ['Thunder', 'OKC', 'Oklahoma City'],
    'Charlotte Hornets': ['Hornets', 'CHA', 'Charlotte'],
    'Washington Wizards': ['Wizards', 'WAS', 'Washington'],
    'Detroit Pistons': ['Pistons', 'DET', 'Detroit'],
    'Orlando Magic': ['Magic', 'ORL', 'Orlando'],
    'Houston Rockets': ['Rockets', 'HOU', 'Houston'],

    // NHL teams
    'New York Rangers': ['Rangers', 'NYR', 'NY Rangers'],
    'Toronto Maple Leafs': ['Maple Leafs', 'TOR', 'Toronto', 'Leafs'],
    'Montreal Canadiens': ['Canadiens', 'MTL', 'Montreal', 'Habs'],
    'Vegas Golden Knights': ['Golden Knights', 'VGK', 'Vegas', 'Knights'],
    'Colorado Avalanche': ['Avalanche', 'COL', 'Colorado', 'Avs'],
    'Tampa Bay Lightning': ['Lightning', 'TB', 'Tampa Bay', 'Bolts'],
    'Boston Bruins': ['Bruins', 'BOS', 'Boston'],
    'Pittsburgh Penguins': ['Penguins', 'PIT', 'Pittsburgh', 'Pens'],
    'Washington Capitals': ['Capitals', 'WAS', 'Washington', 'Caps'],
    'Edmonton Oilers': ['Oilers', 'EDM', 'Edmonton'],
    'Calgary Flames': ['Flames', 'CGY', 'Calgary'],
    'Vancouver Canucks': ['Canucks', 'VAN', 'Vancouver'],
    'Winnipeg Jets': ['Jets', 'WPG', 'Winnipeg'],
    'Ottawa Senators': ['Senators', 'OTT', 'Ottawa', 'Sens'],
    'Florida Panthers': ['Panthers', 'FLA', 'Florida'],
    'Carolina Hurricanes': ['Hurricanes', 'CAR', 'Carolina', 'Canes'],
    'New Jersey Devils': ['Devils', 'NJ', 'New Jersey'],
    'New York Islanders': ['Islanders', 'NYI', 'NY Islanders', 'Isles'],
    'Philadelphia Flyers': ['Flyers', 'PHI', 'Philadelphia'],
    'Detroit Red Wings': ['Red Wings', 'DET', 'Detroit', 'Wings'],
    'Chicago Blackhawks': ['Blackhawks', 'CHI', 'Chicago', 'Hawks'],
    'Minnesota Wild': ['Wild', 'MIN', 'Minnesota'],
    'St. Louis Blues': ['Blues', 'STL', 'St. Louis', 'St Louis'],
    'Nashville Predators': ['Predators', 'NSH', 'Nashville', 'Preds'],
    'Dallas Stars': ['Stars', 'DAL', 'Dallas'],
    'Los Angeles Kings': ['Kings', 'LA', 'Los Angeles'],
    'San Jose Sharks': ['Sharks', 'SJ', 'San Jose'],
    'Anaheim Ducks': ['Ducks', 'ANA', 'Anaheim'],
    'Seattle Kraken': ['Kraken', 'SEA', 'Seattle'],
    'Arizona Coyotes': ['Coyotes', 'ARI', 'Arizona', 'Yotes'],
    'Columbus Blue Jackets': ['Blue Jackets', 'CBJ', 'Columbus', 'Jackets'],
    'Buffalo Sabres': ['Sabres', 'BUF', 'Buffalo'],
  };

  /// Get team logo data with intelligent caching
  Future<TeamLogoData?> getTeamLogo({
    required String teamName,
    required String sport,
    String? league,
  }) async {
    try {
      debugPrint('🎯 TeamLogoService: Getting logo for $teamName ($sport)');

      // Create a unique key for this team
      final cacheKey = _createCacheKey(teamName, sport);

      // Check memory cache first
      if (_memoryCache.containsKey(cacheKey)) {
        debugPrint('✅ Found in memory cache');
        return _memoryCache[cacheKey];
      }

      // Check Firestore cache
      final firestoreData = await _getFromFirestore(cacheKey);
      if (firestoreData != null) {
        debugPrint('✅ Found in Firestore cache');
        _memoryCache[cacheKey] = firestoreData;
        return firestoreData;
      }

      // Fetch from ESPN API for all supported sports
      final normalizedSport = _normalizeSportName(sport);
      if (_espnEndpoints.containsKey(normalizedSport)) {
        final espnData = await _fetchFromEspn(teamName, sport, league);
        if (espnData != null) {
          debugPrint('✅ Fetched from ESPN API');
          await _saveToFirestore(espnData);
          _memoryCache[cacheKey] = espnData;
          return espnData;
        }
      }

      debugPrint('❌ No logo found for $teamName');
      return null;
    } catch (e) {
      debugPrint('❌ Error getting team logo: $e');
      return null;
    }
  }

  /// Create a unique cache key for a team
  String _createCacheKey(String teamName, String sport) {
    final normalizedSport = _normalizeSportName(sport);
    return '${normalizedSport}_${teamName.toLowerCase().replaceAll(' ', '_')}';
  }

  /// Normalize sport name to match our endpoint keys
  String _normalizeSportName(String sport) {
    final sportLower = sport.toLowerCase();

    // Check for specific sports
    if (sportLower.contains('nfl') || sportLower.contains('football') && !sportLower.contains('soccer')) {
      return 'nfl';
    }
    if (sportLower.contains('mlb') || sportLower.contains('baseball')) {
      return 'mlb';
    }
    if (sportLower.contains('nba') || sportLower.contains('basketball')) {
      return 'nba';
    }
    if (sportLower.contains('nhl') || sportLower.contains('hockey')) {
      return 'nhl';
    }
    if (sportLower.contains('soccer') || sportLower.contains('premier') || sportLower.contains('mls')) {
      return 'soccer';
    }

    // Return the original sport if no match
    return sportLower;
  }

  /// Get team logo data from Firestore
  Future<TeamLogoData?> _getFromFirestore(String cacheKey) async {
    try {
      final doc = await _firestore
          .collection('team_logos')
          .doc(cacheKey)
          .get();

      if (doc.exists && doc.data() != null) {
        return TeamLogoData.fromMap(doc.data()!);
      }
      return null;
    } catch (e) {
      debugPrint('Error reading from Firestore: $e');
      return null;
    }
  }

  /// Save team logo data to Firestore
  Future<void> _saveToFirestore(TeamLogoData data) async {
    try {
      await _firestore
          .collection('team_logos')
          .doc(data.cacheKey)
          .set(data.toMap());
      debugPrint('💾 Saved to Firestore: ${data.teamName}');
    } catch (e) {
      debugPrint('Error saving to Firestore: $e');
    }
  }

  /// Fetch team logo from ESPN API
  Future<TeamLogoData?> _fetchFromEspn(
    String teamName,
    String sport,
    String? league,
  ) async {
    try {
      debugPrint('🔍 [ESPN] Fetching logo for: $teamName');
      debugPrint('🔍 [ESPN] Sport: $sport, League: $league');

      // Normalize sport name
      final normalizedSport = _normalizeSportName(sport);
      debugPrint('🔍 [ESPN] Normalized sport: $normalizedSport');

      // Determine the correct ESPN endpoint
      String endpoint;
      if (league != null && _espnEndpoints.containsKey('${normalizedSport}_${league.toLowerCase()}')) {
        endpoint = _espnEndpoints['${normalizedSport}_${league.toLowerCase()}']!;
        debugPrint('🔍 [ESPN] Using league-specific endpoint');
      } else if (_espnEndpoints.containsKey(normalizedSport)) {
        endpoint = _espnEndpoints[normalizedSport]!;
        debugPrint('🔍 [ESPN] Using sport endpoint: $endpoint');
      } else {
        debugPrint('❌ [ESPN] No ESPN endpoint for sport: $normalizedSport');
        debugPrint('❌ [ESPN] Available endpoints: ${_espnEndpoints.keys.toList()}');
        return null;
      }

      debugPrint('📡 Fetching from ESPN: $endpoint');

      final response = await http.get(Uri.parse(endpoint));

      if (response.statusCode != 200) {
        debugPrint('❌ ESPN API returned ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final teams = data['sports']?[0]?['leagues']?[0]?['teams'] ?? [];

      // Find matching team
      debugPrint('🔍 [ESPN] Searching through ${teams.length} teams for: $teamName');
      for (final teamData in teams) {
        final team = teamData['team'];
        if (team == null) continue;

        final espnName = team['displayName']?.toString() ?? '';
        final espnShortName = team['shortDisplayName']?.toString() ?? '';
        final espnAbbr = team['abbreviation']?.toString() ?? '';

        // Check if this is our team
        if (_teamsMatch(teamName, espnName) ||
            _teamsMatch(teamName, espnShortName) ||
            _teamsMatch(teamName, espnAbbr)) {
          debugPrint('✅ [ESPN] Match found! $teamName matches $espnName');

          // Extract logo URL
          final logos = team['logos'];
          String? logoUrl;

          if (logos is List && logos.isNotEmpty) {
            logoUrl = logos[0]['href'];
          }

          if (logoUrl == null) {
            debugPrint('❌ No logo URL for $espnName');
            continue;
          }

          debugPrint('✅ Found match: $espnName -> $logoUrl');

          return TeamLogoData(
            cacheKey: _createCacheKey(teamName, sport),
            teamName: teamName,
            displayName: espnName,
            sport: normalizedSport,
            league: league ?? normalizedSport.toUpperCase(),
            logoUrl: logoUrl,
            espnId: team['id']?.toString(),
            abbreviation: espnAbbr,
            primaryColor: team['color'],
            secondaryColor: team['alternateColor'],
            lastUpdated: DateTime.now(),
          );
        }
      }

      debugPrint('❌ No matching team found for $teamName');
      return null;
    } catch (e) {
      debugPrint('❌ Error fetching from ESPN: $e');
      return null;
    }
  }

  /// Check if two team names match
  bool _teamsMatch(String name1, String name2) {
    // Direct match
    if (name1.toLowerCase() == name2.toLowerCase()) return true;

    // Check variations
    for (final entry in _teamNameVariations.entries) {
      final variations = [entry.key, ...entry.value];

      bool name1Matches = variations.any((v) =>
        v.toLowerCase() == name1.toLowerCase());
      bool name2Matches = variations.any((v) =>
        v.toLowerCase() == name2.toLowerCase());

      if (name1Matches && name2Matches) return true;
    }

    // Partial match for simple cases
    final n1Lower = name1.toLowerCase();
    final n2Lower = name2.toLowerCase();

    // Skip partial matching if one is a very short abbreviation (3 chars or less)
    // to avoid false matches like "LA" matching "Philadelphia"
    if ((n1Lower.length <= 3 || n2Lower.length <= 3) && n1Lower != n2Lower) {
      return false;
    }

    if (n1Lower.contains(n2Lower) || n2Lower.contains(n1Lower)) {
      // Avoid false positives like "United" matching "Manchester United" and "Newcastle United"
      if (!n1Lower.contains('united') && !n2Lower.contains('united')) {
        return true;
      }
    }

    return false;
  }

  /// Batch fetch logos for multiple teams (efficient for game lists)
  Future<Map<String, TeamLogoData>> getBatchLogos({
    required List<String> teamNames,
    required String sport,
    String? league,
  }) async {
    final results = <String, TeamLogoData>{};

    for (final teamName in teamNames) {
      final logo = await getTeamLogo(
        teamName: teamName,
        sport: sport,
        league: league,
      );

      if (logo != null) {
        results[teamName] = logo;
      }
    }

    return results;
  }

  /// Clear memory cache
  void clearCache() {
    _memoryCache.clear();
    debugPrint('🗑️ TeamLogoService: Memory cache cleared');
  }
}

/// Data model for team logo information
class TeamLogoData {
  final String cacheKey;
  final String teamName;
  final String displayName;
  final String sport;
  final String league;
  final String logoUrl;
  final String? espnId;
  final String? abbreviation;
  final String? primaryColor;
  final String? secondaryColor;
  final DateTime lastUpdated;

  TeamLogoData({
    required this.cacheKey,
    required this.teamName,
    required this.displayName,
    required this.sport,
    required this.league,
    required this.logoUrl,
    this.espnId,
    this.abbreviation,
    this.primaryColor,
    this.secondaryColor,
    required this.lastUpdated,
  });

  Map<String, dynamic> toMap() {
    return {
      'cacheKey': cacheKey,
      'teamName': teamName,
      'displayName': displayName,
      'sport': sport,
      'league': league,
      'logoUrl': logoUrl,
      'espnId': espnId,
      'abbreviation': abbreviation,
      'primaryColor': primaryColor,
      'secondaryColor': secondaryColor,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory TeamLogoData.fromMap(Map<String, dynamic> map) {
    return TeamLogoData(
      cacheKey: map['cacheKey'] ?? '',
      teamName: map['teamName'] ?? '',
      displayName: map['displayName'] ?? '',
      sport: map['sport'] ?? '',
      league: map['league'] ?? '',
      logoUrl: map['logoUrl'] ?? '',
      espnId: map['espnId'],
      abbreviation: map['abbreviation'],
      primaryColor: map['primaryColor'],
      secondaryColor: map['secondaryColor'],
      lastUpdated: map['lastUpdated'] != null
          ? DateTime.parse(map['lastUpdated'])
          : DateTime.now(),
    );
  }
}