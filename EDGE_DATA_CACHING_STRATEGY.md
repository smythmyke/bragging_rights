# Edge Data Caching & Multi-User Sharing Strategy

## Executive Summary
This document outlines the caching and data sharing strategy for the Edge Intelligence feature, designed to serve thousands of users while minimizing API calls and staying within free tier limits.

---

## 🎯 Problem Statement

### Current Issues:
- Each user making identical API calls = waste of quota
- Example: 100 users checking Lakers game = 100 identical API calls
- Rate limits would be hit quickly:
  - Balldontlie: 5 req/min
  - NewsAPI: 100 req/day
  - Reddit: 60 req/min

### Solution:
Implement centralized caching where one API call serves all users.

---

## 📊 Architecture Overview

```
User Request → Check Cache → Found? → Return Cached Data
                ↓ Not Found
              API Call → Store in Cache → Return to User
                        ↓
                  Share with ALL users
```

---

## 🏀 Basketball-Specific Timing Strategy

### Game Flow Timeline
```
Pre-Game (2hr before) → Active Game (2.5hr) → Post-Game (30min)
    ↓                        ↓                      ↓
Lineups/Injuries        Fast scoring           Final stats
News peaks             Constant changes        News/reactions
```

### Basketball Characteristics
- **Scoring Frequency**: Every 24-48 seconds (shot clock)
- **Score Changes**: 100+ times per game
- **Average Points**: 200-240 total per game
- **Game Duration**: ~2.5 hours real time
- **Daily Games**: 5-15 NBA games

### Dynamic Cache TTL Configuration

```javascript
const BasketballCacheTTL = {
  // PRE-GAME (2 hours - 0 min before tip)
  preGame: {
    lineups: 300,        // 5 min (might change)
    injuries: 600,       // 10 min
    news: 900,           // 15 min
    odds: 120,           // 2 min (lines move fast)
    social: 300,         // 5 min (building hype)
  },
  
  // LIVE GAME - First Half
  firstHalf: {
    scores: 30,          // 30 seconds (critical)
    stats: 60,           // 1 min
    playByPlay: 30,      // 30 seconds
    news: 600,           // 10 min (less important)
    social: 120,         // 2 min (reactions)
  },
  
  // HALFTIME
  halftime: {
    scores: 300,         // 5 min (no changes)
    stats: 180,          // 3 min
    news: 300,           // 5 min (halftime analysis)
    social: 60,          // 1 min (hot takes)
  },
  
  // LIVE GAME - Second Half
  secondHalf: {
    scores: 30,          // 30 seconds
    stats: 60,           // 1 min
    playByPlay: 30,      // 30 seconds
  },
  
  // CLUTCH TIME (Last 5 minutes, score within 10)
  clutchTime: {
    scores: 15,          // 15 seconds (critical!)
    stats: 30,           // 30 seconds
    playByPlay: 15,      // 15 seconds
    odds: 30,            // 30 seconds (live betting)
  },
  
  // BLOWOUT (20+ point difference)
  blowout: {
    scores: 120,         // 2 min (less interest)
    stats: 300,          // 5 min
    playByPlay: 180,     // 3 min
  },
  
  // POST-GAME
  postGame: {
    finalStats: 3600,    // 1 hour (static)
    news: 300,           // 5 min (reactions)
    social: 180,         // 3 min (hot takes)
  }
};
```

---

## 🔄 Sport Comparison & TTL Strategy

| Sport | Score Frequency | Total Scores | Game Duration | Live Cache | Pre/Post Cache |
|-------|----------------|--------------|---------------|------------|----------------|
| **Basketball** | Every 30s | 200-240 pts | 2.5 hrs | 30s-1min | 5-15min |
| **Football** | Every 10min | 40-60 pts | 3 hrs | 2-3min | 10-30min |
| **Baseball** | Every 20min | 8-12 runs | 3 hrs | 3-5min | 15-30min |
| **Hockey** | Every 20min | 4-6 goals | 2.5 hrs | 3-5min | 10-20min |
| **Soccer** | Every 30min | 2-4 goals | 2 hrs | 5-10min | 15-30min |
| **Tennis** | Every 1-2min | 50+ games | 2-4 hrs | 1-2min | 10-20min |

---

## 🏗️ Implementation Strategy

