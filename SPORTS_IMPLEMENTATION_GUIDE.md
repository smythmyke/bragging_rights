# Sports Details Page Implementation Guide

## Overview
This guide ensures consistent implementation of sports details pages across all remaining sports (NFL, NHL, MMA, Boxing, Tennis) following the established patterns from MLB, Soccer, and NBA.

---

## 📋 Implementation Checklist for Each Sport

### Phase 1: API Discovery & Testing

#### 1.1 Test ESPN API Endpoints
```bash
# Scoreboard endpoint (get current games and IDs)
curl -s "https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/scoreboard" | head -150

# Examples:
# NFL: https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard
# NHL: https://site.api.espn.com/apis/site/v2/sports/hockey/nhl/scoreboard
# MMA: https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard
# Boxing: https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard
# Tennis: https://site.api.espn.com/apis/site/v2/sports/tennis/scoreboard

# Summary endpoint (get detailed game/match data)
# IMPORTANT: python -m json.tool may fail on Windows with large responses
# Save to file first for analysis:
curl -s "https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/summary?event={espnId}" > /tmp/{sport}_summary.json

# Check available sections (UPDATED METHOD)
grep -o '"[^"]*":' /tmp/{sport}_summary.json | sort -u | grep -E 'standings|leaders|injuries|lastFive|season|drives|win|scoring|odds|weather'

# Alternative: Direct grep for sections
curl -s "https://site.api.espn.com/apis/site/v2/sports/{sport}/{league}/summary?event={espnId}" | grep -o '"[^"]*":\|standings\|leaders\|injuries\|lastFiveGames\|seasonSeries\|odds\|predictor\|weather\|winprobability'
```

#### 1.2 Document Available Data Sections
Create a checklist of what's available:
- [ ] boxscore/matchup data
- [ ] standings
- [ ] team/player statistics
- [ ] injuries
- [ ] head-to-head history
- [ ] recent form/last games
- [ ] odds/betting data
- [ ] venue information (check indoor/outdoor flag!)
- [ ] officials/referees
- [ ] weather (for outdoor sports - check venue.indoor flag)
- [ ] winprobability (momentum tracking)
- [ ] news articles
- [ ] video highlights
- [ ] player/fighter profiles
- [ ] season/tournament context

**IMPORTANT DISCOVERY**: Always check what's ACTUALLY in the API response, not what we assume. For example:
- NFL has `weather` data for outdoor games
- NBA has extensive `leaders` categories
- Soccer has different standings structure (team as string, not object)

---

### Phase 2: ESPN ID Resolution

#### 2.1 Verify ESPN ID Resolver Works
```dart
// The EspnIdResolverService should already handle the sport
// Check lib/services/espn_id_resolver_service.dart

// Test matching logic:
1. Check team name normalization
2. Verify date/time matching (within reasonable window)
3. Test with actual game data
```

#### 2.2 Common Matching Issues to Check
- **Team name variations**: "LA Lakers" vs "Los Angeles Lakers"
- **Date/time zones**: ESPN uses ET/EST, Odds API may use UTC
- **Tournament names**: UFC 295 vs UFC 295: Prochazka vs Pereira
- **Individual sports**: Player names in tennis/golf

---

### Phase 3: Data Organization

#### 3.1 Categorize Available Data

**🎯 Edge Cards (Premium Features - $$$)**
Typically 2-3 cards with advanced/predictive data:

1. **Analytics/Insights Card**
   - Win probability
   - Advanced statistics
   - Momentum tracking
   - Key matchup analysis

2. **Betting Card**
   - Odds movements
   - Betting trends
   - Expert picks
   - Historical ATS performance

3. **News & Social Card** (optional)
   - Latest news
   - Social media buzz
   - Expert analysis
   - Video highlights

**📊 Details Page Tabs (Free Features)**
Core information in 3-5 tabs:

1. **Overview Tab**
   - Current score/status
   - Key stats summary
   - Game/match leaders
   - Period/round scores

2. **Stats Tab**
   - Team/player statistics
   - Comparative metrics
   - Performance indicators

3. **Standings Tab** (for league sports)
   - Conference/division standings
   - Playoff implications
   - Current position

4. **H2H Tab**
   - Recent meetings
   - Historical record
   - Form guide

5. **Sport-Specific Tab** (optional)
   - Injuries (NBA, NFL)
   - Fighters (MMA, Boxing)
   - Draw/Bracket (Tennis)

---

### Phase 4: Discussion Points

Before implementation, consider:

1. **Which tabs make sense for this sport?**
   - Individual sports (tennis, golf) don't need standings
   - Combat sports need fighter profiles
   - Outdoor sports might need weather

2. **What's the primary user interest?**
   - Betting focus?
   - Fantasy sports?
   - Casual viewing?

3. **API limitations?**
   - What data is reliably available?
   - What updates in real-time?
   - What's cached vs live?

