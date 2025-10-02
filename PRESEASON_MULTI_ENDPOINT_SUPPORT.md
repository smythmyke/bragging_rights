# Preseason & Multi-Endpoint Support Plan
**Comprehensive Sports API Endpoint Coverage**

**Date:** January 2025
**Status:** Planning Phase
**Priority:** High - Critical for complete game coverage

---

## 📋 Executive Summary

**Problem Identified:**
- NBA preseason games (Oct 2-15, 2025) are missing from the app
- The Odds API uses separate endpoints for preseason vs regular season
- Our app only queries regular season endpoints
- Users see empty bet selection screens for valid preseason games

**Solution:**
1. Support multiple endpoints per sport (preseason, regular season, playoffs, etc.)
2. Auto-detect game type and query correct endpoint
3. Display game type badges ("PRESEASON", "PLAYOFFS", etc.) in UI
4. Implement fallback logic to check all relevant endpoints

---

## 🎯 Part 1: Current State Analysis

### **Available Odds API Sport Endpoints**

Based on API documentation and live query, here are ALL available endpoints:

#### **Basketball:**
- ✅ `basketball_nba` - NBA Regular Season (Oct 21 - Apr 2026)
- ✅ `basketball_nba_preseason` - NBA Preseason (Oct 1-15, 2025) **← MISSING IN APP**
- ✅ `basketball_nba_championship_winner` - NBA Finals futures
- `basketball_ncaab` - NCAA Men's Basketball
- `basketball_euroleague` - European League
- `basketball_wnba` - Women's NBA
- `basketball_nbl` - Australian NBL

#### **Football:**
- ✅ `americanfootball_nfl` - NFL Regular Season
- ❓ `americanfootball_nfl_preseason` - **NEEDS VERIFICATION**
- ❓ `americanfootball_nfl_super_bowl_winner` - **NEEDS VERIFICATION**
- `americanfootball_ncaaf` - NCAA Football

#### **Baseball:**
- ✅ `baseball_mlb` - MLB Regular Season
- ❓ `baseball_mlb_preseason` - Spring Training **NEEDS VERIFICATION**
- ❓ `baseball_mlb_world_series_winner` - **NEEDS VERIFICATION**

#### **Hockey:**
- ✅ `icehockey_nhl` - NHL Regular Season
- ❓ `icehockey_nhl_preseason` - **NEEDS VERIFICATION**
- ❓ `icehockey_nhl_championship_winner` - Stanley Cup **NEEDS VERIFICATION**

#### **Soccer:**
- ✅ `soccer_epl` - English Premier League
- `soccer_spain_la_liga` - La Liga
- `soccer_germany_bundesliga` - Bundesliga
- `soccer_italy_serie_a` - Serie A
- `soccer_france_ligue_one` - Ligue 1
- `soccer_uefa_champs_league` - Champions League
- `soccer_uefa_europa_league` - Europa League
- `soccer_usa_mls` - MLS
- ... (50+ soccer leagues)

#### **Combat Sports:**
- ✅ `mma_mixed_martial_arts` - UFC, Bellator, PFL, ONE Championship
- ✅ `boxing_boxing` - Professional Boxing

#### **Other Sports:**
- `tennis_atp` - ATP Tour
- `golf_masters` - Masters Tournament
- ... (100+ total sports)

---

## 🔍 Part 2: API Endpoint Verification

### **Task 2.1: Verify Preseason Endpoints Exist**

**Need to confirm which preseason endpoints are actually available:**

```bash
# Check all available sports
curl "https://api.the-odds-api.com/v4/sports/?apiKey=YOUR_KEY"

# Filter for preseason-specific endpoints
curl "https://api.the-odds-api.com/v4/sports/?apiKey=YOUR_KEY" | \
  jq '.[] | select(.key | contains("preseason"))'
```

**Expected to find:**
- ✅ `basketball_nba_preseason` (confirmed exists)
- ❓ `americanfootball_nfl_preseason`
- ❓ `icehockey_nhl_preseason`
- ❓ `baseball_mlb_preseason`

