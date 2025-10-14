# Firestore Schema for Mini-Games System

This document defines the Firestore database structure for the mini-games feature in Bragging Rights.

## Collections Overview

```
/mini-games/
/weekly-leaderboards/
/user-mini-game-stats/
/mini-game-config/
/score-verifications/
```

---

## 1. `/mini-games/{gameId}` - Game Metadata

Stores information about each available game.

### Document Structure

```json
{
  "id": "marble_run",
  "name": "Marble Run - Ultimate Race!",
  "slug": "marble_run",
  "category": "arcade",
  "sportType": null,

  // Platform & Integration
  "platform": "gamedistribution",
  "embedUrl": "https://html5.gamedistribution.com/ae42ea5c4e0b4ff4b9eddf47fbd2cc5e/",
  "gdGameId": "ae42ea5c4e0b4ff4b9eddf47fbd2cc5e",

  // Visual Assets
  "thumbnailUrl": "https://firebasestorage.googleapis.com/.../marble_run/thumbnail.jpg",
  "bannerUrl": "https://firebasestorage.googleapis.com/.../marble_run/banner.jpg",
  "gameplayUrl": "https://firebasestorage.googleapis.com/.../marble_run/gameplay.jpg",
  "icon": "🎱",

  // Game Info
  "description": "Guide your marble through colorful mazes and challenging tracks!",
  "instructions": "Tap and swipe to control your marble. Collect points and reach the finish line!",
  "avgPlaytime": "5min",
  "difficulty": "medium",

  // Pricing & Economy
  "brCost": 5,
  "revenueShare": 0.5,

  // Status & Availability
  "active": true,
  "featured": true,
  "weekNumber": 1,
  "rotationOrder": 1,

  // Metadata
  "createdAt": "2025-01-12T00:00:00Z",
  "updatedAt": "2025-01-12T00:00:00Z",
  "totalPlays": 1523,
  "rating": 4.9,
  "ratingCount": 287
}
```

### Field Descriptions

| Field | Type | Required | Description |
|-------|------|----------|-------------|
| `id` | string | ✅ | Unique game identifier (lowercase, underscores) |
| `name` | string | ✅ | Display name of the game |
| `slug` | string | ✅ | URL-friendly version of name |
| `category` | string | ✅ | Game category: `arcade`, `trivia`, `sports`, `puzzle` |
| `sportType` | string | ❌ | Specific sport if applicable: `basketball`, `soccer`, etc. |
| `platform` | string | ✅ | `gamedistribution`, `custom`, `html5` |
| `embedUrl` | string | ✅ | Full URL to embed/load the game |
| `gdGameId` | string | ❌ | GameDistribution game ID (if applicable) |
| `thumbnailUrl` | string | ✅ | Firebase Storage URL for card thumbnail |
| `bannerUrl` | string | ✅ | Firebase Storage URL for featured banner |
| `gameplayUrl` | string | ❌ | Firebase Storage URL for gameplay screenshot |
| `icon` | string | ❌ | Emoji fallback icon |
| `description` | string | ✅ | Short marketing description |
| `instructions` | string | ❌ | How to play instructions |
| `avgPlaytime` | string | ✅ | Average time to complete (e.g., "5min") |
| `difficulty` | string | ❌ | `easy`, `medium`, `hard` |
| `brCost` | number | ✅ | Cost in BR to play (default: 5) |
| `revenueShare` | number | ✅ | Revenue share % (0.5 = 50% for GD, 1.0 = 100% for custom) |
| `active` | boolean | ✅ | Whether game is currently playable |
| `featured` | boolean | ✅ | Show in featured section |
| `weekNumber` | number | ❌ | Week in rotation (1-7 or 1-14) |
| `rotationOrder` | number | ❌ | Display order in list |
| `createdAt` | timestamp | ✅ | When game was added |
| `updatedAt` | timestamp | ✅ | Last modification timestamp |
| `totalPlays` | number | ✅ | Total number of plays across all users |
| `rating` | number | ❌ | Average user rating (0-5 stars) |
| `ratingCount` | number | ❌ | Number of ratings submitted |

---

## 2. `/weekly-leaderboards/{weekId_gameId}/scores/{userId}` - Leaderboard Entries

Stores weekly leaderboard scores for each game.

### Collection Path Example
```
/weekly-leaderboards/2025-w02_marble_run/scores/{userId}
```

### Document Structure

```json
{
  "userId": "abc123",
  "username": "PlayerOne",
  "userPhotoUrl": "https://...",
  "score": 10450,
  "rank": 15,

  // Game Context
  "gameId": "marble_run",
  "weekId": "2025-w02",
  "weekStart": "2025-01-08T00:00:00Z",
  "weekEnd": "2025-01-15T00:00:00Z",

  // Play Details
  "attempts": 8,
  "lastAttemptAt": "2025-01-12T14:30:00Z",
  "bestScoreAt": "2025-01-11T19:15:00Z",
  "brSpent": 40,

  // Verification (for top finishers)
  "verified": false,
  "screenshotUrl": null,
  "verifiedAt": null,
  "verifiedBy": null,

  // Metadata
  "createdAt": "2025-01-08T10:00:00Z",
  "updatedAt": "2025-01-12T14:30:00Z"
}
```

