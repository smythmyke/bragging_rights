# NBA Season Classification & Simple Pick System Implementation Plan

## Executive Summary

This plan addresses the issue of NBA exhibition/preseason games appearing in the app without odds, causing a poor user experience. The solution implements a comprehensive classification system to identify game types and provides a "Simple Pick" betting alternative when traditional odds are unavailable.

---

## Problem Statement

**Current Issue:**
- NBA preseason/exhibition games (e.g., Melbourne United vs Pelicans) appear in the app
- Users can select these games for betting
- Odds API returns NULL (no betting lines available for exhibitions)
- User sees error: "No odds available"
- Dead end - cannot place any bet

**Root Cause:**
- No classification of NBA game types (regular season vs preseason vs exhibition)
- No fallback betting system when odds unavailable
- International teams (non-NBA) not filtered or handled differently

---

## Solution Overview

### Three-Part Solution:

1. **Game Classification System**
   - Detect season type (Regular Season, Preseason, Playoffs)
   - Identify exhibition games (non-NBA teams)
   - Validate NBA team IDs (1-30 range)

2. **Odds Availability Detection**
   - Check both preseason and regular season endpoints
   - Store odds availability flag
   - Enable graceful fallback

3. **Simple Pick System**
   - Alternative betting when no odds available
   - Point-based scoring (similar to MMA system)
   - Confidence multipliers for strategic depth

---

## Technical Implementation

### Phase 1: Classification System (Days 1-2)

#### 1.1 Update GameModel

**File:** `lib/models/game_model.dart`

Add optional fields (non-breaking):

```dart
class GameModel {
  // ... existing fields ...

  // NBA-specific classification (optional - null for other sports)
  final String? seasonType;        // 'regular_season', 'preseason', 'playoffs'
  final bool? hasOdds;              // true/false - odds available?
  final String? exhibitionType;     // 'Global Games', 'International', null

  GameModel({
    // ... existing params ...
    this.seasonType,
    this.hasOdds,
    this.exhibitionType,
  });
}
```

**Why optional:** Backwards compatible, only used for NBA games.

---

#### 1.2 Create NBA Classification Logic

**File:** `lib/services/optimized_games_service.dart`

Add classification method:

```dart
/// Classify NBA game based on ESPN data
Future<NbaGameClassification> _classifyNbaGame(Map<String, dynamic> event) async {
  final season = event['season'] ?? {};
  final competitions = event['competitions'] as List? ?? [];
  final competition = competitions.isNotEmpty ? competitions[0] : {};
  final competitors = competition['competitors'] as List? ?? [];

  // 1. Check season type
  final seasonType = season['type']; // 1=preseason, 2=regular, 3=playoffs
  final seasonSlug = season['slug']; // 'preseason', 'regular-season', 'postseason'

  // 2. Validate team IDs (NBA teams are 1-30)
  final team1Id = int.tryParse(competitors[0]['team']['id']?.toString() ?? '0') ?? 0;
  final team2Id = int.tryParse(competitors[1]['team']['id']?.toString() ?? '0') ?? 0;

  final team1IsNBA = team1Id >= 1 && team1Id <= 30;
  final team2IsNBA = team2Id >= 1 && team2Id <= 30;

  // 3. Check for exhibition indicators
  final notes = competition['notes'] as List? ?? [];
  String? exhibitionType;

  for (final note in notes) {
    final headline = note['headline']?.toString().toLowerCase() ?? '';
    if (headline.contains('global') || headline.contains('international')) {
      exhibitionType = note['headline'];
      break;
    }
  }

  // 4. Determine classification
  String classification;

  if (seasonType == 2) {
    classification = 'regular_season';
  } else if (seasonType == 3) {
    classification = 'playoffs';
  } else if (seasonType == 1) {
    if (team1IsNBA && team2IsNBA) {
      classification = 'preseason_nba'; // Both NBA teams
    } else {
      classification = 'preseason_exhibition'; // Has non-NBA team
      exhibitionType ??= 'Exhibition Game';
    }
  } else {
    classification = 'unknown';
  }

  return NbaGameClassification(
    seasonType: classification,
    exhibitionType: exhibitionType,
    team1IsNBA: team1IsNBA,
    team2IsNBA: team2IsNBA,
  );
}

class NbaGameClassification {
  final String seasonType;
  final String? exhibitionType;
  final bool team1IsNBA;
  final bool team2IsNBA;

  NbaGameClassification({
    required this.seasonType,
    this.exhibitionType,
    required this.team1IsNBA,
    required this.team2IsNBA,
  });
}
```

