# Bragging Rights - API Integration Plan
## Starter Stack Implementation Guide

---

## 📋 Executive Summary

This document outlines the API integration strategy for Bragging Rights, using a cost-effective starter stack that can scale with user growth. The plan prioritizes free/low-cost solutions while maintaining reliability through failover systems.

---

## 🎯 Selected Starter Stack

### Primary APIs
```javascript
const STARTER_STACK = {
  liveScores: 'ESPN API (unofficial)', // FREE
  teamLogos: 'TheSportsDB',           // FREE (non-commercial)
  odds: 'The Odds API',                // $99/mo after free tier
  backup: 'RapidAPI collection'        // Pay as you go
};
```

### Monthly Cost Breakdown
- **ESPN API**: $0 (unofficial/free)
- **TheSportsDB**: $0 (free tier) / $10 (Patreon support)
- **The Odds API**: $0 (first 500 requests) then $99/month
- **Total**: ~$99/month at scale

---

## 🔧 Current Implementation Status

### ✅ Already Integrated
1. **ESPN API** - Live scores and schedules
2. **TheSportsDB** - Team logos and basic data
3. **Failover System** - Automatic fallback between providers
4. **Caching System** - Multi-level caching for efficiency

### ⏳ Pending Integration
1. **The Odds API** - Betting lines and odds (needs API key)

---

## 📝 Implementation Steps

### Step 1: Get The Odds API Key (Immediate)
```bash
# 1. Sign up at https://the-odds-api.com
# 2. Get your free API key (500 requests/month)
# 3. Test the API
curl "https://api.the-odds-api.com/v4/sports/?apiKey=YOUR_KEY"
```

### Step 2: Configure Environment Variables
```bash
# In Firebase Functions config
firebase functions:config:set \
  odds_api.key="YOUR_ODDS_API_KEY" \
  odds_api.tier="free"

# Deploy the config
firebase deploy --only functions
```

### Step 3: Update Cloud Functions
```javascript
// functions/sportsData.js - Already implemented, just needs key
const API_CONFIG = {
  ODDS_API: {
    base_url: 'https://api.the-odds-api.com/v4',
    key: functions.config().odds_api?.key || process.env.ODDS_API_KEY
  }
};
```

### Step 4: Implement Smart Quota Management
```javascript
// Track API usage in Firestore
const quotaManager = {
  async canMakeRequest(apiName) {
    const doc = await db.collection('api_quotas').doc(apiName).get();
    const data = doc.data();
    
    if (!data) return true;
    
    const { used, limit, resetDate } = data;
    
    if (new Date() > resetDate) {
      // Reset quota
      await doc.ref.update({ used: 0, resetDate: getNextResetDate() });
      return true;
    }
    
    return used < limit;
  },
  
  async incrementUsage(apiName) {
    await db.collection('api_quotas').doc(apiName).update({
      used: FieldValue.increment(1),
      lastUsed: FieldValue.serverTimestamp()
    });
  }
};
```

### Step 5: Set Up Monitoring
```javascript
// Monitor API health and costs
exports.monitorAPIs = functions.pubsub
  .schedule('0 0 * * *') // Daily
  .onRun(async () => {
    const apis = ['espn', 'sportsdb', 'odds_api'];
    
    for (const api of apis) {
      const health = await checkAPIHealth(api);
      const usage = await getAPIUsage(api);
      
      if (usage.percentage > 80) {
        // Send alert - approaching quota limit
        await sendAdminNotification({
          type: 'quota_warning',
          api: api,
          usage: usage
        });
      }
    }
  });
```

---

## 📊 API Usage Optimization

### Caching Strategy
```javascript
const CACHE_DURATIONS = {
  // Static data - cache aggressively
  teamLogos: 30 * 24 * 60 * 60 * 1000,  // 30 days
  teamInfo: 7 * 24 * 60 * 60 * 1000,    // 7 days
  
  // Semi-dynamic data
  schedules: 24 * 60 * 60 * 1000,       // 24 hours
  standings: 6 * 60 * 60 * 1000,        // 6 hours
  
  // Dynamic data - cache briefly
  odds: 5 * 60 * 1000,                  // 5 minutes
  liveScores: 30 * 1000,                // 30 seconds during game
  
  // User-specific
  userBets: 60 * 1000,                  // 1 minute
};
```

### Request Prioritization
```javascript
const REQUEST_PRIORITY = {
  CRITICAL: 1,   // Live game user is betting on
  HIGH: 2,       // Upcoming games with active bets
  MEDIUM: 3,     // Popular games without user bets
  LOW: 4,        // Historical data, standings
  BATCH: 5       // Can wait for scheduled update
};

// Only make immediate requests for CRITICAL and HIGH
if (priority <= REQUEST_PRIORITY.HIGH) {
  return await fetchLiveData();
} else {
  return await getCachedOrSchedule();
}
```

---

## 💰 Cost Management

### Free Tier Maximization
```javascript
const FREE_TIER_LIMITS = {
  THE_ODDS_API: {
    monthly: 500,
    daily: Math.floor(500 / 30), // ~16 per day
    strategy: 'Use only for games with active bets'
  },
  API_SPORTS: {
    daily: 100,
    strategy: 'Reserve for failover only'
  }
};
```

