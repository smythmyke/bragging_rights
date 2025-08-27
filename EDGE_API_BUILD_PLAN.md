# EDGE API INTEGRATION BUILD PLAN

## Overview
Complete implementation plan for integrating free APIs with intelligent data relevance and matching strategy for the Bragging Rights Edge feature.

---

## 📋 BUILD PHASES

### PHASE 1: INFRASTRUCTURE SETUP (Week 1)
**Goal:** Establish core infrastructure for API management

#### 1.1 API Gateway Service
```javascript
// functions/edgeGateway.js
class EdgeAPIGateway {
  constructor() {
    this.apis = {
      nba: new NBAStatsAPI(),
      nhl: new NHLAPI(),
      mlb: new MLBStatsAPI(),
      espn: new ESPNAPI(),
      odds: new OddsAPI(),
      news: new NewsAPI(),
      weather: new WeatherAPI(),
      twitter: new TwitterAPI(),
      reddit: new RedditAPI()
    };
    this.cache = new CacheService();
    this.rateLimiter = new RateLimiter();
  }
}
```

#### 1.2 Event Matching Engine
```javascript
// functions/eventMatcher.js
class EventMatcher {
  normalizeTeamName(name) {
    // Convert all team name variations to standard format
    // "LA Lakers" -> "Los Angeles Lakers"
    // "LAL" -> "Los Angeles Lakers"
  }
  
  matchEvent(apiData, eventData) {
    // Smart matching logic
    // Handle date/time variations
    // Match by multiple identifiers
  }
}
```

#### 1.3 Relevance Scoring System
```javascript
// functions/relevanceScorer.js
class RelevanceScorer {
  scoreByTime(timestamp) {}
  scoreBySource(source) {}
  scoreByContent(content, sport) {}
  calculateTotalScore(item) {}
}
```

#### 1.4 Cache Layer
- Redis for hot data (< 5 min)
- Firestore for warm data (< 1 hour)
- Cloud Storage for historical

---

### PHASE 2: OFFICIAL SPORTS APIs (Week 1-2)
**Goal:** Connect all official league APIs

#### 2.1 NBA Stats API Integration
**Documentation:** https://github.com/swar/nba_api/blob/master/docs/table_of_contents.md

```javascript
// functions/sports/nbaAPI.js
const NBA_ENDPOINTS = {
  injuries: 'https://stats.nba.com/stats/commonplayerinfo',
  scores: 'https://stats.nba.com/stats/scoreboardv2',
  stats: 'https://stats.nba.com/stats/leaguedashteamstats',
  news: 'https://stats.nba.com/stats/newsfeed'
};

class NBAStatsAPI {
  async getGameData(gameId) {
    // Headers required for NBA API
    headers: {
      'User-Agent': 'Mozilla/5.0',
      'Referer': 'https://stats.nba.com'
    }
  }
  
  async getInjuryReport(date) {}
  async getLineups(gameId) {}
  async getAdvancedStats(teamId) {}
}
```

#### 2.2 NHL API Integration
**Documentation:** https://gitlab.com/dword4/nhlapi/-/blob/master/stats-api.md

```javascript
// functions/sports/nhlAPI.js
const NHL_BASE = 'https://statsapi.web.nhl.com/api/v1';

class NHLAPI {
  endpoints = {
    schedule: `${NHL_BASE}/schedule`,
    game: `${NHL_BASE}/game/{gameId}/feed/live`,
    teams: `${NHL_BASE}/teams`,
    standings: `${NHL_BASE}/standings`
  };
  
  async getGameFeed(gameId) {}
  async getTeamStats(teamId) {}
  async getPlayerStats(playerId) {}
}
```

#### 2.3 MLB StatsAPI Integration
**Documentation:** https://github.com/MLB-API/mlb-api-docs

```javascript
// functions/sports/mlbAPI.js
const MLB_BASE = 'https://statsapi.mlb.com/api/v1';

class MLBStatsAPI {
  endpoints = {
    schedule: `${MLB_BASE}/schedule`,
    game: `${MLB_BASE}/game/{gameId}/feed/live`,
    weather: `${MLB_BASE}/game/{gameId}/weather`,
    probablePitchers: `${MLB_BASE}/schedule?sportId=1&hydrate=probablePitcher`
  };
  
  async getGameData(gameId) {}
  async getPitcherStats(playerId) {}
  async getWeatherImpact(gameId) {}
}
```

#### 2.4 ESPN API Integration (Unofficial)
**Endpoints Discovery:** Via network inspection

