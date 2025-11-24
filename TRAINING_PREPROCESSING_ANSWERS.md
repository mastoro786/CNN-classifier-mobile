# 🔬 TRAINING PREPROCESSING - EXACT ANSWERS

**Date:** 2025-11-24  
**Responding to:** QUICK_FIX_RESULTS.md  
**Status:** ✅ ALL CRITICAL QUESTIONS ANSWERED

---

## 🎯 EXECUTIVE SUMMARY

Flutter team benar! **Padding fix saja tidak cukup** karena:

1. ✅ Test audio semua **> 216 frames** → tidak ada padding yang executed
2. ⚠️ Ada **4 critical mismatches** lainnya yang harus di-fix
3. 🚨 **STFT center padding adalah masalah terbesar!**

---

## 📋 ANSWERS TO CRITICAL QUESTIONS

### ✅ **Question 1: STFT Center Padding**

**Answer:** Librosa **default menggunakan `center=True`**!

**Python Training Code (Line 49):**
```python
mel_spec = librosa.feature.melspectrogram(y=y, sr=sr, n_mels=N_MELS, fmax=FMAX)
# ↓ Internally calls:
# librosa.stft(y, n_fft=2048, hop_length=512, center=True)  ← DEFAULT!
```

**Detail:** `librosa.feature.melspectrogram` **tidak specify `center` parameter**, jadi menggunakan **default = `True`**!

**Impact:**
- Python: `center=True` → Audio di-pad dengan reflection di awal dan akhir
- Flutter: `center=False` → No padding
- **MAJOR MISMATCH!** Frame alignment berbeda total!

**Flutter MUST CHANGE!**

---

### ✅ **Question 2: Truncation Method**

**Answer:** **Take FIRST 216 frames** (same as Flutter ✅)

**Python Training Code (Line 56):**
```python
else:
    mel_spec_db = mel_spec_db[:, :MAX_LEN]  # Take first MAX_LEN (216) time frames
```

**Explanation:**
- Python shape: `(128, time_frames)` (mels x time)
- `[:, :MAX_LEN]` = Keep all 128 mels, take first 216 time frames
- Flutter equivalent: `spec.sublist(0, targetLen)` ✅ **CORRECT!**

**No change needed for Flutter.**

---

### ✅ **Question 3: FFT Bins**

**Answer:** **Librosa returns 1025 bins, but mel filterbank handles it**

**How librosa works:**
```python
# Step 1: STFT
stft = librosa.stft(y, n_fft=2048)  
# Returns shape: (1025, time_frames) ← 1025 bins (includes Nyquist)

# Step 2: Mel filterbank
mel_filters = librosa.filters.mel(n_fft=2048, n_mels=128)
# Creates filters of shape: (128, 1025) ← Designed for 1025 bins

# Step 3: Apply filters
mel_spec = np.dot(mel_filters, power_spectrum)
# Result: (128, time_frames)
```

**Key Point:** Mel filterbank automatically adapts to 1025 bins!

**Flutter Issue:** 
- Flutter uses **1024 bins** (fftSize / 2)
- Should use **1025 bins** (fftSize / 2 + 1) to match librosa!

**Flutter MUST CHANGE!**

---

### ✅ **Question 4: Mel Filter Normalization**

**Answer:** **Librosa default uses `norm=None`** (no normalization)

**Python equivalent:**
```python
mel_filters = librosa.filters.mel(
    sr=22050,
    n_fft=2048,
    n_mels=128,
    fmin=0.0,
    fmax=8000,
    norm=None  # ← Librosa default when not specified!
)
```

**Flutter implementation:** Already correct ✅ (no normalization)

**No change needed.**

---

## 🔧 EXACT TRAINING PREPROCESSING CODE

Here's the **COMPLETE** preprocessing function matching our training:

