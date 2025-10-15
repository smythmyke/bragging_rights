# Simple Betting System - Build Plan

## Overview
Extend the simple betting system (currently used for MMA/Boxing) to all sports except NFL. This system allows betting without odds data from The Odds API, using only ESPN final game data for settlement.

## Core Principles
1. **Keep existing tab-based UI** - No UI/UX flow changes
2. **Keep existing bet slip system** - Same interaction pattern
3. **Replace odds-based bets with simple yes/no predictions**
4. **Mandatory winner pick + optional additional bets**
5. **Point-based scoring with confidence multipliers**

---

## System Architecture

### **Betting Flow (Unchanged)**
```
User opens game → Tabs displayed → User selects bets → Adds to bet slip → Locks in with BR Coins
```

### **Tab Structure (Modified Content)**

Each sport will have tabs with simple prediction bets instead of odds-based bets:

**Before (Odds-Based):**
```
Winner Tab: "Lakers ML -150" → Click → Add to slip
Spread Tab: "Lakers -5.5 (-110)" → Click → Add to slip
```

**After (Simple Betting):**
```
Winner Tab: "Lakers to Win" → Click → Add to slip
Score Tab: "Lakers score 110+ points" → Click → Add to slip
```

---

## Sport-Specific Tab Configurations

### **NBA** (7 tabs)

#### Tab 1: **Winner** (REQUIRED)
- Pick Lakers to Win (1pt)
- Pick Celtics to Win (1pt)
- Confidence: ⭐⭐⭐⭐⭐

#### Tab 2: **Team Scoring**
- Lakers score 100+ points (1pt)
- Lakers score 110+ points (1pt)
- Lakers score 120+ points (2pt)
- Celtics score 100+ points (1pt)
- Celtics score 110+ points (1pt)
- Celtics score 120+ points (2pt)

#### Tab 3: **Game Total**
- Combined score over 200 (1pt)
- Combined score over 210 (1pt)
- Combined score over 220 (2pt)
- Combined score over 230 (2pt)

#### Tab 4: **Margin**
- Game decided by 1-5 points (2pt)
- Game decided by 6-10 points (2pt)
- Game decided by 10+ points (2pt)
- Game decided by 15+ points (2pt)
- Game decided by 20+ points (3pt)

#### Tab 5: **Player Performance**
- Any player scores 20+ points (1pt)
- Any player scores 25+ points (2pt)
- Any player scores 30+ points (3pt)
- Any player scores 35+ points (3pt)
- Any player scores 40+ points (3pt)

#### Tab 6: **Team Stats**
- Lakers make 10+ threes (2pt)
- Lakers make 12+ threes (2pt)
- Lakers make 15+ threes (3pt)
- Lakers record 25+ assists (2pt)
- Lakers record 30+ assists (3pt)
- Lakers grab 45+ rebounds (2pt)
- Celtics make 10+ threes (2pt)
- Celtics make 12+ threes (2pt)
- Celtics make 15+ threes (3pt)
- Celtics record 25+ assists (2pt)
- Celtics record 30+ assists (3pt)
- Celtics grab 45+ rebounds (2pt)

#### Tab 7: **Efficiency**
- Winner shoots 45%+ FG (2pt)
- Winner shoots 48%+ FG (3pt)
- Winner shoots 35%+ from 3PT (2pt)
- Winner shoots 80%+ FT (2pt)

---

### **NHL** (5 tabs)

#### Tab 1: **Winner** (REQUIRED)
- Pick [Home] to Win (1pt)
- Pick [Away] to Win (1pt)
- Confidence: ⭐⭐⭐⭐⭐

#### Tab 2: **Total Goals**
- Game has 4+ total goals (1pt)
- Game has 5+ total goals (1pt)
- Game has 6+ total goals (2pt)
- Game has 7+ total goals (2pt)
- Game has 8+ total goals (3pt)

