# Bragging Rights - Master Implementation Plan
*Created: September 27, 2025*
*Consolidates all outstanding tasks from previous plans*

## Overview
This master plan consolidates all critical unfinished tasks from:
- API_OPTIMIZATION_PLAN.md
- BUILD_TODO.md
- CACHING_STRATEGY_PLAN.md
- BASEBALL_DETAILS_INTEGRATION_PLAN.md
- bet_indicator_implementation_plan.md
- Combat sports plans (MMA/Boxing enhancements)

## Priority System
- 🚨 **CRITICAL**: Production blockers, must complete
- ⚠️ **HIGH**: Performance/cost issues, strongly recommended
- 📊 **MEDIUM**: Feature completion, user experience
- 💡 **LOW**: Nice-to-have enhancements

---

# Phase 1: Infrastructure & Performance (Week 1)
**Goal:** Reduce API costs by 97% and fix performance issues

## API Optimization & Caching Strategy 🚨

### API Audit & Documentation
- [ ] Document all ESPN API endpoints currently in use
  - [ ] NFL endpoints and frequency
  - [ ] NBA endpoints and frequency
  - [ ] MLB endpoints and frequency
  - [ ] NHL endpoints and frequency
  - [ ] MMA/Boxing endpoints and frequency
- [ ] Calculate current API call volume and costs
- [ ] Identify redundant/duplicate API calls
- [ ] Map data flow from API → Firestore → App

### Implement Firestore-First Caching
- [ ] Add timestamp fields to Firestore game documents
  ```
  - lastUpdated: Timestamp
  - dataExpiry: Timestamp
  - updateFrequency: String (live/pregame/final)
  ```
- [ ] Modify OptimizedGamesService to check Firestore first
  - [ ] Implement `isDataFresh()` method with sport-specific TTLs
  - [ ] Add fallback to API only when data is stale
  - [ ] Implement retry logic with exponential backoff
- [ ] Create CacheService class
  ```dart
  - getCachedData()
  - shouldRefresh()
  - updateCache()
  - clearStaleData()
  ```

### Optimize API Call Patterns
- [ ] Implement batch fetching for multiple games
- [ ] Separate live score updates from full game data
- [ ] Add smart polling based on game state:
  - [ ] Pre-game: Every 30 minutes
  - [ ] Live: Every 2-5 minutes
  - [ ] Final: Once, then cache for 24 hours
- [ ] Implement circuit breaker for API failures
- [ ] Add rate limiting middleware

### Performance Monitoring
- [ ] Set up API call tracking in Firebase Analytics
- [ ] Create cost monitoring dashboard
- [ ] Add alerts for excessive API usage
- [ ] Implement performance metrics logging

---

# Phase 2: Production Essentials (Week 2)
**Goal:** Complete all production-critical features

## Payment System Implementation 🚨

### In-App Purchase Setup
- [ ] Configure products in App Store Connect
  - [ ] BR Coin packages (100, 500, 1000, 5000)
  - [ ] Subscription tiers if applicable
- [ ] Configure products in Google Play Console
  - [ ] Match iOS product IDs
  - [ ] Set up pricing tiers
- [ ] Implement purchase flow in app
  - [ ] Create PurchaseService class
  - [ ] Add purchase UI/modal
  - [ ] Implement receipt validation
  - [ ] Handle restore purchases
- [ ] Server-side receipt validation
  - [ ] Cloud Function for iOS receipt validation
  - [ ] Cloud Function for Android receipt validation
  - [ ] Update user wallet on successful validation
- [ ] Test sandbox purchases
  - [ ] iOS TestFlight testing
  - [ ] Android internal testing track

## Push Notifications 🚨

### Firebase Cloud Messaging Setup
- [ ] Configure FCM in Firebase Console
- [ ] Add iOS APNs certificates
- [ ] Implement notification service
  - [ ] Token registration on app launch
  - [ ] Handle notification permissions
  - [ ] Process foreground notifications
  - [ ] Handle background notifications
