/**
 * Sports Data Integration Cloud Functions for Bragging Rights App
 * Handles live game data, scores, and odds from multiple sources
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Ensure Firebase is initialized
if (!admin.apps.length) {
  admin.initializeApp();
}

const db = admin.firestore();
const FieldValue = admin.firestore.FieldValue;

// API Configuration (store these in Firebase Functions config in production)
const API_CONFIG = {
  // Free tier APIs
  SPORTS_DB: {
    base_url: 'https://www.thesportsdb.com/api/v1/json/3',
    key: '3', // Free tier key
  },
  // ESPN API (unofficial endpoints)
  ESPN: {
    base_url: 'https://site.api.espn.com/apis/site/v2/sports',
  },
  // API-FOOTBALL (has free tier)
  API_FOOTBALL: {
    base_url: 'https://v3.football.api-sports.io',
    key: process.env.API_FOOTBALL_KEY || '', // Add your key
  },
  // The Odds API (has free tier - 500 requests/month)
  ODDS_API: {
    base_url: 'https://api.the-odds-api.com/v4',
    key: functions.config().odds_api?.key || process.env.ODDS_API_KEY || 'a07a990fba881f317ae71ea131cc8223',
  }
};

// Sport mappings
const SPORT_MAPPINGS = {
  NFL: { espn: 'football/nfl', db_id: '4391', odds: 'americanfootball_nfl' },
  NBA: { espn: 'basketball/nba', db_id: '4387', odds: 'basketball_nba' },
  MLB: { espn: 'baseball/mlb', db_id: '4424', odds: 'baseball_mlb' },
  NHL: { espn: 'hockey/nhl', db_id: '4380', odds: 'icehockey_nhl' },
};

// ============================================
// SCHEDULED DATA UPDATES
// ============================================

/**
 * Update live games every 5 minutes during game hours
 */
exports.updateLiveGames = functions.pubsub
  .schedule('*/5 * * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    const hour = new Date().getHours();
    
    // Only run during typical game hours (10 AM - 2 AM ET)
    if (hour >= 2 && hour < 10) {
      console.log('Outside game hours, skipping update');
      return null;
    }
    
    console.log('Updating live games...');
    
    try {
      await updateAllSportsGames();
      console.log('Live games updated successfully');
    } catch (error) {
      console.error('Error updating live games:', error);
    }
    
    return null;
  });

/**
 * Update game schedules daily at 6 AM
 */
exports.updateGameSchedules = functions.pubsub
  .schedule('0 6 * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Updating game schedules...');
    
    try {
      await updateAllSportsSchedules();
      console.log('Game schedules updated successfully');
    } catch (error) {
      console.error('Error updating game schedules:', error);
    }
    
    return null;
  });

/**
 * Update odds every 30 minutes
 */
exports.updateOdds = functions.pubsub
  .schedule('*/30 * * * *')
  .timeZone('America/New_York')
  .onRun(async (context) => {
    console.log('Updating odds...');
    
    try {
      await updateAllOdds();
      console.log('Odds updated successfully');
    } catch (error) {
      console.error('Error updating odds:', error);
    }
    
    return null;
  });

// ============================================
// CORE DATA FUNCTIONS
// ============================================

/**
 * Update games for all sports
 */
async function updateAllSportsGames() {
  const sports = ['NFL', 'NBA', 'MLB', 'NHL'];
  const promises = sports.map(sport => updateSportGames(sport));
  await Promise.allSettled(promises);
}

/**
 * Update games for a specific sport
 */
async function updateSportGames(sport) {
  try {
    // Try ESPN API first (most reliable for scores)
    const games = await fetchESPNGames(sport);
    
    if (games && games.length > 0) {
      await saveGamesToFirestore(sport, games);
      console.log(`Updated ${games.length} ${sport} games`);
    }
  } catch (error) {
    console.error(`Error updating ${sport} games:`, error);
    
    // Fallback to TheSportsDB
    try {
      const games = await fetchSportsDBGames(sport);
      if (games && games.length > 0) {
        await saveGamesToFirestore(sport, games);
        console.log(`Updated ${games.length} ${sport} games (fallback)`);
      }
    } catch (fallbackError) {
      console.error(`Fallback also failed for ${sport}:`, fallbackError);
    }
  }
}

/**
 * Fetch games from ESPN API
 */
