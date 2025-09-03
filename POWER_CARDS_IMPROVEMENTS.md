# Power Cards System Improvements Plan

## Phase 1: Core Infrastructure (Priority 1)
### 1.1 Rules Controller
- [ ] Create `CardRulesController` class
- [ ] Implement sport-specific validation
- [ ] Add game state detection (pregame, live, quarters/periods)
- [ ] Create card compatibility matrix
- [ ] Add cooldown system to prevent spam

### 1.2 Card Playing Interface
- [ ] Design card playing page/modal
- [ ] Create real-time card effects display
- [ ] Add card history feed
- [ ] Implement card animation system
- [ ] Show active effects on all players

### 1.3 Database Schema Updates
- [ ] Add `card_plays` collection
- [ ] Create `active_effects` subcollection
- [ ] Add card history to pool documents
- [ ] Track card usage analytics

## Phase 2: Enhanced Card Types (Priority 2)

### 2.1 Sabotage Cards
- [ ] **Jinx** (🎭): Reduce opponent's win probability by 10%
- [ ] **Steal** (👻): Take 20% of opponent's winnings
- [ ] **Chaos** (🌪️): Randomize one opponent's pick
- [ ] **Curse** (🔥): Opponent needs larger margin to win
- [ ] **Freeze** (🧊): Lock opponent from using cards for 30 min

### 2.2 Collaborative Cards
- [ ] **Rally** (📣): Boost all same-pick players by 10%
- [ ] **Unity** (🤝): Equal split among same-pick winners
- [ ] **Captain** (👑): Lead bonus for followers
- [ ] **Team Spirit** (🎊): Group multiplier based on consensus

### 2.3 Information Cards
- [ ] **Spy** (🕵️): View opponent's unused cards
- [ ] **Oracle** (👁️): See live odds changes
- [ ] **Insider** (📊): Get injury/lineup updates
- [ ] **Scout** (🔍): See historical performance vs opponent

### 2.4 Combo Cards
- [ ] **Perfect Pair**: Bonus for using 2 specific cards together
- [ ] **Trinity**: 3-card combo for massive effect
- [ ] **Chain Reaction**: Trigger effects based on game events

## Phase 3: Advanced Features (Priority 3)

### 3.1 Card Trading System
- [ ] Create card marketplace
- [ ] Implement trade requests
- [ ] Add card valuation algorithm
- [ ] Create trade history
- [ ] Add trade restrictions/cooldowns

### 3.2 Card Crafting
- [ ] Combine 3 common → 1 uncommon
- [ ] Combine 3 uncommon → 1 rare
- [ ] Combine 2 rare → 1 legendary
- [ ] Add crafting animations
- [ ] Create crafting events

### 3.3 Achievement Cards
- [ ] **First Win**: Earned on first pool victory
- [ ] **Streak Master**: 5+ win streak
- [ ] **Underdog**: Win against 80%+ opposition
- [ ] **Perfect Season**: Win all pools in a week
- [ ] **High Roller**: Win 1000+ BR pool

### 3.4 Seasonal/Event Cards
- [ ] **March Madness** exclusive cards
- [ ] **Super Bowl** special editions
- [ ] **World Cup** themed cards
- [ ] **NBA Finals** power-ups
- [ ] Limited-time holiday cards

## Phase 4: Social & Competitive (Priority 4)

### 4.1 Card Tournaments
- [ ] Card-only pools (no BR entry)
- [ ] Card battle modes
- [ ] Card collection leaderboards
- [ ] Rarest card showcases

### 4.2 Card Gifting
- [ ] Send cards to friends
- [ ] Thank you card rewards
- [ ] Birthday card bonuses
- [ ] Referral card rewards

### 4.3 Card Packs & Loot Boxes
- [ ] **Starter Pack**: 5 common, 2 uncommon
- [ ] **Pro Pack**: 3 uncommon, 2 rare, 1 legendary chance
- [ ] **Mystery Box**: Random assortment
- [ ] **Sport Pack**: Sport-specific cards
- [ ] **Mega Pack**: Guaranteed legendary

## Phase 5: Balance & Economics (Priority 5)

### 5.1 Card Economy
- [ ] Dynamic pricing based on usage
- [ ] Card inflation prevention
- [ ] Rare card distribution limits
- [ ] Card retirement system
- [ ] Card rebalancing mechanism

### 5.2 Anti-Abuse Systems
- [ ] Card usage limits per day
- [ ] Collusion detection
- [ ] Multi-account prevention
- [ ] Fair play enforcement
- [ ] Card effect caps

## Implementation Timeline

### Month 1
- Complete Phase 1.1 (Rules Controller)
- Complete Phase 1.2 (Playing Interface)
- Begin Phase 1.3 (Database Updates)

### Month 2
- Complete Phase 1.3
- Implement 50% of Phase 2 cards
- Begin testing and balancing

### Month 3
- Complete Phase 2
- Begin Phase 3.1 (Trading)
- Launch beta testing

### Month 4-6
- Complete Phases 3-4
- Full launch
- Monitor and adjust

## Success Metrics

1. **Engagement**
   - Daily active card users
   - Cards played per pool
   - Card purchase revenue

2. **Balance**
   - Win rate variance with/without cards
   - Most/least used cards
   - Card effect on pool outcomes

3. **Economy**
   - Average cards per user
   - Card circulation velocity
   - BR spent on cards vs pools

4. **User Satisfaction**
   - Card system NPS score
   - Feature request tracking
   - Complaint/praise ratio

## Risk Mitigation

1. **Pay-to-Win Concerns**
   - Limit legendary cards per pool
   - Free card earning opportunities
   - Skill-based matchmaking

2. **Complexity Overload**
   - Gradual card introduction
   - Tutorial system
   - Simple mode option

3. **Technical Challenges**
   - Extensive testing
   - Gradual rollout
   - Rollback capabilities

## Notes

- All card effects should be clearly visible to all players
- Card history must be auditable
- Consider regulatory implications for different regions
- Maintain game integrity as primary concern