#### Tab 3: **Team Goals**
- [Home] scores 3+ goals (1pt)
- [Home] scores 4+ goals (2pt)
- [Home] scores 5+ goals (2pt)
- [Away] scores 3+ goals (1pt)
- [Away] scores 4+ goals (2pt)
- [Away] scores 5+ goals (2pt)

#### Tab 4: **Special Events**
- Either team shut out (3pt)
- Game goes to overtime (2pt)
- Game goes to shootout (3pt)
- Game decided by 1 goal (2pt)
- Game decided by 2+ goals (2pt)

#### Tab 5: **Player Performance**
- Top scorer has 1+ points (1pt)
- Top scorer has 2+ points (2pt)
- Top scorer has 3+ points (3pt)

**Note:** NHL has limited stats from ESPN, so fewer bet options

---

### **MLB** (7 tabs)

#### Tab 1: **Winner** (REQUIRED)
- Pick [Home] to Win (1pt)
- Pick [Away] to Win (1pt)
- Confidence: ⭐⭐⭐⭐⭐

#### Tab 2: **Total Runs**
- Game has 6+ total runs (1pt)
- Game has 8+ total runs (1pt)
- Game has 10+ total runs (2pt)
- Game has 12+ total runs (2pt)
- Game has 15+ total runs (3pt)

#### Tab 3: **Team Runs**
- [Home] scores 3+ runs (1pt)
- [Home] scores 5+ runs (1pt)
- [Home] scores 7+ runs (2pt)
- [Home] scores 10+ runs (3pt)
- [Away] scores 3+ runs (1pt)
- [Away] scores 5+ runs (1pt)
- [Away] scores 7+ runs (2pt)
- [Away] scores 10+ runs (3pt)

#### Tab 4: **Hitting**
- [Home] records 8+ hits (1pt)
- [Home] records 10+ hits (2pt)
- [Home] records 12+ hits (2pt)
- [Away] records 8+ hits (1pt)
- [Away] records 10+ hits (2pt)
- [Away] records 12+ hits (2pt)
- Combined hits 15+ (1pt)
- Combined hits 18+ (2pt)
- Combined hits 20+ (2pt)

#### Tab 5: **Home Runs**
- Home run hit in game (1pt)
- 2+ home runs in game (2pt)
- 3+ home runs in game (2pt)
- [Home] hits a home run (1pt)
- [Away] hits a home run (1pt)

#### Tab 6: **Defense**
- [Home] plays error-free (2pt)
- [Away] plays error-free (2pt)
- Both teams error-free (3pt)
- Either team shut out (3pt)

#### Tab 7: **Special Events**
- Game goes to extra innings (2pt)
- Game decided by 1 run (2pt)
- Game decided by 5+ runs (2pt)

---

### **Soccer** (6 tabs)

#### Tab 1: **Winner** (REQUIRED)
- Pick [Home] to Win (1pt)
- Pick Draw (1pt)
- Pick [Away] to Win (1pt)
- Confidence: ⭐⭐⭐⭐⭐

#### Tab 2: **Total Goals**
- Game has 2+ total goals (1pt)
- Game has 3+ total goals (1pt)
- Game has 4+ total goals (2pt)
- Game has 5+ total goals (3pt)

#### Tab 3: **Team Goals**
- [Home] scores 1+ goals (1pt)
- [Home] scores 2+ goals (2pt)
- [Home] scores 3+ goals (2pt)
- [Away] scores 1+ goals (1pt)
- [Away] scores 2+ goals (2pt)
- [Away] scores 3+ goals (2pt)

#### Tab 4: **Special Outcomes**
- Both teams score (2pt)
- Either team clean sheet (2pt)
- Game ends 0-0 (3pt)
- Game ends 1-0 (3pt)
- Game ends 1-1 (2pt)

#### Tab 5: **Team Stats**
- Winner has 55%+ possession (2pt)
- Winner has 60%+ possession (3pt)
- [Home] has 5+ shots on target (2pt)
- [Home] has 7+ shots on target (2pt)
- [Away] has 5+ shots on target (2pt)
- [Away] has 7+ shots on target (2pt)

