# H2H Challenge Tiebreaker System - Implementation Plan

**Date**: 2025-10-10
**Status**: Planning - To Be Implemented Later
**Priority**: High (Reduces tie scenarios significantly)

---

## Table of Contents
1. [Overview](#overview)
2. [Tiebreaker Logic](#tiebreaker-logic)
3. [Sport-Specific Rules](#sport-specific-rules)
4. [User Flow](#user-flow)
5. [Data Structure](#data-structure)
6. [Settlement Logic](#settlement-logic)
7. [UI Components](#ui-components)
8. [Edge Cases](#edge-cases)

---

## Overview

### Problem Statement
In H2H challenges, when both users pick the same outcome, it results in an unsatisfying tie. This system adds a **spread prediction tiebreaker** to determine a winner even when both users pick the same team.

### Solution
Users predict the **final spread** (margin of victory) when creating/accepting challenges. If both pick the same winner, the user with the closest spread prediction wins.

### Sports Covered
- ✅ NBA
- ✅ NFL
- ✅ NHL
- ✅ MLB
- ❌ MMA/Boxing (not applicable yet - different tiebreaker TBD)
- ❌ Soccer (TBD - may use exact score prediction)

---

## Tiebreaker Logic

### How It Works

**Step 1: Primary Winner Determination**
- User picks winning team
- If teams picked are different → Winner is user who picked actual winner
- Tiebreaker NOT used

**Step 2: Tiebreaker (Same Team Picked)**
- Both users picked same team
- Compare spread predictions to actual spread
- User closest to actual spread wins

**Step 3: Both Wrong**
- Both users picked losing team
- User with closer spread prediction wins
- Encourages skill even when wrong

---

## Sport-Specific Rules

### NBA / NFL / NHL

**Spread Prediction:**
- User predicts margin of victory in points
- Range: ±1 to ±30 points (NBA/NHL), ±1 to ±50 points (NFL)
- Example: "Lakers by 8 points"

**Calculation:**
```
Actual Spread = Winning Score - Losing Score
User A Difference = |User A Prediction - Actual Spread|
User B Difference = |User B Prediction - Actual Spread|

Winner = User with smallest difference
```

**Example:**
```
Game: Lakers vs Warriors

Challenger: Lakers by 8
Opponent: Lakers by 5
Actual Result: Lakers win 112-107 (Lakers by 5)

Challenger Diff: |8 - 5| = 3
Opponent Diff: |5 - 5| = 0

Winner: Opponent (exact prediction!)
```

---

### MLB

**Run Differential Prediction:**
- User predicts run differential
- Range: ±1 to ±10 runs
- Example: "Red Sox by 3 runs"

**Calculation:**
```
Actual Differential = Winning Runs - Losing Runs
User A Difference = |User A Prediction - Actual Differential|
User B Difference = |User B Prediction - Actual Differential|

Winner = User with smallest difference
```

---

### MMA/Boxing

**Status:** NOT IMPLEMENTED YET

**Future Consideration:**
- Method of victory (KO/Decision/Submission)
- Round prediction
- Exact outcome prediction

---

### Soccer

**Status:** TBD

**Future Consideration:**
- Exact score prediction
- Goal differential
- Total goals over/under

---

## User Flow

### Challenge Creation Flow

```
User taps "CREATE CHALLENGE" on game card
    ↓
Challenge Setup Screen appears
    ↓
[1] User selects team
    "Lakers -3.5" (tap to select)
    ↓
[2] Spread prediction input appears
    "Predict Final Spread"
    "Lakers will win by: [__8__] points"
    ↓
[3] User enters spread prediction
    - Numeric input (1-30 for NBA)
    - Stepper buttons (+/-) for easy adjustment
    - Preview: "Lakers by 8 points"
    ↓
[4] User selects opponent type
    - Random / Open / Friend
    ↓
[5] User taps "SEND CHALLENGE (25 BR)"
    ↓
Challenge created with:
    - Pick: Lakers
    - Spread Prediction: 8
    - Entry: 25 BR deducted
```

---

### Challenge Acceptance Flow

```
Opponent sees challenge notification/feed
    ↓
Opponent taps "ACCEPT CHALLENGE"
    ↓
Challenge Accept Screen appears
    ↓
Shows challenger's pick: "Lakers -3.5"
Shows: "Challenger predicted: [HIDDEN]" ← Don't reveal prediction
    ↓
[1] Opponent selects team
    Option A: Warriors +3.5 (opposite)
    Option B: Lakers -3.5 (same, if allowed)
    ↓
[2] Spread prediction input appears
    "Predict Final Spread"
    "Warriors will win by: [__2__] points" (if pick Warriors)
    OR
    "Lakers will win by: [__5__] points" (if pick Lakers)
    ↓
[3] Opponent enters prediction
    ↓
[4] Opponent taps "ACCEPT CHALLENGE (25 BR)"
    ↓
Challenge matched:
    - Opponent's 25 BR deducted
    - Status → 'matched'
    - Both picks locked
    - Wait for game result
```

---

## Data Structure

### Firestore Collection: `h2h_challenges`

```dart
{
  // Basic Challenge Info
  'id': 'challenge_12345',
  'eventId': 'game_67890',
  'eventName': 'Lakers vs Warriors',
  'sport': 'NBA',
  'gameTime': Timestamp,
  'status': 'matched', // open | matched | live | completed | expired | cancelled

  // Entry & Pot
  'entryFee': 25,
  'totalPot': 50,

  // Challenger Info
  'challengerId': 'user_abc',
  'challengerName': 'JohnDoe',
  'challengerPick': 'Lakers',
  'challengerSpread': -3.5, // Odds spread
  'challengerSpreadPrediction': 8, // NEW: User's prediction (Lakers by 8)

  // Opponent Info
  'opponentId': 'user_xyz',
  'opponentName': 'MikeSmith',
  'opponentPick': 'Lakers', // Can be same as challenger
  'opponentSpread': -3.5,
  'opponentSpreadPrediction': 5, // NEW: User's prediction (Lakers by 5)

  // Game Result (filled after game ends)
  'actualWinner': 'Lakers',
  'actualHomeScore': 112,
  'actualAwayScore': 107,
  'actualSpread': 5, // NEW: Lakers won by 5 points

  // Tiebreaker Calculation
  'tiebreakUsed': true, // NEW: Was tiebreaker needed?
  'challengerSpreadDiff': 3, // NEW: |8 - 5| = 3
  'opponentSpreadDiff': 0, // NEW: |5 - 5| = 0

  // Winner
  'winnerId': 'user_xyz', // Opponent won via tiebreaker
  'winMethod': 'tiebreaker', // NEW: 'team_pick' | 'tiebreaker' | 'both_wrong'

  // Timestamps
  'createdAt': Timestamp,
  'matchedAt': Timestamp,
  'completedAt': Timestamp,

  // Metadata
  'isActive': true,
  'notificationSent': false,
}
```

---

### New Fields Explained

| Field | Type | Description |
|-------|------|-------------|
| `challengerSpreadPrediction` | int | Challenger's predicted margin (e.g., 8 = "win by 8") |
| `opponentSpreadPrediction` | int | Opponent's predicted margin |
| `actualSpread` | int | Actual margin of victory (winning score - losing score) |
| `tiebreakUsed` | bool | True if both picked same team |
| `challengerSpreadDiff` | int | Absolute difference from actual spread |
| `opponentSpreadDiff` | int | Absolute difference from actual spread |
| `winMethod` | string | How winner was determined |

---

## Settlement Logic

### Settlement Function Flow

```dart
Future<void> settleH2HChallenge(String challengeId, GameResult result) async {
  final challenge = await _getChallenge(challengeId);

  // Calculate actual spread
  final actualSpread = result.homeScore - result.awayScore;
  final actualWinner = actualSpread > 0 ? 'home' : 'away';

  // Determine picks (convert to home/away)
  final challengerPickedHome = challenge.challengerPick == result.homeTeam;
  final opponentPickedHome = challenge.opponentPick == result.homeTeam;

  String? winnerId;
  String winMethod;

  // CASE 1: Different teams picked
  if (challengerPickedHome != opponentPickedHome) {
    // Simple winner determination
    final challengerCorrect = (challengerPickedHome && actualSpread > 0) ||
                               (!challengerPickedHome && actualSpread < 0);

    winnerId = challengerCorrect ? challenge.challengerId : challenge.opponentId;
    winMethod = 'team_pick';

    await _updateChallenge(challengeId, {
      'actualWinner': actualWinner,
      'actualSpread': actualSpread.abs(),
      'tiebreakUsed': false,
      'winnerId': winnerId,
      'winMethod': winMethod,
      'status': 'completed',
    });
  }

  // CASE 2: Same team picked - USE TIEBREAKER
  else {
    // Calculate spread differences
    final challengerDiff = (challenge.challengerSpreadPrediction - actualSpread.abs()).abs();
    final opponentDiff = (challenge.opponentSpreadPrediction - actualSpread.abs()).abs();

    // Determine winner by closest prediction
    if (challengerDiff < opponentDiff) {
      winnerId = challenge.challengerId;
    } else if (opponentDiff < challengerDiff) {
      winnerId = challenge.opponentId;
    } else {
      // EXACT TIE - both same distance from actual
      winnerId = null; // Will split pot
    }

    // Check if both were wrong (picked losing team)
    final bothWrong = (challengerPickedHome && actualSpread < 0) ||
                      (!challengerPickedHome && actualSpread > 0);

    winMethod = bothWrong ? 'both_wrong' : 'tiebreaker';

    await _updateChallenge(challengeId, {
      'actualWinner': actualWinner,
      'actualSpread': actualSpread.abs(),
      'tiebreakUsed': true,
      'challengerSpreadDiff': challengerDiff,
      'opponentSpreadDiff': opponentDiff,
      'winnerId': winnerId,
      'winMethod': winMethod,
      'status': 'completed',
    });
  }

  // Process payout
  await _processPayout(challenge, winnerId);
}
```

---

### Payout Logic

```dart
Future<void> _processPayout(Challenge challenge, String? winnerId) async {
  final totalPot = challenge.totalPot; // 50 BR

  if (winnerId != null) {
    // Clear winner - pay out full pot
    await WalletService().addToWallet(
      winnerId,
      totalPot,
      'H2H Win: ${challenge.eventName}',
      metadata: {
        'type': 'h2h_win',
        'challengeId': challenge.id,
        'method': challenge.winMethod,
      },
    );
  } else {
    // Exact tie - split pot 50/50
    await WalletService().addToWallet(
      challenge.challengerId,
      totalPot ~/ 2,
      'H2H Tie: ${challenge.eventName}',
    );

    await WalletService().addToWallet(
      challenge.opponentId,
      totalPot ~/ 2,
      'H2H Tie: ${challenge.eventName}',
    );
  }

  // Send notifications
  await _sendResultNotifications(challenge, winnerId);
}
```

---

## UI Components

### Challenge Setup Screen

**New Section: Spread Prediction**

```dart
// After team selection
if (_selectedTeam != null) {
  Container(
    padding: EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.1),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: Colors.amber),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'TIEBREAKER: Predict Final Spread',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        SizedBox(height: 12),
        Text(
          '$_selectedTeam will win by:',
          style: TextStyle(fontSize: 13, color: Colors.white70),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.remove_circle, color: Colors.white),
              onPressed: () => _decrementSpread(),
            ),
            Container(
              width: 80,
              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '$_spreadPrediction',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            IconButton(
              icon: Icon(Icons.add_circle, color: Colors.white),
              onPressed: () => _incrementSpread(),
            ),
          ],
        ),
        SizedBox(height: 8),
        Center(
          child: Text(
            'points',
            style: TextStyle(fontSize: 12, color: Colors.white60),
          ),
        ),
        SizedBox(height: 12),
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '💡 Used if both pick same winner',
            style: TextStyle(fontSize: 11, color: Colors.white70),
            textAlign: TextAlign.center,
          ),
        ),
      ],
    ),
  ),
}
```

---

### Challenge Card Display

**Show Tiebreaker in Challenge Details:**

```dart
// In active challenge card
if (challenge.tiebreakUsed) {
  Row(
    children: [
      Icon(Icons.compare_arrows, size: 14, color: Colors.amber),
      SizedBox(width: 4),
      Text(
        'Tiebreaker: ${challenge.challengerPick} by ${challenge.challengerSpreadPrediction}',
        style: TextStyle(fontSize: 11, color: Colors.white70),
      ),
    ],
  ),
}
```

---

### Result Screen

**Show Tiebreaker Result:**

```dart
if (challenge.tiebreakUsed) {
  Container(
    padding: EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: Colors.amber.withOpacity(0.1),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: Colors.amber),
    ),
    child: Column(
      children: [
        Text(
          '⚖️ TIEBREAKER USED',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.amber,
          ),
        ),
        SizedBox(height: 8),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                Text('You', style: TextStyle(fontSize: 11)),
                Text(
                  '${challenge.challengerPick} by ${challenge.challengerSpreadPrediction}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Off by ${challenge.challengerSpreadDiff}',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
            Column(
              children: [
                Text('Opponent', style: TextStyle(fontSize: 11)),
                Text(
                  '${challenge.opponentPick} by ${challenge.opponentSpreadPrediction}',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
                ),
                Text(
                  'Off by ${challenge.opponentSpreadDiff}',
                  style: TextStyle(fontSize: 11, color: Colors.white70),
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 8),
        Text(
          'Actual: ${challenge.actualWinner} by ${challenge.actualSpread}',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: Colors.green,
          ),
        ),
      ],
    ),
  ),
}
```

---

## Edge Cases

### 1. Exact Tie on Spread Prediction

**Scenario:**
- Challenger: Lakers by 8
- Opponent: Lakers by 8
- Actual: Lakers by 5

**Resolution:**
- Both off by 3 points → EXACT TIE
- Split pot 50/50 (25 BR each)
- Status: 'completed'
- Winner: null

**Alternative:** Add secondary tiebreaker (total points prediction)

---

### 2. Both Wrong, But One Closer

**Scenario:**
- Challenger: Lakers by 8
- Opponent: Lakers by 5
- Actual: Warriors by 3

**Resolution:**
- Both picked wrong team (Lakers lost)
- Opponent closer to actual spread (5 vs 8)
- Winner: Opponent
- Win Method: 'both_wrong'
- Rationale: Rewards better prediction even when wrong

---

### 3. Blowout Games

**Scenario:**
- Challenger: Lakers by 25
- Opponent: Lakers by 8
- Actual: Lakers by 30

**Resolution:**
- Challenger closer (off by 5 vs off by 22)
- Winner: Challenger
- Note: No max spread limit prevents gaming

---

### 4. Overtime Games

**Scenario:**
- Game goes to OT
- Final score: Lakers 118, Warriors 115

**Resolution:**
- Use final score including OT
- Actual spread: Lakers by 3
- Calculate as normal

---

### 5. Forfeit/Cancelled Games

**Scenario:**
- Game cancelled due to weather/COVID/etc.

**Resolution:**
- Auto-refund both users
- Status: 'cancelled'
- No winner declared

---

### 6. Push on Spread

**Scenario:**
- Challenger: Lakers by 5
- Opponent: Warriors by 0 (even)
- Actual: Lakers by 5 (exact)

**Resolution:**
- Challenger exact prediction → WIN
- Even if opponent picked wrong team

---

## Implementation Checklist

### Phase 1: Data Model
- [ ] Add spread prediction fields to Challenge model
- [ ] Add tiebreaker calculation fields
- [ ] Update Firestore security rules
- [ ] Create migration script for existing challenges

### Phase 2: UI Components
- [ ] Create SpreadPredictionInput widget
- [ ] Update Challenge Setup Screen
- [ ] Update Challenge Accept Screen
- [ ] Update Challenge Detail Screen
- [ ] Update Result Screen with tiebreaker display

### Phase 3: Business Logic
- [ ] Implement spread validation (1-30 for NBA, etc.)
- [ ] Update challenge creation service
- [ ] Update challenge acceptance service
- [ ] Implement tiebreaker settlement logic
- [ ] Update payout service

### Phase 4: Testing
- [ ] Test same team + tiebreaker scenarios
- [ ] Test exact tie scenarios
- [ ] Test both wrong scenarios
- [ ] Test blowout games
- [ ] Test edge cases (OT, forfeit, etc.)

### Phase 5: Analytics
- [ ] Track tiebreaker usage rate
- [ ] Track average spread accuracy
- [ ] Track user engagement with feature
- [ ] Monitor tie rate reduction

---

## Success Metrics

### Key Performance Indicators

1. **Tie Rate Reduction**
   - Current: ~25% (estimated)
   - Target: <5%

2. **User Engagement**
   - % of users entering spread predictions
   - Average time spent on prediction

3. **Prediction Accuracy**
   - Average spread difference
   - % of exact predictions
   - % within 3 points

4. **User Satisfaction**
   - Survey: "Tiebreaker made challenges more fair"
   - Repeat challenge rate
   - Challenge completion rate

---

## Future Enhancements

### V2 Features (Later)

1. **Secondary Tiebreakers**
   - Total points prediction
   - First scoring team
   - Time of first score

2. **MMA/Boxing Tiebreakers**
   - Method of victory
   - Round prediction
   - Fight duration

3. **Leaderboards**
   - Most accurate predictors
   - Spread prediction accuracy rankings
   - Tiebreaker win %

4. **Achievements**
   - "Perfect Prediction" (exact spread)
   - "Close Call" (within 1 point)
   - "Tiebreaker Master" (10 tiebreaker wins)

5. **Tutorials**
   - In-app guide explaining tiebreakers
   - Tips for spread prediction
   - Historical accuracy data

---

## Notes

- **Design Philosophy:** Keep tiebreaker simple and skill-based
- **User Education:** Emphasize this is NOT a sportsbook bet, it's a skill prediction
- **Fair Play:** Opponent's prediction hidden until both locked in
- **Transparency:** Show full calculation in results screen

---

**Document Version:** 1.0
**Last Updated:** 2025-10-10
**Author:** Claude Code
**Status:** Ready for Implementation
