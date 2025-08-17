# Bragging Rights App - Run Instructions

## Prerequisites
- Flutter SDK installed at: `C:\flutter`
- Android Studio installed with emulators configured
- Chrome browser installed (for web development)

## Available Devices & Emulators

### Android Emulators
- **Bragging_Rights_Pixel6** - Google Pixel 6 emulator (recommended)
- **Medium_Phone_API_36** - Generic Android emulator

### Web Browsers
- Chrome (web)
- Edge (web)

### Desktop
- Windows (native desktop app)

## How to Run the App

### Method 1: Android Emulator (Recommended)

1. Navigate to the app directory:
   ```bash
   cd bragging_rights_app
   ```

2. Start the emulator:
   ```bash
   C:\flutter\bin\flutter emulators --launch Bragging_Rights_Pixel6
   ```

3. Wait for the emulator to fully boot (this may take 1-2 minutes)

4. Run the app:
   ```bash
   C:\flutter\bin\flutter run
   ```

### Method 2: Chrome Browser (Quick Testing)

1. Navigate to the app directory:
   ```bash
   cd bragging_rights_app
   ```

2. Run directly in Chrome:
   ```bash
   C:\flutter\bin\flutter run -d chrome
   ```

### Method 3: Edge Browser

1. Navigate to the app directory:
   ```bash
   cd bragging_rights_app
   ```

2. Run in Edge:
   ```bash
   C:\flutter\bin\flutter run -d edge
   ```

### Method 4: Windows Desktop App

1. Navigate to the app directory:
   ```bash
   cd bragging_rights_app
   ```

2. Run as Windows desktop application:
   ```bash
   C:\flutter\bin\flutter run -d windows
   ```

## Useful Commands

### List all available devices:
```bash
C:\flutter\bin\flutter devices
```

### List all available emulators:
```bash
C:\flutter\bin\flutter emulators
```

### Run with hot reload (development):
```bash
C:\flutter\bin\flutter run
```
Then press `r` for hot reload or `R` for hot restart while the app is running.

### Build for release:

**Android APK:**
```bash
C:\flutter\bin\flutter build apk
```

**Web:**
```bash
C:\flutter\bin\flutter build web
```

**Windows:**
```bash
C:\flutter\bin\flutter build windows
```

### Clean build files (if you encounter issues):
```bash
C:\flutter\bin\flutter clean
C:\flutter\bin\flutter pub get
```

## Troubleshooting

### If emulator is not detected:
1. Make sure Android Studio is running
2. Open AVD Manager in Android Studio
3. Start the emulator manually
4. Run `C:\flutter\bin\flutter devices` to verify it's detected

### If web platforms are not available:
The platforms have already been added. If you need to recreate them:
```bash
C:\flutter\bin\flutter create . --platforms=web,windows
```

### For any Flutter issues:
```bash
C:\flutter\bin\flutter doctor -v
```

## Quick Start (Copy & Paste)

For the fastest way to run the app, copy and paste these commands:

**Option A - Android Emulator:**
```bash
cd bragging_rights_app
C:\flutter\bin\flutter emulators --launch Bragging_Rights_Pixel6
C:\flutter\bin\flutter run
```

**Option B - Chrome Browser:**
```bash
cd bragging_rights_app
C:\flutter\bin\flutter run -d chrome
```