**Verification Steps:**
1. Query all sports from API
2. Filter for keywords: `preseason`, `playoff`, `championship`, `postseason`
3. Document which sports have multiple endpoints
4. Check date ranges for each endpoint
5. Identify any gaps in coverage

---

## 🔧 Part 3: Technical Implementation Plan

### **Phase 1: Enhanced Sport Key Mapping**

**Current Implementation (odds_api_service.dart:39-56):**
```dart
static const Map<String, String> _sportKeys = {
  'nba': 'basketball_nba',  // Only regular season!
  'nfl': 'americanfootball_nfl',
  'nhl': 'icehockey_nhl',
  'mlb': 'baseball_mlb',
  // ...
};
```

**New Implementation - Multi-Endpoint Support:**

```dart
// New data structure to support multiple endpoints per sport
static const Map<String, List<SportEndpoint>> _sportEndpoints = {
  'nba': [
    SportEndpoint(
      key: 'basketball_nba_preseason',
      type: SportSeasonType.preseason,
      priority: 1, // Check first (earlier dates)
      label: 'PRESEASON',
      dateRange: DateRange(
        start: DateTime(2025, 10, 1),
        end: DateTime(2025, 10, 15),
      ),
    ),
    SportEndpoint(
      key: 'basketball_nba',
      type: SportSeasonType.regularSeason,
      priority: 2, // Check second
      label: null, // No badge for regular season
      dateRange: DateRange(
        start: DateTime(2025, 10, 21),
        end: DateTime(2026, 4, 13),
      ),
    ),
    SportEndpoint(
      key: 'basketball_nba_championship_winner',
      type: SportSeasonType.futures,
      priority: 3,
      label: 'FUTURES',
      dateRange: null, // Always available
    ),
  ],
  'nfl': [
    SportEndpoint(
      key: 'americanfootball_nfl_preseason',
      type: SportSeasonType.preseason,
      priority: 1,
      label: 'PRESEASON',
      dateRange: DateRange(
        start: DateTime(2025, 8, 1),
        end: DateTime(2025, 9, 5),
      ),
    ),
    SportEndpoint(
      key: 'americanfootball_nfl',
      type: SportSeasonType.regularSeason,
      priority: 2,
      label: null,
      dateRange: DateRange(
        start: DateTime(2025, 9, 5),
        end: DateTime(2026, 1, 5),
      ),
    ),
  ],
  'mlb': [
    SportEndpoint(
      key: 'baseball_mlb_preseason',
      type: SportSeasonType.preseason,
      priority: 1,
      label: 'SPRING TRAINING',
      dateRange: DateRange(
        start: DateTime(2026, 2, 15),
        end: DateTime(2026, 3, 28),
      ),
    ),
    SportEndpoint(
      key: 'baseball_mlb',
      type: SportSeasonType.regularSeason,
      priority: 2,
      label: null,
      dateRange: DateRange(
        start: DateTime(2026, 3, 28),
        end: DateTime(2026, 10, 1),
      ),
    ),
  ],
  'nhl': [
    SportEndpoint(
      key: 'icehockey_nhl_preseason',
      type: SportSeasonType.preseason,
      priority: 1,
      label: 'PRESEASON',
      dateRange: DateRange(
        start: DateTime(2025, 9, 15),
        end: DateTime(2025, 10, 10),
      ),
    ),
    SportEndpoint(
      key: 'icehockey_nhl',
      type: SportSeasonType.regularSeason,
      priority: 2,
      label: null,
      dateRange: DateRange(
        start: DateTime(2025, 10, 10),
        end: DateTime(2026, 4, 15),
      ),
    ),
  ],
};

// Supporting classes
class SportEndpoint {
  final String key;
  final SportSeasonType type;
  final int priority; // Lower = check first
  final String? label; // UI badge text
  final DateRange? dateRange;

  const SportEndpoint({
    required this.key,
    required this.type,
    required this.priority,
    this.label,
    this.dateRange,
  });

  /// Check if this endpoint applies to a given date
  bool appliesToDate(DateTime date) {
    if (dateRange == null) return true;
    return date.isAfter(dateRange!.start) &&
           date.isBefore(dateRange!.end);
  }
}

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});
}

enum SportSeasonType {
  preseason,
  regularSeason,
  playoffs,
  postseason,
  futures,
  tournament,
}
```

