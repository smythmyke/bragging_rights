# Bet Settlement Automation Plan

## Current State Analysis

### What We Have ✅

1. **`settlement_service.dart`** - Complete settlement logic
   - Evaluates bets (moneyline, spread, totals, props)
   - Calculates payouts using American odds
   - Updates wallet balances via `wallet_service.dart`
   - Handles pool distributions
   - Includes rollback and verification functions
   - ⚠️ **Must be manually triggered** - no automation exists

2. **`bet_service.dart`** - Bet lifecycle management
   - `placeBet()` - Creates bets, deducts wager from wallet
   - `getActiveBets()` - Streams pending bets (status = 'pending')
   - `getPastBets()` - Streams settled bets (status = 'won', 'lost', 'cancelled')
   - `cancelBet()` - User-initiated bet cancellation with refund
   - ❌ No automatic settlement checking

3. **`active_bets_screen.dart`** - UI for viewing bets
   - Active tab: Shows pending bets with "PENDING" badge
   - Past tab: Shows won/lost/cancelled bets
   - Stats card: Wins, losses, profit, streak
   - ❌ No game status displayed alongside bet status
   - ❌ No manual settlement button

4. **Cloud Functions Documentation** (`CLOUD_FUNCTIONS_GUIDE.md`)
   - `settleGameBets` - Firestore trigger on game status → 'final'
   - `weeklyAllowance` - Scheduled function (Monday 9 AM)
   - `manualSettleGame` - Admin callable function
   - `cancelBet` - User callable function
   - ❓ **Unknown if deployed or active**

### What's Missing ❌

1. **No automated game completion monitoring**
   - Games update to status='final' in Firestore
   - But nothing monitors this change
   - No trigger connects game completion to bet settlement

2. **No deployed Cloud Functions**
   - Functions are documented but deployment status unknown
   - Need to verify: `firebase functions:list`
   - If not deployed, bets will never auto-settle

3. **No connection between services**
   - `optimized_games_service.dart` updates game status to 'final'
   - `settlement_service.dart` exists but isn't called
   - Missing: Trigger to call settlement when game ends

4. **No user feedback for settlement**
   - Users don't know when their bets will be settled
   - No notifications when bets are resolved
   - No estimated settlement time displayed

## Problems Identified

### 🔴 Critical Issues

1. **Bets stay "PENDING" indefinitely**
   - Games finish, scores update, status → 'final'
   - Bets remain in pending state forever
   - Users never receive winnings
   - Wallet balances don't update

2. **No automation exists**
   - Settlement service requires manual invocation
   - No scheduled checks for completed games
   - No triggers on game status changes

3. **Unknown Cloud Functions status**
   - Documentation exists but deployment unclear
   - May need initial deployment
   - Could be inactive or misconfigured

### 🟡 Secondary Issues

1. **Poor user experience**
   - No visibility into when bets will settle
   - No game status shown on bets screen
   - Can't manually request settlement

2. **No error handling**
   - What if settlement fails?
   - No retry mechanism
   - No notification of settlement errors

## Implementation Plan

### Phase 1: Discovery & Verification (Do NOT update code)

#### Step 1.1: Check Firebase Functions Status
```bash
# Check if any functions are deployed
firebase functions:list

# Check specific functions
firebase functions:log --only settleGameBets
firebase functions:log --only weeklyAllowance
```

#### Step 1.2: Review Firebase Console
- Navigate to Firebase Console → Functions
- Document which functions are active
- Check execution logs and error rates
- Verify triggers are configured correctly

#### Step 1.3: Review Firestore Structure
- Check `games` collection for status field usage
- Verify `bets` collection structure matches settlement_service expectations
- Confirm `wallets` collection exists and has correct schema
- Check if `settlements` collection exists

#### Step 1.4: Test Settlement Service Manually
- Create test bet in Firestore
- Create test game with status='final'
- Manually invoke `settlement_service.settleGame()`
- Verify wallet updates and bet status changes

### Phase 2: Cloud Functions Deployment (If Not Active)

