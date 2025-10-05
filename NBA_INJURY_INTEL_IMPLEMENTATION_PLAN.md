# NBA Injury Intel Card - Implementation Plan
**Date:** January 2025
**Status:** Planning Complete - Ready for Implementation
**Target:** Three-Level Intel Card System with BR Monetization

---

## 📋 Current Status Review

### ✅ Already Implemented

#### 1. **Backend Services** (Complete)
- ✅ `lib/services/injury_service.dart`
  - ESPN API integration working
  - `getTeamInjuries()` - fetches injuries for single team
  - `getGameInjuries()` - fetches injuries for both teams
  - `gameHasInjuries()` - quick check without full data fetch
  - Support for NBA, NFL, MLB, NHL, Soccer

#### 2. **Data Models** (Complete)
- ✅ `lib/models/injury_model.dart`
  - `Injury` class with ESPN parser
  - `InjuryDetails` with type, location, return date
  - `GameInjuryReport` with impact scoring
  - `InjurySeverity` enum (Out, Doubtful, Questionable, Day-to-Day)

#### 3. **Intel Card Infrastructure** (Partial)
- ✅ `lib/models/intel_card_model.dart`
  - `IntelCard` class
  - `UserIntelCard` class
  - `IntelCardType` enum
  - Firestore integration

- ✅ `lib/services/intel_card_service.dart`
  - `generateGameIntelCards()` - creates cards only if injuries exist
  - `purchaseIntelCard()` - BR payment integration
  - `userOwnsIntelCard()` - ownership check
  - Already checks for injuries before showing card

#### 4. **Widgets** (Partial)
- ✅ `lib/widgets/injury_report_widget.dart` - Display widget exists
- ✅ `lib/widgets/intel_card_widget.dart` - Card widget exists
- ⚠️ Need new widgets for three-level navigation

---

## ❌ Not Implemented / Needs Changes

### 1. **Bet Selection Screen Integration**
**File:** `lib/screens/betting/bet_selection_screen.dart`

**Current State:**
- ✅ `_availableIntel` Map exists (line 97)
- ✅ `_buildEdgeButton()` method exists (line 2421)
- ✅ Button shows injury indicators in corner
- ❌ Button shows **ALWAYS** - not conditional on injuries
- ❌ No async injury detection on page load
- ❌ Navigates to `/edge` route (old system) instead of new intel flow

**What Needs to Change:**
- Add injury detection when bet selection page loads
- Hide "Get The Edge" button if no injuries detected
- Change button icon from `Icons.bolt` to injury icon
- Navigate to new intel cards page (Level 1)

---

### 2. **Three-Level Navigation System**
**Current State:** Does NOT exist

**Needed Screens:**

#### **Level 1: Intel Type Selection** (NEW)
- **Route:** `/game_intelligence` or `/intel_types`
- **Widget:** `IntelTypeSelectionScreen` (needs creation)
- Shows grid of intel types (Injury, Analytics, Betting)
- Only shows types with available data
- Each tile shows preview stats

#### **Level 2: Team Purchase Options** (NEW)
- **Route:** `/injury_intel_purchase`
- **Widget:** `InjuryIntelPurchaseScreen` (needs creation)
- Shows 3 purchase cards:
  - Lakers only (30 BR)
  - Warriors only (30 BR)
  - Bundle (50 BR - save 10 BR)

#### **Level 3: Injury Report View** (PARTIAL - needs modification)
- **Route:** `/injury_report_view`
- **Widget:** `InjuryReportViewScreen` (needs creation)
- Shows purchased injury report
- Uses existing `InjuryReportWidget`
- Shows ownership badge
- Displays intel insight

---

### 3. **Team-Specific Intel Cards**
**Current State:** Only bundle card exists

**Needed in `intel_card_model.dart`:**
- Add `teamInjuryReport` to `IntelCardType` enum
- Support for team-specific cards

**Needed in `intel_card_service.dart`:**
- Modify `generateGameIntelCards()` to return 3 cards:
  - Home team card (30 BR)
  - Away team card (30 BR)
  - Bundle card (50 BR)

---

### 4. **Firestore Collections**
**Current State:** Partially defined

**Needed Collections:**

