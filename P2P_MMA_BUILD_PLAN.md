# P2P MMA Betting System - Build Plan & Implementation Guide

## Overview
Peer-to-peer betting system for MMA events where users compete directly against each other with the platform acting as facilitator. All predictions are locked before events begin.

## Architecture Overview

### Core Components
- **Challenge Types**: H2H, Group Pools, Confidence Pools, Survivor Brackets
- **Currency**: BR Coins (wagers) → Victory Coins (earned from wins)
- **Platform Revenue**: 10-15% facilitation fee on all P2P contests
- **Legal Structure**: Skill-based competition platform (not gambling)

---

## API Endpoints & Data Structure

### Primary ESPN Endpoints

#### 1. UFC Scoreboard - Get All Events
```javascript
GET https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard

Response Structure:
{
  "events": [
    {
      "id": "600051442",
      "date": "2025-01-19T02:00Z",
      "name": "UFC 311: Makhachev vs. Moicano",
      "competitions": [...],
      "status": {
        "type": {
          "name": "STATUS_SCHEDULED",
          "state": "pre"
        }
      }
    }
  ]
}

Provides:
- Event ID (needed for all other calls)
- Event name and date
- Event status (scheduled/live/final)
- Basic competition array
```

#### 2. Event Competitions - Get Fight Card Structure
```javascript
GET http://sports.core.api.espn.com/v2/sports/mma/leagues/ufc/events/{eventId}/competitions

Response Structure:
{
  "items": [
    {
      "id": "401751541",
      "date": "2025-01-19T03:00Z",
      "competitors": [/* fighter IDs */],
      "type": {
        "text": "Lightweight",
        "abbreviation": "Lightweight"
      },
      "cardSegment": {
        "id": "173",
        "description": "Main Card",
        "name": "main"
      },
      "matchNumber": 1,  // 1 = main event
      "format": {
        "regulation": {
          "periods": 5,  // Number of rounds
          "clock": 300.0 // Seconds per round
        }
      }
    }
  ]
}

Provides:
- Fight ID for each bout
- Card position (Early Prelims/Prelims/Main Card)
- Match number (1 = main event, ascending)
- Weight class
- Number of rounds (3 or 5)
- Fighter competitor IDs
```

#### 3. Fight Status - Get Results (Post-Fight)
```javascript
GET http://sports.core.api.espn.com/v2/sports/mma/leagues/ufc/events/{eventId}/competitions/{fightId}/status

Response Structure:
{
  "clock": 245.0,
  "displayClock": "4:05",
  "period": 1,  // Round number
  "type": {
    "name": "STATUS_FINAL",
    "completed": true
  },
  "result": {
    "name": "submission",
    "displayName": "Submission",
    "description": "D'Arce Choke",
    "target": {
      "name": "head",
      "description": "Head"
    }
  }
}

Provides:
- Method of victory (KO/TKO/Submission/Decision)
- Specific finish technique
- Round of finish
- Time of finish
- Target area
- Completion status
```

#### 4. Fighter Details - Get Stats & Records
```javascript
GET http://sports.core.api.espn.com/v2/sports/mma/athletes/{fighterId}

Response Structure:
{
  "id": "3332412",
  "fullName": "Islam Makhachev",
  "displayName": "Islam Makhachev",
  "weight": 155.0,
  "height": 70.0,
  "displayHeight": "5' 10\"",
  "citizenship": "Russia",
  "headshot": {
    "href": "https://a.espncdn.com/i/headshots/mma/players/full/3332412.png"
  },
  "flag": {
    "href": "https://a.espncdn.com/i/teamlogos/countries/500/rus.png"
  },
  "reach": 70.5,
  "stance": {
    "text": "Southpaw"
  }
}

// Additional call for record
GET http://sports.core.api.espn.com/v2/sports/mma/athletes/{fighterId}/records

Response:
{
  "items": [{
    "summary": "27-1-0",
    "stats": [
      {"name": "wins", "value": 27},
      {"name": "losses", "value": 1},
      {"name": "draws", "value": 0}
    ]
  }]
}

Provides:
- Fighter name and display name
- Physical stats (height, weight, reach)
- Fighter image URL
- Country and flag
- Fighter record (W-L-D)
- Stance (Orthodox/Southpaw)
```