- [ ] Create notification templates
  - [ ] Bet settlement notifications
  - [ ] Game start reminders
  - [ ] Pool invitation notifications
  - [ ] Weekly allowance notifications
- [ ] Test notification delivery
  - [ ] iOS device testing
  - [ ] Android device testing
  - [ ] Handle token refresh

## Testing Suite ⚠️

### Unit Tests
- [ ] Service layer tests
  - [ ] OptimizedGamesService tests
  - [ ] MMAService tests
  - [ ] SettlementService tests
  - [ ] WalletService tests
- [ ] Model tests
  - [ ] Game model serialization
  - [ ] Bet model validation
  - [ ] User model tests
- [ ] Utility function tests

### Integration Tests
- [ ] API integration tests
- [ ] Firestore integration tests
- [ ] Authentication flow tests
- [ ] Purchase flow tests

### Widget Tests
- [ ] Game card widget tests
- [ ] Bet slip widget tests
- [ ] Pool creation flow tests
- [ ] Navigation tests

## Production Configuration 🚨

### Environment Setup
- [ ] Create production Firebase project
- [ ] Configure production API keys
- [ ] Set up production Cloud Functions
- [ ] Configure production Firestore rules
- [ ] Set up production storage rules

### Security
- [ ] Audit Firestore security rules
- [ ] Implement rate limiting on Cloud Functions
- [ ] Add request validation/sanitization
- [ ] Configure CORS policies
- [ ] Set up monitoring and alerts

### Error Handling
- [ ] Implement global error handler
- [ ] Add Crashlytics integration
- [ ] Create error reporting service
- [ ] Add user-friendly error messages
- [ ] Implement offline mode handling

---

# Phase 3: Feature Completion (Week 3)
**Goal:** Complete planned user-facing features

## Baseball Details Integration 📊

### UI Components
- [ ] Create BaseballDetailsScreen
- [ ] Implement PitchingMatchupCard widget
  - [ ] Starting pitcher stats
  - [ ] Bullpen strength indicators
  - [ ] Recent performance
- [ ] Create WeatherImpactCard widget
  - [ ] Wind speed/direction
  - [ ] Temperature
  - [ ] Precipitation chance
- [ ] Build TeamStatsComparison widget
  - [ ] Season statistics
  - [ ] Last 10 games form
  - [ ] Head-to-head history
- [ ] Implement 3-tab structure
  - [ ] Matchup tab
  - [ ] Box Score tab (live/final)
  - [ ] Stats tab

### Data Integration
- [ ] Connect ESPN MLB API endpoints
- [ ] Parse pitcher matchup data
- [ ] Fetch weather data
- [ ] Implement real-time updates for live games
- [ ] Add caching for baseball-specific data

## Bet Indicator System 📊

### Core Components
- [ ] Create BetPlacedRibbon widget
  ```dart
  - Show bet amount
  - Display potential payout
  - Indicate bet type (spread/ML/total)
  - Color coding by status
  ```
- [ ] Implement BetTrackingService
  - [ ] Local storage for active bets
  - [ ] Sync with Firestore
  - [ ] Real-time bet status updates
  - [ ] Bet history management

### Integration
- [ ] Update GameCard widgets
  - [ ] Add bet indicator overlay
  - [ ] Show multiple bets per game
  - [ ] Animate status changes
- [ ] Modify game list views
  - [ ] Filter by games with bets
  - [ ] Sort by bet status
  - [ ] Quick bet summary
- [ ] Add to pool views
  - [ ] Show pool participation indicator
  - [ ] Display current ranking

### User Experience
- [ ] Implement bet slip improvements
  - [ ] Show conflicts with existing bets
  - [ ] One-tap repeat bet
  - [ ] Bet modification flow
- [ ] Add bet analytics
  - [ ] Win/loss tracking
  - [ ] ROI calculation
  - [ ] Betting patterns

---