async function fetchESPNGames(sport) {
  const mapping = SPORT_MAPPINGS[sport];
  if (!mapping || !mapping.espn) return [];
  
  try {
    const url = `${API_CONFIG.ESPN.base_url}/${mapping.espn}/scoreboard`;
    const response = await axios.get(url);
    
    if (!response.data || !response.data.events) return [];
    
    return response.data.events.map(event => ({
      id: event.id,
      sport: sport,
      status: mapESPNStatus(event.status),
      startTime: new Date(event.date),
      homeTeam: {
        id: event.competitions[0].competitors[0].id,
        name: event.competitions[0].competitors[0].team.displayName,
        abbreviation: event.competitions[0].competitors[0].team.abbreviation,
        score: parseInt(event.competitions[0].competitors[0].score) || 0,
        logo: event.competitions[0].competitors[0].team.logo,
      },
      awayTeam: {
        id: event.competitions[0].competitors[1].id,
        name: event.competitions[0].competitors[1].team.displayName,
        abbreviation: event.competitions[0].competitors[1].team.abbreviation,
        score: parseInt(event.competitions[0].competitors[1].score) || 0,
        logo: event.competitions[0].competitors[1].team.logo,
      },
      venue: event.competitions[0].venue?.fullName || '',
      quarter: event.status.period || 0,
      timeRemaining: event.status.displayClock || '',
      lastUpdated: FieldValue.serverTimestamp(),
    }));
  } catch (error) {
    console.error(`ESPN API error for ${sport}:`, error.message);
    return [];
  }
}

/**
 * Fetch games from TheSportsDB
 */
async function fetchSportsDBGames(sport) {
  const mapping = SPORT_MAPPINGS[sport];
  if (!mapping || !mapping.db_id) return [];
  
  try {
    // Get events for the next 7 days
    const url = `${API_CONFIG.SPORTS_DB.base_url}/eventsnextleague.php?id=${mapping.db_id}`;
    const response = await axios.get(url);
    
    if (!response.data || !response.data.events) return [];
    
    return response.data.events.map(event => ({
      id: event.idEvent,
      sport: sport,
      status: event.strStatus === 'Match Finished' ? 'final' : 'scheduled',
      startTime: new Date(`${event.dateEvent} ${event.strTime || '00:00'}`),
      homeTeam: {
        id: event.idHomeTeam,
        name: event.strHomeTeam,
        abbreviation: event.strHomeTeam.substring(0, 3).toUpperCase(),
        score: parseInt(event.intHomeScore) || 0,
        logo: event.strHomeTeamBadge,
      },
      awayTeam: {
        id: event.idAwayTeam,
        name: event.strAwayTeam,
        abbreviation: event.strAwayTeam.substring(0, 3).toUpperCase(),
        score: parseInt(event.intAwayScore) || 0,
        logo: event.strAwayTeamBadge,
      },
      venue: event.strVenue || '',
      lastUpdated: FieldValue.serverTimestamp(),
    }));
  } catch (error) {
    console.error(`SportsDB API error for ${sport}:`, error.message);
    return [];
  }
}

/**
 * Map ESPN status to our status
 */
function mapESPNStatus(status) {
  const statusMap = {
    'STATUS_SCHEDULED': 'scheduled',
    'STATUS_IN_PROGRESS': 'live',
    'STATUS_FINAL': 'final',
    'STATUS_POSTPONED': 'postponed',
    'STATUS_CANCELED': 'canceled',
  };
  
  return statusMap[status.type] || 'scheduled';
}

/**
 * Save games to Firestore
 */
async function saveGamesToFirestore(sport, games) {
  const batch = db.batch();
  
  for (const game of games) {
    const gameRef = db.collection('games').doc(`${sport}_${game.id}`);
    
    // Check if game exists and if it's final
    const existingGame = await gameRef.get();
    
    if (existingGame.exists && existingGame.data().status === 'final') {
      // Don't update final games
      continue;
    }
    
    batch.set(gameRef, game, { merge: true });
    
    // If game just finished, trigger settlement
    if (existingGame.exists && 
        existingGame.data().status !== 'final' && 
        game.status === 'final') {
      
      // Add result data for settlement
      game.result = {
        winner: game.homeTeam.score > game.awayTeam.score ? 'home' : 'away',
        homeScore: game.homeTeam.score,
        awayScore: game.awayTeam.score,
        totalScore: game.homeTeam.score + game.awayTeam.score,
      };
      
      batch.update(gameRef, { result: game.result });
    }
  }
  
  await batch.commit();
}

// ============================================
// ODDS FUNCTIONS
// ============================================

/**
 * Update odds for all sports
 */
