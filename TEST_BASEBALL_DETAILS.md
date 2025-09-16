# Testing Baseball Game Details Page

## How to Test

### 1. Start the App
```bash
cd bragging_rights_app
flutter run
```

### 2. Navigate to Baseball Games
1. Open the app
2. Go to "All Games" screen
3. Find any MLB game (look for baseball icon)
4. Click on the game card

### 3. Expected Console Output

When you click on an MLB game, you should see this in the console:

```
=== BASEBALL DETAILS TEST START ===
Game ID: 401697155 (or similar)
Sport: MLB
Teams: Chicago Cubs @ Pittsburgh Pirates (actual teams)
Fetching summary from: https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event=401697155
Summary response status: 200
Summary data keys: [notes, boxscore, ...]
✅ Box score data found
  - Teams in boxscore: 2
  - Team: Chicago Cubs
    - Stat group: batting
    - Stat group: pitching
    - Stat group: fielding
  - Team: Pittsburgh Pirates
    - Stat group: batting
    - Stat group: pitching
    - Stat group: fielding

Fetching scoreboard from: https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard
Scoreboard response status: 200
Total events in scoreboard: 15 (varies by day)
  Checking event ID: 401697155 vs 401697155
✅ Found matching game!
  - Probables (pitchers): 0-2 (depends on game status)
  - Weather: 72°F, Partly Cloudy (if outdoor stadium)
  - Competitors: 2
    - away: Chicago Cubs (10 records)
    - home: Pittsburgh Pirates (10 records)
=== BASEBALL DETAILS TEST END ===

Building Pitching Matchup Card...
Event details available: true
Probables count: 2 (or 0 if game started)
```

### 4. Visual Verification

#### Matchup Tab
- **Starting Pitchers Card**: Shows pitcher names, ERA, W-L records
- **Weather Card**: Temperature and conditions (may be empty for indoor stadiums)
- **Team Form Card**: Shows team abbreviations, overall records, last 10 games

#### Box Score Tab
- **Line Score**: Table with innings 1-9 and R/H/E columns
- **Batting Statistics**: Shows AB, R, H, RBI, BB, K, AVG, OBP, SLG, LOB
- **Pitching Statistics**: Shows IP, H, R, ER, BB, K, HR, ERA, WHIP, PC

#### Stats Tab
- **Team Toggle**: Can switch between away and home teams
- **Team Header**: Shows team logo, name, and record
- **Records Section**: Home, Away, Division, Last 10, Day/Night records
- **Team Statistics**: Various team stats if available

## Common Issues & Solutions

### Issue 1: "Box score data not available"
**Cause**: Game hasn't started yet or API issue
**Solution**: Try a game that's in progress or completed

### Issue 2: No pitchers shown
**Cause**: Game already started (probables removed) or not yet announced
**Solution**: Check a future game for pitcher data

### Issue 3: No weather data
**Cause**: Indoor stadium or data not available
**Solution**: Normal for domed stadiums

### Issue 4: Game not found in scoreboard
**Cause**: Game is not today or game ID is wrong
**Solution**: The app gets the correct game ID from the games list

## API Endpoints Being Tested

1. **Summary API** (Box Score)
   ```
   https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/summary?event={gameId}
   ```

2. **Scoreboard API** (Weather, Pitchers, Records)
   ```
   https://site.api.espn.com/apis/site/v2/sports/baseball/mlb/scoreboard
   ```

## Test Data Examples

### Working Game ID
- `401697155` - Chicago Cubs @ Pittsburgh Pirates

### API Response Structure
```json
{
  "boxscore": {
    "teams": [
      {
        "team": { "displayName": "Team Name" },
        "statistics": [
          { "name": "batting", "stats": [...] },
          { "name": "pitching", "stats": [...] }
        ]
      }
    ]
  }
}
```

## Debugging Tips

1. **Check Network Tab**: In Flutter DevTools, monitor network requests
2. **Console Logs**: All API calls are logged with status codes
3. **Error Messages**: Stack traces are printed for any exceptions
4. **Data Validation**: Each component logs when data is missing

## Success Criteria

✅ All three tabs load without errors
✅ Console shows successful API calls (status 200)
✅ Matchup tab shows at least team records
✅ Box Score tab shows R/H/E totals
✅ Stats tab allows team switching
✅ No red error screens or exceptions

## Next Steps After Testing

If data is loading correctly:
- Test with different games (live, upcoming, completed)
- Test team toggle functionality
- Verify responsive layout on different screen sizes

If data is NOT loading:
- Check game ID format in console
- Verify API endpoints are accessible
- Check internet connection
- Look for CORS errors (shouldn't happen in Flutter)

---

*Last tested with game ID: 401697155*
*API verified working: Current session*