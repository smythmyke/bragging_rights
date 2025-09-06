import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../sports/espn_nfl_service.dart';
import '../sports/espn_nba_service.dart';  // EspnScoreboard class
import '../sports/espn_nhl_service.dart';
import '../sports/espn_mlb_service.dart';

/// Edge Cache Service - Multi-User Data Sharing
/// Implements smart caching with sport-specific TTLs
class EdgeCacheService {
  static final EdgeCacheService _instance = EdgeCacheService._internal();
  factory EdgeCacheService() => _instance;
  EdgeCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Local memory cache for ultra-fast access
  final Map<String, CachedData> _memoryCache = {};

  /// Basketball-specific cache TTLs (in seconds)
  static const Map<String, Map<String, int>> basketballTTL = {
    'preGame': {
      'lineups': 300,        // 5 min
      'injuries': 600,       // 10 min
      'news': 900,           // 15 min
      'odds': 120,           // 2 min
      'social': 300,         // 5 min
    },
    'firstHalf': {
      'scores': 30,          // 30 seconds
      'stats': 60,           // 1 min
      'playByPlay': 30,      // 30 seconds
      'news': 600,           // 10 min
      'social': 120,         // 2 min
    },
    'halftime': {
      'scores': 300,         // 5 min
      'stats': 180,          // 3 min
      'news': 300,           // 5 min
      'social': 60,          // 1 min
    },
    'secondHalf': {
      'scores': 30,          // 30 seconds
      'stats': 60,           // 1 min
      'playByPlay': 30,      // 30 seconds
      'news': 600,           // 10 min
      'social': 120,         // 2 min
    },
    'clutchTime': {
      'scores': 15,          // 15 seconds - critical!
      'stats': 30,           // 30 seconds
      'playByPlay': 15,      // 15 seconds
      'odds': 30,            // 30 seconds
      'social': 30,          // 30 seconds
    },
    'blowout': {
      'scores': 120,         // 2 min - less interest
      'stats': 300,          // 5 min
      'playByPlay': 180,     // 3 min
      'news': 600,           // 10 min
      'social': 300,         // 5 min
    },
    'postGame': {
      'finalStats': 3600,    // 1 hour
      'news': 300,           // 5 min
      'social': 180,         // 3 min
      'recap': 7200,         // 2 hours
    },
  };

