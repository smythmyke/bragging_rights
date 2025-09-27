/**
 * Combat Sports (MMA/Boxing) Settlement System
 * Handles automated settlement of fight pools using ESPN API data
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const fetch = require('node-fetch');

// Initialize Firestore
const db = admin.firestore();

/**
 * Scheduled function to monitor combat sports events for results
 * Runs every 5 minutes during active event windows
 */
exports.monitorCombatSportsResults = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async (context) => {
    console.log('Starting combat sports monitoring cycle');

    try {
      // Get active combat events (MMA and Boxing only)
      const activeEvents = await getActiveCombatEvents();
      console.log(`Found ${activeEvents.length} active combat events to monitor`);

      // Process each event
      for (const event of activeEvents) {
        await processEventResults(event);
      }

      return null;
    } catch (error) {
      console.error('Error in combat sports monitoring:', error);
      throw error;
    }
  });

/**
 * Get active combat sports events that need monitoring
 * @returns {Array} List of events within monitoring window
 */
async function getActiveCombatEvents() {
  const now = new Date();
  const twoHoursAgo = new Date(now.getTime() - 2 * 60 * 60 * 1000);
  const eightHoursFromNow = new Date(now.getTime() + 8 * 60 * 60 * 1000);

  // Query Firestore for MMA/Boxing events in active window
  const eventsSnapshot = await db.collection('events')
    .where('sport', 'in', ['MMA', 'BOXING'])
    .where('gameTime', '>=', admin.firestore.Timestamp.fromDate(twoHoursAgo))
    .where('gameTime', '<=', admin.firestore.Timestamp.fromDate(eightHoursFromNow))
    .where('settlementStatus', '!=', 'SETTLED')
    .get();

  const events = [];
  eventsSnapshot.forEach(doc => {
    events.push({
      id: doc.id,
      ...doc.data()
    });
  });

  return events;
}

/**
 * Process results for a single event
 * @param {Object} event - Event data from Firestore
 */
async function processEventResults(event) {
  console.log(`Processing event: ${event.eventName} (${event.id})`);

  try {
    // Fetch latest data from ESPN
    const espnData = await fetchESPNEventData(event);
    if (!espnData) {
      console.log(`No ESPN data available for event ${event.id}`);
      return;
    }

    // Process each fight in the event
    const competitions = espnData.competitions || [];
    let newResults = 0;
    let totalCompleted = 0;

    for (const competition of competitions) {
      const isCompleted = competition.status?.type?.completed || false;

      if (isCompleted) {
        totalCompleted++;

        // Check if we already have this result
        const existingResult = await getFightResult(event.id, competition.id);

        if (!existingResult) {
          // New result detected - store it
          await storeFightResult(event.id, competition);
          newResults++;
          console.log(`New result stored for fight ${competition.id}`);
        }
      }
    }

    // Update event status
    await updateEventStatus(event.id, {
      lastChecked: admin.firestore.FieldValue.serverTimestamp(),
      completedFights: totalCompleted,
      totalFights: competitions.length
    });

    // Check if event is ready for settlement
    if (newResults > 0) {
      await checkSettlementTriggers(event.id);
    }

  } catch (error) {
    console.error(`Error processing event ${event.id}:`, error);
  }
}

/**
 * Fetch event data from ESPN API
 * @param {Object} event - Event object with ESPN ID
 * @returns {Object} ESPN event data
 */
async function fetchESPNEventData(event) {
  try {
    // Use ESPN ID if available, otherwise try to fetch by date/name
    const espnId = event.espnId;
    if (!espnId) {
      console.log(`No ESPN ID for event ${event.id}, skipping`);
      return null;
    }

    // Fetch from ESPN scoreboard API
    const sport = event.sport === 'MMA' ? 'ufc' : 'boxing';
    const url = `https://site.api.espn.com/apis/site/v2/sports/mma/${sport}/scoreboard`;

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`ESPN API error: ${response.status}`);
    }

    const data = await response.json();

    // Find our specific event
    const espnEvent = data.events?.find(e => e.id === espnId);

    return espnEvent;

  } catch (error) {
    console.error('Error fetching ESPN data:', error);
    return null;
  }
}

/**
 * Get existing fight result from Firestore
 * @param {string} eventId - Event ID
 * @param {string} fightId - Fight ID
 * @returns {Object} Fight result or null
 */
async function getFightResult(eventId, fightId) {
  const doc = await db.collection('events')
    .doc(eventId)
    .collection('results')
    .doc(fightId)
    .get();

  return doc.exists ? doc.data() : null;
}

/**
 * Store fight result in Firestore
 * @param {string} eventId - Event ID
 * @param {Object} competition - ESPN competition data
 */