### Indexes Required

```
weekId (Ascending) + score (Descending)
gameId (Ascending) + score (Descending)
userId (Ascending) + weekId (Ascending)
```

---

## 3. `/user-mini-game-stats/{userId}` - User Game Statistics

Tracks overall user performance across all games.

### Document Structure

```json
{
  "userId": "abc123",

  // Overall Stats
  "totalPlays": 47,
  "totalBRSpent": 235,
  "totalPrizesWon": 150,
  "gamesPlayed": ["marble_run", "sports_trivia", "basketball_stars"],

  // Best Performances
  "bestRanks": {
    "marble_run": 3,
    "sports_trivia": 12,
    "basketball_stars": 7
  },

  "highScores": {
    "marble_run": 12450,
    "sports_trivia": 95,
    "basketball_stars": 8750
  },

  // Recent Activity
  "lastPlayedGameId": "marble_run",
  "lastPlayedAt": "2025-01-12T14:30:00Z",

  // Achievements
  "weeklyWins": 2,
  "top10Finishes": 8,
  "perfectScores": 1,

  // Metadata
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2025-01-12T14:30:00Z"
}
```

### Subcollection: `games/{gameId}`

Individual game stats per user:

```json
{
  "gameId": "marble_run",
  "attempts": 12,
  "bestScore": 10450,
  "bestRank": 15,
  "brSpent": 60,
  "firstPlayedAt": "2025-01-08T10:00:00Z",
  "lastPlayedAt": "2025-01-12T14:30:00Z",
  "averageScore": 8200,
  "prizesWon": 0
}
```

---

## 4. `/mini-game-config/weekly-rotation` - Rotation Configuration

Controls which game is featured each week.

### Document Structure

```json
{
  "currentWeek": 2,
  "currentYear": 2025,
  "weekStart": "2025-01-08T00:00:00Z",
  "weekEnd": "2025-01-15T00:00:00Z",
  "featuredGameId": "marble_run",

  "rotationSchedule": [
    {"week": 1, "gameId": "sports_trivia"},
    {"week": 2, "gameId": "marble_run"},
    {"week": 3, "gameId": "basketball_stars"},
    {"week": 4, "gameId": "penalty_shooters"},
    {"week": 5, "gameId": "baseball_pro"},
    {"week": 6, "gameId": "memory_match"},
    {"week": 7, "gameId": "golf_orbit"}
  ],

  "prizeStructure": {
    "1": 500,
    "2": 250,
    "3": 100,
    "4-10": 50
  },

  "autoRotate": true,
  "lastRotationAt": "2025-01-08T00:00:00Z",
  "nextRotationAt": "2025-01-15T00:00:00Z"
}
```

---

## 5. `/score-verifications/{verificationId}` - Anti-Cheat Verification

Stores screenshots and verification data for top finishers.

### Document Structure

```json
{
  "userId": "abc123",
  "username": "PlayerOne",
  "gameId": "marble_run",
  "weekId": "2025-w02",
  "score": 12450,
  "rank": 3,

  // Screenshot Evidence
  "screenshotUrl": "https://firebasestorage.googleapis.com/.../screenshot.jpg",
  "screenshotUploadedAt": "2025-01-12T15:00:00Z",

  // Verification Status
  "status": "pending",
  "verified": false,
  "verifiedAt": null,
  "verifiedBy": null,
  "verificationNotes": "",

  // Flags
  "flagged": false,
  "flagReason": null,
  "reportedBy": [],

  // Context
  "attempts": 8,
  "brSpent": 40,
  "deviceInfo": {
    "platform": "android",
    "model": "Pixel 7",
    "os": "Android 13"
  },

  "createdAt": "2025-01-12T14:30:00Z",
  "updatedAt": "2025-01-12T15:00:00Z"
}
```

### Status Values
- `pending` - Awaiting review
- `verified` - Approved by admin
- `rejected` - Suspicious/invalid
- `flagged` - Needs additional review

---

## 6. `/prize-history/{weekId}` - Prize Distribution Records

Archives which users won prizes each week.

### Document Structure

```json
{
  "weekId": "2025-w02",
  "gameId": "marble_run",
  "weekStart": "2025-01-08T00:00:00Z",
  "weekEnd": "2025-01-15T00:00:00Z",
  "totalPrizePool": 1200,
  "distributedAt": "2025-01-15T00:05:00Z",

  "winners": [
    {
      "rank": 1,
      "userId": "abc123",
      "username": "TopPlayer",
      "score": 12450,
      "prize": 500,
      "paidAt": "2025-01-15T00:05:00Z",
      "transactionId": "tx_xyz789"
    },
    {
      "rank": 2,
      "userId": "def456",
      "username": "SecondPlace",
      "score": 11890,
      "prize": 250,
      "paidAt": "2025-01-15T00:05:00Z",
      "transactionId": "tx_abc456"
    }
    // ... ranks 3-10
  ],

  "totalWinners": 10,
  "totalDistributed": 1200,
  "distributionStatus": "completed"
}
```

