# Edge Intel Cards by Sport - Availability Matrix

## 📊 Overview

This document shows exactly which Edge Intel cards are available for each sport based on your current API integrations.

**Legend:**
- ✅ **Fully Available** - Complete data, ready to build
- ⚠️ **Partial** - Some data available, needs fallback
- ❌ **Not Available** - No data source

---

## 🏈 NFL (American Football)

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ✅ | ESPN NFL | QB injuries, impact ratings, status (Out/Doubtful/Questionable) |
| **Weather Impact** | ✅ | ESPN NFL | Wind speed/direction, temp, precipitation, impact analysis |
| **Breaking News** | ✅ | NewsAPI | Injury news, lineup changes, trades |
| **Matchup Analysis** | ✅ | ESPN NFL | Team stats (PPG, red zone %), recent form, streaks |
| **Social Sentiment** | ✅ | Reddit (r/nfl) | Fan confidence, community predictions |
| **Betting Movement** | ⚠️ | ESPN NFL (fallback) | Limited odds - moneyline only, no spread tracking |

### What NFL Cards Can Show:

#### 1. **Injury Intelligence** (15 BR)
```
⚕️ INJURY REPORT
───────────────────
🔴 HIGH IMPACT
Patrick Mahomes (QB) - Questionable
Travis Kelce (TE) - Doubtful

🟡 MEDIUM IMPACT
Chris Jones (DL) - Probable
```
**Data Fields:**
- Player name, position
- Status: Out ❌ | Doubtful 🟡 | Questionable ⚠️ | Probable ✅
- Impact rating (QB = high, skill positions = medium, depth = low)
- Last updated timestamp

#### 2. **Weather Impact** (10 BR)
```
🌦️ WEATHER ALERT
───────────────────
🌬️ Wind: 22 mph gusting to 28
🌡️ Temp: 38°F
🌧️ 40% chance of rain

📊 IMPACT: HIGH
Strong winds will affect passing game
Consider UNDER total points

💡 BETTING EDGE:
Wind >15mph = avg 4.2 fewer points scored
```
**Data Fields:**
- Wind speed, direction
- Temperature
- Precipitation chance
- Impact rating (HIGH/MEDIUM/LOW)
- Betting suggestion (Over/Under)

#### 3. **Breaking News** (20 BR)
```
🚨 BREAKING NEWS
───────────────────
CMC ruled OUT for Sunday
Backup Jordan Mason to start
📰 ESPN • 18m ago

Deebo Samuel practicing fully
Expected to play despite ankle
📰 Yahoo Sports • 42m ago
```
**Data Fields:**
- Headline
- Summary
- Source (ESPN, Yahoo, etc.)
- Published time

#### 4. **Matchup Analysis** (10 BR)
```
📊 MATCHUP INTEL
───────────────────
OFFENSE vs DEFENSE
Chiefs (#1 offense, 29.5 PPG)
vs Eagles (#3 defense, 18.2 PPG allowed)

📈 KEY TRENDS
Chiefs: 8-2 last 10 games
Eagles: 1-4 vs top-5 offenses

🏟️ HOME ADVANTAGE
Chiefs 6-1 at Arrowhead this year
```
**Data Fields:**
- Offensive rankings, PPG
- Defensive rankings, points allowed
- Red zone efficiency
- Recent form (last 5-10 games)
- Home/away splits
- Streaks (win/loss)

#### 5. **Social Sentiment** (5 BR)
```
🗳️ FAN SENTIMENT
───────────────────
r/nfl: 68% confident in Chiefs
r/eagles: 52% confident

🔥 HOT TAKES:
"Mahomes always wins in playoffs"
"Eagles defense will dominate"

⚠️ CONTRARIAN ALERT:
Public heavily on Chiefs (-3.5)
Sharp money may be on Eagles +3.5
```
**Data Fields:**
- Fan confidence % per team
- Post count, comment volume
- Trending topics
- Contrarian indicator

---