---

### **Phase 2: Smart Endpoint Selection Logic**

**New Method: `_getEndpointsForSport()`**

```dart
/// Get all applicable endpoints for a sport
/// Returns endpoints sorted by priority (preseason first, then regular)
List<SportEndpoint> _getEndpointsForSport(String sport, {DateTime? gameDate}) {
  final endpoints = _sportEndpoints[sport.toLowerCase()] ?? [];

  if (endpoints.isEmpty) {
    // Fallback to legacy single-endpoint mapping
    final legacyKey = _sportKeys[sport.toLowerCase()];
    if (legacyKey != null) {
      return [
        SportEndpoint(
          key: legacyKey,
          type: SportSeasonType.regularSeason,
          priority: 1,
          label: null,
          dateRange: null,
        ),
      ];
    }
    return [];
  }

  // Filter by date if provided
  if (gameDate != null) {
    final filtered = endpoints.where((e) => e.appliesToDate(gameDate)).toList();
    if (filtered.isNotEmpty) {
      filtered.sort((a, b) => a.priority.compareTo(b.priority));
      return filtered;
    }
  }

  // Return all endpoints sorted by priority
  final sorted = List<SportEndpoint>.from(endpoints);
  sorted.sort((a, b) => a.priority.compareTo(b.priority));
  return sorted;
}
```

---

### **Phase 3: Multi-Endpoint Search Strategy**

**Enhanced `getMatchOdds()` Method:**

```dart
Future<Map<String, dynamic>?> getMatchOdds({
  required String sport,
  required String homeTeam,
  required String awayTeam,
  DateTime? gameDate, // NEW: helps determine which endpoint to check
}) async {
  await ensureInitialized();

  debugPrint('🎯 getMatchOdds called');
  debugPrint('   Sport: $sport');
  debugPrint('   Game: $awayTeam @ $homeTeam');
  debugPrint('   Date: ${gameDate?.toIso8601String() ?? "unknown"}');

  // Get applicable endpoints for this sport
  final endpoints = _getEndpointsForSport(sport, gameDate: gameDate);

  if (endpoints.isEmpty) {
    debugPrint('❌ No endpoints found for sport: $sport');
    return null;
  }

  debugPrint('📍 Will check ${endpoints.length} endpoint(s):');
  for (final endpoint in endpoints) {
    debugPrint('   - ${endpoint.key} (${endpoint.type.name})${endpoint.label != null ? " [${endpoint.label}]" : ""}');
  }

  // Try each endpoint in priority order
  for (final endpoint in endpoints) {
    debugPrint('🔍 Checking endpoint: ${endpoint.key}');

    final events = await _getSportOddsForEndpoint(endpoint.key);

    if (events == null || events.isEmpty) {
      debugPrint('   ⚠️ No events found in ${endpoint.key}');
      continue;
    }

    debugPrint('   ✅ Found ${events.length} events in ${endpoint.key}');

    // Search for matching game
    for (final event in events) {
      final eventHome = event['home_team']?.toString() ?? '';
      final eventAway = event['away_team']?.toString() ?? '';

      final homeMatches = _teamsMatch(
        eventHome.toLowerCase(),
        _normalizeTeamName(homeTeam),
        sport
      );
      final awayMatches = _teamsMatch(
        eventAway.toLowerCase(),
        _normalizeTeamName(awayTeam),
        sport
      );

      if (homeMatches && awayMatches) {
        debugPrint('   ✅ MATCH FOUND in ${endpoint.key}!');

        // Extract odds
        final bookmakers = event['bookmakers'] ?? [];
        final odds = _extractBestOdds(bookmakers);

        return {
          'eventId': event['id'],
          'commence_time': event['commence_time'],
          'home_team': event['home_team'],
          'away_team': event['away_team'],
          'odds': odds,
          'bookmaker_count': bookmakers.length,
          'sport_title': event['sport_title'],
          'sport_key': event['sport_key'],
          // NEW: Season type metadata
          'season_type': endpoint.type.name,
          'season_label': endpoint.label, // e.g., "PRESEASON"
          'endpoint_used': endpoint.key,
        };
      }
    }

    debugPrint('   ❌ No match in ${endpoint.key}');
  }

  debugPrint('❌ No match found in any endpoint for $awayTeam @ $homeTeam');
  return null;
}

/// Helper method to fetch odds from a specific endpoint
Future<List<Map<String, dynamic>>?> _getSportOddsForEndpoint(String sportKey) async {
  try {
    final url = '$_baseUrl/sports/$sportKey/odds/?'
        'apiKey=$_apiKey'
        '&regions=us'
        '&markets=h2h,spreads,totals'
        '&oddsFormat=american';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      return data.cast<Map<String, dynamic>>();
    }

    return null;
  } catch (e) {
    debugPrint('Error fetching from $sportKey: $e');
    return null;
  }
}
```

