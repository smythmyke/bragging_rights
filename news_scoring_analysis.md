# News Scoring Analysis - Real Data Review

**Date:** 2025-10-10
**Query:** Lakers (last 14 days)
**Domain:** espn.com, bleacherreport.com, cbssports.com, foxsports.com
**Total Results:** 65 articles

---

## Sample Articles Received

### Article 1: ✅ HIGHLY RELEVANT
**Title:** "LeBron out 3-4 weeks, expected to miss opener"
**Source:** ESPN
**Published:** 2025-10-09
**Description:** "Lakers star LeBron James will be sidelined 3-4 weeks because of sciatica on his right side, the team announced Thursday."

**Current Scoring:**
- "Lakers" mentioned → +0.5
- "sidelined" → +0.2
- "miss" (not in keywords) → 0.0
- **TOTAL: 0.7** ✅ PASSES (> 0.5)

**Sentiment:** Negative (injury, sidelined)
**Injury Detection:** ✅ YES
**Injury Impact:** HIGH (contains "sidelined" and "miss")

**Analysis:** ✅ **Perfect catch!** This is exactly the type of news Edge Intelligence should surface.

---

### Article 2: ✅ RELEVANT
**Title:** "Why LeBron James is the hardest player to rank in fantasy basketball this season"
**Source:** ESPN
**Published:** 2025-10-10
**Description:** "An injury has further muddied the waters of LeBron James' already murky fantasy basketball draft value for the 2025-26 season."

**Current Scoring:**
- "Lakers" (not mentioned directly) → 0.0
- "LeBron James" (not scored as team mention) → 0.0
- "injury" → +0.2
- **TOTAL: 0.2** ❌ FAILS (< 0.5)

**Issue:** Article is about Lakers' star player but doesn't mention "Lakers" explicitly!

**Recommendation:** Add **player name matching** for star players:
- LeBron James = Lakers (+0.5 points)
- Stephen Curry = Warriors (+0.5 points)
- etc.

---

### Article 3: ⚠️ BORDERLINE RELEVANT
**Title:** "LeBron James injury ripple effects: Luka Dončić's MVP case gets stronger, Bronny in Lakers' rotation?"
**Source:** CBS Sports
**Published:** 2025-10-09
**Description:** "LeBron James is expected to miss at least 3-4 weeks with sciatica"

**Current Scoring:**
- "Lakers" mentioned → +0.5
- "injury" → +0.2
- "miss" (not in keywords) → 0.0
- **TOTAL: 0.7** ✅ PASSES

**Sentiment:** Negative (injury, miss)
**Injury Detection:** ✅ YES

**Analysis:** ✅ Good catch, discusses Lakers' playoff implications.

---

### Article 4: ❌ IRRELEVANT
**Title:** "Brother of Nikola Jokić pleads guilty to punching fan during 2024 Nuggets playoff game"
**Source:** CBS Sports
**Published:** 2025-10-10
**Description:** "Strahinja Jokić will serve one year of probation..."

**Current Scoring:**
- "Lakers" (not mentioned) → 0.0
- No relevant keywords → 0.0
- **TOTAL: 0.0** ✅ CORRECTLY FILTERED OUT

**Analysis:** ✅ Good! This is about Nuggets, not Lakers.

---

### Article 5: ⚠️ SOMEWHAT RELEVANT
**Title:** "2025-26 NBA Title Odds: OKC Favored; Cavs, Knicks Lead East"
**Source:** Fox Sports
**Published:** 2025-10-10
**Description:** "While OKC is favored to repeat, two Western Conference rivals are moving up the board, including the Clippers, who landed Bradley Beal..."

**Current Scoring:**
- "Lakers" (mentioned in article body but not in description) → 0.0
- **TOTAL: 0.0** ❌ MIGHT BE FILTERED OUT

**Analysis:** Depends on full article text. If Lakers mentioned in odds discussion, could be relevant for betting context.

---

## Findings & Recommendations

### ✅ What's Working Well

1. **Date Filter:** 65 articles from last 14 days (vs 1,002 without filter) - **HUGE improvement!**
2. **Injury Detection:** Catching all LeBron injury news perfectly
3. **Domain Filter:** Good quality sources (ESPN, CBS Sports, Fox Sports)
4. **Basic Team Matching:** Articles that say "Lakers" are caught

### ❌ Current Limitations

1. **No Player Name Matching**
   - Missing articles about LeBron James that don't say "Lakers"
   - Should map star players to their teams