## 🏀 NBA (Basketball)

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ✅ | ESPN NBA | Player health, impact ratings |
| **Weather Impact** | ❌ | N/A | Indoor sport, not applicable |
| **Breaking News** | ✅ | NewsAPI | Injury news, trades, suspensions |
| **Matchup Analysis** | ✅ | ESPN NBA | Team stats, recent form |
| **Social Sentiment** | ✅ | Reddit (r/nba) | Fan buzz, predictions |
| **Betting Movement** | ⚠️ | ESPN NBA (fallback) | Limited odds data |

### NBA-Specific Cards:

#### **Matchup Analysis** (10 BR)
```
📊 NBA MATCHUP INTEL
───────────────────
Lakers (28-15) vs Warriors (22-21)

OFFENSIVE EFFICIENCY
Lakers: 118.2 PPG (#5 in NBA)
Warriors: 115.8 PPG (#12)

DEFENSIVE RANKINGS
Lakers: 112.3 allowed (#8)
Warriors: 116.5 allowed (#18)

🔥 RECENT FORM
Lakers: 7-3 last 10
Warriors: 4-6 last 10

💡 KEY FACTOR:
LeBron averaging 32.5 vs Warriors
```
**Data Fields:**
- Points per game (offensive)
- Points allowed (defensive)
- FG%, 3PT%, assists, rebounds
- Recent form (last 10 games)
- Head-to-head history

---

## ⚾ MLB (Baseball)

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ✅ | ESPN MLB | Player status, rotation updates |
| **Weather Impact** | ✅ | ESPN MLB | **Wind is CRITICAL** - direction & speed |
| **Breaking News** | ✅ | NewsAPI | Lineup changes, pitcher scratches |
| **Matchup Analysis** | ✅ | ESPN MLB | Pitcher stats, team offense/defense |
| **Social Sentiment** | ✅ | Reddit (r/baseball) | Fan confidence |
| **Betting Movement** | ⚠️ | ESPN MLB (fallback) | Limited odds |

### MLB-Specific Cards:

#### **Pitcher Matchup** (15 BR) 🆕 NEW CARD TYPE
```
⚾ STARTING PITCHERS
───────────────────
HOME: Jacob deGrom
2.15 ERA | 1.05 WHIP | 12-3 record
Dominant vs lefties (.189 avg against)

AWAY: Gerrit Cole
3.22 ERA | 1.18 WHIP | 10-5 record
Struggles in day games (4.55 ERA)

💡 EDGE:
Elite pitching matchup
Consider UNDER 7.5 runs
```
**Data Fields:**
- Pitcher name, record
- ERA (Earned Run Average)
- WHIP (Walks + Hits per Inning)
- vs LH/RH splits
- Day/night splits
- Recent starts

#### **Weather Impact** (10 BR) - MLB-SPECIFIC
```
🌦️ GAME CONDITIONS
───────────────────
🌬️ Wind: 15 mph BLOWING OUT to CF
🌡️ Temp: 82°F (ball carries well)
☀️ Day game at Wrigley Field

📊 IMPACT: HIGH
Wind out + heat = more HRs
Fly balls carry 12-15 yards further

💡 BETTING EDGE:
Strong OVER indicator
Wind out at Wrigley = avg 1.8 more runs
```
**MLB Weather Fields:**
- Wind speed
- **Wind direction** (Out/In/L-to-R/R-to-L)
- Temperature
- Ballpark factors (Wrigley, Coors, etc.)
- Historical impact data

#### **Ballpark Factors** (5 BR) 🆕 NEW CARD TYPE
```
🏟️ BALLPARK INTEL
───────────────────
Coors Field (Colorado)
Type: EXTREME Hitter's Park

PARK FACTORS
Runs: 115 (15% above average)
Home Runs: 128 (28% above avg)
Elevation: 5,280 ft

💡 BETTING EDGE:
Always consider OVER at Coors
Avg game total: 11.2 runs
```

---

## 🏒 NHL (Hockey)

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ✅ | ESPN NHL | Player status, goalie injuries critical |
| **Weather Impact** | ❌ | N/A | Indoor sport (except outdoor games) |
| **Breaking News** | ✅ | NewsAPI | Injury news, lineup changes |
| **Matchup Analysis** | ✅ | ESPN NHL + NHL API | Team stats, special teams |
| **Social Sentiment** | ✅ | Reddit (r/hockey) | Fan predictions |
| **Betting Movement** | ⚠️ | ESPN NHL (fallback) | Limited odds |