---

#### 1.3 Integrate Classification into Game Loading

**File:** `lib/services/optimized_games_service.dart`

Update `convertEspnEventToGame()`:

```dart
Future<GameModel> convertEspnEventToGame(Map<String, dynamic> event, String sport) async {
  // ... existing game parsing logic ...

  // NEW: Classify NBA games
  String? seasonType;
  String? exhibitionType;
  bool? hasOdds;

  if (sport.toUpperCase() == 'NBA') {
    final classification = await _classifyNbaGame(event);
    seasonType = classification.seasonType;
    exhibitionType = classification.exhibitionType;

    // Check odds availability
    hasOdds = await _checkNbaOddsAvailability(
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      gameDate: gameTime,
    );

    debugPrint('🏀 NBA Game Classification:');
    debugPrint('   Season: $seasonType');
    debugPrint('   Exhibition: $exhibitionType');
    debugPrint('   Has Odds: $hasOdds');
  }

  return GameModel(
    // ... existing fields ...
    seasonType: seasonType,
    exhibitionType: exhibitionType,
    hasOdds: hasOdds,
    seasonLabel: _getSeasonLabel(seasonType),
  );
}

String? _getSeasonLabel(String? seasonType) {
  switch (seasonType) {
    case 'preseason_nba':
    case 'preseason_exhibition':
      return 'PRESEASON';
    case 'playoffs':
      return 'PLAYOFFS';
    default:
      return null; // No label for regular season
  }
}
```

---

### Phase 2: Odds Availability Detection (Day 3)

#### 2.1 Check Odds Availability

**File:** `lib/services/optimized_games_service.dart`

Add odds checking method:

```dart
/// Check if odds are available for an NBA game
/// Tries both preseason and regular season endpoints
Future<bool> _checkNbaOddsAvailability({
  required String homeTeam,
  required String awayTeam,
  required DateTime gameDate,
}) async {
  try {
    // Use existing OddsApiService method
    final oddsEventId = await _oddsApiService.findOddsApiEventId(
      sport: 'nba',
      homeTeam: homeTeam,
      awayTeam: awayTeam,
      gameDate: gameDate,
    );

    // If we found an event ID, odds are available
    return oddsEventId != null;
  } catch (e) {
    debugPrint('❌ Error checking odds availability: $e');
    return false;
  }
}
```

**Note:** This leverages the existing multi-endpoint system we already built that checks both `basketball_nba_preseason` and `basketball_nba` endpoints.

---

### Phase 3: Simple Pick System (Days 4-6)

#### 3.1 Create Simple Pick Scoring System

**File:** `lib/services/simple_pick_scoring.dart` (NEW)

