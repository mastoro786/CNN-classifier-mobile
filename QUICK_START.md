# ⚡ QUICK START GUIDE

## 🎯 Goal
Menjalankan aplikasi Audio Classifier Flutter untuk klasifikasi gangguan jiwa secara offline.

---

## 📋 Prerequisites

✅ Flutter SDK 3.0+ sudah terinstall  
✅ Android Studio / VS Code  
✅ Android Device dengan USB Debugging enabled ATAU Android Emulator  

---

## 🚀 Langkah-langkah (5 Menit Setup)

### 1️⃣ Enable Developer Mode (Windows) ⚠️ PENTING!

```powershell
# Run di PowerShell as Administrator
start ms-settings:developers
```

**Aktifkan "Developer Mode"** di Windows Settings yang terbuka.

> **Kenapa?** Flutter membutuhkan symlink support untuk plugin development.

---

### 2️⃣ Clean & Install Dependencies

```bash
# Bersihkan cache (opsional tapi recommended)
flutter clean

# Install semua dependencies
flutter pub get
```

**Expected Output:**
```
✓ Downloaded packages (9.4s)
Changed 4 dependencies!
```

---

### 3️⃣ Connect Device atau Start Emulator

#### Option A: Using Real Android Device
1. Connect device via USB
2. Enable **USB Debugging** di Developer Options
3. Trust computer ketika popup muncul

#### Option B: Using Android Emulator
```bash
# Buka Android Studio
# Tools > Device Manager > Create/Start Emulator
```

---

### 4️⃣ Verify Device Connected

```bash
flutter devices
```

**Expected Output:**
```
2 connected devices:

Android SDK built for x86 (mobile) • emulator-5554 • android-x86 • Android 13 (API 33)
Chrome (web)                       • chrome        • web-javascript
```

---

### 5️⃣ Run App! 🎉

```bash
flutter run
```

**First Time Setup** akan memakan waktu 2-5 menit untuk:
- Download dependencies
- Build Gradle
- Install APK ke device

**Subsequent runs** hanya ~30 detik (Hot Reload).

---

## 🎮 How to Use App

### Step 1: Launch App
- App akan load AI model (~1-2 detik)
- Lihat "Loading AI Model..." loading screen

### Step 2: Grant Permission
- **Pertama kali** app akan request **Microphone Permission**
- Tap **"Allow"**

### Step 3: Record Audio
1. Tap **"Start Recording"** button
2. Dialog countdown muncul (5 detik)
3. Speak atau play audio sample
4. Recording akan stop otomatis setelah 5 detik

### Step 4: Processing
- Loading dialog muncul: "Analyzing audio..."
- AI sedang extract features dan run inference
- Tunggu ~1-2 detik

### Step 5: View Results
- **Result card** muncul dengan:
  - ✅ Circular gauge dengan confidence percentage
  - ✅ Class prediction (NORMAL atau SKIZOFRENIA)
  - ✅ Probability bars untuk kedua class
  - ✅ Processing time (ms)

### Step 6: Record Again (Optional)
- Tap **"Start Recording"** lagi untuk classify audio baru

---

## 🎨 Expected UI

### Main Screen
```
┌─────────────────────────────────┐
│  ╔═══════════════════════════╗  │
│  ║   Purple Gradient Header  ║  │
│  ║   🔊 Icon                 ║  │
│  ║   Klasifikasi Gangguan    ║  │
│  ║   Jiwa                    ║  │
│  ╚═══════════════════════════╝  │
│                                 │
│  ┌───────────────────────────┐  │
│  │  🎙️ START RECORDING      │  │ ← Animated Button
│  └───────────────────────────┘  │
│                                 │
│  ┌───────────────────────────┐  │
│  │   HASIL ANALISIS          │  │
│  │                           │  │
│  │      ⭕ 87.5%            │  │ ← Gauge Chart
│  │       NORMAL              │  │
│  │                           │  │
│  │   ▓▓▓▓▓▓▓▓▓░ Normal 87%   │  │ ← Progress Bars
│  │   ▓░░░░░░░░░ Skizofrenia │  │
│  │                           │  │
│  │   ⚡ Processing: 650ms   │  │
│  └───────────────────────────┘  │
└─────────────────────────────────┘
```