```
intel_cards/{cardId}
  - id, type, title, description, brCost
  - sport, gameId, teamId, expiresAt
  - createdAt, isActive

user_intel_cards/{userCardId}
  - userId, cardId, cardType, purchasedAt
  - brSpent, gameId, teamId, expiresAt
  - viewed, viewedAt, injuryData (cached)

analytics_intel_purchases/{purchaseId}
  - userId, cardId, cardType, brCost
  - sport, gameId, purchasedAt
  - userBRBalance, userVCBalance
```

---

## 🎯 Implementation Tasks

### **Phase 1: Bet Selection Integration** (Priority: P0)

#### Task 1.1: Add Injury Detection to Bet Selection
**File:** `lib/screens/betting/bet_selection_screen.dart`

**Changes:**
1. Add state variable for injury detection:
```dart
bool _isCheckingInjuries = false;
bool _hasInjuries = false;
```

2. Add method to check for injuries:
```dart
Future<void> _checkForInjuries() async {
  if (widget.sport.toLowerCase() != 'basketball') return;

  setState(() => _isCheckingInjuries = true);

  final injuryService = InjuryService();
  final hasInjuries = await injuryService.gameHasInjuries(
    sport: widget.sport,
    homeTeamId: _homeTeamEspnId,
    awayTeamId: _awayTeamEspnId,
  );

  setState(() {
    _hasInjuries = hasInjuries;
    _isCheckingInjuries = false;
    if (hasInjuries) {
      _availableIntel['injury'] = 'available';
    }
  });
}
```

3. Call in `initState()`:
```dart
@override
void initState() {
  super.initState();
  // ... existing code
  _checkForInjuries();
}
```

4. Update `_buildEdgeButton()`:
```dart
Widget _buildEdgeButton() {
  // Don't show button if no intel available
  if (_availableIntel.isEmpty) {
    return SizedBox.shrink();
  }

  // Show loading state while checking
  if (_isCheckingInjuries) {
    return Container(
      height: 80,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.grey.shade800, Colors.grey.shade700],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Center(
        child: CircularProgressIndicator(color: AppTheme.primaryCyan),
      ),
    );
  }

  return AnimatedBuilder(
    // ... existing animation code
    child: GestureDetector(
      onTap: _navigateToIntelTypes,  // NEW navigation
      child: Container(
        // ... existing container code
        children: [
          Icon(
            PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone), // NEW ICON
            color: Colors.white,
            size: 32,
          ),
          // ... rest of UI
        ],
      ),
    ),
  );
}
```

5. Update navigation method:
```dart
void _navigateToIntelTypes() {
  Navigator.pushNamed(
    context,
    '/intel_types',
    arguments: {
      'gameId': widget.gameData?.id,
      'gameTitle': widget.gameTitle,
      'sport': widget.sport,
      'homeTeamId': _homeTeamEspnId,
      'awayTeamId': _awayTeamEspnId,
      'homeTeamName': _homeTeam,
      'awayTeamName': _awayTeam,
      'gameTime': widget.gameData?.gameTime,
    },
  );
}
```

---

### **Phase 2: Level 1 - Intel Type Selection Screen** (Priority: P0)