```javascript
// functions/sports/espnAPI.js
const ESPN_BASE = 'https://site.api.espn.com/apis/site/v2/sports';

class ESPNAPI {
  sports = {
    nfl: `${ESPN_BASE}/football/nfl`,
    nba: `${ESPN_BASE}/basketball/nba`,
    mlb: `${ESPN_BASE}/baseball/mlb`,
    nhl: `${ESPN_BASE}/hockey/nhl`,
    mma: `${ESPN_BASE}/mma/ufc`
  };
  
  async getScores(sport, date) {}
  async getNews(sport, teamId) {}
  async getInjuries(sport) {}
  async getOdds(sport, gameId) {}
}
```

---

### PHASE 3: NEWS & SENTIMENT APIs (Week 2)
**Goal:** Implement news aggregation and social sentiment analysis

#### 3.1 NewsAPI.org Integration
**Documentation:** https://newsapi.org/docs

```javascript
// functions/news/newsAPI.js
class NewsAPI {
  constructor() {
    this.apiKey = functions.config().newsapi.key;
    this.baseURL = 'https://newsapi.org/v2';
  }
  
  async searchSports(query, options = {}) {
    // Rate limit: 100 requests/day
    const params = {
      q: query,
      domains: 'espn.com,bleacherreport.com,cbssports.com',
      language: 'en',
      sortBy: 'publishedAt',
      pageSize: 20
    };
  }
  
  async getHeadlines(category = 'sports') {}
  async searchByTeam(teamName, timeframe) {}
}
```

#### 3.2 Twitter API v2 Integration
**Documentation:** https://developer.twitter.com/en/docs/twitter-api

```javascript
// functions/social/twitterAPI.js
class TwitterAPI {
  constructor() {
    this.bearer = functions.config().twitter.bearer;
    this.baseURL = 'https://api.twitter.com/2';
  }
  
  async searchRecent(query, options = {}) {
    // Rate limit: 450 requests/15min
    const params = {
      query: query,
      'tweet.fields': 'created_at,public_metrics,entities',
      'user.fields': 'verified',
      max_results: 100
    };
  }
  
  async getSentiment(tweets) {
    // Analyze with TextBlob or VADER
  }
  
  async trackInjuries(playerName) {
    const verifiedReporters = ['wojespn', 'ShamsCharania'];
    // Search from verified accounts only
  }
}
```

#### 3.3 Reddit API Integration
**Documentation:** https://www.reddit.com/dev/api

```javascript
// functions/social/redditAPI.js
class RedditAPI {
  constructor() {
    this.clientId = functions.config().reddit.client_id;
    this.clientSecret = functions.config().reddit.secret;
  }
  
  async getGameThread(subreddit, teams) {
    // r/nba, r/nfl, etc.
    // Rate limit: 60 requests/minute
  }
  
  async getSentiment(comments) {}
  async getTopPosts(subreddit, timeframe) {}
}
```

#### 3.4 RSS Feed Aggregator
```javascript
// functions/news/rssFeedParser.js
class RSSFeedParser {
  feeds = {
    espn: 'https://www.espn.com/espn/rss/news',
    bleacher: 'https://bleacherreport.com/rss',
    cbs: 'https://www.cbssports.com/rss',
    guardian: 'https://www.theguardian.com/sport/rss'
  };
  
  async parseFeeds(sport, team) {}
  async filterRelevant(articles, event) {}
}
```

---

### PHASE 4: WEATHER & ENVIRONMENTAL (Week 2)
**Goal:** Integrate weather APIs for outdoor sports

#### 4.1 OpenWeatherMap Integration
**Documentation:** https://openweathermap.org/api

```javascript
// functions/weather/openWeatherAPI.js
class OpenWeatherAPI {
  constructor() {
    this.apiKey = functions.config().openweather.key;
    this.baseURL = 'https://api.openweathermap.org/data/2.5';
  }
  
  async getGameTimeWeather(lat, lon, gameTime) {
    // Rate limit: 1000 calls/day
    const endpoint = `${this.baseURL}/onecall`;
    // Include hourly forecast
  }
  
  async getWeatherImpact(conditions, sport) {
    // Calculate impact score
    const impacts = {
      nfl: {
        wind: { threshold: 20, impact: 'HIGH' },
        precipitation: { threshold: 0.5, impact: 'MEDIUM' },
        temperature: { threshold: 20, impact: 'MEDIUM' }
      }
    };
  }
}
```