---

## 🐛 Troubleshooting

### Problem: "Developer Mode" warning
**Solution:**
```bash
start ms-settings:developers
```
Enable Developer Mode di Settings.

---

### Problem: No devices found
**Solution:**
```bash
# Check USB connection
adb devices

# Start emulator
emulator -avd Pixel_3a_API_33_x86_64
```

---

### Problem: Build fails dengan "Gradle error"
**Solution:**
```bash
cd android
./gradlew clean
cd ..
flutter clean
flutter pub get
```

---

### Problem: "Model not found"
**Verify:**
```bash
# Check if model exists
ls assets/models/

# Should show:
# audio_classifier_quantized.tflite
# label_map.txt
```

**Solution:**
```bash
# Re-copy model
Copy-Item "model\mobile\*" -Destination "assets\models\" -Force
```

---

### Problem: Permission denied (microphone)
**Solution:**
- Android: Settings > Apps > Audio Classifier > Permissions > Microphone > Allow
- Or reinstall app

---

### Problem: App crashes on record
**Check logs:**
```bash
flutter logs
```

**Common causes:**
1. Microphone permission not granted
2. Device microphone issue
3. Audio format incompatibility

---

## 📊 Expected Performance

| Metric | Value |
|--------|-------|
| **Model Loading** | 200-300ms |
| **Recording Duration** | 5 seconds (fixed) |
| **Feature Extraction** | 300-500ms |
| **Inference Time** | 100-300ms |
| **Total Processing** | < 1 second |
| **App Size** | ~15 MB (debug), ~8 MB (release) |

---

## 🎯 Success Indicators

✅ App launches without errors  
✅ Model loads successfully  
✅ Microphone permission granted  
✅ 5-second recording completes  
✅ Processing completes dalam <2 detik  
✅ Result card shows classification  
✅ Confidence percentage displayed  
✅ Probability bars render correctly  

---

## 🔄 Development Workflow

### Hot Reload (during development)
```bash
# After making code changes, press 'r' in terminal
r
```

### Hot Restart (for state reset)
```bash
# Press 'R' in terminal
R
```

### Quit
```bash
# Press 'q' in terminal
q
```

---

## 📦 Build APK for Distribution

### Debug APK (for testing)
```bash
flutter build apk --debug
```
**Output:** `build/app/outputs/flutter-apk/app-debug.apk` (~30 MB)

### Release APK (production)
```bash
flutter build apk --release
```
**Output:** `build/app/outputs/flutter-apk/app-release.apk` (~8 MB)

### Install APK
```bash
# Via ADB
adb install build/app/outputs/flutter-apk/app-release.apk

# Or copy APK to device and install manually
```

---

## 💡 Pro Tips

1. **Use Real Device** untuk audio recording yang lebih baik
2. **Quiet Environment** saat recording untuk hasil optimal
3. **Release Build** jauh lebih cepat dari Debug
4. **Hot Reload** untuk quick UI changes
5. **Check Logs** (`flutter logs`) jika ada error

---

## 🎓 Next Steps

1. ✅ Run app successfully
2. 🔄 Test dengan berbagai audio samples
3. 🔄 Validate accuracy dengan clinical data
4. 🔄 Collect feedback dari user
5. 🔄 Optimize performance jika perlu
6. 🔄 Add additional features (history, export, dll)

---

## 📞 Support

Jika ada issues:
1. Check **CHECKLIST.md** untuk troubleshooting
2. Read **README.md** untuk detail lengkap
3. Review **PROJECT_STRUCTURE.md** untuk architecture
4. Check **context/FLUTTER_MOBILE_GUIDE.md** untuk development guide

---

**Ready to Start? Run:**
```bash
flutter run
```

**Selamat Menggunakan! 🎉**

---

Made with ❤️ for RSJD dr. Amino Gondohutomo
