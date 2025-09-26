# Combat Sports (MMA/Boxing) Update Plan

## Overview
Update the MMA/Boxing betting system with improved UI for fight predictions including method and round selection via multi-tap interface.

## Current Issues (RESOLVED)
1. ✅ **Fighter data not displaying properly** - Fixed field mapping
2. ✅ **Fighter images missing** - Now loading from ESPN CDN
3. ✅ **Fighter records shown** - Already displaying correctly
4. ✅ **Method/round prediction UI** - Designed multi-tap interface
5. ✅ **Removed odds dependency** - No longer displaying odds/points

## UI Design Decisions

### Multi-Tap System
- **Fighter Selection**: Tap to select winner, continue tapping to cycle through methods
- **Method Progression**: None → Winner → KO/TKO → Submission → Decision → None
- **Round Selection**: Single centered button below each fighter, tap to cycle rounds
- **Interaction Rules**:
  - Round selector only activates when fighter is selected
  - Selecting opposite fighter clears all previous selections (winner, method, AND round)
  - Draw/No Contest clears both fighters completely

### Visual Elements
- **Event Badges**: Small badges below Draw button showing Main Event (👑) or Co-Main (⭐)
- **Fighter Images**: ESPN CDN with fallback to initials
- **Fighter Records**: Displayed below name
- **Round Selector**: Clock icon with "Round X" or "Select Round" text

## Implementation Tasks

### Phase 1: Fix Fighter Data Display & Round Count
1. **Fighter Names**
   - ✅ Already fixed - using `fighter1` and `fighter2` fields from Firestore
   - Ensure consistent field mapping across all fight data sources

2. **Fighter Images**
   ```dart
   // ESPN CDN pattern for fighter headshots
   String getFighterImageUrl(String espnId) {
     return 'https://a.espncdn.com/i/headshots/mma/players/full/$espnId.png';
   }

   // Fallback to placeholder if image fails
   Widget FighterImage(String? espnId, String fighterName) {
     return CachedNetworkImage(
       imageUrl: espnId != null
         ? getFighterImageUrl(espnId)
         : 'assets/images/fighter_placeholder.png',
       errorWidget: (context, url, error) =>
         CircleAvatar(child: Text(fighterName[0])),
     );
   }
   ```

3. **Fighter Records**
   - Check if records exist in fight data
   - Display format: "29-7-0" or "Record: N/A" if not available
   - Add to fight card UI below fighter name

4. **Round Count from API**
   ```dart
   // Check API response for round information
   // Main events/Championship: 5 rounds
   // Regular fights: 3 rounds

   int getRoundCount(Map<String, dynamic> fightData) {
     // Check explicit rounds field first
     if (fightData['rounds'] != null) {
       return fightData['rounds'];
     }

     // Check card position for championship fights
     if (fightData['cardPosition'] == 'main' ||
         fightData['isChampionship'] == true ||
         fightData['isTitleFight'] == true) {
       return 5;
     }

     // Default to 3 rounds for regular fights
     return 3;
   }
   ```

### Phase 2: Flutter Implementation

1. **Update FightPickState Model**
   ```dart
   class FightPickState {
     final String? winnerId;
     final String? winnerName;
     final String? method;  // 'KO', 'TKO', 'SUB', 'DEC', 'TIE'
     final int? round;      // Round prediction (1-3 or 1-5)
     final int confidence;

     FightPickState({
       this.winnerId,
       this.winnerName,
       this.method,
       this.round,
       this.confidence = 3,
     });
   }
   ```

