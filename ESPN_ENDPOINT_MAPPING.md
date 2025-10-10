# ESPN Endpoint Mapping for Edge Intelligence Cards

## 📡 Available ESPN API Endpoints

### **NFL** - `EspnNflService`
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard`

**Available Data:**
- ✅ Teams, scores, game status
- ✅ **Weather data** (outdoor games only)
- ✅ **Injury reports** (in team data)
- ✅ **Basic odds** (moneyline, spread, total)
- ✅ Team statistics
- ✅ Venue information
- ✅ Broadcast information

**Edge Cards Supported:**
1. ✅ **Injury Intelligence** - Parse `team.injuries` data
2. ✅ **Weather Impact** - Parse `weather` data (wind, temp, precipitation)
3. ✅ **Matchup Analysis** - Team stats, offensive/defensive rankings
4. ⚠️ **Betting Movement** - Limited (only current lines, no movement tracking)

---

### **NBA** - `EspnNbaService`
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard`

**Available Data:**
- ✅ Teams, scores, game status
- ✅ **Season classification** (preseason, regular, playoffs)
- ✅ **Exhibition game detection** (International teams, Global Games)
- ✅ **Basic odds** (when available)
- ✅ Team statistics
- ✅ **Odds availability checking** (integration with Odds API)
- ❌ NO weather (indoor sport)

**Edge Cards Supported:**
1. ✅ **Injury Intelligence** - Parse injury data
2. ❌ **Weather Impact** - Not applicable (indoor)
3. ✅ **Matchup Analysis** - Team stats, rankings
4. ⚠️ **Betting Movement** - Limited odds data

**Special Features:**
- NBA game classification system (`_classifyNbaGame()`)
  - Detects preseason (type=1), regular season (type=2), playoffs (type=3)
  - Identifies exhibition games (non-NBA team IDs >30)
  - Labels: "PRESEASON", "PLAYOFFS", "PRESEASON EXHIBITION"
- Odds availability checking (`_checkNbaOddsAvailability()`)
  - Validates if betting lines exist
  - Returns `hasOdds` and `oddsApiSportKey`

---

### **NHL** - `EspnNhlService`
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard`

**Available Data:**
- ✅ Teams, scores, game status
- ✅ **Goalie information** (starting goalies)
- ✅ **Special teams stats** (power play %, penalty kill %)
- ✅ Team statistics
- ❌ NO weather (indoor sport)

**Edge Cards Supported:**
1. ✅ **Injury Intelligence** - Parse injury/lineup data
2. ❌ **Weather Impact** - Not applicable (indoor)
3. ✅ **Matchup Analysis** - Team stats, goalie matchups
4. ✅ **Goalie Matchup Card** - NEW card type (starting goalies, save %, GAA)
5. ✅ **Special Teams Card** - NEW card type (PP%, PK%)

---

### **MLB** - `EspnMlbService`
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard`

**Available Data:**
- ✅ Teams, scores, game status
- ✅ **Starting pitchers** (critical for betting)
- ✅ **Weather data** (CRITICAL for outdoor games)
  - Wind speed/direction (massive impact on fly balls)
  - Temperature, precipitation
- ✅ **Ballpark factors** (venue characteristics)
- ✅ Team statistics

**Edge Cards Supported:**
1. ✅ **Injury Intelligence** - Parse pitcher/lineup changes
2. ✅ **Weather Impact** - GOLD MINE (wind direction affects totals)
3. ✅ **Matchup Analysis** - Team stats, head-to-head
4. ✅ **Pitcher Matchup Card** - NEW card type (ERA, WHIP, K/9, splits vs L/R)
5. ✅ **Ballpark Factors Card** - NEW card type (Coors altitude, Wrigley wind patterns)

---

### **MMA** - ESPN MMA (UFC, Bellator, PFL)
**Endpoints:**
- UFC: `https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard?dates=YYYYMMDD-YYYYMMDD`
- PFL: `https://site.api.espn.com/apis/site/v2/sports/mma/pfl/scoreboard?dates=YYYYMMDD-YYYYMMDD`
- Bellator: `https://site.api.espn.com/apis/site/v2/sports/mma/bellator/scoreboard?dates=YYYYMMDD-YYYYMMDD`

