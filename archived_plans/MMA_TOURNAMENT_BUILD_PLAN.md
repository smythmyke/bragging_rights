# MMA Tournament System - Build Plan & Checklist

## Overview
Implementation of a three-bracket elimination tournament system for MMA/Combat Sports with Victory Coin (VC) economy and cash prize redemption.

## Architecture Overview

### Currency System
- **BR Coins**: Purchased virtual currency ($0.01 per coin)
- **Victory Coins (VC)**: Earned through winning bets, used for tournament entry
- **Cash Prizes**: Awarded only through tournament victories

### Legal Framework
- **Model**: Skill-based competition with sweepstakes elements
- **No License Required**: P2P facilitation + promotional prizes
- **Compliance**: 48 states (excluding WA, ID)

---

## Phase 1: Foundation (Week 1-2)

### Database Schema

#### [ ] Create Firestore Collections

```javascript
tournaments/
  - id: string
  - eventId: string (ESPN event ID)
  - eventName: string (UFC 315, Bellator 300)
  - promotion: string (UFC, Bellator, PFL, ONE)
  - eventDate: timestamp
  - status: enum (upcoming, registration, live, completed)
  - brackets: array<Bracket>
  - entryFee: number (VC required)
  - prizePool: map (cash distribution)
  - maxParticipants: number
  - currentParticipants: number
  - createdAt: timestamp

tournament_entries/
  - id: string
  - tournamentId: string
  - userId: string
  - bracket1Picks: map<fightId, pick>
  - bracket2Picks: map<fightId, pick>
  - bracket3Picks: map<fightId, pick>
  - bracket1Score: number
  - bracket2Score: number
  - bracket3Score: number
  - currentBracket: enum (prelims, mainCard, mainEvent, eliminated)
  - finalRank: number
  - prizewon: number
  - enteredAt: timestamp

victory_coins/
  - userId: string
  - balance: number
  - earned: number (lifetime)
  - spent: number (lifetime)
  - lastEarned: timestamp
  - dailyEarned: number
  - weeklyEarned: number
```

#### [ ] Create Indexes
```
- tournaments: eventDate DESC, status ASC
- tournament_entries: tournamentId ASC, bracket1Score DESC
- victory_coins: userId ASC
```

### Models

#### [ ] Tournament Model (`tournament_model.dart`)
```dart
class TournamentModel {
  String id;
  String eventId;
  String eventName;
  DateTime eventDate;
  TournamentStatus status;
  List<TournamentBracket> brackets;
  int entryFeeVC;
  Map<String, int> cashPrizes;
  int maxParticipants;
  int currentParticipants;
}
```

#### [ ] Victory Coin Model (`victory_coin_model.dart`)
```dart
class VictoryCoin {
  String userId;
  int balance;
  int lifetimeEarned;
  int lifetimeSpent;
  DateTime lastEarned;
  Map<String, int> earningCaps;
}
```

#### [ ] Tournament Entry Model (`tournament_entry_model.dart`)
```dart
class TournamentEntry {
  String id;
  String tournamentId;
  String userId;
  Map<String, FightPick> allPicks;
  BracketStatus currentBracket;
  int totalScore;
  int? finalRank;
  int? prizeWon;
}
```

---

## Phase 2: Victory Coin Economy (Week 2-3)

### VC Earning System

#### [ ] Implement VC Calculation Service (`vc_calculation_service.dart`)
```dart
class VCCalculationService {
  // Single game bet conversions
  int calculateVCForBet(int brWagered, double odds, bool won)

  // Parlay conversions
  int calculateVCForParlay(int brWagered, int numTeams, bool won)

  // MMA fight card conversions
  int calculateVCForFightCard(int brWagered, int correctPicks, int totalFights)
}
```

#### [ ] VC Conversion Rates
```
Straight Bets:
- Favorite (-200+): 15% BR→VC
- Even odds: 25% BR→VC
- Underdog (+200+): 40% BR→VC

Parlays:
- 2-team: 35% BR→VC
- 3-team: 60% BR→VC
- 4-team: 100% BR→VC
- 5+ team: 150% BR→VC
```

