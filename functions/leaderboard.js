/**
 * Leaderboard Cloud Functions for Bragging Rights App
 * Handles leaderboard calculations, caching, and retrieval
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Ensure Firebase is initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// Leaderboard Types
const LEADERBOARD_TYPES = {
  DAILY: 'daily',
  WEEKLY: 'weekly',
  MONTHLY: 'monthly',
  ALL_TIME: 'all_time'
};

// Ranking Metrics
const RANKING_METRICS = {
  PROFIT: 'profit',
  WIN_RATE: 'winRate',
  TOTAL_WINS: 'totalWins',
  WIN_STREAK: 'winStreak'
};

// ============================================
// SCHEDULED LEADERBOARD UPDATES
// ============================================

/**
 * Updates daily leaderboard - runs every day at midnight
 */
exports.updateDailyLeaderboard = functions.pubsub
  .schedule('0 0 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Updating daily leaderboard...');
    await updateLeaderboard(LEADERBOARD_TYPES.DAILY);
    return null;
  });

/**
 * Updates weekly leaderboard - runs every Monday at midnight
 */
exports.updateWeeklyLeaderboard = functions.pubsub
  .schedule('0 0 * * 1')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Updating weekly leaderboard...');
    await updateLeaderboard(LEADERBOARD_TYPES.WEEKLY);
    return null;
  });

/**
 * Updates monthly leaderboard - runs on first day of each month
 */
exports.updateMonthlyLeaderboard = functions.pubsub
  .schedule('0 0 1 * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Updating monthly leaderboard...');
    await updateLeaderboard(LEADERBOARD_TYPES.MONTHLY);
    return null;
  });

/**
 * Updates all-time leaderboard - runs every 6 hours
 */
exports.updateAllTimeLeaderboard = functions.pubsub
  .schedule('0 */6 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Updating all-time leaderboard...');
    await updateLeaderboard(LEADERBOARD_TYPES.ALL_TIME);
    return null;
  });

// ============================================
// TRIGGERED UPDATES
// ============================================

/**
 * Updates leaderboards when a bet is settled
 */
exports.onBetSettled = functions.firestore
  .document('bets/{betId}')
  .onUpdate(async (change, context) => {
    const previousData = change.before.data();
    const currentData = change.after.data();
    
    // Only process if bet just got settled
    if (previousData.status === 'pending' && 
        (currentData.status === 'won' || currentData.status === 'lost')) {
      
      const userId = currentData.userId;
      console.log(`Updating stats for user ${userId} after bet settlement`);
      
      try {
        await updateUserStats(userId, currentData);
        await updateUserLeaderboardEntry(userId);
      } catch (error) {
        console.error('Error updating stats after bet settlement:', error);
      }
    }
    
    return null;
  });

// ============================================
// CORE LEADERBOARD FUNCTIONS
// ============================================

/**
 * Updates a specific leaderboard type
 */
async function updateLeaderboard(type) {
  const startTime = Date.now();
  
  try {
    // Get time range for the leaderboard
    const timeRange = getTimeRange(type);
    
    // Fetch all users with their stats for the period
    const userStats = await getUserStatsForPeriod(timeRange);
    
    // Calculate rankings for different metrics
    const rankings = {};
    for (const metric of Object.values(RANKING_METRICS)) {
      rankings[metric] = calculateRankings(userStats, metric);
    }
    
    // Store leaderboard in Firestore
    await storeLeaderboard(type, rankings, timeRange);
    
    const duration = Date.now() - startTime;
    console.log(`Updated ${type} leaderboard in ${duration}ms`);
    
    // Log the update
    await db.collection('system_logs').add({
      type: 'leaderboard_update',
      leaderboardType: type,
      timestamp: FieldValue.serverTimestamp(),
      duration,
      userCount: userStats.length
    });
    
  } catch (error) {
    console.error(`Error updating ${type} leaderboard:`, error);
    throw error;
  }
}

/**
 * Gets the time range for a leaderboard type
 */
