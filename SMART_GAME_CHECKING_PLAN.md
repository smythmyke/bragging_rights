# 🎯 Smart Game Checking Strategy - Build Plan

**Version**: 1.0
**Created**: October 14, 2025
**Status**: Ready for Implementation

---

## Executive Summary

This document outlines the optimized game status checking strategy that combines:
1. **Time-based scheduling** - Avoid checking during dead hours (11pm-6am Pacific)
2. **Active window detection** - Only check games that should be happening NOW
3. **Sport-specific durations** - Conservative estimates with buffers for each sport
4. **Automatic postponement handling** - Refund bets after extended delays

**Expected savings**: 90-95% reduction in unnecessary checks compared to naive approach

---

## Sport Duration Configuration

### Official Game Durations (Conservative Estimates)

| Sport | Base Duration | Buffer | Total Check Window | Postponement Threshold |
|-------|--------------|--------|-------------------|------------------------|
| **NFL** | 3h 15m | +45m | **4h 00m** | +6h past expected end |
| **NBA** | 2h 30m | +45m | **3h 15m** | +6h past expected end |
| **NHL** | 2h 30m | +30m | **3h 00m** | +6h past expected end |
| **MLB** | 3h 15m | +2h | **5h 15m** | +8h past expected end |
| **NCAAF** | 3h 30m | +1h | **4h 30m** | +6h past expected end |
| **NCAAB** | 2h 15m | +45m | **3h 00m** | +6h past expected end |
| **Boxing** | 3h 00m | +2h | **5h 00m** | +8h past expected end |
| **MMA** | 3h 00m | +2h | **5h 00m** | +8h past expected end |
| **Soccer** | 2h 00m | +30m | **2h 30m** | +6h past expected end |

### Rationale for Boxing/MMA Extended Time

**Original estimate was too aggressive (1h 15m - 1h 45m)**

**Reality of Combat Sports Events:**
- **Undercard fights push main event**: 3-5 preliminary fights before main event
- **Long ring walks**: Especially for championship fights (30+ minutes for both fighters)
- **Pre-fight ceremonies**: National anthems, VIP introductions, belt presentations
- **Technical delays**: Glove issues, hand-wrapping problems, medical checks
- **PPV broadcast windows**: Events are often delayed to hit specific PPV start times

**Example: Typical UFC Main Card Timeline**
- 10:00 PM ET - Main card scheduled start
- 10:00-10:45 PM - First main card fight
- 10:45-11:30 PM - Second main card fight
- 11:30 PM-12:15 AM - Third main card fight
- 12:15-1:00 AM - Co-main event
- 1:00-2:00 AM - Main event (with long walks + fight)

**Real main event doesn't start until 3-4 hours after "event start time"**

**Conservative 5-hour window ensures we catch:**
- Early knockouts (game finishes at 11pm)
- Full-distance fights (game finishes at 2am)
- Delayed starts due to undercard excitement

---

## Time-Based Checking Schedule

### Weekday Schedule (Monday-Thursday)

| Time Window (Pacific) | Check Frequency | Rationale |
|-----------------------|-----------------|-----------|
| **11:00 PM - 6:00 AM** | Every 30 minutes | Dead zone - minimal games, late combat sports only |
| **6:00 AM - 11:00 PM** | Every 7 minutes | Regular checking for standard games |

### Weekend Schedule (Friday-Sunday)

| Time Window (Pacific) | Check Frequency | Rationale |
|-----------------------|-----------------|-----------|
| **11:00 PM - 6:00 AM** | Every 15 minutes | Late combat sports, some international events |
| **6:00 AM - 11:00 AM** | Every 5 minutes | Early NFL/college games, morning MLB |
| **11:00 AM - 11:00 PM** | Every 3 minutes | Peak game times across all sports |

### Special Considerations

