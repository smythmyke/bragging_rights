# Sports Details Pages Analysis & Standardization Plan

## Current Tab Structure by Sport

### 🥊 Boxing (boxing_details_screen.dart)
**Full Data Mode:**
- FIGHT CARD
- EVENT INFO
- FIGHTERS
- BROADCAST

**ESPN Fallback Mode:**
- EVENT INFO
- PREVIEW

### 🥋 MMA (mma_details_screen.dart)
**Sections (No tabs, scrollable view):**
- Main Event Tale of the Tape
- Fight Card (Main Card, Prelims, Early Prelims)
- Event Information

### 👤 Fighter Details (fighter_details_screen.dart)
**Sections (No tabs, scrollable view):**
- Fighter Header (Avatar, Name, Record)
- Physical Stats
- Fight Stats
- Recent Fights

### 🏈🏀⚾ Game Details (game_details_screen.dart)
**MLB (Baseball):**
- Matchup
- Box Score
- Stats

**NFL (Football):**
- Overview
- Stats
- Standings

**NBA (Basketball):**
- Overview
- Stats
- Standings
- H2H

**NHL (Hockey):**
- Overview
- Box Score
- Scoring
- Standings

**Soccer:**
- Overview
- Stats
- Standings
- H2H

**Default (Other sports):**
- Overview
- Fighters/Odds (conditional)
- Stats
- News
- Pools

## Common Information Across Sports

### 1. **Event/Game Overview**
- Date & Time
- Venue/Location
- Teams/Participants
- Current Score/Result
- Status (Upcoming/Live/Completed)

### 2. **Statistics**
- Team/Fighter stats
- Individual performance metrics
- Historical data
- Records

### 3. **Broadcast/Media**
- TV/Streaming info
- Commentary
- News/Articles

### 4. **Standings/Rankings**
- League position
- Conference standings
- Division rankings

### 5. **Head-to-Head/History**
- Previous matchups
- Recent results
- Historical performance

## Standardization Plan

### Proposed Universal Tab Structure

#### For Team Sports (NFL, NBA, NHL, MLB, Soccer):
1. **OVERVIEW** - Essential game info, score, key highlights
2. **STATS** - Team and player statistics
3. **STANDINGS** - League/division standings
4. **HISTORY** - Head-to-head records, recent meetings

#### For Combat Sports (Boxing, MMA):
1. **OVERVIEW** - Event info, main card preview
2. **FIGHT CARD** - All scheduled bouts
3. **FIGHTERS** - Fighter profiles and stats
4. **BROADCAST** - Viewing options and schedule

#### For Individual Sports:
1. **OVERVIEW** - Athlete profile, current event
2. **STATS** - Performance metrics
3. **HISTORY** - Recent results, achievements
4. **NEWS** - Related articles and updates

### Design Consistency Recommendations

#### 1. **Color Coding**
- Use sport-specific accent colors but maintain consistent base theme
- Standardize status indicators (Live = Red, Upcoming = Blue, Final = Gray)

#### 2. **Layout Patterns**
- **Header Section**: Always show event/game title, date, venue
- **Score/Result Display**: Consistent positioning and styling
- **Tab Bar**: Same height, font size, and interaction patterns

#### 3. **Data Presentation**
- **Stats Tables**: Uniform table styling with alternating row colors
- **Player/Fighter Cards**: Consistent size and info hierarchy
- **Timeline/Scoring Plays**: Same visual style across sports

#### 4. **Common Widgets to Create**
```dart
// Reusable components
- EventHeaderWidget (title, date, venue, status)
- ScoreDisplayWidget (adaptable to sport type)
- StatsTableWidget (configurable columns)
- StandingsTableWidget
- PlayerCardWidget/FighterCardWidget
- BroadcastInfoWidget
- H2HHistoryWidget
```

### Implementation Priority

1. **Phase 1: Core Components**
   - Create shared widgets for common elements
   - Establish consistent color and typography system

2. **Phase 2: Tab Standardization**
   - Align tab names and order across similar sports
   - Ensure consistent tab navigation behavior

3. **Phase 3: Data Presentation**
   - Standardize table and list components
   - Create sport-agnostic data displays

4. **Phase 4: Polish**
   - Add consistent loading states
   - Implement error handling patterns
   - Ensure responsive design

### Benefits of Standardization

1. **User Experience**: Familiar navigation patterns across all sports
2. **Code Reusability**: Shared components reduce duplication
3. **Maintenance**: Easier to update and fix issues
4. **Consistency**: Professional, cohesive appearance
5. **Scalability**: Easy to add new sports following established patterns