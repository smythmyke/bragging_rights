# Deploying Firestore Indexes

## ✅ STATUS: COMPLETE
All required Firestore indexes have been successfully deployed to the project.

## Prerequisites
1. Install Firebase CLI: `npm install -g firebase-tools`
2. Login to Firebase: `firebase login`
3. Initialize Firebase in the project: `firebase init` (if not already done)

## Deploy Indexes

Run the following command from the `bragging_rights_app` directory:

```bash
firebase deploy --only firestore:indexes
```

## Manual Creation (Alternative)

If you prefer to create indexes manually through the Firebase Console:

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your project
3. Navigate to Firestore Database > Indexes
4. Click "Create Index" and add the following:

### Index 1: Games by Sport and Cache Timestamp (Ascending)
- Collection: `games`
- Fields:
  - `sport` (Ascending)
  - `cacheTimestamp` (Ascending)

### Index 2: Games by Sport and Cache Timestamp (Descending)
- Collection: `games`
- Fields:
  - `sport` (Ascending)
  - `cacheTimestamp` (Descending)

### Index 3: Games by Sport and Date
- Collection: `games`
- Fields:
  - `sport` (Ascending)
  - `date` (Ascending)

### Index 4: Pools by Members
- Collection: `pools`
- Fields:
  - `members` (Arrays)
  - `createdAt` (Descending)

### Index 5: Picks by User and Pool
- Collection: `picks`
- Fields:
  - `userId` (Ascending)
  - `poolId` (Ascending)

### Index 6: Picks by Pool and Game
- Collection: `picks`
- Fields:
  - `poolId` (Ascending)
  - `gameId` (Ascending)

## Verify Indexes

✅ **VERIFIED**: All indexes are deployed and active:
- Games collection: sport + cacheTimestamp (ASC/DESC), sport + date
- Pools collection: All required composite indexes
- Picks collection: userId + poolId, poolId + gameId
- Wagers/Transactions: All required indexes
- Members array index for pools

After deployment, verify the indexes are active:
1. Go to Firestore Database > Indexes in Firebase Console
2. All indexes should show status "Enabled"
3. Test the app to ensure no more index errors appear in logs