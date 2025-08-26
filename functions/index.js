/**
 * Cloud Functions for Bragging Rights App
 * Handles automated bet settlement, wallet management, and scheduled tasks
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize Firebase Admin
admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// ============================================
// BET SETTLEMENT FUNCTIONS
// ============================================

/**
 * Triggered when a game status changes to 'final'
 * Automatically settles all pending bets for that game
 */
exports.settleGameBets = functions.firestore
  .document('games/{gameId}')
  .onUpdate(async (change, context) => {
    const gameId = context.params.gameId;
    const previousData = change.before.data();
    const currentData = change.after.data();
    
    // Only process if game just finished
    if (previousData.status !== 'final' && currentData.status === 'final') {
      console.log(`Game ${gameId} finished. Starting bet settlement...`);
      
      try {
        await settleBetsForGame(gameId, currentData);
        await settlePoolsForGame(gameId, currentData);
        console.log(`Successfully settled all bets for game ${gameId}`);
      } catch (error) {
        console.error(`Error settling bets for game ${gameId}:`, error);
        throw error;
      }
    }
    
    return null;
  });

/**
 * Settles all pending bets for a completed game
 */
async function settleBetsForGame(gameId, gameData) {
  // Get all pending bets for this game
  const betsSnapshot = await db.collection('bets')
    .where('gameId', '==', gameId)
    .where('status', '==', 'pending')
    .get();
  
  if (betsSnapshot.empty) {
    console.log(`No pending bets found for game ${gameId}`);
    return;
  }
  
  console.log(`Found ${betsSnapshot.size} pending bets to settle`);
  
  const batch = db.batch();
  const payouts = [];
  
  // Process each bet
  for (const betDoc of betsSnapshot.docs) {
    const bet = betDoc.data();
    const betResult = determineBetOutcome(bet, gameData);
    
    // Update bet status
    batch.update(betDoc.ref, {
      status: betResult.status,
      settledAt: FieldValue.serverTimestamp(),
      winAmount: betResult.winAmount || 0,
      settlementNote: betResult.note || ''
    });
    
    // If bet won, prepare payout
    if (betResult.status === 'won') {
      payouts.push({
        userId: bet.userId,
        amount: betResult.winAmount,
        betId: betDoc.id
      });
    }
    
    // Log the settlement
    console.log(`Bet ${betDoc.id}: ${betResult.status} - ${betResult.note}`);
  }
  
  // Commit all bet status updates
  await batch.commit();
  
  // Process payouts
  for (const payout of payouts) {
    await processPayout(payout.userId, payout.amount, payout.betId, gameId);
  }
  
  console.log(`Settled ${betsSnapshot.size} bets, ${payouts.length} winners`);
}

/**
 * Determines if a bet won or lost based on game results
 */
function determineBetOutcome(bet, gameData) {
  const { betType, selection, odds, wagerAmount } = bet;
  const { result } = gameData;
  
  // Ensure we have results
  if (!result || !result.winner) {
    return { 
      status: 'cancelled', 
      note: 'Game cancelled or no result available' 
    };
  }
  
  let won = false;
  let winAmount = 0;
  let note = '';
  
  switch (betType) {
    case 'moneyline':
      won = (selection === 'home' && result.winner === 'home') ||
            (selection === 'away' && result.winner === 'away');
      note = `Selected ${selection}, winner was ${result.winner}`;
      break;
      
    case 'spread':
      const spread = bet.line || 0;
      const homeScore = result.homeScore || 0;
      const awayScore = result.awayScore || 0;
      const adjustedHomeScore = homeScore + spread;
      
      if (selection === 'home') {
        won = adjustedHomeScore > awayScore;
      } else {
        won = awayScore > adjustedHomeScore;
      }
      note = `Spread ${spread}, Final: ${homeScore}-${awayScore}`;
      break;
      
    case 'total':
      const totalLine = bet.line || 0;
      const totalScore = (result.homeScore || 0) + (result.awayScore || 0);
      
      if (selection === 'over') {
        won = totalScore > totalLine;
      } else {
        won = totalScore < totalLine;
      }
      
      // Push if exactly on the line
      if (totalScore === totalLine) {
        return { 
          status: 'push', 
          winAmount: wagerAmount,
          note: `Total ${totalScore} equals line ${totalLine}` 
        };
      }
      
      note = `Total ${totalScore} vs line ${totalLine}`;
      break;
      
    case 'prop':
      // Custom prop bet logic would go here
      // For now, we'll mark as pending review
      return { 
        status: 'pending_review', 
        note: 'Prop bet requires manual review' 
      };
      
    default:
      return { 
        status: 'error', 
        note: `Unknown bet type: ${betType}` 
      };
  }
  
  // Calculate winnings
  if (won) {
    winAmount = calculatePayout(wagerAmount, odds);
    return { 
      status: 'won', 
      winAmount, 
      note: `${note} - Won ${winAmount} BR` 
    };
  } else {
    return { 
      status: 'lost', 
      winAmount: 0, 
      note: `${note} - Lost` 
    };
  }
}

