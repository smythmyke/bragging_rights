# Boxing UI Implementation Plan

## Overview
This document outlines the required changes to make the Boxing UI match the MMA/UFC implementation, including fighter images, proper fight ordering, and enhanced visual presentation.

## Current State Analysis

### MMA/UFC Implementation (Target State)
- ✅ **Fighter Images**: Displays cached fighter photos from ESPN
- ✅ **Fight Order**: Reversed display (main event at bottom)
- ✅ **Card Positions**: Organized by main/prelim/early cards
- ✅ **Rich Fighter Data**: Full profiles with stats, records, images
- ✅ **Combat Sport Detection**: Uses `SportUtils.isCombatSport()`
- ✅ **Navigation**: Routes to `/fight-card-grid`

### Boxing Implementation (Current State)
- ❌ **Fighter Images**: Only text names, no images
- ✅ **Fight Order**: Already reversed (main event last)
- ⚠️ **Card Positions**: Basic implementation exists
- ❌ **Fighter Data**: Only names, no rich profiles
- ✅ **Combat Sport Detection**: Already identified as combat sport
- ✅ **Navigation**: Routes to `/fight-card-grid`
- ❌ **API Integration**: Limited/broken ESPN API access

## Required Changes

### 1. Create Boxing Service (`boxing_service.dart`)
Model after `mma_service.dart` with the following features:

```dart
class BoxingService {
  // Fetch boxing event with full fighter data
  Future<BoxingEvent?> getEventWithFights(String eventId)

  // Fetch individual boxer profile
  Future<BoxingFighter?> getBoxer(String athleteId)

  // Batch fetch multiple boxers
  Future<Map<String, BoxingFighter>> _batchFetchBoxers(List<String> refs)
}
```

### 2. Create Boxing Models

#### BoxingEvent Model
```dart
class BoxingEvent {
  final String id;
  final String name;
  final DateTime date;
  final String venue;
  final List<BoxingFight> fights;
  final String? posterUrl;
}
```

#### BoxingFighter Model
```dart
class BoxingFighter {
  final String id;
  final String name;
  final String? imageUrl;
  final String? record; // "50-0-0"
  final String? stance;
  final double? reach;
  final String? weightClass;
  final String? nationality;
}
```

#### BoxingFight Model
```dart
class BoxingFight {
  final String id;
  final BoxingFighter fighter1;
  final BoxingFighter fighter2;
  final String weightClass;
  final int rounds;
  final bool isMainEvent;
  final bool isTitleFight;
  final String cardPosition; // "main", "undercard"
  final int fightOrder;
}
```

### 3. Update Event Splitter Service

Current implementation only extracts fighter names. Need to:
1. Fetch full fighter data including ESPN athlete IDs
2. Get fighter images from ESPN API
3. Properly set card positions
4. Maintain reversed order (main event last)

### 4. ESPN API Endpoints

#### Boxing Athlete Endpoint
```
GET https://site.api.espn.com/apis/site/v2/sports/boxing/athletes/{athleteId}
```

#### Boxing Event Endpoint
```
GET https://site.api.espn.com/apis/site/v2/sports/boxing/summary?event={eventId}
```

#### Boxing Scoreboard (Currently Broken)
```
GET https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard
Returns: 404 Error
```

### 5. Implementation Steps

1. **Phase 1: Data Layer**
   - Create `boxing_service.dart`
   - Create boxing models (Event, Fighter, Fight)
   - Test ESPN API endpoints for boxing data

2. **Phase 2: Integration**
   - Update `event_splitter_service.dart` to use new boxing service
   - Ensure fighter data includes images and stats
   - Maintain proper fight ordering

3. **Phase 3: UI Updates**
   - Verify `FighterImageWidget` works with boxing fighters
   - Ensure fight card grid displays boxing correctly
   - Test with real boxing events

4. **Phase 4: Fallback Handling**
   - Handle missing fighter images gracefully
   - Provide default avatars for boxers without photos
   - Handle API failures with cached/mock data

## API Testing Results

### ❌ ESPN Boxing API Status (CRITICAL ISSUE)

Testing reveals that ESPN's boxing API is **completely non-functional**:

