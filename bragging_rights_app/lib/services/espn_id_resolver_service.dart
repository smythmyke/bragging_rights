import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../models/game_model.dart';

/// Service to resolve ESPN IDs for games that come from other sources (like Odds API)
/// This allows us to use Odds API for comprehensive game listings while still
/// being able to fetch detailed data from ESPN when needed
class EspnIdResolverService {
  final _firestore = FirebaseFirestore.instance;

  // Memory cache for quick lookups
  static final Map<String, String> _memoryCache = {};

  // Singleton instance
  static final EspnIdResolverService _instance = EspnIdResolverService._internal();
  factory EspnIdResolverService() => _instance;
  EspnIdResolverService._internal();

  // ESPN API endpoints by sport
  static const Map<String, String> _espnEndpoints = {
    'MLB': 'baseball/mlb',
    'NFL': 'football/nfl',
    'NBA': 'basketball/nba',
    'NHL': 'hockey/nhl',
    'MMA': 'mma',
    'BOXING': 'boxing',
    'SOCCER': 'soccer',
    'TENNIS': 'tennis',
  };

  /// Main method to resolve ESPN ID for a game
  Future<String?> resolveEspnId(GameModel game) async {
    debugPrint('🔍 Resolving ESPN ID for game: ${game.id}');

    // If game already has ESPN ID, return it
    if (game.espnId != null && game.espnId!.isNotEmpty) {
      debugPrint('✅ Game already has ESPN ID: ${game.espnId}');
      return game.espnId;
    }

    // 1. Check memory cache
    final cacheKey = game.id;
    if (_memoryCache.containsKey(cacheKey)) {
      debugPrint('✅ Found ESPN ID in memory cache: ${_memoryCache[cacheKey]}');
      return _memoryCache[cacheKey];
    }

    // 2. Check Firestore cache
    try {
      final mapping = await _firestore
          .collection('id_mappings')
          .doc(cacheKey)
          .get();

      if (mapping.exists) {
        final espnId = mapping.data()?['espnId']?.toString();
        if (espnId != null) {
          _memoryCache[cacheKey] = espnId;
          debugPrint('✅ Found ESPN ID in Firestore cache: $espnId');
          return espnId;
        }
      }
    } catch (e) {
      debugPrint('Error checking Firestore cache: $e');
    }

    // 3. Resolve from ESPN API
    debugPrint('🌐 Attempting to match with ESPN API...');
    final espnId = await _matchWithEspn(game);

    if (espnId != null) {
      // 4. Cache the mapping
      await _saveMapping(cacheKey, espnId, game);
      _memoryCache[cacheKey] = espnId;
      debugPrint('✅ Successfully resolved ESPN ID: $espnId');

      // Also update the game in Firestore with ESPN ID
      await _updateGameWithEspnId(game.id, espnId);
    } else {
      debugPrint('❌ Could not resolve ESPN ID for game');
    }

    return espnId;
  }

