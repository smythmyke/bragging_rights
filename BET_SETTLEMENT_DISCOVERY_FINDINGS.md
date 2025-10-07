# Bet Settlement Discovery Findings

**Date**: 2025-10-06
**Status**: Phase 1 Discovery Complete ✅

## Executive Summary

✅ **Cloud Functions ARE deployed and active**
❌ **But there's a critical data structure mismatch preventing settlement**

The `settleGameBets` function is deployed and triggers correctly, but bets remain pending due to incompatible data schemas between the Flutter app and Cloud Function expectations.

---

## Deployed Functions (51 total)

### Bet Settlement Functions ✅
- `settleGameBets` - **Firestore trigger** on `games/{gameId}` document.update
- `manualSettleGame` - **Callable** for manual settlement
- `cancelBet` - **Callable** for bet cancellation
- `onBetSettled` - **Firestore trigger** when bet status changes
- `onBetSettledNotification` - **Firestore trigger** sends notifications
- `getUserStats` - **Callable** retrieves user bet statistics

### Other Active Functions
- `weeklyAllowance` - **Scheduled** (Monday 9 AM) - weekly BR allowance
- `updateLiveGames` - **Scheduled** - live score updates
- `updateGameSchedules` - **Scheduled** - fetch upcoming games
- `monitorCombatSportsResults` - **Scheduled** - combat sports settlement
- `manualCombatSettlement` - **HTTPS** - manual combat settlement
- 40+ other functions for leaderboards, notifications, sports data, etc.

---

## Critical Finding: Data Structure Mismatch 🔴

### What Cloud Function Expects (index.js lines 136-225)

```javascript
// Bet document structure expected by settleGameBets
{
  gameId: string,
  userId: string,
  status: 'pending' | 'won' | 'lost' | 'push' | 'cancelled',
  betType: 'moneyline' | 'spread' | 'total' | 'prop',  // ❌ MISSING
  selection: 'home' | 'away' | 'over' | 'under',       // ❌ MISSING
  odds: number,                                         // ❌ MISSING
  line: number,                  // for spread/total    // ❌ MISSING
  wagerAmount: number,
  // ... other fields
}
```

### What Flutter App Stores (bet_service.dart lines 36-49)

```dart
// Actual bet document structure from app
{
  'userId': string,
  'gameId': string,
  'gameTitle': string,
  'sport': string,
  'poolName': string,                                   // ✅ Extra field
  'bets': [                                             // ✅ Array structure
    {
      'title': string,
      'selection': string,  // ✅ Here, not at root
      'odds': string,        // ✅ Here, not at root
      'type': string,        // ✅ Here, not at root
      'line': string?,       // ✅ Here, not at root
    }
  ],
  'wagerAmount': number,
  'totalOdds': number,
  'potentialPayout': number,
  'status': 'pending',
  'placedAt': timestamp,
  'isParlay': bool,
}
```

### The Problem

1. **Cloud Function expects**: `betType`, `selection`, `odds`, `line` **at root level**
2. **App stores them**: Inside `bets[]` array
3. **Result**: Cloud Function runs but can't read bet details → **bets stay pending**

---

## Additional Findings

### Game Data Structure Issue

Cloud Function expects game with `result` field (index.js line 138-146):

```javascript
// Expected
{
  status: 'final',
  result: {
    winner: 'home' | 'away',
    homeScore: number,
    awayScore: number
  }
}
```

Need to verify if `optimized_games_service.dart` stores games with this structure when marking them as `status: 'final'`.

### Settlement Trigger Works ✅

From logs (2025-10-07 03:41:52):
```
settleGameBets: Function execution started
settleGameBets: Function execution took 6 ms, finished with status: 'ok'
```

The function **IS** triggering when games update, it's just failing silently due to data mismatch.

---

## Root Cause Analysis

### Why Bets Stay Pending