**Late Combat Sports (Friday/Saturday nights):**
- Boxing/MMA events often scheduled for 10 PM ET (7 PM PT)
- Main event may not start until 1 AM ET (10 PM PT)
- Main event may finish at 3 AM ET (12 AM PT)
- Check more frequently 11pm-2am on Friday/Saturday nights

**MLB Playoff/World Series:**
- Games can go very late (past midnight PT)
- Consider 5-minute checks even during 11pm-6am window in October

**March Madness (NCAAB):**
- Games run 12pm-midnight ET continuously
- Consider 3-minute checks all day during tournament

---

## Active Window Detection Strategy

### Phase System

#### Phase 0: Pre-Game (Before Start)
**Status**: `scheduled`
**Time**: More than 15 minutes before `gameTime`
**Action**: **Skip entirely** - Don't query ESPN, don't check status
**Rationale**: Game hasn't started, nothing to check

#### Phase 1: Starting Soon
**Status**: `scheduled`
**Time**: 15 minutes before `gameTime` to `gameTime`
**Action**: **Check every run** - Game should be transitioning to `live`
**Rationale**: Capture exact moment game goes live

#### Phase 2: Active Game Window
**Status**: `scheduled` OR `live`
**Time**: Between `gameTime` and `gameTime + expectedDuration`
**Action**: **Check every run** - Game is happening NOW
**Rationale**: Most important window - game in progress

#### Phase 3: Expected Finish Window
**Status**: `scheduled` OR `live`
**Time**: `gameTime + expectedDuration` to `gameTime + expectedDuration + 1 hour`
**Action**: **Check every run** - Game should be finishing
**Rationale**: Overtime, delays, tight finishes

#### Phase 4: Extended Delay Window
**Status**: `scheduled` OR `live`
**Time**: `gameTime + expectedDuration + 1 hour` to `gameTime + postponementThreshold`
**Action**: **Check every 30 minutes** - Possible weather delay, postponement
**Rationale**: Reduce checks for likely postponed games

#### Phase 5: Postponement
**Status**: `scheduled` OR `live`
**Time**: More than `postponementThreshold` past `gameTime`
**Action**: **Mark as postponed, refund bets, stop checking**
**Rationale**: Game is definitely postponed or cancelled

#### Phase 6: Complete
**Status**: `final`
**Action**: **Skip entirely** - Game is done, no need to check
**Rationale**: Nothing more to do

---

## Firestore Query Strategy

### Query Pattern

```
Instead of naive approach:
  "Get all games where status != 'final' from past 24 hours"

Use smart queries:
  Query 1: "Starting Soon" - Games within 15 mins of start
  Query 2: "Active Window" - Games between start and expected end
  Query 3: "Extended Window" - Games past expected end but within threshold

Skip:
  - Games that haven't started yet (Phase 0)
  - Games that finished (Phase 6)
```

### Required Game Document Fields

**Existing fields:**
- `gameTime` (Timestamp) - When game starts
- `status` (String) - 'scheduled', 'live', 'final'
- `sport` (String) - 'NFL', 'NBA', etc.
- `homeScore` (Number)
- `awayScore` (Number)

**New fields to add:**
- `expectedDuration` (Number) - Minutes from start to expected end
- `estimatedEndTime` (Timestamp) - Calculated: `gameTime + expectedDuration`
- `lastStatusCheck` (Timestamp) - When we last checked ESPN
- `postponementThreshold` (Number) - Hours past expected end before refunding
- `hasPendingBets` (Boolean) - Whether any bets exist on this game (indexed)

---

## Implementation Phases

### Phase 1: Add Game Metadata (2-3 hours)

**What**: Add new fields to game documents when creating them

**Files to modify:**
- `lib/services/optimized_games_service.dart` - When saving games to Firestore
- `functions/index.js` - Cloud Function that creates games (if any)