/**
 * Calculates payout based on American odds
 */
function calculatePayout(wagerAmount, odds) {
  if (odds > 0) {
    // Positive odds: amount won per $100 wagered
    return wagerAmount + (wagerAmount * odds / 100);
  } else {
    // Negative odds: amount needed to wager to win $100
    return wagerAmount + (wagerAmount * 100 / Math.abs(odds));
  }
}

/**
 * Processes a payout to user's wallet
 */
async function processPayout(userId, amount, betId, gameId) {
  const walletRef = db.collection('users').doc(userId)
    .collection('wallet').doc('current');
  
  const transactionRef = db.collection('transactions').doc();
  
  try {
    await db.runTransaction(async (transaction) => {
      const walletDoc = await transaction.get(walletRef);
      
      if (!walletDoc.exists) {
        throw new Error(`Wallet not found for user ${userId}`);
      }
      
      const currentBalance = walletDoc.data().balance || 0;
      const newBalance = currentBalance + amount;
      
      // Update wallet balance
      transaction.update(walletRef, {
        balance: newBalance,
        lastWin: FieldValue.serverTimestamp(),
        lifetimeWinnings: FieldValue.increment(amount)
      });
      
      // Create transaction record
      transaction.set(transactionRef, {
        userId: userId,
        type: 'payout',
        amount: amount,
        description: `Bet won - Game ${gameId}`,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        timestamp: FieldValue.serverTimestamp(),
        relatedId: betId,
        status: 'completed'
      });
      
      // Update user stats
      const statsRef = db.collection('users').doc(userId)
        .collection('stats').doc('current');
      
      transaction.set(statsRef, {
        wins: FieldValue.increment(1),
        totalWinnings: FieldValue.increment(amount),
        lastWin: FieldValue.serverTimestamp()
      }, { merge: true });
    });
    
    console.log(`Paid out ${amount} BR to user ${userId} for bet ${betId}`);
  } catch (error) {
    console.error(`Failed to process payout for user ${userId}:`, error);
    throw error;
  }
}

/**
 * Settles pools associated with a completed game
 */
async function settlePoolsForGame(gameId, gameData) {
  const poolsSnapshot = await db.collection('pools')
    .where('gameId', '==', gameId)
    .where('status', '==', 'open')
    .get();
  
  if (poolsSnapshot.empty) {
    console.log(`No open pools found for game ${gameId}`);
    return;
  }
  
  for (const poolDoc of poolsSnapshot.docs) {
    const pool = poolDoc.data();
    await settlePool(poolDoc.id, pool, gameData);
  }
}

/**
 * Settles a single pool and distributes winnings
 */
async function settlePool(poolId, poolData, gameData) {
  const { participants, totalPot, type } = poolData;
  
  if (!participants || participants.length === 0) {
    console.log(`Pool ${poolId} has no participants`);
    return;
  }
  
  // Determine winners based on pool type
  const winners = await determinePoolWinners(poolId, participants, gameData);
  
  if (winners.length === 0) {
    console.log(`Pool ${poolId} has no winners`);
    // Return buy-ins to all participants
    for (const participant of participants) {
      await processPayout(participant.userId, poolData.buyIn, poolId, gameData.id);
    }
    return;
  }
  
  // Calculate prize distribution
  const prizePerWinner = Math.floor(totalPot / winners.length);
  
  // Pay out winners
  for (const winner of winners) {
    await processPayout(winner.userId, prizePerWinner, poolId, gameData.id);
  }
  
  // Update pool status
  await db.collection('pools').doc(poolId).update({
    status: 'settled',
    settledAt: FieldValue.serverTimestamp(),
    winners: winners.map(w => w.userId),
    prizePerWinner: prizePerWinner
  });
  
  console.log(`Settled pool ${poolId}: ${winners.length} winners, ${prizePerWinner} BR each`);
}

