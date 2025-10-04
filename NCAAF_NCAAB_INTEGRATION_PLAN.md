# NCAAF/NCAAB Integration Plan

## Overview
Integrate college football (NCAAF) and college basketball (NCAAB) into the existing NFL and NBA sections respectively, with visual indicators (badges/icons) to distinguish college games from professional games.

---

## Implementation Plan

### 1. Research & Verify API Data
**Objective:** Confirm NCAAF/NCAAB endpoints provide sufficient data

**Tasks:**
- Test NCAAF endpoint: `americanfootball_ncaaf`
- Test NCAAB endpoint: `basketball_ncaab`
- Verify game data structure matches professional counterparts
- Check if college games have sufficient odds/betting markets
- Confirm team names, schedules, and venue data availability

**Expected Outcome:** Validated that college sports data is compatible with existing game model structure

---

### 2. Update Sport Configuration Lists
**Objective:** Add NCAAF/NCAAB to supported sports across the app

**Files to Modify:**
- `lib/screens/games/optimized_games_screen.dart` (line 100)
- `lib/screens/settings/preferences_settings_screen.dart` (line 19-21)
- `lib/utils/sport_utils.dart` (team sports list)
- `lib/services/optimized_games_service.dart` (supported sports)

**Changes:**
- Add `'ncaaf'` and `'ncaab'` to available sports arrays
- Keep them separate in backend but display merged with NFL/NBA in UI
- Update sport key mappings in `odds_api_service.dart`

**Example:**
```dart
// Before
_availableSports = ['nfl', 'nba', 'nhl', 'mlb', 'boxing', 'mma', 'soccer'];

// After
_availableSports = ['nfl', 'ncaaf', 'nba', 'ncaab', 'nhl', 'mlb', 'boxing', 'mma', 'soccer'];
```

---

### 3. Add College Sport Detection Logic
**Objective:** Enable games to identify and categorize themselves as college sports

**Files to Modify:**
- `lib/models/game_model.dart`
- `lib/models/enhanced_game_model.dart`

**Add Properties:**
```dart
// Detect if game is college sport
bool get isCollegeSport =>
    sport.toUpperCase() == 'NCAAF' ||
    sport.toUpperCase() == 'NCAAB';

// Get parent sport category (NCAAF -> NFL, NCAAB -> NBA)
String get sportCategory {
  if (sport.toUpperCase() == 'NCAAF') return 'NFL';
  if (sport.toUpperCase() == 'NCAAB') return 'NBA';
  return sport.toUpperCase();
}

// Get display name
String get sportDisplayName => isCollegeSport ? 'COLLEGE' : sport.toUpperCase();
```

**Expected Outcome:** Games can self-identify as college and map to parent sport category

---

### 4. Create College Badge UI Component
**Objective:** Design clear visual indicator for college games

**Design Specifications:**
- Badge text: "COLLEGE" or "NCAA"
- Badge style: Small rounded rectangle
- Color scheme: Blue/gold (NCAA colors) or amber/orange
- Placement: Adjacent to sport icon on game cards
- Font: Bold, 10-12pt, white text

**Implementation:**
```dart
Widget _buildCollegeBadge() {
  return Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: Colors.amber.shade700,
      borderRadius: BorderRadius.circular(4),
      border: Border.all(color: Colors.amber.shade900, width: 1),
    ),
    child: const Text(
      'COLLEGE',
      style: TextStyle(
        fontSize: 10,
        fontWeight: FontWeight.bold,
        color: Colors.white,
        letterSpacing: 0.5,
      ),
    ),
  );
}
```

---

### 5. Update Optimized Games Screen
**Objective:** Merge college games with professional games in UI

**Files to Modify:**
- `lib/screens/games/optimized_games_screen.dart`

**Key Changes:**

#### A. Sport Selection Logic
- When user selects "NFL", load both NFL and NCAAF games
- When user selects "NBA", load both NBA and NCAAB games
- Merge games from both sources into single list

```dart
Future<void> _loadSportGames(String sport) async {
  final games = <GameModel>[];

  // Load professional games
  final proGames = await _gamesService.loadAllGamesForSport(sport);
  games.addAll(proGames);

  // Load college games if applicable
  if (sport == 'nfl') {
    final collegeGames = await _gamesService.loadAllGamesForSport('ncaaf');
    games.addAll(collegeGames);
  } else if (sport == 'nba') {
    final collegeGames = await _gamesService.loadAllGamesForSport('ncaab');
    games.addAll(collegeGames);
  }

  // Sort by game time
  games.sort((a, b) => a.gameTime.compareTo(b.gameTime));

  setState(() {
    _gamesBySport[sport] = games;
  });
}
```

#### B. Game Card Updates
- Add college badge to cards where `game.isCollegeSport == true`
- Update header row to show badge next to sport icon

```dart
// In _buildGameCard method
Row(
  children: [
    Icon(_getSportIcon(game.sport)),
    const SizedBox(width: 4),
    Text(game.sportCategory.toUpperCase()),
    if (game.isCollegeSport) ...[
      const SizedBox(width: 8),
      _buildCollegeBadge(),
    ],
  ],
)
```

---

### 6. Update Preferences Settings
**Objective:** Allow users to toggle college sports on/off

**Files to Modify:**
- `lib/screens/settings/preferences_settings_screen.dart`
- `lib/models/user_preferences.dart`
- `lib/services/user_preferences_service.dart`

**New Settings:**
```dart
bool includeCollegeFootball = true;
bool includeCollegeBasketball = true;
```