function getTimeRange(type) {
  const now = new Date();
  let startDate;
  
  switch (type) {
    case LEADERBOARD_TYPES.DAILY:
      startDate = new Date(now);
      startDate.setHours(0, 0, 0, 0);
      break;
      
    case LEADERBOARD_TYPES.WEEKLY:
      startDate = new Date(now);
      const dayOfWeek = startDate.getDay();
      const daysToMonday = dayOfWeek === 0 ? 6 : dayOfWeek - 1;
      startDate.setDate(startDate.getDate() - daysToMonday);
      startDate.setHours(0, 0, 0, 0);
      break;
      
    case LEADERBOARD_TYPES.MONTHLY:
      startDate = new Date(now.getFullYear(), now.getMonth(), 1);
      break;
      
    case LEADERBOARD_TYPES.ALL_TIME:
      startDate = new Date('2024-01-01'); // App launch date
      break;
      
    default:
      startDate = new Date('2024-01-01');
  }
  
  return {
    start: startDate,
    end: now,
    type
  };
}

/**
 * Fetches user stats for a specific time period
 */
async function getUserStatsForPeriod(timeRange) {
  const userStats = [];
  
  // Get all active users
  const usersSnapshot = await db.collection('users')
    .where('isActive', '!=', false)
    .get();
  
  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const userData = userDoc.data();
    
    // Get user's bets for the period
    const betsSnapshot = await db.collection('bets')
      .where('userId', '==', userId)
      .where('settledAt', '>=', timeRange.start)
      .where('settledAt', '<=', timeRange.end)
      .where('status', 'in', ['won', 'lost'])
      .get();
    
    if (betsSnapshot.empty) continue;
    
    // Calculate stats
    const stats = calculateUserStatsFromBets(betsSnapshot.docs);
    
    userStats.push({
      userId,
      username: userData.username || userData.displayName || 'Anonymous',
      photoURL: userData.photoURL,
      ...stats
    });
  }
  
  return userStats;
}

/**
 * Calculates user stats from bet documents
 */
function calculateUserStatsFromBets(betDocs) {
  let totalWins = 0;
  let totalLosses = 0;
  let totalWagered = 0;
  let totalWinnings = 0;
  let currentStreak = 0;
  let bestStreak = 0;
  let tempStreak = 0;
  
  // Sort bets by settled time
  betDocs.sort((a, b) => {
    const aTime = a.data().settledAt?.toMillis() || 0;
    const bTime = b.data().settledAt?.toMillis() || 0;
    return aTime - bTime;
  });
  
  for (const betDoc of betDocs) {
    const bet = betDoc.data();
    
    totalWagered += bet.wagerAmount || 0;
    
    if (bet.status === 'won') {
      totalWins++;
      totalWinnings += bet.winAmount || 0;
      tempStreak++;
      bestStreak = Math.max(bestStreak, tempStreak);
    } else {
      totalLosses++;
      tempStreak = 0;
    }
  }
  
  currentStreak = tempStreak;
  const totalBets = totalWins + totalLosses;
  const winRate = totalBets > 0 ? (totalWins / totalBets) * 100 : 0;
  const profit = totalWinnings - totalWagered;
  const roi = totalWagered > 0 ? (profit / totalWagered) * 100 : 0;
  
  return {
    totalBets,
    totalWins,
    totalLosses,
    winRate: Math.round(winRate * 10) / 10, // Round to 1 decimal
    totalWagered,
    totalWinnings,
    profit,
    roi: Math.round(roi * 10) / 10, // Round to 1 decimal
    currentStreak,
    bestStreak
  };
}

/**
 * Calculates rankings based on a specific metric
 */
function calculateRankings(userStats, metric) {
  // Filter out users with no activity
  const activeUsers = userStats.filter(user => user.totalBets > 0);
  
  // Sort by the metric (descending)
  activeUsers.sort((a, b) => {
    const aValue = a[metric] || 0;
    const bValue = b[metric] || 0;
    return bValue - aValue;
  });
  
  // Add rank information
  return activeUsers.map((user, index) => ({
    ...user,
    rank: index + 1,
    metric,
    metricValue: user[metric] || 0
  }));
}

/**
 * Stores leaderboard data in Firestore
 */
