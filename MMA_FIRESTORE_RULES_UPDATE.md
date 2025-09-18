# Firestore Rules Update for MMA Collections

Add the following rules to your Firestore security rules to allow read/write access to MMA collections:

```javascript
// MMA Event Cache
match /mma_events/{document=**} {
  allow read: if true;
  allow write: if request.auth != null;
}

// MMA Cache
match /mma_cache/{document=**} {
  allow read: if true;
  allow write: if request.auth != null;
}

// MMA Fighters
match /mma_fighters/{document=**} {
  allow read: if true;
  allow write: if request.auth != null;
}

// Fighter Images Cache
match /fighter_images/{document=**} {
  allow read: if true;
  allow write: if request.auth != null;
}
```

## To Apply These Rules:

1. Go to Firebase Console
2. Navigate to Firestore Database
3. Click on "Rules" tab
4. Add the above rules to your existing rules
5. Click "Publish"

## Alternative: Temporary Testing Rules

If you just want to test quickly, you can temporarily use:

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    // Existing rules...

    // Temporary - allow all access to MMA collections for testing
    match /mma_{document=**} {
      allow read, write: if true;
    }

    match /fighter_{document=**} {
      allow read, write: if true;
    }
  }
}
```

**Note:** Remember to update these rules with proper authentication checks before production deployment.