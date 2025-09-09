# API Optimization Plan - Bragging Rights App

## Overview
Optimize API usage to reduce costs while maintaining core functionality for betting, live scores, and edge intelligence features.

## Current State
- **Problem**: Running on free tier (500 requests/month) of The Odds API - insufficient for user base
- **ESPN API**: Free but no odds data
- **Cost Issue**: Live play-by-play APIs cost $200+/month

## Target Architecture

### Core API Stack
1. **ESPN API (Free)**
   - Game schedules
   - Live scores (updated every 2-5 minutes)
   - Final results
   - Basic team/player data
   - Embedded injury reports
   - Venue information

2. **The Odds API ($30-59/month)**
   - Pre-game betting lines only
   - Moneyline, spread, totals
   - Plan: Start with 20K tier ($30), upgrade to 100K ($59) as needed

3. **OpenWeatherMap API (Free tier)**
   - Weather data for outdoor venues
   - 60 calls/minute free tier
   - For Edge Intel cards

### Data Flow Strategy

#### Pre-Game (T-24 hours)
1. Fetch game schedule from ESPN
2. Get odds from The Odds API
3. Cache for 30-60 minutes
4. Fetch weather for outdoor games
5. Generate Edge Intel cards

#### During Game
1. Poll ESPN every 2-5 minutes for score updates
2. Update game status in Firestore
3. No odds updates (pre-game only)
4. No play-by-play tracking

#### Post-Game
1. Fetch final score from ESPN
2. Trigger bet settlement
3. Update user wallets
4. Clear game cache

## Implementation Tasks

### Phase 1: Fix Odds Integration (Today)
- [ ] Update The Odds API key from .env file
- [ ] Enable odds fetching in GameOddsEnrichmentService
- [ ] Fix hardcoded API key in odds_api_service.dart
- [ ] Test odds display on betting screen

### Phase 2: Optimize Caching
- [ ] Increase cache duration to 30 minutes for odds
- [ ] Implement shared cache across users in Cloud Functions
- [ ] Add cache headers to reduce redundant calls

### Phase 3: ESPN Live Scores
- [ ] Create background service for score updates
- [ ] Poll ESPN every 2-5 minutes during games
- [ ] Update Firestore with latest scores
- [ ] Trigger settlement when game status = "final"

### Phase 4: Edge Intel Cards
- [ ] Parse injury data from ESPN responses
- [ ] Integrate OpenWeatherMap for weather
- [ ] Cache intel data for 24 hours
- [ ] Display in bet selection screen

## Cost Analysis

### Monthly Costs
- **The Odds API**: $30-59
- **ESPN API**: $0
- **OpenWeatherMap**: $0
- **Total**: $30-59/month

### API Call Budget (100K tier)
- **Odds requests**: 60,000/month (60%)
- **Reserve**: 40,000/month (40%)
- **Supports**: ~5,000-8,000 users

## Caching Strategy

### Cache Durations
- **Odds**: 30 minutes (was 5)
- **Game schedules**: 1 hour
- **Live scores**: 2 minutes
- **Edge Intel**: 24 hours
- **Weather**: 1 hour

### Cache Locations
1. **Cloud Functions**: Shared cache for all users
2. **Firestore**: Persistent cache with TTL
3. **App Memory**: Local cache for current session

## Code Changes Required

### 1. Fix The Odds API Key
```dart
// File: lib/services/odds_api_service.dart
// Change from:
static const String _apiKey = '3386d47aa3fe4a7f';
// To:
static String _apiKey = dotenv.env['ODDS_API_KEY'] ?? '';
```

### 2. Enable Odds Fetching
```dart
// File: lib/services/game_odds_enrichment_service.dart
// Uncomment lines 114-126 to re-enable The Odds API
```

### 3. Update Cache Duration
```dart
// File: functions/sports-api-proxy.js
const CACHE_DURATIONS = {
  odds: 1800,      // 30 minutes (was 300)
  games: 300,      // 5 minutes
  news: 3600,      // 1 hour
  stats: 86400,    // 24 hours
};
```

### 4. ESPN Score Polling
```dart
// New file: lib/services/live_score_service.dart
class LiveScoreService {
  Timer? _pollTimer;
  
  void startPolling(String gameId) {
    _pollTimer = Timer.periodic(Duration(minutes: 2), (_) {
      _updateScoreFromEspn(gameId);
    });
  }
}
```

## Monitoring & Alerts

### Track Usage
- Log API calls per endpoint
- Monitor quota remaining
- Alert at 80% usage
- Fallback to cached data when quota exceeded

### Performance Metrics
- Cache hit rate target: 80%
- API response time: <2 seconds
- Settlement accuracy: 100%
- User experience: Bet options always visible

## Rollback Plan
If issues arise:
1. Disable odds enrichment temporarily
2. Use cached/stale data
3. Show "Odds temporarily unavailable"
4. Maintain core betting on cached odds

## Success Criteria
- ✅ Betting options display properly
- ✅ Live scores update during games
- ✅ Bets settle correctly at game end
- ✅ Monthly API costs under $60
- ✅ Support 5,000+ active users

## Timeline
- **Day 1**: Fix odds integration, test betting screen
- **Day 2**: Implement caching improvements
- **Day 3**: Set up live score polling
- **Day 4**: Add Edge Intel cards
- **Day 5**: Testing and monitoring setup

---

**Last Updated**: September 9, 2025
**Status**: In Progress
**Next Step**: Fix The Odds API integration