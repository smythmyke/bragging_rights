# Odds Data Pipeline Fix Plan

## Current Issues Summary

### 1. API Key Status
- **The Odds API**: INVALID (401 error - "API key is not valid")
- **ESPN API**: WORKING (has complete odds data for all NFL games)

### 2. Identified Bugs
1. **Cache Serialization Error**: `EspnNflScoreboard` object can't be saved to Firestore
2. **Type Casting Error**: Cache returns List but code expects Map
3. **String Parsing Error**: "TB -1.5" string can't convert to double
4. **Betting Screen Crash**: Tries to parse malformed odds data

## Get New API Key

### The Odds API Registration
**URL**: https://the-odds-api.com

**Steps to get API key:**
1. Go to https://the-odds-api.com
2. Click "Get API Key" button
3. Sign up with email
4. Free tier includes:
   - 500 requests/month
   - All sports coverage
   - Real-time odds updates
5. API key will be emailed immediately
6. Update key in `sports_game_odds_service.dart`

## Fix Implementation Plan

### Phase 1: Cache Serialization Fix
**File**: `lib/services/edge/cache/edge_cache_service.dart`
**Problem**: Trying to save typed objects to Firestore
**Solution**: 
- Convert `EspnNflScoreboard` to Map before caching
- Or skip Firestore cache for typed objects
- Only use memory cache for complex objects

### Phase 2: Type Casting Fix
**File**: `lib/services/free_odds_service.dart`
**Problem**: Cache returns raw event list, code expects Map
**Current Error**: `type 'List<dynamic>' is not a subtype of type 'Map<String, dynamic>'`
**Solution**:
- Check if cached data is a List or Map
- Handle both cases in `_getNflOdds` method
- Extract events properly from cached structure

### Phase 3: String Parsing Fix
**File**: `lib/services/free_odds_service.dart`
**Problem**: Using string field "details" ("TB -1.5") instead of numeric "spread" (1.5)
**Solution**:
- Use `spread` field (numeric) instead of `details` (string)
- Use `overUnder` field (numeric) instead of parsing strings
- Already partially fixed in `_extractOddsFromEspnEvent`

### Phase 4: Betting Screen Error Fix
**File**: `lib/screens/betting/bet_selection_screen.dart`
**Problem**: Crashes on `toDouble()` call on string
**Solution**:
- Add type checking before conversion
- Use default values for malformed data
- Add try-catch blocks for parsing

### Phase 5: API Strategy Update
**Options**:
1. **Option A**: Get new API key and keep dual-source strategy
2. **Option B**: Disable The Odds API, use ESPN as primary
3. **Option C**: Add API key validation and auto-fallback

## Quick Win Solution

Since ESPN has all required odds data:
1. Comment out The Odds API calls temporarily
2. Make ESPN the primary odds source
3. Fix ESPN data extraction bugs
4. App will work immediately

## Testing Plan

1. Test ESPN odds extraction with curl
2. Verify odds data structure matches expected format
3. Test betting screen with mock data
4. Test full flow: Pool selection → Betting screen → Bet placement

## Success Criteria

- [ ] Betting screen shows odds for all tabs (Winner, Spread, Total, Props, Live)
- [ ] No type casting errors in logs
- [ ] No string parsing errors
- [ ] Cache works without serialization errors
- [ ] Pool joining flow completes successfully

## Implementation Order

1. **Immediate**: Disable The Odds API calls (5 min)
2. **Critical**: Fix type casting in FreeOddsService (15 min)
3. **Important**: Fix cache serialization (10 min)
4. **Nice to have**: Get new API key and re-enable (after registration)

## Files to Modify

1. `lib/services/sports_game_odds_service.dart` - Disable or update API key
2. `lib/services/free_odds_service.dart` - Fix type casting and parsing
3. `lib/services/edge/cache/edge_cache_service.dart` - Fix serialization
4. `lib/screens/betting/bet_selection_screen.dart` - Fix string conversion
5. `lib/services/game_odds_enrichment_service.dart` - Update fallback logic

## Rollback Plan

If fixes cause issues:
1. Revert to mock data in betting screen
2. Disable odds enrichment temporarily
3. Use hardcoded odds for testing