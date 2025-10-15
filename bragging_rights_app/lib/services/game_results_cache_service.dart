import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

/// Service for caching ESPN game results to avoid API quota exhaustion
/// CRITICAL: With thousands of users, we need to fetch ESPN data once per game
/// and cache it for all users to share
class GameResultsCacheService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const CACHE_DURATION = Duration(hours: 24);

  // Singleton
  static final GameResultsCacheService _instance = GameResultsCacheService._internal();
  factory GameResultsCacheService() => _instance;
  GameResultsCacheService._internal();

  /// Get game result (from cache or ESPN)
  /// Returns cached data if available, otherwise fetches from ESPN and caches
  Future<Map<String, dynamic>?> getGameResult({
    required String gameId,
    required String sport,
    bool fetchIfMissing = true,
  }) async {
    try {
      // 1. Check cache first
      final cached = await _getCachedResult(gameId);
      if (cached != null) {
        debugPrint('[GameCache] Cache HIT for $gameId');
        return cached;
      }

      debugPrint('[GameCache] Cache MISS for $gameId');

      // 2. If not cached and fetch allowed, get from ESPN
      if (fetchIfMissing) {
        debugPrint('[GameCache] Fetching from ESPN for $gameId');
        final espnData = await _fetchFromEspn(gameId, sport);

        if (espnData != null) {
          // 3. Cache the result
          await _cacheResult(gameId, sport, espnData);
          return espnData;
        }
      }

      return null;
    } catch (e) {
      debugPrint('[GameCache] Error getting game result: $e');
      return null;
    }
  }

  /// Check if game result is cached
  Future<bool> isCached(String gameId) async {
    try {
      final doc = await _firestore
          .collection('game_results')
          .doc(gameId)
          .get();

      if (!doc.exists) return false;

      final data = doc.data();
      if (data == null) return false;

      // Check if cache is expired
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        debugPrint('[GameCache] Cache expired for $gameId');
        return false;
      }

      return true;
    } catch (e) {
      debugPrint('[GameCache] Error checking cache: $e');
      return false;
    }
  }

  /// Get cached result from Firestore
  Future<Map<String, dynamic>?> _getCachedResult(String gameId) async {
    try {
      final doc = await _firestore
          .collection('game_results')
          .doc(gameId)
          .get();

      if (!doc.exists) return null;

      final data = doc.data();
      if (data == null) return null;

      // Check if cache is expired
      final expiresAt = (data['expiresAt'] as Timestamp).toDate();
      if (DateTime.now().isAfter(expiresAt)) {
        debugPrint('[GameCache] Cache expired for $gameId, deleting');
        await _firestore.collection('game_results').doc(gameId).delete();
        return null;
      }

      return data['espnData'] as Map<String, dynamic>?;
    } catch (e) {
      debugPrint('[GameCache] Error reading cache: $e');
      return null;
    }
  }

  /// Fetch game result from ESPN API
  Future<Map<String, dynamic>?> _fetchFromEspn(String gameId, String sport) async {
    try {
      // Construct ESPN API URL based on sport
      final sportPath = _getSportPath(sport);
      final url = 'https://site.api.espn.com/apis/site/v2/sports/$sportPath/scoreboard';

      debugPrint('[GameCache] Fetching ESPN: $url');

      final response = await http.get(Uri.parse(url));

      if (response.statusCode != 200) {
        debugPrint('[GameCache] ESPN API error: ${response.statusCode}');
        return null;
      }

      final data = json.decode(response.body);
      final events = data['events'] as List? ?? [];

      // Find the specific game by ID
      for (final event in events) {
        if (event['id'] == gameId) {
          debugPrint('[GameCache] Found game $gameId in ESPN response');
          return {
            'event': event,
            'competition': event['competitions']?[0],
          };
        }
      }

      debugPrint('[GameCache] Game $gameId not found in ESPN response');
      return null;
    } catch (e) {
      debugPrint('[GameCache] Error fetching from ESPN: $e');
      return null;
    }
  }

  /// Cache game result in Firestore
  Future<void> _cacheResult(
    String gameId,
    String sport,
    Map<String, dynamic> espnData,
  ) async {
    try {
      final now = DateTime.now();
      final expiresAt = now.add(CACHE_DURATION);

      // Extract key data for quick access
      final competition = espnData['competition'];
      final competitors = competition?['competitors'] as List? ?? [];

      String? winner;
      int? homeScore;
      int? awayScore;

      if (competitors.length >= 2) {
        final home = competitors.firstWhere((c) => c['homeAway'] == 'home', orElse: () => {});
        final away = competitors.firstWhere((c) => c['homeAway'] == 'away', orElse: () => {});

        homeScore = int.tryParse(home['score']?.toString() ?? '0');
        awayScore = int.tryParse(away['score']?.toString() ?? '0');

        if (home['winner'] == true) {
          winner = 'home';
        } else if (away['winner'] == true) {
          winner = 'away';
        } else {
          winner = 'draw';
        }
      }

      await _firestore.collection('game_results').doc(gameId).set({
        'gameId': gameId,
        'sport': sport.toUpperCase(),
        'cachedAt': Timestamp.fromDate(now),
        'expiresAt': Timestamp.fromDate(expiresAt),
        'status': competition?['status']?['type']?['description'] ?? 'unknown',
        'espnData': espnData,
        'homeScore': homeScore,
        'awayScore': awayScore,
        'winner': winner,
        'lastUpdated': FieldValue.serverTimestamp(),
      });

      debugPrint('[GameCache] Cached result for $gameId (expires: $expiresAt)');
    } catch (e) {
      debugPrint('[GameCache] Error caching result: $e');
    }
  }

  /// Invalidate cache for a specific game
  Future<void> invalidateCache(String gameId) async {
    try {
      await _firestore.collection('game_results').doc(gameId).delete();
      debugPrint('[GameCache] Invalidated cache for $gameId');
    } catch (e) {
      debugPrint('[GameCache] Error invalidating cache: $e');
    }
  }

  /// Clear all expired caches (maintenance function)
  Future<void> clearExpiredCaches() async {
    try {
      final now = Timestamp.fromDate(DateTime.now());
      final expired = await _firestore
          .collection('game_results')
          .where('expiresAt', isLessThan: now)
          .get();

      for (final doc in expired.docs) {
        await doc.reference.delete();
      }

      debugPrint('[GameCache] Cleared ${expired.docs.length} expired caches');
    } catch (e) {
      debugPrint('[GameCache] Error clearing expired caches: $e');
    }
  }

  /// Get sport path for ESPN API
  String _getSportPath(String sport) {
    switch (sport.toUpperCase()) {
      case 'NBA':
        return 'basketball/nba';
      case 'NFL':
        return 'football/nfl';
      case 'NHL':
        return 'hockey/nhl';
      case 'MLB':
        return 'baseball/mlb';
      case 'SOCCER':
        return 'soccer/all';
      case 'TENNIS':
        return 'tennis/atp';
      case 'MMA':
      case 'UFC':
        return 'mma/ufc';
      case 'BOXING':
        return 'boxing/boxing';
      default:
        return sport.toLowerCase();
    }
  }
}
