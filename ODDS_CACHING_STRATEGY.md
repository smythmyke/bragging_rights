# Odds API Caching Strategy

**Version**: 1.0
**Date**: 2025-01-06
**Purpose**: Conservative caching strategy for free tier app to minimize Odds API quota usage while providing "good enough" odds for entertainment picks

---

## Overview

This strategy implements time-based caching tiers that balance user experience with API quota conservation. Since this is a free entertainment app, users don't need real-time odds - they need reasonable odds for making picks.

### Key Principles

1. **On-demand fetching**: Only fetch odds when user interacts with an event
2. **Aggressive caching**: Cache for days/weeks, not hours
3. **Shared cache**: Store in Firestore so all users benefit from single API call
4. **No live odds**: Stop fetching odds once game starts (scores only via free ESPN API)
5. **Time as source of truth**: Use Odds API gameTime when available (fixes ESPN midnight issue)

---

## Cache Tier System

### Tier 1: Far Future (7+ days before game)
- **Cache Duration**: 14 days
- **Rationale**: Opening lines barely move weeks before game, users just browsing
- **API Impact**: 1 call every 2 weeks per event

### Tier 2: This Week (1-7 days before game)
- **Cache Duration**: 7 days
- **Rationale**: Lines move slowly for games days away, free tier doesn't need daily updates
- **API Impact**: 1 call per week per event

### Tier 3: Game Day (0-24 hours before game)
- **Cache Duration**: 6 hours
- **Rationale**: Users making last-minute picks, want recent odds but don't need real-time
- **API Impact**: Max 4 calls per day per event

### Tier 4: Live/In Progress (Game started)
- **Cache Duration**: NEVER REFRESH
- **Action**: Show cached odds from before kickoff (locked), update scores only via ESPN
- **Rationale**: Odds are locked once game starts, only scores matter now
- **API Impact**: 0 odds calls (only free ESPN score updates)

### Tier 5: Completed (Game finished)
- **Cache Duration**: Forever (never refresh)
- **Rationale**: Historical data never changes
- **API Impact**: 0 calls

---

## Implementation Details

### Firestore Data Structure

Store odds data in `games` collection:

```javascript
{
  // Existing game fields
  id: "mma_ufc_311_...",
  sport: "MMA",
  homeTeam: "Fighter 2",
  awayTeam: "Fighter 1",
  status: "scheduled",

  // NEW: Odds caching fields
  gameTime: Timestamp, // SOURCE OF TRUTH - from Odds API when available, else ESPN
  gameTimeSource: "odds_api" | "espn" | null,

  odds: {
    h2h: {
      home: { odds: -150, bookmaker: "DraftKings" },
      away: { odds: +130, bookmaker: "DraftKings" }
    },
    spreads: {...},
    totals: {...}
  },

  oddsLastFetched: Timestamp, // When we last fetched from Odds API
  oddsSource: "odds_api" | "espn" | null,
  oddsCacheTier: 1-5, // Which tier was used when caching

  // Existing metadata
  lastFetched: Timestamp,
  lastScoreUpdate: Timestamp
}
```

### Fetching Logic

**Trigger Point**: User opens Game Details screen

