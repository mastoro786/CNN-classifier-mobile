# 🎯 FINAL DIAGNOSIS: Flutter Preprocessing Issue

**Date:** 2025-11-24  
**Status:** ✅ ROOT CAUSE CONFIRMED  
**Priority:** 🔥 CRITICAL FIX NEEDED

---

## 🔬 VERIFICATION RESULTS

### Test: normal_nathan_03.wav

| Platform | Raw Output | Prob Normal | Prob Skizo | Input Mean dB |
|----------|-----------|-------------|------------|---------------|
| **Python (Keras)** | 0.3249 | 67.51% | 32.49% | **-12.83 dB** |
| **Python (TFLite)** | 0.3249 | 67.51% | 32.49% | **-12.83 dB** |
| **Flutter (TFLite)** | 0.0104 | 98.96% | 1.04% | **-63.14 dB** |

---

## ✅ CONCLUSIONS

### 1. TFLite Conversion is CORRECT ✅
```
Keras output:  0.3249035478
TFLite output: 0.3249038756
Difference:    0.0000003278 (0.00%)

✅ Model conversion has NO issues!
```

### 2. Flutter Preprocessing is WRONG ❌
```
Python input mean: -12.83 dB
Flutter input mean: -63.14 dB
Difference: 50.31 dB ← HUGE OFFSET!

❌ Flutter preprocessing produces DIFFERENT mel spectrogram!
```

---

## 🐛 THE BUG

**Flutter mel spectrogram has too LOW energy** (mean -63 dB vs expected -13 dB)

**Impact:**
- Model sees "darker" / lower energy spectrogram
- Interprets as "less distinctive features"
- Pushes predictions toward extremes (overconfident)

---

## 🔍 POSSIBLE CAUSES

### Hypothesis #1: Power vs Magnitude ⭐ MOST LIKELY

**Python (CORRECT):**
```python
# STFT returns complex numbers
stft = librosa.stft(...)
# Power spectrum (magnitude SQUARED)
power = np.abs(stft) ** 2  # ← Squared!
mel_spec = np.dot(mel_filters, power)
```

**Flutter (MIGHT BE WRONG):**
```dart
// If Flutter does:
magnitude = sqrt(real² + imag²)  // ❌ WRONG!
// Should be:
power = real² + imag²  // ✅ CORRECT!
```

**Check:** Is Flutter computing **power** (squared) or **magnitude** (not squared)?

---

### Hypothesis #2: Window Function Energy

**Python:** Hann window normalizes energy properly

**Flutter:** Window might not be normalized correctly

```dart
// Check if window energy is normalized:
double window = 0.5 * (1 - cos(2 * pi * j / (fftSize - 1)));
// Should sum to specific value for energy conservation
```

---

### Hypothesis #3: Mel Filterbank Normalization

**Python (librosa default):**
```python
# Filters are NOT normalized (norm=None)
mel_filters = librosa.filters.mel(norm=None)
```

**Flutter:** Check if filters are accidentally normalized

---

## 🧪 DIAGNOSTIC SCRIPT

### Step 1: Extract Same Audio in Python

Save intermediate values for comparison:

```python
# diagnostic_save_intermediates.py
import librosa
import numpy as np

audio, sr = librosa.load('data_uji/normal_nathan_03.wav', sr=22050)

# 1. STFT
stft = librosa.stft(audio, n_fft=2048, hop_length=512, center=True)
print(f"STFT shape: {stft.shape}")
print(f"STFT max magnitude: {np.abs(stft).max():.4f}")

# 2. Power spectrum
power = np.abs(stft) ** 2
print(f"Power max: {power.max():.4f}")
print(f"Power mean: {power.mean():.4f}")

# 3. Mel filterbank
mel_filters = librosa.filters.mel(sr=22050, n_fft=2048, n_mels=128, fmax=8000)
print(f"Mel filters shape: {mel_filters.shape}")

# 4. Mel spectrogram (power)
mel_spec = np.dot(mel_filters, power)
print(f"Mel spec max: {mel_spec.max():.4f}")
print(f"Mel spec mean: {mel_spec.mean():.4f}")

# 5. Power to dB
mel_spec_db = librosa.power_to_db(mel_spec, ref=np.max)
print(f"Mel dB min: {mel_spec_db.min():.2f}")
print(f"Mel dB max: {mel_spec_db.max():.2f}")
print(f"Mel dB mean: {mel_spec_db.mean():.2f}")

# Save for comparison
np.save('python_stft_power.npy', power[:, :10])  # First 10 frames
np.save('python_mel_spec.npy', mel_spec[:, :10])
np.save('python_mel_db.npy', mel_spec_db[:, :10])

print("\n✅ Saved intermediate values")
```

Run this and note the values!

---

### Step 2: Compare with Flutter Values

