/**
 * Bet Settlement Diagnostic Script
 *
 * This script analyzes why bets are showing as "refunded" instead of being properly settled.
 * It checks:
 * 1. Bet documents and their gameIds
 * 2. Whether matching game documents exist
 * 3. Game status and betsSettled flags
 * 4. Transaction history
 *
 * Usage:
 *   node scripts/diagnose_bet_settlement.js [--user-id=<uid>]
 */

const admin = require('firebase-admin');
const path = require('path');

// Initialize Firebase Admin
const serviceAccountPath = path.join(__dirname, '..', 'service-account-key.json');
const serviceAccount = require(serviceAccountPath);

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  databaseURL: "https://bragging-rights-ea6e1.firebaseio.com"
});

const db = admin.firestore();

// Parse command line arguments
const args = process.argv.slice(2);
const userIdArg = args.find(arg => arg.startsWith('--user-id='));
const specificUserId = userIdArg ? userIdArg.split('=')[1] : null;

console.log('');
console.log('╔════════════════════════════════════════════════════════════╗');
console.log('║     🔍 BET SETTLEMENT DIAGNOSTIC SCRIPT                   ║');
console.log('╚════════════════════════════════════════════════════════════╝');
console.log('');

if (specificUserId) {
  console.log(`Target: User ${specificUserId}`);
} else {
  console.log(`Target: All users with expired/refunded bets`);
}
console.log('');

// Statistics
const stats = {
  totalBets: 0,
  pendingBets: 0,
  expiredBets: 0,
  wonBets: 0,
  lostBets: 0,
  gamesFound: 0,
  gamesNotFound: 0,
  gamesFinal: 0,
  gamesSettled: 0,
  idMismatches: 0,
};

/**
 * Diagnose a single bet
 */
