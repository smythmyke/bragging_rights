import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';

/// Service for caching games locally for instant loading
class GameCacheService {
  static const String _cacheKey = 'cached_games';
  static const String _cacheTimestampKey = 'games_cache_timestamp';
  static const Duration _cacheValidDuration = Duration(minutes: 5);

  // Live score caching (2-minute TTL)
  static const String _liveScoreCachePrefix = 'live_score_';
  static const String _liveScoreTimestampPrefix = 'live_score_timestamp_';
  static const Duration _liveScoreCacheDuration = Duration(minutes: 2);
  
  // Singleton instance
  static final GameCacheService _instance = GameCacheService._internal();
  factory GameCacheService() => _instance;
  GameCacheService._internal();
  
  SharedPreferences? _prefs;
  List<GameModel>? _memoryCache;
  DateTime? _memoryCacheTime;
  
  /// Initialize the service
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
  }
  
  /// Save games to cache
  Future<void> cacheGames(List<GameModel> games) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      // Update memory cache
      _memoryCache = games;
      _memoryCacheTime = DateTime.now();
      
      // Convert games to JSON
      final gamesJson = games.map((game) => game.toMap()).toList();
      final jsonString = json.encode(gamesJson);
      
      // Save to SharedPreferences
      await _prefs!.setString(_cacheKey, jsonString);
      await _prefs!.setInt(_cacheTimestampKey, DateTime.now().millisecondsSinceEpoch);
      
      debugPrint('📦 Cached ${games.length} games to local storage');
    } catch (e) {
      debugPrint('Error caching games: $e');
    }
  }
  
  /// Get cached games
  Future<List<GameModel>?> getCachedGames() async {
    try {
      // Check memory cache first (fastest)
      if (_memoryCache != null && _memoryCacheTime != null) {
        final age = DateTime.now().difference(_memoryCacheTime!);
        if (age < const Duration(seconds: 30)) {
          debugPrint('⚡ Returning ${_memoryCache!.length} games from memory cache');
          return _memoryCache;
        }
      }
      
      _prefs ??= await SharedPreferences.getInstance();
      
      final jsonString = _prefs!.getString(_cacheKey);
      if (jsonString == null) {
        debugPrint('📦 No cached games found');
        return null;
      }
      
      // Check cache age
      final timestamp = _prefs!.getInt(_cacheTimestampKey) ?? 0;
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheTime);
      
      // Parse cached games
      final gamesJson = json.decode(jsonString) as List;
      final games = gamesJson.map((json) => GameModel.fromMap(json)).toList();
      
      // Update memory cache
      _memoryCache = games;
      _memoryCacheTime = DateTime.now();
      
      debugPrint('📦 Loaded ${games.length} games from cache (age: ${age.inMinutes} minutes)');
      
      return games;
    } catch (e) {
      debugPrint('Error loading cached games: $e');
      return null;
    }
  }
  
  /// Check if cache is valid
  Future<bool> isCacheValid() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      final timestamp = _prefs!.getInt(_cacheTimestampKey);
      if (timestamp == null) return false;
      
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheTime);
      
      return age < _cacheValidDuration;
    } catch (e) {
      return false;
    }
  }
  
  /// Clear cache
  Future<void> clearCache() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();
      
      await _prefs!.remove(_cacheKey);
      await _prefs!.remove(_cacheTimestampKey);
      _memoryCache = null;
      _memoryCacheTime = null;
      
      debugPrint('📦 Cache cleared');
    } catch (e) {
      debugPrint('Error clearing cache: $e');
    }
  }
  
  /// Get cache age
  Future<Duration?> getCacheAge() async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      final timestamp = _prefs!.getInt(_cacheTimestampKey);
      if (timestamp == null) return null;

      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      return DateTime.now().difference(cacheTime);
    } catch (e) {
      return null;
    }
  }

  /// Cache live score for a specific game (2-minute TTL)
  Future<void> cacheLiveScore(String gameId, Map<String, dynamic> scoreData) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      final cacheKey = '$_liveScoreCachePrefix$gameId';
      final timestampKey = '$_liveScoreTimestampPrefix$gameId';

      await _prefs!.setString(cacheKey, json.encode(scoreData));
      await _prefs!.setInt(timestampKey, DateTime.now().millisecondsSinceEpoch);

      debugPrint('⚡ Cached live score for game $gameId');
    } catch (e) {
      debugPrint('Error caching live score: $e');
    }
  }

  /// Get cached live score if not stale (< 2 minutes old)
  Future<Map<String, dynamic>?> getCachedLiveScore(String gameId) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      final cacheKey = '$_liveScoreCachePrefix$gameId';
      final timestampKey = '$_liveScoreTimestampPrefix$gameId';

      final scoreJson = _prefs!.getString(cacheKey);
      final timestamp = _prefs!.getInt(timestampKey);

      if (scoreJson == null || timestamp == null) {
        debugPrint('⚡ No cached live score for game $gameId');
        return null;
      }

      // Check if cache is stale
      final cacheTime = DateTime.fromMillisecondsSinceEpoch(timestamp);
      final age = DateTime.now().difference(cacheTime);

      if (age > _liveScoreCacheDuration) {
        debugPrint('⚡ Live score cache stale for game $gameId (age: ${age.inSeconds}s)');
        return null;
      }

      debugPrint('⚡ Returning cached live score for game $gameId (age: ${age.inSeconds}s)');
      return json.decode(scoreJson) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Error getting cached live score: $e');
      return null;
    }
  }

  /// Clear live score cache for a specific game
  Future<void> clearLiveScoreCache(String gameId) async {
    try {
      _prefs ??= await SharedPreferences.getInstance();

      final cacheKey = '$_liveScoreCachePrefix$gameId';
      final timestampKey = '$_liveScoreTimestampPrefix$gameId';

      await _prefs!.remove(cacheKey);
      await _prefs!.remove(timestampKey);

      debugPrint('⚡ Cleared live score cache for game $gameId');
    } catch (e) {
      debugPrint('Error clearing live score cache: $e');
    }
  }
}