# Firestore Rules Setup for MMA Collections

## Current Status
✅ **Mock data removed** - The MMA implementation now only uses real ESPN API data
❌ **Firestore rules needed** - The app needs permission to read/write MMA cache collections

## Required Firestore Rules

Add these rules to your Firebase Console → Firestore Database → Rules:

```javascript
// Add these inside your existing rules_version = '2' block
// Inside service cloud.firestore { match /databases/{database}/documents {

// MMA Event Cache - stores full event details
match /mma_events/{document=**} {
  allow read: if true;  // Anyone can read cached events
  allow write: if request.auth != null;  // Only authenticated users can update cache
}

// MMA General Cache - stores lists of upcoming events
match /mma_cache/{document=**} {
  allow read: if true;  // Anyone can read cached data
  allow write: if request.auth != null;  // Only authenticated users can update cache
}

// MMA Fighter Cache - stores fighter details
match /mma_fighters/{document=**} {
  allow read: if true;  // Anyone can read fighter data
  allow write: if request.auth != null;  // Only authenticated users can update cache
}

// Fighter Images Cache - stores fighter image URLs
match /fighter_images/{document=**} {
  allow read: if true;  // Anyone can read image URLs
  allow write: if request.auth != null;  // Only authenticated users can update cache
}
```

## How to Apply

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project
3. Navigate to **Firestore Database** in the left menu
4. Click on the **Rules** tab
5. Add the above rules to your existing rules (don't replace everything, just add these)
6. Click **Publish**

## What These Rules Do

- **Read access**: Anyone can read cached MMA data (no authentication required for viewing)
- **Write access**: Only authenticated users can update the cache (prevents spam/abuse)
- **Collections covered**:
  - `mma_events`: Full event details with fight cards
  - `mma_cache`: Lists of upcoming events
  - `mma_fighters`: Fighter profiles and stats
  - `fighter_images`: Fighter headshot URLs

## Testing After Adding Rules

1. Navigate to an MMA/UFC event in the app
2. The event should load without permission errors
3. Check the console logs - you should see:
   - "✅ Loaded event from cache" (if cached) or
   - "✅ Received event data from ESPN" (if fetching new)
   - "💾 Event cached successfully" (after successful cache write)

## Note on Event IDs

The app expects numeric ESPN event IDs (e.g., "401603205"). If your events have different ID formats (like "mma_fighter1_vs_fighter2"), they won't work with the ESPN API. The app will show an error message instead of mock data.