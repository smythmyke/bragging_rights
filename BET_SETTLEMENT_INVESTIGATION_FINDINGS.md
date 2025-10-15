# 🔍 Bet Settlement Investigation Findings

**Date**: October 13, 2025
**Issue**: Bets showing as "REFUNDED" in Past tab instead of Won/Lost
**User Affected**: JLl6AoOXHHUhIIW4t7xWDyqWsPm2 (and potentially others)

---

## Executive Summary

The diagnostic script revealed **CRITICAL ISSUES** with the bet settlement system:

- ❌ **0 bets have been properly settled** (0 won, 0 lost)
- ❌ **100% of games are stuck in 'scheduled' status** - None have transitioned to 'final'
- ❌ **10/19 bets (53%) have Game ID mismatches** - Bet gameId doesn't match actual game document ID
- ⚠️ **10/19 bets (53%) were auto-expired** by cleanup function after 30 days pending

**Root Cause**: Games are NOT getting their status updated to 'final' when they complete, preventing the Cloud Function settlement trigger from firing.

---

## Detailed Findings

### Issue #1: Games Never Marked as 'final' ❌ CRITICAL

**Evidence from diagnostic script:**
```
Games with status='final': 0
Games with betsSettled=true: 0
```

**All 9 games found in database have status: 'scheduled'**

Examples:
- `Boston Bruins @ Washington Capitals` - Game Time: Thu Oct 02 18:00 (11 days ago!) - Status: scheduled
- `Detroit Tigers @ Cleveland Guardians` - Game Time: Thu Oct 02 14:00 (11 days ago!) - Status: scheduled
- `Wolverhampton Wanderers @ Tottenham Hotspur` - Game Time: Sat Sep 27 14:00 (16 days ago!) - Status: scheduled
- `Tampa Bay Buccaneers @ Houston Texans` - Game Time: Mon Sep 15 18:01 (28 days ago!) - Status: scheduled

**Why This Is Critical:**
- The Cloud Function `settleGameBets` (functions/index.js:72) ONLY triggers when `status === 'final'`
- If games never transition to 'final', bets will NEVER be settled
- After 30 days, the cleanup function auto-expires them as "refunded"

**Root Cause Analysis:**

Looking at `optimized_games_service.dart:379`:
```dart
status: scoreData['completed'] == true ? 'final' : 'live'
```

The game status depends on the Odds API returning `completed: true` in the score data. If:
1. The Odds API doesn't return score data for old games
2. The game is never re-fetched after completion
3. The score update logic fails

Then games will remain stuck at 'scheduled' forever.

**Code Location:** `optimized_games_service.dart:323-400`

---

### Issue #2: Game ID Mismatches ❌ CRITICAL

**Evidence from diagnostic script:**
```
ID mismatches detected: 10
```

**Examples of ID mismatches:**

#### Example 1: Tampa Bay Buccaneers game
- **Bet gameId**: `NFL_Tampa Bay Buccaneers @ Houston Texans_1757948186659`
- **Actual game ID in DB**: `02522f48a7b7e7524881c1b1638cd94d`
- **Actual game teams**: New York Jets @ Tampa Bay Buccaneers ⚠️ (wrong game!)

#### Example 2: Chicago Cubs game
- **Bet gameId**: `MLB_Chicago Cubs @ Pittsburgh Pirates_1757945746653`
- **Actual game ID in DB**: `0aa60bdef2232854d1e0ed3696d910ce`
- **Actual game teams**: Chicago Cubs @ Milwaukee Brewers ⚠️ (wrong game!)

**Why This Is Critical:**
- Cloud Function query (functions/index.js:118-120): `.where('gameId', '==', gameId)`
- If the bet's `gameId` doesn't match the game document's `id`, the query returns 0 bets
- Settlement will NEVER happen for mismatched bets

**Root Cause:**

The game ID generation is inconsistent between:

1. **When user places bet** (game_details_screen.dart - needs investigation):
   - Generates IDs like: `NFL_Tampa Bay Buccaneers @ Houston Texans_1757948186659`
   - Format: `{Sport}_{AwayTeam} @ {HomeTeam}_{Timestamp}`

2. **When games are fetched from API** (optimized_games_service.dart:976):
   - Uses Odds API event ID: `id: event['id']`
   - Format: Hash string like `02522f48a7b7e7524881c1b1638cd94d`

**The bet placement is generating a CUSTOM ID that will NEVER match the API-provided ID.**

---

### Issue #3: Games Removed from Cache

**Evidence:**
```
Games NOT found: 10 (53% of bets)
```

**Why games disappeared:**
- Line 1886-1909 in `optimized_games_service.dart`: `clearSportCache()` deletes games older than 7 days
- Old bets reference games that were deleted from cache

**Impact:**
- Even if we fix the ID matching, old bets (>7 days) will fail to settle because their games no longer exist

---

### Issue #4: Cleanup Function Working as Designed

**Evidence:**
```
Expired/Refunded: 10 bets
```

