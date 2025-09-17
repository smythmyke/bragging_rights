# NBA API Data Guide

## ESPN API Endpoints

### Main Endpoints
- **Scoreboard**: `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard`
- **Game Summary**: `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event={gameId}`

## Available Data from ESPN API

### 1. Boxscore
- Team statistics
- Player statistics (when game is live/completed)
- Team records
- Quarter/period scores

### 2. Game Leaders
- Points leaders (top 3 players per team)
- Rebounds leaders
- Assists leaders
- Individual player performance stats

### 3. Standings
- Conference standings (Eastern/Western)
- Division standings
- Win/Loss records
- Games behind leader
- Conference records
- Home/Away records
- Last 10 games
- Streak

### 4. Last Five Games
- Recent game results for both teams
- Scores and opponents
- Win/Loss outcomes

### 5. Season Series
- Head-to-head record between teams
- Previous matchup results
- Historical performance

### 6. Injuries
- Injured players list
- Injury status
- Expected return dates

### 7. Win Probability
- Live win probability chart data
- Momentum shifts during game

### 8. Game Info
- Venue information
- Attendance
- Officials/Referees
- Game notes

### 9. Against The Spread (ATS)
- Team ATS records
- Betting trends

### 10. News & Videos
- Team-related news articles
- Game highlights
- Press conference videos

---

## Data Organization for Bragging Rights

### 🎯 EDGE CARDS (Premium Features - $$$)

#### 1. **Advanced Analytics Card**
- **Win Probability Graph**: Real-time win probability throughout the game
- **Momentum Tracker**: Key momentum shifts and turning points
- **Clutch Performance**: Player performance in final 5 minutes
- **Plus/Minus Analysis**: Impact of each player on court
- **Advanced Team Stats**: Offensive/Defensive efficiency ratings

#### 2. **Betting Insights Card**
- **ATS Records**: Against the spread performance
- **Over/Under Trends**: Total points scoring patterns
- **Quarter/Half Betting**: Period-specific betting analysis
- **Live Betting Opportunities**: In-game betting suggestions
- **Historical Betting Performance**: Past betting outcomes

#### 3. **Matchup Intelligence Card**
- **Key Matchup Analysis**: Position-by-position breakdown
- **Pace Analysis**: Expected game tempo
- **Three-Point Trends**: Three-point shooting matchup
- **Defensive Matchup**: Defensive strengths vs offensive threats
- **Coaching Strategy**: Historical coaching decisions

---

### 📊 DETAILS PAGE TABS (Free Features)

#### Tab 1: **Overview**
- **Live Score & Quarter Info**
- **Team Records**: Overall, Home/Away, Conference
- **Game Leaders**: Top performers in Points, Rebounds, Assists
- **Quarter Scores**: Period-by-period scoring
- **Next Game Info**: Upcoming matchups for both teams

#### Tab 2: **Stats**
- **Team Stats Comparison**:
  - Field Goal %
  - Three-Point %
  - Free Throw %
  - Rebounds (Offensive/Defensive)
  - Assists
  - Turnovers
  - Steals
  - Blocks
  - Points in Paint
  - Fast Break Points
  - Bench Points
- **Player Stats** (when available):
  - Minutes Played
  - Points/Rebounds/Assists
  - Field Goals Made/Attempted
  - Plus/Minus

#### Tab 3: **Standings**
- **Conference Standings**:
  - Eastern/Western Conference position
  - Division standings
  - Games Behind leader
  - Win/Loss record
  - Home/Away records
  - Conference record
  - Last 10 games
  - Current streak
- **Playoff Picture**: Playoff seeding implications

#### Tab 4: **H2H** (Head to Head)
- **Season Series**: Current season matchups
- **Last 5 Meetings**: Recent game results
- **Historical Record**: All-time head-to-head
- **Average Scores**: Average points in matchups
- **Home/Away Performance**: Performance at each venue

#### Tab 5: **Injuries**
- **Current Injuries**:
  - Player name and position
  - Injury description
  - Status (Out, Day-to-Day, Questionable, Probable)
  - Expected return
- **Impact Analysis**: How injuries affect team performance
- **Recent Updates**: Latest injury reports

---

## Implementation Priority