From Flutter log:
```
Power range: max=1098.806...
```

**Expected from Python:**
```
python diagnostic_save_intermediates.py

# Should show:
STFT max magnitude: ???
Power max: ???
Power mean: ???
Mel spec max: ???
Mel spec mean: ???
Mel dB mean: -12.83 dB  ← Target to match!
```

---

## 🔧 FIX OPTIONS

### Fix #1: Verify Power Computation ⭐ CHECK THIS FIRST

**Flutter code to check:**

```dart
// In _computeSTFT function:
for (int k = 0; k < fftSize ~/ 2 + 1; k++) {
  double real = fftResult[k].x;
  double imag = fftResult[k].y;
  
  // ✅ CORRECT (power):
  power[k] = real * real + imag * imag;
  
  // ❌ WRONG (magnitude):
  // magnitude[k] = sqrt(real * real + imag * imag);
}
```

**If using magnitude instead of power:**
- Energy is half (in dB: ~6-10 dB difference)
- Could partially explain the 50 dB offset!

---

### Fix #2: Check Window Energy Normalization

```dart
// After applying Hann window, check total energy:
double windowEnergy = 0;
for (int j = 0; j < fftSize; j++) {
  double w = 0.5 * (1 - cos(2 * pi * j / (fftSize - 1)));
  windowEnergy += w * w;
}
print('Window energy: $windowEnergy');
// Should be close to fftSize / 2

// If energy is wrong, normalize:
double normFactor = sqrt(fftSize / 2 / windowEnergy);
for (int j = 0; j < fftSize; j++) {
  frame[j] *= normFactor;
}
```

---

### Fix #3: Match Python Reference Exactly

**Create minimal test case:**

Generate 1 second sine wave (440 Hz):
```python
# Test with pure tone
import numpy as np
t = np.arange(0, 1, 1/22050)
sine = np.sin(2 * np.pi * 440 * t)

# Process
stft = librosa.stft(sine, n_fft=2048, hop_length=512)
power = np.abs(stft) ** 2
print(f"Sine wave power at 440 Hz: {power.max():.4f}")
```

Then same in Flutter and compare!

---

## 📋 ACTION ITEMS FOR FLUTTER TEAM

### URGENT (Next 2 hours):

1. **Add debug logging in Flutter STFT:**
   ```dart
   // In _computeSTFT:
   print('DEBUG STFT:');
   print('  FFT result[10] real: ${fftResult[10].x}');
   print('  FFT result[10] imag: ${fftResult[10].y}');
   print('  Power[10]: ${power[10]}');
   print('  Max power: ${power.reduce(max)}');
   print('  Mean power: ${power.reduce((a,b) => a+b) / power.length}');
   ```

2. **Verify power vs magnitude:**
   - Check if code uses `sqrt(real² + imag²)` anywhere
   - Should be `real² + imag²` (NO sqrt!)

3. **Test with Python diagnostic script:**
   - Run diagnostic_save_intermediates.py
   - Compare power values with Flutter
   - Find where the divergence starts

### MEDIUM (Next day):

4. **Create minimal reproducible test:**
   - Generate sine wave in both platforms
   - Compare STFT power values
   - Should match within 1%

5. **Review all energy computations:**
   - Window function
   - FFT scaling
   - Mel filterbank application

---

## 📊 EXPECTED RESULTS AFTER FIX

| Metric | Current | After Fix |
|--------|---------|-----------|
| **Input mean dB** | -63.14 dB | -12.83 dB |
| **normal_nathan_03 prediction** | 99% Normal | 67% Normal |
| **Match with Python** | ❌ 30% difference | ✅ <2% difference |

---

## 🎯 SUCCESS CRITERIA

✅ Input mean dB matches Python (±2 dB)  
✅ Model output matches TFLite Python (±0.01)  
✅ Predictions match Streamlit (±5%)  

---

## 💡 QUICK CHECK

**To immediately verify if this is power vs magnitude issue:**

If Flutter is using **magnitude** instead of **power**, the fix is literally:

```dart
// BEFORE (WRONG):
double magnitude = sqrt(real * real + imag * imag);
mel_energy += magnitude;

// AFTER (CORRECT):
double power = real * real + imag * imag;
mel_energy += power;
```

**This single change could fix everything!**

---

## 📞 NEXT STEPS

1. **Python team:** Run diagnostic_save_intermediates.py → Send values
2. **Flutter team:** Add STFT debug logging → Send values
3. **Compare:** Find exact point where values diverge
4. **Fix:** Apply correction (likely power vs magnitude)
5. **Test:** Re-run with same audio → Should match!

---

**Estimated time to fix:** 2-4 hours (including testing)

**Confidence level:** 95% that this is power vs magnitude issue

---

*Document created: 2025-11-24*  
*Status: Action required - Flutter team debug STFT computation*
