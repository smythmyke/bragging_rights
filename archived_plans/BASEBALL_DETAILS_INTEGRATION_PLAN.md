# Baseball Game Details Integration Plan

## Overview
This document outlines the plan to integrate ESPN MLB API data into the game details screen for baseball games. The integration will provide comprehensive team and game information to help users make informed decisions.

**Note:** This implementation will NOT include play-by-play data or odds/betting lines data.

---

## Current State

### Problem
- Game details page shows "coming soon" placeholder text in all tabs
- No API calls are being made (`_loadEventDetails()` has TODOs)
- Generic implementation doesn't leverage baseball-specific data
- Users see no useful information when clicking on a baseball game

### File Location
`bragging_rights_app/lib/screens/game/game_details_screen.dart`

---

## Available ESPN API Data

### 1. ESPN MLB Scoreboard API
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard`

**Available Data:**
- Game status and score
- Teams and logos
- Starting pitchers (probables)
  - Name and ID
  - Basic stats
- Team records (W-L)
- Venue information
- Weather conditions
  - Temperature
  - Wind speed and direction
- Game time and broadcast info

### 2. ESPN MLB Summary API
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event={gameId}`

**Available Data:**
- Complete box score
  - Batting statistics (H, R, RBI, BB, K, AVG, etc.)
  - Pitching statistics (IP, H, R, ER, BB, K, ERA, etc.)
  - Fielding statistics (Errors, etc.)
- Line score (inning-by-inning runs)
- Current game situation
  - Current inning
  - Outs
  - Runners on base
  - Ball-strike count
- Team statistics