#### [ ] Implement VC Caps & Limits
```dart
Daily Cap: 500 VC
Weekly Cap: 2,500 VC
Monthly Cap: 8,000 VC
```

#### [ ] Create VC Transaction Service (`vc_transaction_service.dart`)
- Award VC for wins
- Deduct VC for tournament entry
- Check earning caps
- Log all transactions

### Wallet Integration

#### [ ] Update Wallet Service (`wallet_service.dart`)
- Add VC balance tracking
- Show BR and VC separately
- Add VC history tab

#### [ ] Update Wallet UI
- Display VC balance prominently
- Show progress to caps
- Add VC earning history

---

## Phase 3: Tournament System (Week 3-4)

### Tournament Service

#### [ ] Create Tournament Service (`tournament_service.dart`)
```dart
class TournamentService {
  // Tournament creation
  Future<void> createTournamentFromEvent(String eventId)

  // Registration
  Future<bool> enterTournament(String tournamentId, String userId)

  // Pick submission
  Future<void> submitPicks(String entryId, Map<String, FightPick> picks)

  // Scoring
  Future<void> updateScores(String tournamentId, String fightId, FightResult result)

  // Bracket progression
  Future<void> advanceBracket(String tournamentId)

  // Prize distribution
  Future<void> distributePrizes(String tournamentId)
}
```

#### [ ] Implement Bracket Logic
```
Bracket 1 (Prelims):
- All participants
- Bottom 50% eliminated
- Top 50% advance

Bracket 2 (Main Card):
- Top 50% from Bracket 1
- Only top 5% advance
- Rest eliminated

Bracket 3 (Main Event):
- Top 5% compete
- Winner takes main prize
```

#### [ ] Scoring System
```dart
Points System:
- Correct winner: 10 pts
- Correct method: +5 pts
- Correct round: +5 pts
- Underdog bonus: +10 pts
- Quick finish bonus: +3 pts
```

### Tournament UI

#### [ ] Tournament List Screen (`tournament_list_screen.dart`)
- Show upcoming tournaments
- Display entry fee (VC)
- Show prize pools
- Registration countdown

#### [ ] Tournament Entry Screen (`tournament_entry_screen.dart`)
- Fight card display
- Pick selection interface
- Confidence levels
- Submit picks

#### [ ] Live Tournament Screen (`tournament_live_screen.dart`)
- Real-time standings
- Bracket progression
- Elimination notifications
- Score updates

#### [ ] Tournament Results Screen (`tournament_results_screen.dart`)
- Final standings
- Prize distribution
- Share functionality
- Replay picks

---

## Phase 4: Integration (Week 4-5)

### API Integration

#### [ ] ESPN MMA API Updates
- Parse card segments (prelims, main)
- Get fight times
- Track fight results
- Live scoring updates

#### [ ] Fight Card Service Updates
```dart
class FightCardService {
  // Separate fights by card position
  List<Fight> getPreliminaryFights(String eventId)
  List<Fight> getMainCardFights(String eventId)
  Fight getMainEvent(String eventId)

  // Get live results
  Stream<FightResult> getLiveResults(String eventId)
}
```

### Navigation Updates

#### [ ] Update Pool Selection Screen
- Add "Tournament" badge
- Show VC entry requirement
- Display countdown timer
- Quick entry button

#### [ ] Update Home Screen
- Tournament countdown widget
- VC balance display
- Quick tournament access

---

## Phase 5: Testing & Optimization (Week 5-6)

### Testing

#### [ ] Unit Tests
- VC calculation logic
- Tournament scoring
- Bracket advancement
- Prize distribution

#### [ ] Integration Tests
- Full tournament flow
- VC earning and spending
- Multi-user scenarios
- Edge cases

#### [ ] Load Testing
- 100+ simultaneous users
- Real-time score updates
- Bracket transitions

### Security & Anti-Fraud

