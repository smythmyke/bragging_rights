const admin = require('firebase-admin');

// Initialize Firebase Admin (reuse existing app or create new)
let app;
try {
  app = admin.app();
} catch (e) {
  const serviceAccount = require('../service-account-key.json');
  app = admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
    storageBucket: 'bragging-rights-ea6e1.firebasestorage.app'
  });
}

const db = admin.firestore();

async function updateGameCosts() {
  try {
    console.log('💰 Updating all game costs to 15 BR...\n');

    // Get all mini-games
    const gamesSnapshot = await db.collection('mini-games').get();

    if (gamesSnapshot.empty) {
      console.log('❌ No games found in Firestore');
      process.exit(1);
    }

    console.log(`📋 Found ${gamesSnapshot.size} games to update\n`);

    const batch = db.batch();
    let updateCount = 0;

    for (const doc of gamesSnapshot.docs) {
      const gameData = doc.data();
      const currentCost = gameData.brCost || 'undefined';

      console.log(`🎮 ${doc.id}: "${gameData.title}"`);
      console.log(`   Current cost: ${currentCost} BR`);
      console.log(`   New cost: 15 BR`);

      batch.update(doc.ref, {
        brCost: 15,
        lastUpdated: admin.firestore.Timestamp.now()
      });

      updateCount++;
      console.log(`   ✓ Queued for update\n`);
    }

    // Commit the batch
    await batch.commit();

    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    console.log(`✅ Successfully updated ${updateCount} games to 15 BR`);
    console.log('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

updateGameCosts();