async function diagnoseBet(betDoc) {
  const bet = betDoc.data();
  const betId = betDoc.id;

  console.log(`\n📊 Analyzing Bet: ${betId}`);
  console.log(`   User: ${bet.userId}`);
  console.log(`   Game: ${bet.gameTitle || 'Unknown'}`);
  console.log(`   Sport: ${bet.sport || 'Unknown'}`);
  console.log(`   Status: ${bet.status}`);
  console.log(`   Wager: ${bet.wagerAmount} BR`);
  console.log(`   Placed: ${bet.placedAt?.toDate() || 'Unknown'}`);
  console.log(`   Game ID: ${bet.gameId}`);

  stats.totalBets++;

  // Count by status
  if (bet.status === 'pending') stats.pendingBets++;
  if (bet.status === 'expired') stats.expiredBets++;
  if (bet.status === 'won') stats.wonBets++;
  if (bet.status === 'lost') stats.lostBets++;

  // Check if game exists
  const gameRef = db.collection('games').doc(bet.gameId);
  const gameDoc = await gameRef.get();

  if (!gameDoc.exists) {
    console.log(`   ❌ Game NOT FOUND in Firestore (gameId: ${bet.gameId})`);
    stats.gamesNotFound++;

    // Try to find game by searching for team names
    console.log(`   🔍 Searching for game by team names...`);
    const gameQuery = await db.collection('games')
      .where('sport', '==', bet.sport)
      .get();

    let foundMatch = false;
    for (const doc of gameQuery.docs) {
      const game = doc.data();
      if (bet.gameTitle &&
          (bet.gameTitle.includes(game.homeTeam) || bet.gameTitle.includes(game.awayTeam))) {
        console.log(`   ⚠️  POSSIBLE MATCH FOUND with different ID:`);
        console.log(`      Game ID in DB: ${doc.id}`);
        console.log(`      Game ID in Bet: ${bet.gameId}`);
        console.log(`      Teams: ${game.awayTeam} @ ${game.homeTeam}`);
        console.log(`      Status: ${game.status}`);
        console.log(`      Bets Settled: ${game.betsSettled || false}`);
        stats.idMismatches++;
        foundMatch = true;
        break;
      }
    }

    if (!foundMatch) {
      console.log(`   ⚠️  No matching game found by team names either`);
      console.log(`   Possible reasons:`);
      console.log(`      - Game was from too long ago and removed from cache`);
      console.log(`      - Game ID format changed between bet placement and game fetch`);
      console.log(`      - Game was never fetched/saved to Firestore`);
    }

    return;
  }

  // Game exists - analyze it
  const game = gameDoc.data();
  stats.gamesFound++;

  console.log(`   ✅ Game FOUND in Firestore`);
  console.log(`   Game Details:`);
  console.log(`      Teams: ${game.awayTeam} @ ${game.homeTeam}`);
  console.log(`      Status: ${game.status}`);

  // Handle gameTime - might be Timestamp or ISO string
  let gameTimeStr = 'Unknown';
  if (game.gameTime) {
    if (typeof game.gameTime.toDate === 'function') {
      gameTimeStr = game.gameTime.toDate().toString();
    } else {
      gameTimeStr = new Date(game.gameTime).toString();
    }
  }
  console.log(`      Game Time: ${gameTimeStr}`);

  console.log(`      Home Score: ${game.homeScore ?? 'N/A'}`);
  console.log(`      Away Score: ${game.awayScore ?? 'N/A'}`);
  console.log(`      Bets Settled: ${game.betsSettled || false}`);

  // Handle betsSettledAt - might be Timestamp or ISO string
  let settledAtStr = 'N/A';
  if (game.betsSettledAt) {
    if (typeof game.betsSettledAt.toDate === 'function') {
      settledAtStr = game.betsSettledAt.toDate().toString();
    } else {
      settledAtStr = new Date(game.betsSettledAt).toString();
    }
  }
  console.log(`      Bets Settled At: ${settledAtStr}`);

  if (game.status === 'final') {
    stats.gamesFinal++;
  }

  if (game.betsSettled) {
    stats.gamesSettled++;
  }

  // Analyze why bet wasn't settled
  if (bet.status === 'pending' || bet.status === 'expired') {
    console.log(`\n   🔍 Why wasn't this bet settled?`);

    if (game.status !== 'final') {
      console.log(`      ⚠️  Game status is '${game.status}' (not 'final')`);
      console.log(`      → Settlement only triggers when status='final'`);
    } else {
      console.log(`      ✅ Game status is 'final'`);
    }

    if (!game.betsSettled) {
      console.log(`      ⚠️  betsSettled flag is false or missing`);
      console.log(`      → Cloud Function may not have run or failed`);
    } else {
      console.log(`      ✅ betsSettled flag is true`);
      console.log(`      → Settlement should have occurred at ${game.betsSettledAt?.toDate()}`);
      console.log(`      ⚠️  BUT bet is still ${bet.status}!`);
      console.log(`      → Possible Cloud Function error during settlement`);
    }

    // Check how old the bet is
    const betAge = bet.placedAt ? (Date.now() - bet.placedAt.toDate().getTime()) / (1000 * 60 * 60 * 24) : 0;
    console.log(`      Bet age: ${Math.floor(betAge)} days old`);
    if (betAge > 30) {
      console.log(`      ⚠️  Bet is older than 30 days - cleanup function marked it as expired`);
    }
  }

  // Check transaction history
  if (bet.status === 'expired') {
    console.log(`\n   💰 Checking refund transaction...`);
    const txQuery = await db.collection('transactions')
      .where('relatedId', '==', betId)
      .where('type', '==', 'refund')
      .get();

    if (!txQuery.empty) {
      const refundTx = txQuery.docs[0].data();
      console.log(`      ✅ Refund transaction found:`);
      console.log(`         Amount: ${refundTx.amount} BR`);
      console.log(`         Description: ${refundTx.description}`);
      console.log(`         Time: ${refundTx.timestamp?.toDate()}`);
    } else {
      console.log(`      ❌ No refund transaction found!`);
    }
  }

  if (bet.status === 'won' || bet.status === 'lost') {
    console.log(`\n   💰 Checking settlement transaction...`);
    const txQuery = await db.collection('transactions')
      .where('relatedId', '==', betId)
      .where('type', 'in', ['winnings', 'payout'])
      .get();

    if (!txQuery.empty) {
      const settlementTx = txQuery.docs[0].data();
      console.log(`      ✅ Settlement transaction found:`);
      console.log(`         Type: ${settlementTx.type}`);
      console.log(`         Amount: ${settlementTx.amount} BR`);
      console.log(`         Time: ${settlementTx.timestamp?.toDate()}`);
    } else if (bet.status === 'won') {
      console.log(`      ❌ No winnings transaction found!`);
    }
  }
}

/**
 * Main diagnostic function
 */