#### Step 2.1: Review Functions Code
Location: `functions/index.js` (or wherever Cloud Functions are defined)
- Verify `settleGameBets` trigger exists
- Confirm `weeklyAllowance` schedule is correct
- Check admin functions are properly secured

#### Step 2.2: Deploy Functions
```bash
# Install dependencies
cd functions
npm install

# Test locally first
firebase emulators:start --only functions

# Deploy to production
firebase deploy --only functions
```

#### Step 2.3: Verify Deployment
```bash
# Check deployment status
firebase functions:list

# Monitor logs
firebase functions:log --follow
```

### Phase 3: Alternative Client-Side Settlement (If Cloud Functions Not Viable)

If Cloud Functions can't be deployed or are too expensive:

#### Option A: Background Service in Flutter
Create `bet_settlement_monitor.dart`:
- Runs periodic checks (every 5 minutes)
- Queries for games with status='final' AND active bets
- Calls settlement_service for each completed game
- Runs only when app is active

#### Option B: Manual Settlement Button
Add to `active_bets_screen.dart`:
- "Check for Settled Games" button
- User-initiated settlement check
- Shows loading indicator while processing
- Displays results after settlement

#### Option C: On-Demand Settlement
Modify `active_bets_screen.dart`:
- Check game status when viewing active bets
- Auto-settle if game is final
- Show "Settling..." indicator
- Refresh list after settlement

### Phase 4: Enhanced User Experience

#### Step 4.1: Update Active Bets Screen
Add to each bet card:
- Game status badge (Scheduled, Live, Final)
- Expected settlement time
- "Settling..." indicator if in progress
- Error message if settlement failed

#### Step 4.2: Add Manual Settlement Option
```dart
// Add button to active_bets_screen.dart
ElevatedButton(
  onPressed: () => _settleBetsForCompletedGames(),
  child: Text('Check for Settled Games'),
)
```

#### Step 4.3: Add Notifications
- Settlement completed notification
- Win/Loss notification with amount
- Weekly allowance notification

### Phase 5: Testing & Validation

#### Step 5.1: Create Test Scenarios
1. Place bet on upcoming game
2. Manually update game to status='final'
3. Verify automatic settlement (or trigger manual)
4. Check wallet balance updated
5. Verify bet moves to Past tab
6. Confirm stats updated

#### Step 5.2: Edge Cases
- Bet on cancelled game (refund)
- Bet on postponed game (keep pending)
- Multiple bets on same game
- Parlay bets (if supported)
- Settlement errors and retries

#### Step 5.3: Performance Testing
- 100+ pending bets settlement
- Settlement during peak load
- Concurrent settlements
- Database transaction conflicts

## Technical Requirements

### Firestore Collections Required

```javascript
// games/{gameId}
{
  status: 'scheduled' | 'live' | 'final' | 'cancelled',
  homeTeam: string,
  awayTeam: string,
  homeScore: number,
  awayScore: number,
  lastUpdated: timestamp
}

// bets/{betId}
{
  userId: string,
  gameId: string,
  status: 'pending' | 'won' | 'lost' | 'cancelled',
  wagerAmount: number,
  potentialPayout: number,
  bets: [{ type, selection, odds, line }],
  placedAt: timestamp
}

// settlements/{gameId}
{
  gameId: string,
  settledAt: timestamp,
  poolsSettled: number,
  wagersSettled: number,
  totalPayouts: number
}

// wallets/{userId}
{
  balance: number,
  totalWinnings: number,
  totalWagered: number
}
```

### Cloud Function Triggers

```javascript
// Automatic settlement on game completion
exports.settleGameBets = functions.firestore
  .document('games/{gameId}')
  .onUpdate(async (change, context) => {
    const before = change.before.data();
    const after = change.after.data();

    // Trigger settlement when status changes to 'final'
    if (before.status !== 'final' && after.status === 'final') {
      // Call settlement service
      await settleGame(context.params.gameId, after);
    }
  });
```

## Security Considerations

