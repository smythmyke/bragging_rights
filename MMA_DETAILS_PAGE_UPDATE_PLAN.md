# MMA/UFC Details Page Update Plan

## Overview
Comprehensive plan to update the MMA/UFC details page with improved layout, rich fighter data, caching strategy, and integration with existing matching services.

## Current State Analysis
- **Location**: `bragging_rights_app/lib/screens/boxing/boxing_details_screen.dart`
- **Current Structure**: 4-tab layout (Overview, Fighters, Stats, News)
- **Data Sources**: ESPN MMA API, Boxing Service
- **Matching Service**: ESPN ID resolver service for team/fighter matching

## Proposed Changes

### 1. Simplified Single-Page Layout
**Remove the tab structure** and implement a scrollable single-page design:

```dart
// New structure for MMA details page
Column(
  children: [
    // 1. Event Header
    EventHeaderSection(
      eventName: "UFC 311",
      date: "January 19, 2025",
      venue: "Intuit Dome, Inglewood",
      eventPosterUrl: cachedPosterUrl,
    ),

    // 2. Main Event Tale of the Tape
    MainEventTaleOfTape(
      fighter1: mainEventFighter1,
      fighter2: mainEventFighter2,
      showOdds: hasOddsData,
    ),

    // 3. Full Fight Card
    FightCardSection(
      mainCard: mainCardFights,
      prelimCard: prelimFights,
      earlyPrelims: earlyPrelimFights,
    ),

    // 4. Event Information
    EventInfoSection(
      broadcast: broadcastInfo,
      venue: venueDetails,
      startTimes: timelineData,
    ),
  ],
)
```

### 2. Enhanced Fighter Data Display

#### Tale of the Tape Component
```dart
class TaleOfTheTape extends StatelessWidget {
  // Display side-by-side comparison
  // Include:
  - Fighter headshots (cached from ESPN)
  - Records (W-L-D)
  - Physical stats (Height, Weight, Reach)
  - Stance
  - Age
  - Country/Flag
  - Training camp
  - Win method breakdown (KO%, Sub%, Dec%)
  - Recent form (last 5 fights)
}
```

#### Fight Card Item Component
```dart
class FightCardItem extends StatelessWidget {
  // Compact view with expand capability
  // Shows:
  - Fighter names
  - Records
  - Weight class
  - Round format (3 or 5)
  - Title/ranking badges
  - Betting odds (if available)
  - Tap to expand for mini Tale of the Tape
}
```

### 3. Caching Strategy

#### Firestore Cache Service Integration
```dart
class MMADataCacheService {
  final FirestoreCacheService _cacheService = FirestoreCacheService();

  // Cache levels:
  // 1. Event data - 24 hours
  // 2. Fighter data - 7 days
  // 3. Fighter images - 30 days
  // 4. Historical stats - permanent

  Future<FighterData?> getCachedFighterData(String fighterId) async {
    // Check Firestore cache first
    final cached = await _cacheService.getCachedData(
      collection: 'fighter_cache',
      docId: fighterId,
      maxAge: Duration(days: 7),
    );

    if (cached != null) return FighterData.fromJson(cached);

    // Fetch from ESPN API if not cached
    final fresh = await _fetchFromESPN(fighterId);
    if (fresh != null) {
      await _cacheService.setCachedData(
        collection: 'fighter_cache',
        docId: fighterId,
        data: fresh.toJson(),
      );
    }
    return fresh;
  }

  Future<String?> getCachedFighterImage(String athleteId) async {
    // Cache fighter headshots locally and in Firebase Storage
    final imageUrl = 'https://a.espncdn.com/i/headshots/mma/players/full/$athleteId.png';

    // Check if image exists in Firebase Storage cache
    final cachedUrl = await _cacheService.getCachedImage(
      'fighters/$athleteId.png',
      originalUrl: imageUrl,
      maxAge: Duration(days: 30),
    );

    return cachedUrl;
  }
}
```

#### Cache Invalidation Rules
- Event data refreshes every 24 hours before event, every hour on event day
- Fighter stats refresh weekly
- Images cache for 30 days
- Odds data refreshes every 15 minutes when available

### 4. ESPN ID Resolver Integration