2. **Event Badge Widget**
   ```dart
   Widget _buildEventBadge(String cardPosition) {
     if (cardPosition == 'main') {
       return Container(
         margin: EdgeInsets.only(top: 10),
         padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
         decoration: BoxDecoration(
           color: Color(0xFFFFD700).withOpacity(0.15),
           border: Border.all(color: Color(0xFFFFD700).withOpacity(0.3)),
           borderRadius: BorderRadius.circular(4),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Text('👑', style: TextStyle(fontSize: 11)),
             SizedBox(width: 4),
             Text('MAIN EVENT', style: TextStyle(
               color: Color(0xFFFFD700),
               fontSize: 10,
               fontWeight: FontWeight.w600,
             )),
           ],
         ),
       );
     } else if (cardPosition == 'co-main') {
       // Similar for co-main with ⭐ and silver color
     }
     return SizedBox.shrink();
   }
   ```

### Phase 3: Round Selector Implementation

1. **Single Round Selector Widget**
   ```dart
   Widget _buildRoundSelector(String fightId, int maxRounds) {
     final pick = _picks[fightId];
     final isActive = pick?.winnerId != null;
     final currentRound = pick?.round ?? 0;

     return GestureDetector(
       onTap: isActive ? () => _cycleRound(fightId, maxRounds) : null,
       child: Container(
         padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
         decoration: BoxDecoration(
           color: isActive
             ? AppTheme.primaryCyan.withOpacity(0.3)
             : AppTheme.primaryCyan.withOpacity(0.05),
           border: Border.all(
             color: isActive ? AppTheme.primaryCyan : AppTheme.borderCyan.withOpacity(0.3),
             width: isActive ? 2 : 1,
           ),
           borderRadius: BorderRadius.circular(6),
         ),
         child: Row(
           mainAxisSize: MainAxisSize.min,
           children: [
             Icon(Icons.access_time, size: 14, color: AppTheme.primaryCyan),
             SizedBox(width: 4),
             Text(
               currentRound > 0 ? 'Round $currentRound' : 'Select Round',
               style: TextStyle(
                 color: isActive ? AppTheme.primaryCyan : Colors.grey,
                 fontSize: 12,
                 fontWeight: FontWeight.w600,
               ),
             ),
           ],
         ),
       ),
     );
   }

   void _cycleRound(String fightId, int maxRounds) {
     final currentPick = _picks[fightId];
     if (currentPick?.winnerId == null) return;

     int nextRound = ((currentPick?.round ?? 0) % maxRounds) + 1;

     setState(() {
       _picks[fightId] = FightPickState(
         winnerId: currentPick!.winnerId,
         winnerName: currentPick.winnerName,
         method: currentPick.method,
         round: nextRound,
       );
     });
   }
   ```

2. **Fighter Display Card**
   ```dart
   Widget FighterCard(Fight fight, bool isHome) {
     final fighter = isHome ? fight.fighter2 : fight.fighter1;
     final record = isHome ? fight.fighter2Record : fight.fighter1Record;
     final espnId = isHome ? fight.fighter2Id : fight.fighter1Id;

     return Column(
       children: [
         // Fighter Image
         FighterImage(espnId, fighter),

         // Fighter Name
         Text(fighter, style: TextStyle(fontWeight: FontWeight.bold)),

         // Fighter Record
         if (record.isNotEmpty)
           Text(record, style: TextStyle(fontSize: 12, color: Colors.grey)),

         // Odds indicator (if underdog)
         if (isUnderdog)
           Chip(label: Text('+$odds'), backgroundColor: Colors.green),
       ],
     );
   }
   ```

### Phase 4: Updated Fighter Selection Logic

1. **Fighter Selection with Opponent Clearing**
   ```dart
   void _handleFighterTap(Fight fight, String fighterId, String fighterName) {
     setState(() {
       final currentPick = _picks[fight.id];

       // If selecting different fighter, clear opponent's everything
       if (currentPick?.winnerId != null && currentPick?.winnerId != fighterId) {
         _picks[fight.id] = FightPickState(
           winnerId: fighterId,
           winnerName: fighterName,
           method: null,
           round: null, // Clear round when switching fighters
         );
         return;
       }

       // Continue with method cycling for same fighter
       if (currentPick?.winnerId == fighterId) {
         final methods = ['KO', 'TKO', 'SUB', 'DEC', null];
         final currentIndex = methods.indexOf(currentPick.method);
         final nextIndex = (currentIndex + 1) % methods.length;
         final nextMethod = methods[nextIndex];

         if (nextMethod == null) {
           // Cycling back to no selection - clear round too
           _picks.remove(fight.id);
         } else {
           _picks[fight.id] = FightPickState(
             winnerId: fighterId,
             winnerName: fighterName,
             method: nextMethod,
             round: currentPick.round, // Preserve round selection
           );
         }
       } else {
         // First selection
         _picks[fight.id] = FightPickState(
           winnerId: fighterId,
           winnerName: fighterName,
         );
       }
     });
   }
   ```

