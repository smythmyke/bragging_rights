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
    'soccer': 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/teams',
    'soccer_epl': 'https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/teams',
    'soccer_laliga': 'https://site.api.espn.com/apis/site/v2/sports/soccer/esp.1/teams',
    'soccer_seriea': 'https://site.api.espn.com/apis/site/v2/sports/soccer/ita.1/teams',
    'soccer_bundesliga': 'https://site.api.espn.com/apis/site/v2/sports/soccer/ger.1/teams',
    'soccer_ligue1': 'https://site.api.espn.com/apis/site/v2/sports/soccer/fra.1/teams',
    'soccer_mls': 'https://site.api.espn.com/apis/site/v2/sports/soccer/usa.1/teams',
  };

  // Team name variations for matching
  static const Map<String, List<String>> _teamNameVariations = {
    'Manchester United': ['Man United', 'Man Utd', 'MUFC', 'Manchester Utd'],
    'Manchester City': ['Man City', 'MCFC', 'City'],
    'Tottenham Hotspur': ['Tottenham', 'Spurs', 'THFC'],
    'Wolverhampton Wanderers': ['Wolves', 'Wolverhampton'],
    'Brighton & Hove Albion': ['Brighton', 'Brighton and Hove Albion'],
    'Newcastle United': ['Newcastle', 'NUFC'],
    'West Ham United': ['West Ham', 'WHU'],
    'Leicester City': ['Leicester', 'LCFC'],
    'Nottingham Forest': ['Nott\'m Forest', 'Forest'],
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

      // Fetch from ESPN API
      if (sport.toLowerCase().contains('soccer')) {
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
    return '${sport.toLowerCase()}_${teamName.toLowerCase().replaceAll(' ', '_')}';
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
      // Determine the correct ESPN endpoint
      String endpoint;
      if (league != null && _espnEndpoints.containsKey('soccer_${league.toLowerCase()}')) {
        endpoint = _espnEndpoints['soccer_${league.toLowerCase()}']!;
      } else {
        endpoint = _espnEndpoints['soccer']!; // Default to EPL
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
            sport: sport,
            league: league ?? 'EPL',
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