async function updateAllOdds() {
  if (!API_CONFIG.ODDS_API.key) {
    console.log('Odds API key not configured');
    return;
  }
  
  const sports = ['NFL', 'NBA', 'MLB', 'NHL'];
  
  for (const sport of sports) {
    try {
      await updateSportOdds(sport);
    } catch (error) {
      console.error(`Error updating ${sport} odds:`, error);
    }
  }
}

/**
 * Update odds for a specific sport
 */
async function updateSportOdds(sport) {
  const mapping = SPORT_MAPPINGS[sport];
  if (!mapping || !mapping.odds) return;
  
  try {
    const url = `${API_CONFIG.ODDS_API.base_url}/sports/${mapping.odds}/odds`;
    const params = {
      apiKey: API_CONFIG.ODDS_API.key,
      regions: 'us',
      markets: 'h2h,spreads,totals',
      oddsFormat: 'american',
    };
    
    const response = await axios.get(url, { params });
    
    if (!response.data) return;
    
    await saveOddsToFirestore(sport, response.data);
    console.log(`Updated odds for ${response.data.length} ${sport} games`);
    
  } catch (error) {
    console.error(`Odds API error for ${sport}:`, error.message);
  }
}

/**
 * Save odds to Firestore
 */
async function saveOddsToFirestore(sport, oddsData) {
  const batch = db.batch();
  
  for (const game of oddsData) {
    // Find matching game in our database
    const gamesSnapshot = await db.collection('games')
      .where('sport', '==', sport)
      .where('startTime', '>=', new Date(game.commence_time))
      .where('startTime', '<=', new Date(new Date(game.commence_time).getTime() + 3600000))
      .limit(1)
      .get();
    
    if (gamesSnapshot.empty) continue;
    
    const gameDoc = gamesSnapshot.docs[0];
    const odds = processOdds(game.bookmakers);
    
    batch.update(gameDoc.ref, {
      odds: odds,
      oddsUpdatedAt: FieldValue.serverTimestamp(),
    });
  }
  
  await batch.commit();
}

/**
 * Process bookmaker odds to get best lines
 */
function processOdds(bookmakers) {
  const odds = {
    moneyline: { home: null, away: null },
    spread: { line: null, home: null, away: null },
    total: { line: null, over: null, under: null },
  };
  
  // Get best odds from all bookmakers
  for (const bookmaker of bookmakers) {
    for (const market of bookmaker.markets) {
      switch (market.key) {
        case 'h2h':
          // Moneyline
          const homeML = market.outcomes.find(o => o.name === bookmaker.home_team);
          const awayML = market.outcomes.find(o => o.name === bookmaker.away_team);
          
          if (!odds.moneyline.home || homeML.price > odds.moneyline.home) {
            odds.moneyline.home = homeML.price;
          }
          if (!odds.moneyline.away || awayML.price > odds.moneyline.away) {
            odds.moneyline.away = awayML.price;
          }
          break;
          
        case 'spreads':
          // Point spread
          const homeSpread = market.outcomes.find(o => o.name === bookmaker.home_team);
          const awaySpread = market.outcomes.find(o => o.name === bookmaker.away_team);
          
          if (homeSpread) {
            odds.spread.line = homeSpread.point;
            odds.spread.home = homeSpread.price;
            odds.spread.away = awaySpread.price;
          }
          break;
          
        case 'totals':
          // Over/Under
          const over = market.outcomes.find(o => o.name === 'Over');
          const under = market.outcomes.find(o => o.name === 'Under');
          
          if (over) {
            odds.total.line = over.point;
            odds.total.over = over.price;
            odds.total.under = under.price;
          }
          break;
      }
    }
  }
  
  return odds;
}

// ============================================
// SCHEDULE FUNCTIONS
// ============================================

/**
 * Update schedules for all sports
 */
async function updateAllSportsSchedules() {
  const sports = ['NFL', 'NBA', 'MLB', 'NHL'];
  
  for (const sport of sports) {
    try {
      await updateSportSchedule(sport);
    } catch (error) {
      console.error(`Error updating ${sport} schedule:`, error);
    }
  }
}

/**
 * Update schedule for a specific sport
 */
async function updateSportSchedule(sport) {
  try {
    // Fetch upcoming games for the next 7 days
    const games = await fetchUpcomingGames(sport);
    
    if (games && games.length > 0) {
      await saveScheduleToFirestore(sport, games);
      console.log(`Updated ${games.length} scheduled ${sport} games`);
    }
  } catch (error) {
    console.error(`Error updating ${sport} schedule:`, error);
  }
}

/**
 * Fetch upcoming games
 */
