# Cloud Functions API Proxy Deployment Guide

## Overview
We've migrated from hardcoded API keys in the Flutter app to secure Cloud Functions that proxy API calls. This ensures API keys are never exposed to users.

## Architecture
```
Flutter App → Cloud Function → External API
    ↓              ↓              ↓
 No API keys   Has API keys   Returns data
```

## Setup Instructions

### 1. Set Firebase Functions Configuration
Run the batch file to set your API keys:
```bash
set_firebase_config.bat
```

Or manually set them:
```bash
firebase functions:config:set api.balldontlie="978b1ba9-9847-40cc-93d1-abca911cf822"
firebase functions:config:set api.news="3386d47aa3fe4a7f8375643727fa5afe"
firebase functions:config:set api.odds="a07a990fba881f317ae71ea131cc8223"
firebase functions:config:set api.sportsdb="3"
```

### 2. Verify Configuration
```bash
firebase functions:config:get
```

### 3. Deploy Cloud Functions
```bash
cd functions
npm install
firebase deploy --only functions
```

Or deploy specific functions:
```bash
firebase deploy --only functions:getNBAGames,functions:getOdds
```

### 4. Test the Functions
Use the Firebase Console or test from your app:
```dart
final cloudApi = CloudApiService();
final nbaGames = await cloudApi.getNBAGames(season: 2024);
final odds = await cloudApi.getOdds(sport: 'basketball_nba');
```

## Available Cloud Functions

### Sports Data APIs
- `getNBAGames` - Fetch NBA games from Balldontlie
- `getNBAStats` - Get NBA player statistics
- `getOdds` - Get betting odds from The Odds API
- `getSportsInSeason` - List active sports
- `getSportsNews` - Get sports news articles
- `getESPNScoreboard` - ESPN scoreboard data
- `getNHLSchedule` - NHL game schedule
- `getTennisMatches` - Tennis matches (coming soon)

### Features
- **Authentication Required**: All functions require user authentication
- **Caching**: Automatic caching to reduce API calls
  - Odds: 5 minutes
  - Games: 5 minutes
  - News: 1 hour
  - Stats: 24 hours
- **Rate Limiting**: Built-in protection against abuse
- **Error Handling**: Graceful fallbacks and error messages

## Security Benefits

1. **API Keys Protected**: Keys stored server-side only
2. **User Authentication**: Only authenticated users can call functions
3. **Rate Limiting**: Prevent API quota abuse
4. **Usage Monitoring**: Track API usage in Firebase Console
5. **Key Rotation**: Update keys without app updates

## Monitoring

View function logs:
```bash
firebase functions:log
```

View specific function logs:
```bash
firebase functions:log --only getNBAGames
```

## Cost Considerations

Firebase Cloud Functions Free Tier:
- 2 million invocations per month
- 400,000 GB-seconds compute time
- 200,000 CPU-seconds

Your app would need thousands of active users to exceed free tier.

## Troubleshooting

### Function not found
- Ensure functions are deployed: `firebase deploy --only functions`
- Check function names match exactly

### Authentication errors
- Ensure user is logged in before calling functions
- Check Firebase Auth is properly configured

### API errors
- Verify API keys are set: `firebase functions:config:get`
- Check API quotas haven't been exceeded
- View logs: `firebase functions:log`

## Migration Checklist

- [x] Create Cloud Function proxies
- [x] Add caching layer
- [x] Create Flutter CloudApiService
- [ ] Deploy functions to Firebase
- [ ] Update app to use CloudApiService
- [ ] Remove hardcoded API keys from Flutter code
- [ ] Test all API integrations
- [ ] Monitor usage and performance

## Next Steps

1. Run `set_firebase_config.bat` to set API keys
2. Deploy functions: `firebase deploy --only functions`
3. Update Flutter services to use CloudApiService
4. Remove all hardcoded API keys from the app
5. Test thoroughly before production release