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

async function uploadGameImages(gameFolder, gameId) {
  console.log(`📤 Uploading ${gameId} images to Firebase Storage...`);

  const imagesToUpload = [
    { local: 'thumbnail.jpg', remote: `game_images/${gameId}/thumbnail.jpg` },
    { local: 'banner.jpg', remote: `game_images/${gameId}/banner.jpg` },
    { local: 'gameplay.jpg', remote: `game_images/${gameId}/gameplay.jpg` }
  ];

  const imageUrls = {};

  for (const img of imagesToUpload) {
    const localPath = path.join(__dirname, '..', 'game_assets', gameFolder, img.local);

    if (!fs.existsSync(localPath)) {
      console.error(`❌ Image not found: ${localPath}`);
      continue;
    }

    console.log(`  Uploading ${img.local}...`);

    await bucket.upload(localPath, {
      destination: img.remote,
      metadata: {
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000',
      }
    });

    const file = bucket.file(img.remote);
    await file.makePublic();

    const publicUrl = `https://storage.googleapis.com/${bucket.name}/${img.remote}`;
    imageUrls[img.local.replace('.jpg', '')] = publicUrl;
    console.log(`  ✓ Uploaded: ${publicUrl}`);
  }

  return imageUrls;
}

async function addBabyClickerToFirestore(imageUrls) {
  console.log('\n👶 Adding Italian Brainrot Baby Clicker to Firestore...');

  const babyClickerData = {
    id: 'baby_clicker',
    active: true,
    name: 'baby_clicker',
    title: 'Italian Brainrot Baby Clicker',
    description: 'Click your way to victory in this addictive clicker game! Tap the baby to earn points and unlock upgrades.',
    category: 'clicker',
    platform: 'gamedistribution',
    embedUrl: 'https://html5.gamedistribution.com/fe3c5c9d90f24f10a9e01cca22f5243f/',
    thumbnailUrl: imageUrls.thumbnail,
    bannerUrl: imageUrls.banner,
    gameplayImageUrl: imageUrls.gameplay,
    brCost: 5,
    difficulty: 'easy',
    estimatedPlayTime: 15,
    minPlayers: 1,
    maxPlayers: 1,
    tags: ['clicker', 'casual', 'idle', 'addictive'],
    controls: 'Tap/click to play',
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
    icon: 'gameController',
    sportType: 'casual',
    weekNumber: getWeekNumber(new Date()),
    maxScore: 1000000,
    releaseDate: admin.firestore.Timestamp.now(),
    lastUpdated: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.Timestamp.now()
  };

  await db.collection('mini-games').doc('baby_clicker').set(babyClickerData);
  console.log('✓ Italian Brainrot Baby Clicker added to Firestore');
}

async function addPokerToFirestore(imageUrls) {
  console.log('\n🃏 Adding Governor of Poker 3 to Firestore...');

  const pokerData = {
    id: 'poker',
    active: true,
    name: 'poker',
    title: 'Governor of Poker 3',
    description: 'Play Texas Hold\'em poker and become the Governor! Compete against players, win tournaments, and dominate the Wild West.',
    category: 'cards',
    platform: 'gamedistribution',
    embedUrl: 'https://html5.gamedistribution.com/fe3c5c9d90f24f10a9e01cca22f5243f/',
    thumbnailUrl: imageUrls.thumbnail,
    bannerUrl: imageUrls.banner,
    gameplayImageUrl: imageUrls.gameplay,
    brCost: 5,
    difficulty: 'medium',
    estimatedPlayTime: 20,
    minPlayers: 1,
    maxPlayers: 1,
    tags: ['poker', 'cards', 'strategy', 'casino', 'texas-holdem'],
    controls: 'Mouse/Touch to play cards',
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
    featuredOrder: 4,
    icon: 'cards',
    sportType: 'cards',
    weekNumber: getWeekNumber(new Date()),
    maxScore: 1000000,
    releaseDate: admin.firestore.Timestamp.now(),
    lastUpdated: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.Timestamp.now()
  };

  await db.collection('mini-games').doc('poker').set(pokerData);
  console.log('✓ Governor of Poker 3 added to Firestore');
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
    console.log('🎮 Adding 2 new games...\n');

    // Game 1: Italian Brainrot Baby Clicker
    const babyClickerImages = await uploadGameImages('baby_clicker', 'baby_clicker');
    await addBabyClickerToFirestore(babyClickerImages);

    // Game 2: Governor of Poker 3
    const pokerImages = await uploadGameImages('poker', 'poker');
    await addPokerToFirestore(pokerImages);

    // List all games
    await listAllGames();

    console.log('\n✅ Both games added successfully! Hot restart your Flutter app to see the changes.');

  } catch (error) {
    console.error('❌ Error during setup:', error);
  } finally {
    process.exit(0);
  }
}

main();