#### Maintain Existing Matching Service
```dart
class MMADetailsScreen extends StatefulWidget {
  // Keep using ESPNIdResolverService for fighter matching
  final ESPNIdResolverService _idResolver = ESPNIdResolverService();

  Future<void> _loadFightCard() async {
    // Use resolver to match fighters across different data sources
    for (final fight in fights) {
      // Resolve ESPN IDs for fighters
      final fighter1Id = await _idResolver.resolveFighterId(
        fighterName: fight.fighter1Name,
        sport: 'mma',
      );

      final fighter2Id = await _idResolver.resolveFighterId(
        fighterName: fight.fighter2Name,
        sport: 'mma',
      );

      // Load fighter data using resolved IDs
      if (fighter1Id != null) {
        fight.fighter1Data = await _cacheService.getCachedFighterData(fighter1Id);
      }

      if (fighter2Id != null) {
        fight.fighter2Data = await _cacheService.getCachedFighterData(fighter2Id);
      }
    }
  }
}
```

### 5. API Data Fetching

#### ESPN MMA API Integration
```dart
class ESPNMMAService {
  // Primary endpoints
  static const String UFC_SCOREBOARD = 'https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard';
  static const String EVENT_DETAILS = 'http://sports.core.api.espn.com/v2/sports/mma/leagues/ufc/events/';
  static const String ATHLETE_DETAILS = 'http://sports.core.api.espn.com/v2/sports/mma/athletes/';

  Future<MMAEvent?> getEventWithFights(String eventId) async {
    try {
      // 1. Get event details
      final eventResponse = await http.get(Uri.parse('$EVENT_DETAILS$eventId'));
      final eventData = json.decode(eventResponse.body);

      // 2. Extract competitions (fights)
      final List<Competition> fights = [];
      if (eventData['competitions'] != null) {
        for (final comp in eventData['competitions']) {
          // Fetch detailed competition data
          final compUrl = comp['\$ref'];
          final compResponse = await http.get(Uri.parse(compUrl));
          final compData = json.decode(compResponse.body);

          // Extract fighter IDs and fetch details
          final competitors = compData['competitors'] ?? [];
          for (final competitor in competitors) {
            final athleteRef = competitor['athlete']['\$ref'];
            // Cache this athlete data
            await _fetchAndCacheAthlete(athleteRef);
          }

          fights.add(Competition.fromJson(compData));
        }
      }

      return MMAEvent(
        id: eventId,
        name: eventData['name'],
        date: eventData['date'],
        fights: fights,
        venue: eventData['venue'],
      );
    } catch (e) {
      print('Error fetching MMA event: $e');
      return null;
    }
  }
}
```

### 6. Visual Design Updates

#### Color Scheme
```dart
class MMATheme {
  // Corner colors
  static const Color redCorner = Color(0xFFDC2626);
  static const Color blueCorner = Color(0xFF2563EB);

  // Event tier colors
  static const Color mainEvent = Color(0xFFFFD700); // Gold
  static const Color titleFight = Color(0xFFFFA500); // Orange
  static const Color mainCard = AppTheme.neonGreen;
  static const Color prelims = AppTheme.primaryCyan;
  static const Color earlyPrelims = AppTheme.surfaceBlue;

  // Status indicators
  static const Color champion = Color(0xFFFFD700);
  static const Color ranked = Color(0xFF8B4513);
}
```

#### Component Styling
```dart
// Main Event Card
Container(
  decoration: BoxDecoration(
    gradient: LinearGradient(
      colors: [MMATheme.mainEvent.withOpacity(0.2), Colors.transparent],
    ),
    border: Border.all(color: MMATheme.mainEvent, width: 2),
    borderRadius: BorderRadius.circular(16),
  ),
  child: MainEventTaleOfTape(...),
)

// Fighter Card with Corner Colors
Row(
  children: [
    // Red Corner Fighter
    Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            left: BorderSide(color: MMATheme.redCorner, width: 4),
          ),
        ),
        child: FighterInfo(fighter: redCornerFighter),
      ),
    ),

    // VS Badge
    Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.surfaceBlue,
        shape: BoxShape.circle,
      ),
      child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
    ),

    // Blue Corner Fighter
    Expanded(
      child: Container(
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: MMATheme.blueCorner, width: 4),
          ),
        ),
        child: FighterInfo(fighter: blueCornerFighter),
      ),
    ),
  ],
)
```

### 7. Data Models

#### Enhanced Fighter Model
```dart
class MMAFighter {
  final String id;
  final String name;
  final String? nickname;
  final String record; // "25-3-0"
  final int wins;
  final int losses;
  final int draws;
  final int knockouts;
  final int submissions;
  final int decisions;

  // Physical attributes
  final String? height; // "5'11\""
  final String? weight; // "155 lbs"
  final String? reach; // "72\""
  final String? stance; // "Orthodox"
  final int? age;

  // Additional info
  final String? country;
  final String? flagUrl;
  final String? headshotUrl;
  final String? camp; // Training camp/team
  final List<String>? fightStyles; // ["Wrestling", "BJJ"]
  final String? weightClass;
  final int? ranking;
  final bool isChampion;

  // Recent fights
  final List<RecentFight>? recentFights;

  // Cached data
  final DateTime? lastUpdated;
  final String? espnId;
}
```