#### 5. Odds Data - Get Betting Lines
```javascript
GET http://sports.core.api.espn.com/v2/sports/mma/leagues/ufc/events/{eventId}/competitions/{fightId}/odds

Response Structure:
{
  "items": [{
    "provider": {
      "name": "ESPN BET"
    },
    "details": "I. Makhachev -1300",
    "overUnder": 1.5,
    "awayAthleteOdds": {
      "moneyLine": 700,
      "current": {
        "moneyLine": {
          "american": "+700"
        },
        "victoryMethod": {
          "koTkoDq": {
            "american": "+1200"
          },
          "submission": {
            "american": "+1800"
          },
          "points": {
            "american": "+2200"
          }
        }
      }
    },
    "homeAthleteOdds": {
      "moneyLine": -1300,
      "current": {
        "moneyLine": {
          "american": "-1300"
        }
      }
    }
  }]
}

Provides:
- Moneyline odds for each fighter
- Method of victory odds
- Over/Under rounds
- Favorite/underdog designation
```

---

## Database Schema

### P2P Collections

#### challenges
```javascript
{
  id: string,
  type: enum ['h2h', 'group', 'confidence', 'survivor'],
  eventId: string,
  eventName: string,
  creatorId: string,
  creatorUsername: string,
  creatorElo: number,
  status: enum ['open', 'matched', 'locked', 'scoring', 'completed'],
  stake: number, // BR Coins
  platformFee: number, // 10-15%
  participants: [{
    userId: string,
    username: string,
    elo: number,
    picks: map<fightId, pick>,
    score: number,
    rank: number,
    payout: number
  }],
  maxParticipants: number,
  minParticipants: number,
  createdAt: timestamp,
  lockedAt: timestamp,
  completedAt: timestamp
}
```

#### p2p_picks
```javascript
{
  id: string,
  challengeId: string,
  userId: string,
  fightId: string,
  fighterPicked: string,
  methodPrediction: enum ['ko', 'submission', 'decision', null],
  roundPrediction: number, // 1-5
  confidence: number, // For confidence pools
  submittedAt: timestamp,
  result: {
    correct: boolean,
    pointsEarned: number,
    perfectPick: boolean
  }
}
```

#### user_p2p_stats
```javascript
{
  userId: string,
  elo: number,
  totalChallenges: number,
  wins: number,
  losses: number,
  winRate: number,
  totalBRWagered: number,
  totalBRWon: number,
  totalVCEarned: number,
  perfectPicks: number,
  currentStreak: number,
  bestStreak: number,
  favoritePickRate: number,
  updatedAt: timestamp
}
```

---

## P2P Challenge Types Implementation

### 1. Head-to-Head (H2H)
```javascript
class H2HChallenge {
  // Creation
  async createChallenge(userId, eventId, stake, options = {}) {
    const challenge = {
      type: 'h2h',
      eventId,
      creatorId: userId,
      stake,
      platformFee: stake * 0.10, // 10% fee
      status: 'open',
      maxParticipants: 2,
      minParticipants: 2,
      eloRange: options.eloRange || 200,
      friendsOnly: options.friendsOnly || false,
      createdAt: Date.now()
    };

    return await db.collection('challenges').add(challenge);
  }

  // Matching
  async findMatch(userId, stake, elo) {
    const matches = await db.collection('challenges')
      .where('type', '==', 'h2h')
      .where('status', '==', 'open')
      .where('stake', '==', stake)
      .where('creatorElo', '>=', elo - 200)
      .where('creatorElo', '<=', elo + 200)
      .limit(1)
      .get();

    return matches.docs[0];
  }

  // Scoring
  calculateScore(picks, results) {
    let score = 0;
    for (const [fightId, pick] of Object.entries(picks)) {
      const result = results[fightId];

      // Base points for correct winner
      if (pick.fighter === result.winner) {
        score += 10;

        // Bonus for method
        if (pick.method === result.method) {
          score += 5;
        }

        // Bonus for round
        if (pick.round === result.round) {
          score += 5;
        }

        // Underdog bonus
        if (result.winnerOdds > 0) { // Positive odds = underdog
          score += 10;
        }
      }
    }
    return score;
  }
}
```