```javascript
async function getGameOdds(gameId, sport, gameTime, status) {
  // 1. Check game status
  if (status === 'live' || status === 'in_progress' || status === 'completed') {
    // Return cached odds (don't fetch)
    return getCachedOdds(gameId);
  }

  // 2. Calculate time to game
  const timeToGame = gameTime - now();
  const tier = determineCacheTier(timeToGame);

  // 3. Check Firestore cache
  const cached = await firestore.collection('games').doc(gameId).get();

  if (cached.exists && cached.data.oddsLastFetched) {
    const cacheAge = now() - cached.data.oddsLastFetched;
    const cacheDuration = getCacheDuration(tier);

    // If cache is fresh, use it
    if (cacheAge < cacheDuration) {
      console.log(`✅ Using cached odds (age: ${cacheAge}, tier: ${tier})`);
      return cached.data.odds;
    }
  }

  // 4. Check Odds API quota
  if (!quotaManager.canMakeRequest(sport)) {
    console.log('⚠️ Quota exceeded - using stale cache or showing without odds');
    return cached?.data?.odds || null; // Return stale cache or null
  }

  // 5. Fetch from Odds API
  const oddsData = await oddsApiService.getMatchOdds({
    sport: sport,
    homeTeam: game.homeTeam,
    awayTeam: game.awayTeam,
    gameDate: gameTime
  });

  if (oddsData) {
    // 6. Save to Firestore cache
    await firestore.collection('games').doc(gameId).update({
      odds: oddsData.odds,
      gameTime: oddsData.commence_time, // Use Odds API time as source of truth
      gameTimeSource: 'odds_api',
      oddsLastFetched: serverTimestamp(),
      oddsSource: 'odds_api',
      oddsCacheTier: tier
    });

    // 7. Record quota usage
    await quotaManager.recordUsage(sport);

    return oddsData.odds;
  }

  // 8. Fallback to cached or null
  return cached?.data?.odds || null;
}
```

### Cache Duration Calculation

```javascript
function getCacheDuration(tier) {
  switch(tier) {
    case 1: return 14 * 24 * 60 * 60 * 1000; // 14 days
    case 2: return 7 * 24 * 60 * 60 * 1000;  // 7 days
    case 3: return 6 * 60 * 60 * 1000;       // 6 hours
    case 4: return Infinity;                 // Never refresh (live)
    case 5: return Infinity;                 // Never refresh (completed)
  }
}

function determineCacheTier(timeToGame) {
  if (timeToGame < 0) return 4; // Game started (live)
  if (timeToGame <= 24 * 60 * 60 * 1000) return 3; // 0-24 hours
  if (timeToGame <= 7 * 24 * 60 * 60 * 1000) return 2; // 1-7 days
  return 1; // 7+ days
}
```

---

## Game Time Source of Truth

### Problem
- ESPN API returns MMA events with date at midnight: `"2025-10-08T00:00Z"`
- Odds API returns actual event time: `"2025-10-08T19:00Z"` (7 PM)
- This causes display of two different times in UI

### Solution
Always prioritize Odds API time when available:

1. **When fetching odds**: Save `commence_time` from Odds API as `gameTime`
2. **Mark source**: Set `gameTimeSource: "odds_api"`
3. **Display logic**: Use `gameTime` regardless of source
4. **Fallback**: If no odds fetched, use ESPN time (midnight) with `gameTimeSource: "espn"`

```javascript
// Display logic
if (game.gameTimeSource === 'odds_api') {
  // Show time confidently
  showTime(game.gameTime); // "Tomorrow 19:00" ✅
} else if (game.gameTimeSource === 'espn') {
  // Show date only (ESPN gives midnight, which is inaccurate)
  showDateOnly(game.gameTime); // "Tomorrow" (hide time) ✅
} else {
  // Unknown source
  showDateOnly(game.gameTime);
}
```

---

## Quota Impact Analysis

### Current State (No Caching)
- Every user viewing event = 1 API call
- 100 users view MMA event = 100 calls
- Monthly limit: 1,000 calls for MMA
- Quota exhausted after ~10 users per event

### With Conservative Caching
- First user views event 10 days out = 1 API call (cached 7 days)
- Next 1,000 users for 7 days = 0 API calls (use cache)
- Game day: Refresh once every 6 hours = 4 calls max
- **Total per event**: ~5-10 calls vs 1,000+ calls

### Projected Savings
- **Before**: 20,000 monthly quota → ~200 events
- **After**: 20,000 monthly quota → ~2,000-4,000 events
- **10-20x efficiency improvement**

---

## User Experience

### Free Tier Users
- ✅ Get odds for making picks
- ✅ Odds are "good enough" for entertainment
- ✅ Don't see confusing midnight times for MMA events
- ⚠️ May see slightly outdated odds (acceptable for free tier)
- ⚠️ Don't get live in-game odds updates (scores update via ESPN)

### Premium Tier Users (Future)
Same caching strategy - premium features are:
- Advanced pick types (spreads, totals, props)
- Detailed analytics and intel
- Pool customization
- NOT real-time odds (still cached)

