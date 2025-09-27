# Intelligent Caching Strategy for Bragging Rights

## Overview
A comprehensive caching strategy to minimize API calls while maintaining data freshness, designed to scale efficiently to hundreds of users.

## Current System Problems
1. **Redundant API Calls**: Each user triggers their own API calls
2. **Fixed Cache Duration**: All games expire after 5 minutes regardless of status
3. **No Shared Cache**: Users don't benefit from data fetched by others
4. **Stale Data Issue**: Games show incorrect data when navigating between time periods
5. **High API Costs**: Linear growth with user count

## Proposed Multi-Tier Architecture

```
┌─────────────────────────────────────────────────────────┐
│                    TIER 1: FIRESTORE                     │
│         (Centralized, Shared Across All Users)           │
│  • Games Collection with lastFetched timestamps          │
│  • Sport-specific refresh intervals                      │
│  • Automatic serving based on gameTime                   │
└─────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────┐
│                 TIER 2: LOCAL DEVICE                     │
│              (SharedPreferences + Memory)                │
│  • Quick access for recently viewed                      │
│  • Offline capability                                    │
│  • 5-minute freshness for active games                   │
└─────────────────────────────────────────────────────────┘
                            ↕
┌─────────────────────────────────────────────────────────┐
│                    TIER 3: ODDS API                      │
│               (Only when necessary)                      │
│  • Triggered by staleness checks                         │
│  • Batch updates to Firestore                           │
│  • Rate-limited per sport                               │
└─────────────────────────────────────────────────────────┘
```

## Intelligent Freshness Rules

### Game-Specific Cache Duration
```dart
Completed games: 7 days     // Rarely change
Live games: 30 seconds       // Only update scores (not odds/spreads)
Starting soon: 5 minutes     // About to start
Today's games: 1 hour        // Same day
This week: 6 hours          // Within 7 days
Future games: 1 day         // Beyond 7 days
```

### Important Notes on Live Games
- **ONLY update scores for live games** - odds and spreads don't change during play
- This significantly reduces API payload and processing time
- Live score updates should be lightweight and frequent
- Other game data (venue, teams, etc.) remains cached

## Firestore Schema

### Games Collection
```javascript
games/{gameId}:
  - gameData: {
      id: string,
      sport: string,
      homeTeam: string,
      awayTeam: string,
      gameTime: Timestamp,
      status: string,
      homeScore: number,    // Updated frequently if live
      awayScore: number,    // Updated frequently if live
      spread: number,       // Cached, rarely updated once game starts
      overUnder: number,    // Cached, rarely updated once game starts
      // ... other game data
    }
  - lastFetched: Timestamp
  - lastScoreUpdate: Timestamp  // Separate timestamp for score updates
  - lastOddsUpdate: Timestamp   // Separate timestamp for odds updates
  - sport: string (for queries)
  - gameTime: Timestamp (for queries)
  - status: string (for queries)
```

### Sport Metadata Collection
```javascript
sportMetadata/{sport}:
  - lastFullRefresh: Timestamp
  - nextScheduledRefresh: Timestamp
  - activeGamesCount: number
  - upcomingGamesCount: number
```

## Implementation Strategy

### 1. Smart Data Fetching
```dart
Future<List<GameModel>> getGamesForPeriod(String period, String sport) async {
  // Step 1: Query Firestore for games in date range
  final games = await queryFirestoreGames(period, sport);

  // Step 2: Separate live games from others
  final liveGames = games.where((g) => g.status == 'in_progress').toList();
  final otherGames = games.where((g) => g.status != 'in_progress').toList();

  // Step 3: Check if live games need score updates only
  for (final game in liveGames) {
    if (needsScoreUpdate(game)) {
      await updateLiveScoreOnly(game.id); // Lightweight update
    }
  }

  // Step 4: Check if other games need full updates
  final staleGames = otherGames.where((g) => isStale(g)).toList();
  if (staleGames.isNotEmpty) {
    await batchRefreshGames(staleGames);
  }

  return games;
}
```

### 2. Live Score Updates (Lightweight)
```dart
Future<void> updateLiveScoreOnly(String gameId) async {
  // Fetch ONLY score data from ESPN or lightweight endpoint
  final scoreData = await fetchLiveScoreOnly(gameId);

  // Update only score fields in Firestore
  await FirebaseFirestore.instance
    .collection('games')
    .doc(gameId)
    .update({
      'homeScore': scoreData.homeScore,
      'awayScore': scoreData.awayScore,
      'status': scoreData.status,
      'lastScoreUpdate': FieldValue.serverTimestamp(),
    });
}
```

