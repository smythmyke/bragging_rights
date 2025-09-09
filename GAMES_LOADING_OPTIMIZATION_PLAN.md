# Games Loading Optimization Plan

## Current Performance Issues

### Problem Summary
The app is taking too long to load initial games data on startup, fetching 647 games across 4 sports with a 60-day lookahead when only 12 featured games are displayed initially.

### Current Loading Metrics
- **NFL**: 100 games loaded
- **NBA**: 100 games loaded  
- **NHL**: 347 games loaded
- **MLB**: 100 games loaded
- **Total**: 647 games fetched on startup
- **Displayed**: Only 12 featured games shown

### Issues Identified

1. **Excessive Data Volume**
   - Loading 60 days of games for all sports on startup
   - 647 games fetched when only 12 are needed initially
   - Users typically only need today/this week's games immediately

2. **Firestore Document Size Limit Exceeded**
   - NHL data: 1,382,564 bytes (exceeds 1MB limit)
   - MLB data: 1,322,979 bytes (exceeds 1MB limit)
   - Cache writes failing, forcing re-fetches

3. **Sequential API Calls**
   - Each sport fetched one after another
   - Total time = NFL + NBA + NHL + MLB
   - No parallelization

4. **Betting Odds API Errors**
   - Repeated 422 errors for event-specific odds
   - Invalid or expired event IDs
   - No error handling to stop retries

## Optimization Strategy

### Phase 1: Reduce Initial Load (Immediate Impact)

#### 1.1 Reduce Lookahead Period
```dart
// Change from:
const int DAYS_AHEAD = 60;

// To:
const int INITIAL_DAYS_AHEAD = 14;  // 2 weeks
const int EXTENDED_DAYS_AHEAD = 60; // Load on-demand
```

**Expected Impact**: 
- Reduce data by ~75% (14 days vs 60 days)
- NHL: ~80 games instead of 347
- Total: ~150 games instead of 647

#### 1.2 Implement Progressive Loading
```dart
// Priority order:
1. Live games (immediate)
2. Today's games (immediate)
3. This week (1-2 seconds)
4. Next week (background)
5. Extended (on-demand/scroll)
```

### Phase 2: Parallel Loading

#### 2.1 Concurrent Sport Fetching
```dart
// Instead of sequential:
final nfl = await _loadNflGames();
final nba = await _loadNbaGames();
final nhl = await _loadNhlGames();
final mlb = await _loadMlbGames();

// Use parallel:
final results = await Future.wait([
  _loadNflGames(),
  _loadNbaGames(),
  _loadNhlGames(),
  _loadMlbGames(),
]);
```

**Expected Impact**: 
- Load time = MAX(NFL, NBA, NHL, MLB) instead of SUM
- ~4x faster for API calls

### Phase 3: Fix Caching

#### 3.1 Split Large Documents
```dart
// Instead of one document per sport:
'games/nhl_range_20250909_20251108' // 1.3MB - FAILS

// Split by week:
'games/nhl_week_2025_37' // ~200KB
'games/nhl_week_2025_38' // ~200KB
'games/nhl_week_2025_39' // ~200KB
```

#### 3.2 Implement Tiered Caching
- Memory cache: Immediate (current session)
- Firestore: 5-10 minute TTL (cross-session)
- API: On cache miss or expiry

### Phase 4: Fix Odds API Issues

#### 4.1 Validate Event IDs
```dart
// Check if event ID matches Odds API format
bool isValidOddsEventId(String eventId) {
  // ESPN IDs like "401697075" may need conversion
  // Or use commence_time matching instead
}
```

#### 4.2 Stop Retry on 422
```dart
if (response.statusCode == 422) {
  // Invalid event - don't retry
  return OddsData.empty();
}
```

#### 4.3 Use Batch Odds Fetching
```dart
// Instead of per-event:
/events/{eventId}/odds

// Use sport-wide with filtering:
/sports/{sport}/odds?eventIds=id1,id2,id3
```

## Implementation Priority

### Quick Wins (Today)
1. ✅ Reduce lookahead from 60 to 14 days
2. ✅ Stop retrying 422 errors
3. ✅ Implement parallel sport loading

### Medium Term (This Week)
4. Progressive loading (today → week → extended)
5. Fix Firestore document splitting
6. Implement memory caching layer

### Long Term (Next Sprint)
7. Smart prefetching based on user patterns
8. Differential updates (only fetch changes)
9. WebSocket for live game updates

## Expected Results

### Before Optimization
- Initial load: 647 games
- Load time: ~8-10 seconds
- Cache failures: NHL, MLB
- API errors: Continuous 422s

### After Optimization
- Initial load: ~150 games
- Load time: ~2-3 seconds
- Cache success: All sports
- API errors: Handled gracefully

### Performance Metrics to Track
- Time to first game displayed
- Time to interactive
- API calls per session
- Cache hit rate
- Error rate

## Testing Plan

1. Measure current baseline metrics
2. Implement Phase 1 optimizations
3. Measure improvement
4. Deploy if >50% improvement
5. Iterate through remaining phases

## Rollback Plan

Feature flag for easy rollback:
```dart
const bool USE_OPTIMIZED_LOADING_V2 = true;
```

If issues occur, flip flag to restore original behavior while fixing.