# ESPN Fighter API Documentation

## Working Endpoints

### UFC Scoreboard
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard`
**Method:** GET
**Status:** ✅ Working

#### Example Call:
```bash
curl -s "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/scoreboard"
```

#### Fighter Data Received:
```json
{
  "id": "5289841",
  "uid": "s:3301~a:5289841",
  "type": "athlete",
  "order": 2,
  "winner": false,
  "athlete": {
    "fullName": "Daniil Donchenko",
    "displayName": "Daniil Donchenko",
    "shortName": "D. Donchenko",
    "flag": {
      "href": "https://a.espncdn.com/i/teamlogos/countries/500/ukr.png",
      "alt": "Ukraine",
      "rel": ["country-flag"]
    }
  },
  "records": [
    {
      "name": "overall",
      "abbreviation": "TOT",
      "type": "total",
      "summary": "12-2-0"
    }
  ]
}
```

### Available Fighter Fields from Scoreboard:
- **Fighter ID**: Unique identifier (e.g., "5289841")
- **Full Name**: Complete fighter name
- **Display Name**: Name for UI display
- **Short Name**: Abbreviated name (e.g., "D. Donchenko")
- **Country Flag**: URL to country flag image
- **Record**: Win-Loss-Draw format (e.g., "12-2-0")
- **Weight Class**: From competition type field

## Non-Working Endpoints (404 Errors)

### Individual Fighter Details
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/mma/ufc/athletes/{fighterId}`
**Status:** ❌ Returns 404

#### Example Failed Calls:
```bash
# UFC Fighter
curl -s "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/athletes/5289841"
# Response: {"code":404}

# Known fighter (Jon Jones)
curl -s "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/athletes/2710857"
# Response: {"code":404}
```

### Boxing Endpoints
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard`
**Status:** ❌ Returns 404

```bash
curl -s "https://site.api.espn.com/apis/site/v2/sports/boxing/scoreboard"
# Response: {"code":404}
```

### Event Details
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/mma/ufc/events/{eventId}`
**Status:** ❌ Returns 404

```bash
curl -s "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/events/600053664"
# Response: {"code":404}
```

### Event Summary
**Endpoint:** `https://site.api.espn.com/apis/site/v2/sports/mma/ufc/summary?event={eventId}`
**Status:** ❌ Returns 404

```bash
curl -s "https://site.api.espn.com/apis/site/v2/sports/mma/ufc/summary?event=600053664"
# Response: {"code":404,"message":"error invoking GET..."}
```

## Data Extraction Strategy

Since individual fighter endpoints don't work, we must:

1. **Extract from Scoreboard**: Parse fighter data from the UFC scoreboard endpoint
2. **Cache in Firestore**: Store extracted data in Firestore for future use
3. **Build Profiles Over Time**: Accumulate fighter data as different events are viewed

## Sample Fighter IDs from Recent Events

| Fighter Name | Fighter ID | Record | Country |
|-------------|------------|--------|---------|
| Daniil Donchenko | 5289841 | 12-2-0 | Ukraine |
| Rodrigo Sezinando | 5289853 | 9-1-0 | Brazil |
| Montserrat Rendon | 5093484 | 6-1-0 | Mexico |
| Alice Pereira | 5261515 | 6-0-0 | Brazil |
| Alessandro Costa | 5074121 | 14-4-0 | Brazil |
| Tatiana Suarez | 4020435 | 11-1-0 | USA |
| Amanda Lemos | 4233196 | 15-4-1 | Brazil |

## Other Sports APIs Used in the App

### MLB Stats API
**Endpoint:** `https://statsapi.mlb.com/api/v1/people/{playerId}`
**Status:** ✅ Working
**Provider:** MLB Advanced Media

#### Example Call & Response:
```bash
curl -s "https://statsapi.mlb.com/api/v1/people/660271"
```

```json
{
  "people": [{
    "id": 660271,
    "fullName": "Shohei Ohtani",
    "firstName": "Shohei",
    "lastName": "Ohtani",
    "primaryNumber": "17",
    "birthDate": "1994-07-05",
    "currentAge": 31,
    "birthCity": "Oshu",
    "birthCountry": "Japan",
    "height": "6' 3\"",
    "weight": 210,
    "active": true,
    "primaryPosition": {
      "code": "Y",
      "name": "Two-Way Player",
      "type": "Two-Way Player"
    },
    "mlbDebutDate": "2018-03-29",
    "batSide": {"code": "L", "description": "Left"},
    "pitchHand": {"code": "R", "description": "Right"}
  }]
}
```

### NHL Stats API
**Endpoint:** `https://statsapi.web.nhl.com/api/v1/people/{playerId}`
**Status:** ❌ Appears to be deprecated/moved

### The Odds API
**Endpoint:** `https://api.the-odds-api.com/v4`
**Status:** ✅ Working (requires API key)
**Used for:** Live odds and betting lines

### Weather API
**Endpoint:** `https://api.openweathermap.org/data/2.5`
**Status:** ✅ Working (requires API key)
**Used for:** Weather conditions for outdoor events

### News API
**Endpoint:** `https://newsapi.org/v2`
**Status:** ✅ Working (requires API key)
**Used for:** Sports news and updates

## API Summary by Sport

| Sport | Player/Fighter Details API | Status | Alternative |
|-------|---------------------------|--------|-------------|
| MMA/UFC | ESPN Individual Athletes | ❌ 404 | Use scoreboard data + Firestore cache |
| Boxing | ESPN Individual Athletes | ❌ 404 | Use scoreboard data + Firestore cache |
| MLB | MLB Stats API | ✅ Working | Full player stats available |
| NHL | NHL Stats API | ❌ Deprecated | Use ESPN scoreboard |
| NFL | ESPN Individual Athletes | ❌ 404 | Use scoreboard data |
| NBA | ESPN Individual Athletes | ❌ 404 | Use scoreboard data |

## Implementation Notes

- The app uses `FighterDataService` to cache fighter data in Firestore
- Cache duration is set to 30 days for fighter profiles
- When ESPN API fails, the app falls back to cached data or creates basic fighter profiles
- Fighter headshot URLs can be constructed using pattern: `https://a.espncdn.com/i/headshots/mma/players/full/{espnId}.png`
- MLB has the most comprehensive player stats API that actually works
- For combat sports, we must rely on extracting data from scoreboard/event endpoints