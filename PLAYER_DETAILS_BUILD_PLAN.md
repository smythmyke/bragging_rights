# Player & Fighter Details Implementation Build Plan

## Overview
Implement a unified player/fighter details system that works across all sports, utilizing Firestore caching with API fallback.

## Architecture

### Data Flow
1. **Check Firestore Cache** → If exists and < 90 days old → Display
2. **API Fallback** → If cache miss/stale → Fetch from API
3. **Save to Firestore** → Cache successful API responses
4. **Display Data** → Show whatever data is available

## API Endpoints by Sport

### ✅ WORKING ENDPOINTS

#### The Odds API - Fighter/Player Participants (ALL SPORTS)
```bash
# Endpoint
GET https://api.the-odds-api.com/v4/sports/{sport}/participants?apiKey={apiKey}

# Test Commands
# MMA Fighters
curl -s "https://api.the-odds-api.com/v4/sports/mma_mixed_martial_arts/participants?apiKey=YOUR_KEY"

# Boxing Fighters
curl -s "https://api.the-odds-api.com/v4/sports/boxing_boxing/participants?apiKey=YOUR_KEY"

# NFL Teams
curl -s "https://api.the-odds-api.com/v4/sports/americanfootball_nfl/participants?apiKey=YOUR_KEY"

# Available Data
- Participant ID (unique identifier)
- Full Name
- Complete list of ALL fighters/teams in the sport
- Not limited to current events only

# Response Example (MMA)
{
  "full_name": "Conor McGregor",
  "id": "par_01hqmkqbk1fhxb0ms2s951y8te"
}

# Important Notes
- Returns individual fighters for combat sports
- Returns teams for team sports (not individual players)
- Costs 1 API credit per call
- Should be cached heavily as participant lists don't change frequently
```

#### MLB - Full Player Stats
```bash
# Endpoint
GET https://statsapi.mlb.com/api/v1/people/{playerId}

# Test Command
curl -s "https://statsapi.mlb.com/api/v1/people/660271"

# Available Data
- Full Name, First/Last Name
- Birth Date, Age, Birth City/Country
- Height, Weight
- Position, Jersey Number
- Batting/Pitching Side
- MLB Debut Date
- Active Status
- Career Statistics (via additional endpoints)
```

#### UFC/MMA - Scoreboard Data Only
```bash
# Endpoint
GET https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard

# Test Command
curl -s "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard"

# Available Data (from events)
- Fighter ID
- Full Name, Display Name
- Win-Loss-Draw Record
- Country & Flag URL
- Weight Class (from competition)
- Limited to fighters in current/recent events
```

### ❌ NON-WORKING ENDPOINTS (Return 404)

#### ESPN Individual Athletes (All Sports)
```bash
# These all return 404:
GET https://site.api.espn.com/apis/site/v2/sports/mma/ufc/athletes/{id}
GET https://site.api.espn.com/apis/site/v2/sports/boxing/athletes/{id}
GET https://site.api.espn.com/apis/site/v2/sports/football/nfl/athletes/{id}
GET https://site.api.espn.com/apis/site/v2/sports/basketball/nba/athletes/{id}
```

## Implementation Steps

### Phase 1: Create Unified Player Service

```dart
// services/unified_player_service.dart
class UnifiedPlayerService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static const Duration _cacheDuration = Duration(days: 90);

  Future<PlayerData?> getPlayerDetails({
    required String playerId,
    required String sport,
    required String playerName,
    String? espnId,
  }) async {
    // 1. Check Firestore cache
    final cached = await _getFromCache(playerId, sport);
    if (cached != null && _isCacheValid(cached.lastUpdated)) {
      return cached;
    }

    // 2. Fetch from appropriate API
    final fresh = await _fetchFromAPI(playerId, sport, playerName);

    // 3. Save to cache if successful
    if (fresh != null) {
      await _saveToCache(fresh);
    }

    // 4. Return fresh or cached data
    return fresh ?? cached;
  }
}
```

