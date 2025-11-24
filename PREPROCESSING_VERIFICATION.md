# 🔬 PREPROCESSING VERIFICATION DOCUMENT
**Audio Classification Mobile App - Flutter Implementation**

## 📋 Document Purpose

Dokumen ini menjelaskan **EXACT preprocessing pipeline** yang digunakan di Flutter mobile app untuk inference model TFLite. Tim Python perlu **MEMVERIFIKASI** bahwa preprocessing ini **MATCH 100%** dengan preprocessing yang digunakan saat training model.

**CRITICAL**: Jika ada perbedaan preprocessing antara training dan inference, model akan menghasilkan prediksi yang salah (bias ke satu kelas).

---

## 🎯 Current Issue

**Problem**: Model TFLite di mobile app **bias ke kelas "normal" 100%** untuk semua audio input (baik normal maupun skizofrenia).

**Hypothesis**: Ada perbedaan antara preprocessing Python (training) dan Flutter (inference).

**Goal**: Dokumentasi lengkap preprocessing Flutter agar tim Python bisa compare dan fix mismatch.

---

## 🔧 Technical Stack

### Flutter Dependencies
```yaml
# pubspec.yaml
dependencies:
  flutter:
    sdk: flutter
  tflite_flutter: ^0.10.4  # TensorFlow Lite interpreter
  file_picker: ^6.1.1      # Audio file selection
  fftea: ^1.0.0            # FFT computation (Fast Fourier Transform)
  
  # Custom implementation:
  # - Mel filterbank (librosa-compatible)
  # - STFT windowing (Hann window)
  # - Power-to-dB conversion
```

### Libraries Used
1. **`fftea`**: FFT computation engine
   - URL: https://pub.dev/packages/fftea
   - Version: 1.0.0
   - Used for: STFT (Short-Time Fourier Transform)

2. **Custom Mel Filterbank**: `lib/services/mel_filterbank.dart`
   - Implementation: Librosa-compatible
   - Triangular filters with proper mel scale conversion

---

## 📊 Model Specifications

### Input Tensor
```
Name: serving_default_input_layer:0
Type: float32
Shape: [1, 128, 216, 1]
       │   │    │    └─ Channels (1 = grayscale)
       │   │    └────── Time frames
       │   └─────────── Mel frequency bands
       └─────────────── Batch size
```

### Output Tensor
```
Name: StatefulPartitionedCall_1:0
Type: float32
Shape: [1, 1]
       │  └─ Sigmoid probability for class 1 (skizofrenia)
       └──── Batch size

Output Interpretation:
- output[0][0] = 0.0 → 100% normal (class 0)
- output[0][0] = 1.0 → 100% skizofrenia (class 1)
- output[0][0] = 0.5 → 50% skizofrenia, 50% normal
```

### Labels
```
label_map.txt:
normal
skizofrenia
```

---

## 🎵 Audio Preprocessing Pipeline

### Constants Configuration
```dart
// lib/services/audio_processor.dart

static const int sampleRate = 22050;  // Sampling frequency (Hz)
static const int nMels = 128;         // Number of mel frequency bands
static const int maxLen = 216;        // Fixed time dimension (frames)
static const int fftSize = 2048;      // FFT window size
static const int hopLength = 512;     // Hop length between frames
static const int fMax = 8000;         // Maximum frequency (Hz)
```

**CRITICAL**: Pastikan nilai ini **EXACT MATCH** dengan Python training!

---

## 🔄 Step-by-Step Preprocessing

### Step 1: Audio Loading

**Input**: WAV file (16-bit PCM, mono)

**Process**:
```dart
// Load WAV file and decode PCM data
Float32List audioSamples = loadWavFile(filePath);

// Expected format:
// - Sample rate: 22050 Hz
// - Channels: 1 (mono)
// - Bit depth: 16-bit
// - Format: PCM
```