#### Task 2.1: Create Intel Type Selection Screen
**New File:** `lib/screens/intel/intel_type_selection_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_theme.dart';

class IntelTypeSelectionScreen extends StatefulWidget {
  final String gameId;
  final String gameTitle;
  final String sport;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final DateTime? gameTime;

  const IntelTypeSelectionScreen({
    Key? key,
    required this.gameId,
    required this.gameTitle,
    required this.sport,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.gameTime,
  }) : super(key: key);

  @override
  State<IntelTypeSelectionScreen> createState() => _IntelTypeSelectionScreenState();
}

class _IntelTypeSelectionScreenState extends State<IntelTypeSelectionScreen> {
  bool _isLoadingInjuryStats = true;
  int _homeInjuryCount = 0;
  int _awayInjuryCount = 0;

  @override
  void initState() {
    super.initState();
    _loadInjuryStats();
  }

  Future<void> _loadInjuryStats() async {
    final injuryService = InjuryService();

    // Fetch injury counts for preview
    final report = await injuryService.getGameInjuries(
      sport: widget.sport,
      homeTeamId: widget.homeTeamId,
      homeTeamName: widget.homeTeamName,
      awayTeamId: widget.awayTeamId,
      awayTeamName: widget.awayTeamName,
    );

    setState(() {
      _homeInjuryCount = report?.homeInjuries.length ?? 0;
      _awayInjuryCount = report?.awayInjuries.length ?? 0;
      _isLoadingInjuryStats = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavy,
      appBar: AppBar(
        title: Text('Game Intelligence'),
        subtitle: Text('Select Intelligence Type'),
      ),
      body: Column(
        children: [
          _buildGameContext(),
          Expanded(
            child: _buildIntelTypeGrid(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContext() {
    // Game context bar (see HTML preview)
  }

  Widget _buildIntelTypeGrid() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        _buildIntelTypeTile(
          icon: PhosphorIcons.heartbeat(PhosphorIconsStyle.duotone),
          iconColor: Colors.red,
          title: 'Injury Intel',
          subtitle: 'Complete injury reports',
          description: 'Get detailed injury reports for both teams including player status, injury type, expected return dates, and game impact analysis.',
          isAvailable: true,
          stats: [
            IntelStat('${_homeInjuryCount + _awayInjuryCount}', 'Total'),
            IntelStat('$_homeInjuryCount', widget.homeTeamName),
            IntelStat('$_awayInjuryCount', widget.awayTeamName),
          ],
          onTap: () => _navigateToInjuryPurchase(),
        ),

        _buildIntelTypeTile(
          icon: PhosphorIcons.chartBar(PhosphorIconsStyle.duotone),
          iconColor: AppTheme.primaryCyan,
          title: 'Advanced Analytics',
          subtitle: 'Win probability & momentum',
          description: 'Real-time win probability charts, momentum tracking, and advanced team efficiency ratings.',
          isAvailable: false,
          comingSoon: true,
          onTap: null,
        ),

        _buildIntelTypeTile(
          icon: PhosphorIcons.target(PhosphorIconsStyle.duotone),
          iconColor: Colors.green,
          title: 'Betting Insights',
          subtitle: 'ATS records & trends',
          description: 'Against the spread performance, over/under trends, and historical betting outcomes.',
          isAvailable: false,
          comingSoon: true,
          onTap: null,
        ),
      ],
    );
  }

  Widget _buildIntelTypeTile({
    required IconData icon,
    required Color iconColor,
    required String title,
    required String subtitle,
    required String description,
    required bool isAvailable,
    List<IntelStat>? stats,
    bool comingSoon = false,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: isAvailable ? onTap : null,
      child: Container(
        margin: EdgeInsets.only(bottom: 12),
        padding: EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isAvailable
                ? [
                    AppTheme.surfaceBlue.withOpacity(0.8),
                    AppTheme.surfaceBlue.withOpacity(0.6),
                  ]
                : [
                    Colors.grey.shade800.withOpacity(0.3),
                    Colors.grey.shade900.withOpacity(0.3),
                  ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isAvailable
                ? AppTheme.primaryCyan.withOpacity(0.3)
                : Colors.grey.withOpacity(0.2),
            width: 2,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: iconColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: iconColor.withOpacity(0.3),
                    ),
                  ),
                  child: Icon(icon, color: iconColor, size: 28),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white60,
                        ),
                      ),
                    ],
                  ),
                ),
                if (comingSoon)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryCyan.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'COMING SOON',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                  )
                else if (isAvailable)
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppTheme.neonGreen, Colors.green.shade600],
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'AVAILABLE',
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.darkNavy,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(height: 12),
            Text(
              description,
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
                height: 1.5,
              ),
            ),
            if (stats != null && stats.isNotEmpty) ...[
              SizedBox(height: 12),
              Container(
                padding: EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  border: Border(
                    top: BorderSide(
                      color: AppTheme.primaryCyan.withOpacity(0.1),
                    ),
                  ),
                ),
                child: Row(
                  children: stats
                      .map((stat) => Expanded(
                            child: _buildStatItem(stat),
                          ))
                      .toList(),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(IntelStat stat) {
    return Container(
      padding: EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: AppTheme.primaryCyan.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        children: [
          Text(
            stat.value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppTheme.primaryCyan,
            ),
          ),
          SizedBox(height: 4),
          Text(
            stat.label,
            style: TextStyle(
              fontSize: 10,
              color: Colors.white50,
              textTransform: TextUpper case,
            ),
          ),
        ],
      ),
    );
  }

  void _navigateToInjuryPurchase() {
    Navigator.pushNamed(
      context,
      '/injury_intel_purchase',
      arguments: {
        'gameId': widget.gameId,
        'gameTitle': widget.gameTitle,
        'sport': widget.sport,
        'homeTeamId': widget.homeTeamId,
        'awayTeamId': widget.awayTeamId,
        'homeTeamName': widget.homeTeamName,
        'awayTeamName': widget.awayTeamName,
        'gameTime': widget.gameTime,
        'homeInjuryCount': _homeInjuryCount,
        'awayInjuryCount': _awayInjuryCount,
      },
    );
  }
}

class IntelStat {
  final String value;
  final String label;

  IntelStat(this.value, this.label);
}
```