---

### **Phase 4: Enhanced `getSportOdds()` for Multi-Endpoint**

**Update to aggregate results from multiple endpoints:**

```dart
Future<List<Map<String, dynamic>>?> getSportOdds({
  required String sport,
  String? tournament,
  String regions = 'us',
  String markets = 'h2h,spreads,totals',
  String oddsFormat = 'american',
  bool includeAllSeasons = true, // NEW: include preseason + regular season
}) async {
  await ensureInitialized();

  return await _quotaManager.executeWithQuota<List<Map<String, dynamic>>>(
    sport: sport,
    apiCall: () async {
      if (!includeAllSeasons) {
        // Legacy behavior - single endpoint
        final sportKey = _sportKeys[sport.toLowerCase()] ?? sport;
        return await _fetchOddsFromEndpoint(sportKey, regions, markets, oddsFormat);
      }

      // NEW: Multi-endpoint aggregation
      final endpoints = _getEndpointsForSport(sport);
      final allEvents = <Map<String, dynamic>>[];
      final seenEventIds = <String>{};

      debugPrint('📡 Fetching odds from ${endpoints.length} endpoint(s) for $sport');

      for (final endpoint in endpoints) {
        debugPrint('   Checking ${endpoint.key}...');

        final events = await _fetchOddsFromEndpoint(
          endpoint.key,
          regions,
          markets,
          oddsFormat
        );

        if (events != null && events.isNotEmpty) {
          // Add season metadata to each event
          for (final event in events) {
            final eventId = event['id'] as String;

            // Avoid duplicates (shouldn't happen but just in case)
            if (seenEventIds.contains(eventId)) {
              continue;
            }

            seenEventIds.add(eventId);

            // Enrich event with season metadata
            event['season_type'] = endpoint.type.name;
            event['season_label'] = endpoint.label;
            event['endpoint_used'] = endpoint.key;

            allEvents.add(event);
          }

          debugPrint('   ✅ Added ${events.length} events from ${endpoint.key}');
        }
      }

      debugPrint('✅ Total events across all endpoints: ${allEvents.length}');

      // Sort by commence time
      allEvents.sort((a, b) {
        final aTime = DateTime.parse(a['commence_time']);
        final bTime = DateTime.parse(b['commence_time']);
        return aTime.compareTo(bTime);
      });

      return allEvents.isNotEmpty ? allEvents : null;
    },
    getCached: null,
  );
}

Future<List<Map<String, dynamic>>?> _fetchOddsFromEndpoint(
  String sportKey,
  String regions,
  String markets,
  String oddsFormat,
) async {
  try {
    final url = '$_baseUrl/sports/$sportKey/odds/?'
        'apiKey=$_apiKey'
        '&regions=$regions'
        '&markets=$markets'
        '&oddsFormat=$oddsFormat';

    final response = await http.get(Uri.parse(url));

    if (response.statusCode == 200) {
      final data = json.decode(response.body) as List;
      return data.cast<Map<String, dynamic>>();
    }

    return null;
  } catch (e) {
    debugPrint('Error fetching from $sportKey: $e');
    return null;
  }
}
```

---

## 🎨 Part 4: UI Badge Implementation

### **Phase 5: Add Season Type to GameModel**

**Update GameModel (lib/models/game_model.dart):**

