# NCAAF and NCAAB ESPN API Documentation
**College Football and College Basketball Details Data Structure**

## API Endpoint Comparison

### Summary Endpoints

| Sport | Endpoint Pattern | Example |
|-------|-----------------|---------|
| **NFL** | `https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event={eventId}` | event=401547402 |
| **NCAAF** | `https://site.api.espn.com/apis/site/v2/sports/football/college-football/summary?event={eventId}` | event=401756913 |
| **NBA** | `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event={eventId}` | event=401584651 |
| **NCAAB** | `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/summary?event={eventId}` | event=401829496 |
| **MLB** | `https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event={eventId}` | event=401581026 |

### Scoreboard Endpoints (for finding event IDs)

| Sport | Endpoint |
|-------|----------|
| **NCAAF** | `https://site.api.espn.com/apis/site/v2/sports/football/college-football/scoreboard` |
| **NCAAB** | `https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/scoreboard` |

---

## Data Structure Comparison

### Response Keys Available

#### NFL Summary Response
```json
{
  "boxscore": {},
  "header": {},
  "leaders": [],
  "standings": {},
  "drives": [],
  "scoringPlays": [],
  "gameInfo": {},
  "odds": [],
  "broadcasts": [],
  "winprobability": [],
  "videos": [],
  "news": []
}
```

#### NCAAF Summary Response (Very Similar to NFL!)
```json
{
  "boxscore": {},
  "header": {},
  "leaders": [],
  "standings": {},
  "drives": [],
  "scoringPlays": [],
  "gameInfo": {},
  "odds": [],
  "broadcasts": [],
  "winprobability": [],
  "pickcenter": [],
  "againstTheSpread": [],
  "videos": [],
  "news": [],
  "format": {},
  "wallclockAvailable": bool
}
```

**Key Differences from NFL:**
- ✅ Has `pickcenter` (betting picks/predictions)
- ✅ Has `againstTheSpread` (ATS betting data)
- ✅ Has `wallclockAvailable` flag

**Similarities:**
- ✅ Same `boxscore` structure
- ✅ Same `leaders` structure (passing, rushing, receiving)
- ✅ Same `drives` and `scoringPlays` structure
- ✅ Has `standings` (conference standings)

#### MLB Summary Response
```json
{
  "boxscore": {},
  "header": {},
  "leaders": [],
  "gameInfo": {},
  "odds": [],
  "broadcasts": [],
  "videos": [],
  "news": []
}
```

#### NCAAB Summary Response (Very Similar to NBA!)
```json
{
  "boxscore": {},
  "header": {},
  "leaders": [],
  "standings": {},
  "lastFiveGames": [],
  "gameInfo": {},
  "odds": [],
  "broadcasts": [],
  "winprobability": [],
  "pickcenter": [],
  "againstTheSpread": [],
  "videos": [],
  "news": [],
  "format": {},
  "wallclockAvailable": bool,
  "meta": {}
}
```

**Key Differences from NBA:**
- ✅ Has `pickcenter` (betting picks/predictions)
- ✅ Has `againstTheSpread` (ATS betting data)
- ✅ Has `lastFiveGames` (recent form)

**Similarities:**
- ✅ Same `boxscore` structure
- ✅ Same `leaders` structure (points, rebounds, assists)
- ✅ Has `standings` (conference standings)
- ✅ Has `winprobability`

---

## Detailed Data Availability

### NCAAF (College Football)

**Tested with Event:** Texas Tech @ Houston (ID: 401756913)

```
✅ Boxscore:
   - 2 teams with full statistics
   - 2 player groups (passing, rushing, receiving, defensive)

✅ Leaders:
   - 2 teams
   - Passing leaders
   - Rushing leaders
   - Receiving leaders

✅ Standings:
   - 1 group (Conference standings)
   - Division/conference breakdown
   - Win-loss records, conference records

✅ Drives:
   - Play-by-play drive data
   - Scoring drives highlighted

✅ Scoring Plays:
   - Touchdowns, field goals, safeties
   - Quarter/time information

✅ Game Info:
   - Venue, attendance
   - Weather conditions
   - Referees
```

### NCAAB (Men's College Basketball)

**Tested with Event:** Old Dominion @ Miami (OH) (ID: 401829496)

```
✅ Boxscore:
   - 2 teams with full statistics
   - 0 players initially (populated when game starts)

✅ Leaders:
   - 2 teams
   - Points leaders
   - Rebounds leaders
   - Assists leaders

✅ Standings:
   - 2 groups (typically different conferences)
   - Conference standings
   - Win-loss records

✅ Last Five Games:
   - Recent performance data
   - Win/loss streak information

✅ Game Info:
   - Venue, attendance
   - Referees
```