#### Fight Card Model
```dart
class MMAFight {
  final String id;
  final MMAFighter fighter1;
  final MMAFighter fighter2;
  final String weightClass;
  final int rounds; // 3 or 5
  final bool isMainEvent;
  final bool isTitleFight;
  final String cardPosition; // "main", "prelim", "early"
  final int? fightOrder; // Position on card

  // Betting data (if available)
  final double? fighter1Odds;
  final double? fighter2Odds;

  // Result (post-fight)
  final String? winner;
  final String? method; // "KO", "TKO", "Submission", "Decision"
  final int? endRound;
  final String? endTime;
}
```

### 8. Implementation Steps

#### Phase 1: Data Layer (Day 1)
1. Create `MMADataCacheService` with Firestore integration
2. Update `ESPNMMAService` with fighter data fetching
3. Integrate with existing `ESPNIdResolverService`
4. Set up cache invalidation rules

#### Phase 2: Models & Services (Day 2)
1. Create enhanced `MMAFighter` and `MMAFight` models
2. Update `BoxingService` to handle MMA events
3. Implement fighter image caching
4. Add odds data integration points

#### Phase 3: UI Components (Day 3-4)
1. Build `MainEventTaleOfTape` component
2. Create `FightCardSection` with expandable items
3. Implement `EventHeaderSection`
4. Add `EventInfoSection` for venue/broadcast

#### Phase 4: Screen Integration (Day 5)
1. Refactor `boxing_details_screen.dart` to single-page layout
2. Remove tab controller and tab views
3. Integrate all new components
4. Add loading states and error handling

#### Phase 5: Testing & Optimization (Day 6)
1. Test with real UFC event data
2. Optimize image loading and caching
3. Add pull-to-refresh functionality
4. Performance testing with large fight cards

### 9. Performance Considerations

#### Image Optimization
```dart
// Use cached network images with placeholders
CachedNetworkImage(
  imageUrl: await _cacheService.getCachedFighterImage(fighter.espnId),
  placeholder: (context, url) => ShimmerEffect(),
  errorWidget: (context, url, error) => FighterAvatarPlaceholder(),
  fadeInDuration: Duration(milliseconds: 200),
  memCacheWidth: 150, // Optimize memory usage
)
```

#### Lazy Loading
```dart
// Load fight details on demand
ListView.builder(
  itemCount: fights.length,
  itemBuilder: (context, index) {
    return FutureBuilder<MMAFight>(
      future: _loadFightDetails(fights[index]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          return FightCardItem(fight: snapshot.data!);
        }
        return FightCardItemSkeleton(); // Shimmer placeholder
      },
    );
  },
)
```

### 10. Error Handling

#### Graceful Degradation
```dart
// Fallback to basic info if detailed data unavailable
Widget _buildFighterInfo(MMAFighter? fighter, String fallbackName, String? fallbackRecord) {
  if (fighter != null && fighter.hasFullData) {
    return FullFighterCard(fighter: fighter);
  } else if (fighter != null) {
    return BasicFighterCard(
      name: fighter.name,
      record: fighter.record,
    );
  } else {
    return MinimalFighterCard(
      name: fallbackName,
      record: fallbackRecord ?? 'Record unavailable',
    );
  }
}
```

### 11. Testing Checklist

- [ ] Event loads with all fights displayed
- [ ] Fighter images cache and display correctly
- [ ] Tale of the Tape shows accurate comparisons
- [ ] Fight cards expand/collapse smoothly
- [ ] Offline mode shows cached data
- [ ] Pull-to-refresh updates event data
- [ ] ESPN ID resolver matches fighters correctly
- [ ] Cache invalidation works as expected
- [ ] Loading states display appropriately
- [ ] Error states handle API failures gracefully

### 12. Future Enhancements

1. **Live Fight Updates**: WebSocket integration for real-time results
2. **Fighter Comparison Tool**: Select any two fighters to compare
3. **Historical Data**: Previous fights between opponents
4. **Social Integration**: Fighter tweets and Instagram posts
5. **Prediction System**: AI-based fight predictions
6. **AR Features**: View fighter stats in AR
7. **Voice Navigation**: "Show me the main event"

## Notes

- Keep existing `BoxingService` and extend for MMA support
- Maintain `ESPNIdResolverService` for fighter matching
- Cache aggressively to reduce API calls
- Design for offline-first experience
- Prioritize main event and main card visibility
- Use shimmer effects during loading for better UX

---

*Document Version: 1.0*
*Created: January 2025*
*Last Updated: January 2025*