#### 4.2 Venue Database
```javascript
// functions/data/venueDatabase.js
const VENUE_DATABASE = {
  nfl: {
    'Lambeau Field': { lat: 44.5013, lon: -88.0622, type: 'outdoor' },
    'U.S. Bank Stadium': { lat: 44.9736, lon: -93.2575, type: 'dome' },
    // ... all venues
  },
  mlb: {
    'Fenway Park': { lat: 42.3467, lon: -71.0972, type: 'outdoor' },
    'Tropicana Field': { lat: 27.7682, lon: -82.6534, type: 'dome' },
    // ... all venues
  }
};
```

---

### PHASE 5: ODDS & BETTING INTELLIGENCE (Week 3)
**Goal:** Track line movements and betting patterns

#### 5.1 Enhanced Odds Tracking
```javascript
// functions/betting/oddsTracker.js
class OddsTracker {
  constructor() {
    this.oddsAPI = new OddsAPI(); // Already integrated
    this.history = new Map(); // Store line movement
  }
  
  async trackLineMovement(gameId) {
    const current = await this.oddsAPI.getOdds(gameId);
    const history = this.history.get(gameId) || [];
    
    // Detect significant moves
    if (this.isSignificantMove(current, history)) {
      return {
        alert: 'SHARP_MONEY',
        data: this.analyzeMovement(current, history)
      };
    }
  }
  
  isSignificantMove(current, history) {
    // Logic to detect sharp money
  }
}
```

#### 5.2 Web Scraping Setup (OddsShark, Covers)
```javascript
// functions/scraping/oddsScraper.js
const puppeteer = require('puppeteer');

class OddsScraper {
  async scrapeOddsShark(gameId) {
    const browser = await puppeteer.launch();
    const page = await browser.newPage();
    // Scraping logic
  }
  
  async scrapeCovers(gameId) {}
  async getPublicBetting(gameId) {}
  async getConsensus(gameId) {}
}
```

---

### PHASE 6: INTELLIGENT MATCHING ENGINE (Week 3)
**Goal:** Implement smart event matching and relevance scoring

#### 6.1 Event Identification System
```javascript
// functions/intelligence/eventIdentifier.js
class EventIdentifier {
  constructor() {
    this.teamMappings = require('./teamMappings.json');
    this.playerMappings = require('./playerMappings.json');
  }
  
  identifyEvent(rawData) {
    return {
      primaryId: this.extractGameId(rawData),
      date: this.normalizeDate(rawData),
      teams: this.normalizeTeams(rawData),
      players: this.extractKeyPlayers(rawData),
      venue: this.identifyVenue(rawData),
      searchTerms: this.generateSearchTerms(rawData)
    };
  }
  
  generateSearchTerms(event) {
    // Create comprehensive search terms
    const terms = [];
    terms.push(...event.teams.home.aliases);
    terms.push(...event.teams.away.aliases);
    terms.push(...event.players.map(p => p.name));
    terms.push(`#${event.teams.home.hashtag}`);
    return terms;
  }
}
```

#### 6.2 Relevance Engine
```javascript
// functions/intelligence/relevanceEngine.js
class RelevanceEngine {
  constructor() {
    this.scoringWeights = {
      timeDecay: 0.3,
      sourceCredibility: 0.25,
      contentType: 0.25,
      userEngagement: 0.2
    };
  }
  
  scoreIntelligence(item, event, context) {
    const scores = {
      time: this.scoreTimeRelevance(item.timestamp),
      source: this.scoreSourceCredibility(item.source),
      content: this.scoreContentRelevance(item.content, event),
      engagement: this.scoreEngagement(item.metrics)
    };
    
    return this.calculateWeightedScore(scores);
  }
  
  filterNoise(items) {
    // Remove duplicate info
    // Filter out promotional content
    // Remove outdated information
  }
}
```

#### 6.3 Alert System
```javascript
// functions/intelligence/alertSystem.js
class AlertSystem {
  triggers = {
    CRITICAL: [
      { type: 'INJURY', pattern: /ruled out|will not play/i },
      { type: 'LINE_MOVE', threshold: 3.0 },
      { type: 'WEATHER', condition: 'severe' }
    ],
    HIGH: [
      { type: 'INJURY', pattern: /questionable|game-time decision/i },
      { type: 'LINE_MOVE', threshold: 1.5 },
      { type: 'NEWS', keywords: ['suspension', 'benched'] }
    ]
  };
  