```dart
import 'package:flutter/foundation.dart';

/// Simple pick scoring system for games without odds
/// Similar to MMA fight card scoring but adapted for team sports
class SimplePickScoring {
  /// Calculate user's score for simple picks
  static double calculateScore({
    required List<SimplePick> picks,
    required List<GameResult> results,
  }) {
    double totalScore = 0;

    for (final pick in picks) {
      final result = results.firstWhere(
        (r) => r.gameId == pick.gameId,
        orElse: () => GameResult.empty(),
      );

      // Skip if game not completed
      if (!result.isCompleted) continue;

      // Check if pick was correct
      if (pick.pickedTeam == result.winningTeam) {
        // Base point for correct pick
        double score = 1.0;

        // Apply confidence multiplier (1-5 stars)
        if (pick.confidence != null) {
          // Formula: 0.9x to 1.3x based on confidence
          // 1 star = 0.9x, 2 = 1.0x, 3 = 1.1x, 4 = 1.2x, 5 = 1.3x
          final confidenceMultiplier = 0.8 + (pick.confidence! * 0.1);
          score *= confidenceMultiplier;
        }

        totalScore += score;
      }
    }

    return totalScore;
  }

  /// Calculate payouts for simple pick pools
  static Map<String, int> distributePrizePool({
    required List<UserScore> rankings,
    required int totalPool,
    required int minPayout,
  }) {
    final payouts = <String, int>{};

    if (rankings.isEmpty) return payouts;

    // Winner-takes-all OR top 50% split
    final winnersCount = (rankings.length * 0.5).ceil();

    if (winnersCount == 1) {
      // Winner takes all
      payouts[rankings[0].userId] = totalPool;
    } else {
      // Split among top performers
      final payoutPerWinner = totalPool ~/ winnersCount;

      for (int i = 0; i < winnersCount && i < rankings.length; i++) {
        payouts[rankings[i].userId] = payoutPerWinner;
      }
    }

    return payouts;
  }
}

class SimplePick {
  final String gameId;
  final String pickedTeam;
  final int? confidence; // 1-5 stars (optional)
  final DateTime pickedAt;

  SimplePick({
    required this.gameId,
    required this.pickedTeam,
    this.confidence,
    required this.pickedAt,
  });
}

class GameResult {
  final String gameId;
  final String? winningTeam;
  final bool isCompleted;

  GameResult({
    required this.gameId,
    this.winningTeam,
    required this.isCompleted,
  });

  factory GameResult.empty() => GameResult(
    gameId: '',
    isCompleted: false,
  );
}

class UserScore {
  final String userId;
  final String username;
  final double score;
  final int correctPicks;
  final int totalPicks;
  final DateTime submittedAt; // For tiebreaker

  UserScore({
    required this.userId,
    required this.username,
    required this.score,
    required this.correctPicks,
    required this.totalPicks,
    required this.submittedAt,
  });
}
```

---

#### 3.2 Update Pool Generator

**File:** `lib/services/pool_auto_generator.dart`

Add simple pick pool generation:

```dart
Future<void> generatePoolsForGame(GameModel game, WriteBatch batch) async {
  // ... existing code ...

  // NBA-specific logic
  if (game.sport == 'NBA') {
    // Check if odds are available
    if (game.hasOdds == false) {
      // Create simple pick pools only
      await _createSimplePickPools(game, batch);
      return; // Don't create odds-based pools
    } else {
      // Create normal odds-based pools
      await _createMoneylinePools(game, batch);
      await _createSpreadPools(game, batch);
      await _createOverUnderPools(game, batch);
    }
  }
}

/// Create simple pick pools for games without odds
Future<void> _createSimplePickPools(GameModel game, WriteBatch batch) async {
  final buyIns = [5, 10, 25, 50, 100];

  for (final buyIn in buyIns) {
    final pool = Pool(
      id: '',
      gameId: game.id,
      gameTitle: game.gameTitle,
      sport: game.sport,
      type: PoolType.quick,
      status: PoolStatus.open,
      name: 'Simple Pick - $buyIn BR',
      buyIn: buyIn,
      minPlayers: 2,
      maxPlayers: buyIn <= 25 ? 50 : 20,
      currentPlayers: 0,
      playerIds: [],
      startTime: game.gameTime,
      closeTime: game.gameTime.subtract(const Duration(minutes: 15)),
      prizePool: 0,
      prizeStructure: _getSimplePickPrizeStructure(),
      tier: _getTierFromBuyIn(buyIn),
      createdAt: DateTime.now(),
      metadata: {
        'autoGenerated': true,
        'betType': 'simple_pick',
        'requiresOdds': false, // KEY: Does not need odds
        'scoringSystem': 'simple_pick',
        'confidenceEnabled': true,
      },
    );

    final docRef = _firestore.collection('pools').doc();
    batch.set(docRef, pool.copyWith(id: docRef.id).toFirestore());
  }

  debugPrint('✅ Created simple pick pools for ${game.gameTitle}');
}

Map<String, dynamic> _getSimplePickPrizeStructure() {
  return {
    'type': 'simple_pick',
    'distribution': 'top_50_percent',
    'tiebreaker': 'submission_time', // First to submit wins ties
  };
}
```

