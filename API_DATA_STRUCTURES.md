# API Data Structures Analysis

## 📊 Summary of Available Data

### ✅ NewsAPI - **WORKING**
**Endpoint:** `https://newsapi.org/v2/everything?q=NFL+injury&apiKey=XXX`

**Data Structure:**
```json
{
  "status": "ok",
  "totalResults": 5509,
  "articles": [
    {
      "source": {"id": null, "name": "Thechampaignroom.com"},
      "author": "SB Nation",
      "title": "...",
      "description": "...",
      "url": "...",
      "urlToImage": "...",
      "publishedAt": "2025-10-09T02:37:18Z",
      "content": "..."
    }
  ]
}
```

**Available Fields for Breaking News Card:**
- ✅ `title` - Headline (e.g., "Brock Purdy still sidelined by toe injury")
- ✅ `description` - Summary
- ✅ `source.name` - Publisher
- ✅ `publishedAt` - Timestamp
- ✅ `urlToImage` - Article image
- ✅ `content` - Partial article text

**Sample Headlines Found:**
1. "Brock Purdy still sidelined by toe injury, Mac Jones could start again for 49ers"
2. "Denver Broncos still mum on who will start in place of Ben Powers"
3. "Los Angeles Chargers named landing spot for 86-TD running back through trade"

**Intel Card Value:**
- 🔥 **Injury news** - Can detect QB/star player injuries
- 🔥 **Lineup changes** - Backup starters, trades
- 🔥 **Breaking trades** - Player movement
- ⏰ **Real-time** - Updates every few minutes

---

### ❌ Odds API - **QUOTA EXCEEDED**
**Error Response:**
```json
{
  "message": "Usage quota has been reached. See usage plans at https://the-odds-api.com",
  "error_code": "OUT_OF_USAGE_CREDITS",
  "details_url": "https://the-odds-api.com/liveapi/guides/v4/api-error-codes.html#out-of-usage-credits"
}
```

**🚨 CRITICAL FINDING:**
Your Odds API has **hit the monthly quota limit** (500 requests/month on free tier).

**Impact on Edge Cards:**
- ❌ **Betting Movement** card - Currently broken (no odds data)
- ❌ **Line Value Detector** - Can't build without odds
- ❌ **Public Fade Alert** - Needs odds movement

**Solutions:**
1. **Upgrade Plan** - $50/month for 10,000 requests
2. **Cache Aggressively** - Save odds to Firestore, reduce API calls
3. **Use Free Alternative** - ESPN has betting odds (less data, but free)

**Expected Data Structure (when working):**
```json
[
  {
    "id": "abc123",
    "sport_key": "basketball_nba",
    "commence_time": "2025-10-10T00:00:00Z",
    "home_team": "Los Angeles Lakers",
    "away_team": "Golden State Warriors",
    "bookmakers": [
      {
        "key": "fanduel",
        "title": "FanDuel",
        "markets": [
          {
            "key": "h2h",
            "outcomes": [
              {"name": "Lakers", "price": -150},
              {"name": "Warriors", "price": +130}
            ]
          }
        ]
      }
    ]
  }
]
```

---

### ✅ ESPN API - **WORKING**
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/football/nfl/scoreboard`

**Data Saved:** `espn_nfl_sample.json` (579KB)

**Available Data:**
- ✅ League info, season type
- ✅ Calendar (preseason, regular season, playoffs)
- ✅ Teams, scores, game status
- ✅ **Weather** (outdoor games)
- ✅ **Odds** (limited betting lines)
- ✅ **Injuries** (in team data)
- ✅ **Stats** (team performance)

**Intel Card Opportunities:**
- **Injury Intelligence** - Parse ESPN injury reports
- **Weather Impact** - Get wind/rain/temp for outdoor games
- **Matchup Analysis** - Team stats, recent form

---

## 🎯 Recommended Edge Cards (Based on Available Data)

### **Tier 1: Fully Supported (Build Now)**

1. ✅ **Breaking News** (NewsAPI)
   - Headlines, descriptions, timestamps
   - Injury news, trades, lineup changes
   - **Cost:** 20 BR (epic rarity)

2. ✅ **Injury Intelligence** (ESPN)
   - Player status (Out, Doubtful, Questionable)
   - Impact rating (QB injury = high impact)
   - **Cost:** 15 BR (rare rarity)

3. ✅ **Weather Impact** (ESPN)
   - Wind speed/direction
   - Temperature, precipitation
   - **Cost:** 10 BR (uncommon rarity)

4. ✅ **Matchup Analysis** (ESPN)
   - Team stats (PPG, offensive efficiency)
   - Head-to-head records
   - Recent form
   - **Cost:** 10 BR (uncommon rarity)

5. ✅ **Social Sentiment** (Reddit API)
   - Fan buzz, predictions
   - Community sentiment
   - **Cost:** 5 BR (common rarity)

### **Tier 2: Partially Supported (Build with Fallbacks)**

6. ⚠️ **Betting Movement** (ESPN as fallback)
   - ESPN has limited odds (not as detailed as Odds API)
   - Show moneyline only (no spread/total tracking)
   - **Cost:** 15 BR (rare rarity)

### **Tier 3: Cannot Build Yet (Wait for Odds API)**

7. ❌ **Line Value Detector** - Needs Odds API
8. ❌ **Public Fade Alert** - Needs Odds API + Reddit

---

## 💰 Odds API Quota Management

**Current Status:**
- Monthly Limit: 500 requests
- Status: **EXCEEDED**
- Reset: Next billing cycle

**Usage Optimization:**
1. **Cache to Firestore** - Save odds for 30-60 min
2. **Batch Requests** - Get all games at once, not individually
3. **Smart Refresh** - Only update odds for games starting soon (<3 hours)

**Cost to Upgrade:**
- **Starter:** $50/month for 10,000 requests
- **Pro:** $250/month for 100,000 requests

**Alternative:**
- Use ESPN odds (free, less data) for Betting Movement card
- Skip advanced cards (Line Value, Fade Alert) until budget allows

---

## 🔥 High-Value Intel Cards to Build First

### **1. Breaking News Card** (NewsAPI)
**What It Shows:**
- Last 5 injury/trade headlines
- Published time (e.g., "2m ago")
- Source (e.g., "ESPN", "Yahoo Sports")
- Link to full article

**Example:**
```
🚨 BREAKING NEWS
───────────────────
Brock Purdy sidelined with toe injury
Mac Jones may start for 49ers
📰 Yahoo Sports • 15m ago

