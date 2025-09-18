const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Daily boxing update function - runs at 3 AM EST
exports.dailyBoxingUpdate = functions.pubsub
  .schedule('0 3 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const db = admin.firestore();

    try {
      // Check API usage
      const metadataDoc = await db.doc('boxing_cache/metadata').get();
      let metadata = metadataDoc.exists ? metadataDoc.data() : {
        apiCallsThisMonth: 0,
        apiCallsRemaining: 100,
        lastUpdated: null,
      };

      // Skip if approaching limit
      if (metadata.apiCallsThisMonth >= 95) {
        console.log('Approaching API limit, skipping update');
        await logActivity(db, 'skipped', 'API limit approaching');
        return null;
      }

      const apiKey = functions.config().boxing?.api_key;
      if (!apiKey) {
        console.error('Boxing API key not configured');
        await logError(db, 'Missing API key configuration');
        return null;
      }

      const headers = {
        'x-rapidapi-host': 'boxing-data-api.p.rapidapi.com',
        'x-rapidapi-key': apiKey
      };

      let callsUsed = 0;
      const batch = db.batch();
      const now = admin.firestore.FieldValue.serverTimestamp();

      // 1. Get next 7 days of events (1 API call)
      console.log('Fetching upcoming events...');
      const eventsResponse = await axios.get(
        'https://boxing-data-api.p.rapidapi.com/v1/events/schedule?days=7&past_hours=12',
        { headers, timeout: 10000 }
      );
      callsUsed++;

      const events = eventsResponse.data || [];
      console.log(`Found ${events.length} upcoming events`);

      // 2. Store/update events
      for (const event of events) {
        const eventRef = db.doc(`boxing_events/${event.id}`);
        batch.set(eventRef, {
          ...event,
          lastUpdated: now,
          source: 'boxing_data',
          hasFullData: true,
          cacheExpiry: new Date(Date.now() + 48 * 60 * 60 * 1000), // 48 hours
        }, { merge: true });
      }

      // 3. Get fights for top upcoming events (limited to save API calls)
      const topEvents = events.slice(0, 3); // Only get fights for next 3 events

      for (const event of topEvents) {
        if (callsUsed >= 5) break; // Limit daily calls to 5 maximum

        try {
          console.log(`Fetching fights for event: ${event.title}`);
          const fightsResponse = await axios.get(
            `https://boxing-data-api.p.rapidapi.com/v1/fights?event_id=${event.id}`,
            { headers, timeout: 10000 }
          );
          callsUsed++;

          const fights = fightsResponse.data || [];
          console.log(`Found ${fights.length} fights for ${event.title}`);

          // Store fights with card position
          fights.forEach((fight, index) => {
            const fightRef = db.doc(`boxing_fights/${fight.id}`);
            batch.set(fightRef, {
              ...fight,
              eventId: event.id,
              cardPosition: index + 1, // 1 = main event
              lastUpdated: now,
            }, { merge: true });
          });
        } catch (error) {
          console.error(`Error fetching fights for event ${event.id}:`, error.message);
        }
      }

      // 4. Update metadata
      const metadataRef = db.doc('boxing_cache/metadata');
      batch.set(metadataRef, {
        lastUpdated: now,
        apiCallsThisMonth: admin.firestore.FieldValue.increment(callsUsed),
        apiCallsRemaining: 100 - (metadata.apiCallsThisMonth + callsUsed),
        nextScheduledUpdate: new Date(Date.now() + 24 * 60 * 60 * 1000),
        lastUpdateCallsUsed: callsUsed,
        lastUpdateEventsFound: events.length,
      }, { merge: true });

      // Commit all changes
      await batch.commit();
      console.log(`Boxing cache updated successfully. Calls used: ${callsUsed}`);

      await logActivity(db, 'success', `Updated ${events.length} events using ${callsUsed} API calls`);

    } catch (error) {
      console.error('Failed to update boxing cache:', error);
      await logError(db, error.message);
    }
  });