### NHL-Specific Cards:

#### **Goalie Matchup** (15 BR) 🆕 NEW CARD TYPE
```
🥅 STARTING GOALIES
───────────────────
HOME: Andrei Vasilevskiy
.927 SV% | 2.21 GAA | 18-8-3
Elite vs top lines (.935 SV%)

AWAY: Igor Shesterkin
.918 SV% | 2.45 GAA | 15-10-2
Struggles on road (.901 SV%)

💡 EDGE:
Elite goaltending duel
Consider UNDER 5.5 goals
Vasilevskiy dominates at home
```
**Data Fields:**
- Goalie name, record
- Save percentage (SV%)
- Goals Against Average (GAA)
- Home/road splits
- vs top lines
- Recent form (last 5 starts)

#### **Special Teams** (10 BR) 🆕 NEW CARD TYPE
```
⚡ POWER PLAY vs PENALTY KILL
───────────────────
Lightning PP: 28.5% (#1 in NHL)
Rangers PK: 76.2% (#22)

💡 EDGE DETECTED:
Elite PP vs weak PK
Lightning score PP goal in 72% of wins
Consider Lightning team total OVER

🎯 BETTING ANGLE:
Lightning to score first +140
```
**Data Fields:**
- Power play %
- Penalty kill %
- PP goals per game
- PK goals allowed
- 5v5 strength

---

## 🥊 MMA/Boxing (Combat Sports)

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ✅ | ESPN MMA/Boxing | Weight cut issues, fight-day injuries |
| **Weather Impact** | ❌ | N/A | Indoor events |
| **Breaking News** | ✅ | NewsAPI | Fight cancellations, weigh-in drama |
| **Matchup Analysis** | ✅ | ESPN MMA/Boxing | Fighter records, styles, stats |
| **Social Sentiment** | ✅ | Reddit (r/MMA, r/boxing) | Fan predictions |
| **Betting Movement** | ⚠️ | ESPN (fallback) | Limited odds |

### Combat Sports-Specific Cards:

#### **Fighter Analysis** (15 BR) 🆕 NEW CARD TYPE
```
🥊 FIGHTER INTEL
───────────────────
FIGHTER 1: Israel Adesanya
Record: 24-3 (15 KOs)
Reach: 80" | Stance: Switch
Finish rate: 62.5%

FIGHTER 2: Alex Pereira
Record: 8-2 (7 KOs)
Reach: 79" | Stance: Orthodox
Finish rate: 87.5% (DANGEROUS)

💡 STYLE MATCHUP:
Pereira = power puncher
Adesanya = technical counter-striker
High chance of finish
```
**Data Fields:**
- Record (wins-losses-draws)
- KO/finish rate
- Reach, height
- Stance (Orthodox/Southpaw)
- Win methods (KO/Sub/Decision)
- Recent form

#### **Weight Cut Alert** (10 BR) 🆕 NEW CARD TYPE
```
⚠️ WEIGH-IN CONCERNS
───────────────────
Fighter A: Made weight easily (185 lbs)
Looked strong, hydrated

Fighter B: Struggled at scale
Took 2 attempts, looked drained
📸 Visibly depleted at weigh-in

💡 BETTING EDGE:
Fighter B may lack cardio
Consider Fighter A or UNDER 2.5 rounds
Dehydrated fighters fade late
```
**Data Fields:**
- Official weight
- Attempts to make weight
- Visual assessment (if available)
- Historical weight cut issues
- Rehydration concerns

---

## 🎾 Tennis

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ✅ | ESPN Tennis | Player health, withdrawals |
| **Weather Impact** | ⚠️ | Partial | Outdoor tournaments only |
| **Breaking News** | ✅ | NewsAPI | Withdrawals, rankings |
| **Matchup Analysis** | ✅ | ESPN Tennis | Head-to-head, surface stats |
| **Social Sentiment** | ✅ | Reddit (r/tennis) | Match predictions |
| **Betting Movement** | ❌ | Not available | Odds API doesn't support tennis well |

### Tennis-Specific Cards:

#### **Surface Analysis** (10 BR) 🆕 NEW CARD TYPE
```
🎾 SURFACE MATCHUP
───────────────────
Tournament: French Open
Surface: Red Clay

PLAYER A: Rafael Nadal
Clay record: 112-3 (97.4% win rate)
Clay titles: 14x French Open

PLAYER B: Novak Djokovic
Clay record: 205-51 (80.1%)

💡 EDGE:
Nadal DOMINATES on clay
H2H on clay: Nadal leads 20-8
```
**Data Fields:**
- Surface type (Hard/Clay/Grass)
- Win % by surface
- H2H on this surface
- Titles on surface
- Recent form on surface

---

## 🏈 NCAAF (College Football)

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ⚠️ | Limited | Less reporting than NFL |
| **Weather Impact** | ✅ | ESPN NCAAF | Same as NFL |
| **Breaking News** | ✅ | NewsAPI | Coaching changes, suspensions |
| **Matchup Analysis** | ✅ | ESPN NCAAF | Team stats |
| **Social Sentiment** | ✅ | Reddit (r/CFB) | Fan confidence |
| **Betting Movement** | ⚠️ | ESPN (fallback) | Limited odds |

---

## 🏀 NCAAB (College Basketball)

### Available Intel Cards:

| Card | Status | Data Source | Details |
|------|--------|-------------|---------|
| **Injury Intelligence** | ⚠️ | Limited | Less reporting than NBA |
| **Weather Impact** | ❌ | N/A | Indoor sport |
| **Breaking News** | ✅ | NewsAPI | Transfers, suspensions |
| **Matchup Analysis** | ✅ | ESPN NCAAB | Team stats |
| **Social Sentiment** | ✅ | Reddit (r/CollegeBasketball) | March Madness hype |
| **Betting Movement** | ⚠️ | ESPN (fallback) | Limited odds |

---

## 📊 Master Availability Matrix

### By Sport:

| Sport | Injury | Weather | News | Matchup | Social | Betting |
|-------|--------|---------|------|---------|--------|---------|
| **NFL** | ✅ Full | ✅ Critical | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **NBA** | ✅ Full | ❌ N/A | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **MLB** | ✅ Full | ✅ **CRITICAL** | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **NHL** | ✅ Full | ❌ N/A | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **MMA** | ✅ Full | ❌ N/A | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **Boxing** | ✅ Full | ❌ N/A | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **Tennis** | ✅ Full | ⚠️ Outdoor | ✅ Full | ✅ Full | ✅ Full | ❌ None |
| **NCAAF** | ⚠️ Limited | ✅ Full | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |
| **NCAAB** | ⚠️ Limited | ❌ N/A | ✅ Full | ✅ Full | ✅ Full | ⚠️ Limited |

---

## 🎯 Recommended Card Builds by Sport

### **Priority 1: NFL** (Most Complete Data)
1. ✅ Injury Intelligence - QB injuries are game-changers
2. ✅ Weather Impact - Massive edge for outdoor games
3. ✅ Breaking News - Real-time lineup changes
4. ✅ Matchup Analysis - Red zone, 3rd down efficiency
5. ✅ Social Sentiment - r/nfl is very active

### **Priority 2: MLB** (Weather is CRITICAL)
1. ✅ Weather Impact - **Wind direction = biggest edge**
2. ✅ Pitcher Matchup - **NEW CARD** - ERA, WHIP, splits
3. ✅ Ballpark Factors - **NEW CARD** - Coors, Wrigley
4. ✅ Breaking News - Pitcher scratches
5. ✅ Injury Intelligence

### **Priority 3: NHL** (Goalie = Everything)
1. ✅ Goalie Matchup - **NEW CARD** - Save %, GAA
2. ✅ Special Teams - **NEW CARD** - PP% vs PK%
3. ✅ Injury Intelligence - Goalie injuries critical
4. ✅ Matchup Analysis
5. ✅ Breaking News

### **Priority 4: NBA** (Stats-Heavy)
1. ✅ Injury Intelligence - Star player injuries
2. ✅ Matchup Analysis - Offensive efficiency
3. ✅ Breaking News - Load management, trades
4. ✅ Social Sentiment

