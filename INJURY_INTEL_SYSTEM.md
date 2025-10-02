# Injury Intelligence System - Build Plan
## ESPN Injury Data Integration & Intel Card Monetization

**Date:** January 2025
**Status:** Planning Phase
**Business Model:** BR-purchasable Intel Cards with injury insights
**Revenue Opportunity:** High-value information product

---

## Visual Reference: HTML Preview Template

A complete HTML preview template has been created to demonstrate the exact UI/UX design for Intel Cards: **`INJURY_INTEL_PREVIEW.html`**

This preview file showcases:
- ✅ Intel Card **locked state** with "💰 GET INTEL - 50 BR" purchase button
- ✅ Intel Card **unlocked state** with OWNED badge
- ✅ Complete injury report layout with **team logos** (Lakers & Warriors)
- ✅ Player injury cards with status badges (OUT, QUESTIONABLE)
- ✅ Injury details (type, expected return, comments)
- ✅ Impact scoring visualization
- ✅ Intel Insight section with betting recommendations
- ✅ All ESPN API fields demonstrated with real data structure

**Use this HTML template as the definitive design reference when implementing Flutter widgets.** All colors, spacing, layout, and data presentation patterns should match this preview.

---

## Executive Summary

ESPN provides comprehensive injury data for **team sports only** (NBA, NFL, MLB, NHL, Soccer). This data includes player status, injury details, expected return dates, and fantasy impact. We can leverage this data to create **premium "Intel Cards"** that users purchase with BR coins to gain competitive edge in their predictions.

**Key Insight:** Injury information is **critical for betting decisions** and significantly impacts game outcomes. By packaging this data into purchasable Intel Cards, we create a high-value BR sink that incentivizes BR purchases while providing genuine utility.

---

## Sports with Injury Data Available

### ✅ **Full Injury Support (Team Sports)**

| Sport | API Endpoint | Data Quality | Betting Impact | Priority |
|-------|--------------|--------------|----------------|----------|
| **NBA** | `/teams/{id}/injuries` | ⭐⭐⭐⭐⭐ Excellent | 🔥 Very High | **P0** |
| **NFL** | `/teams/{id}/injuries` | ⭐⭐⭐⭐⭐ Excellent | 🔥 Very High | **P0** |
| **MLB** | `/teams/{id}/injuries` | ⭐⭐⭐⭐ Good | 🔥 High | **P1** |
| **NHL** | `/teams/{id}/injuries` | ⭐⭐⭐⭐ Good | 🔥 High | **P1** |
| **Soccer** | `/teams/{id}/injuries` | ⭐⭐⭐ Moderate | 🔥 Moderate | **P2** |

### ❌ **No Injury Support (Individual Sports)**

| Sport | Reason | Workaround |
|-------|--------|------------|
| **MMA/UFC** | Individual athletes, no team roster | Fighter withdrawals handled at event level |
| **Boxing** | Individual athletes, event-based | Manual entry if fighter pulls out |
| **Tennis** | Individual athletes, tournament-based | Player withdrawals before match |

---

## ESPN Injury Data Structure

### **Complete Injury Object (NBA/NFL Example)**

```json
{
  "id": "497842",
  "longComment": "Strus underwent surgery on his fractured left foot on Aug. 26, with his expected recovery process being three to four months. De'Andre Hunter will likely see more time on the floor with Strus on the mend to start the upcoming 2025-26 season.",
  "shortComment": "Strus (foot) is no longer wearing a walking boot on Tuesday, but still has a lengthy recovery process ahead.",
  "status": "Out",
  "date": "2025-09-30T20:20Z",
  "athlete": {
    "$ref": "http://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/seasons/2025/athletes/4065778"
  },
  "team": {
    "$ref": "http://sports.core.api.espn.com/v2/sports/basketball/leagues/nba/seasons/2025/teams/5"
  },
  "type": {
    "id": "4",
    "name": "INJURY_STATUS_OUT",
    "description": "out",
    "abbreviation": "O"
  },
  "details": {
    "fantasyStatus": {
      "description": "OUT",
      "abbreviation": "OUT"
    },
    "type": "Foot",
    "location": "Leg",
    "detail": "Surgery",
    "side": "Left",
    "returnDate": "2025-12-01"
  }
}
```

### **Key Fields for Intel Cards**

| Field | Description | Intel Card Usage |
|-------|-------------|------------------|
| `status` | "Out", "Questionable", "Doubtful", "Day-to-Day" | **Critical** - Show player availability |
| `shortComment` | Brief injury update | **Display** - Quick summary |
| `longComment` | Detailed injury report | **Premium Detail** - Full context |
| `details.type` | Body part (Knee, Ankle, etc.) | **Analysis** - Injury severity indicator |
| `details.returnDate` | Expected return date | **Critical** - Timeline for availability |
| `type.abbreviation` | "O", "Q", "D", "DTD" | **UI Badge** - Visual status indicator |
| `date` | Last update timestamp | **Freshness** - Show how recent the info is |

---

## Intel Card System Design

### **Concept: Injury Intel Cards**

**What it is:**
Purchasable cards (using BR coins) that reveal injury information for specific games/teams. Users buy Intel Cards to gain competitive advantage in their predictions.

**Why it works:**
1. **Real Value**: Injury info directly impacts game outcomes (e.g., LeBron out = Lakers odds shift)
2. **Time-Sensitive**: Info becomes stale after game starts, creating urgency
3. **Variable Pricing**: Star player injuries = premium price
4. **BR Sink**: Encourages BR purchases to buy Intel
5. **Competitive Edge**: Players who invest in Intel have better win rates

---

### **Intel Card Types**

#### **1. Game Intel Card** (Recommended Starting Point)
**Price:** 50-100 BR
**Unlocks:** All injury reports for both teams in a specific game
**Use Case:** User wants to bet on Lakers vs Warriors, buys Game Intel to see injury reports

