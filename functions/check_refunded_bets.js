const admin = require('firebase-admin');
admin.initializeApp();
const db = admin.firestore();

async function checkRefundedBets() {
  console.log('🔍 Checking refunded bets...\n');

  const expiredBets = await db.collection('bets')
    .where('status', '==', 'expired')
    .limit(50)
    .get();

  console.log(`Found ${expiredBets.size} expired/refunded bets:\n`);

  for (const betDoc of expiredBets.docs) {
    const bet = betDoc.data();
    console.log(`Bet ID: ${betDoc.id}`);
    console.log(`  Game ID: ${bet.gameId}`);
    console.log(`  Game Title: ${bet.gameTitle}`);
    console.log(`  Sport: ${bet.sport}`);
    console.log(`  Wager: ${bet.wagerAmount} BR`);
    console.log(`  Placed: ${bet.placedAt ? bet.placedAt.toDate() : 'N/A'}`);
    console.log(`  Settled: ${bet.settledAt ? bet.settledAt.toDate() : 'N/A'}`);
    console.log(`  Settlement Note: ${bet.settlementNote || 'N/A'}`);
    console.log('');
  }
}

checkRefundedBets().then(() => process.exit(0));
