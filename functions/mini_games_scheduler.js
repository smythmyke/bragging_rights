/**
 * Mini-Games Weekly Scheduler
 * Handles weekly leaderboard rotation and prize distribution
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');

// Initialize admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

/**
 * Weekly Leaderboard Rotation
 * Runs every Monday at 12:00 AM UTC
 * Archives old leaderboards and creates new ones
 */
exports.rotateWeeklyLeaderboards = functions.pubsub
  .schedule('0 0 * * 1') // Every Monday at midnight
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🔄 Starting weekly leaderboard rotation...');

    try {
      const now = new Date();
      const weekNumber = getWeekNumber(now);

      // Get all active games
      const gamesSnapshot = await db.collection('mini-games')
        .where('active', '==', true)
        .get();

      if (gamesSnapshot.empty) {
        console.log('⚠️ No active games found');
        return null;
      }

      const batch = db.batch();
      let rotationCount = 0;

      for (const gameDoc of gamesSnapshot.docs) {
        const gameId = gameDoc.id;
        const previousWeek = weekNumber - 1;

        // Archive previous week's leaderboard
        const oldLeaderboardId = `${gameId}_week_${previousWeek}`;
        const oldLeaderboardRef = db.collection('leaderboards').doc(oldLeaderboardId);

        batch.update(oldLeaderboardRef, {
          active: false,
          archivedAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        // Create new leaderboard for current week
        const newLeaderboardId = `${gameId}_week_${weekNumber}`;
        const weekStart = getWeekStart(now);
        const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000);

        const newLeaderboardRef = db.collection('leaderboards').doc(newLeaderboardId);
        batch.set(newLeaderboardRef, {
          gameId: gameId,
          weekStart: admin.firestore.Timestamp.fromDate(weekStart),
          weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
          scores: [],
          active: true,
          createdAt: admin.firestore.FieldValue.serverTimestamp(),
        });

        rotationCount++;
        console.log(`✅ Rotated leaderboard for game: ${gameId}`);
      }

      await batch.commit();
      console.log(`🎉 Successfully rotated ${rotationCount} leaderboards`);

      return { success: true, rotated: rotationCount };
    } catch (error) {
      console.error('❌ Error rotating leaderboards:', error);
      throw error;
    }
  });

/**
 * Distribute Weekly Prizes
 * Runs every Monday at 12:30 AM UTC (30 minutes after rotation)
 * Awards BR to top 10 players
 */
exports.distributeWeeklyPrizes = functions.pubsub
  .schedule('30 0 * * 1') // Every Monday at 12:30 AM
  .timeZone('UTC')
  .onRun(async (context) => {
    console.log('🏆 Starting weekly prize distribution...');

    try {
      const now = new Date();
      const previousWeek = getWeekNumber(now) - 1;

      // Get all archived leaderboards from previous week
      const leaderboardsSnapshot = await db.collection('leaderboards')
        .where('active', '==', false)
        .where('archivedAt', '>', new Date(Date.now() - 24 * 60 * 60 * 1000)) // Last 24 hours
        .get();

      if (leaderboardsSnapshot.empty) {
        console.log('⚠️ No leaderboards to process');
        return null;
      }

      let totalPrizesDistributed = 0;
      let totalBRAwarded = 0;

      for (const leaderboardDoc of leaderboardsSnapshot.docs) {
        const leaderboard = leaderboardDoc.data();
        const gameId = leaderboard.gameId;

        if (!leaderboard.scores || leaderboard.scores.length === 0) {
          console.log(`⚠️ No scores for game: ${gameId}`);
          continue;
        }

        // Sort scores (highest first)
        const sortedScores = [...leaderboard.scores].sort((a, b) => b.score - a.score);

        // Get unique top players (in case same user has multiple scores)
        const uniquePlayers = [];
        const seenUserIds = new Set();

        for (const entry of sortedScores) {
          if (!seenUserIds.has(entry.userId)) {
            seenUserIds.add(entry.userId);
            uniquePlayers.push(entry);
          }
          if (uniquePlayers.length >= 10) break;
        }

        // Prize structure
        const prizes = [
          { rank: 1, amount: 500 },
          { rank: 2, amount: 250 },
          { rank: 3, amount: 100 },
          { rank: 4, amount: 50 },
          { rank: 5, amount: 50 },
          { rank: 6, amount: 50 },
          { rank: 7, amount: 50 },
          { rank: 8, amount: 50 },
          { rank: 9, amount: 50 },
          { rank: 10, amount: 50 },
        ];

        // Distribute prizes
        const batch = db.batch();

        for (let i = 0; i < Math.min(uniquePlayers.length, 10); i++) {
          const player = uniquePlayers[i];
          const prize = prizes[i];

          // Award BR to user
          const userRef = db.collection('users').doc(player.userId);
          batch.update(userRef, {
            braggingRights: admin.firestore.FieldValue.increment(prize.amount),
          });

          // Log prize transaction
          const transactionRef = db.collection('transactions').doc();
          batch.set(transactionRef, {
            userId: player.userId,
            type: 'mini_game_prize',
            amount: prize.amount,
            gameId: gameId,
            rank: prize.rank,
            weekNumber: previousWeek,
            timestamp: admin.firestore.FieldValue.serverTimestamp(),
            description: `Week ${previousWeek} - Rank #${prize.rank}`,
          });

          totalPrizesDistributed++;
          totalBRAwarded += prize.amount;

          console.log(`💰 Awarded ${prize.amount} BR to ${player.username} (Rank #${prize.rank})`);
        }

        await batch.commit();
      }

      console.log(`🎉 Prize distribution complete!`);
      console.log(`   Players rewarded: ${totalPrizesDistributed}`);
      console.log(`   Total BR awarded: ${totalBRAwarded}`);

      return {
        success: true,
        prizesDistributed: totalPrizesDistributed,
        totalBRAwarded: totalBRAwarded,
      };
    } catch (error) {
      console.error('❌ Error distributing prizes:', error);
      throw error;
    }
  });

