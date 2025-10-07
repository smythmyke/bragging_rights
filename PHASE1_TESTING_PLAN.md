# Phase 1 Free Tier Testing Plan

## Overview
Comprehensive testing plan for the freemium free tier implementation before moving to Phase 2 (Premium Tier).

## Test Environment Setup
- **Test User**: smythmyke@gmail.com (ID: JLl6AoOXHHUhIIW4t7xWDyqWsPm2)
- **Admin Override**: Enabled for tier testing (free/premium switching)
- **BR Balance**: 1000 BR starting balance
- **Test Device**: Windows development environment
- **Database**: Firebase Firestore (bragging-rights-ea6e1)

## Week 6 Testing Tasks

### 1. End-to-End Free Tier Flow Testing

#### Test Case 1.1: New User Onboarding
**Objective**: Verify complete new user experience from signup to first pool

**Steps**:
1. Create new test user account
2. Verify initial BR balance (should be 1000 BR)
3. Check that daily bonus is claimable
4. Verify achievement tracking initialization

**Expected Results**:
- ✅ User created with default BR balance
- ✅ All BR currency fields initialized
- ✅ Login streak starts at 0
- ✅ Can claim first daily bonus

**Test Data**:
```
Initial State:
- brBalance: 1000
- totalBrEarned: 1000
- totalBrSpent: 0
- loginStreak: 0
- longestLoginStreak: 0
```

#### Test Case 1.2: Daily Bonus Claim Flow
**Objective**: Test daily bonus claiming and streak tracking

**Steps**:
1. Navigate to Daily Bonus screen
2. Verify "canClaim" status shows true
3. Click "Claim Bonus" button
4. Verify success dialog appears
5. Check BR balance increased by 50
6. Verify daily bonus cannot be claimed again today
7. Check transaction history shows daily_bonus entry

**Expected Results**:
- ✅ Bonus claim button is active and glowing
- ✅ Success dialog shows "+50 BR"
- ✅ Balance updates from 1000 to 1050
- ✅ Button becomes disabled with "Already Claimed"
- ✅ Transaction recorded in br_transactions

**Test Data**:
```
Before Claim:
- brBalance: 1000
- canClaim: true
- currentStreak: 0

After Claim:
- brBalance: 1050
- canClaim: false
- currentStreak: 1
- lastDailyBonus: [current timestamp]
- lastLoginDate: "2025-01-06"
```

#### Test Case 1.3: Pool Selection and Entry
**Objective**: Test browsing pools and paying BR to enter

**Steps**:
1. Navigate to Games screen
2. Select an active game
3. View available pools (should be simple pick pools only)
4. Select a pool with buy-in ≤ current balance
5. Click "Join Pool"
6. Verify BR balance decreased by buy-in amount
7. Verify pool shows user as joined

**Expected Results**:
- ✅ Only simple pick pools displayed (no odds-based pools)
- ✅ Team records displayed instead of odds
- ✅ Underdog badge shows for team with worse record
- ✅ BR deducted from balance
- ✅ User appears in pool playerIds array
- ✅ Transaction recorded as pool_entry

**Test Data**:
```
Pool Entry:
- Pool Buy-in: 100 BR
- Balance Before: 1050 BR
- Balance After: 950 BR
- Pool currentPlayers: increments by 1
- user_pools document created
```

#### Test Case 1.4: Pick Submission
**Objective**: Test submitting picks in a pool

**Steps**:
1. Open joined pool
2. View game matchups
3. Select picks for each game (simple picks, no spread/total)
4. Submit picks
5. Verify picks are locked
6. Check that picks cannot be changed after submission

**Expected Results**:
- ✅ Can select picks for all games
- ✅ Pick submission succeeds
- ✅ Picks locked with timestamp
- ✅ No edit option after lock
- ✅ UI shows "Picks Submitted"

#### Test Case 1.5: Game Scoring with Underdog Bonus
**Objective**: Verify simple pick scoring with record-based underdog detection