  /// Get cached data or fetch if expired
  Future<T?> getCachedData<T>({
    required String collection,
    required String documentId,
    required String dataType,
    required Future<T> Function() fetchFunction,
    required String sport,
    Map<String, dynamic>? gameState,
  }) async {
    final cacheKey = '$collection/$documentId/$dataType';
    debugPrint('🔍 Cache check: $cacheKey');

    // 1. Check memory cache first (fastest)
    final memoryCached = _getFromMemoryCache(cacheKey);
    if (memoryCached != null && memoryCached.data is T) {
      debugPrint('✅ Memory cache hit: $cacheKey');
      return memoryCached.data as T;
    }

    // 2. Check Firestore cache (shared across users)
    final firestoreCached = await _getFromFirestoreCache(
      collection: collection,
      documentId: documentId,
      dataType: dataType,
      sport: sport,
      gameState: gameState,
    );
    
    if (firestoreCached != null && firestoreCached['data'] != null) {
      debugPrint('✅ Firestore cache hit: $cacheKey');
      
      // Reconstruct the typed object if needed
      dynamic reconstructedData = firestoreCached['data'];
      
      // Check if we need to reconstruct an ESPN model
      if (T == EspnNflScoreboard) {
        try {
          reconstructedData = EspnNflScoreboard.fromJson(firestoreCached['data'] as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Warning: Could not reconstruct EspnNflScoreboard: $e');
        }
      } else if (T == EspnScoreboard) {
        try {
          reconstructedData = EspnScoreboard.fromJson(firestoreCached['data'] as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Warning: Could not reconstruct EspnScoreboard: $e');
        }
      } else if (T == EspnNhlScoreboard) {
        try {
          reconstructedData = EspnNhlScoreboard.fromJson(firestoreCached['data'] as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Warning: Could not reconstruct EspnNhlScoreboard: $e');
        }
      } else if (T == EspnMlbScoreboard) {
        try {
          reconstructedData = EspnMlbScoreboard.fromJson(firestoreCached['data'] as Map<String, dynamic>);
        } catch (e) {
          debugPrint('Warning: Could not reconstruct EspnMlbScoreboard: $e');
        }
      }
      
      // Update memory cache
      _memoryCache[cacheKey] = CachedData(
        data: reconstructedData,
        timestamp: (firestoreCached['timestamp'] as Timestamp).toDate(),
        ttl: firestoreCached['ttl'] ?? 300,
      );
      
      return reconstructedData as T;
    }

    // 3. Cache miss - fetch fresh data
    debugPrint('❌ Cache miss: $cacheKey - Fetching fresh data...');
    
    try {
      final freshData = await fetchFunction();
      
      if (freshData != null) {
        // Calculate appropriate TTL
        final ttl = _calculateTTL(
          sport: sport,
          dataType: dataType,
          gameState: gameState,
        );
        
        // Save to both caches
        await _saveToCache(
          collection: collection,
          documentId: documentId,
          dataType: dataType,
          data: freshData,
          ttl: ttl,
        );
        
        debugPrint('💾 Cached new data: $cacheKey (TTL: ${ttl}s)');
        return freshData;
      }
    } catch (e) {
      debugPrint('❌ Error fetching data: $e');
      
      // Try to return stale cache if available
      final staleCached = await _getFromFirestoreCache(
        collection: collection,
        documentId: documentId,
        dataType: dataType,
        sport: sport,
        gameState: gameState,
        allowStale: true,
      );
      
      if (staleCached != null) {
        debugPrint('📦 Returning stale cache due to error');
        return staleCached['data'] as T?;
      }
    }
    
    return null;
  }

  /// Get from memory cache
  CachedData? _getFromMemoryCache(String key) {
    final cached = _memoryCache[key];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp).inSeconds;
      if (age < cached.ttl) {
        return cached;
      } else {
        _memoryCache.remove(key);
      }
    }
    return null;
  }

  /// Get from Firestore cache
  Future<Map<String, dynamic>?> _getFromFirestoreCache({
    required String collection,
    required String documentId,
    required String dataType,
    required String sport,
    Map<String, dynamic>? gameState,
    bool allowStale = false,
  }) async {
    try {
      final docRef = _firestore
          .collection('edge_cache')
          .doc(collection)
          .collection(documentId)
          .doc(dataType);
      
      final doc = await docRef.get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final timestamp = data['timestamp'] as Timestamp;
        final ttl = data['ttl'] ?? 300;
        
        final age = DateTime.now().difference(timestamp.toDate()).inSeconds;
        
        if (age < ttl || allowStale) {
          return data;
        } else {
          debugPrint('⏰ Cache expired: age=${age}s, ttl=${ttl}s');
        }
      }
    } catch (e) {
      debugPrint('Error reading Firestore cache: $e');
    }
    
    return null;
  }

  /// Save data to both caches
  Future<void> _saveToCache({
    required String collection,
    required String documentId,
    required String dataType,
    required dynamic data,
    required int ttl,
  }) async {
    final timestamp = DateTime.now();
    final cacheKey = '$collection/$documentId/$dataType';
    
    // 1. Save to memory cache
    _memoryCache[cacheKey] = CachedData(
      data: data,
      timestamp: timestamp,
      ttl: ttl,
    );
    
    // 2. Save to Firestore (for all users)
    try {
      // Convert data to JSON-serializable format if needed
      dynamic serializableData = data;
      if (data != null) {
        // Check if the data has a toJson method
        try {
          if (data.runtimeType.toString().contains('Espn')) {
            // It's an ESPN model class, convert to JSON
            serializableData = data.toJson();
          }
        } catch (_) {
          // If toJson doesn't exist, use the data as-is
        }
      }
      
      await _firestore
          .collection('edge_cache')
          .doc(collection)
          .collection(documentId)
          .doc(dataType)
          .set({
        'data': serializableData,
        'timestamp': Timestamp.fromDate(timestamp),
        'ttl': ttl,
        'expiresAt': Timestamp.fromDate(
          timestamp.add(Duration(seconds: ttl)),
        ),
      });
    } catch (e) {
      debugPrint('Error saving to Firestore cache: $e');
      // Don't fail the whole operation if caching fails
    }
  }

  /// Calculate appropriate TTL based on sport and game state
  int _calculateTTL({
    required String sport,
    required String dataType,
    Map<String, dynamic>? gameState,
  }) {
    if (sport.toLowerCase() == 'nba' || sport.toLowerCase() == 'basketball') {
      return _calculateBasketballTTL(dataType, gameState);
    }
    
    // Default TTLs for other sports
    switch (sport.toLowerCase()) {
      case 'nfl':
      case 'football':
        return _getFootballTTL(dataType);
      case 'mlb':
      case 'baseball':
        return _getBaseballTTL(dataType);
      case 'nhl':
      case 'hockey':
        return _getHockeyTTL(dataType);
      case 'soccer':
        return _getSoccerTTL(dataType);
      default:
        return 300; // 5 min default
    }
  }

