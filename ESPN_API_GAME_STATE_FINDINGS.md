# ESPN API Game State Analysis - Detailed Findings

## Executive Summary
ESPN API provides comprehensive, granular game state data for FREE, making it the ideal choice for tracking period/quarter/inning changes needed for the power card system.

## Available Data by Sport

### 🏀 NBA (Basketball)
**Granularity: EXCELLENT**
- **Period Data**: Quarter number (1-4) + Overtime periods
- **Clock**: Exact game clock (MM:SS format, e.g., "5:23")
- **Play-by-Play**: Every shot, foul, timeout, substitution
- **Timestamps**: Wallclock time for each play (exact second)
- **Special Events**: Timeouts, technical fouls, reviews
- **Update Frequency**: ~15-30 seconds for scoreboard, real-time for play-by-play

```json
Example NBA Play:
{
  "period": {"number": 3, "displayValue": "3rd Quarter"},
  "clock": {"displayValue": "7:45"},
  "type": {"text": "Jump Shot"},
  "scoringPlay": true,
  "shootingPlay": true,
  "wallclock": "2024-01-09T01:45:23Z"
}
```

### 🏈 NFL (Football)
**Granularity: EXCELLENT**
- **Period Data**: Quarter number (1-4) + Overtime
- **Clock**: Game clock (MM:SS)
- **Situation Data**: 
  - Down & Distance (e.g., "3rd & 7")
  - Field position (yard line)
  - Possession team
  - Red zone indicator
  - Timeouts remaining (per team)
- **Drive Summaries**: Complete drive data with plays
- **Play-by-Play**: Every snap with result
- **Update Frequency**: ~15-30 seconds

```json
Example NFL Situation:
{
  "down": 3,
  "distance": 7,
  "yardLine": 35,
  "possession": "KC",
  "isRedZone": false,
  "homeTimeouts": 2,
  "awayTimeouts": 3,
  "lastPlay": {"text": "Patrick Mahomes pass incomplete to Travis Kelce"}
}
```

### ⚾ MLB (Baseball)
**Granularity: GOOD**
- **Period Data**: Inning number + Top/Bottom
- **No Clock**: Baseball has no game clock
- **At-Bat Details**: Balls, strikes, outs, runners on base
- **Play-by-Play**: Every pitch result
- **Special Events**: Pitching changes, reviews
- **Update Frequency**: After each play completes

```json
Example MLB State:
{
  "period": {"number": 5, "displayValue": "5th Inning"},
  "inning": "top",
  "outs": 2,
  "balls": 3,
  "strikes": 2,
  "runnersOn": [1, 3]
}
```

### 🏒 NHL (Hockey)
**Granularity: GOOD**
- **Period Data**: Period number (1-3) + Overtime/Shootout
- **Clock**: Period clock (MM:SS)
- **Special Situations**: Power play, penalty kill
- **Play-by-Play**: Goals, shots, penalties, faceoffs
- **Update Frequency**: ~15-30 seconds

### 🥊 UFC/MMA
**Granularity: LIMITED**
- **Round Data**: Round number (1-3 or 1-5)
- **Clock**: Round time remaining (when available)
- **Event Details**: Limited to round results
- **No Play-by-Play**: Only round-end summaries
- **Update Frequency**: After each round

```json
Example UFC Data:
{
  "status": {"period": 2, "displayClock": "3:45"},
  "details": [
    {"type": {"text": "Round End"}},
    {"type": {"text": "Round Start"}}
  ]
}
```

### 🎾 Tennis
**Granularity: LIMITED**
- **Set/Game Score**: Current set and game
- **Serve Information**: Who's serving
- **Point-by-point**: Not available in free API
- **Update Frequency**: After each game

## Data Endpoints Comparison

| Endpoint | Update Rate | Data Detail | Best For |
|----------|------------|-------------|----------|
| `/scoreboard` | 15-30 sec | Basic game state, scores, period, clock | Quick status checks |
| `/summary` | 15-30 sec | Detailed + play-by-play history | Full game tracking |
| `/playbyplay` | Real-time* | Every play with timestamps | Card timing precision |

*Note: Play-by-play endpoint appears to be deprecated/empty in testing