---

### **Phase 3: Level 2 - Injury Intel Purchase Screen** (Priority: P0)

#### Task 3.1: Create Purchase Options Screen
**New File:** `lib/screens/intel/injury_intel_purchase_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../theme/app_theme.dart';
import '../../services/injury_service.dart';
import '../../services/intel_card_service.dart';
import '../../models/intel_card_model.dart';

class InjuryIntelPurchaseScreen extends StatefulWidget {
  final String gameId;
  final String gameTitle;
  final String sport;
  final String homeTeamId;
  final String awayTeamId;
  final String homeTeamName;
  final String awayTeamName;
  final DateTime? gameTime;
  final int homeInjuryCount;
  final int awayInjuryCount;

  const InjuryIntelPurchaseScreen({
    Key? key,
    required this.gameId,
    required this.gameTitle,
    required this.sport,
    required this.homeTeamId,
    required this.awayTeamId,
    required this.homeTeamName,
    required this.awayTeamName,
    this.gameTime,
    required this.homeInjuryCount,
    required this.awayInjuryCount,
  }) : super(key: key);

  @override
  State<InjuryIntelPurchaseScreen> createState() => _InjuryIntelPurchaseScreenState();
}

class _InjuryIntelPurchaseScreenState extends State<InjuryIntelPurchaseScreen> {
  final _intelCardService = IntelCardService();
  bool _isPurchasing = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavy,
      appBar: AppBar(
        title: Text('Injury Intel'),
        subtitle: Text('Choose Your Coverage'),
      ),
      body: Column(
        children: [
          _buildGameContext(),
          Expanded(
            child: _buildPurchaseOptions(),
          ),
        ],
      ),
    );
  }

  Widget _buildGameContext() {
    // Same as Level 1
  }

  Widget _buildPurchaseOptions() {
    return ListView(
      padding: EdgeInsets.all(16),
      children: [
        Text(
          'SELECT TEAM OR BUNDLE',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.bold,
            color: Colors.white70,
            letterSpacing: 1,
          ),
        ),
        SizedBox(height: 16),

        // Home Team Card
        _buildPurchaseCard(
          teamName: widget.homeTeamName,
          teamIcon: '🟣', // Use actual team logo
          subtitle: '${widget.homeTeamName} injury report only',
          injuryCount: widget.homeInjuryCount,
          price: 30,
          isBundle: false,
          onPurchase: () => _purchaseCard('home'),
        ),

        // Away Team Card
        _buildPurchaseCard(
          teamName: widget.awayTeamName,
          teamIcon: '🔵', // Use actual team logo
          subtitle: '${widget.awayTeamName} injury report only',
          injuryCount: widget.awayInjuryCount,
          price: 30,
          isBundle: false,
          onPurchase: () => _purchaseCard('away'),
        ),

        // Bundle Card
        _buildPurchaseCard(
          teamName: 'Full Game Bundle',
          teamIcon: '⭐',
          subtitle: 'Both teams + comparative analysis',
          injuryCount: widget.homeInjuryCount + widget.awayInjuryCount,
          price: 50,
          originalPrice: 60,
          savingsBadge: 'SAVE 10 BR',
          isBundle: true,
          onPurchase: () => _purchaseCard('bundle'),
        ),
      ],
    );
  }

  Widget _buildPurchaseCard({
    required String teamName,
    required String teamIcon,
    required String subtitle,
    required int injuryCount,
    required int price,
    int? originalPrice,
    String? savingsBadge,
    bool isBundle = false,
    required VoidCallback onPurchase,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isBundle
            ? LinearGradient(
                colors: [
                  AppTheme.warningAmber.withOpacity(0.1),
                  AppTheme.warningAmber.withOpacity(0.05),
                ],
              )
            : LinearGradient(
                colors: [
                  AppTheme.surfaceBlue.withOpacity(0.8),
                  AppTheme.surfaceBlue.withOpacity(0.6),
                ],
              ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isBundle
              ? AppTheme.warningAmber.withOpacity(0.4)
              : AppTheme.primaryCyan.withOpacity(0.2),
          width: isBundle ? 2 : 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                teamIcon,
                style: TextStyle(fontSize: 24),
              ),
              SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      teamName,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white60,
                      ),
                    ),
                  ],
                ),
              ),
              if (savingsBadge != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppTheme.warningAmber, Colors.orange.shade600],
                    ),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    savingsBadge,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ),
            ],
          ),

          SizedBox(height: 12),

          // Preview
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.red.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.red.withOpacity(0.2),
              ),
            ),
            child: Text(
              'Preview: $injuryCount ${injuryCount == 1 ? "injury" : "injuries"} detected',
              style: TextStyle(
                fontSize: 13,
                color: Colors.white70,
              ),
            ),
          ),

          SizedBox(height: 12),

          // Purchase Button
          Row(
            children: [
              Container(
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.primaryCyan.withOpacity(0.1),
                  border: Border.all(
                    color: AppTheme.primaryCyan.withOpacity(0.3),
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Icon(
                      PhosphorIcons.coins(PhosphorIconsStyle.fill),
                      color: AppTheme.primaryCyan,
                      size: 20,
                    ),
                    SizedBox(width: 6),
                    Text(
                      '$price',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: AppTheme.primaryCyan,
                      ),
                    ),
                    if (originalPrice != null) ...[
                      SizedBox(width: 6),
                      Text(
                        '$originalPrice',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.white40,
                          decoration: TextDecoration.lineThrough,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: _isPurchasing ? null : onPurchase,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isBundle
                        ? AppTheme.warningAmber
                        : AppTheme.primaryCyan,
                    padding: EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    _isPurchasing
                        ? 'Processing...'
                        : (isBundle ? '🔥 Unlock Bundle' : 'Unlock Intel'),
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: isBundle ? Colors.white : AppTheme.darkNavy,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _purchaseCard(String cardType) async {
    setState(() => _isPurchasing = true);

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      // Show login prompt
      setState(() => _isPurchasing = false);
      return;
    }

    // Create appropriate intel card based on selection
    IntelCard card;
    if (cardType == 'bundle') {
      card = IntelCard(
        id: '${widget.gameId}_bundle',
        type: IntelCardType.gameInjuryReport,
        title: 'Full Game Injury Intel',
        description: 'Both teams + analysis',
        brCost: 50,
        gameId: widget.gameId,
        expiresAt: widget.gameTime,
        sport: widget.sport,
      );
    } else if (cardType == 'home') {
      card = IntelCard(
        id: '${widget.gameId}_home',
        type: IntelCardType.teamInjuryReport, // NEW type needed
        title: '${widget.homeTeamName} Injury Intel',
        description: 'Home team injuries',
        brCost: 30,
        gameId: widget.gameId,
        teamId: widget.homeTeamId,
        expiresAt: widget.gameTime,
        sport: widget.sport,
      );
    } else {
      card = IntelCard(
        id: '${widget.gameId}_away',
        type: IntelCardType.teamInjuryReport, // NEW type needed
        title: '${widget.awayTeamName} Injury Intel',
        description: 'Away team injuries',
        brCost: 30,
        gameId: widget.gameId,
        teamId: widget.awayTeamId,
        expiresAt: widget.gameTime,
        sport: widget.sport,
      );
    }

    final result = await _intelCardService.purchaseIntelCard(
      userId: user.uid,
      card: card,
    );

    setState(() => _isPurchasing = false);

    if (result.success) {
      // Navigate to Level 3 - Report View
      Navigator.pushNamed(
        context,
        '/injury_report_view',
        arguments: {
          'userCard': result.userCard,
          'cardType': cardType,
        },
      );
    } else {
      // Show error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(result.message)),
      );
    }
  }
}
```