  async checkTriggers(intel, event) {
    const alerts = [];
    
    for (const item of intel) {
      const priority = this.evaluatePriority(item);
      if (priority) {
        alerts.push({ ...item, priority });
      }
    }
    
    return alerts.sort((a, b) => 
      this.priorityOrder[a.priority] - this.priorityOrder[b.priority]
    );
  }
}
```

---

### PHASE 7: DATA AGGREGATION PIPELINE (Week 4)
**Goal:** Combine all data sources into unified intelligence

#### 7.1 Master Aggregator
```javascript
// functions/intelligence/masterAggregator.js
class MasterAggregator {
  async gatherEventIntelligence(event) {
    // Step 1: Identify event across all APIs
    const eventId = await this.eventIdentifier.identify(event);
    
    // Step 2: Parallel data gathering
    const [
      official,
      news,
      social,
      weather,
      betting
    ] = await Promise.all([
      this.gatherOfficialData(eventId),
      this.gatherNewsData(eventId),
      this.gatherSocialData(eventId),
      this.gatherWeatherData(eventId),
      this.gatherBettingData(eventId)
    ]);
    
    // Step 3: Merge and deduplicate
    const merged = this.mergeIntelligence(
      official, news, social, weather, betting
    );
    
    // Step 4: Score relevance
    const scored = this.relevanceEngine.score(merged, event);
    
    // Step 5: Generate Edge cards
    return this.formatForEdgeCards(scored);
  }
}
```

#### 7.2 Edge Card Formatter
```javascript
// functions/intelligence/edgeCardFormatter.js
class EdgeCardFormatter {
  formatIntelligence(intel, sport) {
    const cards = [];
    
    // Injury Report Card
    if (intel.injuries.length > 0) {
      cards.push({
        id: 'injury',
        title: 'Injury Report',
        priority: this.calculatePriority(intel.injuries),
        data: this.formatInjuries(intel.injuries),
        cost: 20,
        confidence: intel.injuries[0].confidence
      });
    }
    
    // Social Sentiment Card
    if (intel.social.sentiment) {
      cards.push({
        id: 'sentiment',
        title: 'Social Pulse',
        data: this.formatSentiment(intel.social),
        cost: 10
      });
    }
    
    // Weather Impact Card (outdoor only)
    if (intel.weather && intel.weather.impact > 0.5) {
      cards.push({
        id: 'weather',
        title: 'Weather Alert',
        data: this.formatWeather(intel.weather),
        cost: 5
      });
    }
    
    return cards;
  }
}
```

---

### PHASE 8: TESTING & OPTIMIZATION (Week 4)
**Goal:** Test all integrations and optimize performance

#### 8.1 API Testing Suite
```javascript
// test/apiTests.js
describe('API Integration Tests', () => {
  test('NBA API returns valid data', async () => {
    const nba = new NBAStatsAPI();
    const data = await nba.getGameData('0022300123');
    expect(data).toHaveProperty('gameId');
  });
  
  test('Event matcher handles team variations', () => {
    const matcher = new EventMatcher();
    const result = matcher.match('LA Lakers', 'Los Angeles Lakers');
    expect(result).toBe(true);
  });
  
  test('Relevance scorer weights correctly', () => {
    const scorer = new RelevanceScorer();
    const score = scorer.score(mockItem, mockEvent);
    expect(score).toBeGreaterThan(0);
    expect(score).toBeLessThanOrEqual(100);
  });
});
```

#### 8.2 Performance Optimization
```javascript
// functions/optimization/cacheStrategy.js
class CacheStrategy {
  rules = {
    'live-scores': { ttl: 30, priority: 'memory' },
    'injuries': { ttl: 300, priority: 'memory' },
    'news': { ttl: 900, priority: 'database' },
    'weather': { ttl: 1800, priority: 'database' },
    'historical': { ttl: 86400, priority: 'storage' }
  };
  
