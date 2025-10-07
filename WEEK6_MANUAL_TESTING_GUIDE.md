# Week 6 Manual Testing Guide - Phase 1 Free Tier

**Test Date**: 2025-01-06
**Test User**: smythmyke@gmail.com (ID: JLl6AoOXHHUhIIW4t7xWDyqWsPm2)
**Starting Balance**: 1000 BR
**Admin Override**: Enabled (forceFreeTier: true)

---

## Prerequisites

### Environment Setup
- [ ] Flutter app running on device/emulator
- [ ] Firebase connection verified
- [ ] Test user logged in
- [ ] Admin override enabled for free tier

### Verify Test User State
Run: `python scripts/query_user.py`

Expected:
```json
{
  "brBalance": 1000,
  "totalBrEarned": 1000,
  "totalBrSpent": 0,
  "loginStreak": 0,
  "longestLoginStreak": 0,
  "adminOverride": {
    "enabled": true,
    "forceFreeTier": true
  }
}
```

---

## Test 1: Daily Bonus Claim Flow

### Objective
Verify daily bonus claim increases BR balance and updates streak

### Steps
1. **Navigate to Daily Bonus Screen**
   - Location: Rewards tab or main navigation
   - Expected: Screen loads with streak calendar

2. **Verify Can Claim Status**
   - Check: "Claim Daily Bonus" button is active
   - Check: Button has glowing cyan border animation
   - Check: Current streak shows "0 days"

3. **Claim Daily Bonus**
   - Action: Tap "Claim Daily Bonus" button
   - Expected: Success dialog appears
   - Expected: Shows "+50 BR" or "+150 BR" (if day 7)

4. **Verify Balance Update**
   - Check: BR balance in app bar increased by 50
   - Check: Balance now shows 1050 BR
   - Check: Snackbar notification shows "+50 BR"

5. **Verify Streak Update**
   - Check: Current streak now shows "1 day"
   - Check: Day 1 in calendar has green checkmark
   - Check: Current day (Day 1) has green border

6. **Verify Cannot Claim Again**
   - Check: "Claim Daily Bonus" button is disabled
   - Check: Button text shows "Already Claimed Today"
   - Check: Next claim time displayed (tomorrow)

### Expected Results
- ✅ Balance: 1000 → 1050 BR
- ✅ Streak: 0 → 1
- ✅ Transaction recorded in br_transactions
- ✅ Button disabled until tomorrow

### Verification Query
```bash
python scripts/query_user.py
```
Expected fields:
- `brBalance: 1050`
- `loginStreak: 1`
- `lastDailyBonus: [today's timestamp]`
- `lastLoginDate: "2025-01-06"`

---

## Test 2: BR Balance Display

### Objective
Verify BR balance widgets display correctly across app

### Test Locations

#### 2.1: Compact Widget (App Bar)
- **Location**: Top right of main screens
- **Check**: Shows balance in format "1050 BR"
- **Check**: Has cyan glowing border
- **Check**: Wallet icon present
- **Check**: Tap navigates to transaction history

#### 2.2: Full Widget (Wallet/Profile Screen)
- **Location**: Rewards or Profile screen
- **Check**: Large balance display with "BR Balance" label
- **Check**: Animated glow effect
- **Check**: Shows "View Transaction History" link
- **Check**: Updates in real-time when balance changes

#### 2.3: Balance Change Animation
- **Action**: Earn BR (claim daily bonus)
- **Check**: Green "+50 BR" snackbar appears
- **Check**: Trending up icon shown
- **Check**: Balance counter animates to new value

### Expected Results
- ✅ Balance displayed consistently across app
- ✅ Real-time updates when balance changes
- ✅ Animations trigger on balance increase
- ✅ Navigation to transaction history works

---

## Test 3: Pool Entry with BR Payment

### Objective
Test pool browsing, entry, and BR spending

### Steps

1. **Navigate to Games Screen**
   - Action: Open Games tab
   - Expected: List of upcoming games loads