---

#### 3.3 Update Bet Selection Screen

**File:** `lib/screens/betting/bet_selection_screen.dart`

Add simple pick handling:

```dart
// In initState or loadData method
Future<void> _loadGameData() async {
  // ... existing odds loading code ...

  // NEW: Check if this is a simple pick game
  if (_gameData?.hasOdds == false) {
    debugPrint('🎯 Game has no odds - enabling simple pick mode');

    setState(() {
      _isSimplePickMode = true;
      _isLoadingData = false;
    });

    return; // Skip odds loading
  }

  // ... continue with normal odds loading ...
}

// Add simple pick UI
Widget _buildSimplePickUI() {
  return Column(
    children: [
      // Info banner
      Container(
        padding: EdgeInsets.all(16),
        color: Colors.blue.withOpacity(0.1),
        child: Row(
          children: [
            Icon(Icons.info_outline, color: Colors.blue),
            SizedBox(width: 12),
            Expanded(
              child: Text(
                'Simple Pick Mode: Choose the winning team. 1 point per correct pick.',
                style: TextStyle(color: Colors.blue),
              ),
            ),
          ],
        ),
      ),

      SizedBox(height: 24),

      // Team selection
      _buildTeamSelectionCard(
        team: _awayTeam,
        isHome: false,
      ),

      SizedBox(height: 16),

      _buildTeamSelectionCard(
        team: _homeTeam,
        isHome: true,
      ),

      SizedBox(height: 24),

      // Confidence selector (optional)
      if (_enableConfidence) _buildConfidenceSelector(),

      SizedBox(height: 24),

      // Submit button
      _buildSubmitButton(),
    ],
  );
}

Widget _buildConfidenceSelector() {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        'Confidence Level (Optional)',
        style: TextStyle(fontWeight: FontWeight.bold),
      ),
      SizedBox(height: 8),
      Text(
        'Higher confidence = higher reward if correct',
        style: TextStyle(fontSize: 12, color: Colors.grey),
      ),
      SizedBox(height: 12),
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          for (int i = 1; i <= 5; i++)
            _buildConfidenceChip(i),
        ],
      ),
    ],
  );
}

Widget _buildConfidenceChip(int level) {
  final isSelected = _selectedConfidence == level;
  final multiplier = 0.8 + (level * 0.1);

  return GestureDetector(
    onTap: () => setState(() => _selectedConfidence = level),
    child: Column(
      children: [
        Container(
          padding: EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isSelected ? Colors.blue : Colors.grey.shade200,
            shape: BoxShape.circle,
          ),
          child: Icon(
            Icons.star,
            color: isSelected ? Colors.white : Colors.grey,
            size: 20,
          ),
        ),
        SizedBox(height: 4),
        Text(
          '${multiplier.toStringAsFixed(1)}x',
          style: TextStyle(
            fontSize: 12,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
          ),
        ),
      ],
    ),
  );
}
```

---

### Phase 4: UI/Badges (Day 7)

#### 4.1 Add Badge Components

**File:** `lib/widgets/game_card_enhanced.dart`

Update header to include new badges:

