import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

class ApiGateway {
  static final ApiGateway _instance = ApiGateway._internal();
  factory ApiGateway() => _instance;
  ApiGateway._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  
  // In-memory cache
  final Map<String, CachedResponse> _memoryCache = {};
  
  // Rate limiting tracking
  final Map<String, RateLimitInfo> _rateLimits = {};
  
  // API configurations
  final Map<String, ApiConfig> _apiConfigs = {
    'nba_stats': ApiConfig(
      baseUrl: 'https://stats.nba.com',
      rateLimit: 100,
      rateLimitWindow: const Duration(minutes: 1),
      timeout: const Duration(seconds: 10),
      cacheDuration: const Duration(minutes: 5),
    ),
    'nhl_api': ApiConfig(
      baseUrl: 'https://statsapi.web.nhl.com/api/v1',
      rateLimit: 100,
      rateLimitWindow: const Duration(minutes: 1),
      timeout: const Duration(seconds: 10),
      cacheDuration: const Duration(minutes: 5),
    ),
    'mlb_stats': ApiConfig(
      baseUrl: 'https://statsapi.mlb.com',
      rateLimit: 100,
      rateLimitWindow: const Duration(minutes: 1),
      timeout: const Duration(seconds: 10),
      cacheDuration: const Duration(minutes: 5),
    ),
    'espn': ApiConfig(
      baseUrl: 'https://site.api.espn.com/apis/site/v2/sports',
      rateLimit: 100,
      rateLimitWindow: const Duration(minutes: 1),
      timeout: const Duration(seconds: 10),
      cacheDuration: const Duration(minutes: 15),
    ),
    'news_api': ApiConfig(
      baseUrl: 'https://newsapi.org/v2',
      rateLimit: 100,
      rateLimitWindow: const Duration(hours: 24),
      timeout: const Duration(seconds: 10),
      cacheDuration: const Duration(minutes: 30),
      apiKey: 'YOUR_NEWS_API_KEY', // TODO: Move to environment config
    ),
    'openweather': ApiConfig(
      baseUrl: 'https://api.openweathermap.org/data/2.5',
      rateLimit: 60,
      rateLimitWindow: const Duration(minutes: 1),
      timeout: const Duration(seconds: 10),
      cacheDuration: const Duration(minutes: 30),
      apiKey: 'YOUR_OPENWEATHER_API_KEY', // TODO: Move to environment config
    ),
    'odds_api': ApiConfig(
      baseUrl: 'https://api.the-odds-api.com/v4',
      rateLimit: 500,
      rateLimitWindow: const Duration(days: 30),
      timeout: const Duration(seconds: 10),
      cacheDuration: const Duration(minutes: 5),
      apiKey: 'YOUR_ODDS_API_KEY', // Already integrated
    ),
  };

  /// Main request method with all gateway features
  Future<ApiResponse> request({
    required String apiName,
    required String endpoint,
    Map<String, dynamic>? queryParams,
    Map<String, String>? headers,
    String? method = 'GET',
    dynamic body,
    bool useCache = true,
    int maxRetries = 3,
    bool fallbackOnError = true,
  }) async {
    final config = _apiConfigs[apiName];
    if (config == null) {
      throw ApiException('Unknown API: $apiName');
    }

    // Generate cache key
    final cacheKey = _generateCacheKey(apiName, endpoint, queryParams);

    // Check memory cache first
    if (useCache && method == 'GET') {
      final cached = _getFromMemoryCache(cacheKey);
      if (cached != null) {
        debugPrint('✅ Cache hit: $cacheKey');
        return ApiResponse(
          data: cached.data,
          source: 'memory_cache',
          timestamp: cached.timestamp,
        );
      }

      // Check Firestore cache
      final firestoreCached = await _getFromFirestoreCache(cacheKey);
      if (firestoreCached != null) {
        debugPrint('✅ Firestore cache hit: $cacheKey');
        // Update memory cache
        _memoryCache[cacheKey] = CachedResponse(
          data: firestoreCached['data'],
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            firestoreCached['timestamp'],
          ),
        );
        return ApiResponse(
          data: firestoreCached['data'],
          source: 'firestore_cache',
          timestamp: DateTime.fromMillisecondsSinceEpoch(
            firestoreCached['timestamp'],
          ),
        );
      }
    }

    // Check rate limiting
    await _checkRateLimit(apiName, config);

    // Build request URL
    final uri = _buildUri(config.baseUrl, endpoint, queryParams, config.apiKey);

    // Prepare headers
    final requestHeaders = {
      'Accept': 'application/json',
      ...?headers,
    };

    // Execute request with retry logic
    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        debugPrint('🔍 API Request: $uri (attempt ${attempt + 1})');
        
