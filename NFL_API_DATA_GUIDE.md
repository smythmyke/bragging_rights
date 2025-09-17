# NFL API Data Guide

## ESPN API Endpoints

### Main Endpoints (Verified & In Use)
- **Scoreboard**: `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard?dates={YYYYMMDD}`
  - Returns games for specific date
  - Used for: Game lists, basic scores, team records
- **Game Summary**: `https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event={gameId}`
  - Primary data source for game details
  - Returns: boxscore, standings, leaders, injuries, weather, odds, winprobability, lastFiveGames

## Available Data from ESPN API

### ✅ Confirmed Available Sections
Based on API testing:

1. **boxscore** - Team statistics and performance metrics
2. **standings** - Division and conference standings
3. **leaders** - Game/team leaders in various categories
4. **injuries** - Injury reports for both teams
5. **lastFiveGames** - Recent game history for each team
6. **odds** - Betting odds and lines
7. **weather** - Weather conditions (UNIQUE TO OUTDOOR SPORTS!)
8. **winprobability** - Win probability data throughout game

### Detailed Data Breakdown

#### 1. Boxscore
- Team statistics per game:
  - Points Per Game
  - Total Yards
  - Passing Yards
  - Rushing Yards
  - Points Allowed
  - Yards Allowed
  - Pass/Rush Yards Allowed
- Quarter-by-quarter scoring
- Team records (overall, home, away)

#### 2. Game Leaders
- **Passing Leaders**: Yards, TDs, completions
- **Rushing Leaders**: Carries, yards, TDs
- **Receiving Leaders**: Receptions, yards, TDs
- **Defensive Leaders**: Sacks, tackles, interceptions

#### 3. Standings
- Division standings (AFC/NFC East, West, North, South)
- Conference standings (AFC/NFC)
- Wild card race
- Playoff seeding
- Win/Loss records
- Division records
- Conference records
- Strength of schedule

#### 4. Injuries
- Player injury status (Out, Questionable, Doubtful, Probable)
- Injury descriptions
- Expected return dates
- Impact on depth chart

#### 5. Last Five Games
- Recent results for both teams
- Scores and opponents
- Home/Away performance
- Win/Loss streaks

#### 6. Weather (Unique!)
- Temperature (current, high, low)
- Wind speed and direction
- Precipitation percentage
- Field conditions
- Game-time forecast

#### 7. Win Probability
- Live win probability chart
- Key momentum shifts
- Biggest plays impact

#### 8. Odds
- Point spread
- Over/Under totals
- Moneyline odds
- Prop bets

---

## Data Organization for Bragging Rights

### 🎯 EDGE CARDS (Premium Features - $$$)

#### 1. **Advanced Analytics Card**
- **Win Probability Graph**: Real-time probability with momentum shifts
- **Drive Efficiency**: Success rate, yards per drive, scoring percentage
- **Red Zone Performance**: TD percentage in red zone
- **Third Down Conversions**: Success rates
- **Time of Possession Analysis**

#### 2. **Betting Insights Card**
- **Live Odds Movement**: Spread and total adjustments
- **ATS Records**: Against the spread performance
- **Over/Under Trends**: Scoring patterns
- **Quarter/Half Betting**: Period-specific analysis
- **Player Prop Performance**: Key player prop tracking

#### 3. **Injury Report Card** (Critical for betting & fantasy)
- **Real-Time Status**: Out, Questionable, Doubtful, Probable
- **Injury Details**: Type and severity of injuries
- **Practice Participation**: Weekly practice reports
- **Expected Return**: Timeline for return to play
- **Depth Chart Impact**: Replacement players and adjustments
- **Fantasy Implications**: How injuries affect player values
- **Betting Line Movement**: How injuries affect spreads

#### 4. **Weather & Conditions Card** (For outdoor games)
- **Current Conditions**: Temp, wind, precipitation
- **Impact Analysis**: How weather affects gameplay
- **Historical Performance**: Teams in similar conditions
- **Fantasy Adjustments**: Weather impact on player projections

---

### 📊 DETAILS PAGE TABS (Free Features)

