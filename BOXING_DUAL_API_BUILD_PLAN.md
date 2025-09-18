# Boxing Integration Build Plan - Dual API Strategy

## Overview
Implement boxing support using **Boxing Data API** (primary) with **ESPN API** (fallback), with conditional UI based on data availability.

## API Strategy

### Primary: Boxing Data API (Cached)
- **Usage:** Read from Firestore cache (updated daily via Cloud Function)
- **Data Available:** Events, fight cards, fighter profiles, divisions, titles
- **UI:** Full 4-tab details page

### Fallback: ESPN API (Direct)
- **Usage:** When Boxing Data cache is stale or unavailable
- **Data Available:** Basic event info, limited fighter data
- **UI:** Reduced 2-tab details page

## Data Models

### 1. Boxing Event Model
```dart
// lib/models/boxing_event_model.dart
class BoxingEvent {
  final String id;
  final String title;
  final DateTime date;
  final String venue;
  final String location;
  final String? posterUrl;
  final String promotion;
  final List<String> broadcasters;
  final DataSource source; // 'boxing_data' or 'espn'
  final bool hasFullData; // true for Boxing Data, false for ESPN

  // Additional fields only from Boxing Data API
  final List<String>? ringAnnouncers;
  final List<String>? tvAnnouncers;
  final List<String>? coPromotions;

  bool get canShowFullDetails => source == DataSource.boxingData;
}
```

### 2. Boxing Fight Model
```dart
// lib/models/boxing_fight_model.dart
class BoxingFight {
  final String id;
  final String title;
  final String eventId;
  final Map<String, Fighter> fighters;
  final String division;
  final int scheduledRounds;
  final List<String> titles;
  final int cardPosition; // 1 = main event
  final FightStatus status;

  bool get isMainEvent => cardPosition == 1;
  bool get isTitleFight => titles.isNotEmpty;
}
```

### 3. Boxing Fighter Model
```dart
// lib/models/boxing_fighter_model.dart
class BoxingFighter {
  final String id;
  final String name;
  final String? nickname;
  final String nationality;
  final BoxingStats stats;
  final PhysicalAttributes physical;
  final String? division;
  final List<String> titles;
  final DataSource source;
}
```

## Service Implementation

### 1. Boxing Service (Main Coordinator)
```dart
// lib/services/boxing_service.dart
class BoxingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final BoxingDataApiService _boxingDataApi = BoxingDataApiService();
  final ESPNBoxingService _espnApi = ESPNBoxingService();

  Future<List<BoxingEvent>> getUpcomingEvents() async {
    try {
      // Try Firestore cache first (Boxing Data API cached data)
      final cacheData = await _getFromCache();
      if (cacheData != null && _isCacheFresh(cacheData)) {
        return cacheData.map((e) => BoxingEvent.fromBoxingData(e)).toList();
      }

      // Fallback to ESPN if cache is stale
      print('Boxing Data cache stale, falling back to ESPN');
      final espnData = await _espnApi.getBoxingEvents();
      return espnData.map((e) => BoxingEvent.fromESPN(e)).toList();
    } catch (e) {
      print('Error fetching boxing events: $e');
      return [];
    }
  }

  Future<BoxingEventDetails?> getEventDetails(String eventId, DataSource source) async {
    if (source == DataSource.boxingData) {
      // Get full data from cache
      return await _getFullEventFromCache(eventId);
    } else {
      // Get limited data from ESPN
      return await _espnApi.getEventBasics(eventId);
    }
  }

  Future<List<BoxingFight>?> getFightCard(String eventId) async {
    // Only available from Boxing Data cache
    try {
      final fights = await _firestore
          .collection('boxing_fights')
          .where('eventId', isEqualTo: eventId)
          .orderBy('cardPosition')
          .get();

      if (fights.docs.isEmpty) return null;

      return fights.docs
          .map((doc) => BoxingFight.fromFirestore(doc))
          .toList();
    } catch (e) {
      return null;
    }
  }

  bool _isCacheFresh(dynamic cacheData) {
    // Check if cache is less than 24 hours old
    final lastUpdated = cacheData['lastUpdated'] as Timestamp;
    final hoursSinceUpdate = DateTime.now()
        .difference(lastUpdated.toDate())
        .inHours;
    return hoursSinceUpdate < 24;
  }
}
```