**Output**: `Float32List` dengan nilai range **[-1.0, 1.0]**

**Python Equivalent**:
```python
import librosa

audio, sr = librosa.load(audio_path, sr=22050, mono=True)
# Returns: numpy array with float32 values in [-1.0, 1.0]
```

---

### Step 2: STFT (Short-Time Fourier Transform)

**Input**: `Float32List audioSamples` (length = N samples)

**Process**:
```dart
// Compute number of frames
numFrames = ((audioLength - fftSize) / hopLength) + 1

// For each frame:
for (int i = 0; i < numFrames; i++) {
  start = i * hopLength;
  end = start + fftSize;
  
  // 1. Extract frame
  frame = audioSamples[start:end];  // Length = 2048
  
  // 2. Apply Hann window
  for (int j = 0; j < fftSize; j++) {
    window = 0.5 * (1 - cos(2 * π * j / (fftSize - 1)));
    frame[j] *= window;
  }
  
  // 3. Compute FFT using fftea library
  fftResult = FFT(fftSize).realFft(frame);
  
  // 4. Compute power spectrum (magnitude squared)
  for (int k = 0; k < fftSize / 2; k++) {
    real = fftResult[k].x;
    imag = fftResult[k].y;
    power[k] = real² + imag²;  // NOT sqrt! Power spectrum
  }
  
  stft.add(power);
}
```

**Output**: STFT matrix
- Shape: `(numFrames, fftSize/2)` = `(numFrames, 1024)`
- Values: **Power spectrum** (magnitude squared, NOT magnitude)

**Python Equivalent**:
```python
import librosa
import numpy as np

# Compute STFT
stft = librosa.stft(
    audio,
    n_fft=2048,
    hop_length=512,
    win_length=2048,
    window='hann',
    center=False  # IMPORTANT: Check if Python uses center=True!
)

# Compute power spectrum (magnitude squared)
power = np.abs(stft) ** 2  # Shape: (1025, numFrames)

# Transpose to match Flutter shape
power = power.T  # Shape: (numFrames, 1025)

# IMPORTANT: Flutter uses fftSize/2 = 1024 bins
# Python librosa returns 1025 bins (includes Nyquist)
# Verify which bins Python model uses!
```

**⚠️ CRITICAL VERIFICATION POINTS**:
1. **Window function**: Flutter uses Hann window. Python uses?
2. **Center padding**: Flutter `center=False`. Python?
3. **Power vs Magnitude**: Flutter uses power (squared). Python uses?
4. **FFT bins**: Flutter 1024 bins. Python 1025 bins? Which ones used?

---

### Step 3: Mel Filterbank

**Input**: Power spectrum `(numFrames, 1024)`

**Process**:
```dart
// 1. Create mel filterbank (cached, computed once)
melFilters = createMelFilterbank(
  nfft: 2048,
  nMels: 128,
  sampleRate: 22050,
  fMin: 0.0,
  fMax: 8000.0
);

// 2. Convert Hz to Mel scale (using librosa formula)
double hzToMel(double hz) {
  return 2595.0 * log10(1.0 + hz / 700.0);
}

// 3. Convert Mel to Hz
double melToHz(double mel) {
  return 700.0 * (pow(10.0, mel / 2595.0) - 1.0);
}

// 4. Create mel points
melMin = hzToMel(0.0);      // 0 mel
melMax = hzToMel(8000.0);   // ~2840 mel
melPoints = linspace(melMin, melMax, 128 + 2);  // 130 points

// 5. Convert back to Hz
hzPoints = melPoints.map((mel) => melToHz(mel));

// 6. Convert Hz to FFT bins
fftBins = hzPoints.map((hz) => floor((nfft + 1) * hz / sampleRate));

// 7. Create triangular filters
for (int i = 1; i < 128 + 1; i++) {
  left = fftBins[i - 1];
  center = fftBins[i];
  right = fftBins[i + 1];
  
  // Triangular filter weights
  for (int j = left; j < center; j++) {
    filter[i][j] = (j - left) / (center - left);
  }
  for (int j = center; j < right; j++) {
    filter[i][j] = (right - j) / (right - center);
  }
}

// 8. Apply filterbank to power spectrum
melSpec[frame][mel] = sum(power[frame] * filter[mel]);
```