**Available Data:**
- ✅ Event structure (main card, prelims, early prelims)
- ✅ **Fighter profiles** (names, athlete IDs)
- ✅ **Fighter records** (W-L-D)
- ✅ **Fighter headshots** (`https://a.espncdn.com/i/headshots/mma/players/full/{athleteId}.png`)
- ✅ **Weight classes**
- ✅ **Rounds** (3 or 5 rounds)
- ✅ Venue, date

**Edge Cards Supported:**
1. ✅ **Fighter Analysis Card** - NEW card type
   - Fighter records (15-3-0)
   - Weight class
   - Fighter images
   - Win methods (KO/TKO %, submission %, decision %)
2. ✅ **Weight Cut Alert Card** - NEW card type (if weigh-in data available)
3. ✅ **Matchup Analysis** - Style matchups, reach advantage

**Event Grouping:**
- ESPN provides event-level structure with all fights
- Main event automatically detected (last fight in array)
- Card positions: "main", "prelim", "early"
- Fight order assigned (main event = 1, co-main = 2, etc.)

---

### **Boxing** - ESPN Boxing
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard?dates=YYYYMMDD-YYYYMMDD`

**Available Data:**
- ✅ Event structure
- ✅ **Fighter profiles** (names, records)
- ✅ **Weight classes**
- ✅ **Rounds** (typically 10-12 for main events)
- ✅ Venue, date

**Edge Cards Supported:**
1. ✅ **Fighter Analysis Card** - NEW card type
   - Fighter records
   - KO percentage
   - Weight class
   - Southpaw vs Orthodox detection
2. ✅ **Matchup Analysis** - Style matchups, power puncher vs boxer

---

### **NCAAF (College Football)** - Falls back to Odds API
**Note:** No dedicated ESPN service in current codebase

**Available via Odds API:**
- ✅ Basic game data (teams, time)
- ✅ Odds data
- ❌ Limited stats compared to NFL

**Edge Cards Supported:**
1. ⚠️ **Injury Intelligence** - Limited (not as detailed as NFL)
2. ⚠️ **Weather Impact** - If game is outdoor (need venue data)
3. ⚠️ **Matchup Analysis** - Basic only

---

### **NCAAB (College Basketball)** - Falls back to Odds API
**Note:** No dedicated ESPN service in current codebase

**Available via Odds API:**
- ✅ Basic game data (teams, time)
- ✅ Odds data
- ❌ NO weather (indoor)

**Edge Cards Supported:**
1. ⚠️ **Injury Intelligence** - Limited
2. ❌ **Weather Impact** - Not applicable
3. ⚠️ **Matchup Analysis** - Basic only

---

### **Tennis** - Not implemented in ESPN services
**Status:** Would need new service or rely on Odds API

**Potential ESPN Endpoint:**
- `https://site.api.espn.com/apis/site/v2/sports/tennis/atp/scoreboard`

**Expected Data:**
- Player rankings
- Surface type (clay, hard, grass)
- Tournament information

**Edge Cards Potential:**
1. **Surface Analysis Card** - Player stats by surface
2. **Ranking Differential** - Upset potential

---

## 🔄 Data Flow Architecture

### Current Service Structure:
```
OptimizedGamesService (main orchestrator)
  ├── Odds API (primary source for game listings)
  │   ├── getSportGames() - Main game data
  │   └── getSportScores() - Live scores
  │
  ├── ESPN Services (fallback + enrichment)
  │   ├── EspnNflService - NFL data
  │   ├── EspnNbaService - NBA data
  │   ├── EspnNhlService - NHL data
  │   └── EspnMlbService - MLB data
  │
  └── Firestore Cache (2-hour cache)
      └── Reduces API calls
```

