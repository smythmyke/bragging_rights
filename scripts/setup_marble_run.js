const admin = require('firebase-admin');
const fs = require('fs');
const path = require('path');

// Initialize Firebase Admin
const serviceAccount = require('../service-account-key.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
  storageBucket: 'bragging-rights-ea6e1.firebasestorage.app'
});

const db = admin.firestore();
const bucket = admin.storage().bucket();

async function uploadImages() {
  console.log('Uploading Marble Run images to Firebase Storage...');

  const imagesToUpload = [
    { local: 'thumbnail.jpg', remote: 'game_images/marble_run/thumbnail.jpg' },
    { local: 'banner.jpg', remote: 'game_images/marble_run/banner.jpg' },
    { local: 'gameplay.jpg', remote: 'game_images/marble_run/gameplay.jpg' }
  ];

  const imageUrls = {};

  for (const img of imagesToUpload) {
    const localPath = path.join(__dirname, '..', 'game_assets', 'marble_run', img.local);

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

async function addMarbleRunToFirestore(imageUrls) {
  console.log('\nAdding Marble Run to Firestore...');

  const marbleRunData = {
    id: 'marble_run',
    active: true,
    title: 'Marble Run - Ultimate Race!',
    description: 'Guide your marble through challenging tracks, avoid obstacles, and race to the finish line in this exciting 3D marble racing game!',
    category: 'racing',
    platform: 'gamedistribution',
    embedUrl: 'https://html5.gamedistribution.com/ae42ea5c4e0b4ff4b9eddf47fbd2cc5e/',
    thumbnailUrl: imageUrls.thumbnail,
    bannerUrl: imageUrls.banner,
    gameplayImageUrl: imageUrls.gameplay,
    brCost: 5,
    difficulty: 'medium',
    estimatedPlayTime: 5,
    minPlayers: 1,
    maxPlayers: 1,
    tags: ['racing', 'arcade', '3d', 'casual'],
    controls: 'Touch or mouse to control marble direction',
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
    featuredOrder: 1,
    releaseDate: admin.firestore.Timestamp.now(),
    lastUpdated: admin.firestore.Timestamp.now(),
    createdAt: admin.firestore.Timestamp.now()
  };

  await db.collection('mini-games').doc('marble_run').set(marbleRunData);
  console.log('✓ Marble Run added to Firestore');
}

async function verifySportsTrivia() {
  console.log('\nVerifying Sports Trivia in Firestore...');

  const sportsTriviaDoc = await db.collection('mini-games').doc('sports_trivia').get();

  if (sportsTriviaDoc.exists) {
    const data = sportsTriviaDoc.data();
    console.log(`✓ Sports Trivia found - Active: ${data.active}, Title: ${data.title}`);

    // Update Sports Trivia if it's missing the title field
    if (!data.title || !data.name) {
      console.log('  Updating Sports Trivia with title and name fields...');
      await db.collection('mini-games').doc('sports_trivia').update({
        title: data.title || 'Sports Trivia',
        name: data.name || 'sports_trivia',
      });
      console.log('  ✓ Sports Trivia updated');
    }

    return true;
  } else {
    console.log('❌ Sports Trivia not found in Firestore');
    return false;
  }
}

async function listAllGames() {
  console.log('\nListing all mini-games:');

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
    console.log('🎮 Setting up Marble Run game...\n');

    // Step 1: Upload images
    const imageUrls = await uploadImages();

    // Step 2: Add Marble Run to Firestore
    await addMarbleRunToFirestore(imageUrls);

    // Step 3: Verify Sports Trivia
    await verifySportsTrivia();

    // Step 4: List all games
    await listAllGames();

    console.log('\n✅ Setup complete! Hot restart your Flutter app to see the changes.');

  } catch (error) {
    console.error('Error during setup:', error);
  } finally {
    process.exit(0);
  }
}

main();
