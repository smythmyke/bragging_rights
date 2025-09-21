# NHL Details Page Implementation Plan

## Overview
Implementation plan for adding comprehensive NHL game details to the Bragging Rights app, utilizing ESPN and Odds API data.

## Available Data Sources

### 1. ESPN API Endpoints

#### Scoreboard Endpoint
**URL:** `https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard`
**Data Retrieved:**
- Game ID, name, and status
- Home/Away teams with logos
- Current score
- Period and time remaining
- Venue information
- Basic team statistics

#### Game Summary Endpoint
**URL:** `https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/summary?event={gameId}`
**Data Retrieved:**
- **Box Score:**
  - Team statistics (shots on goal, power plays, penalty minutes, faceoff %, etc.)
  - Player statistics by category (forwards, defense, goalies)
  - Goalie stats (saves, save %, goals against)
- **Scoring Plays:**
  - Goal-by-goal breakdown
  - Time of each goal
  - Scorer and assists
  - Period information
- **Standings:**
  - Current division/conference standings
  - Points, wins, losses, OT losses
  - Playoff positioning
- **Game Info:**
  - Venue details
  - Attendance
  - Officials (referees, linesmen)
- **Leaders:**
  - Top performers for each team
  - Key statistics leaders

#### Teams Endpoint
**URL:** `https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/teams`
**Data Retrieved:**
- All 32 NHL teams
- Team logos (multiple sizes)
- Team colors
- Abbreviations

### 2. Odds API Endpoints

#### Odds Endpoint
**URL:** `https://api.the-odds-api.com/v4/sports/icehockey_nhl/odds?apiKey={key}&regions=us&markets=h2h,totals,spreads`
**Sport Key:** `icehockey_nhl`
**Data Retrieved:**
- **Moneyline (h2h):** Straight win/loss odds
- **Puck Line (spreads):** Typically ±1.5 goals
- **Totals:** Over/Under goals (usually 5.5-6.5)
- Multiple bookmakers (DraftKings, FanDuel, etc.)
- Live odds updates during games

**Note:** Player props (goals, assists, points) are NOT available for NHL through this API.

## Tab Structure

### Tab 1: Overview
**Components:**
- Live score display with period/time
- Team logos and records
- Current odds (moneyline, puck line, O/U)
- Game leaders (top 3 players each team)
- Shot counter
- Power play opportunities
- Key game situations (power play, penalty kill, empty net)

### Tab 2: Box Score
**Components:**
- **Team Stats Section:**
  - Shots on Goal
  - Power Play (made/attempts)
  - Penalty Minutes
  - Faceoff Win %
  - Hits
  - Blocked Shots
  - Giveaways/Takeaways
- **Player Stats Section:**
  - Forwards: Goals, Assists, Points, +/-, PIM, SOG, TOI
  - Defense: Goals, Assists, Points, +/-, PIM, SOG, TOI, Blocks
  - Goalies: Saves, Shots Against, Save %, Goals Against, TOI

### Tab 3: Scoring
**Components:**
- Period-by-period scoring summary
- Detailed goal list:
  - Time of goal
  - Scorer name and season total
  - Assist(s) and season totals
  - Strength (Even, PP, SH, EN)
  - Video highlight link (if available)
- Penalty summary
- Three stars of the game

### Tab 4: Standings
**Components:**
- Division standings (team's division)
- Conference standings
- Wild card race (if applicable)
- Key metrics:
  - Points
  - Games Played
  - Wins-Losses-OT Losses
  - Goal Differential
  - Home/Away records
  - Last 10 games
  - Streak

## Implementation Steps

### 1. Add NHL Support to Game Details Screen
```dart
// In initState() - Add NHL to tab count
final tabCount = widget.sport.toUpperCase() == 'NHL' ? 4 : ...

// In _loadEventDetails() - Add NHL case
else if (widget.sport.toUpperCase() == 'NHL') {
  await _loadNHLDetails();
}
```

### 2. Create _loadNHLDetails() Method
```dart
Future<void> _loadNHLDetails() async {
  // 1. Resolve ESPN game ID
  final espnGameId = await _resolveNHLGameId();

  // 2. Fetch game summary from ESPN
  final summaryUrl = 'https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/summary?event=$espnGameId';

  // 3. Fetch odds data
  await _loadNHLOdds();

  // 4. Parse and store data
  _parseNHLData(summaryData);
}
```

### 3. Add Tab Labels
```dart
tabs: widget.sport.toUpperCase() == 'NHL'
  ? [
      const Tab(text: 'Overview'),
      const Tab(text: 'Box Score'),
      const Tab(text: 'Scoring'),
      const Tab(text: 'Standings'),
    ]
```

### 4. Create Tab View Methods
```dart
// Tab builders
Widget _buildNHLOverviewTab() { }
Widget _buildNHLBoxScoreTab() { }
Widget _buildNHLScoringTab() { }
Widget _buildNHLStandingsTab() { }
```

### 5. Add to TabBarView
```dart
children: widget.sport.toUpperCase() == 'NHL'
  ? [
      _buildNHLOverviewTab(),
      _buildNHLBoxScoreTab(),
      _buildNHLScoringTab(),
      _buildNHLStandingsTab(),
    ]
```

## Data Models Needed

### NHL-Specific Properties
```dart
Map<String, dynamic>? _nhlBoxScore;
List<dynamic>? _nhlScoringPlays;
Map<String, dynamic>? _nhlStandings;
Map<String, dynamic>? _nhlGameLeaders;
```

## UI Components to Create

1. **Period Display Widget** - Show current period (1st, 2nd, 3rd, OT, SO)
2. **Shot Counter Widget** - Visual shot comparison
3. **Power Play Indicator** - Show when team is on PP/PK
4. **Goal Scorer Card** - Display goal with assists
5. **Goalie Stats Card** - Special display for goalie performance
6. **Three Stars Display** - Post-game honors

## Error Handling

- Handle games not yet started (no box score)
- Handle completed games (final stats)
- Handle overtime/shootout scenarios
- Handle postponed/cancelled games
- Handle ESPN ID resolution failures

## Testing Considerations

- Test with live games
- Test with completed games
- Test with future games
- Test overtime/shootout games
- Test playoff games (different format)

## Notes

- NHL games have 3 periods (not quarters)
- Overtime is 3v3 sudden death in regular season
- Shootout after OT in regular season
- Playoff overtime is full strength, continuous
- Empty net situations important for betting
- Power play/penalty kill affects odds

## Clean Up
- Delete test files after implementation:
  - test_nhl_api.dart
  - test_nhl_odds.dart