# Bragging Rights - Development Environment Setup Guide

## System Requirements

### Minimum Hardware Requirements
- **CPU**: Intel i5 or AMD equivalent (4+ cores recommended)
- **RAM**: 8GB minimum (16GB recommended for smooth emulator performance)
- **Storage**: 50GB free space minimum
  - Android Studio: ~10GB
  - Android SDK & Emulator images: ~15GB
  - Flutter SDK: ~2GB
  - Project files & dependencies: ~5GB
  - Build cache: ~10GB
- **Graphics**: DirectX 11 or OpenGL 2.0 support

### Operating System
- **Windows**: Windows 10 64-bit or Windows 11
- **macOS**: macOS 10.14 (Mojave) or later (for iOS development)
- **Linux**: Ubuntu 20.04 LTS or later (Android only)

---

## Windows Development Setup (Your Environment)

### Step 1: Install Flutter SDK
1. **Download Flutter**
   - Visit: https://flutter.dev/docs/get-started/install/windows
   - Download the latest stable release ZIP
   - Extract to `C:\flutter` (avoid spaces in path)

2. **Add Flutter to PATH**
   - Open Environment Variables (Windows key + search "env")
   - Add `C:\flutter\bin` to System PATH
   - Restart terminal/VS Code

3. **Verify Installation**
   ```bash
   flutter --version
   flutter doctor
   ```

### Step 2: Install Android Studio
1. **Download Android Studio**
   - Visit: https://developer.android.com/studio
   - Download Windows installer (1GB+)
   - Run installer with default settings

2. **During Installation, Select**:
   - Android SDK
   - Android SDK Platform-Tools
   - Android Virtual Device (AVD)

3. **Post-Installation Setup**
   - Launch Android Studio
   - Go to SDK Manager (Configure → SDK Manager)
   - Install:
     - Android SDK Command-line Tools
     - Android SDK Build-Tools
     - Android 13.0 (API 33) or latest
     - Google Play Services
     - Intel x86 Emulator Accelerator (HAXM)

### Step 3: Configure Android Emulator
1. **Enable Virtualization in BIOS**
   - Restart computer
   - Enter BIOS (usually F2, F10, or Del during boot)
   - Enable: Intel VT-x or AMD-V
   - Save and exit

2. **Create Virtual Device**
   - Open Android Studio
   - Tools → AVD Manager
   - Create Virtual Device
   - Select: Pixel 6 (good balance of features)
   - System Image: Android 13 (API 33) with Google Play
   - RAM: 2GB minimum (4GB if you have 16GB+ system RAM)
   - Enable "Hardware - GLES 2.0" for graphics

3. **Optimize Emulator Performance**
   - Enable "Cold Boot" snapshot
   - Use x86_64 images (not ARM)
   - Allocate dedicated GPU if available

### Step 4: Install VS Code & Extensions
1. **Download VS Code**
   - Visit: https://code.visualstudio.com
   - Install 64-bit Windows version

2. **Essential Extensions**
   ```
   - Flutter (Dart-Code.flutter)
   - Dart (Dart-Code.dart-code)
   - Firebase (toba.vsfire)
   - GitLens (eamodio.gitlens)
   - Thunder Client (rangav.vscode-thunder-client) - API testing
   - Error Lens (usernamehw.errorlens)
   ```

3. **VS Code Settings for Flutter**
   ```json
   {
     "dart.flutterSdkPath": "C:\\flutter",
     "dart.openDevTools": "flutter",
     "editor.formatOnSave": true,
     "dart.lineLength": 120,
     "files.autoSave": "onFocusChange"
   }
   ```

### Step 5: Additional Tools
1. **Git for Windows**
   - Download: https://git-scm.com/download/win
   - Use Git Bash terminal

2. **Node.js (for backend)**
   - Download: https://nodejs.org (LTS version)
   - Verify: `node --version` and `npm --version`

3. **Firebase CLI**
   ```bash
   npm install -g firebase-tools
   firebase login
   ```

4. **Chrome Browser**
   - Required for Flutter web debugging
   - Download if not installed

---

## iOS Development Setup (macOS Only)

### Requirements
- **Mac hardware**: Any Mac from 2015 or later
- **macOS**: 10.14 (Mojave) minimum
- **Storage**: 20GB+ for Xcode

