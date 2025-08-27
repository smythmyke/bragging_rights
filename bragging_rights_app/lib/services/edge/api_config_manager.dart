import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class ApiConfigManager {
  static final ApiConfigManager _instance = ApiConfigManager._internal();
  factory ApiConfigManager() => _instance;
  ApiConfigManager._internal();

  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, ApiCredentials> _credentials = {};
  bool _initialized = false;

  /// Initialize API configurations
  Future<void> initialize() async {
    if (_initialized) return;

    // Load from environment variables first
    await _loadFromEnvironment();
    
    // Then override with Firestore Remote Config if available
    await _loadFromFirestore();

    _initialized = true;
  }

  /// Load API keys from environment variables
  Future<void> _loadFromEnvironment() async {
    try {
      // Load .env file if it exists
      await dotenv.load(fileName: '.env');
      
      _credentials = {
        'news_api': ApiCredentials(
          apiKey: dotenv.env['NEWS_API_KEY'] ?? '',
          baseUrl: 'https://newsapi.org/v2',
          rateLimit: 100,
          rateLimitWindow: const Duration(hours: 24),
        ),
        'openweather': ApiCredentials(
          apiKey: dotenv.env['OPENWEATHER_API_KEY'] ?? '',
          baseUrl: 'https://api.openweathermap.org/data/2.5',
          rateLimit: 60,
          rateLimitWindow: const Duration(minutes: 1),
        ),
        'twitter': ApiCredentials(
          apiKey: dotenv.env['TWITTER_BEARER_TOKEN'] ?? '',
          baseUrl: 'https://api.twitter.com/2',
          rateLimit: 500,
          rateLimitWindow: const Duration(minutes: 15),
        ),
        'reddit': ApiCredentials(
          apiKey: dotenv.env['REDDIT_CLIENT_ID'] ?? '',
          apiSecret: dotenv.env['REDDIT_CLIENT_SECRET'] ?? '',
          baseUrl: 'https://oauth.reddit.com',
          rateLimit: 60,
          rateLimitWindow: const Duration(minutes: 1),
        ),
        'odds_api': ApiCredentials(
          apiKey: dotenv.env['ODDS_API_KEY'] ?? '',
          baseUrl: 'https://api.the-odds-api.com/v4',
          rateLimit: 500,
          rateLimitWindow: const Duration(days: 30),
        ),
        'youtube': ApiCredentials(
          apiKey: dotenv.env['YOUTUBE_API_KEY'] ?? '',
          baseUrl: 'https://www.googleapis.com/youtube/v3',
          rateLimit: 10000, // Units per day
          rateLimitWindow: const Duration(days: 1),
        ),
        'currents': ApiCredentials(
          apiKey: dotenv.env['CURRENTS_API_KEY'] ?? '',
          baseUrl: 'https://api.currentsapi.services/v1',
          rateLimit: 600,
          rateLimitWindow: const Duration(days: 1),
        ),
      };
    } catch (e) {
      print('Failed to load environment variables: $e');
    }
  }

  /// Load API configurations from Firestore
  Future<void> _loadFromFirestore() async {
    try {
      final doc = await _firestore
          .collection('config')
          .doc('api_credentials')
          .get();

      if (doc.exists) {
        final data = doc.data()!;
        
        // Override with Firestore values if they exist
        data.forEach((key, value) {
          if (value is Map<String, dynamic>) {
            _credentials[key] = ApiCredentials.fromMap(value);
          }
        });
      }
    } catch (e) {
      print('Failed to load API configs from Firestore: $e');
    }
  }

  /// Get API credentials
  ApiCredentials? getCredentials(String apiName) {
    if (!_initialized) {
      throw StateError('ApiConfigManager not initialized. Call initialize() first.');
    }
    return _credentials[apiName];
  }

  /// Update API credentials (admin only)
  Future<void> updateCredentials(
    String apiName,
    ApiCredentials credentials,
  ) async {
    _credentials[apiName] = credentials;
    
    // Save to Firestore
    await _firestore
        .collection('config')
        .doc('api_credentials')
        .set(
          {apiName: credentials.toMap()},
          SetOptions(merge: true),
        );
  }

  /// Get all configured APIs
  List<String> getConfiguredApis() {
    return _credentials.keys.toList();
  }

  /// Check if an API is properly configured
  bool isApiConfigured(String apiName) {
    final creds = _credentials[apiName];
    return creds != null && creds.apiKey.isNotEmpty;
  }

  /// Get API usage statistics
  Future<Map<String, dynamic>> getUsageStats(String apiName) async {
    try {
      final doc = await _firestore
          .collection('api_usage')
          .doc(apiName)
          .get();
      
      if (doc.exists) {
        return doc.data()!;
      }
    } catch (e) {
      print('Failed to get usage stats: $e');
    }
    
    return {
      'requestCount': 0,
      'lastReset': DateTime.now().toIso8601String(),
      'errors': 0,
    };
  }

  /// Track API usage
  Future<void> trackUsage(
    String apiName, {
    bool success = true,
  }) async {
    try {
      final ref = _firestore.collection('api_usage').doc(apiName);
      
      await _firestore.runTransaction((transaction) async {
        final doc = await transaction.get(ref);
        
        Map<String, dynamic> data;
        if (doc.exists) {
          data = doc.data()!;
        } else {
          data = {
            'requestCount': 0,
            'lastReset': DateTime.now().toIso8601String(),
            'errors': 0,
            'successCount': 0,
          };
        }

        data['requestCount'] = (data['requestCount'] ?? 0) + 1;
        
        if (success) {
          data['successCount'] = (data['successCount'] ?? 0) + 1;
        } else {
          data['errors'] = (data['errors'] ?? 0) + 1;
        }
        
        data['lastRequest'] = DateTime.now().toIso8601String();
        
        transaction.set(ref, data);
      });
    } catch (e) {
      print('Failed to track API usage: $e');
    }
  }

  /// Get remaining quota for an API
  int? getRemainingQuota(String apiName) {
    final creds = _credentials[apiName];
    if (creds == null) return null;

    // Special handling for known APIs with quotas
    switch (apiName) {
      case 'odds_api':
        return 500 - (_getMonthlyUsage(apiName) ?? 0);
      case 'news_api':
        return 100 - (_getDailyUsage(apiName) ?? 0);
      case 'youtube':
        return 10000 - (_getDailyUsage(apiName) ?? 0);
      default:
        return null;
    }
  }

  int? _getDailyUsage(String apiName) {
    // TODO: Implement daily usage tracking
    return 0;
  }

  int? _getMonthlyUsage(String apiName) {
    // TODO: Implement monthly usage tracking
    return 0;
  }
}

/// API Credentials model
class ApiCredentials {
  final String apiKey;
  final String? apiSecret;
  final String baseUrl;
  final int rateLimit;
  final Duration rateLimitWindow;
  final Map<String, String>? headers;

  ApiCredentials({
    required this.apiKey,
    this.apiSecret,
    required this.baseUrl,
    required this.rateLimit,
    required this.rateLimitWindow,
    this.headers,
  });

  factory ApiCredentials.fromMap(Map<String, dynamic> map) {
    return ApiCredentials(
      apiKey: map['apiKey'] ?? '',
      apiSecret: map['apiSecret'],
      baseUrl: map['baseUrl'] ?? '',
      rateLimit: map['rateLimit'] ?? 100,
      rateLimitWindow: Duration(
        seconds: map['rateLimitWindowSeconds'] ?? 3600,
      ),
      headers: map['headers'] != null
          ? Map<String, String>.from(map['headers'])
          : null,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'apiKey': apiKey,
      'apiSecret': apiSecret,
      'baseUrl': baseUrl,
      'rateLimit': rateLimit,
      'rateLimitWindowSeconds': rateLimitWindow.inSeconds,
      'headers': headers,
    };
  }

  bool get isValid => apiKey.isNotEmpty;
}