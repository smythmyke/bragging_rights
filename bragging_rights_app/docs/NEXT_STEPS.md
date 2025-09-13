# Next Steps - Bragging Rights Development

## Immediate Tasks (This Week)

### 1. Complete Quick Pick Integration
- [ ] Add mode selection dialog to pool entry flow
- [ ] Wire up navigation between modes
- [ ] Test ESPN fighter ID mapping and image URLs
- [ ] Add fallback images for missing fighter photos
- [ ] Implement error handling for failed image loads

### 2. Fix MMA/Boxing Event Display
- [x] Group individual fights into events (COMPLETED)
- [ ] Test event grouping with live data
- [ ] Ensure event names display correctly
- [ ] Verify fight counts are accurate
- [ ] Add event poster support when available

### 3. Database Indexes
- [ ] Create Firestore indexes for the failed queries seen in logs:
  - `games` where `sport==MMA` and `cacheTimestamp>X`
  - `games` where `sport==BOXING` and `cacheTimestamp>X`
  - Follow Firebase console links in error messages

## Short Term (Next 2 Weeks)

### 1. Fighter Data Enhancement
- [ ] Set up cron job to update fighter records after events
- [ ] Add fighter country flags from additional API
- [ ] Implement fighter comparison overlay
- [ ] Cache event posters from promotion websites
- [ ] Add win streak indicators

### 2. Quick Pick Enhancements
- [ ] Add confidence levels (swipe up/down gestures)
- [ ] Implement "shake to random pick" feature
- [ ] Add quick stats tooltip on long press
- [ ] Create onboarding for first-time users
- [ ] Add visual indicators for championship fights

### 3. Performance Optimization
- [ ] Implement image preloading for fight cards
- [ ] Add skeleton loaders during data fetch
- [ ] Optimize Firestore queries with proper indexes
- [ ] Reduce API calls with smarter caching
- [ ] Add offline support for cached data

## Medium Term (Next Month)

### 1. Analytics & Insights
- [ ] Track pick completion rates by mode
- [ ] Measure time-to-complete for each mode
- [ ] Monitor mode preference by user segment
- [ ] Track conversion from quick to detailed mode
- [ ] Add user feedback collection

### 2. Social Features
- [ ] Add pick sharing to social media
- [ ] Implement pick comparison with friends
- [ ] Create public/private pool options
- [ ] Add pool invitations system
- [ ] Build leaderboard visualizations

### 3. Enhanced Scoring
- [ ] Add bonus points for underdog picks
- [ ] Implement confidence multipliers
- [ ] Create achievement badges
- [ ] Add streak bonuses
- [ ] Build historical stats dashboard

## Long Term (Next Quarter)

### 1. Expand Sports Coverage
- [ ] Add Kickboxing support
- [ ] Integrate Muay Thai events
- [ ] Add Wrestling (WWE/AEW) events
- [ ] Support for regional MMA promotions
- [ ] Add bare knuckle boxing variations

### 2. Premium Features
- [ ] Expert picks comparison
- [ ] Advanced analytics dashboard
- [ ] Custom pool scoring rules
- [ ] Private league management
- [ ] Ad-free experience

### 3. Platform Expansion
- [ ] Web app development
- [ ] iOS optimization
- [ ] Tablet-optimized layouts
- [ ] Apple Watch companion app
- [ ] Widget support for live scores

## Technical Debt

### High Priority
- [ ] Fix network error handling (seen in logs)
- [ ] Resolve Firestore index warnings
- [ ] Update deprecated packages
- [ ] Fix memory leaks in image caching
- [ ] Improve error messages for users

### Medium Priority
- [ ] Refactor API service architecture
- [ ] Consolidate duplicate code
- [ ] Add comprehensive unit tests
- [ ] Implement integration tests
- [ ] Document API contracts

### Low Priority
- [ ] Migrate to null safety completely
- [ ] Update to latest Material 3 design
- [ ] Optimize bundle size
- [ ] Add code coverage reporting
- [ ] Set up automated deployments

## Known Issues to Fix

### From Recent Logs
1. **Network Errors**: `Failed host lookup: 'api.the-odds-api.com'`
   - Add retry logic with exponential backoff
   - Implement offline queue for submissions
   - Show user-friendly error messages

2. **Firestore Index Errors**: Multiple missing indexes
   - Create required composite indexes
   - Optimize query patterns
   - Add query result caching

3. **Image Loading**: Fighter photos returning 404
   - Implement fallback image strategy
   - Add placeholder avatars by weight class
   - Cache successful image URLs

## Testing Requirements

### Before Next Release
- [ ] Test Quick Pick flow end-to-end
- [ ] Verify event grouping for all combat sports
- [ ] Load test with 100+ concurrent users
- [ ] Test offline mode functionality
- [ ] Verify push notifications work

### Continuous Testing
- [ ] Daily smoke tests on production
- [ ] Weekly regression testing
- [ ] Performance monitoring
- [ ] User feedback monitoring
- [ ] Crash reporting analysis

## Success Metrics to Track

### User Engagement
- Daily/Monthly Active Users
- Pick completion rates
- Time spent in app
- Return user rate
- Pool participation rate

### Feature Adoption
- Quick Pick vs Detailed Pick usage
- Feature discovery rate
- Mode switching patterns
- Social sharing frequency
- Premium conversion rate

### Technical Health
- API response times
- App crash rate
- Image load success rate
- Offline functionality usage
- Cache hit rates

## Development Process Improvements

### Immediate
- [ ] Set up staging environment
- [ ] Implement feature flags
- [ ] Add remote config support
- [ ] Create rollback procedures
- [ ] Document deployment process

### Future
- [ ] Automated testing pipeline
- [ ] Continuous deployment
- [ ] A/B testing framework
- [ ] Performance monitoring
- [ ] User behavior analytics

## Questions to Resolve

1. **Fighter IDs**: How do we map Odds API fighter IDs to ESPN IDs?
2. **Event Posters**: Where can we source official event poster images?
3. **Scoring Rules**: Should quick picks have different scoring than detailed?
4. **Caching Strategy**: How long should we cache fight results?
5. **Push Notifications**: When should we notify users about picks/results?

## Resource Requirements

### Development
- Additional developer for web app
- UI/UX designer for new features
- QA tester for regression testing

### Infrastructure
- Increased Firestore quota
- CDN for image delivery
- Analytics platform subscription
- Crash reporting service
- Performance monitoring tools

### External Services
- Premium ESPN API access
- Fighter image database
- Event poster API
- Country flag API
- Social media integration

---

*Last Updated: January 2025*
*Next Review: February 2025*