2. **Select Active Game**
   - Action: Tap on a game card
   - Expected: Game details screen opens
   - Check: Team records displayed (e.g., "8-5" vs "5-8")
   - Check: Underdog badge on team with worse record

3. **View Available Pools**
   - Location: "Available Pools" section
   - Check: Only simple pick pools shown (no spread/total)
   - Check: Pool buy-ins displayed in BR
   - Check: Current players count shown

4. **Join Pool with BR Payment**
   - Action: Select pool with buy-in ≤ 1050 BR (e.g., 100 BR)
   - Action: Tap "Join Pool" button
   - Expected: Confirmation dialog appears
   - Expected: Shows "Cost: 100 BR"
   - Expected: Shows new balance after entry

5. **Confirm Pool Entry**
   - Action: Tap "Confirm" on dialog
   - Expected: Success message appears
   - Expected: Balance decreases: 1050 → 950 BR
   - Expected: Pool shows user as joined
   - Expected: "Make Picks" button now available

6. **Verify Insufficient Funds**
   - Action: Try to join pool with buy-in > current balance
   - Expected: Error message: "Insufficient BR balance"
   - Expected: Cannot join pool

### Expected Results
- ✅ Pool entry successful with sufficient BR
- ✅ Balance: 1050 → 950 BR (for 100 BR pool)
- ✅ User added to pool playerIds array
- ✅ Transaction recorded as "pool_entry"
- ✅ Insufficient balance blocked properly

### Verification Query
```bash
python scripts/query_user.py
```
Expected:
- `brBalance: 950`
- `totalBrSpent: 100`

Check transaction:
```python
# Query br_transactions collection
# Should show pool_entry transaction with -100 BR
```

---

## Test 4: Pick Submission in Free Tier Pool

### Objective
Verify pick submission in simple pick pool (no spreads/totals)

### Steps

1. **Open Joined Pool**
   - Action: Navigate to pool joined in Test 3
   - Expected: "Make Picks" button visible

2. **View Pick Options**
   - Action: Tap "Make Picks"
   - Expected: Simple pick screen opens
   - Check: Only "Winner" pick type shown (no spread/total tabs)
   - Check: Both teams listed with records
   - Check: Underdog badge on team with worse record

3. **Select Pick**
   - Action: Tap to select underdog team
   - Expected: Team highlights with cyan border
   - Expected: Selection confirmation shown

4. **Submit Picks**
   - Action: Tap "Submit Picks" button
   - Expected: Confirmation dialog appears
   - Expected: Shows selected picks summary

5. **Confirm Submission**
   - Action: Tap "Confirm" on dialog
   - Expected: Success message appears
   - Expected: Picks locked with timestamp
   - Expected: "Picks Submitted" badge shown

6. **Verify Cannot Edit**
   - Action: Try to tap on pick again
   - Expected: Picks are locked/disabled
   - Expected: No edit option available
   - Expected: Lock icon or "Locked" indicator shown

### Expected Results
- ✅ Simple picks only (no spread/total)
- ✅ Picks submitted successfully
- ✅ Picks locked after submission
- ✅ No edit capability after lock
- ✅ Timestamp recorded

---

## Test 5: Game Scoring with Underdog Bonus

### Objective
Verify underdog bonus applied to winning picks

### Prerequisites
- Need admin access to mark games as final
- OR wait for actual game to complete

### Test Scenario
**Game Setup**:
- Home Team: Record "3-7" (win% = 0.300)
- Away Team: Record "8-2" (win% = 0.800)
- Underdog: Home Team (difference = 0.500)
- Expected Bonus: +50 points (difference ≥ 0.301)

### Steps

1. **Submit Pick on Underdog**
   - Pick: Home Team (3-7 record)
   - Expected: Underdog badge shown on selection

2. **Mark Game as Final** (Admin Only)
   - Result: Home Team wins (underdog wins)
   - Score: Any valid score

3. **View Game Results**
   - Action: Navigate to pool results
   - Expected: Results screen shows completed game

