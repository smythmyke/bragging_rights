# NCAAF and NCAAB Details Pages Implementation Plan
**Adding Game Details Pages for College Football and College Basketball**

## Current Status

### ✅ Details Pages Implemented
- **NFL** - 3 tabs: Overview, Stats, Standings
- **NBA** - 5 tabs: Overview, Box Score, Stats, Standings, News
- **MLB** - 3 tabs: Matchup, Box Score, Stats

### ⏳ Ready to Implement
- **NCAAF** (College Football) - Can reuse 95% of NFL implementation
- **NCAAB** (Men's College Basketball) - Can reuse 95% of NBA implementation

---

## API Endpoints Verified

### NCAAF
```
Summary: https://site.api.espn.com/apis/site/v2/sports/football/college-football/summary?event={eventId}
Scoreboard: https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard
```

**Response Structure:**
```json
{
  "boxscore": {},      // Team/player stats
  "header": {},        // Game info, teams, scores
  "leaders": [],       // Passing, rushing, receiving leaders
  "standings": {},     // Conference standings
  "drives": [],        // Play-by-play drive data
  "scoringPlays": [],  // Touchdowns, field goals
  "gameInfo": {},      // Venue, weather, attendance
  "odds": [],          // Betting odds
  "broadcasts": [],    // TV info
  "winprobability": [],
  "pickcenter": [],    // College-specific: betting picks
  "againstTheSpread": [] // College-specific: ATS data
}
```

### NCAAB
```
Summary: https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/summary?event={eventId}
Scoreboard: https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard
```

**Response Structure:**
```json
{
  "boxscore": {},      // Team/player stats
  "header": {},        // Game info, teams, scores
  "leaders": [],       // Points, rebounds, assists leaders
  "standings": {},     // Conference standings
  "lastFiveGames": [], // Recent form
  "gameInfo": {},      // Venue, attendance
  "odds": [],          // Betting odds
  "broadcasts": [],    // TV info
  "winprobability": [],
  "pickcenter": [],    // College-specific: betting picks
  "againstTheSpread": [] // College-specific: ATS data
}
```

---

## Implementation Strategy

### Phase 1: Code Structure Setup
**Goal:** Set up routing and initial loading methods

#### 1.1 Update `_loadGameDetails()` in `game_details_screen.dart`

**Current Code** (lines ~4180-4220):
```dart
Future<void> _loadGameDetails() async {
  setState(() {
    _isLoading = true;
  });

  switch (widget.sport.toLowerCase()) {
    case 'basketball':
      await _loadBasketballDetails();
      break;
    case 'football':
      await _loadNFLDetails();
      break;
    case 'baseball':
      await _loadBaseballDetails();
      break;
    // ... other sports
  }
}
```

**Add Cases:**
```dart
case 'ncaaf':
  await _loadNCAAfDetails();
  break;
case 'ncaab':
  await _loadNCAABDetails();
  break;
```

**Location:** After line ~4220 in `game_details_screen.dart`

---

### Phase 2: NCAAF Implementation

#### 2.1 Create `_loadNCAAfDetails()` Method

**Add after `_loadNFLDetails()` method (line ~4390):**

```dart
/// Load NCAAF game details from ESPN API
Future<void> _loadNCAAfDetails() async {
  try {
    print('=== LOADING NCAAF DETAILS ===');

    // 1. Resolve ESPN ID (same as NFL)
    final resolver = EspnIdResolverService();
    var espnGameId = _game?.espnId ?? await resolver.resolveEspnId(_game!);

    if (espnGameId == null) {
      print('❌ Could not resolve ESPN ID for NCAAF game');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print('✅ ESPN Game ID: $espnGameId');

    // 2. Fetch summary from college-football endpoint
    final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/football/college-football/summary?event=$espnGameId';
    print('📡 Fetching summary from: $summaryUrl');

    final summaryResponse = await http.get(Uri.parse(summaryUrl));

    if (summaryResponse.statusCode == 200) {
      final summaryData = json.decode(summaryResponse.body);

      setState(() {
        _boxScore = summaryData['boxscore'];
        _gameData = summaryData;
        _eventDetails = summaryData;
      });

      print('✅ NCAAF details loaded successfully');
      print('   - Boxscore: ${_boxScore != null ? "✓" : "✗"}');
      print('   - Leaders: ${summaryData['leaders'] != null ? "✓" : "✗"}');
      print('   - Drives: ${summaryData['drives'] != null ? "✓" : "✗"}');
      print('   - Standings: ${summaryData['standings'] != null ? "✓" : "✗"}');
    } else {
      print('❌ Failed to load NCAAF summary: ${summaryResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Error loading NCAAF details: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}
```

#### 2.2 Update Tab Configuration for NCAAF

**Modify `_buildTabs()` method (lines ~440-500):**

**Current:**
```dart
case 'football':
  return [
    Tab(text: 'OVERVIEW'),
    Tab(text: 'STATS'),
    Tab(text: 'STANDINGS'),
  ];
```

**Add:**
```dart
case 'ncaaf':
  return [
    Tab(text: 'OVERVIEW'),
    Tab(text: 'STATS'),
    Tab(text: 'STANDINGS'),
  ];
```

#### 2.3 Update Tab Views for NCAAF

**Modify `_buildTabViews()` method (lines ~500-600):**

**Add:**
```dart
case 'ncaaf':
  return [
    _buildNFLOverviewTab(),    // Reuse NFL overview
    _buildNFLStatsTab(),       // Reuse NFL stats
    _buildNFLStandingsTab(),   // Reuse NFL standings
  ];
```

**Why this works:**
- NCAAF has same data structure as NFL (boxscore, leaders, drives, scoringPlays)
- Can reuse all NFL widget builders without modification
- Only difference is the API endpoint URL

---

### Phase 3: NCAAB Implementation

#### 3.1 Create `_loadNCAABDetails()` Method

**Add after `_loadBasketballDetails()` method (line ~4120):**

```dart
/// Load NCAAB game details from ESPN API
Future<void> _loadNCAABDetails() async {
  try {
    print('=== LOADING NCAAB DETAILS ===');

    // 1. Resolve ESPN ID (same as NBA)
    final resolver = EspnIdResolverService();
    var espnGameId = _game?.espnId ?? await resolver.resolveEspnId(_game!);

    if (espnGameId == null) {
      print('❌ Could not resolve ESPN ID for NCAAB game');
      setState(() {
        _isLoading = false;
      });
      return;
    }

    print('✅ ESPN Game ID: $espnGameId');

    // 2. Fetch summary from mens-college-basketball endpoint
    final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/summary?event=$espnGameId';
    print('📡 Fetching summary from: $summaryUrl');

    final summaryResponse = await http.get(Uri.parse(summaryUrl));

    if (summaryResponse.statusCode == 200) {
      final summaryData = json.decode(summaryResponse.body);

      setState(() {
        _boxScore = summaryData['boxscore'];
        _gameData = summaryData;
        _eventDetails = summaryData;
      });

      // Fetch standings (conference standings)
      await _fetchNCAABStandings(summaryData);

      print('✅ NCAAB details loaded successfully');
      print('   - Boxscore: ${_boxScore != null ? "✓" : "✗"}');
      print('   - Leaders: ${summaryData['leaders'] != null ? "✓" : "✗"}');
      print('   - Standings: ${summaryData['standings'] != null ? "✓" : "✗"}');
      print('   - Last 5 Games: ${summaryData['lastFiveGames'] != null ? "✓" : "✗"}');
    } else {
      print('❌ Failed to load NCAAB summary: ${summaryResponse.statusCode}');
    }
  } catch (e) {
    print('❌ Error loading NCAAB details: $e');
  } finally {
    setState(() {
      _isLoading = false;
    });
  }
}

/// Fetch NCAAB standings (conference standings)
Future<void> _fetchNCAABStandings(Map<String, dynamic> gameData) async {
  try {
    print('🏀 Fetching NCAAB standings...');

    // NCAAB standings are in the summary response
    final standingsData = gameData['standings'];

    if (standingsData != null && standingsData['groups'] != null) {
      setState(() {
        if (_eventDetails != null) {
          _eventDetails!['standings'] = standingsData;
        }
      });
      print('✅ NCAAB standings loaded');
    } else {
      print('⚠️ No standings data available');
    }
  } catch (e) {
    print('❌ Error loading NCAAB standings: $e');
  }
}
```

#### 3.2 Update Tab Configuration for NCAAB

**Modify `_buildTabs()` method:**

**Add:**
```dart
case 'ncaab':
  return [
    Tab(text: 'OVERVIEW'),
    Tab(text: 'BOX SCORE'),
    Tab(text: 'STATS'),
    Tab(text: 'STANDINGS'),
    Tab(text: 'NEWS'),
  ];
```

#### 3.3 Update Tab Views for NCAAB

**Modify `_buildTabViews()` method:**

**Add:**
```dart
case 'ncaab':
  return [
    _buildBasketballOverviewTab(),    // Reuse NBA overview
    _buildBasketballBoxScoreTab(),    // Reuse NBA box score
    _buildBasketballStatsTab(),       // Reuse NBA stats
    _buildBasketballStandingsTab(),   // Reuse NBA standings
    _buildBasketballNewsTab(),        // Reuse NBA news
  ];
```

**Why this works:**
- NCAAB has same data structure as NBA (boxscore, leaders, standings)
- Can reuse all NBA widget builders without modification
- Only difference is the API endpoint URL

---

## Phase 4: ESPN ID Resolution

Both NCAAF and NCAAB will need ESPN ID resolution to map games to ESPN event IDs.

### Current Implementation (Works for All Sports)

**File:** `lib/services/espn_id_resolver_service.dart`

The existing `EspnIdResolverService` already supports all sports including NCAAF and NCAAB:

```dart
Future<String?> resolveEspnId(GameModel game) async {
  // Maps sport to ESPN API path
  final sportPath = _getSportPath(game.sport);

  // Fetches scoreboard and matches by team names
  final url = 'https://site.api.espn.com/apis/site/v2/sports/$sportPath/scoreboard';
  // ... matching logic
}

String _getSportPath(String sport) {
  switch (sport.toLowerCase()) {
    case 'basketball':
      return 'basketball/nba';
    case 'ncaab':
      return 'basketball/mens-college-basketball';
    case 'football':
      return 'football/nfl';
    case 'ncaaf':
      return 'football/college-football';
    // ... other sports
  }
}
```

**No changes needed** - NCAAF and NCAAB are already supported.

---

## Phase 5: UI Components and Widget Reuse

### 5.1 NCAAF Widget Reuse (from NFL)

**All NFL widgets can be reused:**

1. **Overview Tab** (`_buildNFLOverviewTab()`)
   - Game summary
   - Team leaders (passing, rushing, receiving)
   - Scoring plays
   - Drive chart

2. **Stats Tab** (`_buildNFLStatsTab()`)
   - Team statistics
   - Player statistics (passing, rushing, receiving, defense)
   - Box score

3. **Standings Tab** (`_buildNFLStandingsTab()`)
   - Conference standings (will show college conferences instead of NFL divisions)
   - Win-loss records

**No modifications needed** - data structure is identical.

### 5.2 NCAAB Widget Reuse (from NBA)

**All NBA widgets can be reused:**

1. **Overview Tab** (`_buildBasketballOverviewTab()`)
   - Game summary
   - Team leaders (points, rebounds, assists)
   - Key plays

2. **Box Score Tab** (`_buildBasketballBoxScoreTab()`)
   - Quarter/half scoring
   - Team statistics

3. **Stats Tab** (`_buildBasketballStatsTab()`)
   - Player statistics
   - Team comparison

4. **Standings Tab** (`_buildBasketballStandingsTab()`)
   - Conference standings (will show college conferences)
   - Recent form (Last 5 games)

5. **News Tab** (`_buildBasketballNewsTab()`)
   - Game-related news articles

**No modifications needed** - data structure is identical.

---

## Phase 6: Testing Strategy

### 6.1 NCAAF Testing

**Test Cases:**

1. **Load game with ESPN ID present**
   - Game: Texas Tech @ Houston (ID: 401756913)
   - Expected: Details load immediately

2. **Load game requiring ESPN ID resolution**
   - Game: Any recent NCAAF game without ESPN ID
   - Expected: Resolver finds ESPN ID, then loads details

3. **Display data**
   - ✓ Boxscore displays correctly
   - ✓ Team leaders show (passing, rushing, receiving)
   - ✓ Scoring plays display
   - ✓ Drive chart displays
   - ✓ Conference standings display

4. **Game states**
   - ✓ Pregame: Shows odds, team info
   - ✓ Live: Shows live score, plays
   - ✓ Final: Shows final score, full stats

### 6.2 NCAAB Testing

**Test Cases:**

1. **Load game with ESPN ID present**
   - Game: Old Dominion @ Miami (OH) (ID: 401829496)
   - Expected: Details load immediately

2. **Load game requiring ESPN ID resolution**
   - Game: Any recent NCAAB game without ESPN ID
   - Expected: Resolver finds ESPN ID, then loads details

3. **Display data**
   - ✓ Boxscore displays correctly
   - ✓ Team leaders show (points, rebounds, assists)
   - ✓ Player statistics display
   - ✓ Conference standings display
   - ✓ Last 5 games display

4. **Game states**
   - ✓ Pregame: Shows odds, team info
   - ✓ Live: Shows live score, plays
   - ✓ Final: Shows final score, full stats

### 6.3 Edge Cases

1. **ESPN ID not found**
   - Expected: Show error message, gracefully degrade

2. **API returns 404**
   - Expected: Show "Details not available" message

3. **Partial data (missing standings, etc.)**
   - Expected: Show available data, hide missing sections

4. **Team name mismatches**
   - Expected: Resolver attempts fuzzy matching

---

## Phase 7: College-Specific Enhancements (Optional)

### 7.1 Additional Data Fields

NCAAF and NCAAB APIs include college-specific data not in pro sports:

```json
"pickcenter": [],           // Betting picks/predictions
"againstTheSpread": [],     // ATS betting data
"wallclockAvailable": bool  // Timing flag
```

**Future Enhancement:**
- Add "Picks" tab showing betting picks from pickcenter
- Show ATS record in standings

### 7.2 Conference-Specific Handling

**NCAAF Conferences:**
- SEC, Big Ten, ACC, Big 12, Pac-12
- Independent schools
- Group of 5 conferences

**NCAAB Conferences:**
- 30+ conferences (ACC, Big Ten, Big 12, etc.)
- May want to filter to show only relevant conference

**Implementation:**
- Current standings widget should handle this automatically
- Conference name will display in standings table

---

## Implementation Timeline

### Week 1: NCAAF Implementation
- **Day 1-2:** Add `_loadNCAAfDetails()` method
- **Day 2-3:** Update routing and tab configuration
- **Day 3-4:** Test with live NCAAF games
- **Day 4-5:** Bug fixes and refinement

### Week 2: NCAAB Implementation
- **Day 1-2:** Add `_loadNCAABDetails()` method
- **Day 2-3:** Update routing and tab configuration
- **Day 3-4:** Test with live NCAAB games
- **Day 4-5:** Bug fixes and refinement

### Week 3: Polish and Testing
- **Day 1-2:** Edge case testing
- **Day 3-4:** Performance optimization
- **Day 5:** Documentation update

**Total Estimated Time:** 2-3 weeks

---

## Code Changes Summary

### Files to Modify

1. **`lib/screens/games/game_details_screen.dart`**
   - Add `_loadNCAAfDetails()` method (~50 lines)
   - Add `_loadNCAABDetails()` method (~50 lines)
   - Add `_fetchNCAABStandings()` method (~20 lines)
   - Update `_loadGameDetails()` switch statement (+4 lines)
   - Update `_buildTabs()` method (+6 lines)
   - Update `_buildTabViews()` method (+10 lines)
   - **Total: ~140 new lines**

2. **No other files need modification**
   - ESPN ID resolver already supports NCAAF/NCAAB
   - All widgets can be reused from NFL/NBA

### Lines of Code Estimate
- **New code:** ~140 lines
- **Reused code:** ~2000 lines (all NFL/NBA widgets)
- **Efficiency:** 93% code reuse

---

## Risk Mitigation

### Potential Issues

1. **ESPN ID resolution fails for college teams**
   - **Mitigation:** Add team name aliases for common variations
   - **Fallback:** Manual ESPN ID mapping for top 25 teams

2. **Conference standings display issues**
   - **Mitigation:** Test with multiple conferences
   - **Fallback:** Hide standings tab if data malformed

3. **Player data differences**
   - **Mitigation:** Handle missing fields gracefully
   - **Fallback:** Show team stats only if player data missing

4. **API rate limits**
   - **Mitigation:** Cache details data locally
   - **Fallback:** Show cached data with timestamp

---

## Success Metrics

- [ ] NCAAF details pages load successfully
- [ ] NCAAB details pages load successfully
- [ ] All tabs display correct data
- [ ] ESPN ID resolution works >95% of the time
- [ ] <2 second load time for details
- [ ] No crashes or errors in production
- [ ] User can navigate seamlessly between pro and college games

---

## Future Enhancements

1. **Add "Picks" Tab**
   - Display pickcenter betting predictions
   - Show expert picks and analysis

2. **ATS Tracking**
   - Show team's ATS record in standings
   - Display ATS trends

3. **Last 5 Games Widget (NCAAF)**
   - Add recent form display for football
   - Match NBA/NCAAB functionality

4. **Injury Reports Integration**
   - Show injury intel cards in details page
   - Link to existing injury intel system

5. **Conference Tournament Brackets**
   - Special handling for March Madness (NCAAB)
   - Bowl game tracking (NCAAF)

---

## Sample ESPN Event IDs for Testing

### NCAAF (Oct 4, 2025)
```
401756913 - Texas Tech @ Houston
401752859 - Minnesota @ Ohio State
401754553 - Miami @ Florida State
```

### NCAAB (Nov 3, 2025)
```
401829496 - Old Dominion @ Miami (OH)
401829451 - Evangel @ Kansas City
401829426 - Northwestern State @ Texas A&M
```

---

## Conclusion

**Implementation is straightforward** due to API similarity:
- NCAAF = NFL with different endpoint
- NCAAB = NBA with different endpoint
- Minimal new code required (~140 lines)
- 93% code reuse from existing implementations
- 2-3 week timeline for full implementation and testing

**Recommended Approach:**
1. Start with NCAAF (simpler, fewer conferences)
2. Test thoroughly with live games
3. Replicate for NCAAB
4. Add college-specific enhancements later
