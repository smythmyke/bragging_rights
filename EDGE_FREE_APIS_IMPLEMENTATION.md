# EDGE FEATURE - FREE APIs IMPLEMENTATION PLAN

## Executive Summary
This document outlines all FREE APIs that will be integrated into the Bragging Rights Edge feature, organized by sport and data type for maximum coverage without cost.

---

## 🎯 FREE APIs BY SPORT

### 🏀 NBA Coverage (Excellent - 95%+ games)
1. **NBA Stats API** (Official)
   - Endpoint: `stats.nba.com/stats/`
   - Data: Live scores, player stats, team stats, advanced metrics
   - Rate Limit: Reasonable (unofficial)
   - Implementation Priority: **HIGH**

2. **ESPN NBA API** (Unofficial)
   - Endpoint: `site.api.espn.com/apis/site/v2/sports/basketball/nba`
   - Data: Scores, news, injuries, standings
   - Rate Limit: No official limit
   - Implementation Priority: **HIGH**

3. **Basketball-Reference** (Scraping)
   - URL: `basketball-reference.com`
   - Data: Historical stats, advanced metrics, head-to-head
   - Implementation Priority: **MEDIUM**

4. **Twitter NBA Community**
   - API: Twitter v2
   - Data: Real-time sentiment, injury updates, insider news
   - Implementation Priority: **HIGH**

5. **Reddit r/nba**
   - API: Reddit API
   - Data: Fan sentiment, game threads, news discussion
   - Implementation Priority: **MEDIUM**

### 🏈 NFL Coverage (Good - 90%+ games)
1. **NFL NextGen Stats** 
   - URL: `nextgenstats.nfl.com`
   - Data: Advanced player tracking, speed, distance
   - Access: Web scraping
   - Implementation Priority: **HIGH**

2. **ESPN NFL API** (Unofficial)
   - Endpoint: `site.api.espn.com/apis/site/v2/sports/football/nfl`
   - Data: Scores, injuries, news, standings
   - Implementation Priority: **HIGH**

3. **Pro-Football-Reference** (Scraping)
   - URL: `pro-football-reference.com`
   - Data: Historical stats, weather info, betting trends
   - Implementation Priority: **MEDIUM**

4. **NFLfastR** (Open Source)
   - Source: R package / Python port
   - Data: Play-by-play data, EPA, success rates
   - Implementation Priority: **MEDIUM**

5. **Twitter NFL Community**
   - Accounts: @AdamSchefter, @RapSheet, team beats
   - Data: Breaking news, injuries, insider info
   - Implementation Priority: **HIGH**

### 🏒 NHL Coverage (Excellent - 95%+ games)
1. **NHL API** (Official)
   - Endpoint: `statsapi.web.nhl.com/api/v1`
   - Data: Live scores, player stats, team stats
   - Rate Limit: None published
   - Implementation Priority: **HIGH**

2. **ESPN NHL API** (Unofficial)
   - Endpoint: `site.api.espn.com/apis/site/v2/sports/hockey/nhl`
   - Data: Scores, news, injuries
   - Implementation Priority: **HIGH**

3. **Natural Stat Trick**
   - URL: `naturalstattrick.com`
   - Data: Advanced analytics, Corsi, Fenwick
   - Access: Scraping
   - Implementation Priority: **MEDIUM**

4. **MoneyPuck**
   - URL: `moneypuck.com`
   - Data: Expected goals, win probability
   - Access: Scraping/CSV
   - Implementation Priority: **LOW**

### ⚾ MLB Coverage (Excellent - 95%+ games)
1. **MLB StatsAPI** (Official)
   - Endpoint: `statsapi.mlb.com`
   - Data: Live data, pitch-by-pitch, Statcast
   - Rate Limit: Generous
   - Implementation Priority: **HIGH**

2. **Baseball Savant**
   - URL: `baseballsavant.mlb.com`
   - Data: Statcast metrics, sprint speed, exit velocity
   - Access: API/CSV
   - Implementation Priority: **HIGH**

3. **Baseball-Reference** (Scraping)
   - URL: `baseball-reference.com`
   - Data: Historical stats, weather, park factors
   - Implementation Priority: **MEDIUM**

4. **Brooks Baseball**
   - URL: `brooksbaseball.net`
   - Data: PitchFX data, pitch movement
   - Implementation Priority: **LOW**

### ⚽ Soccer Coverage (Good - 85%+ matches)
1. **Football-Data.org**
   - Endpoint: `api.football-data.org/v4`
   - Data: European leagues, scores, standings
   - Rate Limit: 10 req/min (free)
   - Implementation Priority: **HIGH**

