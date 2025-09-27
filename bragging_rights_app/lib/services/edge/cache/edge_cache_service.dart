import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../sports/espn_nfl_service.dart';
import '../sports/espn_nba_service.dart';  // EspnScoreboard class
import '../sports/espn_nhl_service.dart';
import '../sports/espn_mlb_service.dart';
import '../../api_call_tracker.dart';

/// Edge Cache Service - Multi-User Data Sharing
/// Implements smart caching with sport-specific TTLs
class EdgeCacheService {
  static final EdgeCacheService _instance = EdgeCacheService._internal();
  factory EdgeCacheService() => _instance;
  EdgeCacheService._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // Local memory cache for ultra-fast access
  final Map<String, CachedData> _memoryCache = {};

  /// Basketball-specific cache TTLs (in seconds) - Optimized for Firestore sharing
  static const Map<String, Map<String, int>> basketballTTL = {
    'preGame': {
      'lineups': 1800,       // 30 min (was 5 min)
      'injuries': 3600,      // 1 hour (was 10 min)
      'news': 3600,          // 1 hour (was 15 min)
      'odds': 600,           // 10 min (was 2 min)
      'social': 1800,        // 30 min (was 5 min)
    },
    'firstHalf': {
      'scores': 120,         // 2 min (was 30 seconds)
      'stats': 300,          // 5 min (was 1 min)
      'playByPlay': 120,     // 2 min (was 30 seconds)
      'news': 3600,          // 1 hour (was 10 min)
      'social': 600,         // 10 min (was 2 min)
    },
    'halftime': {
      'scores': 900,         // 15 min (was 5 min)
      'stats': 600,          // 10 min (was 3 min)
      'news': 1800,          // 30 min (was 5 min)
      'social': 300,         // 5 min (was 1 min)
    },
    'secondHalf': {
      'scores': 120,         // 2 min (was 30 seconds)
      'stats': 300,          // 5 min (was 1 min)
      'playByPlay': 120,     // 2 min (was 30 seconds)
      'news': 3600,          // 1 hour (was 10 min)
      'social': 600,         // 10 min (was 2 min)
    },
    'clutchTime': {
      'scores': 60,          // 1 min (was 15 seconds) - still fast for critical moments
      'stats': 120,          // 2 min (was 30 seconds)
      'playByPlay': 60,      // 1 min (was 15 seconds)
      'odds': 120,           // 2 min (was 30 seconds)
      'social': 120,         // 2 min (was 30 seconds)
    },
    'blowout': {
      'scores': 600,         // 10 min (was 2 min) - less interest
      'stats': 1800,         // 30 min (was 5 min)
      'playByPlay': 900,     // 15 min (was 3 min)
      'news': 3600,          // 1 hour (was 10 min)
      'social': 1800,        // 30 min (was 5 min)
    },
    'postGame': {
      'finalStats': 86400,   // 24 hours (was 1 hour)
      'news': 1800,          // 30 min (was 5 min)
      'social': 900,         // 15 min (was 3 min)
      'recap': 86400,        // 24 hours (was 2 hours)
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
      APICallTracker.logAPICall('CACHE', 'Memory Hit', details: '$sport - $dataType', cached: true);
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
      APICallTracker.logAPICall('CACHE', 'Firestore Hit', details: '$sport - $dataType', cached: true);
      APICallTracker.logFirestoreRead('cache', docId: documentId);
      
      // Reconstruct the typed object if needed
      dynamic reconstructedData = firestoreCached['data'];
      
      // Type safety check - ensure data is correct type before attempting reconstruction
      if (reconstructedData is List) {
        // If it's already a list, check if we can cast it properly
        if (T == List) {
          // Update memory cache
          _memoryCache[cacheKey] = CachedData(
            data: reconstructedData,
            timestamp: (firestoreCached['timestamp'] as Timestamp).toDate(),
            ttl: firestoreCached['ttl'] ?? 300,
          );
          return reconstructedData as T;
        }
      }
      
      // Check if we need to reconstruct an ESPN model from Map data
      if (reconstructedData is Map<String, dynamic>) {
        if (T == EspnNflScoreboard) {
          try {
            reconstructedData = EspnNflScoreboard.fromJson(reconstructedData);
          } catch (e) {
            debugPrint('Warning: Could not reconstruct EspnNflScoreboard: $e');
          }
        } else if (T == EspnScoreboard) {
          try {
            reconstructedData = EspnScoreboard.fromJson(reconstructedData);
          } catch (e) {
            debugPrint('Warning: Could not reconstruct EspnScoreboard: $e');
          }
        } else if (T == EspnNhlScoreboard) {
          try {
            reconstructedData = EspnNhlScoreboard.fromJson(reconstructedData);
          } catch (e) {
            debugPrint('Warning: Could not reconstruct EspnNhlScoreboard: $e');
          }
        } else if (T == EspnMlbScoreboard) {
          try {
            reconstructedData = EspnMlbScoreboard.fromJson(reconstructedData);
          } catch (e) {
            debugPrint('Warning: Could not reconstruct EspnMlbScoreboard: $e');
          }
        }
      }
      
      // Update memory cache
      _memoryCache[cacheKey] = CachedData(
        data: reconstructedData,
        timestamp: (firestoreCached['timestamp'] as Timestamp).toDate(),
        ttl: firestoreCached['ttl'] ?? 300,
      );
      
      // Final type check before returning
      try {
        return reconstructedData as T;
      } catch (e) {
        debugPrint('Warning: Type casting error for cached data: $e');
        debugPrint('Expected type: $T, Got: ${reconstructedData.runtimeType}');
        return null;
      }
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
      case 'ufc':
      case 'mma':
      case 'boxing':
        return _getCombatSportsTTL(dataType);
      default:
        return 1800; // 30 min default (was 5 min)
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

  /// Get football TTL - Optimized for Firestore sharing
  int _getFootballTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 600;   // 10 min (was 2 min)
      case 'stats':
        return 900;   // 15 min (was 3 min)
      case 'news':
        return 3600;  // 1 hour (was 10 min)
      case 'odds':
        return 900;   // 15 min
      case 'games':
        return 1800;  // 30 min for game listings
      case 'scoreboard':
        return 600;   // 10 min for scoreboards
      default:
        return 1800;  // 30 min default (was 5 min)
    }
  }