### Phase 2: API Integration by Sport

#### MLB Implementation
```dart
Future<PlayerData?> _fetchMLBPlayer(String playerId) async {
  final url = 'https://statsapi.mlb.com/api/v1/people/$playerId';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    final player = json['people'][0];

    return PlayerData(
      id: playerId,
      name: player['fullName'],
      position: player['primaryPosition']['name'],
      height: player['height'],
      weight: player['weight'],
      birthDate: player['birthDate'],
      country: player['birthCountry'],
      jerseyNumber: player['primaryNumber'],
      sport: 'MLB',
      rawData: player,
      lastUpdated: DateTime.now(),
    );
  }
  return null;
}
```

#### UFC/MMA Implementation
```dart
Future<PlayerData?> _fetchMMAFighter(String fighterId, String fighterName) async {
  // Since individual fighter endpoints don't work,
  // extract from scoreboard if fighter appears in upcoming events
  final url = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard';
  final response = await http.get(Uri.parse(url));

  if (response.statusCode == 200) {
    final json = jsonDecode(response.body);
    // Search through events for fighter
    // Extract available data
    // Return PlayerData object
  }

  // Fallback: Create basic profile
  return PlayerData.basic(
    id: fighterId,
    name: fighterName,
    sport: 'MMA',
  );
}
```

### Phase 3: Firestore Schema

```javascript
// Firestore Collection: players/{sport}_{playerId}
{
  "id": "MLB_660271",
  "playerId": "660271",
  "sport": "MLB",
  "name": "Shohei Ohtani",
  "displayName": "Shohei Ohtani",
  "position": "Two-Way Player",
  "jerseyNumber": "17",
  "physical": {
    "height": "6' 3\"",
    "weight": 210,
    "age": 31,
    "birthDate": "1994-07-05"
  },
  "location": {
    "birthCity": "Oshu",
    "birthCountry": "Japan",
    "currentTeam": "Los Angeles Dodgers"
  },
  "stats": {
    "record": "N/A",  // For fighters
    "wins": 0,        // For fighters
    "losses": 0,      // For fighters
    "battingAvg": 0.304,  // For baseball
    "homeRuns": 44,       // For baseball
    // Sport-specific stats
  },
  "images": {
    "headshot": "url",
    "flag": "url",
    "teamLogo": "url"
  },
  "metadata": {
    "lastUpdated": "2025-01-13T12:00:00Z",
    "dataSource": "MLB_API",
    "cacheVersion": 1
  }
}
```

### Phase 4: Update Details Screen

```dart
class PlayerDetailsScreen extends StatefulWidget {
  final String playerId;
  final String playerName;
  final String sport;
  final String? espnId;

  // ... rest of implementation
}
```

## Testing Protocol

### 1. Test Each API Endpoint
```bash
# MLB - Expected: 200 OK
curl -s "https://statsapi.mlb.com/api/v1/people/660271" | jq '.people[0].fullName'

# UFC Scoreboard - Expected: 200 OK
curl -s "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard" | jq '.events[0]'

# NFL (via scoreboard) - Expected: 200 OK
curl -s "https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard" | jq '.'

# NBA (via scoreboard) - Expected: 200 OK
curl -s "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard" | jq '.'
```

### 2. Verify Cache Logic
- First load: API call → Save to Firestore
- Second load: Read from Firestore (no API call)
- After 90 days: API call → Update Firestore

### 3. Handle Edge Cases
- Player not found in API
- API timeout/error
- Corrupted cache data
- Sport-specific data variations

## Sport-Specific Implementations

### Combat Sports (MMA/Boxing)
- **Primary Source**: ESPN Scoreboard
- **Data Available**: Basic stats from fight cards
- **Fallback**: Manual data entry or web scraping
- **Cache Key**: `MMA_{fighterId}` or `BOXING_{fighterId}`