### 2. Boxing Data API Service (Cache Reader)
```dart
// lib/services/boxing_data_api_service.dart
class BoxingDataApiService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Read from Firestore cache only - no direct API calls
  Future<List<Map<String, dynamic>>> getCachedEvents() async {
    final snapshot = await _firestore
        .collection('boxing_events')
        .where('date', isGreaterThan: Timestamp.now())
        .orderBy('date')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => doc.data()).toList();
  }

  Future<BoxingFighter?> getCachedFighter(String fighterId) async {
    final doc = await _firestore
        .collection('boxing_fighters')
        .doc(fighterId)
        .get();

    if (!doc.exists) return null;
    return BoxingFighter.fromFirestore(doc);
  }
}
```

### 3. ESPN Boxing Service (Direct API)
```dart
// lib/services/espn_boxing_service.dart
class ESPNBoxingService {
  static const String baseUrl = 'https://site.api.espn.com/apis/site/v2/sports/mma';

  Future<List<dynamic>> getBoxingEvents() async {
    try {
      final response = await http.get(
        Uri.parse('$baseUrl/boxing/scoreboard'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['events'] ?? [];
      }
      return [];
    } catch (e) {
      print('ESPN API error: $e');
      return [];
    }
  }
}
```

## UI Implementation

### 1. Boxing Details Screen (Adaptive)
```dart
// lib/screens/boxing/boxing_details_screen.dart
class BoxingDetailsScreen extends StatefulWidget {
  final BoxingEvent event;

  @override
  _BoxingDetailsScreenState createState() => _BoxingDetailsScreenState();
}

class _BoxingDetailsScreenState extends State<BoxingDetailsScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<BoxingFight>? _fightCard;
  bool _isLoadingFights = true;

  @override
  void initState() {
    super.initState();
    // Dynamic tab count based on data availability
    final tabCount = widget.event.hasFullData ? 4 : 2;
    _tabController = TabController(length: tabCount, vsync: this);

    if (widget.event.hasFullData) {
      _loadFightCard();
    }
  }

  Future<void> _loadFightCard() async {
    final fights = await BoxingService().getFightCard(widget.event.id);
    setState(() {
      _fightCard = fights;
      _isLoadingFights = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.codGray,
      appBar: AppBar(
        title: Text(widget.event.title),
        backgroundColor: AppTheme.raisinBlack,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.neonGreen,
          tabs: _buildTabs(),
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: _buildTabViews(),
      ),
    );
  }

  List<Tab> _buildTabs() {
    if (widget.event.hasFullData) {
      return [
        Tab(text: 'FIGHT CARD'),
        Tab(text: 'EVENT INFO'),
        Tab(text: 'FIGHTERS'),
        Tab(text: 'HOW TO WATCH'),
      ];
    } else {
      // ESPN fallback - limited tabs
      return [
        Tab(text: 'EVENT INFO'),
        Tab(text: 'PREVIEW'),
      ];
    }
  }

  List<Widget> _buildTabViews() {
    if (widget.event.hasFullData) {
      return [
        _FightCardTab(fights: _fightCard, isLoading: _isLoadingFights),
        _EventInfoTab(event: widget.event),
        _FightersTab(fights: _fightCard),
        _BroadcastTab(event: widget.event),
      ];
    } else {
      // ESPN fallback - limited views
      return [
        _BasicEventInfoTab(event: widget.event),
        _ESPNPreviewTab(event: widget.event),
      ];
    }
  }
}
```

### 2. Fight Card Tab (Boxing Data Only)
```dart
// lib/screens/boxing/tabs/fight_card_tab.dart
class _FightCardTab extends StatelessWidget {
  final List<BoxingFight>? fights;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return Center(child: CircularProgressIndicator());
    }

    if (fights == null || fights!.isEmpty) {
      return Center(
        child: Text('Fight card not available',
          style: TextStyle(color: AppTheme.lightGray)),
      );
    }

    return ListView.builder(
      padding: EdgeInsets.all(16),
      itemCount: fights!.length,
      itemBuilder: (context, index) {
        final fight = fights![index];
        return Card(
          color: AppTheme.darkGray,
          margin: EdgeInsets.only(bottom: 12),
          child: Container(
            decoration: BoxDecoration(
              border: fight.isMainEvent
                ? Border.all(color: AppTheme.neonGreen, width: 2)
                : null,
              borderRadius: BorderRadius.circular(8),
            ),
            child: ListTile(
              title: Row(
                children: [
                  if (fight.isMainEvent)
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppTheme.neonGreen,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text('MAIN EVENT',
                        style: TextStyle(
                          color: AppTheme.raisinBlack,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(fight.title,
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('${fight.division} • ${fight.scheduledRounds} rounds',
                    style: TextStyle(color: AppTheme.lightGray),
                  ),
                  if (fight.isTitleFight)
                    Text(fight.titles.first,
                      style: TextStyle(
                        color: AppTheme.gold,
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
```