1. **Athlete Endpoints - ALL FAILED**
   - `https://site.api.espn.com/apis/site/v2/sports/boxing/athletes/{id}` - Returns empty/no data
   - `https://sports.core.api.espn.com/v2/sports/boxing/athletes/{id}` - Returns error: "Invalid sport (boxing)"
   - No fighter images available through API
   - No fighter stats or records accessible

2. **Event Endpoints - ALL FAILED**
   - `https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard` - Returns 404
   - `https://site.api.espn.com/apis/site/v2/sports/boxing/top-rank/events` - Returns compressed/invalid data
   - No boxing events found in any endpoint tested

3. **Comparison with MMA/UFC**
   - MMA endpoints also show limited functionality
   - Some MMA data is embedded in event responses
   - MMA images come from cached/scraped data, not direct API

### 🔍 Key Finding
**ESPN has discontinued public API support for boxing.** Unlike MMA/UFC which has limited but functional endpoints, boxing APIs return either 404 errors or invalid responses.

## Success Criteria

- [ ] Boxing fights display with fighter images (like MMA)
- [ ] Main event appears at bottom of card
- [ ] Fighter profiles accessible with full stats
- [ ] Smooth navigation between fights
- [ ] Graceful fallback for missing data
- [ ] Performance on par with MMA implementation

## Risk Factors

1. **ESPN API Limitations**
   - Boxing scoreboard endpoint returns 404
   - May need alternative data sources
   - Limited historical data access

2. **Data Quality**
   - Fighter images may not be available for all boxers
   - Incomplete fighter profiles
   - Missing bout information

3. **Implementation Complexity**
   - Need to handle multiple boxing organizations (WBC, WBA, IBF, WBO)
   - Different data structures than MMA
   - Legacy boxing data may be incomplete

## ✅ SOLUTION FOUND: THE ODDS API

### Great News! The Odds API Has Full Boxing Support

Testing confirms **The Odds API** provides comprehensive boxing data:

#### Available Data:
- **71+ upcoming boxing fights** with full fighter names
- **Fighter Names**: Both fighters clearly identified (home_team, away_team)
- **Event IDs**: Unique identifiers for each fight
- **Dates & Times**: Full schedule information
- **Odds Data**: Multiple bookmakers (DraftKings, FanDuel, etc.)
- **Markets**: H2H (moneyline), totals, and more

#### Example Data Retrieved:
```json
{
  "id": "af06787f8e9c52b8a6c029e64192010b",
  "sport_key": "boxing_boxing",
  "sport_title": "Boxing",
  "commence_time": "2025-10-12T01:00:00Z",
  "home_team": "Alexis Barriere",
  "away_team": "Guido Vianello",
  "bookmakers": [7 different sportsbooks with odds]
}
```

#### API Configuration:
- **Endpoint**: `https://api.the-odds-api.com/v4/sports/boxing_boxing/odds/`
- **API Key**: Already configured in `.env` file
- **Service**: Already implemented in `odds_api_service.dart`
- **Sport Key**: `boxing_boxing` (already mapped)

## Recommended Solution (Using The Odds API)

### Implementation Plan Using The Odds API + Static Images

Since The Odds API provides fight data but not fighter images, we'll use a hybrid approach:
#### Phase 1: Fetch Fight Data from The Odds API
```dart
class BoxingService {
  final OddsApiService _oddsApi = OddsApiService();

  Future<List<BoxingEvent>> getUpcomingFights() async {
    // Already implemented - just need to parse boxing_boxing sport
    final oddsData = await _oddsApi.getSportOdds(sport: 'boxing');
    return _parseBoxingEvents(oddsData);
  }
}
```

#### Phase 2: Enhance with Fighter Images
```dart
class BoxingFighterImageService {
  // Map of known boxers to their image URLs
  static final Map<String, String> fighterImages = {
    'canelo alvarez': 'assets/images/boxers/canelo.jpg',
    'tyson fury': 'assets/images/boxers/fury.jpg',
    'anthony joshua': 'assets/images/boxers/joshua.jpg',
    'gervonta davis': 'assets/images/boxers/davis.jpg',
    'errol spence': 'assets/images/boxers/spence.jpg',
    // Add more as needed
  };

  String getImageForFighter(String fighterName) {
    final normalized = fighterName.toLowerCase();
    return fighterImages[normalized] ?? 'assets/images/boxers/default.jpg';
  }
}
```

