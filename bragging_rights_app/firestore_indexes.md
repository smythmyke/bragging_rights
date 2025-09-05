# Firestore Composite Indexes Required

Based on the queries in the pool_service.dart file, you need to create the following composite indexes in your Firebase Console:

## 1. Pools Collection Indexes

### Index 1: For getPoolsForGame and getPoolsByType
**Collection:** `pools`  
**Fields:**
- `gameId` (Ascending)
- `status` (Ascending)

### Index 2: For getPoolsByType with specific type
**Collection:** `pools`  
**Fields:**
- `gameId` (Ascending)
- `type` (Ascending)
- `status` (Ascending)

### Index 3: For getRegionalPools
**Collection:** `pools`  
**Fields:**
- `gameId` (Ascending)
- `type` (Ascending)
- `region` (Ascending)
- `status` (Ascending)

### Index 4: For getTournamentPools
**Collection:** `pools`  
**Fields:**
- `gameId` (Ascending)
- `type` (Ascending)
- `status` (Ascending)
- `prizePool` (Descending)

### Index 5: For getQuickPlayPools (if it exists)
**Collection:** `pools`  
**Fields:**
- `gameId` (Ascending)
- `type` (Ascending)
- `status` (Ascending)
- `tier` (Ascending)

## 2. User_Pools Collection Indexes

### Index 6: For user pool entries
**Collection:** `user_pools`  
**Fields:**
- `userId` (Ascending)
- `poolId` (Ascending)

## How to Create These Indexes

1. Go to the [Firebase Console](https://console.firebase.google.com/)
2. Select your project: `bragging-rights-ea6e1`
3. Navigate to **Firestore Database** → **Indexes** tab
4. Click **"Create Index"** for each index above
5. Configure the fields exactly as listed
6. Click **"Create"** and wait for the index to build (this can take a few minutes)

## Alternative: Auto-Create Indexes

Firebase will automatically prompt you to create required indexes when queries fail. To trigger this:

1. Run the app and navigate to the pool selection screens
2. Watch the console logs for errors like: "The query requires an index..."
3. The error message will include a direct link to create the exact index needed
4. Click the link and confirm creation in the Firebase Console

## Note on Network Issues

The current errors in your logs indicate network connectivity issues with Firestore. Make sure:
- Your device has internet connectivity
- The Firebase project is active and not suspended
- Your API keys are valid and not restricted