  /// Match game with ESPN API to find the ESPN ID
  Future<String?> _matchWithEspn(GameModel game) async {
    try {
      var sportPath = _espnEndpoints[game.sport.toUpperCase()];
      if (sportPath == null) {
        debugPrint('❌ No ESPN endpoint for sport: ${game.sport}');
        return null;
      }

      // Special handling for soccer - need to specify league
      if (game.sport.toUpperCase() == 'SOCCER') {
        String league = 'eng.1'; // Default to Premier League

        // Determine league from game data if available
        if (game.league != null) {
          final leagueName = game.league!.toLowerCase();
          if (leagueName.contains('premier') || leagueName.contains('epl')) {
            league = 'eng.1';
          } else if (leagueName.contains('la liga')) {
            league = 'esp.1';
          } else if (leagueName.contains('bundesliga')) {
            league = 'ger.1';
          } else if (leagueName.contains('serie a')) {
            league = 'ita.1';
          } else if (leagueName.contains('ligue 1')) {
            league = 'fra.1';
          } else if (leagueName.contains('mls')) {
            league = 'usa.1';
          } else if (leagueName.contains('champions')) {
            league = 'uefa.champions';
          }
        }
        sportPath = 'soccer/$league';
        debugPrint('🌍 Using soccer league: $league');
      }

      // Format date for ESPN API (yyyyMMdd format)
      // ESPN sometimes lists games under different days due to timezone issues
      // We'll check current date, day before, and day after for ALL sports
      final gameDate = game.gameTime.toUtc();

      // Prepare three dates to check (works for all sports)
      final datesToCheck = [
        gameDate,                              // Current date
        gameDate.subtract(Duration(days: 1)),  // Day before
        gameDate.add(Duration(days: 1)),       // Day after
      ];

      debugPrint('📡 Searching for ESPN ${game.sport} game: ${game.awayTeam} @ ${game.homeTeam}');

      // Try each date until we find a match
      for (int dateIndex = 0; dateIndex < datesToCheck.length; dateIndex++) {
        final checkDate = datesToCheck[dateIndex];
        final dateString = '${checkDate.year}${checkDate.month.toString().padLeft(2, '0')}${checkDate.day.toString().padLeft(2, '0')}';

        final dateLabel = dateIndex == 0 ? 'game date' :
                         dateIndex == 1 ? 'day before' : 'day after';

        final url = 'https://site.api.espn.com/apis/site/v2/sports/$sportPath/scoreboard?dates=$dateString';
        debugPrint('   Checking $dateLabel ($dateString)...');

        try {
          final response = await http.get(Uri.parse(url));

          if (response.statusCode == 200) {
            final data = json.decode(response.body);
            final events = data['events'] as List? ?? [];

            debugPrint('     Found ${events.length} events');

            // Log first few events for debugging (especially useful for NBA/NHL/MLB)
            if (events.isNotEmpty && (game.sport.toUpperCase() == 'NBA' ||
                                      game.sport.toUpperCase() == 'NHL' ||
                                      game.sport.toUpperCase() == 'MLB')) {
              for (int i = 0; i < events.length && i < 3; i++) {
                final evt = events[i];
                final comps = evt['competitions']?[0];
                if (comps != null) {
                  final competitors = comps['competitors'] as List? ?? [];
                  if (competitors.length >= 2) {
                    final home = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => {})['team']?['displayName'] ?? 'Unknown';
                    final away = competitors.firstWhere((c) => c['homeAway'] == 'away', orElse: () => {})['team']?['displayName'] ?? 'Unknown';
                    debugPrint('       - $away @ $home');
                  }
                }
              }
            }

            // Check each event for a match
            for (final event in events) {
              if (_eventMatches(event, game)) {
                final espnId = event['id'].toString();
                debugPrint('✅ Found matching ESPN event on $dateLabel: $espnId');
                return espnId;
              }
            }
          } else {
            debugPrint('     API error: ${response.statusCode}');
          }
        } catch (e) {
          debugPrint('     Error fetching date: $e');
        }
      }

      debugPrint('❌ No matching event found after checking 3 days');
      debugPrint('   Looking for: ${game.awayTeam} @ ${game.homeTeam}');
    } catch (e) {
      debugPrint('❌ Error matching with ESPN: $e');
    }