4. **UI/UX considerations?**
   - How to display tournament brackets?
   - How to show player matchups?
   - How to handle postponed/canceled events?

---

### Phase 5: Implementation

#### 5.1 Create Sport-Specific Documentation
```markdown
# {SPORT}_API_DATA_GUIDE.md

## ESPN API Endpoints
- Scoreboard: `url here`
- Summary: `url here`

## Available Data
### From ESPN API:
- List all available sections

### From Odds API:
- List betting data

## Edge Cards (2-3 premium features)
1. Card name and contents
2. Card name and contents

## Details Page Tabs (3-5 tabs)
1. Tab name and contents
2. Tab name and contents
...

## Caching Strategy
- Follow soccer/NBA model
- Use FirestoreCacheService
- Cache durations based on game status
```

#### 5.2 Update game_details_screen.dart

```dart
// Add to initState() tab count logic
: widget.sport.toUpperCase() == 'NFL'
? 5  // Number of tabs for NFL

// Add to _loadEventDetails()
} else if (widget.sport.toUpperCase() == 'NFL') {
  await _loadNFLDetails();

// Add tab labels
: widget.sport.toUpperCase() == 'NFL'
? [
    const Tab(text: 'Overview'),
    const Tab(text: 'Stats'),
    const Tab(text: 'Standings'),
    const Tab(text: 'H2H'),
    const Tab(text: 'Injuries'),
  ]

// Add tab views
: widget.sport.toUpperCase() == 'NFL'
? [
    _buildNFLOverviewTab(),
    _buildNFLStatsTab(),
    _buildNFLStandingsTab(),
    _buildNFLH2HTab(),
    _buildNFLInjuriesTab(),
  ]

// Implement methods
Future<void> _loadNFLDetails() async {
  // Use ESPN ID resolver
  // Fetch from ESPN API (should use cache service!)
  // Store in _eventDetails
}

Widget _buildNFLOverviewTab() {
  // Build UI for overview
}
// ... etc for each tab
```

#### 5.3 Integration with Caching

**IMPORTANT**: Use the FirestoreCacheService!

```dart
Future<void> _loadNFLDetails() async {
  try {
    // 1. Resolve ESPN ID
    final resolver = EspnIdResolverService();
    var espnGameId = _game?.espnId;

    if (espnGameId == null && _game != null) {
      espnGameId = await resolver.resolveEspnId(_game!);
    }

    // 2. Use cache service instead of direct HTTP
    final cacheService = FirestoreCacheService();
    final cachedData = await cacheService.getGameDetails(
      gameId: widget.gameId,
      espnId: espnGameId,
      sport: 'NFL',
    );

    if (cachedData != null) {
      setState(() {
        _eventDetails = cachedData;
      });
    } else {
      // Fetch and cache if not available
      final url = 'https://site.api.espn.com/apis/site/v2/sports/football/nfl/summary?event=$espnGameId';
      // ... fetch and store in cache
    }
  } catch (e) {
    print('Error loading NFL details: $e');
  }
}
```

---

## 🎮 Sport-Specific Considerations

### NFL
- 4 quarters + overtime
- Extensive injury reports
- Fantasy football integration important
- Weather conditions for outdoor games
- Playoff implications

### NHL
- 3 periods + overtime/shootout
- Power play statistics
- Goalie statistics prominent
- Line combinations
- Plus/minus ratings

### MMA/UFC
- Fighter records and stats
- Tale of the tape comparison
- Finish methods (KO, SUB, DEC)
- Round scoring
- Fighter rankings

### Boxing
- Fighter records
- Punch statistics (if available)
- Round-by-round scoring
- Title implications
- Weight class context

### Tennis
- Set and game scores
- Serve statistics
- Break points
- Head-to-head record
- Surface performance
- Tournament bracket position

---

## 🚀 Testing Checklist

For each sport implementation:

- [ ] ESPN API endpoints return data
- [ ] ESPN ID resolver correctly matches games
- [ ] All tabs load without errors
- [ ] Data displays correctly for:
  - [ ] Scheduled games
  - [ ] Live games
  - [ ] Completed games
- [ ] Caching service integration works
- [ ] Handles missing data gracefully
- [ ] UI responsive on mobile
- [ ] No overflow errors
- [ ] Loading states work
- [ ] Error states handled

---

## 📝 Implementation Order Recommendation

1. **NFL** - Most similar to existing sports, high user interest
2. **NHL** - Similar structure to NFL/NBA
3. **Tennis** - Different structure but simpler (no teams)
4. **MMA** - Combat sport with unique requirements
5. **Boxing** - Similar to MMA but less data available

---

## 🔄 Cache Integration Reminder

**CRITICAL**: All implementations should use FirestoreCacheService!

Benefits:
- 97% reduction in API calls
- Shared cache across all users
- Intelligent freshness rules
- Cost-effective scaling

Don't make direct HTTP calls - use the caching layer!

---

*Last Updated: December 2024*