```python
import librosa
import numpy as np

# Configuration
SAMPLE_RATE = 22050
N_MELS = 128
FMAX = 8000
MAX_LEN = 216

def preprocess_audio_for_training(audio_path):
    """
    EXACT preprocessing function used during training.
    Returns shape: (1, 128, 216, 1)
    """
    # 1. Load audio
    audio, sr = librosa.load(audio_path, sr=SAMPLE_RATE, mono=True)
    # Returns: float32 array, values in [-1, 1]
    
    # 2. Extract mel spectrogram
    # Uses librosa DEFAULTS:
    # - n_fft=2048 (librosa default)
    # - hop_length=512 (librosa default = n_fft/4)
    # - center=True (librosa DEFAULT!) ← CRITICAL!
    # - window='hann'
    # - power=2.0 (power spectrum, not magnitude)
    mel_spec = librosa.feature.melspectrogram(
        y=audio, 
        sr=sr, 
        n_mels=N_MELS, 
        fmax=FMAX
        # NOT specifying: n_fft, hop_length, center, window
        # So ALL use librosa DEFAULTS!
    )
    # Returns shape: (128, time_frames)
    # Values: Power spectrum (S²)
    
    # 3. Convert to dB scale
    mel_spec_db = librosa.power_to_db(
        mel_spec, 
        ref=np.max  # Reference = maximum value in spectrogram
        # NOT specifying: amin (default=1e-10), top_db (default=80.0)
    )
    # Returns shape: (128, time_frames)
    # Values: dB scale, clipped to [max-80, 0] dB
    # (librosa clips to top_db=80 by default!)
    
    # 4. Pad or truncate to fixed length
    if mel_spec_db.shape[1] < MAX_LEN:
        # Short audio: Pad along time axis (axis 1)
        pad_width = MAX_LEN - mel_spec_db.shape[1]
        mel_spec_db = np.pad(
            mel_spec_db, 
            pad_width=((0, 0), (0, pad_width)), 
            mode='constant'
            # NOT specifying constant_values, so default=0.0
        )
    else:
        # Long audio: Truncate to first MAX_LEN frames
        mel_spec_db = mel_spec_db[:, :MAX_LEN]
    # Result shape: (128, 216)
    
    # 5. NO NORMALIZATION! Keep raw dB values
    # (NO min-max scaling, NO z-score)
    
    # 6. Reshape for model input
    # From (128, 216) to (1, 128, 216, 1)
    input_tensor = mel_spec_db[np.newaxis, ..., np.newaxis]
    # Final shape: (1, 128, 216, 1)
    #              (batch, mels, time, channels)
    
    return input_tensor
```

---

## 🚨 CRITICAL FIXES NEEDED FOR FLUTTER

### **FIX #1: STFT Center Padding** 🔥 **HIGHEST PRIORITY**

**Impact:** MAJOR - Causes frame misalignment

**Current Flutter (WRONG):**
```dart
// No center padding
for (int i = 0; i < numFrames; i++) {
  start = i * hopLength;
  end = start + fftSize;
  // Extract frame directly from audio
  frame = audioSamples[start:end];
}
```

**Required Flutter (CORRECT):**
```dart
// ADD center padding like librosa
Float32List paddedAudio = _addCenterPadding(audioSamples, fftSize);

// Then compute STFT on padded audio
for (int i = 0; i < numFrames; i++) {
  start = i * hopLength;
  end = start + fftSize;
  frame = paddedAudio[start:end];
}

// Helper function:
static Float32List _addCenterPadding(Float32List audio, int nfft) {
  int padLength = nfft ~/ 2;
  Float32List padded = Float32List(audio.length + nfft);
  
  // Pad left with reflection
  for (int i = 0; i < padLength; i++) {
    padded[i] = audio[padLength - i];
  }
  
  // Copy original audio
  for (int i = 0; i < audio.length; i++) {
    padded[padLength + i] = audio[i];
  }
  
  // Pad right with reflection
  for (int i = 0; i < padLength; i++) {
    padded[padLength + audio.length + i] = audio[audio.length - 1 - i];
  }
  
  return padded;
}
```

---

### **FIX #2: FFT Bins Count** 📊

**Impact:** MEDIUM - Affects mel filterbank frequency mapping

**Current Flutter (WRONG):**
```dart
for (int k = 0; k < fftSize ~/ 2; k++) {  // 1024 bins
  power.add(real * real + imag * imag);
}
```

**Required Flutter (CORRECT):**
```dart
for (int k = 0; k < fftSize ~/ 2 + 1; k++) {  // 1025 bins (includes Nyquist)
  double real = fftResult[k].x;
  double imag = fftResult[k].y;
  power.add(real * real + imag * imag);
}
```

**Also update mel filterbank:**
```dart
melFilters = MelFilterbank.createMelFilterbank(
  nfft: fftSize,  // 2048
  nMels: nMels,   // 128
  sampleRate: sampleRate,
  fMin: 0.0,
  fMax: fMax.toDouble(),
);
// Should create filters of shape (128, 1025) not (128, 1024)!
```

---

### **FIX #3: Top dB Clipping** 📉

**Impact:** MEDIUM - librosa clips to 80 dB range by default