/**
 * Determines pool winners based on bet results
 */
async function determinePoolWinners(poolId, participants, gameData) {
  const winners = [];
  
  for (const participant of participants) {
    if (participant.betId) {
      const betDoc = await db.collection('bets').doc(participant.betId).get();
      if (betDoc.exists && betDoc.data().status === 'won') {
        winners.push(participant);
      }
    }
  }
  
  return winners;
}

// ============================================
// SCHEDULED FUNCTIONS
// ============================================

/**
 * Weekly BR allowance distribution
 * Runs every Monday at 9 AM EST
 */
exports.weeklyAllowance = functions.pubsub
  .schedule('0 9 * * 1')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Starting weekly BR allowance distribution...');
    
    const usersSnapshot = await db.collection('users')
      .where('isActive', '!=', false)
      .get();
    
    if (usersSnapshot.empty) {
      console.log('No active users found');
      return null;
    }
    
    let successCount = 0;
    let errorCount = 0;
    const allowanceAmount = 25; // Weekly BR allowance
    
    // Process each user
    const promises = usersSnapshot.docs.map(async (userDoc) => {
      const userId = userDoc.id;
      const userData = userDoc.data();
      
      try {
        // Check last allowance date
        const walletRef = db.collection('users').doc(userId)
          .collection('wallet').doc('current');
        
        const walletDoc = await walletRef.get();
        
        if (!walletDoc.exists) {
          console.error(`Wallet not found for user ${userId}`);
          errorCount++;
          return;
        }
        
        const walletData = walletDoc.data();
        const lastAllowance = walletData.lastAllowance?.toDate();
        const now = new Date();
        
        // Check if 7 days have passed
        if (lastAllowance) {
          const daysSinceLastAllowance = Math.floor(
            (now - lastAllowance) / (1000 * 60 * 60 * 24)
          );
          
          if (daysSinceLastAllowance < 7) {
            console.log(`User ${userId} received allowance ${daysSinceLastAllowance} days ago, skipping`);
            return;
          }
        }
        
        // Process allowance
        await processAllowance(userId, allowanceAmount);
        successCount++;
        
      } catch (error) {
        console.error(`Error processing allowance for user ${userId}:`, error);
        errorCount++;
      }
    });
    
    await Promise.all(promises);
    
    console.log(`Weekly allowance complete: ${successCount} success, ${errorCount} errors`);
    
    // Log summary
    await db.collection('system_logs').add({
      type: 'weekly_allowance',
      timestamp: FieldValue.serverTimestamp(),
      successCount,
      errorCount,
      totalAmount: successCount * allowanceAmount
    });
    
    return null;
  });

/**
 * Processes weekly allowance for a user
 */
async function processAllowance(userId, amount) {
  const walletRef = db.collection('users').doc(userId)
    .collection('wallet').doc('current');
  
  const transactionRef = db.collection('transactions').doc();
  
  await db.runTransaction(async (transaction) => {
    const walletDoc = await transaction.get(walletRef);
    const currentBalance = walletDoc.data().balance || 0;
    const newBalance = currentBalance + amount;
    
    // Update wallet
    transaction.update(walletRef, {
      balance: newBalance,
      lastAllowance: FieldValue.serverTimestamp()
    });
    
    // Create transaction record
    transaction.set(transactionRef, {
      userId: userId,
      type: 'allowance',
      amount: amount,
      description: 'Weekly BR allowance',
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      timestamp: FieldValue.serverTimestamp(),
      status: 'completed'
    });
  });
  
  console.log(`Distributed ${amount} BR allowance to user ${userId}`);
}

// ============================================
// HTTP CALLABLE FUNCTIONS
// ============================================

/**
 * Manually trigger bet settlement for testing
 * (Admin only)
 */