#### Tab 6: **Match Events**
- Game has 10+ corners (2pt)
- Game has 12+ corners (2pt)
- Game has 20+ fouls (1pt)
- Game has 30+ fouls (2pt)

---

### **Tennis** (3 tabs)

#### Tab 1: **Winner** (REQUIRED)
- Pick [Player 1] to Win (1pt)
- Pick [Player 2] to Win (1pt)
- Confidence: ⭐⭐⭐⭐⭐

#### Tab 2: **Match Duration**
- Match goes to 3 sets (2pt)
- Match ends in 2 sets (2pt)

#### Tab 3: **Set Results**
- Winner wins in straight sets (2pt)
- Match has a tiebreak (2pt)

**Note:** Tennis has very limited ESPN data

---

### **NFL** (KEEP EXISTING ODDS-BASED SYSTEM)
- No changes to NFL
- Continue using ESPN odds data
- Fallback to simple betting only if odds unavailable

---

## Point System

### **Base Points by Difficulty:**

**Tier 1 (1 point):**
- Pick winner
- Basic score thresholds (common outcomes)
- Basic totals

**Tier 2 (2 points):**
- Moderate thresholds
- Team stat predictions
- Special outcomes (clean sheet, both teams score)
- Margin predictions

**Tier 3 (3 points):**
- Difficult thresholds
- Rare events (shutouts, straight sets)
- High stat achievements
- Specific score predictions

### **Confidence Multipliers:**
- 1 ⭐ = 1.0× points
- 2 ⭐ = 1.5× points
- 3 ⭐ = 2.0× points
- 4 ⭐ = 2.5× points
- 5 ⭐ = 3.0× points

### **Scoring Example:**
```
User Bet: Lakers score 110+ points
Base Points: 1
User Confidence: 4 stars (2.5× multiplier)
Result: Lakers scored 118 (WIN)
Points Earned: 1 × 2.5 = 2.5 points
```

---

## Data Models

### **SimpleBet Model** (New)
```dart
class SimpleBet {
  final String id;
  final String betType;          // 'winner', 'team_score', 'total_score', etc.
  final String description;      // "Lakers score 110+ points"
  final bool selection;          // true = yes, false = no
  final int basePoints;          // 1, 2, or 3
  final int confidence;          // 1-5 stars
  final double multiplier;       // confidence multiplier
  final String? team;            // 'home', 'away', or null
  final double? threshold;       // numeric threshold (110, 200, etc)
  final bool isRequired;         // true for winner pick
  final bool? result;            // null before settlement, true/false after
  final double? pointsEarned;    // calculated after settlement

  SimpleBet({
    required this.id,
    required this.betType,
    required this.description,
    required this.selection,
    required this.basePoints,
    required this.confidence,
    required this.multiplier,
    this.team,
    this.threshold,
    this.isRequired = false,
    this.result,
    this.pointsEarned,
  });
}
```

### **BetSlip Updates**
```dart
class BetSlip {
  final String gameId;
  final SimpleBet winnerBet;              // REQUIRED
  final List<SimpleBet> optionalBets;     // User's selections
  final double totalPotentialPoints;
  final double? totalEarnedPoints;        // After settlement
  final int wagerAmount;                  // BR Coins
  final bool settled;

  // Calculate potential points
  double calculatePotentialPoints() {
    double total = winnerBet.basePoints * winnerBet.multiplier;
    for (var bet in optionalBets) {
      total += bet.basePoints * bet.multiplier;
    }
    return total;
  }
}
```

