# Bragging Rights App

A competitive sports betting app using virtual currency (BR - Bragging Rights) with pool-based and head-to-head betting options.

## Features

### Supported Sports (7 Total)
- **NBA** - Basketball games with live scores
- **NFL** - Football games with spreads and totals
- **NHL** - Hockey games with puck lines
- **MLB** - Baseball games with run lines
- **Tennis** - ATP/WTA matches with rankings
- **MMA/UFC** - Fight cards with multiple bouts (UFC, Bellator, PFL, ONE Championship)
- **Boxing** - Boxing events and matches

### Betting Types
- **Pool-Based Betting**
  - Quick Play pools with different buy-in tiers
  - Regional pools (neighborhood, city, state, national)
  - Tournament pools with structured payouts
  - Private pools for friends
  
- **Head-to-Head Challenges**
  - Direct challenges to specific users
  - Open challenges for anyone to accept
  - Auto-match system for instant opponents
  - Single fight or full card betting for MMA/UFC

### UFC/MMA Fight Card Features
- Complete fight card support (Main Event, Co-Main, Main Card, Prelims)
- Fighter pick with confidence levels (1-5 stars)
- Method of victory predictions (KO/TKO, Submission, Decision)
- Round predictions for finishes
- Underdog bonus scoring
- 2x1 mobile-first grid layout

### Key Systems
- **BR Currency**: Virtual currency system with no real money
- **100% Prize Pool Distribution**: No house fees taken
- **Auto Pool Generation**: Automatic creation of pools for events
- **Live Odds Integration**: Real-time betting lines from multiple sources
- **Multi-Source Data**: ESPN API with fallback to free odds services

## Tech Stack
- **Frontend**: Flutter/Dart
- **Backend**: Firebase (Firestore, Auth, Cloud Functions)
- **APIs**: ESPN, The Odds API, Free Odds Service
- **Platform**: iOS and Android

## Running the App

```bash
# Navigate to project directory
cd C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\bragging_rights_app

# Run on connected device
C:\flutter\bin\flutter run

# Run on specific device
C:\flutter\bin\flutter run -d [device-id]
```

## Project Structure
```
lib/
├── models/           # Data models (pools, games, fight cards, H2H)
├── screens/          # UI screens
│   ├── pools/       # Pool betting screens
│   ├── games/       # Game selection screens
│   └── profile/     # User profile screens
├── services/        # Backend services
│   ├── edge/        # ESPN and sports data services
│   └── firebase/    # Firestore operations
└── widgets/         # Reusable UI components
```

## Recent Updates
- Added MMA/UFC support with full fight card betting
- Implemented head-to-head challenge system
- Added tennis integration with ATP/WTA rankings
- Created auto pool generation to populate events
- Built mobile-first 2x1 fight grid layout
- Integrated live odds from multiple sources

## Development Notes
- No house fees on any pools (100% payout)
- BR-only scoring system (no dual point/BR system)
- Supports skipping prelims and late entries
- Smart matchmaking for head-to-head challenges

For deployment and configuration details, see the documentation in the parent directory.