### 2. Group Pools (3-10 Players)
```javascript
class GroupPool {
  async createPool(userId, eventId, stake, maxPlayers = 10) {
    const pool = {
      type: 'group',
      eventId,
      creatorId: userId,
      stake,
      platformFee: stake * 0.12, // 12% fee
      status: 'open',
      maxParticipants: maxPlayers,
      minParticipants: 3,
      prizeDistribution: {
        1: 0.50, // 50% to 1st
        2: 0.30, // 30% to 2nd
        3: 0.20  // 20% to 3rd
      },
      createdAt: Date.now()
    };

    return await db.collection('challenges').add(pool);
  }

  calculatePayouts(participants, totalPot) {
    const sorted = participants.sort((a, b) => b.score - a.score);
    const netPot = totalPot * 0.88; // After 12% fee

    return {
      1: sorted[0] ? netPot * 0.50 : 0,
      2: sorted[1] ? netPot * 0.30 : 0,
      3: sorted[2] ? netPot * 0.20 : 0
    };
  }
}
```

### 3. Confidence Pools
```javascript
class ConfidencePool {
  async submitPicks(challengeId, userId, picks) {
    // Validate confidence points (must use 1-12 for 12 fights)
    const confidencePoints = Object.values(picks).map(p => p.confidence);
    const expectedSum = (12 * 13) / 2; // Sum of 1-12
    const actualSum = confidencePoints.reduce((a, b) => a + b, 0);

    if (actualSum !== expectedSum) {
      throw new Error('Invalid confidence point distribution');
    }

    // Save picks
    for (const [fightId, pick] of Object.entries(picks)) {
      await db.collection('p2p_picks').add({
        challengeId,
        userId,
        fightId,
        fighterPicked: pick.fighter,
        confidence: pick.confidence,
        submittedAt: Date.now()
      });
    }
  }

  calculateScore(picks, results) {
    let score = 0;
    for (const pick of picks) {
      if (pick.fighterPicked === results[pick.fightId].winner) {
        score += pick.confidence; // Add confidence points if correct
      }
    }
    return score;
  }
}
```

### 4. Survivor Brackets
```javascript
class SurvivorBracket {
  async progressBracket(challengeId, bracketStage) {
    const challenge = await db.collection('challenges').doc(challengeId).get();
    const participants = challenge.data().participants;

    switch (bracketStage) {
      case 'prelims':
        // Score early prelims, eliminate bottom 50%
        const prelimScores = participants.map(p => ({
          ...p,
          score: this.calculateScore(p.picks.prelims, results.prelims)
        }));

        const cutoff = Math.ceil(prelimScores.length / 2);
        const survivors = prelimScores
          .sort((a, b) => b.score - a.score)
          .slice(0, cutoff);

        await this.updateParticipants(challengeId, survivors);
        break;

      case 'mainCard':
        // Score main card, keep top 5%
        const mainScores = participants.map(p => ({
          ...p,
          score: p.score + this.calculateScore(p.picks.mainCard, results.mainCard)
        }));

        const topPercent = Math.max(1, Math.ceil(mainScores.length * 0.05));
        const finalists = mainScores
          .sort((a, b) => b.score - a.score)
          .slice(0, topPercent);

        await this.updateParticipants(challengeId, finalists);
        break;

      case 'mainEvent':
        // Final scoring
        const finalScores = participants.map(p => ({
          ...p,
          score: p.score + this.calculateScore(p.picks.mainEvent, results.mainEvent)
        }));

        const winner = finalScores.sort((a, b) => b.score - a.score)[0];
        await this.completeChallenge(challengeId, winner);
        break;
    }
  }
}
```

