# UFC/MMA Fight Card Implementation Plan

## Overview
This document outlines the implementation strategy for proper UFC/MMA fight card support in the Bragging Rights app. Currently, each fight appears as a separate event. This plan details how to group fights into complete fight cards with comprehensive betting options.

## Current Issues
1. **Event Grouping**: Each fight appears separately, no indication of belonging to same event (e.g., UFC 310)
2. **Event Name Missing**: "UFC 310", "Bellator 300" etc. not displayed
3. **Single Fight Only**: Can only bet on one fight at a time
4. **No Card Position**: Can't distinguish Main Event from Prelims

## Solution Architecture

### Core Principles
- **Mobile-first** swipeable interface
- **Pool-specific** rules and scoring
- **Progressive disclosure** (simple → advanced picks)
- **Flexible entry** (allow late joins, skip prelims based on pool)

## User Flow

```
Event Selection → Pool Selection → Fight List (2x1) → Fight Details → Review → Submit
```

## Data Models

### 1. Fight Card Event Model
```dart
class FightCardEventModel extends GameModel {
  final String eventId;
  final String eventName;        // "UFC 310"
  final String promotion;        // UFC, Bellator, PFL, ONE
  final DateTime eventDate;
  final String venue;
  final String location;
  final int totalFights;
  final String mainEvent;        // "Jones vs Miocic"
  final List<Fight> fights;
  final String? eventPoster;
  final String? broadcastInfo;
  
  // Categorized access
  List<Fight> get mainCard => fights.where((f) => f.cardPosition == 'main').toList();
  List<Fight> get prelims => fights.where((f) => f.cardPosition == 'prelim').toList();
  List<Fight> get earlyPrelims => fights.where((f) => f.cardPosition == 'early').toList();
}
```

### 2. Individual Fight Model
```dart
class Fight {
  final String id;
  final String eventId;
  
  // Fighter information
  final String fighter1Id;
  final String fighter1Name;
  final String fighter1Record;     // "25-3-0"
  final String fighter1Country;
  final String? fighter1FlagUrl;
  
  final String fighter2Id;
  final String fighter2Name;
  final String fighter2Record;
  final String fighter2Country;
  final String? fighter2FlagUrl;
  
  // Fight details
  final String weightClass;
  final int rounds;                // 3 or 5
  final int fightOrder;            // 1 = main event
  final String cardPosition;       // main, prelim, early
  final bool isTitle;
  final DateTime? scheduledTime;
  
  // Betting data
  final Map<String, dynamic>? odds;
  
  // Helper getters
  bool get isMainCard => cardPosition == 'main';
  bool get isPrelim => cardPosition == 'prelim' || cardPosition == 'early';
  bool get isMainEvent => fightOrder == 1;
  bool get isCoMain => fightOrder == 2;
}
```

### 3. Fight Pick Model
```dart
class FightPick {
  final String fightId;
  final String userId;
  final String poolId;
  
  // Required pick
  final String? winnerId;
  
  // Optional advanced picks
  final String? method;           // KO/TKO, Submission, Decision
  final int? round;               // 1-5
  final String? roundTime;        // early, late
  final bool? goesDistance;
  final bool? knockdown;
  
  // Confidence for scoring
  final int confidence;           // 1-5 stars
  final DateTime pickedAt;
  
  bool get isComplete => winnerId != null;
}
```

### 4. Pool Rules Model
```dart
class PoolRules {
  final bool requireAllFights;         // Must pick every fight?
  final bool allowSkipPrelims;         // Can skip early/prelims?
  final bool allowLatePicks;           // Join after event starts?
  final bool requireAdvancedPicks;     // Method, round required?
  final int minimumPicks;              // Min fights to pick
  final ScoringSystem scoring;
}
```

### 5. Scoring System
```dart
class ScoringSystem {
  final int winnerPoints;
  final int methodPoints;
  final int roundPoints;
  final List<double> confidenceMultipliers;
  final double underdogMultiplier;
  final int perfectCardBonus;
  final int perfectMainCardBonus;
  
  // Predefined systems
  static final simple = ScoringSystem(
    winnerPoints: 10,
    methodPoints: 0,
    roundPoints: 0,
    confidenceMultipliers: [1.0, 1.0, 1.0, 1.0, 1.0],
    underdogMultiplier: 1.0,
    perfectCardBonus: 0,
    perfectMainCardBonus: 0,
  );
  
  static final advanced = ScoringSystem(
    winnerPoints: 10,
    methodPoints: 5,
    roundPoints: 5,
    confidenceMultipliers: [1.0, 1.1, 1.2, 1.3, 1.5],
    underdogMultiplier: 1.5,
    perfectCardBonus: 100,
    perfectMainCardBonus: 50,
  );
  
  static final confidence = ScoringSystem(
    winnerPoints: 10,
    methodPoints: 3,
    roundPoints: 2,
    confidenceMultipliers: [0.5, 0.75, 1.0, 1.25, 1.5],
    underdogMultiplier: 1.25,
    perfectCardBonus: 50,
    perfectMainCardBonus: 25,
  );
}
```

