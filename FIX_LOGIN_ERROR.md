# Fix Login Error - Bragging Rights App

## Quick Diagnosis

### 1. Check the Exact Error Message
While the app is running, try to login and look for the error in:
- The terminal where you ran `flutter run`
- Look for red text with error details

Common error messages and their fixes:

### 2. Common Login Errors & Solutions

#### Error: "PERMISSION_DENIED" or "401"
**Fix:** Enable Authentication in Firebase Console
1. Go to https://console.firebase.google.com
2. Select project: **bragging-rights-ea6e1**
3. Go to Authentication → Sign-in method
4. Enable:
   - Email/Password
   - Google Sign-in

#### Error: "PlatformException(sign_in_failed...)" 
**Fix:** Add SHA fingerprints to Firebase
```bash
# Get your debug SHA-1
cd bragging_rights_app/android
./gradlew signingReport

# Or alternative method:
keytool -list -v -keystore %USERPROFILE%\.android\debug.keystore -alias androiddebugkey -storepass android -keypass android
```

Then:
1. Copy the SHA1 fingerprint
2. Go to Firebase Console → Project Settings → Your Android app
3. Add the SHA-1 fingerprint
4. Download updated `google-services.json`
5. Replace the file in `android/app/`

#### Error: "Network Error" or "Unable to resolve host"
**Fix:** Check internet connection and Firebase project status
- Ensure device has internet
- Check Firebase Console for any service issues

#### Error: "App not authorized" or "Invalid API key"
**Fix:** Regenerate Firebase configuration
```bash
cd bragging_rights_app

# Install FlutterFire CLI if not installed
dart pub global activate flutterfire_cli

# Reconfigure Firebase
flutterfire configure --project=bragging-rights-ea6e1
```

## Step-by-Step Debug Process

### Step 1: Enable Detailed Logging
Add verbose logging to see exact error:

In `lib/services/auth_service.dart`, the errors are already being printed.
Run the app and check the console output.

### Step 2: Test Basic Firebase Connection
Create a test file to verify Firebase is working:

```dart
// test_firebase.dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('Firebase initialized successfully!');
  } catch (e) {
    print('Firebase initialization error: $e');
  }
}
```

Run: `flutter run test_firebase.dart`

### Step 3: Check Firebase Console Setup

1. **Authentication Status**
   - Go to: https://console.firebase.google.com/project/bragging-rights-ea6e1/authentication
   - Ensure "Email/Password" is enabled
   - Ensure "Google" is enabled (if using Google Sign-in)

2. **Firestore Rules** (if login works but data fails)
   - Go to Firestore → Rules
   - For development, use:
   ```javascript
   rules_version = '2';
   service cloud.firestore {
     match /databases/{database}/documents {
       match /{document=**} {
         allow read, write: if request.auth != null;
       }
     }
   }
   ```

3. **API Keys**
   - Go to Project Settings → General
   - Verify Web API key matches your `firebase_options.dart`

## Quick Test Commands

### Test with Email/Password
```dart
// In your login screen, try hardcoded test:
await FirebaseAuth.instance.createUserWithEmailAndPassword(
  email: 'test@example.com',
  password: 'password123'
);
```

### View Real-time Logs
```bash
# While app is running on your Pixel 8a:
adb logcat | findstr "Firebase Auth flutter"

# Or use Flutter logs:
cd bragging_rights_app
flutter logs
```

## If Nothing Works - Nuclear Option

1. **Complete Firebase Reset**
```bash
# Remove old config
cd bragging_rights_app
rm android/app/google-services.json
rm lib/firebase_options.dart

# Reinstall and reconfigure
flutter pub add firebase_core firebase_auth cloud_firestore
dart pub global activate flutterfire_cli
flutterfire configure

# Select:
# - Project: bragging-rights-ea6e1
# - Platforms: android, web, windows
```

2. **Clean Rebuild**
```bash
cd bragging_rights_app
flutter clean
cd android
./gradlew clean
cd ..
flutter pub get
flutter run -d 4B301JEKB11455
```

## Expected Success Output

When login works correctly, you should see in logs:
```
AuthService: signInWithEmailAndPassword called
AuthService: Attempting to sign in with email: [email]
AuthService: Sign in successful. User ID: [uid]
WalletService: Checking wallet for user: [uid]
```

## Still Having Issues?

Run this diagnostic command and share the output:
```bash
cd bragging_rights_app
flutter doctor -v
flutter pub deps | findstr firebase
```

Also share:
1. The exact error message from the console
2. Which login method you're trying (Email or Google)
3. Whether you can see your project at: https://console.firebase.google.com

---
*Note: The project ID **bragging-rights-ea6e1** is correct and matches your google-services.json*