async function storeLeaderboard(type, rankings, timeRange) {
  const leaderboardRef = db.collection('leaderboards').doc(type);
  
  // Prepare top 100 for each metric
  const topRankings = {};
  for (const [metric, rankedUsers] of Object.entries(rankings)) {
    topRankings[metric] = rankedUsers.slice(0, 100).map(user => ({
      userId: user.userId,
      username: user.username,
      photoURL: user.photoURL,
      rank: user.rank,
      value: user.metricValue,
      stats: {
        totalBets: user.totalBets,
        winRate: user.winRate,
        profit: user.profit,
        roi: user.roi
      }
    }));
  }
  
  await leaderboardRef.set({
    type,
    rankings: topRankings,
    lastUpdated: FieldValue.serverTimestamp(),
    timeRange: {
      start: timeRange.start,
      end: timeRange.end
    },
    totalPlayers: rankings[RANKING_METRICS.PROFIT]?.length || 0
  });
  
  console.log(`Stored ${type} leaderboard with ${Object.keys(topRankings).length} metrics`);
}

/**
 * Updates individual user stats
 */
async function updateUserStats(userId, betData) {
  const statsRef = db.collection('users').doc(userId)
    .collection('stats').doc('current');
  
  const increment = betData.status === 'won' ? 1 : 0;
  const winAmount = betData.winAmount || 0;
  const wagerAmount = betData.wagerAmount || 0;
  
  try {
    await db.runTransaction(async (transaction) => {
      const statsDoc = await transaction.get(statsRef);
      
      let currentStats = statsDoc.exists ? statsDoc.data() : {
        totalBets: 0,
        wins: 0,
        losses: 0,
        totalWagered: 0,
        totalWinnings: 0,
        currentStreak: 0,
        bestStreak: 0
      };
      
      // Update stats
      currentStats.totalBets++;
      
      if (betData.status === 'won') {
        currentStats.wins++;
        currentStats.totalWinnings += winAmount;
        currentStats.currentStreak++;
        currentStats.bestStreak = Math.max(currentStats.bestStreak, currentStats.currentStreak);
      } else {
        currentStats.losses++;
        currentStats.currentStreak = 0;
      }
      
      currentStats.totalWagered += wagerAmount;
      currentStats.winRate = currentStats.totalBets > 0 
        ? (currentStats.wins / currentStats.totalBets) * 100 
        : 0;
      currentStats.profit = currentStats.totalWinnings - currentStats.totalWagered;
      currentStats.roi = currentStats.totalWagered > 0 
        ? (currentStats.profit / currentStats.totalWagered) * 100 
        : 0;
      
      currentStats.lastUpdated = FieldValue.serverTimestamp();
      
      transaction.set(statsRef, currentStats, { merge: true });
    });
    
    console.log(`Updated stats for user ${userId}`);
  } catch (error) {
    console.error(`Failed to update stats for user ${userId}:`, error);
    throw error;
  }
}

/**
 * Updates user's leaderboard entry immediately
 */
async function updateUserLeaderboardEntry(userId) {
  // Get user's current stats
  const statsDoc = await db.collection('users').doc(userId)
    .collection('stats').doc('current').get();
  
  if (!statsDoc.exists) return;
  
  const stats = statsDoc.data();
  
  // Update user's position in real-time leaderboard cache
  const realtimeRef = db.collection('leaderboards').doc('realtime')
    .collection('users').doc(userId);
  
  await realtimeRef.set({
    userId,
    profit: stats.profit || 0,
    winRate: stats.winRate || 0,
    totalWins: stats.wins || 0,
    currentStreak: stats.currentStreak || 0,
    lastUpdated: FieldValue.serverTimestamp()
  });
}

// ============================================
// HTTP CALLABLE FUNCTIONS
// ============================================

/**
 * Get leaderboard data
 */
exports.getLeaderboard = functions.https.onCall(async (data, context) => {
  const { type = LEADERBOARD_TYPES.ALL_TIME, metric = RANKING_METRICS.PROFIT, limit = 50 } = data;
  
  // Validate inputs
  if (!Object.values(LEADERBOARD_TYPES).includes(type)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid leaderboard type'
    );
  }
  
  if (!Object.values(RANKING_METRICS).includes(metric)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Invalid ranking metric'
    );
  }
  
  try {
    // Get cached leaderboard
    const leaderboardDoc = await db.collection('leaderboards').doc(type).get();
    
    if (!leaderboardDoc.exists) {
      // Trigger an update if no cache exists
      await updateLeaderboard(type);
      const updatedDoc = await db.collection('leaderboards').doc(type).get();
      const data = updatedDoc.data();
      
      return {
        type,
        metric,
        rankings: (data.rankings[metric] || []).slice(0, limit),
        lastUpdated: data.lastUpdated,
        totalPlayers: data.totalPlayers
      };
    }
    
    const leaderboardData = leaderboardDoc.data();
    
    // Check if cache is stale (older than 1 hour for daily, 6 hours for others)
    const cacheAge = Date.now() - leaderboardData.lastUpdated.toMillis();
    const maxAge = type === LEADERBOARD_TYPES.DAILY ? 3600000 : 21600000;
    
    if (cacheAge > maxAge) {
      // Update in background
      updateLeaderboard(type).catch(console.error);
    }
    
    return {
      type,
      metric,
      rankings: (leaderboardData.rankings[metric] || []).slice(0, limit),
      lastUpdated: leaderboardData.lastUpdated,
      totalPlayers: leaderboardData.totalPlayers
    };
    
  } catch (error) {
    console.error('Error fetching leaderboard:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch leaderboard'
    );
  }
});

