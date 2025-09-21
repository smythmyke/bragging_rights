# Team Matching Improvements Plan

## Problem Statement
The ESPN ID resolver is failing to match soccer games (e.g., Newcastle vs Bournemouth) because it requires BOTH team names to match exactly. If one team name differs between APIs (e.g., "Newcastle United" vs "Newcastle"), the entire match fails.

## Current Matching Logic
```dart
// Both teams must match (AND condition)
normalMatch = (espnHome == gameHome && espnAway == gameAway)
reversedMatch = (espnHome == gameAway && espnAway == gameHome)
return normalMatch || reversedMatch
```

## Proposed Solutions

### 1. Enhanced Soccer Team Normalizations
Add more Premier League and common soccer team normalizations:
- "Newcastle United" → "newcastle"
- "AFC Bournemouth" → "bournemouth"
- "Wolverhampton Wanderers" → "wolves"
- "West Ham United" → "west ham"
- "Manchester United" → "manchester united" (distinguish from Man City)
- "Manchester City" → "manchester city"
- "Nottingham Forest" → "nottingham forest"
- "Leicester City" → "leicester"
- "Sheffield United" → "sheffield united"
- "Crystal Palace" → "crystal palace"
- "Leeds United" → "leeds"
- Remove "FC", "AFC", "United", "City" suffixes when safe

### 2. Fuzzy Matching Implementation
Implement partial string matching for team names:
- Use contains() checks for key team identifiers
- Calculate similarity scores (e.g., Levenshtein distance)
- Accept matches above a threshold (e.g., 80% similarity)
- Handle common abbreviations and nicknames

### 3. Single Team + Date Fallback Matching
When both-team matching fails:
1. Try to match ANY one team from the game
2. If one team matches on the same date (within 24 hours):
   - Check if the opponent partially matches
   - Accept the match if reasonable confidence
3. Priority order:
   - Exact both-team match (current)
   - Fuzzy both-team match (new)
   - Single team exact + date (fallback)
   - Single team fuzzy + date (last resort)

## Implementation Steps

1. **Phase 1: Add Normalizations**
   - Extend `_normalizeTeamName()` with comprehensive soccer teams
   - Test with known problem teams

2. **Phase 2: Fuzzy Matching**
   - Create `_fuzzyTeamMatch()` method
   - Implement similarity scoring
   - Set appropriate thresholds

3. **Phase 3: Fallback Logic**
   - Modify `_teamsMatch()` to return confidence level
   - Implement `_singleTeamMatch()` for fallback
   - Add logging for match confidence

## Success Criteria
- Newcastle vs Bournemouth matches successfully
- Other Premier League games with name variations match
- No false positives (wrong games matched)
- Clear logging of match confidence levels

## Test Cases
- "Newcastle United" vs "Newcastle"
- "AFC Bournemouth" vs "Bournemouth"
- "Wolverhampton Wanderers" vs "Wolves"
- "Tottenham Hotspur" vs "Spurs"
- Manchester United vs Manchester City (ensure no mix-up)