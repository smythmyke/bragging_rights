/**
 * Manual Settlement Script for Stuck Bets
 *
 * This script finds and settles bets that are stuck in 'pending' status
 * for games that have already finished (status='final').
 *
 * Run with: node manual_settle_stuck_bets.js
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin (uses default credentials from environment)
admin.initializeApp();

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

async function manualSettleStuckBets() {
  console.log('🔧 MANUAL BET SETTLEMENT SCRIPT');
  console.log('=' .repeat(60));
  console.log('Finding stuck bets with finished games...\n');

  try {
    // Step 1: Find all pending bets
    const pendingBetsSnapshot = await db.collection('bets')
      .where('status', '==', 'pending')
      .get();

    if (pendingBetsSnapshot.empty) {
      console.log('✅ No pending bets found. All bets are settled!');
      return;
    }

    console.log(`📊 Found ${pendingBetsSnapshot.size} pending bets`);
    console.log('Checking which games have finished...\n');

    const stuckBets = [];

    // Step 2: Check each bet's game status
    for (const betDoc of pendingBetsSnapshot.docs) {
      const bet = betDoc.data();
      const betId = betDoc.id;

      // Get the game document
      const gameDoc = await db.collection('games').doc(bet.gameId).get();

      if (!gameDoc.exists) {
        console.log(`⚠️  Bet ${betId}: Game ${bet.gameId} not found`);
        stuckBets.push({
          betId,
          bet,
          issue: 'game_not_found'
        });
        continue;
      }

      const game = gameDoc.data();

      // Check if game is final
      if (game.status === 'final') {
        console.log(`❌ STUCK BET FOUND: ${betId}`);
        console.log(`   Game: ${bet.gameTitle || game.gameTitle}`);
        console.log(`   Game Status: ${game.status}`);
        console.log(`   Score: ${game.homeScore} - ${game.awayScore}`);
        console.log(`   Wager: ${bet.wagerAmount} BR`);
        console.log('');

        stuckBets.push({
          betId,
          bet,
          game,
          issue: 'game_finished_but_bet_pending'
        });
      }
    }

    if (stuckBets.length === 0) {
      console.log('✅ No stuck bets found! All pending bets are for ongoing games.');
      return;
    }

    console.log('\n' + '='.repeat(60));
    console.log(`🚨 FOUND ${stuckBets.length} STUCK BETS`);
    console.log('='.repeat(60));

    // Step 3: Trigger settlement for each stuck bet's game
    console.log('\n🔧 Triggering settlement for stuck bets...\n');

    let settledCount = 0;
    let errorCount = 0;

    for (const stuckBet of stuckBets) {
      try {
        if (stuckBet.issue === 'game_not_found') {
          console.log(`⚠️  Refunding bet ${stuckBet.betId} - game not found`);
          // Refund the bet since game doesn't exist
          await db.collection('bets').doc(stuckBet.betId).update({
            status: 'expired',
            settledAt: FieldValue.serverTimestamp(),
            settlementNote: 'Game not found - auto-refunded by manual script'
          });

          // Refund to wallet
          const walletRef = db.collection('users').doc(stuckBet.bet.userId)
            .collection('wallet').doc('current');
          await walletRef.update({
            balance: FieldValue.increment(stuckBet.bet.wagerAmount)
          });

          settledCount++;
          continue;
        }

        // Trigger settlement by updating the game with betsSettled=false
        // This will cause the Cloud Function to process it
        console.log(`🔄 Triggering settlement for game ${stuckBet.bet.gameId}...`);

        await db.collection('games').doc(stuckBet.bet.gameId).update({
          betsSettled: false,  // Force re-settlement
          lastManualSettlementTrigger: FieldValue.serverTimestamp()
        });

        console.log(`✅ Triggered settlement for bet ${stuckBet.betId}`);
        settledCount++;

        // Wait a bit to avoid overwhelming Firestore
        await new Promise(resolve => setTimeout(resolve, 500));

      } catch (error) {
        console.error(`❌ Error settling bet ${stuckBet.betId}:`, error.message);
        errorCount++;
      }
    }

    console.log('\n' + '='.repeat(60));
    console.log('📊 SETTLEMENT SUMMARY');
    console.log('='.repeat(60));
    console.log(`Total stuck bets: ${stuckBets.length}`);
    console.log(`Successfully triggered: ${settledCount}`);
    console.log(`Errors: ${errorCount}`);
    console.log('\n✅ Manual settlement script completed!');
    console.log('⏰ Please wait 30-60 seconds for Cloud Functions to process the settlements.');

  } catch (error) {
    console.error('\n❌ FATAL ERROR:', error);
    throw error;
  }
}

// Run the script
manualSettleStuckBets()
  .then(() => {
    console.log('\n👋 Script finished. Exiting...');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n💥 Script failed:', error);
    process.exit(1);
  });