---

### **Phase 4: Level 3 - Injury Report View Screen** (Priority: P0)

#### Task 4.1: Create Report View Screen
**New File:** `lib/screens/intel/injury_report_view_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:phosphor_flutter/phosphor_flutter.dart';
import '../../theme/app_theme.dart';
import '../../models/intel_card_model.dart';
import '../../services/injury_service.dart';
import '../../widgets/injury_report_widget.dart';

class InjuryReportViewScreen extends StatefulWidget {
  final UserIntelCard userCard;
  final String cardType; // 'home', 'away', or 'bundle'

  const InjuryReportViewScreen({
    Key? key,
    required this.userCard,
    required this.cardType,
  }) : super(key: key);

  @override
  State<InjuryReportViewScreen> createState() => _InjuryReportViewScreenState();
}

class _InjuryReportViewScreenState extends State<InjuryReportViewScreen> {
  bool _isLoading = true;
  GameInjuryReport? _report;

  @override
  void initState() {
    super.initState();
    _loadInjuryData();
  }

  Future<void> _loadInjuryData() async {
    // Check if data is cached in user card
    if (widget.userCard.injuryData != null) {
      setState(() {
        _report = widget.userCard.injuryData;
        _isLoading = false;
      });
      return;
    }

    // Fetch fresh injury data
    final injuryService = InjuryService();
    // Need to extract team IDs from game data
    // This would require passing more context or fetching game data

    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.darkNavy,
      appBar: AppBar(
        title: Text('Full Game Injury Intel'),
        subtitle: Text('Complete Report'),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Column(
              children: [
                _buildGameContext(),
                _buildOwnershipBadge(),
                Expanded(
                  child: _report != null
                      ? InjuryReportWidget(
                          report: _report!,
                          showTeams: widget.cardType,
                        )
                      : _buildNoDataState(),
                ),
              ],
            ),
    );
  }

  Widget _buildGameContext() {
    // Same as previous levels
  }

  Widget _buildOwnershipBadge() {
    return Container(
      margin: EdgeInsets.all(16),
      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppTheme.neonGreen, Colors.green.shade600],
        ),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            PhosphorIcons.checkCircle(PhosphorIconsStyle.fill),
            color: AppTheme.darkNavy,
            size: 20,
          ),
          SizedBox(width: 8),
          Text(
            'Owned - Purchased for ${widget.userCard.brSpent} BR',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.bold,
              color: AppTheme.darkNavy,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoDataState() {
    return Center(
      child: Text(
        'No injury data available',
        style: TextStyle(color: Colors.white70),
      ),
    );
  }
}
```

