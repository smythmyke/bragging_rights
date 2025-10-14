# Full Fix: Add Marble Run to Edge Tab - Step-by-Step Guide

Follow these steps exactly to add Marble Run game to your Edge tab.

---

## Prerequisites

- ✅ Firebase Console access: https://console.firebase.google.com/
- ✅ Project: `bragging-rights-ea6e1`
- ✅ Marble Run images ready at: `game_assets/marble_run/`

---

## Step 1: Upload Images to Firebase Storage

### 1.1 Open Firebase Console
1. Go to: https://console.firebase.google.com/
2. Select project: **Bragging Rights** (`bragging-rights-ea6e1`)
3. Click **Storage** in left sidebar
4. Click **Get Started** (if first time) or **Files** tab

### 1.2 Create Folder Structure
1. Click **Create folder** button
2. Name it: `game_images`
3. Open the `game_images` folder
4. Click **Create folder** again
5. Name it: `marble_run`

### 1.3 Upload Images
1. Open the `marble_run` folder
2. Click **Upload file** button
3. Navigate to: `C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\game_assets\marble_run\`
4. Select and upload these 3 files:
   - `thumbnail.jpg`
   - `banner.jpg`
   - `gameplay.jpg`
5. Wait for uploads to complete (green checkmarks)

### 1.4 Get Image URLs
For each uploaded image:
1. Click the filename
2. Click **Copy location** or note the download URL
3. Save these URLs - you'll need them in Step 2

**Example URLs will look like:**
```
https://firebasestorage.googleapis.com/v0/b/bragging-rights-ea6e1.appspot.com/o/game_images%2Fmarble_run%2Fthumbnail.jpg?alt=media&token=...
```

---

## Step 2: Add Marble Run to Firestore

### 2.1 Open Firestore
1. In Firebase Console, click **Firestore Database** in left sidebar
2. If you see "Get started", click it and choose:
   - **Start in production mode** (or test mode for development)
   - Location: Choose closest to your users
3. You should now see the Firestore data viewer

### 2.2 Check for Existing Games
1. Look for a collection named `mini-games`
2. If it exists, note what games are already there
3. If it doesn't exist, you'll create it in the next step

### 2.3 Add Marble Run Game Document

**Option A: Manual Entry (Recommended)**

1. Click **Start collection** (or click `mini-games` if it exists)
2. Collection ID: `mini-games`
3. Document ID: `marble_run` (type this exactly)
4. Click **Add field** and enter these fields ONE BY ONE:

| Field Name | Type | Value |
|------------|------|-------|
| `id` | string | `marble_run` |
| `name` | string | `Marble Run - Ultimate Race!` |
| `slug` | string | `marble-run` |
| `category` | string | `arcade` |
| `sportType` | null | (leave as null) |
| `platform` | string | `gamedistribution` |
| `embedUrl` | string | `https://html5.gamedistribution.com/ae42ea5c4e0b4ff4b9eddf47fbd2cc5e/` |
| `gdGameId` | string | `ae42ea5c4e0b4ff4b9eddf47fbd2cc5e` |
| `thumbnailUrl` | string | *[Paste URL from Step 1.4]* |
| `bannerUrl` | string | *[Paste URL from Step 1.4]* |
| `gameplayUrl` | string | *[Paste URL from Step 1.4]* |
| `icon` | string | `🎱` |
| `description` | string | `Guide your marble through colorful mazes and challenging tracks! Race against time and collect points.` |
| `instructions` | string | `Tap and swipe to control your marble. Collect points and reach the finish line!` |
| `avgPlaytime` | string | `5min` |
| `difficulty` | string | `medium` |
| `brCost` | number | `5` |
| `revenueShare` | number | `0.5` |
| `active` | boolean | `true` ⬅️ **VERY IMPORTANT** |
| `featured` | boolean | `true` |
| `weekNumber` | number | `1` |
| `rotationOrder` | number | `1` |
| `totalPlays` | number | `0` |
| `rating` | number | `0` |
| `ratingCount` | number | `0` |

5. Click **Save**

**Option B: Import JSON (Faster)**

1. Open file: `firebase_data/marble_run_game.json`
2. Replace the placeholder URLs with your real image URLs from Step 1.4:
   ```json
   "thumbnailUrl": "https://firebasestorage.googleapis.com/...",
   "bannerUrl": "https://firebasestorage.googleapis.com/...",
   "gameplayUrl": "https://firebasestorage.googleapis.com/...",
   ```
3. In Firestore Console, there's no direct JSON import (requires Firebase CLI)
4. **Recommended**: Use Option A (manual entry) instead

---

## Step 3: Verify Sports Trivia is in Firestore

### 3.1 Check for Sports Trivia
1. In Firestore, look in the `mini-games` collection
2. Look for document ID: `sports_trivia` or `sports-trivia`
3. If it exists and has `active: true`, you're good!
4. If it doesn't exist, add it:

**Sports Trivia Document:**
```
Document ID: sports_trivia
Fields:
  id: "sports_trivia"
  name: "Sports Trivia Challenge"
  active: true
  platform: "custom"
  category: "trivia"
  icon: "🧠"
  brCost: 5
  description: "Test your sports knowledge across NBA, NFL, MLB, NHL and more!"
  embedUrl: "https://[your-firebase-hosting-url]/sports-trivia/"
  thumbnailUrl: "" (leave empty for now)
  bannerUrl: "" (leave empty for now)
  featured: false
  rotationOrder: 2
  totalPlays: 0
```