  /// Get baseball TTL - Optimized for Firestore sharing
  int _getBaseballTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 900;   // 15 min (was 3 min)
      case 'stats':
        return 1800;  // 30 min (was 5 min)
      case 'news':
        return 3600;  // 1 hour (was 15 min)
      case 'odds':
        return 1800;  // 30 min
      case 'games':
        return 3600;  // 1 hour for game listings
      case 'scoreboard':
        return 900;   // 15 min for scoreboards
      default:
        return 1800;  // 30 min default (was 5 min)
    }
  }

  /// Get hockey TTL - Optimized for Firestore sharing
  int _getHockeyTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 600;   // 10 min (was 3 min)
      case 'stats':
        return 900;   // 15 min (was 4 min)
      case 'news':
        return 3600;  // 1 hour (was 10 min)
      case 'odds':
        return 900;   // 15 min
      case 'games':
        return 1800;  // 30 min for game listings
      case 'scoreboard':
        return 600;   // 10 min for scoreboards
      default:
        return 1800;  // 30 min default (was 5 min)
    }
  }

  /// Get soccer TTL - Optimized for Firestore sharing
  int _getSoccerTTL(String dataType) {
    switch (dataType) {
      case 'scores':
        return 1800;  // 30 min (was 5 min - goals are rare)
      case 'stats':
        return 3600;  // 1 hour (was 10 min)
      case 'news':
        return 3600;  // 1 hour (was 15 min)
      case 'odds':
        return 1800;  // 30 min
      case 'games':
        return 3600;  // 1 hour for game listings
      case 'scoreboard':
        return 1800;  // 30 min for scoreboards
      default:
        return 3600;  // 1 hour default (was 10 min)
    }
  }

  /// Get combat sports TTL - Optimized for Firestore sharing
  int _getCombatSportsTTL(String dataType) {
    switch (dataType) {
      case 'events':
        return 7200;  // 2 hours for event listings
      case 'odds':
        return 3600;  // 1 hour
      case 'news':
        return 3600;  // 1 hour
      case 'stats':
        return 7200;  // 2 hours
      case 'fighters':
        return 86400; // 24 hours for fighter info
      default:
        return 3600;  // 1 hour default
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