```dart
class GameModel {
  final String id;
  final String sport;
  final String homeTeam;
  final String awayTeam;
  final DateTime gameTime;
  final String status;
  final String league;

  // NEW: Season type metadata
  final String? seasonType; // 'preseason', 'regularSeason', 'playoffs'
  final String? seasonLabel; // 'PRESEASON', 'SPRING TRAINING', 'PLAYOFFS'

  // ... existing fields

  GameModel({
    required this.id,
    required this.sport,
    required this.homeTeam,
    required this.awayTeam,
    required this.gameTime,
    required this.status,
    required this.league,
    this.seasonType,
    this.seasonLabel,
    // ... existing fields
  });

  // Update fromJson to include new fields
  factory GameModel.fromJson(Map<String, dynamic> json) {
    return GameModel(
      id: json['id'] as String,
      sport: json['sport'] as String,
      homeTeam: json['homeTeam'] as String,
      awayTeam: json['awayTeam'] as String,
      gameTime: (json['gameTime'] is Timestamp)
          ? (json['gameTime'] as Timestamp).toDate()
          : DateTime.parse(json['gameTime'] as String),
      status: json['status'] as String? ?? 'scheduled',
      league: json['league'] as String? ?? '',
      seasonType: json['seasonType'] as String?, // NEW
      seasonLabel: json['seasonLabel'] as String?, // NEW
      // ... existing fields
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'sport': sport,
      'homeTeam': homeTeam,
      'awayTeam': awayTeam,
      'gameTime': Timestamp.fromDate(gameTime),
      'status': status,
      'league': league,
      'seasonType': seasonType, // NEW
      'seasonLabel': seasonLabel, // NEW
      // ... existing fields
    };
  }
}
```

---

### **Phase 6: Season Badge Widget**

**Create new widget: `lib/widgets/season_type_badge.dart`**

```dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class SeasonTypeBadge extends StatelessWidget {
  final String? seasonLabel;
  final String? seasonType;

  const SeasonTypeBadge({
    Key? key,
    this.seasonLabel,
    this.seasonType,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show badge for regular season
    if (seasonLabel == null || seasonType == 'regularSeason') {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: _getBadgeColor().withOpacity(0.2),
        border: Border.all(
          color: _getBadgeColor(),
          width: 1.5,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getBadgeIcon(),
            size: 12,
            color: _getBadgeColor(),
          ),
          const SizedBox(width: 4),
          Text(
            seasonLabel!,
            style: TextStyle(
              color: _getBadgeColor(),
              fontSize: 10,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Color _getBadgeColor() {
    switch (seasonType) {
      case 'preseason':
        return AppTheme.warningAmber;
      case 'playoffs':
      case 'postseason':
        return AppTheme.neonGreen;
      case 'futures':
        return AppTheme.primaryCyan;
      case 'tournament':
        return AppTheme.accentPurple;
      default:
        return AppTheme.secondaryText;
    }
  }

  IconData _getBadgeIcon() {
    switch (seasonType) {
      case 'preseason':
        return Icons.fitness_center; // Training icon
      case 'playoffs':
      case 'postseason':
        return Icons.emoji_events; // Trophy icon
      case 'futures':
        return Icons.calendar_month;
      case 'tournament':
        return Icons.military_tech; // Medal icon
      default:
        return Icons.sports;
    }
  }
}
```

---

### **Phase 7: Integrate Badges into UI**

**Update Home Screen Game Cards (lib/screens/home/home_screen.dart):**

```dart
// In game card builder
Widget _buildGameCard(GameModel game) {
  return Card(
    child: Column(
      children: [
        // Game title row with season badge
        Row(
          children: [
            Expanded(
              child: Text(
                '${game.awayTeam} @ ${game.homeTeam}',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            // NEW: Season type badge
            SeasonTypeBadge(
              seasonLabel: game.seasonLabel,
              seasonType: game.seasonType,
            ),
          ],
        ),
        // ... rest of game card
      ],
    ),
  );
}
```

**Update Bet Selection Screen (lib/screens/betting/bet_selection_screen.dart):**

