# Soccer API Data Guide - Bragging Rights App
## ESPN & The Odds API Data Availability

---

## 📊 ESPN Soccer API
**Base URL:** `https://site.api.espn.com/apis/site/v2/sports/soccer/{league}/`

### Supported Leagues
- `eng.1` - English Premier League
- `esp.1` - La Liga (Spain)
- `ger.1` - Bundesliga (Germany)
- `ita.1` - Serie A (Italy)
- `fra.1` - Ligue 1 (France)
- `usa.1` - MLS (USA)
- `uefa.champions` - Champions League
- `uefa.europa` - Europa League

### Available Endpoints

#### 1. Scoreboard
**Endpoint:** `/scoreboard`
**Returns:** Current/upcoming games for the league

#### 2. Game Summary
**Endpoint:** `/summary?event={gameId}`
**Returns:** Detailed game information

---

## ✅ Data Available from ESPN

### For Edge Cards

| Data Type | Available | Details | Use Case |
|-----------|-----------|---------|----------|
| **News Articles** | ✅ Yes | 6+ articles with headlines, descriptions | Transfer rumors, team news, injury updates |
| **Team Form** | ✅ Yes | Last 5 matches (W/D/L) for each team | Recent performance analysis |
| **League Standings** | ✅ Yes | Full table with position, points, GD, W/D/L | Team's current league position |
| **Team Statistics** | ✅ Yes | Goals, assists, goals against, goal difference | Season performance metrics |
| **Head-to-Head** | ✅ Yes | Recent meetings between teams | Historical matchup data |
| **Game Info** | ✅ Yes | Venue, weather (if available), kickoff time | Match conditions |
| **Broadcasts** | ✅ Yes | TV/streaming information | Where to watch |
| **Videos** | ✅ Yes | Highlights and preview clips | Visual content |
| **Injuries** | ❌ No | Not provided in API | Would need alternative source |
| **Lineups** | ❌ No | Roster array is empty | Not available pre-match |
| **Player Stats** | ❌ No | No individual player data | Team stats only |
| **Referee Info** | ❌ No | Not included | Not available |

### ESPN Data Structure Examples

#### News Articles
```json
{
  "headline": "Transfer rumors: Man United's Mainoo eyed by Newcastle",
  "description": "Latest transfer news and rumors...",
  "published": "2025-09-17T09:00:00Z"
}
```

#### Team Form
```json
{
  "form": [
    {"result": "W", "gameDate": "2025-09-14"},
    {"result": "D", "gameDate": "2025-09-07"},
    {"result": "W", "gameDate": "2025-08-31"},
    {"result": "W", "gameDate": "2025-08-24"},
    {"result": "L", "gameDate": "2025-08-17"}
  ]
}
```

#### Team Statistics
```json
{
  "statistics": [
    {"label": "Goal Difference", "displayValue": "+15"},
    {"label": "Total Goals", "displayValue": "28"},
    {"label": "Assists", "displayValue": "22"},
    {"label": "Goals Against", "displayValue": "13"}
  ]
}
```

---

## 💰 The Odds API
**Base URL:** `https://api.the-odds-api.com/v4/sports/`

### Supported Soccer Leagues
- `soccer_epl` - English Premier League
- `soccer_spain_la_liga` - La Liga
- `soccer_germany_bundesliga` - Bundesliga
- `soccer_italy_serie_a` - Serie A
- `soccer_france_ligue_one` - Ligue 1
- `soccer_uefa_champs_league` - Champions League
- `soccer_uefa_europa_league` - Europa League
- `soccer_usa_mls` - MLS

### Available Markets

| Market Type | Available | Details | Edge Card Use |
|-------------|-----------|---------|---------------|
| **H2H (3-way)** | ✅ Yes | Home Win, Draw, Away Win | Primary betting odds |
| **Draw No Bet** | ⚠️ Limited | Removes draw option | Alternative betting |
| **Double Chance** | ⚠️ Limited | Home/Draw, Away/Draw, Home/Away | Safer betting options |
| **Spreads** | ❌ No | Not standard for soccer | N/A |
| **Totals (O/U)** | ⚠️ Limited | Goals over/under | May be available for some games |
| **Player Props** | ❌ No | No individual player bets | Not supported |
| **Correct Score** | ❌ No | Exact score predictions | Not in standard API |

### Odds Data Structure Example
```json
{
  "id": "c5a9413ae7de9a4b1319ef0313c46a29",
  "sport_key": "soccer_epl",
  "commence_time": "2025-09-20T11:30:00Z",
  "home_team": "Liverpool",
  "away_team": "Everton",
  "bookmakers": [
    {
      "key": "fanduel",
      "title": "FanDuel",
      "markets": [
        {
          "key": "h2h",
          "outcomes": [
            {"name": "Liverpool", "price": 1.38},
            {"name": "Draw", "price": 4.7},
            {"name": "Everton", "price": 7.0}
          ]
        }
      ]
    }
  ]
}
```