**Steps**:
1. Create test game with team records
2. Set homeTeamRecord: "3-7" (underdog)
3. Set awayTeamRecord: "8-2" (favorite)
4. Submit pick for home team (underdog)
5. Mark game as final with home team win
6. Verify underdog bonus applied to score

**Expected Results**:
- ✅ Underdog detected: team with worse record
- ✅ Pick on underdog gets bonus points
- ✅ GameResult includes underdogBonus field
- ✅ Final score calculation includes bonus
- ✅ User sees bonus in results breakdown

**Test Data**:
```
Game Setup:
- homeTeamRecord: "3-7" (win% = 0.30)
- awayTeamRecord: "8-2" (win% = 0.80)
- Underdog: Home Team (lower win%)

Scoring:
- Base Points: 100
- Underdog Bonus: +50 (example)
- Total Points: 150
```

### 2. Underdog Bonus Calculation Verification

#### Test Case 2.1: Record Parsing
**Objective**: Verify correct parsing of various record formats

**Test Records**:
```
Standard Records:
- "10-5" → wins=10, losses=5, winPct=0.667
- "5-10" → wins=5, losses=10, winPct=0.333
- "0-0" → wins=0, losses=0, winPct=null (no games)

Records with Ties:
- "8-3-2" → wins=8, losses=3, ties=2, winPct=0.692
  (ties count as 0.5 wins: (8 + 1) / 13 = 0.692)
- "5-5-3" → wins=5, losses=5, ties=3, winPct=0.500
  ((5 + 1.5) / 13 = 0.500)
```

**Expected Results**:
- ✅ Standard records parse correctly
- ✅ Ties counted as 0.5 wins
- ✅ Empty records (0-0) handled gracefully
- ✅ Win percentage calculated accurately

#### Test Case 2.2: Underdog Detection
**Objective**: Verify correct underdog identification

**Test Scenarios**:
```
Scenario 1: Clear Underdog
- Home: "3-10" (0.231)
- Away: "10-3" (0.769)
- Underdog: Home Team ✓

Scenario 2: Close Records
- Home: "7-6" (0.538)
- Away: "6-7" (0.462)
- Underdog: Away Team ✓

Scenario 3: Equal Records
- Home: "5-5" (0.500)
- Away: "5-5" (0.500)
- Underdog: None (no bonus)

Scenario 4: With Ties
- Home: "6-4-3" (0.577)
- Away: "8-3-2" (0.692)
- Underdog: Home Team ✓
```

**Expected Results**:
- ✅ Team with lower win% identified as underdog
- ✅ Equal records = no underdog
- ✅ Ties factored into calculation
- ✅ Underdog badge displays correctly

#### Test Case 2.3: Bonus Points Calculation
**Objective**: Verify underdog bonus point awards

**Test Cases**:
```
Bonus Tiers (from simple_pick_scoring.dart):
- Win% Difference 0.000-0.100: +10 points
- Win% Difference 0.101-0.200: +20 points
- Win% Difference 0.201-0.300: +30 points
- Win% Difference 0.301+: +50 points

Test Case A:
- Home: "7-8" (0.467)
- Away: "8-7" (0.533)
- Difference: 0.066
- Expected Bonus: +10 points

Test Case B:
- Home: "5-10" (0.333)
- Away: "10-5" (0.667)
- Difference: 0.334
- Expected Bonus: +50 points

Test Case C:
- Home: "6-9" (0.400)
- Away: "10-5" (0.667)
- Difference: 0.267
- Expected Bonus: +30 points
```

**Expected Results**:
- ✅ Bonus tier correctly identified
- ✅ Points awarded match tier
- ✅ Bonus shows in GameResult
- ✅ Total score includes bonus

