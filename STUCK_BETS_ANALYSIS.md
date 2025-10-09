# Stuck Bets Analysis - October 8, 2025

**Issue**: 35 bets showing as "pending" but many games are already completed
**Impact**: Users not receiving winnings, bet history not updating, performance stats broken

---

## 🔍 Analysis from Logs

### Problem Summary

From your active bets logs, we can see:

**35 Pending Bets** including:
- ❌ **Lakers vs Celtics** - Placed Aug 25, 2025 (45+ days ago!)
- ❌ **Tampa Bay @ Atlanta** - Placed Sep 6, 2025 (32+ days ago)
- ❌ **Pittsburgh @ Baltimore** - Placed Sep 9-11, 2025 (27-29 days ago)
- ❌ **Chicago Cubs @ Pittsburgh** - Placed Sep 15, 2025 (23 days ago)
- ❌ **NFL Games** - Placed Sep 15, 2025 (23 days ago)
- ❌ **Soccer Games** - Placed Sep 13-27, 2025 (11-25 days ago)
- ❌ **MLB Playoff Game** - Placed Oct 2, 2025 (6 days ago)

These games are **definitely finished** but bets are still pending.

---

## 🐛 Root Causes Identified

### Cause 1: Inconsistent Game ID Format

**Problem**: Two different game ID formats exist:

**ESPN API Format** (Correct):
```
mlb_401809253_1759431600000
nhl_401790338_1759446000000
df4b9f35b66ef20724b6b3e81081ddfd  (soccer MD5 hash)
```

**Manual Format** (Problematic):
```
NFL_Tampa Bay Buccaneers @ Houston Texans_1757948186659
MLB_Chicago Cubs @ Pittsburgh Pirates_1757945746653
SOCCER_Nottingham Forest @ Arsenal_1757749317843
NBA_Lakers vs Celtics_1756154468288
```

**Impact**:
- Bets placed with manual game IDs won't match when ESPN API updates the game
- Cloud Function can't find these games to settle them
- Games might exist in Firestore with different IDs

---

### Cause 2: Game Not Updated to 'final' Status

**Problem**: Games in Firestore may have status:
- `'scheduled'` - Game hasn't started
- `'live'` - Game in progress
- `'in_progress'` - Game in progress (alternative)
- Missing `'final'` - Game completed but status not updated

**Why this happens**:
1. Game finishes
2. ESPN API returns `STATUS_FINAL`
3. But game never saved to Firestore with `status: 'final'` (our bug from earlier)
4. Cloud Function never triggers
5. Bets stay pending forever

**We fixed this in `BET_SETTLEMENT_CRITICAL_FIX.md`** but:
- Fix only applies to NEW games going forward
- OLD stuck bets need manual intervention

---

### Cause 3: Cloud Function Not Triggering

**Possible reasons**:
1. ❌ Game document doesn't exist in Firestore
2. ❌ Game exists but status field never changed to `'final'`
3. ❌ Game ID mismatch (bet uses different ID than game)
4. ❌ Cloud Function error (check logs: `firebase functions:log --only settleGameBets`)

---

## 📊 Breakdown of Your 35 Stuck Bets

### By Sport:
- **NFL**: 13 bets (Tampa Bay, Cleveland Browns games)
- **MLB**: 10 bets (Pirates, Cubs, Tigers, Reds games)
- **Soccer**: 6 bets (Premier League matches)
- **NBA**: 3 bets (Lakers, Warriors games)
- **NHL**: 3 bets (Bruins game)

### By Age:
- **45+ days old**: 1 bet (Lakers vs Celtics)
- **30-40 days old**: 3 bets (Tampa Bay @ Atlanta)
- **20-30 days old**: 16 bets (Sept 9-15 games)
- **10-20 days old**: 6 bets (Soccer matches)
- **5-10 days old**: 9 bets (Recent MLB/NHL)

### By Game ID Format:
- **Manual IDs**: ~23 bets (NFL_*, MLB_*, SOCCER_*, NBA_*)
- **ESPN IDs**: ~12 bets (correct format)

---

## 🔧 Diagnostic Steps

### Step 1: Check if Games Exist in Firestore

For each stuck bet, we need to:
1. Get the `gameId` from the bet
2. Query Firestore `games` collection for that game
3. Check if:
   - Game exists? (Yes/No)
   - What is `game.status`? (scheduled/live/final)
   - What are scores? (homeScore, awayScore)

