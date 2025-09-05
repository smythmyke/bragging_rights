# Combat Sports Betting Implementation Plan

## Overview
Implement a streamlined two-tier betting system for UFC/MMA events: a Quick Pick Grid for rapid selections across entire fight cards, and an Advanced Betting view for detailed prop bets.

## Phase 1: Quick Pick Grid Screen
### 1.1 Create `fight_card_grid_screen.dart`
**Location**: `lib/screens/betting/fight_card_grid_screen.dart`

**Features**:
- 2x1 fighter card layout per fight
- Single screen showing all fights (Main → Prelims → Early Prelims)
- Tap interaction system:
  - 1st tap: Select winner (green outline)
  - 2nd tap: Cycle through KO → TKO → SUB → DEC → basic win
  - Tap opponent: Clear current, select new
  - TIE option in cycle (both green, "TIE" label)
- Visual elements per fighter card:
  - Fighter photo/avatar
  - Name
  - Record (W-L-D)
  - Country flag
  - Odds display (if available)
  - Selected state indicator

**Data Requirements**:
- Receive `FightCardEventModel` with all fights
- Fetch odds per fight from `FightOddsService`
- Save picks to Firestore as `FightPick` objects

### 1.2 Update Navigation Flow
**Files to modify**:
- `lib/screens/pools/pool_selection_screen.dart`
- `lib/main.dart` (add route)

**Flow**:
```
Game Selected (UFC Event) → Pool Selection → Fight Card Grid → (Optional) Advanced Betting
```

**Implementation**:
- Detect if sport is 'MMA' or promotion is UFC/Bellator/PFL
- Route to `FightCardGridScreen` instead of standard `BetSelectionScreen`
- Pass event data and pool information

## Phase 2: Enhanced Advanced Betting View
### 2.1 Update `fight_pick_detail_screen.dart`
**New bet types to add**:
- **Round Groups**:
  - Rounds 1-2 (Early finish)
  - Rounds 3-4 (Mid fight)
  - Round 5 (Championship round)
- **Over/Under Rounds**:
  - O/U 1.5 rounds
  - O/U 2.5 rounds
  - O/U 4.5 rounds (5-round fights)
- **Advanced Props**:
  - Specific submission type (dropdown)
  - Fighter to be knocked down
  - Fight ends in first 60 seconds
  - Fighter to bleed first
  - Total significant strikes O/U

### 2.2 Create Prop Bet Models
**Location**: `lib/models/fight_props_model.dart`

```dart
class FightProps {
  final bool? firstBlood;
  final String? firstBloodFighter;
  final bool? knockdown;
  final String? knockdownFighter;
  final bool? endsIn60Seconds;
  final String? submissionType;
  final double? totalStrikesLine;
  final bool? overUnderStrikes;
}
```

## Phase 3: Data Integration
### 3.1 Odds Service Enhancement
**File**: `lib/services/fight_odds_service.dart`

**Enhancements**:
- Add method odds fetching
- Add round betting odds
- Add prop bet odds (if available)
- Implement fallback for missing odds
- Cache odds to reduce API calls

### 3.2 Fighter Data Service
**Create**: `lib/services/fighter_stats_service.dart`

**Features**:
- Fetch fighter records from ESPN
- Get recent fight history
- Calculate win streaks
- Provide tale of tape data

## Phase 4: Parlay System
### 4.1 Create Parlay Builder
**Location**: `lib/screens/betting/parlay_builder_screen.dart`

**Features**:
- Select multiple fights from same card
- Calculate combined odds
- Show potential payout
- Save as single parlay bet

### 4.2 Parlay Model
```dart
class FightParlay {
  final List<FightPick> picks;
  final double combinedOdds;
  final int wagerAmount;
  final int potentialPayout;
}
```

## Phase 5: UI Components
### 5.1 Fighter Card Widget
**Location**: `lib/widgets/betting/fighter_card_widget.dart`

**Visual states**:
- Default (unselected)
- Selected winner (green outline)
- Selected with method (green + method label)
- TIE state (both green)
- Disabled (if fight started)

### 5.2 Fight Status Indicator
- Show if fight is live
- Display round progress
- Lock betting when fight starts

## Phase 6: Testing & Polish
### 6.1 Test Scenarios
- Full card pick flow
- Partial picks with navigation
- Method cycling
- TIE selection
- Odds display with missing data
- Live fight lockout

### 6.2 Performance Optimization
- Lazy load fighter images
- Cache odds data
- Optimize Firestore queries
- Smooth scroll performance with 15+ fights

## Implementation Order
1. **Day 1**: Fight Card Grid Screen base UI
2. **Day 2**: Tap interaction system and state management
3. **Day 3**: Navigation integration and data flow
4. **Day 4**: Advanced props in detail screen
5. **Day 5**: Odds integration and display
6. **Day 6**: Parlay system
7. **Day 7**: Testing and polish

## Success Metrics
- Users can pick all fights on a card in < 30 seconds
- Zero conflicts between winner/method selections
- Smooth performance with 15+ fight cards
- Odds display for available fights
- Successful save to Firestore

## Edge Cases to Handle
- Fights with no odds data
- Cancelled/postponed fights
- Fighter replacements
- Draw/No Contest results
- Technical decisions
- Doctor stoppages