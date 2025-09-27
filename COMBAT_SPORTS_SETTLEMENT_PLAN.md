# Combat Sports (MMA/Boxing) Settlement System

## Overview
Automated settlement system for MMA and Boxing betting pools using ESPN API data. This system handles fight result detection, score calculation, and prize distribution without manual admin intervention.

## Scope
- **Sports Covered**: MMA (UFC, Bellator, ONE) and Boxing only
- **Not Applicable To**: Traditional sports (NFL, NBA, MLB, etc.)
- **Data Source**: ESPN API exclusively

## System Architecture

### 1. Multi-Layer Monitoring System

#### Real-Time Fight Monitoring
- **Frequency**: Every 5 minutes during active events
- **Active Window**: Event start time -2 hours to +8 hours
- **Purpose**: Detect individual fight results as they complete

```javascript
// Scheduled Cloud Function
exports.monitorCombatSportsResults = functions.pubsub
  .schedule('every 5 minutes')
  .onRun(async () => {
    // Only process MMA and Boxing events
    const activeEvents = await getActiveCombatEvents(['MMA', 'BOXING']);

    for (const event of activeEvents) {
      await checkFightResults(event);
    }
  });
```

### 2. Event State Machine

```
SCHEDULED → LIVE → COMPLETING → READY_TO_SETTLE → SETTLING → SETTLED
```

- **SCHEDULED**: Before first fight starts
- **LIVE**: First fight has started
- **COMPLETING**: Main event finished OR 50%+ of card complete
- **READY_TO_SETTLE**: All fights done OR timeout reached
- **SETTLING**: Calculating scores and payouts
- **SETTLED**: BR tokens distributed

### 3. Settlement Triggers

Settlement initiates when ANY of these conditions are met:

1. **All Fights Complete**: Every scheduled fight has a result
2. **Main Event + 80% Complete**: Main event finished and 80% of undercard complete
3. **Timeout**: Event end time + 3 hours with 50%+ fights complete

### 4. Data Collection & Storage

#### Fight Result Structure
```javascript
{
  fightId: string,
  eventId: string,
  completed: boolean,
  timestamp: Timestamp,

  // Winner Information
  winnerId: string,
  winnerName: string,

  // Fight Details
  round: number,        // Round ended (null for decision)
  time: string,         // Time in round (e.g., "2:34")
  method: string,       // KO, TKO, SUBMISSION, DECISION, DRAW
  methodDetail: string, // Raw text from ESPN

  // Tracking
  espnStatus: string,
  processed: boolean,
  scoringComplete: boolean
}
```

### 5. Method Detection & Matching

#### Method Categories for MMA
- **KO/TKO**: Knockout, Technical Knockout
- **SUBMISSION**: Tap out, verbal submission, technical submission
- **DECISION**: Unanimous, Split, Majority
- **DRAW/NC**: Draw, No Contest

#### Method Categories for Boxing
- **KO/TKO**: Knockout, Technical Knockout, RTD (Retired)
- **DECISION**: Unanimous, Split, Majority, Technical
- **DRAW**: Draw, Technical Draw
- **DQ/NC**: Disqualification, No Contest

#### Flexible Matching Logic
```javascript
function matchCombatMethod(userPick, actualMethod) {
  // User picked "KO/TKO" matches both "KO" and "TKO"
  // User picked "DECISION" matches all decision types
  // User picked "SUBMISSION" matches all submission types
}
```

### 6. Scoring System

#### Point Structure
- **Correct Winner**: 1.0 base points
- **Correct Method**: +0.3 bonus points
- **Correct Round**: +0.2 bonus points (not applicable for decisions)
- **Confidence Multiplier**: 0.8x to 1.3x (based on 1-5 star rating)

#### Special Rules
- Round prediction disabled when DECISION is selected
- No round bonus for fights that go to decision
- Underdog bonus calculated from pre-fight odds (if available)

### 7. Partial Event Handling

#### Completion Thresholds
- **100% Complete**: Normal settlement
- **80%+ Complete**: Settle with normalized scoring
- **50-79% Complete**: Settle with admin notification
- **<50% Complete**: Hold for admin review
- **0% Complete**: Full refund (event cancelled)

#### Score Normalization
When not all fights complete:
```javascript
normalizedScore = rawScore * (totalFights / completedFights)
```

### 8. Polling Strategy

#### Standard Polling (Scheduled Events)
- **Pre-Event**: Check every 30 minutes starting 2 hours before
- **Live Event**: Check every 5 minutes
- **Post-Event**: Check every 15 minutes until settled
- **Timeout**: Stop polling 8 hours after start time