## Cloud Function Implementation

```javascript
// functions/updateBoxingCache.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

exports.dailyBoxingUpdate = functions.pubsub
  .schedule('0 3 * * *') // Daily at 3 AM EST
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const db = admin.firestore();

    // Check API usage
    const metadata = await db.doc('boxing_cache/metadata').get();
    const { apiCallsThisMonth, lastUpdated } = metadata.data();

    if (apiCallsThisMonth >= 95) {
      console.log('Approaching API limit, skipping update');
      return null;
    }

    const headers = {
      'x-rapidapi-host': 'boxing-data-api.p.rapidapi.com',
      'x-rapidapi-key': functions.config().boxing.api_key
    };

    try {
      // 1. Get next 7 days of events (1 API call)
      const eventsResponse = await axios.get(
        'https://boxing-data-api.p.rapidapi.com/v1/events/schedule?days=7',
        { headers }
      );

      const batch = db.batch();
      const now = admin.firestore.FieldValue.serverTimestamp();

      // 2. Store events
      for (const event of eventsResponse.data) {
        const eventRef = db.doc(`boxing_events/${event.id}`);
        batch.set(eventRef, {
          ...event,
          lastUpdated: now,
          source: 'boxing_data',
          hasFullData: true,
        }, { merge: true });
      }

      // 3. Update metadata
      batch.update(db.doc('boxing_cache/metadata'), {
        lastUpdated: now,
        apiCallsThisMonth: admin.firestore.FieldValue.increment(1),
        nextUpdate: new Date(Date.now() + 24 * 60 * 60 * 1000), // Tomorrow
      });

      await batch.commit();
      console.log('Boxing cache updated successfully');

    } catch (error) {
      console.error('Failed to update boxing cache:', error);
      // Log error to Firestore for monitoring
      await db.collection('errors').add({
        service: 'boxing_update',
        error: error.message,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
      });
    }
  });

// Reset monthly counter
exports.resetBoxingApiCounter = functions.pubsub
  .schedule('0 0 1 * *') // First of each month
  .onRun(async (context) => {
    await admin.firestore().doc('boxing_cache/metadata').update({
      apiCallsThisMonth: 0,
      monthStarted: admin.firestore.FieldValue.serverTimestamp(),
    });
  });
```

## Implementation Steps

### Phase 1: Data Layer (Day 1-2)
1. Create boxing data models
2. Set up Firestore collections and rules
3. Deploy Cloud Functions for caching
4. Test API integration

### Phase 2: Service Layer (Day 3)
1. Implement BoxingService with dual API support
2. Create cache management logic
3. Add fallback handling
4. Test data flow

### Phase 3: UI Implementation (Day 4-5)
1. Build adaptive BoxingDetailsScreen
2. Create conditional tab system
3. Implement fight card display
4. Add loading and error states

### Phase 4: Integration (Day 6)
1. Connect to main sports navigation
2. Add boxing to sports list
3. Test full flow
4. Handle edge cases

### Phase 5: Testing & Polish (Day 7)
1. Test with stale cache scenarios
2. Verify ESPN fallback works
3. UI polish and animations
4. Performance optimization

## File Structure
```
bragging_rights_app/
├── lib/
│   ├── models/
│   │   ├── boxing_event_model.dart
│   │   ├── boxing_fight_model.dart
│   │   └── boxing_fighter_model.dart
│   ├── services/
│   │   ├── boxing_service.dart
│   │   ├── boxing_data_api_service.dart
│   │   └── espn_boxing_service.dart
│   ├── screens/
│   │   └── boxing/
│   │       ├── boxing_details_screen.dart
│   │       └── tabs/
│   │           ├── fight_card_tab.dart
│   │           ├── event_info_tab.dart
│   │           ├── fighters_tab.dart
│   │           └── broadcast_tab.dart
└── functions/
    └── updateBoxingCache.js
```

## Success Metrics
- ✅ Boxing events load within 2 seconds
- ✅ Graceful fallback to ESPN when cache stale
- ✅ API usage stays under 100 calls/month
- ✅ UI adapts based on data availability
- ✅ No empty tabs shown to users

## Notes
- Always read from Firestore cache for Boxing Data API
- Never make direct Boxing Data API calls from the app
- ESPN fallback provides basic functionality
- Consider upgrade to paid tier if users need full features