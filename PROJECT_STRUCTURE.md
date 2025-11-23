# 🏗️ PROJECT STRUCTURE

```
Flutter_CNN/
│
├── 📱 lib/                          # Source code
│   ├── main.dart                    # App entry point
│   │
│   ├── 📺 screens/
│   │   └── classifier_screen.dart   # Main classification UI
│   │
│   ├── 🎨 widgets/
│   │   ├── gradient_header.dart     # Beautiful app header
│   │   ├── recording_button.dart    # Animated record button
│   │   └── result_card.dart         # Results display
│   │
│   ├── ⚙️ services/
│   │   ├── audio_processor.dart     # Mel Spectrogram extraction
│   │   ├── classifier_service.dart  # TFLite AI inference
│   │   └── audio_recording_service.dart  # Microphone recording
│   │
│   ├── 🔄 providers/
│   │   └── audio_provider.dart      # State management
│   │
│   ├── 🛠️ utils/                    # Utility functions (empty)
│   └── 📊 models/                   # Data models (empty)
│
├── 🗂️ assets/
│   └── models/
│       ├── audio_classifier_quantized.tflite  # AI Model (1.3 MB)
│       ├── audio_classifier.tflite            # Full model (5 MB)
│       └── label_map.txt                      # Class labels
│
├── 🤖 android/                      # Android config
│   └── app/src/main/
│       └── AndroidManifest.xml      # Permissions configured
│
├── 🍎 ios/                          # iOS config
│   └── Runner/
│       └── Info.plist               # Permissions configured
│
├── 📄 context/
│   └── FLUTTER_MOBILE_GUIDE.md      # Development guide
│
├── 🧠 model/
│   └── mobile/                      # Source models
│
├── 📝 Documentation
│   ├── README.md                    # Project overview
│   ├── CHECKLIST.md                 # Development checklist
│   └── PROJECT_STRUCTURE.md         # This file
│
└── ⚙️ Configuration
    ├── pubspec.yaml                 # Dependencies
    ├── analysis_options.yaml        # Linting rules
    └── .gitignore                   # Git ignore rules

```

## 📊 Data Flow

```
┌─────────────────────────────────────────────────────┐
│                   USER INTERACTION                   │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│           classifier_screen.dart (UI)                │
│  ┌──────────────┐  ┌──────────────┐  ┌───────────┐ │
│  │ Header       │  │ Record Btn   │  │ Result   │ │
│  │ Widget       │  │ Widget       │  │ Card     │ │
│  └──────────────┘  └──────────────┘  └───────────┘ │
└──────────────────┬──────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────┐
│         audio_provider.dart (State)                  │
│  • isRecording                                       │
│  • isProcessing                                      │
│  • result                                            │
└──────────────────┬──────────────────────────────────┘
                   │
          ┌────────┴────────┐
          ▼                 ▼
┌──────────────────┐  ┌──────────────────────┐
│ Recording Service│  │  Classifier Service  │
│                  │  │                      │
│ • Start/Stop    │  │ • Load Model         │
│ • WAV Convert   │  │ • Extract Features   │
│                  │  │ • Run Inference      │
└────────┬─────────┘  └────────┬─────────────┘
         │                     │
         ▼                     ▼
┌─────────────────┐   ┌─────────────────────┐
│ Float32List     │──▶│ Audio Processor     │
│ (Audio Samples) │   │ • STFT              │
└─────────────────┘   │ • Mel Filterbank    │
                      │ • Normalization     │
                      └────────┬────────────┘
                               │
                               ▼
                      ┌─────────────────────┐
                      │ Mel Spectrogram     │
                      │ (128 x 216)         │
                      └────────┬────────────┘
                               │
                               ▼
                      ┌─────────────────────┐
                      │ TFLite Model        │
                      │ (Quantized CNN)     │
                      └────────┬────────────┘
                               │
                               ▼
                      ┌─────────────────────┐
                      │ Classification      │
                      │ Result              │
                      │ • Class             │
                      │ • Confidence        │
                      │ • Probabilities     │
                      └─────────────────────┘
```

## 🎨 Widget Tree

```
MaterialApp
└── ClassifierScreen
    ├── AppBar (Purple Gradient)
    └── Body
        ├── GradientHeader
        │   ├── Icon (Hearing)
        │   ├── Title
        │   └── Subtitle
        │
        ├── RecordingButton (Animated)
        │   ├── Icon (Mic/Stop)
        │   ├── Text (State-based)
        │   └── Pulse Animation
        │
        └── ResultCard (Conditional)
            ├── Header (Gradient)
            │   ├── Title
            │   └── Confidence Badge
            │
            └── Content
                ├── Circular Gauge
                │   ├── Percentage
                │   └── Class Name
                │
                ├── Probability Bars
                │   ├── Normal Bar
                │   └── Skizofrenia Bar
                │
                └── Inference Time
```

## 🔧 Service Dependencies

```
ClassifierService
├── Depends on:
│   ├── tflite_flutter (AI inference)
│   └── AudioProcessor (feature extraction)
│
└── Used by:
    └── ClassifierScreen

AudioProcessor
├── Depends on:
│   └── fftea (FFT computation)
│
└── Used by:
    └── ClassifierService

AudioRecordingService
├── Depends on:
│   ├── record (audio recording)
│   ├── permission_handler (permissions)
│   └── path_provider (file paths)
│
└── Used by:
    └── AudioProvider

AudioProvider
├── Depends on:
│   └── AudioRecordingService
│
└── Provides state to:
    └── ClassifierScreen
```

## 📦 Package Dependencies

### Core Dependencies
- **flutter**: SDK
- **provider**: State management

### AI & Processing
- **tflite_flutter**: TensorFlow Lite inference
- **fftea**: Fast Fourier Transform

### Audio
- **record**: Audio recording
- **audio_waveforms**: Waveform visualization

### System
- **permission_handler**: Runtime permissions
- **path_provider**: File system paths
- **shared_preferences**: Local storage

### UI
- **fl_chart**: Charts and graphs
- **percent_indicator**: Circular progress
- **intl**: Internationalization

## 📱 Screens Map

```
App Launch
    ↓
[Splash Screen] (Optional)
    ↓
[Classifier Screen]
    │
    ├─→ [Recording Dialog] (5 second countdown)
    │
    ├─→ [Processing Dialog] (Loading)
    │
    └─→ [Result Section] (Inline display)
```

## 🎯 Key Features

1. **Offline Processing** - No internet required
2. **Real-time Recording** - 5-second audio capture
3. **AI Classification** - CNN model inference
4. **Beautiful UI** - Material 3 design
5. **State Management** - Provider pattern
6. **Cross Platform** - Android & iOS

## 🔐 Permissions Flow

```
App Start
    ↓
Check Microphone Permission
    │
    ├─→ [Granted] → Ready to Record
    │
    └─→ [Denied] → Request Permission
            │
            ├─→ [Granted] → Ready to Record
            │
            └─→ [Denied] → Show Error
```

---

**Total Files**: 16 Dart files + Configuration  
**Total Lines**: ~1,800 lines of code  
**Model Size**: 1.3 MB (quantized)  
**Target Platforms**: Android, iOS

---

Made with ❤️ for Mental Health Care