```dart
Widget _buildHeader(BuildContext context) {
  final theme = Theme.of(context);

  return Row(
    children: [
      // 1. Sport badge (existing)
      _buildSportBadge(),

      const SizedBox(width: 8),

      // 2. Season badge (NEW)
      if (game.seasonLabel != null) ...[
        _buildSeasonBadge(game.seasonLabel!),
        const SizedBox(width: 8),
      ],

      // 3. Exhibition badge (NEW)
      if (game.exhibitionType != null) ...[
        _buildExhibitionBadge(),
        const SizedBox(width: 8),
      ],

      // Spacer
      Expanded(child: SizedBox()),

      // 4. Betting type badge (NEW)
      if (game.hasOdds != null) ...[
        _buildBettingTypeBadge(),
        const SizedBox(width: 8),
      ],

      // 5. Status badge (existing - LIVE)
      if (game.isLive) _buildLiveBadge(),
    ],
  );
}

Widget _buildSeasonBadge(String label) {
  final color = _getSeasonColor(label);

  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: color.withOpacity(0.2),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color),
    ),
    child: Text(
      label,
      style: TextStyle(
        color: color,
        fontSize: 10,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}

Color _getSeasonColor(String label) {
  switch (label.toUpperCase()) {
    case 'PRESEASON':
      return Color(0xFFFF9500); // Orange
    case 'PLAYOFFS':
      return Color(0xFFFFD700); // Gold
    default:
      return Colors.grey;
  }
}

Widget _buildExhibitionBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    decoration: BoxDecoration(
      color: Color(0xFF9B59B6).withOpacity(0.2), // Purple
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: Color(0xFF9B59B6)),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(Icons.public, size: 12, color: Color(0xFF9B59B6)),
        SizedBox(width: 4),
        Text(
          'EXHIBITION',
          style: TextStyle(
            color: Color(0xFF9B59B6),
            fontSize: 10,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    ),
  );
}

Widget _buildBettingTypeBadge() {
  if (game.hasOdds == false) {
    // Simple Pick mode
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Color(0xFF3498DB).withOpacity(0.2), // Blue
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Color(0xFF3498DB)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_outline, size: 12, color: Color(0xFF3498DB)),
          SizedBox(width: 4),
          Text(
            'SIMPLE PICK',
            style: TextStyle(
              color: Color(0xFF3498DB),
              fontSize: 10,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  // Don't show badge for normal odds-based games
  return SizedBox.shrink();
}
```

---

#### 4.2 Badge Color Reference

```dart
// Badge Colors
const PRESEASON_ORANGE = Color(0xFFFF9500);
const PLAYOFFS_GOLD = Color(0xFFFFD700);
const EXHIBITION_PURPLE = Color(0xFF9B59B6);
const SIMPLE_PICK_BLUE = Color(0xFF3498DB);
const LIVE_RED = Colors.red; // existing
```

---

### Phase 5: Testing & Polish (Days 8-9)

#### 5.1 Test Cases

**Regular Season Game (Lakers vs Celtics):**
- ✅ No season badge shown
- ✅ Has odds
- ✅ Shows normal betting pools
- ✅ Odds-based scoring

**Preseason NBA Game (76ers vs Knicks):**
- ✅ Shows "PRESEASON" badge (orange)
- ✅ May or may not have odds
- ✅ If odds: normal pools
- ✅ If no odds: simple pick pools

**Exhibition Game (Pelicans vs Melbourne United):**
- ✅ Shows "PRESEASON" badge (orange)
- ✅ Shows "EXHIBITION" badge (purple)
- ✅ Shows "SIMPLE PICK" badge (blue)
- ✅ No odds available
- ✅ Only simple pick pools created
- ✅ Confidence selector available

**Playoffs Game:**
- ✅ Shows "PLAYOFFS" badge (gold)
- ✅ Has odds
- ✅ Normal betting pools

---

#### 5.2 User Flow Testing

1. **Load Games List**
   - Verify all badges display correctly
   - Check badge colors match spec
   - Ensure no overlapping badges

2. **Select Exhibition Game**
   - Opens to simple pick mode
   - Shows info banner
   - Team selection works
   - Confidence selector works
   - Can submit pick

3. **Select Regular Game**
   - Opens to normal betting mode
   - Shows odds
   - Can place all bet types
   - Normal flow unchanged

4. **Pool Creation**
   - Exhibition games create simple pick pools
   - Regular games create odds-based pools
   - Correct metadata stored

5. **Scoring**
   - Simple picks score correctly
   - Confidence multipliers apply
   - Tiebreaker works (submission time)
   - Payouts distributed correctly

---

## Database Schema Changes

### Games Collection

```javascript
{
  // ... existing fields ...

  // NEW FIELDS (optional, NBA only)
  "seasonType": "preseason_exhibition",  // or null
  "seasonLabel": "PRESEASON",            // or null
  "hasOdds": false,                      // or true/null
  "exhibitionType": "NBA Abu Dhabi Game" // or null
}
```

### Pools Collection