#### Aggressive Polling (PPV/Major Events)
- **Live Event**: Check every 2 minutes
- **Triggered By**: Events marked as "PPV" or "Title Fight"

### 9. Settlement Process Flow

```
1. Detect Event Ready for Settlement
   ↓
2. Lock Pool (No New Entries/Changes)
   ↓
3. Fetch All Fight Results
   ↓
4. Calculate User Scores
   ↓
5. Determine Rankings
   ↓
6. Calculate Payouts (Based on Pool Structure)
   ↓
7. Distribute BR Tokens
   ↓
8. Send Notifications
   ↓
9. Mark Pool as Settled
```

### 10. Prize Distribution

#### Pool Structures (No House Cut - 100% to Winners)
- **Quick Play**: Top 40% of participants win
- **Tournament**: Top 25% of participants win
- **Winner Take All**: Only 1st place wins
- **Top 3**: Top 15% of participants win

### 11. Edge Cases & Error Handling

#### Fight-Specific Issues
- **No Contest**: Exclude from scoring
- **Fighter Withdrawal**: Skip fight in scoring
- **Weight Miss**: Process normally (fight still happens)
- **Catchweight**: Process normally

#### Event-Level Issues
- **Event Cancellation**: Full refund if no fights complete
- **Venue Change**: No impact on settlement
- **Date Change**: Update monitoring schedule
- **Partial Card**: Settle based on completed fights

#### Technical Issues
- **ESPN API Down**: Retry with exponential backoff
- **Missing Method Data**: Default to "UNKNOWN" and match winner only
- **Duplicate Results**: Use timestamp to keep latest
- **Network Timeout**: Queue for retry

### 12. Notifications

#### User Notifications
- **Fight Complete**: Optional live update during event
- **Event Complete**: "Event finished, calculating results..."
- **Settlement Complete**: "You won X BR!" or "Better luck next time"
- **Refund Issued**: "Event cancelled - entry refunded"

### 13. Audit Trail

#### Required Logging
```javascript
{
  eventId: string,
  poolId: string,
  action: string, // RESULT_DETECTED, SETTLEMENT_TRIGGERED, PAYOUT_COMPLETE
  timestamp: Timestamp,
  details: object,
  source: string, // ESPN_API, CLOUD_FUNCTION, ADMIN_OVERRIDE
}
```

## Implementation Phases

### Phase 1: Core Settlement (Week 1-2)
- Fight result detection from ESPN
- Basic score calculation
- Manual settlement trigger

### Phase 2: Automation (Week 3-4)
- Automated polling system
- Settlement triggers
- State machine implementation

### Phase 3: Payout System (Week 5-6)
- BR token distribution
- Pool payout structures
- Transaction logging

### Phase 4: Notifications (Week 7)
- Push notifications
- Email notifications
- In-app notifications

### Phase 5: Edge Cases (Week 8)
- Partial event handling
- Cancellation logic
- Admin override tools

## Testing Strategy

### Test Scenarios
1. Normal event - all fights complete
2. Main event only completes
3. Event cancelled before start
4. Event stopped mid-way (injury/weather)
5. Multiple no-contests
6. API returns partial data
7. Network failures during settlement

### Test Events
Use historical UFC/Boxing events with known results to validate scoring accuracy.

## Security Considerations

- No manual score manipulation
- All settlements logged for audit
- Payout caps to prevent overflow attacks
- Rate limiting on API calls
- Webhook validation for any external triggers

## Performance Targets

- Result detection: Within 5 minutes of fight ending
- Settlement completion: Within 15 minutes of event ending
- Payout distribution: Within 1 minute of settlement
- API response time: <2 seconds
- Settlement accuracy: 99.9%

## Monitoring & Alerts

### Key Metrics
- Events monitored per day
- Settlement success rate
- Average settlement time
- API failure rate
- User dispute rate

### Alert Triggers
- Settlement fails 3x in a row
- API unavailable >30 minutes
- Unusual payout amounts detected
- Manual intervention required

## Future Enhancements

- Real-time WebSocket updates during events
- Prop bet support (FOTN bonus, specific submission type)
- Parlay/accumulator betting
- Live betting (mid-fight picks)
- Historical performance analytics
- AI-powered method prediction from fight flow

## Dependencies

- ESPN API access
- Firebase Cloud Functions
- Firestore database
- Cloud Scheduler
- Firebase Cloud Messaging (FCM)

## Compliance Notes

- No real money gambling
- BR tokens only (virtual currency)
- Skill-based scoring system
- No odds-based payouts
- Entertainment purposes only