/**
 * Get user's ranking across all leaderboards
 */
exports.getUserRankings = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = data.userId || context.auth.uid;
  
  try {
    const rankings = {};
    
    // Get rankings for each leaderboard type
    for (const type of Object.values(LEADERBOARD_TYPES)) {
      const leaderboardDoc = await db.collection('leaderboards').doc(type).get();
      
      if (!leaderboardDoc.exists) continue;
      
      const leaderboardData = leaderboardDoc.data();
      rankings[type] = {};
      
      // Find user's rank in each metric
      for (const [metric, rankedUsers] of Object.entries(leaderboardData.rankings)) {
        const userIndex = rankedUsers.findIndex(u => u.userId === userId);
        
        if (userIndex >= 0) {
          rankings[type][metric] = {
            rank: userIndex + 1,
            value: rankedUsers[userIndex].value,
            percentile: Math.round(((leaderboardData.totalPlayers - userIndex) / leaderboardData.totalPlayers) * 100)
          };
        }
      }
    }
    
    // Get user's current stats
    const statsDoc = await db.collection('users').doc(userId)
      .collection('stats').doc('current').get();
    
    const stats = statsDoc.exists ? statsDoc.data() : null;
    
    return {
      userId,
      rankings,
      stats,
      timestamp: FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('Error fetching user rankings:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch user rankings'
    );
  }
});

/**
 * Get friends leaderboard
 */
exports.getFriendsLeaderboard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = context.auth.uid;
  const { metric = RANKING_METRICS.PROFIT } = data;
  
  try {
    // Get user's friends list
    const userDoc = await db.collection('users').doc(userId).get();
    
    if (!userDoc.exists) {
      throw new functions.https.HttpsError(
        'not-found',
        'User not found'
      );
    }
    
    const userData = userDoc.data();
    const friendIds = userData.friends || [];
    
    // Include the user themselves
    friendIds.push(userId);
    
    // Get stats for all friends
    const friendStats = [];
    
    for (const friendId of friendIds) {
      const statsDoc = await db.collection('users').doc(friendId)
        .collection('stats').doc('current').get();
      
      if (statsDoc.exists) {
        const friendDoc = await db.collection('users').doc(friendId).get();
        const friendData = friendDoc.data();
        
        friendStats.push({
          userId: friendId,
          username: friendData.username || friendData.displayName,
          photoURL: friendData.photoURL,
          ...statsDoc.data()
        });
      }
    }
    
    // Calculate rankings
    const rankings = calculateRankings(friendStats, metric);
    
    return {
      metric,
      rankings,
      totalFriends: friendIds.length
    };
    
  } catch (error) {
    console.error('Error fetching friends leaderboard:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch friends leaderboard'
    );
  }
});

/**
 * Force update a specific leaderboard (Admin only)
 */
exports.forceUpdateLeaderboard = functions.https.onCall(async (data, context) => {
  // Verify admin status
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can force leaderboard updates'
    );
  }
  
  const { type } = data;
  
  if (!type || !Object.values(LEADERBOARD_TYPES).includes(type)) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Valid leaderboard type is required'
    );
  }
  
  try {
    await updateLeaderboard(type);
    
    return {
      success: true,
      message: `Successfully updated ${type} leaderboard`
    };
  } catch (error) {
    console.error(`Error forcing ${type} leaderboard update:`, error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update leaderboard'
    );
  }
});

console.log('Leaderboard Cloud Functions initialized');