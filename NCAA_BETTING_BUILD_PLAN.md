# NCAA Betting System Build Plan

## Overview
Add NCAAF (College Football) and NCAAB (College Basketball) betting support using the simple betting system with 4-5 betting tabs per sport.

## Problem Statement
- NCAAF and NCAAB games are displayed in the app but have no betting configuration
- Users attempting to bet on NCAA games encounter errors (TabController mismatch: 5 tabs expected, 0 provided)
- ESPN API supports both NCAA sports with comprehensive game data

## Verified API Support

### NCAAF (College Football)
- **Endpoint**: `https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard`
- **Available Data**:
  - Final scores (both teams)
  - Scoring by quarter
  - Team records (overall, home/away, conference)
  - Individual player stats (passing, rushing, receiving leaders)
  - Rankings (Top 25)
  - Game metadata (venue, date, broadcast)

### NCAAB (Men's College Basketball)
- **Endpoint**: `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard`
- **Available Data**:
  - Final scores (both teams)
  - Team statistics (FG%, 3PT%, FT%, rebounds, assists)
  - Individual player stats (points, rebounds, assists leaders)
  - Rankings (Top 25)
  - Game metadata (venue, date, broadcast)

## Betting Structure

### NCAAF - 4 Tabs
1. **Winner** (Required) - Pick winning team
2. **Team Scoring** - Team scores X+ points
3. **Game Total** - Combined score thresholds
4. **Margin** - Winning margin ranges

### NCAAB - 5 Tabs
1. **Winner** (Required) - Pick winning team
2. **Team Scoring** - Team scores X+ points
3. **Game Total** - Combined score thresholds
4. **Margin** - Winning margin ranges
5. **Team Stats** - Three-pointers, assists, rebounds

## Implementation Tasks

### Phase 1: Create ESPN Service Files

#### Task 1.1: Create `espn_ncaaf_service.dart`
**Location**: `bragging_rights_app/lib/services/edge/sports/`

**Action**: Copy from `espn_nfl_service.dart` and modify:
- Change base URL to: `https://site.api.espn.com/apis/site/v2/sports/football/college-football`
- Update class name: `EspnNcaafService`
- Update model names: `EspnNcaafScoreboard`, `EspnNcaafNews`, `EspnNcaafArticle`
- Keep same methods: `getTodaysGames()`, `getGamesForDateRange()`, `getNews()`

**Files to Modify**:
- Create: `bragging_rights_app/lib/services/edge/sports/espn_ncaaf_service.dart`

#### Task 1.2: Create `espn_ncaab_service.dart`
**Location**: `bragging_rights_app/lib/services/edge/sports/`

**Action**: Copy from `espn_nba_service.dart` and modify:
- Change base URL to: `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball`
- Update class name: `EspnNcaabService`
- Update model names: `EspnNcaabScoreboard`, `EspnNcaabNews`, `EspnNcaabArticle`
- Keep same methods: `getTodaysGames()`, `getGamesForDateRange()`, `getNews()`

**Files to Modify**:
- Create: `bragging_rights_app/lib/services/edge/sports/espn_ncaab_service.dart`

---

### Phase 2: Create Betting Configuration Files

#### Task 2.1: Create `ncaaf_simple_bets.dart`
**Location**: `bragging_rights_app/lib/config/bets/`

**Betting Tabs**:

**Tab 1: Winner** (Required)
- Home team to win (1 pt)
- Away team to win (1 pt)

**Tab 2: Team Scoring**
- Home scores 14+ points (1 pt)
- Home scores 21+ points (1 pt)
- Home scores 28+ points (2 pts)
- Home scores 35+ points (2 pts)
- Home scores 42+ points (3 pts)
- Away scores 14+ points (1 pt)
- Away scores 21+ points (1 pt)
- Away scores 28+ points (2 pts)
- Away scores 35+ points (2 pts)
- Away scores 42+ points (3 pts)

**Tab 3: Game Total**
- Combined score over 45 (1 pt)
- Combined score over 50 (1 pt)
- Combined score over 55 (2 pts)
- Combined score over 60 (2 pts)
- Combined score over 65 (3 pts)

**Tab 4: Margin**
- Game decided by 1-7 points (2 pts)
- Game decided by 8-14 points (2 pts)
- Game decided by 15+ points (2 pts)
- Game decided by 21+ points (3 pts)
- Game decided by 28+ points (3 pts)

**Files to Modify**:
- Create: `bragging_rights_app/lib/config/bets/ncaaf_simple_bets.dart`

#### Task 2.2: Create `ncaab_simple_bets.dart`
**Location**: `bragging_rights_app/lib/config/bets/`

**Betting Tabs**:

**Tab 1: Winner** (Required)
- Home team to win (1 pt)
- Away team to win (1 pt)