# Phase 4: Combat Sports Enhancements (Week 4+)
**Goal:** Refine and enhance MMA/Boxing features

## Settlement System Refinements 💡

### Monitoring Improvements
- [ ] Add backup data sources for fight results
- [ ] Implement result verification across multiple APIs
- [ ] Add manual override capability for admins
- [ ] Create settlement audit log UI

### Scoring Enhancements
- [ ] Fine-tune confidence multipliers
- [ ] Add bonus categories
  - [ ] Perfect card predictions
  - [ ] Underdog bonus
  - [ ] Early finish bonus
- [ ] Implement progressive scoring for tournaments

## UI/UX Polish 💡

### Fighter Cards
- [ ] Add fighter images from ESPN
- [ ] Implement record tooltips
- [ ] Add betting trends indicator
- [ ] Include reach/height comparisons

### Pool Creation
- [ ] Add custom scoring rules
- [ ] Implement private pool invitations
- [ ] Create pool templates
- [ ] Add pool chat functionality

### Statistics & Analytics
- [ ] Create fighter performance trends
- [ ] Add prediction accuracy tracking
- [ ] Implement leaderboards
- [ ] Build achievement system

---

# Phase 5: Advanced Features (Future)
**Goal:** Differentiate from competitors

## Peer-to-Peer Features 💡
- [ ] P2P betting implementation
- [ ] Custom bet creation
- [ ] Social betting groups
- [ ] Bet marketplace

## Tournament System 💡
- [ ] Multi-event tournaments
- [ ] Bracket competitions
- [ ] Season-long leagues
- [ ] Championship events

## Social Features 💡
- [ ] User profiles
- [ ] Follow system
- [ ] Betting feed
- [ ] Trash talk chat

## Advanced Analytics 💡
- [ ] ML-powered predictions
- [ ] Personalized insights
- [ ] Betting strategy recommendations
- [ ] Risk management tools

---

# Success Metrics

## Phase 1 Targets
- ✅ API costs reduced by >90%
- ✅ Page load times <2 seconds
- ✅ Cache hit rate >80%

## Phase 2 Targets
- ✅ Payment system processing transactions
- ✅ Push notifications delivering >95% success rate
- ✅ Test coverage >60%
- ✅ Zero critical security issues

## Phase 3 Targets
- ✅ Baseball details feature complete
- ✅ Bet indicators on all game cards
- ✅ User satisfaction score >4.0/5.0

## Phase 4 Targets
- ✅ Combat sports settlement accuracy >99%
- ✅ Settlement time <5 minutes after event
- ✅ User engagement +25%

---

# Cleanup Tasks
Once phases are complete:
- [ ] Archive old implementation plans
- [ ] Update documentation
- [ ] Remove deprecated code
- [ ] Optimize bundle size
- [ ] Performance audit

---

# Notes
- Priority should be Phase 1-2 for production readiness
- Phase 3 adds key differentiating features
- Phase 4+ can be rolled out post-launch
- Continuously monitor API costs and performance
- Gather user feedback after each phase

## Files to Archive After Completion
1. API_OPTIMIZATION_PLAN.md
2. BUILD_TODO.md
3. CACHING_STRATEGY_PLAN.md
4. BASEBALL_DETAILS_INTEGRATION_PLAN.md
5. bet_indicator_implementation_plan.md
6. NHL_DETAILS_IMPLEMENTATION_PLAN.md
7. COMBAT_SPORTS_UPDATE_PLAN.md
8. BOXING_DUAL_API_BUILD_PLAN.md
9. MMA_BETTING_UI_UPGRADE_PLAN.md
10. MMA_ESPN_ONLY_BUILD_PLAN.md
11. P2P_MMA_BUILD_PLAN.md
12. MMA_TOURNAMENT_BUILD_PLAN.md
13. MMA_FIGHTER_DETAILS_ENHANCEMENT.md
14. EDGE_CARDS_MASTER_GUIDE.md
15. COMBAT_SPORTS_DETAILS_BUILD.md