**Example Query** (Firebase Console):
```
games/{gameId}
```

**Expected Results**:
- **Game exists + status='final'**: Settlement should have happened but didn't (Cloud Function issue)
- **Game exists + status='scheduled'/'live'**: Game finished but status not updated (our previous bug)
- **Game doesn't exist**: Bet placed with wrong game ID or game never fetched

---

### Step 2: Check Cloud Function Logs

```bash
# Check settlement function logs
firebase functions:log --only settleGameBets --limit 100

# Look for:
# - Errors when trying to settle
# - Games that triggered but failed
# - Missing game IDs
```

**What to look for**:
- `Error: Game not found` → Game ID mismatch
- `Error: Cannot read property 'homeScore'` → Game missing score data
- `Successfully settled X bets for game Y` → Function worked (rare for old games)
- No logs at all → Function never triggered (status never changed)

---

### Step 3: Check Game Data in Firestore

For the oldest stuck bet (`Lakers vs Celtics`):

**Firestore Query**:
```javascript
// In Firebase Console
db.collection('games').doc('NBA_Lakers vs Celtics_1756154468288').get()
```

**Check**:
1. Does document exist?
2. What is `status` field?
3. What are `homeScore` and `awayScore`?
4. When was `lastUpdated`?

---

## 🛠️ Solutions

### Solution 1: Manual Settlement Script (Quick Fix)

Create a script to:
1. Query all pending bets older than 7 days
2. For each bet:
   - Look up the game in Firestore
   - If game.status === 'final' → Call settlement function
   - If game doesn't exist → Mark bet as `'cancelled'` with refund
   - If game.status !== 'final' but game is old → Fetch latest from ESPN API

**Implementation**:
```dart
// lib/scripts/settle_stuck_bets.dart
Future<void> settleStuckBets() async {
  final now = DateTime.now();
  final sevenDaysAgo = now.subtract(Duration(days: 7));

  // Get all pending bets older than 7 days
  final snapshot = await FirebaseFirestore.instance
    .collection('bets')
    .where('status', isEqualTo: 'pending')
    .where('placedAt', isLessThan: Timestamp.fromDate(sevenDaysAgo))
    .get();

  print('Found ${snapshot.docs.length} stuck bets');

  for (var betDoc in snapshot.docs) {
    final bet = betDoc.data();
    final gameId = bet['gameId'];

    // Check if game exists
    final gameDoc = await FirebaseFirestore.instance
      .collection('games')
      .doc(gameId)
      .get();

    if (!gameDoc.exists) {
      print('❌ Game not found: $gameId - Cancelling bet');
      // Refund the bet
      await _refundBet(betDoc.id, bet);
      continue;
    }

    final game = gameDoc.data()!;

    if (game['status'] == 'final') {
      print('✅ Game is final but bet not settled - Triggering settlement');
      // Manually trigger settlement
      await _settleBet(betDoc.id, bet, game);
    } else {
      print('⚠️ Game exists but not final: ${game['status']} - Fetching latest from API');
      // Refresh game from ESPN API
      await _refreshGameFromAPI(gameId);
    }
  }
}
```

---

### Solution 2: Callable Cloud Function (Better)

Create a Cloud Function that users/admins can call to force settlement:

**Cloud Function** (`functions/index.js`):
```javascript
exports.manualSettleStuckBets = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'Must be logged in');
  }

  const userId = context.auth.uid;
  const sevenDaysAgo = admin.firestore.Timestamp.fromDate(
    new Date(Date.now() - 7 * 24 * 60 * 60 * 1000)
  );

  // Get stuck bets for this user
  const betsSnapshot = await admin.firestore()
    .collection('bets')
    .where('userId', '==', userId)
    .where('status', '==', 'pending')
    .where('placedAt', '<', sevenDaysAgo)
    .get();

  const results = {
    total: betsSnapshot.docs.length,
    settled: 0,
    cancelled: 0,
    errors: 0
  };

  for (const betDoc of betsSnapshot.docs) {
    const bet = betDoc.data();
    const gameId = bet.gameId;

    try {
      // Get game
      const gameDoc = await admin.firestore().collection('games').doc(gameId).get();

      if (!gameDoc.exists) {
        // Cancel bet and refund
        await refundBet(betDoc.id, bet);
        results.cancelled++;
        continue;
      }

      const game = gameDoc.data();

      if (game.status === 'final') {
        // Settle bet
        await settleBetsForGame(gameId, game);
        results.settled++;
      } else {
        // Game not final yet - leave as pending
        results.errors++;
      }
    } catch (error) {
      console.error(`Error processing bet ${betDoc.id}:`, error);
      results.errors++;
    }
  }

  return results;
});
```

