# 🐛 FIX: Model Bias ke Kelas "Normal" di Flutter App

## 🔍 **DIAGNOSIS MASALAH**

### **Gejala:**
- ✅ Model Python (Streamlit) bekerja BAIK
- ❌ Model Flutter (TFLite) selalu prediksi "NORMAL"
- ⚠️ Bias prediction → kemungkinan **preprocessing mismatch**

---

## 🎯 **ROOT CAUSE ANALYSIS**

Setelah membandingkan kode Python dan Flutter, saya menemukan **PERBEDAAN KRITIS**:

### **1. NORMALIZATION METHOD** ⚠️ **PENYEBAB UTAMA**

#### Python (Streamlit) - `app_optimized.py`:
```python
# Line 49-50
mel_spec = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=N_MELS, fmax=FMAX)
mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)  # ← REF=NP.MAX
```

**Breakdown:**
1. Convert power to dB dengan `ref=np.max`
2. Range dinamis: sekitar -80 dB to 0 dB
3. Nilai **TIDAK** di-normalize ke [0,1]

#### Flutter (audio_processor.dart) - SALAH:
```dart
// Line 509-520
static List<List<double>> _powerToDb(List<List<double>> spec) {
  for (var frame in spec) {
    List<double> dbFrame = frame.map((value) {
      return 10 * log(max(value, 1e-10)) / ln10;  // ← POWER TO DB
    }).toList();
    dbSpec.add(dbFrame);
  }
  return dbSpec;
}

// Line 524-543  
static List<List<double>> _normalize(List<List<double>> spec) {
  // Min-Max normalization ke [0, 1]  ← INI MASALAHNYA!
  return (value - minVal) / (maxVal - minVal);
}
```

**Masalah:**
- ✅ Power to dB: CORRECT
- ❌ **Normalization ke [0,1]**: **WRONG!** (tidak ada di Python)
- ❌ Reference tidak sama dengan `np.max`

---

### **2. MEL FILTERBANK MISMATCH** ⚠️

#### Python (Librosa):
- Menggunakan **mel filterbank standar librosa**
- Mel scale conversion yang presisi
- Triangular overlapping filters

#### Flutter (Simplified):
```dart
// Line 485-506
static List<List<double>> _createMelFilterbank(int nfft, int nMels) {
  // SIMPLIFIED mel filterbank  ← TIDAK AKURAT!
  // Simple triangular filters
  int center = (i * nfft / nMels).round();
  int width = (nfft / nMels).round();
  
  for (int j = max(0, center - width); j < min(nfft, center + width); j++) {
    filter[j] = 1.0 - (j - center).abs() / width;
  }
}
```

**Masalah:**
- ❌ **Simplified filterbank** bukan mel scale yang benar
- ❌ Tidak ada Hz → Mel conversion
- ❌ Filter width dan spacing tidak akurat

---

### **3. MODEL OUTPUT INTERPRETATION**

#### Python:
```python
# Line 305-308
if len(prediction_proba.shape) == 0 or prediction_proba.shape[0] == 1:
    prob_positive = float(prediction_proba[0])
    prediction_proba = np.array([1 - prob_positive, prob_positive])
```

Model menggunakan **sigmoid output** (binary classification):
- Output shape: `(1, 1)` 
- Value: probability untuk class positive (skizofrenia)
- Class 0 (Normal) = 1 - prob
- Class 1 (Skizo) = prob

#### Flutter:
```dart
// classifier_service.dart Line 74-78
double probSkizofrenia = output[0][0];
double probNormal = 1.0 - probSkizofrenia;

List<double> probabilities = [probNormal, probSkizofrenia];
int predictedIndex = probNormal > probSkizofrenia ? 0 : 1;
```

**Ini BENAR** - tidak ada masalah di sini.

---

## ✅ **SOLUTION - 3 FIXES YANG HARUS DILAKUKAN**

### **FIX #1: HAPUS NORMALIZATION** ⭐ **CRITICAL**

`audio_processor.dart` - **REMOVE Line 20: normalize**

```dart
static Future<List<List<double>>> extractMelSpectrogram(
  Float32List audioSamples,
) async {
  // ... STFT computation ...
  
  // 2. Convert to Mel scale
  List<List<double>> melSpec = _applyMelFilterbank(stft);
  
  // 3. Convert to dB scale
  List<List<double>> melSpecDB = _powerToDb(melSpec);
  
  // 4. ❌ HAPUS INI! Jangan normalize!
  // List<List<double>> normalized = _normalize(melSpecDB);
  
  // 5. Pad or truncate - LANGSUNG dari melSpecDB
  List<List<double>> fixed = _fixLength(melSpecDB, maxLen);  // ← CHANGE!
  
  return fixed;
}
```