**Example Display:**
```
🏀 Lakers vs Warriors - Game Intel
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

LOS ANGELES INJURY REPORT:
❌ LeBron James - OUT (Ankle)
   └─ Expected Return: Dec 15
   └─ Last 5 Games: 28.4 PPG, 7.2 RPG

⚠️ Anthony Davis - QUESTIONABLE (Back)
   └─ Game-Time Decision
   └─ Played through similar in 3 of last 5

GOLDEN STATE INJURY REPORT:
✅ Stephen Curry - ACTIVE (No injuries)

💡 INTEL INSIGHT:
Lakers are 2-8 without LeBron this season.
Spread has moved from LAL -3.5 to GSW -1.5
```

---

#### **2. Team Season Intel** (Future Enhancement)
**Price:** 500 BR
**Unlocks:** All injury reports for a team for the entire season
**Use Case:** User follows Lakers all season, wants ongoing injury intel

---

#### **3. Star Player Intel** (Premium Tier)
**Price:** 200 BR
**Unlocks:** Detailed injury history and return timeline for specific star player
**Use Case:** User betting on LeBron props, wants deep dive on ankle injury

**Example Display:**
```
⭐ LeBron James - Injury Intel Pro
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

CURRENT STATUS: OUT (Left Ankle Sprain)
Expected Return: December 15, 2025

INJURY TIMELINE:
• Oct 30: Initial injury vs Suns (rolled ankle in Q3)
• Nov 5: MRI showed Grade 2 sprain
• Nov 12: Began on-court shooting
• Nov 20: 5-on-5 practice participation
• Nov 28: Expected to return within 2 weeks

PERFORMANCE IMPACT:
Before Injury: 29.8 PPG, 8.1 RPG, 6.9 APG
Historical Return Games (same injury):
  - 2022: 18 PPG first game back (72% normal output)
  - 2023: 24 PPG first game back (89% normal output)

BETTING INSIGHTS:
• Lakers are 2-8 without LeBron (20% win rate)
• Lakers ATS: 3-7 without LeBron
• Team O/U: 4-6 UNDER without LeBron
```

---

## Business Model & Monetization

### **Revenue Flow**

```
User buys BR coins ($)
    ↓
User spends BR on Intel Cards
    ↓
Better predictions = More VC earned
    ↓
More VC = Access to Elite Tournaments (gift card prizes)
    ↓
Users who invest in Intel have competitive advantage
    ↓
Higher conversion to BR purchases
```

---

### **Pricing Strategy**

| Intel Card Type | BR Cost | User Value | Use Case |
|----------------|---------|------------|----------|
| **Single Game Intel** | 50 BR | High | Betting on specific game |
| **Doubleheader Intel** | 80 BR | Very High | Multiple games same day |
| **Team Weekly Intel** | 200 BR | High | Following one team closely |
| **League Daily Intel** | 500 BR | Very High | Daily fantasy / heavy bettor |
| **Star Player Deep Dive** | 200 BR | Premium | Prop bets on star player |

