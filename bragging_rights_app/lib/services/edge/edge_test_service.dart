import 'package:flutter/foundation.dart';
import 'api_gateway.dart';
import 'event_matcher.dart';
import 'api_config_manager.dart';

/// Test service to demonstrate Edge API functionality
class EdgeTestService {
  final ApiGateway _gateway = ApiGateway();
  final EventMatcher _matcher = EventMatcher();
  final ApiConfigManager _configManager = ApiConfigManager();

  /// Initialize the service
  Future<void> initialize() async {
    await _configManager.initialize();
    debugPrint('✅ Edge Test Service initialized');
  }

  /// Test ESPN API integration
  Future<void> testEspnApi() async {
    try {
      debugPrint('🏀 Testing ESPN NBA API...');
      
      final response = await _gateway.request(
        apiName: 'espn',
        endpoint: '/basketball/nba/scoreboard',
        queryParams: {
          'limit': '10',
        },
      );

      debugPrint('✅ ESPN Response: ${response.source}');
      debugPrint('📊 Data: ${response.data}');
    } catch (e) {
      debugPrint('❌ ESPN API Error: $e');
    }
  }

  /// Test NBA Stats API
  Future<void> testNbaStatsApi() async {
    try {
      debugPrint('🏀 Testing NBA Stats API...');
      
      final response = await _gateway.request(
        apiName: 'nba_stats',
        endpoint: '/stats/scoreboard',
        queryParams: {
          'GameDate': '2025-08-27',
          'LeagueID': '00',
        },
        headers: {
          'Referer': 'https://stats.nba.com/',
          'User-Agent': 'Mozilla/5.0',
        },
      );

      debugPrint('✅ NBA Stats Response: ${response.source}');
      debugPrint('📊 Games today: ${response.data}');
    } catch (e) {
      debugPrint('❌ NBA Stats API Error: $e');
    }
  }

  /// Test Event Matching
  Future<void> testEventMatching() async {
    debugPrint('🔍 Testing Event Matcher...');
    
    final match = await _matcher.matchEvent(
      eventId: 'test_001',
      eventDate: DateTime.now(),
      homeTeam: 'Lakers',
      awayTeam: 'Boston Celtics',
      sport: 'NBA',
    );

    debugPrint('✅ Event Match Created:');
    debugPrint('  Home: ${match.homeTeam}');
    debugPrint('  Away: ${match.awayTeam}');
    debugPrint('  Search Terms: ${match.searchTerms}');
    debugPrint('  API IDs: ${match.apiIdentifiers}');
  }

  /// Test caching functionality
  Future<void> testCaching() async {
    debugPrint('💾 Testing Cache System...');
    
    // First request (will hit API)
    debugPrint('Request 1: Should hit API...');
    await _gateway.request(
      apiName: 'espn',
      endpoint: '/test/cache',
      queryParams: {'test': 'true'},
    );

    // Second request (should hit cache)
    debugPrint('Request 2: Should hit cache...');
    final cached = await _gateway.request(
      apiName: 'espn',
      endpoint: '/test/cache',
      queryParams: {'test': 'true'},
    );

    debugPrint('✅ Cache test complete. Source: ${cached.source}');
    
    // Get cache stats
    final stats = _gateway.getCacheStats();
    debugPrint('📊 Cache Stats: $stats');
  }

  /// Test rate limiting
  Future<void> testRateLimiting() async {
    debugPrint('⏱️ Testing Rate Limiting...');
    
    // Make multiple rapid requests
    for (int i = 0; i < 5; i++) {
      try {
        debugPrint('Request ${i + 1}...');
        await _gateway.request(
          apiName: 'espn',
          endpoint: '/test/ratelimit',
          useCache: false, // Disable cache to test rate limiting
        );
      } catch (e) {
        debugPrint('Rate limit hit: $e');
      }
    }
    
    debugPrint('✅ Rate limiting test complete');
  }

  /// Test all Edge systems
  Future<void> runAllTests() async {
    debugPrint('🚀 Starting Edge API Tests...\n');
    
    await initialize();
    
    debugPrint('\n--- Event Matching Test ---');
    await testEventMatching();
    
    debugPrint('\n--- ESPN API Test ---');
    await testEspnApi();
    
    debugPrint('\n--- NBA Stats API Test ---');
    await testNbaStatsApi();
    
    debugPrint('\n--- Cache System Test ---');
    await testCaching();
    
    debugPrint('\n--- Rate Limiting Test ---');
    await testRateLimiting();
    
    debugPrint('\n✅ All Edge API tests complete!');
  }

  /// Get aggregated intelligence for an event
  Future<Map<String, dynamic>> getEventIntelligence({
    required String eventId,
    required DateTime eventDate,
    required String homeTeam,
    required String awayTeam,
    required String sport,
  }) async {
    // Create event match
    final match = await _matcher.matchEvent(
      eventId: eventId,
      eventDate: eventDate,
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      sport: sport,
    );

    final intelligence = <String, dynamic>{
      'eventId': eventId,
      'match': match.toMap(),
      'data': {},
      'confidence': 0.0,
    };

    // Gather data from multiple sources in parallel
    final futures = <Future>[];

    // ESPN data
    futures.add(_getEspnData(match).then((data) {
      intelligence['data']['espn'] = data;
    }).catchError((e) {
      debugPrint('ESPN data error: $e');
    }));

    // Add more API calls here as they're implemented
    
    // Wait for all data to be gathered
    await Future.wait(futures);

    // Calculate overall confidence
    intelligence['confidence'] = _calculateConfidence(intelligence['data']);

    return intelligence;
  }

  Future<Map<String, dynamic>?> _getEspnData(EventMatch match) async {
    final response = await _gateway.request(
      apiName: 'espn',
      endpoint: '/${match.sport}/scoreboard',
      queryParams: {
        'dates': match.eventDate.toIso8601String().split('T')[0],
      },
    );

    // Parse and filter relevant data
    if (response.data != null) {
      // TODO: Filter to find matching event
      return response.data;
    }
    
    return null;
  }

  double _calculateConfidence(Map<String, dynamic> data) {
    int sources = 0;
    double totalConfidence = 0.0;

    data.forEach((key, value) {
      if (value != null) {
        sources++;
        totalConfidence += 1.0;
      }
    });

    return sources > 0 ? totalConfidence / sources : 0.0;
  }
}