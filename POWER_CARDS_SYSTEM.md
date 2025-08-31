# Bragging Rights Power Cards System

## Overview
Power Cards are special in-app purchase items that add strategic gameplay elements to Bragging Rights. Similar to power-ups in games like Uno, these cards allow players to influence outcomes, protect themselves, or affect other players during pools and wagers.

## Card Categories

### 🛡️ Defensive Cards (Protect Yourself)
These cards help players defend their position or recover from losses.

| Card | Price | Effect | When to Use |
|------|-------|---------|-------------|
| **Extra Life Card** | $2.99 | Get back into an eliminated pool | After elimination from survivor pool |
| **Eraser Card** | $3.99 | Turn one loss into a win | After a game ends unfavorably |
| **Shield Card** | $1.99 | Block one attack card from another player | When targeted by offensive card |
| **Insurance Card** | $1.99 | Get 50% of wager back if you lose | Before placing risky wager |
| **Mulligan Card** | $1.99 | Change your pick before game starts | After making pick, before game starts |
| **Time Freeze Card** | $0.99 | Extend deadline by 15 minutes | When about to miss pick deadline |

### ⚔️ Offensive Cards (Affect Others)
These cards allow players to disrupt opponents' strategies.

| Card | Price | Effect | When to Use |
|------|-------|---------|-------------|
| **Steal Card** | $4.99 | Swap your loss with another's win | After games conclude |
| **Sabotage Card** | $3.99 | Force opponent to pick opposite team | Before opponent makes pick |
| **Curse Card** | $2.99 | Give opponent -10% odds on next pick | Before opponent's next wager |
| **Copycat Card** | $2.99 | Copy the current leader's pick | Before making your pick |
| **Chaos Card** | $2.99 | Randomize one opponent's pick | After picks are locked |
| **Veto Card** | $3.99 | Cancel another player's power card | When opponent plays power card |

### 🎯 Utility Cards (Special Effects)
These cards provide unique advantages without directly affecting others.

| Card | Price | Effect | When to Use |
|------|-------|---------|-------------|
| **Double Down Card** | $3.99 | Double your winnings if you win | Before placing confident pick |
| **Crystal Ball Card** | $2.99 | See what majority picked | Before making your pick |
| **Lucky Charm Card** | $2.99 | +15% better odds on next pick | Before placing wager |
| **Split Card** | $3.99 | Bet on both teams (small guaranteed win) | For must-win situations |
| **Wildcard** | $9.99 | Acts as any other card | Emergency situations |
| **Referee Card** | $4.99 | Override one controversial call | After disputed game result |

### 👥 Social Cards (Group Effects)
These cards affect multiple players or the entire pool.

| Card | Price | Effect | When to Use |
|------|-------|---------|-------------|
| **Party Pooper Card** | $3.99 | Cancel all power cards in current game | When too many cards in play |
| **Robin Hood Card** | $2.99 | Take 10% from leader, give to last | Mid-pool to balance standings |
| **Amnesty Card** | $4.99 | All eliminated players return | To reset survivor pool |
| **Blackout Card** | $2.99 | Hide all picks until game starts | Before picks are made |
| **Auction Card** | $3.99 | Force highest bidder to switch teams | During live game |

## Card Packs & Bundles

| Pack | Price | Contents | Value |
|------|-------|----------|-------|
| **Starter Pack** | $2.99 | 3 random common cards | Good for beginners |
| **Power Pack** | $4.99 | 5 cards with 1 guaranteed rare | Mid-tier value |
| **Ultimate Pack** | $9.99 | 10 cards with 2 guaranteed epic | Best random value |
| **Defensive Bundle** | $14.99 | All 6 defensive cards | Save $3.94 |
| **Offensive Bundle** | $19.99 | All 6 offensive cards | Save $4.94 |
| **Master Collection** | $49.99 | ALL 22 power cards | Save $25+ |

## Implementation Strategy

### Phase 1: Foundation (Week 1-2)
1. **Card Inventory System**
   - Create card storage in Firestore per user
   - Track owned cards and quantities
   - Implement card purchase flow

2. **Card UI Components**
   - Card collection screen in profile
   - Card selection during games
   - Animation effects when played

### Phase 2: Core Mechanics (Week 3-4)
1. **Card Playing System**
   - Add "Use Power Card" button in active games
   - Implement timing rules (before/during/after game)
   - Create card effect processors

2. **Card Rules Engine**
   - Validate when cards can be played
   - Process card effects on game state
   - Handle card interactions (Shield blocks Steal, etc.)