/**
 * Manual trigger for prize distribution (for testing)
 * Call this HTTPS function to manually distribute prizes
 */
exports.manualDistributePrizes = functions.https.onCall(async (data, context) => {
  // Verify admin
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can manually distribute prizes'
    );
  }

  console.log('🔧 Manual prize distribution triggered by admin');

  try {
    const weekNumber = data.weekNumber || (getWeekNumber(new Date()) - 1);

    // Get specific week's leaderboards
    const leaderboardsSnapshot = await db.collection('leaderboards')
      .where('active', '==', false)
      .get();

    let totalPrizesDistributed = 0;
    let totalBRAwarded = 0;

    for (const leaderboardDoc of leaderboardsSnapshot.docs) {
      const leaderboard = leaderboardDoc.data();
      const gameId = leaderboard.gameId;

      if (!leaderboard.scores || leaderboard.scores.length === 0) {
        continue;
      }

      const sortedScores = [...leaderboard.scores].sort((a, b) => b.score - a.score);

      const uniquePlayers = [];
      const seenUserIds = new Set();

      for (const entry of sortedScores) {
        if (!seenUserIds.has(entry.userId)) {
          seenUserIds.add(entry.userId);
          uniquePlayers.push(entry);
        }
        if (uniquePlayers.length >= 10) break;
      }

      const prizes = [
        { rank: 1, amount: 500 },
        { rank: 2, amount: 250 },
        { rank: 3, amount: 100 },
        { rank: 4, amount: 50 },
        { rank: 5, amount: 50 },
        { rank: 6, amount: 50 },
        { rank: 7, amount: 50 },
        { rank: 8, amount: 50 },
        { rank: 9, amount: 50 },
        { rank: 10, amount: 50 },
      ];

      const batch = db.batch();

      for (let i = 0; i < Math.min(uniquePlayers.length, 10); i++) {
        const player = uniquePlayers[i];
        const prize = prizes[i];

        const userRef = db.collection('users').doc(player.userId);
        batch.update(userRef, {
          braggingRights: admin.firestore.FieldValue.increment(prize.amount),
        });

        const transactionRef = db.collection('transactions').doc();
        batch.set(transactionRef, {
          userId: player.userId,
          type: 'mini_game_prize',
          amount: prize.amount,
          gameId: gameId,
          rank: prize.rank,
          weekNumber: weekNumber,
          timestamp: admin.firestore.FieldValue.serverTimestamp(),
          description: `Week ${weekNumber} - Rank #${prize.rank} (Manual)`,
        });

        totalPrizesDistributed++;
        totalBRAwarded += prize.amount;
      }

      await batch.commit();
    }

    return {
      success: true,
      prizesDistributed: totalPrizesDistributed,
      totalBRAwarded: totalBRAwarded,
    };
  } catch (error) {
    console.error('❌ Error in manual prize distribution:', error);
    throw new functions.https.HttpsError('internal', error.message);
  }
});

// Helper functions

function getWeekNumber(date) {
  const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
  const daysSinceFirstDay = Math.floor((date - firstDayOfYear) / (24 * 60 * 60 * 1000));
  return Math.floor(daysSinceFirstDay / 7) + 1;
}

function getWeekStart(date) {
  const weekday = date.getDay();
  const daysToSubtract = weekday === 0 ? 6 : weekday - 1; // Monday is start
  const weekStart = new Date(date.getTime() - daysToSubtract * 24 * 60 * 60 * 1000);
  weekStart.setHours(0, 0, 0, 0);
  return weekStart;
}