---

## Edge Cases

### Quota Exhausted Mid-Month
- Show stale cached odds with indicator: "Odds from 2 days ago"
- Or show games without odds
- Users can still make picks based on team records/intel

### First-Time Event Load (No Cache)
- Fetch odds immediately when user opens Game Details
- Show loading spinner while fetching
- If fetch fails, show without odds

### Rapid Line Movement (Injury News)
- Free tier won't catch rapid changes (by design)
- Conservative cache means odds may be hours/days old
- Acceptable tradeoff for free entertainment app

### Multiple Sports Quota Conflicts
- OddsQuotaManager already handles per-sport allocations
- MMA: 1,000 calls/month
- If MMA exhausted but NFL has quota, NFL still works

---

## Implementation Checklist

### Phase 1: Core Caching
- [ ] Add odds caching fields to Firestore game documents
- [ ] Implement cache tier calculation based on time-to-game
- [ ] Add cache freshness check in game details screen
- [ ] Implement Odds API fetch with Firestore save
- [ ] Add quota check before fetching

### Phase 2: Time Source of Truth
- [ ] Save Odds API `commence_time` as `gameTime` when fetching odds
- [ ] Add `gameTimeSource` field to track where time came from
- [ ] Update UI to use `gameTime` from Firestore
- [ ] Implement fallback display logic (hide time if source is ESPN midnight)

### Phase 3: Live Game Handling
- [ ] Stop fetching odds for live/completed games
- [ ] Show cached odds with "locked" indicator
- [ ] Update scores only via ESPN (existing score update logic)

### Phase 4: Monitoring
- [ ] Add logging for cache hits/misses
- [ ] Track quota usage per sport
- [ ] Monitor average cache age
- [ ] Alert if quota approaching limit

---

## Testing Plan

### Test Scenarios

1. **Far Future Event (14+ days)**
   - Open event → Verify fetch → Close app
   - Reopen after 5 days → Verify uses cache (no fetch)
   - Reopen after 15 days → Verify new fetch

2. **This Week Event (3 days away)**
   - Open event → Verify fetch → Close app
   - Reopen after 2 days → Verify uses cache
   - Reopen after 8 days → Verify new fetch

3. **Game Day Event (12 hours away)**
   - Open event → Verify fetch → Close app
   - Reopen after 3 hours → Verify uses cache
   - Reopen after 7 hours → Verify new fetch

4. **Live Game**
   - Open live game → Verify NO odds fetch
   - Verify shows cached odds from before kickoff
   - Verify scores update via ESPN

5. **Quota Exhausted**
   - Exhaust quota via admin override
   - Open event with no cache → Verify shows without odds
   - Open event with stale cache → Verify shows stale odds

6. **MMA Time Fix**
   - View MMA event with cached odds → Verify shows 7 PM (not midnight)
   - View MMA event without odds → Verify shows date only

---

## Rollout Strategy

### Stage 1: Silent Deploy
- Deploy caching logic
- Monitor for 1 week
- Track quota savings vs previous week

### Stage 2: Validate
- Verify quota usage decreased
- Check for any UI bugs
- Ensure odds display correctly

### Stage 3: Optimize
- Adjust cache durations if needed
- Fix any edge cases discovered
- Update quota allocations if needed

---

## Success Metrics

- **Quota efficiency**: 10x+ reduction in Odds API calls
- **Cache hit rate**: >80% of game detail views use cached odds
- **User experience**: No increase in "missing odds" complaints
- **Time accuracy**: MMA events show correct time (not midnight)

---

## Future Enhancements

### Dynamic Cache Adjustment
Adjust cache duration based on:
- Quota remaining (extend cache if running low)
- Sport popularity (cache popular sports longer)
- Time of season (cache more during playoffs)

### Predictive Caching
Pre-cache odds for:
- Featured games
- Games with high pool participation
- User's favorite teams

### Premium Real-Time Odds
For paid users:
- Shorter cache durations (1-2 hours)
- Live odds updates during game
- Push notifications for line movements

---

**Document Owner**: Development Team
**Last Updated**: 2025-01-06
**Next Review**: After implementation