```javascript
{
  // ... existing fields ...

  "metadata": {
    "autoGenerated": true,
    "betType": "simple_pick",    // NEW: 'simple_pick' or 'moneyline', etc.
    "requiresOdds": false,        // NEW: false for simple picks
    "scoringSystem": "simple_pick", // NEW: 'simple_pick' or 'odds_based'
    "confidenceEnabled": true     // NEW: allow confidence multipliers
  }
}
```

### Picks Collection (for simple picks)

```javascript
{
  "userId": "user123",
  "poolId": "pool456",
  "gameId": "game789",
  "pickedTeam": "New Orleans Pelicans",
  "confidence": 5,               // 1-5 stars (optional)
  "pickedAt": "2025-10-02T10:30:00Z",
  "type": "simple_pick"
}
```

---

## UI/UX Specifications

### Badge Visual Examples

```
┌─────────────────────────────────────────────┐
│ 🏀 NBA  [PRESEASON]  [EXHIBITION]  [●LIVE]  │
│                                             │
│ Melbourne United @ New Orleans Pelicans     │
│                                             │
│ [🎯 SIMPLE PICK]              Oct 2, 4:00 PM│
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ 🏀 NBA  [PRESEASON]                         │
│                                             │
│ 76ers @ Knicks                              │
│                                             │
│ Oct 2, 4:00 PM                              │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ 🏀 NBA                                       │
│                                             │
│ Celtics @ Lakers                            │
│                                             │
│ Oct 22, 7:30 PM                             │
└─────────────────────────────────────────────┘

┌─────────────────────────────────────────────┐
│ 🏀 NBA  [PLAYOFFS]                          │
│                                             │
│ Heat @ Nuggets                              │
│                                             │
│ Jun 5, 9:00 PM                              │
└─────────────────────────────────────────────┘
```

### Badge Priority (Left to Right)

1. Sport (always)
2. Season Type (if preseason/playoffs)
3. Exhibition (if applicable)
4. Betting Type (if simple pick)
5. Status (if live)

---

## API Integration Points

### ESPN API - Season Detection

```javascript
// From ESPN scoreboard API
{
  "season": {
    "type": 1,              // 1=preseason, 2=regular, 3=playoffs
    "slug": "preseason",    // String version
    "year": 2026
  },
  "competitions": [{
    "competitors": [{
      "team": {
        "id": "3",          // Pelicans (NBA team 1-30)
        "displayName": "New Orleans Pelicans"
      }
    }, {
      "team": {
        "id": "111124",     // Melbourne United (NOT 1-30)
        "displayName": "Melbourne United"
      }
    }],
    "notes": [{
      "type": "event",
      "headline": "NBA Abu Dhabi Game"  // Exhibition indicator
    }]
  }]
}
```

### Odds API - Multi-Endpoint Check

```javascript
// Check both endpoints in priority order
const endpoints = [
  'basketball_nba_preseason',  // Priority 1
  'basketball_nba'             // Priority 2
];

// Returns event ID if found, null if not available
```

---

## Implementation Timeline

| Phase | Task | Duration | Status |
|-------|------|----------|--------|
| **Phase 1** | Classification System | 2 days | Pending |
| - | Update GameModel | 2 hours | Pending |
| - | NBA classification logic | 4 hours | Pending |
| - | Team ID validation | 2 hours | Pending |
| - | Integration & testing | 2 hours | Pending |
| **Phase 2** | Odds Detection | 1 day | Pending |
| - | Odds availability check | 3 hours | Pending |
| - | Cache implementation | 2 hours | Pending |
| - | Testing | 1 hour | Pending |
| **Phase 3** | Simple Pick System | 3 days | Pending |
| - | Scoring service | 4 hours | Pending |
| - | Pool type creation | 4 hours | Pending |
| - | Bet selection UI | 6 hours | Pending |
| - | Pool generator updates | 3 hours | Pending |
| - | Testing | 3 hours | Pending |
| **Phase 4** | UI/Badges | 1 day | Pending |
| - | Badge components | 3 hours | Pending |
| - | Game card updates | 2 hours | Pending |
| - | Styling & polish | 1 hour | Pending |
| **Phase 5** | Testing & Polish | 2 days | Pending |
| - | Integration testing | 6 hours | Pending |
| - | Bug fixes | 4 hours | Pending |
| - | User acceptance | 2 hours | Pending |
| **TOTAL** | | **9 days** | |