**Output**: Mel spectrogram
- Shape: `(numFrames, 128)`
- Values: **Mel power** (sum of power spectrum weighted by mel filters)

**Python Equivalent**:
```python
import librosa

# Create mel filterbank
mel_filters = librosa.filters.mel(
    sr=22050,
    n_fft=2048,
    n_mels=128,
    fmin=0.0,
    fmax=8000.0,
    htk=False,  # Use Slaney (librosa default)
    norm=None   # IMPORTANT: Check normalization!
)

# Apply mel filterbank
mel_spec = np.dot(mel_filters, power.T)  # Shape: (128, numFrames)
mel_spec = mel_spec.T  # Shape: (numFrames, 128)
```

**⚠️ CRITICAL VERIFICATION POINTS**:
1. **Mel scale formula**: Flutter uses `2595 * log10(1 + f/700)`. Python same?
2. **Filter normalization**: Flutter `norm=None`. Python `norm='slaney'`? or `norm=1`?
3. **fmin/fmax**: Flutter `0.0` to `8000.0`. Python same?
4. **htk parameter**: Flutter uses Slaney (librosa default). Python uses HTK?

---

### Step 4: Power to dB Conversion

**Input**: Mel spectrogram `(numFrames, 128)` with power values

**Process**:
```dart
// 1. Find maximum power in entire spectrogram
maxPower = max(melSpec);  // Global maximum

// 2. Set reference power (using max)
refPower = max(maxPower, 1e-10);  // Avoid division by zero

// 3. Convert to dB scale (librosa formula)
for each value in melSpec {
  db = 10.0 * log10(max(value, 1e-10) / refPower);
}
```

**Formula**: `dB = 10 * log₁₀(S / ref)`

Where:
- `S` = power value
- `ref` = maximum power in spectrogram
- `1e-10` = floor value to avoid `log(0)`

**Output**: Mel spectrogram in dB scale
- Shape: `(numFrames, 128)`
- Values: **dB scale**, typically range `[-120, 0]` dB
- Maximum value: `0 dB` (because ref=max)

**Python Equivalent**:
```python
import librosa
import numpy as np

# Convert to dB scale
mel_spec_db = librosa.power_to_db(
    mel_spec,
    ref=np.max,     # CRITICAL: Use max as reference
    amin=1e-10,
    top_db=None     # No clipping
)
```

**⚠️ CRITICAL VERIFICATION POINTS**:
1. **Reference**: Flutter uses `ref=np.max`. Python same? Or `ref=1.0`?
2. **Floor value**: Flutter `1e-10`. Python same?
3. **Top dB clipping**: Flutter no clipping. Python clips to `top_db=80`?
4. **Formula**: Flutter `10 * log10`. Python `20 * log10` (for amplitude, not power)?

**IMPORTANT**: `power_to_db` vs `amplitude_to_db`
- Power: `10 * log10(S)`
- Amplitude: `20 * log10(S) = 10 * log10(S²)`

Flutter uses **power** (already squared in STFT). Verify Python uses power not amplitude!

---

### Step 5: Pad or Truncate

**Input**: Mel spectrogram dB `(numFrames, 128)`

**Process**:
```dart
if (numFrames >= 216) {
  // Truncate: Take first 216 frames
  melSpecFixed = melSpec[0:216];
  
} else {
  // Pad: Add frames at the end
  
  // Find minimum dB value in spectrogram
  minDb = min(melSpec);  // e.g., -120 dB
  
  // Use minimum dB for padding (represents silence)
  padValue = minDb if minDb.isFinite else -80.0;
  
  // Pad with minDb value
  numPadFrames = 216 - numFrames;
  for (int i = 0; i < numPadFrames; i++) {
    melSpec.add([padValue] * 128);  // Add frame filled with minDb
  }
}
```

