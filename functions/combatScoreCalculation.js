/**
 * Combat Sports Score Calculation Module
 * Calculates user scores based on fight picks vs actual results
 */

const admin = require('firebase-admin');
const db = admin.firestore();

/**
 * Calculate scores for all users in a pool
 * @param {string} poolId - Pool ID
 * @param {string} eventId - Event ID
 * @param {string} settlementReason - Reason for settlement
 * @returns {Array} Array of user scores
 */
async function calculatePoolScores(poolId, eventId, settlementReason) {
  console.log(`Calculating scores for pool ${poolId}`);

  try {
    // Get all user picks for the pool
    const picksSnapshot = await db.collection('pools')
      .doc(poolId)
      .collection('picks')
      .get();

    // Get all fight results for the event
    const resultsSnapshot = await db.collection('events')
      .doc(eventId)
      .collection('results')
      .where('completed', '==', true)
      .get();

    // Get event details for total fight count
    const eventDoc = await db.collection('events').doc(eventId).get();
    const event = eventDoc.data();

    // Convert results to map for easy lookup
    const resultsMap = {};
    resultsSnapshot.forEach(doc => {
      const result = doc.data();
      resultsMap[result.fightId] = result;
    });

    // Calculate completion rate
    const completedFights = Object.keys(resultsMap).length;
    const totalFights = event.totalFights || completedFights;
    const completionRate = totalFights > 0 ? completedFights / totalFights : 1;

    console.log(`Scoring based on ${completedFights}/${totalFights} completed fights`);

    // Calculate score for each user
    const userScores = [];

    for (const pickDoc of picksSnapshot.docs) {
      const userId = pickDoc.id;
      const userPicks = pickDoc.data();

      // Calculate score for this user
      const scoreData = await calculateUserScore(
        userId,
        userPicks,
        resultsMap,
        completionRate,
        settlementReason
      );

      userScores.push(scoreData);

      // Store score in database
      await storeUserScore(poolId, userId, scoreData);
    }

    // Sort by score (highest first)
    userScores.sort((a, b) => b.totalScore - a.totalScore);

    // Assign rankings
    for (let i = 0; i < userScores.length; i++) {
      userScores[i].rank = i + 1;

      // Update rank in database
      await db.collection('pools')
        .doc(poolId)
        .collection('scores')
        .doc(userScores[i].userId)
        .update({ rank: i + 1 });
    }

    return userScores;

  } catch (error) {
    console.error(`Error calculating scores for pool ${poolId}:`, error);
    throw error;
  }
}

/**
 * Calculate score for a single user
 * @param {string} userId - User ID
 * @param {Object} userPicks - User's picks data
 * @param {Object} resultsMap - Map of fight results
 * @param {number} completionRate - Percentage of fights completed
 * @param {string} settlementReason - Reason for settlement
 * @returns {Object} Score data
 */
async function calculateUserScore(userId, userPicks, resultsMap, completionRate, settlementReason) {
  let totalScore = 0;
  let correctWinners = 0;
  let correctMethods = 0;
  let correctRounds = 0;
  let fightsScored = 0;
  const scoreBreakdown = [];

  // Get user data for display name
  const userDoc = await db.collection('users').doc(userId).get();
  const userData = userDoc.exists ? userDoc.data() : {};

  // Process each fight pick
  const fights = userPicks.fights || {};

  for (const [fightId, pick] of Object.entries(fights)) {
    // Skip if no result available
    const result = resultsMap[fightId];
    if (!result || !result.completed) {
      continue;
    }

    fightsScored++;
    let fightScore = 0;
    const breakdown = {
      fightId: fightId,
      pick: pick,
      result: result,
      points: {}
    };

    // Check if user picked the correct winner
    if (pick.winnerId === result.winnerId) {
      correctWinners++;

      // Base points for correct winner
      const basePoints = 1.0;
      fightScore += basePoints;
      breakdown.points.winner = basePoints;

      // Method bonus (only if winner is correct)
      if (pick.method && result.method) {
        if (matchMethod(pick.method, result.method)) {
          correctMethods++;
          const methodBonus = 0.3;
          fightScore += methodBonus;
          breakdown.points.method = methodBonus;
        }
      }

      // Round bonus (only for finishes, not decisions)
      if (pick.round && result.round && !result.method?.includes('DECISION')) {
        if (pick.round === result.round) {
          correctRounds++;
          const roundBonus = 0.2;
          fightScore += roundBonus;
          breakdown.points.round = roundBonus;
        }
      }

      // Apply confidence multiplier
      const confidence = pick.confidence || 3; // Default to 3 if not set
      const confidenceMultiplier = 0.8 + (confidence * 0.1); // 1-5 stars = 0.9-1.3x
      fightScore *= confidenceMultiplier;
      breakdown.confidenceMultiplier = confidenceMultiplier;
    }

    breakdown.totalPoints = fightScore;
    totalScore += fightScore;
    scoreBreakdown.push(breakdown);
  }

  // Normalize score if not all fights were completed (for fairness)
  let normalizedScore = totalScore;
  if (completionRate < 1.0 && completionRate >= 0.5) {
    // Scale up scores proportionally
    normalizedScore = totalScore * (1 / completionRate);
  }

  return {
    userId: userId,
    username: userData.displayName || userData.username || 'Unknown',
    totalScore: normalizedScore,
    rawScore: totalScore,
    correctWinners: correctWinners,
    correctMethods: correctMethods,
    correctRounds: correctRounds,
    fightsScored: fightsScored,
    accuracy: fightsScored > 0 ? (correctWinners / fightsScored) : 0,
    completionRate: completionRate,
    settlementReason: settlementReason,
    scoreBreakdown: scoreBreakdown,
    timestamp: admin.firestore.FieldValue.serverTimestamp()
  };
}

