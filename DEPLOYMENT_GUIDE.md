# Bragging Rights - Complete Deployment Guide

## Table of Contents
1. [Development Setup](#development-setup)
2. [Running the App](#running-the-app)
3. [Git Workflow](#git-workflow)
4. [Building for Release](#building-for-release)
5. [Testing Guidelines](#testing-guidelines)
6. [Deployment Checklist](#deployment-checklist)

---

## Development Setup

### Prerequisites
- **Flutter SDK**: `C:\flutter`
- **Android Studio**: With SDK tools installed
- **Git**: For version control
- **VS Code**: With Flutter extension
- **Firebase**: Project configured (bragging-rights-d5b8e)

### First Time Setup
```bash
# Clone repository (if needed)
git clone [repository-url]
cd Bragging_Rights

# Navigate to app directory
cd bragging_rights_app

# Get dependencies
C:\flutter\bin\flutter pub get

# Verify setup
C:\flutter\bin\flutter doctor
```

---

## Running the App

### Quick Commands for Your Pixel 8a

#### Development Mode (with hot reload)
```bash
cd bragging_rights_app
C:\flutter\bin\flutter run -d 4B301JEKB11455
```
- Press `r` for hot reload
- Press `R` for hot restart
- Press `q` to quit

#### Release Mode (performance testing)
```bash
cd bragging_rights_app
C:\flutter\bin\flutter run --release -d 4B301JEKB11455
```

#### Profile Mode (performance analysis)
```bash
cd bragging_rights_app
C:\flutter\bin\flutter run --profile -d 4B301JEKB11455
```

### Other Platforms

#### Web (Chrome)
```bash
C:\flutter\bin\flutter run -d chrome
```

#### Windows Desktop
```bash
C:\flutter\bin\flutter run -d windows
```

#### Android Emulator
```bash
C:\flutter\bin\flutter emulators --launch Bragging_Rights_Pixel6
C:\flutter\bin\flutter run
```

---

## Git Workflow

### Daily Development Workflow

#### 1. Start Your Day
```bash
# Always pull latest changes
git pull origin main

# Create feature branch
git checkout -b feature/your-feature-name
```

#### 2. Make Changes
```bash
# Check status frequently
git status

# View changes
git diff

# Stage specific files
git add lib/screens/your_file.dart
# OR stage all changes
git add .
```

#### 3. Commit Your Work

##### Commit Message Format
```
<type>: <description>

[optional body]

[optional footer]
```

**Types:**
- `feat:` New feature
- `fix:` Bug fix
- `docs:` Documentation
- `style:` Code style (formatting, no logic change)
- `refactor:` Code restructuring
- `test:` Tests
- `chore:` Maintenance

**Examples:**
```bash
git commit -m "feat: add BR wallet integration to Edge screen"
git commit -m "fix: resolve navigation issue in betting flow"
git commit -m "docs: update deployment guide with device instructions"
```

#### 4. Push Changes
```bash
# First time pushing branch
git push -u origin feature/your-feature-name

# Subsequent pushes
git push
```

#### 5. Create Pull Request
```bash
# Using GitHub CLI (if installed)
gh pr create --title "Feature: Your feature name" --body "Description of changes"

# Or push and create PR via GitHub website
```

### Common Git Commands

```bash
# View commit history
git log --oneline -10

# Undo last commit (keep changes)
git reset --soft HEAD~1

# Discard local changes
git checkout -- filename.dart

# Stash changes temporarily
git stash
git stash pop

# Update branch with main
git checkout main
git pull
git checkout your-branch
git merge main

# View remote info
git remote -v

# Check branch
git branch
```

---

## Building for Release

### Android APK

#### Standard APK (larger, compatible with all devices)
```bash
cd bragging_rights_app
C:\flutter\bin\flutter build apk --release
```
Output: `build\app\outputs\flutter-apk\app-release.apk`

#### Split APKs (smaller, per architecture)
```bash
C:\flutter\bin\flutter build apk --split-per-abi
```
Outputs:
- `app-armeabi-v7a-release.apk` (older devices)
- `app-arm64-v8a-release.apk` (modern devices)
- `app-x86_64-release.apk` (emulators)

#### App Bundle (for Play Store)
```bash
C:\flutter\bin\flutter build appbundle
```
Output: `build\app\outputs\bundle\release\app-release.aab`

### Web Build
```bash
C:\flutter\bin\flutter build web

# With specific renderer
C:\flutter\bin\flutter build web --web-renderer html  # Better compatibility
C:\flutter\bin\flutter build web --web-renderer canvaskit  # Better performance
```
Output: `build\web\`

### Windows Build
```bash
C:\flutter\bin\flutter build windows
```
Output: `build\windows\runner\Release\`

---

## Testing Guidelines

### Before Every Commit

#### 1. Run Tests
```bash
# Run all tests
C:\flutter\bin\flutter test

# Run specific test file
C:\flutter\bin\flutter test test/widget_test.dart
```

#### 2. Analyze Code
```bash
# Check for issues
C:\flutter\bin\flutter analyze

# Fix formatting
C:\flutter\bin\flutter format lib/
```

#### 3. Test on Device
```bash
# Quick test on Pixel 8a
C:\flutter\bin\flutter run -d 4B301JEKB11455

# Test these flows:
# - Login/Registration
# - Sport selection
# - Place a bet
# - Check wallet balance
# - Navigate all screens
```

### Performance Testing
```bash
# Run in profile mode
C:\flutter\bin\flutter run --profile -d 4B301JEKB11455

# Check performance overlay
# Press 'P' while running
```

---

## Deployment Checklist

### Pre-Deployment

#### Code Quality
- [ ] All tests passing (`flutter test`)
- [ ] No analyzer issues (`flutter analyze`)
- [ ] Code formatted (`flutter format lib/`)
- [ ] No print statements in production code
- [ ] TODOs addressed or documented

#### Functionality
- [ ] Login/Auth working
- [ ] All navigation paths tested
- [ ] Betting flow complete
- [ ] Wallet transactions working
- [ ] Edge screen purchasing works
- [ ] No crashes or errors

#### Performance
- [ ] App runs smooth 60 FPS
- [ ] No memory leaks
- [ ] Images optimized
- [ ] Animations smooth
- [ ] App size reasonable (<100MB)

#### Security
- [ ] API keys secure
- [ ] No hardcoded secrets
- [ ] Firebase rules configured
- [ ] User data protected

### Build & Deploy

#### For Testing (Internal)
```bash
# 1. Update version in pubspec.yaml
# version: 1.0.0+1 -> 1.0.1+2

# 2. Build APK
C:\flutter\bin\flutter build apk --release

# 3. Test on multiple devices
# - Install APK manually
# - Test all features
# - Check performance

# 4. Commit version change
git add pubspec.yaml
git commit -m "chore: bump version to 1.0.1"
git push
```

#### For Production (Play Store)
```bash
# 1. Clean build
C:\flutter\bin\flutter clean
C:\flutter\bin\flutter pub get

# 2. Build app bundle
C:\flutter\bin\flutter build appbundle --release

# 3. Upload to Play Console
# Location: build\app\outputs\bundle\release\app-release.aab
```

### Post-Deployment

#### Monitor
- [ ] Check Firebase Crashlytics
- [ ] Monitor performance metrics
- [ ] Review user feedback
- [ ] Check analytics data

#### Hotfix Process
```bash
# 1. Create hotfix branch
git checkout -b hotfix/issue-name

# 2. Fix issue
# 3. Test thoroughly
# 4. Update version (patch)
# 5. Build and deploy
# 6. Merge to main
git checkout main
git merge hotfix/issue-name
git push
```

---

## Troubleshooting

### Common Issues

#### Device Not Found
```bash
# Check connection
C:\flutter\bin\flutter devices

# Restart ADB
adb kill-server
adb start-server

# Re-authorize device
# Unplug and replug USB
```

#### Build Failures
```bash
# Clean everything
C:\flutter\bin\flutter clean
rm -rf build/
C:\flutter\bin\flutter pub get

# Clear Gradle cache (Android)
cd android
gradlew clean
cd ..
```

#### Hot Reload Not Working
```bash
# Restart app
# Press 'R' (capital R) for hot restart
# Or stop (q) and run again
```

#### Performance Issues
```bash
# Use release mode for testing
C:\flutter\bin\flutter run --release

# Enable performance overlay
# Press 'P' while app is running
```

---

## Quick Reference Card

### Your Device Info
- **Device**: Pixel 8a
- **Device ID**: 4B301JEKB11455
- **Platform**: Android 16 (API 36)

### Most Used Commands
```bash
# Run on your phone (debug)
C:\flutter\bin\flutter run -d 4B301JEKB11455

# Run on your phone (fast)
C:\flutter\bin\flutter run --release -d 4B301JEKB11455

# Check git status
git status

# Commit changes
git add .
git commit -m "feat: your message"
git push

# Build APK
C:\flutter\bin\flutter build apk --release

# Run tests
C:\flutter\bin\flutter test
```

### VS Code Shortcuts
- `Ctrl+Shift+P`: Command palette
- `F5`: Start debugging
- `Ctrl+F5`: Run without debugging
- `Ctrl+S`: Save (triggers hot reload)
- `Ctrl+Shift+F5`: Restart debugging

---

## Contact & Support

### Project Structure
```
Bragging_Rights/
├── bragging_rights_app/    # Flutter app
│   ├── lib/               # Source code
│   ├── test/              # Tests
│   └── build/             # Build outputs
├── firebase_integration_plan.md
├── global_checklist.md
├── RUN_INSTRUCTIONS.md
├── physical_device_setup.md
└── DEPLOYMENT_GUIDE.md    # This file
```

### Key Files to Know
- `pubspec.yaml` - Dependencies and version
- `lib/main.dart` - App entry point
- `lib/firebase_options.dart` - Firebase config
- `.gitignore` - Files excluded from git

---

*Last updated: 2025-08-23*
*Device tested: Pixel 8a (Android 16)*