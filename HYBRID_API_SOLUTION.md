# Hybrid API Solution: Odds API + ESPN

## Problem Statement
- **Odds API**: Provides comprehensive game listings with MD5 hash IDs
- **ESPN API**: Provides detailed game data with numeric IDs
- **Issue**: The IDs are incompatible, causing details page to fail

## Solution Architecture

### 1. Data Structure Enhancement
Store both IDs in GameModel:
```dart
class GameModel {
  final String id;          // Odds API ID (for internal use)
  final String? espnId;      // ESPN ID (for details page)
  final String? oddsApiId;   // Explicitly store Odds API ID
  // ... other fields
}
```

### 2. Two-Phase Data Loading

#### Phase 1: Game Listings (Odds API)
- Fetch comprehensive game list from Odds API
- Store with Odds API hash IDs
- Display in game lists/cards

#### Phase 2: ESPN ID Resolution (On-Demand)
When user clicks on a game:
- If ESPN ID exists → Use it
- If not → Match by team names and date
- Cache the mapping for future use

### 3. Implementation Strategy

#### A. Enhanced GameModel Storage
```dart
// When fetching from Odds API
GameModel(
  id: event['id'],           // Odds API hash
  oddsApiId: event['id'],    // Explicit Odds API ID
  espnId: null,              // To be resolved later
  sport: 'MLB',
  homeTeam: event['home_team'],
  awayTeam: event['away_team'],
  gameTime: gameTime,
  // ... other fields
)
```

#### B. ESPN ID Resolution Service
```dart
class EspnIdResolver {
  // Cache mappings
  static final Map<String, String> _idMappings = {};

  static Future<String?> resolveEspnId({
    required String sport,
    required String homeTeam,
    required String awayTeam,
    required DateTime gameTime,
    String? oddsApiId,
  }) async {
    // Check cache first
    if (oddsApiId != null && _idMappings.containsKey(oddsApiId)) {
      return _idMappings[oddsApiId];
    }

    // Fetch ESPN scoreboard
    final scoreboardData = await fetchEspnScoreboard(sport);

    // Match by teams and date
    for (final event in scoreboardData['events']) {
      if (teamsMatch(event, homeTeam, awayTeam) &&
          datesMatch(event['date'], gameTime)) {
        final espnId = event['id'].toString();

        // Cache the mapping
        if (oddsApiId != null) {
          _idMappings[oddsApiId] = espnId;
        }

        return espnId;
      }
    }

    return null;
  }
}
```

#### C. Game Details Page Flow
```dart
Future<void> _loadBaseballDetails() async {
  // 1. Check if ESPN ID exists
  var espnId = _game?.espnId;

  // 2. If not, resolve it
  if (espnId == null && _game != null) {
    espnId = await EspnIdResolver.resolveEspnId(
      sport: _game.sport,
      homeTeam: _game.homeTeam,
      awayTeam: _game.awayTeam,
      gameTime: _game.gameTime,
      oddsApiId: _game.oddsApiId ?? _game.id,
    );

    // 3. Update the game model with ESPN ID
    if (espnId != null) {
      await _updateGameWithEspnId(_game.id, espnId);
    }
  }

  // 4. Use ESPN ID for details
  if (espnId != null) {
    await _fetchEspnDetails(espnId);
  } else {
    // Fallback: Show limited data
    _showLimitedDetails();
  }
}
```

### 4. Benefits

#### ✅ Advantages
- **More Games**: Odds API provides comprehensive listings
- **Better Details**: ESPN provides rich game details
- **Efficient**: ESPN ID resolved only when needed
- **Cached**: Mappings stored for future use
- **Fallback**: Works even if ESPN match fails

#### 📊 Data Flow
```
1. App Start → Fetch from Odds API → Display games
2. User clicks game → Check for ESPN ID
3. If no ESPN ID → Match by teams/date → Cache mapping
4. Use ESPN ID → Fetch details → Display
```

### 5. Implementation Steps

#### Step 1: Update GameModel
Add `oddsApiId` and ensure `espnId` fields exist

#### Step 2: Create ESPN ID Resolver
Service to match Odds API games to ESPN games

#### Step 3: Update Game Details Page
Use resolver when ESPN ID is missing

#### Step 4: Cache Mappings
Store successful mappings in Firestore

#### Step 5: Background Sync (Optional)
Periodically sync ESPN IDs for upcoming games

### 6. Firestore Structure