2. **TheSportsDB**
   - Endpoint: `thesportsdb.com/api/v1/json/3`
   - Data: Multiple leagues, team info, events
   - Rate Limit: Reasonable
   - Implementation Priority: **HIGH**

3. **SofaScore** (Scraping)
   - URL: `sofascore.com`
   - Data: Live scores, stats, lineups
   - Implementation Priority: **MEDIUM**

4. **FBref** (Scraping)
   - URL: `fbref.com`
   - Data: Advanced stats, xG, player data
   - Implementation Priority: **MEDIUM**

### 🥊 MMA/Boxing Coverage (Moderate - 80%+ events)
1. **UFC Stats** (Scraping)
   - URL: `ufcstats.com`
   - Data: Fighter stats, strike accuracy, takedowns
   - Implementation Priority: **HIGH**

2. **Sherdog** (Scraping)
   - URL: `sherdog.com`
   - Data: Fighter records, event results
   - Implementation Priority: **MEDIUM**

3. **BoxRec** (Scraping)
   - URL: `boxrec.com`
   - Data: Boxing records, rankings
   - Implementation Priority: **MEDIUM**

4. **Tapology** (Scraping)
   - URL: `tapology.com`
   - Data: MMA rankings, fighter profiles
   - Implementation Priority: **LOW**

### 🎾 Tennis Coverage (Moderate - 75%+ matches)
1. **Tennis Abstract**
   - URL: `tennisabstract.com`
   - Data: Historical data, analytics
   - Access: CSV downloads
   - Implementation Priority: **MEDIUM**

2. **Ultimate Tennis Statistics**
   - Source: GitHub (open source)
   - Data: Historical stats, H2H, surface analysis
   - Implementation Priority: **LOW**

3. **ATP/WTA Official** (Scraping)
   - URLs: `atptour.com`, `wtatennis.com`
   - Data: Rankings, recent form
   - Implementation Priority: **MEDIUM**

---

## 📰 NEWS & MEDIA APIS (FREE)

### Primary News Sources
1. **NewsAPI.org**
   - Limit: 100 requests/day
   - Coverage: 80+ sources
   - Languages: 14
   - Priority: **HIGH**

2. **Currents API**
   - Limit: 600 requests/day
   - Coverage: Global news
   - Priority: **MEDIUM**

3. **GNews API**
   - Limit: 100 requests/day
   - Coverage: 60,000+ sources
   - Priority: **LOW**

### RSS Feeds (Unlimited)
1. **ESPN RSS** - All sports
2. **Bleacher Report RSS** - All sports
3. **CBS Sports RSS** - All sports
4. **Fox Sports RSS** - All sports
5. **The Guardian Sports RSS** - Soccer focus
6. **BBC Sport RSS** - UK sports
7. **Google News RSS** - Customizable

---

## 🌡️ WEATHER APIS (FREE)

1. **OpenWeatherMap**
   - Limit: 1000 calls/day
   - Data: Current, forecast, historical
   - Priority: **HIGH**

2. **Open-Meteo**
   - Limit: Unlimited
   - Data: Global weather, no key required
   - Priority: **HIGH**

3. **NOAA/NWS API**
   - Limit: Unlimited (US only)
   - Data: Official US government data
   - Priority: **MEDIUM**

4. **WeatherAPI**
   - Limit: 1M calls/month
   - Data: Current, forecast, sports specific
   - Priority: **LOW**

---

## 📱 SOCIAL SENTIMENT APIS (FREE)

1. **Twitter API v2**
   - Limit: 500k tweets/month
   - Use Cases: Sentiment, injuries, news
   - Priority: **HIGH**

2. **Reddit API**
   - Limit: 60 requests/minute
   - Use Cases: Game threads, sentiment
   - Priority: **HIGH**

3. **YouTube Data API**
   - Limit: 10,000 units/day
   - Use Cases: Highlights, analysis
   - Priority: **LOW**

4. **Discord API**
   - Limit: Reasonable
   - Use Cases: Community sentiment
   - Priority: **LOW**

---

## 🎲 BETTING DATA (FREE)

1. **The Odds API**
   - Limit: 500 requests/month (free tier)
   - Data: Lines, movement
   - Priority: **ALREADY INTEGRATED**

2. **OddsShark** (Scraping)
   - Data: Consensus, public betting
   - Priority: **HIGH**

3. **Covers.com** (Scraping)
   - Data: Trends, consensus
   - Priority: **MEDIUM**

