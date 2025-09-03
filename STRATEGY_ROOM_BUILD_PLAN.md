# Strategy Room Build Plan

## Overview
Implementation of a comprehensive Strategy Room system where users commit their intel and power card strategies before submitting picks, with complete privacy until pool locks.

## Core Principles
1. **Privacy First**: No visibility of other players' picks/cards until after submission
2. **All Cards Consumed**: Intel and power cards are used regardless of triggers
3. **Accessible Pricing**: 5-20 BR for intel, 15-50 BR for power cards
4. **Strategic Commitment**: Lock in 3-phase card strategy before game starts
5. **Monthly Allowance Friendly**: 500 BR can support 8-10 full strategic plays

## System Architecture

### Phase Structure
```
PRE-SUBMISSION (Private):
├── Intel Phase (Optional)
│   └── Consume intel cards for information
├── Pick Phase
│   └── Make selections with intel insights
├── Strategy Room (Optional)
│   ├── Pre-Game Card Selection
│   ├── Mid-Game Card + Trigger
│   └── Post-Game Card + Condition
└── Final Review & Submit

POST-SUBMISSION (Public):
├── View all players' picks
├── View all card strategies
└── Track card activations during game
```

## Pricing Structure

### Intel Cards (5-20 BR)
```javascript
{
  // Basic (5-10 BR)
  'injury_reports': 5,
  'weather_report': 5,
  'referee_stats': 8,
  
  // Advanced (10-15 BR)
  'pre_game_analysis': 10,
  'live_sentiment': 12,
  'head_to_head': 15,
  
  // Premium (15-20 BR)
  'expert_picks': 18,
  'insider_tips': 20
}
```

### Power Cards (15-50 BR)
```javascript
{
  // Common (15-20 BR)
  'mulligan': 15,
  'insurance': 18,
  'time_freeze': 20,
  
  // Uncommon (25-30 BR)
  'crystal_ball': 25,
  'shield': 28,
  'copycat': 30,
  
  // Rare (35-40 BR)
  'double_down': 35,
  'hedge': 38,
  'wildcard': 40,
  
  // Legendary (45-50 BR)
  'all_in': 45,
  'lucky_charm': 50
}
```

## User Flow

### 1. Pool Selection
- Choose pool to enter
- See entry fee (25 BR standard)
- View pool rules and card allowances

### 2. Intel Consumption Phase
- Browse available intel cards
- Purchase and instantly consume for information
- Intel affects pick decisions
- Non-refundable once consumed

### 3. Pick Submission
- Make all selections
- Can modify until proceeding to Strategy Room
- Intel insights visible during selection

### 4. Strategy Room
- Select up to 3 power cards (1 per phase)
- Configure triggers for mid-game card
- Set conditions for post-game card
- Review total cost

### 5. Final Confirmation
```
Total Cost Breakdown:
- Pool Entry: 25 BR
- Intel Used: X BR
- Power Cards: Y BR
- Total: Z BR
- Remaining Balance: XXX BR
```

### 6. Post-Submission View
- All strategies revealed simultaneously
- Track card activations in real-time
- Monitor pool standings

## Database Schema

### Pool Strategy Structure
```typescript
// Intel consumption tracking
pools/{poolId}/intel_usage/{userId} {
  cards_consumed: [{
    card_id: string,
    cost: number,
    consumed_at: timestamp,
    target: string, // fight_id or game_id
    data_received: object
  }],
  total_spent: number
}

// Power card strategy
pools/{poolId}/strategies/{userId} {
  pre_card: {
    id: string,
    cost: number
  },
  mid_card: {
    id: string,
    cost: number,
    trigger: {
      type: 'round' | 'score' | 'time',
      value: any,
      condition: string
    }
  },
  post_card: {
    id: string,
    cost: number,
    condition: 'if_winning' | 'if_losing' | 'always'
  },
  total_cost: number,
  submitted_at: timestamp,
  locked: boolean
}

// Privacy control
pools/{poolId}/submissions/{userId} {
  picks_submitted: boolean,
  strategy_locked: boolean,
  submitted_at: timestamp,
  total_spent: number
}
```

## Implementation Phases

### Phase 1: Core Infrastructure (Week 1)
- [ ] Create Strategy Room screen
- [ ] Implement card selection UI
- [ ] Build trigger configuration system
- [ ] Add privacy enforcement logic
- [ ] Create submission flow

### Phase 2: Intel System (Week 1-2)
- [ ] Design intel card UI
- [ ] Implement consumption mechanics
- [ ] Create intel data display
- [ ] Add to pick flow
- [ ] Track usage in database

### Phase 3: Power Card Integration (Week 2)
- [ ] Update card definitions with new prices
- [ ] Create trigger validation system
- [ ] Build execution engine
- [ ] Add notification system
- [ ] Implement card activation monitoring

### Phase 4: Privacy & Security (Week 3)
- [ ] Enforce pick hiding before submission
- [ ] Implement simultaneous reveal
- [ ] Add transaction atomicity
- [ ] Create audit logging
- [ ] Build anti-cheat measures

### Phase 5: UI/UX Polish (Week 3-4)
- [ ] Add animations for card consumption
- [ ] Create strategy preview
- [ ] Build cost calculator
- [ ] Add confirmation dialogs
- [ ] Implement error handling

### Phase 6: Testing & Optimization (Week 4)
- [ ] Test all card combinations
- [ ] Verify trigger conditions
- [ ] Load test with multiple users
- [ ] Optimize database queries
- [ ] Fix edge cases

