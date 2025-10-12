# Mini-Games Monetization Strategy
## Progressive Approach: Start Free, Scale Smart

**Last Updated**: January 2025
**Status**: Phase 0 Implementation Start

---

## Table of Contents
1. [Executive Summary](#executive-summary)
2. [System Overview](#system-overview)
3. [Phase 0: Free HTML5 Games Proof-of-Concept (Week 1 - START HERE)](#phase-0-free-html5-games)
4. [Phase 1: GameDistribution Partnership (Optional Later)](#phase-1-gamedistribution-partnership)
5. [Phase 2: Custom Games Integration (Upgrade Path)](#phase-2-custom-games-integration)
6. [Revenue Projections](#revenue-projections)
7. [Technical Implementation](#technical-implementation)
8. [Leaderboard System](#leaderboard-system)
9. [Social Features](#social-features)
10. [Anti-Cheat & Fair Play](#anti-cheat--fair-play)
11. [Action Items & Timeline](#action-items--timeline)

---

## Executive Summary

### Strategy Overview
Launch weekly rotating mini-games with competitive leaderboards using a **three-phase progressive approach**:

- **Phase 0 (Week 1 - START HERE)**: Launch with FREE open-source HTML5 games to validate concept at zero cost with 100% ad revenue
- **Phase 1 (Optional)**: Add GameDistribution partnership for more game variety (50% revenue share)
- **Phase 2 (Upgrade)**: Purchase templates or build custom games for maximum control and 100% revenue

### Key Metrics
- **Entry Fee**: 5 BR per play
- **Weekly Prize Pool**: 1,200 BR (top 10 players)
- **Target Revenue**: $630-63,000/month (scale dependent, 100% revenue model)
- **Launch Timeline**: 1 week (Phase 0)

### Why Phase 0 First?
- **Zero cost**: No partnerships, no licensing fees, no upfront investment
- **100% revenue**: Keep all ad revenue from day one
- **Fast validation**: Test full system (leaderboards, BR economy, user engagement) immediately
- **Low risk**: Validate concept before spending money on templates or partnerships
- **Learn first**: Understand which game types users prefer before investing

---

## System Overview

### Core Mechanics
1. **Weekly Game Rotation**: 7-week cycle, each game featured for one week
2. **Single Global Leaderboard**: All players compete on same board per game
3. **5 BR Entry Fee**: Unlimited plays, each costs 5 BR
4. **Best Score Counts**: Only player's highest score posted to leaderboard
5. **Weekly Prizes**: Top 10 win BR prizes (500/250/100/50×7)
6. **Social Sharing**: Brag rights and viral growth mechanism

### Player Flow
```
User opens app → Sees featured game (Basketball Stars)
  ↓
Taps "Play Now" → Charged 5 BR from wallet
  ↓
Game loads in WebView → User plays game
  ↓
Game ends, score captured → Close WebView
  ↓
Ad shown (Rewarded or Interstitial)
  ↓
Score posted to leaderboard (if personal best)
  ↓
"Play again?" → Watch ad to play free OR pay 5 BR
  ↓
Share score to friends → Viral growth
```

---

## Phase 0: Free HTML5 Games

### Overview
**Duration**: Week 1 (START HERE)
**Goal**: Validate mini-game concept at zero cost with 100% ad revenue

### Why Start with Free HTML5 Games?

**Advantages:**
- ✅ **Zero upfront cost** - no licensing, no partnerships, no fees
- ✅ **100% ad revenue** - keep all AdMob/AppLovin earnings (no GameDistribution split)
- ✅ **Fast launch** - find games and integrate in 1 week
- ✅ **Full validation** - test leaderboards, BR economy, user engagement before investing
- ✅ **Learn user preferences** - see which game types are popular before buying templates
- ✅ **Same tech stack** - WebView integration (same as GameDistribution would be)

**The Strategy:**
1. Find 5-7 FREE open-source HTML5 sports games
2. Integrate via WebView (identical to how GameDistribution works)
3. Add YOUR AdMob ads outside WebView
4. Launch and measure engagement
5. Based on results → upgrade to templates or GameDistribution

### Finding Free HTML5 Games

**Top Sources:**

**1. itch.io**
- URL: https://itch.io/games/tag-html5/tag-sports
- Filter by: Free, HTML5, Sports, Mobile-friendly
- License types: CC0 (public domain), MIT, CC-BY (with attribution)
- Quality: Variable but many gems available

**2. GitHub**
- Search: "HTML5 sports game" or "JavaScript basketball game"
- Look for: MIT licensed, mobile-responsive, active repos
- Examples:
  - Basketball shooting games
  - Soccer penalty kick games
  - Trivia quiz games

**3. CodePen**
- URL: https://codepen.io/search/pens?q=sports+game
- Many demos allow reuse with attribution
- Great for simple games (trivia, memory match)

**4. OpenGameArt.org**
- Free game assets if building simple games
- Community-contributed, open licenses

### Vetting Criteria for Free Games

**Must Have:**
- ✅ Mobile-optimized (responsive design, touch controls)
- ✅ Runs in WebView without external dependencies
- ✅ Clear score/win condition
- ✅ 3-5 minute average playtime
- ✅ Open license (MIT, CC0, CC-BY, or public domain)
- ✅ Lightweight (<5MB)
- ✅ No backend server required

**Must NOT Have:**
- ❌ Keyboard-only controls (must support touch)
- ❌ Copyrighted assets (team logos, player names)
- ❌ External API dependencies that might break
- ❌ WebGL/Unity (too heavy for mobile WebView)
- ❌ Restrictive licenses (commercial use prohibited)

### Phase 0 Game Recommendations

**Target 5-7 games for launch:**

| Game Type | Why It Works | Where to Find | Vetting Priority |
|-----------|--------------|---------------|------------------|
| **Sports Trivia** | Easy scoring, broad appeal, quiz format | CodePen, GitHub | HIGH |
| **Memory Match** | Simple mechanics, clear win condition | itch.io, CodePen | HIGH |
| **Higher or Lower** | Stat guessing, sports-themed | Build simple HTML/JS | HIGH |
| **Basketball Shot** | Physics, arcade-style, visual | itch.io, GitHub | MEDIUM |
| **Penalty Kick** | Soccer theme, skill-based | itch.io, GitHub | MEDIUM |
| **Logo Quiz** | Easy to build, team branding | Build with your team logos | MEDIUM |
| **Word Search** | Casual, relaxing, time-based | CodePen, GitHub | LOW |

### Phase 0 Integration Approach

**Technical Implementation:**

**Same as GameDistribution approach:**
1. WebView loads HTML5 game URL (local or hosted)
2. User plays game in WebView
3. On WebView close → Manual score input dialog
4. Post score to Firestore leaderboard
5. Show AdMob rewarded/interstitial ad
6. Update leaderboard in real-time

**File Hosting Options:**
- **Option A**: Host HTML files in Firebase Hosting (free tier)
- **Option B**: Include HTML files in app assets folder
- **Option C**: Use GitHub Pages (free hosting)

**Recommendation**: Firebase Hosting (easy updates without app release)

### Phase 0 Monetization

**100% Ad Revenue (No Split):**

**Your Ads:**
1. **Rewarded Video Ad** - After game close, offer "Watch ad to play again free"
2. **Interstitial Ad** - After every 3rd game attempt
3. **Banner Ad** - On leaderboard screen (optional)

**Revenue Projections (100% yours):**

| Active Users | Monthly Ad Revenue (100%) |
|--------------|---------------------------|
| 1,000 | $630 |
| 5,000 | $3,150 |
| 10,000 | $6,300 |
| 25,000 | $15,750 |
| 50,000 | $31,500 |
| 100,000 | $63,000 |

**Compare to GameDistribution (50% split):**
- 10,000 users: You keep $6,300 vs $3,150 (100% better)

### Phase 0 Timeline

**Day 1: Game Research & Selection**
- [ ] Search itch.io for "HTML5 sports" (1 hour)
- [ ] Search GitHub for open-source games (1 hour)
- [ ] Check CodePen for simple game demos (30 min)
- [ ] Test 15-20 games in mobile browser (2 hours)
- [ ] Select 5-7 games that meet vetting criteria
- [ ] Document licenses and attribution requirements

**Day 2: Game Preparation**
- [ ] Download/clone selected games
- [ ] Test each game in local mobile browser
- [ ] Modify for mobile optimization if needed
- [ ] Remove any external dependencies
- [ ] Add attribution notices if required
- [ ] Upload to Firebase Hosting or package in app

**Day 3: WebView Integration**
- [ ] Create MiniGameWebView widget
- [ ] Load first game in WebView
- [ ] Test touch controls work properly
- [ ] Implement WebView close handler
- [ ] Add loading indicator
- [ ] Handle errors (connection, load failures)

**Day 4: Score & Leaderboard System**
- [ ] Create manual score input dialog
- [ ] Implement Firestore score submission
- [ ] Build leaderboard screen with StreamBuilder
- [ ] Add user rank highlighting
- [ ] Test with mock scores
- [ ] Verify real-time updates work

**Day 5: Ad Integration**
- [ ] Load rewarded video ads on game screen
- [ ] Show ad after game close
- [ ] Implement "Watch ad to play free" flow
- [ ] Add interstitial ads (every 3 plays)
- [ ] Test ad flow on iOS and Android
- [ ] Verify ad revenue tracking

**Day 6: Polish & Testing**
- [ ] Add all 5-7 games to rotation config
- [ ] Test each game individually
- [ ] Test leaderboard with multiple users
- [ ] Test prize distribution logic
- [ ] Fix any bugs found
- [ ] Prepare for launch

**Day 7: Launch**
- [ ] Deploy to production
- [ ] Enable first week's game
- [ ] Send push notification to users
- [ ] Monitor analytics closely
- [ ] Gather user feedback
- [ ] Fix critical issues immediately

### Phase 0 Success Criteria

**After Week 1, evaluate:**

✅ **Continue with free games if:**
- 20%+ of users try mini-games
- Average 5+ plays per user
- $0.40+ ad revenue per user
- Positive user feedback
- Low cheating incidents

📊 **Upgrade to templates/GD if:**
- Users want more game variety
- Free games have quality issues
- You've identified which game types are most popular
- Revenue validates spending $150-500 on templates

❌ **Pivot or cancel if:**
- <10% user engagement
- High cheating (integrity issues)
- Technical problems (WebView crashes)
- Negative user feedback

### Phase 0 to Phase 1/2 Decision Tree

**Scenario A: Great Engagement, Want More Variety**
→ Add GameDistribution games (Phase 1)
→ Keep best free games, supplement with GD catalog

**Scenario B: Great Engagement, Want Better Quality**
→ Buy game templates (Phase 2)
→ Replace free games with professional templates

**Scenario C: Great Engagement, Happy with Free Games**
→ Stay in Phase 0
→ Find more free games, build simple custom games

**Scenario D: Low Engagement**
→ Analyze why (game quality? pricing? UI?)
→ Fix issues before investing in Phase 1/2

---

## Phase 1: GameDistribution Partnership

### Overview
**Duration**: Optional (add later for variety)
**Goal**: Supplement free games with 20K+ professional game catalog

### GameDistribution Details

**What They Offer:**
- 20,000+ high-quality HTML5/WebGL games
- 26 genres across all sports types
- 20+ languages, fully localized
- Cross-platform (mobile-optimized available)
- Premium video ads via Azerion network
- Automatic ad serving and revenue split

**Business Model:**
- **Direct Game Integration (DGI)** via iframe embedding
- Browse catalog → Copy embed link → Drop into WebView
- They serve premium brand ads automatically
- Revenue split on ad impressions
- Regular automated payments

**Partnership Type:**
- Register as **Publisher** (not Developer)
- Contact: partnership@azerion.com
- Registration: https://gamedistribution.com/for-business

### Phase 1 Game Selection

**7-Week Rotation (GameDistribution Catalog):**

| Week | Game | Sport Type | Audience |
|------|------|------------|----------|
| 1 | Basketball Stars | Basketball | NBA betting crowd |
| 2 | Penalty Shooters 2 | Soccer | Soccer betting crowd |
| 3 | 8 Ball Billiards Classic | Billiards | Universal appeal |
| 4 | Baseball Pro | Baseball | MLB betting crowd |
| 5 | Golf Orbit | Golf (arcade) | Casual gamers |
| 6 | Table Tennis World Tour | Table Tennis | Quick play fans |
| 7 | Racing/Combat | Motorsports/Boxing | Extreme sports fans |

**Selection Criteria:**
- Mobile-optimized with touch controls
- Average playtime: 3-5 minutes
- Clear win/loss conditions for scoring
- High replay value
- Relevant to sports betting audience

### Phase 1 Monetization

**Revenue Share Model:**
- GameDistribution serves ads within games
- Split ad revenue (exact % TBD - typically 50-70% to publisher)
- Azerion's premium network = higher eCPM rates
- Automatic payment distribution

**Additional Revenue:**
- BR entry fees (5 BR per play) = BR sink mechanism
- BR prizes (1,200 BR/week) = BR faucet
- Net effect: Encourages play without real cost

**Projected Revenue (50% rev-share assumption):**

| Active Users | Total Ad Revenue | Your Share (50%) | Monthly |
|--------------|------------------|------------------|---------|
| 1,000 | $1,200 | $600 | $600 |
| 5,000 | $6,000 | $3,000 | $3,000 |
| 10,000 | $12,000 | $6,000 | $6,000 |
| 50,000 | $60,000 | $30,000 | $30,000 |

### Phase 1 Implementation Requirements

**Technical Setup:**
1. Register as GameDistribution publisher
2. Browse catalog, select 7 mobile-optimized games
3. Copy iframe embed codes for each game
4. Build Flutter WebView wrapper
5. Implement JavaScript bridge for score capture
6. Test ad delivery and revenue tracking

**Firestore Schema:**
```
/mini-games/{gameId}
  - name: "Basketball Stars"
  - embedUrl: "https://gamedistribution.com/games/..."
  - platform: "gamedistribution"
  - weekNumber: 1
  - active: true
  - icon: "basketball"
  - sportType: "basketball"

/leaderboards/{gameId_weekId}
  - gameId: "basketball_stars"
  - weekStart: Timestamp
  - weekEnd: Timestamp
  - scores: [
      {userId, username, score, timestamp}
    ]

/user-stats/{userId}/games/{gameId}
  - attempts: 12
  - bestScore: 10450
  - brSpent: 60
  - lastPlayed: Timestamp
```

### Phase 1 Key Considerations

**1. Mobile Optimization Check**
- Not all 20K games are mobile-friendly
- Filter catalog by "mobile-optimized" tag
- Test each game in WebView before adding to rotation
- Verify touch controls work properly

**2. Score Capture**
- GameDistribution games may not expose score APIs
- Options:
  - **Manual input** (honor system + screenshot verification)
  - **JavaScript scraping** (game-specific, fragile)
  - **Playtime scoring** (time played = score)
- **Recommendation**: Manual input for Phase 1

**3. Ad Integration**
- Ads served within GD iframe (you don't control frequency)
- Add YOUR ads outside iframe:
  - Rewarded video: "Watch ad to play again free"
  - Interstitial: Between WebView close and leaderboard

**4. Revenue Tracking**
- GD provides analytics dashboard
- Track impressions, eCPM, revenue per game
- Compare to your own analytics for validation

**5. Contract Terms to Clarify**
- Exact revenue share percentage
- Payment minimums (typically $100-500)
- Payment schedule (NET 30/60 days)
- Geographic restrictions (if any)
- Can you supplement with your own ads?

---

## Phase 2: Custom Games Integration

### Overview
**Duration**: Month 4+
**Goal**: Maximize revenue by adding 100% revenue-retention games

### Transition Strategy

**When to Move to Phase 2:**
- ✅ Phase 1 validates user engagement (30%+ weekly participation)
- ✅ Identified which game types perform best
- ✅ Revenue from Phase 1 covers Phase 2 development costs
- ✅ User base grown to 5,000+ active users

**Phase 2 Doesn't Replace Phase 1:**
- Keep GameDistribution games as bonus content
- Add custom games to rotation
- Players get more variety (14 games instead of 7)
- A/B test revenue: GD games vs custom games

### Custom Game Development Options

**Option A: Purchase Game Templates**

**Source**: CodeCanyon (Envato Market)
- Pre-built Flutter/HTML5 game templates
- Full source code ownership
- Customize branding, scoring, mechanics

**Cost per Game**: $20-100
**Total Cost (7 games)**: $150-500

**Example Templates:**
- "Sports Quiz Bundle" - $49
- "Memory Match Sports Edition" - $29
- "Basketball Shooting Game" - $35
- "Penalty Kick Challenge" - $45
- "Trivia Game Template" - $25
- "Billiards 8-Ball" - $60
- "Baseball Batting Game" - $39

**Total**: ~$282 for 7 professional templates

**Timeline**:
- Purchase: 1 day
- Integration per game: 2-3 days
- Total: 2-3 weeks for all 7 games

---

**Option B: Build Native Flutter Games**

**Technology Stack:**
- **Flame Engine** - 2D game engine for Flutter
- **flutter_animate** - Smooth animations
- **audioplayers** - Sound effects
- **Firebase** - Backend scoring, auth

**Game Complexity Tiers:**

**Tier 1 - Simple (2-3 days each):**
- Sports Trivia Quiz
- Logo Quiz
- Higher or Lower (stat comparison)
- Memory Match
- Word Search

**Tier 2 - Medium (5-7 days each):**
- Basketball Shooting (physics-based)
- Penalty Kicks (aim + power)
- Baseball Batting (timing-based)
- Billiards (angle calculation)

**Tier 3 - Complex (10-14 days each):**
- Racing game with track
- Fighting game (boxing)
- Full soccer/basketball simulation

**Recommended for Phase 2**: 4-5 Tier 1 games + 2-3 Tier 2 games

**Total Development Time**: 25-35 days
**Cost**: Developer time only (no licensing fees)

---

**Option C: Hybrid Game Sourcing (Recommended)**

**Strategy**: Mix templates + custom builds + GD games

**Game Portfolio (14 total):**

**GameDistribution Games (7):**
- Keep best performers from Phase 1
- High-quality, zero dev cost
- 50% revenue share

**Purchased Templates (4):**
- Buy templates for proven popular games
- Quick integration (2-3 days each)
- 100% revenue, one-time cost
- Examples: Trivia, Memory Match, Logo Quiz, Word Search

**Custom Built (3):**
- Build unique games specific to your brand
- Higher or Lower (Stat Battle)
- Sports Challenge Roulette
- BR Prediction Mini-Game
- 100% revenue, full control

**Benefits:**
- Best of all worlds
- Low risk + high reward
- Content variety (14 total games)
- Maximize revenue mix

---

### Phase 2 Monetization

**Your Own Ad Implementation:**

**Ad Placements:**

1. **Rewarded Video Ads** (Primary Revenue)
   - "Watch ad to play again FREE (save 5 BR)"
   - "Watch ad for hint" (trivia games)
   - "Watch ad for extra life"
   - **eCPM**: $10-25
   - **User acceptance**: 70-80%

2. **Interstitial Ads**
   - After every 3rd game attempt
   - Between game switches
   - When viewing leaderboard
   - **eCPM**: $5-12
   - **Frequency**: 2-3 per session

3. **Banner Ads** (Optional)
   - Bottom of leaderboard screen
   - Within game lobby
   - **eCPM**: $2-4
   - **Less intrusive, always visible**

**Ad Networks:**
- Primary: **AdMob** (already integrated)
- Secondary: **AppLovin MAX** (mediation)
- Backup: Facebook Audience Network

**Revenue**: 100% yours (no split)

---

### Phase 2 Weekly Rotation

**Updated 14-Week Cycle:**

| Week | Game | Source | Revenue Split |
|------|------|--------|---------------|
| 1 | Basketball Stars | GameDistribution | 50% |
| 2 | Sports Trivia Quiz | Custom Built | 100% |
| 3 | Penalty Shooters 2 | GameDistribution | 50% |
| 4 | Memory Match Sports | Purchased Template | 100% |
| 5 | 8 Ball Billiards | GameDistribution | 50% |
| 6 | Logo Quiz | Custom Built | 100% |
| 7 | Baseball Pro | GameDistribution | 50% |
| 8 | Higher or Lower | Custom Built | 100% |
| 9 | Golf Orbit | GameDistribution | 50% |
| 10 | Word Search | Purchased Template | 100% |
| 11 | Table Tennis | GameDistribution | 50% |
| 12 | Trivia Battle | Purchased Template | 100% |
| 13 | Racing Game | GameDistribution | 50% |
| 14 | Crossword Sports | Purchased Template | 100% |

**Rotation Strategy:**
- Alternate GD games with custom games
- Players always have fresh content
- Optimize mix based on engagement data

---

### Phase 2 Revenue Projections

**Blended Revenue Model:**

**Assumptions:**
- 50% of plays on GD games (50% rev-share)
- 50% of plays on custom games (100% revenue)
- 10,000 active users
- 10 plays per user per week

**Monthly Revenue Breakdown:**

| Source | Plays/Month | Ad Revenue | Your Share | Monthly Total |
|--------|-------------|------------|------------|---------------|
| GD Games | 200,000 | $6,000 | 50% | $3,000 |
| Custom Games | 200,000 | $6,000 | 100% | $6,000 |
| **Total** | **400,000** | **$12,000** | **75% avg** | **$9,000** |

**Compared to:**
- Phase 1 only (GD): $6,000/month (50% split)
- Phase 2 only (Custom): $12,000/month (100% yours)
- Hybrid: **$9,000/month (best of both)**

**Scaled Projections (Hybrid Model):**

| Active Users | Monthly Revenue (Hybrid) |
|--------------|--------------------------|
| 1,000 | $900 |
| 5,000 | $4,500 |
| 10,000 | $9,000 |
| 25,000 | $22,500 |
| 50,000 | $45,000 |

---

## Revenue Projections

### Detailed Revenue Model

**Revenue Streams:**
1. Ad impressions (primary)
2. BR entry fees (engagement driver)
3. BR prizes (retention mechanism)

### Ad Revenue Math

**Assumptions:**
- Average 10 plays per user per week
- 70% watch rewarded video ads
- 2 interstitial ads per session (3 plays = 1 session)
- 1 banner ad view per leaderboard check (2x per week)

**Per User Weekly Ad Impressions:**
- Rewarded videos: 7 views (70% × 10 plays)
- Interstitials: 6 views (10 plays / 3 × 2)
- Banners: 2 views (leaderboard checks)

**eCPM Rates:**
- Rewarded: $15 CPM
- Interstitial: $8 CPM
- Banner: $3 CPM

**Revenue per User per Month:**
- Rewarded: 28 views × $0.015 = $0.42
- Interstitial: 24 views × $0.008 = $0.19
- Banner: 8 views × $0.003 = $0.02
- **Total: $0.63 per user/month**

### Scaled Revenue Projections

| Active Users | Phase 1 (50%) | Phase 2 (100%) | Hybrid (75%) |
|--------------|---------------|----------------|--------------|
| 1,000 | $315 | $630 | $473 |
| 2,500 | $788 | $1,575 | $1,181 |
| 5,000 | $1,575 | $3,150 | $2,363 |
| 10,000 | $3,150 | $6,300 | $4,725 |
| 25,000 | $7,875 | $15,750 | $11,813 |
| 50,000 | $15,750 | $31,500 | $23,625 |
| 100,000 | $31,500 | $63,000 | $47,250 |

**Conservative estimates** - actual may be higher with:
- Seasonal events (Super Bowl, March Madness)
- Tournament modes (higher engagement)
- Premium users (more plays)

### BR Economy (Zero Real Cost)

**Weekly BR Flow:**

**BR Sinks (spent by players):**
- Average player: 10 plays × 5 BR = 50 BR/week
- 1,000 active players = 50,000 BR spent/week

**BR Faucets (earned by players):**
- Prize pool: 1,200 BR/week (top 10 winners)
- Ad rewards: 5 BR per rewarded video watch
  - 7,000 rewarded views/week × 5 BR = 35,000 BR

**Net BR Burn:**
- Spent: 50,000 BR
- Earned: 36,200 BR (prizes + ad rewards)
- **Net sink: 13,800 BR/week**

**Why this matters:**
- Players need to earn BR elsewhere (pool entries, bets)
- Creates cross-platform engagement
- Mini-games drive users to core betting features

---

## Technical Implementation

### Phase 1: GameDistribution Integration

**Step 1: Registration & Game Selection**

1. Register at https://gamedistribution.com/for-business
2. Complete onboarding questionnaire
3. Await partnership approval (typically 1-3 business days)
4. Login to Publisher Dashboard
5. Browse catalog filtered by:
   - Mobile-optimized: Yes
   - Sports category
   - English language (or your target languages)
   - Touch controls: Required
6. Test games in browser (mobile view)
7. Select 7 games for rotation
8. Copy iframe embed codes

**Step 2: Flutter WebView Wrapper**

**Create Reusable Mini-Game Widget:**

Basic structure needed:
- WebView that loads iframe URL
- JavaScript bridge for score capture (if possible)
- Ad trigger on WebView close
- Score submission to Firestore

**Key Features:**
- Load iframe in WebView
- Inject JavaScript to monitor game state
- Capture score when game ends (if possible)
- Close WebView and show ad
- Post score to Firestore leaderboard

**Step 3: Score Capture Strategy**

**Challenge**: GameDistribution games don't expose score APIs

**Solutions:**

**Option A: Manual Input (Simplest)**
- User plays game in WebView
- On close, prompt: "What was your score?"
- User types score
- Include screenshot requirement for top 10

**Option B: JavaScript Scraping**
- Inject JavaScript to read score from DOM
- Game-specific selectors (fragile)
- Requires reverse engineering each game

**Option C: Playtime Scoring**
- Score = seconds played
- Works for endless runners, survival games
- Doesn't work for goal-based games

**Recommendation**: Start with Option A (manual) for Phase 1, improve in Phase 2

**Step 4: Ad Integration Points**

**Your Ads (Outside GD Iframe):**

1. **On WebView Close:**
   - Interstitial ad OR
   - Rewarded video with incentive

2. **Leaderboard Screen:**
   - Banner ad at bottom
   - Rewarded video: "Watch ad for 10 BR bonus"

3. **Between Games:**
   - Interstitial when switching games

**Note**: GD also serves ads inside iframe (their revenue)

**Step 5: Firestore Integration**

**Collections Needed:**

```
/mini-games-config/{gameId}
/weekly-leaderboards/{gameId_weekId}/scores/{userId}
/user-mini-game-stats/{userId}
/prize-history/{weekId}
```

**Real-time Updates:**
- StreamBuilder for leaderboard
- Auto-refresh every 30 seconds
- Push notification on rank changes

---

### Phase 2: Custom Game Integration

**Step 1: Game Development/Purchase**

**For Purchased Templates:**
1. Buy from CodeCanyon/Chupamobile
2. Download source code
3. Import into Flutter project
4. Customize branding (colors, logos, sounds)
5. Implement scoring API
6. Test thoroughly

**For Custom Built Games:**
1. Design game mechanics (on paper first)
2. Create assets (graphics, sounds)
3. Implement with Flame engine
4. Build scoring system
5. Add animations and polish
6. Test with beta users

**Step 2: Native Game Architecture**

**File Structure:**
```
lib/
  screens/
    mini_games/
      game_lobby_screen.dart
      leaderboard_screen.dart
      games/
        trivia_game_screen.dart
        memory_match_game.dart
        logo_quiz_game.dart
  services/
    mini_game_service.dart
    leaderboard_service.dart
    mini_game_ad_service.dart
  models/
    mini_game.dart
    game_score.dart
    leaderboard_entry.dart
```

**Step 3: Ad Integration (Native)**

**AdMob Implementation:**

Key components needed:
- Load rewarded ads on game screen open
- Show after game complete
- Option: Watch ad for free play (deduct 0 BR) or pay 5 BR
- Interstitial ads after every 3 plays
- Pre-cache next ad for faster loading

**Ad Timing:**
- Load rewarded ad when game screen opens
- Show after game complete
- Load next ad immediately (pre-cache)

**Step 4: Score Validation**

**Server-Side Checks:**

Implement Cloud Function that:
- Gets reasonable score range for game
- Calculates mean and standard deviation
- Flags scores > 3 standard deviations from mean
- Notifies admin for manual review

**Client-Side Obfuscation:**
- Don't store score in plain SharedPreferences
- Use encrypted storage
- Validate score format server-side
- Rate limit score submissions

---

### Cross-Phase Considerations

**1. Leaderboard Persistence**

**Question**: What happens to old leaderboards?

**Solution**: Archive system
```
/leaderboards-archive/{year}/{weekNumber}/{gameId}
```

**Features:**
- "Hall of Fame" screen showing past winners
- Personal stats: "You've won 3 times!"
- All-time leaderboard (separate from weekly)

**2. Game Rotation Management**

**Firestore Config:**
```json
{
  "currentWeek": 3,
  "weekStartDate": "2025-01-15T00:00:00Z",
  "featuredGameId": "basketball_stars",
  "rotationSchedule": [
    {"week": 1, "gameId": "basketball_stars"},
    {"week": 2, "gameId": "trivia_quiz"},
    ...
  ]
}
```

**Auto-Rotation:**
- Cloud Function runs Monday 12:00 AM
- Updates currentWeek
- Archives previous leaderboard
- Distributes prizes automatically
- Sends push notifications

**3. Mixed Game Loading**

**Universal Game Launcher:**

Create a universal launcher that checks game platform:
- If "gamedistribution": Load WebView with iframe
- If "native": Load native Flutter game screen
- Same entry fee (5 BR)
- Same leaderboard UI
- Same prize structure
- Same social sharing
- Players don't notice difference

**Unified Experience:**
- Same entry fee (5 BR)
- Same leaderboard UI
- Same prize structure
- Same social sharing
- Players don't notice difference

---

## Leaderboard System

### Visual Design

**Top of Screen:**
```
┌─────────────────────────────────────┐
│  🏀 BASKETBALL STARS - Week 3       │
│  Ends in: 4d 12h 35m                │
│                                     │
│  🏆 1st Place: 500 BR               │
│  🥈 2nd Place: 250 BR               │
│  🥉 3rd Place: 100 BR               │
│  🎖️ 4th-10th: 50 BR each           │
└─────────────────────────────────────┘
```

**Leaderboard Table:**
```
┌─────────────────────────────────────┐
│ LIVE LEADERBOARD                    │
│                                     │
│ 🥇 1. ShotKing2024 ..... 12,450 pts│
│       Last played: 2h ago           │
│                                     │
│ 🥈 2. HoopsLegend ..... 11,890 pts │
│       Last played: 45m ago          │
│                                     │
│ 🥉 3. BucketGetter .... 11,200 pts │
│       Last played: 3h ago           │
│                                     │
│ 4. ThreePointer ....... 10,950 pts │
│ 5. DunkMaster ......... 10,100 pts │
│ ...                                 │
│ 42. 👤 YOU ............. 7,250 pts │
│       Rank: 42nd / 156 players     │
│       Attempts: 8 (40 BR spent)    │
│       Current Prize: 0 BR          │
│                                     │
│ [📊 My Stats] [🎮 Play Now] [📤 Share]│
└─────────────────────────────────────┘
```

**Bottom Actions:**
```
┌─────────────────────────────────────┐
│  🎯 Need 1,450 points to reach      │
│     Top 25 (50 BR prize)            │
│                                     │
│  [🎮 PLAY NOW - 5 BR]               │
│  [📺 Watch Ad to Play Free]         │
│  [📤 Challenge Friend]              │
└─────────────────────────────────────┘
```

### Real-Time Updates

**StreamBuilder Implementation:**

Use Firestore snapshots for real-time updates:
- Order by score descending
- Limit to top 100 for performance
- Highlight user's position
- Auto-scroll to user's rank on load

**Features:**
- Updates every time score changes (real-time)
- Push notification when rank changes significantly
- Smooth animations for rank movements
- Auto-refresh without user action

### Leaderboard Tiers View

**Toggle Between Views:**
- **Top 10**: Show only prize winners
- **Around Me**: Show 5 above, 5 below user
- **Full List**: Paginated, scroll to see all
- **Friends Only**: Filter to friends list

### Prize Projection Widget

**Dynamic Prize Indicator:**

Show users:
- "🎉 You're winning 100 BR!" (if in top 10)
- "🎯 150 points to reach 3rd place!" (if close)
- "Only 2 players between you and Top 10!" (motivation)

**Motivational Messaging:**
- "You're 150 points from 3rd place! 🔥"
- "Only 2 players between you and Top 10!"
- "You're in the prize zone! Hold your position!"

---

## Social Features

### Share Score Functionality

**After Each Game Completion:**

**Share Card Generation:**

Generate shareable image with:
- BR logo
- Game icon
- User score
- Rank
- "Can you beat me?" CTA
- App download link QR code

**Share Options:**
- SMS/iMessage
- WhatsApp
- Instagram Story
- Twitter/X
- Facebook
- Copy link
- System share sheet (native)

**Share Tracking:**
```
/share-events/{userId}/{timestamp}
  - gameId
  - score
  - rank
  - platform (twitter, instagram, etc)
  - clickthroughs (if trackable)
```

**Viral Incentives:**
- "Share your score to earn 10 BR bonus!"
- "Shared scores get 2x weight in leaderboard (for 1 hour)"
- Weekly prize for "Most Shared Score"

### Challenge Friends

**Direct Challenge Flow:**

1. User finishes game with great score
2. Tap "Challenge Friend" button
3. Select friend from contacts/app friends list
4. Friend receives push notification:
   - "ShotKing2024 scored 12,450 in Basketball Stars!"
   - "Think you can beat it? Play now!"
5. Friend plays game
6. If friend beats score: both get 25 BR bonus
7. If friend loses: challenger gets 10 BR bonus

**Benefits:**
- Re-engages dormant users
- Creates competitive atmosphere
- Drives repeat plays
- Builds community

### Friend Leaderboards

**Separate Tab:**
- "Global" leaderboard (everyone)
- "Friends" leaderboard (connected users only)

**Friend Connection Methods:**
- Phone contacts sync (with permission)
- In-app friend search by username
- Import from social media (Facebook, Twitter)
- QR code friend add

**Friend Stats:**
- Head-to-head record
- Most played games together
- Rivalry tracker

---

## Anti-Cheat & Fair Play

### Score Validation

**Server-Side Validation (Cloud Functions):**

Validation logic:
- Check if score is within possible range (min/max)
- Calculate z-score (standard deviations from mean)
- Flag if > 3 standard deviations
- Require manual review for top 3 finishers

**Automated Flags:**
- Score too high/low
- Submitted too quickly after game start
- Multiple high scores in short timespan
- Scores only submitted when near prize cutoff
- Device/IP associated with multiple accounts

### Account Security

**Requirements:**
- Phone number verification (SMS)
- Email confirmation
- Device fingerprinting
- IP logging

**Multi-Account Prevention:**
- One account per phone number
- Flag if same device/IP has multiple top-10 accounts
- Require 30-day account age to win prizes >100 BR

**Penalties:**
- 1st offense: Score removal, warning
- 2nd offense: 1-week ban from mini-games
- 3rd offense: Permanent ban from mini-games
- Egregious cheating: Account termination

### Screenshot Requirements (Top Winners)

**For Top 3 Finishers:**
- Must submit screenshot of final score screen
- Manual review by admin before prize payout
- Screenshot must match submitted score
- Timestamp must be within week window

**Automated Checking:**
- OCR to read score from screenshot
- Metadata verification (not edited)
- Reverse image search (not stolen)

### Fair Play Monitoring

**Analytics Dashboard:**
- Flag unusual patterns
- Monitor score distributions per game
- Track user behavior anomalies
- Review top 10 weekly before payout

**Community Reporting:**
- "Report Suspicious Score" button
- Community vote threshold triggers review
- Transparency reports published monthly

---

## Action Items & Timeline

### Phase 1 Launch Checklist (Weeks 1-3)

**Week 1: Partnership & Planning**

**Day 1-2: GameDistribution Setup**
- [ ] Register at gamedistribution.com/for-business
- [ ] Complete onboarding questionnaire
- [ ] Email partnership@azerion.com with:
  - Mobile app details
  - Expected user volume
  - Request revenue share percentage
  - Request mobile WebView embed confirmation
  - Request payment terms

**Day 3-4: Game Selection**
- [ ] Login to GD Publisher Dashboard
- [ ] Browse catalog with filters:
  - Mobile-optimized: Yes
  - Sports category
  - Touch controls
- [ ] Test 15-20 games in mobile browser
- [ ] Select final 7 games for rotation
- [ ] Document embed URLs and game IDs
- [ ] Screenshot game interfaces for UI design

**Day 5-7: Design & Planning**
- [ ] Design leaderboard UI mockups
- [ ] Design game lobby screen
- [ ] Design prize display widget
- [ ] Plan Firestore schema
- [ ] Write technical specification doc
- [ ] Create development tasks in project tracker

---

**Week 2: Development**

**Day 1-3: WebView Integration**
- [ ] Create MiniGameWebView widget
- [ ] Implement iframe loading
- [ ] Test with 1 game (Basketball Stars)
- [ ] Implement WebView close handler
- [ ] Add loading indicator
- [ ] Handle errors (connection, timeout)

**Day 4-5: Score System**
- [ ] Implement manual score input dialog
- [ ] Add score validation
- [ ] Create Firestore score submission
- [ ] Test score posting to leaderboard
- [ ] Implement "personal best" tracking

**Day 6-7: Leaderboard Screen**
- [ ] Create leaderboard UI
- [ ] Implement StreamBuilder for real-time updates
- [ ] Add user rank highlighting
- [ ] Add prize display widget
- [ ] Create "My Stats" section
- [ ] Test with mock data

---

**Week 3: Polish & Launch**

**Day 1-2: Ad Integration**
- [ ] Implement rewarded video ad loading
- [ ] Show ad after game completion
- [ ] Add "Watch ad to play free" option
- [ ] Implement interstitial ads
- [ ] Test ad frequency limits
- [ ] Verify ad revenue tracking

**Day 3-4: Social Features**
- [ ] Create share score card generator
- [ ] Implement share button
- [ ] Test share on iOS and Android
- [ ] Add share tracking analytics
- [ ] Create viral incentive system

**Day 5: Testing**
- [ ] Full QA testing on iOS
- [ ] Full QA testing on Android
- [ ] Test all 7 games in WebView
- [ ] Test leaderboard with multiple users
- [ ] Test prize distribution logic
- [ ] Load testing (simulate 100 concurrent users)

**Day 6-7: Launch**
- [ ] Deploy to production
- [ ] Enable Week 1 game (Basketball Stars)
- [ ] Send push notification to all users
- [ ] Monitor analytics dashboard
- [ ] Respond to user feedback
- [ ] Fix any critical bugs immediately

---

### Phase 1 Monitoring (Months 1-3)

**Weekly Tasks:**
- [ ] Monday 12:01 AM: Verify game rotation
- [ ] Monday 9:00 AM: Announce new game via push
- [ ] Daily: Monitor leaderboard for cheating
- [ ] Daily: Check ad revenue dashboard
- [ ] Sunday 11:59 PM: Archive leaderboard
- [ ] Monday 12:01 AM: Distribute prizes

**Monthly Review:**
- [ ] Analyze engagement metrics
- [ ] Review revenue vs projections
- [ ] Survey users for game preferences
- [ ] A/B test ad placements
- [ ] Optimize game rotation order
- [ ] Plan Phase 2 based on learnings

**Key Metrics to Track:**
- Weekly active users playing mini-games
- Average plays per user
- Ad view rates (rewarded vs interstitial)
- eCPM by game and ad type
- Share button click rate
- New user acquisition from shares
- Revenue per user
- Top 10 leaderboard churn rate

**Phase 1 Success Criteria:**
- [ ] 30%+ of active users play mini-games weekly
- [ ] Average 8+ plays per user per week
- [ ] $0.50+ revenue per active user per month
- [ ] 15%+ share rate after games
- [ ] 10%+ new users from viral shares
- [ ] <1% cheating incidents

---

### Phase 2 Preparation (Month 3)

**Decision Point:**
- [ ] Review Phase 1 metrics
- [ ] Decide: Proceed to Phase 2?
- [ ] If YES: Which games to build/buy?
- [ ] Budget approval for game purchases
- [ ] Allocate developer time (3-4 weeks)

**Game Selection Criteria:**
- Highest engagement games from Phase 1
- Most requested by users
- Easiest to build/customize
- Best ad revenue potential

**Development Planning:**
- [ ] Purchase 3-4 game templates from CodeCanyon
- [ ] Assign 2-3 games for custom development
- [ ] Create detailed game design docs
- [ ] Set up Flame engine project
- [ ] Design game assets (hire designer if needed)

---

### Phase 2 Development (Month 4)

**Week 1-2: Template Integration**
- [ ] Purchase templates
- [ ] Import into project
- [ ] Customize branding
- [ ] Implement ad integration (native)
- [ ] Connect to leaderboard system
- [ ] Test thoroughly

**Week 3-4: Custom Game Development**
- [ ] Build game mechanics
- [ ] Create assets and animations
- [ ] Implement scoring system
- [ ] Add sound effects
- [ ] Integrate ads
- [ ] Beta test with small group

**Week 5: Integration**
- [ ] Add custom games to rotation config
- [ ] Update game launcher to handle native games
- [ ] Test mixed rotation (GD + custom)
- [ ] Verify ad revenue tracking
- [ ] Final QA

**Week 6: Phase 2 Launch**
- [ ] Deploy custom games
- [ ] Announce new games via push notification
- [ ] Monitor performance vs GD games
- [ ] Gather user feedback
- [ ] Optimize based on data

---

### Ongoing Operations (Month 6+)

**Weekly:**
- Game rotation management
- Leaderboard monitoring
- Prize distribution
- Cheating review

**Monthly:**
- Performance analysis
- Revenue optimization
- New game additions (1-2 per quarter)
- User surveys

**Quarterly:**
- Major feature releases
- Tournament modes
- Seasonal events
- Partnership reviews

---

## Key Questions & Decisions Needed

### Immediate Decisions (Before Phase 1 Launch):

1. **GameDistribution Partnership Terms**
   - [ ] What is the exact revenue share %?
   - [ ] Payment minimums and schedule?
   - [ ] Can we add our own ads outside iframe?
   - [ ] WebView iframe embedding confirmed?

2. **Score Capture Method**
   - [ ] Manual input (honor system)?
   - [ ] JavaScript scraping (game-specific)?
   - [ ] Hybrid: Manual + screenshot for top 10?

3. **Launch Scope**
   - [ ] Launch with 1 game (test) or full 7-game rotation?
   - [ ] Beta test with small group first?
   - [ ] Phased rollout (10% → 50% → 100%)?

4. **Prize Structure**
   - [ ] Confirm: 500/250/100/50×7 BR weekly prizes?
   - [ ] Add: Monthly grand prize (5,000 BR)?
   - [ ] Include: Bonus prizes for streaks?

5. **Entry Fee**
   - [ ] Confirm: 5 BR per play?
   - [ ] Test: Dynamic pricing by game difficulty?
   - [ ] Include: Daily free play option?

### Phase 2 Decisions (Month 3):

1. **Investment Budget**
   - [ ] Allocate funds for game templates?
   - [ ] Hire external developer/designer?
   - [ ] In-house development only?

2. **Game Mix**
   - [ ] 50/50 GD vs custom games?
   - [ ] Phase out GD games entirely?
   - [ ] Keep GD for variety?

3. **Revenue Optimization**
   - [ ] A/B test ad placements?
   - [ ] Experiment with entry fees?
   - [ ] Test subscription model (ad-free)?

---

## Risk Mitigation

### Technical Risks

**Risk 1: WebView Performance**
- **Impact**: Games lag on low-end devices
- **Mitigation**:
  - Test on minimum spec devices (Android 8, iPhone 8)
  - Filter games by file size (<10MB)
  - Add loading screens with progress indicator
  - Fallback: "Device incompatible" message

**Risk 2: Score Capture Failure**
- **Impact**: Can't automatically get scores from GD games
- **Mitigation**:
  - Manual input as primary method
  - Screenshot verification for top winners
  - Clear instructions with examples
  - Anti-cheat validation server-side

**Risk 3: Ad Blocking**
- **Impact**: Users block ads, no revenue
- **Mitigation**:
  - Detect ad blocker, show warning
  - Require ad viewing for free plays
  - Don't block access, just no free plays
  - Use native in-app ads (harder to block)

### Business Risks

**Risk 1: Low Engagement**
- **Impact**: <10% of users play mini-games
- **Mitigation**:
  - Prominent placement in app nav
  - Push notifications for new games
  - BR bonuses for first-time play
  - Tutorial/onboarding flow

**Risk 2: GameDistribution Revenue Share Too Low**
- **Impact**: 70% to them, 30% to you = not profitable
- **Mitigation**:
  - Negotiate before signing
  - Accelerate Phase 2 timeline
  - Supplement with your own ads
  - Compare to alternatives (Poki, CrazyGames)

**Risk 3: Cheating Epidemic**
- **Impact**: Fake scores destroy leaderboard integrity
- **Mitigation**:
  - Strong anti-cheat from Day 1
  - Manual review of top 10 weekly
  - Community reporting
  - Harsh penalties (bans)

### Legal/Policy Risks

**Risk 1: GameDistribution Contract Issues**
- **Impact**: Unfavorable terms, can't terminate
- **Mitigation**:
  - Legal review before signing
  - Negotiate termination clause
  - Ensure you can use other platforms
  - Don't make them exclusive

**Risk 2: IP Infringement**
- **Impact**: Game template has stolen assets
- **Mitigation**:
  - Only purchase from reputable sources
  - Review license terms carefully
  - Check for trademark violations
  - Keep receipts and licenses

**Risk 3: App Store Policy Violations**
- **Impact**: App rejected for gambling-like features
- **Mitigation**:
  - BR has no real-world value (clearly stated)
  - No cash prizes or redemption
  - Age-gate if needed (13+)
  - Review Apple/Google policies

---

## Success Metrics & KPIs

### Primary Metrics

**Engagement:**
- Weekly Active Players (WAP): Target 30%+
- Average Plays per User per Week: Target 8+
- Average Session Length: Target 15+ minutes
- Return Rate (Week 2): Target 60%+

**Monetization:**
- Ad Revenue per User per Month: Target $0.50+
- Total Monthly Ad Revenue: Target $3,000+ (at 5K users)
- eCPM (Rewarded): Target $12+
- eCPM (Interstitial): Target $6+

**Growth:**
- Share Button Click Rate: Target 15%+
- New Users from Shares: Target 10%+
- Viral Coefficient: Target 0.15+

**Competition:**
- Leaderboard Check Frequency: Target 3+ per week
- Top 10 Participation Rate: Target 50+ unique users/week
- Prize Claim Rate: Target 100% (all winners claim)

### Secondary Metrics

**Game Performance:**
- Completion Rate: % who finish games
- Average Score per Game
- Score Distribution (detect outliers)
- Game Load Time (<3 seconds)

**Ad Performance:**
- Rewarded Ad Watch Rate: Target 70%+
- Interstitial Show Rate: Target 90%+
- Ad Error Rate: <5%
- Fill Rate: >95%

**User Behavior:**
- Peak Play Hours (optimize notifications)
- Most Popular Games (inform Phase 2)
- Entry Fee Sensitivity (price testing)
- Friend Challenge Rate

---

## Appendix

### Game Catalog Reference

**Phase 1: GameDistribution Games**

| Game Name | Sport | Platform | Touch Controls | Avg Playtime |
|-----------|-------|----------|----------------|--------------|
| Basketball Stars | Basketball | Poki/CrazyGames | Yes | 5 min |
| Penalty Shooters 2 | Soccer | Poki | Yes | 4 min |
| 8 Ball Billiards Classic | Billiards | Multi-platform | Yes | 6 min |
| Baseball Pro | Baseball | HTML5Games | Yes | 3 min |
| Golf Orbit | Golf | CrazyGames | Yes | 7 min |
| Table Tennis World Tour | Table Tennis | Multi-platform | Yes | 4 min |
| Ultimate Boxing | Combat | HTML5Games | Yes | 5 min |

**Phase 2: Custom/Template Games**

| Game Name | Type | Source | Dev Time | Cost |
|-----------|------|--------|----------|------|
| Sports Trivia Quiz | Native | Custom Built | 3 days | $0 |
| Memory Match Sports | Native | Template | 2 days | $29 |
| Logo Quiz | Native | Custom Built | 3 days | $0 |
| Higher or Lower | Native | Custom Built | 2 days | $0 |
| Word Search Sports | Native | Template | 2 days | $25 |
| Crossword Sports | Native | Template | 3 days | $35 |
| Trivia Battle | Native | Template | 2 days | $49 |

---

### Contact Information

**GameDistribution Partnership:**
- Email: partnership@azerion.com
- Website: https://gamedistribution.com/for-business
- Publisher Dashboard: https://gamedistribution.com/dev-panel

**Alternative Platforms:**
- Poki: https://developers.poki.com
- CrazyGames: https://developer.crazygames.com
- HTML5Games: http://html5games.com

**Game Template Sources:**
- CodeCanyon: https://codecanyon.net
- Chupamobile: https://www.chupamobile.com
- Unity Asset Store: https://assetstore.unity.com
- itch.io: https://itch.io

---

## Document Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Jan 2025 | Initial spec with Phase 1 only |
| 2.0 | Jan 2025 | Added Phase 2 and hybrid approach |
| 2.1 | Jan 2025 | Expanded implementation details, considerations, and full roadmap |

---

**Next Review Date**: End of Month 1 (Phase 1 Launch)
**Owner**: Bragging Rights Development Team
**Status**: Ready for Implementation

---

## Quick Reference: Key Numbers

| Metric | Target |
|--------|--------|
| Entry Fee | 5 BR |
| Weekly Prize Pool | 1,200 BR |
| 1st Place Prize | 500 BR |
| Game Rotation | 7 weeks (Phase 1) / 14 weeks (Phase 2) |
| Revenue per User | $0.63/month |
| Target Participation | 30% of active users |
| Phase 1 Duration | 3 months |
| Phase 2 Dev Time | 4-6 weeks |
| Expected Revenue (10K users, Hybrid) | $9,000/month |

---

**END OF DOCUMENT**