4. **Vegas Insider** (Scraping)
   - Data: Line movement, betting percentages
   - Priority: **LOW**

---

## 🔧 IMPLEMENTATION PLAN

### Phase 1: Core APIs (Week 1)
```javascript
Priority: CRITICAL
- NBA Stats API
- NHL API
- MLB StatsAPI
- ESPN APIs (all sports)
- OpenWeatherMap
- The Odds API (already done)
```

### Phase 2: News & Sentiment (Week 2)
```javascript
Priority: HIGH
- NewsAPI.org
- Twitter API v2
- Reddit API
- Google News RSS
- ESPN RSS feeds
```

### Phase 3: Advanced Stats (Week 3)
```javascript
Priority: MEDIUM
- Sport-specific scraping
- Basketball-Reference
- Pro-Football-Reference
- Natural Stat Trick
- Baseball Savant
```

### Phase 4: Supplementary (Week 4)
```javascript
Priority: LOW
- Additional news APIs
- YouTube API
- Secondary weather APIs
- Historical data sources
```

---

## 📊 DATA AGGREGATION STRATEGY

### For Each Game/Event:
1. **Primary Data** (Official APIs)
   - Live scores and stats
   - Official injury reports
   - Starting lineups

2. **Betting Intelligence** (Odds + Scraping)
   - Line movement from The Odds API
   - Public betting % from OddsShark
   - Sharp money indicators

3. **News & Sentiment** (News APIs + Social)
   - Breaking news from NewsAPI
   - Twitter sentiment analysis
   - Reddit game thread sentiment

4. **Weather** (Weather APIs)
   - Game-time conditions
   - Wind speed for outdoor games
   - Precipitation probability

5. **Historical Context** (Reference Sites)
   - Head-to-head records
   - Recent performance
   - Venue/surface analysis

---

## 💾 CACHING STRATEGY

### Cache Durations:
- **Live Scores**: 30 seconds
- **Statistics**: 5 minutes
- **News**: 15 minutes
- **Weather**: 30 minutes
- **Historical Data**: 24 hours
- **Social Sentiment**: 5 minutes

### Cache Layers:
1. **Memory Cache** (Redis)
   - Hot data (< 5 min old)
2. **Database Cache** (Firestore)
   - Warm data (< 1 hour old)
3. **Cold Storage** (Cloud Storage)
   - Historical data (> 1 hour old)

---

## 🎯 COVERAGE TARGETS

### Minimum Coverage Goals:
- **NBA**: 100% of games
- **NFL**: 100% of games
- **NHL**: 100% of games
- **MLB**: 100% of games
- **Soccer**: 90% of major leagues
- **MMA/Boxing**: 85% of major events
- **Tennis**: 80% of ATP/WTA events
- **Golf**: 75% of PGA events
- **Other**: 60% coverage

### Data Points Per Event:
- **Minimum**: 10 data points
- **Target**: 25 data points
- **Optimal**: 40+ data points

---

## 🚨 FALLBACK CHAINS

### If Primary API Fails:
1. **NBA Game**
   - Primary: NBA Stats API
   - Fallback 1: ESPN API
   - Fallback 2: TheSportsDB
   - Fallback 3: Web scraping

2. **NFL Game**
   - Primary: ESPN API
   - Fallback 1: TheSportsDB
   - Fallback 2: Web scraping

3. **News**
   - Primary: NewsAPI.org
   - Fallback 1: Currents API
   - Fallback 2: RSS feeds
   - Fallback 3: Google News RSS

---

## ✅ SUCCESS METRICS

### API Reliability:
- **Uptime Target**: 99.9%
- **Response Time**: < 500ms
- **Error Rate**: < 0.1%

### Data Quality:
- **Accuracy**: 99%+
- **Freshness**: < 1 minute for live data
- **Completeness**: 95%+ fields populated

### User Experience:
- **Edge Cards Load Time**: < 2 seconds
- **Data Refresh Rate**: Real-time where available
- **Fallback Transparency**: Users informed of data source

---

## 📝 LEGAL COMPLIANCE

### Required Actions:
1. **Review Terms of Service** for each API
2. **Implement Rate Limiting** per API requirements
3. **Add Attribution** where required
4. **Respect Robots.txt** for scraping
5. **Cache Appropriately** to minimize requests
6. **Monitor Usage** to stay within limits

### Risk Mitigation:
- Multiple data sources per data type
- Graceful degradation
- User consent for data usage
- Clear data source attribution
- Regular legal review

---

*Implementation Start Date: [TBD]*
*Target Completion: 4 weeks*
*Document Version: 1.0*