### **Firestore Structure**
```javascript
// bets/{betId}
{
  userId: "user123",
  gameId: "401234567",
  sport: "NBA",
  wagerAmount: 50,
  submittedAt: timestamp,

  // Required winner bet
  winnerBet: {
    betType: "winner",
    description: "Lakers to Win",
    selection: "home",
    confidence: 3,
    basePoints: 1,
    multiplier: 2.0,
    result: null,
    pointsEarned: null
  },

  // Optional bets
  optionalBets: [
    {
      betType: "team_score_threshold",
      description: "Lakers score 110+ points",
      selection: true,
      team: "home",
      threshold: 110,
      confidence: 4,
      basePoints: 1,
      multiplier: 2.5,
      result: null,
      pointsEarned: null
    },
    {
      betType: "margin",
      description: "Game decided by 10+ points",
      selection: true,
      threshold: 10,
      confidence: 2,
      basePoints: 2,
      multiplier: 1.5,
      result: null,
      pointsEarned: null
    }
  ],

  totalPotentialPoints: 8.5,
  totalEarnedPoints: null,
  settled: false,
  settledAt: null
}
```

---

## ESPN Data Caching Strategy

### **Critical: Scale for Thousands of Users**

To avoid exhausting ESPN API quota with thousands of users:

**Problem:** Each game could have 100+ users betting on it. Without caching, settlement would make 100+ API calls to ESPN.

**Solution: Aggressive Caching System**

### **Game Results Cache Service**
```dart
class GameResultsCacheService {
  static const CACHE_DURATION = Duration(hours: 24);

  // Cache completed game results in Firestore
  // Collection: game_results/{gameId}
  {
    gameId: "401234567",
    sport: "NBA",
    cachedAt: timestamp,
    expiresAt: timestamp,
    status: "final",
    espnData: { /* full ESPN response */ },
    homeScore: 118,
    awayScore: 100,
    winner: "home",
    statistics: { /* parsed stats */ }
  }

  // Settlement process:
  // 1. Check cache first (game_results/{gameId})
  // 2. If cached and not expired: use cached data
  // 3. If not cached: fetch from ESPN once, then cache
  // 4. All user bets for this game use the SAME cached data
}
```

### **Caching Rules:**
1. **One API call per game** - First settlement caches result for all users
2. **24-hour cache lifetime** - Prevents stale data
3. **Firestore storage** - Shared across all users
4. **Automatic invalidation** - If game status changes (postponed, etc.)

### **Settlement Flow with Caching:**
```
Game ends (Lakers vs Celtics)
  ↓
User 1 bet settlement triggered
  ↓
Check cache: game_results/401234567
  ↓
NOT FOUND → Fetch ESPN data → Cache in Firestore
  ↓
Settle User 1 bet using cached data
  ↓
User 2-100 bet settlements triggered
  ↓
Check cache: game_results/401234567
  ↓
FOUND → Use cached data (no ESPN API call)
  ↓
Settle User 2-100 bets instantly
```

### **Benefits:**
- ✅ 1 ESPN API call per game (vs 100+ without caching)
- ✅ Instant settlement for users 2+
- ✅ No API quota exhaustion
- ✅ Consistent results for all users
- ✅ Works for thousands of concurrent users

---

## Settlement Logic

### **Settlement Service** (New)

```dart
class SimpleBetSettlementService {
  final GameResultsCacheService _cacheService = GameResultsCacheService();

  // Main settlement function with caching
  Future<void> settleBet(String betId) async {
    final bet = await _getBet(betId);

    // CRITICAL: Check cache first
    final gameData = await _cacheService.getGameResult(
      gameId: bet.gameId,
      sport: bet.sport,
      // Only fetch from ESPN if not cached
      fetchIfMissing: true,
    );

    if (gameData == null) {
      throw Exception('Game data unavailable');
    }

    // Settle winner bet
    final winnerResult = _evaluateWinnerBet(bet.winnerBet, gameData);

    // Settle optional bets
    final optionalResults = bet.optionalBets.map((b) =>
      _evaluateBet(b, gameData)
    ).toList();

    // Calculate total points
    double totalPoints = _calculateTotalPoints(winnerResult, optionalResults);

    // Update Firestore
    await _updateBetResults(betId, winnerResult, optionalResults, totalPoints);
  }

  // Evaluate individual bet based on type
  bool _evaluateBet(SimpleBet bet, Map<String, dynamic> gameData) {
    switch (bet.betType) {
      case 'winner':
        return _evaluateWinner(bet, gameData);
      case 'team_score_threshold':
        return _evaluateTeamScore(bet, gameData);
      case 'total_score_threshold':
        return _evaluateTotalScore(bet, gameData);
      case 'margin':
        return _evaluateMargin(bet, gameData);
      case 'player_performance':
        return _evaluatePlayerPerformance(bet, gameData);
      case 'team_stat':
        return _evaluateTeamStat(bet, gameData);
      // ... more bet types
      default:
        return false;
    }
  }

  // Example: Evaluate team score threshold
  bool _evaluateTeamScore(SimpleBet bet, Map<String, dynamic> gameData) {
    final team = bet.team; // 'home' or 'away'
    final threshold = bet.threshold;
    final teamScore = gameData['competitors']
      .firstWhere((c) => c['homeAway'] == team)['score'];

    return int.parse(teamScore) >= threshold;
  }

  // Example: Evaluate margin
  bool _evaluateMargin(SimpleBet bet, Map<String, dynamic> gameData) {
    final homeScore = int.parse(gameData['competitors'][0]['score']);
    final awayScore = int.parse(gameData['competitors'][1]['score']);
    final margin = (homeScore - awayScore).abs();

    return margin >= bet.threshold;
  }
}
```