exports.manualSettleGame = functions.https.onCall(async (data, context) => {
  // Verify admin status
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can manually settle games'
    );
  }
  
  const { gameId } = data;
  
  if (!gameId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'gameId is required'
    );
  }
  
  // Get game data
  const gameDoc = await db.collection('games').doc(gameId).get();
  
  if (!gameDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Game not found'
    );
  }
  
  const gameData = gameDoc.data();
  
  if (gameData.status !== 'final') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Game must be in final status to settle'
    );
  }
  
  try {
    await settleBetsForGame(gameId, gameData);
    await settlePoolsForGame(gameId, gameData);
    
    return {
      success: true,
      message: `Successfully settled bets for game ${gameId}`
    };
  } catch (error) {
    console.error('Manual settlement error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to settle game',
      error.message
    );
  }
});

/**
 * Cancel a bet (user request)
 */
exports.cancelBet = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = context.auth.uid;
  const { betId } = data;
  
  if (!betId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'betId is required'
    );
  }
  
  // Get bet document
  const betRef = db.collection('bets').doc(betId);
  const betDoc = await betRef.get();
  
  if (!betDoc.exists) {
    throw new functions.https.HttpsError(
      'not-found',
      'Bet not found'
    );
  }
  
  const bet = betDoc.data();
  
  // Verify ownership
  if (bet.userId !== userId) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'You can only cancel your own bets'
    );
  }
  
  // Check if bet can be cancelled
  if (bet.status !== 'pending') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Only pending bets can be cancelled'
    );
  }
  
  // Check if game has started
  const gameDoc = await db.collection('games').doc(bet.gameId).get();
  if (gameDoc.exists && gameDoc.data().status !== 'scheduled') {
    throw new functions.https.HttpsError(
      'failed-precondition',
      'Cannot cancel bet after game has started'
    );
  }
  
  try {
    // Refund the wager
    await processRefund(userId, bet.wagerAmount, betId);
    
    // Update bet status
    await betRef.update({
      status: 'cancelled',
      cancelledAt: FieldValue.serverTimestamp()
    });
    
    return {
      success: true,
      message: 'Bet cancelled successfully',
      refundAmount: bet.wagerAmount
    };
  } catch (error) {
    console.error('Bet cancellation error:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to cancel bet',
      error.message
    );
  }
});

/**
 * Process refund to user's wallet
 */
async function processRefund(userId, amount, betId) {
  const walletRef = db.collection('users').doc(userId)
    .collection('wallet').doc('current');
  
  const transactionRef = db.collection('transactions').doc();
  
  await db.runTransaction(async (transaction) => {
    const walletDoc = await transaction.get(walletRef);
    const currentBalance = walletDoc.data().balance || 0;
    const newBalance = currentBalance + amount;
    
    // Update wallet
    transaction.update(walletRef, {
      balance: newBalance
    });
    
    // Create transaction record
    transaction.set(transactionRef, {
      userId: userId,
      type: 'refund',
      amount: amount,
      description: 'Bet cancellation refund',
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      timestamp: FieldValue.serverTimestamp(),
      relatedId: betId,
      status: 'completed'
    });
  });
}

/**
 * Get user's current stats and ranking
 */
exports.getUserStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError(
      'unauthenticated',
      'User must be authenticated'
    );
  }
  
  const userId = context.auth.uid;
  
  // Get user stats
  const statsDoc = await db.collection('users').doc(userId)
    .collection('stats').doc('current').get();
  
  const stats = statsDoc.exists ? statsDoc.data() : {
    totalBets: 0,
    wins: 0,
    losses: 0,
    winRate: 0,
    totalWagered: 0,
    totalWinnings: 0,
    currentStreak: 0,
    bestStreak: 0
  };
  
  // Get user's ranking
  const ranking = await getUserRanking(userId);
  
  return {
    stats,
    ranking
  };
});

/**
 * Get user's ranking on leaderboard
 */