**Changes:**
```dart
// When creating GameModel from ESPN/Odds API
final game = GameModel(
  id: ...,
  gameTime: ...,
  sport: ...,
  expectedDuration: _getExpectedDuration(sport), // NEW
  estimatedEndTime: gameTime.add(Duration(minutes: expectedDuration)), // NEW
  postponementThreshold: _getPostponementThreshold(sport), // NEW
  hasPendingBets: false, // NEW - will be updated when bets placed
);
```

**Helper functions:**
```dart
int _getExpectedDuration(String sport) {
  switch (sport.toUpperCase()) {
    case 'NFL': return 240; // 4 hours in minutes
    case 'NBA': return 195; // 3h 15m
    case 'NHL': return 180; // 3h
    case 'MLB': return 315; // 5h 15m
    case 'NCAAF': return 270; // 4h 30m
    case 'NCAAB': return 180; // 3h
    case 'BOXING': return 300; // 5h
    case 'MMA': return 300; // 5h
    case 'SOCCER': return 150; // 2h 30m
    default: return 180; // 3h default
  }
}

int _getPostponementThreshold(String sport) {
  switch (sport.toUpperCase()) {
    case 'MLB': return 8; // hours
    case 'BOXING': return 8; // hours
    case 'MMA': return 8; // hours
    default: return 6; // hours
  }
}
```

**Migration**: Update existing games in Firestore with these fields (one-time script)

---

### Phase 2: Create Cloud Function (6-8 hours)

**What**: Replace client-side polling with scheduled Cloud Function

**File**: `functions/index.js`

**Structure:**
```javascript
exports.updateGameStatuses = functions.pubsub
  .schedule('every 5 minutes') // Will be dynamic based on time/day
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const db = admin.firestore();
    const now = new Date();
    const nowTimestamp = admin.firestore.Timestamp.fromDate(now);

    // Check if we should run at all based on time
    if (!shouldCheckNow(now)) {
      console.log('⏸️ [SCHEDULER] Skipping check - outside active hours');
      return { skipped: true };
    }

    // Get games in active windows
    const activeGames = await getActiveWindowGames(db, nowTimestamp);

    if (activeGames.length === 0) {
      console.log('✅ [SCHEDULER] No active games to check');
      return { gamesChecked: 0 };
    }

    console.log(`🎮 [SCHEDULER] Checking ${activeGames.length} active games`);

    // Group by sport for efficient ESPN calls
    const gamesBySport = groupBySport(activeGames);

    let totalUpdated = 0;
    for (const [sport, games] of Object.entries(gamesBySport)) {
      const updated = await updateSportGames(db, sport, games, nowTimestamp);
      totalUpdated += updated;
    }

    console.log(`✅ [SCHEDULER] Updated ${totalUpdated} games to final`);
    return { gamesChecked: activeGames.length, gamesUpdated: totalUpdated };
  });
```