---

## Code Implementation Reference

### NFL Details Loading (Current Implementation)

**File:** `game_details_screen.dart` lines 4270-4390

```dart
Future<void> _loadNFLDetails() async {
  // 1. Resolve ESPN ID using resolver service
  final resolver = EspnIdResolverService();
  var espnGameId = _game?.espnId ?? await resolver.resolveEspnId(_game!);

  // 2. Fetch summary data
  final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=$espnGameId';
  final response = await http.get(Uri.parse(summaryUrl));

  // 3. Parse and store data
  if (response.statusCode == 200) {
    final summaryData = json.decode(response.body);
    setState(() {
      _boxScore = summaryData['boxscore'];
      _gameData = summaryData;
      _eventDetails = summaryData;
    });
  }
}
```

**Tabs:** 3 tabs
1. **Overview** - Game summary, leaders, scoring plays
2. **Stats** - Detailed team/player statistics from boxscore
3. **Standings** - Conference standings

### MLB Details Loading (Current Implementation)

**File:** `game_details_screen.dart` lines 113-250

```dart
Future<void> _loadBaseballDetails() async {
  // 1. Resolve ESPN ID
  final resolver = EspnIdResolverService();
  var espnGameId = _game?.espnId ?? await resolver.resolveEspnId(_game!);

  // 2. Fetch summary
  final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=$espnGameId';
  final response = await http.get(Uri.parse(summaryUrl));

  // 3. Parse data
  if (response.statusCode == 200) {
    final summaryData = json.decode(response.body);
    setState(() {
      _boxScore = summaryData['boxscore'];
      _gameData = summaryData;
      _eventDetails = {
        ...summaryData,
        'competitions': summaryData['header']['competitions'],
      };
    });
  }
}
```

**Tabs:** 3 tabs
1. **Matchup** - Game overview, probable pitchers
2. **Box Score** - Inning-by-inning scoring
3. **Stats** - Batting and pitching statistics

---

## Recommended NCAAF Implementation

### Method Structure

```dart
Future<void> _loadNCAAfDetails() async {
  try {
    print('=== LOADING NCAAF DETAILS ===');

    // 1. Resolve ESPN ID (same as NFL)
    final resolver = EspnIdResolverService();
    var espnGameId = _game?.espnId ?? await resolver.resolveEspnId(_game!);

    if (espnGameId == null) {
      print('❌ Could not resolve ESPN ID');
      return;
    }

    // 2. Fetch summary (change endpoint to college-football)
    final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/football/college-football/summary?event=$espnGameId';
    print('Fetching summary from: $summaryUrl');

    final summaryResponse = await http.get(Uri.parse(summaryUrl));

    if (summaryResponse.statusCode == 200) {
      final summaryData = json.decode(summaryResponse.body);

      setState(() {
        _boxScore = summaryData['boxscore'];
        _gameData = summaryData;
        _eventDetails = summaryData;
      });

      print('✅ NCAAF details loaded successfully');
    }
  } catch (e) {
    print('❌ Error loading NCAAF details: $e');
  }
}
```

### Tab Configuration

**Recommended: 3 tabs (same as NFL)**

1. **Overview**
   - Game summary
   - Team leaders (passing, rushing, receiving)
   - Scoring plays
   - Drive chart

2. **Stats**
   - Team statistics
   - Player statistics (passing, rushing, receiving, defense)
   - Box score

3. **Standings**
   - Conference standings
   - Division records

### Data Reuse from NFL

**Can reuse 95% of NFL UI components:**
- ✅ Scoring plays widget
- ✅ Drive chart widget
- ✅ Team leaders display
- ✅ Box score layout
- ✅ Standings table

**Only change needed:** Endpoint URL from `nfl` → `college-football`

---

## Recommended NCAAB Implementation

### Method Structure