  async get(key, fetcher) {
    const cached = await this.cache.get(key);
    if (cached && !this.isExpired(cached)) {
      return cached.data;
    }
    
    const fresh = await fetcher();
    await this.cache.set(key, fresh, this.rules[type].ttl);
    return fresh;
  }
}
```

#### 8.3 Error Handling & Fallbacks
```javascript
// functions/errorHandling/fallbackChain.js
class FallbackChain {
  async executeWithFallback(primaryFn, fallbacks) {
    try {
      return await primaryFn();
    } catch (error) {
      console.error('Primary failed:', error);
      
      for (const fallback of fallbacks) {
        try {
          return await fallback();
        } catch (fallbackError) {
          console.error('Fallback failed:', fallbackError);
        }
      }
      
      return this.getDefaultResponse();
    }
  }
}
```

---

## 📅 IMPLEMENTATION TIMELINE

### Week 1: Infrastructure & Official APIs
- [ ] Day 1-2: Setup API Gateway, Event Matcher, Cache Layer
- [ ] Day 3-4: NBA Stats API integration
- [ ] Day 4-5: NHL & MLB API integration
- [ ] Day 5-6: ESPN API integration
- [ ] Day 7: Testing & debugging

### Week 2: News & Social Intelligence
- [ ] Day 8-9: NewsAPI.org integration
- [ ] Day 9-10: Twitter API v2 setup
- [ ] Day 10-11: Reddit API integration
- [ ] Day 11-12: RSS feed parser
- [ ] Day 12-13: Weather API integration
- [ ] Day 14: Sentiment analysis implementation

### Week 3: Advanced Intelligence
- [ ] Day 15-16: Web scraping setup
- [ ] Day 16-17: Odds tracking enhancement
- [ ] Day 17-18: Event matching engine
- [ ] Day 18-19: Relevance scoring system
- [ ] Day 19-20: Alert system
- [ ] Day 21: Integration testing

### Week 4: Pipeline & Optimization
- [ ] Day 22-23: Master aggregator
- [ ] Day 23-24: Edge card formatter
- [ ] Day 24-25: Performance optimization
- [ ] Day 25-26: Error handling & fallbacks
- [ ] Day 26-27: End-to-end testing
- [ ] Day 28: Production deployment

---

## 🔧 TECHNICAL REQUIREMENTS

### Environment Variables Needed
```env
# API Keys
NEWS_API_KEY=
TWITTER_BEARER_TOKEN=
REDDIT_CLIENT_ID=
REDDIT_CLIENT_SECRET=
OPENWEATHER_API_KEY=
ODDS_API_KEY=

# Database
REDIS_URL=
FIRESTORE_PROJECT=

# Rate Limits
NBA_RATE_LIMIT=30
NEWS_API_DAILY_LIMIT=100
TWITTER_RATE_LIMIT=450
```

### Dependencies to Install
```json
{
  "dependencies": {
    "axios": "^1.6.0",
    "puppeteer": "^21.0.0",
    "cheerio": "^1.0.0",
    "node-cache": "^5.1.2",
    "redis": "^4.6.0",
    "twitter-api-v2": "^1.15.0",
    "snoowrap": "^1.23.0",
    "rss-parser": "^3.13.0",
    "sentiment": "^5.0.2",
    "bottleneck": "^2.19.5"
  }
}
```

---

## 🎯 SUCCESS METRICS

### Coverage Targets
- **NBA Games**: 100% coverage
- **NFL Games**: 100% coverage
- **NHL Games**: 100% coverage
- **MLB Games**: 100% coverage
- **Soccer Matches**: 90% coverage
- **MMA/Boxing Events**: 85% coverage

### Performance Targets
- **API Response Time**: < 500ms (cached)
- **Data Freshness**: < 1 minute for live data
- **Relevance Score**: > 80% accuracy
- **Uptime**: 99.9%
- **Cost**: $0 (all free APIs)

### Quality Metrics
- **False Positive Rate**: < 5%
- **Data Accuracy**: > 95%
- **User Satisfaction**: > 4.5/5 stars

---

## 🚀 DEPLOYMENT STRATEGY

### Phase 1: Development
- Local testing with sample data
- API integration verification
- Unit testing all components

### Phase 2: Staging
- Deploy to Firebase Functions (dev project)
- Load testing with real API calls
- Monitor rate limits and quotas

### Phase 3: Production
- Gradual rollout (10% -> 50% -> 100%)
- Real-time monitoring
- Alert system for failures

---

## 📝 DOCUMENTATION REQUIREMENTS

### For Each API Integration:
1. Authentication method
2. Rate limits and quotas
3. Error codes and handling
4. Example requests/responses
5. Fallback strategies

### For Intelligence System:
1. Matching algorithm documentation
2. Relevance scoring formula
3. Alert trigger definitions
4. Edge card format specifications

---

## ✅ DELIVERABLES

### Week 1 Deliverables
- [ ] Functional API Gateway
- [ ] Connected official sports APIs
- [ ] Basic event matching
- [ ] Cache implementation

### Week 2 Deliverables
- [ ] News aggregation system
- [ ] Social sentiment analysis
- [ ] Weather integration
- [ ] RSS feed parsing

### Week 3 Deliverables
- [ ] Web scraping system
- [ ] Enhanced odds tracking
- [ ] Intelligent matching engine
- [ ] Alert system

### Week 4 Deliverables
- [ ] Complete data pipeline
- [ ] Optimized performance
- [ ] Full test coverage
- [ ] Production deployment

---

*Build Start Date: [TBD]*
*Target Completion: 4 weeks*
*Document Version: 1.0*