async function getUserRanking(userId) {
  // This is a simplified ranking system
  // In production, you'd want to optimize this with scheduled calculations
  
  const usersSnapshot = await db.collection('users').get();
  const userStats = [];
  
  for (const doc of usersSnapshot.docs) {
    const statsDoc = await doc.ref.collection('stats').doc('current').get();
    if (statsDoc.exists) {
      const stats = statsDoc.data();
      userStats.push({
        userId: doc.id,
        wins: stats.wins || 0,
        winRate: stats.winRate || 0,
        profit: (stats.totalWinnings || 0) - (stats.totalWagered || 0)
      });
    }
  }
  
  // Sort by profit
  userStats.sort((a, b) => b.profit - a.profit);
  
  // Find user's rank
  const userIndex = userStats.findIndex(u => u.userId === userId);
  
  return {
    rank: userIndex + 1,
    totalPlayers: userStats.length,
    percentile: Math.round(((userStats.length - userIndex) / userStats.length) * 100)
  };
}

// ============================================
// ADMIN FUNCTIONS
// ============================================

/**
 * Set admin claim on a user (super admin only)
 */
exports.setAdminClaim = functions.https.onCall(async (data, context) => {
  // This should only be called by existing admins
  // For initial setup, use Firebase Console or Admin SDK directly
  
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can set admin claims'
    );
  }
  
  const { targetUserId, isAdmin } = data;
  
  if (!targetUserId) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'targetUserId is required'
    );
  }
  
  try {
    await admin.auth().setCustomUserClaims(targetUserId, { admin: isAdmin });
    
    return {
      success: true,
      message: `Admin claim ${isAdmin ? 'set' : 'removed'} for user ${targetUserId}`
    };
  } catch (error) {
    console.error('Error setting admin claim:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to set admin claim'
    );
  }
});

// ============================================
// EXPORT LEADERBOARD FUNCTIONS
// ============================================

const leaderboard = require('./leaderboard');

// Scheduled functions
exports.updateDailyLeaderboard = leaderboard.updateDailyLeaderboard;
exports.updateWeeklyLeaderboard = leaderboard.updateWeeklyLeaderboard;
exports.updateMonthlyLeaderboard = leaderboard.updateMonthlyLeaderboard;
exports.updateAllTimeLeaderboard = leaderboard.updateAllTimeLeaderboard;

// Triggered functions
exports.onBetSettled = leaderboard.onBetSettled;

// Callable functions
exports.getLeaderboard = leaderboard.getLeaderboard;
exports.getUserRankings = leaderboard.getUserRankings;
exports.getFriendsLeaderboard = leaderboard.getFriendsLeaderboard;
exports.forceUpdateLeaderboard = leaderboard.forceUpdateLeaderboard;

// ============================================
// EXPORT NOTIFICATION FUNCTIONS
// ============================================

const notifications = require('./notifications');

// Triggered notifications
exports.onBetSettledNotification = notifications.onBetSettledNotification;
exports.onPoolInvitation = notifications.onPoolInvitation;
exports.onWeeklyAllowanceNotification = notifications.onWeeklyAllowanceNotification;
exports.onFriendRequest = notifications.onFriendRequest;
exports.onLeaderboardRankChange = notifications.onLeaderboardRankChange;

// Scheduled notifications
exports.sendGameReminders = notifications.sendGameReminders;

// Callable functions
exports.registerFCMToken = notifications.registerFCMToken;
exports.updateNotificationPreferences = notifications.updateNotificationPreferences;
exports.sendTestNotification = notifications.sendTestNotification;
exports.markNotificationsRead = notifications.markNotificationsRead;

// ============================================
// EXPORT PURCHASE FUNCTIONS
// ============================================

const purchases = require('./purchases');

// Callable functions
exports.verifyPurchase = purchases.verifyPurchase;
exports.grantPromotionalCoins = purchases.grantPromotionalCoins;
exports.applyReferralBonus = purchases.applyReferralBonus;

// Scheduled functions
exports.checkPremiumStatus = purchases.checkPremiumStatus;

// ============================================
// EXPORT SPORTS DATA FUNCTIONS
// ============================================

const sportsData = require('./sportsData');

// Scheduled functions
exports.updateLiveGames = sportsData.updateLiveGames;
exports.updateGameSchedules = sportsData.updateGameSchedules;
exports.updateOdds = sportsData.updateOdds;

// Callable functions
exports.getLiveGames = sportsData.getLiveGames;
exports.getUpcomingGames = sportsData.getUpcomingGames;
exports.forceUpdateGames = sportsData.forceUpdateGames;

console.log('Cloud Functions initialized for Bragging Rights');