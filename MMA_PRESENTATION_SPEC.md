# MMA Event Presentation Specification
## Test HTML vs Current App Implementation

### Document Purpose
This document tracks the ideal MMA event presentation shown in `mma_events_test_interactive.html` versus the current app implementation, and provides an action plan for updates.

---

## 1. TEST HTML PRESENTATION (IDEAL STATE)

### Event List View
- **Promotion Badge**: Color-coded by promotion (PFL=Blue, UFC=Red, Bellator=Orange, ONE=Purple)
- **Event Date**: Clearly displayed next to promotion
- **Event Name**: Full event name with location/number
- **Main Event**: Fighter names prominently displayed
- **Fight Count**: Total number of fights on card

### Event Details View (Modal)
#### Header Section
- **Event Title**: Full event name (e.g., "PFL Europe 3: Nantes 2025")
- **Event Info**: Date and venue combined (e.g., "September 26, 2025 • Zenith Nantes, France")

#### Fight Card Sections
**Main Card:**
- Title: "MAIN CARD" in green (#00ff88)
- Broadcast info: Right-aligned (e.g., "DAZN PPV", "ESPN+ PPV")
- Each fight shows:
  - Fighter names with "vs" separator
  - Weight class
  - Special badges: "MAIN EVENT", "TITLE FIGHT"
  - Championship indicator (🏆)

**Preliminary Card:**
- Title: "PRELIMINARY CARD" in cyan (#00bcd4)
- Broadcast info: Right-aligned (e.g., "DAZN", "ESPN", "PFL App")
- Same fight details as main card

**Early Prelims (when applicable):**
- Title: "EARLY PRELIMS" in grey
- Broadcast info: Right-aligned (e.g., "ESPN+", "UFC Fight Pass")

### Promotion-Specific Broadcasts
```javascript
PFL: { main: "DAZN PPV", prelim: "DAZN" or "PFL App" }
UFC: { main: "ESPN+ PPV", prelim: "ESPN", early: "ESPN+" }
Bellator: { main: "MAX", prelim: "Bellator App" }
ONE: { main: "Amazon Prime", prelim: "ONE App" }
```

---

## 2. CURRENT APP IMPLEMENTATION

### Event List View (`optimized_games_screen.dart`)
✅ **Working:**
- Promotion badge with color coding
- Event date display
- Main event fighters
- Fight count

❌ **Issues:**
- Event name not always complete
- Missing specific event numbers/locations for some promotions
- Generic "Event" naming for time-grouped fights

### Event Details View (`mma_details_screen.dart`)
✅ **Working:**
- Main Card/Prelims/Early Prelims separation
- Fight order (reversed to show main event first)
- Weight class display
- Title fight detection

❌ **Issues:**
- **Generic broadcast assignments**: Always defaults to ESPN+/ESPN
- **No promotion-specific broadcasts**: Missing DAZN for PFL, MAX for Bellator, Prime for ONE
- **Broadcast data not fetched**: Only uses generic fallbacks
- **Missing fight badges**: No visual "MAIN EVENT" or "TITLE FIGHT" badges

---

## 3. DATA FLOW COMPARISON

### Test HTML (Static)
```javascript
eventData = {
  title, date, venue,
  mainCard: [...fights],
  prelims: [...fights],
  broadcast: { main: "DAZN PPV", prelim: "DAZN" }
}
```

### Current App (Dynamic)
```dart
// Data sources:
1. Odds API → Basic fight info (fighters, time)
2. ESPN API → Event structure, some broadcasts
3. Firestore cache → Previous data

// Problems:
- Broadcast data rarely provided by APIs
- Falls back to hardcoded ESPN+/ESPN
- No promotion-specific logic for broadcasts
```

---

## 4. ACTION PLAN FOR UPDATES

### Phase 1: Broadcast Information
**File:** `lib/services/mma_service.dart`

#### Add Promotion-Specific Broadcast Logic
```dart
Map<String, Map<String, String>> _getPromotionBroadcasts(String promotion, bool isPPV) {
  switch (promotion.toUpperCase()) {
    case 'PFL':
      return {
        'main': isPPV ? 'DAZN PPV' : 'DAZN',
        'prelim': 'PFL App',
      };
    case 'UFC':
      return {
        'main': isPPV ? 'ESPN+ PPV' : 'ESPN+',
        'prelim': 'ESPN',
        'early': 'ESPN+',
      };
    case 'BELLATOR':
      return {
        'main': 'MAX',
        'prelim': 'Bellator App',
      };
    case 'ONE':
      return {
        'main': 'Amazon Prime',
        'prelim': 'ONE App',
      };
    default:
      return {'main': 'PPV', 'prelim': 'Streaming'};
  }
}
```

### Phase 2: Update MMAEvent Model
**File:** `lib/models/mma_event_model.dart`

#### Add Broadcast Structure
```dart
class MMAEvent {
  // Add:
  final Map<String, String>? broadcastByCard; // {'main': 'DAZN PPV', 'prelim': 'DAZN'}

  // Update broadcasters to be more structured
  List<String> get allBroadcasters {
    if (broadcastByCard != null) {
      return broadcastByCard!.values.toSet().toList();
    }
    return broadcasters ?? [];
  }
}
```

### Phase 3: Update Details Screen
**File:** `lib/screens/mma/mma_details_screen.dart`

#### Update _buildCardSection
```dart
Widget _buildCardSection({
  required String title,
  required List<MMAFight> fights,
  required Color color,
  String? broadcast,
}) {
  // Get proper broadcast based on promotion and card type
  final actualBroadcast = _getBroadcastForCard(title);

  // Add visual badges for fights
  // Add proper broadcast display
}
```

#### Add Fight Badges
```dart
Widget _buildFightBadges(MMAFight fight) {
  return Row(
    children: [
      if (fight.isMainEvent)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red, Colors.orange]),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('MAIN EVENT', style: TextStyle(fontSize: 10)),
        ),
      if (fight.isTitleFight)
        Container(
          padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.yellow, Colors.orange]),
            borderRadius: BorderRadius.circular(4),
          ),
          child: Text('TITLE FIGHT', style: TextStyle(fontSize: 10)),
        ),
    ],
  );
}
```

### Phase 4: Improve Event Name Display
**File:** `lib/services/optimized_games_service.dart`

#### Update Event Name Generation
```dart
// In _groupByTimeWindows and _groupCombatSportsByEvent
String _generateEventName(String promotion, DateTime date, String? eventNumber) {
  final dateStr = DateFormat('MMMM d, y').format(date);

  switch (promotion) {
    case 'PFL':
      // Try to extract event number from ESPN data
      return eventNumber != null
        ? 'PFL $eventNumber'
        : 'PFL Event - $dateStr';
    case 'UFC':
      return eventNumber != null
        ? 'UFC $eventNumber'
        : 'UFC Fight Night';
    // etc...
  }
}
```

---

## 5. TESTING CHECKLIST

### Per Promotion Testing
- [ ] **PFL Events**
  - [ ] Shows "DAZN" or "DAZN PPV" for main card
  - [ ] Shows "PFL App" for prelims
  - [ ] Event name includes number/location

- [ ] **UFC Events**
  - [ ] Shows "ESPN+ PPV" for numbered events
  - [ ] Shows "ESPN" for Fight Night prelims
  - [ ] Shows "ESPN+" for early prelims

- [ ] **Bellator Events**
  - [ ] Shows "MAX" for main card
  - [ ] Shows "Bellator App" for prelims
  - [ ] Event name includes "Champions Series" when applicable

- [ ] **ONE Championship Events**
  - [ ] Shows "Amazon Prime" for main card
  - [ ] Shows "ONE App" for prelims
  - [ ] Includes both MMA and Muay Thai fights

### Visual Elements
- [ ] Main Event badge appears on top fight
- [ ] Title Fight badge appears on championship bouts
- [ ] Weight classes display correctly
- [ ] Broadcast info aligns properly
- [ ] Card sections have correct colors

---

## 6. IMPLEMENTATION PRIORITY

1. **High Priority** (User-facing, high impact)
   - Add promotion-specific broadcast information
   - Add visual badges for main events and title fights
   - Fix event naming for better clarity

2. **Medium Priority** (Enhancement)
   - Improve broadcast data fetching from APIs
   - Add caching for broadcast information
   - Better PFL tournament format support

3. **Low Priority** (Nice to have)
   - Add fighter records to display
   - Show betting odds when available
   - Add countdown timer for upcoming events

---

## 7. NOTES

- Current implementation correctly separates fights into cards but lacks promotion-specific details
- ESPN API doesn't always provide broadcast info, requiring fallback logic
- PFL's unique tournament format may need special handling in future updates
- Consider adding a broadcast configuration file for easy updates as streaming rights change

---

*Last Updated: September 2025*
*Test File: `mma_events_test_interactive.html`*
*Target Platform: Flutter (iOS/Android)*