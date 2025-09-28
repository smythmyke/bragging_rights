# Boxing Data API Integration Plan

## Overview
Integration strategy for Boxing Data API (RapidAPI) with aggressive caching to maximize value from 100 calls/month free tier.

## API Limitations & Strategy

### Free Tier Constraints
- **100 API calls per month**
- **Rate limiting** (likely 1-2 requests/second)
- **No real-time odds** (still need The Odds API)

### Our Advantages
- **14-day forward window** - Only need data for upcoming fights
- **Firestore shared cache** - All users share same cached data
- **The Odds API** - Primary source for fights and odds (unlimited)

## Monthly API Budget Allocation

```
10 calls - New fighter profiles (5-10 new fighters/month in 14-day window)
5 calls  - Title holder updates (monthly refresh)
10 calls - Main event enrichment (detailed stats for big fights)
75 calls - Reserve/Buffer for unexpected needs
---------
100 calls TOTAL
```

## Caching Strategy

### Cache Durations
```javascript
{
  'fighter_profile': 30 days,    // Records, bio, image
  'fighter_stats': 30 days,      // Career statistics
  'division_info': 365 days,     // Weight classes (rarely change)
  'title_holders': 7 days,       // Current champions
  'historical_fight': Forever,   // Past fights never change
}
```

### Why 30 Days for Fighters?
- Fighters rarely appear twice in a 14-day window
- After 30 days, they've cycled out of our view
- Keeps cache size manageable

## Architecture

### 1. Centralized Cloud Function (Recommended)
```javascript
// Runs daily at 3 AM
exports.updateBoxingCache = functions.pubsub
  .schedule('0 3 * * *')
  .onRun(async () => {
    // 1. Get next 14 days of fights from Odds API (free)
    const upcomingFights = await getOddsAPIFights();

    // 2. Extract unique fighters
    const fighters = extractUniqueFighters(upcomingFights);

    // 3. Check who's missing from cache
    const newFighters = await findUncachedFighters(fighters);

    // 4. Fetch up to 3 new profiles per day (budget management)
    for (const fighter of newFighters.slice(0, 3)) {
      if (monthlyCallsUsed < 80) { // Keep 20 in reserve
        const profile = await BoxingDataAPI.getFighter(fighter);
        await firestore.collection('boxing_cache')
          .doc(fighter)
          .set({
            data: profile,
            cachedAt: Date.now(),
            expiresAt: Date.now() + (30 * 24 * 60 * 60 * 1000)
          });
        monthlyCallsUsed++;
      }
    }
  });
```

### 2. Client-Side Service
```dart
class BoxingEnhancementService {
  // Always check cache first
  Future<FighterProfile?> getFighterProfile(String name) async {
    // 1. Check Firestore cache (no API call)
    final cached = await firestore
      .collection('boxing_cache')
      .doc(name.toLowerCase())
      .get();

    if (cached.exists && !isExpired(cached.data)) {
      return FighterProfile.fromCache(cached.data);
    }

    // 2. Return null if no cache (don't make API call from client)
    return null;
  }
}
```

## UI Graceful Degradation

### Principle: Hide, Don't Show Empty

```dart
Widget buildFighterCard(BoxingFight fight) {
  return Column(
    children: [
      // ALWAYS SHOWN (from Odds API - always available)
      Text(fight.fighter1Name),
      Text('vs'),
      Text(fight.fighter2Name),
      Text('Odds: ${fight.fighter1Odds}'),

      // CONDITIONALLY SHOWN (from Boxing Data API cache)
      if (fight.fighter1Record != null)
        Text(fight.fighter1Record),  // "32-2-1"

      if (fight.fighter1Image != null)
        NetworkImage(fight.fighter1Image)
      // No else - don't show placeholder

      if (fight.weightClass != null)
        Text(fight.weightClass),

      if (fight.titleBelts.isNotEmpty)
        BeltIcons(fight.titleBelts),
    ],
  );
}
```

### Never Show
- ❌ "N/A" or "Unknown"
- ❌ Loading placeholders for missing data
- ❌ Empty image placeholders
- ❌ Grayed out fields

### Always Show
- ✅ Fighter names (from Odds API)
- ✅ Betting odds (from Odds API)
- ✅ Fight date/time (from Odds API)

## Implementation Phases

### Phase 1: Basic Integration (Week 1)
1. Set up RapidAPI authentication
2. Create Firestore cache collection
3. Implement basic fighter profile fetching
4. Add usage tracking

### Phase 2: Smart Caching (Week 2)
1. Implement Cloud Function for daily updates
2. Add cache expiration logic
3. Build fallback system
4. Test with 14-day window

### Phase 3: UI Integration (Week 3)
1. Update fighter cards with conditional rendering
2. Add graceful degradation
3. Remove all placeholder/empty states
4. Test with exhausted API scenario

## Cost Analysis

### Monthly Costs
- **Boxing Data API**: $0 (free tier, 100 calls)
- **The Odds API**: $0 (free tier, 500 calls)
- **Firestore Reads**: ~$0.06 per 100k reads
- **Cloud Functions**: ~$0 (within free tier)

### Serving Capacity
- **100 API calls** → **Unlimited users**
- Each user reads from shared cache
- No per-user API consumption

## Success Metrics

1. **API Usage**: Stay under 80 calls/month (20 buffer)
2. **Cache Hit Rate**: >95% for active fighters
3. **UI Completeness**: Never show empty fields
4. **User Experience**: Seamless degradation when API exhausted

## Example Monthly Usage Pattern

```
Week 1:
- New fighters detected: 3
- API calls used: 3
- Cache hits: 150

Week 2:
- New fighters detected: 2
- API calls used: 2
- Title holder update: 1
- Cache hits: 200

Week 3:
- New fighters detected: 4
- API calls used: 4
- Cache hits: 180

Week 4:
- New fighters detected: 2
- API calls used: 2
- Monthly refresh: 5
- Cache hits: 220

Total: 17 calls used, 83 remaining
Cache hit rate: 97.7%
```

## Fallback Strategy

When API calls exhausted:
1. Continue showing all Odds API data (names, odds, dates)
2. Hide all Boxing Data API fields (records, images, stats)
3. Log event for monitoring
4. Send alert if consistently hitting limits

## Code References

- **Cache Service**: `lib/services/boxing_data_cache_service.dart`
- **Cloud Function**: `functions/boxing_cache_updater.js`
- **Fighter Model**: `lib/models/boxing_fighter_model.dart`
- **UI Components**: `lib/widgets/fighter_card.dart`

## Notes

- The 14-day window dramatically reduces our data needs
- Most fighters won't appear twice in a month
- Cloud Functions ensure no user ever triggers an API call
- UI gracefully degrades without showing broken states
- 100 calls/month is sufficient with proper caching