**Helper functions:**
```javascript
function shouldCheckNow(now) {
  const hour = now.getHours(); // 0-23 in Pacific time
  const day = now.getDay(); // 0=Sunday, 6=Saturday

  // Weekend (Fri/Sat/Sun)
  if (day === 0 || day === 5 || day === 6) {
    // Always check on weekends (different frequencies handled by schedule)
    return true;
  }

  // Weekday - skip dead zone
  if (hour >= 23 || hour < 6) {
    // 11pm-6am on weekdays - check less frequently
    // This function runs every X minutes based on schedule
    return true; // Schedule handles frequency
  }

  return true;
}

async function getActiveWindowGames(db, nowTimestamp) {
  const games = [];

  // Query 1: Starting soon (within 15 mins of start)
  const fifteenMinsFromNow = admin.firestore.Timestamp.fromDate(
    new Date(nowTimestamp.toDate().getTime() + 15 * 60 * 1000)
  );

  const startingSoon = await db.collection('games')
    .where('status', '==', 'scheduled')
    .where('gameTime', '<=', fifteenMinsFromNow)
    .where('gameTime', '>=', nowTimestamp)
    .get();

  games.push(...startingSoon.docs.map(doc => ({ id: doc.id, ...doc.data() })));

  // Query 2: Currently active (started but not finished)
  const activeNow = await db.collection('games')
    .where('status', 'in', ['scheduled', 'live'])
    .where('gameTime', '<=', nowTimestamp)
    .where('estimatedEndTime', '>=', nowTimestamp)
    .get();

  games.push(...activeNow.docs.map(doc => ({ id: doc.id, ...doc.data() })));

  // Query 3: Past expected end but not postponed yet
  const extendedWindow = await db.collection('games')
    .where('status', 'in', ['scheduled', 'live'])
    .where('estimatedEndTime', '<', nowTimestamp)
    .get();

  // Filter to only include games within postponement threshold
  const extendedGames = extendedWindow.docs
    .map(doc => ({ id: doc.id, ...doc.data() }))
    .filter(game => {
      const hoursSinceExpectedEnd = (nowTimestamp.toDate() - game.estimatedEndTime.toDate()) / (1000 * 60 * 60);
      return hoursSinceExpectedEnd <= game.postponementThreshold;
    });

  games.push(...extendedGames);

  // Remove duplicates by ID
  const uniqueGames = games.reduce((acc, game) => {
    if (!acc.find(g => g.id === game.id)) {
      acc.push(game);
    }
    return acc;
  }, []);

  return uniqueGames;
}

async function updateSportGames(db, sport, games, nowTimestamp) {
  // Fetch ESPN data once per sport
  const espnEvents = await fetchEspnEventsBySport(sport);

  let updatedCount = 0;

  for (const game of games) {
    // Match game to ESPN event
    const espnEvent = findMatchingEspnEvent(espnEvents, game);

    if (espnEvent) {
      const isCompleted = checkIfCompleted(espnEvent);

      if (isCompleted) {
        const scores = extractScores(espnEvent);

        await db.collection('games').doc(game.id).update({
          status: 'final',
          homeScore: scores.homeScore,
          awayScore: scores.awayScore,
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastStatusCheck: admin.firestore.FieldValue.serverTimestamp(),
        });

        console.log(`✅ Updated game ${game.id} to final`);
        updatedCount++;
      } else {
        // Game not completed yet - update last check time
        await db.collection('games').doc(game.id).update({
          lastStatusCheck: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
    } else {
      // Game not found in ESPN - might be postponed
      await handlePotentiallyPostponedGame(db, game, nowTimestamp);
    }
  }

  return updatedCount;
}

async function handlePotentiallyPostponedGame(db, game, nowTimestamp) {
  const hoursSinceExpectedEnd = (nowTimestamp.toDate() - game.estimatedEndTime.toDate()) / (1000 * 60 * 60);

  if (hoursSinceExpectedEnd >= game.postponementThreshold) {
    console.log(`⚠️ Game ${game.id} passed postponement threshold - marking as postponed`);

    // Mark game as postponed
    await db.collection('games').doc(game.id).update({
      status: 'postponed',
      postponedAt: admin.firestore.FieldValue.serverTimestamp(),
    });

    // Trigger bet refunds (will be handled by existing cleanup or new function)
    await refundBetsForPostponedGame(db, game.id);
  }
}

async function refundBetsForPostponedGame(db, gameId) {
  // Get all pending bets for this game
  const betsSnapshot = await db.collection('bets')
    .where('gameId', '==', gameId)
    .where('status', '==', 'pending')
    .get();

  console.log(`💰 Refunding ${betsSnapshot.size} bets for postponed game ${gameId}`);

  const batch = db.batch();

  for (const betDoc of betsSnapshot.docs) {
    const bet = betDoc.data();

    // Update bet status to cancelled
    batch.update(betDoc.ref, {
      status: 'cancelled',
      cancelledAt: admin.firestore.FieldValue.serverTimestamp(),
      cancellationReason: 'Game postponed',
    });

    // Create refund transaction
    const refundTxRef = db.collection('transactions').doc();
    batch.set(refundTxRef, {
      userId: bet.userId,
      type: 'refund',
      amount: bet.wagerAmount,
      description: `Refund for postponed game: ${bet.gameTitle}`,
      relatedId: betDoc.id,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      status: 'completed',
    });

    // Update user wallet balance
    const userWalletRef = db.collection('users').doc(bet.userId).collection('wallet').doc('current');
    batch.update(userWalletRef, {
      balance: admin.firestore.FieldValue.increment(bet.wagerAmount),
      lastTransaction: admin.firestore.FieldValue.serverTimestamp(),
    });
  }

  await batch.commit();
  console.log(`✅ Refunded ${betsSnapshot.size} bets`);
}
```