    return null;
  }

  /// Check if an ESPN event matches our game
  bool _eventMatches(Map<String, dynamic> event, GameModel game) {
    try {
      // Get competitors from event
      final competition = event['competitions']?[0];
      if (competition == null) return false;

      final competitors = competition['competitors'] as List? ?? [];
      if (competitors.length < 2) return false;

      // Extract team names
      final homeCompetitor = competitors.firstWhere(
        (c) => c['homeAway'] == 'home',
        orElse: () => <String, dynamic>{},
      );
      final awayCompetitor = competitors.firstWhere(
        (c) => c['homeAway'] == 'away',
        orElse: () => <String, dynamic>{},
      );

      final homeTeam = homeCompetitor['team']?['displayName']?.toString() ?? '';
      final awayTeam = awayCompetitor['team']?['displayName']?.toString() ?? '';

      // Debug output for matching
      if (game.sport.toUpperCase() == 'SOCCER' || game.sport.toUpperCase() == 'NBA') {
        debugPrint('   Comparing ESPN: $awayTeam @ $homeTeam');
        debugPrint('   With our game: ${game.awayTeam} @ ${game.homeTeam}');
      }

      // Check if teams match
      final teamsMatch = _teamsMatch(homeTeam, awayTeam, game.homeTeam, game.awayTeam);

      if (teamsMatch) {
        // Also check if dates are close (within 24 hours)
        final eventDate = DateTime.tryParse(event['date'] ?? '');
        if (eventDate != null) {
          final timeDiff = eventDate.difference(game.gameTime).abs();
          if (timeDiff.inHours <= 24) {
            debugPrint('✅ Match found: ${awayTeam} @ ${homeTeam}');
            return true;
          }
        } else {
          // If no date check possible, just use team match
          return true;
        }
      }
    } catch (e) {
      debugPrint('Error checking event match: $e');
    }

    return false;
  }

  /// Check if team names match (with normalization and fuzzy matching)
  bool _teamsMatch(String espnHome, String espnAway, String gameHome, String gameAway) {
    final normalizedEspnHome = _normalizeTeamName(espnHome);
    final normalizedEspnAway = _normalizeTeamName(espnAway);
    final normalizedGameHome = _normalizeTeamName(gameHome);
    final normalizedGameAway = _normalizeTeamName(gameAway);

    debugPrint('     ESPN normalized: [$normalizedEspnAway @ $normalizedEspnHome]');
    debugPrint('     Game normalized: [$normalizedGameAway @ $normalizedGameHome]');

    // First try exact match (both normal order and reversed)
    final exactNormalMatch = (normalizedEspnHome == normalizedGameHome && normalizedEspnAway == normalizedGameAway);
    final exactReversedMatch = (normalizedEspnHome == normalizedGameAway && normalizedEspnAway == normalizedGameHome);

    if (exactNormalMatch) {
      debugPrint('     ✅ Teams match exactly (normal order)');
      return true;
    } else if (exactReversedMatch) {
      debugPrint('     ✅ Teams match exactly (reversed order)');
      return true;
    }

    // If exact match fails, try fuzzy matching
    final fuzzyNormalMatch = _fuzzyTeamMatch(normalizedEspnHome, normalizedGameHome) &&
                             _fuzzyTeamMatch(normalizedEspnAway, normalizedGameAway);
    final fuzzyReversedMatch = _fuzzyTeamMatch(normalizedEspnHome, normalizedGameAway) &&
                               _fuzzyTeamMatch(normalizedEspnAway, normalizedGameHome);

    if (fuzzyNormalMatch) {
      debugPrint('     ✅ Teams match with fuzzy matching (normal order)');
      return true;
    } else if (fuzzyReversedMatch) {
      debugPrint('     ✅ Teams match with fuzzy matching (reversed order)');
      return true;
    }

    debugPrint('     ❌ Teams do not match (tried exact and fuzzy)');
    return false;
  }

  /// Fuzzy match two team names
  bool _fuzzyTeamMatch(String team1, String team2) {
    // If they're exactly the same, it's a match
    if (team1 == team2) return true;

    // If one contains the other (and it's meaningful length), it's likely a match
    if (team1.length >= 4 && team2.length >= 4) {
      if (team1.contains(team2) || team2.contains(team1)) {
        debugPrint('       Fuzzy match: "$team1" ~ "$team2" (contains)');
        return true;
      }
    }

    // Calculate similarity score using simple character overlap
    final similarity = _calculateSimilarity(team1, team2);
    if (similarity >= 0.75) {  // 75% similarity threshold
      debugPrint('       Fuzzy match: "$team1" ~ "$team2" (${(similarity * 100).toStringAsFixed(0)}% similar)');
      return true;
    }

    // Check for common word matches (for multi-word teams)
    if (_hasSignificantWordMatch(team1, team2)) {
      debugPrint('       Fuzzy match: "$team1" ~ "$team2" (significant words match)');
      return true;
    }

    return false;
  }

  /// Calculate similarity between two strings (0.0 to 1.0)
  double _calculateSimilarity(String s1, String s2) {
    if (s1.isEmpty || s2.isEmpty) return 0.0;
    if (s1 == s2) return 1.0;

    // Use Jaccard similarity with character bigrams
    final bigrams1 = _getBigrams(s1);
    final bigrams2 = _getBigrams(s2);

    if (bigrams1.isEmpty || bigrams2.isEmpty) return 0.0;

    final intersection = bigrams1.intersection(bigrams2).length;
    final union = bigrams1.union(bigrams2).length;

    return union > 0 ? intersection / union : 0.0;
  }

  /// Get character bigrams from a string
  Set<String> _getBigrams(String str) {
    if (str.length < 2) return {str};

    final bigrams = <String>{};
    for (int i = 0; i < str.length - 1; i++) {
      bigrams.add(str.substring(i, i + 2));
    }
    return bigrams;
  }

  /// Check if teams share significant words (for multi-word team names)
  bool _hasSignificantWordMatch(String team1, String team2) {
    final words1 = team1.split(' ').where((w) => w.length > 2).toSet();
    final words2 = team2.split(' ').where((w) => w.length > 2).toSet();

    if (words1.isEmpty || words2.isEmpty) return false;

    // Check for significant word overlap
    final commonWords = words1.intersection(words2);

    // If they share at least one significant word (not just "fc", "united", etc.)
    for (final word in commonWords) {
      // Ignore common suffixes/prefixes
      if (word != 'united' && word != 'city' && word != 'fc' && word != 'afc' &&
          word != 'town' && word != 'county' && word.length > 3) {
        return true;
      }
    }

    return false;
  }

  /// Normalize team name for comparison
  String _normalizeTeamName(String team) {
    // First do basic normalization
    String normalized = team
        .toLowerCase()
        .trim();

    // === COMPREHENSIVE SOCCER TEAM NORMALIZATIONS ===
    // Premier League and common soccer teams

    // Teams with "United"
    if (normalized.contains('newcastle')) {
      return 'newcastle';  // Newcastle United -> Newcastle
    }
    if (normalized.contains('manchester united') || (normalized.contains('man united') && !normalized.contains('city'))) {
      return 'manchester united';  // Keep full to distinguish from City
    }
    if (normalized.contains('manchester city') || normalized.contains('man city')) {
      return 'manchester city';  // Keep full to distinguish from United
    }
    if (normalized.contains('west ham')) {
      return 'west ham';  // West Ham United -> West Ham
    }
    if (normalized.contains('leeds')) {
      return 'leeds';  // Leeds United -> Leeds
    }
    if (normalized.contains('sheffield united')) {
      return 'sheffield united';  // Keep full to distinguish from Wednesday
    }
    if (normalized.contains('sheffield wednesday')) {
      return 'sheffield wednesday';  // Keep full to distinguish from United
    }

    // Teams with "AFC/FC" prefix/suffix
    if (normalized.contains('bournemouth')) {
      return 'bournemouth';  // AFC Bournemouth -> Bournemouth
    }
    if (normalized.contains('wimbledon')) {
      return 'wimbledon';  // AFC Wimbledon -> Wimbledon
    }

    // Teams with "City"
    if (normalized.contains('leicester')) {
      return 'leicester';  // Leicester City -> Leicester
    }
    if (normalized.contains('norwich')) {
      return 'norwich';  // Norwich City -> Norwich
    }
    if (normalized.contains('bristol city')) {
      return 'bristol city';  // Keep full to distinguish from Rovers
    }
    if (normalized.contains('bristol rovers')) {
      return 'bristol rovers';  // Keep full to distinguish from City
    }
    if (normalized.contains('coventry')) {
      return 'coventry';  // Coventry City -> Coventry
    }
    if (normalized.contains('cardiff')) {
      return 'cardiff';  // Cardiff City -> Cardiff
    }
    if (normalized.contains('swansea')) {
      return 'swansea';  // Swansea City -> Swansea
    }
    if (normalized.contains('hull')) {
      return 'hull';  // Hull City -> Hull
    }
    if (normalized.contains('stoke')) {
      return 'stoke';  // Stoke City -> Stoke
    }

    // Teams with longer names
    if (normalized.contains('wolverhampton') || normalized.contains('wolves')) {
      return 'wolves';  // Wolverhampton Wanderers -> Wolves
    }
    if (normalized.contains('brighton')) {
      return 'brighton';  // Brighton & Hove Albion -> Brighton
    }
    if (normalized.contains('tottenham') || normalized.contains('spurs')) {
      return 'tottenham';  // Tottenham Hotspur -> Tottenham
    }
    if (normalized.contains('nottingham forest') || normalized == 'forest') {
      return 'nottingham forest';  // Keep full name
    }
    if (normalized.contains('crystal palace') || normalized == 'palace') {
      return 'crystal palace';  // Keep full name
    }
    if (normalized.contains('queens park rangers') || normalized.contains('qpr')) {
      return 'qpr';  // Queens Park Rangers -> QPR
    }
    if (normalized.contains('west bromwich') || normalized.contains('west brom') || normalized.contains('wba')) {
      return 'west brom';  // West Bromwich Albion -> West Brom
    }

    // Other common teams
    if (normalized.contains('arsenal')) {
      return 'arsenal';
    }
    if (normalized.contains('chelsea')) {
      return 'chelsea';
    }
    if (normalized.contains('liverpool')) {
      return 'liverpool';
    }
    if (normalized.contains('everton')) {
      return 'everton';
    }
    if (normalized.contains('fulham')) {
      return 'fulham';
    }
    if (normalized.contains('brentford')) {
      return 'brentford';
    }
    if (normalized.contains('burnley')) {
      return 'burnley';
    }
    if (normalized.contains('watford')) {
      return 'watford';
    }
    if (normalized.contains('southampton')) {
      return 'southampton';
    }
    if (normalized.contains('aston villa') || normalized == 'villa') {
      return 'aston villa';
    }

    // International teams (for Champions League, etc.)
    if (normalized.contains('real madrid')) {
      return 'real madrid';
    }
    if (normalized.contains('barcelona') || normalized.contains('barca')) {
      return 'barcelona';
    }
    if (normalized.contains('bayern')) {
      return 'bayern';  // Bayern Munich -> Bayern
    }
    if (normalized.contains('juventus') || normalized.contains('juve')) {
      return 'juventus';
    }
    if (normalized.contains('paris saint-germain') || normalized.contains('psg')) {
      return 'psg';
    }
    if (normalized.contains('atletico madrid') || normalized == 'atletico') {
      return 'atletico madrid';
    }

    // Handle NBA team name variations
    // Thunder vs Oklahoma City Thunder
    if (normalized.contains('thunder') && !normalized.contains('oklahoma')) {
      debugPrint('   Normalizing: Thunder -> Oklahoma City Thunder');
      normalized = 'oklahoma city thunder';
    }
    if (normalized.contains('rockets') && !normalized.contains('houston')) {
      normalized = 'houston rockets';
    }
    if (normalized.contains('lakers') && !normalized.contains('los angeles')) {
      debugPrint('   Normalizing: Lakers -> Los Angeles Lakers');
      normalized = 'los angeles lakers';
    }
    if (normalized.contains('clippers') && !normalized.contains('los angeles')) {
      normalized = 'los angeles clippers';
    }
    if (normalized.contains('warriors') && !normalized.contains('golden state')) {
      debugPrint('   Normalizing: Warriors -> Golden State Warriors');
      normalized = 'golden state warriors';
    }
    if (normalized.contains('heat') && !normalized.contains('miami')) {
      normalized = 'miami heat';
    }
    if (normalized.contains('celtics') && !normalized.contains('boston')) {
      normalized = 'boston celtics';
    }
    if (normalized.contains('nets') && !normalized.contains('brooklyn')) {
      normalized = 'brooklyn nets';
    }
    if (normalized.contains('knicks') && !normalized.contains('new york')) {
      normalized = 'new york knicks';
    }
    if (normalized.contains('76ers') && !normalized.contains('philadelphia')) {
      normalized = 'philadelphia 76ers';
    }

    // For other teams, do standard normalization
    normalized = normalized
        .replaceAll(' and ', ' ')
        .replaceAll(' & ', ' ')
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '') // Remove special characters
        .replaceAll(RegExp(r'\s+'), ' ') // Normalize spaces
        .trim();

    return normalized;
  }

  /// Save ID mapping to Firestore
  Future<void> _saveMapping(String oddsApiId, String espnId, GameModel game) async {
    try {
      await _firestore.collection('id_mappings').doc(oddsApiId).set({
        'oddsApiId': oddsApiId,
        'espnId': espnId,
        'sport': game.sport,
        'homeTeam': game.homeTeam,
        'awayTeam': game.awayTeam,
        'gameTime': game.gameTime.toIso8601String(),
        'verified': true,
        'createdAt': FieldValue.serverTimestamp(),
      });
      debugPrint('💾 Saved ID mapping to Firestore');
    } catch (e) {
      debugPrint('Error saving ID mapping: $e');
    }
  }

  /// Update game document with ESPN ID
  Future<void> _updateGameWithEspnId(String gameId, String espnId) async {
    try {
      await _firestore.collection('games').doc(gameId).update({
        'espnId': espnId,
        'lastUpdated': FieldValue.serverTimestamp(),
      });
      debugPrint('📝 Updated game with ESPN ID');
    } catch (e) {
      debugPrint('Error updating game with ESPN ID: $e');
    }
  }

  /// Clear cache (for testing)
  void clearCache() {
    _memoryCache.clear();
    debugPrint('🗑️ Memory cache cleared');
  }

  /// Batch resolve ESPN IDs for multiple games
  Future<Map<String, String?>> batchResolveEspnIds(List<GameModel> games) async {
    final results = <String, String?>{};

    for (final game in games) {
      final espnId = await resolveEspnId(game);
      results[game.id] = espnId;
    }

    return results;
  }
}