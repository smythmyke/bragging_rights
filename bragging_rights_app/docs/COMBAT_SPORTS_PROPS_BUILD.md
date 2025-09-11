# Combat Sports Props Implementation Plan

## Overview
Implement a specialized props interface for combat sports (MMA/UFC, Boxing) that automatically detects sport type and presents a fight-card based selection flow.

## Auto-Detection Strategy

### Sport Type Detection
```dart
bool isCombatSport(String sport) {
  const combatSports = ['mma', 'ufc', 'boxing', 'mixed_martial_arts'];
  return combatSports.contains(sport.toLowerCase());
}
```

### Detection Points
1. **OddsApiService**: Check sport parameter when fetching props
2. **BetSelectionScreen**: Route to appropriate props widget based on sport
3. **PropsTab**: Conditionally render team vs combat sports interface

## Data Structures

### Fight Card Model
```dart
class FightCard {
  final String eventId;
  final String eventName;
  final DateTime eventDate;
  final List<Fight> fights;
  final bool isMainCard;
  
  FightCard({
    required this.eventId,
    required this.eventName,
    required this.eventDate,
    required this.fights,
    this.isMainCard = true,
  });
}
```

### Fight Model
```dart
class Fight {
  final String fightId;
  final Fighter fighter1;
  final Fighter fighter2;
  final String weightClass;
  final int rounds;
  final bool isMainEvent;
  final bool isTitleFight;
  
  Fight({
    required this.fightId,
    required this.fighter1,
    required this.fighter2,
    required this.weightClass,
    this.rounds = 3,
    this.isMainEvent = false,
    this.isTitleFight = false,
  });
}
```

### Fighter Model
```dart
class Fighter {
  final String id;
  final String name;
  final String record;
  final String? imageUrl;
  final String stance;
  final Map<String, dynamic> stats;
  
  Fighter({
    required this.id,
    required this.name,
    required this.record,
    this.imageUrl,
    this.stance = 'Orthodox',
    this.stats = const {},
  });
}
```

### Combat Props Categories
```dart
enum CombatPropCategory {
  method,      // Method of Victory
  round,       // Round Betting
  fight,       // Fight Outcome (Winner, Draw, etc)
  performance, // Fighter Performance (Knockdowns, Takedowns)
  time,        // Time-based props
}
```

## UI Components

### 1. Fight Selection Screen (`combat_props_selection.dart`)
```dart
class CombatPropsSelection extends StatefulWidget {
  final String eventId;
  final String sport;
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Event Header
        EventHeader(eventName, date, venue),
        
        // Fight List (Vertical Scroll)
        Expanded(
          child: ListView.builder(
            itemCount: fights.length,
            itemBuilder: (context, index) {
              return FightCard(
                fight: fights[index],
                onTap: () => navigateToFightProps(fights[index]),
              );
            },
          ),
        ),
      ],
    );
  }
}
```

### 2. Fight Card Widget
```dart
class FightCard extends StatelessWidget {
  final Fight fight;
  
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.all(8),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            // Weight Class & Fight Type
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (fight.isTitleFight) Icon(Icons.emoji_events, color: Colors.amber),
                Text(fight.weightClass),
                Text('${fight.rounds} Rounds'),
              ],
            ),
            
            // Fighter vs Fighter
            Row(
              children: [
                // Fighter 1
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(backgroundImage: NetworkImage(fighter1.imageUrl)),
                      Text(fighter1.name),
                      Text(fighter1.record, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
                
                // VS
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16),
                  child: Text('VS', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
                
                // Fighter 2
                Expanded(
                  child: Column(
                    children: [
                      CircleAvatar(backgroundImage: NetworkImage(fighter2.imageUrl)),
                      Text(fighter2.name),
                      Text(fighter2.record, style: TextStyle(fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            
            // Main Event Badge
            if (fight.isMainEvent)
              Container(
                margin: EdgeInsets.only(top: 8),
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.red,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text('MAIN EVENT', style: TextStyle(color: Colors.white, fontSize: 10)),
              ),
          ],
        ),
      ),
    );
  }
}
```

### 3. Individual Fight Props Screen (`combat_fight_props.dart`)
```dart
class CombatFightProps extends StatefulWidget {
  final Fight fight;
  
  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: Text('${fight.fighter1.name} vs ${fight.fighter2.name}'),
          bottom: TabBar(
            tabs: [
              Tab(text: 'Fight'),
              Tab(text: 'Method'),
              Tab(text: 'Round'),
              Tab(text: 'Props'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            FightOutcomeTab(fight),
            MethodOfVictoryTab(fight),
            RoundBettingTab(fight),
            PerformancePropsTab(fight),
          ],
        ),
      ),
    );
  }
}
```

### 4. Method of Victory Cards
```dart
class MethodOfVictoryTab extends StatelessWidget {
  final Fight fight;
  
  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      padding: EdgeInsets.all(8),
      children: [
        MethodCard(
          fighter: fight.fighter1,
          method: 'KO/TKO',
          odds: '+150',
        ),
        MethodCard(
          fighter: fight.fighter2,
          method: 'KO/TKO',
          odds: '+220',
        ),
        MethodCard(
          fighter: fight.fighter1,
          method: 'Submission',
          odds: '+300',
        ),
        MethodCard(
          fighter: fight.fighter2,
          method: 'Submission',
          odds: '+450',
        ),
        MethodCard(
          fighter: fight.fighter1,
          method: 'Decision',
          odds: '+180',
        ),
        MethodCard(
          fighter: fight.fighter2,
          method: 'Decision',
          odds: '+250',
        ),
      ],
    );
  }
}
```

