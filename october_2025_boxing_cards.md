# October 2025 Boxing Cards Analysis

## Overview
**Month:** October 2025
**Total Events from The Odds API:** 8 individual fights
**Grouped into:** 5 boxing cards using time-proximity algorithm
- **Multi-fight cards:** 2
- **Standalone fights:** 3

## Grouping Algorithm Used

Fights are grouped into cards based on:
1. **Same date** - Must occur on the same calendar day
2. **Time proximity** - Fights within 2.5 hours are considered part of the same card
3. **Main event designation** - The latest fight chronologically is considered the main event

---

## Boxing Cards Detected

### 📅 October 11, 2025 - Standalone Event
**Type:** Single Fight Card
**Location:** Unknown (The Odds API doesn't provide venue data)

| Time (UTC) | Fight | Event Type | Event ID |
|------------|-------|------------|----------|
| 21:00 | Arslanbek Makhmudov vs David Allen | Main Event | `4e4a3c15...` |

**Analysis:** Single fight event, likely a smaller promotion or preliminary card.

---

### 📅 October 12, 2025 - Multi-Fight Card 🔥
**Type:** Multi-Fight Card (2 fights detected)
**Potential Card Name:** "Ennis vs Lima"
**Time Span:** 1 hour between fights

| Time (UTC) | Fight | Event Type | Event ID |
|------------|-------|------------|----------|
| 02:00 | Jesse Hart vs Khalil Coe | Undercard | `9451b1f3...` |
| 03:00 | **Jaron Ennis vs Uisma Lima** | Main Event | `c8ca57ce...` |

**Analysis:**
- ✅ Successfully grouped 2 fights on same night
- Fights are 1 hour apart, typical for boxing card structure
- Jaron "Boots" Ennis is a rising welterweight star - this would be a significant main event

---

### 📅 October 17, 2025 - Standalone Event
**Type:** Single Fight Card
**Location:** Unknown

| Time (UTC) | Fight | Event Type | Event ID |
|------------|-------|------------|----------|
| 21:00 | George Liddard vs Kieron Conway | Main Event | `1e38ee0d...` |

**Analysis:** Single fight, possibly a British/European card based on fighter names.

---

### 📅 October 25, 2025 - Standalone Event
**Type:** Single Fight Card
**Location:** Unknown

| Time (UTC) | Fight | Event Type | Event ID |
|------------|-------|------------|----------|
| 21:00 | Fabio Wardley vs Joseph Parker | Main Event | `996e1363...` |

**Analysis:**
- Notable heavyweight bout between Joseph Parker (former WBO champion) and Fabio Wardley
- Surprising this appears as standalone - likely missing undercard data

---

### 📅 October 26, 2025 - Multi-Fight Card 🔥🔥
**Type:** Multi-Fight Card (3 fights detected)
**Potential Card Name:** "Fundora vs Thurman"
**Time Span:** 2 hours from first to last fight

| Time (UTC) | Fight | Event Type | Event ID |
|------------|-------|------------|----------|
| 02:00 | Shane Mosley Jr vs Jesus Alejandro Ramos Jr | Prelim | `6e9c1cf7...` |
| 03:00 | Stephen Fulton vs O'Shaquie Foster | Co-Main | `d3776e7c...` |
| 04:00 | **Sebastian Fundora vs Keith Thurman** | Main Event | `f58ac446...` |

**Analysis:**
- ✅ Successfully grouped 3 fights into single card
- Perfect 1-hour spacing between fights
- High-quality card with multiple championship-level fighters:
  - Fundora vs Thurman: Former champions at welterweight
  - Fulton vs Foster: Both former world champions
  - Mosley Jr: Son of legendary Shane Mosley
- This appears to be a premium boxing event (likely PPV)

---

## Algorithm Performance Analysis

### ✅ Successes
1. **October 12 Card**: Correctly grouped Hart-Coe and Ennis-Lima (1 hour apart)
2. **October 26 Card**: Successfully identified 3-fight card with proper hierarchy
3. **Time spacing detection**: Algorithm correctly identified 1-hour intervals as same card

### ⚠️ Limitations Identified

1. **Missing Undercard Data**
   - October 25: Parker vs Wardley likely has undercard fights not in The Odds API
   - October 11 & 17: Single fights probably have preliminary bouts not captured

2. **No Venue Information**
   - The Odds API doesn't provide location data
   - Can't confirm if fights are actually at same venue

3. **No Promotion/Event Names**
   - Can't identify if fights belong to specific promotions (Top Rank, PBC, DAZN, etc.)
   - Missing official event titles

---

## Comparison with Real World

### October 26 Card Deep Dive
The algorithm successfully identified what appears to be a major boxing event:

**What we detected:**
- 3 championship-caliber fights
- Proper time spacing (1 hour between fights)
- Logical fight order (biggest names last)

**What's likely missing:**
- 3-4 preliminary fights that would start earlier
- Official event name and promotion
- Venue and broadcast information

---

## Recommendations for Implementation

### 1. Filter Out Invalid Data
```dart
// Exclude December 31, 2025 fantasy fights
if (game.gameTime.year == 2025 &&
    game.gameTime.month == 12 &&
    game.gameTime.day == 31) {
  return false;
}
```

### 2. Group Algorithm Implementation
```dart
class BoxingCard {
  final DateTime date;
  final String cardName; // Use main event as name
  final List<BoxingFight> fights;
  final bool isMultiFight;

  String get mainEvent => fights.last.matchup;
  int get fightCount => fights.length;
}

List<BoxingCard> groupBoxingFights(List<GameModel> fights) {
  // Group by date
  // Then group by 2.5 hour windows
  // Sort fights chronologically within each card
  // Last fight = main event
}
```

### 3. Display Improvements Needed
- Show "Card includes X fights" when multiple detected
- Indicate "Additional prelim fights may not be shown"
- Add manual override to merge/split detected cards

---

## Conclusion

The time-proximity grouping algorithm **successfully identifies multi-fight boxing cards** from The Odds API data:

✅ **Works Well For:**
- Main card fights (typically 1 hour apart)
- Premium events with multiple title fights
- Detecting fight hierarchy (main event = last fight)

❌ **Limitations:**
- Missing preliminary/undercard fights
- No venue confirmation
- No official event names
- Can't distinguish between same-venue cards and separate events on same night

**Overall Assessment:** The algorithm provides a **good foundation** for grouping boxing fights, but needs supplementary data sources for complete fight cards. For October 2025, it successfully identified 2 multi-fight cards that appear to be legitimate boxing events based on fighter profiles and time spacing.