#### [ ] Implement Rate Limiting
- Max picks per second
- API call limits
- Transaction throttling

#### [ ] Fraud Detection
- Unusual win patterns
- Multiple account detection
- Velocity checks

#### [ ] Audit Logging
- All VC transactions
- Tournament entries
- Prize payouts
- Pick submissions

---

## Phase 6: Launch Preparation (Week 6-7)

### Legal & Compliance

#### [ ] Terms of Service Updates
- VC has no cash value clause
- Tournament rules
- Prize redemption terms
- Skill-based competition disclosure

#### [ ] Privacy Policy Updates
- Data collection for tournaments
- Prize fulfillment information
- Tax reporting requirements

#### [ ] Geo-blocking
- Block WA, ID
- Implement location verification
- VPN detection

### Admin Tools

#### [ ] Admin Dashboard
- Tournament creation interface
- Manual score adjustments
- Prize pool configuration
- User management

#### [ ] Analytics Dashboard
- VC economy metrics
- Tournament fill rates
- User engagement stats
- Revenue tracking

### Marketing Materials

#### [ ] In-App Tutorials
- How to earn VC
- Tournament entry guide
- Bracket system explanation
- Prize structure

#### [ ] Landing Pages
- Tournament schedule
- Prize pool displays
- Leaderboards
- Success stories

---

## Deployment Checklist

### Pre-Launch (Day -7)

- [ ] Database migrations complete
- [ ] All tests passing
- [ ] Security audit complete
- [ ] Legal review approved
- [ ] Admin tools functional
- [ ] Analytics tracking verified

### Soft Launch (Day 0)

- [ ] Deploy to 10% of users
- [ ] Monitor VC economy
- [ ] Track tournament entries
- [ ] Gather user feedback
- [ ] Check for exploits

### Adjustments (Day 1-7)

- [ ] Tune VC conversion rates
- [ ] Adjust tournament prizes
- [ ] Fix discovered bugs
- [ ] Optimize performance
- [ ] Update documentation

### Full Launch (Day 7+)

- [ ] Roll out to 100% users
- [ ] Enable all tournament tiers
- [ ] Launch marketing campaign
- [ ] Monitor metrics daily
- [ ] Weekly economy reviews

---

## Success Metrics

### Key Performance Indicators

- **User Engagement**
  - [ ] 30% of active users earn VC weekly
  - [ ] 20% enter tournaments monthly
  - [ ] 50% tournament fill rate

- **Economy Health**
  - [ ] Platform margin >80%
  - [ ] VC inflation <10% monthly
  - [ ] Prize payout ratio 1-2% of BR sales

- **User Satisfaction**
  - [ ] Tournament NPS >40
  - [ ] <5% fraud/dispute rate
  - [ ] >60% tournament retention

---

## Risk Mitigation

### Technical Risks
- [ ] Database backup strategy
- [ ] Rollback procedures
- [ ] Circuit breakers for APIs
- [ ] Graceful degradation

### Economic Risks
- [ ] Dynamic rate adjustment system
- [ ] Emergency VC freeze capability
- [ ] Prize pool caps
- [ ] Liability monitoring

### Legal Risks
- [ ] Legal counsel on retainer
- [ ] Clear audit trail
- [ ] Compliance monitoring
- [ ] Regular legal reviews

---

## Post-Launch Roadmap

### Month 2
- [ ] Add Bellator events
- [ ] Introduce team tournaments
- [ ] Premium tournament tiers
- [ ] Seasonal championships

### Month 3
- [ ] PFL and ONE Championship
- [ ] Cross-promotion tournaments
- [ ] Survivor pools
- [ ] Achievement system

### Month 6
- [ ] Boxing tournaments
- [ ] International expansion
- [ ] Sponsorship integration
- [ ] VIP tournament access

---

## Contact & Support

**Technical Lead**: [Your Name]
**Legal Counsel**: [Legal Contact]
**Customer Support**: [Support Email]
**Emergency Hotline**: [Phone Number]

---

*Last Updated: [Current Date]*
*Version: 1.0.0*