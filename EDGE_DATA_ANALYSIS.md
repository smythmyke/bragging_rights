# Edge Intel Cards - Data Availability Analysis

## 📊 Executive Summary

This document analyzes **what data is actually available** from your current APIs to determine which Edge Intel cards can be built vs. which should be removed due to API limitations.

---

## ✅ Available Data Sources

### 1. **ESPN APIs** (Primary Source)
You have ESPN service integrations for:
- **NFL** (`espn_nfl_service.dart`)
- **NBA** (`espn_nba_service.dart`)
- **NHL** (`espn_nhl_service.dart`)
- **MLB** (`espn_mlb_service.dart`)
- **MMA** (`espn_mma_service.dart`)
- **Boxing** (`espn_boxing_service.dart`)
- **Tennis** (`espn_tennis_service.dart`)

**Available ESPN Data:**
- ✅ Team stats (PPG, offensive efficiency, defensive rankings)
- ✅ Recent form (win/loss records, streaks)
- ✅ Injury reports
- ✅ Weather data (for outdoor games)
- ✅ Betting odds/lines
- ✅ Starting lineups (MLB pitchers, etc.)
- ✅ Venue information
- ✅ Game situations (live games only)
- ✅ Fighter records & profiles (combat sports)

### 2. **The Odds API** (`odds_api_service.dart`)
- ✅ Betting odds (moneyline, spreads, totals)
- ✅ Line movement tracking
- ✅ Multiple bookmaker comparisons
- ✅ Player props (NFL: passing/rushing yards, MLB: strikeouts/hits)
- ✅ Preseason/regular season game detection
- ❌ **NO play-by-play data**
- ❌ **NO in-game momentum tracking**
- ❌ **NO live scoring events**

### 3. **NewsAPI** (`news_api_service.dart`)
- ✅ Breaking news articles
- ✅ Headlines and snippets
- ✅ Team/player mentions
- ✅ Recent news (last 24-48 hours)

### 4. **Reddit API** (`reddit_service.dart`)
- ✅ Fan sentiment analysis
- ✅ Community predictions
- ✅ Social buzz/excitement metrics
- ✅ Subreddit discussions (r/nfl, r/nba, r/hockey, r/baseball, r/mma)

### 5. **NHL Official API** (`nhl_api_service.dart`)
- ✅ Goalie matchup stats
- ✅ Power play percentages
- ✅ Penalty kill percentages
- ✅ Team statistics

### 6. **Weather API** (Referenced in Edge Service)
- ✅ Temperature, wind speed, direction
- ✅ Precipitation forecast
- ✅ Outdoor venue detection

---

## ❌ Data NOT Available (Cannot Build Cards)

### Missing from ALL APIs:
1. **Play-by-Play Data** - No API provides this
2. **Live Momentum Shifts** - Would require play-by-play
3. **In-Game Scoring Events** - Not real-time enough
4. **Referee Tendencies** - No API tracks this
5. **Sharp vs Public Money** - Premium betting data (not in free APIs)
6. **Contrarian Indicators** - Would need betting ticket data
7. **Live Player Performance Tracking** - Would need play-by-play

---

## 🎯 RECOMMENDATION: Keep These Intel Cards

### ✅ **Core Intel Cards** (Have Full Data Support)

#### 1. **Injury Intelligence** ✅ KEEP
**Data Source:** ESPN injury reports
- Status (Out, Doubtful, Questionable)
- Impact analysis (QB injuries = high impact)
- Last updated timestamp
**Value:** Critical for betting decisions

#### 2. **Weather Impact** ✅ KEEP
**Data Source:** ESPN weather API
- Wind speed/direction (crucial for MLB/NFL)
- Temperature (affects baseball flight)
- Precipitation
**Value:** Massive edge for outdoor sports betting

#### 3. **Betting Movement** ✅ KEEP
**Data Source:** The Odds API
- Line movement tracking
- Spread changes
- Total (over/under) adjustments
- Multiple bookmaker comparison
**Value:** Shows where sharp money is moving

#### 4. **Breaking News** ✅ KEEP
**Data Source:** NewsAPI
- Last-minute lineup changes
- Trade/signing news
- Coach decisions
**Value:** Real-time edge before lines adjust

#### 5. **Matchup Analysis** ✅ KEEP
**Data Source:** ESPN team stats
- Head-to-head records
- Style matchups (e.g., pass offense vs pass defense)
- Home/away splits
- Recent form
**Value:** Statistical edge for game planning

#### 6. **Social Sentiment** ✅ KEEP
**Data Source:** Reddit API
- Fan confidence levels
- Community predictions
- Buzz/excitement metrics
**Value:** Contrarian indicator, fade the public