---

## Step 4: Test in Flutter App

### 4.1 Hot Restart the App
1. If your app is running, do a **hot restart** (not hot reload):
   - Press `Ctrl+Shift+F5` in VS Code
   - Or click the restart button
   - Or run: `flutter run` again
2. This ensures Firestore connections are refreshed

### 4.2 Navigate to Edge Tab
1. Open your app
2. Tap the **Edge** tab in the bottom navigation
3. You should now see:
   - "Mini-Games Arena" header ✅
   - Your BR balance ✅
   - Game cards for Marble Run (and Sports Trivia if added) ✅

### 4.3 Verify Game Card
The Marble Run card should show:
- 🎱 Icon or thumbnail image
- "Marble Run" title
- "PLAY" button
- Trophy icon for leaderboard

### 4.4 Test Playing (Optional)
⚠️ **Note**: The WebView screen for GameDistribution games is not implemented yet.
- If you tap "PLAY", it will try to navigate to `MiniGamePlayScreen`
- This screen expects custom games (like Sports Trivia)
- GameDistribution integration needs the WebView screen (from `GAMEDISTRIBUTION_INTEGRATION_PLAN.md`)

---

## Step 5: Troubleshooting

### Issue: "No Games Available" still shows

**Cause**: Firestore query not finding games

**Fix:**
1. Check document has `active: true` (boolean, not string)
2. Verify document ID is correct (`marble_run`)
3. Try hot restart (Ctrl+Shift+F5)
4. Check Firebase rules allow read access:
   ```javascript
   match /mini-games/{gameId} {
     allow read: if true;
   }
   ```

### Issue: Images not showing

**Cause**: URLs wrong or Storage rules blocking access

**Fix:**
1. Verify URLs are complete (include `?alt=media&token=...`)
2. Check Firebase Storage rules allow read:
   ```javascript
   match /game_images/{allPaths=**} {
     allow read: if true;
   }
   ```
3. Try opening the URL in a browser - should show the image

### Issue: Can't find Firestore or Storage in Console

**Cause**: Services not enabled yet

**Fix:**
1. Go to Firebase Console
2. Click **Firestore Database** → **Create database**
3. Click **Storage** → **Get started**
4. Follow prompts to enable services

### Issue: Flutter app crashes when tapping Edge tab

**Cause**: Firebase not initialized properly

**Fix:**
1. Check `main.dart` has `await Firebase.initializeApp()`
2. Check `firebase_options.dart` exists
3. Run `flutterfire configure` to regenerate config
4. Check console for error messages

---

## Step 6: Next Steps (Optional)

### Add More Games
1. Repeat Steps 1-2 for each new game
2. Browse GameDistribution catalog for games
3. Follow same process: upload images → add Firestore document

### Implement GameDistribution WebView
1. Follow guide: `GAMEDISTRIBUTION_INTEGRATION_PLAN.md`
2. Create `GameWebViewScreen` widget
3. Update `_handleGameTap()` to check platform type
4. Add score input dialog for GD games

### Set up Leaderboards
1. The leaderboard system will auto-create when users play
2. Follow Firestore schema in `FIRESTORE_MINI_GAMES_SCHEMA.md`
3. Implement Cloud Functions for weekly rotation

---

## Quick Reference: What You Created

### Files Created:
```
C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights\
├── game_assets/
│   ├── marble_run/
│   │   ├── thumbnail.jpg ✅
│   │   ├── banner.jpg ✅
│   │   └── gameplay.jpg ✅
│   └── README.md ✅
├── firebase_data/
│   └── marble_run_game.json ✅
├── FIRESTORE_MINI_GAMES_SCHEMA.md ✅
├── GAMEDISTRIBUTION_INTEGRATION_PLAN.md ✅
└── FULL_FIX_STEP_BY_STEP.md ✅ (this file)
```

### Firebase Structure You'll Create:
```
Firebase Storage:
/game_images/
  /marble_run/
    thumbnail.jpg
    banner.jpg
    gameplay.jpg

Firestore:
/mini-games/
  /marble_run (document)
    - active: true
    - name: "Marble Run - Ultimate Race!"
    - embedUrl: "https://..."
    - thumbnailUrl: "https://..."
    - ... (all other fields)
```

---

## Success Checklist

- [ ] Images uploaded to Firebase Storage
- [ ] Image URLs copied
- [ ] Marble Run document added to Firestore with `active: true`
- [ ] Sports Trivia verified in Firestore (if applicable)
- [ ] App hot restarted
- [ ] Edge tab shows game cards
- [ ] Marble Run card visible with icon/image
- [ ] No error messages in console

---

## Need Help?

**Common Commands:**
```bash
# Check Firebase project
firebase projects:list

# Login to Firebase
firebase login

# Deploy to Firebase Hosting (if needed)
firebase deploy --only hosting

# Run Flutter app
flutter run

# Hot restart
Press 'R' in terminal or Ctrl+Shift+F5
```

**Firebase Console URLs:**
- Console: https://console.firebase.google.com/
- Project: https://console.firebase.google.com/project/bragging-rights-ea6e1/
- Firestore: https://console.firebase.google.com/project/bragging-rights-ea6e1/firestore
- Storage: https://console.firebase.google.com/project/bragging-rights-ea6e1/storage

---

**Last Updated**: January 12, 2025
**Status**: Ready to Execute
**Estimated Time**: 15-20 minutes
