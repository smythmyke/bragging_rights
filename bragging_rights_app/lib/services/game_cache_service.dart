import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import '../models/game_model.dart';

/// Service for caching games locally for instant loading
class GameCacheService {
  static const String _cacheKey = 'cached_games';
  static const String _cacheTimestampKey = 'games_cache_timestamp';
  static const Duration _cacheValidDuration = Duration(minutes: 5);
  
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
}