```dart
Future<void> _loadNCAABDetails() async {
  try {
    print('=== LOADING NCAAB DETAILS ===');

    // 1. Resolve ESPN ID (same as NBA)
    final resolver = EspnIdResolverService();
    var espnGameId = _game?.espnId ?? await resolver.resolveEspnId(_game!);

    if (espnGameId == null) {
      print('❌ Could not resolve ESPN ID');
      return;
    }

    // 2. Fetch summary (change endpoint to mens-college-basketball)
    final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/basketball/mens-college-basketball/summary?event=$espnGameId';
    print('Fetching summary from: $summaryUrl');

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
    }
  } catch (e) {
    print('❌ Error loading NCAAB details: $e');
  }
}

Future<void> _fetchNCAABStandings(Map<String, dynamic> gameData) async {
  try {
    print('🏀 Fetching NCAAB standings...');

    // NCAAB standings are typically in the summary response
    // But can also fetch from dedicated endpoint if needed
    final standingsData = gameData['standings'];

    if (standingsData != null && standingsData['groups'] != null) {
      setState(() {
        if (_eventDetails != null) {
          _eventDetails!['standings'] = standingsData;
        }
      });
      print('✅ NCAAB standings loaded');
    }
  } catch (e) {
    print('❌ Error loading NCAAB standings: $e');
  }
}
```

### Tab Configuration

**Recommended: 5 tabs (same as NBA)**

1. **Overview**
   - Game summary
   - Team leaders (points, rebounds, assists)
   - Key plays

2. **Box Score**
   - Quarter/half scoring
   - Team statistics

3. **Stats**
   - Player statistics
   - Team comparison

4. **Standings**
   - Conference standings
   - Recent form (Last 5 games)

5. **News**
   - Game-related news articles

### Data Reuse from NBA

**Can reuse 95% of NBA UI components:**
- ✅ Box score widget
- ✅ Team leaders display
- ✅ Player stats table
- ✅ Standings display
- ✅ Last 5 games widget

**Only change needed:** Endpoint URL from `nba` → `mens-college-basketball`

---

## Key Observations

### NCAAF vs NFL
- ✅ **Nearly identical API structure**
- ✅ Same data fields (boxscore, leaders, drives, scoringPlays)
- ✅ Additional college-specific features (pickcenter, againstTheSpread)
- 🔧 Only need to change endpoint URL

### NCAAB vs NBA
- ✅ **Nearly identical API structure**
- ✅ Same data fields (boxscore, leaders, standings)
- ✅ Has lastFiveGames (like NBA)
- ✅ Additional college-specific features (pickcenter, againstTheSpread)
- 🔧 Only need to change endpoint URL

### Implementation Effort
- **NCAAF:** ~2-3 hours (copy NFL implementation, change endpoint)
- **NCAAB:** ~2-3 hours (copy NBA implementation, change endpoint)

### ESPN ID Resolution
Both sports will need ESPN ID resolution (same as NFL/NBA/MLB):
- Use `EspnIdResolverService` to map Odds API IDs to ESPN IDs
- Fallback to team name matching if needed

---

## Testing Checklist

### NCAAF
- [ ] Load game with ESPN ID already present
- [ ] Load game requiring ESPN ID resolution
- [ ] Display boxscore data
- [ ] Display team leaders (passing, rushing, receiving)
- [ ] Display scoring plays
- [ ] Display drive chart
- [ ] Display conference standings
- [ ] Handle pregame state
- [ ] Handle live game state
- [ ] Handle final game state

### NCAAB
- [ ] Load game with ESPN ID already present
- [ ] Load game requiring ESPN ID resolution
- [ ] Display boxscore data
- [ ] Display team leaders (points, rebounds, assists)
- [ ] Display player statistics
- [ ] Display conference standings
- [ ] Display last 5 games
- [ ] Handle pregame state
- [ ] Handle live game state
- [ ] Handle final game state

---

## Sample ESPN IDs for Testing

### NCAAF
```
401756913 - Texas Tech @ Houston (Oct 4, 2025)
401752859 - Minnesota @ Ohio State (Oct 4, 2025)
401754553 - Miami @ Florida State (Oct 4, 2025)
```

### NCAAB
```
401829496 - Old Dominion @ Miami (OH) (Nov 3, 2025)
401829451 - Evangel @ Kansas City (Nov 3, 2025)
401829426 - Northwestern State @ Texas A&M (Nov 3, 2025)
```

---

## Additional Resources

### Standings Endpoints (if needed separately)

```
NCAAF: https://site.api.espn.com/apis/v2/sports/football/college-football/standings
NCAAB: https://site.api.espn.com/apis/v2/sports/basketball/mens-college-basketball/standings
```

### Conference-Specific Standings

NCAAF conferences are organized differently than NFL divisions. May need special handling for:
- SEC, Big Ten, ACC, Big 12, Pac-12
- Independent schools
- Group of 5 conferences

NCAAB conferences:
- Many more conferences than NBA (30+ conferences)
- May want to filter to show only relevant conference
