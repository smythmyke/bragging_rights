/**
 * Sports API Proxy Functions
 * Securely proxies API calls to external sports data providers
 * API keys are stored in Firebase Functions config, never exposed to clients
 */

const functions = require('firebase-functions');
const admin = require('firebase-admin');
const axios = require('axios');

// Initialize Firestore for caching
const db = admin.firestore();

// Cache durations (in seconds)
const CACHE_DURATIONS = {
  odds: 300,        // 5 minutes for odds
  games: 300,       // 5 minutes for live games
  news: 3600,       // 1 hour for news
  stats: 86400,     // 24 hours for player stats
};

// ============================================
// NBA API PROXY (Balldontlie)
// ============================================

exports.getNBAGames = functions.https.onCall(async (data, context) => {
  // Require authentication
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { season, page = 1, perPage = 25 } = data;
  const cacheKey = `nba_games_${season}_${page}_${perPage}`;

  try {
    // Check cache first
    const cached = await checkCache(cacheKey, CACHE_DURATIONS.games);
    if (cached) return cached;

    // Get API key from Firebase config
    const apiKey = functions.config().api?.balldontlie;
    if (!apiKey) {
      throw new functions.https.HttpsError('failed-precondition', 'NBA API not configured');
    }

    // Make API request
    const response = await axios.get('https://api.balldontlie.io/v1/games', {
      params: {
        'seasons[]': season || 2024,
        page,
        per_page: perPage
      },
      headers: {
        'Authorization': apiKey
      }
    });

    // Cache the response
    await setCache(cacheKey, response.data, CACHE_DURATIONS.games);

    return response.data;
  } catch (error) {
    console.error('NBA API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch NBA games');
  }
});

exports.getNBAStats = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { playerId, season } = data;
  const cacheKey = `nba_stats_${playerId}_${season}`;

  try {
    // Check cache first
    const cached = await checkCache(cacheKey, CACHE_DURATIONS.stats);
    if (cached) return cached;

    const apiKey = functions.config().api?.balldontlie;
    if (!apiKey) {
      throw new functions.https.HttpsError('failed-precondition', 'NBA API not configured');
    }

    const response = await axios.get(`https://api.balldontlie.io/v1/season_averages`, {
      params: {
        'player_ids[]': playerId,
        season: season || 2024
      },
      headers: {
        'Authorization': apiKey
      }
    });

    await setCache(cacheKey, response.data, CACHE_DURATIONS.stats);
    return response.data;
  } catch (error) {
    console.error('NBA Stats API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch NBA stats');
  }
});

// ============================================
// ODDS API PROXY
// ============================================

exports.getOdds = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { sport, markets = 'h2h', bookmakers = 'draftkings' } = data;
  const cacheKey = `odds_${sport}_${markets}_${bookmakers}`;

  try {
    // Check cache first
    const cached = await checkCache(cacheKey, CACHE_DURATIONS.odds);
    if (cached) return cached;

    const apiKey = functions.config().api?.odds;
    if (!apiKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Odds API not configured');
    }

    // Get odds for the specified sport
    const response = await axios.get(`https://api.the-odds-api.com/v4/sports/${sport}/odds`, {
      params: {
        apiKey,
        regions: 'us',
        markets,
        bookmakers
      }
    });

    // Add quota information to response
    const quotaInfo = {
      used: response.headers['x-requests-used'],
      remaining: response.headers['x-requests-remaining']
    };

    const result = {
      odds: response.data,
      quota: quotaInfo
    };

    await setCache(cacheKey, result, CACHE_DURATIONS.odds);
    return result;
  } catch (error) {
    console.error('Odds API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch odds');
  }
});

exports.getSportsInSeason = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const cacheKey = 'sports_in_season';

  try {
    // Check cache first
    const cached = await checkCache(cacheKey, CACHE_DURATIONS.games);
    if (cached) return cached;

    const apiKey = functions.config().api?.odds;
    if (!apiKey) {
      throw new functions.https.HttpsError('failed-precondition', 'Odds API not configured');
    }

    const response = await axios.get('https://api.the-odds-api.com/v4/sports', {
      params: { apiKey }
    });

    // Filter for active sports only
    const activeSports = response.data.filter(sport => sport.active);
    
    await setCache(cacheKey, activeSports, CACHE_DURATIONS.games);
    return activeSports;
  } catch (error) {
    console.error('Sports API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch sports');
  }
});

// ============================================
// NEWS API PROXY
// ============================================