// Weekly fighter update - Sundays at 2 AM
exports.weeklyFighterUpdate = functions.pubsub
  .schedule('0 2 * * 0')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const db = admin.firestore();

    try {
      const metadata = await db.doc('boxing_cache/metadata').get();
      const { apiCallsThisMonth } = metadata.data() || { apiCallsThisMonth: 0 };

      if (apiCallsThisMonth >= 90) {
        console.log('API limit too close, skipping fighter updates');
        return null;
      }

      const apiKey = functions.config().boxing?.api_key;
      const headers = {
        'x-rapidapi-host': 'boxing-data-api.p.rapidapi.com',
        'x-rapidapi-key': apiKey
      };

      // Get top rated fighters (2 API calls)
      console.log('Fetching top rated fighters...');
      const fightersResponse = await axios.get(
        'https://boxing-data-api.p.rapidapi.com/v1/fighters/top-rated?limit=10',
        { headers, timeout: 10000 }
      );

      const batch = db.batch();
      const fighters = fightersResponse.data || [];

      for (const fighter of fighters) {
        const fighterRef = db.doc(`boxing_fighters/${fighter.id}`);
        batch.set(fighterRef, {
          ...fighter,
          lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
          updatePriority: fighter.titles?.length > 0 ? 1 : 2, // Champions get priority
        }, { merge: true });
      }

      // Update metadata
      batch.update(db.doc('boxing_cache/metadata'), {
        apiCallsThisMonth: admin.firestore.FieldValue.increment(1),
        lastFighterUpdate: admin.firestore.FieldValue.serverTimestamp(),
      });

      await batch.commit();
      console.log(`Updated ${fighters.length} fighter profiles`);

    } catch (error) {
      console.error('Failed to update fighters:', error);
      await logError(db, error.message);
    }
  });

// Reset monthly counter - First of each month at midnight
exports.resetBoxingApiCounter = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const db = admin.firestore();

    try {
      await db.doc('boxing_cache/metadata').update({
        apiCallsThisMonth: 0,
        apiCallsRemaining: 100,
        monthStarted: admin.firestore.FieldValue.serverTimestamp(),
        lastMonthCalls: admin.firestore.FieldValue.delete(),
      });

      console.log('Monthly API counter reset successfully');
      await logActivity(db, 'reset', 'Monthly counter reset to 0/100');

    } catch (error) {
      console.error('Failed to reset counter:', error);
      await logError(db, error.message);
    }
  });

// Manual refresh endpoint (callable function)
exports.manualBoxingRefresh = functions.https.onCall(async (data, context) => {
  // Check if user is admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can manually refresh boxing data'
    );
  }

  const db = admin.firestore();
  const { eventId, forceUpdate } = data;

  try {
    const metadata = await db.doc('boxing_cache/metadata').get();
    const { apiCallsThisMonth } = metadata.data() || { apiCallsThisMonth: 0 };

    if (apiCallsThisMonth >= 98 && !forceUpdate) {
      throw new functions.https.HttpsError(
        'resource-exhausted',
        'API limit nearly reached. Use forceUpdate to override.'
      );
    }

    // Trigger specific event update
    if (eventId) {
      // Implementation for specific event refresh
      console.log(`Manual refresh requested for event: ${eventId}`);
    }

    return {
      success: true,
      message: 'Refresh initiated',
      callsRemaining: 100 - apiCallsThisMonth
    };

  } catch (error) {
    console.error('Manual refresh error:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Helper functions
async function logActivity(db, status, message) {
  try {
    await db.collection('boxing_activity_log').add({
      status,
      message,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Failed to log activity:', error);
  }
}

async function logError(db, errorMessage) {
  try {
    await db.collection('boxing_errors').add({
      service: 'boxing_cache_update',
      error: errorMessage,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error) {
    console.error('Failed to log error:', error);
  }
}