4. **Verify Underdog Bonus Applied**
   - Check: Base points awarded (e.g., 100 pts)
   - Check: Underdog bonus shown (e.g., +50 pts)
   - Check: Total points = Base + Bonus (150 pts)
   - Check: Results breakdown shows bonus separately

5. **Verify Pool Standings**
   - Check: User score updated in leaderboard
   - Check: Underdog bonus reflected in total score
   - Check: Other users without underdog pick scored lower

### Expected Results
- ✅ Underdog correctly identified (lower win%)
- ✅ Bonus tier calculated correctly (50 pts for 0.500 diff)
- ✅ Total score includes bonus
- ✅ Results UI shows bonus breakdown
- ✅ Leaderboard reflects accurate scoring

### Bonus Tier Reference
From `simple_pick_scoring.dart`:
- **0.000-0.100**: +10 points
- **0.101-0.200**: +20 points
- **0.201-0.300**: +30 points
- **0.301+**: +50 points

---

## Test 6: Achievements System

### Objective
Verify achievements trigger and award BR rewards

### Test Achievements

#### 6.1: First Pool Entry
- **Trigger**: Join your first pool
- **Achievement**: "first_pool_entry"
- **Reward**: +50 BR
- **Verification**:
  - Check: Achievement notification appears
  - Check: Balance increases by 50 BR
  - Check: Achievement marked complete in UI
  - Check: Transaction recorded as "achievement"

#### 6.2: Daily Login Streak (3 days)
- **Trigger**: Login 3 consecutive days
- **Achievement**: "login_streak_3"
- **Reward**: +50 BR
- **Verification**:
  - Requires multi-day testing (see Test 7)

#### 6.3: First Win
- **Trigger**: Win your first pool
- **Achievement**: "first_pool_win"
- **Reward**: +100 BR
- **Verification**:
  - Requires pool completion and winning

### Expected Results
- ✅ Achievements trigger automatically
- ✅ BR rewards credited instantly
- ✅ Notification shown to user
- ✅ Achievement appears in profile/rewards screen
- ✅ Transaction recorded

### Verification Query
```python
# Check user_achievements collection
# Should show unlocked achievements with timestamps
```

---

## Test 7: Multi-Day Streak Tracking

### Objective
Test login streak across multiple days

**Note**: This test requires multi-day execution OR time manipulation

### Day 1 (Today - 2025-01-06)
- [x] Claim daily bonus: +50 BR
- [x] Verify streak: 1 day
- [x] Balance: 1000 → 1050 BR

### Day 2 (2025-01-07)
- [ ] Login to app
- [ ] Claim daily bonus: +50 BR
- [ ] Verify streak: 2 days
- [ ] Check calendar: Days 1-2 have checkmarks
- [ ] Balance: 1050 → 1100 BR

### Day 3 (2025-01-08)
- [ ] Login to app
- [ ] Claim daily bonus: +50 BR
- [ ] Verify streak: 3 days
- [ ] Check calendar: Days 1-3 have checkmarks
- [ ] Balance: 1100 → 1150 BR
- [ ] Check: "3-Day Streak" achievement unlocked (+50 BR)
- [ ] Balance: 1150 → 1200 BR

### Day 4 (2025-01-09)
- [ ] Login to app
- [ ] Claim daily bonus: +50 BR
- [ ] Verify streak: 4 days
- [ ] Balance: 1200 → 1250 BR

### Day 5 (2025-01-10)
- [ ] Login to app
- [ ] Claim daily bonus: +50 BR
- [ ] Verify streak: 5 days
- [ ] Balance: 1250 → 1300 BR

### Day 6 (2025-01-11)
- [ ] Login to app
- [ ] Claim daily bonus: +50 BR
- [ ] Verify streak: 6 days
- [ ] Balance: 1300 → 1350 BR

