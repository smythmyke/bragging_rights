# NBA Endpoint Verification Results
**API Verification Completed**

**Date:** October 2, 2025
**Status:** ✅ VERIFIED

---

## 📊 Available NBA Endpoints

### 1. **basketball_nba_preseason** ✅
- **Title:** NBA Preseason
- **Active:** Yes
- **Has Outrights:** No
- **Current Games:** 3
- **Date Range:** October 2-4, 2025
- **Purpose:** Preseason/exhibition games

**Games Found:**
1. Philadelphia 76ers @ New York Knicks - Oct 2, 2025 16:00 UTC
2. Melbourne United @ New Orleans Pelicans - Oct 3, 2025 09:30 UTC
3. Phoenix Suns @ Los Angeles Lakers - Oct 4, 2025 02:00 UTC

**Odds Available:** ✅ Full odds (Moneyline, Spread, Totals)
**Bookmakers:** DraftKings, BetRivers, FanDuel, Caesars, MyBookie.ag

---

### 2. **basketball_nba** ✅
- **Title:** NBA
- **Active:** Yes
- **Has Outrights:** No
- **Current Games:** 44
- **Date Range:** October 21, 2025 - January 20, 2026
- **Purpose:** Regular season games

**First Game:** Houston Rockets @ Oklahoma City Thunder - Oct 21, 2025 23:30 UTC
**Last Game:** Boston Celtics @ Detroit Pistons - Jan 20, 2026 01:00 UTC

**Odds Available:** ✅ Full odds (Moneyline, Spread, Totals)

---

### 3. **basketball_nba_championship_winner** ✅
- **Title:** NBA Championship Winner
- **Active:** Yes
- **Has Outrights:** Yes (Futures betting)
- **Purpose:** Championship futures

---

### 4. **basketball_wnba** ✅
- **Title:** WNBA
- **Active:** Yes
- **Has Outrights:** No
- **Purpose:** Women's NBA

---

## 🎯 Key Findings

### **Date Gap Confirmed:**
- ❌ **Gap:** October 5-20, 2025 (15 days with no NBA games in either endpoint)
- ✅ **Preseason:** October 2-4, 2025
- ✅ **Regular Season:** October 21, 2025 onwards

### **Endpoint Separation Confirmed:**
- The 76ers-Knicks game (Oct 2) is **ONLY** in `basketball_nba_preseason`
- It does **NOT** appear in `basketball_nba`
- Our app currently only checks `basketball_nba`
- **This is why the bet selection page was empty!**

---

## 📋 Implementation Requirements for NBA

### **Minimum Viable Fix:**
```dart
// Current mapping
'nba': 'basketball_nba'

// Updated mapping (multi-endpoint)
'nba': [
  {
    key: 'basketball_nba_preseason',
    type: 'preseason',
    label: 'PRESEASON',
    dateRange: {start: '2025-10-01', end: '2025-10-15'},
    priority: 1
  },
  {
    key: 'basketball_nba',
    type: 'regularSeason',
    label: null,
    dateRange: {start: '2025-10-15', end: '2026-06-30'},
    priority: 2
  }
]
```

### **Search Strategy:**
1. User opens 76ers @ Knicks game (Oct 2, 2025)
2. Service checks date: October 2
3. Date falls in preseason range (Oct 1-15)
4. Query `basketball_nba_preseason` first (priority 1)
5. Match found! Return odds with `seasonLabel: 'PRESEASON'`
6. If not found, fallback to `basketball_nba` (priority 2)

---

## ✅ Next Steps

### **Phase 2: Data Structure Updates**

**Step 1: Create supporting classes** in `odds_api_service.dart`:

```dart
enum SportSeasonType {
  preseason,
  regularSeason,
  playoffs,
  postseason,
  futures,
}

class DateRange {
  final DateTime start;
  final DateTime end;

  const DateRange({required this.start, required this.end});

  bool contains(DateTime date) {
    return date.isAfter(start) && date.isBefore(end);
  }
}

class SportEndpoint {
  final String key;
  final SportSeasonType type;
  final int priority;
  final String? label;
  final DateRange? dateRange;

  const SportEndpoint({
    required this.key,
    required this.type,
    required this.priority,
    this.label,
    this.dateRange,
  });

  bool appliesToDate(DateTime date) {
    if (dateRange == null) return true;
    return dateRange!.contains(date);
  }
}
```

**Step 2: Create NBA endpoint configuration**:

```dart
static const List<SportEndpoint> _nbaEndpoints = [
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
    label: null, // No label for regular season
    dateRange: DateRange(
      start: DateTime(2025, 10, 15),
      end: DateTime(2026, 6, 30),
    ),
  ),
];
```

**Step 3: Update mapping**:

```dart
// Replace single string mapping
static const Map<String, String> _sportKeys = {
  'nba': 'basketball_nba',  // OLD
};

// With multi-endpoint mapping
static const Map<String, List<SportEndpoint>> _sportEndpoints = {
  'nba': _nbaEndpoints,  // NEW
};
```

---

## 🧪 Test Plan

### **Test Case 1: 76ers-Knicks Preseason Game**
```
Input:
  - Sport: 'nba'
  - Home: 'New York Knicks'
  - Away: 'Philadelphia 76ers'
  - Date: October 2, 2025

Expected Output:
  ✅ Endpoint used: basketball_nba_preseason
  ✅ Event ID: 8dfa5b85ce84a573ea3c5ccf6c31dad2
  ✅ Season type: 'preseason'
  ✅ Season label: 'PRESEASON'
  ✅ Odds available: ML, Spread, Totals
```

### **Test Case 2: Rockets-Thunder Regular Season**
```
Input:
  - Sport: 'nba'
  - Home: 'Oklahoma City Thunder'
  - Away: 'Houston Rockets'
  - Date: October 21, 2025

Expected Output:
  ✅ Endpoint used: basketball_nba
  ✅ Season type: 'regularSeason'
  ✅ Season label: null (no badge)
  ✅ Odds available: ML, Spread, Totals
```

### **Test Case 3: Unknown Date Fallback**
```
Input:
  - Sport: 'nba'
  - Home: 'New York Knicks'
  - Away: 'Philadelphia 76ers'
  - Date: null (unknown)

Expected Behavior:
  ✅ Check basketball_nba_preseason first (priority 1)
  ✅ If not found, check basketball_nba (priority 2)
  ✅ Return first match found
```

---

## 📈 Expected Impact

### **Before Fix:**
- NBA preseason games: 0% coverage (bet selection empty)
- User frustration: High
- Lost betting opportunities: 3 games (Oct 2-4)

### **After Fix:**
- NBA preseason games: 100% coverage
- Badge shown: "PRESEASON" in amber
- Users understand game context
- Full odds available

---

## 🚀 Ready to Implement

**Verified Endpoints:** ✅ 3/3 NBA endpoints working
**Date Ranges:** ✅ Confirmed via API
**Test Cases:** ✅ Defined
**Architecture:** ✅ Designed

**Status:** READY TO CODE

**Next Step:** Begin Phase 2 implementation in `odds_api_service.dart`