### 5. Round Betting Cards
```dart
class RoundBettingTab extends StatelessWidget {
  final Fight fight;
  
  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: fight.rounds,
      itemBuilder: (context, index) {
        final round = index + 1;
        return Card(
          margin: EdgeInsets.all(8),
          child: ExpansionTile(
            title: Text('Round $round'),
            children: [
              ListTile(
                title: Text('${fight.fighter1.name} wins in Round $round'),
                trailing: Text('+400'),
                onTap: () => placeBet(),
              ),
              ListTile(
                title: Text('${fight.fighter2.name} wins in Round $round'),
                trailing: Text('+550'),
                onTap: () => placeBet(),
              ),
            ],
          ),
        );
      },
    );
  }
}
```

## API Integration

### API Findings
Based on testing The Odds API for MMA events:

**Available Markets:**
- **h2h**: Head-to-head winner betting (Fighter A vs Fighter B)
- **totals**: Total rounds Over/Under (limited availability)
- **Note**: Method of victory, round betting, and other prop markets are NOT currently available through The Odds API

**Data Structure:**
```json
{
  "id": "4cda62b303ad8840a9b5f64eaf34aa56",
  "sport_key": "mma_mixed_martial_arts",
  "sport_title": "MMA",
  "commence_time": "2025-09-13T09:00:00Z",
  "home_team": "David Dvorak",
  "away_team": "Mohammed Walid",
  "bookmakers": [
    {
      "key": "betonlineag",
      "title": "BetOnline.ag",
      "markets": [
        {
          "key": "h2h",
          "outcomes": [
            {"name": "David Dvorak", "price": -500},
            {"name": "Mohammed Walid", "price": 300}
          ]
        }
      ]
    }
  ]
}
```

### Fetch Combat Sports Props
```dart
// In OddsApiService
Future<Map<String, dynamic>> getCombatSportsProps(String eventId) async {
  final sport = detectSportFromEventId(eventId);
  
  if (isCombatSport(sport)) {
    // Special handling for combat sports
    // Note: Currently only h2h and totals are available
    final response = await http.get(
      Uri.parse('$baseUrl/sports/$sport/events/$eventId/odds')
        .replace(queryParameters: {
          'apiKey': apiKey,
          'regions': 'us',
          'markets': 'h2h,totals', // Only available markets for MMA
          'oddsFormat': 'american',
        }),
    );
    
    return parseCombatSportsResponse(response);
  }
  
  // Regular team sports flow
  return getEventProps(eventId);
}
```

### Parse Combat Sports Response
```dart
Map<String, dynamic> parseCombatSportsResponse(Response response) {
  final data = json.decode(response.body);
  
  return {
    'fights': extractFights(data),
    'methods': extractMethodProps(data),
    'rounds': extractRoundProps(data),
    'performance': extractPerformanceProps(data),
  };
}
```

## Caching Strategy

### Combat Sports Cache
```dart
class CombatSportsCache {
  // Cache fight cards for 30 minutes (events don't change frequently)
  static const int FIGHT_CARD_TTL = 30;
  
  // Cache live fight props for 2 minutes (odds change frequently during events)
  static const int LIVE_PROPS_TTL = 2;
  
  // Cache future fight props for 15 minutes
  static const int FUTURE_PROPS_TTL = 15;
  
  Future<void> cacheFightCard(String eventId, FightCard card) async {
    await FirebaseFirestore.instance
      .collection('cache')
      .doc('combat_sports')
      .collection('fight_cards')
      .doc(eventId)
      .set({
        'data': card.toJson(),
        'timestamp': FieldValue.serverTimestamp(),
        'ttl': FIGHT_CARD_TTL,
      });
  }
}
```

## Implementation Steps

### Phase 1: Detection & Routing
1. Add sport type detection to OddsApiService
2. Update BetSelectionScreen to route combat sports
3. Create combat sports detection utility

### Phase 2: Fight Selection
1. Create FightCard model and widget
2. Implement CombatPropsSelection screen
3. Add fight list fetching from API

### Phase 3: Simplified Combat Props (Based on API Limitations)
1. Create CombatFightProps screen with h2h betting only
2. Display fighter vs fighter cards
3. Add totals (rounds Over/Under) when available
4. Mock additional prop types for future API expansion

### Phase 4: Integration
1. Connect to bet slip functionality
2. Update bet confirmation for combat sports
3. Add combat sports to pool creation

### Phase 5: Future Enhancement (When API Adds Support)
1. Method of victory cards
2. Round betting interface
3. Performance props section
4. Fighter stats and images

## Testing Considerations

### API Testing
- Test with actual MMA/UFC event IDs
- Verify method of victory markets
- Check round betting availability
- Test fighter name parsing

### UI Testing
- Verify auto-detection works correctly
- Test navigation between fights
- Ensure bet selection works
- Test with different screen sizes

### Edge Cases
- Handle draws and no contests
- Support championship rounds (5 rounds)
- Handle fighter replacements
- Support catchweight fights

## Performance Optimizations

1. **Lazy Loading**: Load fight details only when selected
2. **Image Caching**: Cache fighter images locally
3. **Prop Grouping**: Group similar props to reduce API calls
4. **Incremental Updates**: Update only changed odds during live events
5. **Pagination**: Load fights in batches for large cards

## Future Enhancements

1. **Fighter Stats**: Add reach, height, stance comparison
2. **Historical Data**: Show previous fight results
3. **Betting Trends**: Display popular bets
4. **Live Updates**: Real-time round-by-round updates
5. **Video Highlights**: Integrate fight preview videos
6. **Expert Picks**: Show analyst predictions
7. **Parlay Builder**: Create multi-fight parlays
8. **Prop Combinations**: Allow method + round combos