**UI Addition:**
```dart
SwitchListTile(
  title: const Text('Include College Football (NCAAF)'),
  subtitle: const Text('Show NCAAF games with NFL games'),
  value: _includeCollegeFootball,
  onChanged: (value) {
    setState(() => _includeCollegeFootball = value);
  },
),
SwitchListTile(
  title: const Text('Include College Basketball (NCAAB)'),
  subtitle: const Text('Show NCAAB games with NBA games'),
  value: _includeCollegeBasketball,
  onChanged: (value) {
    setState(() => _includeCollegeBasketball = value);
  },
),
```

---

### 7. Update Sport Icons & Colors
**Objective:** Ensure college games display with appropriate visual styling

**Files to Modify:**
- `lib/screens/games/optimized_games_screen.dart`

**Icon Mapping:**
```dart
IconData _getSportIcon(String sport) {
  switch (sport.toUpperCase()) {
    case 'NFL':
    case 'NCAAF':  // Add college football
      return Icons.sports_football;
    case 'NBA':
    case 'NCAAB':  // Add college basketball
      return Icons.sports_basketball;
    // ... rest of mappings
  }
}
```

**Color Mapping:**
```dart
Color _getSportColor(String sport) {
  switch (sport.toUpperCase()) {
    case 'NFL':
    case 'NCAAF':
      return Colors.blue;
    case 'NBA':
    case 'NCAAB':
      return Colors.orange;
    // ... rest of mappings
  }
}
```

**Optional:** Add subtle variation for college (e.g., lighter shade)

---

### 8. Update Game Loading Service
**Objective:** Ensure college games are fetched and cached properly

**Files to Modify:**
- `lib/services/optimized_games_service.dart`

**Changes:**
- Add NCAAF/NCAAB to supported sports list
- Update `loadFeaturedGames()` to include college games when appropriate
- Ensure caching works for college games
- Update `loadAllGamesForSport()` to merge pro + college when requested

---

### 9. Testing Checklist
**Objective:** Verify all functionality works correctly

**Test Cases:**
- [ ] NCAAF games appear in NFL section
- [ ] NCAAB games appear in NBA section
- [ ] College badge displays correctly on college game cards
- [ ] College badge does NOT display on professional game cards
- [ ] Games sort correctly by time (mixed pro/college)
- [ ] Preferences toggles work (enable/disable college sports)
- [ ] Odds loading works for college games
- [ ] Pool creation works for college games
- [ ] "Enter Pool" button works on college games
- [ ] Game details screen loads for college games
- [ ] Sport icons display correctly for college games
- [ ] Sport colors display correctly for college games
- [ ] Cache invalidation works for college sports
- [ ] Pull-to-refresh works with mixed pro/college games

---

## UI/UX Design

### Game Card Display Example
```
┌─────────────────────────────────────┐
│ 🏀 NBA  [COLLEGE]       7:00 PM    │ <- Badge indicates college
│                                     │
│ Duke Blue Devils                    │
│ UNC Tar Heels                       │
│                                     │
│ Cameron Indoor Stadium              │
│ [Enter Pool]                        │
└─────────────────────────────────────┘

┌─────────────────────────────────────┐
│ 🏀 NBA                  8:30 PM    │ <- No badge = professional
│                                     │
│ Los Angeles Lakers                  │
│ Boston Celtics                      │
│                                     │
│ Crypto.com Arena                    │
│ [Enter Pool]                        │
└─────────────────────────────────────┘
```

### Sport Selection Grid (No Visual Change)
```
┌──────────┬──────────┐
│   ALL    │   NFL    │  <- Clicking NFL shows NFL + NCAAF games
│  SPORTS  │    🏈    │
├──────────┼──────────┤
│   NBA    │   NHL    │  <- Clicking NBA shows NBA + NCAAB games
│    🏀    │    🏒    │
└──────────┴──────────┘
```

---

## Benefits

### User Experience
- **Seamless Integration:** Users don't need to navigate separately for college sports
- **Clear Distinction:** College badge prevents confusion
- **User Control:** Preferences allow filtering if desired
- **Familiar Navigation:** No new UI patterns to learn

### Technical
- **Minimal Code Changes:** Leverages existing infrastructure
- **Scalable:** Easy to add more college sports later (e.g., college hockey)
- **Maintainable:** College logic centralized in game models
- **Performance:** Uses existing caching and loading patterns

### Business
- **Increased Engagement:** More betting opportunities
- **Broader Appeal:** Attracts college sports fans
- **Competitive Advantage:** Not all betting apps integrate college/pro seamlessly

---

## Future Enhancements

### Phase 2 Considerations
- Add conference badges (SEC, Big Ten, ACC, etc.)
- Add team logos for major college programs
- Add college-specific statistics and insights
- Add rivalry game indicators
- Add college playoff/tournament brackets
- Support for other college sports (hockey, baseball, soccer)

---

## Implementation Timeline

### Estimated Effort
- **Research & Testing:** 2-4 hours
- **Backend Updates:** 4-6 hours
- **UI Updates:** 4-6 hours
- **Testing & QA:** 3-4 hours
- **Total:** ~13-20 hours

### Recommended Phases
1. **Phase 1:** Backend integration (tasks 1-3)
2. **Phase 2:** UI components (tasks 4, 7)
3. **Phase 3:** Screen updates (tasks 5, 6, 8)
4. **Phase 4:** Testing & refinement (task 9)

---

## Notes
- NCAAF/NCAAB are already mapped in `odds_api_service.dart` (lines 154-155)
- College games may have less betting market variety than professional games
- Some college games may not have odds available (smaller programs)
- Consider adding "No odds available" messaging for games without betting lines
