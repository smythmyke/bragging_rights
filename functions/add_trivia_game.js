/**
 * Script to add Sports Trivia game to Firestore
 * Run this once to initialize the game in your database
 */

const admin = require('firebase-admin');

// Initialize admin if not already initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();

async function addSportsTriviaGame() {
  console.log('📝 Adding Sports Trivia game to Firestore...');

  try {
    // Get current week info
    const now = new Date();
    const weekNumber = getWeekNumber(now);
    const weekStart = getWeekStart(now);
    const weekEnd = new Date(weekStart.getTime() + 7 * 24 * 60 * 60 * 1000);

    // Add game to mini-games collection
    const gameData = {
      id: 'sports_trivia',
      name: 'Sports Trivia Challenge',
      embedUrl: 'https://bragging-rights-ea6e1.web.app/sports_trivia.html',
      platform: 'html5_free',
      weekNumber: weekNumber,
      active: true,
      icon: 'brain',
      sportType: 'all',
      description: '70 questions covering NBA, NFL, MLB, NHL, MLS, Boxing, and MMA. 10 seconds per question!',
      maxScore: 2000,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('mini-games').doc('sports_trivia').set(gameData);
    console.log('✅ Sports Trivia game added to mini-games collection');

    // Create initial leaderboard for current week
    const leaderboardId = `sports_trivia_week_${weekNumber}`;
    const leaderboardData = {
      gameId: 'sports_trivia',
      weekStart: admin.firestore.Timestamp.fromDate(weekStart),
      weekEnd: admin.firestore.Timestamp.fromDate(weekEnd),
      scores: [],
      active: true,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    };

    await db.collection('leaderboards').doc(leaderboardId).set(leaderboardData);
    console.log(`✅ Leaderboard created for week ${weekNumber}`);

    console.log('\n🎉 Setup complete!');
    console.log(`\nGame URL: ${gameData.embedUrl}`);
    console.log(`Leaderboard ID: ${leaderboardId}`);
    console.log(`Week: ${weekNumber} (${weekStart.toDateString()} - ${weekEnd.toDateString()})`);

  } catch (error) {
    console.error('❌ Error adding game:', error);
    throw error;
  }
}

// Helper functions
function getWeekNumber(date) {
  const firstDayOfYear = new Date(date.getFullYear(), 0, 1);
  const daysSinceFirstDay = Math.floor((date - firstDayOfYear) / (24 * 60 * 60 * 1000));
  return Math.floor(daysSinceFirstDay / 7) + 1;
}

function getWeekStart(date) {
  const weekday = date.getDay();
  const daysToSubtract = weekday === 0 ? 6 : weekday - 1; // Monday is start
  const weekStart = new Date(date.getTime() - daysToSubtract * 24 * 60 * 60 * 1000);
  weekStart.setHours(0, 0, 0, 0);
  return weekStart;
}

// Run the script
addSportsTriviaGame()
  .then(() => {
    console.log('\n✅ Script completed successfully');
    process.exit(0);
  })
  .catch((error) => {
    console.error('\n❌ Script failed:', error);
    process.exit(1);
  });
