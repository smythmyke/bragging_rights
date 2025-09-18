# Boxing Details Page Data Mapping

## Available Data from Boxing Data API

Based on the API response, here's what we can populate in a boxing details page:

### Tab 1: Event Overview
**Available Data:**
- ✅ **Event Title** → `title` (e.g., "Canelo vs Crawford")
- ✅ **Date/Time** → `date` (ISO format, needs formatting)
- ✅ **Venue** → `venue` (e.g., "Allegiant Stadium")
- ✅ **Location** → `location` (e.g., "Las Vegas, United States")
- ✅ **Event Poster** → `poster_image_url` (visual content)

### Tab 2: Broadcast & Production
**Available Data:**
- ✅ **TV Networks** → `broadcasters` array (by country)
- ✅ **Streaming** → `broadcast` details
- ✅ **Promoter** → `promotion` (e.g., "Zuffa Boxing")
- ✅ **Co-Promoters** → `co_promotion` array
- ✅ **Ring Announcers** → `ring_announcers` array
- ✅ **Commentary Team** → `tv_announcers` array

### Tab 3: Fight Card (NOT AVAILABLE)
**Missing Data:**
- ❌ Individual bout matchups
- ❌ Fighter records
- ❌ Weight classes
- ❌ Title fights designation
- ❌ Preliminary vs Main card

### Tab 4: Fighter Stats (NOT AVAILABLE)
**Missing Data:**
- ❌ Fighter profiles
- ❌ Win/Loss records
- ❌ Height/Reach/Stance
- ❌ KO percentage
- ❌ Recent fight history
- ❌ Tale of the tape comparisons

## Data Gaps & Supplemental Needs

### Critical Missing Elements:
1. **Fighter Information**
   - No individual fighter data
   - No records or statistics
   - No biographical information

2. **Fight Card Structure**
   - No bout listings
   - No fight order
   - No weight divisions

3. **Historical/Results Data**
   - No past results
   - No fight outcomes
   - No performance metrics

4. **Betting/Odds Information**
   - No odds data
   - No predictions
   - No betting lines

## Recommended Tab Structure with Available Data

### Option 1: Event-Focused (Using Available Data)
```
Tab 1: Event Info
- Date, Time, Venue
- Location Map
- Event Poster

Tab 2: How to Watch
- TV Networks by Country
- Streaming Platforms
- Broadcast Times

Tab 3: Production
- Promoters
- Ring Announcers
- Commentary Team

Tab 4: More Events
- Upcoming boxing events
- Recent events
- Filter by promotion
```

### Option 2: Hybrid Approach (Needs Additional API)
```
Tab 1: Fight Card
- [Need another API for bout listings]
- Main Event highlight
- Full card with times

Tab 2: Event Details
- Venue & Location (✅ Available)
- Broadcast Info (✅ Available)
- Promoters (✅ Available)

Tab 3: Fighters
- [Need fighter API for stats]
- Tale of the tape
- Recent performances

Tab 4: Live Updates
- [Need live scoring API]
- Round-by-round scoring
- Fight results
```

## Implementation Recommendation

**For MVP:** Use Option 1 (Event-Focused) since all data is available
**For Full Version:** Combine Boxing Data API with:
- ESPN Fighter API (for fighter stats)
- BoxRec API (for records/history)
- Odds API (for betting lines)

## Sample Implementation Code Structure

```dart
class BoxingEventDetails {
  // From Boxing Data API
  final String eventId;
  final String title;
  final DateTime date;
  final String venue;
  final String location;
  final String posterUrl;
  final List<Broadcaster> broadcasters;
  final String promotion;
  final List<String> coPromotions;
  final List<String> ringAnnouncers;
  final List<String> tvAnnouncers;

  // Would need from other APIs
  final List<Bout>? fights; // Not available
  final List<Fighter>? fighters; // Not available
  final Map<String, dynamic>? odds; // Not available
}