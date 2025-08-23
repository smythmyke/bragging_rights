# Connect Physical Android Device to Flutter

## Step-by-Step Setup Guide

### 1. Enable Developer Mode on Your Android Phone

1. **Open Settings** on your Android device
2. **Go to "About Phone"** (usually at the bottom of Settings)
3. **Find "Build Number"** (might be under "Software Information")
4. **Tap "Build Number" 7 times** 
   - You'll see a message: "You are now a developer!"
5. **Go back to main Settings**
6. **Find "Developer Options"** (usually near "About Phone" or under "System")

### 2. Enable USB Debugging

In Developer Options:
1. **Toggle ON "Developer Options"** at the top
2. **Scroll down and find "USB Debugging"**
3. **Toggle ON "USB Debugging"**
4. **Toggle ON "Install via USB"** (if available)
5. **Toggle OFF "Verify apps over USB"** (optional, speeds up installation)

### 3. Connect Your Phone to Computer

1. **Use a good quality USB cable** (some cables are charge-only)
2. **Plug phone into your computer's USB port**
3. **On your phone, you'll see a popup:**
   - "Allow USB debugging?"
   - Check "Always allow from this computer"
   - Tap "Allow" or "OK"
4. **You might also see "USB Connection Mode":**
   - Select "File Transfer" or "MTP" mode
   - NOT "Charging only"

### 4. Verify Device Connection

Open a terminal and run:
```bash
C:/flutter/bin/flutter devices
```

You should see something like:
```
3 connected devices:
Samsung SM-G998B (mobile) • RFXXXXX • android-arm64 • Android 13 (API 33)
sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x64 • Android 14 (API 34)
Chrome (web) • chrome • web-javascript • Google Chrome 120.0.6099.130
```

### 5. Run App on Your Physical Device

```bash
cd bragging_rights_app
C:/flutter/bin/flutter run --release
```

Flutter will:
- Automatically detect your physical device
- If multiple devices are connected, it will ask you to choose
- Build and install the app on your phone

### 6. Select Specific Device (if multiple connected)

If you have both emulator and physical device connected:
```bash
# List devices first
C:/flutter/bin/flutter devices

# Run on specific device using its ID
C:/flutter/bin/flutter run --release -d DEVICEID

# Example:
C:/flutter/bin/flutter run --release -d RF8M40T
```

## Troubleshooting

### Device Not Showing Up?

1. **Try different USB cable** (many cables are charge-only)
2. **Try different USB port** (use USB 2.0 if USB 3.0 doesn't work)
3. **Check Windows Device Manager:**
   - Press Win+X, select Device Manager
   - Look for your phone under "Portable Devices" or "Android Device"
   - If yellow warning icon, update drivers

4. **Install/Update ADB drivers:**
   ```bash
   # Check if ADB sees your device
   adb devices
   ```
   If not listed, you may need:
   - Samsung: Install Samsung USB drivers
   - Google Pixel: Google USB drivers
   - Other: Universal ADB drivers

5. **Revoke and Re-authorize USB Debugging:**
   - On phone: Developer Options > Revoke USB debugging authorizations
   - Reconnect cable
   - Accept the new authorization prompt

### Common Issues and Fixes

| Problem | Solution |
|---------|----------|
| "Waiting for device" | Check USB debugging is ON |
| "Unauthorized device" | Accept USB debugging prompt on phone |
| "Device offline" | Unplug and replug USB cable |
| "No devices found" | Try different cable/port, check drivers |
| App crashes on launch | Run with `--debug` first time to see errors |

### Security Settings (if app won't install)

On your phone:
1. **Settings > Security**
2. **Enable "Unknown sources"** or **"Install unknown apps"**
3. For your file manager or Chrome, allow installation

### Performance Expectations

**Physical Device vs Emulator:**
- **3-5x faster** overall performance
- **Smooth 60 FPS** animations
- **Instant** screen transitions
- **Real** hardware acceleration
- **Actual** user experience

### Best Development Workflow

1. **Use emulator for quick testing** with hot reload:
   ```bash
   flutter run  # Debug mode with hot reload
   ```

2. **Use physical device for performance testing**:
   ```bash
   flutter run --release -d PHONEID
   ```

3. **Final testing before release**:
   ```bash
   flutter build apk --release
   # Then manually install APK on multiple devices
   ```

## Quick Commands Reference

```bash
# Check connected devices
C:/flutter/bin/flutter devices

# Run on physical device (release mode - fast)
C:/flutter/bin/flutter run --release

# Run on physical device (debug mode - with hot reload)
C:/flutter/bin/flutter run

# Run on specific device
C:/flutter/bin/flutter run -d DEVICEID

# Build APK for manual installation
C:/flutter/bin/flutter build apk --release
# APK location: build/app/outputs/flutter-apk/app-release.apk
```

## Wireless Debugging (Optional - Android 11+)

1. Connect phone via USB first
2. In Developer Options, enable "Wireless debugging"
3. Note the IP address and port
4. Run: `adb connect IPADDRESS:PORT`
5. Unplug USB cable
6. Now you can run Flutter wirelessly!

---
*Tip: Keep USB debugging OFF when not developing for security. Anyone with physical access to your phone could potentially access its data with USB debugging enabled.*