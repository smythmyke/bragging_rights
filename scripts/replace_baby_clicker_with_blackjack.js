const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

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
const bucket = admin.storage().bucket();

async function replaceGame() {
  try {
    console.log('🗑️  Removing Italian Brainrot Baby Clicker...');

    // Delete the baby_clicker game from Firestore
    await db.collection('mini-games').doc('baby_clicker').delete();
    console.log('✅ Removed baby_clicker from Firestore');

    console.log('\n📤 Uploading Lucky Vegas Blackjack images...');

    // Upload images to Firebase Storage
    const gameAssetsPath = path.join(__dirname, '..', 'game_assets', 'blackjack');
    const imageFiles = ['thumbnail.jpg', 'banner.jpg', 'gameplay.jpg'];
    const imageUrls = {};

    for (const imageFile of imageFiles) {
      const localPath = path.join(gameAssetsPath, imageFile);
      const storagePath = `game_images/blackjack/${imageFile}`;

      if (!fs.existsSync(localPath)) {
        console.error(`❌ Image not found: ${localPath}`);
        continue;
      }

      await bucket.upload(localPath, {
        destination: storagePath,
        metadata: {
          contentType: 'image/jpeg',
          cacheControl: 'public, max-age=31536000',
        }
      });

      const file = bucket.file(storagePath);
      await file.makePublic();

      const publicUrl = `https://storage.googleapis.com/${bucket.name}/${storagePath}`;
      const imageName = imageFile.replace('.jpg', '');
      imageUrls[imageName] = publicUrl;
      console.log(`  ✓ Uploaded: ${publicUrl}`);
    }

    console.log('\n📝 Creating Firestore document for Lucky Vegas Blackjack...');

    function getWeekNumber(date) {
      const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
      const pastDaysOfYear = (date - firstDayOfYear) / 86400000;
      return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
    }

    const blackjackData = {
      id: 'blackjack',
      active: true,
      name: 'blackjack',
      title: 'Lucky Vegas Blackjack',
      description: 'Experience the thrill of Las Vegas blackjack! Play classic 21 and test your luck against the dealer.',
      category: 'casino',
      platform: 'gamedistribution',
      embedUrl: 'PLACEHOLDER_NEEDS_UPDATE', // User needs to provide this
      thumbnailUrl: imageUrls.thumbnail,
      bannerUrl: imageUrls.banner,
      gameplayImageUrl: imageUrls.gameplay,
      brCost: 5,
      difficulty: 'medium',
      estimatedPlayTime: 15,
      minPlayers: 1,
      maxPlayers: 1,
      tags: ['casino', 'cards', 'blackjack', 'vegas', '21'],
      controls: 'Mouse/Touch to play',
      prizes: {
        first: 100,
        second: 50,
        third: 25,
        top10: 10
      },
      leaderboard: {
        currentWeekStart: admin.firestore.Timestamp.now(),
        currentWeekNumber: getWeekNumber(new Date()),
        resetDay: 'monday',
        topPlayersCount: 10
      },
      stats: {
        totalPlays: 0,
        totalPlayers: 0,
        averageScore: 0,
        highestScore: 0
      },
      featured: true,
      featuredOrder: 3,
      icon: 'cards',
      sportType: 'casino',
      weekNumber: getWeekNumber(new Date()),
      maxScore: 1000000,
      releaseDate: admin.firestore.Timestamp.now(),
      lastUpdated: admin.firestore.Timestamp.now(),
      createdAt: admin.firestore.Timestamp.now()
    };

    await db.collection('mini-games').doc('blackjack').set(blackjackData);
    console.log('✅ Added Lucky Vegas Blackjack to Firestore');

    console.log('\n✨ Game replacement complete!');
    console.log('\n⚠️  IMPORTANT: Update the embedUrl in Firestore with the correct GameDistribution iframe URL');

    process.exit(0);
  } catch (error) {
    console.error('❌ Error:', error);
    process.exit(1);
  }
}

replaceGame();