## UI Screens

### 1. Event Display on Games Page
```
┌────────────────────────────────┐
│ UFC 310: Jones vs Miocic       │
│ Sat, Dec 14 • 8:00 PM         │
│ T-Mobile Arena, Las Vegas      │
│ 13 Fights • PPV                │
│ [Event Poster Thumbnail]       │
└────────────────────────────────┘
```

### 2. Fight List Screen (2x1 Layout)
```
┌────────────────────────────────┐
│ < Back   UFC 310   Pool Info > │
│                                │
│ Quick Play • $25 Entry         │
│ Progress: 3/8 picks made       │
├────────────────────────────────┤
│ ┌──────────────────────────┐   │
│ │ MAIN EVENT • 5 ROUNDS    │   │
│ │ ┌──────────┬──────────┐  │   │
│ │ │ 🇺🇸 Jones │ Miocic 🇺🇸│  │   │
│ │ │   25-1   │   23-4   │  │   │
│ │ │   -350   │   +280   │  │   │
│ │ └──────────┴──────────┘  │   │
│ │ [ TAP TO MAKE PICK ]     │   │
│ └──────────────────────────┘   │
│                                │
│ ┌──────────────────────────┐   │
│ │ CO-MAIN • WELTERWEIGHT   │   │
│ │ ✅ Pick Made: Buckley    │   │
│ └──────────────────────────┘   │
│                                │
│ [SHOW PRELIMS] ▼               │
│                                │
│ [REVIEW ALL PICKS]             │
└────────────────────────────────┘
```

### 3. Fight Detail Screen
```
┌────────────────────────────────┐
│ < Back to Card                 │
├────────────────────────────────┤
│    HEAVYWEIGHT TITLE FIGHT     │
│         5 ROUNDS                │
├────────────────────────────────┤
│ ┌──────────────────────────┐   │
│ │      JON JONES 🇺🇸       │   │
│ │ Record: 25-1-0           │   │
│ │ Champion                 │   │
│ │ Odds: -350               │   │
│ └──────────────────────────┘   │
│                                │
│            VS                  │
│                                │
│ ┌──────────────────────────┐   │
│ │    STIPE MIOCIC 🇺🇸      │   │
│ │ Record: 23-4-0           │   │
│ │ Former Champion          │   │
│ │ Odds: +280               │   │
│ └──────────────────────────┘   │
├────────────────────────────────┤
│ PICK WINNER (Required)         │
│ ○ Jones    ○ Miocic           │
├────────────────────────────────┤
│ METHOD (Optional +5pts)        │
│ [KO/TKO] [SUB] [DEC]          │
├────────────────────────────────┤
│ ROUND (Optional +5pts)         │
│ [1] [2] [3] [4] [5]           │
├────────────────────────────────┤
│ CONFIDENCE                     │
│ ⭐ ⭐ ⭐ ☆ ☆                   │
├────────────────────────────────┤
│ Potential: 10-22 points        │
│ [SAVE & NEXT →]                │
└────────────────────────────────┘
```

### 4. Review & Submit Screen
```
┌────────────────────────────────┐
│ Review Your Picks              │
├────────────────────────────────┤
│ MAIN CARD (5/5 ✅)            │
│ • Jones by KO (R3) ⭐⭐⭐⭐⭐   │
│ • Buckley by Dec ⭐⭐⭐        │
│ • Oliveira by Sub ⭐⭐⭐⭐     │
│ • Dariush by Dec ⭐⭐         │
│ • Craig by KO ⭐⭐⭐          │
├────────────────────────────────┤
│ PRELIMS (3/4 ⚠️)              │
│ • Fight 6: No pick            │
│ • Fight 7: Thompson ⭐        │
│ • Fight 8: Martinez ⭐⭐      │
│ • Fight 9: No pick (skipped)  │
├────────────────────────────────┤
│ Entry: $25                     │
│ Max Points: 180                │
│ Prize Pool: $2,500             │
│                                │
│ [SUBMIT PICKS]                 │
└────────────────────────────────┘
```

## Pool Variants