**Tab 2: Team Scoring**
- Home scores 60+ points (1 pt)
- Home scores 70+ points (1 pt)
- Home scores 80+ points (2 pts)
- Home scores 90+ points (3 pts)
- Away scores 60+ points (1 pt)
- Away scores 70+ points (1 pt)
- Away scores 80+ points (2 pts)
- Away scores 90+ points (3 pts)

**Tab 3: Game Total**
- Combined score over 120 (1 pt)
- Combined score over 130 (1 pt)
- Combined score over 140 (2 pts)
- Combined score over 150 (2 pts)
- Combined score over 160 (3 pts)

**Tab 4: Margin**
- Game decided by 1-5 points (2 pts)
- Game decided by 6-10 points (2 pts)
- Game decided by 10+ points (2 pts)
- Game decided by 15+ points (2 pts)
- Game decided by 20+ points (3 pts)

**Tab 5: Team Stats**
- Home makes 8+ threes (2 pts)
- Home makes 10+ threes (2 pts)
- Home makes 12+ threes (3 pts)
- Home records 15+ assists (2 pts)
- Home records 20+ assists (3 pts)
- Home grabs 35+ rebounds (2 pts)
- Away makes 8+ threes (2 pts)
- Away makes 10+ threes (2 pts)
- Away makes 12+ threes (3 pts)
- Away records 15+ assists (2 pts)
- Away records 20+ assists (3 pts)
- Away grabs 35+ rebounds (2 pts)

**Files to Modify**:
- Create: `bragging_rights_app/lib/config/bets/ncaab_simple_bets.dart`

---

### Phase 3: Update Game Fetching Service

#### Task 3.1: Add NCAA Services to `optimized_games_service.dart`
**Location**: `bragging_rights_app/lib/services/optimized_games_service.dart`

**Changes Needed**:

1. **Add imports** (top of file):
```dart
import 'edge/sports/espn_ncaaf_service.dart';
import 'edge/sports/espn_ncaab_service.dart';
```

2. **Add service instances** (around line 34-36):
```dart
final EspnNcaafService _ncaafService = EspnNcaafService();
final EspnNcaabService _ncaabService = EspnNcaabService();
```

3. **Add fetch methods for NCAAF** (similar to `_fetchNflGames` around line 460):
```dart
Future<List<GameModel>> _fetchNcaafGames({int daysAhead = 14}) async {
  final scoreboard = await _ncaafService.getGamesForDateRange(daysAhead: daysAhead);
  // Parse and return games
}
```

4. **Add fetch methods for NCAAB** (similar to `_fetchNbaGames` around line 490):
```dart
Future<List<GameModel>> _fetchNcaabGames({int daysAhead = 14}) async {
  final scoreboard = await _ncaabService.getGamesForDateRange(daysAhead: daysAhead);
  // Parse and return games
}
```

5. **Update `loadFeaturedGames()` to include NCAA sports** (around line 70-100)

6. **Update `loadAllGamesForSport()` to handle NCAAF and NCAAB** (around line 185-272)

**Files to Modify**:
- `bragging_rights_app/lib/services/optimized_games_service.dart`

---

### Phase 4: Update Bet Selection Screen

#### Task 4.1: Import NCAA Betting Configs
**Location**: `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`

**Add imports** (around line 29-33):
```dart
import '../../config/bets/ncaaf_simple_bets.dart';
import '../../config/bets/ncaab_simple_bets.dart';
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`

#### Task 4.2: Update `_createBetTypeController()` Method
**Location**: Line 750-753

**Change from**:
```dart
if (sportUpper.contains('NFL') || sportUpper.contains('NCAAF') || sportUpper.contains('FOOTBALL')) {
  print('Creating 5-tab controller for NFL with odds (or will switch to simple if no odds)');
  return TabController(length: 5, vsync: this); // Winner, Spread, Totals, Props, Live
}
```

**Change to**:
```dart
if (sportUpper.contains('NFL') || sportUpper.contains('FOOTBALL')) {
  // Only NFL uses odds-based betting
  if (sportUpper.contains('NCAAF')) {
    // NCAAF uses simple betting
    _loadSimpleBettingTabs();
    final tabCount = _simpleBetTabs.length;
    print('Creating $tabCount-tab controller for NCAAF simple betting');
    return TabController(length: tabCount, vsync: this);
  }
  print('Creating 5-tab controller for NFL with odds');
  return TabController(length: 5, vsync: this);
}
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart` (line 750-753)

#### Task 4.3: Update `_useSimpleBetting()` Method
**Location**: Line 761-768

**Add NCAAF and NCAAB checks**:
```dart
// NCAAF always uses simple betting
if (sportUpper.contains('NCAAF')) {
  return true;
}

// NCAAB always uses simple betting
if (sportUpper.contains('NCAAB') || sportUpper.contains('BASKETBALL')) {
  return true;
}
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart` (line 761-768)

#### Task 4.4: Update `_loadSimpleBettingTabs()` Method
**Location**: Line 775-791