---

## Implementation Phases

### **Phase 1: Data Models & Configuration**
**Files to Create:**
- `lib/models/simple_bet.dart`
- `lib/models/simple_bet_slip.dart`
- `lib/config/simple_bet_config.dart` (sport-specific bet definitions)

**Files to Update:**
- `lib/models/betting_models.dart` (add simple bet types)

**Tasks:**
1. Create SimpleBet model
2. Create SimpleBetSlip model
3. Define bet configurations for each sport (NBA, NHL, MLB, Soccer, Tennis)
4. Add confidence multiplier constants

---

### **Phase 2: Bet Selection Screen Updates**
**Files to Update:**
- `lib/screens/betting/bet_selection_screen.dart`

**Tasks:**
1. Add `isSimpleBetting` flag to determine which system to use
2. Update `_loadGameData()` to check if simple betting should be used:
   ```dart
   bool _useSimpleBetting() {
     // Use simple betting for all sports except NFL
     if (widget.sport.toUpperCase() == 'NFL') {
       // Only use simple if ESPN odds are unavailable
       return _oddsData == null;
     }
     return true; // All other sports use simple betting
   }
   ```
3. Update tab building methods to show simple bets instead of odds-based:
   ```dart
   Widget _buildWinnerTab() {
     if (_useSimpleBetting()) {
       return _buildSimpleWinnerTab();
     } else {
       return _buildOddsBasedMoneylineTab(); // existing
     }
   }
   ```
4. Create new tab builders for simple betting:
   - `_buildSimpleWinnerTab()`
   - `_buildSimpleTeamScoreTab()`
   - `_buildSimpleTotalTab()`
   - `_buildSimpleMarginTab()`
   - etc.

---

### **Phase 3: Bet Card Components**
**Files to Create:**
- `lib/widgets/simple_bet_card.dart`
- `lib/widgets/confidence_selector.dart`

**Tasks:**
1. Create SimpleBetCard widget:
   ```dart
   Widget SimpleBetCard({
     required String description,
     required int basePoints,
     required bool selected,
     required int confidence,
     required Function(bool) onSelect,
     required Function(int) onConfidenceChange,
   })
   ```
2. Create ConfidenceSelector widget (star rating 1-5)
3. Style cards to match existing betting UI

---

### **Phase 4: Bet Slip Integration**
**Files to Update:**
- `lib/widgets/bet_slip_widget.dart`
- `lib/services/bet_service.dart`

**Tasks:**
1. Update BetSlip to handle SimpleBet objects
2. Display potential points in bet slip
3. Show confidence multipliers
4. Validate required winner bet
5. Calculate total potential points
6. Update bet submission to save simple bets to Firestore

---

### **Phase 5: Settlement Service**
**Files to Create:**
- `lib/services/simple_bet_settlement_service.dart`