### 3. Rate Limiting
```dart
class ApiRateLimiter {
  static final _lastApiCall = <String, DateTime>{};
  static final _rateLimits = {
    'NFL': Duration(minutes: 5),
    'NBA': Duration(minutes: 5),
    'MLB': Duration(minutes: 10),
    'NHL': Duration(minutes: 10),
    'SOCCER': Duration(minutes: 15),
    'LIVE_SCORES': Duration(seconds: 30), // Separate limit for live scores
  };

  static bool canMakeCall(String type) {
    final lastCall = _lastApiCall[type];
    final limit = _rateLimits[type];
    if (lastCall == null) return true;
    return DateTime.now().difference(lastCall) >= limit;
  }
}
```

## Cost Analysis

### Current System (100 users/day)
- API Calls: 100 users × 5 sports × 12 refreshes = 6,000 calls/day
- Cost: ~$30/day at $0.005/call

### Proposed System (100 users/day)
- API Calls: 5 sports × 24 refreshes = 120 calls/day
- Live Score Updates: ~50 lightweight calls/day
- Firestore Reads: 100 users × 50 reads = 5,000 reads
- Cost: ~$0.60 API + $0.02 Firestore = ~$0.62/day
- **Savings: 97% reduction in costs**

## Migration Path

### Phase 1: Foundation (Week 1)
- [x] Design caching strategy
- [ ] Add timestamp fields to Firestore schema
- [ ] Implement game-specific freshness logic
- [ ] Create lightweight score update service

### Phase 2: Firestore Integration (Week 2)
- [ ] Modify OptimizedGamesService to check Firestore first
- [ ] Implement batch update logic
- [ ] Add rate limiting for API calls
- [ ] Create background refresh service

### Phase 3: Live Score Optimization (Week 3)
- [ ] Implement separate live score fetching
- [ ] Add WebSocket support for real-time scores (future)
- [ ] Create score-only update paths
- [ ] Optimize Firestore writes for scores

### Phase 4: Testing & Optimization (Week 4)
- [ ] Load testing with simulated users
- [ ] Monitor API usage and costs
- [ ] Fine-tune freshness intervals
- [ ] Add analytics for cache hit rates

## Key Benefits

1. **97% API Cost Reduction**: From $30/day to $0.62/day
2. **Improved Performance**: Instant loads from Firestore
3. **Better UX**: No blocking API calls, background updates
4. **Scalability**: Supports thousands of users efficiently
5. **Smart Updates**: Live games get score updates only
6. **Offline Support**: Local cache for airplane mode
7. **Fixes Stale Data**: Games always show in correct timeframe

## Technical Considerations

### Why Separate Score Updates?
- Odds/spreads don't change during live games
- Score updates are 10x smaller than full game data
- Can update every 30 seconds without cost concerns
- Better user experience for live game tracking

### Firestore Query Optimization
- Use composite indexes for sport + gameTime queries
- Paginate results for large datasets
- Use `where()` clauses to minimize document reads
- Consider using Firestore bundles for common queries

### Error Handling
- Graceful fallback to cached data on API failures
- Exponential backoff for retry logic
- User notification for extended outages
- Automatic recovery when services restore

## Success Metrics

1. **API Call Reduction**: Target 95%+ reduction
2. **Cache Hit Rate**: Target 90%+ for non-live games
3. **Load Time**: < 500ms for cached data
4. **Live Score Latency**: < 45 seconds from actual game
5. **User Satisfaction**: Reduced complaints about stale data

## Future Enhancements

1. **WebSocket Integration**: Real-time updates for live games
2. **Predictive Caching**: Pre-fetch games users likely to view
3. **Edge Caching**: Use CDN for static game data
4. **Machine Learning**: Optimize refresh intervals based on usage patterns
5. **Differential Updates**: Only sync changed fields to reduce bandwidth

## Notes for Implementation

- Start with one sport (NFL) as pilot
- Monitor Firestore costs closely during rollout
- Keep existing system as fallback during migration
- Add feature flags for gradual rollout
- Document all API endpoints and rate limits
- Create dashboard for monitoring cache performance

---

*Last Updated: December 2024*
*Version: 1.0*