### Phase 3: Pool Integration (Week 5-6)
1. **Pool Settings**
   - Allow pool creators to enable/disable cards
   - Set card limits per pool
   - Create card-specific pool types

2. **Card Notifications**
   - Alert when targeted by card
   - Show when cards are played
   - Display card effects in game feed

## Game Modes

### Classic Mode
- No power cards allowed
- Pure skill-based competition
- Original Bragging Rights experience

### Power Play Mode
- All cards enabled
- Strategic gameplay emphasis
- Higher stakes and rewards

### Card Mayhem Mode
- Unlimited card usage
- Chaotic, fun-focused gameplay
- Special tournaments

### Draft Mode
- Each player gets 3 random cards at start
- Equal playing field
- Tournament style

## Monetization Impact

### Revenue Streams
1. **Direct Card Sales**: $0.99 - $9.99 per card
2. **Card Packs**: $2.99 - $9.99 for random bundles
3. **Premium Bundles**: $14.99 - $49.99 for collections
4. **Subscription Tier**: Include monthly card allowance

### Engagement Drivers
- **Collection Mentality**: Encourage completing card sets
- **Strategic Depth**: Add layers to gameplay
- **Social Pressure**: Others using cards creates FOMO
- **Seasonal Cards**: Limited-time special cards

## Balance Considerations

### Card Limitations
- Maximum 3 cards per game
- Cooldown periods between uses
- Pool-specific restrictions
- Rarity-based availability

### Counter-Play
- Shield blocks offensive cards
- Veto cancels any card
- Party Pooper resets all cards
- Classic mode for purists

### Fair Play
- Matchmaking considers card inventory
- Free card rewards for active players
- Daily login bonuses include cards
- Achievement-based card unlocks

## Technical Implementation

### Database Structure
```
/users/{userId}/cards
  - cardId: string
  - quantity: number
  - lastUsed: timestamp
  - totalUses: number

/pools/{poolId}/cardRules
  - cardsEnabled: boolean
  - maxCardsPerPlayer: number
  - allowedCardTypes: array
  - bannedCards: array

/games/{gameId}/cardPlays
  - playerId: string
  - cardId: string
  - targetId: string (optional)
  - timestamp: timestamp
  - effect: object
```

### Card Effect Processing
```javascript
// Example: Process Steal Card
async function processStealCard(gameId, playerId, targetId) {
  // 1. Validate card ownership
  // 2. Check if target has win
  // 3. Swap outcomes
  // 4. Update standings
  // 5. Send notifications
  // 6. Log card usage
}
```

## Future Expansions

### Season 2 Cards
- Weather cards (affect outdoor games)
- Momentum cards (streak bonuses)
- Alliance cards (team up with others)
- Revenge cards (target previous attackers)

### Special Event Cards
- Super Bowl exclusive cards
- March Madness tournament cards
- World Cup special editions
- Playoff-specific power-ups

### Card Trading System
- Player-to-player trading
- Card marketplace
- Auction house
- Trade-in system for duplicates

## Success Metrics

### KPIs to Track
- Card purchase conversion rate
- Average cards used per game
- Player retention with/without cards
- Revenue per card type
- Pool completion rates with cards enabled

### Target Goals (First Quarter)
- 30% of active players purchase at least one card
- 15% purchase card packs
- 5% purchase premium bundles
- 20% increase in session length
- 25% increase in revenue per user

## Marketing Strategy

### Launch Campaign
1. **Free Starter Cards**: Give 3 free cards to all players
2. **Tutorial Mode**: Teach card mechanics with rewards
3. **Launch Tournament**: Card-enabled pools with prizes
4. **Influencer Packs**: Special codes for content creators

### Ongoing Promotion
- Weekly featured card sales
- Bundle discounts
- Seasonal card releases
- Achievement-based unlocks
- Referral card rewards

## Risk Mitigation

### Potential Issues & Solutions
1. **Pay-to-Win Perception**
   - Solution: Classic mode, free card rewards, skill-based matchmaking

2. **Card Complexity**
   - Solution: Progressive tutorial, simple starter cards, tooltips

3. **Balance Problems**
   - Solution: Card adjustments, usage analytics, player feedback

4. **Technical Bugs**
   - Solution: Extensive testing, gradual rollout, rollback system

## Conclusion

The Power Cards system transforms Bragging Rights from a simple sports betting app into a strategic, engaging game platform. By adding collectible elements and tactical gameplay, we create multiple revenue streams while increasing player engagement and retention. The system is designed to be fun for casual players while offering depth for competitive users, ensuring broad appeal across our user base.