```dart
// In app bar or header
AppBar(
  title: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(widget.gameTitle),
      // NEW: Show season badge in header
      if (widget.seasonLabel != null)
        SeasonTypeBadge(
          seasonLabel: widget.seasonLabel,
          seasonType: widget.seasonType,
        ),
    ],
  ),
)

// Update BetSelectionScreen constructor
class BetSelectionScreen extends StatefulWidget {
  final String gameTitle;
  final String sport;
  final String poolName;
  final String? poolId;
  final String? gameId;
  final String? seasonLabel; // NEW
  final String? seasonType; // NEW

  const BetSelectionScreen({
    Key? key,
    required this.gameTitle,
    required this.sport,
    required this.poolName,
    this.poolId,
    this.gameId,
    this.seasonLabel, // NEW
    this.seasonType, // NEW
  }) : super(key: key);
}
```

**Update Navigation Arguments:**

```dart
// When navigating to bet selection
Navigator.pushNamed(
  context,
  '/bet-selection',
  arguments: {
    'gameTitle': game.homeTeam + ' vs ' + game.awayTeam,
    'sport': game.sport,
    'poolName': poolName,
    'poolId': poolId,
    'gameId': game.id,
    'seasonLabel': game.seasonLabel, // NEW
    'seasonType': game.seasonType, // NEW
  },
);
```

---

## 📊 Part 5: Testing Strategy

### **Phase 8: Comprehensive Testing**

**Test Case 1: NBA Preseason Game**
```
Game: Philadelphia 76ers @ New York Knicks
Date: Oct 2, 2025, 4:00 PM UTC
Expected:
  ✅ Odds found in basketball_nba_preseason
  ✅ Badge displays "PRESEASON" in amber
  ✅ Full odds available (ML, spread, total)
  ✅ Bet selection screen populated
```

**Test Case 2: NBA Regular Season Game**
```
Game: Houston Rockets @ Oklahoma City Thunder
Date: Oct 21, 2025, 11:30 PM UTC
Expected:
  ✅ Odds found in basketball_nba
  ✅ NO badge displayed (regular season)
  ✅ Full odds available
```

**Test Case 3: NFL Preseason (if available)**
```
Game: Any NFL preseason matchup
Date: Aug-Sep 2025
Expected:
  ✅ Check americanfootball_nfl_preseason endpoint
  ✅ Badge displays "PRESEASON" if found
  ✅ Fallback to regular endpoint if not found
```

**Test Case 4: MLB Spring Training (if available)**
```
Game: Any Spring Training game
Date: Feb-Mar 2026
Expected:
  ✅ Check baseball_mlb_preseason endpoint
  ✅ Badge displays "SPRING TRAINING"
```

**Test Case 5: Multi-Sport Aggregation**
```
Action: Load "All Games" screen with includeAllSeasons=true
Expected:
  ✅ NBA preseason + regular season games both appear
  ✅ Sorted chronologically
  ✅ Correct badges on each game
  ✅ No duplicate games
```

**Test Case 6: Date-Based Endpoint Selection**
```
Action: Request odds for Oct 2 NBA game
Expected:
  ✅ Only checks basketball_nba_preseason (date in range)
  ✅ Skips basketball_nba (date before start)
```

**Test Case 7: Fallback Behavior**
```
Action: Request odds for sport with no multi-endpoint config
Expected:
  ✅ Falls back to legacy _sportKeys mapping
  ✅ Works as before (backward compatible)
```

---

## 🚀 Part 6: Implementation Phases

### **Phase 1: API Verification (Day 1)**
**Priority:** Critical
**Estimated Time:** 2 hours

**Tasks:**
1. ✅ Query `/v4/sports/` endpoint to get ALL available sports
2. ✅ Filter for preseason/playoff/championship endpoints
3. ✅ Document findings in spreadsheet:
   - Sport name
   - Endpoint key
   - Season type
   - Typical date range
   - Currently active? (yes/no)
4. ✅ Test each preseason endpoint with sample query
5. ✅ Confirm date ranges match our assumptions

**Deliverable:** `ODDS_API_ENDPOINT_MAPPING.md` with complete list

---

### **Phase 2: Data Structure Updates (Day 1-2)**
**Priority:** High
**Estimated Time:** 4 hours