### Firestore Rules
```javascript
// Only allow settlement service to update bet status
match /bets/{betId} {
  allow read: if request.auth.uid == resource.data.userId;
  allow create: if request.auth.uid != null;
  allow update: if request.auth.uid == resource.data.userId
                || request.auth.token.admin == true;
}

// Protect wallet from direct updates
match /wallets/{userId} {
  allow read: if request.auth.uid == userId;
  allow write: false; // Only Cloud Functions can write
}
```

### Admin Functions
- Require custom claims: `admin: true`
- Log all manual settlements
- Implement rate limiting
- Add rollback capability

## Monitoring & Alerts

### Metrics to Track
1. **Settlement Success Rate**
   - % of games settled successfully
   - Average settlement time
   - Failed settlements count

2. **Bet Statistics**
   - Total pending bets
   - Average bet amount
   - Win/loss ratio

3. **Financial Metrics**
   - Total payouts per day
   - Wallet balance changes
   - Settlement discrepancies

### Alerts to Configure
- Settlement failures (critical)
- High payout amounts (review)
- Wallet balance mismatches (critical)
- Function timeout errors (warning)

## Cost Considerations

### Cloud Functions Pricing
- **Invocations**: $0.40 per million (after free tier)
- **Compute time**: ~$0.0000025 per GB-second
- **Free tier**: 2M invocations/month

### Estimated Costs (for 1000 games/month)
- Settlement triggers: ~1000 invocations
- Weekly allowance: ~4 invocations
- Manual settlements: ~100 invocations
- **Total**: Well within free tier

### Alternative (Client-Side)
- **Cost**: $0 (uses existing app)
- **Tradeoff**: Only settles when users open app
- **Benefit**: No Cloud Functions needed

## Rollout Strategy

### Stage 1: Internal Testing (Week 1)
- Deploy functions to test environment
- Create test bets and games
- Verify settlement works correctly
- Test error scenarios

### Stage 2: Beta Testing (Week 2)
- Enable for 10-20 beta users
- Monitor settlement accuracy
- Collect user feedback
- Fix any issues found

### Stage 3: Gradual Rollout (Week 3)
- Enable for 25% of users
- Monitor performance and errors
- Increase to 50%, then 100%
- Keep manual settlement as backup

### Stage 4: Full Production (Week 4)
- All users using automatic settlement
- Remove manual settlement option (or keep as backup)
- Full monitoring and alerts active
- Documentation complete

## Success Criteria

- ✅ 95%+ of bets settled within 5 minutes of game completion
- ✅ 0 wallet balance discrepancies
- ✅ Settlement success rate > 99%
- ✅ No user complaints about pending bets
- ✅ Monitoring and alerts functional
- ✅ Rollback capability tested and working

## Next Steps

### Immediate Actions (Before Any Code Changes)
1. ✅ **Created this plan document**
2. ⏳ **Check Firebase Functions deployment status**
   - Run: `firebase functions:list`
   - Document active functions
3. ⏳ **Review Firebase Console**
   - Check Functions tab
   - Review execution logs
4. ⏳ **Verify Firestore collections**
   - Confirm schema matches expectations
   - Check for test data
5. ⏳ **Decision point**: Cloud Functions vs Client-Side
   - Based on deployment status
   - Based on cost/complexity tradeoffs

### After Discovery Phase
- Create implementation tasks based on findings
- Update this document with specific implementation details
- Begin Phase 2 or Phase 3 based on discovery results

## Questions to Answer

1. **Are Cloud Functions currently deployed?**
   - If yes: Which ones are active?
   - If no: Why not? Deployment issues or intentional?

2. **What is the current Firestore structure?**
   - Does it match settlement_service expectations?
   - Are there any schema mismatches?

3. **How often do games complete?**
   - Daily volume of completed games
   - Peak settlement times
   - Required settlement speed

4. **What's the user expectation?**
   - Instant settlement after game ends?
   - Acceptable delay (5 min, 1 hour, next day)?
   - Manual settlement acceptable?

5. **Budget constraints?**
   - Can we use Cloud Functions?
   - Need free-tier solution only?
   - Cost per settlement acceptable?