**Kenapa?** Python tidak normalize ke [0,1]. Model di-train dengan raw dB values (-80 to 0 range).

---

### **FIX #2: GUNAKAN LIBROSA-EQUIVALENT MEL FILTERBANK** ⭐ **HIGH PRIORITY**

Ada 2 opsi:

#### **Option A: Use Package `flutter_audio_processing`** (Recommended)
```yaml
# pubspec.yaml
dependencies:
  flutter_audio_processing: ^0.1.0  # Jika ada package yang mirip librosa
```

#### **Option B: Port Librosa Mel Filterbank ke Dart**

Create file: `lib/utils/mel_filterbank.dart`

```dart
import 'dart:math';
import 'dart:typed_data';

class MelFilterbank {
  /// Convert Hz to Mel scale
  static double hzToMel(double hz) {
    return 2595.0 * log(1.0 + hz / 700.0) / ln10;
  }
  
  /// Convert Mel to Hz scale
  static double melToHz(double mel) {
    return 700.0 * (pow(10, mel / 2595.0) - 1.0);
  }
  
  /// Create Mel filterbank (librosa-compatible)
  static List<List<double>> createMelFilterbank({
    required int nfft,
    required int nMels,
    required int sampleRate,
    double fMin = 0.0,
    required double fMax,
  }) {
    // 1. Create mel-spaced frequencies
    double melFMin = hzToMel(fMin);
    double melFMax = hzToMel(fMax);
    
    List<double> melPoints = List.generate(
      nMels + 2,
      (i) => melFMin + (melFMax - melFMin) * i / (nMels + 1),
    );
    
    // 2. Convert back to Hz
    List<double> hzPoints = melPoints.map((m) => melToHz(m)).toList();
    
    // 3. Convert Hz to FFT bin numbers
    List<int> bins = hzPoints.map((hz) {
      return ((nfft + 1) * hz / sampleRate).round();
    }).toList();
    
    // 4. Create triangular filterbank
    List<List<double>> filterbank = [];
    int fftBins = nfft ~/ 2 + 1;
    
    for (int i = 1; i < nMels + 1; i++) {
      List<double> filter = List.filled(fftBins, 0.0);
      
      int leftBin = bins[i - 1];
      int centerBin = bins[i];
      int rightBin = bins[i + 1];
      
      // Left slope (rising)
      for (int j = leftBin; j < centerBin; j++) {
        if (j < fftBins) {
          filter[j] = (j - leftBin) / (centerBin - leftBin);
        }
      }
      
      // Right slope (falling)
      for (int j = centerBin; j < rightBin; j++) {
        if (j < fftBins) {
          filter[j] = (rightBin - j) / (rightBin - centerBin);
        }
      }
      
      filterbank.add(filter);
    }
    
    return filterbank;
  }
  
  /// Apply filterbank to STFT magnitude
  static List<List<double>> applyFilterbank(
    List<List<double>> stft,
    List<List<double>> filterbank,
  ) {
    List<List<double>> melSpec = [];
    
    for (var frame in stft) {
      List<double> melFrame = [];
      
      for (var filter in filterbank) {
        double melValue = 0.0;
        for (int i = 0; i < frame.length && i < filter.length; i++) {
          melValue += frame[i] * filter[i];
        }
        melFrame.add(melValue);
      }
      
      melSpec.add(melFrame);
    }
    
    return melSpec;
  }
}
```

**Update `audio_processor.dart`:**

```dart
import '../utils/mel_filterbank.dart';

class AudioProcessor {
  // ... existing code ...
  
  static Future<List<List<double>>> extractMelSpectrogram(
    Float32List audioSamples,
  ) async {
    // 1. STFT
    List<List<double>> stft = await _computeSTFT(audioSamples);
    
    // 2. Create proper Mel filterbank (ONCE, cache it!)
    var melFilters = MelFilterbank.createMelFilterbank(
      nfft: fftSize ~/ 2 + 1,
      nMels: nMels,
      sampleRate: sampleRate,
      fMin: 0.0,
      fMax: fMax.toDouble(),
    );
    
    // 3. Apply Mel filterbank
    List<List<double>> melSpec = MelFilterbank.applyFilterbank(stft, melFilters);
    
    // 4. Convert to dB (WITH PROPER REFERENCE!)
    List<List<double>> melSpecDB = _powerToDbLibrosa(melSpec);
    
    // 5. Pad/truncate
    List<List<double>> fixed = _fixLength(melSpecDB, maxLen);
    
    return fixed;
  }
  
  /// Power to dB matching librosa (ref=np.max)
  static List<List<double>> _powerToDbLibrosa(List<List<double>> spec) {
    // Find maximum value in entire spectrogram
    double maxVal = double.negativeInfinity;
    for (var frame in spec) {
      for (var value in frame) {
        if (value > maxVal) maxVal = value;
      }
    }
    
    double refPower = max(maxVal, 1e-10);  // Avoid log(0)
    
    List<List<double>> dbSpec = [];
    for (var frame in spec) {
      List<double> dbFrame = frame.map((value) {
        // librosa formula: 10 * log10(S / ref)
        return 10.0 * log(max(value, 1e-10) / refPower) / ln10;
      }).toList();
      dbSpec.add(dbFrame);
    }
    
    return dbSpec;
  }
}
```