**Output**: Fixed-length mel spectrogram
- Shape: `(216, 128)` ← **ALWAYS 216 frames**
- Values: dB scale, range `[-120, 0]` dB

**Python Equivalent**:
```python
import numpy as np

target_length = 216

if mel_spec_db.shape[0] >= target_length:
    # Truncate
    mel_spec_fixed = mel_spec_db[:target_length, :]
else:
    # Pad
    # IMPORTANT: What padding value does Python use?
    
    # Option 1: Pad with zeros (WRONG for dB!)
    pad_width = ((0, target_length - mel_spec_db.shape[0]), (0, 0))
    mel_spec_fixed = np.pad(mel_spec_db, pad_width, mode='constant', constant_values=0.0)
    
    # Option 2: Pad with minimum value (CORRECT)
    min_db = np.min(mel_spec_db)
    mel_spec_fixed = np.pad(mel_spec_db, pad_width, mode='constant', constant_values=min_db)
    
    # Option 3: Pad with edge values
    mel_spec_fixed = np.pad(mel_spec_db, pad_width, mode='edge')
    
    # Option 4: Repeat or wrap
    # ...
```

**⚠️ CRITICAL VERIFICATION POINTS**:
1. **Padding value**: Flutter uses `min(spectrogram)`. Python uses?
   - `0.0` → WRONG (means high power in dB scale)
   - `min_db` → Correct
   - `-80.0` or `-120.0` → Acceptable if consistent
2. **Padding position**: Flutter pads at **end**. Python pads at **start** or **end**?
3. **Truncation position**: Flutter takes **first** 216 frames. Python takes **first**, **middle**, or **random** crop?

---

### Step 6: Transpose and Reshape

**Input**: Mel spectrogram `(216, 128)` in dB scale

**Process**:
```dart
// 1. Transpose: (216, 128) → (128, 216)
transposed = [];
for (int i = 0; i < 128; i++) {      // For each mel band
  row = [];
  for (int j = 0; j < 216; j++) {    // For each time frame
    row.add(melSpec[j][i]);          // Get value at (time=j, mel=i)
  }
  transposed.add(row);
}
// Result: (128, 216) = (nMels, maxLen)

// 2. Add batch and channel dimensions
// Shape: (128, 216) → (1, 128, 216, 1)
input = [
  transposed.map((row) => 
    row.map((val) => [val]).toList()  // Add channel dimension
  ).toList()
];

// Final shape: (1, 128, 216, 1)
//              │   │    │    └─ Channels = 1
//              │   │    └────── Time frames = 216
//              │   └─────────── Mel bands = 128
//              └─────────────── Batch size = 1
```

**Output**: Model input tensor
- Shape: `(1, 128, 216, 1)`
- Values: **RAW dB values**, range `[-120, 0]` dB
- **NO NORMALIZATION** to [0, 1] range!

**Python Equivalent**:
```python
import numpy as np

# Transpose
mel_spec_transposed = mel_spec_fixed.T  # (128, 216)

# Reshape for model
input_tensor = mel_spec_transposed.reshape(1, 128, 216, 1)

# IMPORTANT: Check if Python normalizes here!
# Option 1: No normalization (CORRECT)
# input_tensor stays in dB scale [-120, 0]

# Option 2: Normalize to [0, 1] (WRONG if not done in training!)
# input_tensor = (input_tensor - input_tensor.min()) / (input_tensor.max() - input_tensor.min())

# Option 3: Standardize (z-score)
# input_tensor = (input_tensor - mean) / std
```