### **Priority 5: MMA/Boxing** (Unique Intel)
1. ✅ Fighter Analysis - **NEW CARD** - Records, styles
2. ✅ Weight Cut Alert - **NEW CARD** - Weigh-in issues
3. ✅ Breaking News - Fight cancellations
4. ✅ Social Sentiment - r/MMA very active

---

## 🆕 New Card Types to Build

### Sport-Specific Cards:

1. **MLB: Pitcher Matchup** (15 BR)
   - ERA, WHIP, record
   - LH/RH splits
   - Day/night splits
   - Last 3 starts

2. **MLB: Ballpark Factors** (5 BR)
   - Hitter/pitcher park
   - Elevation
   - Park factor stats
   - Historical run totals

3. **NHL: Goalie Matchup** (15 BR)
   - Save %
   - GAA (Goals Against Avg)
   - Home/road splits
   - vs top lines

4. **NHL: Special Teams** (10 BR)
   - Power play %
   - Penalty kill %
   - Goals per game
   - Matchup advantage

5. **MMA/Boxing: Fighter Analysis** (15 BR)
   - Record, KO rate
   - Reach, stance
   - Style matchup
   - Recent form

6. **MMA: Weight Cut Alert** (10 BR)
   - Weigh-in issues
   - Visual assessment
   - Historical concerns
   - Cardio impact

7. **Tennis: Surface Analysis** (10 BR)
   - Surface win %
   - H2H on surface
   - Titles on surface
   - Recent form

---

## 💰 Pricing Recommendations by Sport

### NFL (Highest Demand):
- Injury Intelligence: **20 BR** (was 15)
- Weather Impact: **15 BR** (was 10)
- Breaking News: **25 BR** (was 20)
- Matchup Analysis: **15 BR** (was 10)
- Social Sentiment: **10 BR** (was 5)

### MLB (Weather = Gold):
- Weather Impact: **20 BR** (CRITICAL)
- Pitcher Matchup: **15 BR** (NEW)
- Ballpark Factors: **10 BR** (NEW)
- Injury Intelligence: **15 BR**
- Breaking News: **20 BR**

### NHL (Goalie = King):
- Goalie Matchup: **20 BR** (NEW - highest value)
- Special Teams: **15 BR** (NEW)
- Injury Intelligence: **15 BR**
- Matchup Analysis: **10 BR**

### Combat Sports:
- Fighter Analysis: **15 BR** (NEW)
- Weight Cut Alert: **15 BR** (NEW)
- Breaking News: **20 BR**
- Social Sentiment: **10 BR**

---

## 📋 Implementation Checklist

### Phase 1: Core Cards (All Sports)
- [ ] Breaking News (NewsAPI)
- [ ] Injury Intelligence (ESPN)
- [ ] Matchup Analysis (ESPN)
- [ ] Social Sentiment (Reddit)

### Phase 2: Sport-Specific Cards
- [ ] NFL: Weather Impact
- [ ] MLB: Weather Impact (wind focus)
- [ ] MLB: Pitcher Matchup 🆕
- [ ] MLB: Ballpark Factors 🆕
- [ ] NHL: Goalie Matchup 🆕
- [ ] NHL: Special Teams 🆕

### Phase 3: Combat Sports
- [ ] MMA: Fighter Analysis 🆕
- [ ] MMA: Weight Cut Alert 🆕
- [ ] Boxing: Fighter Analysis 🆕

### Phase 4: Additional Sports
- [ ] Tennis: Surface Analysis 🆕
- [ ] NCAAF: Weather Impact
- [ ] NCAAB: Matchup Analysis

---

## 🔥 Key Takeaways

1. **NFL** = Most complete data, build all 5-6 cards
2. **MLB** = Weather intel is GOLD, wind direction critical
3. **NHL** = Goalie matchup is everything, must build
4. **NBA** = Stats-heavy, focus on efficiency metrics
5. **Combat Sports** = Unique intel (weight cuts, styles)
6. **All Sports** = NewsAPI provides breaking news edge
7. **Betting Movement** = Limited (Odds API quota exceeded)

**Next Steps:** Build the core 4 cards for each major sport, then add sport-specific enhancements!