exports.getSportsNews = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { query, sport } = data;
  const cacheKey = `news_${sport}_${query?.substring(0, 20)}`;

  try {
    // Check cache first
    const cached = await checkCache(cacheKey, CACHE_DURATIONS.news);
    if (cached) return cached;

    const apiKey = functions.config().api?.news;
    if (!apiKey) {
      throw new functions.https.HttpsError('failed-precondition', 'News API not configured');
    }

    const response = await axios.get('https://newsapi.org/v2/everything', {
      params: {
        q: query || sport,
        sortBy: 'publishedAt',
        language: 'en',
        pageSize: 20,
        apiKey
      }
    });

    await setCache(cacheKey, response.data, CACHE_DURATIONS.news);
    return response.data;
  } catch (error) {
    console.error('News API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch news');
  }
});

// ============================================
// ESPN API PROXY (No auth required)
// ============================================

exports.getESPNScoreboard = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { sport } = data;
  const cacheKey = `espn_scoreboard_${sport}`;

  try {
    // Check cache first
    const cached = await checkCache(cacheKey, CACHE_DURATIONS.games);
    if (cached) return cached;

    // ESPN doesn't require API key
    const sportMappings = {
      'nfl': 'football/nfl',
      'nba': 'basketball/nba',
      'nhl': 'hockey/nhl',
      'mlb': 'baseball/mlb',
      'mma': 'mma/ufc',
      'boxing': 'boxing'
    };

    const espnSport = sportMappings[sport.toLowerCase()] || sport;
    const response = await axios.get(
      `https://site.api.espn.com/apis/site/v2/sports/${espnSport}/scoreboard`
    );

    await setCache(cacheKey, response.data, CACHE_DURATIONS.games);
    return response.data;
  } catch (error) {
    console.error('ESPN API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch ESPN data');
  }
});

// ============================================
// NHL API PROXY (No auth required)
// ============================================

exports.getNHLSchedule = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  const { date } = data;
  const cacheKey = `nhl_schedule_${date || 'today'}`;

  try {
    // Check cache first
    const cached = await checkCache(cacheKey, CACHE_DURATIONS.games);
    if (cached) return cached;

    // NHL API doesn't require authentication
    const endpoint = date 
      ? `https://api-web.nhle.com/v1/schedule/${date}`
      : 'https://api-web.nhle.com/v1/schedule/now';

    const response = await axios.get(endpoint);
    
    await setCache(cacheKey, response.data, CACHE_DURATIONS.games);
    return response.data;
  } catch (error) {
    console.error('NHL API error:', error);
    throw new functions.https.HttpsError('internal', 'Failed to fetch NHL schedule');
  }
});

// ============================================
// CACHING UTILITIES
// ============================================

async function checkCache(key, maxAge) {
  try {
    const doc = await db.collection('api_cache').doc(key).get();
    
    if (!doc.exists) return null;
    
    const data = doc.data();
    const age = (Date.now() - data.timestamp) / 1000; // Age in seconds
    
    if (age > maxAge) {
      // Cache expired
      return null;
    }
    
    console.log(`Cache hit for ${key}`);
    return data.value;
  } catch (error) {
    console.error('Cache check error:', error);
    return null;
  }
}

async function setCache(key, value, ttl) {
  try {
    await db.collection('api_cache').doc(key).set({
      value,
      timestamp: Date.now(),
      ttl,
      expiresAt: new Date(Date.now() + (ttl * 1000))
    });
    console.log(`Cached ${key} for ${ttl} seconds`);
  } catch (error) {
    console.error('Cache set error:', error);
  }
}

// ============================================
// TENNIS API PROXY (Future implementation)
// ============================================

exports.getTennisMatches = functions.https.onCall(async (data, context) => {
  if (!context.auth) {
    throw new functions.https.HttpsError('unauthenticated', 'User must be authenticated');
  }

  // TODO: Implement SportDevs Tennis API proxy
  // Placeholder for tennis integration
  throw new functions.https.HttpsError('unimplemented', 'Tennis API coming soon');
});

module.exports = {
  getNBAGames: exports.getNBAGames,
  getNBAStats: exports.getNBAStats,
  getOdds: exports.getOdds,
  getSportsInSeason: exports.getSportsInSeason,
  getSportsNews: exports.getSportsNews,
  getESPNScoreboard: exports.getESPNScoreboard,
  getNHLSchedule: exports.getNHLSchedule,
  getTennisMatches: exports.getTennisMatches
};