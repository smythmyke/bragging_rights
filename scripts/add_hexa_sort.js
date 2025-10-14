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

async function uploadImages() {
  console.log('📤 Uploading Hexa Sort images to Firebase Storage...');

  const imagesToUpload = [
    { local: 'thumbnail.jpg', remote: 'game_images/hexa_sort/thumbnail.jpg' },
    { local: 'banner.jpg', remote: 'game_images/hexa_sort/banner.jpg' },
    { local: 'gameplay.jpg', remote: 'game_images/hexa_sort/gameplay.jpg' }
  ];

  const imageUrls = {};

  for (const img of imagesToUpload) {
    const localPath = path.join(__dirname, '..', 'game_assets', 'hexa_sort', img.local);

    if (!fs.existsSync(localPath)) {
      console.error(`❌ Image not found: ${localPath}`);
      continue;
    }

    console.log(`  Uploading ${img.local}...`);

    // Upload file
    await bucket.upload(localPath, {
      destination: img.remote,
      metadata: {
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      }
    });

    // Make it publicly readable
    const file = bucket.file(img.remote);
    await file.makePublic();

    // Get public URL
    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${img.remote}`;
    imageUrls[img.local.replace('.jpg', '')] = publicUrl;
    console.log(`  ✓ Uploaded: ${publicUrl}`);
  }

  return imageUrls;
}

async function addHexaSortToFirestore(imageUrls) {
  console.log('\n🎃 Adding Hexa Sort Trick or Treat to Firestore...');

  const hexaSortData = {
    id: 'hexa_sort',
    active: true,
    name: 'hexa_sort',
    title: 'Hexa Sort Trick or Treat',
    description: 'Sort colorful hexagons in this relaxing puzzle game with a Halloween twist! Match and stack to clear the board.',
    category: 'puzzle',
    platform: 'gamedistribution',
    embedUrl: 'https://html5.gamedistribution.com/66fddb2022464fce86e045f78db3f46d/',
    thumbnailUrl: imageUrls.thumbnail,
    bannerUrl: imageUrls.banner,
    gameplayImageUrl: imageUrls.gameplay,
    brCost: 5,
    difficulty: 'easy',
    estimatedPlayTime: 10,
    minPlayers: 1,
    maxPlayers: 1,
    tags: ['puzzle', 'casual', 'halloween', 'sorting', 'relaxing'],
    controls: 'Drag and drop hexagons to sort them',
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
    icon: 'target',
    sportType: 'puzzle',
    weekNumber: getWeekNumber(new Date()),
    maxScore: 10000,
    releaseDate: admin.firestore.Timestamp.now(),
    lastUpdated: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.Timestamp.now()
  };

  await db.collection('mini-games').doc('hexa_sort').set(hexaSortData);
  console.log('✓ Hexa Sort added to Firestore');
}

async function listAllGames() {
  console.log('\n📋 Listing all mini-games:');

  const gamesSnapshot = await db.collection('mini-games').get();

  if (gamesSnapshot.empty) {
    console.log('  No games found in Firestore');
    return;
  }

  gamesSnapshot.forEach(doc => {
    const data = doc.data();
    console.log(`  - ${doc.id}: "${data.title}" (Active: ${data.active})`);
  });

  console.log(`\nTotal games: ${gamesSnapshot.size}`);
}

function getWeekNumber(date) {
  const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
  const pastDaysOfYear = (date - firstDayOfYear) / 86400000;
  return Math.ceil((pastDaysOfYear + firstDayOfYear.getDay() + 1) / 7);
}

async function main() {
  try {
    console.log('🎃 Adding Hexa Sort Trick or Treat game...\n');

    // Step 1: Upload images
    const imageUrls = await uploadImages();

    // Step 2: Add Hexa Sort to Firestore
    await addHexaSortToFirestore(imageUrls);

    // Step 3: List all games
    await listAllGames();

    console.log('\n✅ Hexa Sort setup complete! Hot restart your Flutter app to see the changes.');

  } catch (error) {
    console.error('❌ Error during setup:', error);
  } finally {
    process.exit(0);
  }
}

main();