---

### **Phase 5: Routes & Navigation** (Priority: P0)

#### Task 5.1: Register Routes
**File:** `lib/main.dart` (or wherever routes are defined)

```dart
routes: {
  '/intel_types': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return IntelTypeSelectionScreen(
      gameId: args['gameId'],
      gameTitle: args['gameTitle'],
      sport: args['sport'],
      homeTeamId: args['homeTeamId'],
      awayTeamId: args['awayTeamId'],
      homeTeamName: args['homeTeamName'],
      awayTeamName: args['awayTeamName'],
      gameTime: args['gameTime'],
    );
  },
  '/injury_intel_purchase': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return InjuryIntelPurchaseScreen(
      gameId: args['gameId'],
      gameTitle: args['gameTitle'],
      sport: args['sport'],
      homeTeamId: args['homeTeamId'],
      awayTeamId: args['awayTeamId'],
      homeTeamName: args['homeTeamName'],
      awayTeamName: args['awayTeamName'],
      gameTime: args['gameTime'],
      homeInjuryCount: args['homeInjuryCount'],
      awayInjuryCount: args['awayInjuryCount'],
    );
  },
  '/injury_report_view': (context) {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, dynamic>;
    return InjuryReportViewScreen(
      userCard: args['userCard'],
      cardType: args['cardType'],
    );
  },
},
```

