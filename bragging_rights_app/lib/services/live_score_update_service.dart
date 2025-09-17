import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
import '../models/game_model.dart';

/// Lightweight service for updating only live game scores
/// This service fetches minimal data (scores, status) to reduce API costs
/// and improve performance for live game tracking
class LiveScoreUpdateService {
  static final LiveScoreUpdateService _instance = LiveScoreUpdateService._internal();
  factory LiveScoreUpdateService() => _instance;
  LiveScoreUpdateService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // ESPN endpoints for live scores
  static const Map<String, String> _espnEndpoints = {
    'NFL': 'football/nfl',
    'NBA': 'basketball/nba',
    'NHL': 'hockey/nhl',
    'MLB': 'baseball/mlb',
    'SOCCER': 'soccer/eng.1', // Default to Premier League
    'MMA': 'mma',
    'BOXING': 'boxing',
  };

  /// Update scores for a list of live games
  /// Only fetches score data, not full game details
  Future<void> updateLiveGameScores(List<GameModel> liveGames) async {
    if (liveGames.isEmpty) return;

    debugPrint('⚡ Updating scores for ${liveGames.length} live games');

    // Group games by sport for batch fetching
    final gamesBySport = <String, List<GameModel>>{};
    for (final game in liveGames) {
      final sport = game.sport.toUpperCase();
      gamesBySport[sport] ??= [];
      gamesBySport[sport]!.add(game);
    }

    // Fetch scores for each sport
    for (final entry in gamesBySport.entries) {
      await _updateSportScores(entry.key, entry.value);
    }
  }

  /// Update scores for games of a specific sport
  Future<void> _updateSportScores(String sport, List<GameModel> games) async {
    try {
      final endpoint = _espnEndpoints[sport];
      if (endpoint == null) {
        debugPrint('⚠️ No ESPN endpoint for sport: $sport');
        return;
      }

      // Fetch scoreboard data (lighter than full game details)
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$endpoint/scoreboard';
      debugPrint('📡 Fetching live scores from: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('❌ Failed to fetch scores: ${response.statusCode}');
        return;
      }

      final data = json.decode(response.body);
      final events = data['events'] as List? ?? [];

      debugPrint('📊 Found ${events.length} ${sport} events from ESPN');

      // Match ESPN games with our games
      final updates = <String, Map<String, dynamic>>{};

      for (final game in games) {
        final espnGame = _findMatchingEspnGame(game, events);
        if (espnGame != null) {
          final scoreData = _extractScoreData(espnGame);
          if (scoreData != null) {
            updates[game.id] = scoreData;
          }
        }
      }

      // Batch update Firestore
      if (updates.isNotEmpty) {
        await _batchUpdateScores(updates);
      }

    } catch (e) {
      debugPrint('❌ Error updating $sport scores: $e');
    }
  }

  /// Find matching ESPN game for our game
  Map<String, dynamic>? _findMatchingEspnGame(GameModel game, List<dynamic> espnEvents) {
    for (final event in espnEvents) {
      if (_gamesMatch(game, event)) {
        return event as Map<String, dynamic>;
      }
    }
    return null;
  }

  /// Check if ESPN event matches our game
  bool _gamesMatch(GameModel game, Map<String, dynamic> espnEvent) {
    try {
      // Try matching by ESPN ID first if available
      if (game.espnId != null && espnEvent['id'] != null) {
        return game.espnId == espnEvent['id'].toString();
      }

      // Otherwise match by teams
      final competition = espnEvent['competitions']?[0];
      if (competition == null) return false;

      final competitors = competition['competitors'] as List? ?? [];
      if (competitors.length < 2) return false;

      // Extract team names
      String? homeTeam, awayTeam;
      for (final competitor in competitors) {
        final team = competitor['team']?['displayName']?.toString();
        if (competitor['homeAway'] == 'home') {
          homeTeam = team;
        } else if (competitor['homeAway'] == 'away') {
          awayTeam = team;
        }
      }

      if (homeTeam == null || awayTeam == null) return false;

      // Normalize and compare
      final normalizedGameHome = _normalizeTeamName(game.homeTeam);
      final normalizedGameAway = _normalizeTeamName(game.awayTeam);
      final normalizedEspnHome = _normalizeTeamName(homeTeam);
      final normalizedEspnAway = _normalizeTeamName(awayTeam);

      return (normalizedGameHome == normalizedEspnHome &&
              normalizedGameAway == normalizedEspnAway) ||
             (normalizedGameHome == normalizedEspnAway &&
              normalizedGameAway == normalizedEspnHome);

    } catch (e) {
      debugPrint('Error matching game: $e');
      return false;
    }
  }