```json
// games collection
{
  "id": "b57e123101e4d592a1725d80fed2dc75",  // Odds API ID
  "oddsApiId": "b57e123101e4d592a1725d80fed2dc75",
  "espnId": "401697155",  // Resolved ESPN ID
  "sport": "MLB",
  "homeTeam": "Washington Nationals",
  "awayTeam": "Atlanta Braves",
  "gameTime": "2024-09-15T13:05:00Z",
  "lastUpdated": "2024-09-15T12:00:00Z"
}

// id_mappings collection (for quick lookup)
{
  "oddsApiId": "b57e123101e4d592a1725d80fed2dc75",
  "espnId": "401697155",
  "sport": "MLB",
  "verified": true,
  "createdAt": "2024-09-15T12:00:00Z"
}
```

### 7. Testing Strategy

1. **Test Odds API game fetch** - Verify games load
2. **Test ESPN ID resolution** - Verify matching works
3. **Test details page** - Verify ESPN data loads
4. **Test caching** - Verify mappings are saved
5. **Test fallback** - Verify app works if matching fails

### 8. Example Code

#### ESPN ID Resolver Implementation
```dart
class EspnIdResolverService {
  final _firestore = FirebaseFirestore.instance;
  static final Map<String, String> _memoryCache = {};

  Future<String?> resolveEspnId(GameModel game) async {
    // 1. Check memory cache
    final cacheKey = game.oddsApiId ?? game.id;
    if (_memoryCache.containsKey(cacheKey)) {
      return _memoryCache[cacheKey];
    }

    // 2. Check Firestore cache
    final mapping = await _firestore
        .collection('id_mappings')
        .doc(cacheKey)
        .get();

    if (mapping.exists) {
      final espnId = mapping.data()?['espnId'];
      _memoryCache[cacheKey] = espnId;
      return espnId;
    }

    // 3. Resolve from ESPN API
    final espnId = await _matchWithEspn(game);

    if (espnId != null) {
      // 4. Cache the mapping
      await _saveMapping(cacheKey, espnId, game.sport);
      _memoryCache[cacheKey] = espnId;
    }

    return espnId;
  }

  Future<String?> _matchWithEspn(GameModel game) async {
    try {
      final url = _getEspnScoreboardUrl(game.sport);
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final events = data['events'] as List;

        for (final event in events) {
          if (_teamsMatch(event, game) && _dateMatches(event, game)) {
            return event['id'].toString();
          }
        }
      }
    } catch (e) {
      print('Error matching with ESPN: $e');
    }

    return null;
  }

  bool _teamsMatch(Map event, GameModel game) {
    final competitors = event['competitions']?[0]?['competitors'] ?? [];
    if (competitors.length < 2) return false;

    final homeTeam = competitors.firstWhere(
      (c) => c['homeAway'] == 'home',
      orElse: () => {},
    )['team']?['displayName'] ?? '';

    final awayTeam = competitors.firstWhere(
      (c) => c['homeAway'] == 'away',
      orElse: () => {},
    )['team']?['displayName'] ?? '';

    return _normalizeTeam(homeTeam) == _normalizeTeam(game.homeTeam) &&
           _normalizeTeam(awayTeam) == _normalizeTeam(game.awayTeam);
  }

  String _normalizeTeam(String team) {
    return team.toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '')
        .trim();
  }
}
```

### 9. Immediate Fix (Temporary)

While implementing the full solution, add this quick fix to game_details_screen.dart:

```dart
// If Odds API ID detected, try to resolve ESPN ID
if (espnGameId.length == 32 && RegExp(r'^[a-f0-9]+$').hasMatch(espnGameId)) {
  print('⚠️ Odds API ID detected, resolving ESPN ID...');

  // Fetch ESPN scoreboard and match by teams
  final scoreboardUrl = 'https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard';
  final response = await http.get(Uri.parse(scoreboardUrl));

  if (response.statusCode == 200) {
    final data = json.decode(response.body);
    final events = data['events'] as List;

    for (final event in events) {
      // Match by team names
      final competitors = event['competitions']?[0]?['competitors'] ?? [];
      if (competitors.length >= 2) {
        final home = competitors.firstWhere((c) => c['homeAway'] == 'home')['team']?['displayName'];
        final away = competitors.firstWhere((c) => c['homeAway'] == 'away')['team']?['displayName'];

        if (home == _game?.homeTeam && away == _game?.awayTeam) {
          espnGameId = event['id'].toString();
          print('✅ Resolved ESPN ID: $espnGameId');
          break;
        }
      }
    }
  }
}
```

---

## Summary

This hybrid approach gives you:
1. **Comprehensive game listings** from Odds API
2. **Detailed game information** from ESPN
3. **Automatic ID resolution** when needed
4. **Cached mappings** for performance
5. **Graceful fallbacks** if matching fails

The best of both worlds!