---

### **Phase 6: Model Updates** (Priority: P1)

#### Task 6.1: Add Team-Specific Intel Card Type
**File:** `lib/models/intel_card_model.dart`

```dart
enum IntelCardType {
  gameInjuryReport,     // Both teams (bundle)
  teamInjuryReport,     // Single team (NEW)
  teamWeeklyInjury,
  starPlayerDeepDive,
  leagueDaily,
}
```

---

### **Phase 7: Firestore Security Rules** (Priority: P1)

```javascript
// rules for user_intel_cards collection
match /user_intel_cards/{cardId} {
  allow read: if request.auth != null
    && request.auth.uid == resource.data.userId;

  allow write: if false; // Only backend can write
}

// rules for analytics_intel_purchases
match /analytics_intel_purchases/{purchaseId} {
  allow read, write: if false; // Only backend
}
```

---

## 📊 Summary of Changes

### Files to Create (8 new files)
1. `lib/screens/intel/intel_type_selection_screen.dart`
2. `lib/screens/intel/injury_intel_purchase_screen.dart`
3. `lib/screens/intel/injury_report_view_screen.dart`

### Files to Modify (3 files)
1. `lib/screens/betting/bet_selection_screen.dart`
   - Add injury detection
   - Hide button if no injuries
   - Change icon to medical symbol
   - Update navigation to Level 1

2. `lib/models/intel_card_model.dart`
   - Add `teamInjuryReport` enum value

3. `lib/main.dart`
   - Add 3 new routes

### Backend Already Complete ✅
- Injury service with ESPN API integration
- Intel card purchase flow with BR payment
- Firestore models and collections
- Impact scoring and analysis

---

## 🎯 Testing Checklist

### Functional Testing
- [ ] Bet selection page loads and checks for injuries
- [ ] Button hidden when no NBA injuries exist
- [ ] Button shows when injuries detected
- [ ] Button uses medical icon
- [ ] Navigation to Level 1 works
- [ ] Level 1 shows correct injury counts
- [ ] Navigation to Level 2 works
- [ ] Level 2 shows 3 purchase options with correct pricing
- [ ] Home team card purchase works (30 BR deducted)
- [ ] Away team card purchase works (30 BR deducted)
- [ ] Bundle card purchase works (50 BR deducted)
- [ ] Navigation to Level 3 works after purchase
- [ ] Level 3 displays correct injury data
- [ ] Intel Insight section shows impact scores
- [ ] Report accessible from user's purchased intel list

### Edge Cases
- [ ] No injuries for game (button hidden)
- [ ] Insufficient BR balance (error shown)
- [ ] Already purchased card (duplicate prevention)
- [ ] Expired card (cannot purchase)
- [ ] Network error during injury check (button hidden)

---

## 📈 Success Metrics

### Week 1 (Soft Launch - 10% of users)
- Monitor purchase conversion rate
- Track which option users prefer (team vs bundle)
- Measure BR spend on intel cards
- Collect user feedback

### Month 1 Goals
- 10-15% of NBA game viewers purchase injury intel
- Average 2-3 intel cards purchased per buying user per week
- 60%+ choose bundle over individual team cards
- <5% refund requests / complaints

### Revenue Projection (100k active users)
- Conservative: 10k users × 2 cards/week × 50 BR avg = 1M BR/week
- Optimistic: 20k users × 4 cards/week × 50 BR avg = 4M BR/week

---

## 🚀 Deployment Plan

### Pre-Deployment
1. Create all 3 new screens
2. Modify bet selection screen
3. Add routes to navigation
4. Test on development environment
5. QA testing with mock data

### Soft Launch (Week 1)
1. Deploy to 10% of users (A/B test)
2. Monitor analytics dashboard
3. Track purchase flow completion rate
4. Collect user feedback via in-app survey

### Full Launch (Week 2-3)
1. Address any bugs from soft launch
2. Deploy to 100% of users
3. Send push notification campaign
4. Monitor revenue and engagement

---

**End of Implementation Plan**