**Tasks:**
1. ✅ Create `SportEndpoint` class
2. ✅ Create `SportSeasonType` enum
3. ✅ Create `DateRange` class
4. ✅ Build `_sportEndpoints` mapping for all verified sports
5. ✅ Update `GameModel` to include `seasonType` and `seasonLabel`
6. ✅ Update Firestore schema (add optional fields, no migration needed)

**Files to Modify:**
- `lib/services/odds_api_service.dart`
- `lib/models/game_model.dart`

**Deliverable:** Updated models with season metadata

---

### **Phase 3: Service Layer Logic (Day 2)**
**Priority:** High
**Estimated Time:** 6 hours

**Tasks:**
1. ✅ Implement `_getEndpointsForSport()` method
2. ✅ Implement `_fetchOddsFromEndpoint()` helper
3. ✅ Update `getSportOdds()` for multi-endpoint aggregation
4. ✅ Update `getMatchOdds()` with multi-endpoint search
5. ✅ Update `getSportGames()` to include season metadata
6. ✅ Add date-based filtering logic
7. ✅ Add deduplication logic (prevent same event appearing twice)

**Files to Modify:**
- `lib/services/odds_api_service.dart` (major refactor)

**Deliverable:** Working multi-endpoint odds fetching

---

### **Phase 4: UI Badge Component (Day 3)**
**Priority:** Medium
**Estimated Time:** 3 hours

**Tasks:**
1. ✅ Create `SeasonTypeBadge` widget
2. ✅ Add color/icon mapping for each season type
3. ✅ Test badge in isolation (Storybook/preview)
4. ✅ Add badge to game cards
5. ✅ Add badge to bet selection header
6. ✅ Add badge to game details screen

**Files to Create:**
- `lib/widgets/season_type_badge.dart`

**Files to Modify:**
- `lib/screens/home/home_screen.dart`
- `lib/screens/betting/bet_selection_screen.dart`
- `lib/screens/game/game_details_screen.dart`

**Deliverable:** Season badges appearing in all game UIs

---

### **Phase 5: Navigation Updates (Day 3)**
**Priority:** Medium
**Estimated Time:** 2 hours

**Tasks:**
1. ✅ Update `BetSelectionScreen` constructor with season fields
2. ✅ Update all navigation calls to pass season metadata
3. ✅ Update `EdgeScreenV2` to display season badge
4. ✅ Update route argument parsing in `main.dart`

**Files to Modify:**
- `lib/screens/betting/bet_selection_screen.dart`
- `lib/screens/premium/edge_screen_v2.dart`
- `lib/main.dart`
- All files that navigate to bet selection

**Deliverable:** Season metadata flowing through navigation

---

### **Phase 6: Testing & Validation (Day 4)**
**Priority:** High
**Estimated Time:** 4 hours

**Tasks:**
1. ✅ Run all test cases listed in Part 5
2. ✅ Test with live NBA preseason games (Oct 2-4)
3. ✅ Verify badge colors match design
4. ✅ Check performance (multi-endpoint calls should be fast)
5. ✅ Test quota usage (multiple endpoint calls count toward limit)
6. ✅ Verify backward compatibility (non-configured sports still work)
7. ✅ Test edge cases:
   - Game right at season boundary (Oct 15 → Oct 21)
   - Date unknown (should check all endpoints)
   - Invalid sport name

**Deliverable:** All test cases passing

---

### **Phase 7: Documentation (Day 4)**
**Priority:** Medium
**Estimated Time:** 2 hours

**Tasks:**
1. ✅ Update `odds_api_service.dart` code comments
2. ✅ Document season type enum values
3. ✅ Create developer guide for adding new sports
4. ✅ Update README with preseason support info
5. ✅ Add inline examples in code

**Deliverable:** Complete documentation

---

## 📋 Part 7: Rollout Plan

### **Rollout Strategy**

**Stage 1: Soft Launch (NBA Only)**
- Enable multi-endpoint for NBA only
- Monitor for issues during Oct 2-15 preseason
- Gather user feedback on badge visibility
- Check quota usage patterns

**Stage 2: Expand to Other Sports**
- Add NFL preseason support (if endpoint exists)
- Add NHL preseason support (if endpoint exists)
- Add MLB spring training (future)