**Current Flutter (WRONG):**
```dart
// No clipping
db = 10.0 * log10(max(value, 1e-10) / refPower);
```

**Required Flutter (CORRECT):**
```dart
// Apply top_db clipping like librosa
db = 10.0 * log10(max(value, 1e-10) / refPower);

// Clip to max - 80 dB (librosa default)
double maxDb = 0.0;  // Because ref=max
if (db < maxDb - 80.0) {
  db = maxDb - 80.0;
}
```

---

### **FIX #4: Padding Value** ✅ Already Applied

Already fixed (use 0.0), but not tested because test audio was too long.

---

## 📊 LIBROSA DEFAULTS REFERENCE

| Parameter | Librosa Default | Used in Training | Flutter Current | Match? |
|-----------|----------------|------------------|-----------------|--------|
| `sr` | 22050 | 22050 | 22050 | ✅ |
| `n_fft` | 2048 | 2048 | 2048 | ✅ |
| `hop_length` | n_fft/4 = 512 | 512 | 512 | ✅ |
| `center` | **True** | **True** | **False** | ❌ **CRITICAL!** |
| `window` | 'hann' | 'hann' | 'hann' | ✅ |
| `n_mels` | 128 | 128 | 128 | ✅ |
| `fmax` | sr/2 | 8000 | 8000 | ✅ |
| `power` | 2.0 (S²) | 2.0 | 2.0 (real²+imag²) | ✅ |
| `ref` for dB | 1.0 | np.max | max | ✅ |
| `amin` | 1e-10 | 1e-10 | 1e-10 | ✅ |
| `top_db` | **80.0** | **80.0** | **None** | ❌ |
| FFT bins | **1025** | **1025** | **1024** | ❌ |
| `norm` (mel) | None | None | None | ✅ |
| Padding value | 0.0 | 0.0 | 0.0 (fixed) | ✅ |

**Critical mismatches:** 3 items (center, top_db, FFT bins)

---

## 🎯 PRIORITY ORDER

1. 🔥 **FIX CENTER PADDING** - Highest impact, causes frame shift
2. 📊 **FIX FFT BINS** - Medium impact, affects frequency mapping  
3. 📉 **FIX TOP_DB CLIPPING** - Medium impact, affects dB range
4. ✅ **PADDING VALUE** - Already fixed

---

## 🧪 TESTING STRATEGY

### After applying fixes, test with:

1. **Same audio file** in Python and Flutter
2. **Save intermediate outputs:**

**Python:**
```python
mel_spec = extract_mel_spectrogram(audio, sr)
np.save('python_mel.npy', mel_spec)
print(f"Shape: {mel_spec.shape}")  # (128, 216)
print(f"Min: {mel_spec.min():.2f}")
print(f"Max: {mel_spec.max():.2f}")
print(f"Sample values: {mel_spec[0, :5]}")
```

**Flutter:**
```dart
var melSpec = await AudioProcessor.extractMelSpectrogram(audioSamples);
print('Shape: (${melSpec[0].length}, ${melSpec.length})');  // Should be (128, 216)
print('Min: $minVal');
print('Max: $maxVal');
print('Sample values: ${melSpec[0].sublist(0, 5)}');
```

3. **Compare outputs:**
   - Shapes should match: (128, 216)
   - Values should match within **0.1 dB**
   - First 10 values should be nearly identical

---

## 📁 NEXT STEPS

1. ✅ **Python team:** Document provided (this file)
2. 🔄 **Flutter team:** Apply 3 critical fixes
3. 🧪 **Both teams:** Test with same audio and compare outputs
4. ✅ **Deploy:** Once outputs match within 0.1 dB

---

## 💡 WHY STILL BIASED EVEN WITH PADDING FIX?

**Root cause:** **STFT center padding mismatch!**

When `center=True` (Python) vs `center=False` (Flutter):
- **Python:** Audio is `[reflected_left | original_audio | reflected_right]`
- **Flutter:** Audio is `[original_audio]` only
- **Result:** Frame 0 in Python ≠ Frame 0 in Flutter!
- **Impact:** ENTIRE spectrogram shifted → Model sees different features → Wrong predictions!

**Analogy:** Seperti membaca buku dari halaman 1 (Flutter) vs halaman 0 (Python dengan negative page numbers dari reflection). Isi yang dibaca berbeda total!

---

*Document created: 2025-11-24*  
*Python code verified from: app_optimized.py*  
*Librosa version: Latest defaults documented*  
*Status: ✅ COMPLETE - ALL QUESTIONS ANSWERED*
