/**
 * Migration Script: Update Mini-Games Schema
 *
 * This script adds new fields to existing mini-game documents in Firestore
 * for the games page improvements feature.
 *
 * New Fields:
 * - featured: Boolean - Is this the featured game?
 * - featuredUntil: Timestamp - When to unfeature
 * - longDescription: String - 2-3 sentences for featured card
 * - playerCount: Number - Total plays this week
 * - averageDuration: Number - Minutes per game session
 * - topPrize: Number - BR amount for 1st place
 * - category: String - Game category
 *
 * Usage:
 *   cd scripts
 *   node update_mini_games_schema.js
 */

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

/**
 * Infer category from game title and sportType
 */
function inferCategory(title, sportType, description) {
  const titleLower = (title || '').toLowerCase();
  const sportTypeLower = (sportType || '').toLowerCase();
  const descLower = (description || '').toLowerCase();

  const combined = `${titleLower} ${sportTypeLower} ${descLower}`;

  // Check for trivia
  if (combined.includes('trivia') || combined.includes('quiz')) {
    return 'Trivia';
  }

  // Check for sports
  if (combined.includes('basketball') || combined.includes('football') ||
      combined.includes('soccer') || combined.includes('baseball') ||
      combined.includes('hockey') || combined.includes('nba') ||
      combined.includes('nfl') || combined.includes('mlb') || combined.includes('nhl')) {
    return 'Sports';
  }

  // Check for puzzle
  if (combined.includes('puzzle') || combined.includes('memory') ||
      combined.includes('match') || combined.includes('sort')) {
    return 'Puzzle';
  }

  // Check for arcade
  if (combined.includes('arcade') || combined.includes('action') ||
      combined.includes('shooter') || combined.includes('runner')) {
    return 'Arcade';
  }

  // Check for card/casino games
  if (combined.includes('card') || combined.includes('poker') ||
      combined.includes('blackjack') || combined.includes('casino')) {
    return 'Casino';
  }

  // Check for strategy
  if (combined.includes('strategy') || combined.includes('chess')) {
    return 'Strategy';
  }

  return 'General';
}

/**
 * Generate a long description from existing description or title
 */
function generateLongDescription(title, description, category) {
  if (description && description.length > 50) {
    // If description is already long enough, use it
    return description;
  }

  // Generate based on category
  switch (category) {
    case 'Trivia':
      return `Test your knowledge with ${title}! Answer questions correctly to score points and compete on the leaderboard for weekly prizes.`;

    case 'Sports':
      return `Play ${title} and compete against other players! Show off your skills and climb the leaderboard to win BR prizes.`;

    case 'Puzzle':
      return `Challenge your mind with ${title}! Solve puzzles quickly and accurately to earn a high score and compete for prizes.`;

    case 'Arcade':
      return `Enjoy classic arcade action with ${title}! Compete for the highest score and win weekly BR prizes.`;

    case 'Casino':
      return `Try your luck with ${title}! Play to win and compete on the leaderboard for weekly prizes.`;

    default:
      return `Play ${title} and compete for the highest score! Win BR prizes and climb the weekly leaderboard.`;
  }
}

/**
 * Estimate average duration based on game type
 */
function estimateDuration(category, description) {
  const descLower = (description || '').toLowerCase();

  // Check for quick/short games
  if (descLower.includes('quick') || descLower.includes('fast')) {
    return 3;
  }

  switch (category) {
    case 'Trivia':
      return 3; // Trivia games are usually quick
    case 'Puzzle':
      return 5; // Puzzles take a bit longer
    case 'Sports':
      return 4; // Sports games vary
    case 'Arcade':
      return 6; // Arcade games can be longer
    case 'Casino':
      return 7; // Card games take time
    default:
      return 5; // Default 5 minutes
  }
}

/**
 * Main migration function
 */
async function migrateGamesSchema() {
  console.log('🚀 Starting mini-games schema migration...\n');

  try {
    // Get all games from mini-games collection
    const gamesRef = db.collection('mini-games');
    const snapshot = await gamesRef.get();

    if (snapshot.empty) {
      console.log('⚠️  No games found in mini-games collection');
      return;
    }

    console.log(`📊 Found ${snapshot.size} game(s) to update\n`);

    const batch = db.batch();
    let updateCount = 0;

    // Process each game
    snapshot.forEach((doc, index) => {
      const data = doc.data();
      const gameTitle = data.title || data.name || doc.id;

      console.log(`\n[${index + 1}/${snapshot.size}] Processing: ${gameTitle}`);
      console.log(`   Game ID: ${doc.id}`);

      // Infer category
      const category = data.category || inferCategory(
        data.title,
        data.sportType,
        data.description
      );
      console.log(`   Category: ${category}`);

      // Generate long description
      const longDescription = data.longDescription || generateLongDescription(
        gameTitle,
        data.description,
        category
      );

      // Estimate duration
      const averageDuration = data.averageDuration || estimateDuration(
        category,
        data.description
      );
      console.log(`   Duration: ~${averageDuration} min`);

      // Determine top prize (could be customized per game)
      const topPrize = data.topPrize || 500;
      console.log(`   Top Prize: ${topPrize} BR`);

      // Build update object
      const updates = {
        // Featured status (first game will be featured by default)
        featured: data.featured !== undefined ? data.featured : (index === 0),
        featuredUntil: data.featuredUntil || null,

        // Descriptions
        longDescription: longDescription,

        // Statistics
        playerCount: data.playerCount || 0,
        averageDuration: averageDuration,
        topPrize: topPrize,

        // Category
        category: category,

        // Update BR cost to 15 if it's still 5
        brCost: data.brCost === 5 ? 15 : (data.brCost || 15),
      };

      // Add to batch
      batch.update(doc.ref, updates);
      updateCount++;

      console.log(`   ✅ Prepared update`);
    });

    // Commit all updates
    console.log('\n\n💾 Committing updates to Firestore...');
    await batch.commit();

    console.log(`\n✅ Successfully updated ${updateCount} game(s)!`);
    console.log('\n📋 Summary of Changes:');
    console.log('   • Added featured/featuredUntil fields');
    console.log('   • Added longDescription for featured cards');
    console.log('   • Added playerCount (initialized to 0)');
    console.log('   • Added averageDuration (estimated per game)');
    console.log('   • Added topPrize (500 BR default)');
    console.log('   • Added category field');
    console.log('   • Updated brCost to 15 BR if needed');

    // Set featured until date for the first game
    if (snapshot.size > 0) {
      const firstGame = snapshot.docs[0];
      const nextWeek = new Date();
      nextWeek.setDate(nextWeek.getDate() + 7);

      await firstGame.ref.update({
        featuredUntil: admin.firestore.Timestamp.fromDate(nextWeek)
      });

      console.log(`\n⭐ Set "${firstGame.data().title}" as featured until ${nextWeek.toLocaleDateString()}`);
    }

    console.log('\n✨ Migration complete!\n');

  } catch (error) {
    console.error('\n❌ Error during migration:', error);
    throw error;
  }
}

// Run the migration
migrateGamesSchema()
  .then(() => {
    console.log('👋 Exiting...');
    process.exit(0);
  })
  .catch((error) => {
    console.error('💥 Migration failed:', error);
    process.exit(1);
  });