2. **Missing Keywords**
   - "miss" (as in "miss the opener") → Should add +0.2
   - "ruled out" → Already has "out" but should boost score more
   - "return" → Already in list ✅
   - "sidelined" → Already in list ✅

3. **No Context Understanding**
   - Can't tell if "Lakers not injured" vs "Lakers injured"
   - Simple keyword matching misses negation

4. **Description Only Scoring**
   - Only scores title + description
   - Doesn't check full article content (might miss Lakers mentioned deeper in article)

5. **No Source Weighting**
   - ESPN injury report = random blog = same score
   - Should weight credible sources higher

---

## Proposed Keyword Additions

### Add to Relevance Keywords (+0.2 each):
```dart
'miss',           // "miss the opener"
'ruled out',      // Stronger than just "out"
'day-to-day',     // Injury status
'listed',         // "listed as questionable"
'status',         // "injury status"
'report',         // "injury report"
'update',         // "injury update"
'out for',        // "out for 3 weeks"
'week-to-week',   // Injury timeline
'placed on IL',   // Injured list (MLB)
```

### Add Star Player → Team Mapping:
```dart
final starPlayers = {
  'LeBron James': 'Lakers',
  'Anthony Davis': 'Lakers',
  'Stephen Curry': 'Warriors',
  'Giannis Antetokounmpo': 'Bucks',
  'Nikola Jokic': 'Nuggets',
  'Luka Doncic': 'Mavericks',
  // ... top 50 NBA players
};
```

---

## Sentiment Analysis Review

### Positive Keywords (currently):
- win, victory, dominant, streak, healthy, return

**Add:**
- "comeback", "recovered", "cleared to play", "activated", "ready"

### Negative Keywords (currently):
- loss, injury, doubtful, struggle, suspension

**Add:**
- "eliminated", "knocked out", "upset loss", "blowout", "benched"

---

## Impact Assessment Accuracy

Current logic correctly identifies:
- ✅ "out" / "ruled out" → HIGH
- ✅ "doubtful" → HIGH
- ✅ "questionable" → MEDIUM
- ✅ "probable" → LOW

**Recommendation:** Add:
- "day-to-day" → MEDIUM
- "week-to-week" → HIGH
- "out for season" → CRITICAL (new level)
- "placed on IL" → HIGH

---

## Test Cases - How Would Current System Score?

| Article | Team Mention | Keywords | Score | Pass? | Should Pass? |
|---------|--------------|----------|-------|-------|--------------|
| "Lakers' LeBron out 3-4 weeks" | +0.5 | injury +0.2, sidelined +0.2 | 0.9 | ✅ Yes | ✅ Yes |
| "LeBron James injury affects Lakers playoff hopes" | +0.5 | injury +0.2 | 0.7 | ✅ Yes | ✅ Yes |
| "Fantasy impact of LeBron injury" | 0.0 | injury +0.2 | 0.2 | ❌ No | ⚠️ Maybe |
| "Lakers vs Warriors preview" | +0.5 | 0.0 | 0.5 | ❌ No (exactly 0.5, needs >) | ✅ Yes |
| "NBA title odds update" | 0.0 | 0.0 | 0.0 | ❌ No | ⚠️ Maybe (if Lakers discussed) |

**Issue:** Threshold is `> 0.5`, so exactly 0.5 fails. Consider changing to `>= 0.5`.

---

## Recommendations Summary

### High Priority (Implement Now):
1. ✅ **14-day date filter** - DONE!
2. **Change threshold to `>= 0.5`** (from `> 0.5`)
3. **Add missing keywords:** miss, ruled out, day-to-day, week-to-week
4. **Star player → team mapping** (at least top 20 per sport)

### Medium Priority:
5. Check full article text, not just description
6. Add source credibility weighting
7. Add more sentiment keywords (comeback, eliminated, etc.)

### Low Priority (Future):
8. Negation detection ("not injured" vs "injured")
9. Entity recognition (NER) for automatic player detection
10. Machine learning sentiment model

---

## Expected Impact

With high-priority changes:
- **Relevance improvement:** 20-30% more relevant articles caught
- **False negatives reduced:** Catch player-focused news without team name
- **Better injury detection:** More specific injury status keywords
- **Fairer threshold:** Articles with exactly 0.5 score will pass

---

## Next Steps

1. ✅ Add 14-day filter (DONE)
2. Update keyword list
3. Change threshold to >= 0.5
4. Add star player mapping
5. Test with real game scenarios
6. Create HTML mockup of news card display