/**
 * Store user score in Firestore
 * @param {string} poolId - Pool ID
 * @param {string} userId - User ID
 * @param {Object} scoreData - Score data to store
 */
async function storeUserScore(poolId, userId, scoreData) {
  // Store in pool scores collection
  await db.collection('pools')
    .doc(poolId)
    .collection('scores')
    .doc(userId)
    .set(scoreData);

  // Also update user's overall stats
  await updateUserStats(userId, scoreData);
}

/**
 * Update user's overall statistics
 * @param {string} userId - User ID
 * @param {Object} scoreData - Score data from this event
 */
async function updateUserStats(userId, scoreData) {
  const userStatsRef = db.collection('users').doc(userId).collection('stats').doc('combat_sports');

  await db.runTransaction(async (transaction) => {
    const statsDoc = await transaction.get(userStatsRef);

    let stats = {
      totalEvents: 0,
      totalFightsPicked: 0,
      correctWinners: 0,
      correctMethods: 0,
      correctRounds: 0,
      totalScore: 0,
      wins: 0,
      top3Finishes: 0,
      lastPlayed: admin.firestore.FieldValue.serverTimestamp()
    };

    if (statsDoc.exists) {
      stats = statsDoc.data();
    }

    // Update stats
    stats.totalEvents += 1;
    stats.totalFightsPicked += scoreData.fightsScored;
    stats.correctWinners += scoreData.correctWinners;
    stats.correctMethods += scoreData.correctMethods;
    stats.correctRounds += scoreData.correctRounds;
    stats.totalScore += scoreData.totalScore;

    // Win/placement tracking will be updated after rankings
    transaction.set(userStatsRef, stats, { merge: true });
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

  // MMA method groups
  if (pick === 'ko/tko' && (method === 'ko' || method === 'tko')) return true;
  if (pick === 'submission' && (method === 'submission' || method.includes('sub'))) return true;
  if (pick === 'decision' && method.includes('decision')) return true;

  // Boxing method groups
  if (pick === 'ko/tko' && (method.includes('ko') || method.includes('tko') || method === 'rtd')) return true;
  if (pick === 'decision' && (method.includes('decision') || method === 'ud' || method === 'sd' || method === 'md')) return true;

  // Draw/No Contest
  if ((pick === 'draw' || pick === 'tie') && (method === 'draw' || method === 'no_contest' || method === 'nc')) return true;

  return false;
}

/**
 * Calculate perfect event bonuses
 * @param {Object} scoreData - User's score data
 * @param {number} totalFights - Total fights in event
 * @returns {number} Bonus points
 */
function calculatePerfectBonus(scoreData, totalFights) {
  let bonus = 0;

  // Perfect card bonus (all fights correct)
  if (scoreData.correctWinners === totalFights && totalFights >= 10) {
    bonus += 5.0; // Significant bonus for perfect card
  }

  // Perfect main card bonus (typically 5 fights)
  if (scoreData.correctWinners >= 5 && scoreData.fightsScored === 5) {
    const mainCardAccuracy = scoreData.correctWinners / scoreData.fightsScored;
    if (mainCardAccuracy === 1.0) {
      bonus += 2.5; // Bonus for perfect main card
    }
  }

  return bonus;
}

/**
 * Get leaderboard for a pool
 * @param {string} poolId - Pool ID
 * @returns {Array} Sorted leaderboard
 */
async function getPoolLeaderboard(poolId) {
  const scoresSnapshot = await db.collection('pools')
    .doc(poolId)
    .collection('scores')
    .orderBy('totalScore', 'desc')
    .get();

  const leaderboard = [];
  scoresSnapshot.forEach(doc => {
    leaderboard.push({
      ...doc.data(),
      userId: doc.id
    });
  });

  return leaderboard;
}

module.exports = {
  calculatePoolScores,
  calculateUserScore,
  matchMethod,
  calculatePerfectBonus,
  getPoolLeaderboard
};