---

### 🆕 **New Intel Cards You Could Add**

#### 7. **Pitcher/Goalie Spotlight** 🆕 RECOMMENDED
**Data Source:** ESPN MLB/NHL services
- Starting pitcher ERA, WHIP, recent starts (MLB)
- Goalie save percentage, GAA, recent form (NHL)
**Value:** Elite pitching/goaltending is a massive edge

#### 8. **Line Value Detector** 🆕 RECOMMENDED
**Data Source:** The Odds API + ESPN stats
- Compare current odds to statistical models
- Identify +EV bets (positive expected value)
- Show best available odds across books
**Value:** Mathematical edge for sharp bettors

#### 9. **Trend Tracker** 🆕 RECOMMENDED
**Data Source:** ESPN team stats
- Team trends (e.g., "5-0 ATS as underdog")
- Player trends (e.g., "LeBron 8-2 vs Celtics")
- Situational trends (e.g., "Back-to-back games")
**Value:** Pattern recognition edge

#### 10. **Public Fade Alert** 🆕 RECOMMENDED
**Data Source:** Reddit sentiment + Odds movement
- If Reddit heavily favors one side BUT line moves opposite = sharp money
- Shows when to fade the public
**Value:** Contrarian betting edge

---

## 🗑️ REMOVE: These Intel Cards (No Data Available)

### ❌ Cards to Delete:

1. **Insider/Camp Info** ❌ REMOVE
   - **Why:** No API provides practice reports, training camp notes
   - **Alternative:** Use Breaking News card instead

2. **Clutch Performance** ❌ REMOVE
   - **Why:** Requires play-by-play data for clutch situations
   - **Alternative:** Use Recent Form in Matchup Analysis

---

## 🚫 REMOVE: All Power Cards

### Why Power Cards Don't Work:

**Original Power Card Concept:**
- In-game "power-ups" that users activate during live games
- Examples: "Momentum Shift Detector", "Comeback Multiplier", "Score Boost"

**Why They're Impossible:**
1. ❌ **No Play-by-Play Data** - Can't track in-game events
2. ❌ **Not Real-Time Enough** - APIs update too slowly for live action
3. ❌ **No Game State Tracking** - Can't know score, quarter, possession

**Better Alternative:**
Focus on **pre-game intelligence** that helps users make smarter bets BEFORE the game starts. This is more valuable than gimmicky in-game boosts.

---

## 📈 Recommended Edge Page Structure

### **Intel Cards Only** (8-10 cards total)

**Pre-Game Intelligence:**
1. ⚕️ **Injury Intelligence** - Who's out/questionable
2. 🌦️ **Weather Impact** - Wind/rain affects scoring
3. 📊 **Matchup Analysis** - Team stats & H2H
4. 🎯 **Pitcher/Goalie Spotlight** - Starting matchup
5. 📰 **Breaking News** - Last-minute updates
6. 💰 **Betting Movement** - Where lines are moving
7. 🗳️ **Social Sentiment** - Reddit/fan buzz
8. 📈 **Trend Tracker** - Hot streaks & patterns
9. 🎯 **Line Value Detector** - Find +EV bets
10. 🔄 **Public Fade Alert** - When to go contrarian

**Card Pricing (in BR):**
- Common Intel (Weather, News): 10-20 BR
- Rare Intel (Matchup, Trends): 30-40 BR
- Epic Intel (Line Value, Fade Alert): 50-75 BR
- Legendary Intel (Breaking injury news): 100+ BR

**Dynamic Pricing:**
- Cards get MORE expensive as game approaches (urgency)
- Cards expire at game start (no refunds)
- Bundle discount: Buy 3 cards = 20% off

---

## 💡 Key Insights from Edge Intelligence Service

Looking at `edge_intelligence_service.dart` (lines 1-2149), I can see you're already gathering:

### **NFL Intel** (lines 153-433):
- ✅ ESPN odds, weather, injuries
- ✅ Team stats (PPG, red zone %)
- ✅ Recent form & streaks
- ✅ Key matchups
- ✅ News + Reddit sentiment
- 📊 **Generates betting suggestions** (e.g., "Under if bad weather")

### **MLB Intel** (lines 435-762):
- ✅ Starting pitchers (ERA, WHIP)
- ✅ Weather (wind direction CRITICAL)
- ✅ Ballpark factors (hitter/pitcher park)
- ✅ Team stats & recent form
- 📊 **Generates suggestions** (e.g., "Over if wind blowing out")

