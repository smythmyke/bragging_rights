# Odds API Optimization & Preseason Simple Scoring Plan

## 📊 API Call & Cache Analysis Summary

### ✅ Positive Findings - Good Caching

#### 1. Firestore Game Caching Works Well
- ✅ **Loaded 254 games from CACHED Firestore data** - Excellent!
- All sports loading from cache:
  - NBA: 63 games
  - NHL: 88 games
  - MLB: 21 games
  - NFL: 29 games
  - NCAAF: 43 games
  - SOCCER: 10 games
- **No ESPN API calls made on startup** - cache is effective
- Games persist across app restarts without re-fetching

#### 2. Odds Caching Working
- ✅ `Using cached odds for Manchester City @ Brentford`
- Multiple cache hits visible in logs
- Odds data persists after initial fetch
- Reduces redundant API calls

#### 3. Old Cache Cleanup
- 🗑️ `Clearing OLD cache for MLB (games >7 days old)`
- 🗑️ `Clearing OLD cache for MMA (games >7 days old)`
- Automatic cleanup prevents stale data
- Maintains database health

---

## ❌ CRITICAL ISSUES - Quota Waste

### 1. REPEATED ODDS API CALLS FOR UNAVAILABLE GAMES

**Problem:**
```
🔍 Checking endpoint: basketball_nba_preseason
   ! No events in basketball_nba_preseason
🔍 Checking endpoint: basketball_nba
   ! No events in basketball_nba
❌ No matching event found
```

**Issues:**
- This pattern repeats **multiple times** for NBA preseason games
- **Wasting quota** checking endpoints that return empty
- Same games checked repeatedly on every navigation
- No memory of previous failed lookups

**Impact:**
- Unnecessary API calls: ~2-4 calls per preseason game
- Quota exhaustion for games that will never have odds
- Slower load times

---

### 2. NO CACHING OF "NO ODDS AVAILABLE" STATE

**Problem:**
- When a game has no odds (too far future, preseason, etc.), it **re-checks every time**
- No record that "we already looked and found nothing"

**Current Behavior:**
```
User opens game → Check Odds API → No results
User closes game
User opens same game again → Check Odds API AGAIN → No results (wasted call)
```

**Solution Needed:**
- Cache "no odds available" state for 24 hours
- Store negative results in Firestore: `{ hasOdds: false, lastChecked: timestamp }`
- Skip API calls for games marked as "no odds"

---

### 3. CHECKING ALL ENDPOINTS EVEN WHEN QUOTA EXHAUSTED

**Problem:**
- Logs show checking multiple endpoints even after quota is exhausted
- Should fail fast when quota is gone

**Current Behavior:**
```
Check endpoint 1 → Quota exhausted (402/429 error)
Check endpoint 2 → Quota exhausted (waste of time)
Check endpoint 3 → Quota exhausted (waste of time)
```

**Solution Needed:**
- Check quota **before** making any endpoint calls
- Fail fast if quota = 0
- Show user-friendly "Odds unavailable" message

---

## 🎯 Improvement Opportunities

### 1. Cache Negative Results
**Implementation:**
- Store "no odds available" state in Firestore
- Add `oddsCheckTimestamp` field to game documents
- Skip API calls if checked within last 24 hours and `hasOdds: false`

**Expected Savings:**
- 50-70% reduction in wasted API calls
- Preseason games checked once, then skipped

---

### 2. Check Quota Before Endpoint Calls
**Implementation:**
- Query quota manager **before** any `findOddsApiEventId()` call
- If quota <= 0, return cached data or "unavailable" immediately
- Don't iterate through endpoints if quota exhausted

**Expected Savings:**
- Eliminates sequential failed calls
- Faster failure response

---

### 3. Preseason Game Detection - Skip Odds API
**Implementation:**
- Check `game.seasonType == 'preseason'` **before** calling Odds API
- For preseason games:
  - Set `hasOdds: false` automatically
  - Use **Simple Scoring** system instead
  - No Odds API calls needed

**Expected Savings:**
- 100% quota savings for preseason games
- Currently: ~63 NBA preseason games × 2 calls = 126 wasted calls
- After fix: 0 calls

---

### 4. Batch Endpoint Checks - Share Results
**Implementation:**
- When fetching odds for multiple games at once
- Fetch endpoint data once, then match all games
- Store endpoint response in memory cache (5 min TTL)

**Current Behavior:**
```
Game 1: Fetch basketball_nba endpoint → 1 call
Game 2: Fetch basketball_nba endpoint AGAIN → 1 call (wasted)
Game 3: Fetch basketball_nba endpoint AGAIN → 1 call (wasted)
```

**After Optimization:**
```
Fetch basketball_nba endpoint once → 1 call
Match Game 1, Game 2, Game 3 from same response
```

**Expected Savings:**
- 60-80% reduction in endpoint fetches
- Faster parallel processing

---

## 🏈 Preseason Simple Scoring System

### Overview
Enable betting on preseason games **without requiring odds** from the Odds API by using a simple "pick the winner" system.

### System Components Already in Place

#### ✅ 1. Simple Scoring Logic Exists
**File:** `lib/services/simple_pick_scoring.dart`
- Pick winning team
- Optional confidence stars (1-5)
- Points calculation: `1.0 × confidence_multiplier`
- Multiplier range: 0.9x (1 star) to 1.3x (5 stars)

#### ✅ 2. Pool Model Supports Scoring Types
**File:** `lib/models/pool_model.dart`
- `scoringType: 'odds-based'` - Current system (requires Odds API)
- `scoringType: 'skill-based'` - Simple picks