**✅ TEST RESULTS - COMPLETED 2025-01-06**:
```
Script: scripts/test_underdog_bonus.py
Total Tests: 22
Passed: 22
Failed: 0
Success Rate: 100.0%

Test Coverage:
- 10 comprehensive scenarios (ties, extreme underdogs, close matchups, equal records)
- 12 bonus tier verification tests (all 4 tiers validated)

Key Validations:
✅ Record parsing handles standard format (W-L)
✅ Record parsing handles ties (W-L-T), counted as 0.5 wins
✅ Empty records (0-0) return null gracefully
✅ Underdog detection accurate (lower win% = underdog)
✅ Equal records yield no underdog bonus
✅ Bonus tiers correct:
   - 0.000-0.100 difference: +10 points
   - 0.101-0.200 difference: +20 points
   - 0.201-0.300 difference: +30 points
   - 0.301+ difference: +50 points
✅ Python test logic matches Dart implementation in simple_pick_scoring.dart
```

### 3. Streak Tracking Multi-Day Testing

#### Test Case 3.1: Consecutive Day Login
**Objective**: Verify streak increments on consecutive logins

**Test Plan** (requires time manipulation or manual testing):
```
Day 1:
- Claim bonus
- Streak: 1
- Balance: +50 BR

Day 2:
- Claim bonus
- Streak: 2
- Balance: +50 BR

Day 3:
- Claim bonus
- Streak: 3
- Balance: +50 BR

...

Day 7:
- Claim bonus
- Streak: 7 (triggers bonus)
- Balance: +50 BR (daily) + 100 BR (streak) = +150 BR
- Streak resets to 0
```

**Expected Results**:
- ✅ Streak increments each consecutive day
- ✅ 7-day bonus triggers on day 7
- ✅ Streak resets after bonus claimed
- ✅ longestLoginStreak updated if exceeded

#### Test Case 3.2: Streak Break
**Objective**: Verify streak resets when day is skipped

**Test Plan**:
```
Day 1: Claim bonus → Streak: 1
Day 2: Claim bonus → Streak: 2
Day 3: Claim bonus → Streak: 3
Day 4: SKIP (no login)
Day 5: Claim bonus → Streak: 1 (reset)
```

**Expected Results**:
- ✅ Streak resets to 1 after skip
- ✅ longestLoginStreak preserved
- ✅ No 7-day bonus awarded

#### Test Case 3.3: Streak Calendar UI
**Objective**: Verify visual streak calendar is accurate

**Test Checkpoints**:
- ✅ Current day highlighted with green border
- ✅ Completed days show checkmark
- ✅ Day 7 shows fire icon when completed
- ✅ Future days show day number
- ✅ Progress updates in real-time

### 4. BR Currency Flow Testing

#### Test Case 4.1: BR Earning Sources
**Objective**: Verify all BR earning methods work

**Test Each Source**:
```
✅ Daily Bonus: +50 BR
✅ 7-Day Streak: +100 BR
✅ Referral Bonus: +200 BR per friend
✅ Video Ad: +25 BR (max 5/day = 125 BR)
✅ Achievement: Variable BR (50-1000)
✅ Pool Winnings: Based on pool prize
```

**Verification**:
- Check balance increases
- Verify transaction recorded
- Confirm source field correct

#### Test Case 4.2: BR Spending
**Objective**: Verify all BR spending methods work

**Test Each Spend**:
```
✅ Pool Entry: -[buyIn] BR
✅ Pool Creation: -[buyIn] BR (creator auto-joins)
```

**Verification**:
- Check balance decreases
- Verify insufficient balance blocks transaction
- Confirm transaction recorded

#### Test Case 4.3: Balance Display
**Objective**: Test BR balance widgets

**Test Locations**:
- ✅ Compact widget in app bar
- ✅ Full widget in wallet/profile screen
- ✅ Real-time updates on balance change
- ✅ Animated notifications on increase

### 5. Achievements Testing

#### Test Case 5.1: Achievement Triggers
**Objective**: Verify achievements awarded correctly