### Progressive Enhancement
```javascript
// Scale API usage with revenue
const API_SCALING = {
  users_0_100: {
    odds_refresh: '30 minutes',
    live_scores: 'ESPN only',
    cost: '$0/month'
  },
  users_100_1000: {
    odds_refresh: '5 minutes',
    live_scores: 'ESPN + backup',
    cost: '$99/month'
  },
  users_1000_5000: {
    odds_refresh: '1 minute',
    live_scores: 'Multi-source',
    cost: '$299/month'
  }
};
```

---

## 🚨 Failover Strategy

### Provider Priority Chain
```javascript
const PROVIDER_CHAIN = {
  scores: [
    { name: 'ESPN', weight: 0.8, free: true },
    { name: 'TheSportsDB', weight: 0.15, free: true },
    { name: 'Cached', weight: 0.05, free: true }
  ],
  odds: [
    { name: 'TheOddsAPI', weight: 0.7, free: false },
    { name: 'Cached', weight: 0.25, free: true },
    { name: 'Manual', weight: 0.05, free: true }
  ],
  logos: [
    { name: 'CachedLocal', weight: 0.6, free: true },
    { name: 'TheSportsDB', weight: 0.3, free: true },
    { name: 'ESPN', weight: 0.1, free: true }
  ]
};
```

### Error Handling
```javascript
async function fetchWithFallback(dataType, params) {
  const providers = PROVIDER_CHAIN[dataType];
  
  for (const provider of providers) {
    try {
      if (!provider.free && !await quotaManager.canMakeRequest(provider.name)) {
        continue; // Skip if quota exceeded
      }
      
      const data = await fetchFromProvider(provider.name, params);
      
      if (data) {
        if (!provider.free) {
          await quotaManager.incrementUsage(provider.name);
        }
        return data;
      }
    } catch (error) {
      console.error(`${provider.name} failed:`, error);
      // Continue to next provider
    }
  }
  
  // All providers failed
  throw new Error(`All providers failed for ${dataType}`);
}
```

---

## 📈 Scaling Roadmap

### Phase 1: MVP (Current)
- ✅ ESPN free API
- ✅ TheSportsDB free tier
- ⏳ The Odds API free tier
- **Cost**: $0/month

### Phase 2: Early Growth (100-1000 users)
- The Odds API paid tier ($99/mo)
- TheSportsDB Patreon ($10/mo)
- Add RapidAPI backup ($20/mo)
- **Cost**: ~$130/month

### Phase 3: Growth (1000-5000 users)
- SportsDataIO for 2 sports ($400/mo)
- The Odds API premium ($299/mo)
- Keep free APIs as backup
- **Cost**: ~$700/month

### Phase 4: Scale (5000+ users)
- Sportradar enterprise
- Multiple redundant providers
- Direct data partnerships
- **Cost**: $3000+/month

---

## 🔐 Security Considerations

### API Key Management
```javascript
// NEVER commit API keys to code
// Use environment variables or Firebase config

// Bad ❌
const API_KEY = 'abc123xyz';

// Good ✅
const API_KEY = functions.config().odds_api.key;
```

### Rate Limiting
```javascript
// Implement per-user rate limits
const userRateLimit = {
  odds_requests: {
    per_minute: 10,
    per_hour: 100,
    per_day: 500
  }
};
```

---

## 📋 Action Items

### Immediate (Today)
1. [ ] Sign up for The Odds API
2. [ ] Get API key and test endpoints
3. [ ] Configure Firebase environment variables
4. [ ] Deploy updated Cloud Functions

### This Week
1. [ ] Implement quota tracking
2. [ ] Set up monitoring alerts
3. [ ] Test failover scenarios
4. [ ] Create admin dashboard for API stats

### This Month
1. [ ] Analyze usage patterns
2. [ ] Optimize caching strategy
3. [ ] Plan for paid tier upgrade
4. [ ] Research additional providers

---

## 🎯 Success Metrics

### Technical KPIs
- API uptime: >99.5%
- Average response time: <500ms
- Cache hit rate: >70%
- Failover success rate: >95%

### Business KPIs
- API cost per user: <$0.10/month
- Data freshness: <5 minutes for odds
- User satisfaction: >4.5 stars
- Betting accuracy: >95%

---

## 📚 Resources

### API Documentation
- [ESPN API (Unofficial)](https://gist.github.com/akeaswaran/b48b02f1c94f873c6655e7129910fc3b)
- [TheSportsDB API](https://www.thesportsdb.com/api.php)
- [The Odds API](https://the-odds-api.com/docs/)
- [RapidAPI Sports](https://rapidapi.com/collection/sports-apis)

### Monitoring Tools
- Firebase Console: Performance & Crashes
- Google Cloud Monitoring: API metrics
- Custom Dashboard: Usage & costs

---

## 🆘 Troubleshooting

### Common Issues

#### Issue: Quota Exceeded
```javascript
// Solution: Implement smart caching
if (error.code === 'QUOTA_EXCEEDED') {
  return await getCachedData() || getDefaultOdds();
}
```

#### Issue: API Timeout
```javascript
// Solution: Reduce timeout and failover quickly
const fetchWithTimeout = (url, timeout = 3000) => {
  return Promise.race([
    fetch(url),
    new Promise((_, reject) => 
      setTimeout(() => reject(new Error('Timeout')), timeout)
    )
  ]);
};
```

#### Issue: Stale Data
```javascript
// Solution: Implement smart cache invalidation
const shouldRefresh = (cached) => {
  const age = Date.now() - cached.timestamp;
  const maxAge = CACHE_DURATIONS[cached.type];
  return age > maxAge || cached.isLiveGame;
};
```

---

*Last Updated: August 26, 2025*
*Next Review: September 1, 2025*