### Installation Steps
1. **Install Xcode**
   ```bash
   # From App Store (8GB+ download)
   # Or via command line:
   xcode-select --install
   ```

2. **Configure Xcode**
   - Open Xcode
   - Preferences → Locations
   - Select Command Line Tools version

3. **Set up iOS Simulator**
   - Xcode → Open Developer Tool → Simulator
   - Hardware → Device → iOS 16.x → iPhone 14

4. **CocoaPods Installation**
   ```bash
   sudo gem install cocoapods
   pod setup
   ```

---

## Verify Complete Setup

### Run Flutter Doctor
```bash
flutter doctor -v
```

Expected output:
```
[✓] Flutter (Channel stable, 3.x.x)
[✓] Android toolchain - develop for Android devices
[✓] Chrome - develop for the web
[✓] Visual Studio - develop for Windows (optional)
[✓] Android Studio
[✓] VS Code
[✓] Connected device (1 available)
```

### Test Flutter App
```bash
# Create test app
flutter create test_app
cd test_app

# Run on Android Emulator
flutter run

# List available devices
flutter devices
```

---

## Common Issues & Solutions

### Issue 1: Android Emulator Won't Start
**Solution**:
- Check BIOS virtualization is enabled
- Disable Hyper-V: `bcdedit /set hypervisorlaunchtype off`
- Restart computer
- Try WHPX instead of HAXM on Windows 11

### Issue 2: Flutter Doctor Shows Red X
**Solution**:
- Run `flutter doctor --android-licenses`
- Accept all licenses
- Reinstall Android SDK if needed

### Issue 3: Slow Emulator Performance
**Solution**:
- Increase RAM allocation
- Enable GPU acceleration
- Use x86_64 images
- Close unnecessary applications
- Consider using physical device

### Issue 4: "Unable to locate Android SDK"
**Solution**:
```bash
flutter config --android-sdk C:\Users\[username]\AppData\Local\Android\Sdk
```

---

## Performance Tips

### For Android Emulator
1. **Use Snapshots**: Save emulator state for faster startup
2. **Quick Boot**: Enable in AVD settings
3. **Multi-core CPU**: Assign 2-4 cores to emulator
4. **Dedicated Graphics**: Use discrete GPU if available

### For Development
1. **Hot Reload**: Use `r` in terminal for instant UI updates
2. **Hot Restart**: Use `R` for state reset
3. **DevTools**: Access via `flutter pub global activate devtools`
4. **Physical Device**: Consider USB debugging for better performance

---

## Alternative: Physical Device Testing

### Android Device
1. Enable Developer Options (tap Build Number 7 times)
2. Enable USB Debugging
3. Connect via USB
4. Run `flutter devices` to verify

### iOS Device (requires Apple Developer Account)
1. Connect iPhone via USB
2. Trust computer on device
3. Open Xcode → Window → Devices
4. Add device to provisioning profile

---

## Project-Specific Setup

### For Bragging Rights App
```bash
# Clone repository (when available)
git clone [repository-url]
cd bragging-rights

# Install dependencies
flutter pub get

# Set up Firebase
flutterfire configure

# Run the app
flutter run
```

### Environment Files
Create `.env` file in project root:
```
SPORTS_API_KEY=your_api_key_here
FIREBASE_PROJECT_ID=bragging-rights-prod
GIPHY_API_KEY=your_giphy_key
```

---

## Recommended VS Code Workspace

### Launch Configuration (.vscode/launch.json)
```json
{
  "version": "0.2.0",
  "configurations": [
    {
      "name": "Flutter Debug",
      "request": "launch",
      "type": "dart",
      "flutterMode": "debug"
    },
    {
      "name": "Flutter Profile",
      "request": "launch",
      "type": "dart",
      "flutterMode": "profile"
    },
    {
      "name": "Flutter Release",
      "request": "launch",
      "type": "dart",
      "flutterMode": "release"
    }
  ]
}
```

---

## Next Steps
1. ✅ Complete all installations
2. ✅ Run `flutter doctor` and fix any issues
3. ✅ Create and run test Flutter app
4. ✅ Set up Firebase project
5. 🚀 Ready to start Bragging Rights development!