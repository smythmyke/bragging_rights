# Phase 2 Complete: Data Structure Updates
**NBA Preseason Support - Data Structures Implemented**

**Date:** January 2025
**Status:** ✅ COMPLETE
**Build Status:** ✅ PASSING (No errors)

---

## ✅ What Was Completed

### **1. New Supporting Classes in `odds_api_service.dart`**

**SportSeasonType Enum:**
```dart
enum SportSeasonType {
  preseason,
  regularSeason,
  playoffs,
  postseason,
  futures,
}
```
- Defines all possible season types
- Used for categorizing games
- Determines badge display

**DateRange Class:**
```dart
class DateRange {
  final DateTime start;
  final DateTime end;

  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }
}
```
- Stores date ranges for each endpoint
- `contains()` method checks if a date falls within range
- Used for smart endpoint selection

**SportEndpoint Class:**
```dart
class SportEndpoint {
  final String key;               // API endpoint key
  final SportSeasonType type;     // Season type
  final int priority;             // Check order (lower = first)
  final String? label;            // UI badge text
  final DateRange? dateRange;     // Applicable date range

  bool appliesToDate(DateTime date);
}
```
- Complete metadata for each API endpoint
- Priority determines check order (preseason=1, regular=2)
- `appliesToDate()` filters by game date

---

### **2. NBA Endpoint Configuration**

**Added to `odds_api_service.dart`:**
```dart
static final Map<String, List<SportEndpoint>> _sportEndpoints = {
  'nba': [
    SportEndpoint(
      key: 'basketball_nba_preseason',
      type: SportSeasonType.preseason,
      priority: 1,
      label: 'PRESEASON',
      dateRange: DateRange(
        start: DateTime(2025, 10, 1),
        end: DateTime(2025, 10, 15),
      ),
    ),
    SportEndpoint(
      key: 'basketball_nba',
      type: SportSeasonType.regularSeason,
      priority: 2,
      label: null, // No badge for regular season
      dateRange: DateRange(
        start: DateTime(2025, 10, 15),
        end: DateTime(2026, 6, 30),
      ),
    ),
  ],
};
```

**Key Features:**
- ✅ Preseason endpoint checked first (priority 1)
- ✅ Regular season endpoint as fallback (priority 2)
- ✅ Date ranges prevent checking wrong endpoint
- ✅ Label "PRESEASON" for UI badges

---

### **3. Smart Endpoint Selection Method**

**Added `_getEndpointsForSport()` helper method:**

```dart
List<SportEndpoint> _getEndpointsForSport(String sport, {DateTime? gameDate}) {
  final endpoints = _sportEndpoints[sport.toLowerCase()];

  if (endpoints == null || endpoints.isEmpty) {
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

**How It Works:**
1. Check if sport has multi-endpoint configuration
2. If date provided, filter endpoints by date range
3. Sort by priority (lower number = checked first)
4. Fallback to legacy mapping for unconfigured sports

**Examples:**

```dart
// Example 1: NBA game on Oct 2 (preseason)
_getEndpointsForSport('nba', gameDate: DateTime(2025, 10, 2))
// Returns: [basketball_nba_preseason] (only preseason)

// Example 2: NBA game on Oct 25 (regular season)
_getEndpointsForSport('nba', gameDate: DateTime(2025, 10, 25))
// Returns: [basketball_nba] (only regular season)

// Example 3: NBA game with no date
_getEndpointsForSport('nba')
// Returns: [basketball_nba_preseason, basketball_nba] (both, sorted by priority)

// Example 4: NFL (not yet configured)
_getEndpointsForSport('nfl')
// Returns: [americanfootball_nfl] (legacy fallback)
```

---

### **4. Updated GameModel with Season Metadata**

**Added to `game_model.dart`:**

```dart
// New fields
final String? seasonType;   // 'preseason', 'regularSeason', 'playoffs'
final String? seasonLabel;  // 'PRESEASON', 'PLAYOFFS', null for regular

// Constructor
GameModel({
  // ... existing fields
  this.seasonType,
  this.seasonLabel,
});