---

## Victory Coin Integration

### VC Earning Rates from P2P
```javascript
const P2P_VC_CONVERSION = {
  h2h: {
    win: 0.35,        // 35% of BR stake
    perfectCard: 0.50 // 50% if all picks correct
  },
  group: {
    first: 0.40,      // 40% of stake
    second: 0.25,     // 25% of stake
    third: 0.15       // 15% of stake
  },
  confidence: {
    win: 0.40,        // 40% of stake
    top3: 0.25        // 25% for top 3
  },
  survivor: {
    winner: 1.00,     // 100% of stake
    finalist: 0.50,   // 50% for reaching final
    semifinal: 0.25   // 25% for reaching semis
  }
};

async function awardVictoryCoins(userId, challengeType, result, stake) {
  const rate = P2P_VC_CONVERSION[challengeType][result];
  const vcEarned = Math.floor(stake * rate);

  // Check daily/weekly caps
  const caps = await checkVCCaps(userId);
  const actualVC = Math.min(vcEarned, caps.remaining);

  await db.collection('victory_coins').doc(userId).update({
    balance: FieldValue.increment(actualVC),
    earned: FieldValue.increment(actualVC),
    lastEarned: Date.now()
  });

  return actualVC;
}
```

---

## Matchmaking & ELO System

### ELO Rating Implementation
```javascript
class EloSystem {
  static K_FACTOR = 32; // Rating change sensitivity

  calculateNewRatings(winnerElo, loserElo) {
    // Expected scores
    const expectedWinner = 1 / (1 + Math.pow(10, (loserElo - winnerElo) / 400));
    const expectedLoser = 1 - expectedWinner;

    // New ratings
    const newWinnerElo = winnerElo + this.K_FACTOR * (1 - expectedWinner);
    const newLoserElo = loserElo + this.K_FACTOR * (0 - expectedLoser);

    return {
      winner: Math.round(newWinnerElo),
      loser: Math.round(newLoserElo)
    };
  }

  getSkillTier(elo) {
    if (elo < 1000) return 'bronze';
    if (elo < 1500) return 'silver';
    if (elo < 2000) return 'gold';
    if (elo < 2500) return 'platinum';
    return 'diamond';
  }

  getMaxStake(elo) {
    const tier = this.getSkillTier(elo);
    const limits = {
      bronze: 100,
      silver: 500,
      gold: 2000,
      platinum: 5000,
      diamond: 10000
    };
    return limits[tier];
  }
}
```

---

## Fight Result Processing

### Real-Time Result Updates
```javascript
class FightResultProcessor {
  async pollEventResults(eventId) {
    const competitions = await this.getEventCompetitions(eventId);

    for (const competition of competitions) {
      const status = await this.getFightStatus(eventId, competition.id);

      if (status.type.completed) {
        await this.processFightResult(competition.id, status);
      }
    }
  }

  async processFightResult(fightId, status) {
    const result = {
      fightId,
      completed: true,
      winner: status.winnerId,
      method: status.result.name, // 'submission', 'ko', 'decision'
      specificMethod: status.result.description, // 'D\'Arce Choke'
      round: status.period,
      time: status.displayClock,
      target: status.result.target?.name
    };

    // Update all active challenges with this fight
    await this.updateChallengesWithResult(fightId, result);

    // Check for bracket progressions
    await this.checkBracketProgressions(fightId);
  }

  async updateChallengesWithResult(fightId, result) {
    // Find all active challenges for this event
    const challenges = await db.collection('challenges')
      .where('status', 'in', ['locked', 'scoring'])
      .where('eventId', '==', result.eventId)
      .get();

    for (const challenge of challenges.docs) {
      await this.scoreFightForChallenge(challenge.id, fightId, result);
    }
  }
}
```