#### Tab 1: **Overview**
- **Live Score & Quarter Info**
- **Team Records**: Overall, Home/Away, Division, Conference
- **Game Leaders**: Top performers in Pass/Rush/Receive/Defense
- **Quarter Scores**: Period-by-period breakdown
- **Current Drive**: Live drive tracker (when live)
- **Weather Snapshot**: Basic conditions (for outdoor games)

#### Tab 2: **Stats**
- **Team Stats Comparison**:
  - Total Yards
  - Passing/Rushing Yards
  - First Downs
  - Third Down Efficiency
  - Red Zone Efficiency
  - Turnovers
  - Penalties
  - Time of Possession
  - Sacks
  - Points Scored
- **Player Stats** (when available):
  - Passing: Comp/Att, Yards, TDs, INTs, Rating
  - Rushing: Carries, Yards, Avg, TDs
  - Receiving: Targets, Catches, Yards, TDs
  - Defense: Tackles, Sacks, INTs, Pass Deflections

#### Tab 3: **Standings**
- **Division Standings**:
  - Division record
  - Conference record
  - Games behind leader
- **Wild Card Race**: Playoff picture
- **Conference Standings**: Overall conference position
- **Tiebreakers**: Head-to-head records
- **Remaining Schedule Strength**

#### Tab 4: **H2H**
- **All-Time Series**: Historical record
- **Recent Meetings**: Last 5-10 games
- **Home/Away Split**: Performance at each venue
- **Playoff History**: Postseason matchups
- **Common Opponents**: Comparative performance
- **Last 5 Games**: Recent form for both teams

---

## Implementation Notes

### Caching Strategy (Following Soccer/NBA Model)
```dart
Future<void> _loadNFLDetails() async {
  // 1. Use ESPN ID resolver
  final resolver = EspnIdResolverService();
  var espnGameId = _game?.espnId;

  if (espnGameId == null && _game != null) {
    espnGameId = await resolver.resolveEspnId(_game!);
  }

  // 2. IMPORTANT: Use FirestoreCacheService!
  final cacheService = FirestoreCacheService();

  // 3. Check cache first
  final cachedData = await cacheService.getGameDetails(
    gameId: widget.gameId,
    espnId: espnGameId,
    sport: 'NFL',
  );

  if (cachedData != null && cacheService.isFresh(cachedData, _game!)) {
    setState(() => _eventDetails = cachedData);
    return;
  }

  // 4. Only fetch if cache miss or stale
  final url = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=$espnGameId';
  final response = await http.get(Uri.parse(url));

  // 5. Cache the response
  await cacheService.cacheGameDetails(
    gameId: widget.gameId,
    espnId: espnGameId,
    sport: 'NFL',
    data: json.decode(response.body),
  );
}
```

### NFL-Specific Considerations

1. **Weather Handling**:
   - Only show weather tab for outdoor stadiums
   - Check venue.indoor flag
   - Update weather more frequently for live games

2. **Game States**:
   - Pre-game (show inactives)
   - In-progress (live drive tracker)
   - Halftime (halftime stats)
   - Final (full box score)
   - Overtime (special OT rules)

3. **Season Context**:
   - Regular season (17 games)
   - Playoffs (single elimination)
   - Super Bowl (neutral site)

4. **Fantasy Integration**:
   - High importance for NFL
   - Player projections vs actual
   - Snap counts when available

---

## Testing Checklist

- [x] ESPN scoreboard endpoint returns data
- [x] ESPN summary endpoint returns all sections
- [x] Weather data available for outdoor games
- [ ] ESPN ID resolver works for NFL games
- [ ] All 5 tabs display correctly
- [ ] Caching service integration works
- [ ] Weather only shows for outdoor games
- [ ] Injury report displays properly
- [ ] Standings show playoff picture

---

## Lessons Learned for Other Sports

1. **Check for sport-specific data**: NFL has weather, combat sports might have fight cards
2. **Venue information matters**: Indoor vs outdoor affects available data
3. **Season structure varies**: NFL has divisions, tennis has tournaments
4. **Cache differently based on context**: Playoff games might need different cache rules
5. **Always test with real game IDs**: Structure can vary between pre-season/regular/playoffs

---

*Last Updated: December 2024*