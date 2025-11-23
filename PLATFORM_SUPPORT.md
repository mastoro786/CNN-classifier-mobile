# ⚠️ IMPORTANT: Platform Compatibility

## ❌ **TIDAK SUPPORT WEB/CHROME**

Aplikasi Audio Classifier ini **TIDAK BISA** dijalankan di Web Browser (Chrome/Edge) karena menggunakan dependency yang hanya support **mobile platform**:

### Dependency yang Tidak Support Web:
- ❌ `tflite_flutter` - TensorFlow Lite (Mobile only)
- ❌ `record` - Audio recording (Mobile only)
- ❌ `fftea` - FFT computation (Native mobile)
- ❌ `path_provider` - File system access (Limited web support)
- ❌ `permission_handler` - Runtime permissions (Mobile only)

---

## ✅ **SUPPORTED PLATFORMS**

### 1. Android (Recommended) ✅
- **Android Device** (API 21+ / Android 5.0+)
- **Android Emulator** (API 28+ recommended)

### 2. iOS ✅
- **iOS Device** (iOS 13+)
- **iOS Simulator** (iOS 13+)

---

## 🚀 **HOW TO RUN**

### Option A: Using Android Emulator

#### Step 1: Check Available Emulators
```bash
flutter emulators
```

**Output:**
```
2 available emulators:
Pixel_3a_API_33_x86_64 • Pixel 3a API 33 • Google • android
Pixel_3a_API_34_arm64  • Pixel 3a API 34 • Google • android
```

#### Step 2: Launch Emulator
```bash
# Launch emulator (pilih salah satu)
flutter emulators --launch Pixel_3a_API_33_x86_64

# Atau launch dari Android Studio:
# Tools > Device Manager > Play button di emulator
```

⏳ **Wait 30-60 seconds** for emulator to fully boot.

#### Step 3: Verify Device Connected
```bash
flutter devices
```

**Expected Output:**
```
Found 2 connected devices:
  sdk gphone64 x86 64 (mobile) • emulator-5554 • android-x86 • Android 13 (API 33)
  Chrome (web)                 • chrome        • web-javascript
```

#### Step 4: Run App!
```bash
# Run on Android emulator
flutter run

# Atau specify device jika ada multiple
flutter run -d emulator-5554
```

---

### Option B: Using Real Android Device

#### Step 1: Enable USB Debugging
1. Go to **Settings** > **About Phone**
2. Tap **Build Number** 7 times (Developer mode enabled)
3. Go back to **Settings** > **System** > **Developer Options**
4. Enable **USB Debugging**

#### Step 2: Connect via USB
1. Connect device via USB cable
2. Allow USB debugging when popup appears on phone
3. Select **File Transfer** mode (not just charging)

#### Step 3: Verify Connection
```bash
# Check ADB connection
adb devices

# Should show:
# List of devices attached
# ABC123XYZ    device
```

```bash
# Check Flutter devices
flutter devices

# Should show your device
```

#### Step 4: Run App!
```bash
flutter run
```

---

### Option C: Using iOS Simulator (Mac Only)

```bash
# List iOS simulators
xcrun simctl list devices

# Run on iOS
flutter run -d <device-id>
```

---

## 🐛 **TROUBLESHOOTING**

### Error: "No devices found"

**Solution 1: Start Emulator**
```bash
flutter emulators --launch Pixel_3a_API_33_x86_64
```

**Solution 2: Check ADB**
```bash
adb devices
# If nothing shows, restart ADB:
adb kill-server
adb start-server
```

**Solution 3: Restart Android Studio Emulator**
- Close all emulators
- Android Studio > Tools > Device Manager > Start emulator

---

### Error: "flutter run -d chrome" fails

**Explanation:**  
❌ **This is expected!** App tidak support web.

**Solution:**  
✅ Use Android/iOS device instead:
```bash
flutter run  # Auto-selects available mobile device
```

---

### Error: "Emulator not booting"

**Solution:**
1. Close emulator
2. Open Android Studio > Tools > Device Manager
3. Click **Cold Boot** on emulator
4. Wait 60-90 seconds

---

### Error: "Device not showing in flutter devices"

**Solution:**
```bash
# Restart Flutter daemon
flutter doctor

# Check again
flutter devices
```

---

## 📱 **RECOMMENDED SETUP**

### For Development:
✅ **Android Emulator** (Fastest iteration with Hot Reload)
- API 33 (Android 13) or higher
- x86_64 architecture (faster than ARM)
- 2GB RAM minimum

### For Testing:
✅ **Real Android Device** (Best for audio testing)
- Better microphone quality
- Real-world performance testing
- Actual runtime permissions

---

## ⚡ **QUICK COMMANDS**

```bash
# Check available options
flutter devices
flutter emulators

# Launch emulator
flutter emulators --launch <emulator-id>

# Run app (auto-select device)
flutter run

# Run with specific device
flutter run -d emulator-5554

# Build APK (no emulator needed)
flutter build apk --debug
flutter build apk --release

# Install APK manually
adb install build/app/outputs/flutter-apk/app-release.apk
```

---

## 📊 **Platform Support Matrix**

| Feature | Android | iOS | Web | Windows | Linux | macOS |
|---------|---------|-----|-----|---------|-------|-------|
| TFLite Model | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Audio Recording | ✅ | ✅ | ⚠️ | ⚠️ | ⚠️ | ⚠️ |
| Mel Spectrogram | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| Permissions | ✅ | ✅ | ❌ | ❌ | ❌ | ❌ |
| **FULL SUPPORT** | **✅** | **✅** | **❌** | **❌** | **❌** | **❌** |

---

## 💡 **WHY NO WEB SUPPORT?**

### Technical Limitations:

1. **TensorFlow Lite**
   - Flutter web doesn't support TFLite native libraries
   - Would need TensorFlow.js (different model format)

2. **Audio Recording**
   - Web audio API berbeda dari native
   - Browser security restrictions

3. **FFT Computation**
   - Requires native FFI (Foreign Function Interface)
   - Not available in JavaScript/Web

4. **File System**
   - Web has limited file system access
   - Different permission model

### Possible Future Solutions:
- 🔄 Use TensorFlow.js for web
- 🔄 Rewrite audio processing for Web Audio API
- 🔄 Create separate web version of app

**For now: Use Android/iOS only! ✅**

---

## ✅ **NEXT STEPS**

1. **Launch Android Emulator:**
   ```bash
   flutter emulators --launch Pixel_3a_API_33_x86_64
   ```

2. **Wait for boot** (30-60 seconds)

3. **Run app:**
   ```bash
   flutter run
   ```

4. **Test dengan recording audio!** 🎙️

---

**Platform:** Android/iOS ONLY  
**No Web Support:** By design (native dependencies)

Made with ❤️ for Mobile Mental Health Care