### Edge Intelligence Flow:
```
EdgeIntelligenceService
  ├── NewsAPI - Breaking news (ALL sports)
  ├── Reddit API - Social sentiment (ALL sports)
  ├── ESPN APIs - Sport-specific intelligence
  │   ├── NFL: weather, injuries, stats
  │   ├── NBA: injuries, stats, odds availability
  │   ├── NHL: goalies, special teams, stats
  │   ├── MLB: pitchers, weather (CRITICAL), ballpark
  │   ├── MMA: fighters, records, weight class
  │   └── Boxing: fighters, records, KO%
  │
  └── Odds API - Betting lines (QUOTA EXCEEDED)
      └── Fallback: Use ESPN odds (limited)
```

---

## 📊 Edge Card Data Mapping

### 1. **Breaking News Card** (NewsAPI)
```javascript
Source: NewsAPI
Endpoint: https://newsapi.org/v2/everything?q={sport}+{team}+injury
Data Used:
  - articles[].title
  - articles[].description
  - articles[].source.name
  - articles[].publishedAt
  - articles[].urlToImage
```

### 2. **Injury Intelligence Card** (ESPN)
```javascript
NFL: EspnNflService
  - competition.teams[].injuries[]
  - Injury status: Out/Doubtful/Questionable
  - Player position (prioritize QB, RB, WR)

NBA: EspnNbaService
  - competition.teams[].injuries[]

NHL: EspnNhlService
  - competition.teams[].injuries[]
  - Starting goalie status

MLB: EspnMlbService
  - competition.teams[].injuries[]
  - Starting pitcher status (CRITICAL)
```

### 3. **Weather Impact Card** (ESPN)
```javascript
NFL: EspnNflService
  - competition.weather.displayValue
  - competition.weather.temperature
  - competition.weather.conditions
  - competition.weather.windSpeed
  - competition.weather.windDirection

MLB: EspnMlbService
  - competition.weather.* (SAME as NFL)
  - ⚠️ Wind direction is CRITICAL for totals betting
  - Example: 15 mph wind blowing out = favor OVER
```

### 4. **Matchup Analysis Card** (ESPN)
```javascript
ALL ESPN Services:
  - competition.teams[].statistics[]
  - competition.teams[].records[]
  - Head-to-head history (if available)
  - Home/away splits
```

### 5. **Betting Movement Card** (ESPN/Odds API)
```javascript
Primary: Odds API (QUOTA EXCEEDED)
Fallback: ESPN odds
  - competition.odds[].details (spread, total, moneyline)
  - ⚠️ ESPN only shows CURRENT lines, no historical movement
```

### 6. **Social Sentiment Card** (Reddit API)
```javascript
Source: Reddit API
Subreddits: r/{team}, r/{sport}
Data Used:
  - Post count (trending discussions)
  - Comment sentiment (positive/negative)
  - Upvote ratio (community confidence)
```

---

## 🆕 New Sport-Specific Cards (ESPN-Powered)

### **MLB: Pitcher Matchup Card**
```javascript
Source: EspnMlbService
Data:
  - Starting pitcher names
  - Pitcher ERA, WHIP, K/9
  - Splits vs LHB/RHB
  - Recent form (last 3 starts)
  - Head-to-head vs opposing team
```

### **MLB: Ballpark Factors Card**
```javascript
Source: ESPN venue data
Data:
  - Venue name (Coors Field, Wrigley, etc.)
  - Elevation (Coors = 5,200 ft)
  - Dimensions (short porch, deep center)
  - Historical run factors
```

### **NHL: Goalie Matchup Card**
```javascript
Source: EspnNhlService
Data:
  - Starting goalie names
  - Save % (Sv%)
  - Goals Against Average (GAA)
  - Recent form (last 5 games)
  - Record vs opposing team
```

### **NHL: Special Teams Card**
```javascript
Source: EspnNhlService
Data:
  - Power Play % (PP%)
  - Penalty Kill % (PK%)
  - Team rankings
  - Head-to-head special teams battles
```

### **MMA/Boxing: Fighter Analysis Card**
```javascript
Source: ESPN MMA/Boxing
Data:
  - Fighter records (15-3-0)
  - Fighter headshots
  - Weight class
  - Win methods (KO/TKO %, Submission %, Decision %)
  - Reach advantage
  - Age, experience
```

### **MMA: Weight Cut Alert Card**
```javascript
Source: ESPN (if weigh-in data available)
Potential Data:
  - Official weigh-in weight
  - Weight class limit
  - Missed weight history
  - Same-day weigh-in issues
```