        final response = await _executeRequest(
          uri: uri,
          method: method ?? 'GET',
          headers: requestHeaders,
          body: body,
          timeout: config.timeout,
        );

        if (response.statusCode >= 200 && response.statusCode < 300) {
          final responseData = json.decode(response.body);
          
          // Cache successful GET requests
          if (useCache && method == 'GET') {
            await _cacheResponse(cacheKey, responseData, config.cacheDuration);
          }

          return ApiResponse(
            data: responseData,
            source: apiName,
            timestamp: DateTime.now(),
          );
        } else if (response.statusCode == 429) {
          // Rate limited - wait and retry
          final retryAfter = int.tryParse(
            response.headers['retry-after'] ?? '60',
          ) ?? 60;
          
          debugPrint('⚠️ Rate limited. Waiting $retryAfter seconds...');
          
          if (attempt < maxRetries) {
            await Future.delayed(Duration(seconds: retryAfter));
            continue;
          }
        } else if (response.statusCode >= 500) {
          // Server error - retry with exponential backoff
          if (attempt < maxRetries) {
            final delay = _calculateBackoff(attempt);
            debugPrint('⚠️ Server error. Retrying in $delay...');
            await Future.delayed(delay);
            continue;
          }
        } else {
          // Client error - don't retry
          throw ApiException(
            'API error: ${response.statusCode} - ${response.body}',
          );
        }
      } on TimeoutException {
        if (attempt < maxRetries) {
          final delay = _calculateBackoff(attempt);
          debugPrint('⏱️ Timeout. Retrying in $delay...');
          await Future.delayed(delay);
          continue;
        }
        throw ApiException('Request timeout after $maxRetries attempts');
      } catch (e) {
        if (attempt < maxRetries) {
          final delay = _calculateBackoff(attempt);
          debugPrint('❌ Error: $e. Retrying in $delay...');
          await Future.delayed(delay);
          continue;
        }
        
        // All retries exhausted
        if (fallbackOnError) {
          // Try to return cached data even if expired
          final fallbackData = await _getFallbackData(cacheKey);
          if (fallbackData != null) {
            debugPrint('📦 Returning fallback cached data');
            return ApiResponse(
              data: fallbackData,
              source: 'fallback_cache',
              timestamp: DateTime.now(),
              isStale: true,
            );
          }
        }
        
        throw ApiException('Failed after $maxRetries attempts: $e');
      }
    }

    throw ApiException('Request failed after all retry attempts');
  }

  /// Execute the actual HTTP request
  Future<http.Response> _executeRequest({
    required Uri uri,
    required String method,
    required Map<String, String> headers,
    dynamic body,
    required Duration timeout,
  }) async {
    switch (method.toUpperCase()) {
      case 'GET':
        return await http.get(uri, headers: headers).timeout(timeout);
      case 'POST':
        return await http.post(
          uri,
          headers: headers,
          body: body is Map ? json.encode(body) : body,
        ).timeout(timeout);
      case 'PUT':
        return await http.put(
          uri,
          headers: headers,
          body: body is Map ? json.encode(body) : body,
        ).timeout(timeout);
      case 'DELETE':
        return await http.delete(uri, headers: headers).timeout(timeout);
      default:
        throw ApiException('Unsupported HTTP method: $method');
    }
  }

  /// Build URI with query parameters
  Uri _buildUri(
    String baseUrl,
    String endpoint,
    Map<String, dynamic>? queryParams,
    String? apiKey,
  ) {
    final url = '$baseUrl$endpoint';
    final params = {...?queryParams};
    
    if (apiKey != null) {
      params['apiKey'] = apiKey;
    }

    return Uri.parse(url).replace(queryParameters: params);
  }

  /// Generate cache key
  String _generateCacheKey(
    String apiName,
    String endpoint,
    Map<String, dynamic>? queryParams,
  ) {
    final params = queryParams?.entries
        .map((e) => '${e.key}=${e.value}')
        .join('&') ?? '';
    return '$apiName:$endpoint:$params';
  }

  /// Get from memory cache
  CachedResponse? _getFromMemoryCache(String key) {
    final cached = _memoryCache[key];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);
      if (age.inMinutes < 5) {
        // Memory cache valid for 5 minutes
        return cached;
      } else {
        _memoryCache.remove(key);
      }
    }
    return null;
  }

  /// Get from Firestore cache
  Future<Map<String, dynamic>?> _getFromFirestoreCache(String key) async {
    try {
      final doc = await _firestore
          .collection('edge_cache')
          .doc(key.replaceAll(':', '_'))
          .get();
      
      if (doc.exists) {
        final data = doc.data()!;
        final timestamp = data['timestamp'] as int;
        final age = DateTime.now().millisecondsSinceEpoch - timestamp;
        
        // Check if cache is still valid (default 30 minutes)
        if (age < 30 * 60 * 1000) {
          return data;
        }
      }
    } catch (e) {
      debugPrint('Firestore cache error: $e');
    }
    return null;
  }

  /// Cache response in memory and Firestore
  Future<void> _cacheResponse(
    String key,
    dynamic data,
    Duration cacheDuration,
  ) async {
    final timestamp = DateTime.now();
    
    // Memory cache
    _memoryCache[key] = CachedResponse(
      data: data,
      timestamp: timestamp,
    );

    // Firestore cache
    try {
      await _firestore
          .collection('edge_cache')
          .doc(key.replaceAll(':', '_'))
          .set({
        'data': data,
        'timestamp': timestamp.millisecondsSinceEpoch,
        'expiresAt': timestamp
            .add(cacheDuration)
            .millisecondsSinceEpoch,
      });
    } catch (e) {
      debugPrint('Failed to cache in Firestore: $e');
    }
  }

  /// Get fallback data from any cache
  Future<dynamic> _getFallbackData(String key) async {
    // Check memory cache (even if expired)
    final memoryCached = _memoryCache[key];
    if (memoryCached != null) {
      return memoryCached.data;
    }

    // Check Firestore (even if expired)
    try {
      final doc = await _firestore
          .collection('edge_cache')
          .doc(key.replaceAll(':', '_'))
          .get();
      
      if (doc.exists) {
        return doc.data()?['data'];
      }
    } catch (e) {
      debugPrint('Fallback cache error: $e');
    }

    return null;
  }

  /// Check and enforce rate limiting
  Future<void> _checkRateLimit(String apiName, ApiConfig config) async {
    final now = DateTime.now();
    final limitInfo = _rateLimits[apiName];

    if (limitInfo != null) {
      final windowAge = now.difference(limitInfo.windowStart);
      
      if (windowAge < config.rateLimitWindow) {
        // Still in current window
        if (limitInfo.requestCount >= config.rateLimit) {
          // Rate limit exceeded
          final waitTime = config.rateLimitWindow - windowAge;
          debugPrint('⏰ Rate limit reached. Waiting ${waitTime.inSeconds}s');
          await Future.delayed(waitTime);
          
          // Reset window
          _rateLimits[apiName] = RateLimitInfo(
            windowStart: now,
            requestCount: 1,
          );
        } else {
          // Increment counter
          limitInfo.requestCount++;
        }
      } else {
        // New window
        _rateLimits[apiName] = RateLimitInfo(
          windowStart: now,
          requestCount: 1,
        );
      }
    } else {
      // First request
      _rateLimits[apiName] = RateLimitInfo(
        windowStart: now,
        requestCount: 1,
      );
    }
  }

  /// Calculate exponential backoff delay
  Duration _calculateBackoff(int attempt) {
    final seconds = (2 << attempt).clamp(1, 60);
    return Duration(seconds: seconds);
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _memoryCache.clear();
    
    try {
      final batch = _firestore.batch();
      final docs = await _firestore.collection('edge_cache').get();
      
      for (final doc in docs.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
    } catch (e) {
      debugPrint('Failed to clear Firestore cache: $e');
    }
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'memoryCacheSize': _memoryCache.length,
      'rateLimits': _rateLimits.map(
        (key, value) => MapEntry(key, {
          'windowStart': value.windowStart.toIso8601String(),
          'requestCount': value.requestCount,
        }),
      ),
    };
  }
}

/// API configuration
class ApiConfig {
  final String baseUrl;
  final int rateLimit;
  final Duration rateLimitWindow;
  final Duration timeout;
  final Duration cacheDuration;
  final String? apiKey;

  ApiConfig({
    required this.baseUrl,
    required this.rateLimit,
    required this.rateLimitWindow,
    required this.timeout,
    required this.cacheDuration,
    this.apiKey,
  });
}

/// Cached response
class CachedResponse {
  final dynamic data;
  final DateTime timestamp;

  CachedResponse({
    required this.data,
    required this.timestamp,
  });
}

/// Rate limit tracking
class RateLimitInfo {
  DateTime windowStart;
  int requestCount;

  RateLimitInfo({
    required this.windowStart,
    required this.requestCount,
  });
}

/// API response wrapper
class ApiResponse {
  final dynamic data;
  final String source;
  final DateTime timestamp;
  final bool isStale;

  ApiResponse({
    required this.data,
    required this.source,
    required this.timestamp,
    this.isStale = false,
  });
}

/// API exception
class ApiException implements Exception {
  final String message;

  ApiException(this.message);

  @override
  String toString() => 'ApiException: $message';
}