## Critical Timing Windows for Cards

### Before Halftime Cards
**NBA**: Period < 3 (Before 3rd quarter)
**NFL**: Period < 3 (Before 3rd quarter)  
**MLB**: Inning < 5 (Before 5th inning)
**NHL**: Period < 2 (Before 2nd period)

### Before 4th Quarter Cards
**NBA**: Period < 4
**NFL**: Period < 4
**MLB**: Inning < 7 (7th inning stretch)
**NHL**: Period < 3

### Live Game Only Cards
All sports: `status.type.name === "STATUS_IN_PROGRESS"`

## Implementation Recommendations

### 1. Use ESPN Summary Endpoint
```javascript
const url = `https://site.api.espn.com/apis/site/v2/sports/${sport}/${league}/summary?event=${gameId}`;
```

### 2. Poll Frequency Strategy
```javascript
// Normal polling
const NORMAL_INTERVAL = 30000; // 30 seconds

// Critical moment polling (last 2 min of period)
const CRITICAL_INTERVAL = 10000; // 10 seconds

// Determine polling rate
function getPollInterval(gameState) {
  if (gameState.clock && parseTime(gameState.clock) < 120) {
    return CRITICAL_INTERVAL;
  }
  return NORMAL_INTERVAL;
}
```

### 3. Card Availability Calculation
```javascript
function getAvailableCards(gameState, userCards) {
  const available = [];
  
  userCards.forEach(card => {
    switch(card.id) {
      case 'double_down':
        if (gameState.status === 'live' && gameState.period < 3) {
          available.push(card);
        }
        break;
      case 'insurance':
        if (gameState.status === 'live' && gameState.period < 4) {
          available.push(card);
        }
        break;
      case 'mulligan':
        if (gameState.status === 'scheduled') {
          available.push(card);
        }
        break;
    }
  });
  
  return available;
}
```

### 4. Period Change Detection
```javascript
class GameStateMonitor {
  constructor(gameId) {
    this.gameId = gameId;
    this.lastPeriod = null;
    this.listeners = [];
  }
  
  async checkState() {
    const state = await fetchGameState(this.gameId);
    
    if (state.period !== this.lastPeriod) {
      this.onPeriodChange(this.lastPeriod, state.period);
      this.lastPeriod = state.period;
    }
    
    return state;
  }
  
  onPeriodChange(oldPeriod, newPeriod) {
    // Notify card system
    this.listeners.forEach(listener => {
      listener({ event: 'period_change', old: oldPeriod, new: newPeriod });
    });
    
    // Check card cutoffs
    if (newPeriod === 3) {
      this.notifyCardCutoff('double_down', 'split_bet');
    }
    if (newPeriod === 4) {
      this.notifyCardCutoff('insurance');
    }
  }
}
```

## Comparison: ESPN vs The Odds API

| Feature | ESPN API | The Odds API |
|---------|----------|--------------|
| **Cost** | FREE | $0-599/month |
| **Period/Quarter Data** | ✅ Yes, detailed | ❌ No |
| **Game Clock** | ✅ Yes, exact time | ❌ No |
| **Play-by-Play** | ✅ Yes, with timestamps | ❌ No |
| **Possession/Situation** | ✅ Yes (NFL/NBA) | ❌ No |
| **Update Frequency** | 15-30 seconds | 60-120 seconds |
| **Request Limits** | None (unofficial) | 500/month (free) |
| **Best For** | Game state tracking | Odds/betting lines |

## Conclusion

**ESPN API is the clear winner** for tracking game state for the power card system:

1. **FREE** with no documented rate limits
2. **Granular period/quarter/inning data** for all major sports
3. **Exact game clock** for timed sports
4. **Play-by-play with timestamps** for precise event tracking
5. **Sport-specific details** (possession, timeouts, down & distance)

The Odds API should only be considered as a backup for getting final scores or if ESPN API becomes unavailable.

## Next Steps

1. Implement `GameStateMonitor` service using ESPN Summary endpoint
2. Create period change detection system
3. Build card availability calculator based on game state
4. Add real-time notifications for card cutoff warnings
5. Implement adaptive polling based on game criticality