  /// Calculate basketball-specific TTL
  int _calculateBasketballTTL(String dataType, Map<String, dynamic>? gameState) {
    if (gameState == null) {
      // No game state, use conservative defaults
      return basketballTTL['preGame']?[dataType] ?? 300;
    }

    final gamePhase = _detectBasketballPhase(gameState);
    final phaseTTLs = basketballTTL[gamePhase] ?? basketballTTL['preGame']!;
    
    return phaseTTLs[dataType] ?? 300;
  }

  /// Detect basketball game phase
  String _detectBasketballPhase(Map<String, dynamic> gameState) {
    final status = gameState['status']?.toString().toLowerCase() ?? '';
    final period = gameState['period'] ?? 0;
    final timeRemaining = gameState['timeRemaining'] ?? 0;
    final homeScore = gameState['homeScore'] ?? 0;
    final awayScore = gameState['awayScore'] ?? 0;
    final scoreDiff = (homeScore - awayScore).abs();

    // Check game status
    if (status.contains('final') || status.contains('end')) {
      return 'postGame';
    }
    
    if (status.contains('halftime')) {
      return 'halftime';
    }
    
    if (status.contains('pregame') || status.contains('scheduled')) {
      return 'preGame';
    }

    // Game is live - check for special situations
    
    // Clutch time: 4th quarter, last 5 minutes, close game
    if (period >= 4 && timeRemaining < 300 && scoreDiff <= 10) {
      debugPrint('🔥 Clutch time detected! Using 15s cache');
      return 'clutchTime';
    }
    
    // Blowout: 20+ point difference
    if (scoreDiff > 20) {
      debugPrint('😴 Blowout detected. Using longer cache times');
      return 'blowout';
    }
    
    // Regular game phases
    if (period <= 2) {
      return 'firstHalf';
    } else {
      return 'secondHalf';
    }
  }

  /// Get football TTL
  int _getFootballTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 120;  // 2 min
      case 'stats':
        return 180;  // 3 min
      case 'news':
        return 600;  // 10 min
      default:
        return 300;  // 5 min
    }
  }

  /// Get baseball TTL
  int _getBaseballTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 180;  // 3 min
      case 'stats':
        return 300;  // 5 min
      case 'news':
        return 900;  // 15 min
      default:
        return 300;  // 5 min
    }
  }

  /// Get hockey TTL
  int _getHockeyTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 180;  // 3 min
      case 'stats':
        return 240;  // 4 min
      case 'news':
        return 600;  // 10 min
      default:
        return 300;  // 5 min
    }
  }

  /// Get soccer TTL
  int _getSoccerTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 300;  // 5 min (goals are rare)
      case 'stats':
        return 600;  // 10 min
      case 'news':
        return 900;  // 15 min
      default:
        return 600;  // 10 min
    }
  }

  /// Clear all caches
  Future<void> clearAllCaches() async {
    _memoryCache.clear();
    
    // Note: Be careful with this in production
    // You might want to clear only expired entries instead
    debugPrint('🧹 Cleared all caches');
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    int totalItems = _memoryCache.length;
    int expiredItems = 0;
    int activeItems = 0;
    
    _memoryCache.forEach((key, cached) {
      final age = DateTime.now().difference(cached.timestamp).inSeconds;
      if (age > cached.ttl) {
        expiredItems++;
      } else {
        activeItems++;
      }
    });
    
    return {
      'totalItems': totalItems,
      'activeItems': activeItems,
      'expiredItems': expiredItems,
      'hitRate': _calculateHitRate(),
    };
  }

  // Cache hit tracking
  int _cacheHits = 0;
  int _cacheMisses = 0;
  
  double _calculateHitRate() {
    final total = _cacheHits + _cacheMisses;
    if (total == 0) return 0.0;
    return (_cacheHits / total) * 100;
  }

  /// Warm cache for upcoming games
  Future<void> warmCacheForGame({
    required String gameId,
    required String sport,
    required DateTime gameTime,
  }) async {
    final now = DateTime.now();
    final timeUntilGame = gameTime.difference(now);
    
    if (timeUntilGame.inHours <= 2) {
      debugPrint('🔥 Warming cache for game $gameId...');
      
      // Pre-fetch essential data
      // This would trigger the actual API calls
      // Implementation depends on your API services
    }
  }
}

/// Cached data model
class CachedData {
  final dynamic data;
  final DateTime timestamp;
  final int ttl;

  CachedData({
    required this.data,
    required this.timestamp,
    required this.ttl,
  });

  bool get isExpired {
    final age = DateTime.now().difference(timestamp).inSeconds;
    return age > ttl;
  }
}