Broncos starter Ben Powers out
Matt Peart expected to fill in
📰 Sporting News • 22m ago
```

**Value:** Massive - users get injury news before lines adjust

---

### **2. Injury Intelligence Card** (ESPN)
**What It Shows:**
- All injured players (starters highlighted)
- Status: Out ❌ | Doubtful 🟡 | Questionable ⚠️
- Position (QB injuries prioritized)
- Impact rating: High 🔴 | Medium 🟡 | Low 🟢

**Example:**
```
⚕️ INJURY REPORT
───────────────────
🔴 HIGH IMPACT
Brock Purdy (QB) - Out
Christian McCaffrey (RB) - Doubtful

🟡 MEDIUM IMPACT
Deebo Samuel (WR) - Questionable
George Kittle (TE) - Probable
```

**Value:** Critical for betting decisions

---

### **3. Weather Impact Card** (ESPN)
**What It Shows:**
- Temperature, wind, precipitation
- Impact rating on scoring
- Betting suggestion (Over/Under)

**Example:**
```
🌦️ WEATHER ALERT
───────────────────
🌬️ Wind: 18 mph (blowing out)
🌡️ Temp: 52°F
☁️ Conditions: Partly cloudy

📊 IMPACT: HIGH
Ball will carry 10-15 yards further
Favor long passes and fly balls

💡 SUGGESTION:
Consider OVER total points
```

**Value:** Huge for outdoor sports (MLB, NFL)

---

### **4. Matchup Analysis Card** (ESPN)
**What It Shows:**
- Team offensive/defensive rankings
- Head-to-head last 5 games
- Home/away splits
- Recent form (last 3 games)

**Example:**
```
📊 MATCHUP INTEL
───────────────────
OFFENSE vs DEFENSE
49ers (#3 offense) vs
Cowboys (#8 defense)

📈 TRENDS
49ers: 3-0 last 3 home games
Cowboys: 1-4 vs top-5 offenses

🏟️ H2H (Last 5)
49ers lead 4-1
Avg margin: 49ers by 8.2 pts
```

**Value:** Statistical edge

---

### **5. Social Sentiment Card** (Reddit)
**What It Shows:**
- Reddit fan confidence (r/49ers, r/cowboys)
- Most discussed topics
- Contrarian indicator (fade the public)

**Example:**
```
🗳️ FAN SENTIMENT
───────────────────
r/49ers: 78% confident (342 posts)
r/cowboys: 45% confident (189 posts)

🔥 HOT TAKES:
"49ers will dominate without Purdy"
"Cowboys defense will shut down CMC"

⚠️ CONTRARIAN ALERT:
Public heavily on 49ers (-7)
Sharp money may be on Cowboys +7
```

**Value:** Contrarian betting edge

---

## 🚀 Implementation Priority

**Week 1: Build Core 3 Cards**
1. Breaking News (NewsAPI) ✅
2. Injury Intelligence (ESPN) ✅
3. Weather Impact (ESPN) ✅

**Week 2: Add Analysis Cards**
4. Matchup Analysis (ESPN) ✅
5. Social Sentiment (Reddit) ✅

**Week 3: Upgrade Odds API**
6. Betting Movement (Odds API) ⚠️
   - OR use ESPN odds as placeholder

**Week 4: Advanced Cards (If Odds API upgraded)**
7. Line Value Detector
8. Public Fade Alert

---

## 📋 Action Items

### Immediate (This Week):
- [x] Remove unusable cards (Insider, Clutch, Power Cards)
- [ ] Build Breaking News card with NewsAPI
- [ ] Build Injury Intelligence card with ESPN
- [ ] Build Weather Impact card with ESPN

### Short-term (Next 2 Weeks):
- [ ] Add Matchup Analysis card
- [ ] Add Social Sentiment card
- [ ] Decide on Odds API upgrade ($50/month)

### Long-term (Month 2):
- [ ] If Odds API upgraded: Build Line Value Detector
- [ ] If Odds API upgraded: Build Public Fade Alert
- [ ] Add dynamic pricing (cards cost more near game time)
- [ ] Add bundle discounts (3+ cards = 20% off)

---

## 💡 Key Takeaways

1. **NewsAPI is GOLD** - Injury/trade news in real-time
2. **Odds API is DEAD** - Quota exceeded, need upgrade or alternative
3. **ESPN is SOLID** - Injuries, weather, stats all available
4. **6 Cards are Viable** - Focus on these, not impossible ones
5. **Upgrade Decision** - Need $50/month for Odds API or use ESPN odds

**Next Step:** Build the 3 core cards (News, Injury, Weather) with the working APIs!
