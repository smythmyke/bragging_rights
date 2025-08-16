# Bragging Rights - Setup Commands & Steps

## Step 1: Install Flutter SDK

### Download Flutter
1. Open browser and go to: https://docs.flutter.dev/get-started/install/windows
2. Click "Download Flutter SDK" (about 1GB)
3. Create folder: `C:\flutter`
4. Extract ZIP contents to `C:\flutter`

### Add Flutter to PATH
```powershell
# Open PowerShell as Administrator and run:
[Environment]::SetEnvironmentVariable("Path", $env:Path + ";C:\flutter\bin", [EnvironmentVariableTarget]::Machine)
```

### Verify Flutter Installation
```bash
# Close and reopen terminal, then run:
flutter --version
flutter doctor
```

---

## Step 2: Install Android Studio

### Download & Install
1. Download from: https://developer.android.com/studio
2. Run installer with these options checked:
   - ✅ Android SDK
   - ✅ Android SDK Platform-Tools  
   - ✅ Android Virtual Device
   - ✅ Performance (Intel HAXM) - if available

### Post-Installation Configuration
1. Launch Android Studio
2. Click "More Actions" → "SDK Manager"
3. SDK Platforms tab - Install:
   - Android 13.0 (Tiramisu) API Level 33
   - Android 12.0 (S) API Level 31

4. SDK Tools tab - Install:
   - Android SDK Build-Tools
   - Android SDK Command-line Tools
   - Android Emulator
   - Android SDK Platform-Tools
   - Google Play Services
   - Intel x86 Emulator Accelerator (HAXM installer)

---

## Step 3: Create Android Virtual Device

### In Android Studio:
1. Click "More Actions" → "Virtual Device Manager"
2. Click "Create Device"
3. Select: Pixel 6 → Next
4. System Image: Android 13 (API 33) with Google Play Store → Download → Next
5. AVD Name: "Pixel_6_API_33"
6. Show Advanced Settings:
   - RAM: 4096 MB
   - VM heap: 256 MB
   - Internal Storage: 2048 MB
7. Finish

### Test Emulator
```bash
# List available emulators
flutter emulators

# Launch emulator
flutter emulators --launch Pixel_6_API_33
```

---

## Step 4: VS Code Setup

### Install VS Code Extensions
```bash
# After installing VS Code, run these commands:
code --install-extension Dart-Code.flutter
code --install-extension Dart-Code.dart-code
code --install-extension toba.vsfire
code --install-extension eamodio.gitlens
code --install-extension usernamehw.errorlens
code --install-extension rangav.vscode-thunder-client
```

---

## Step 5: Install Node.js & Firebase CLI

### Install Node.js
1. Download LTS from: https://nodejs.org/
2. Run installer with default options

### Install Firebase CLI
```bash
# Open new terminal and run:
npm install -g firebase-tools

# Login to Firebase
firebase login
```

---

## Step 6: Create Firebase Project

### Via Firebase Console (Web)
1. Go to: https://console.firebase.google.com/
2. Click "Create a project"
3. Project name: "bragging-rights-app"
4. Enable Google Analytics: Yes
5. Select Default Account for Firebase
6. Create Project

### Enable Firebase Services
In Firebase Console for your project:

1. **Authentication**
   - Go to Authentication → Get Started
   - Sign-in Methods → Enable:
     - Email/Password
     - Google
     - Apple (configure later)