async function fetchUpcomingGames(sport) {
  // Try ESPN first
  try {
    return await fetchESPNSchedule(sport);
  } catch (error) {
    // Fallback to SportsDB
    return await fetchSportsDBGames(sport);
  }
}

/**
 * Fetch ESPN schedule
 */
async function fetchESPNSchedule(sport) {
  const mapping = SPORT_MAPPINGS[sport];
  if (!mapping || !mapping.espn) return [];
  
  try {
    const url = `${API_CONFIG.ESPN.base_url}/${mapping.espn}/schedule`;
    const response = await axios.get(url);
    
    if (!response.data || !response.data.events) return [];
    
    return response.data.events.map(event => ({
      id: event.id,
      sport: sport,
      status: 'scheduled',
      startTime: new Date(event.date),
      homeTeam: {
        id: event.competitions[0].competitors[0].id,
        name: event.competitions[0].competitors[0].team.displayName,
        abbreviation: event.competitions[0].competitors[0].team.abbreviation,
      },
      awayTeam: {
        id: event.competitions[0].competitors[1].id,
        name: event.competitions[0].competitors[1].team.displayName,
        abbreviation: event.competitions[0].competitors[1].team.abbreviation,
      },
      venue: event.competitions[0].venue?.fullName || '',
      broadcast: event.competitions[0].broadcasts?.[0]?.names?.[0] || '',
    }));
  } catch (error) {
    console.error(`ESPN schedule error for ${sport}:`, error.message);
    return [];
  }
}

/**
 * Save schedule to Firestore
 */
async function saveScheduleToFirestore(sport, games) {
  const batch = db.batch();
  
  for (const game of games) {
    const gameRef = db.collection('games').doc(`${sport}_${game.id}`);
    
    // Only update if game doesn't exist or is still scheduled
    const existingGame = await gameRef.get();
    
    if (!existingGame.exists || existingGame.data().status === 'scheduled') {
      batch.set(gameRef, {
        ...game,
        createdAt: FieldValue.serverTimestamp(),
        lastUpdated: FieldValue.serverTimestamp(),
      }, { merge: true });
    }
  }
  
  await batch.commit();
}

// ============================================
// HTTP CALLABLE FUNCTIONS
// ============================================

/**
 * Get live games for a sport
 */
exports.getLiveGames = functions.https.onCall(async (data, context) => {
  const { sport } = data;
  
  if (!sport) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Sport is required'
    );
  }
  
  try {
    const gamesSnapshot = await db.collection('games')
      .where('sport', '==', sport)
      .where('status', '==', 'live')
      .orderBy('startTime', 'asc')
      .limit(20)
      .get();
    
    const games = gamesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    return {
      games,
      timestamp: FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('Error fetching live games:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch live games'
    );
  }
});

/**
 * Get upcoming games for a sport
 */
exports.getUpcomingGames = functions.https.onCall(async (data, context) => {
  const { sport, days = 7 } = data;
  
  if (!sport) {
    throw new functions.https.HttpsError(
      'invalid-argument',
      'Sport is required'
    );
  }
  
  try {
    const now = new Date();
    const future = new Date(now.getTime() + (days * 24 * 60 * 60 * 1000));
    
    const gamesSnapshot = await db.collection('games')
      .where('sport', '==', sport)
      .where('startTime', '>=', now)
      .where('startTime', '<=', future)
      .orderBy('startTime', 'asc')
      .limit(50)
      .get();
    
    const games = gamesSnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data()
    }));
    
    return {
      games,
      timestamp: FieldValue.serverTimestamp()
    };
    
  } catch (error) {
    console.error('Error fetching upcoming games:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to fetch upcoming games'
    );
  }
});

/**
 * Force update games (Admin only)
 */
exports.forceUpdateGames = functions.https.onCall(async (data, context) => {
  // Verify admin status
  if (!context.auth || !context.auth.token.admin) {
    throw new functions.https.HttpsError(
      'permission-denied',
      'Only admins can force game updates'
    );
  }
  
  const { sport } = data;
  
  try {
    if (sport) {
      await updateSportGames(sport);
      await updateSportOdds(sport);
    } else {
      await updateAllSportsGames();
      await updateAllOdds();
    }
    
    return {
      success: true,
      message: `Successfully updated games${sport ? ` for ${sport}` : ''}`
    };
  } catch (error) {
    console.error('Error forcing game update:', error);
    throw new functions.https.HttpsError(
      'internal',
      'Failed to update games'
    );
  }
});

console.log('Sports Data Cloud Functions initialized');