async function storeFightResult(eventId, competition) {
  // Extract winner information
  const competitors = competition.competitors || [];
  const winner = competitors.find(c => c.winner === true);
  const loser = competitors.find(c => c.winner === false);

  // Extract fight details
  const result = {
    fightId: competition.id,
    eventId: eventId,
    completed: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),

    // Winner information
    winnerId: winner?.id || null,
    winnerName: winner?.athlete?.displayName || null,

    // Fight details
    round: competition.situation?.period || null,
    time: competition.situation?.displayClock || null,

    // Method extraction
    method: extractMethod(competition),
    methodRaw: competition.note || competition.situation?.lastPlay?.text || null,

    // ESPN status
    espnStatus: competition.status?.type?.name || 'UNKNOWN',

    // Processing flags
    processed: false,
    scoringComplete: false
  };

  // Store in Firestore
  await db.collection('events')
    .doc(eventId)
    .collection('results')
    .doc(competition.id)
    .set(result);

  // Log for audit trail
  await logAuditEvent(eventId, 'RESULT_DETECTED', result);
}

/**
 * Extract method of victory from competition data
 * @param {Object} competition - ESPN competition data
 * @returns {string} Method of victory
 */
function extractMethod(competition) {
  const note = (competition.note || '').toLowerCase();
  const situation = competition.situation?.lastPlay?.text?.toLowerCase() || '';
  const status = competition.status?.type?.detail?.toLowerCase() || '';
  const combined = `${note} ${situation} ${status}`;

  // Check for specific methods
  if (combined.includes('ko') || combined.includes('knockout')) {
    return 'KO';
  }
  if (combined.includes('tko') || combined.includes('technical knockout')) {
    return 'TKO';
  }
  if (combined.includes('submission') || combined.includes('tap')) {
    return 'SUBMISSION';
  }
  if (combined.includes('decision')) {
    if (combined.includes('unanimous')) return 'DECISION_UNANIMOUS';
    if (combined.includes('split')) return 'DECISION_SPLIT';
    if (combined.includes('majority')) return 'DECISION_MAJORITY';
    return 'DECISION';
  }
  if (combined.includes('draw')) {
    return 'DRAW';
  }
  if (combined.includes('no contest') || combined.includes('nc')) {
    return 'NO_CONTEST';
  }
  if (combined.includes('dq') || combined.includes('disqualification')) {
    return 'DQ';
  }

  // Check if fight went the distance
  const format = competition.format?.regulation;
  if (format && competition.status?.period >= format.periods) {
    return 'DECISION';
  }

  return 'UNKNOWN';
}

/**
 * Update event status in Firestore
 * @param {string} eventId - Event ID
 * @param {Object} updates - Status updates
 */
async function updateEventStatus(eventId, updates) {
  await db.collection('events').doc(eventId).update(updates);
}

/**
 * Check if event meets any settlement triggers
 * @param {string} eventId - Event ID
 */
async function checkSettlementTriggers(eventId) {
  console.log(`Checking settlement triggers for event ${eventId}`);

  // Get event and results data
  const eventDoc = await db.collection('events').doc(eventId).get();
  if (!eventDoc.exists) {
    console.error(`Event ${eventId} not found`);
    return;
  }

  const event = eventDoc.data();

  // Get all fight results
  const resultsSnapshot = await db.collection('events')
    .doc(eventId)
    .collection('results')
    .get();

  const results = [];
  resultsSnapshot.forEach(doc => {
    results.push(doc.data());
  });

  const completedCount = results.filter(r => r.completed).length;
  const totalFights = event.totalFights || 0;
  const completionRate = totalFights > 0 ? completedCount / totalFights : 0;

  console.log(`Event ${eventId}: ${completedCount}/${totalFights} fights complete (${(completionRate * 100).toFixed(1)}%)`);

  // Check trigger conditions
  let settlementReason = null;

  // Trigger 1: All fights completed
  if (completedCount === totalFights && totalFights > 0) {
    settlementReason = 'ALL_FIGHTS_COMPLETE';
  }

  // Trigger 2: Main event complete + 80% of fights
  else if (completionRate >= 0.8) {
    // Check if main event is complete
    const mainEventResult = results.find(r => r.fightOrder === 1);
    if (mainEventResult?.completed) {
      settlementReason = 'MAIN_EVENT_COMPLETE';
    }
  }

  // Trigger 3: Timeout (event scheduled end + 3 hours)
  else if (event.scheduledEndTime) {
    const endTime = event.scheduledEndTime.toDate();
    const cutoffTime = new Date(endTime.getTime() + 3 * 60 * 60 * 1000);

    if (new Date() > cutoffTime && completionRate >= 0.5) {
      settlementReason = 'TIMEOUT_REACHED';
    }
  }

  // Initiate settlement if triggered
  if (settlementReason) {
    console.log(`Settlement triggered for event ${eventId}: ${settlementReason}`);
    await initiateSettlement(eventId, settlementReason);
  } else {
    console.log(`No settlement triggers met for event ${eventId}`);
  }
}