**Stage 3: Full Production**
- Enable for all verified sports
- Remove legacy single-endpoint fallback
- Optimize API call strategy

---

## 🎯 Part 8: Success Metrics

**Primary Goals:**
1. ✅ **Zero missed games** - All games with odds appear in app
2. ✅ **Clear labeling** - Users understand when games are preseason
3. ✅ **Performance** - Multi-endpoint queries complete in <2s
4. ✅ **Accuracy** - 100% correct endpoint selection by date

**Monitoring:**
- Track games found per endpoint
- Monitor API quota usage increase
- User feedback on badge clarity
- Crash rate for bet selection screen

---

## 🔧 Part 9: Potential Issues & Mitigation

### **Issue 1: Increased API Quota Usage**
**Problem:** Checking multiple endpoints uses more API calls
**Mitigation:**
- Implement smart caching (5-minute cache for sport odds)
- Use date-based filtering to skip irrelevant endpoints
- Only check preseason endpoint during preseason dates
- Aggregate results to reduce redundant calls

### **Issue 2: Endpoint Date Ranges Change**
**Problem:** NBA might extend/shorten preseason dates
**Mitigation:**
- Make date ranges configurable (not hardcoded)
- Add admin panel to update date ranges
- Fall back to checking all endpoints if date unknown
- Monitor API responses for unexpected results

### **Issue 3: New Endpoints Added**
**Problem:** Odds API adds new playoff/tournament endpoints
**Mitigation:**
- Build automated endpoint discovery
- Alert when new sport keys detected
- Make adding endpoints easy (just update config map)

### **Issue 4: Badge Visual Clutter**
**Problem:** Too many badges make UI messy
**Mitigation:**
- Only show non-regular season badges
- Make badges small and subtle
- Allow users to hide badges in settings
- A/B test badge designs

### **Issue 5: Confusion About Preseason Bets**
**Problem:** Users don't know if preseason bets count for pools
**Mitigation:**
- Add tooltip explaining preseason
- Show warning when selecting preseason game for pool
- Allow pool creators to restrict to regular season only
- Clear messaging in bet confirmation

---

## 📝 Part 10: File Change Summary

### **Files to Create:**
1. `lib/widgets/season_type_badge.dart` - Badge widget
2. `ODDS_API_ENDPOINT_MAPPING.md` - API documentation

### **Files to Modify:**
1. `lib/services/odds_api_service.dart` - Major refactor (multi-endpoint support)
2. `lib/models/game_model.dart` - Add season fields
3. `lib/screens/betting/bet_selection_screen.dart` - Add badge, update constructor
4. `lib/screens/home/home_screen.dart` - Display badges on game cards
5. `lib/screens/game/game_details_screen.dart` - Display badge
6. `lib/screens/premium/edge_screen_v2.dart` - Display badge
7. `lib/main.dart` - Update route arguments
8. All navigation callers - Pass season metadata

### **Estimated Lines of Code:**
- **New code:** ~400 lines
- **Modified code:** ~200 lines
- **Total impact:** ~600 lines across 10 files

---

## 🎉 Part 11: Final Deliverables

**Code Deliverables:**
1. ✅ Multi-endpoint odds fetching system
2. ✅ Season type badge widget
3. ✅ Updated GameModel with season metadata
4. ✅ Enhanced UI with season indicators

**Documentation Deliverables:**
1. ✅ Complete endpoint mapping document
2. ✅ Developer guide for adding new sports
3. ✅ User-facing changelog entry
4. ✅ This implementation plan

**Testing Deliverables:**
1. ✅ Test suite covering all scenarios
2. ✅ Performance benchmarks
3. ✅ Quota usage analysis

---

## 🚦 Next Steps

**Immediate Actions:**
1. Run API verification script to confirm all preseason endpoints
2. Review and approve this plan
3. Begin Phase 1 implementation
4. Set up monitoring for quota usage

**Questions to Answer:**
1. ❓ Do we want to support playoffs/postseason endpoints too?
2. ❓ Should badges be toggleable in settings?
3. ❓ Do we restrict preseason games from certain pool types?
4. ❓ What's our API quota limit and can we afford 2-3x calls?

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Ready for Implementation:** ✅ YES