### Day 7 (2025-01-12)
- [ ] Login to app
- [ ] Claim daily bonus: +50 BR (daily) + 100 BR (streak bonus)
- [ ] Verify streak: Resets to 0 after claiming
- [ ] Check calendar: All 7 days have checkmarks
- [ ] Check: Day 7 shows fire icon 🔥
- [ ] Balance: 1350 → 1500 BR
- [ ] Check: "7-Day Streak" achievement unlocked (+100 BR)
- [ ] Balance: 1500 → 1600 BR

### Streak Break Test
**Day 8**: Skip login (no claim)
**Day 9**: Login and claim
- [ ] Verify streak reset to 1
- [ ] Check longestLoginStreak preserved (should be 7)
- [ ] Balance: 1600 → 1650 BR

### Expected Results
- ✅ Streak increments daily
- ✅ Day 7 awards bonus +100 BR
- ✅ Streak resets after day 7 bonus
- ✅ Skipping a day resets streak to 1
- ✅ Longest streak preserved
- ✅ Calendar UI accurate

---

## Test 8: Transaction History

### Objective
Verify all transactions recorded and displayed

### Steps

1. **Navigate to Transaction History**
   - Action: Tap BR balance widget
   - Expected: Transaction History screen opens

2. **Verify Transactions Listed**
   - Check: All transactions from today shown
   - Expected entries:
     - Initial balance (1000 BR)
     - Daily bonus (+50 BR)
     - Pool entry (-100 BR)
     - Achievement (+50 BR if unlocked)

3. **Check Transaction Details**
   - For each transaction, verify:
     - Type (earn/spend)
     - Source (daily_bonus, pool_entry, achievement)
     - Amount (correct value)
     - Timestamp (accurate)
     - Balance before/after

4. **Test Filters**
   - Action: Filter by "Earnings"
   - Expected: Only earn transactions shown
   - Action: Filter by "Spending"
   - Expected: Only spend transactions shown
   - Action: Filter by date range
   - Expected: Only transactions in range shown

5. **Test Sorting**
   - Check: Transactions sorted by date (newest first)
   - Action: Change sort order (if available)
   - Expected: List re-orders

### Expected Results
- ✅ All transactions recorded
- ✅ Correct amounts and types
- ✅ Timestamps accurate
- ✅ Balance tracking correct
- ✅ Filters and sorting work

---

## Test 9: Team Records Display

### Objective
Verify team records shown instead of odds in free tier

### Steps

1. **View Game Cards**
   - Action: Browse games list
   - Check: Each game shows team records (e.g., "8-5")
   - Check: NO odds displayed (no moneyline, spread, total)
   - Check: Underdog badge on team with worse record

2. **Verify Record Parsing**
   - Standard records: "10-5" (wins-losses)
   - Records with ties: "8-3-2" (wins-losses-ties)
   - Empty records: "0-0" or null

3. **Verify Underdog Badge**
   - Check: Badge appears on correct team (lower win%)
   - Check: Badge color/icon matches theme
   - Check: No badge when records equal (e.g., "5-5" vs "5-5")

### Test Cases
| Home Record | Away Record | Underdog | Win% Diff | Bonus Tier |
|-------------|-------------|----------|-----------|------------|
| "3-10"      | "10-3"      | Home     | 0.538     | +50        |
| "7-6"       | "6-7"       | Away     | 0.077     | +10        |
| "5-5"       | "5-5"       | None     | 0.000     | 0          |
| "8-3-2"     | "5-6-1"     | Away     | 0.275     | +30        |

### Expected Results
- ✅ Records displayed in all game views
- ✅ No odds shown (free tier restriction)
- ✅ Underdog badges accurate
- ✅ Ties handled correctly (counted as 0.5 wins)

---

## Test 10: Free Tier Restrictions

### Objective
Verify free tier users cannot access premium features

### Restrictions to Test

#### 10.1: No Odds Display
- **Check**: Moneyline odds NOT shown on game cards
- **Check**: Spread NOT shown
- **Check**: Total (Over/Under) NOT shown
- **Expected**: Only team records and winner picks available