/**
 * Initiate settlement process for an event
 * @param {string} eventId - Event ID
 * @param {string} reason - Settlement trigger reason
 */
async function initiateSettlement(eventId, reason) {
  console.log(`Initiating settlement for event ${eventId} - Reason: ${reason}`);

  try {
    // Update event status to SETTLING
    await db.collection('events').doc(eventId).update({
      settlementStatus: 'SETTLING',
      settlementReason: reason,
      settlementStarted: admin.firestore.FieldValue.serverTimestamp()
    });

    // Get all pools for this event
    const poolsSnapshot = await db.collection('pools')
      .where('eventId', '==', eventId)
      .where('status', '!=', 'SETTLED')
      .get();

    const pools = [];
    poolsSnapshot.forEach(doc => {
      pools.push({
        id: doc.id,
        ...doc.data()
      });
    });

    console.log(`Found ${pools.length} pools to settle for event ${eventId}`);

    // Settle each pool
    for (const pool of pools) {
      await settlePool(pool.id, eventId, reason);
    }

    // Update event status to SETTLED
    await db.collection('events').doc(eventId).update({
      settlementStatus: 'SETTLED',
      settlementCompleted: admin.firestore.FieldValue.serverTimestamp()
    });

    console.log(`Settlement completed for event ${eventId}`);

  } catch (error) {
    console.error(`Settlement failed for event ${eventId}:`, error);

    // Update status to ERROR
    await db.collection('events').doc(eventId).update({
      settlementStatus: 'ERROR',
      settlementError: error.message
    });

    throw error;
  }
}

/**
 * Settle a specific pool
 * @param {string} poolId - Pool ID
 * @param {string} eventId - Event ID
 * @param {string} reason - Settlement reason
 */
async function settlePool(poolId, eventId, reason) {
  console.log(`Settling pool ${poolId}`);

  const { calculatePoolScores } = require('./combatScoreCalculation');
  const { distributePoolPayouts } = require('./combatPayoutDistribution');

  try {
    // Mark pool as settling
    await db.collection('pools').doc(poolId).update({
      status: 'SETTLING',
      settlementReason: reason,
      settlementStarted: admin.firestore.FieldValue.serverTimestamp()
    });

    // Step 1: Calculate scores for all users
    console.log(`Calculating scores for pool ${poolId}`);
    const userScores = await calculatePoolScores(poolId, eventId, reason);
    console.log(`Scores calculated for ${userScores.length} users`);

    // Step 2: Distribute payouts based on rankings
    console.log(`Distributing payouts for pool ${poolId}`);
    const payoutSummary = await distributePoolPayouts(poolId, userScores);
    console.log(`Payouts distributed: ${payoutSummary.winnersCount} winners`);

    // Step 3: Mark pool as settled
    await db.collection('pools').doc(poolId).update({
      status: 'SETTLED',
      settlementCompleted: admin.firestore.FieldValue.serverTimestamp(),
      settlementSummary: {
        totalParticipants: userScores.length,
        winners: payoutSummary.winnersCount,
        totalPaidOut: payoutSummary.totalPaidOut
      }
    });

    console.log(`Pool ${poolId} settlement completed successfully`);

  } catch (error) {
    console.error(`Error settling pool ${poolId}:`, error);

    // Mark pool as error
    await db.collection('pools').doc(poolId).update({
      status: 'SETTLEMENT_ERROR',
      settlementError: error.message,
      settlementErrorTime: admin.firestore.FieldValue.serverTimestamp()
    });

    throw error;
  }
}

/**
 * Log audit event for tracking
 * @param {string} eventId - Event ID
 * @param {string} action - Action performed
 * @param {Object} details - Action details
 */
async function logAuditEvent(eventId, action, details) {
  await db.collection('audit_logs').add({
    eventId,
    action,
    details,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    source: 'CLOUD_FUNCTION'
  });
}

/**
 * Match user's method pick with actual result
 * @param {string} userPick - User's method prediction
 * @param {string} actualMethod - Actual method from result
 * @returns {boolean} True if methods match
 */
function matchMethod(userPick, actualMethod) {
  if (!userPick || !actualMethod) return false;

  const pick = userPick.toLowerCase();
  const method = actualMethod.toLowerCase();

  // Exact match
  if (pick === method) return true;

  // Group matches for MMA
  if (pick === 'ko/tko' && (method === 'ko' || method === 'tko')) return true;
  if (pick === 'decision' && method.includes('decision')) return true;
  if (pick === 'submission' && (method === 'submission' || method.includes('sub'))) return true;
  if (pick === 'tie' && (method === 'draw' || method === 'no_contest')) return true;

  return false;
}

module.exports = {
  monitorCombatSportsResults: exports.monitorCombatSportsResults,
  checkSettlementTriggers,
  initiateSettlement,
  matchMethod
};