**⚠️ CRITICAL VERIFICATION POINTS**:
1. **Transpose**: Flutter `(216, 128)` → `(128, 216)`. Python same?
2. **Normalization**: Flutter **NO normalization**. Python normalizes?
3. **Value range**: Flutter keeps **raw dB** `[-120, 0]`. Python expects `[0, 1]` or `[-1, 1]`?
4. **Data type**: Flutter `float32`. Python same?

---

## 📈 Expected Value Ranges

### At Each Step:

| Step | Output | Value Range | Shape |
|------|--------|-------------|-------|
| 1. Audio Loading | Float32 samples | `[-1.0, 1.0]` | `(N,)` |
| 2. STFT | Power spectrum | `[0, max_power]` | `(frames, 1024)` |
| 3. Mel Filterbank | Mel power | `[0, max_power]` | `(frames, 128)` |
| 4. Power to dB | dB scale | `[-120, 0]` dB | `(frames, 128)` |
| 5. Pad/Truncate | Fixed length | `[-120, 0]` dB | `(216, 128)` |
| 6. Transpose | Model input | `[-120, 0]` dB | `(1, 128, 216, 1)` |

**CRITICAL**: Model input is **RAW dB VALUES**, NOT normalized to [0, 1]!

---

## 🔍 Verification Checklist

Tim Python harus cek dan konfirmasi untuk **SETIAP POIN**:

### ✅ Audio Loading
- [ ] Sample rate: 22050 Hz (same?)
- [ ] Mono audio (same?)
- [ ] Value range: [-1, 1] (same?)

### ✅ STFT
- [ ] FFT size: 2048 (same?)
- [ ] Hop length: 512 (same?)
- [ ] Window: Hann (same?)
- [ ] Center padding: False (same?)
- [ ] Output: **Power spectrum** (squared magnitude, not magnitude)
- [ ] FFT bins: 1024 (Flutter) vs 1025 (librosa)? Which used?

### ✅ Mel Filterbank
- [ ] Number of mels: 128 (same?)
- [ ] fmin: 0.0 Hz (same?)
- [ ] fmax: 8000.0 Hz (same?)
- [ ] Mel scale: `2595 * log10(1 + f/700)` (same?)
- [ ] Filter type: Triangular (same?)
- [ ] Normalization: None (same? or 'slaney'? or norm=1?)
- [ ] HTK: False/Slaney (same?)

### ✅ Power to dB
- [ ] Formula: `10 * log10(S / ref)` for power (same?)
- [ ] **NOT** `20 * log10(S)` for amplitude
- [ ] Reference: `np.max` (same? or ref=1.0?)
- [ ] Floor value: 1e-10 (same?)
- [ ] Top dB clipping: None (same? or top_db=80?)

### ✅ Padding/Truncate
- [ ] Target length: 216 frames (same?)
- [ ] Truncate: Take **first** 216 frames (same? or random crop?)
- [ ] Pad position: At **end** (same? or at start?)
- [ ] Pad value: **minimum dB** value (same? or 0? or -80?)

### ✅ Normalization
- [ ] **NO NORMALIZATION** to [0, 1] (same?)
- [ ] Model receives **raw dB values** [-120, 0] (same?)
- [ ] **NO z-score standardization** (same?)

### ✅ Reshape
- [ ] Transpose: (216, 128) → (128, 216) (same?)
- [ ] Final shape: (1, 128, 216, 1) (same?)
- [ ] Axis order: (batch, mels, time, channels) (same?)

---

## 🧪 Test Case for Verification

### Provide Sample Audio

Berikan 1 file audio (misalnya `test_sample.wav`) ke tim Python.

### Compare Outputs

