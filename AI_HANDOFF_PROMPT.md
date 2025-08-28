# AI Handoff Prompt - Bragging Rights Edge Feature

## Project Context
You are continuing development on the "Bragging Rights" sports betting app, specifically the Edge feature which provides premium betting intelligence. The backend API integrations and caching system are complete. The next critical task is connecting the UI to display real data.

## Current State (as of 2025-08-27)

### ✅ Completed Components:
1. **API Gateway** (`lib/services/edge/api_gateway.dart`)
   - Rate limiting, retry logic, caching layers
   - Configured with API keys:
     - NewsAPI: `3386d47aa3fe4a7f8375643727fa5afe`
     - Balldontlie: `978b1ba9-9847-40cc-93d1-abca911cf822`

2. **NBA API Integrations**
   - ESPN NBA API (free, no limits) - `sports/espn_nba_service.dart`
   - Balldontlie API (5 req/min) - `sports/balldontlie_service.dart`
   - NewsAPI (100 req/day) - `news/news_api_service.dart`
   - Reddit API (no auth) - `social/reddit_service.dart`

3. **Caching System** (`cache/edge_cache_service.dart`)
   - Multi-user data sharing via Firestore
   - Dynamic TTL based on game state:
     - Clutch time: 15 seconds
     - Regular game: 30 seconds
     - Blowout: 2 minutes
     - Pre/Post game: 5-60 minutes

4. **Event Matcher** (`event_matcher.dart`)
   - Normalizes team names across APIs
   - Fuzzy matching for events

### ❌ Pending Tasks (YOUR PRIORITIES):

## Task 1: Connect Edge UI to Real Data
**File:** `lib/screens/premium/edge_screen.dart`

Currently shows mock data with hardcoded "Lakers vs Celtics". Need to:
1. Import the Edge services
2. Fetch real game data using `EdgeIntelligenceService`
3. Display dynamic cards with:
   - Live scores (from ESPN/Balldontlie)
   - Breaking news (from NewsAPI)
   - Reddit sentiment (from Reddit API)
   - Injury reports (extracted from news)
   - Betting insights (from existing Odds API)

### Implementation Steps:
```dart
// In edge_screen.dart, replace mock data with:
import 'package:bragging_rights_app/services/edge/edge_intelligence_service.dart';

// Fetch real intelligence
final intelligence = await EdgeIntelligenceService().getEventIntelligence(
  eventId: gameId,
  sport: 'nba',
  homeTeam: homeTeam,
  awayTeam: awayTeam,
  eventDate: gameDate,
);

// Display in cards
EdgeCard(
  title: 'Live Score',
  data: intelligence.dataPoints['scores'],
  confidence: intelligence.overallConfidence,
)
```

## Task 2: Test with Live NBA Games
1. Run the app during an NBA game (check ESPN for schedule)
2. Verify:
   - Cache hit rates (should be >95%)
   - Clutch time detection (last 5 min, close game)
   - API quotas not exceeded
   - Real-time score updates

## Task 3: Add Other Sports Support
Extend beyond NBA to NFL, MLB, NHL:

### NFL Implementation:
```dart
// Create lib/services/edge/sports/nfl_service.dart
// Use ESPN NFL endpoint: /football/nfl/scoreboard
// Cache TTL: 2-3 minutes (slower scoring)
```

### MLB Implementation:
```dart
// Create lib/services/edge/sports/mlb_service.dart
// Use ESPN MLB endpoint: /baseball/mlb/scoreboard
// Cache TTL: 3-5 minutes
```

## Task 4: Create Edge Cards UI Components
Design intelligence cards that show:
- Confidence indicators (high/medium/low)
- Data freshness (last updated X seconds ago)
- Source attribution (ESPN, NewsAPI, Reddit)
- Trend arrows (momentum shifts)

## Technical Notes:

### API Rate Limits to Remember:
- Balldontlie: 5 requests/minute (FREE tier)
- NewsAPI: 100 requests/day
- Reddit: 60 requests/minute (no auth)
- ESPN: No documented limits

### Caching is Critical:
- All API calls MUST go through `EdgeCacheService`
- One API call serves ALL users (Firestore shared cache)
- Check cache before any API call

### Testing Endpoints:
```bash
# Test ESPN NBA
curl "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard"

# Test NewsAPI
curl "https://newsapi.org/v2/everything?q=NBA&apiKey=3386d47aa3fe4a7f8375643727fa5afe"

# Test Reddit
curl -H "User-Agent: BraggingRights" "https://www.reddit.com/r/nba/hot.json"
```

### Key Files Structure:
```
lib/services/edge/
├── api_gateway.dart           # Core API management
├── event_matcher.dart          # Event normalization
├── edge_intelligence_service.dart  # Main aggregator
├── cache/
│   └── edge_cache_service.dart    # Caching system
├── sports/
│   ├── espn_nba_service.dart      # ESPN NBA
│   ├── balldontlie_service.dart   # Balldontlie
│   └── [TODO: nfl, mlb, nhl services]
├── news/
│   └── news_api_service.dart      # NewsAPI
└── social/
    └── reddit_service.dart         # Reddit

lib/screens/premium/
└── edge_screen.dart            # [TODO: Connect to real data]
```

### Environment:
- Platform: Windows (MSYS_NT)
- Flutter: Latest stable
- Firebase: Configured and deployed
- Git repo: https://github.com/smythmyke/bragging_rights

### Success Criteria:
1. Edge screen shows real NBA game data
2. Cache hit rate >95%
3. API usage stays within free tiers
4. Live scores update every 30 seconds during games
5. News and social sentiment refresh appropriately

### Recent Commits for Context:
- Implemented Edge API Gateway infrastructure
- Added NBA API integrations (ESPN, Balldontlie)
- Created multi-user caching with dynamic TTL
- Integrated NewsAPI and Reddit for intelligence

## Questions You Should Ask:
1. Are there any live NBA games today to test with?
2. Should the UI show confidence scores for each data point?
3. What's the priority order for other sports (NFL/MLB/NHL)?
4. Should Edge be a premium feature or available to all users?

## Your First Commands:
```bash
# Check current branch and status
git status

# Review the Edge screen that needs updating
cat lib/screens/premium/edge_screen.dart

# Test the current API integrations
curl "https://site.api.espn.com/apis/site/v2/sports/basketball/nba/scoreboard"

# Run the app
flutter run
```

## Documentation to Review:
- `MASTER_CHECKLIST.md` - Overall progress (Edge is 60% complete)
- `EDGE_API_BUILD_PLAN.md` - Detailed implementation plan
- `EDGE_DATA_CACHING_STRATEGY.md` - Caching architecture
- `EDGE_FREE_APIS_IMPLEMENTATION.md` - Available APIs list

---

*Note: The user has been very clear about wanting to see REAL data, not mock data. The Edge feature should provide genuine betting intelligence using the integrated APIs. Focus on making the UI functional with live data before adding more sports or features.*