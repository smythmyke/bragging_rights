# MMA Fighter Details Enhancement Plan

## Overview
Enhance the MMA fighter details experience by improving the modal bottom sheet with real API data and adding navigation to individual fighter profile pages.

## Current State
- **Modal Bottom Sheet**: Shows Tale of the Tape comparison when tapping a bout
- **FighterDetailsScreen**: Exists but not connected from MMA details page
- **Fighter Images**: Not currently displayed in either view

## Implementation Plan

### Phase 1: Enhance Modal Bottom Sheet
1. **Keep existing Tale of the Tape modal** for side-by-side fighter comparison
2. **Add API data integration**:
   - Use MMAFighter data from MMAService
   - Display real stats (height, reach, stance, record)
   - Show fighter images if available

3. **Fighter Image Sources**:
   - ESPN headshot URLs: `https://a.espncdn.com/i/headshots/mma/players/full/{fighterId}.png`
   - Cached images from `fighter_images` collection in Firestore
   - Fallback to initials or default avatar

### Phase 2: Add Navigation to Fighter Profiles
1. **Add "View Profile" buttons** in modal for each fighter
2. **Navigate to FighterDetailsScreen** with proper parameters:
   ```dart
   Navigator.pushNamed(
     context,
     '/fighter-details',
     arguments: {
       'fighterId': fighter.id,
       'fighterName': fighter.name,
       'record': fighter.record,
       'sport': 'MMA',
       'espnId': fighter.espnId,
     },
   );
   ```

### Phase 3: Ensure Consistency
1. **Check all navigation paths to MMA details**:
   - From Home Screen (All Games)
   - From Pool Games
   - From Active Wagers
   - From Search (if implemented)

2. **Ensure consistent data passing**:
   - All paths must pass `gameData` with fights array
   - Verify pseudo-ESPN IDs work from all entry points

### Phase 4: Fighter Images Implementation
1. **In Modal (Tale of the Tape)**:
   - Display fighter headshots at top of comparison
   - Size: 80x80 circular avatars
   - Add border color based on corner (red/blue)

2. **In FighterDetailsScreen**:
   - Larger profile image (120x120)
   - Full body stance images if available
   - Gallery of recent fight images (if available)

## API Data Structure

### MMAFighter Model Fields
```dart
- id: String
- name: String
- displayName: String
- nickname: String?
- record: String (e.g., "25-3-0")
- height: double? (in inches)
- displayHeight: String? (e.g., "5'11\"")
- weight: double? (in pounds)
- displayWeight: String? (e.g., "155 lbs")
- reach: double? (in inches)
- displayReach: String? (e.g., "72\"")
- stance: String? (Orthodox/Southpaw/Switch)
- headshotUrl: String?
- espnId: String?
```

## Files to Modify

### 1. `lib/screens/mma/mma_details_screen.dart`
- Enhance `_showFightDetails` method
- Add fighter image display
- Add navigation buttons to fighter profiles

### 2. `lib/screens/mma/widgets/tale_of_tape_widget.dart`
- Update to display fighter images
- Ensure all stats use real API data
- Improve layout for better visual hierarchy

### 3. `lib/screens/fighter/fighter_details_screen.dart`
- Ensure it handles MMA fighters properly
- Add fighter image gallery if multiple images available
- Display comprehensive fighter stats

### 4. `lib/services/mma_service.dart`
- Enhance fighter data fetching
- Add image URL generation/caching
- Ensure fighter stats are properly populated

## Navigation Flow

```
MMA Details Page
    ├── Tap on Bout
    │   └── Modal Bottom Sheet (Tale of the Tape)
    │       ├── Fighter 1 Stats & Image
    │       ├── VS Comparison
    │       ├── Fighter 2 Stats & Image
    │       ├── [View Fighter 1 Profile] Button
    │       └── [View Fighter 2 Profile] Button
    │           └── Navigate to FighterDetailsScreen
    │               ├── Full Fighter Profile
    │               ├── Fight History
    │               ├── Stats Breakdown
    │               └── Image Gallery
```

## Testing Checklist

- [ ] Modal displays real fighter data from API
- [ ] Fighter images load correctly with fallbacks
- [ ] View Profile buttons navigate properly
- [ ] FighterDetailsScreen receives correct parameters
- [ ] Navigation works from all entry points
- [ ] Pseudo-ESPN IDs work correctly
- [ ] Fighter images cache properly
- [ ] Offline mode shows cached data

## Success Criteria

1. Users can see side-by-side fighter comparison in modal
2. Real fighter data and images are displayed
3. Users can navigate to individual fighter profiles for detailed view
4. Navigation is consistent from all app entry points
5. Fighter images load quickly with proper caching
6. App handles missing data gracefully with appropriate fallbacks

## Notes

- Priority on ESPN API data when available
- Cache fighter images for 30 days to reduce API calls
- Ensure loading states and error handling for all API calls
- Consider adding swipe-to-dismiss on modal for better UX
- Fighter stance images (left/right) could be future enhancement