---

### Phase 3: Dynamic Scheduling (3-4 hours)

**What**: Adjust Cloud Function schedule based on time/day

**Approach**: Use multiple Cloud Functions with different schedules

```javascript
// Weekday dead zone (Mon-Thu, 11pm-6am PT)
exports.updateGameStatusesWeekdayNight = functions.pubsub
  .schedule('every 30 minutes')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();

    // Only run Mon-Thu 11pm-6am
    if ((day >= 1 && day <= 4) && (hour >= 23 || hour < 6)) {
      return await checkGameStatuses();
    }

    return { skipped: true, reason: 'Outside weekday night window' };
  });

// Weekday active hours (Mon-Thu, 6am-11pm PT)
exports.updateGameStatusesWeekdayDay = functions.pubsub
  .schedule('every 7 minutes')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();

    // Only run Mon-Thu 6am-11pm
    if ((day >= 1 && day <= 4) && (hour >= 6 && hour < 23)) {
      return await checkGameStatuses();
    }

    return { skipped: true, reason: 'Outside weekday day window' };
  });

// Weekend late night (Fri-Sun, 11pm-6am PT)
exports.updateGameStatusesWeekendNight = functions.pubsub
  .schedule('every 15 minutes')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();

    // Only run Fri-Sun 11pm-6am
    if ((day === 0 || day === 5 || day === 6) && (hour >= 23 || hour < 6)) {
      return await checkGameStatuses();
    }

    return { skipped: true, reason: 'Outside weekend night window' };
  });

// Weekend peak hours (Fri-Sun, 6am-11pm PT)
exports.updateGameStatusesWeekendDay = functions.pubsub
  .schedule('every 3 minutes')
  .timeZone('America/Los_Angeles')
  .onRun(async (context) => {
    const now = new Date();
    const hour = now.getHours();
    const day = now.getDay();

    // Only run Fri-Sun 6am-11pm
    if ((day === 0 || day === 5 || day === 6) && (hour >= 6 && hour < 23)) {
      return await checkGameStatuses();
    }

    return { skipped: true, reason: 'Outside weekend day window' };
  });

// Shared logic
async function checkGameStatuses() {
  // ... implementation from Phase 2 ...
}
```

---

### Phase 4: Update Bet Service (1-2 hours)

**What**: Set `hasPendingBets` flag when bets are placed/settled

**File**: `lib/services/bet_service.dart`

```dart
Future<String> placeBet({...}) async {
  // ... existing bet placement logic ...

  // After bet is created successfully
  await _firestore.collection('games').doc(gameId).update({
    'hasPendingBets': true,
  });

  return betId;
}
```

**File**: `functions/index.js` (in settleGameBets function)

```javascript
// After settling all bets for a game
const remainingBetsCount = await db.collection('bets')
  .where('gameId', '==', gameId)
  .where('status', '==', 'pending')
  .count()
  .get();

if (remainingBetsCount.data().count === 0) {
  await db.collection('games').doc(gameId).update({
    hasPendingBets: false,
  });
}
```

---

### Phase 5: Remove Client-Side Polling (30 minutes)

