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

      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sportPath/scoreboard';
      debugPrint('📡 Fetching ESPN scoreboard: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List? ?? [];

        debugPrint('🔍 Checking ${events.length} ESPN events for match...');

        for (final event in events) {
          if (_eventMatches(event, game)) {
            final espnId = event['id'].toString();
            debugPrint('✅ Found matching ESPN event: $espnId');
            return espnId;
          }
        }

        debugPrint('❌ No matching event found in ESPN data');
        debugPrint('   Looking for: ${game.awayTeam} @ ${game.homeTeam}');
      } else {
        debugPrint('❌ ESPN API returned status: ${response.statusCode}');
      }
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

      // Debug output for soccer
      if (game.sport.toUpperCase() == 'SOCCER') {
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

  /// Check if team names match (with normalization)
  bool _teamsMatch(String espnHome, String espnAway, String gameHome, String gameAway) {
    final normalizedEspnHome = _normalizeTeamName(espnHome);
    final normalizedEspnAway = _normalizeTeamName(espnAway);
    final normalizedGameHome = _normalizeTeamName(gameHome);
    final normalizedGameAway = _normalizeTeamName(gameAway);

    debugPrint('     ESPN normalized: [$normalizedEspnAway @ $normalizedEspnHome]');
    debugPrint('     Game normalized: [$normalizedGameAway @ $normalizedGameHome]');

    // Check both normal order and reversed (in case teams are swapped)
    final normalMatch = (normalizedEspnHome == normalizedGameHome && normalizedEspnAway == normalizedGameAway);
    final reversedMatch = (normalizedEspnHome == normalizedGameAway && normalizedEspnAway == normalizedGameHome);

    if (normalMatch) {
      debugPrint('     ✅ Teams match (normal order)');
    } else if (reversedMatch) {
      debugPrint('     ✅ Teams match (reversed order)');
    } else {
      debugPrint('     ❌ Teams do not match');
    }

    return normalMatch || reversedMatch;
  }

  /// Normalize team name for comparison
  String _normalizeTeamName(String team) {
    // First do basic normalization
    String normalized = team
        .toLowerCase()
        .trim();

    // Handle special cases for soccer teams that cause matching issues
    // Brighton & Hove Albion vs Brighton and Hove Albion
    if (normalized.contains('brighton')) {
      return 'brighton';  // Simplify to just "Brighton"
    }

    // Tottenham Hotspur vs Tottenham
    if (normalized.contains('tottenham')) {
      return 'tottenham';  // Simplify to just "Tottenham"
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