---

## Success Metrics

### Functional Requirements
- ✅ All NBA games classified correctly
- ✅ Exhibition games show appropriate badges
- ✅ Simple pick pools created when no odds
- ✅ Users can place simple picks
- ✅ Scoring system works correctly
- ✅ No errors for games without odds

### User Experience
- ✅ Clear visual distinction between game types
- ✅ No confusion about betting availability
- ✅ Smooth simple pick flow
- ✅ Confidence system intuitive
- ✅ Proper feedback on all actions

### Performance
- ✅ Classification adds <100ms to load time
- ✅ Odds check cached for 15 minutes
- ✅ No impact on existing features
- ✅ Database queries optimized

---

## Risk Mitigation

### Risk 1: Classification Errors
**Mitigation:**
- Multiple validation checks (team ID, season type, notes)
- Fallback to safe defaults
- Comprehensive logging
- Manual review capability

### Risk 2: Odds API Changes
**Mitigation:**
- Graceful degradation to simple picks
- Cache odds availability results
- Retry logic with backoff
- User-friendly error messages

### Risk 3: User Confusion
**Mitigation:**
- Clear badges and labels
- Info banners explaining simple picks
- Help tooltips
- In-app tutorial (optional)

### Risk 4: Scoring Edge Cases
**Mitigation:**
- Extensive unit tests
- Tiebreaker logic
- Manual payout review for first pools
- User support system

---

## Future Enhancements

### Phase 2 (Post-Launch)
- Add simple pick support for other sports
- Advanced confidence strategies
- Leaderboards for simple picks
- Simple pick tournaments
- Group simple pick challenges

### Phase 3 (Future)
- Machine learning for game classification
- Custom pool rules (user-defined confidence multipliers)
- Social simple picks (challenge friends)
- Simple pick badges/achievements
- Analytics dashboard

---

## Appendix

### A. Team ID Validation Reference

Valid NBA team IDs: 1-30

| ID | Team | ID | Team |
|----|------|----|------|
| 1 | Hawks | 16 | Grizzlies |
| 2 | Celtics | 17 | Heat |
| 3 | Pelicans | 18 | Bucks |
| 4 | Bulls | 19 | Timberwolves |
| 5 | Cavaliers | 20 | Nets |
| 6 | Mavericks | 21 | Hornets |
| 7 | Nuggets | 22 | Knicks |
| 8 | Pistons | 23 | Thunder |
| 9 | Warriors | 24 | Magic |
| 10 | Rockets | 25 | 76ers |
| 11 | Pacers | 26 | Suns |
| 12 | Clippers | 27 | Trail Blazers |
| 13 | Lakers | 28 | Kings |
| 14 | Heat | 29 | Spurs |
| 15 | Bucks | 30 | Raptors |

Non-NBA teams have IDs > 100000 (e.g., Melbourne United = 111124)

---

### B. Season Type Reference

ESPN Season Type Values:
- `1` = Preseason
- `2` = Regular Season
- `3` = Playoffs/Postseason

ESPN Season Slug Values:
- `"preseason"` = Preseason
- `"regular-season"` = Regular Season
- `"postseason"` = Playoffs

---

### C. Confidence Multiplier Formula

```
multiplier = 0.8 + (confidence * 0.1)

1 star: 0.8 + (1 * 0.1) = 0.9x
2 stars: 0.8 + (2 * 0.1) = 1.0x
3 stars: 0.8 + (3 * 0.1) = 1.1x
4 stars: 0.8 + (4 * 0.1) = 1.2x
5 stars: 0.8 + (5 * 0.1) = 1.3x
```

---

## Change Log

| Date | Version | Changes | Author |
|------|---------|---------|--------|
| 2025-10-02 | 1.0 | Initial plan created | System |

---

## Approval Sign-off

- [ ] Technical Lead Review
- [ ] Product Owner Approval
- [ ] QA Test Plan Created
- [ ] Ready for Implementation

---

**END OF DOCUMENT**