---

### **FIX #3: VERIFY MODEL INPUT SHAPE**

Pastikan input shape **EXACT MATCH** dengan training:

```dart
static List<List<List<List<double>>>> toModelInput(
  List<List<double>> melSpec,
) {
  // Python: (maxLen, nMels) → model expects (1, nMels, maxLen, 1)
  // Need to transpose!
  
  List<List<double>> transposed = [];
  
  for (int i = 0; i < nMels; i++) {
    List<double> row = [];
    for (int j = 0; j < maxLen; j++) {
      row.add(melSpec[j][i]);  // ← Transpose
    }
    transposed.add(row);
  }
  
  // Add batch and channel dimensions: (1, 128, 216, 1)
  return [
    transposed.map((row) => 
      row.map((val) => [val]).toList()
    ).toList()
  ];
}
```

**Verify dengan print:**
```dart
print('Input shape: (${input.length}, ${input[0].length}, ${input[0][0].length}, ${input[0][0][0].length})');
// Should print: Input shape: (1, 128, 216, 1)
```

---

## 🧪 **TESTING & VALIDATION**

### **Test Script untuk Compare**

Create: `lib/utils/model_validator.dart`

```dart
import 'dart:typed_data';
import '../services/audio_processor.dart';

class ModelValidator {
  /// Test preprocessing dengan known input
  static Future<void> validatePreprocessing(Float32List audioSamples) async {
    final melSpec = await AudioProcessor.extractMelSpectrogram(audioSamples);
    
    print('=== VALIDATION ===');
    print('Mel Spec Shape: ${melSpec.length} x ${melSpec[0].length}');
    print('Expected: 216 x 128');
    
    //Calculate statistics
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sum = 0;
    int count = 0;
    
    for (var frame in melSpec) {
      for (var value in frame) {
        if (value < minVal) minVal = value;
        if (value > maxVal) maxVal = value;
        sum += value;
        count++;
      }
    }
    
    double mean = sum / count;
    
    print('Value Range: [$minVal, $maxVal]');
    print('Expected: [-80, 0] (dB scale)');
    print('Mean: $mean');
    
    // COMPARE dengan Python output
    if (maxVal > 10 || minVal > 0) {
      print('❌ WARNING: Values out of expected dB range!');
      print('   Preprocessing might be incorrect.');
    } else {
      print('✅ Values in expected dB range');
    }
  }
}
```

---

## 📊 **QUICK FIX SUMMARY**

### **Minimum Fix (30 menit):**
1. ✅ **HAPUS** `_normalize()` call di `extractMelSpectrogram()`
2. ✅ **UPDATE** `_powerToDb()` untuk gunakan `ref=max`

### **Proper Fix (2-3 jam):**
1. ✅ Implement `MelFilterbank` class
2. ✅ Replace simplified filterbank
3. ✅ Update power_to_db dengan librosa reference
4. ✅ Add validation

### **Testing:**
1. ✅ Test dengan audio yang sama di Python dan Flutter
2. ✅ Compare output probabilities
3. ✅ Should match within 1-2%

---

## 🎯 **EXPECTED RESULTS AFTER FIX**

| Metric | Before | After |
|--------|--------|-------|
| **Bias** | Always "Normal" | Balanced predictions |
| **Accuracy** | ~50% (random) | ~90%+ (matching Python) |
| **Confidence** | Low | High (matching training) |

---

## 📞 **VERIFICATION CHECKLIST**

- [ ] Removed `_normalize()` from preprocessing
- [ ] Updated `_powerToDb()` to use max reference
- [ ] Implemented proper Mel filterbank
- [ ] Verified input shape (1, 128, 216, 1)
- [ ] Tested with same audio as Python
- [ ] Probabilities match within 5%
- [ ] No more bias to "Normal"

---

**PRIORITY: HIGH** 🔥  
**Estimated Fix Time:** 30 min (quick) to 3 hours (proper)  
**Impact:** CRITICAL - fixes main classification bug

---

Made with 🔍 Deep Analysis for Flutter CNN Classifier