---

## Security Rules

### Firestore Security Rules Example

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Mini-games collection - Read: Public, Write: Admin only
    match /mini-games/{gameId} {
      allow read: if true;
      allow write: if request.auth != null &&
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Leaderboards - Read: Public, Write: Authenticated users (own scores only)
    match /weekly-leaderboards/{weekGameId}/scores/{userId} {
      allow read: if true;
      allow create, update: if request.auth != null && request.auth.uid == userId;
      allow delete: if false;
    }

    // User stats - Read/Write: Own data only
    match /user-mini-game-stats/{userId} {
      allow read, write: if request.auth != null && request.auth.uid == userId;

      match /games/{gameId} {
        allow read, write: if request.auth != null && request.auth.uid == userId;
      }
    }

    // Config - Read: Public, Write: Admin only
    match /mini-game-config/{doc} {
      allow read: if true;
      allow write: if request.auth != null &&
                      get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
    }

    // Verifications - Read: Admin only, Write: User can upload screenshot
    match /score-verifications/{verificationId} {
      allow read: if request.auth != null &&
                     get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin';
      allow create: if request.auth != null && request.resource.data.userId == request.auth.uid;
      allow update: if request.auth != null && (
        // User can update their own screenshot
        (request.auth.uid == resource.data.userId &&
         request.resource.data.diff(resource.data).affectedKeys().hasOnly(['screenshotUrl', 'screenshotUploadedAt', 'updatedAt'])) ||
        // Admin can verify
        (get(/databases/$(database)/documents/users/$(request.auth.uid)).data.role == 'admin')
      );
    }

    // Prize history - Read: Public, Write: Admin/Cloud Function only
    match /prize-history/{weekId} {
      allow read: if true;
      allow write: if false; // Only Cloud Functions can write
    }
  }
}
```

---

## Cloud Functions Needed

### 1. `onGameComplete` - Score Submission Handler
- Triggered when user closes game WebView
- Validates score range
- Updates leaderboard
- Updates user stats
- Checks for top 10 placement → triggers screenshot request

### 2. `weeklyRotation` - Scheduled Function
- Runs every Monday at 00:00 UTC
- Archives current week's leaderboard
- Distributes prizes to top 10
- Rotates to next featured game
- Sends push notifications

### 3. `calculateRankings` - Real-time Rankings
- Triggered on leaderboard updates
- Recalculates ranks for all users
- Updates rank field in real-time

### 4. `antiCheatValidation` - Score Validation
- Triggered on score submission
- Checks for outliers (>3 standard deviations)
- Flags suspicious scores
- Notifies admin for review

---

## Example Queries

### Get Current Week's Leaderboard
```dart
final snapshot = await FirebaseFirestore.instance
  .collection('weekly-leaderboards')
  .doc('2025-w02_marble_run')
  .collection('scores')
  .orderBy('score', descending: true)
  .limit(100)
  .get();
```

### Get User's Rank
```dart
final snapshot = await FirebaseFirestore.instance
  .collection('weekly-leaderboards')
  .doc('2025-w02_marble_run')
  .collection('scores')
  .doc(userId)
  .get();

final rank = snapshot.data()?['rank'] ?? 999;
```

### Get Featured Game
```dart
final config = await FirebaseFirestore.instance
  .collection('mini-game-config')
  .doc('weekly-rotation')
  .get();

final featuredGameId = config.data()?['featuredGameId'];

final game = await FirebaseFirestore.instance
  .collection('mini-games')
  .doc(featuredGameId)
  .get();
```

### Get All Active Games
```dart
final games = await FirebaseFirestore.instance
  .collection('mini-games')
  .where('active', isEqualTo: true)
  .orderBy('rotationOrder')
  .get();
```

---

## Migration Path

### Phase 0 → Phase 1 (Adding GameDistribution Games)

1. Add new game documents to `/mini-games/`
2. No schema changes needed
3. Just populate with GD game data

### Phase 1 → Phase 2 (Adding Custom Games)

1. Update `platform` field to distinguish game types
2. Add `revenueShare` field (1.0 for custom, 0.5 for GD)
3. No breaking changes

---

## Notes

- All timestamps use ISO 8601 format
- Week IDs format: `YYYY-wWW` (e.g., `2025-w02`)
- Game IDs use lowercase with underscores (e.g., `marble_run`)
- All BR amounts are integers (no decimals)
- Scores are integers (game-specific meaning)
- Rankings are 1-indexed (1st place = rank 1)

---

**Last Updated**: January 12, 2025
**Version**: 1.0
**Status**: Ready for Implementation