### **NHL Intel** (lines 764-1009):
- ✅ Goalie matchup (save %)
- ✅ Special teams (PP%, PK%)
- ✅ Recent form & streaks
- 📊 **Generates suggestions** (e.g., "Under with elite goalie")

### **MMA/Boxing Intel** (lines 1011-1713):
- ✅ Fighter records & styles
- ✅ KO percentages
- ✅ Weight cut concerns
- ✅ Betting odds & method props
- 📊 **Generates suggestions** (e.g., "Won't go distance if high KO rate")

---

## 🎯 Final Recommendation

### **DO THIS:**
1. ✅ **Remove all Power Cards** - They're impossible without play-by-play data
2. ✅ **Keep 8-10 Intel Cards** - Focus on pre-game intelligence
3. ✅ **Add 3-4 new cards** (Pitcher Spotlight, Line Value, Trends, Fade Alert)
4. ✅ **Expand existing cards** with more data points from ESPN APIs
5. ✅ **Dynamic pricing** - Cards cost more closer to game time

### **DON'T DO THIS:**
1. ❌ Don't try to build in-game power cards
2. ❌ Don't add cards for data you don't have (referee trends, sharp money)
3. ❌ Don't create cosmetic/achievement cards (users want actionable intel)

---

## 📋 Implementation Checklist

### Phase 1: Cleanup (Week 1)
- [ ] Remove all Power Card references from codebase
- [ ] Remove Insider/Camp Info card (no data)
- [ ] Remove Clutch Performance card (no data)

### Phase 2: Enhance Existing (Week 2)
- [ ] Expand Injury Intelligence with impact ratings
- [ ] Improve Weather card with betting suggestions
- [ ] Add historical line movement to Betting Movement card
- [ ] Enhance Matchup Analysis with more ESPN stats

### Phase 3: Add New Cards (Week 3)
- [ ] Build Pitcher/Goalie Spotlight card
- [ ] Build Line Value Detector (compare odds to stats)
- [ ] Build Trend Tracker (team/player patterns)
- [ ] Build Public Fade Alert (Reddit + line movement)

### Phase 4: Polish (Week 4)
- [ ] Implement dynamic pricing system
- [ ] Add bundle discounts (buy 3+ cards)
- [ ] Card expiration at game start
- [ ] Add time-decay urgency indicators ("⏰ Game in 2 hours!")

---

## 🔥 Killer Feature Idea

### **"Smart Scout" Package**
**Auto-select the 3 most relevant cards for each game based on:**
1. Sport type (weather matters for MLB/NFL, not NBA)
2. Game context (rivalry game = check social sentiment)
3. Recent news (injury news in last 24h = auto-include)
4. Line movement (sharp action detected = auto-include betting movement)

**Pricing:**
- Individual cards: 20-100 BR each
- Smart Scout bundle: 60 BR (saves 20-40 BR)
- Season pass: 500 BR (unlimited scouts for 30 days)

This gives users an "easy mode" while power users can still cherry-pick cards.

---

## Summary Table

| Intel Card | Data Source | Keep/Remove | Confidence | New Card? |
|-----------|-------------|-------------|------------|-----------|
| Injury Intelligence | ESPN | ✅ KEEP | 95% | No |
| Weather Impact | ESPN | ✅ KEEP | 90% | No |
| Betting Movement | Odds API | ✅ KEEP | 95% | No |
| Breaking News | NewsAPI | ✅ KEEP | 85% | No |
| Matchup Analysis | ESPN | ✅ KEEP | 90% | No |
| Social Sentiment | Reddit | ✅ KEEP | 75% | No |
| Pitcher/Goalie Spotlight | ESPN | ✅ ADD | 90% | Yes |
| Line Value Detector | Odds + ESPN | ✅ ADD | 80% | Yes |
| Trend Tracker | ESPN | ✅ ADD | 85% | Yes |
| Public Fade Alert | Reddit + Odds | ✅ ADD | 75% | Yes |
| Insider/Camp Info | ❌ None | ❌ REMOVE | 0% | No |
| Clutch Performance | ❌ No play-by-play | ❌ REMOVE | 0% | No |
| **ALL Power Cards** | ❌ No play-by-play | ❌ REMOVE | 0% | No |

---

## Questions for You

1. **Do you want to keep any form of Power Cards?** (e.g., cosmetic achievements)
2. **Should Intel cards expire at game start or stay viewable during games?**
3. **What's your preferred card pricing model?** (static vs dynamic based on time)
4. **Should we add a "Full Intel Package" bundle discount?**
5. **Priority order for the 4 new cards?** (Which to build first)

Let me know your thoughts and I can help implement whichever direction you choose!