**Test Achievements**:
```
First Pool Entry:
- Join 1 pool
- Achievement: "first_pool"
- Reward: +50 BR

First Win:
- Win 1 pool
- Achievement: "first_win"
- Reward: +100 BR

3-Day Streak:
- Login 3 consecutive days
- Achievement: "login_streak_3"
- Reward: +50 BR

First Referral:
- Refer 1 friend
- Achievement: "first_referral"
- Reward: +200 BR
```

**Expected Results**:
- ✅ Achievement triggers automatically
- ✅ user_achievements document created
- ✅ BR reward credited
- ✅ Achievement shown as completed

#### Test Case 5.2: Achievement UI
**Objective**: Test achievements display

**Verification**:
- ✅ Can view all achievements
- ✅ Progress shown for multi-step
- ✅ Completed achievements marked
- ✅ Tier colors correct (bronze/silver/gold/platinum)
- ✅ BR rewards displayed

### 6. Transaction History Testing

#### Test Case 6.1: Transaction Recording
**Objective**: Verify all transactions recorded

**Transaction Types**:
```
✅ earn - daily_bonus
✅ earn - streak_bonus
✅ earn - referral
✅ earn - ad_watch
✅ earn - achievement
✅ spend - pool_entry
```

**Verification**:
- Timestamp correct
- Amount correct
- Balance before/after tracked
- Metadata included

#### Test Case 6.2: Transaction History UI
**Objective**: Test transaction history screen

**Features**:
- ✅ List all transactions
- ✅ Filter by type
- ✅ Filter by date range
- ✅ Pagination works
- ✅ Sort by date (newest first)
- ✅ Export functionality

## Test Execution Checklist

### Pre-Test Setup
- [ ] Verify Firebase connection
- [ ] Confirm test user exists
- [ ] Reset test user BR balance if needed
- [ ] Clear test data from previous runs
- [ ] Enable admin override for testing

### Execution
- [ ] Run Test Case 1.1: New User Onboarding
- [ ] Run Test Case 1.2: Daily Bonus Claim
- [ ] Run Test Case 1.3: Pool Entry
- [ ] Run Test Case 1.4: Pick Submission
- [ ] Run Test Case 1.5: Scoring with Underdog
- [ ] Run Test Case 2.1: Record Parsing
- [ ] Run Test Case 2.2: Underdog Detection
- [ ] Run Test Case 2.3: Bonus Calculation
- [ ] Run Test Case 3.1: Streak Increment
- [ ] Run Test Case 3.2: Streak Break
- [ ] Run Test Case 3.3: Streak UI
- [ ] Run Test Case 4.1: BR Earning
- [ ] Run Test Case 4.2: BR Spending
- [ ] Run Test Case 4.3: Balance Display
- [ ] Run Test Case 5.1: Achievement Triggers
- [ ] Run Test Case 5.2: Achievement UI
- [ ] Run Test Case 6.1: Transaction Recording
- [ ] Run Test Case 6.2: Transaction History UI

### Post-Test
- [ ] Document any bugs found
- [ ] Verify all critical paths work
- [ ] Confirm free tier ready for production
- [ ] Create bug fix tasks if needed

## Success Criteria

**Phase 1 Testing Complete When**:
- ✅ All test cases pass
- ✅ No critical bugs blocking user flow
- ✅ BR economy balanced and working
- ✅ Underdog bonus calculations accurate
- ✅ Streak tracking reliable
- ✅ UI responsive and intuitive
- ✅ Ready to proceed to Phase 2 (Premium Tier)

## Known Limitations

1. **Multi-Day Testing**: Streak testing requires multiple days or time manipulation
2. **Pool Completion**: Full pool lifecycle testing requires game completion
3. **Referral Testing**: Requires second test account
4. **Ad Rewards**: May require ad SDK integration (can mock for now)

## Next Steps After Testing

1. Fix any critical bugs discovered
2. Document any edge cases
3. Update user documentation
4. Begin Phase 2: Premium Tier Implementation
5. Set up IAP products in App Store Connect & Play Console
