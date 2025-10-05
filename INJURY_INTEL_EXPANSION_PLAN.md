# Injury Intel Expansion Plan
**Expanding Injury Intel Cards to All Supported Sports**

## Current Status

### ✅ Fully Implemented
- **NBA** - Complete injury intel card system with detection, purchase, and report viewing

### ✅ ESPN API Available (Verified)
- **NCAAF** (College Football) - Injury endpoint tested, data available
- **NFL** - ESPN supports injury data
- **MLB** - ESPN supports injury data
- **NHL** - ESPN supports injury data
- **Soccer/MLS** - ESPN supports injury data
- **NCAAB** (Men's College Basketball) - Endpoint tested (currently 0 injuries, but structure exists)

---

## ESPN Injury Endpoint Structure

### Verified Endpoints:
```
NBA:    /v2/sports/basketball/leagues/nba/teams/{teamId}/injuries
NFL:    /v2/sports/football/leagues/nfl/teams/{teamId}/injuries
NCAAF:  /v2/sports/football/leagues/college-football/teams/{teamId}/injuries
MLB:    /v2/sports/baseball/leagues/mlb/teams/{teamId}/injuries
NHL:    /v2/sports/hockey/leagues/nhl/teams/{teamId}/injuries
NCAAB:  /v2/sports/basketball/leagues/mens-college-basketball/teams/{teamId}/injuries
MLS:    /v2/sports/soccer/leagues/usa.1/teams/{teamId}/injuries
```

### Data Structure (Same for All Sports):
```json
{
  "count": 2,
  "items": [
    {
      "$ref": "http://sports.core.api.espn.com/v2/.../injuries/{injuryId}"
    }
  ]
}
```

Each injury reference returns:
- `status` - Injury status (e.g., "Active", "Out", "Questionable")
- `type` - Status type details
- `longComment` - Detailed injury description
- `athlete` - Reference to athlete data (name, position, etc.)

---

## Implementation Plan

### Phase 1: Service Layer Updates

#### 1.1 Update `InjuryService` (`lib/services/injury_service.dart`)

**Add College Sport Support:**
```dart
String _getLeague(String sport) {
  switch (sport.toLowerCase()) {
    case 'basketball':
      return 'nba';
    case 'ncaab':  // ADD
      return 'mens-college-basketball';
    case 'football':
      return 'nfl';
    case 'ncaaf':  // ADD
      return 'college-football';
    case 'baseball':
      return 'mlb';
    case 'hockey':
      return 'nhl';
    case 'soccer':
      return 'usa.1';
    default:
      return sport.toLowerCase();
  }
}
```

**Update Supported Sports:**
```dart
bool sportSupportsInjuries(String sport) {
  final supportedSports = [
    'basketball',
    'ncaab',      // ADD
    'football',
    'ncaaf',      // ADD
    'baseball',
    'hockey',
    'soccer'
  ];
  return supportedSports.contains(sport.toLowerCase());
}
```

**Location**: Lines 117-144

---

### Phase 2: Team ID Extraction

#### 2.1 Expand Team ID Mapping in `bet_selection_screen.dart`

**Current**: Only has NBA team mapping (30 teams)
**Needed**: Add mappings for:

1. **NFL Teams** (32 teams)
   ```dart
   // Example mapping
   'arizona cardinals': '22',
   'atlanta falcons': '1',
   // ... 30 more teams
   ```

2. **NCAAF Teams** (Top ~130 FBS teams)
   ```dart
   // Example mapping
   'alabama crimson tide': '333',
   'auburn tigers': '2',
   'georgia bulldogs': '61',
   // ... more teams
   ```

3. **MLB Teams** (30 teams)
   ```dart
   // Example mapping
   'new york yankees': '10',
   'boston red sox': '2',
   // ... 28 more teams
   ```

4. **NHL Teams** (32 teams)
   ```dart
   // Example mapping
   'boston bruins': '6',
   'chicago blackhawks': '5',
   // ... 30 more teams
   ```

5. **NCAAB Teams** (Top ~350 Division I teams)
   ```dart
   // Example mapping
   'duke blue devils': '150',
   'kansas jayhawks': '96',
   // ... more teams
   ```

**Alternative Approach**: Store team ID mappings in a separate JSON file or Firestore collection to avoid bloating the code file.

**Location**: `bet_selection_screen.dart` lines 2476-2540 (after `_extractEspnTeamId()`)

---

### Phase 3: Detection Logic Updates

#### 3.1 Update `_checkForInjuries()` in `bet_selection_screen.dart`

**Current Logic** (Line 2419):
```dart
if (widget.sport.toLowerCase() != 'basketball') {
  return; // Only checks NBA
}
```

**New Logic**:
```dart
Future<void> _checkForInjuries() async {
  // Determine sport type for injury checking
  String sportToCheck = widget.sport.toLowerCase();

  // Map display sport to injury API sport
  final sportMapping = {
    'basketball': 'basketball',     // NBA
    'ncaab': 'ncaab',               // College Basketball
    'football': 'football',         // NFL
    'ncaaf': 'ncaaf',               // College Football
    'baseball': 'baseball',         // MLB
    'hockey': 'hockey',             // NHL
    'soccer': 'soccer',             // MLS
  };

  if (!sportMapping.containsKey(sportToCheck)) {
    print('[InjuryCheck] Sport not supported: $sportToCheck');
    return;
  }

  final injuryService = InjuryService();

  // Check if this sport supports injuries
  if (!injuryService.sportSupportsInjuries(sportToCheck)) {
    print('[InjuryCheck] Sport does not support injuries: $sportToCheck');
    return;
  }

  // Wait for game data
  if (_gameData == null) {
    await Future.delayed(Duration(seconds: 2));
    if (_gameData == null) return;
  }

  setState(() => _isCheckingInjuries = true);

  try {
    // Extract ESPN team IDs (now supports all sports)
    final homeTeamId = _extractEspnTeamId(_gameData!.homeTeam, sportToCheck);
    final awayTeamId = _extractEspnTeamId(_gameData!.awayTeam, sportToCheck);

    if (homeTeamId == null || awayTeamId == null) {
      print('[InjuryCheck] Could not extract ESPN team IDs');
      setState(() => _isCheckingInjuries = false);
      return;
    }

    // Check for injuries
    final hasInjuries = await injuryService.gameHasInjuries(
      sport: sportToCheck,
      homeTeamId: homeTeamId,
      awayTeamId: awayTeamId,
    );

    setState(() {
      _hasInjuries = hasInjuries;
      _isCheckingInjuries = false;
      if (hasInjuries) {
        _availableIntel['injury'] = 'available';
      }
    });
  } catch (e) {
    print('[InjuryCheck] Error: $e');
    setState(() => _isCheckingInjuries = false);
  }
}
```

**Location**: Lines 2417-2475

---

### Phase 4: Team ID Extraction Enhancement

#### 4.1 Update `_extractEspnTeamId()` Method

**Current**: Single method with NBA-only mapping
**New**: Sport-aware method with multiple mappings

```dart
String? _extractEspnTeamId(String teamName, String sport) {
  final normalizedTeam = teamName.toLowerCase().trim();

  switch (sport.toLowerCase()) {
    case 'basketball':
      return _nbaTeamIds[normalizedTeam];
    case 'ncaab':
      return _ncaabTeamIds[normalizedTeam];
    case 'football':
      return _nflTeamIds[normalizedTeam];
    case 'ncaaf':
      return _ncaafTeamIds[normalizedTeam];
    case 'baseball':
      return _mlbTeamIds[normalizedTeam];
    case 'hockey':
      return _nhlTeamIds[normalizedTeam];
    case 'soccer':
      return _mlsTeamIds[normalizedTeam];
    default:
      return null;
  }
}

// Separate maps for each sport
final Map<String, String> _nbaTeamIds = { /* existing 30 teams */ };
final Map<String, String> _nflTeamIds = { /* 32 teams */ };
final Map<String, String> _ncaafTeamIds = { /* 130+ teams */ };
final Map<String, String> _mlbTeamIds = { /* 30 teams */ };
final Map<String, String> _nhlTeamIds = { /* 32 teams */ };
final Map<String, String> _ncaabTeamIds = { /* 350+ teams */ };
final Map<String, String> _mlsTeamIds = { /* 29 teams */ };
```

**Location**: After line 2540

---

### Phase 5: UI Updates

#### 5.1 Icon Updates for Each Sport

Currently uses `Icons.healing` for injury indicator. Consider sport-specific variations:
- **Football**: Keep healing icon or use injury-specific icon
- **Baseball**: Keep healing icon
- **Hockey**: Keep healing icon
- **Soccer**: Keep healing icon

**Location**: `bet_selection_screen.dart` line 2652 (icon in pulsing indicator)

#### 5.2 Navigation Updates

The navigation to injury intel screens should work universally since it passes:
- `sport` parameter
- `homeTeamId` / `awayTeamId`
- Team names

**No changes needed** - Already generic

**Location**: `bet_selection_screen.dart` lines 4145-4173 (`_navigateToEdge()`)

---

### Phase 6: Intel Card Screens Updates

#### 6.1 Update Sport Icon Display

**Files to Update:**
1. `lib/screens/intel/intel_type_selection_screen.dart`
2. `lib/screens/intel/injury_intel_purchase_screen.dart`
3. `lib/screens/intel/injury_report_view_screen.dart`

**Current**: Hardcoded basketball emoji (🏀)
**New**: Dynamic emoji based on sport

```dart
String _getSportEmoji(String sport) {
  switch (sport.toLowerCase()) {
    case 'basketball':
    case 'ncaab':
      return '🏀';
    case 'football':
    case 'ncaaf':
      return '🏈';
    case 'baseball':
      return '⚾';
    case 'hockey':
      return '🏒';
    case 'soccer':
      return '⚽';
    default:
      return '🏀';
  }
}
```

**Locations:**
- `injury_intel_purchase_screen.dart` line 109
- `injury_report_view_screen.dart` line 209, 219

#### 6.2 Update Sport-Specific Text

Replace hardcoded "NBA" references with dynamic sport display:
- "NBA Injury Intel" → "{Sport} Injury Intel"
- Update season-specific language if needed

---

## Testing Plan

### 1. Unit Tests
- [ ] Test injury detection for each sport
- [ ] Test team ID extraction for each sport
- [ ] Test ESPN API responses for each league

### 2. Integration Tests

**For Each Sport (NFL, NCAAF, MLB, NHL, NCAAB, Soccer):**
- [ ] Navigate to a game
- [ ] Verify injury detection works
- [ ] Verify "Get The Edge" button appears when injuries present
- [ ] Tap button and verify navigation to intel type selection
- [ ] Purchase injury intel card
- [ ] Verify injury report displays correctly
- [ ] Verify team logos display (if available)
- [ ] Test bundle vs individual team purchases

### 3. Edge Cases
- [ ] Games with no injuries (button should not appear)
- [ ] Games with injuries on only one team
- [ ] Games with injuries on both teams
- [ ] Team names that don't match mapping (graceful degradation)
- [ ] API failures (show appropriate error messages)

---

## Data Requirements

### ESPN Team ID Mappings Needed

**Priority Order:**

1. **High Priority** (Implement First)
   - ✅ NBA (30 teams) - Already done
   - 🟡 NFL (32 teams) - High user demand
   - 🟡 NCAAF (~130 FBS teams) - Top 25 initially

2. **Medium Priority**
   - 🟡 MLB (30 teams)
   - 🟡 NHL (32 teams)

3. **Low Priority** (Based on Usage)
   - 🟡 NCAAB (~350 D1 teams) - Top 25 initially
   - 🟡 MLS (29 teams)

### Recommended Approach for Large Mappings (NCAAF, NCAAB)

Instead of hardcoding all teams:

1. **Create JSON files:**
   ```
   /assets/team_ids/ncaaf_teams.json
   /assets/team_ids/ncaab_teams.json
   ```

2. **Load dynamically:**
   ```dart
   Future<Map<String, String>> _loadTeamIds(String sport) async {
     final jsonString = await rootBundle.loadString('assets/team_ids/${sport}_teams.json');
     final Map<String, dynamic> data = json.decode(jsonString);
     return data.map((key, value) => MapEntry(key, value.toString()));
   }
   ```

3. **Cache in memory** after first load

---

## Implementation Timeline

### Week 1: Foundation
- [ ] Update `InjuryService` with college sports support
- [ ] Create team ID JSON files for all sports
- [ ] Update `_checkForInjuries()` logic to support all sports

### Week 2: NFL & NCAAF
- [ ] Add NFL team ID mappings
- [ ] Add NCAAF team ID mappings (top 25 teams)
- [ ] Update `_extractEspnTeamId()` to support football
- [ ] Test with live NFL/NCAAF games

### Week 3: MLB & NHL
- [ ] Add MLB team ID mappings
- [ ] Add NHL team ID mappings
- [ ] Test with live games

### Week 4: Polish & Expansion
- [ ] Add remaining NCAAF teams
- [ ] Add NCAAB support (top 25 teams)
- [ ] Add MLS support
- [ ] Update UI with sport-specific icons
- [ ] Comprehensive testing

---

## Risk Mitigation

### Potential Issues:

1. **Team Name Variations**
   - ESPN might use different names than Odds API
   - Solution: Add alternate name mappings

2. **Large Team ID Dictionaries**
   - NCAAF/NCAAB have hundreds of teams
   - Solution: Use JSON files instead of hardcoded maps

3. **API Rate Limits**
   - Checking injuries for every game might hit limits
   - Solution: Implement caching, check only on user action

4. **Missing Team IDs**
   - Small schools might not have ESPN IDs
   - Solution: Gracefully skip injury check, log missing teams

---

## Success Metrics

- [ ] Injury intel cards available for all 6 sports
- [ ] Team ID coverage >90% for pro sports
- [ ] Team ID coverage >80% for top 25 college teams
- [ ] <500ms injury detection time
- [ ] <5% error rate on team ID extraction
- [ ] User purchases injury intel across multiple sports

---

## Future Enhancements

1. **Automatic Team ID Discovery**
   - Build ESPN team ID scraper
   - Update mappings automatically

2. **Injury Severity Scoring**
   - Weight injuries by player importance
   - Show "High Impact" vs "Low Impact" indicators

3. **Historical Injury Tracking**
   - Track injury trends over season
   - "Team has dealt with injuries all season" insights

4. **Injury Intel Bundles**
   - "All NFL Games This Week" bundle
   - Season-long injury tracking subscription
