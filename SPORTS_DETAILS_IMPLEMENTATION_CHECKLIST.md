# Sports Details Page Implementation Checklist

## Overview
This checklist captures lessons learned from implementing the MLB baseball details page to ensure smooth implementation for NFL, NBA, NHL, and other sports.

---

## 🔑 Critical Issues to Address First

### 1. Game ID Management
**Problem Found:** Internal game IDs don't match ESPN API IDs
- ❌ **Wrong:** Using hash-like IDs (e.g., `b57e123101e4d592a1725d80fed2dc75`)
- ✅ **Correct:** Store ESPN IDs separately (e.g., `401697155`)

**Implementation Steps:**
- [ ] Add `espnId` field to GameModel if not present
- [ ] Update `_convertEspnEventToGame` in `optimized_games_service.dart`
- [ ] Store ESPN ID when fetching games: `espnId: event['id']?.toString()`
- [ ] Use ESPN ID for all API calls: `final espnGameId = _game?.espnId ?? widget.gameId`

### 2. API Data Verification
**Before implementing UI, verify data availability:**
- [ ] Test ESPN scoreboard endpoint: `/sports/{sport}/{league}/scoreboard`
- [ ] Test ESPN summary endpoint: `/sports/{sport}/{league}/summary?event={gameId}`
- [ ] Document available fields for each sport
- [ ] Note sport-specific data (e.g., pitchers for MLB, quarterbacks for NFL)

---

## 📋 Implementation Steps

### Phase 1: Planning & Documentation

#### 1.1 Create Sport-Specific Plan
- [ ] Document available ESPN API data
- [ ] Define tab structure (usually 3 tabs instead of 5)
- [ ] Decide on UI layout approach:
  - **Hybrid approach** (recommended):
    - Matchup tab: Split view for comparisons
    - Stats/Box Score: Full width for tables
    - Team stats: Toggle view for detailed stats
- [ ] Exclude premium features from basic details:
  - No play-by-play data
  - No odds/betting lines
  - No news/injuries (save for Edge feature)

#### 1.2 Sport-Specific Data Mapping
Map sport-specific terms and data:

**NFL Example:**
```dart
// Key players: quarterbacks
// Key stats: passing yards, rushing yards, turnovers
// Special: possession time, red zone efficiency
```

**NBA Example:**
```dart
// Key players: leading scorers
// Key stats: FG%, 3P%, rebounds, assists
// Special: fast break points, points in paint
```

**NHL Example:**
```dart
// Key players: goalies
// Key stats: shots, saves, power play
// Special: face-off percentage, penalty minutes
```

### Phase 2: API Integration

#### 2.1 Update `_loadEventDetails()` Method
- [ ] Add sport-specific loading method (e.g., `_loadNflDetails()`)
- [ ] Use correct ESPN endpoints with sport/league:
  ```dart
  final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/summary?event=$espnGameId';
  final scoreboardUrl = 'https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/scoreboard';
  ```
- [ ] Add comprehensive error handling and logging
- [ ] Parse both summary and scoreboard data

#### 2.2 Data Parsing Methods
Create sport-specific parsing methods:
- [ ] `_parse{Sport}Summary()`
- [ ] `_parse{Sport}BoxScore()`
- [ ] `_parse{Sport}KeyPlayers()`
- [ ] `_parse{Sport}TeamStats()`

#### 2.3 Testing & Debugging
- [ ] Add console logging at each step:
  ```dart
  print('=== {SPORT} DETAILS TEST START ===');
  print('Game ID: $gameId');
  print('ESPN ID: $espnGameId');
  print('Fetching from: $url');
  print('Response status: ${response.statusCode}');
  ```
- [ ] Verify data structure matches expectations
- [ ] Handle missing/null data gracefully

### Phase 3: UI Implementation

#### 3.1 Tab Structure
- [ ] Implement 3-tab structure (remove unnecessary tabs):
  1. **Matchup/Overview** - Key matchup information
  2. **Box Score/Stats** - Live scoring and statistics
  3. **Team Stats/History** - Season stats and trends
- [ ] Add sport detection in build method:
  ```dart
  final isSportName = widget.sport.toUpperCase() == 'SPORT_NAME';
  ```

#### 3.2 Sport-Specific Widgets
Create reusable widgets:
- [ ] `{Sport}MatchupCard` - Key player comparisons
- [ ] `{Sport}StatsTable` - Sport-specific statistics
- [ ] `{Sport}ScoreWidget` - Score display format
- [ ] `TeamFormCard` - Recent performance

#### 3.3 Responsive Design
- [ ] Implement responsive layouts:
  ```dart
  final isTablet = MediaQuery.of(context).size.width > 600;
  ```
- [ ] Use split view on tablets where appropriate
- [ ] Stack views on phones for readability

### Phase 4: Data Models

#### 4.1 Sport-Specific Models
Create models as needed:

**NFL Example:**
```dart
class NflQuarterbackData {
  final String name;
  final int completions;
  final int attempts;
  final int yards;
  final int touchdowns;
  final int interceptions;
  final double rating;
}
```

**NBA Example:**
```dart
class NbaPlayerStats {
  final String name;
  final int points;
  final int rebounds;
  final int assists;
  final String fieldGoalPct;
  final String threePtPct;
}
```

### Phase 5: Testing & Validation

#### 5.1 Create Test Documentation
- [ ] Create `TEST_{SPORT}_DETAILS.md` with:
  - Sample game IDs for testing
  - Expected console output
  - Common issues and solutions
  - API response examples

