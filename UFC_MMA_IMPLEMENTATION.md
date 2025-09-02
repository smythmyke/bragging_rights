# UFC/MMA Fight Card Implementation

## Overview
Complete implementation of UFC/MMA fight card betting system with pool-based and head-to-head challenges.

## Implementation Date
January 2, 2025

## Key Features Implemented

### 1. Fight Card Event Model
- **File**: `lib/models/fight_card_model.dart`
- Complete fight card structure with multiple bouts
- Fight categorization (Main Event, Co-Main, Main Card, Prelims, Early Prelims)
- Fighter records and weight classes
- Title fight indicators

### 2. Pool-Based Fight Betting
- **Files**: 
  - `lib/models/fight_pool_rules.dart`
  - `lib/services/pool_auto_generator.dart`
- Auto-generation of Quick Play, Regional, and Tournament pools
- Flexible rules (skip prelims, late entries allowed)
- 100% prize pool distribution (no house fees)

### 3. Head-to-Head Challenge System
- **Files**:
  - `lib/models/head_to_head_model.dart`
  - `lib/services/head_to_head_service.dart`
- Three challenge types: Direct, Open, Auto-match
- Entry fee tiers: 10, 25, 50, 100, 250, 500 BR
- Winner-takes-all format
- Smart matchmaking based on event and requirements

### 4. Scoring System
- **File**: `lib/models/fight_card_scoring.dart`
- BR-only scoring (no dual point system)
- Base points for correct winner picks
- Underdog bonuses based on odds
- Method prediction bonus (+0.3 points)
- Round prediction bonus (+0.2 points)
- Confidence multiplier (0.8x to 1.3x based on 1-5 stars)

### 5. Odds Integration
- **File**: `lib/services/fight_odds_service.dart`
- Integration with The Odds API for real betting lines
- Fallback to estimated odds based on fighter records
- Support for multiple MMA organizations (UFC, Bellator, PFL, ONE)

### 6. UI Screens

#### Fight Card Screen
- **File**: `lib/screens/pools/fight_card_screen.dart`
- 2x1 mobile-first grid layout
- Color-coded fight categories
- Progress tracking for required picks
- Visual odds display
- Entry fee and prize pool information

#### Fight Pick Detail Screen
- **File**: `lib/screens/pools/fight_pick_detail_screen.dart`
- Fighter selection with records
- Method of victory selection
- Round prediction for finishes
- Confidence level system (1-5 stars)
- Bonus indicators

#### Head-to-Head Challenge Screen
- **File**: `lib/screens/pools/head_to_head_screen.dart`
- Three tabs: Create, Open Challenges, My Challenges
- Challenge type selection
- Entry fee selection
- Fight selection (full card or custom)

#### H2H Picks Screen
- **File**: `lib/screens/pools/h2h_picks_screen.dart`
- VS display showing matchup
- Progress tracking
- Detailed pick display
- Submit functionality

## Backend Services

### Fight Card Service
- **File**: `lib/services/fight_card_service.dart`
- Event retrieval and management
- Pick submission and validation
- Score calculation
- Pool result processing
- Leaderboard generation

### Head-to-Head Service
- **File**: `lib/services/head_to_head_service.dart`
- Challenge creation and acceptance
- Auto-matching algorithm
- Pick submission
- Result calculation
- User statistics tracking

## Database Structure

### Collections
- `events` - UFC/MMA events with fight arrays
- `pools` - Auto-generated betting pools
- `h2h_challenges` - Head-to-head challenges
- `h2h_picks` - User picks for H2H challenges
- `fight_picks` - User picks for pool betting
- `pool_entries` - User entries in pools
- `pool_results` - Completed pool results
- `h2h_results` - Completed H2H results

## Configuration

### Pool Auto-Generation
- Runs automatically when events are fetched
- Creates 4 Quick Play tiers (10, 25, 50, 100 BR)
- Creates 5 Regional pools (USA, CA, NY, TX, FL)
- Creates 3 Tournament tiers (Bronze, Silver, Gold)

### No House Fees
- 100% of entry fees go to prize pool
- Winner-takes-all for H2H
- Structured payouts for pools

## Testing Considerations

### Test Scenarios
1. Full card pick submission
2. Main card only picks
3. Skip prelims functionality
4. Late entry after event starts
5. H2H matchmaking with same requirements
6. Tie handling in H2H (pot split)
7. Score calculation with underdog bonuses

### Mock Data
- `MockFightOdds` class for testing without API
- `PoolSeeder` class for adding mock players

## Future Enhancements
1. Live fight updates during events
2. Fighter statistics and history
3. Parlay betting across multiple fights
4. Tournament brackets for elimination pools
5. Social features (trash talk, leaderboards)
6. Fighter image integration
7. Push notifications for challenge invites

## API Integration

### ESPN API
- No MMA odds available
- Event data only

### The Odds API
- Primary source for MMA betting lines
- Supports multiple bookmakers
- Real-time odds updates

### Supported MMA Organizations
- UFC (Ultimate Fighting Championship)
- Bellator MMA
- PFL (Professional Fighters League)  
- ONE Championship

## Key Design Decisions

1. **BR-Only System**: Simplified to use only Bragging Rights currency, no separate point system
2. **No House Fees**: 100% payout to maintain user engagement
3. **Mobile-First**: 2x1 grid optimized for phone screens
4. **Flexible Rules**: Pool-specific requirements for different user preferences
5. **Auto-Generation**: Prevents empty screens, ensures content availability

## Files Modified/Created

### New Files (12)
- `lib/models/fight_card_model.dart`
- `lib/models/fight_pool_rules.dart`
- `lib/models/fight_card_scoring.dart`
- `lib/models/head_to_head_model.dart`
- `lib/services/fight_odds_service.dart`
- `lib/services/pool_auto_generator.dart`
- `lib/services/head_to_head_service.dart`
- `lib/services/fight_card_service.dart`
- `lib/screens/pools/fight_card_screen.dart`
- `lib/screens/pools/fight_pick_detail_screen.dart`
- `lib/screens/pools/head_to_head_screen.dart`
- `lib/screens/pools/h2h_picks_screen.dart`

### Modified Files
- `lib/services/free_odds_service.dart` - Added MMA/UFC support
- `README.md` - Updated with current features

## Deployment Notes
- Ensure Firestore indexes are created for new queries
- Update security rules for new collections
- Test with real UFC event data before production