### Quick Play
- **Requirements**: Main card only (5-6 fights)
- **Picks**: Winner only
- **Entry**: $5-50
- **Scoring**: Simple (10 pts per correct)

### Regional
- **Requirements**: Main card minimum
- **Picks**: Winner + confidence
- **Entry**: $25-100
- **Scoring**: Confidence-based

### Tournament
- **Requirements**: Full card required
- **Picks**: Winner + method + round
- **Entry**: $50-500
- **Scoring**: Advanced with bonuses

### Private
- **Requirements**: Pool creator decides
- **Picks**: Customizable
- **Entry**: Set by creator
- **Scoring**: Customizable

## Implementation Steps

### Phase 1: Data Layer (Week 1)
1. Create fight card models
2. Modify ESPN service to group fights
3. Update Firestore structure
4. Create fight card service

### Phase 2: UI Components (Week 2)
1. Build fight card widget (2x1)
2. Create fight list screen
3. Build fight detail screen
4. Implement review screen

### Phase 3: Pool Integration (Week 3)
1. Add pool rules to pools
2. Implement validation logic
3. Create scoring calculators
4. Add late entry handling

### Phase 4: Testing & Polish (Week 4)
1. Test with real UFC data
2. Handle edge cases
3. Add animations
4. Performance optimization

## Technical Considerations

### API Data Sources
- **ESPN MMA API**: Primary source for fight data
- **Country Flags**: Available from ESPN
- **Fighter Images**: Not available (use placeholders)
- **Odds Data**: Available from ESPN

### Firestore Structure
```
/events
  /{eventId}
    - eventData
    - promotion
    - venue
    - date
    /fights
      /{fightId}
        - fighter1
        - fighter2
        - weightClass
        - rounds
        - cardPosition
    /pools
      /{poolId}
        - rules
        - scoring
    /userPicks
      /{userId}
        /{fightId}
          - winnerId
          - method
          - round
          - confidence

/users/{userId}/activeBets
  /{betId}
    - eventId
    - poolId
    - picks[]
    - totalRisk
    - potentialWin
```

### State Management
```dart
class FightCardBettingSession {
  final String eventId;
  final String poolId;
  final PoolRules rules;
  final List<Fight> fights;
  final Map<String, FightPick> picks = {};
  
  // Progress tracking
  int get requiredPicks => rules.requireAllFights 
    ? fights.length 
    : fights.where((f) => f.isMainCard).length;
    
  int get completedPicks => picks.values
    .where((p) => p.winnerId != null)
    .length;
    
  double get progressPercent => completedPicks / requiredPicks;
  
  // Validation
  bool get canSubmit {
    if (rules.requireAllFights) {
      return picks.length == fights.length;
    } else if (rules.allowSkipPrelims) {
      final mainCardFights = fights.where((f) => f.isMainCard);
      return mainCardFights.every((f) => picks.containsKey(f.id));
    }
    return picks.isNotEmpty;
  }
}
```

### Late Entry Handling
```dart
class LateEntryHandler {
  static List<Fight> getAvailableFights(
    FightCardEvent event,
    DateTime currentTime,
  ) {
    return event.fights.where((fight) {
      return fight.scheduledTime?.isAfter(currentTime) ?? true;
    }).toList();
  }
  
  static int calculateAdjustedFee(
    int originalFee,
    int totalFights,
    int remainingFights,
  ) {
    final percentage = remainingFights / totalFights;
    return (originalFee * percentage).round();
  }
}
```

## Success Metrics
- **User Engagement**: 70% completion rate for fight picks
- **Pool Filling**: 80% of pools reach minimum players
- **Pick Accuracy**: Track average correct picks per card
- **Time to Complete**: < 3 minutes to pick full card

## Risk Mitigation
1. **Missing Fighter Data**: Use placeholder silhouettes
2. **Late API Updates**: Cache fight data 24hrs before
3. **Incomplete Cards**: Allow submission with minimum picks
4. **Connection Issues**: Local storage of picks until submitted

## Future Enhancements
1. **Fighter Stats Display**: Recent form, KO%, Sub rate
2. **Community Picks**: Show % picking each fighter
3. **Live Scoring**: Real-time updates during event
4. **Historical Performance**: User's past pick accuracy
5. **Expert Picks**: Premium feature showing analyst predictions

## Next Steps
1. ✅ Create implementation plan
2. 🚧 Build data models
3. ⏳ Modify ESPN service
4. ⏳ Create UI screens
5. ⏳ Integrate with pools
6. ⏳ Test with live data

---

*Document Version: 1.0*  
*Created: Current Session*  
*Status: Ready for Implementation*