### Phase 1 - Core Features (Details Page)
1. **Overview Tab**: Score, leaders, quarter scores
2. **Stats Tab**: Team comparison, basic stats
3. **Standings Tab**: Conference/Division standings
4. **H2H Tab**: Recent matchups and season series

### Phase 2 - Enhanced Features
1. **Injuries Tab**: Full injury report with impacts
2. **Advanced Stats**: More detailed statistical breakdowns
3. **Live Updates**: Real-time score and stat updates

### Phase 3 - Premium Features (Edge Cards)
1. **Advanced Analytics**: Win probability, momentum
2. **Betting Insights**: ATS records, trends
3. **Matchup Intelligence**: Deep analysis

---

## API Response Examples

### Team Stats Structure
```json
{
  "statistics": [
    {
      "name": "fieldGoalPercentage",
      "displayValue": "45.5%"
    },
    {
      "name": "threePointPercentage",
      "displayValue": "38.2%"
    }
  ]
}
```

### Player Leader Structure
```json
{
  "displayName": "Points",
  "leaders": [
    {
      "athlete": {
        "displayName": "Joel Embiid"
      },
      "displayValue": "31"
    }
  ]
}
```

### Standings Structure
```json
{
  "groups": [
    {
      "standings": {
        "entries": [
          {
            "team": "Boston Celtics",
            "stats": [
              {"name": "wins", "displayValue": "45"},
              {"name": "losses", "displayValue": "12"},
              {"name": "gamesBehind", "displayValue": "-"}
            ]
          }
        ]
      }
    }
  ]
}
```

---

## Caching Strategy (Following Soccer Model)

### ESPN ID Resolution & Caching
Just like with soccer, we need to efficiently resolve and cache ESPN IDs for NBA games:

1. **First Check**: Look for ESPN ID in game data
2. **Memory Cache**: Check in-memory cache (instant)
3. **Firestore Cache**: Check `id_mappings` collection
4. **ESPN API Match**: If not cached, match with ESPN scoreboard
5. **Save Mapping**: Store in Firestore for future use

### Data Fetching Flow
```
1. Game Details Request
   ↓
2. Check if ESPN ID exists
   ↓
3. If yes → Fetch summary from ESPN (with caching)
   ↓
4. If no → Resolve ID using EspnIdResolverService
   ↓
5. Cache resolved ID in Firestore
   ↓
6. Fetch and cache game details
```

### Implementation Example
```dart
// Similar to soccer implementation
Future<void> _loadNBAGameDetails() async {
  // 1. Check for ESPN ID
  String? espnId = widget.gameData?.espnId;

  // 2. If no ESPN ID, resolve it
  if (espnId == null || espnId.isEmpty) {
    final resolver = EspnIdResolverService();
    espnId = await resolver.resolveEspnId(widget.gameData!);
  }

  // 3. Fetch summary data (will be cached)
  if (espnId != null) {
    final url = 'https://site.api.espn.com/apis/site/v2/sports/basketball/nba/summary?event=$espnId';
    // Fetch and cache data
  }
}
```

### Caching Rules
- **Live Games**: Update every 30 seconds (scores only)
- **Upcoming Today**: Refresh every 5 minutes
- **Future Games**: Cache for 6-24 hours based on proximity
- **Completed Games**: Cache for 7 days

### Firestore Structure
```
games/
  {gameId}/
    - espnId: "401812480"
    - lastFetched: Timestamp
    - lastScoreUpdate: Timestamp
    - sport: "NBA"
    - gameTime: Timestamp
    - detailsData: {
        standings: {...},
        leaders: {...},
        injuries: {...},
        lastFiveGames: {...}
      }

id_mappings/
  {oddsApiGameId}/
    - espnId: "401812480"
    - sport: "NBA"
    - teams: {...}
    - verified: true
```

### Efficient Data Loading
1. **Batch Loading**: Load all tab data in one API call
2. **Selective Updates**: Only update changed data (scores for live games)
3. **Background Refresh**: Update non-visible tabs in background
4. **Stale-While-Revalidate**: Show cached data immediately, update in background

---

## Notes

- NBA games provide rich statistical data perfect for analytics
- Player-specific data is crucial for NBA betting and fantasy
- Conference/Division standings are more important than in other sports
- Injury reports significantly impact NBA games due to smaller rosters
- Quarter/Half betting is popular in NBA
- Pace of play and three-point shooting are key modern NBA metrics

---

*Last Updated: December 2024*