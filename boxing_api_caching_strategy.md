# Boxing Data API Caching Strategy

## API Limit Constraints (Free Tier)
- **100 calls per month** (hard limit)
- **7 Day Window** for event data
- **No access to:** All Fighters, Full Fight Cards, All Fights, Extended time windows
- **Available:** Upcoming Fights, Historic Fights, Fighter Profiles, Stats, Top Rated
- **Rate Limit:** 1000 requests/hour (not relevant with 100/month limit)
- Must serve ALL app users from cached data

## Critical Limitations Impact
⚠️ **7-Day Window means we can ONLY get events for the next week**
❌ Cannot get full fighter roster
❌ Cannot get complete fight cards
❌ Limited to featured/top-rated content

## Revised Strategy: 90-95 Calls/Month

### 1. **Daily Rolling Update Strategy (30 calls/month)**
- **Frequency:** Once daily
- **What:** Next 7 days of events (API limit)
- **Calls:** 1 call/day × 30 days = 30 calls
- **Purpose:** Keep upcoming week always fresh

### 2. **Weekly Fighter Updates (32 calls/month)**
- **Top Rated Fighters:** 2 calls/week = 8 calls
- **Featured Fighter Profiles:** 6 fighters/week = 24 calls
- **Focus:** Champions and upcoming main event fighters only

### 3. **Event Details Updates (20 calls/month)**
- **Frequency:** For major events only
- **What:** Specific high-profile fight cards
- **Calls:** ~5 events × 4 calls = 20 calls

### 4. **Reserve Pool (18 calls)**
- Historic fight results after major events
- Emergency updates
- Error retries
- Manual admin refreshes

## Firestore Data Structure

```javascript
// Collection: boxing_cache
{
  "metadata": {
    "lastUpdated": "2025-09-18T10:00:00Z",
    "nextScheduledUpdate": "2025-09-21T10:00:00Z",
    "apiCallsThisMonth": 45,
    "apiCallsRemaining": 55,
    "cacheVersion": "1.0"
  }
}

// Collection: boxing_events
{
  "eventId": "682a0c659912d4416a13bff4",
  "title": "Canelo vs Crawford",
  "date": "2025-09-14T01:00:00",
  "venue": "Allegiant Stadium",
  "location": "Las Vegas, United States",
  "posterUrl": "https://...",
  "promotion": "Zuffa Boxing",
  "broadcasters": [...],
  "lastUpdated": "2025-09-18T10:00:00Z",
  "cacheExpiry": "2025-09-21T10:00:00Z"
}

// Collection: boxing_fights
{
  "fightId": "689fce0958bc79939699ec5c",
  "eventId": "689fcdf158bc79939699ec50", // Links to event
  "title": "Gorham vs Alamo",
  "date": "2025-09-21T03:00:00",
  "fighters": {
    "fighter1": {...},
    "fighter2": {...}
  },
  "division": "Super Lightweight",
  "scheduledRounds": 10,
  "isTitle": false,
  "cardPosition": 2, // 1=main event, 2+=undercard
  "lastUpdated": "2025-09-18T10:00:00Z"
}

// Collection: boxing_fighters
{
  "fighterId": "6715fc1faf69bb50508b7a03",
  "name": "Oscar Collazo",
  "nationality": "Puerto Rico",
  "stats": {
    "wins": 10,
    "losses": 0,
    "draws": 0,
    "kos": 7
  },
  "physical": {
    "height": "5'9\"",
    "reach": "69\"",
    "stance": "orthodox"
  },
  "division": "Minimumweight",
  "titles": ["WBO World Minimumweight"],
  "lastUpdated": "2025-09-18T10:00:00Z",
  "updatePriority": 1 // 1=champion, 2=ranked, 3=other
}
```

## Cloud Function Implementation

```javascript
// functions/updateBoxingData.js
const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Scheduled function - runs daily at 3 AM
exports.scheduledBoxingUpdate = functions.pubsub
  .schedule('0 3 * * *') // Daily at 3 AM
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const db = admin.firestore();
    const metadata = await db.doc('boxing_cache/metadata').get();
    const { apiCallsThisMonth, apiCallsRemaining } = metadata.data();

    // Check if we have calls remaining
    if (apiCallsRemaining < 10) {
      console.log('API limit approaching, skipping update');
      return null;
    }

    const headers = {
      'x-rapidapi-host': 'boxing-data-api.p.rapidapi.com',
      'x-rapidapi-key': process.env.BOXING_API_KEY
    };

    try {
      // 1. Update event schedule (1 call - LIMITED TO 7 DAYS)
      const scheduleResponse = await axios.get(
        'https://boxing-data-api.p.rapidapi.com/v1/events/schedule?days=7',
        { headers }
      );

      // 2. Update events in Firestore
      const batch = db.batch();
      for (const event of scheduleResponse.data) {
        const eventRef = db.doc(`boxing_events/${event.id}`);
        batch.set(eventRef, {
          ...event,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          cacheExpiry: new Date(Date.now() + 3 * 24 * 60 * 60 * 1000) // 3 days
        }, { merge: true });
      }

      // 3. Get fights for upcoming events (limited calls)
      const upcomingEvents = scheduleResponse.data.slice(0, 5); // Top 5 events
      let callsUsed = 1;

      for (const event of upcomingEvents) {
        if (callsUsed >= 8) break; // Limit to 8 calls per run

        const fightsResponse = await axios.get(
          `https://boxing-data-api.p.rapidapi.com/v1/fights?event_id=${event.id}`,
          { headers }
        );
        callsUsed++;

        // Store fights
        fightsResponse.data.forEach((fight, index) => {
          const fightRef = db.doc(`boxing_fights/${fight.id}`);
          batch.set(fightRef, {
            ...fight,
            cardPosition: index + 1,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          }, { merge: true });
        });
      }

      // 4. Update metadata
      const metadataRef = db.doc('boxing_cache/metadata');
      batch.update(metadataRef, {
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        apiCallsThisMonth: admin.firestore.FieldValue.increment(callsUsed),
        apiCallsRemaining: admin.firestore.FieldValue.increment(-callsUsed),
        nextScheduledUpdate: new Date(Date.now() + 3.5 * 24 * 60 * 60 * 1000)
      });

      await batch.commit();
      console.log(`Boxing data updated. Calls used: ${callsUsed}`);

    } catch (error) {
      console.error('Error updating boxing data:', error);
    }
  });