The cleanup function (`functions/index.js:858-975`) is working correctly:
- Finds bets with `status == 'pending'` and `placedAt < 30 days ago`
- Marks them as `expired` and refunds the wager

**This is NOT a bug** - it's the safety mechanism for stuck bets. The real problem is upstream (Issues #1 and #2).

---

## Impact Assessment

### Current State:
- ✅ **Bet placement**: Working
- ✅ **Wallet deduction**: Working
- ❌ **Game status updates**: BROKEN - Games never become 'final'
- ❌ **Game ID consistency**: BROKEN - Bet IDs don't match game IDs
- ❌ **Bet settlement**: BROKEN - 0 bets have settled in 28+ days
- ✅ **Cleanup/refund**: Working (but shouldn't be needed)

### User Experience:
1. User places bet ✅
2. Wager deducted ✅
3. Game happens (in real life) 🏈
4. Game in app stays "scheduled" ❌
5. Bet stays "pending" for 30 days ❌
6. Cleanup function expires bet and refunds wager ✅
7. User sees "REFUNDED" in Past tab ⚠️

**Result**: Users are being refunded instead of paid winnings or marked as losses.

---

## Recommendations

### PRIORITY 1: Fix Game Status Updates (CRITICAL)

**Problem**: Games never transition from 'scheduled' to 'final'

**Solutions:**

#### Option A: Active Score Polling (Recommended)
Create a background service that periodically checks live games and updates their status:

```dart
// New file: lib/services/game_status_updater.dart
class GameStatusUpdater {
  Timer? _timer;

  void startMonitoring() {
    // Check every 5 minutes
    _timer = Timer.periodic(Duration(minutes: 5), (_) {
      _updateGameStatuses();
    });
  }

  Future<void> _updateGameStatuses() async {
    // Get all games with status 'live' or games in the past 24 hours
    final games = await _getActiveGames();

    for (final game in games) {
      // Fetch latest scores from Odds API
      final scores = await _oddsApiService.getSportScores(game.sport);
      final scoreData = scores[game.id];

      if (scoreData != null && scoreData['completed'] == true) {
        // Update game to final status in Firestore
        await _firestore.collection('games').doc(game.id).update({
          'status': 'final',
          'homeScore': scoreData['scores']['home_team'],
          'awayScore': scoreData['scores']['away_team'],
          'completedAt': FieldValue.serverTimestamp(),
        });

        debugPrint('✅ Updated game ${game.id} to final status');
      }
    }
  }
}
```

**Where to implement**: Create new service and call from `home_screen.dart` on app start

#### Option B: Cloud Function Scheduled Task
Create a Cloud Function that runs every 15 minutes to check for completed games:

```javascript
// Add to functions/index.js
exports.updateCompletedGames = functions.pubsub
  .schedule('every 15 minutes')
  .onRun(async (context) => {
    // Query games with status='live' or scheduled games in the past
    // Fetch scores from Odds API
    // Update to status='final' if completed
    // Let existing settleGameBets trigger handle settlement
  });
```

---

### PRIORITY 2: Fix Game ID Consistency (CRITICAL)

**Problem**: Bet gameId doesn't match game document ID

**Solution**: Use the game's actual Firestore document ID when creating bets

**Files to modify:**

1. **game_details_screen.dart** (needs investigation - find where bets are created)
   - Change from generating custom ID to using `game.id`
   - Ensure `game.id` passed to `BetService.placeBet()`

2. **bet_service.dart:37** - Verify gameId parameter:
```dart
await _firestore.collection('bets').doc(betId).set({
  'userId': _userId,
  'gameId': gameId,  // ← Must match game document ID
  // ...
});
```

**Before:**
```dart
final customGameId = 'NFL_${awayTeam} @ ${homeTeam}_${timestamp}';
```

**After:**
```dart
final gameId = game.id;  // Use the actual Firestore document ID
```

---

### PRIORITY 3: Prevent Cache Deletion Until Bets Settled

**Problem**: Games deleted from cache while bets still pending

**Solution**: Modify `clearSportCache()` to preserve games with pending bets

```dart
// optimized_games_service.dart:1878
Future<void> clearSportCache(String sport) async {
  // Get all game IDs that have pending bets
  final pendingBetsSnapshot = await _firestore
      .collection('bets')
      .where('sport', isEqualTo: sport.toUpperCase())
      .where('status', '==', 'pending')
      .get();

  final gameIdsWithPendingBets = pendingBetsSnapshot.docs
      .map((doc) => doc.data()['gameId'] as String)
      .toSet();

  // Only delete games older than 7 days that DON'T have pending bets
  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 7));
  final querySnapshot = await _firestore
      .collection('games')
      .where('sport', isEqualTo: sport.toUpperCase())
      .where('gameTime', isLessThan: Timestamp.fromDate(sevenDaysAgo))
      .get();

  final batch = _firestore.batch();
  int deleteCount = 0;

  for (final doc in querySnapshot.docs) {
    // Skip games with pending bets
    if (!gameIdsWithPendingBets.contains(doc.id)) {
      batch.delete(doc.reference);
      deleteCount++;
    }
  }

  if (deleteCount > 0) {
    await batch.commit();
    debugPrint('✅ Cleared $deleteCount old $sport games (preserved ${gameIdsWithPendingBets.length} games with pending bets)');
  }
}
```

---

### PRIORITY 4: Add Comprehensive Logging

**Add status transition logging to catch issues early:**

```dart
// optimized_games_service.dart:1486-1494
// Already has good logging! Just ensure it's enabled in production
```

**Add Cloud Function logging:**

```javascript
// functions/index.js - Enhance existing logs
console.log(`🎮 [SETTLEMENT] Querying bets for game ${gameId}`);
console.log(`   Query: gameId == ${gameId}, status == pending`);

const betsSnapshot = await db.collection('bets')
  .where('gameId', '==', gameId)
  .where('status', '==', 'pending')
  .get();

console.log(`📊 [SETTLEMENT] Found ${betsSnapshot.size} pending bets for game ${gameId}`);

if (betsSnapshot.empty) {
  console.log(`⚠️ [SETTLEMENT] No pending bets found - possible reasons:`);
  console.log(`   1. Bets already settled`);
  console.log(`   2. Game ID mismatch (bet gameId != game document ID)`);
  console.log(`   3. No bets were placed on this game`);
}
```

---

## Testing Plan

### Phase 1: Verify Current Issues (DONE ✅)
- [x] Run diagnostic script
- [x] Confirm 0 settled bets
- [x] Confirm game status issues
- [x] Confirm ID mismatches

### Phase 2: Fix Game ID Consistency
1. Find where bets are created (investigate game_details_screen.dart or similar)
2. Change to use `game.id` instead of custom ID
3. Place test bet
4. Verify bet document has correct gameId

### Phase 3: Implement Game Status Updater
1. Create `GameStatusUpdater` service
2. Add periodic checks for completed games
3. Test with a live game
4. Verify game transitions to 'final'
5. Verify Cloud Function settles bets

### Phase 4: Regression Testing
1. Place bets on upcoming games
2. Wait for games to complete
3. Verify:
   - Game status → 'final'
   - Bets settle automatically
   - Wallet updated correctly
   - Bets appear in Past tab with Won/Lost status

---

## Migration Strategy for Existing Bets

**For the 10 expired bets that were refunded:**
- These bets are likely on games that already completed in real life
- Games were never updated to 'final' status
- Cannot retroactively settle them accurately

**Recommendations:**
1. Keep them as 'expired' (users already refunded)
2. Document as known issue from pre-fix era
3. Focus on preventing future occurrences

**For the 9 pending bets:**
1. After fixing gameId issue, manually update their gameIds if possible
2. Or mark them as 'cancelled' with full refund
3. Focus on ensuring NEW bets work correctly

---

## Timeline Estimate

- **Priority 1 (Game Status Updates)**: 4-6 hours
- **Priority 2 (Fix Game ID)**: 2-3 hours
- **Priority 3 (Cache Protection)**: 1-2 hours
- **Priority 4 (Logging)**: 1 hour
- **Testing**: 2-3 days (need actual games to complete)

**Total**: ~8-12 hours development + 2-3 days testing

---

## Related Files

### Files Requiring Changes:
1. `bragging_rights_app/lib/services/optimized_games_service.dart` - Game status updates
2. `bragging_rights_app/lib/services/game_status_updater.dart` - NEW FILE to create
3. `bragging_rights_app/lib/screens/game/game_details_screen.dart` - Fix gameId on bet placement
4. `bragging_rights_app/lib/services/bet_service.dart` - Verify gameId usage
5. `bragging_rights_app/lib/screens/home/home_screen.dart` - Start status updater
6. `functions/index.js` - Enhanced logging (optional)

### Files Analyzed (No Changes Needed):
- ✅ `functions/index.js` - Settlement logic is correct
- ✅ `bet_service.dart` - Bet queries are correct
- ✅ `active_bets_screen.dart` - Display logic is correct
- ✅ `wallet_service.dart` - Wallet updates are correct (after migration fix)

---

## Conclusion

The bet settlement system is architecturally sound but has two critical failures:

1. **Games never transition to 'final' status** - Needs active monitoring/updating
2. **Game ID mismatches prevent settlement** - Needs consistent ID usage

Once these are fixed, the existing Cloud Function settlement logic will work correctly. The cleanup/refund mechanism is functioning as designed and will serve as a safety net for any edge cases.

**Next Steps**:
1. Investigate game_details_screen.dart to find bet creation code
2. Implement GameStatusUpdater service
3. Test with live games
4. Deploy fixes
5. Monitor for successful settlements

---

**Script Used**: `scripts/diagnose_bet_settlement.js`
**Command**: `node diagnose_bet_settlement.js --user-id=JLl6AoOXHHUhIIW4t7xWDyqWsPm2`