### MLB
- **Primary Source**: MLB Stats API
- **Data Available**: Comprehensive player stats
- **Additional Endpoints**:
  - `/api/v1/people/{id}/stats/career`
  - `/api/v1/people/{id}/stats/season`
- **Cache Key**: `MLB_{playerId}`

### NFL
- **Primary Source**: ESPN Scoreboard
- **Data Available**: Limited to game rosters
- **Fallback**: Build profiles from game data
- **Cache Key**: `NFL_{playerId}`

### NBA
- **Primary Source**: ESPN Scoreboard
- **Data Available**: Limited to game rosters
- **Fallback**: Build profiles from game data
- **Cache Key**: `NBA_{playerId}`

### NHL
- **Primary Source**: ESPN Scoreboard (NHL API deprecated)
- **Data Available**: Limited to game rosters
- **Cache Key**: `NHL_{playerId}`

## Error Handling

```dart
enum DataSource {
  cache,
  api,
  fallback
}

class PlayerDataResult {
  final PlayerData? data;
  final DataSource source;
  final String? error;

  bool get hasData => data != null;
  bool get isFromCache => source == DataSource.cache;
}
```

## Performance Optimizations

1. **Batch Fetching**: When loading team rosters, fetch all players in parallel
2. **Memory Cache**: Keep recently viewed players in memory
3. **Progressive Loading**: Show cached data immediately, update if fresher data arrives
4. **Image Caching**: Use Flutter's cached_network_image for headshots

## Migration Strategy

1. **Week 1**: Implement UnifiedPlayerService
2. **Week 2**: Add MLB integration (most complete API)
3. **Week 3**: Add combat sports (UFC/Boxing)
4. **Week 4**: Add team sports (NFL/NBA/NHL)
5. **Week 5**: Testing and optimization

## Success Metrics

- Cache hit rate > 80% after first month
- API response time < 2 seconds
- Player details load time < 500ms (from cache)
- 90-day cache retention working correctly
- All sports have basic player info available

## Future Enhancements

1. **Web Scraping**: For missing data
2. **Admin Portal**: Manual data entry for high-profile athletes
3. **Community Contributions**: Allow users to submit player info
4. **Statistics Tracking**: Career stats, recent performance
5. **Social Media Integration**: Latest posts, news
6. **Injury Reports**: Real-time injury status
7. **Fantasy Stats**: Fantasy points, projections

## API Documentation Resources

### The Odds API
- **Official Documentation**: https://the-odds-api.com/liveapi/guides/v4/
- **Participants Endpoint**: https://the-odds-api.com/liveapi/guides/v4/#get-participants
- **API Key Required**: Yes (Get from https://the-odds-api.com/#get-access)
- **Rate Limits**: Based on subscription plan

### ESPN API (Unofficial/Hidden)
- **Community Documentation**: https://github.com/pseudo-r/Public-ESPN-API
- **Unofficial Docs**: https://gist.github.com/akeaswaran/b48b02f1c94f873c6655e7129910fc3b
- **Blog Post**: https://zuplo.com/blog/2024/10/01/espn-hidden-api-guide
- **Status**: Undocumented, unsupported, subject to change
- **Note**: No official documentation exists - these are reverse-engineered endpoints

### MLB Stats API
- **Official**: Yes (MLB Advanced Media)
- **Base URL**: https://statsapi.mlb.com
- **Documentation**: Limited public docs, mostly reverse-engineered

## Notes

- ESPN's individual athlete endpoints are completely broken (404 for all sports)
- MLB has the only fully functional player API
- The Odds API provides comprehensive participant lists for ALL sports
- Combat sports can use The Odds API for complete fighter lists
- 90-day cache duration balances freshness with API limits
- Firestore document IDs use format: `{SPORT}_{playerId}`
- The Odds API participants should be cached aggressively (weekly refresh at most)