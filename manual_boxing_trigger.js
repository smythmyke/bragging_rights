const { initializeApp } = require('firebase-admin/app');
const { getFirestore, FieldValue } = require('firebase-admin/firestore');
const axios = require('axios');

// Initialize Firebase Admin
const app = initializeApp({
  projectId: 'bragging-rights-ea6e1'
});

const db = getFirestore();

async function manualBoxingUpdate() {
  console.log('🥊 Manual Boxing Update Starting...\n');

  try {
    // Check API usage
    const metadataDoc = await db.doc('boxing_cache/metadata').get();
    const metadata = metadataDoc.data() || { apiCallsThisMonth: 0 };

    if (metadata.apiCallsThisMonth >= 95) {
      console.log('❌ API limit approaching (${metadata.apiCallsThisMonth}/100). Aborting.');
      process.exit(1);
    }

    console.log(`📊 Current API usage: ${metadata.apiCallsThisMonth}/100`);
    console.log('Starting data fetch...\n');

    const apiKey = 'c050e36faamshb3c100793a53076p19a527jsn589f090905a5';
    const headers = {
      'x-rapidapi-host': 'boxing-data-api.p.rapidapi.com',
      'x-rapidapi-key': apiKey
    };

    let callsUsed = 0;
    const batch = db.batch();
    const now = FieldValue.serverTimestamp();

    // 1. Get next 7 days of events
    console.log('Fetching upcoming events (7-day window)...');
    const eventsResponse = await axios.get(
      'https://boxing-data-api.p.rapidapi.com/v1/events/schedule?days=7&past_hours=12',
      { headers, timeout: 10000 }
    );
    callsUsed++;

    const events = eventsResponse.data || [];
    console.log(`✅ Found ${events.length} upcoming events\n`);

    // 2. Store events
    for (const event of events) {
      console.log(`  • ${event.title} - ${new Date(event.date).toLocaleDateString()}`);
      const eventRef = db.doc(`boxing_events/${event.id}`);
      batch.set(eventRef, {
        ...event,
        lastUpdated: now,
        source: 'boxing_data',
        hasFullData: true,
        cacheExpiry: new Date(Date.now() + 48 * 60 * 60 * 1000),
      }, { merge: true });
    }

    // 3. Get fights for top events (limit to 2 for manual trigger)
    console.log('\nFetching fight cards for top events...');
    const topEvents = events.slice(0, 2);

    for (const event of topEvents) {
      if (callsUsed >= 3) break; // Limit manual trigger to 3 calls

      try {
        console.log(`  Fetching fights for: ${event.title}`);
        const fightsResponse = await axios.get(
          `https://boxing-data-api.p.rapidapi.com/v1/fights?event_id=${event.id}`,
          { headers, timeout: 10000 }
        );
        callsUsed++;

        const fights = fightsResponse.data || [];
        console.log(`    Found ${fights.length} fights`);

        fights.forEach((fight, index) => {
          const fightRef = db.doc(`boxing_fights/${fight.id}`);
          batch.set(fightRef, {
            ...fight,
            eventId: event.id,
            cardPosition: index + 1,
            lastUpdated: now,
          }, { merge: true });
        });
      } catch (error) {
        console.error(`    ❌ Error fetching fights: ${error.message}`);
      }
    }

    // 4. Update metadata
    console.log('\nUpdating metadata...');
    const metadataRef = db.doc('boxing_cache/metadata');
    batch.set(metadataRef, {
      lastUpdated: now,
      apiCallsThisMonth: FieldValue.increment(callsUsed),
      apiCallsRemaining: 100 - (metadata.apiCallsThisMonth + callsUsed),
      nextScheduledUpdate: new Date(Date.now() + 24 * 60 * 60 * 1000),
      lastUpdateCallsUsed: callsUsed,
      lastUpdateEventsFound: events.length,
    }, { merge: true });

    // 5. Log activity
    await db.collection('boxing_activity_log').add({
      status: 'success',
      message: `Manual update: ${events.length} events, ${callsUsed} API calls`,
      timestamp: FieldValue.serverTimestamp()
    });

    // Commit all changes
    await batch.commit();

    console.log('\n✅ Boxing data updated successfully!');
    console.log(`📊 API calls used: ${callsUsed}`);
    console.log(`📊 Total this month: ${metadata.apiCallsThisMonth + callsUsed}/100`);
    console.log(`📊 Remaining: ${100 - (metadata.apiCallsThisMonth + callsUsed)}`);

  } catch (error) {
    console.error('\n❌ Update failed:', error.message);

    // Log error
    await db.collection('boxing_errors').add({
      service: 'manual_update',
      error: error.message,
      timestamp: FieldValue.serverTimestamp()
    });
  }

  process.exit(0);
}

// Run the update
manualBoxingUpdate();