#### 5.2 Testing Checklist
- [ ] Test with scheduled games (future)
- [ ] Test with live games (in progress)
- [ ] Test with completed games (final)
- [ ] Test with games from different days
- [ ] Verify ESPN ID is being used (not internal ID)
- [ ] Check all tabs load without errors
- [ ] Verify data displays correctly

---

## 🐛 Common Issues & Solutions

### Issue 1: API Returns 400/404 Error
**Cause:** Wrong game ID format
**Solution:**
- Ensure using ESPN ID, not internal ID
- Check ID format matches sport (numeric for most sports)
- Verify game exists in ESPN system

### Issue 2: Data Shows "TBD" or "N/A"
**Cause:** API call failing or data not available
**Solution:**
- Check console for actual API response
- Verify game hasn't been postponed/cancelled
- Some data only available after game starts

### Issue 3: Missing Sport-Specific Data
**Cause:** Game status or data availability
**Solution:**
- Starting lineups only available close to game time
- Live stats only during game
- Final stats after game completion

### Issue 4: Console Shows Wrong Game ID Format
**Cause:** Using internal ID instead of ESPN ID
**Solution:**
- Update `_convertEspnEventToGame` to store ESPN ID
- Use `game.espnId` instead of `game.id` for API calls

---

## 📝 Code Templates

### API Call Template
```dart
Future<void> _load{Sport}Details() async {
  if (_game == null) return;

  setState(() => _isLoading = true);

  try {
    // Use ESPN ID if available, fallback to widget ID
    final espnGameId = _game?.espnId ?? widget.gameId;

    print('=== {SPORT} DETAILS TEST START ===');
    print('Game ID: ${widget.gameId}');
    print('ESPN ID: $espnGameId');
    print('Sport: ${widget.sport}');
    print('Teams: ${_game?.awayTeam} @ ${_game?.homeTeam}');

    // Fetch summary data
    final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/summary?event=$espnGameId';
    print('Fetching summary from: $summaryUrl');

    final summaryResponse = await http.get(Uri.parse(summaryUrl));
    print('Summary response status: ${summaryResponse.statusCode}');

    if (summaryResponse.statusCode == 200) {
      final summaryData = json.decode(summaryResponse.body);
      print('Summary data keys: ${summaryData.keys.toList()}');
      _parse{Sport}Summary(summaryData);
    }

    // Fetch scoreboard for additional data
    final scoreboardUrl = 'https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/scoreboard';
    final scoreboardResponse = await http.get(Uri.parse(scoreboardUrl));

    if (scoreboardResponse.statusCode == 200) {
      final scoreboardData = json.decode(scoreboardResponse.body);
      _findAndParse{Sport}Event(scoreboardData, espnGameId);
    }

    print('=== {SPORT} DETAILS TEST END ===');

  } catch (e, stackTrace) {
    print('Error loading {sport} details: $e');
    print('Stack trace: $stackTrace');
  } finally {
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }
}
```

### Sport Detection Template
```dart
Widget build(BuildContext context) {
  final sportUpper = widget.sport.toUpperCase();

  // Determine sport-specific configuration
  int tabCount;
  List<Tab> tabs;

  switch (sportUpper) {
    case 'NFL':
      tabCount = 3;
      tabs = [
        Tab(text: 'Matchup'),
        Tab(text: 'Box Score'),
        Tab(text: 'Stats'),
      ];
      break;
    case 'NBA':
      tabCount = 3;
      tabs = [
        Tab(text: 'Matchup'),
        Tab(text: 'Box Score'),
        Tab(text: 'Stats'),
      ];
      break;
    // Add other sports...
    default:
      // Generic tabs
      tabCount = 5;
      tabs = _buildGenericTabs();
  }

  return DefaultTabController(
    length: tabCount,
    child: Scaffold(
      // ... rest of build
    ),
  );
}
```

---

## ✅ Final Checklist Before Testing

- [ ] ESPN ID is properly stored when games are fetched
- [ ] ESPN ID is used for all API calls (not internal ID)
- [ ] All API endpoints use correct sport/league format
- [ ] Error handling is in place for all API calls
- [ ] Console logging added for debugging
- [ ] Sport detection logic implemented
- [ ] Tab structure matches sport requirements
- [ ] Data parsing handles null/missing values
- [ ] UI gracefully handles loading and error states
- [ ] Test documentation created

---

## 📊 Sport-Specific API Endpoints

### NFL
- Scoreboard: `/sports/football/nfl/scoreboard`
- Summary: `/sports/football/nfl/summary?event={id}`

### NBA
- Scoreboard: `/sports/basketball/nba/scoreboard`
- Summary: `/sports/basketball/nba/summary?event={id}`

### NHL
- Scoreboard: `/sports/hockey/nhl/scoreboard`
- Summary: `/sports/hockey/nhl/summary?event={id}`

### MLB
- Scoreboard: `/sports/baseball/mlb/scoreboard`
- Summary: `/sports/baseball/mlb/summary?event={id}`

---

## 🎯 Success Criteria

1. **Data Loading:** All tabs show real data (no placeholders)
2. **ID Management:** ESPN IDs used correctly for API calls
3. **Error Handling:** Graceful handling of API failures
4. **Sport Detection:** Correct tabs/layout for each sport
5. **Performance:** Page loads within 2 seconds
6. **Responsiveness:** Works on phone and tablet layouts
7. **User Value:** Displays actionable information for betting decisions

---

*Last Updated: Current Session*
*Next Sport to Implement: NFL (most popular)*