2. **Firestore Database**
   - Go to Firestore Database → Create Database
   - Start in Test Mode (we'll secure it later)
   - Location: nam5 (United States)

3. **Cloud Storage**
   - Go to Storage → Get Started
   - Start in Test Mode
   - Location: Same as Firestore

4. **Cloud Messaging**
   - Go to Project Settings → Cloud Messaging
   - Note the Server Key for later

---

## Step 7: Initialize Flutter Project

### Create Flutter Project
```bash
# Navigate to your projects folder
cd C:\Users\smyth\OneDrive\Desktop\Projects\Bragging_Rights

# Create Flutter app
flutter create bragging_rights_app --org com.braggingrights --platforms android,ios

# Navigate to project
cd bragging_rights_app
```

### Add Firebase to Flutter
```bash
# Install FlutterFire CLI
dart pub global activate flutterfire_cli

# Configure Firebase in your Flutter app
flutterfire configure

# Select:
# - Project: bragging-rights-app
# - Platforms: android, ios
# - Android package name: com.braggingrights.app
```

### Install Firebase Packages
```bash
# Add Firebase dependencies
flutter pub add firebase_core
flutter pub add firebase_auth
flutter pub add cloud_firestore
flutter pub add firebase_storage
flutter pub add firebase_messaging
flutter pub add firebase_analytics
```

---

## Step 8: Project Structure Setup

### Create folder structure:
```
bragging_rights_app/
├── lib/
│   ├── main.dart
│   ├── core/
│   │   ├── constants/
│   │   ├── themes/
│   │   └── utils/
│   ├── data/
│   │   ├── models/
│   │   ├── repositories/
│   │   └── services/
│   ├── presentation/
│   │   ├── screens/
│   │   ├── widgets/
│   │   └── providers/
│   └── routes/
├── assets/
│   ├── images/
│   ├── fonts/
│   └── icons/
└── test/
```

### Create structure via terminal:
```bash
# Windows Command Prompt
mkdir lib\core\constants lib\core\themes lib\core\utils
mkdir lib\data\models lib\data\repositories lib\data\services  
mkdir lib\presentation\screens lib\presentation\widgets lib\presentation\providers
mkdir lib\routes
mkdir assets\images assets\fonts assets\icons
```

---

## Step 9: Test Everything

### Run Flutter Doctor
```bash
flutter doctor -v
```

Expected output should show all green checkmarks for:
- Flutter
- Android toolchain
- Chrome
- Android Studio
- VS Code
- Connected device (emulator)

### Create Test App with Firebase
```bash
# Create a simple test file
echo "Test file for Firebase" > lib/test_firebase.dart
```

### Run the App
```bash
# Ensure emulator is running
flutter emulators --launch Pixel_6_API_33

# Run the app
flutter run

# You should see the default Flutter demo app
```

---

## Step 10: Initialize Git Repository

```bash
# Initialize git
git init

# Create .gitignore
echo "# Flutter
.dart_tool/
.packages
build/
.flutter-plugins
.flutter-plugins-dependencies
*.iml
.idea/
.vscode/
*.log
.DS_Store

# Firebase
google-services.json
GoogleService-Info.plist
firebase_options.dart

# Environment
.env
.env.local" > .gitignore

# Initial commit
git add .
git commit -m "Initial Flutter project setup with Firebase"
```

---

## Troubleshooting Commands

### If Flutter doctor shows issues:
```bash
# Accept Android licenses
flutter doctor --android-licenses

# Update Flutter
flutter upgrade

# Clean and rebuild
flutter clean
flutter pub get

# Reset Flutter
flutter config --clear-features
```

### If emulator won't start:
```powershell
# Check virtualization (PowerShell as Admin)
Get-ComputerInfo | select HyperVisorPresent

# Disable Hyper-V if needed
bcdedit /set hypervisorlaunchtype off
# Then restart computer
```

---

## Environment Variables (.env)

Create `.env` file in project root:
```
# API Keys (add these as you get them)
SPORTS_API_KEY=your_sports_api_key
GIPHY_API_KEY=your_giphy_api_key
FIREBASE_WEB_API_KEY=from_firebase_console

# Feature Flags
ENABLE_CHAT=true
ENABLE_INSTA_BETS=true
MIN_BR_BALANCE=10
WEEKLY_ALLOWANCE=25
STARTING_BALANCE=500
```

---

## Next Steps After Setup

1. ✅ All tools installed and configured
2. ✅ Firebase project created and linked
3. ✅ Flutter project initialized
4. ✅ Emulator working
5. 🎯 Ready to start building the Bragging Rights app!

---

## Quick Reference Commands

```bash
# Daily development commands
flutter run                 # Run app
flutter run -d chrome       # Run in Chrome
flutter build apk          # Build Android APK
flutter clean              # Clean build
flutter pub get            # Get dependencies
flutter doctor             # Check setup

# Firebase commands  
firebase init              # Initialize Firebase
firebase deploy            # Deploy to Firebase
flutterfire configure      # Configure FlutterFire

# Git commands
git status                 # Check changes
git add .                  # Stage all changes
git commit -m "message"    # Commit changes
git push                   # Push to remote
```