---

## 🎯 Edge Card Implementation (2 Cards Only)

### 1. **News & Insights Card** (Premium Edge Content)
- **Data Source:** ESPN API - News articles
- **Display:** Latest 3-5 headlines with summaries
- **Value:** Exclusive transfer news, injuries, team updates
- **Content:**
  - Transfer rumors and confirmed moves
  - Injury updates from news parsing
  - Manager quotes and team news
  - Tactical insights

### 2. **Betting Odds Card** (Premium Edge Content)
- **Data Source:** The Odds API - H2H markets
- **Display:** Comprehensive odds from all available bookmakers
- **Value:** Best odds comparison and value identification
- **Content:**
  - All bookmaker odds with timestamps
  - Best value highlights
  - Odds movement tracking
  - Draw No Bet / Double Chance (if available)

---

## 📱 Details Page Implementation (4 Tabs)

### 1. Overview Tab
- **Match Information:**
  - Match time and venue (ESPN)
  - Team badges and colors (ESPN)
  - Weather conditions if available (ESPN)
  - Competition/league context
- **Basic Odds Display:**
  - Simple H2H odds from top bookmaker (Odds API)
  - Favorite/underdog indication
  - *Note: Detailed odds exclusive to Edge Card*

### 2. Stats Tab
- **Team Form:**
  - Last 5 matches with W/D/L indicators (ESPN)
  - Recent scores and opponents
- **Season Statistics (ESPN):**
  - Goals scored/conceded
  - Goal difference
  - Assists
  - Clean sheets (if available)
- **Key Performance Metrics:**
  - Home vs Away form
  - Goals per game average
  - Defense record

### 3. Standings Tab
- **Full League Table (ESPN):**
  - Current position
  - Points, Games Played
  - Wins, Draws, Losses
  - Goal Difference
  - Recent form (last 5)
- **Context:**
  - Gap to top 4 (Champions League)
  - Gap to relegation zone
  - Games in hand

### 4. H2H Tab
- **Historical Meetings (ESPN):**
  - Last 5-10 meetings
  - Scores and dates
  - Venue for each match
  - Competition (league/cup)
- **Statistical Summary:**
  - Overall H2H record
  - Goals scored in fixture
  - Biggest wins
  - Recent trends

### ❌ Removed Tabs:
- **News Tab** - Exclusive to Edge Card for premium insights
- **Odds Tab** - Detailed odds exclusive to Edge Card

---

## 🚫 Data Limitations

### Not Available from Either API:
1. **Live lineups** - Not provided until match starts
2. **Individual player statistics** - No player-level data
3. **Detailed injury reports** - Only mentioned in news articles
4. **Referee assignments** - Not included
5. **Expected goals (xG)** - Advanced metrics not available
6. **Player props betting** - Not supported by Odds API
7. **Asian handicaps** - Limited availability
8. **Formation/tactics** - Not provided

### Workarounds:
- Parse news articles for injury mentions
- Use team statistics as proxy for player performance
- Focus on team-level metrics and betting
- Consider adding a third API for player data in future

---

## 🔄 Update Frequency

### ESPN API
- **Scoreboard:** Real-time during matches
- **News:** Updated multiple times daily
- **Statistics:** Updated after each match
- **Standings:** Real-time updates

### The Odds API
- **Odds updates:** Every few minutes
- **New markets:** Added as bookmakers post them
- **Rate limits:** Check API key limits (typically 500-1000/month for free tier)

---

## 💡 Best Practices

1. **Cache data aggressively** - Especially standings and team stats
2. **Batch API calls** - Request multiple games at once
3. **Handle missing data gracefully** - Not all fields always populated
4. **Update odds frequently** - Every 5-10 minutes for live games
5. **Parse news for insights** - Extract injury info from article text
6. **Combine data sources** - Use both APIs to create comprehensive view

---

## 📝 Sample API Calls

### ESPN - Get Premier League Games
```bash
curl "https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/scoreboard"
```

### ESPN - Get Game Details
```bash
curl "https://site.api.espn.com/apis/site/v2/sports/soccer/eng.1/summary?event={gameId}"
```

### Odds API - Get EPL Odds
```bash
curl "https://api.the-odds-api.com/v4/sports/soccer_epl/odds/?apiKey={API_KEY}&regions=us&markets=h2h"
```

---

*Last Updated: September 17, 2025*
*Created for: Bragging Rights App - Soccer Module*