**Tasks:**
1. Create SimpleBetSettlementService class
2. Implement bet evaluation logic for each bet type:
   - Winner evaluation
   - Score threshold evaluation
   - Margin evaluation
   - Player performance evaluation
   - Team stat evaluation
3. Fetch ESPN final game data
4. Calculate points earned per bet
5. Update Firestore with results
6. Trigger payout distribution

---

### **Phase 6: Sport-Specific Configurations**
**Files to Create:**
- `lib/config/bets/nba_simple_bets.dart`
- `lib/config/bets/nhl_simple_bets.dart`
- `lib/config/bets/mlb_simple_bets.dart`
- `lib/config/bets/soccer_simple_bets.dart`
- `lib/config/bets/tennis_simple_bets.dart`

**Format:**
```dart
class NbaSimpleBets {
  static List<BetTabConfig> getTabs() {
    return [
      BetTabConfig(
        name: 'Winner',
        icon: Icons.emoji_events,
        bets: [
          SimpleBetTemplate(
            betType: 'winner',
            description: '{home} to Win',
            basePoints: 1,
            isRequired: true,
          ),
        ],
      ),
      BetTabConfig(
        name: 'Team Scoring',
        icon: Icons.score,
        bets: [
          SimpleBetTemplate(
            betType: 'team_score_threshold',
            description: '{home} scores 100+ points',
            basePoints: 1,
            threshold: 100,
            team: 'home',
          ),
          SimpleBetTemplate(
            betType: 'team_score_threshold',
            description: '{home} scores 110+ points',
            basePoints: 1,
            threshold: 110,
            team: 'home',
          ),
          // ... more bets
        ],
      ),
      // ... more tabs
    ];
  }
}
```

---

### **Phase 7: Testing**
**Test Cases:**
1. Bet selection flow for each sport
2. Confidence level selection
3. Bet slip validation (winner required)
4. Points calculation
5. Bet submission
6. Settlement for each bet type
7. Payout distribution
8. Edge cases (ties, postponed games, missing stats)

---

## Migration Strategy

### **For Existing Bets:**
1. Keep odds-based betting for NFL (primary)
2. Keep MMA/Boxing simple betting (already implemented)
3. Add simple betting for NBA, NHL, MLB, Soccer, Tennis
4. NFL falls back to simple betting only if ESPN odds unavailable

### **Feature Flag:**
```dart
class BettingConfig {
  static const Map<String, BettingSystemType> SPORT_BETTING_SYSTEMS = {
    'NFL': BettingSystemType.oddsBasedWithFallback,
    'NBA': BettingSystemType.simple,
    'NHL': BettingSystemType.simple,
    'MLB': BettingSystemType.simple,
    'SOCCER': BettingSystemType.simple,
    'TENNIS': BettingSystemType.simple,
    'MMA': BettingSystemType.simple,
    'BOXING': BettingSystemType.simple,
  };
}
```

---

## Success Metrics

1. ✅ Users can place bets on all sports without odds data
2. ✅ Winner pick is always required
3. ✅ Users can select multiple optional bets per game
4. ✅ Confidence levels affect point multipliers
5. ✅ Settlement works correctly from ESPN data
6. ✅ Point-based scoring calculates accurately
7. ✅ Existing UI/UX flow unchanged
8. ✅ No dependency on Odds API quota

---

## Future Enhancements

1. **Leaderboards** - Show top point earners
2. **Bet History** - Track user accuracy per bet type
3. **Recommendations** - Suggest bets based on historical data
4. **Streak Bonuses** - Bonus points for consecutive correct picks
5. **Live Betting** - Allow bet modifications during game
6. **Bet Sharing** - Share bet slips with friends

---

## Notes

- Simple betting is PRIMARY for all sports except NFL
- NFL uses ESPN odds when available, falls back to simple betting
- All bets are binary (yes/no or team selection)
- All bets are optional except winner pick
- Settlement logic must be robust for missing/incomplete ESPN data
- Confidence system encourages engagement
- Point system rewards difficulty + confidence