**What**: Remove auto-start of GameStatusUpdater

**Files to modify:**
- `lib/screens/home/home_screen.dart`

**Changes:**
```dart
// REMOVE these lines:
// _startGameStatusMonitoring();
// _gameStatusUpdater.startMonitoring();

// KEEP the service file for manual refresh option
// Users can pull-to-refresh to manually trigger a check
```

**Keep GameStatusUpdater available for:**
- Manual "refresh" button
- Pull-to-refresh gestures
- Testing/debugging

---

## Testing Strategy

### Phase 1 Testing: Metadata
- [ ] Create new game from ESPN API
- [ ] Verify `expectedDuration` calculated correctly
- [ ] Verify `estimatedEndTime` = gameTime + expectedDuration
- [ ] Verify `postponementThreshold` set correctly by sport
- [ ] Run migration script on existing games

### Phase 2 Testing: Cloud Function Basic
- [ ] Deploy function to Firebase
- [ ] Trigger manually via Firebase Console
- [ ] Verify function queries active games correctly
- [ ] Verify function calls ESPN API
- [ ] Verify function updates game status to 'final'
- [ ] Check Cloud Function logs for errors

### Phase 3 Testing: Dynamic Scheduling
- [ ] Verify weekday night function only runs Mon-Thu 11pm-6am
- [ ] Verify weekday day function only runs Mon-Thu 6am-11pm
- [ ] Verify weekend schedules work correctly
- [ ] Monitor function execution count over 24 hours
- [ ] Verify no duplicate executions

### Phase 4 Testing: hasPendingBets Flag
- [ ] Place bet on a game
- [ ] Verify `hasPendingBets` set to true
- [ ] Settle bet (mock or real)
- [ ] Verify `hasPendingBets` set to false when no pending bets remain

### Phase 5 Testing: End-to-End
- [ ] Place bet on real upcoming game
- [ ] Wait for game to start (verify status: scheduled → live)
- [ ] Wait for game to finish (verify status: live → final)
- [ ] Verify bet settles automatically
- [ ] Verify wallet updated
- [ ] Verify bet appears in Past tab
- [ ] Check Cloud Function logs for full flow

### Edge Case Testing
- [ ] Game goes to overtime (stays live longer than expected)
- [ ] Game postponed due to weather (verify refund after threshold)
- [ ] Game cancelled before start (verify immediate refund)
- [ ] Multiple bets on same game (verify all settle)
- [ ] Combat sports main event delayed by undercard (verify 5h window works)

---

## Rollout Plan

### Week 1: Development
- **Day 1-2**: Implement Phase 1 (metadata)
- **Day 3-4**: Implement Phase 2 (basic Cloud Function)
- **Day 5**: Testing Phase 1-2

### Week 2: Advanced Features
- **Day 1-2**: Implement Phase 3 (dynamic scheduling)
- **Day 3**: Implement Phase 4 (hasPendingBets)
- **Day 4**: Implement Phase 5 (remove client polling)
- **Day 5**: Testing Phase 3-5

### Week 3: Staging
- **Day 1**: Deploy to staging environment
- **Day 2-6**: Monitor real games in staging
- **Day 7**: Fix any issues discovered

### Week 4: Production
- **Day 1**: Deploy to production
- **Day 2-7**: Monitor closely, ready to rollback if needed

---

## Monitoring & Success Metrics

### Key Metrics to Track

**Function Execution:**
- Number of executions per hour/day
- Average execution time
- Error rate
- Games checked per execution
- Games updated per execution

**Game Status Updates:**
- Time from game ending → status 'final'
- % of games marked as postponed
- % of games settled within 30 minutes of completion

**Bet Settlement:**
- Time from game 'final' → bets settled
- % of bets settled automatically
- % of bets refunded due to postponement
- User complaints about settlement delays

**Cost:**
- Firestore read operations per day
- Cloud Function execution costs per day
- ESPN API call count per day

