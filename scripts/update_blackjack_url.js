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

async function updateBlackjackUrl() {
  try {
    console.log('🎰 Updating Lucky Vegas Blackjack iframe URL...');

    // Correct Lucky Vegas Blackjack GameDistribution URL
    const blackjackUrl = 'https://html5.gamedistribution.com/bb2a8674b78f47c7a4857aaad3fe6b9d/';

    await db.collection('mini-games').doc('blackjack').update({
      embedUrl: blackjackUrl,
      lastUpdated: admin.firestore.Timestamp.now()
    });

    console.log('✅ Updated Lucky Vegas Blackjack embedUrl');
    console.log(`   URL: ${blackjackUrl}`);

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

updateBlackjackUrl();