**Add NCAAF and NCAAB handling**:
```dart
void _loadSimpleBettingTabs() {
  final sportUpper = widget.sport.toUpperCase().trim();

  if (sportUpper.contains('NBA') || sportUpper.contains('BASKETBALL')) {
    _simpleBetTabs = NbaSimpleBets.getTabs();
  } else if (sportUpper.contains('NCAAB')) {
    _simpleBetTabs = NcaabSimpleBets.getTabs();
  } else if (sportUpper.contains('NHL') || sportUpper.contains('HOCKEY')) {
    _simpleBetTabs = NhlSimpleBets.getTabs();
  } else if (sportUpper.contains('MLB') || sportUpper.contains('BASEBALL')) {
    _simpleBetTabs = MlbSimpleBets.getTabs();
  } else if (sportUpper.contains('NCAAF')) {
    _simpleBetTabs = NcaafSimpleBets.getTabs();
  } else if (sportUpper.contains('SOCCER') || (sportUpper.contains('FOOTBALL') && !sportUpper.contains('NFL'))) {
    _simpleBetTabs = SoccerSimpleBets.getTabs();
  } else if (sportUpper.contains('TENNIS')) {
    _simpleBetTabs = TennisSimpleBets.getTabs();
  }

  setState(() {});
}
```

**Files to Modify**:
- `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart` (line 775-791)

---

### Phase 5: Update Bet Settlement Service

#### Task 5.1: Add NCAA Sport Handling
**Location**: `bragging_rights_app/lib/services/simple_bet_settlement_service.dart`

**Add NCAAF and NCAAB to sport-specific logic**:
- Update any sport-specific parsing (if needed)
- Ensure settlement logic handles NCAA games
- Verify stat field names match ESPN API response

**Files to Check**:
- `bragging_rights_app/lib/services/simple_bet_settlement_service.dart`

---

## Testing Checklist

### Manual Testing
- [ ] NCAAF game appears in Games screen
- [ ] Tapping NCAAF game opens bet selection screen
- [ ] Bet selection screen shows 4 tabs (Winner, Team Scoring, Game Total, Margin)
- [ ] Each tab displays correct bets with proper team names
- [ ] Can select and adjust confidence for each bet
- [ ] Bet slip updates correctly with selected bets
- [ ] Can submit bet slip without errors
- [ ] NCAAB game appears in Games screen
- [ ] Tapping NCAAB game opens bet selection screen
- [ ] Bet selection screen shows 5 tabs (Winner, Team Scoring, Game Total, Margin, Team Stats)
- [ ] Each tab displays correct bets with proper team names
- [ ] Can select and adjust confidence for each bet
- [ ] Bet slip updates correctly with selected bets
- [ ] Can submit bet slip without errors

### Edge Cases
- [ ] NCAA games with missing data handle gracefully
- [ ] Ranked vs unranked matchups display correctly
- [ ] Conference games display properly
- [ ] Neutral site games show correct venue
- [ ] Past NCAA games settle correctly (test with historical data)

### Error Scenarios
- [ ] No TabController mismatch errors
- [ ] No betId collision errors
- [ ] API failures handle gracefully with error messages
- [ ] Missing stats don't crash settlement service

---

## Files Summary

### New Files to Create (6)
1. `bragging_rights_app/lib/services/edge/sports/espn_ncaaf_service.dart`
2. `bragging_rights_app/lib/services/edge/sports/espn_ncaab_service.dart`
3. `bragging_rights_app/lib/config/bets/ncaaf_simple_bets.dart`
4. `bragging_rights_app/lib/config/bets/ncaab_simple_bets.dart`

### Files to Modify (3)
1. `bragging_rights_app/lib/services/optimized_games_service.dart`
2. `bragging_rights_app/lib/screens/betting/bet_selection_screen.dart`
3. `bragging_rights_app/lib/services/simple_bet_settlement_service.dart` (verify only)

---

## Implementation Order

1. **Start with NCAAF** (simpler, 4 tabs)
   - Create ESPN service
   - Create betting config
   - Update games service
   - Update bet selection screen
   - Test end-to-end

2. **Then add NCAAB** (5 tabs with team stats)
   - Create ESPN service
   - Create betting config
   - Update games service
   - Update bet selection screen
   - Test end-to-end

3. **Final verification**
   - Test bet settlement with completed games
   - Verify all edge cases
   - Check error handling

---

## Success Criteria

✅ Users can bet on NCAAF games with 4 betting tabs
✅ Users can bet on NCAAB games with 5 betting tabs
✅ No TabController mismatch errors
✅ NCAA games fetch and display properly
✅ Bets can be placed and submitted
✅ Completed NCAA bets settle correctly
✅ All team names, scores, and stats display accurately

---

## Notes

- NCAA games use the same simple betting system as NBA/NHL/MLB
- No odds-based betting for NCAA sports (point-based only)
- Lower scoring thresholds for NCAAF compared to NFL
- NCAAB thresholds similar to NBA
- ESPN API provides sufficient data for all bet types
- Team stats for NCAAB match NBA structure (threes, assists, rebounds)