**Step 1**: Python generate mel spectrogram
```python
import librosa
import numpy as np

# Your exact training preprocessing code here
mel_spec = preprocess_audio('test_sample.wav')

# Save to file
np.save('python_output.npy', mel_spec)

# Print statistics
print(f"Shape: {mel_spec.shape}")
print(f"Min: {mel_spec.min():.2f} dB")
print(f"Max: {mel_spec.max():.2f} dB")
print(f"Mean: {mel_spec.mean():.2f} dB")
print(f"First 10 values: {mel_spec[0, 0, :10, 0]}")
```

**Step 2**: Flutter generate mel spectrogram
```dart
// Flutter preprocessing code
var melSpec = await AudioProcessor.extractMelSpectrogram(audioSamples);

// Print statistics (already implemented)
print("Shape: (${melSpec.length}, ${melSpec[0].length})");
print("Min: ${min} dB");
print("Max: ${max} dB");
print("Mean: ${mean} dB");
print("First 10 values: ...");
```

**Step 3**: Compare values
- Shapes should **MATCH EXACTLY**
- Min/Max/Mean should be **within 0.01 dB**
- First 10 values should be **within 0.1 dB**

If values are significantly different → **FOUND THE BUG!**

---

## 🐛 Known Issues in Flutter

### Issue 1: Padding with 0.0 (FIXED)
**Before**:
```dart
// Pad with zeros (WRONG!)
paddedSpec.add(List.filled(128, 0.0));
```

**After**:
```dart
// Pad with minimum dB value (CORRECT)
double minDb = findMin(melSpec);
paddedSpec.add(List.filled(128, minDb));
```

### Issue 2: FFT Bin Count
Flutter uses **1024 bins** (fftSize/2).
Librosa returns **1025 bins** (includes Nyquist frequency).

**Verify**: Does Python model use all 1025 bins or only first 1024?

### Issue 3: Center Padding in STFT
Flutter uses `center=False` (no padding at start/end of audio).
Librosa default is `center=True` (pads with zeros).

**Verify**: What does Python training use?

---

## 📝 Questions for Python Team

Please answer the following questions about your training preprocessing:

### 1. STFT Configuration
```python
# Your stft code here:
stft = librosa.stft(
    audio,
    n_fft=?,
    hop_length=?,
    win_length=?,
    window=?,
    center=?,  # True or False?
)

# Do you use power or magnitude?
power = np.abs(stft) ** 2  # Power (squared)
# OR
magnitude = np.abs(stft)   # Magnitude (not squared)
```

### 2. Mel Filterbank Configuration
```python
# Your mel filter code here:
mel_filters = librosa.filters.mel(
    sr=?,
    n_fft=?,
    n_mels=?,
    fmin=?,
    fmax=?,
    htk=?,    # True or False?
    norm=?    # None, 'slaney', or 1?
)
```

### 3. Power to dB Configuration
```python
# Your power_to_db code here:
mel_spec_db = librosa.power_to_db(
    mel_spec,
    ref=?,      # np.max, 1.0, or other?
    amin=?,
    top_db=?    # None or 80?
)

# OR do you use amplitude_to_db?
mel_spec_db = librosa.amplitude_to_db(...)  # Different formula!
```

### 4. Padding Configuration
```python
# Your padding code here:
if mel_spec.shape[0] < 216:
    # What padding do you use?
    pad_value = ?  # 0.0, min, -80, or other?
    pad_mode = ?   # 'constant', 'edge', 'wrap', etc.
    
    mel_spec = np.pad(
        mel_spec,
        pad_width=?,
        mode=?,
        constant_values=?
    )
```

### 5. Normalization Configuration
```python
# Do you normalize the mel spectrogram?

# Option A: No normalization (keep raw dB)
input_tensor = mel_spec  # Just reshape

# Option B: Min-Max normalization
input_tensor = (mel_spec - mel_spec.min()) / (mel_spec.max() - mel_spec.min())

# Option C: Z-score standardization
input_tensor = (mel_spec - mean) / std

# Which one do you use?
```