1. Game finishes → `status` changes to `'final'`
2. `settleGameBets` Cloud Function triggers ✅
3. Function queries for pending bets ✅
4. Function tries to read `bet.betType` ❌ **undefined** (doesn't exist)
5. Function can't determine outcome → bet stays pending
6. No error thrown (silent failure)

### Why No Errors Shown

The Cloud Function uses defensive coding:
```javascript
if (!result || !result.winner) {
  return { status: 'cancelled', note: 'Game cancelled or no result available' };
}
```

If `betType` is undefined, it likely hits the `default:` case and returns an error status, but the bet document isn't updated properly.

---

## Solutions

### Option 1: Update Cloud Function (Recommended)

Modify `functions/index.js` to read from `bets[]` array:

```javascript
function determineBetOutcome(bet, gameData) {
  // Support new app structure with bets[] array
  if (bet.bets && bet.bets.length > 0) {
    const betDetail = bet.bets[0]; // For non-parlays
    const betType = betDetail.type;  // 'moneyline', 'spread', etc.
    const selection = betDetail.selection;
    const odds = parseFloat(betDetail.odds);
    const line = betDetail.line ? parseFloat(betDetail.line) : 0;

    // Now proceed with existing logic
    // ...
  }

  // Fallback to old structure for backward compatibility
  const betType = bet.betType || bet.bets?.[0]?.type;
  // ...
}
```

**Pros:**
- Fixes all existing pending bets
- No app changes needed
- Backward compatible

**Cons:**
- Requires Cloud Functions deployment
- Need to test thoroughly

### Option 2: Update Flutter App

Modify `bet_service.dart` to flatten bet structure:

```dart
await _firestore.collection('bets').doc(betId).set({
  'userId': _userId,
  'gameId': gameId,
  // Add root-level fields for Cloud Function
  'betType': bets.first.type,        // NEW
  'selection': bets.first.selection, // NEW
  'odds': double.parse(bets.first.odds), // NEW
  'line': bets.first.line != null ? double.parse(bets.first.line!) : null, // NEW
  // Keep existing structure
  'bets': bets.map((b) => b.toMap()).toList(),
  'wagerAmount': wagerAmount,
  // ...
});
```

**Pros:**
- No Cloud Functions changes
- Future bets will settle

**Cons:**
- Doesn't fix existing pending bets
- Breaks parlay support (multiple bets)
- Changes app architecture

### Option 3: Hybrid Approach (Best)

1. Update Cloud Function to support both structures
2. Update app to add root-level fields for single bets
3. Handle parlays specially in Cloud Function
4. Manually settle existing pending bets using `manualSettleGame`

---

## Game Result Structure Verification Needed

**Action Required**: Check if `optimized_games_service.dart` stores games correctly when they finish.

Expected Firestore document when game ends:
```javascript
{
  id: 'game123',
  status: 'final',  // ✅ This triggers settleGameBets
  homeTeam: 'Team A',
  awayTeam: 'Team B',
  homeScore: 105,  // ✅ Needed
  awayScore: 98,   // ✅ Needed
  result: {        // ❌ Check if this exists
    winner: 'home',    // or 'away'
    homeScore: 105,
    awayScore: 98
  }
}
```

If `result` object doesn't exist, Cloud Function will mark all bets as `cancelled`.

---

## Testing Plan

### Step 1: Verify Game Structure
```dart
// Check Firestore for a completed game
games/{gameId} where status == 'final'

// Verify fields exist:
- homeScore
- awayScore
- result.winner (or calculate from scores)
```

### Step 2: Manual Test Settlement

Use `manualSettleGame` callable function:
```dart
final manualSettle = FirebaseFunctions.instance.httpsCallable('manualSettleGame');
final result = await manualSettle.call({'gameId': 'test_game_id'});
print(result.data);
```

### Step 3: Update Cloud Function

Modify `determineBetOutcome()` to support `bets[]` array structure.

### Step 4: Redeploy and Test

```bash
cd functions
firebase deploy --only functions:settleGameBets
```

### Step 5: Verify Settlement

- Place test bet
- Manually update game to status='final'
- Check if bet status updates to 'won' or 'lost'
- Verify wallet balance updates

---

## Immediate Actions Needed

### 1. Check Game Structure ⏳
```dart
// In Flutter app or Firestore Console
// Find a completed game and verify structure
```

### 2. Check Existing Pending Bets ⏳
```dart
// Query Firestore
bets
  .where('status', '==', 'pending')
  .get()

// Document:
// - How many pending bets exist?
// - Are any games actually completed?
// - What's the bet structure?
```

### 3. Update Cloud Function ⏳
Based on findings, modify `functions/index.js` to:
- Read from `bets[]` array
- Calculate `result.winner` if not present
- Add better error logging

### 4. Add Logging ⏳
Update Cloud Function to log:
```javascript
console.log('Bet structure:', JSON.stringify(bet, null, 2));
console.log('Game structure:', JSON.stringify(gameData, null, 2));
console.log('Bet outcome:', betResult);
```

---

## Questions for User

1. **How many pending bets currently exist in production?**
   - Need to know scope of issue

2. **Are there completed games with pending bets?**
   - If yes, need to manually settle them after fix

3. **Do we support parlays?**
   - If yes, Cloud Function needs special handling for `bets[]` array with multiple items

4. **What's in the `result` field of completed games?**
   - Check Firestore Console for game with `status='final'`

5. **Priority: Fix existing bets or just future ones?**
   - Existing: Need manual settlement after fix
   - Future only: Just deploy updated Cloud Function

---

## Cost Analysis

Current Cloud Functions usage is well within free tier:
- **Free tier**: 2M invocations/month
- **Estimated usage**: ~1000-2000 invocations/month
- **Cost**: $0 (free tier covers it)

Settlement functions are efficient (5-6ms execution time).

---

## Next Steps

### Option A: Full Investigation First (Recommended)
1. Check Firestore for completed games and pending bets
2. Verify game `result` structure
3. Document exact data structures
4. Design comprehensive fix
5. Test locally with emulator
6. Deploy to production

### Option B: Quick Fix Now
1. Update Cloud Function immediately to support `bets[]` array
2. Deploy
3. Test with new bet
4. Manually settle existing pending bets

### Option C: Client-Side Settlement
1. Don't fix Cloud Function
2. Add manual settlement button to app
3. Call `manualSettleGame` when user clicks
4. Simpler but requires user action

---

## Conclusion

**The good news:**
- Settlement infrastructure exists and is active ✅
- Functions are deployed and triggering correctly ✅
- Cost is zero (within free tier) ✅

**The bad news:**
- Data structure mismatch prevents automatic settlement ❌
- Bets are staying pending indefinitely ❌
- Silent failure (no visible errors) ❌

**The fix:**
Relatively simple - update Cloud Function to read from `bets[]` array instead of expecting root-level fields. Estimated effort: 1-2 hours including testing.

**Recommendation:**
Proceed with **Option 1** (Update Cloud Function) using **Hybrid Approach** for best long-term solution.
