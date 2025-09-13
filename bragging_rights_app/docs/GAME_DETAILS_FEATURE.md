# Game Details Page Feature Specification

## Overview
A dedicated details page for each game/event that provides comprehensive information including event details, venue information, odds comparison, and quick access to pools. Users access this page by clicking anywhere on a game card except the "View Pools" button.

## Navigation Flow
- **Entry Point**: Click on game card from Games page (anywhere except "View Pools" button)
- **"View Pools" Button**: Still navigates directly to pool selection
- **Back Navigation**: Returns to Games page

## Page Structure

### 1. Header Section
- **Event Name**:
  - Combat Sports: "Canelo vs Crawford" or "UFC 311: Jones vs Miocic"
  - Team Sports: "Lakers @ Warriors" or "Cowboys vs Eagles"
- **Sport Badge**: Visual indicator (Boxing, MMA, NFL, NBA, etc.)
- **Date & Time**:
  - Formatted display (e.g., "Sat, Sept 14 • 9:00 PM ET")
  - Countdown timer for upcoming events
- **Status Indicator**:
  - Live (with pulsing animation)
  - Scheduled
  - Final/Completed

### 2. Venue Information
*Data from ESPN API*
- **Venue Name**: e.g., "Allegiant Stadium", "Madison Square Garden"
- **Location**: City, State/Country
- **Capacity/Attendance**: When available
- **Map Link**: Opens in maps app

## Sport-Specific Sections

### Combat Sports (Boxing/MMA)

#### Fight Card Display
- **Tabbed View**:
  - Main Card
  - Preliminary Card
  - Early Prelims (if applicable)
- **Each Fight Shows**:
  - Fighter names with country flags
  - Records (W-L-D)
  - Weight class
  - Scheduled rounds
  - Fight time
  - Odds for each fighter (-150/+130)
  - Title/championship indicator

#### Main Event Spotlight
- **Enhanced Display Card**:
  - Fighter photos/avatars
  - Tale of the tape comparison
  - Championship belts at stake
  - Reach, height, stance (if available)
  - Recent fight history (last 5)

### Team Sports (NFL/NBA/MLB/NHL/Soccer)

#### Teams Section
- **Team Display**:
  - Team logos (from TeamLogoService)
  - Season records (e.g., "24-10")
  - Conference/Division standings
  - Recent form (last 5 games: W-W-L-W-L)

#### Game Information Panel
- **Betting Lines**:
  - Spread with best odds
  - Over/Under total
  - Moneyline for each team
- **Game Details**:
  - Officials/Referees
  - Weather (outdoor sports)
  - Playing surface
  - Injury report summary

## Universal Sections

### 3. Betting Intelligence
- **Odds Comparison Table**:
  - Top 3-5 bookmakers
  - Best available odds highlighted
  - Last updated timestamp
- **Line Movement Graph** (if historical data available):
  - Opening lines vs current
  - Significant movements flagged
- **Public Betting Trends** (future enhancement):
  - % of bets on each side
  - % of money on each side

### 4. News & Media
*Data from ESPN API*
- **Recent Articles**:
  - Headline, preview text, thumbnail
  - Link to full article
- **Key Storylines**: Bullet points of main narratives
- **Social Media Feed** (future enhancement)

### 5. Broadcast Information
- **TV Networks**: FOX, ESPN, NBC, etc.
- **Streaming Options**: ESPN+, DAZN, Netflix
- **Commentary Team**: Names and roles
- **Radio Coverage**: Local stations

### 6. Live Event Features
*For in-progress events*
- **Live Score Ticker**: Real-time updates
- **Play-by-Play Feed**: Recent plays/rounds
- **Win Probability Chart**: Visual graph
- **Key Moments**: Scoring plays, knockdowns, etc.
- **Live Stats**: Possession, strikes landed, etc.

## Action Buttons

### Primary Actions
- **View Pools**: Navigate to pool selection
- **Quick Bet**: Opens bet slip with pre-selected game
- **Create Pool**: For eligible users

### Secondary Actions
- **Set Reminder**: Push notification before event
- **Share Event**: Share link/details
- **Add to Calendar**: Export to device calendar
- **Follow Event**: Get updates

## Bottom Navigation Tabs

1. **Overview** (Default): Main event information
2. **Odds**: Detailed odds comparison and markets
3. **Stats**: Historical data, head-to-head, trends
4. **News**: Articles, updates, social media
5. **Pools**: Available pools with entry fees and sizes

## Data Sources

### Odds API
- Current odds all markets
- Multiple bookmaker data
- Line movements
- Prop bets availability

### ESPN API
- Event metadata
- Venue information
- Fighter/team records
- Live scoring data
- Play-by-play
- News articles
- Injury reports
- Officials information
- Historical matchups

### Firestore (Cached)
- Team logos
- User preferences
- Betting history
- Pool information
- Cached odds data

### TeamLogoService
- NFL team logos
- NBA team logos
- MLB team logos
- NHL team logos
- Soccer team crests

## Technical Implementation

### Route Definition
```dart
'/game-details': (context) => GameDetailsScreen(
  gameId: args['gameId'],
  sport: args['sport'],
  gameData: args['gameData'], // Optional pre-loaded data
)
```

### State Management
- Use Provider/Riverpod for real-time updates
- Cache frequently accessed data
- Implement pull-to-refresh
- WebSocket for live data (future)

### Performance Considerations
- Lazy load sections as user scrolls
- Cache images aggressively
- Minimize API calls with smart caching
- Pre-fetch data when possible

## UI/UX Guidelines

### Design Principles
- **Dark Theme**: Consistent with app theme
- **Card-Based Layout**: Information in digestible chunks
- **Progressive Disclosure**: Show essential info first
- **Responsive**: Adapt to different screen sizes

### Visual Hierarchy
1. Event name and status (largest)
2. Teams/fighters and odds
3. Supporting information
4. Actions and navigation

### Animations
- Smooth transitions between tabs
- Live score pulsing
- Subtle loading skeletons
- Pull-to-refresh animation

## Future Enhancements

### Phase 2
- Live betting odds updates via WebSocket
- Push notifications for event start
- In-app video highlights
- Social features (comments, reactions)

### Phase 3
- AR features for venue view
- Voice commentary integration
- Betting calculators
- Historical odds database

## Success Metrics
- User engagement time on details page
- Conversion rate to pool entry
- Share rate of events
- Return visitor rate

## Error Handling
- Graceful fallbacks for missing data
- Offline mode with cached data
- Retry logic for failed API calls
- User-friendly error messages

---

*Last Updated: September 2025*
*Version: 1.0*