### Success Criteria

✅ 95%+ of games marked 'final' within 15 minutes of actual completion
✅ 95%+ of bets settled within 30 minutes of game completion
✅ <1% of games incorrectly marked as postponed
✅ Cloud Function execution time <60 seconds average
✅ Total monthly cost <$0.50 at 1,000 active users
✅ Zero ESPN API rate limit errors

---

## Fallback & Rollback Plan

### If Cloud Function Fails

**Symptoms:**
- Games not transitioning to 'final'
- Bets not settling
- Cloud Function errors in logs

**Immediate Action:**
1. Re-enable client-side polling (revert Phase 5)
2. Investigate Cloud Function logs
3. Fix issue in staging
4. Redeploy when fixed

### If Postponement Logic Too Aggressive

**Symptoms:**
- Games marked as postponed that actually finished
- Users complaining about unwarranted refunds

**Immediate Action:**
1. Increase `postponementThreshold` from 6h to 12h
2. Add manual override tool for admins
3. Review ESPN API reliability

### If ESPN API Rate Limited

**Symptoms:**
- 429 errors in Cloud Function logs
- Games not updating

**Immediate Action:**
1. Increase check intervals (5min → 10min)
2. Add exponential backoff
3. Consider premium ESPN API (if available)
4. Add caching layer

---

## Cost Projections

### At 1,000 Active Users

**Firestore Reads:**
- Active window queries: ~50 reads per execution
- Weekday: 1,440 executions/day × 50 reads = 72,000 reads/day
- Weekend: 2,880 executions/day × 50 reads = 144,000 reads/day
- Monthly average: ~3 million reads/month
- **Cost: $0.18/month** ($0.06 per million reads)

**Cloud Function Executions:**
- Average 1,500 executions/day
- 45,000 executions/month
- Average 10 seconds per execution
- **Cost: $0.00/month** (free tier: 2M executions, 400K GB-seconds)

**Firestore Writes:**
- ~100 games updated per day
- 3,000 writes/month
- **Cost: $0.01/month** ($0.18 per million writes)

**Total: ~$0.20/month at 1,000 users**

### At 10,000 Active Users

Costs scale linearly with game count, not user count (same games checked):
**Total: ~$0.20/month** (unchanged)

### At 100,000 Active Users

Still checking same games:
**Total: ~$0.20/month** (unchanged)

**This is why Cloud Function approach is superior - cost doesn't scale with users!**

---

## Appendix: Sport-Specific Notes

### MLB Special Considerations
- **Most unpredictable duration**: 2h 20m to 6+ hours
- **Extra innings**: No limit, can go 15+ innings
- **Weather delays**: Common, can last hours
- **Strategy**: Use longest buffer (5h 15m) and postponement threshold (8h)

### Boxing/MMA Special Considerations
- **Undercard delays**: Main event often 3-4 hours after scheduled start
- **Long entrances**: Championship fights have 30+ minute walks
- **Early finishes**: KO/submission can end fight in Round 1
- **Strategy**: Use 5-hour check window, don't mark postponed too quickly

### Soccer Special Considerations
- **Most predictable**: Almost always 2h 00m ± 15 minutes
- **Rare delays**: Weather rarely stops soccer
- **Extra time**: Only in knockout tournaments (+30 mins + penalties)
- **Strategy**: Shortest check window (2h 30m), quick postponement (6h)

---

## Questions Before Implementation

1. **Firebase project setup**: Do you have Cloud Functions enabled?
2. **Timezone**: Confirm all times should be Pacific (America/Los_Angeles)?
3. **Testing accounts**: Do you have test user accounts for safe testing?
4. **Staging environment**: Do you have a Firebase staging project?
5. **Budget approval**: Comfortable with ~$0.20-0.50/month costs?

---

**Ready to proceed with implementation?**

Next step: Implement Phase 1 (add game metadata)