### Phase 1: Basic Firestore Caching (Week 1)
```
firestore/
├── edge_cache/
│   ├── games/
│   │   ├── {gameId}/
│   │   │   ├── scores (TTL: dynamic)
│   │   │   ├── stats (TTL: dynamic)
│   │   │   ├── news (TTL: 30 min)
│   │   │   └── social (TTL: 10 min)
│   ├── global/
│   │   ├── todays_games (TTL: 5 min)
│   │   ├── standings (TTL: 1 hour)
│   │   └── trending (TTL: 15 min)
```

### Phase 2: Cloud Functions Proxy (Week 2)
- Move API calls to server-side
- Centralized rate limiting
- Hide API keys from client
- Batch processing for efficiency

### Phase 3: Scheduled Updates (Week 3)
- Pre-fetch popular games
- Automated score updates during games
- Scheduled news refreshes
- Predictive caching

### Phase 4: Advanced Features (Week 4)
- User preference-based caching
- Regional optimization
- Machine learning for cache prediction
- Cost optimization algorithms

---

## 💡 Smart Detection Logic

```javascript
function getBasketballCacheTTL(gameState) {
  // Clutch time detection
  if (game.period === 4 && game.timeRemaining < 300) {
    if (Math.abs(game.homeScore - game.awayScore) <= 10) {
      return BasketballCacheTTL.clutchTime; // High frequency!
    }
  }
  
  // Blowout detection
  if (Math.abs(game.homeScore - game.awayScore) > 20) {
    return BasketballCacheTTL.blowout; // Lower frequency
  }
  
  // Halftime
  if (game.status === 'Halftime') {
    return BasketballCacheTTL.halftime;
  }
  
  // Regular game phases
  if (game.status === 'Pre-Game') {
    return BasketballCacheTTL.preGame;
  } else if (game.status === 'Final') {
    return BasketballCacheTTL.postGame;
  } else if (game.period <= 2) {
    return BasketballCacheTTL.firstHalf;
  } else {
    return BasketballCacheTTL.secondHalf;
  }
}
```

---

## 📈 Cost-Benefit Analysis

### Without Caching (Current):
- **Users**: 1,000
- **API calls/user/day**: 10
- **Total API calls**: 10,000/day
- **Result**: Rate limits exceeded, service degraded

### With Caching (Proposed):
- **Unique data requests**: 10-20/day
- **API calls needed**: 10-20/day
- **Cache hits**: 99.9%
- **Result**: 99.9% reduction in API usage

### Projected Savings:
- **API Calls**: -99.9%
- **Latency**: -80% (cached data)
- **Costs**: Stay within free tiers
- **Scalability**: Support 10,000+ users

---

## 🎯 Implementation Checklist

### Week 1: Basketball Caching
- [ ] Implement dynamic TTL system for basketball
- [ ] Add Firestore cache layer
- [ ] Create cache check before API calls
- [ ] Implement game state detection
- [ ] Add clutch time detection
- [ ] Test with live NBA games

### Week 2: Cloud Functions
- [ ] Create getGameIntelligence function
- [ ] Implement server-side caching
- [ ] Add batch game updates
- [ ] Set up rate limiting
- [ ] Hide API keys server-side

### Week 3: Automation
- [ ] Schedule pre-game caching
- [ ] Implement live game tracking
- [ ] Add post-game cleanup
- [ ] Create cache warming strategy

### Week 4: Optimization
- [ ] Add cache analytics
- [ ] Implement predictive caching
- [ ] Optimize TTL values based on usage
- [ ] Add fallback strategies

---

## 📊 Success Metrics

### Target Performance:
- **Cache Hit Rate**: > 95%
- **API Usage**: < 100 calls/day
- **Response Time**: < 100ms (cached)
- **User Capacity**: 10,000+ concurrent
- **Cost**: $0 (stay in free tiers)

### Monitoring:
- Cache hit/miss ratios
- API quota usage
- Response times
- User experience metrics
- Cost tracking

---

## 🚨 Fallback Strategies

1. **API Limit Reached**: Serve stale cache with warning
2. **Cache Miss**: Queue request, serve when available
3. **API Down**: Use backup API or last known data
4. **Firestore Limit**: Implement local caching
5. **Network Issues**: Offline mode with cached data

---

## 📝 Notes

- Basketball requires most frequent updates during games
- Clutch time needs near real-time data (15s cache)
- Blowouts can use longer cache times (2-5min)
- Pre/post game data is less time-sensitive
- Social sentiment peaks during key moments

---

*Last Updated: 2025-08-27*
*Version: 1.0*