/**
 * Combat Sports Payout Distribution Module
 * Handles prize pool distribution based on rankings
 */

const admin = require('firebase-admin');
const db = admin.firestore();

// Predefined payout structures (100% payout - no house cut)
const PAYOUT_STRUCTURES = {
  QUICK_PLAY: {
    name: 'Quick Play',
    payoutPercent: 0.40, // Top 40% win
    payouts: {
      1: 0.30,   // 30% of pool
      2: 0.20,   // 20% of pool
      3: 0.15,   // 15% of pool
      4: 0.12,   // 12% of pool
      5: 0.08,   // 8% of pool
      6: 0.06,   // 6% of pool
      7: 0.05,   // 5% of pool
      8: 0.04,   // 4% of pool
    }
  },
  TOURNAMENT: {
    name: 'Tournament',
    payoutPercent: 0.25, // Top 25% win
    payouts: {
      1: 0.40,   // 40% of pool
      2: 0.25,   // 25% of pool
      3: 0.15,   // 15% of pool
      4: 0.10,   // 10% of pool
      5: 0.10,   // 10% of pool
    }
  },
  WINNER_TAKE_ALL: {
    name: 'Winner Take All',
    payoutPercent: 0.05, // Only winner (top 5%)
    payouts: {
      1: 1.00,   // 100% of pool
    }
  },
  TOP_3: {
    name: 'Top 3',
    payoutPercent: 0.15, // Top 15% win
    payouts: {
      1: 0.50,   // 50% of pool
      2: 0.30,   // 30% of pool
      3: 0.20,   // 20% of pool
    }
  }
};

/**
 * Distribute payouts for a settled pool
 * @param {string} poolId - Pool ID
 * @param {Array} rankings - Sorted array of user scores
 * @returns {Object} Payout summary
 */
async function distributePoolPayouts(poolId, rankings) {
  console.log(`Distributing payouts for pool ${poolId}`);

  try {
    // Get pool details
    const poolDoc = await db.collection('pools').doc(poolId).get();
    if (!poolDoc.exists) {
      throw new Error(`Pool ${poolId} not found`);
    }

    const pool = poolDoc.data();
    const entryFee = pool.entryFee || 0;
    const totalEntries = pool.totalEntries || rankings.length;
    const totalPot = entryFee * totalEntries;

    // Get payout structure
    const structureType = pool.payoutStructure || 'QUICK_PLAY';
    const structure = PAYOUT_STRUCTURES[structureType];

    if (!structure) {
      throw new Error(`Invalid payout structure: ${structureType}`);
    }

    console.log(`Pool ${poolId}: ${totalEntries} entries, ${totalPot} BR total pot, ${structure.name} structure`);

    // Calculate number of winners
    const winnersCount = Math.ceil(totalEntries * structure.payoutPercent);
    const payouts = [];

    // Distribute prizes based on structure
    for (let position = 1; position <= winnersCount && position <= rankings.length; position++) {
      const payoutPercent = structure.payouts[position] || 0;

      if (payoutPercent > 0) {
        const payoutAmount = Math.round(totalPot * payoutPercent);
        const user = rankings[position - 1];

        const payoutData = {
          userId: user.userId,
          username: user.username,
          position: position,
          score: user.totalScore,
          payoutAmount: payoutAmount,
          profit: payoutAmount - entryFee,
          payoutPercent: payoutPercent
        };

        payouts.push(payoutData);

        // Process the payout
        await processUserPayout(user.userId, poolId, payoutAmount, position);
      }
    }

    // Store payout summary
    const payoutSummary = {
      poolId: poolId,
      totalPot: totalPot,
      totalEntries: totalEntries,
      winnersCount: payouts.length,
      totalPaidOut: payouts.reduce((sum, p) => sum + p.payoutAmount, 0),
      payouts: payouts,
      structure: structureType,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    };

    await db.collection('pools')
      .doc(poolId)
      .collection('payouts')
      .doc('summary')
      .set(payoutSummary);

    // Update pool status
    await db.collection('pools').doc(poolId).update({
      status: 'SETTLED',
      settlementCompleted: admin.firestore.FieldValue.serverTimestamp(),
      payoutSummary: payoutSummary
    });

    console.log(`Payouts distributed for pool ${poolId}: ${payouts.length} winners`);

    return payoutSummary;

  } catch (error) {
    console.error(`Error distributing payouts for pool ${poolId}:`, error);
    throw error;
  }
}