#### 10.2: No Spread/Total Picks
- **Check**: Pick screen shows only "Winner" tab
- **Check**: "Spread" and "Totals" tabs NOT visible
- **Check**: Cannot submit spread or total picks

#### 10.3: No Odds-Based Pools
- **Check**: Pool list shows only simple pick pools
- **Check**: Cannot join spread or total pools
- **Check**: Odds-based pools show "Premium Only" lock

#### 10.4: Premium Upgrade Prompts
- **Check**: Tapping locked features shows upgrade prompt
- **Check**: Prompt explains premium benefits
- **Check**: "Upgrade to Premium" button shown

### Expected Results
- ✅ Free tier fully restricted to simple picks
- ✅ No odds data accessible
- ✅ Premium features locked with prompts
- ✅ Upgrade path clearly communicated

---

## Post-Test Verification

### Final State Check
Run: `python scripts/query_user.py`

Expected final state (after all tests):
```json
{
  "brBalance": ~950 BR (varies based on achievements),
  "totalBrEarned": ~1150 BR (1000 initial + 50 daily + 50 achievement + 50 pool entry bonus),
  "totalBrSpent": 100 BR (pool entry),
  "loginStreak": 1,
  "longestLoginStreak": 1,
  "adminOverride": {
    "enabled": true,
    "forceFreeTier": true
  }
}
```

### Database Verification
```python
# Check collections:
# 1. br_transactions - should have 3+ entries
# 2. user_achievements - should have 1+ unlocked
# 3. user_pools - should have 1 pool entry
```

---

## Test Summary Template

### Test Execution Date: _____________

| Test # | Test Name | Status | Notes |
|--------|-----------|--------|-------|
| 1 | Daily Bonus Claim | ⬜ Pass ⬜ Fail | |
| 2 | BR Balance Display | ⬜ Pass ⬜ Fail | |
| 3 | Pool Entry with BR | ⬜ Pass ⬜ Fail | |
| 4 | Pick Submission | ⬜ Pass ⬜ Fail | |
| 5 | Underdog Bonus Scoring | ⬜ Pass ⬜ Fail | |
| 6 | Achievements System | ⬜ Pass ⬜ Fail | |
| 7 | Multi-Day Streaks | ⬜ Pass ⬜ Fail | |
| 8 | Transaction History | ⬜ Pass ⬜ Fail | |
| 9 | Team Records Display | ⬜ Pass ⬜ Fail | |
| 10 | Free Tier Restrictions | ⬜ Pass ⬜ Fail | |

### Critical Bugs Found:
- [ ] None
- [ ] List bugs here...

### Minor Issues Found:
- [ ] None
- [ ] List issues here...

### Overall Assessment:
- [ ] ✅ Phase 1 Free Tier Ready for Production
- [ ] ⚠️ Needs bug fixes before production
- [ ] ❌ Major issues blocking release

---

## Next Steps After Testing

### If All Tests Pass:
1. ✅ Mark Phase 1 complete in todo list
2. ✅ Document any edge cases discovered
3. ✅ Begin Phase 2 planning (Premium Tier)
4. ✅ Set up IAP products in App Store Connect & Play Console

### If Tests Fail:
1. ❌ Document all bugs in GitHub Issues
2. ❌ Create bug fix tasks
3. ❌ Prioritize critical vs minor issues
4. ❌ Re-test after fixes

---

## Testing Tips

### Time Manipulation (for Streak Testing)
If you need to test multi-day streaks without waiting:
1. **Option A**: Modify Firebase timestamp manually (admin access)
2. **Option B**: Use device date/time manipulation (may break other features)
3. **Option C**: Wait for actual days to pass (most reliable)

### Quick Balance Reset
To reset test user to clean state:
```python
# Run scripts/reset_test_user.py (create if needed)
# Resets brBalance to 1000, clears transactions, resets streaks
```

### Debugging Tools
- Firebase Console: Check Firestore collections directly
- Flutter DevTools: Monitor app state and streams
- Python scripts: Query user data and transactions

---

**End of Manual Testing Guide**
