# 📱 Flutter Mobile App Development Guide
## Offline Audio Classification for Schizophrenia Detection

**Comprehensive guide untuk mengintegrasikan CNN model ke aplikasi Flutter mobile**

---

## 📋 Table of Contents

1. [Overview & Architecture](#overview--architecture)
2. [Prerequisites](#prerequisites)
3. [Model Conversion (TensorFlow Lite)](#model-conversion-tensorflow-lite)
4. [Flutter Project Setup](#flutter-project-setup)
5. [Audio Processing Implementation](#audio-processing-implementation)
6. [Model Integration](#model-integration)
7. [UI/UX Implementation](#uiux-implementation)
8. [Testing & Optimization](#testing--optimization)
9. [Deployment](#deployment)
10. [Troubleshooting](#troubleshooting)

---

## 🏗️ Overview & Architecture

### System Architecture

```
┌─────────────────────────────────────────────────────┐
│              FLUTTER MOBILE APP                      │
│  ┌───────────────────────────────────────────────┐  │
│  │         UI Layer (Material/Cupertino)         │  │
│  └──────────────────┬────────────────────────────┘  │
│                     │                                │
│  ┌──────────────────▼────────────────────────────┐  │
│  │      Audio Recording & Processing             │  │
│  │  - Record audio from microphone               │  │
│  │  - Convert to WAV format                      │  │
│  │  - Extract Mel Spectrogram features           │  │
│  └──────────────────┬────────────────────────────┘  │
│                     │                                │
│  ┌──────────────────▼────────────────────────────┐  │
│  │      TensorFlow Lite Inference                │  │
│  │  - Load .tflite model                         │  │
│  │  - Run prediction (OFFLINE)                   │  │
│  │  - Get probability scores                     │  │
│  └──────────────────┬────────────────────────────┘  │
│                     │                                │
│  ┌──────────────────▼────────────────────────────┐  │
│  │      Results Display                          │  │
│  │  - Show prediction (Normal/Skizofrenia)       │  │
│  │  - Display confidence score                   │  │
│  │  - Visualize audio waveform                   │  │
│  └───────────────────────────────────────────────┘  │
└─────────────────────────────────────────────────────┘
```

### Tech Stack

- **Flutter SDK**: 3.16+ (Dart 3.2+)
- **TensorFlow Lite**: 2.20.0
- **Audio Processing**: FFmpeg, Librosa equivalent
- **Platforms**: Android (API 21+), iOS (13+)

---

## ✅ Prerequisites

### Development Environment

```bash
# Check Flutter installation
flutter doctor

# Required tools
- Flutter SDK 3.16+
- Android Studio / VS Code
- Python 3.8+ (for model conversion)
- TensorFlow 2.20+
```

### Required Skills

- ✅ Dart programming
- ✅ Flutter widget system
- ✅ Basic audio processing concepts
- ✅ State management (Provider/Riverpod/Bloc)

---

## 🔄 Model Conversion (TensorFlow Lite)

### Step 1: Convert Keras Model to TFLite

Create file: `convert_to_tflite.py`

```python
"""
Script untuk convert model Keras (.h5) ke TensorFlow Lite (.tflite)
Optimized untuk mobile deployment
"""

import tensorflow as tf
import numpy as np

# --- CONFIGURATION ---
MODEL_PATH = "models/best_model.h5"
TFLITE_MODEL_PATH = "models/audio_classifier.tflite"
QUANTIZED_MODEL_PATH = "models/audio_classifier_quantized.tflite"

def convert_to_tflite(model_path, output_path, quantize=False):
    """
    Convert Keras model to TensorFlow Lite
    
    Args:
        model_path: Path to .h5 model
        output_path: Path to save .tflite model
        quantize: Enable quantization for smaller model size
    """
    print(f"\n{'='*60}")
    print("CONVERTING MODEL TO TENSORFLOW LITE")
    print(f"{'='*60}\n")
    
    # Load Keras model
    print("📂 Loading Keras model...")
    model = tf.keras.models.load_model(model_path)
    model.summary()
    
    # Create converter
    converter = tf.lite.TFLiteConverter.from_keras_model(model)
    
    if quantize:
        print("\n⚙️  Enabling quantization (smaller size, slightly lower accuracy)...")
        # Dynamic range quantization
        converter.optimizations = [tf.lite.Optimize.DEFAULT]
        
        # Optional: Full integer quantization (requires representative dataset)
        # converter.target_spec.supported_types = [tf.float16]
    else:
        print("\n⚙️  Converting without quantization (full precision)...")
    
    # Set optimization flags
    converter.target_spec.supported_ops = [
        tf.lite.OpsSet.TFLITE_BUILTINS,  # Enable TensorFlow Lite ops
        tf.lite.OpsSet.SELECT_TF_OPS     # Enable TensorFlow ops
    ]
    
    # Convert model
    print("🔄 Converting model...")
    tflite_model = converter.convert()
    
    # Save model
    with open(output_path, 'wb') as f:
        f.write(tflite_model)
    
    # Get file size
    import os
    size_mb = os.path.getsize(output_path) / (1024 * 1024)
    
    print(f"\n✅ Model converted successfully!")
    print(f"📁 Saved to: {output_path}")
    print(f"📊 Size: {size_mb:.2f} MB")
    
    return output_path

def test_tflite_model(tflite_path, input_shape=(1, 128, 216, 1)):
    """
    Test TFLite model with random input
    """
    print(f"\n{'='*60}")
    print("TESTING TFLITE MODEL")
    print(f"{'='*60}\n")
    
    # Load TFLite model
    interpreter = tf.lite.Interpreter(model_path=tflite_path)
    interpreter.allocate_tensors()
    
    # Get input and output details
    input_details = interpreter.get_input_details()
    output_details = interpreter.get_output_details()
    
    print("📊 Model Details:")
    print(f"  Input shape: {input_details[0]['shape']}")
    print(f"  Input type: {input_details[0]['dtype']}")
    print(f"  Output shape: {output_details[0]['shape']}")
    print(f"  Output type: {output_details[0]['dtype']}")
    
    # Test with random data
    print("\n🧪 Testing with random input...")
    test_input = np.random.randn(*input_shape).astype(np.float32)
    interpreter.set_tensor(input_details[0]['index'], test_input)
    
    # Run inference
    interpreter.invoke()
    
    # Get output
    output = interpreter.get_tensor(output_details[0]['index'])
    print(f"\n✅ Inference successful!")
    print(f"  Output: {output}")
    print(f"  Output shape: {output.shape}")
    
    return True

if __name__ == "__main__":
    
    # 1. Convert normal model (full precision)
    print("\n" + "="*60)
    print("STEP 1: Converting to TFLite (Full Precision)")
    print("="*60)
    tflite_path = convert_to_tflite(MODEL_PATH, TFLITE_MODEL_PATH, quantize=False)
    test_tflite_model(tflite_path)
    
    # 2. Convert quantized model (smaller size)
    print("\n" + "="*60)
    print("STEP 2: Converting to TFLite (Quantized)")
    print("="*60)
    quantized_path = convert_to_tflite(MODEL_PATH, QUANTIZED_MODEL_PATH, quantize=True)
    test_tflite_model(quantized_path)
    
    print("\n" + "="*60)
    print("✅ CONVERSION COMPLETE!")
    print("="*60)
    print(f"\n📱 Use in Flutter:")
    print(f"  - Full precision: {TFLITE_MODEL_PATH}")
    print(f"  - Quantized: {QUANTIZED_MODEL_PATH}")
    print(f"\n💡 Recommendation: Use quantized model for mobile apps (smaller size)")
    print("="*60)
```

### Step 2: Run Conversion

```bash
# Convert model
python convert_to_tflite.py

# Output files:
# - audio_classifier.tflite (~15-20 MB)
# - audio_classifier_quantized.tflite (~4-6 MB) <- Use this for mobile!
```

### Expected Output

```
Conversion Results:
✅ audio_classifier.tflite - 15.2 MB (Full precision)
✅ audio_classifier_quantized.tflite - 4.8 MB (Quantized)

Recommendation: Use quantized version for mobile deployment
```

---

## 📱 Flutter Project Setup

### Step 1: Create Flutter Project

```bash
# Create new Flutter project
flutter create audio_classifier_app
cd audio_classifier_app

# Test run
flutter run
```

### Step 2: Add Dependencies

Edit `pubspec.yaml`:

```yaml
name: audio_classifier_app
description: Offline audio classification for schizophrenia detection
publish_to: 'none'
version: 1.0.0+1

environment:
  sdk: '>=3.2.0 <4.0.0'

dependencies:
  flutter:
    sdk: flutter
  
  # State Management
  provider: ^6.1.1
  
  # TensorFlow Lite
  tflite_flutter: ^0.10.4
  tflite_flutter_helper: ^0.3.1
  
  # Audio Recording & Processing
  record: ^5.0.4
  path_provider: ^2.1.1
  permission_handler: ^11.1.0
  
  # Audio Analysis (FFI based)
  fft: ^2.0.1
  
  # UI Components
  fl_chart: ^0.65.0
  percent_indicator: ^4.2.3
  audio_waveforms: ^1.0.5
  
  # Utilities
  intl: ^0.19.0
  shared_preferences: ^2.2.2

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^3.0.1

flutter:
  uses-material-design: true
  
  # Add your .tflite model here
  assets:
    - assets/models/audio_classifier_quantized.tflite
    - assets/models/label_map.txt
```

### Step 3: Install Dependencies

```bash
flutter pub get
```

### Step 4: Setup Assets

```bash
# Create directories
mkdir -p assets/models

# Copy TFLite model
cp ../models/audio_classifier_quantized.tflite assets/models/

# Create label map
echo "normal
skizofrenia" > assets/models/label_map.txt
```

### Step 5: Configure Permissions

**Android**: Edit `android/app/src/main/AndroidManifest.xml`

```xml
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    
    <!-- Permissions -->
    <uses-permission android:name="android.permission.RECORD_AUDIO" />
    <uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" />
    <uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" />
    
    <application
        android:label="Audio Classifier"
        android:icon="@mipmap/ic_launcher">
        <!-- Your app configuration -->
    </application>
</manifest>
```

**iOS**: Edit `ios/Runner/Info.plist`

```xml
<dict>
    <!-- Add these keys -->
    <key>NSMicrophoneUsageDescription</key>
    <string>This app needs microphone access to record audio for analysis</string>
    
    <key>UIBackgroundModes</key>
    <array>
        <string>audio</string>
    </array>
</dict>
```

---

## 🎙️ Audio Processing Implementation

### File: `lib/services/audio_processor.dart`

```dart
import 'dart:typed_data';
import 'dart:math';
import 'package:fft/fft.dart';

class AudioProcessor {
  // Configuration matching Python preprocessing
  static const int sampleRate = 22050;
  static const int nMels = 128;
  static const int maxLen = 216;
  static const int fftSize = 2048;
  static const int hopLength = 512;
  static const int fMax = 8000;
  
  /// Extract Mel Spectrogram from audio samples
  /// This should match the preprocessing done in Python
  static Future<List<List<double>>> extractMelSpectrogram(
    Float32List audioSamples,
  ) async {
    print('📊 Extracting Mel Spectrogram...');
    print('   Sample rate: $sampleRate Hz');
    print('   Audio length: ${audioSamples.length} samples');
    
    // 1. STFT (Short-Time Fourier Transform)
    List<List<double>> stft = await _computeSTFT(audioSamples);
    print('   STFT shape: ${stft.length} x ${stft[0].length}');
    
    // 2. Convert to Mel scale
    List<List<double>> melSpec = _applyMelFilterbank(stft);
    print('   Mel spec shape: ${melSpec.length} x ${melSpec[0].length}');
    
    // 3. Convert to dB scale
    List<List<double>> melSpecDB = _powerToDb(melSpec);
    
    // 4. Normalize to [0, 1]
    List<List<double>> normalized = _normalize(melSpecDB);
    
    // 5. Pad or truncate to fixed length
    List<List<double>> fixed = _fixLength(normalized, maxLen);
    print('   Final shape: ${fixed.length} x ${fixed[0].length}');
    
    return fixed;
  }
  
  /// Compute Short-Time Fourier Transform
  static Future<List<List<double>>> _computeSTFT(Float32List audio) async {
    List<List<double>> stft = [];
    
    final numFrames = ((audio.length - fftSize) ~/ hopLength) + 1;
    
    for (int i = 0; i < numFrames; i++) {
      final start = i * hopLength;
      final end = min(start + fftSize, audio.length);
      
      // Extract frame
      List<double> frame = List.filled(fftSize, 0.0);
      for (int j = 0; j < end - start; j++) {
        // Apply Hann window
        double window = 0.5 * (1 - cos(2 * pi * j / (fftSize - 1)));
        frame[j] = audio[start + j] * window;
      }
      
      // Compute FFT
      final fft = FFT().Transform(frame);
      
      // Compute magnitude
      List<double> magnitude = [];
      for (int k = 0; k < fftSize ~/ 2; k++) {
        double real = fft[k];
        double imag = fft[k + fftSize ~/2];
        magnitude.add(sqrt(real * real + imag * imag));
      }
      
      stft.add(magnitude);
    }
    
    return stft;
  }
  
  /// Apply Mel filterbank (simplified version)
  static List<List<double>> _applyMelFilterbank(List<List<double>> stft) {
    // This is a simplified version
    // For production, use a proper Mel filterbank implementation
    // or port from librosa
    
    List<List<double>> melSpec = [];
    
    final melBands = _createMelFilterbank(stft[0].length, nMels);
    
    for (var frame in stft) {
      List<double> melFrame = [];
      for (var melFilter in melBands) {
        double melValue = 0.0;
        for (int i = 0; i < frame.length && i < melFilter.length; i++) {
          melValue += frame[i] * melFilter[i];
        }
        melFrame.add(melValue);
      }
      melSpec.add(melFrame);
    }
    
    return melSpec;
  }
  
  /// Create Mel filterbank (simplified)
  static List<List<double>> _createMelFilterbank(int nfft, int nMels) {
    // Simplified mel filterbank
    // For production, implement proper mel scale conversion
    List<List<double>> filterbank = [];
    
    for (int i = 0; i < nMels; i++) {
      List<double> filter = List.filled(nfft, 0.0);
      
      // Simple triangular filters
      int center = (i * nfft / nMels).round();
      int width = (nfft / nMels).round();
      
      for (int j = max(0, center - width); 
           j < min(nfft, center + width); j++) {
        filter[j] = 1.0 - (j - center).abs() / width;
      }
      
      filterbank.add(filter);
    }
    
    return filterbank;
  }
  
  /// Convert power to dB
  static List<List<double>> _powerToDb(List<List<double>> spec) {
    List<List<double>> dbSpec = [];
    
    for (var frame in spec) {
      List<double> dbFrame = frame.map((value) {
        return 10 * log(max(value, 1e-10)) / ln10;
      }).toList();
      dbSpec.add(dbFrame);
    }
    
    return dbSpec;
  }
  
  /// Normalize to [0, 1]
  static List<List<double>> _normalize(List<List<double>> spec) {
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    
    for (var frame in spec) {
      for (var value in frame) {
        if (value < minVal) minVal = value;
        if (value > maxVal) maxVal = value;
      }
    }
    
    List<List<double>> normalized = [];
    for (var frame in spec) {
      List<double> normFrame = frame.map((value) {
        return (value - minVal) / (maxVal - minVal);
      }).toList();
      normalized.add(normFrame);
    }
    
    return normalized;
  }
  
  /// Pad or truncate to fixed length
  static List<List<double>> _fixLength(
    List<List<double>> spec,
    int targetLen,
  ) {
    if (spec.length >= targetLen) {
      return spec.sublist(0, targetLen);
    } else {
      // Pad with zeros
      List<List<double>> paddedSpec = List.from(spec);
      int padLen = targetLen - spec.length;
      
      for (int i = 0; i < padLen; i++) {
        paddedSpec.add(List.filled(spec[0].length, 0.0));
      }
      
      return paddedSpec;
    }
  }
  
  /// Convert to model input format
  static List<List<List<List<double>>>> toModelInput(
    List<List<double>> melSpec,
  ) {
    // Reshape to (1, nMels, maxLen, 1)
    // Transpose: (maxLen, nMels) -> (nMels, maxLen)
    List<List<double>> transposed = [];
    
    for (int i = 0; i < nMels; i++) {
      List<double> row = [];
      for (int j = 0; j < maxLen; j++) {
        row.add(melSpec[j][i]);
      }
      transposed.add(row);
    }
    
    // Add batch and channel dimensions
    return [
      transposed.map((row) => 
        row.map((val) => [val]).toList()
      ).toList()
    ];
  }
}
```

---

## 🤖 Model Integration

### File: `lib/services/classifier_service.dart`

```dart
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'audio_processor.dart';

class ClassifierService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  
  bool get isLoaded => _interpreter != null;
  
  /// Load TFLite model
  Future<void> loadModel() async {
    try {
      print('📦 Loading TFLite model...');
      
      // Load model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/audio_classifier_quantized.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      
      print('✅ Model loaded successfully');
      print('   Input shape: ${_interpreter!.getInputTensors()}');
      print('   Output shape: ${_interpreter!.getOutputTensors()}');
      
      // Load labels
      await _loadLabels();
      
    } catch (e) {
      print('❌ Error loading model: $e');
      rethrow;
    }
  }
  
  /// Load class labels
  Future<void> _loadLabels() async {
    final labelsData = await rootBundle.loadString(
      'assets/models/label_map.txt',
    );
    _labels = labelsData.split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    print('📋 Labels loaded: $_labels');
  }
  
  /// Run inference on audio
  Future<ClassificationResult> classify(Float32List audioSamples) async {
    if (!isLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }
    
    print('\n🔮 Running inference...');
    final stopwatch = Stopwatch()..start();
    
    // 1. Extract features
    print('   1️⃣ Extracting Mel Spectrogram...');
    final melSpec = await AudioProcessor.extractMelSpectrogram(audioSamples);
    
    // 2. Prepare input
    print('   2️⃣ Preparing model input...');
    final input = AudioProcessor.toModelInput(melSpec);
    
    // 3. Create output buffer
    // Output shape: (1, 1) for binary classification with sigmoid
    var output = List.filled(1, 0.0).reshape([1, 1]);
    
    // 4. Run inference
    print('   3️⃣ Running TFLite inference...');
    _interpreter!.run(input, output);
    
    // 5. Process output
    print('   4️⃣ Processing results...');
    double probSkizofrenia = output[0][0];
    double probNormal = 1.0 - probSkizofrenia;
    
    List<double> probabilities = [probNormal, probSkizofrenia];
    int predictedIndex = probNormal > probSkizofrenia ? 0 : 1;
    String predictedClass = _labels[predictedIndex];
    double confidence = probabilities[predictedIndex];
    
    stopwatch.stop();
    
    print('✅ Inference complete!');
    print('   Time: ${stopwatch.elapsedMilliseconds}ms');
    print('   Result: $predictedClass (${(confidence * 100).toStringAsFixed(1)}%)');
    
    return ClassificationResult(
      predictedClass: predictedClass,
      confidence: confidence,
      probabilities: {
        _labels[0]: probabilities[0],
        _labels[1]: probabilities[1],
      },
      inferenceTime: stopwatch.elapsedMilliseconds,
    );
  }
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Classification result model
class ClassificationResult {
  final String predictedClass;
  final double confidence;
  final Map<String, double> probabilities;
  final int inferenceTime;
  
  ClassificationResult({
    required this.predictedClass,
    required this.confidence,
    required this.probabilities,
    required this.inferenceTime,
  });
  
  bool get isNormal => predictedClass.toLowerCase() == 'normal';
  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.6 && confidence < 0.8;
  bool get isLowConfidence => confidence < 0.6;
  
  String get confidenceLevel {
    if (isHighConfidence) return 'High';
    if (isMediumConfidence) return 'Medium';
    return 'Low';
  }
}
```

---

## 🎨 UI/UX Implementation

### File: `lib/screens/classifier_screen.dart`

```dart
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import '../services/classifier_service.dart';
import '../providers/audio_provider.dart';

class ClassifierScreen extends StatefulWidget {
  @override
  _ClassifierScreenState createState() => _ClassifierScreenState();
}

class _ClassifierScreenState extends State<ClassifierScreen> {
  final ClassifierService _classifier = ClassifierService();
  bool _isLoading = true;
  
  @override
  void initState() {
    super.initState();
    _loadModel();
  }
  
  Future<void> _loadModel() async {
    try {
      await _classifier.loadModel();
      setState(() => _isLoading = false);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading model: $e')),
      );
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Audio Classifier'),
        backgroundColor: Color(0xFF667eea),
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator())
          : Consumer<AudioProvider>(
              builder: (context, audioProvider, child) {
                return SingleChildScrollView(
                  padding: Edge Insets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeader(),
                      SizedBox(height: 24),
                      _buildRecordButton(audioProvider),
                      SizedBox(height: 24),
                      if (audioProvider.result != null)
                        _buildResultsSection(audioProvider.result!),
                    ],
                  ),
                );
              },
            ),
    );
  }
  
  Widget _buildHeader() {
    return Container(
      padding: EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF667eea), Color(0xFF764ba2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(15),
      ),
      child: Column(
        children: [
          Icon(Icons.mic, size: 48, color: Colors.white),
          SizedBox(height: 12),
          Text(
            'Klasifikasi Gangguan Jiwa',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            'RSJD dr. Amino Gondohutomo',
            style: TextStyle(
              fontSize: 14,
              color: Colors.white70,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
  
  Widget _buildRecordButton(AudioProvider audioProvider) {
    return ElevatedButton.icon(
      onPressed: audioProvider.isRecording
          ? null
          : () => _startRecording(audioProvider),
      icon: Icon(
        audioProvider.isRecording ? Icons.stop : Icons.mic,
        size: 32,
      ),
      label: Text(
        audioProvider.isRecording ? 'Recording...' : 'Start Recording',
        style: TextStyle(fontSize: 18),
      ),
      style: ElevatedButton.styleFrom(
        padding: EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
  
  Widget _buildResultsSection(ClassificationResult result) {
    return Card(
      elevation: 4,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(15),
      ),
      child: Padding(
        padding: EdgeInsets.all(20),
        child: Column(
          children: [
            Text(
              'Hasil Analisis',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 24),
            _buildGaugeChart(result),
            SizedBox(height: 24),
            _buildProbabilityBars(result),
            SizedBox(height: 16),
            _buildInferenceTime(result),
          ],
        ),
      ),
    );
  }
  
  Widget _buildGaugeChart(ClassificationResult result) {
    Color color = result.isNormal ? Colors.green : Colors.red;
    
    return CircularPercentIndicator(
      radius: 100,
      lineWidth: 15,
      percent: result.confidence,
      center: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '${(result.confidence * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          SizedBox(height: 8),
          Text(
            result.predictedClass.toUpperCase(),
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
      progressColor: color,
      backgroundColor: color.withOpacity(0.2),
      circularStrokeCap: CircularStrokeCap.round,
    );
  }
  
  Widget _buildProbabilityBars(ClassificationResult result) {
    return Column(
      children: result.probabilities.entries.map((entry) {
        return Padding(
          padding: EdgeInsets.only(bottom: 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                entry.key.toUpperCase(),
                style: TextStyle(fontWeight: FontWeight.w600),
              ),
              SizedBox(height: 4),
              LinearProgressIndicator(
                value: entry.value,
                backgroundColor: Colors.grey[200],
                valueColor: AlwaysStoppedAnimation<Color>(
                  entry.key.toLowerCase() == 'normal'
                      ? Colors.green
                      : Colors.red,
                ),
                minHeight: 10,
              ),
              SizedBox(height: 4),
              Text(
                '${(entry.value * 100).toStringAsFixed(1)}%',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
  
  Widget _buildInferenceTime(ClassificationResult result) {
    return Container(
      padding: EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.speed, color: Colors.blue, size: 20),
          SizedBox(width: 8),
          Text(
            'Processing time: ${result.inferenceTime}ms',
            style: TextStyle(
              color: Colors.blue[900],
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
  
  Future<void> _startRecording(AudioProvider audioProvider) async {
    // Implementation in audio_provider.dart
    await audioProvider.startRecording();
    
    // Wait for configured duration (e.g., 5 seconds)
    await Future.delayed(Duration(seconds: 5));
    
    final audioData = await audioProvider.stopRecording();
    
    if (audioData != null) {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: CircularProgressIndicator(),
        ),
      );
      
      // Run classification
      try {
        final result = await _classifier.classify(audioData);
        audioProvider.setResult(result);
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: $e')),
        );
      } finally {
        Navigator.pop(context); // Close loading dialog
      }
    }
  }
  
  @override
  void dispose() {
    _classifier.dispose();
    super.dispose();
  }
}
```

---

## 🧪 Testing & Optimization

### Performance Testing

```dart
// lib/utils/benchmark.dart

class ModelBenchmark {
  static Future<void> runBenchmark(ClassifierService classifier) async {
    print('\n🧪 Running benchmark...');
    
    final random = Random();
    final testAudio = Float32List.fromList(
      List.generate(22050 * 5, (_) => random.nextDouble() * 2 - 1),
    );
    
    List<int> times = [];
    
    for (int i = 0; i < 10; i++) {
      final stopwatch = Stopwatch()..start();
      await classifier.classify(testAudio);
      stopwatch.stop();
      times.add(stopwatch.elapsedMilliseconds);
    }
    
    final avgTime = times.reduce((a, b) => a + b) / times.length;
    final minTime = times.reduce(min);
    final maxTime = times.reduce(max);
    
    print('📊 Benchmark Results:');
    print('   Average: ${avgTime.toStringAsFixed(1)}ms');
    print('   Min: ${minTime}ms');
    print('   Max: ${maxTime}ms');
  }
}
```

---

## 📦 Deployment

### Build for Android

```bash
# Build APK
flutter build apk --release

# Build App Bundle (for Play Store)
flutter build appbundle --release

# Output: build/app/outputs/flutter-apk/app-release.apk
```

### Build for iOS

```bash
# Build IPA
flutter build ios --release

# Open in Xcode for signing
open ios/Runner.xcworkspace
```

---

## 🔧 Troubleshooting

### Common Issues

#### 1. Model Loading Error

```dart
// Error: Unable to load model
// Solution: Check asset path in pubspec.yaml
assets:
  - assets/models/audio_classifier_quantized.tflite
```

#### 2. Permission Denied

```dart
// Error: Microphone permission denied
// Solution: Request permission before recording

import 'package:permission_handler/permission_handler.dart';

Future<bool> requestMicrophonePermission() async {
  final status = await Permission.microphone.request();
  return status.isGranted;
}
```

#### 3. Audio Processing Errors

```
// Error: FFT computation failed
// Solution: Ensure audio length > FFT size
if (audioSamples.length < AudioProcessor.fftSize) {
  // Pad audio
}
```

---

## 📚 Additional Resources

- [TensorFlow Lite Flutter](https://pub.dev/packages/tflite_flutter)
- [Audio Recording Flutter](https://pub.dev/packages/record)
- [Flutter Provider](https://pub.dev/packages/provider)

---

## ✅ Checklist

- [ ] Model converted to TFLite
- [ ] Flutter project created
- [ ] Dependencies added
- [ ] Permissions configured
- [ ] Audio processing implemented
- [ ] Model integration complete
- [ ] UI implemented
- [ ] Testing performed
- [ ] App built for release
- [ ] Deployment ready

---

**🎉 Congratulations! Your offline mobile audio classifier is ready!**