### **Tennis: Surface Analysis Card**
```javascript
Source: ESPN Tennis (not implemented yet)
Potential Data:
  - Player ranking
  - Surface-specific record (clay/hard/grass)
  - Head-to-head on surface
  - Recent form on surface
```

---

## ⚠️ Current Limitations

### **Odds API Quota Exceeded**
- **Impact:** Cannot build advanced betting cards
- **Affected Cards:**
  - ❌ Line Value Detector
  - ❌ Public Fade Alert
  - ⚠️ Betting Movement (only current ESPN odds)
- **Solution:** Upgrade to $50/month OR use ESPN odds as placeholder

### **Missing ESPN Services**
- ❌ NCAAF - No dedicated service (falls back to Odds API)
- ❌ NCAAB - No dedicated service (falls back to Odds API)
- ❌ Tennis - No service implemented
- ❌ Soccer - Service exists in Odds API, but limited ESPN data

### **ESPN Data Gaps**
- ⚠️ Odds movement history (only current lines)
- ⚠️ Public betting percentages (not available)
- ⚠️ Sharp money indicators (not available)
- ⚠️ Advanced player props (limited)

---

## 🎯 Implementation Priority by Data Availability

### **Tier 1: Fully Supported (Build Now)**
✅ Data available in ESPN + NewsAPI + Reddit

1. **Breaking News** - NewsAPI (ALL sports)
2. **Injury Intelligence** - ESPN (NFL, NBA, NHL, MLB)
3. **Weather Impact** - ESPN (NFL, MLB outdoor games)
4. **Matchup Analysis** - ESPN (NFL, NBA, NHL, MLB)
5. **Social Sentiment** - Reddit (ALL sports)

### **Tier 2: Sport-Specific (Build by Sport)**
✅ Data available for specific sports

6. **Pitcher Matchup** - ESPN MLB
7. **Ballpark Factors** - ESPN MLB
8. **Goalie Matchup** - ESPN NHL
9. **Special Teams** - ESPN NHL
10. **Fighter Analysis** - ESPN MMA/Boxing

### **Tier 3: Requires Odds API Upgrade**
❌ Needs Odds API quota or alternative data source

11. **Betting Movement** - Needs historical odds
12. **Line Value Detector** - Needs odds comparison
13. **Public Fade Alert** - Needs public betting %

---

## 📝 Code Reference

### Service Files:
- `lib/services/optimized_games_service.dart` - Main orchestrator
- `lib/services/edge/sports/espn_nfl_service.dart` - NFL endpoint
- `lib/services/edge/sports/espn_nba_service.dart` - NBA endpoint
- `lib/services/edge/sports/espn_nhl_service.dart` - NHL endpoint
- `lib/services/edge/sports/espn_mlb_service.dart` - MLB endpoint
- `lib/services/edge/edge_intelligence_service.dart` - Edge card aggregator

### Key Functions:
- `_loadSportGamesWithRange()` - Load games by sport (line 287)
- `_convertEspnEventToGame()` - Convert ESPN data to GameModel (line 724)
- `_classifyNbaGame()` - NBA season classification (line 549)
- `_groupCombatSportsByEvent()` - MMA/Boxing event grouping (line 1107)
- `_fetchESPNEvents()` - Fetch ESPN MMA/Boxing events (line 1540)

---

## ✅ Next Steps

1. **Build Core Edge Cards** using available ESPN data
   - Breaking News (NewsAPI)
   - Injury Intelligence (ESPN)
   - Weather Impact (ESPN NFL/MLB)

2. **Build Sport-Specific Cards**
   - MLB: Pitcher Matchup, Ballpark Factors
   - NHL: Goalie Matchup, Special Teams
   - MMA/Boxing: Fighter Analysis

3. **Decide on Odds API**
   - Upgrade to $50/month for advanced betting cards
   - OR use ESPN odds as free alternative (limited features)

4. **Implement Missing Services**
   - Add ESPN Tennis service
   - Add NCAAF/NCAAB ESPN endpoints
   - Enhance soccer data integration