### 6. Model Input Shape
```python
# What is the exact input shape and axis order?
input_tensor = mel_spec.reshape(?, ?, ?, ?)

# Is it:
# (batch, time, mels, channels) = (1, 216, 128, 1)
# OR
# (batch, mels, time, channels) = (1, 128, 216, 1)
```

---

## 🔧 Debugging Commands

### Check Python Preprocessing
```python
import librosa
import numpy as np

audio, sr = librosa.load('test.wav', sr=22050)
print(f"Audio shape: {audio.shape}")
print(f"Audio range: [{audio.min():.3f}, {audio.max():.3f}]")

stft = librosa.stft(audio, n_fft=2048, hop_length=512)
print(f"STFT shape: {stft.shape}")

power = np.abs(stft) ** 2
print(f"Power shape: {power.shape}")
print(f"Power range: [{power.min():.2e}, {power.max():.2e}]")

mel_filters = librosa.filters.mel(sr=22050, n_fft=2048, n_mels=128, fmax=8000)
print(f"Mel filters shape: {mel_filters.shape}")

mel_spec = np.dot(mel_filters, power)
print(f"Mel spec shape: {mel_spec.shape}")
print(f"Mel spec range: [{mel_spec.min():.2e}, {mel_spec.max():.2e}]")

mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)
print(f"Mel spec dB shape: {mel_spec_db.shape}")
print(f"Mel spec dB range: [{mel_spec_db.min():.2f}, {mel_spec_db.max():.2f}]")
```

### Check Flutter Preprocessing
```dart
// Add this in classifier_service.dart after extractMelSpectrogram
print('Flutter Mel Spec Debug:');
print('Shape: (${melSpec.length}, ${melSpec[0].length})');
print('Sample values:');
for (int i = 0; i < 5; i++) {
  print('  Frame $i: ${melSpec[i].sublist(0, 5)}');
}
```

---

## 📚 References

### Flutter Implementation Files
- `lib/services/audio_processor.dart` - Main preprocessing pipeline
- `lib/services/mel_filterbank.dart` - Mel filterbank implementation
- `lib/services/classifier_service.dart` - TFLite model inference

### Python Libraries Documentation
- **Librosa**: https://librosa.org/doc/latest/index.html
- **librosa.stft**: https://librosa.org/doc/latest/generated/librosa.stft.html
- **librosa.filters.mel**: https://librosa.org/doc/latest/generated/librosa.filters.mel.html
- **librosa.power_to_db**: https://librosa.org/doc/latest/generated/librosa.power_to_db.html

### Mel Scale Formula
- **HTK**: `mel = 2595 * log10(1 + f/700)`
- **Slaney**: Same as HTK but with different filter normalization

---

## 🎯 Expected Outcome

Setelah verifikasi, tim Python harus:

1. ✅ **Konfirmasi bahwa preprocessing Flutter sudah benar** (match dengan training)
   - Jika benar → Masalah ada di model atau data augmentation
   
2. ❌ **Menemukan perbedaan preprocessing**
   - List semua perbedaan yang ditemukan
   - Tentukan mana yang harus diubah (training atau inference)
   - Jika training sudah jadi → **Fix Flutter code**
   - Jika bisa re-train → **Fix training code** agar match Flutter

3. 🔄 **Provide exact Python preprocessing code**
   - Berikan file `.py` dengan fungsi lengkap
   - Include semua parameter dan nilai
   - Saya akan translate ke Flutter dengan exact match

---

## 📞 Contact

Jika ada pertanyaan atau perlu diskusi lebih lanjut:
- Document ini: `PREPROCESSING_VERIFICATION.md`
- Flutter code: `lib/services/audio_processor.dart`
- Test audio: Siapkan 2-3 sample (1 normal, 1 skizofrenia, 1 edge case)

**Goal**: 100% preprocessing match antara training dan inference!

---

*Document created: 2025-11-24*  
*Flutter app version: 1.5.0*  
*TFLite model: audio_classifier_quantized.tflite*
