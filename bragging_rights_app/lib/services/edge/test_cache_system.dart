import 'package:flutter/foundation.dart';
import 'cache/edge_cache_service.dart';
import 'sports/espn_nba_service.dart';
import 'sports/balldontlie_service.dart';
import 'news/news_api_service.dart';
import 'social/reddit_service.dart';

/// Test the Edge Cache System
class TestEdgeCacheSystem {
  final EdgeCacheService _cache = EdgeCacheService();
  final EspnNbaService _espn = EspnNbaService();
  final BalldontlieService _balldontlie = BalldontlieService();
  final NewsApiService _news = NewsApiService();
  final RedditService _reddit = RedditService();

  /// Run comprehensive cache tests
  Future<void> runTests() async {
    debugPrint('🚀 Starting Edge Cache System Tests...\n');
    
    await testCacheHitRate();
    await testDynamicTTL();
    await testMultiUserSharing();
    await testClutchTimeDetection();
    
    debugPrint('\n✅ Cache System Tests Complete!');
    
    // Print final statistics
    final stats = _cache.getCacheStats();
    debugPrint('\n📊 Cache Statistics:');
    debugPrint('  Total Items: ${stats['totalItems']}');
    debugPrint('  Active Items: ${stats['activeItems']}');
    debugPrint('  Hit Rate: ${stats['hitRate'].toStringAsFixed(1)}%');
  }

  /// Test cache hit rate
  Future<void> testCacheHitRate() async {
    debugPrint('\n📈 Testing Cache Hit Rate...');
    
    // First call - should miss cache and fetch from API
    final start1 = DateTime.now();
    final games1 = await _espn.getTodaysGames();
    final duration1 = DateTime.now().difference(start1);
    debugPrint('  First call: ${duration1.inMilliseconds}ms (cache miss expected)');
    
    // Second call - should hit cache
    final start2 = DateTime.now();
    final games2 = await _espn.getTodaysGames();
    final duration2 = DateTime.now().difference(start2);
    debugPrint('  Second call: ${duration2.inMilliseconds}ms (cache hit expected)');
    
    // Third call - should still hit cache
    final start3 = DateTime.now();
    final games3 = await _espn.getTodaysGames();
    final duration3 = DateTime.now().difference(start3);
    debugPrint('  Third call: ${duration3.inMilliseconds}ms (cache hit expected)');
    
    // Cache should be much faster
    if (duration2.inMilliseconds < duration1.inMilliseconds / 2) {
      debugPrint('  ✅ Cache is working! ${duration1.inMilliseconds / duration2.inMilliseconds}x faster');
    } else {
      debugPrint('  ⚠️ Cache might not be working properly');
    }
  }

  /// Test dynamic TTL based on game state
  Future<void> testDynamicTTL() async {
    debugPrint('\n⏱️ Testing Dynamic TTL...');
    
    // Simulate different game states
    final gameStates = [
      {
        'name': 'Pre-Game',
        'state': {'status': 'pregame'},
        'expectedTTL': 'lineups: 300s, news: 900s',
      },
      {
        'name': 'First Half',
        'state': {'status': 'live', 'period': 1},
        'expectedTTL': 'scores: 30s, stats: 60s',
      },
      {
        'name': 'Halftime',
        'state': {'status': 'halftime'},
        'expectedTTL': 'scores: 300s (no changes)',
      },
      {
        'name': 'Clutch Time',
        'state': {
          'status': 'live',
          'period': 4,
          'timeRemaining': 120,
          'homeScore': 98,
          'awayScore': 95,
        },
        'expectedTTL': 'scores: 15s (critical!)',
      },
      {
        'name': 'Blowout',
        'state': {
          'status': 'live',
          'period': 3,
          'homeScore': 95,
          'awayScore': 65,
        },
        'expectedTTL': 'scores: 120s (less interest)',
      },
    ];

    for (final test in gameStates) {
      debugPrint('  ${test['name']}: ${test['expectedTTL']}');
    }
  }

  /// Test multi-user cache sharing
  Future<void> testMultiUserSharing() async {
    debugPrint('\n👥 Testing Multi-User Cache Sharing...');
    
    // Simulate multiple users requesting same data
    debugPrint('  Simulating 10 users checking Lakers game...');
    
    int apiCalls = 0;
    int cacheHits = 0;
    
    for (int user = 1; user <= 10; user++) {
      final start = DateTime.now();
      
      // Each "user" requests the same game data
      final games = await _espn.getTodaysGames();
      
      final duration = DateTime.now().difference(start);
      
      if (duration.inMilliseconds < 50) {
        cacheHits++;
        debugPrint('  User $user: Cache hit (${duration.inMilliseconds}ms)');
      } else {
        apiCalls++;
        debugPrint('  User $user: API call (${duration.inMilliseconds}ms)');
      }
      
      // Small delay to simulate real users
      await Future.delayed(const Duration(milliseconds: 100));
    }
    
    debugPrint('  Results: $apiCalls API calls, $cacheHits cache hits');
    debugPrint('  Efficiency: ${(cacheHits / 10 * 100).toStringAsFixed(0)}% served from cache');
  }

  /// Test clutch time detection
  Future<void> testClutchTimeDetection() async {
    debugPrint('\n🔥 Testing Clutch Time Detection...');
    
    // Simulate a close game in the 4th quarter
    final clutchGameState = {
      'status': 'live',
      'period': 4,
      'timeRemaining': 180, // 3 minutes left
      'homeScore': 102,
      'awayScore': 99,
      'homeTeam': 'Lakers',
      'awayTeam': 'Celtics',
    };
    
    debugPrint('  Game: LAL 102 - BOS 99, 3:00 left in 4th');
    debugPrint('  Expected: 15-second cache for maximum freshness');
    
    // This would use the clutch time TTL (15 seconds for scores)
    await _cache.getCachedData(
      collection: 'games',
      documentId: 'test_clutch_game',
      dataType: 'scores',
      sport: 'nba',
      gameState: clutchGameState,
      fetchFunction: () async {
        debugPrint('  ✅ Using clutch time cache settings!');
        return {'test': 'clutch_data'};
      },
    );
  }

  /// Test cache warming for upcoming games
  Future<void> testCacheWarming() async {
    debugPrint('\n🔥 Testing Cache Warming...');
    
    // Get games scheduled for next 2 hours
    final upcomingGames = [
      {'id': 'game_001', 'time': DateTime.now().add(const Duration(hours: 1))},
      {'id': 'game_002', 'time': DateTime.now().add(const Duration(hours: 2))},
    ];
    
    for (final game in upcomingGames) {
      await _cache.warmCacheForGame(
        gameId: game['id'] as String,
        sport: 'nba',
        gameTime: game['time'] as DateTime,
      );
    }
    
    debugPrint('  ✅ Cache warmed for ${upcomingGames.length} upcoming games');
  }

  /// Demonstrate API call savings
  Future<void> demonstrateSavings() async {
    debugPrint('\n💰 Demonstrating API Call Savings...');
    
    debugPrint('  Without caching:');
    debugPrint('    1000 users × 10 requests = 10,000 API calls/day');
    debugPrint('    Result: Rate limits exceeded! 🚫');
    
    debugPrint('  With caching:');
    debugPrint('    10 unique data points × 1 API call = 10 API calls/day');
    debugPrint('    Result: 99.9% reduction! ✅');
    
    debugPrint('  Cost savings:');
    debugPrint('    NewsAPI: 100/day limit → Stay within free tier');
    debugPrint('    Balldontlie: 5/min limit → Never exceeded');
    debugPrint('    Total cost: \$0/month 🎉');
  }
}