#### Phase 3: Create Boxing Event Model
```dart
class BoxingEvent {
  final String id;           // From Odds API
  final String fighter1Name;  // From Odds API (away_team)
  final String fighter2Name;  // From Odds API (home_team)
  final DateTime date;        // From Odds API
  final String? fighter1Image; // From our service
  final String? fighter2Image; // From our service
  final List<BookmakerOdds> odds; // From Odds API
}
```

### Benefits of This Approach

1. **Real, Live Data**: Actual upcoming fights from The Odds API
2. **No ESPN Dependency**: Works without broken ESPN endpoints
3. **Already Integrated**: OddsApiService already exists in the app
4. **Scalable**: Can add more fighter images over time
5. **Fallback Ready**: Generic boxer image for unknown fighters

### Alternative Enhancement: Web Scraping for Images
1. **Scrape fighter images from boxing websites**
   - Parse HTML for fighter names and images
   - Extract fight card information
   - Cache results locally

2. **Technical Requirements**
   - HTML parser (html package)
   - Regular expression patterns
   - Caching mechanism

### Option 3: Third-Party API Integration
1. **Potential Services**
   - BoxRec API (requires subscription)
   - SportsData.io Boxing API (paid)
   - RapidAPI Boxing endpoints

2. **Considerations**
   - Cost implications
   - API reliability
   - Data licensing

### Option 4: Hybrid Approach (Most Robust)
Combine multiple strategies:
1. Use mock data for known boxers
2. Scrape ESPN for event structure
3. Allow manual data entry for new fights
4. Cache everything locally

## Testing Plan

1. Test with known boxing event IDs
2. Verify fighter image loading
3. Check fight order display
4. Test error handling
5. Performance testing with large fight cards
6. Cross-platform compatibility (iOS/Android)

## Timeline Estimate

- **Day 1**: API testing and verification
- **Day 2**: Create boxing service and models
- **Day 3**: Integration with existing UI
- **Day 4**: Testing and bug fixes
- **Day 5**: Polish and optimization

## Implementation Summary

### ✅ Confirmed Data Source: The Odds API
After extensive testing, we've confirmed that **The Odds API** will be our primary data source for boxing:

- **71+ live boxing fights** available at any time
- **Complete fighter names** for all bouts
- **Unique event IDs** for tracking
- **Full scheduling data** with dates/times
- **Live odds** from 5-7 bookmakers per fight
- **Already integrated** in the app's `odds_api_service.dart`

### ❌ ESPN API Status: Completely Non-Functional
- All boxing endpoints return 404 or invalid data
- No fighter profiles or images available
- Cannot be used as a data source

### 📋 Final Implementation Strategy

1. **Primary Data Source**: The Odds API for all fight data
2. **Fighter Images**: Static asset mapping for popular boxers
3. **UI Framework**: Reuse existing MMA fight card grid
4. **Fallback Strategy**: Generic boxer silhouette for unknown fighters

### 🎯 Next Steps (Priority Order)

1. **Create Boxing Service** (`boxing_service.dart`)
   - Fetch fights from The Odds API
   - Parse boxing_boxing sport data
   - Format for fight card display

2. **Add Static Fighter Assets**
   - Create `assets/images/boxers/` directory
   - Add images for top 30 boxers
   - Implement fallback silhouette

3. **Update Event Splitter**
   - Parse Odds API boxing format
   - Map to existing fight card structure
   - Maintain reversed order (main event last)

4. **Test Integration**
   - Verify fight card grid displays boxing
   - Ensure betting flow works
   - Test odds display

### 📊 Data Availability Matrix

| Data Field | ESPN API | The Odds API | Our Solution |
|------------|----------|--------------|--------------|
| Fighter Names | ❌ | ✅ | Use Odds API |
| Event IDs | ❌ | ✅ | Use Odds API |
| Dates/Times | ❌ | ✅ | Use Odds API |
| Live Odds | ❌ | ✅ | Use Odds API |
| Fighter Images | ❌ | ❌ | Static Assets |
| Fighter Records | ❌ | ❌ | Optional: Web Scrape |
| Weight Classes | ❌ | ❌ | Optional: Manual Entry |
| Fighter Stats | ❌ | ❌ | Not Required for MVP |

### ✅ Ready for Implementation
With The Odds API providing real fight data and our static image solution for fighters, we have everything needed to implement a professional boxing UI that matches the MMA experience.