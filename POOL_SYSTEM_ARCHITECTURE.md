# Bragging Rights Pool System Architecture

## Table of Contents
1. [Pool Types & Configuration](#pool-types--configuration)
2. [Pool Lifecycle Management](#pool-lifecycle-management)
3. [Power Cards Integration](#power-cards-integration)
4. [BR Calculation System](#br-calculation-system)
5. [Winner Determination](#winner-determination)
6. [Game Modes & Rules](#game-modes--rules)
7. [Implementation Plan](#implementation-plan)

## Pool Types & Configuration

### Pool Categories

#### Quick Play Pools
```javascript
{
  type: 'quick',
  minPlayers: 2,
  maxPlayers: 20,
  entryFees: [10, 25, 50, 100], // BR Coins
  autoCreate: true,
  activationTime: 'gameStart - 15min',
  platformFee: 0.10,
  powerCards: {
    enabled: true,
    maxPerPlayer: 3,
    restrictions: ['no_wildcard']
  }
}
```

#### Regional Pools
```javascript
{
  type: 'regional',
  minPlayers: 10,
  maxPlayers: 500,
  entryFees: [25, 50, 100, 250, 500],
  regions: ['neighborhood', 'city', 'state', 'national'],
  autoCreate: true,
  activationTime: 'gameStart - 30min',
  platformFee: 0.10,
  powerCards: {
    enabled: true,
    maxPerPlayer: 5,
    restrictions: []
  }
}
```

#### Private Pools
```javascript
{
  type: 'private',
  minPlayers: 2,
  maxPlayers: 50,
  entryFees: 'custom', // 0-1000 BR
  inviteOnly: true,
  shareCode: 'auto-generated',
  creationFee: {
    first3PerMonth: 0,
    additional: 50 // BR Coins
  },
  platformFee: 0.05, // Lower for private
  powerCards: {
    enabled: 'creator_choice',
    maxPerPlayer: 'creator_choice',
    restrictions: 'creator_choice'
  }
}
```

#### Tournament Pools
```javascript
{
  type: 'tournament',
  minPlayers: 16,
  maxPlayers: [64, 128, 256, 512, 1024],
  entryFees: [100, 250, 500, 1000, 5000],
  format: 'elimination' | 'swiss' | 'roundRobin',
  rounds: 'multiple',
  activationTime: 'gameStart - 1hour',
  platformFee: 0.15, // Higher for tournaments
  powerCards: {
    enabled: false, // Tournaments are skill-only
    exceptions: ['tournament_specific_cards']
  }
}
```

## Pool Lifecycle Management

### 1. Creation Phase
```javascript
async function createPool(config) {
  // Validate creator permissions
  const canCreate = await validateCreator(userId, poolType);
  
  // Check creation limits
  const activePoolCount = await getUserActivePoolCount(userId);
  if (activePoolCount >= 5) {
    throw new Error('Maximum 5 active pools allowed');
  }
  
  // Calculate fees
  const creationFee = calculateCreationFee(userId, poolType);
  if (creationFee > 0) {
    await deductBR(userId, creationFee);
  }
  
  // Set activation deadline
  const activationDeadline = gameStartTime - getActivationBuffer(poolType);
  
  // Create pool
  return {
    id: generatePoolId(),
    status: 'pending',
    createdAt: now(),
    activationDeadline,
    minPlayers: config.minPlayers,
    currentPlayers: 0,
    prizePool: 0,
    powerCardsEnabled: config.powerCards.enabled,
    cardRules: config.powerCards
  };
}
```

### 2. Joining Phase
```javascript
async function joinPool(poolId, userId) {
  const pool = await getPool(poolId);
  
  // Validation checks
  if (pool.status !== 'pending') throw new Error('Pool not accepting players');
  if (pool.currentPlayers >= pool.maxPlayers) throw new Error('Pool full');
  if (pool.playerIds.includes(userId)) throw new Error('Already in pool');
  if (getUserBalance(userId) < pool.entryFee) throw new Error('Insufficient BR');
  
  // Process entry
  await transaction(async (tx) => {
    // Deduct entry fee
    await deductBR(userId, pool.entryFee, tx);
    
    // Add to pool
    await updatePool(poolId, {
      currentPlayers: increment(1),
      playerIds: arrayUnion(userId),
      prizePool: increment(pool.entryFee * (1 - PLATFORM_FEE))
    }, tx);
    
    // Create player entry
    await createPoolEntry(poolId, userId, {
      joinedAt: now(),
      entryFee: pool.entryFee,
      picks: null,
      powerCards: [],
      score: 0,
      rank: null
    }, tx);
  });
}
```

### 3. Activation Check
```javascript
async function checkPoolActivation(poolId) {
  const pool = await getPool(poolId);
  const now = Date.now();
  
  if (now >= pool.activationDeadline) {
    if (pool.currentPlayers >= pool.minPlayers) {
      // Activate pool
      await updatePool(poolId, {
        status: 'active',
        activatedAt: now,
        finalPlayerCount: pool.currentPlayers,
        finalPrizePool: pool.prizePool
      });
      
      // Lock prize distribution
      const prizeStructure = calculatePrizeStructure(
        pool.currentPlayers,
        pool.prizePool
      );
      await updatePool(poolId, { prizeStructure });
      
      // Notify players
      await notifyPlayers(pool.playerIds, 'Pool activated! Make your picks.');
      
    } else {
      // Cancel pool
      await cancelPool(poolId);
    }
  }
}

async function cancelPool(poolId) {
  const pool = await getPool(poolId);
  
  await transaction(async (tx) => {
    // Update pool status
    await updatePool(poolId, {
      status: 'cancelled',
      cancelledAt: now(),
      cancellationReason: 'Minimum players not met'
    }, tx);
    
    // Refund all players
    for (const playerId of pool.playerIds) {
      const entry = await getPoolEntry(poolId, playerId);
      await addBR(playerId, entry.entryFee, 'Pool cancelled refund', tx);
    }
    
    // Notify players
    await notifyPlayers(pool.playerIds, 'Pool cancelled - refund issued');
  });
}
```

### 4. Game Phase
```javascript
async function processGamePhase(poolId) {
  const pool = await getPool(poolId);
  const game = await getGame(pool.gameId);
  
  // Update pool status based on game
  if (game.status === 'live') {
    await updatePool(poolId, { status: 'in_progress' });
    
    // Start live scoring
    await startLiveScoring(poolId);
    
    // Enable in-game power cards
    if (pool.powerCardsEnabled) {
      await enableInGameCards(poolId);
    }
  }
}
```

### 5. Settlement Phase
```javascript
async function settlePool(poolId) {
  const pool = await getPool(poolId);
  const game = await getGame(pool.gameId);
  
  if (game.status !== 'completed') return;
  
  // Wait for official results (5 minute buffer)
  await delay(5 * 60 * 1000);
  
  // Calculate final scores
  const finalScores = await calculateFinalScores(poolId);
  
  // Determine winners
  const rankings = await determineRankings(finalScores);
  
  // Distribute prizes
  await distributePrizes(poolId, rankings, pool.prizeStructure);
  
  // Update pool status
  await updatePool(poolId, {
    status: 'completed',
    completedAt: now(),
    finalRankings: rankings
  });
  
  // Update player stats
  await updatePlayerStats(rankings);
  
  // Notify winners
  await notifyWinners(rankings);
}
```

## Power Cards Integration

### Card Usage Rules by Game Phase

#### Pre-Game Cards (Before Lock Time)
```javascript
const preGameCards = [
  {
    id: 'mulligan_card',
    phase: 'pre_game',
    effect: 'Change pick before game starts',
    usage: 'unlimited_until_lock',
    cost: 1
  },
  {
    id: 'crystal_ball_card',
    phase: 'pre_game',
    effect: 'See majority picks',
    usage: 'once_per_pool',
    cost: 1
  },
  {
    id: 'copycat_card',
    phase: 'pre_game',
    effect: 'Copy leader pick',
    usage: 'once_per_pool',
    cost: 1
  },
  {
    id: 'time_freeze_card',
    phase: 'pre_game',
    effect: 'Extend pick deadline 15min',
    usage: 'once_per_pool',
    cost: 1
  }
];
```

#### In-Game Cards (During Live Game)
```javascript
const inGameCards = [
  {
    id: 'double_down_card',
    phase: 'in_game',
    effect: 'Double winnings if correct',
    usage: 'before_halftime',
    cost: 1
  },
  {
    id: 'insurance_card',
    phase: 'in_game',
    effect: '50% refund if lose',
    usage: 'before_4th_quarter',
    cost: 1
  },
  {
    id: 'split_card',
    phase: 'in_game',
    effect: 'Bet both teams for small win',
    usage: 'before_halftime',
    cost: 1
  },
  {
    id: 'sabotage_card',
    phase: 'in_game',
    effect: 'Force opponent to opposite team',
    usage: 'first_quarter_only',
    cost: 1,
    target: 'other_player'
  },
  {
    id: 'steal_card',
    phase: 'in_game',
    effect: 'Swap positions if you lose',
    usage: 'last_5_minutes',
    cost: 1,
    target: 'other_player'
  }
];
```

#### Post-Game Cards (After Game Ends)
```javascript
const postGameCards = [
  {
    id: 'eraser_card',
    phase: 'post_game',
    effect: 'Turn one loss into win',
    usage: 'within_5_minutes',
    cost: 1
  },
  {
    id: 'referee_card',
    phase: 'post_game',
    effect: 'Challenge controversial call',
    usage: 'within_10_minutes',
    cost: 1
  },
  {
    id: 'extra_life_card',
    phase: 'post_game',
    effect: 'Re-enter eliminated pool',
    usage: 'survivor_pools_only',
    cost: 1
  }
];
```

### Card Processing System
```javascript
async function processCardPlay(poolId, userId, cardId, targetId = null) {
  const pool = await getPool(poolId);
  const card = await getCard(cardId);
  const playerEntry = await getPoolEntry(poolId, userId);
  
  // Validate card can be played
  if (!canPlayCard(card, pool, playerEntry)) {
    throw new Error('Card cannot be played at this time');
  }
  
  // Check card inventory
  if (!playerHasCard(userId, cardId)) {
    throw new Error('Card not in inventory');
  }
  
  // Check card limits
  if (playerEntry.cardsUsed.length >= pool.cardRules.maxPerPlayer) {
    throw new Error('Card limit reached for this pool');
  }
  
  // Apply card effect
  const effect = await applyCardEffect(card, poolId, userId, targetId);
  
  // Deduct card from inventory
  await useCard(userId, cardId);
  
  // Log card usage
  await logCardUsage(poolId, userId, cardId, effect);
  
  // Notify affected players
  await notifyCardEffect(poolId, userId, targetId, card, effect);
  
  return effect;
}
```

## BR Calculation System

### Live Scoring During Game
```javascript
class LiveScoringEngine {
  async calculateLiveScore(poolId, userId) {
    const pool = await getPool(poolId);
    const entry = await getPoolEntry(poolId, userId);
    const game = await getLiveGameData(pool.gameId);
    
    let score = 0;
    let projectedBR = 0;
    
    // Base calculation
    if (entry.pick === game.currentLeader) {
      score = 100; // Base points for being ahead
      projectedBR = calculateWinningBR(pool, entry);
    } else {
      score = 50; // Partial points for being close
      projectedBR = 0;
    }
    
    // Apply active card effects
    for (const card of entry.activeCards) {
      const modifier = getCardModifier(card, game);
      score *= modifier.scoreMultiplier;
      projectedBR *= modifier.brMultiplier;
    }
    
    // Confidence pool adjustments
    if (pool.scoringSystem === 'confidence') {
      score *= entry.confidencePoints;
      projectedBR *= entry.confidencePoints;
    }
    
    return {
      currentScore: score,
      projectedBR: projectedBR,
      currentRank: await getCurrentRank(poolId, score),
      timeRemaining: game.timeRemaining,
      winProbability: calculateWinProbability(entry, game)
    };
  }
}
```

### Final BR Calculation
```javascript
async function calculateFinalBR(poolId) {
  const pool = await getPool(poolId);
  const entries = await getPoolEntries(poolId);
  const game = await getGameResult(pool.gameId);
  
  const results = [];
  
  for (const entry of entries) {
    let finalScore = 0;
    let brEarned = 0;
    let brLost = entry.entryFee;
    
    // Determine if pick was correct
    const correct = (entry.pick === game.winner);
    
    if (correct) {
      finalScore = 100;
      
      // Apply card modifiers
      for (const card of entry.cardsUsed) {
        if (card.type === 'double_down') {
          finalScore *= 2;
        } else if (card.type === 'lucky_charm') {
          finalScore *= 1.15;
        }
      }
      
      // Special scoring systems
      if (pool.scoringSystem === 'spread') {
        if (entry.spreadCovered) {
          finalScore *= 1.5;
        }
      } else if (pool.scoringSystem === 'confidence') {
        finalScore *= entry.confidencePoints;
      }
    } else {
      // Check for cards that affect losses
      for (const card of entry.cardsUsed) {
        if (card.type === 'eraser') {
          finalScore = 100; // Convert loss to win
          correct = true;
        } else if (card.type === 'insurance') {
          brLost *= 0.5; // Get 50% back
        } else if (card.type === 'split') {
          finalScore = 25; // Small points for split bet
          brLost *= 0.75; // Lose less
        }
      }
      
      // Check if steal card was played against them
      const stolenFrom = await checkSteals(poolId, entry.userId);
      if (stolenFrom) {
        finalScore = 0;
        brLost = entry.entryFee;
      }
    }
    
    results.push({
      userId: entry.userId,
      finalScore,
      correct,
      brLost,
      cardsUsed: entry.cardsUsed.length,
      rank: null // Will be determined after sorting
    });
  }
  
  // Sort by score and assign ranks
  results.sort((a, b) => b.finalScore - a.finalScore);
  results.forEach((result, index) => {
    result.rank = index + 1;
  });
  
  // Calculate BR earned based on rank and prize structure
  for (const result of results) {
    const prize = pool.prizeStructure[result.rank];
    if (prize) {
      result.brEarned = prize;
      result.netBR = prize - result.brLost;
    } else {
      result.brEarned = 0;
      result.netBR = -result.brLost;
    }
  }
  
  return results;
}
```

## Winner Determination

### Ranking Systems

#### Standard Ranking
```javascript
function standardRanking(entries) {
  return entries
    .sort((a, b) => {
      // Primary: Correct picks
      if (a.correct !== b.correct) return b.correct - a.correct;
      
      // Secondary: Total score
      if (a.finalScore !== b.finalScore) return b.finalScore - a.finalScore;
      
      // Tertiary: Time of pick (earlier is better)
      return a.pickTime - b.pickTime;
    })
    .map((entry, index) => ({
      ...entry,
      rank: index + 1
    }));
}
```

#### Survivor Pool Ranking
```javascript
function survivorRanking(entries, weeks) {
  const surviving = entries.filter(e => e.eliminatedWeek === null);
  
  if (surviving.length === 1) {
    // Single survivor wins
    return [{
      ...surviving[0],
      rank: 1,
      winType: 'sole_survivor'
    }];
  } else if (surviving.length === 0) {
    // Last eliminated wins
    const lastWeek = Math.max(...entries.map(e => e.eliminatedWeek));
    const finalists = entries.filter(e => e.eliminatedWeek === lastWeek);
    
    // Tiebreaker: Total score across all weeks
    return finalists
      .sort((a, b) => b.totalScore - a.totalScore)
      .map((entry, index) => ({
        ...entry,
        rank: index + 1,
        winType: 'last_standing'
      }));
  } else {
    // Multiple survivors split
    return surviving.map(entry => ({
      ...entry,
      rank: 1,
      winType: 'co_survivor'
    }));
  }
}
```

#### Tournament Bracket Ranking
```javascript
function tournamentRanking(bracket) {
  const rankings = [];
  
  // Champion
  rankings.push({
    ...bracket.champion,
    rank: 1,
    roundsWon: bracket.totalRounds
  });
  
  // Runner-up
  rankings.push({
    ...bracket.runnerUp,
    rank: 2,
    roundsWon: bracket.totalRounds - 1
  });
  
  // Semi-finalists
  bracket.semiFinalLosers.forEach(player => {
    rankings.push({
      ...player,
      rank: 3,
      roundsWon: bracket.totalRounds - 2
    });
  });
  
  // Continue for all rounds
  let currentRank = 5;
  for (let round = bracket.totalRounds - 3; round >= 0; round--) {
    const losers = bracket.getRoundLosers(round);
    losers.forEach(player => {
      rankings.push({
        ...player,
        rank: currentRank,
        roundsWon: round
      });
    });
    currentRank += losers.length;
  }
  
  return rankings;
}
```

### Prize Distribution
```javascript
async function distributePrizes(poolId, rankings) {
  const pool = await getPool(poolId);
  const distributions = [];
  
  for (const player of rankings) {
    let prize = 0;
    
    // Check prize structure
    if (pool.prizeStructure[player.rank]) {
      if (typeof pool.prizeStructure[player.rank] === 'number') {
        // Fixed amount
        prize = pool.prizeStructure[player.rank];
      } else {
        // Percentage
        prize = pool.finalPrizePool * pool.prizeStructure[player.rank];
      }
    }
    
    // Handle ties
    if (player.tied) {
      const tiedPlayers = rankings.filter(p => p.rank === player.rank);
      const totalPrize = calculateTiedPrize(player.rank, pool.prizeStructure);
      prize = totalPrize / tiedPlayers.length;
    }
    
    // Apply prize
    if (prize > 0) {
      await addBR(player.userId, prize, `Pool prize: Rank #${player.rank}`);
      
      distributions.push({
        userId: player.userId,
        rank: player.rank,
        prize: prize,
        type: player.winType || 'standard'
      });
    }
  }
  
  // Log distributions
  await logPrizeDistribution(poolId, distributions);
  
  // Update pool with final distributions
  await updatePool(poolId, {
    prizeDistributions: distributions,
    distributedAt: now()
  });
  
  return distributions;
}
```

## Game Modes & Rules

### Pool Game Modes

#### Classic Mode
```javascript
{
  mode: 'classic',
  description: 'Traditional pick the winner',
  powerCards: false,
  scoring: {
    correct: 100,
    incorrect: 0
  },
  tiebreaker: 'pickTime',
  suitable: ['all_sports']
}
```

#### Power Play Mode
```javascript
{
  mode: 'power_play',
  description: 'Strategic card-enhanced gameplay',
  powerCards: {
    enabled: true,
    maxPerGame: 3,
    allowedTypes: 'all'
  },
  scoring: {
    base: 100,
    cardModifiers: true
  },
  suitable: ['all_sports']
}
```

#### Confidence Mode
```javascript
{
  mode: 'confidence',
  description: 'Assign confidence points to picks',
  powerCards: {
    enabled: true,
    maxPerGame: 1,
    allowedTypes: ['defensive', 'utility']
  },
  scoring: {
    method: 'confidence_weighted',
    pointsToAssign: 16, // For NFL week
    distribution: 'unique' // Can't use same confidence twice
  },
  suitable: ['nfl', 'ncaa_football']
}
```

#### Spread Mode
```javascript
{
  mode: 'spread',
  description: 'Pick against the spread',
  powerCards: {
    enabled: false // Pure skill
  },
  scoring: {
    coverSpread: 100,
    pushSpread: 50,
    missSpread: 0
  },
  suitable: ['nfl', 'nba', 'ncaa']
}
```

#### Survivor Mode
```javascript
{
  mode: 'survivor',
  description: 'One loss and you\'re out',
  powerCards: {
    enabled: true,
    maxPerSeason: 1,
    allowedTypes: ['extra_life_card']
  },
  rules: {
    picksPerWeek: 1,
    canRepeatTeam: false,
    elimination: 'single_loss'
  },
  suitable: ['nfl', 'nba']
}
```

#### Props Mode
```javascript
{
  mode: 'props',
  description: 'Bet on player performances',
  powerCards: {
    enabled: true,
    allowedTypes: ['utility', 'defensive']
  },
  categories: [
    'first_touchdown',
    'total_points',
    'player_yards',
    'three_pointers'
  ],
  suitable: ['all_sports']
}
```

### Sport-Specific Rules

#### NFL/Football
```javascript
{
  sport: 'nfl',
  gameDuration: '3.5 hours',
  cardCutoffs: {
    preGame: 'kickoff',
    mulligan: 'kickoff',
    doubleDown: 'halftime',
    insurance: 'start_4th_quarter',
    steal: 'two_minute_warning'
  },
  scoring: {
    winner: 100,
    spread: 100,
    overUnder: 100,
    props: 'varies'
  }
}
```

#### NBA/Basketball
```javascript
{
  sport: 'nba',
  gameDuration: '2.5 hours',
  cardCutoffs: {
    preGame: 'tipoff',
    mulligan: 'tipoff',
    doubleDown: 'halftime',
    insurance: 'start_4th_quarter',
    steal: 'last_2_minutes'
  },
  scoring: {
    winner: 100,
    spread: 100,
    overUnder: 100,
    quarterWinners: 25
  }
}
```

#### MMA/Boxing
```javascript
{
  sport: 'mma',
  gameDuration: 'varies',
  cardCutoffs: {
    preGame: 'fight_start',
    mulligan: 'fight_start',
    doubleDown: 'after_round_1',
    insurance: 'after_round_2',
    steal: 'not_available'
  },
  scoring: {
    winner: 100,
    method: 50, // KO, submission, decision
    round: 50,
    exactResult: 200
  }
}
```

## Implementation Plan

### Phase 1: Core Pool System (Week 1-2)
- [ ] Remove all mock data
- [ ] Implement pool lifecycle management
- [ ] Create automatic pool generation
- [ ] Add pool activation/cancellation logic
- [ ] Build real-time pool discovery

### Phase 2: Scoring & Settlement (Week 3-4)
- [ ] Implement live scoring engine
- [ ] Create winner determination algorithms
- [ ] Build prize distribution system
- [ ] Add transaction logging
- [ ] Implement dispute resolution

### Phase 3: Power Cards Integration (Week 5-6)
- [ ] Create card inventory system
- [ ] Implement card playing mechanics
- [ ] Add card effect processors
- [ ] Build card UI components
- [ ] Test card interactions

### Phase 4: Game Modes (Week 7-8)
- [ ] Implement different pool modes
- [ ] Add sport-specific rules
- [ ] Create confidence pools
- [ ] Build survivor pools
- [ ] Add tournament brackets

### Phase 5: Testing & Optimization (Week 9-10)
- [ ] Load testing with 1000+ concurrent pools
- [ ] Card effect edge cases
- [ ] Prize distribution accuracy
- [ ] Refund scenarios
- [ ] Performance optimization

## Database Schema

### Pools Collection
```javascript
{
  poolId: string,
  gameId: string,
  type: string,
  mode: string,
  status: string,
  
  // Players
  minPlayers: number,
  maxPlayers: number,
  currentPlayers: number,
  playerIds: array,
  
  // Financials
  entryFee: number,
  prizePool: number,
  platformFee: number,
  prizeStructure: object,
  
  // Timing
  createdAt: timestamp,
  activationDeadline: timestamp,
  startTime: timestamp,
  endTime: timestamp,
  
  // Rules
  powerCardsEnabled: boolean,
  cardRules: object,
  scoringSystem: string,
  
  // Results
  finalRankings: array,
  prizeDistributions: array,
  completedAt: timestamp
}
```

### Pool Entries Collection
```javascript
{
  entryId: string,
  poolId: string,
  userId: string,
  
  // Entry details
  joinedAt: timestamp,
  entryFee: number,
  
  // Picks
  pick: string,
  pickTime: timestamp,
  confidencePoints: number,
  
  // Cards
  cardsAvailable: array,
  cardsUsed: array,
  cardEffects: array,
  
  // Scoring
  liveScore: number,
  finalScore: number,
  rank: number,
  
  // Results
  correct: boolean,
  brEarned: number,
  brLost: number,
  netBR: number
}
```

### Card Plays Collection
```javascript
{
  playId: string,
  poolId: string,
  userId: string,
  cardId: string,
  
  // Timing
  playedAt: timestamp,
  gamePhase: string,
  
  // Target
  targetUserId: string,
  targetType: string,
  
  // Effect
  effectApplied: object,
  effectDuration: object,
  reversed: boolean,
  
  // Validation
  validPlay: boolean,
  rejectionReason: string
}
```

## Security & Anti-Cheat

### Measures
1. **Transaction-based operations** - All financial operations in transactions
2. **Server-side validation** - Never trust client for scores or results
3. **Rate limiting** - Prevent card spamming
4. **Audit trails** - Log all actions with timestamps
5. **Dispute system** - 24-hour window for challenges
6. **Trust scores** - Track player reliability
7. **Card cooldowns** - Prevent rapid card usage
8. **Pick locks** - No changes after deadlines
9. **Result verification** - 5-minute buffer for official results
10. **Refund protection** - Automatic refunds for cancelled pools

## Success Metrics

### KPIs
- Pool fill rate: Target 80%+ 
- Average players per pool: Target 15+
- Card usage rate: Target 40% of pools
- Settlement accuracy: Target 99.9%
- Dispute rate: Target <1%
- Player retention: Target 60% monthly active
- Revenue per pool: Target $2-5 platform fee
- Pool completion rate: Target 95%+

## Conclusion

This comprehensive pool system integrates traditional pool mechanics with innovative Power Cards, creating a unique and engaging experience. The system is designed to be fair, scalable, and profitable while maintaining the excitement of sports wagering with friends.