**Pricing Philosophy:**
- **Game Intel (50 BR)** = Impulse purchase ($0.50 value)
- **Encourages daily engagement** (buy Intel for tonight's games)
- **Creates urgency** (Intel expires after game starts)
- **Repeat purchases** (need Intel for every game you bet on)

---

### **Revenue Projections**

**Conservative Scenario (100k Active Users):**

**Assumptions:**
- 10% of users buy Intel Cards regularly
- Average 3 cards per week per user
- Average price: 75 BR per card

**Weekly Revenue:**
```
100,000 users × 10% adoption = 10,000 Intel buyers
10,000 buyers × 3 cards/week = 30,000 cards sold
30,000 cards × 75 BR = 2,250,000 BR spent

At $0.01/BR (1,100 BR = $9.99):
2,250,000 BR ÷ 110 = ~$20,455/week
Annual: $1.06M from Intel Cards alone
```

**Optimistic Scenario (100k Active Users):**
- 20% adoption
- 5 cards per week
- Average price: 100 BR

**Weekly Revenue:**
```
100,000 × 20% × 5 cards × 100 BR = 10,000,000 BR
10,000,000 ÷ 110 = ~$90,909/week
Annual: $4.73M from Intel Cards alone
```

---

## Critical: Remove Existing Free Injury Displays

### ⚠️ **IMPORTANT: Injury Reports Must Be Paywalled**

Before implementing Intel Cards, we MUST remove all free injury displays from the app. Injury information is premium content that users will pay BR for.

#### **Files with Free Injury Displays (Must Remove):**

1. **`lib/screens/game/game_details_screen.dart`**
   - **Line 652:** Remove "Injuries" tab from NBA games
   - **Line 705:** Remove `_buildNBAInjuriesTab()` call
   - **Lines 7795-7900:** Delete entire `_buildNBAInjuriesTab()` method
   - **Lines 5736-5770:** Delete entire `_buildNFLInjuriesTab()` method
   - **Action:** Replace with "🔒 Unlock Injury Intel" placeholder that links to Intel Card purchase

2. **`lib/models/intel_product.dart`**
   - **Lines 42, 79-88:** Update "Injury Reports" product to point to new Intel Card system
   - **Action:** Change from free Edge product to BR-purchasable Intel Card

3. **`lib/services/edge/sports/nba_service.dart`**
   - **Check:** Ensure injury fetching is not exposed in any public methods
   - **Action:** Keep injury API methods private, only accessible through Intel Card purchase

4. **`lib/services/edge/sports/espn_nfl_service.dart`**
   - **Check:** Same as NBA - ensure injury data is not freely accessible

#### **Search Pattern to Find All Instances:**

```bash
# Command to find all injury references
grep -r "injur" bragging_rights_app/lib --include="*.dart" | grep -v "intel_card"
```

**Files Found (Need to Audit):**
- ✅ `lib/screens/game/game_details_screen.dart` - **REMOVE free tabs**
- ✅ `lib/models/intel_product.dart` - **UPDATE to Intel Card system**
- ⚠️ `lib/screens/betting/bet_selection_screen.dart` - **CHECK for free injury displays**
- ⚠️ `lib/screens/intel_detail_screen.dart` - **CHECK if showing free injury data**
- ⚠️ `lib/screens/premium/edge_screen.dart` - **CHECK Edge product displays**
- ⚠️ `lib/widgets/edge/edge_card_types.dart` - **CHECK if injury cards show data**
- ⚠️ `lib/services/edge/sports/espn_mlb_service.dart` - **CHECK MLB injuries**
- ⚠️ `lib/services/edge/sports/tennis_multi_api_service.dart` - **CHECK tennis (shouldn't have)**

---

### **Replacement UI for Free Injury Sections**

Instead of showing injury data for free, replace tabs with:

```dart
Widget _buildInjuryLockedPlaceholder() {
  return Container(
    padding: EdgeInsets.all(24),
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          PhosphorIcons.lockKey(PhosphorIconsStyle.duotone),
          size: 80,
          color: AppTheme.warningAmber,
        ),
        SizedBox(height: 16),
        Text(
          'Injury Intel Locked',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        SizedBox(height: 8),
        Text(
          'Unlock complete injury reports to gain competitive edge',
          textAlign: TextAlign.center,
          style: TextStyle(
            color: Colors.white70,
            fontSize: 14,
          ),
        ),
        SizedBox(height: 24),
        ElevatedButton.icon(
          onPressed: () => _showIntelCardPurchase(),
          icon: Icon(PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)),
          label: Text('Unlock for 50 BR'),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.warningAmber,
            minimumSize: Size(200, 50),
          ),
        ),
        SizedBox(height: 12),
        TextButton(
          onPressed: () => _showIntelExplainer(),
          child: Text('Why Intel Cards?'),
        ),
      ],
    ),
  );
}
```

---

## Icon Library: Phosphor Icons

### **Why Switch to Phosphor Icons?**

The app already has `phosphor_flutter: ^2.1.0` installed. Phosphor provides:

1. **6,000+ icons** vs Material's ~1,000
2. **Multiple styles:** Regular, Thin, Light, Bold, Fill, Duotone
3. **Better sports/gaming icons:** Cards, shields, locks, intelligence symbols
4. **Consistent design language:** All icons designed to work together
5. **Professional appearance:** More modern than default Material icons

### **Phosphor Icons for Intel Cards**

| Use Case | Material Icon (Old) | Phosphor Icon (New) | Why Better |
|----------|-------------------|-------------------|------------|
| **Intel Card** | `Icons.psychology` | `PhosphorIcons.brain(PhosphorIconsStyle.duotone)` | More distinctive, duotone adds depth |
| **Injury Report** | `Icons.health_and_safety` | `PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone)` | Medical theme, professional |
| **Locked Content** | `Icons.lock` | `PhosphorIcons.lockKey(PhosphorIconsStyle.duotone)` | More secure appearance |
| **Purchase/BR** | `Icons.monetization_on` | `PhosphorIcons.coins(PhosphorIconsStyle.fill)` | Clearer currency symbol |
| **Intelligence** | `Icons.lightbulb` | `PhosphorIcons.lightbulb(PhosphorIconsStyle.duotone)` | Same concept, better style |
| **Shield/Protection** | `Icons.shield` | `PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)` | Verified/trusted feeling |
| **Player Status** | `Icons.person` | `PhosphorIcons.userCircle(PhosphorIconsStyle.duotone)` | More polished |
| **Calendar/Return** | `Icons.calendar_today` | `PhosphorIcons.calendarCheck(PhosphorIconsStyle.regular)` | Shows expectation |
| **Warning/Alert** | `Icons.warning` | `PhosphorIcons.warningCircle(PhosphorIconsStyle.fill)` | More prominent |
| **Success/Available** | `Icons.check_circle` | `PhosphorIcons.checkCircle(PhosphorIconsStyle.fill)` | Cleaner design |

### **Phosphor Icon Styles**

```dart
// Regular (default)
PhosphorIcons.brain(PhosphorIconsStyle.regular)

// Bold (emphasis)
PhosphorIcons.brain(PhosphorIconsStyle.bold)

// Duotone (two-tone, premium look) ⭐ RECOMMENDED
PhosphorIcons.brain(PhosphorIconsStyle.duotone)

// Fill (solid)
PhosphorIcons.brain(PhosphorIconsStyle.fill)

// Thin (subtle)
PhosphorIcons.brain(PhosphorIconsStyle.thin)

// Light (delicate)
PhosphorIcons.brain(PhosphorIconsStyle.light)
```

### **Icon Migration Examples**

**Before (Material Icons):**
```dart
Icon(Icons.health_and_safety, color: AppTheme.warningAmber)
Icon(Icons.lock, size: 20, color: Colors.grey)
Icon(Icons.lightbulb, color: AppTheme.warningAmber, size: 20)
```

**After (Phosphor Icons):**
```dart
Icon(
  PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone),
  color: AppTheme.warningAmber,
)
Icon(
  PhosphorIcons.lockKey(PhosphorIconsStyle.duotone),
  size: 20,
  color: Colors.grey,
)
Icon(
  PhosphorIcons.lightbulb(PhosphorIconsStyle.duotone),
  color: AppTheme.warningAmber,
  size: 20,
)
```

### **Import Statement**

```dart
import 'package:phosphor_flutter/phosphor_flutter.dart';
```

---

## Implementation Plan

### **Phase 0: Remove Free Injury Displays (Week 1 - Day 1-2)** 🔴 **CRITICAL**

#### **Task 0.1: Audit All Injury References**

Run comprehensive search:
```bash
cd bragging_rights_app
grep -rn "injur" lib/ --include="*.dart" > injury_audit.txt
```

Review each file and determine:
- ❌ **Remove:** Free displays of injury data
- ✅ **Keep:** Service methods for fetching (will be paywalled)
- 🔄 **Update:** Edge products to point to new Intel Cards

#### **Task 0.2: Remove Free NBA Injury Tab**

**File:** `lib/screens/game/game_details_screen.dart`

**Changes:**
1. Remove "Injuries" tab from TabBar (line 652)
2. Replace with "Intel" tab
3. Delete `_buildNBAInjuriesTab()` method (lines 7795-7900)
4. Add `_buildIntelCardSection()` method
5. Show locked placeholder with "Unlock for 50 BR" button

#### **Task 0.3: Remove Free NFL Injury Tab**

**File:** `lib/screens/game/game_details_screen.dart`

**Changes:**
1. Delete `_buildNFLInjuriesTab()` method (lines 5736-5770)
2. Replace with Intel Card purchase option

#### **Task 0.4: Update Intel Products**

**File:** `lib/models/intel_product.dart`

**Changes:**
1. Update "Injury Reports" product (lines 79-88)
2. Change from free Edge product to BR-purchasable Intel Card
3. Add pricing information

#### **Task 0.5: Verify No Free Injury Displays Remain**

**Checklist:**
- [ ] Game details screen - no free injury tabs
- [ ] Bet selection screen - no injury hints
- [ ] Edge screen - injury product requires purchase
- [ ] Intel detail screen - shows purchase flow, not data
- [ ] All services keep injury methods private

---

### **Phase 1: Foundation (Week 1-2)**

#### **Task 1.1: Create Injury Service**
**New File:** `lib/services/injury_service.dart`

```dart
class InjuryService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Fetch team injuries from ESPN API
  Future<List<Injury>> getTeamInjuries({
    required String sport,
    required String league,
    required String teamId,
  }) async {
    final url = 'http://sports.core.api.espn.com/v2/sports/$sport/leagues/$league/teams/$teamId/injuries';

    final response = await http.get(Uri.parse(url));
    if (response.statusCode != 200) return [];

    final data = json.decode(response.body);
    final injuries = <Injury>[];

    // Fetch each injury reference
    for (final item in data['items']) {
      final injuryUrl = item['\$ref'];
      final injuryResponse = await http.get(Uri.parse(injuryUrl));

      if (injuryResponse.statusCode == 200) {
        final injuryData = json.decode(injuryResponse.body);
        injuries.add(Injury.fromESPN(injuryData));
      }
    }

    return injuries;
  }

  /// Get injuries for a specific game
  Future<GameInjuryReport> getGameInjuries({
    required String sport,
    required String homeTeamId,
    required String awayTeamId,
  }) async {
    final homeInjuries = await getTeamInjuries(
      sport: sport,
      league: _getLeague(sport),
      teamId: homeTeamId,
    );

    final awayInjuries = await getTeamInjuries(
      sport: sport,
      league: _getLeague(sport),
      teamId: awayTeamId,
    );

    return GameInjuryReport(
      homeTeam: homeTeamId,
      awayTeam: awayTeamId,
      homeInjuries: homeInjuries,
      awayInjuries: awayInjuries,
      fetchedAt: DateTime.now(),
    );
  }

  String _getLeague(String sport) {
    switch (sport.toLowerCase()) {
      case 'basketball': return 'nba';
      case 'football': return 'nfl';
      case 'baseball': return 'mlb';
      case 'hockey': return 'nhl';
      default: return '';
    }
  }
}
```

---

#### **Task 1.2: Create Injury Model**
**New File:** `lib/models/injury_model.dart`

```dart
class Injury {
  final String id;
  final String athleteId;
  final String athleteName;
  final String status;              // "Out", "Questionable", "Doubtful", "Day-to-Day"
  final String shortComment;
  final String longComment;
  final DateTime date;
  final InjuryDetails? details;
  final InjuryType type;

  Injury({
    required this.id,
    required this.athleteId,
    required this.athleteName,
    required this.status,
    required this.shortComment,
    required this.longComment,
    required this.date,
    this.details,
    required this.type,
  });

  factory Injury.fromESPN(Map<String, dynamic> json) {
    return Injury(
      id: json['id']?.toString() ?? '',
      athleteId: json['athlete']?['\$ref']?.split('/').last ?? '',
      athleteName: '', // Will be fetched separately
      status: json['status'] ?? 'Unknown',
      shortComment: json['shortComment'] ?? '',
      longComment: json['longComment'] ?? '',
      date: DateTime.parse(json['date'] ?? DateTime.now().toIso8601String()),
      details: json['details'] != null
          ? InjuryDetails.fromJSON(json['details'])
          : null,
      type: InjuryType.fromJSON(json['type'] ?? {}),
    );
  }

  // Severity based on status
  InjurySeverity get severity {
    switch (status.toLowerCase()) {
      case 'out':
        return InjurySeverity.out;
      case 'doubtful':
        return InjurySeverity.doubtful;
      case 'questionable':
        return InjurySeverity.questionable;
      default:
        return InjurySeverity.dayToDay;
    }
  }
}

class InjuryDetails {
  final String? type;               // "Knee", "Ankle", etc.
  final String? location;           // "Leg", "Arm", etc.
  final String? detail;             // "Surgery", "Sprain", etc.
  final String? side;               // "Left", "Right"
  final DateTime? returnDate;
  final FantasyStatus? fantasyStatus;

  InjuryDetails({
    this.type,
    this.location,
    this.detail,
    this.side,
    this.returnDate,
    this.fantasyStatus,
  });

  factory InjuryDetails.fromJSON(Map<String, dynamic> json) {
    return InjuryDetails(
      type: json['type'],
      location: json['location'],
      detail: json['detail'],
      side: json['side'],
      returnDate: json['returnDate'] != null
          ? DateTime.parse(json['returnDate'])
          : null,
      fantasyStatus: json['fantasyStatus'] != null
          ? FantasyStatus.fromJSON(json['fantasyStatus'])
          : null,
    );
  }
}

class InjuryType {
  final String name;                // "INJURY_STATUS_OUT"
  final String description;         // "out"
  final String abbreviation;        // "O"

  InjuryType({
    required this.name,
    required this.description,
    required this.abbreviation,
  });

  factory InjuryType.fromJSON(Map<String, dynamic> json) {
    return InjuryType(
      name: json['name'] ?? '',
      description: json['description'] ?? '',
      abbreviation: json['abbreviation'] ?? '',
    );
  }
}

class FantasyStatus {
  final String description;         // "OUT"
  final String abbreviation;        // "OUT"

  FantasyStatus({
    required this.description,
    required this.abbreviation,
  });

  factory FantasyStatus.fromJSON(Map<String, dynamic> json) {
    return FantasyStatus(
      description: json['description'] ?? '',
      abbreviation: json['abbreviation'] ?? '',
    );
  }
}

enum InjurySeverity {
  out,          // Definitely not playing
  doubtful,     // <25% chance of playing
  questionable, // 50/50 chance
  dayToDay,     // Minor, game-time decision
}

class GameInjuryReport {
  final String homeTeam;
  final String awayTeam;
  final List<Injury> homeInjuries;
  final List<Injury> awayInjuries;
  final DateTime fetchedAt;

  GameInjuryReport({
    required this.homeTeam,
    required this.awayTeam,
    required this.homeInjuries,
    required this.awayInjuries,
    required this.fetchedAt,
  });

  // Calculate impact score for betting
  double get homeImpactScore {
    return homeInjuries.fold(0.0, (sum, injury) {
      switch (injury.severity) {
        case InjurySeverity.out:
          return sum + 10.0; // Major impact
        case InjurySeverity.doubtful:
          return sum + 7.0;
        case InjurySeverity.questionable:
          return sum + 4.0;
        default:
          return sum + 1.0;
      }
    });
  }

  double get awayImpactScore {
    return awayInjuries.fold(0.0, (sum, injury) {
      switch (injury.severity) {
        case InjurySeverity.out:
          return sum + 10.0;
        case InjurySeverity.doubtful:
          return sum + 7.0;
        case InjurySeverity.questionable:
          return sum + 4.0;
        default:
          return sum + 1.0;
      }
    });
  }

  // Which team is more affected by injuries?
  String get advantageTeam {
    if (homeImpactScore > awayImpactScore + 5) {
      return awayTeam; // Away team has advantage
    } else if (awayImpactScore > homeImpactScore + 5) {
      return homeTeam; // Home team has advantage
    }
    return 'Even'; // Injuries cancel out
  }
}
```

---

### **Phase 2: Intel Card System (Week 3-4)**

#### **Task 2.1: Create Intel Card Model**
**New File:** `lib/models/intel_card_model.dart`

```dart
enum IntelCardType {
  gameInjuryReport,     // Single game, both teams
  teamWeeklyInjury,     // One team, week of games
  starPlayerDeepDive,   // Individual player analysis
  leagueDaily,          // All games for one day
}

class IntelCard {
  final String id;
  final IntelCardType type;
  final String title;
  final String description;
  final int brCost;
  final String? gameId;         // For game-specific Intel
  final String? teamId;         // For team-specific Intel
  final String? athleteId;      // For player-specific Intel
  final DateTime? expiresAt;    // Intel expires after game starts
  final String sport;

  IntelCard({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.brCost,
    this.gameId,
    this.teamId,
    this.athleteId,
    this.expiresAt,
    required this.sport,
  });

  bool get isExpired {
    if (expiresAt == null) return false;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get isActive {
    return !isExpired;
  }
}

class UserIntelCard {
  final String id;
  final String userId;
  final IntelCard card;
  final DateTime purchasedAt;
  final int brSpent;
  final GameInjuryReport? data; // Fetched injury data

  UserIntelCard({
    required this.id,
    required this.userId,
    required this.card,
    required this.purchasedAt,
    required this.brSpent,
    this.data,
  });

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'cardId': card.id,
      'cardType': card.type.toString(),
      'purchasedAt': purchasedAt.toIso8601String(),
      'brSpent': brSpent,
      'gameId': card.gameId,
      'teamId': card.teamId,
      'athleteId': card.athleteId,
      'expiresAt': card.expiresAt?.toIso8601String(),
    };
  }
}
```

---

#### **Task 2.2: Intel Card Service**
**New File:** `lib/services/intel_card_service.dart`

```dart
class IntelCardService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final WalletService _walletService = WalletService();
  final InjuryService _injuryService = InjuryService();

  /// Generate available Intel Cards for a game
  List<IntelCard> generateGameIntelCards(String gameId, String sport, DateTime gameTime) {
    return [
      IntelCard(
        id: '${gameId}_game_intel',
        type: IntelCardType.gameInjuryReport,
        title: 'Game Injury Intel',
        description: 'Complete injury reports for both teams',
        brCost: 50,
        gameId: gameId,
        expiresAt: gameTime,
        sport: sport,
      ),
    ];
  }

  /// Purchase Intel Card with BR
  Future<Map<String, dynamic>> purchaseIntelCard(
    String userId,
    IntelCard card,
  ) async {
    // Check if card is expired
    if (card.isExpired) {
      return {
        'success': false,
        'message': 'This Intel Card has expired',
      };
    }

    // Check if user already owns this card
    final existing = await _firestore
        .collection('user_intel_cards')
        .where('userId', isEqualTo: userId)
        .where('cardId', isEqualTo: card.id)
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) {
      return {
        'success': false,
        'message': 'You already own this Intel Card',
      };
    }

    // Deduct BR from wallet
    final paymentResult = await _walletService.deductBR(
      userId: userId,
      amount: card.brCost,
      reason: 'intel_card_purchase',
      metadata: {
        'cardId': card.id,
        'cardType': card.type.toString(),
        'gameId': card.gameId,
      },
    );

    if (!paymentResult['success']) {
      return {
        'success': false,
        'message': 'Insufficient BR balance',
      };
    }

    // Create user Intel Card
    final userCard = UserIntelCard(
      id: '${userId}_${card.id}_${DateTime.now().millisecondsSinceEpoch}',
      userId: userId,
      card: card,
      purchasedAt: DateTime.now(),
      brSpent: card.brCost,
    );

    await _firestore
        .collection('user_intel_cards')
        .doc(userCard.id)
        .set(userCard.toFirestore());

    // Log purchase for analytics
    await _logIntelCardPurchase(userId, card);

    return {
      'success': true,
      'message': 'Intel Card purchased successfully!',
      'userCardId': userCard.id,
    };
  }

  /// Get user's purchased Intel Cards
  Future<List<UserIntelCard>> getUserIntelCards(String userId) async {
    final snapshot = await _firestore
        .collection('user_intel_cards')
        .where('userId', isEqualTo: userId)
        .orderBy('purchasedAt', descending: true)
        .get();

    final cards = <UserIntelCard>[];
    for (final doc in snapshot.docs) {
      // Reconstruct UserIntelCard from Firestore
      // (simplified - would need full reconstruction logic)
      // cards.add(UserIntelCard.fromFirestore(doc));
    }

    return cards;
  }

  /// Fetch injury data for purchased Intel Card
  Future<GameInjuryReport?> getIntelCardData(UserIntelCard userCard) async {
    if (userCard.card.type == IntelCardType.gameInjuryReport) {
      // Fetch game details to get team IDs
      // Then fetch injury reports for both teams
      // Return GameInjuryReport
    }

    return null;
  }

  Future<void> _logIntelCardPurchase(String userId, IntelCard card) async {
    await _firestore.collection('analytics_intel_purchases').add({
      'userId': userId,
      'cardId': card.id,
      'cardType': card.type.toString(),
      'brCost': card.brCost,
      'sport': card.sport,
      'gameId': card.gameId,
      'purchasedAt': FieldValue.serverTimestamp(),
    });
  }
}
```

---

### **Phase 3: UI Components (Week 5-6)**

#### **Task 3.1: Intel Card Widget**
**New File:** `lib/widgets/intel_card_widget.dart`

```dart
class IntelCardWidget extends StatelessWidget {
  final IntelCard card;
  final bool owned;
  final VoidCallback onPurchase;

  const IntelCardWidget({
    Key? key,
    required this.card,
    required this.owned,
    required this.onPurchase,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: owned ? AppTheme.neonGreen : AppTheme.primaryCyan,
          width: 2,
        ),
      ),
      child: Container(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone),
                  color: AppTheme.warningAmber,
                  size: 24,
                ),
                SizedBox(width: 8),
                Expanded(
                  child: Text(
                    card.title,
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
                if (owned)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.neonGreen,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'OWNED',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),

            SizedBox(height: 12),

            Text(
              card.description,
              style: TextStyle(
                color: Colors.white70,
                fontSize: 14,
              ),
            ),

            SizedBox(height: 16),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Price
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.primaryCyan, AppTheme.secondaryCyan],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        PhosphorIcons.coins(PhosphorIconsStyle.fill),
                        size: 16,
                        color: Colors.white,
                      ),
                      SizedBox(width: 4),
                      Text(
                        '${card.brCost} BR',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),

                // Expiration
                if (card.expiresAt != null)
                  Row(
                    children: [
                      Icon(
                        PhosphorIcons.timer(PhosphorIconsStyle.regular),
                        size: 14,
                        color: Colors.white60,
                      ),
                      SizedBox(width: 4),
                      Text(
                        'Expires: ${_formatExpiration(card.expiresAt!)}',
                        style: TextStyle(
                          color: Colors.white60,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
              ],
            ),

            SizedBox(height: 12),

            ElevatedButton(
              onPressed: owned || card.isExpired ? null : onPurchase,
              style: ElevatedButton.styleFrom(
                backgroundColor: owned
                    ? Colors.grey
                    : card.isExpired
                        ? Colors.red.shade900
                        : AppTheme.warningAmber,
                minimumSize: Size(double.infinity, 44),
              ),
              child: Text(
                owned
                    ? 'VIEW INTEL'
                    : card.isExpired
                        ? 'EXPIRED'
                        : 'PURCHASE',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatExpiration(DateTime expiration) {
    final now = DateTime.now();
    final difference = expiration.difference(now);

    if (difference.inDays > 0) {
      return '${difference.inDays}d';
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h';
    } else {
      return '${difference.inMinutes}m';
    }
  }
}
```

---

#### **Task 3.2: Injury Report Display Widget**
**New File:** `lib/widgets/injury_report_widget.dart`

```dart
class InjuryReportWidget extends StatelessWidget {
  final GameInjuryReport report;
  final String homeTeamName;
  final String awayTeamName;

  const InjuryReportWidget({
    Key? key,
    required this.report,
    required this.homeTeamName,
    required this.awayTeamName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.surfaceBlue,
            AppTheme.surfaceBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.borderCyan.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            children: [
              Icon(Icons.health_and_safety, color: AppTheme.warningAmber),
              SizedBox(width: 8),
              Text(
                'INJURY REPORT',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: AppTheme.neonGreen,
                ),
              ),
            ],
          ),

          SizedBox(height: 16),

          // Away Team Injuries
          _buildTeamInjurySection(
            teamName: awayTeamName,
            injuries: report.awayInjuries,
            isHome: false,
          ),

          SizedBox(height: 16),

          Divider(color: AppTheme.borderCyan.withOpacity(0.3)),

          SizedBox(height: 16),

          // Home Team Injuries
          _buildTeamInjurySection(
            teamName: homeTeamName,
            injuries: report.homeInjuries,
            isHome: true,
          ),

          SizedBox(height: 16),

          // Intel Insight
          _buildIntelInsight(),
        ],
      ),
    );
  }

  Widget _buildTeamInjurySection({
    required String teamName,
    required List<Injury> injuries,
    required bool isHome,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$teamName INJURY REPORT',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: AppTheme.primaryCyan,
          ),
        ),

        SizedBox(height: 12),

        if (injuries.isEmpty)
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.neonGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: AppTheme.neonGreen.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppTheme.neonGreen, size: 20),
                SizedBox(width: 8),
                Text(
                  'No injuries reported',
                  style: TextStyle(
                    color: AppTheme.neonGreen,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          )
        else
          ...injuries.map((injury) => _buildInjuryItem(injury)).toList(),
      ],
    );
  }

  Widget _buildInjuryItem(Injury injury) {
    final statusColor = _getStatusColor(injury.severity);
    final statusIcon = _getStatusIcon(injury.severity);

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: statusColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  injury.athleteName,
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  injury.status.toUpperCase(),
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),

          if (injury.details?.type != null) ...[
            SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.local_hospital, size: 14, color: Colors.white60),
                SizedBox(width: 4),
                Text(
                  '${injury.details!.type} - ${injury.details!.detail ?? ""}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          if (injury.details?.returnDate != null) ...[
            SizedBox(height: 4),
            Row(
              children: [
                Icon(Icons.calendar_today, size: 14, color: Colors.white60),
                SizedBox(width: 4),
                Text(
                  'Expected Return: ${_formatDate(injury.details!.returnDate!)}',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ],

          if (injury.shortComment.isNotEmpty) ...[
            SizedBox(height: 8),
            Text(
              injury.shortComment,
              style: TextStyle(
                color: Colors.white60,
                fontSize: 12,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildIntelInsight() {
    final advantage = report.advantageTeam;

    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.warningAmber.withOpacity(0.2),
            AppTheme.warningAmber.withOpacity(0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AppTheme.warningAmber.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lightbulb, color: AppTheme.warningAmber, size: 20),
              SizedBox(width: 8),
              Text(
                'INTEL INSIGHT',
                style: TextStyle(
                  color: AppTheme.warningAmber,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),

          SizedBox(height: 8),

          Text(
            advantage == 'Even'
                ? 'Both teams similarly affected by injuries. Injury factor is neutral.'
                : '$advantage has the health advantage. Consider this in your betting decision.',
            style: TextStyle(
              color: Colors.white,
              fontSize: 13,
            ),
          ),

          SizedBox(height: 8),

          Row(
            children: [
              Text(
                'Injury Impact Score: ',
                style: TextStyle(color: Colors.white70, fontSize: 12),
              ),
              Text(
                'Home: ${report.homeImpactScore.toStringAsFixed(1)}',
                style: TextStyle(
                  color: report.homeImpactScore > report.awayImpactScore
                      ? Colors.red
                      : AppTheme.neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(' | ', style: TextStyle(color: Colors.white70, fontSize: 12)),
              Text(
                'Away: ${report.awayImpactScore.toStringAsFixed(1)}',
                style: TextStyle(
                  color: report.awayImpactScore > report.homeImpactScore
                      ? Colors.red
                      : AppTheme.neonGreen,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Color _getStatusColor(InjurySeverity severity) {
    switch (severity) {
      case InjurySeverity.out:
        return Colors.red;
      case InjurySeverity.doubtful:
        return Colors.orange;
      case InjurySeverity.questionable:
        return Colors.yellow;
      case InjurySeverity.dayToDay:
        return AppTheme.primaryCyan;
    }
  }

  IconData _getStatusIcon(InjurySeverity severity) {
    switch (severity) {
      case InjurySeverity.out:
        return Icons.cancel;
      case InjurySeverity.doubtful:
        return Icons.error;
      case InjurySeverity.questionable:
        return Icons.warning;
      case InjurySeverity.dayToDay:
        return Icons.info;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}
```

---

### **Phase 4: Integration & Testing (Week 7-8)**

#### **Task 4.1: Add Intel Card Purchase to Game Details Screen**

**Modify:** `lib/screens/games/game_details_screen.dart`

Add Intel Card section above betting options:

```dart
// Inside game details screen
if (sport == 'basketball' || sport == 'football') ...[
  SizedBox(height: 16),

  // Intel Cards Section
  Container(
    padding: EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(Icons.psychology, color: AppTheme.warningAmber),
            SizedBox(width: 8),
            Text(
              'INTEL CARDS',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: AppTheme.neonGreen,
              ),
            ),
          ],
        ),

        SizedBox(height: 12),

        Text(
          'Unlock injury reports and gain competitive edge',
          style: TextStyle(
            color: Colors.white70,
            fontSize: 12,
          ),
        ),

        SizedBox(height: 12),

        // Game Intel Card
        IntelCardWidget(
          card: _gameIntelCard,
          owned: _userOwnsIntelCard,
          onPurchase: _purchaseIntelCard,
        ),

        // If owned, show injury report
        if (_userOwnsIntelCard && _injuryReport != null) ...[
          SizedBox(height: 16),
          InjuryReportWidget(
            report: _injuryReport!,
            homeTeamName: game.homeTeam,
            awayTeamName: game.awayTeam,
          ),
        ],
      ],
    ),
  ),
],
```

---

### **Phase 5: Analytics & Optimization (Week 9-10)**

#### **Task 5.1: Intel Card Analytics**

**New File:** `lib/services/analytics/intel_card_analytics.dart`

```dart
class IntelCardAnalytics {
  static void logIntelCardViewed(IntelCard card) {
    FirebaseAnalytics.instance.logEvent(
      name: 'intel_card_viewed',
      parameters: {
        'card_id': card.id,
        'card_type': card.type.toString(),
        'br_cost': card.brCost,
        'sport': card.sport,
      },
    );
  }

  static void logIntelCardPurchased(IntelCard card, String userId) {
    FirebaseAnalytics.instance.logEvent(
      name: 'intel_card_purchased',
      parameters: {
        'card_id': card.id,
        'card_type': card.type.toString(),
        'br_cost': card.brCost,
        'sport': card.sport,
        'user_id': userId,
      },
    );
  }

  static void logIntelCardImpact(String userId, IntelCard card, bool wonBet) {
    FirebaseAnalytics.instance.logEvent(
      name: 'intel_card_impact',
      parameters: {
        'card_id': card.id,
        'user_id': userId,
        'won_bet': wonBet,
        'sport': card.sport,
      },
    );
  }
}
```

---

#### **Task 5.2: A/B Testing Intel Card Pricing**

Test different price points to optimize conversion:

```dart
class IntelCardPricingExperiments {
  static int getGameIntelPrice(String userId) {
    final experiment = _getUserExperiment(userId, 'intel_card_pricing');

    switch (experiment) {
      case 'variant_a':
        return 30;  // Lower price point
      case 'variant_b':
        return 50;  // Control
      case 'variant_c':
        return 75;  // Premium pricing
      default:
        return 50;
    }
  }
}
```

---

## Database Schema Changes

### **New Collections**

#### `intel_cards` (Available Intel Cards)
```javascript
intel_cards/{cardId} {
  id: string,
  type: 'gameInjuryReport' | 'teamWeeklyInjury' | 'starPlayerDeepDive',
  title: string,
  description: string,
  brCost: number,
  sport: string,
  gameId: string?,
  teamId: string?,
  athleteId: string?,
  expiresAt: timestamp?,
  createdAt: timestamp,
  isActive: boolean,
}
```

#### `user_intel_cards` (Purchased Intel Cards)
```javascript
user_intel_cards/{userCardId} {
  userId: string,
  cardId: string,
  cardType: string,
  purchasedAt: timestamp,
  brSpent: number,
  gameId: string?,
  teamId: string?,
  athleteId: string?,
  expiresAt: timestamp?,
  viewed: boolean,
  viewedAt: timestamp?,
}
```

#### `analytics_intel_purchases` (Purchase Tracking)
```javascript
analytics_intel_purchases/{purchaseId} {
  userId: string,
  cardId: string,
  cardType: string,
  brCost: number,
  sport: string,
  gameId: string?,
  purchasedAt: timestamp,
  userBRBalance: number,       // Balance before purchase
  userVCBalance: number,        // VC balance at purchase
  wonBet: boolean?,            // Track if Intel led to win
  betOutcomeTrackedAt: timestamp?,
}
```

---

## Testing Plan

### **Unit Tests**

1. **InjuryService Tests**
   - Test ESPN API parsing
   - Test team injury fetching
   - Test game injury report generation
   - Test injury impact scoring

2. **IntelCardService Tests**
   - Test card purchase with sufficient BR
   - Test card purchase with insufficient BR
   - Test duplicate purchase prevention
   - Test expired card purchase prevention

3. **Model Tests**
   - Test Injury.fromESPN() parsing
   - Test InjurySeverity calculations
   - Test GameInjuryReport.advantageTeam logic

### **Integration Tests**

1. **End-to-End Intel Card Purchase**
   - User views game → sees Intel Card → purchases → BR deducted → injury data unlocked

2. **Injury Data Refresh**
   - Test injury data caching
   - Test injury data expiration
   - Test real-time injury updates

### **User Testing**

1. **5-10 users** purchase Intel Cards for live games
2. Track conversion rates at different price points
3. Measure impact on bet success rate
4. Collect feedback on Intel value

---

## Launch Checklist

### **Pre-Launch (Week 10)**
- [ ] All backend services deployed
- [ ] Injury API integration tested
- [ ] Intel Card purchase flow tested
- [ ] BR deduction logic verified
- [ ] UI components polished
- [ ] Analytics tracking implemented
- [ ] A/B testing framework ready

### **Soft Launch (Week 11)**
- [ ] Release to 10% of users (NBA only)
- [ ] Monitor purchase conversion rates
- [ ] Track BR spending on Intel Cards
- [ ] Monitor injury data accuracy
- [ ] Collect user feedback
- [ ] Fix critical bugs

### **Full Launch (Week 12)**
- [ ] Release to 100% of users
- [ ] Add NFL Intel Cards
- [ ] Launch marketing campaign
- [ ] Create "How Intel Cards Work" tutorial
- [ ] Email campaign to existing users
- [ ] Monitor revenue impact

---

## Success Metrics

### **Primary KPIs**

- **Intel Card Purchase Rate:** % of users who buy at least one Intel Card per week
- **Intel Card Revenue:** Total BR spent on Intel Cards per week
- **BR Purchase Conversion:** % of Intel Card buyers who also purchase BR
- **Win Rate Impact:** Do Intel Card buyers have higher win rates?

### **Target Metrics (Month 3)**

- Intel Card Purchase Rate: 15-25%
- Average Intel Cards per buyer: 3-5 per week
- Intel Card Revenue: $15k-$30k per month (100k users)
- Win Rate Lift: +5-10% for Intel Card users

---

## Risk Mitigation

### **Data Accuracy Risks**

**Risk:** ESPN injury data is outdated or incorrect
**Mitigation:**
- Display "Last Updated" timestamp on all injury reports
- Refresh injury data every 30 minutes leading up to game time
- Add disclaimer: "Intel based on ESPN data - verify before betting"

### **User Perception Risks**

**Risk:** Users feel Intel Cards are "pay-to-win"
**Mitigation:**
- Frame as "information advantage" not guaranteed wins
- Offer free sample Intel Cards to new users
- Show that injury info is public data (we're aggregating it)

### **Legal Risks**

**Risk:** Intel Cards could be considered "insider information"
**Mitigation:**
- All data sourced from public ESPN API
- Clear disclosure that Intel is publicly available information
- Legal review before launch

---

## Future Enhancements

### **Phase 6: Advanced Intel Features (Post-Launch)**

1. **Historical Injury Impact Analysis**
   - "Team is 2-8 without LeBron this season"
   - "Player averages 18 PPG first game back from injury"

2. **Injury Severity Predictions**
   - Use ML to predict likelihood of player sitting out
   - "Questionable" players: 67% chance of playing (based on history)

3. **Lineup Intel Cards**
   - Show confirmed starting lineups when available
   - "Starters" vs "Bench depth" analysis

4. **Weather Intel Cards** (NFL)
   - Wind speed, temperature, precipitation forecasts
   - Impact on passing/kicking game

5. **Referee Intel Cards** (NBA/NFL)
   - Referee tendencies (fouls called, home/away bias)
   - "Tony Brothers calls 10% more fouls than league average"

6. **Matchup Intel Cards**
   - Head-to-head player statistics
   - "Player X is 8-2 vs Player Y in career matchups"

---

## Appendix

### **File Structure**

```
lib/
├── models/
│   ├── injury_model.dart (NEW)
│   └── intel_card_model.dart (NEW)
│
├── services/
│   ├── injury_service.dart (NEW)
│   └── intel_card_service.dart (NEW)
│
├── widgets/
│   ├── intel_card_widget.dart (NEW)
│   └── injury_report_widget.dart (NEW)
│
└── services/analytics/
    └── intel_card_analytics.dart (NEW)
```

### **External Dependencies**

```yaml
# pubspec.yaml (no new dependencies needed)
dependencies:
  http: ^1.1.0              # Already have
  firebase_analytics: ^10.8.0 # Already have
  cloud_firestore: ^4.13.0  # Already have
```

### **Marketing Copy for Intel Cards**

**In-App Messaging:**
```
🎯 GAIN THE EDGE

Injury Intel Cards reveal critical injury reports
before you bet. See who's OUT, QUESTIONABLE, or
ready to DOMINATE.

Smart bettors know: Information = Wins

💡 50 BR for complete game injury intel
```

**Push Notification:**
```
⚠️ LeBron listed as QUESTIONABLE for tonight's game!

Unlock Injury Intel for Lakers vs Warriors
to see full report and make smarter bets.

🔓 50 BR - Tap to unlock
```

---

**Document Version:** 1.0
**Last Updated:** January 2025
**Owner:** Product Team
**Status:** Ready for Review & Implementation