// fromFirestore factory
seasonType: data['seasonType'],
seasonLabel: data['seasonLabel'],

// toMap method
'seasonType': seasonType,
'seasonLabel': seasonLabel,

// toFirestore method
'seasonType': seasonType,
'seasonLabel': seasonLabel,

// fromMap factory
seasonType: map['seasonType'],
seasonLabel: map['seasonLabel'],
```

**Benefits:**
- ✅ Season metadata flows through entire app
- ✅ Stored in Firestore for persistence
- ✅ Available for UI badge display
- ✅ Backward compatible (nullable fields)

---

## 📊 Architecture Overview

### **Flow Diagram:**

```
User requests 76ers @ Knicks odds (Oct 2, 2025)
         ↓
OddsApiService.getMatchOdds()
         ↓
_getEndpointsForSport('nba', gameDate: Oct 2)
         ↓
Filters endpoints by date range
         ↓
Oct 2 falls in [Oct 1 - Oct 15]
         ↓
Returns: [basketball_nba_preseason] (priority 1 only)
         ↓
Query basketball_nba_preseason endpoint
         ↓
Match found!
         ↓
Return odds + metadata:
  {
    eventId: "8dfa5b85...",
    odds: {...},
    season_type: "preseason",
    season_label: "PRESEASON"
  }
         ↓
Create GameModel with seasonType/seasonLabel
         ↓
Display in UI with PRESEASON badge
```

---

## 🧪 Testing Readiness

### **Unit Test Scenarios:**

**Test 1: Date Filtering**
```dart
test('Filters NBA endpoints by date', () {
  final oct2 = DateTime(2025, 10, 2);
  final oct25 = DateTime(2025, 10, 25);

  final preseasonEndpoints = service._getEndpointsForSport('nba', gameDate: oct2);
  expect(preseasonEndpoints.length, 1);
  expect(preseasonEndpoints[0].key, 'basketball_nba_preseason');

  final regularEndpoints = service._getEndpointsForSport('nba', gameDate: oct25);
  expect(regularEndpoints.length, 1);
  expect(regularEndpoints[0].key, 'basketball_nba');
});
```

**Test 2: Priority Sorting**
```dart
test('Returns endpoints sorted by priority', () {
  final endpoints = service._getEndpointsForSport('nba');
  expect(endpoints[0].priority, lessThan(endpoints[1].priority));
  expect(endpoints[0].key, 'basketball_nba_preseason'); // Priority 1
  expect(endpoints[1].key, 'basketball_nba'); // Priority 2
});
```

**Test 3: Legacy Fallback**
```dart
test('Falls back to legacy mapping for unconfigured sports', () {
  final endpoints = service._getEndpointsForSport('nfl');
  expect(endpoints.length, 1);
  expect(endpoints[0].key, 'americanfootball_nfl');
  expect(endpoints[0].label, null); // No label
});
```

---

## 📝 What's Next: Phase 3

**Next Phase: Multi-Endpoint Search Logic**

We need to:
1. Update `getMatchOdds()` to query multiple endpoints
2. Update `getSportOdds()` to aggregate results
3. Add season metadata to returned odds
4. Test with live 76ers-Knicks game

**Files to Modify Next:**
- `lib/services/odds_api_service.dart` - Update `getMatchOdds()` and `getSportOdds()`

---

## ✅ Phase 2 Summary

**Completed Tasks:**
1. ✅ Created `SportSeasonType` enum
2. ✅ Created `DateRange` class
3. ✅ Created `SportEndpoint` class
4. ✅ Configured NBA endpoints (preseason + regular)
5. ✅ Implemented `_getEndpointsForSport()` helper
6. ✅ Updated `GameModel` with season fields
7. ✅ Updated all serialization methods

**Build Status:** ✅ Clean compile, no errors
**Test Coverage:** Ready for unit tests
**Documentation:** Complete inline comments

**Ready for Phase 3:** ✅ YES

---

**Phase 2 Duration:** ~30 minutes
**Lines of Code Added:** ~150 lines
**Files Modified:** 2 files
**Breaking Changes:** None (backward compatible)