async function runDiagnostics() {
  try {
    console.log('═══════════════════════════════════════════════════════════');
    console.log('STEP 1: Finding bets to analyze');
    console.log('═══════════════════════════════════════════════════════════\n');

    let betsQuery = db.collection('bets');

    if (specificUserId) {
      betsQuery = betsQuery.where('userId', '==', specificUserId);
    }

    // Focus on expired and pending bets
    const expiredBets = await betsQuery
      .where('status', '==', 'expired')
      .orderBy('placedAt', 'desc')
      .limit(10)
      .get();

    const pendingBets = await betsQuery
      .where('status', '==', 'pending')
      .orderBy('placedAt', 'desc')
      .limit(10)
      .get();

    console.log(`Found ${expiredBets.size} expired bets`);
    console.log(`Found ${pendingBets.size} pending bets`);

    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('STEP 2: Analyzing expired bets');
    console.log('═══════════════════════════════════════════════════════════');

    for (const betDoc of expiredBets.docs) {
      await diagnoseBet(betDoc);
    }

    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('STEP 3: Analyzing pending bets');
    console.log('═══════════════════════════════════════════════════════════');

    for (const betDoc of pendingBets.docs) {
      await diagnoseBet(betDoc);
    }

    // Also check a few won/lost bets to see if settlement worked properly for any
    console.log('\n═══════════════════════════════════════════════════════════');
    console.log('STEP 4: Checking settled bets (for comparison)');
    console.log('═══════════════════════════════════════════════════════════');

    const settledBets = await betsQuery
      .where('status', 'in', ['won', 'lost'])
      .orderBy('placedAt', 'desc')
      .limit(3)
      .get();

    console.log(`\nFound ${settledBets.size} settled bets (won/lost)`);

    for (const betDoc of settledBets.docs) {
      await diagnoseBet(betDoc);
    }

    // Print summary
    console.log('\n\n');
    console.log('╔════════════════════════════════════════════════════════════╗');
    console.log('║     📊 DIAGNOSTIC SUMMARY                                  ║');
    console.log('╚════════════════════════════════════════════════════════════╝');
    console.log('');
    console.log(`Total bets analyzed: ${stats.totalBets}`);
    console.log(`  - Pending: ${stats.pendingBets}`);
    console.log(`  - Expired/Refunded: ${stats.expiredBets}`);
    console.log(`  - Won: ${stats.wonBets}`);
    console.log(`  - Lost: ${stats.lostBets}`);
    console.log('');
    console.log(`Game lookup results:`);
    console.log(`  - Games found: ${stats.gamesFound}`);
    console.log(`  - Games NOT found: ${stats.gamesNotFound}`);
    console.log(`  - Games with status='final': ${stats.gamesFinal}`);
    console.log(`  - Games with betsSettled=true: ${stats.gamesSettled}`);
    console.log(`  - ID mismatches detected: ${stats.idMismatches}`);
    console.log('');

    // Analysis & Recommendations
    console.log('═══════════════════════════════════════════════════════════');
    console.log('ANALYSIS & RECOMMENDATIONS');
    console.log('═══════════════════════════════════════════════════════════\n');

    if (stats.gamesNotFound > 0) {
      console.log('❌ ISSUE 1: Missing Games in Firestore');
      console.log(`   ${stats.gamesNotFound} bets reference games that don\'t exist in Firestore`);
      console.log('   Possible causes:');
      console.log('   - Old games removed from cache (games older than 7 days)');
      console.log('   - Game ID format changed between bet placement and game fetch');
      console.log('   - Games were never saved to Firestore initially');
      console.log('   Recommendation: Ensure games persist in Firestore until all bets are settled');
      console.log('');
    }

    if (stats.idMismatches > 0) {
      console.log('❌ ISSUE 2: Game ID Mismatches');
      console.log(`   ${stats.idMismatches} bets have gameIds that don't match actual game documents`);
      console.log('   This is CRITICAL - bet will NEVER settle if IDs don\'t match');
      console.log('   Recommendation: Ensure consistent game ID generation between:');
      console.log('   - Game creation in optimized_games_service.dart');
      console.log('   - Bet placement in game_details_screen.dart');
      console.log('');
    }

    if (stats.gamesFinal > 0 && !stats.gamesSettled) {
      console.log('❌ ISSUE 3: Games Marked Final But Bets Not Settled');
      console.log(`   ${stats.gamesFinal - stats.gamesSettled} games have status='final' but betsSettled=false`);
      console.log('   This means the Cloud Function did NOT run or failed');
      console.log('   Recommendation: Check Cloud Function logs for errors');
      console.log('');
    }

    if (stats.expiredBets > 0) {
      console.log('⚠️  ISSUE 4: Cleanup Function Auto-Expiring Old Bets');
      console.log(`   ${stats.expiredBets} bets were marked as expired by cleanup function`);
      console.log('   This is working as designed, but may indicate upstream settlement issues');
      console.log('   Recommendation: Fix root causes (Issues 1-3) to prevent future expirations');
      console.log('');
    }

    if (stats.wonBets > 0 || stats.lostBets > 0) {
      console.log('✅ Settlement IS working for some bets');
      console.log(`   ${stats.wonBets} won, ${stats.lostBets} lost`);
      console.log('   This confirms the settlement flow can work correctly');
      console.log('');
    }

    console.log('═══════════════════════════════════════════════════════════\n');

  } catch (error) {
    console.error('\n❌ FATAL ERROR during diagnostics:', error);
    console.error('Stack trace:', error.stack);
  } finally {
    // Close Firebase connection
    await admin.app().delete();
  }
}

// Run the diagnostics
runDiagnostics().catch(error => {
  console.error('Unhandled error:', error);
  process.exit(1);
});