### 3. ESPN MLB News API
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/news`

**Note:** News and injury data will be reserved for the Edge (premium) feature, not included in basic game details.

---

## Proposed Tab Structure

### Current Generic Tabs (5 tabs)
1. Overview
2. Odds → *Will be removed*
3. Stats
4. News
5. Pools

### New Baseball-Specific Tabs (3 tabs)
1. **Matchup** - Pitching matchup, weather, team form
2. **Box Score** - Live scoring, batting/pitching stats
3. **Stats** - Season stats, head-to-head records

---

## UI Layout Strategy: Hybrid Approach

The baseball details page will use a **hybrid layout approach** that adapts the display based on content type and screen size:

### Layout Per Tab:
1. **Matchup Tab**: Split view (side-by-side comparison)
2. **Box Score Tab**: Full width (unified display)
3. **Stats Tab**: Toggle view (team selector)

### Mobile Responsiveness:
- **Tablets (>600px)**: Use split view where applicable
- **Phones (<600px)**: Use toggle/stacked views for better readability

---

## Tab Content Design

### 🎯 Tab 1: Matchup (Split View)
Primary focus on factors that affect game outcome. Uses side-by-side comparison layout.

#### Starting Pitchers Card (Split View)
```
┌─────────────────────────────────────┐
│      STARTING PITCHERS              │
├─────────────────┬───────────────────┤
│  Spencer Strider │   Josiah Gray     │
│      (ATL)       │      (WSH)        │
├─────────────────┼───────────────────┤
│  Season: 18-5    │   Season: 7-11    │
│  ERA: 3.86       │   ERA: 4.23       │
│  WHIP: 1.09      │   WHIP: 1.31      │
│  K/9: 11.8       │   K/9: 8.7        │
│  Last Start:     │   Last Start:     │
│  7 IP, 2 ER, W   │   5 IP, 4 ER, L   │
└─────────────────┴───────────────────┘
```

#### Weather Impact Card
```
┌─────────────────────────────────────┐
│      WEATHER CONDITIONS             │
├─────────────────────────────────────┤
│  🌡️ Temperature: 78°F               │
│  💨 Wind: 12 mph OUT                 │
│  ☁️ Conditions: Partly Cloudy        │
│                                     │
│  Impact Analysis:                   │
│  • Wind out favors hitters          │
│  • Warm weather increases scoring   │
│  • Expect higher run totals         │
└─────────────────────────────────────┘
```

#### Team Form Card
```
┌─────────────────────────────────────┐
│      TEAM FORM                      │
├─────────────────────────────────────┤
│         Braves    |    Nationals    │
│  Record: 85-60    |    72-73        │
│  Home: 44-28      |    38-35        │
│  Away: 41-32      |    34-38        │
│  Last 10: 7-3     |    4-6          │
│  Streak: W3       |    L2           │
│  vs RHP: .268     |    .251         │
│  vs LHP: .259     |    .244         │
└─────────────────────────────────────┘
```

### ⚾ Tab 2: Box Score (Full Width)
Real-time game statistics and scoring. Uses full width for better table readability.

#### Line Score (for live/completed games)
```
┌─────────────────────────────────────┐
│          LINE SCORE                 │
├─────────────────────────────────────┤
│     1 2 3 4 5 6 7 8 9  R  H  E     │
│ ATL 0 2 0 1 0 0 1 0 0  4  9  1     │
│ WSH 1 0 0 0 2 0 0 0 0  3  7  0     │
└─────────────────────────────────────┘
```

#### Batting Statistics
```
┌─────────────────────────────────────┐
│      BATTING STATISTICS             │
├─────────────────────────────────────┤
│ Atlanta Braves                      │
│ Player         AB R H RBI BB K AVG │
│ R. Acuña Jr.   4  1 2  1  0  1 .298│
│ F. Freeman     4  1 1  2  0  0 .325│
│ M. Ozuna       3  0 1  0  1  1 .241│
│ ...                                 │
│                                     │
│ Washington Nationals                │
│ Player         AB R H RBI BB K AVG │
│ CJ Abrams      4  1 1  0  0  2 .246│
│ J. Meneses     4  0 2  1  0  0 .275│
│ ...                                 │
└─────────────────────────────────────┘
```

#### Pitching Statistics
```
┌─────────────────────────────────────┐
│      PITCHING STATISTICS            │
├─────────────────────────────────────┤
│ Pitcher        IP  H  R ER BB K ERA│
│ S. Strider    7.0  5  3  3  2  9 3.86│
│ A. Minter     1.0  1  0  0  0  2 2.06│
│ K. Jansen     1.0  1  0  0  1  1 2.41│
│                                     │
│ J. Gray       5.2  7  3  3  3  6 4.23│
│ M. Barnes     1.1  1  1  1  0  2 4.50│
│ K. Finnegan   2.0  1  0  0  0  2 2.89│
└─────────────────────────────────────┘
```

### 📊 Tab 3: Stats (Toggle View)
Season and historical performance data. Uses team selector toggle for detailed views.

#### Season Comparison
```
┌─────────────────────────────────────┐
│      SEASON STATISTICS              │
├─────────────────────────────────────┤
│              Braves  |  Nationals   │
│ BATTING                             │
│ Team AVG:    .269    |    .251      │
│ Runs/Game:   5.2     |    4.3       │
│ HR:          243     |    178       │
│ OBP:         .337    |    .312      │
│ SLG:         .459    |    .403      │
│                                     │
│ PITCHING                            │
│ Team ERA:    3.89    |    4.67      │
│ WHIP:        1.23    |    1.41      │
│ K/9:         9.2     |    8.1       │
│ BB/9:        3.1     |    3.8       │
│ QS:          89      |    62        │
└─────────────────────────────────────┘
```

#### Head-to-Head Record
```
┌─────────────────────────────────────┐
│      HEAD-TO-HEAD                   │
├─────────────────────────────────────┤
│ 2024 Season Series: ATL 7-5         │
│                                     │
│ Recent Meetings:                    │
│ 09/10: ATL 7, WSH 3 (at WSH)       │
│ 09/09: WSH 5, ATL 4 (at WSH)       │
│ 08/15: ATL 8, WSH 5 (at ATL)       │
│ 08/14: ATL 4, WSH 2 (at ATL)       │
│ 08/13: WSH 6, ATL 5 (at ATL)       │
│                                     │
│ At Nationals Park: ATL 3-2          │
│ Run Differential: ATL +12           │
└─────────────────────────────────────┘
```


---

## Implementation Steps

### Phase 1: API Integration
1. **Update `_loadEventDetails()` method**
   ```dart
   Future<void> _loadEventDetails() async {
     setState(() => _isLoading = true);

     try {
       // Fetch game summary
       final summaryResponse = await http.get(
         Uri.parse('https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=${widget.gameId}')
       );

       // Fetch scoreboard for additional data
       final scoreboardResponse = await http.get(
         Uri.parse('https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard')
       );

       // Parse and store data
       if (summaryResponse.statusCode == 200) {
         final summaryData = json.decode(summaryResponse.body);
         _parseGameSummary(summaryData);
       }

     } catch (e) {
       print('Error loading game details: $e');
     } finally {
       setState(() => _isLoading = false);
     }
   }
   ```

2. **Create data parsing methods**
   - `_parseGameSummary()`
   - `_parseBoxScore()`
   - `_parsePitchers()`
   - `_parseWeather()`
   - `_parseTeamStats()`

### Phase 2: UI Components
1. **Create baseball-specific widgets**
   - `PitchingMatchupCard`
   - `WeatherImpactCard`
   - `LineScoreWidget`
   - `BoxScoreTable`
   - `TeamStatsComparison`

2. **Update tab structure**
   - Remove Odds and News tabs
   - Rename Overview to Matchup
   - Add Box Score tab
   - Update content builders

### Phase 3: Sport-Specific Rendering
```dart
@override
Widget build(BuildContext context) {
  // Check if baseball game
  final isBaseball = widget.sport.toUpperCase() == 'MLB';

  return DefaultTabController(
    length: isBaseball ? 3 : 5,
    child: Scaffold(
      // ...
      TabBar(
        tabs: isBaseball
          ? [
              Tab(text: 'Matchup'),
              Tab(text: 'Box Score'),
              Tab(text: 'Stats'),
            ]
          : [
              // Keep existing tabs for other sports
            ],
      ),
    ),
  );
}
```

---

## Data Models Needed

### PitcherData
```dart
class PitcherData {
  final String name;
  final String teamAbbr;
  final int wins;
  final int losses;
  final double era;
  final double whip;
  final double kPer9;
  final String lastStartSummary;
}
```

### BoxScore
```dart
class BoxScore {
  final List<InningScore> innings;
  final int runsHome;
  final int runsAway;
  final int hitsHome;
  final int hitsAway;
  final int errorsHome;
  final int errorsAway;
  final List<BattingStats> homeBatters;
  final List<BattingStats> awayBatters;
  final List<PitchingStats> homePitchers;
  final List<PitchingStats> awayPitchers;
}
```

### WeatherData
```dart
class WeatherData {
  final int temperature;
  final String conditions;
  final int windSpeed;
  final String windDirection;
  final String impact;
}
```

---

## Success Metrics

1. **Data Display**
   - All tabs show real data (no "coming soon" text)
   - Data updates when game goes live
   - Proper error handling for API failures

2. **User Experience**
   - Load time under 2 seconds
   - Smooth tab transitions
   - Clear data visualization
   - Mobile-responsive layouts

3. **Information Value**
   - Users can see pitching matchup
   - Weather impact is clearly explained
   - Team form and trends visible
   - Current game state displayed (if live)

---

## Timeline

- **Day 1-2:** API integration and data parsing
- **Day 3-4:** Create UI components
- **Day 5:** Testing and refinement
- **Day 6:** Error handling and edge cases
- **Day 7:** Final testing and deployment

---

## Notes

- Focus on baseball-specific insights that affect game outcomes
- Prioritize pitching matchup as most important factor
- Weather data should include impact analysis
- Box score updates in real-time for live games
- Cache data appropriately to reduce API calls
- **News and injury information reserved for Edge (premium) feature**

---

*Last Updated: Current Session*
*Target Completion: 1 week*