---

## User Interface Components

### Challenge Creation Screen
```dart
class CreateChallengeScreen extends StatefulWidget {
  // UI for creating P2P challenges

  Widget buildChallengeOptions() {
    return Column(
      children: [
        // Challenge Type Selection
        SegmentedControl(
          options: ['H2H', 'Group', 'Confidence', 'Survivor'],
          onChanged: (type) => setState(() => challengeType = type),
        ),

        // Stake Selection
        StakeSelector(
          min: 100,
          max: getUserMaxStake(userElo),
          onChanged: (stake) => setState(() => selectedStake = stake),
        ),

        // Event Selection
        EventPicker(
          events: upcomingEvents,
          onSelected: (event) => setState(() => selectedEvent = event),
        ),

        // Advanced Options
        if (challengeType == 'h2h') ...[
          SwitchListTile(
            title: Text('Friends Only'),
            value: friendsOnly,
            onChanged: (val) => setState(() => friendsOnly = val),
          ),
          SliderListTile(
            title: Text('ELO Range: ±$eloRange'),
            value: eloRange,
            min: 100,
            max: 500,
            onChanged: (val) => setState(() => eloRange = val),
          ),
        ],
      ],
    );
  }
}
```

### Fight Pick Interface
```dart
class FightPickCard extends StatelessWidget {
  final Fight fight;
  final Function(Pick) onPickSubmitted;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Column(
        children: [
          // Fight Info Header
          ListTile(
            title: Text('${fight.weightClass} - ${fight.rounds} Rounds'),
            subtitle: Text(fight.cardPosition),
            trailing: Chip(
              label: Text('Fight #${fight.matchNumber}'),
            ),
          ),

          // Fighter Selection
          Row(
            children: [
              // Fighter 1
              Expanded(
                child: FighterButton(
                  fighter: fight.fighter1,
                  odds: fight.fighter1Odds,
                  isSelected: selectedFighter == fight.fighter1.id,
                  onTap: () => selectFighter(fight.fighter1),
                ),
              ),

              Text('VS'),

              // Fighter 2
              Expanded(
                child: FighterButton(
                  fighter: fight.fighter2,
                  odds: fight.fighter2Odds,
                  isSelected: selectedFighter == fight.fighter2.id,
                  onTap: () => selectFighter(fight.fighter2),
                ),
              ),
            ],
          ),

          // Method & Round Prediction (Optional)
          if (showAdvancedPicks) ...[
            MethodSelector(
              options: ['KO/TKO', 'Submission', 'Decision'],
              selected: selectedMethod,
              onChanged: (method) => setState(() => selectedMethod = method),
            ),

            RoundSelector(
              maxRounds: fight.rounds,
              selected: selectedRound,
              onChanged: (round) => setState(() => selectedRound = round),
            ),
          ],

          // Confidence Points (for confidence pools)
          if (challengeType == 'confidence')
            ConfidenceSlider(
              value: confidencePoints,
              available: availablePoints,
              onChanged: (points) => setState(() => confidencePoints = points),
            ),
        ],
      ),
    );
  }
}
```

---

## Revenue & Economics

### Platform Fee Structure
```javascript
const PLATFORM_FEES = {
  h2h: 0.10,        // 10% of total pot
  group: 0.12,      // 12% of total pot
  confidence: 0.12, // 12% of total pot
  survivor: 0.15    // 15% of entry fees
};

function calculatePlatformRevenue(challengeType, totalPot) {
  return totalPot * PLATFORM_FEES[challengeType];
}

// Example: UFC PPV Event
// 500 users, average 3 challenges each
// Average stake: 500 BR

const eventRevenue = {
  h2h: 600 * 1000 * 0.10,      // 60,000 BR
  group: 300 * 500 * 0.12,      // 18,000 BR
  confidence: 450 * 500 * 0.12, // 27,000 BR
  survivor: 150 * 500 * 0.15,   // 11,250 BR
  total: 116250                 // BR ($1,162.50)
};
```