#### ✅ 3. Game Model Tracks Season Info
**File:** `lib/models/game_model.dart`
- `seasonType: 'preseason' | 'regularSeason' | 'playoffs'`
- `seasonLabel: 'PRESEASON'`
- `hasOdds: true/false`
- `exhibitionType: 'Global Games' | 'International' | null`

---

### Implementation Plan

#### Step 1: Auto-Detect Preseason Games
**File:** `lib/services/optimized_games_service.dart`

```dart
bool useSimpleScoring(GameModel game) {
  // Use simple scoring for:
  return game.seasonType == 'preseason' ||      // NBA/NFL/NHL preseason
         game.exhibitionType != null ||          // Global games, international
         game.hasOdds == false;                  // No betting lines available
}
```

#### Step 2: Set Scoring Type on Pool Creation
**File:** `lib/services/pool_service.dart`

When creating a pool:
1. Check if game requires simple scoring
2. Set `scoringType: 'skill-based'` for preseason
3. Set `scoringType: 'odds-based'` for regular season

```dart
Future<String?> createPool({
  required GameModel game,
  // ... other params
}) async {
  final scoringType = useSimpleScoring(game)
    ? 'skill-based'
    : 'odds-based';

  // Create pool with appropriate scoring type
}
```

#### Step 3: Update Bet Selection Screen
**File:** `lib/screens/betting/bet_selection_screen.dart`

Route to appropriate UI based on pool scoring type:
- `scoringType == 'skill-based'` → Show simple pick UI
- `scoringType == 'odds-based'` → Show moneyline/spread/totals UI

```dart
Widget _buildBettingInterface() {
  if (widget.pool.scoringType == 'skill-based') {
    return _buildSimplePickUI();  // Just pick winner
  } else {
    return _buildOddsBasedUI();   // Current system
  }
}
```

#### Step 4: Create Simple Pick UI Widget
Reuse patterns from combat sports (MMA/Boxing):
- Home team button
- Away team button
- Optional confidence slider (1-5 stars)
- "PRESEASON - Simple Pick" badge

#### Step 5: Update Scoring Service
**File:** `lib/services/pool_scoring_service.dart`

Use appropriate scoring logic:
```dart
double calculateUserScore(Pool pool, List<UserPicks> picks) {
  if (pool.scoringType == 'skill-based') {
    return SimplePickScoring.calculateScore(picks);
  } else {
    return OddsBasedScoring.calculateScore(picks);
  }
}
```

#### Step 6: Update Game Cards
**File:** `lib/widgets/game_card_enhanced.dart`

Show visual indicator for preseason games:
- Badge: "PRESEASON"
- Subtitle: "Simple Pick - No Odds Required"
- Color: Different accent color (e.g., amber for preseason)

---

### Benefits

#### 1. Quota Savings
- **100% elimination** of Odds API calls for preseason games
- Current waste: ~126 calls per day for NBA preseason
- After fix: 0 calls

#### 2. User Experience
- ✅ Still enables betting on preseason games
- ✅ Simpler interface - just pick winner
- ✅ No "odds unavailable" errors
- ✅ Faster load times

#### 3. Code Reuse
- ✅ Simple scoring system already exists
- ✅ Pool model already supports it
- ✅ Combat sport UI can be adapted
- ✅ Minimal new code required

#### 4. Automatic Detection
- ✅ `seasonType` field already populated from ESPN
- ✅ No manual configuration needed
- ✅ Works for all preseason sports (NBA, NFL, NHL, MLB)

---

## 📋 Implementation Checklist

### Phase 1: Negative Result Caching (High Priority)
- [ ] Add `oddsLastChecked` timestamp field to game model
- [ ] Update `findOddsApiEventId()` to check timestamp before API call
- [ ] Store `hasOdds: false` in Firestore when no odds found
- [ ] Skip API calls for games with recent "no odds" check
- [ ] Add 24-hour TTL for negative cache

### Phase 2: Quota Check Optimization (High Priority)
- [ ] Add quota check at start of `findOddsApiEventId()`
- [ ] Return early if quota exhausted
- [ ] Show user-friendly message when quota depleted
- [ ] Log quota exhaustion for monitoring

### Phase 3: Preseason Simple Scoring (Medium Priority)
- [ ] Create `useSimpleScoring()` detection function
- [ ] Update pool creation to set `scoringType` based on game type
- [ ] Create simple pick UI widget
- [ ] Add routing logic in bet selection screen
- [ ] Update scoring service to handle both types
- [ ] Add preseason badge to game cards
- [ ] Test with NBA/NFL/NHL preseason games

### Phase 4: Batch Endpoint Optimization (Low Priority)
- [ ] Create in-memory cache for endpoint responses
- [ ] Add 5-minute TTL to cached endpoint data
- [ ] Update game enrichment to fetch endpoints once
- [ ] Share endpoint results across multiple games
- [ ] Monitor reduction in API calls

---

## 📊 Expected Impact

### Quota Savings
- **Before:** ~500-800 API calls per day
- **After:** ~150-300 API calls per day
- **Reduction:** 60-70% fewer calls

### Breakdown
- Negative caching: -30% calls
- Preseason detection: -25% calls
- Quota fail-fast: -10% calls
- Batch optimization: -5% calls

### Performance
- Faster load times (no waiting for failed API calls)
- Better user experience (no "odds unavailable" errors)
- Reduced server costs
- Extended quota lifetime

---

## 🎯 Success Metrics

### Quantitative
- API calls reduced by 60%+
- Quota lasts 3x longer
- Load time improvement: 30-50%
- Zero preseason quota waste

### Qualitative
- Users can bet on all games (preseason included)
- Clear messaging (PRESEASON badge)
- Simplified UX for simple scoring
- No confusing "odds unavailable" errors
