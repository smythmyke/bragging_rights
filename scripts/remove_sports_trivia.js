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

async function removeSportsTrivia() {
  try {
    console.log('🗑️  Removing Sports Trivia from Firestore...\n');

    // Delete the game document
    await db.collection('mini-games').doc('sports_trivia').delete();
    console.log('✅ Sports Trivia deleted from Firestore');

    // List remaining games
    console.log('\n📋 Remaining mini-games:');
    const gamesSnapshot = await db.collection('mini-games').get();

    if (gamesSnapshot.empty) {
      console.log('  No games found');
    } else {
      gamesSnapshot.forEach(doc => {
        const data = doc.data();
        console.log(`  - ${doc.id}: "${data.title}" (Active: ${data.active})`);
      });
      console.log(`\nTotal games: ${gamesSnapshot.size}`);
    }

  } catch (error) {
    console.error('❌ Error removing Sports Trivia:', error);
  } finally {
    process.exit(0);
  }
}

removeSportsTrivia();