### Phase 5: Pick Submission to Firestore

1. **Updated Pick Submission**
   ```dart
   Future<void> _savePicks() async {
     final userId = FirebaseAuth.instance.currentUser?.uid;
     if (userId == null) return;

     final picksData = <String, dynamic>{};
     _picks.forEach((fightId, pick) {
       if (pick.winnerId != null || pick.method == 'TIE') {
         picksData[fightId] = {
           'winnerId': pick.winnerId,
           'winnerName': pick.winnerName,
           'method': pick.method,
           'round': pick.round, // NEW: Include round prediction
           'confidence': pick.confidence,
           'pickedAt': FieldValue.serverTimestamp(),
         };
       }
     });

     await _firestore
         .collection('pools')
         .doc(widget.poolId)
         .collection('picks')
         .doc(userId)
         .set({
       'eventId': widget.event.id,
       'userId': userId,
       'fights': picksData,
       'submittedAt': FieldValue.serverTimestamp(),
     });
   }
   ```

## Database Structure

### Firestore Collections

1. **games/{gameId}** (MMA/Boxing Events)
   ```javascript
   {
     id: "600055226",
     sport: "MMA",
     homeTeam: "Carlos Ulberg",
     awayTeam: "Dominick Reyes",
     fights: [
       {
         id: "fight_1",
         fighter1: "Dominick Reyes",
         fighter2: "Carlos Ulberg",
         fighter1Record: "12-3",
         fighter2Record: "7-1",
         fighter1Id: "3074889", // ESPN ID for images
         fighter2Id: "4285973",
         weightClass: "Light Heavyweight",
         rounds: 5,
         cardPosition: "main",
         odds: {
           fighter1: "+205",
           fighter2: "-240"
         }
       }
     ]
   }
   ```

2. **pools/{poolId}/picks/{userId}**
   ```javascript
   {
     userId: "user123",
     picks: {
       "fight_1": {
         fighter: "Carlos Ulberg",
         method: "ko",
         round: 2,
         confidence: 4,
         submittedAt: timestamp
       }
     }
   }
   ```

## Testing Plan

1. **Test Fighter Data Loading**
   - Verify fighter names display correctly
   - Test image loading with valid/invalid ESPN IDs
   - Verify record display

2. **Test Pick Submission**
   - Submit picks with all prediction types
   - Verify data saved correctly to Firestore

3. **Test Scoring**
   - Create test results
   - Calculate scores for various scenarios
   - Verify underdog bonus applies correctly

4. **Test Pool Settlement**
   - Test with multiple participants
   - Verify correct point calculations
   - Check payout distributions

## Timeline

- **Day 1**: Fix fighter data display (names, images, records)
- **Day 2**: Update data models and Firestore structure
- **Day 3**: Build new UI components for predictions
- **Day 4**: Implement scoring logic
- **Day 5**: Testing and refinement

## Success Metrics

1. Fighter data displays correctly (no TBD)
2. Fighter images load from ESPN CDN
3. Fighter records visible on cards
4. Users can predict method and round
5. Point-based scoring calculates correctly
6. Pools settle based on points, not odds

## Notes

- This system removes dependency on matching odds between APIs
- Creates more engaging prediction experience
- Rewards fight knowledge over just picking winners
- Can be extended to include confidence multipliers for tournament play