/**
 * Process individual user payout
 * @param {string} userId - User ID
 * @param {string} poolId - Pool ID
 * @param {number} amount - Payout amount in BR
 * @param {number} position - Final position
 */
async function processUserPayout(userId, poolId, amount, position) {
  console.log(`Processing payout: User ${userId} receives ${amount} BR (Position: ${position})`);

  try {
    // Use transaction to ensure atomic updates
    await db.runTransaction(async (transaction) => {
      // Get user's wallet
      const walletRef = db.collection('users').doc(userId).collection('wallet').doc('balance');
      const walletDoc = await transaction.get(walletRef);

      let currentBalance = 0;
      if (walletDoc.exists) {
        currentBalance = walletDoc.data().balance || 0;
      }

      const newBalance = currentBalance + amount;

      // Update wallet balance
      transaction.set(walletRef, {
        balance: newBalance,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });

      // Create transaction record
      const transactionRef = db.collection('users')
        .doc(userId)
        .collection('transactions')
        .doc();

      transaction.set(transactionRef, {
        type: 'PAYOUT',
        poolId: poolId,
        amount: amount,
        position: position,
        balanceBefore: currentBalance,
        balanceAfter: newBalance,
        description: `Pool winnings - Position #${position}`,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

      // Update user stats
      const statsRef = db.collection('users').doc(userId).collection('stats').doc('combat_sports');
      const statsDoc = await transaction.get(statsRef);

      if (statsDoc.exists) {
        const stats = statsDoc.data();
        const updates = {
          totalWinnings: (stats.totalWinnings || 0) + amount,
          lastWin: admin.firestore.FieldValue.serverTimestamp()
        };

        // Track wins and top 3 finishes
        if (position === 1) {
          updates.wins = (stats.wins || 0) + 1;
        }
        if (position <= 3) {
          updates.top3Finishes = (stats.top3Finishes || 0) + 1;
        }

        transaction.update(statsRef, updates);
      }
    });

    // Queue notification for the user
    await queuePayoutNotification(userId, amount, position, poolId);

    console.log(`Payout processed successfully for user ${userId}`);

  } catch (error) {
    console.error(`Error processing payout for user ${userId}:`, error);
    throw error;
  }
}

/**
 * Queue notification for payout
 * @param {string} userId - User ID
 * @param {number} amount - Payout amount
 * @param {number} position - Final position
 * @param {string} poolId - Pool ID
 */
async function queuePayoutNotification(userId, amount, position, poolId) {
  try {
    // Get user's FCM token
    const userDoc = await db.collection('users').doc(userId).get();
    if (!userDoc.exists) return;

    const userData = userDoc.data();
    const fcmToken = userData.fcmToken;

    if (!fcmToken) {
      console.log(`No FCM token for user ${userId}, skipping notification`);
      return;
    }

    // Get pool details for notification
    const poolDoc = await db.collection('pools').doc(poolId).get();
    const poolData = poolDoc.data();

    // Create notification payload
    const notification = {
      token: fcmToken,
      notification: {
        title: position === 1 ? '🏆 You Won!' : `🎉 You Placed #${position}!`,
        body: `You earned ${amount} BR in the ${poolData.name || 'pool'}!`,
      },
      data: {
        type: 'PAYOUT',
        poolId: poolId,
        amount: amount.toString(),
        position: position.toString(),
        timestamp: new Date().toISOString()
      },
      android: {
        priority: 'high',
        notification: {
          sound: 'default',
          priority: 'high',
          visibility: 'public'
        }
      },
      apns: {
        payload: {
          aps: {
            sound: 'default',
            badge: 1
          }
        }
      }
    };

    // Send notification
    const messaging = admin.messaging();
    await messaging.send(notification);

    console.log(`Payout notification sent to user ${userId}`);

  } catch (error) {
    console.error(`Error sending payout notification:`, error);
    // Don't throw - notification failure shouldn't stop payout process
  }
}

/**
 * Handle refunds for cancelled events
 * @param {string} eventId - Event ID
 * @param {string} reason - Cancellation reason
 */
async function refundCancelledEvent(eventId, reason) {
  console.log(`Processing refunds for cancelled event ${eventId}`);

  try {
    // Get all pools for the event
    const poolsSnapshot = await db.collection('pools')
      .where('eventId', '==', eventId)
      .where('status', '!=', 'SETTLED')
      .get();

    const refundSummary = {
      eventId: eventId,
      reason: reason,
      totalPools: 0,
      totalUsers: 0,
      totalRefunded: 0,
      refunds: []
    };

    // Process each pool
    for (const poolDoc of poolsSnapshot.docs) {
      const pool = poolDoc.data();
      const poolId = poolDoc.id;
      refundSummary.totalPools++;

      // Get all entries in the pool
      const entriesSnapshot = await db.collection('pools')
        .doc(poolId)
        .collection('entries')
        .get();

      // Refund each entry
      for (const entryDoc of entriesSnapshot.docs) {
        const entry = entryDoc.data();
        const userId = entry.userId;
        const refundAmount = pool.entryFee;

        await processRefund(userId, poolId, refundAmount, reason);

        refundSummary.totalUsers++;
        refundSummary.totalRefunded += refundAmount;
        refundSummary.refunds.push({
          userId: userId,
          poolId: poolId,
          amount: refundAmount
        });
      }

      // Update pool status
      await db.collection('pools').doc(poolId).update({
        status: 'CANCELLED',
        cancellationReason: reason,
        cancelledAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }

    // Store refund summary
    await db.collection('events')
      .doc(eventId)
      .collection('refunds')
      .doc('summary')
      .set({
        ...refundSummary,
        timestamp: admin.firestore.FieldValue.serverTimestamp()
      });

    console.log(`Refunds completed for event ${eventId}: ${refundSummary.totalUsers} users refunded`);

    return refundSummary;

  } catch (error) {
    console.error(`Error processing refunds for event ${eventId}:`, error);
    throw error;
  }
}

/**
 * Process individual refund
 * @param {string} userId - User ID
 * @param {string} poolId - Pool ID
 * @param {number} amount - Refund amount
 * @param {string} reason - Refund reason
 */
async function processRefund(userId, poolId, amount, reason) {
  await db.runTransaction(async (transaction) => {
    // Get user's wallet
    const walletRef = db.collection('users').doc(userId).collection('wallet').doc('balance');
    const walletDoc = await transaction.get(walletRef);

    let currentBalance = 0;
    if (walletDoc.exists) {
      currentBalance = walletDoc.data().balance || 0;
    }

    const newBalance = currentBalance + amount;

    // Update wallet balance
    transaction.set(walletRef, {
      balance: newBalance,
      lastUpdated: admin.firestore.FieldValue.serverTimestamp()
    }, { merge: true });

    // Create transaction record
    const transactionRef = db.collection('users')
      .doc(userId)
      .collection('transactions')
      .doc();

    transaction.set(transactionRef, {
      type: 'REFUND',
      poolId: poolId,
      amount: amount,
      balanceBefore: currentBalance,
      balanceAfter: newBalance,
      description: `Pool entry refund - ${reason}`,
      timestamp: admin.firestore.FieldValue.serverTimestamp()
    });
  });
}

module.exports = {
  distributePoolPayouts,
  processUserPayout,
  refundCancelledEvent,
  PAYOUT_STRUCTURES
};