## UI Components

### 1. Strategy Room Screen
```dart
class StrategyRoomScreen extends StatefulWidget {
  final String poolId;
  final List<Pick> picks;
  final List<IntelCard> consumedIntel;
  final int poolEntryFee;
}
```

### 2. Intel Card Widget
```dart
class IntelCardWidget extends StatelessWidget {
  final IntelCard card;
  final VoidCallback onConsume;
  final bool canAfford;
}
```

### 3. Power Card Selector
```dart
class PowerCardSelector extends StatefulWidget {
  final GamePhase phase;
  final Function(PowerCard, TriggerCondition?) onSelect;
  final int maxCost;
}
```

### 4. Cost Summary Widget
```dart
class CostSummaryWidget extends StatelessWidget {
  final int entryFee;
  final int intelCost;
  final int powerCardCost;
  final int currentBalance;
}
```

## Trigger System

### Mid-Game Triggers
```dart
enum TriggerType {
  round,          // Specific round number
  score,          // Score differential
  time,           // Game clock
  percentage,     // Win percentage
  opponent_action // Opponent uses card
}

class TriggerCondition {
  final TriggerType type;
  final dynamic value;
  final String comparison; // 'equals', 'greater_than', 'less_than'
  
  bool evaluate(GameState state) {
    // Trigger evaluation logic
  }
}
```

### Post-Game Conditions
```dart
enum ResultCondition {
  if_winning,
  if_losing,
  if_tie,
  always
}
```

## Cloud Functions

### 1. Strategy Submission
```javascript
exports.submitPoolStrategy = functions.https.onCall(async (data, context) => {
  // Validate user
  // Check balances
  // Lock picks and strategy
  // Deduct costs
  // Make visible after submission
});
```

### 2. Card Execution Monitor
```javascript
exports.monitorCardTriggers = functions.pubsub.schedule('every 1 minute').onRun(async (context) => {
  // Check all active pools
  // Evaluate trigger conditions
  // Execute cards when triggered
  // Send notifications
  // Update pool states
});
```

### 3. Intel Data Provider
```javascript
exports.consumeIntelCard = functions.https.onCall(async (data, context) => {
  // Verify card ownership
  // Deduct from inventory
  // Fetch relevant data
  // Log consumption
  // Return intel data
});
```

## Security Considerations

1. **Atomic Transactions**: All-or-nothing submission
2. **Balance Verification**: Check funds before allowing strategy
3. **Timestamp Validation**: Prevent late submissions
4. **Privacy Enforcement**: Server-side visibility controls
5. **Anti-Pattern Detection**: Monitor for suspicious behavior

## Success Metrics

### Engagement
- Average cards used per pool
- Intel consumption rate
- Strategy completion rate
- Return player rate

### Economic
- Average spend per pool
- Monthly allowance utilization
- Card revenue per user
- Pool fill rates

### Gameplay
- Strategy diversity index
- Trigger success rate
- Win rate correlation with card usage
- Player satisfaction scores

## Monthly Allowance Impact

With 500 BR monthly allowance:
- **Free Players**: 20 pools (entry only)
- **Casual Players**: 10 pools with basic cards
- **Strategic Players**: 5-8 fully loaded pools
- **Competitive Players**: Purchase additional BR

## Risk Mitigation

1. **Price Adjustments**: Monitor and adjust card prices based on usage
2. **Trigger Balance**: Ensure triggers are achievable but not guaranteed
3. **Intel Value**: Keep intel impactful but not game-breaking
4. **Technical Issues**: Graceful degradation if services fail
5. **User Education**: Clear tutorials and tooltips

## Launch Strategy

### Soft Launch (Week 1)
- Enable for 10% of users
- Monitor usage patterns
- Gather feedback

### Adjustments (Week 2)
- Tune pricing based on data
- Fix discovered issues
- Optimize performance

### Full Launch (Week 3)
- Roll out to all users
- Marketing campaign
- Influencer showcases

### Post-Launch (Week 4+)
- Weekly card rotations
- Seasonal special cards
- Tournament modes
- Achievement system

## Future Enhancements

1. **Card Crafting**: Combine cards for better effects
2. **Card Trading**: Player-to-player marketplace
3. **Season Passes**: Monthly card subscriptions
4. **Guild Strategies**: Team-based card plays
5. **AI Opponents**: Practice against bot strategies

## Development Checklist

### Week 1
- [ ] Create Strategy Room UI
- [ ] Implement card selection logic
- [ ] Build trigger configuration
- [ ] Add cost calculator
- [ ] Create submission flow

### Week 2
- [ ] Add intel card system
- [ ] Implement privacy controls
- [ ] Build execution engine
- [ ] Create notifications
- [ ] Add database schema

### Week 3
- [ ] Polish UI/UX
- [ ] Add animations
- [ ] Implement error handling
- [ ] Create help system
- [ ] Build admin tools

### Week 4
- [ ] Complete testing
- [ ] Fix bugs
- [ ] Optimize performance
- [ ] Prepare launch
- [ ] Deploy to production

## Conclusion

The Strategy Room system transforms Bragging Rights from a simple betting app into a strategic gaming platform. By combining consumable intel cards with committed power card strategies, we create depth, engagement, and monetization opportunities while keeping the game accessible through reasonable pricing and the monthly allowance system.