/**
 * Diagnostic script to check bet settlement status
 * Run with: node diagnose_settlement.js
 */

const admin = require('firebase-admin');
const serviceAccount = require('./bragging-rights-ea6e1-firebase-adminsdk-b5q87-d5c0cdbb35.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function diagnoseBetSettlement() {
  console.log('🔍 DIAGNOSING BET SETTLEMENT ISSUE\n');
  console.log('=' .repeat(60));

  try {
    // 1. Check recent games and their status
    console.log('\n📊 1. CHECKING RECENT GAMES:');
    console.log('-'.repeat(60));

    const gamesSnapshot = await db.collection('games')
      .orderBy('gameTime', 'desc')
      .limit(10)
      .get();

    console.log(`Found ${gamesSnapshot.size} recent games:\n`);

    for (const gameDoc of gamesSnapshot.docs) {
      const game = gameDoc.data();
      console.log(`Game ID: ${gameDoc.id}`);
      console.log(`  Title: ${game.gameTitle || 'N/A'}`);
      console.log(`  Sport: ${game.sport || 'N/A'}`);
      console.log(`  Status: ${game.status || 'N/A'}`);
      console.log(`  Time: ${game.gameTime ? game.gameTime.toDate() : 'N/A'}`);
      console.log(`  Home Score: ${game.homeScore ?? 'N/A'}`);
      console.log(`  Away Score: ${game.awayScore ?? 'N/A'}`);
      console.log('');
    }

    // 2. Check for games with status='final'
    console.log('\n🏁 2. CHECKING GAMES WITH STATUS="final":');
    console.log('-'.repeat(60));

    const finalGamesSnapshot = await db.collection('games')
      .where('status', '==', 'final')
      .limit(5)
      .get();

    console.log(`Found ${finalGamesSnapshot.size} games with status="final"\n`);

    for (const gameDoc of finalGamesSnapshot.docs) {
      const game = gameDoc.data();
      console.log(`Game ID: ${gameDoc.id}`);
      console.log(`  Title: ${game.gameTitle || 'N/A'}`);
      console.log(`  Final Score: ${game.homeScore ?? '?'} - ${game.awayScore ?? '?'}`);
      console.log('');
    }

    // 3. Check pending bets
    console.log('\n⏳ 3. CHECKING PENDING BETS:');
    console.log('-'.repeat(60));

    const pendingBetsSnapshot = await db.collection('bets')
      .where('status', '==', 'pending')
      .limit(10)
      .get();

    console.log(`Found ${pendingBetsSnapshot.size} pending bets:\n`);

    for (const betDoc of pendingBetsSnapshot.docs) {
      const bet = betDoc.data();
      console.log(`Bet ID: ${betDoc.id}`);
      console.log(`  User: ${bet.userId}`);
      console.log(`  Game ID: ${bet.gameId}`);
      console.log(`  Game Title: ${bet.gameTitle || 'N/A'}`);
      console.log(`  Sport: ${bet.sport || 'N/A'}`);
      console.log(`  Wager: ${bet.wagerAmount} BR`);
      console.log(`  Placed: ${bet.placedAt ? bet.placedAt.toDate() : 'N/A'}`);

      // Check if game exists and its status
      const gameDoc = await db.collection('games').doc(bet.gameId).get();
      if (gameDoc.exists) {
        const game = gameDoc.data();
        console.log(`  ⚠️ GAME STATUS: ${game.status}`);
        console.log(`  Game Time: ${game.gameTime ? game.gameTime.toDate() : 'N/A'}`);
        if (game.status === 'final') {
          console.log(`  ❗ ISSUE: Bet is pending but game is FINAL!`);
          console.log(`     Final Score: ${game.homeScore ?? '?'} - ${game.awayScore ?? '?'}`);
        }
      } else {
        console.log(`  ❌ GAME NOT FOUND!`);
      }
      console.log('');
    }

    // 4. Check past bets (won/lost/refunded)
    console.log('\n📜 4. CHECKING PAST BETS:');
    console.log('-'.repeat(60));

    const pastBetsSnapshot = await db.collection('bets')
      .where('status', 'in', ['won', 'lost', 'expired', 'cancelled', 'cashed_out'])
      .limit(10)
      .get();

    console.log(`Found ${pastBetsSnapshot.size} past bets:\n`);

    const statusCounts = {};
    for (const betDoc of pastBetsSnapshot.docs) {
      const bet = betDoc.data();
      const status = bet.status;
      statusCounts[status] = (statusCounts[status] || 0) + 1;
    }

    console.log('Status breakdown:');
    for (const [status, count] of Object.entries(statusCounts)) {
      console.log(`  ${status}: ${count}`);
    }
    console.log('');

    // 5. Summary
    console.log('\n📋 5. SUMMARY & DIAGNOSIS:');
    console.log('='.repeat(60));

    // Check for mismatch
    const pendingWithFinalGames = [];
    for (const betDoc of pendingBetsSnapshot.docs) {
      const bet = betDoc.data();
      const gameDoc = await db.collection('games').doc(bet.gameId).get();
      if (gameDoc.exists && gameDoc.data().status === 'final') {
        pendingWithFinalGames.push({
          betId: betDoc.id,
          gameId: bet.gameId,
          gameTitle: bet.gameTitle
        });
      }
    }

    if (pendingWithFinalGames.length > 0) {
      console.log('\n❌ CRITICAL ISSUE FOUND:');
      console.log(`   ${pendingWithFinalGames.length} pending bet(s) have finished games!`);
      console.log('   This means the settleGameBets trigger is NOT firing.\n');
      console.log('   Affected bets:');
      for (const bet of pendingWithFinalGames) {
        console.log(`     - Bet ${bet.betId} (${bet.gameTitle})`);
      }
      console.log('\n   POSSIBLE CAUSES:');
      console.log('   1. Game documents are not being updated in Firestore');
      console.log('   2. Games are written with status="final" initially (no update trigger)');
      console.log('   3. Firestore trigger is not working correctly');
      console.log('   4. Games are in a different collection or subcollection');
    } else if (finalGamesSnapshot.size > 0 && pendingBetsSnapshot.size === 0) {
      console.log('\n✅ SETTLEMENT APPEARS TO BE WORKING:');
      console.log('   Games are marked as final and no pending bets remain.');
    } else if (finalGamesSnapshot.size === 0) {
      console.log('\n⚠️ NO FINAL GAMES FOUND:');
      console.log('   Games may not be getting marked as "final" in Firestore.');
      console.log('   Check your game update logic in the Flutter app.');
    } else {
      console.log('\n✅ NO OBVIOUS ISSUES DETECTED');
      console.log('   Manual investigation may be needed.');
    }

    console.log('\n' + '='.repeat(60));

  } catch (error) {
    console.error('\n❌ ERROR:', error);
  } finally {
    process.exit(0);
  }
}

diagnoseBetSettlement();
