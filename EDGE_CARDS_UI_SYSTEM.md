# Edge Intelligence Cards UI System
## Standardized Card Design & Presentation Strategy

---

## 🎯 Overview

A comprehensive card-based system for presenting Edge Intelligence data, designed to entice users to spend BR points through clear visual hierarchy, recognizable patterns, and strategic information reveals.

---

## 📱 Card Categories & Visual Identity

### 1. **Injury Intelligence Card** 🏥
- **Color Scheme**: Red/Orange gradient (#FF6B6B → #FFA502)
- **Icon**: Medical cross or bandage icon
- **Preview Text**: "Injury Concern Detected"
- **Teaser Info**: Shows injury severity (e.g., "Questionable" or "Day-to-day")
- **Full Intel**: 
  - Detailed injury report
  - Expected playing time impact
  - Historical recovery patterns
  - Similar injury performance data
- **BR Cost**: 15-20 BR (higher for breaking news)
- **Priority**: HIGH

### 2. **Weather Impact Card** 🌦️
- **Color Scheme**: Blue/Gray gradient (#4834D4 → #95A5A6)
- **Icon**: Dynamic weather icon (rain, snow, wind)
- **Preview Text**: "Weather Alert - Game Impact"
- **Teaser Info**: Basic condition (e.g., "20+ mph winds")
- **Full Intel**:
  - Detailed weather forecast
  - Historical performance in conditions
  - Specific player/team impacts
  - Over/under implications
- **BR Cost**: 10-15 BR
- **Priority**: MEDIUM (HIGH for outdoor sports)

### 3. **Social Sentiment Card** 🔥
- **Color Scheme**: Reddit orange / Twitter blue (#FF4500 / #1DA1F2)
- **Icon**: Trending arrow or flame icon
- **Preview Text**: "Fan Buzz Detected"
- **Teaser Info**: Sentiment meter (e.g., "70% positive")
- **Full Intel**:
  - Reddit thread analysis
  - Betting community insights
  - Fan confidence metrics
  - Trending discussions
- **BR Cost**: 5-10 BR
- **Priority**: LOW-MEDIUM

### 4. **Matchup Analysis Card** ⚔️
- **Color Scheme**: Purple gradient (#6C5CE7 → #A29BFE)
- **Icon**: Crossed swords or versus symbol
- **Preview Text**: "Critical Matchup Intel"
- **Teaser Info**: Advantage indicator (e.g., "Pitcher dominates lefties")
- **Full Intel**:
  - Head-to-head statistics
  - Style matchups
  - Historical performance
  - Key player battles
- **BR Cost**: 10-15 BR
- **Priority**: MEDIUM-HIGH

### 5. **Breaking News Card** 📰
- **Color Scheme**: Yellow/Gold gradient (#FFC107 → #FFD700)
- **Icon**: Lightning bolt or bell
- **Preview Text**: "Breaking: [Team/Player]"
- **Teaser Info**: Timestamp (e.g., "2 hours ago")
- **Full Intel**:
  - Full news story
  - Source verification
  - Betting implications
  - Related intel links
- **BR Cost**: Variable (20 BR if <1hr old, 10 BR if older)
- **Priority**: HIGHEST

### 6. **Betting Movement Card** 💰
- **Color Scheme**: Green gradient (#00B894 → #00D2D3)
- **Icon**: Line graph or dollar sign
- **Preview Text**: "Sharp Money Alert"
- **Teaser Info**: Line movement (e.g., "-3 → -5.5")
- **Full Intel**:
  - Sharp vs public money
  - Line movement history
  - Closing line value
  - Steam move alerts
- **BR Cost**: 15-20 BR
- **Priority**: HIGH

### 7. **Insider/Camp Card** 🏋️
- **Color Scheme**: Dark blue/black (#2C3E50 → #34495E)
- **Icon**: Boxing glove or training icon
- **Preview Text**: "Training Camp Intel"
- **Teaser Info**: Source credibility (e.g., "Verified coach report")
- **Full Intel**:
  - Sparring reports
  - Weight cut status
  - Camp dynamics
  - Preparation quality
- **BR Cost**: 15-20 BR
- **Priority**: HIGH (for combat sports)

### 8. **Clutch Performance Card** ⏱️
- **Color Scheme**: Gold/Bronze gradient (#FFD700 → #B8860B)
- **Icon**: Clock or star
- **Preview Text**: "Clutch Factor Analysis"
- **Teaser Info**: Clutch rating (e.g., "Elite 4th quarter: +8.5")
- **Full Intel**:
  - Situational statistics
  - Pressure performance metrics
  - Historical clutch moments
  - Late-game tendencies
- **BR Cost**: 10-15 BR
- **Priority**: MEDIUM

---

## 🎨 Card States & Interactions

### Locked State (Before BR Spend)
```
┌─────────────────────────┐
│ [ICON] CARD CATEGORY    │
│                         │
│ "Teaser Headline"       │
│ ─────────────────       │
│ ▓▓▓▓░░░░ Partial Info   │
│                         │
│ 🔒 Unlock for XX BR     │
└─────────────────────────┘
```

### Unlocked State (After BR Spend)
```
┌─────────────────────────┐
│ [ICON] CARD CATEGORY    │
│                         │
│ Full Detailed Info      │
│ • Key Point 1           │
│ • Key Point 2           │
│ • Key Point 3           │
│                         │
│ Impact: +/- X.X         │
│ Confidence: 85%         │
└─────────────────────────┘
```

### Hover/Preview State
- Slight card elevation
- Glow effect in category color
- Quick stats preview
- "Tap to unlock" prompt

---

## 🎯 Intelligence Availability Indicators

### Card Badges
- **🆕 NEW**: Pulsing dot for intel < 2 hours old
- **🔥 HOT**: Fire emoji for high-engagement content
- **🔒 EXCLUSIVE**: Lock icon for limited availability
- **✅ VERIFIED**: Checkmark for confirmed reports
- **⚡ BREAKING**: Lightning bolt for time-sensitive
- **📈 TRENDING**: Up arrow for rapidly changing info
- **👁️ VIEWS**: Eye icon with view count

### Card Stack Priority (Top to Bottom)
1. Breaking/time-sensitive intel
2. Injury updates
3. Weather impacts (outdoor sports)
4. Betting line movements
5. Matchup advantages
6. Social sentiment
7. Historical patterns
8. General statistics

---

## 💎 Dynamic Pricing Strategy

### Base Price Tiers
| Category | Base Price | Condition |
|----------|------------|-----------|
| Critical | 15-20 BR | Injuries, Breaking News |
| Important | 10-15 BR | Weather, Matchups, Betting |
| Supplemental | 5-10 BR | Social, Historical |

### Price Modifiers
| Modifier | Adjustment | Trigger |
|----------|------------|---------|
| Freshness Bonus | +5 BR | < 1 hour old |
| Exclusivity Premium | +5 BR | Limited sources |
| Game Proximity | +5 BR | < 30 min to game |
| Upset Potential | +10 BR | Underdog advantage detected |
| Bundle Discount | -20% | Multiple cards purchased |

### Time-Based Pricing
```
Time to Game    Price Multiplier
< 30 min        1.5x
30-60 min       1.3x
1-3 hours       1.1x
3-24 hours      1.0x
> 24 hours      0.8x
```

---

## 🎮 Gamification Elements

### Intel Quality Indicators
```
Confidence:     ████████░░ 85%
Source Quality: ⭐⭐⭐⭐⭐
Freshness:      ████████████ < 1hr
Impact Level:   HIGH
```

### Rarity Tiers
| Tier | Color | Description | Frequency |
|------|-------|-------------|-----------|
| Common | Gray | Basic stats, public info | 40% |
| Uncommon | Green | Advanced metrics | 30% |
| Rare | Blue | Insider information | 20% |
| Epic | Purple | Breaking news | 8% |
| Legendary | Gold | Game-changing intel | 2% |

### Achievement Unlocks
- "Early Bird" - Purchase intel > 24hrs before game
- "Sharp Eye" - Unlock winning intel 5 times
- "Intel Master" - Use 100 Edge cards total
- "Upset Caller" - Win with underdog intel

---

## 📊 Sport-Specific Card Types

### NBA/NHL
- **Rest Advantage**: Games played in last 5 days
- **Travel Fatigue**: Miles traveled, time zones crossed
- **Back-to-Back**: Performance in 2nd game metrics
- **Lineup Changes**: Late scratches, rotations

### NFL
- **QB Pressure**: Sack rate, pressure percentage
- **Weather Impact**: Wind, rain, snow effects
- **Primetime Performance**: Night game statistics
- **Division Rivalry**: Historical division game data

### MLB
- **Pitcher Matchup**: Batter vs pitcher history
- **Ballpark Factors**: Wind direction, humidity
- **Day/Night Splits**: Performance variations
- **Bullpen Status**: Usage and availability

### Boxing/MMA
- **Weight Cut**: Hydration and cut difficulty
- **Sparring Reports**: Training camp performance
- **Judge Analysis**: Scoring tendencies
- **Style Matchup**: Fighter style advantages

---

## 🔔 Notification & Engagement Strategy

### Push Notification Triggers
- New legendary intel for followed teams
- Price drops on saved cards
- Breaking news alerts
- Intel expiring in 15 minutes
- Bundle offers available

### In-App Notifications
```
"💎 Legendary intel just dropped for Lakers vs Celtics!"
"⏰ Price increasing in 5 minutes on Weather Impact card"
"🔥 3 users just unlocked this intel and won their bets"
```

### Email Campaigns
- Weekly intel performance reports
- Upcoming game intel previews
- Success stories from intel users

---

## 💡 User Psychology & FOMO Tactics

### Social Proof Elements
- "🔥 12 users viewing this intel"
- "⏱️ Last unlocked 2 min ago"
- "📈 73% win rate with this intel"
- "👥 5 of your friends unlocked"

### Urgency Creation
- Countdown timers for price changes
- Limited quantity indicators
- "Only 3 unlocks remaining"
- Flash sale notifications

### Value Demonstration
- Show potential BR winnings
- Display historical accuracy
- Compare to betting without intel
- Success story carousel

---

## 🎯 Implementation Priorities

### Phase 1: Core Cards (Week 1)
1. Injury Intelligence
2. Breaking News
3. Matchup Analysis
4. Basic locked/unlocked states

### Phase 2: Enhanced Cards (Week 2)
1. Weather Impact
2. Betting Movement
3. Social Sentiment
4. Dynamic pricing

### Phase 3: Gamification (Week 3)
1. Rarity system
2. Achievement badges
3. Social proof elements
4. Bundle offers

### Phase 4: Polish (Week 4)
1. Animations and transitions
2. Push notifications
3. A/B testing framework
4. Analytics integration

---

## 🏗️ Technical Architecture

### Card Component Structure
```dart
EdgeCard
├── CardHeader (icon, category, badges)
├── CardBody
│   ├── LockedContent (teaser, blur effect)
│   └── UnlockedContent (full intel)
├── CardFooter (price, unlock button)
└── CardAnimations (hover, unlock, flip)
```

### State Management
- Card state (locked/unlocked/expired)
- Pricing state (base/modified/sale)
- User interaction state (viewed/saved/shared)
- Analytics tracking state

### Caching Strategy
- Cache unlocked cards for session
- Pre-load high-priority cards
- Lazy load supplemental cards
- Expire cache based on freshness

---

## 📈 Success Metrics

### Engagement KPIs
- Card unlock rate by category
- Average BR spent per user
- Time to first unlock
- Return visitor card usage

### Revenue KPIs
- BR consumption rate
- Bundle adoption rate
- Premium card conversion
- Price elasticity by category

### User Satisfaction
- Intel accuracy rating
- Card helpfulness scores
- Feature request tracking
- Churn rate analysis

---

## 🚀 Future Enhancements

### Version 2.0
- AI-powered intel recommendations
- Personalized card ordering
- Voice-activated card reveals
- AR card visualizations

### Version 3.0
- Community-contributed intel
- Intel trading marketplace
- Subscription tiers for unlimited cards
- White-label B2B offering

---

## 📝 Design Guidelines

### Visual Consistency
- Maintain color scheme across all cards
- Consistent icon style (outlined vs filled)
- Standardized font hierarchy
- Uniform spacing and padding

### Accessibility
- High contrast ratios (WCAG AA)
- Screen reader descriptions
- Keyboard navigation support
- Colorblind-friendly indicators

### Performance
- Lazy load card images
- Progressive content reveal
- Optimistic UI updates
- Smooth 60fps animations

---

## ✅ Launch Checklist

- [ ] Design all 8 card categories
- [ ] Implement locked/unlocked states
- [ ] Create pricing engine
- [ ] Add badge system
- [ ] Build notification system
- [ ] Integrate analytics
- [ ] A/B test card designs
- [ ] Launch to beta users
- [ ] Iterate based on feedback
- [ ] Full production release