// Manual refresh endpoint (for emergency updates)
exports.manualBoxingRefresh = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError('permission-denied', 'Admin only');
  }

  const { eventId, fighterIds } = data;
  // Implement selective refresh logic
  // ...
});

// Reset monthly counter
exports.resetMonthlyCounter = functions.pubsub
  .schedule('0 0 1 * *') // First day of each month
  .onRun(async (context) => {
    const db = admin.firestore();
    await db.doc('boxing_cache/metadata').update({
      apiCallsThisMonth: 0,
      apiCallsRemaining: 100
    });
  });
```

## App-Side Implementation

```dart
// boxing_service.dart
class BoxingService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<List<BoxingEvent>> getUpcomingEvents() async {
    try {
      // Always read from Firestore cache first
      final snapshot = await _firestore
          .collection('boxing_events')
          .where('date', isGreaterThan: DateTime.now())
          .orderBy('date')
          .limit(20)
          .get(GetOptions(source: Source.cache));

      if (snapshot.docs.isEmpty) {
        // Fallback to server if cache is empty
        final serverSnapshot = await _firestore
            .collection('boxing_events')
            .where('date', isGreaterThan: DateTime.now())
            .orderBy('date')
            .limit(20)
            .get(GetOptions(source: Source.server));

        return serverSnapshot.docs
            .map((doc) => BoxingEvent.fromFirestore(doc))
            .toList();
      }

      return snapshot.docs
          .map((doc) => BoxingEvent.fromFirestore(doc))
          .toList();
    } catch (e) {
      // Return empty list or cached data
      return [];
    }
  }

  Future<List<Fight>> getFightsForEvent(String eventId) async {
    final snapshot = await _firestore
        .collection('boxing_fights')
        .where('eventId', isEqualTo: eventId)
        .orderBy('cardPosition')
        .get(GetOptions(source: Source.cache));

    return snapshot.docs
        .map((doc) => Fight.fromFirestore(doc))
        .toList();
  }

  Stream<BoxingMetadata> watchApiStatus() {
    return _firestore
        .doc('boxing_cache/metadata')
        .snapshots()
        .map((doc) => BoxingMetadata.fromFirestore(doc));
  }
}
```

## Cost Optimization Benefits

### API Calls Saved
- **Without caching:** 100+ calls per day × 30 days = 3,000+ calls/month
- **With caching:** 80-90 calls/month
- **Savings:** 97% reduction in API calls

### User Experience
- **Instant loading** from Firestore cache
- **Offline support** with local persistence
- **Consistent data** across all users
- **No rate limiting** issues

### Monitoring Dashboard
```dart
// Admin screen to monitor API usage
class BoxingApiMonitor extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return StreamBuilder<BoxingMetadata>(
      stream: BoxingService().watchApiStatus(),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return LoadingIndicator();

        final metadata = snapshot.data!;
        final percentUsed = metadata.apiCallsThisMonth / 100;

        return Card(
          child: Column(
            children: [
              Text('API Calls: ${metadata.apiCallsThisMonth}/100'),
              LinearProgressIndicator(value: percentUsed),
              Text('Last Updated: ${metadata.lastUpdated}'),
              Text('Next Update: ${metadata.nextScheduledUpdate}'),
              if (metadata.apiCallsRemaining < 20)
                Text('⚠️ Low API calls remaining',
                  style: TextStyle(color: Colors.orange)),
            ],
          ),
        );
      },
    );
  }
}
```

## Implementation Timeline

1. **Phase 1:** Set up Firestore collections and security rules
2. **Phase 2:** Deploy Cloud Functions for scheduled updates
3. **Phase 3:** Implement app-side caching service
4. **Phase 4:** Add admin monitoring dashboard
5. **Phase 5:** Test and optimize call frequency

## Monthly API Budget (Revised for Free Tier)

| Purpose | Calls | Frequency | Notes |
|---------|-------|-----------|--------|
| Event Schedule | 30 | Daily | 7-day window only |
| Top Rated Fighters | 8 | 2x weekly | Limited access |
| Fighter Profiles | 24 | 6/week | Main event fighters |
| Event Details | 20 | Major events | ~5 events/month |
| Emergency Reserve | 18 | As needed | Results & errors |
| **Total** | **100** | Per month | Hard limit |

## Alternative Data Sources Needed

Due to free tier limitations, consider supplementing with:
1. **ESPN API** - Fighter profiles and fight results (free)
2. **Web scraping** - BoxRec or similar for complete fight cards
3. **Manual entry** - Admin panel for major fight announcements
4. **User submissions** - Crowdsourced fight results

## Degraded Features on Free Tier

| Feature | Free Tier | Paid Tier |
|---------|-----------|-----------|
| Event Window | 7 days | 30-90 days |
| Fighter Access | Top rated only | All fighters |
| Fight Cards | Limited | Full cards |
| Update Frequency | Daily | Real-time |
| Historical Data | Recent only | Full history |