**Call from Flutter**:
```dart
final callable = FirebaseFunctions.instance.httpsCallable('manualSettleStuckBets');
final result = await callable.call();
print('Settlement results: $result');
// Example: {total: 35, settled: 28, cancelled: 5, errors: 2}
```

---

### Solution 3: Admin Panel (Long-term)

Create an admin screen to:
1. View all stuck bets
2. Manually trigger settlement for specific bets
3. Cancel/refund problematic bets
4. View settlement logs

---

## 🎯 Immediate Action Plan

### Phase 1: Diagnosis (15 min)

1. **Check one stuck bet in detail**:
   ```bash
   # In Firebase Console, check:
   # 1. Bet document: bets/HISUdADtKg7wrWtIlhrJ
   # 2. Game document: games/NBA_Lakers vs Celtics_1756154468288
   ```

2. **Check Cloud Function logs**:
   ```bash
   firebase functions:log --only settleGameBets --limit 50
   ```

3. **Identify pattern**:
   - Are games missing from Firestore?
   - Are games present but status not 'final'?
   - Are there errors in function logs?

### Phase 2: Quick Fix (30 min)

**Option A**: If games exist with `status='final'`:
- Create callable Cloud Function to manually settle
- Call it from Flutter for this user
- Bets settle immediately

**Option B**: If games missing or wrong status:
- Query ESPN API for final scores
- Update game documents with `status='final'`
- Cloud Function triggers automatically
- Bets settle

**Option C**: If games are truly lost (wrong IDs):
- Cancel bets and refund BR
- Update bet status to `'cancelled'`
- Return wager amount to wallet

### Phase 3: Prevention (1 hour)

1. **Ensure consistent game ID format**:
   - Always use ESPN API game IDs
   - Never create manual game IDs
   - Validate game ID format before allowing bets

2. **Add bet expiration**:
   - Auto-cancel bets older than 30 days if game not found
   - Auto-refund to prevent stuck BR

3. **Add settlement status tracking**:
   - `settlementAttempts: 0` (increment on each try)
   - `lastSettlementAttempt: timestamp`
   - `settlementError: string` (store error if failed)

---

## 🔍 What I Need from You

To help fix this, I need to know:

1. **Do you have Firebase Console access?**
   - Can you check if game `NBA_Lakers vs Celtics_1756154468288` exists?
   - If so, what is its `status` field?

2. **Can you run Cloud Functions locally or check logs?**
   ```bash
   firebase functions:log --only settleGameBets
   ```

3. **What do you want to do with these stuck bets?**
   - Option A: Try to settle them (if games are final)
   - Option B: Cancel and refund (if games are lost/invalid)
   - Option C: Leave them for now and fix going forward

4. **Do you want me to create:**
   - A diagnostic script to check all stuck bets?
   - A callable function to manually settle?
   - An admin panel to manage stuck bets?
   - All of the above?

---

## 📋 Next Steps

**Choose one**:

### Option 1: Manual Diagnosis (You do it)
1. I'll guide you through Firebase Console checks
2. You tell me what you find
3. I'll create the appropriate fix

### Option 2: Automated Script (I create it)
1. I'll create a diagnostic script
2. You run it in the app
3. It reports all stuck bets + reasons
4. Then I create settlement script

### Option 3: Cloud Function (Best for production)
1. I create `manualSettleStuckBets` callable function
2. You deploy it to Firebase
3. Call it from app to fix all stuck bets
4. Works for future issues too

**Recommended**: Option 3 (Cloud Function) - It's the most robust and reusable solution.

Let me know which approach you prefer and I'll implement it!

---

**Files to Create** (based on your choice):
- `lib/scripts/diagnose_stuck_bets.dart` (Option 2)
- `functions/manualSettlement.js` (Option 3)
- `lib/screens/admin/stuck_bets_admin.dart` (Admin panel)