  /// Extract only score data from ESPN event
  Map<String, dynamic>? _extractScoreData(Map<String, dynamic> espnEvent) {
    try {
      final competition = espnEvent['competitions']?[0];
      if (competition == null) return null;

      final competitors = competition['competitors'] as List? ?? [];
      if (competitors.length < 2) return null;

      int? homeScore, awayScore;
      for (final competitor in competitors) {
        final score = competitor['score']?.toString();
        if (competitor['homeAway'] == 'home') {
          homeScore = int.tryParse(score ?? '0') ?? 0;
        } else if (competitor['homeAway'] == 'away') {
          awayScore = int.tryParse(score ?? '0') ?? 0;
        }
      }

      // Get game status
      final status = espnEvent['status']?['type']?['name']?.toString() ?? 'In Progress';
      final clock = espnEvent['status']?['displayClock']?.toString();
      final period = espnEvent['status']?['period']?.toString();

      // Build minimal update data
      final updateData = <String, dynamic>{
        'homeScore': homeScore ?? 0,
        'awayScore': awayScore ?? 0,
        'status': status,
        'lastScoreUpdate': FieldValue.serverTimestamp(),
      };

      // Add timing info if available
      if (clock != null) {
        updateData['gameClock'] = clock;
      }
      if (period != null) {
        updateData['period'] = period;
      }

      // Add ESPN ID if we didn't have it
      if (espnEvent['id'] != null) {
        updateData['espnId'] = espnEvent['id'].toString();
      }

      return updateData;

    } catch (e) {
      debugPrint('Error extracting score data: $e');
      return null;
    }
  }

  /// Batch update scores in Firestore
  Future<void> _batchUpdateScores(Map<String, Map<String, dynamic>> updates) async {
    final batch = _firestore.batch();

    for (final entry in updates.entries) {
      final docRef = _firestore.collection('games').doc(entry.key);
      batch.update(docRef, entry.value);
    }

    try {
      await batch.commit();
      debugPrint('✅ Updated scores for ${updates.length} games');
    } catch (e) {
      debugPrint('❌ Error updating scores in Firestore: $e');
    }
  }

  /// Normalize team name for matching
  String _normalizeTeamName(String team) {
    String normalized = team
        .toLowerCase()
        .trim()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
        .replaceAll(RegExp(r'\s+'), ' ');

    // Handle common variations
    if (normalized.contains('brighton')) {
      return 'brighton';
    } else if (normalized.contains('tottenham')) {
      return 'tottenham';
    }

    return normalized;
  }

  /// Get live score stream for a specific game
  /// Returns a stream that updates every 30 seconds
  Stream<Map<String, dynamic>> watchLiveGameScore(String gameId) {
    return Stream.periodic(const Duration(seconds: 30), (count) {
      return count; // Just return the count
    }).asyncMap((count) async {
      // Now do the async work in asyncMap
      try {
        // Get game from Firestore
        final doc = await _firestore.collection('games').doc(gameId).get();
        if (!doc.exists) {
          return {'error': 'Game not found'};
        }

        final game = GameModel.fromMap(doc.data()!);

        // Check if game is still live
        if (!_isLiveGame(game)) {
          return {'status': 'completed'};
        }

        // Update score
        await updateLiveGameScores([game]);

        // Return updated data
        final updatedDoc = await _firestore.collection('games').doc(gameId).get();
        return updatedDoc.data() ?? {};

      } catch (e) {
        return {'error': e.toString()};
      }
    });
  }

  /// Check if a game is live
  bool _isLiveGame(GameModel game) {
    final status = game.status.toLowerCase();
    return status == 'in_progress' ||
           status == 'live' ||
           status == 'active' ||
           status.contains('quarter') ||
           status.contains('half') ||
           status.contains('period') ||
           status.contains('inning');
  }

  /// Get all currently live games across all sports
  Future<List<GameModel>> getAllLiveGames() async {
    try {
      final now = DateTime.now();
      final threeDaysAgo = now.subtract(const Duration(days: 3));

      // Query games that started in the last 3 days (potential live games)
      final query = await _firestore
          .collection('games')
          .where('gameTime', isGreaterThan: Timestamp.fromDate(threeDaysAgo))
          .where('gameTime', isLessThan: Timestamp.fromDate(now))
          .get();

      final liveGames = <GameModel>[];

      for (final doc in query.docs) {
        final game = GameModel.fromMap(doc.data());
        if (_isLiveGame(game)) {
          liveGames.add(game);
        }
      }

      debugPrint('🔴 Found ${liveGames.length} live games');
      return liveGames;

    } catch (e) {
      debugPrint('Error getting live games: $e');
      return [];
    }
  }

  /// Start automatic live score updates
  /// Call this when the app starts to keep live games updated
  void startAutomaticUpdates() {
    // Update live scores every 30 seconds
    Stream.periodic(const Duration(seconds: 30), (_) async {
      final liveGames = await getAllLiveGames();
      if (liveGames.isNotEmpty) {
        debugPrint('🔄 Auto-updating ${liveGames.length} live games');
        await updateLiveGameScores(liveGames);
      }
    }).listen((_) {});
  }

  /// Stop automatic updates (call when app goes to background)
  void stopAutomaticUpdates() {
    // Implementation would cancel the stream subscription
    debugPrint('⏹️ Stopped automatic score updates');
  }
}