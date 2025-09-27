# API Call Optimization Plan - Bragging Rights App

## 📋 Table of Contents
1. [Current State Analysis](#current-state-analysis)
2. [Verification & Audit Phase](#verification--audit-phase)
3. [Sport-by-Sport Breakdown](#sport-by-sport-breakdown)
4. [Critical Issues Identified](#critical-issues-identified)
5. [Optimization Strategy](#optimization-strategy)
6. [Implementation Plan](#implementation-plan)
7. [Success Metrics](#success-metrics)

---

## Current State Analysis

### API Call Volume
- **101 HTTP requests** identified across 29 service files
- Multiple services making parallel calls to same endpoints
- EdgeCacheService exists but underutilized
- No unified caching strategy across sports

### Existing Caching Infrastructure
1. **EdgeCacheService** - Multi-tier caching system:
   - Memory cache (local, fastest)
   - Firestore cache (shared across users)
   - Sport-specific TTLs configured (basketball only)

2. **Current TTL Settings** (Basketball example):
   - PreGame: 30min-1hr cache
   - Live Game: 2-5min cache
   - Clutch Time: 1min cache
   - Post Game: 24hr cache

---

## 🔍 Verification & Audit Phase

### ⚠️ **CRITICAL: Complete ALL verification steps before making ANY changes**

### Phase 1: Documentation & Baseline (Week 1)

#### 1.1 API Inventory Audit
- [ ] Document every API endpoint currently in use
- [ ] Record average response times for each endpoint
- [ ] Measure current API call frequency per user session
- [ ] Calculate current monthly API costs
- [ ] Create API dependency map showing which screens use which endpoints

#### 1.2 Cache Analysis
- [ ] Audit existing cache implementations
- [ ] Measure current cache hit/miss ratios
- [ ] Document cache key patterns in use
- [ ] Identify orphaned cache entries
- [ ] Review Firestore usage and costs

#### 1.3 User Behavior Analysis
- [ ] Track most viewed sports/games
- [ ] Identify peak usage times
- [ ] Document user navigation patterns
- [ ] Measure average session duration
- [ ] Identify most common user flows

### Phase 2: Testing & Validation (Week 2)

#### 2.1 Create Test Suite
```dart
// Test file: test/api_optimization_tests.dart
class ApiOptimizationTests {
  // Test current API response times
  test('measure_mlb_api_response_time')
  test('measure_nfl_api_response_time')
  test('measure_cache_performance')

  // Test data accuracy
  test('verify_cached_data_matches_live')
  test('verify_ttl_expiration')

  // Load tests
  test('simulate_100_concurrent_users')
  test('measure_firestore_read_costs')
}
```

#### 2.2 Create Monitoring Dashboard
- [ ] Setup API call tracking
- [ ] Create cache hit rate monitoring
- [ ] Add cost tracking dashboard
- [ ] Setup alerts for API failures
- [ ] Monitor user experience metrics

#### 2.3 Backup & Rollback Plan
- [ ] Create full backup of current codebase
- [ ] Document current API configurations
- [ ] Setup feature flags for gradual rollout
- [ ] Create rollback procedures
- [ ] Test rollback process in staging

### Phase 3: Verification Checklist

Before implementing ANY optimization:

- [ ] **Performance Baseline**: Document current performance metrics
- [ ] **Cost Baseline**: Record current monthly API/Firestore costs
- [ ] **User Impact**: Verify no degradation in user experience
- [ ] **Data Accuracy**: Confirm cached data remains accurate
- [ ] **Error Handling**: Test all error scenarios
- [ ] **Staging Testing**: Complete full testing in staging environment
- [ ] **Load Testing**: Verify system handles expected load
- [ ] **Rollback Ready**: Ensure rollback plan is tested and ready

---

## Sport-by-Sport Breakdown

### ⚾ MLB
**Current State:**
- Services: `EspnMlbService`, `espn_direct_service`
- API Calls per session:
  - Home Screen: 1 call (getTodaysGames)
  - Game Details: 3-5 calls (summary, boxscore, odds, weather)
  - Live Game: 1 call/2min (refresh)
- Caching: ✅ Partial (EdgeCacheService)
- **Verification Required:** Test cache TTL appropriateness for baseball game pace

### 🏈 NFL
**Current State:**
- Services: `EspnNflService`
- API Calls per session:
  - Home: 1 call (scoreboard)
  - Details: 4 calls (summary, standings, leaders, weather)
  - Live: 1 call/2min
- Caching: ✅ Partial
- **Verification Required:** Confirm standings update frequency needs

### 🏒 NHL
**Current State:**
- Services: `EspnNhlService`, `NhlApiService`
- API Calls per session:
  - Home: 1 call
  - Details: 3 calls (summary, standings, odds)
  - Live: 1 call/2min
- Caching: ✅ Partial
- **Verification Required:** Check for duplicate data between two services

### 🏀 NBA
**Current State:**
- Services: `EspnNbaService`, `BallDontLieService`, `NbaMultiSourceService`
- API Calls per session:
  - Home: 2-3 calls (multiple sources!)
  - Details: 5+ calls
  - Live: 1 call/30sec-2min
- Caching: ⚠️ Redundant services
- **Verification Required:** Identify which service provides best data

### 🥊 MMA/Boxing
**Current State:**
- Services: `EspnMmaService`, `EspnBoxingService`, `FighterDataService`
- API Calls per session:
  - Event List: 2 calls
  - Fighter Details: 3-4 calls (stats, images, records)
  - Fight Card: 2 calls
- Caching: ❌ Limited (fighter images only)
- **Verification Required:** Test fighter data update frequency

### ⚽ Soccer
**Current State:**
- Services: Various ESPN endpoints
- API Calls per session: Similar to other sports
- Caching: Partial
- **Verification Required:** International match time zones handling

---

## Critical Issues Identified

### 1. Duplicate API Calls
- Multiple users viewing same game trigger separate API calls
- No shared Firestore caching for game details
- Game details screen makes 3-7 API calls on load

### 2. Missing Cache Layers
- Weather data not cached (called per user)
- Odds refreshed too frequently (every 2 min vs needed)
- Team logos fetched repeatedly

### 3. Redundant Services
- NBA has 3 different data services
- MMA/Boxing has duplicate ESPN services
- No service consolidation strategy

### 4. Inefficient Data Fetching
- No batch API calls
- No predictive pre-fetching
- No background refresh strategy

---

## Optimization Strategy

### 1. Firestore-First Architecture

**Before:**
```dart
// Direct API call for every user
final data = await http.get(ESPN_API);
```

**After:**
```dart
// Check Firestore first, API as fallback
final data = await FirestoreCache.get(
  'games/mlb/today',
  ttl: Duration(minutes: 5),
  fallback: () => http.get(ESPN_API)
);
```

### 2. Unified Cache Keys Structure
```
sports/
├── {sport}/
│   ├── games/
│   │   ├── {date}/          # Daily games
│   │   └── {gameId}/         # Specific game
│   │       ├── details/      # Static info
│   │       ├── live/         # Live updates
│   │       └── stats/        # Statistics
│   ├── teams/
│   │   └── {teamId}/
│   │       ├── roster/
│   │       └── schedule/
│   └── cache_metadata/       # TTLs, versions
```

### 3. Sport-Specific TTL Strategy

| Sport | Pre-Game | Live (Regular) | Live (Critical) | Post-Game |
|-------|----------|----------------|-----------------|-----------|
| MLB   | 30 min   | 2 min         | 30 sec          | 24 hrs    |
| NFL   | 1 hr     | 2 min         | 30 sec          | 48 hrs    |
| NHL   | 30 min   | 1 min         | 20 sec          | 24 hrs    |
| NBA   | 15 min   | 30 sec        | 15 sec          | 24 hrs    |
| MMA   | 2 hrs    | 5 min         | 1 min           | 72 hrs    |
| Soccer| 45 min   | 1 min         | 30 sec          | 24 hrs    |

### 4. API Call Consolidation

**Current:** Multiple calls per screen
```dart
// Game Details Screen - Current
await getGameSummary(gameId);     // Call 1
await getGameBoxScore(gameId);    // Call 2
await getGameOdds(gameId);        // Call 3
await getWeather(venueId);        // Call 4
```

**Optimized:** Single batch call
```dart
// Game Details Screen - Optimized
await getGameBundle(gameId); // 1 call returns all data
```

---

## Implementation Plan

### Phase 1: Verification & Testing (Weeks 1-2)
- Complete all verification steps
- Establish baselines
- Create test suite
- Setup monitoring

### Phase 2: Core Infrastructure (Weeks 3-4)
- [ ] Create `UnifiedCacheService`
- [ ] Implement Firestore cache collections
- [ ] Setup cache warming jobs
- [ ] Add cache invalidation logic

### Phase 3: Sport-by-Sport Migration (Weeks 5-8)
Priority order based on impact:

1. **NBA** (Week 5)
   - [ ] Consolidate 3 services into 1
   - [ ] Implement aggressive caching
   - [ ] Add WebSocket for live updates

2. **Game Details Screen** (Week 6)
   - [ ] Batch API calls
   - [ ] Implement tab pre-loading
   - [ ] Cache static data (logos, venues)

3. **Home Screen** (Week 7)
   - [ ] Single API call for all sports
   - [ ] Implement predictive caching
   - [ ] Add pull-to-refresh with rate limiting

4. **NFL & MLB** (Week 8)
   - [ ] Optimize game day caching
   - [ ] Add smart TTLs based on game state
   - [ ] Implement delta updates

### Phase 4: Advanced Optimizations (Weeks 9-10)
- [ ] Implement WebSocket/SSE for live updates
- [ ] Add CDN for static assets
- [ ] Create cache pre-warming based on user patterns
- [ ] Implement intelligent cache eviction

### Phase 5: Monitoring & Optimization (Ongoing)
- [ ] A/B test cache strategies
- [ ] Fine-tune TTLs based on usage
- [ ] Monitor and optimize Firestore costs
- [ ] Regular performance audits

---

## Success Metrics

### Target Improvements
- **80% reduction** in API calls
- **95% cache hit rate** for common data
- **<100ms** response time for cached data
- **50% reduction** in monthly API costs
- **30% improvement** in app performance scores

### Monitoring KPIs
1. **Performance Metrics**
   - API calls per user session
   - Cache hit/miss ratio
   - Average response time
   - Error rates

2. **Cost Metrics**
   - Monthly API costs
   - Firestore read/write costs
   - CDN bandwidth costs

3. **User Experience Metrics**
   - Page load times
   - Time to first meaningful paint
   - User engagement rates
   - App store ratings

### Rollback Criteria
Immediate rollback if:
- Error rate increases >5%
- Response time degrades >20%
- Cache accuracy falls below 99%
- User complaints increase

---

## Risk Mitigation

### Identified Risks
1. **Cache Inconsistency**: Stale data shown to users
   - Mitigation: Implement cache versioning and validation

2. **Firestore Costs**: Increased Firestore usage
   - Mitigation: Monitor costs daily, set budget alerts

3. **API Rate Limits**: Hitting provider limits during cache warming
   - Mitigation: Implement rate limiting and backoff

4. **User Experience**: Degraded performance during migration
   - Mitigation: Feature flags for gradual rollout

---

## Appendix

### A. Test Scenarios
- New user first load
- Returning user with cache
- Live game viewing
- Multi-sport navigation
- Peak load conditions
- Network failure scenarios

### B. Cache Invalidation Events
- Game start/end
- Score changes
- Injury updates
- Lineup changes
- Odds updates
- Weather changes

### C. Emergency Procedures
1. Cache corruption: Clear and rebuild
2. API failure: Serve from cache with warning
3. Firestore outage: Fallback to direct API
4. Performance degradation: Increase TTLs temporarily

---

## Document Version
- Version: 1.0.0
- Created: 2025-01-21
- Last Updated: 2025-01-21
- Author: Development Team
- Status: DRAFT - Pending Review

## Review & Approval
- [ ] Technical Lead Review
- [ ] Architecture Review
- [ ] Cost Analysis Review
- [ ] Final Approval

---

**⚠️ REMEMBER: No changes without completing ALL verification steps!**