---

## Security & Anti-Fraud

### Pick Verification
```javascript
class PickVerification {
  // Hash picks before event starts
  hashPicks(picks, userId, timestamp) {
    const data = JSON.stringify({ picks, userId, timestamp });
    return crypto.createHash('sha256').update(data).digest('hex');
  }

  // Verify picks haven't changed
  verifyPicks(originalHash, picks, userId, timestamp) {
    const currentHash = this.hashPicks(picks, userId, timestamp);
    return originalHash === currentHash;
  }

  // Lock picks when event starts
  async lockChallengePicks(challengeId, eventStartTime) {
    if (Date.now() >= eventStartTime - 3600000) { // 1 hour before
      await db.collection('challenges').doc(challengeId).update({
        status: 'locked',
        lockedAt: Date.now()
      });
    }
  }
}
```

### Anti-Collusion Measures
```javascript
class AntiCollusion {
  async checkSuspiciousActivity(userId1, userId2) {
    // Check IP addresses
    const ip1 = await getUserIP(userId1);
    const ip2 = await getUserIP(userId2);
    if (ip1 === ip2) return { suspicious: true, reason: 'Same IP' };

    // Check win trading patterns
    const history = await getH2HHistory(userId1, userId2);
    const alternatingWins = this.checkAlternatingWins(history);
    if (alternatingWins) return { suspicious: true, reason: 'Win trading' };

    // Check unusual betting patterns
    const bettingPattern = await this.analyzeBettingPattern(userId1, userId2);
    if (bettingPattern.suspicious) return bettingPattern;

    return { suspicious: false };
  }
}
```

---

## Deployment Timeline

### Week 1-2: Core P2P Infrastructure
- [ ] Database schema setup
- [ ] API integration layer
- [ ] Basic H2H challenge system
- [ ] Fight result processing

### Week 3-4: Challenge Types
- [ ] Group pools implementation
- [ ] Confidence pools
- [ ] Survivor brackets
- [ ] ELO rating system

### Week 5-6: UI Development
- [ ] Challenge creation screens
- [ ] Fight pick interface
- [ ] Live scoring display
- [ ] Challenge history

### Week 7-8: Testing & Launch
- [ ] Security testing
- [ ] Load testing (500+ concurrent users)
- [ ] Beta test with 100 users
- [ ] Full launch

---

## Success Metrics

### Key Performance Indicators
- Average challenges per user per event: Target 3+
- Challenge fill rate: Target >80%
- User retention rate: Target >60% event-to-event
- Platform revenue per event: Target $1,000+
- Dispute rate: Target <2%

### User Engagement Metrics
- Time to match: <30 seconds for H2H
- Picks submission rate: >95%
- Return user rate: >70%
- Social sharing rate: >20%

---

## Legal Compliance Checklist

- [ ] Terms of Service updated with P2P rules
- [ ] Skill-based competition disclosure
- [ ] Platform facilitation only (no house edge)
- [ ] Clear fee structure disclosure
- [ ] Dispute resolution process
- [ ] Age verification (18+)
- [ ] Geo-blocking (WA, ID)
- [ ] Anti-fraud measures implemented

---

## Contact & Support

**Technical Implementation**: [Dev Team Lead]
**API Support**: ESPN API Documentation
**Legal Review**: [Legal Counsel]
**Customer Support**: support@braggingrights.com

---

*Document Version: 1.0.0*
*Last Updated: [Current Date]*
*Next Review: [30 days]*