# 🔬 DEBUGGING OVERCONFIDENCE ISSUE

**Date:** 2025-11-24  
**Issue:** Model predictions always 99-100% confidence (overconfident)  
**Status:** Using Float32 model (not quantized) - still overconfident  

---

## 🎯 PROBLEM STATEMENT

**Symptoms:**
- ✅ Model NO LONGER BIASED (predicts both classes) ✅
- ❌ ALL predictions have 99-100% confidence ❌
- ❌ No uncertain predictions (should have 60-90% range) ❌

**Expected Behavior (Python Streamlit):**
- Confidence varies: 60% to 95%
- Average confidence: ~85%
- Some uncertain cases: 60-75%

**Current Flutter Behavior:**
- ALL cases: 99-100%
- No variation in confidence
- Extremely overconfident

---

## 🔍 ROOT CAUSE ANALYSIS

Since quantization is NOT the issue (using float32 model), the problem must be:

### **Hypothesis #1: Input Preprocessing Scaling Issue** 🔥 MOST LIKELY

**Theory:** Input values might be scaled incorrectly, causing extreme model outputs.

**Possible causes:**

#### A. Values multiplied by 100 (dB scale issue)

**Correct input:**
- Range: `[-80, 0]` dB
- Example values: `[-52.3, -46.5, -50.6, -48.1, ...]`

**If accidentally multiplied:**
- Range: `[-8000, 0]` (wrong!)
- Model sees extreme values → extreme outputs

**Check Flutter code:**
```dart
// Is there any scaling that shouldn't be there?
// Look for:
melSpec[i][j] * 100  // ❌ WRONG
melSpec[i][j] / 100  // ❌ WRONG
```

#### B. Normalization applied when shouldn't be

**Correct:** NO normalization (keep raw dB values)

**If Flutter does:**
```dart
// ❌ WRONG - Min-max normalization
normalized = (value - min) / (max - min);  
// This converts [-80, 0] → [0, 1] → model trained on dB sees [0,1] → confused!
```

**Check:** Make sure NO normalization step after getting dB values.

#### C. Incorrect axis order in reshape

**Correct shape:** `(1, 128, 216, 1)` 
- Axis 0: Batch (1)
- Axis 1: Mels (128)
- Axis 2: Time (216)
- Axis 3: Channels (1)

**If axes swapped:**
```dart
// WRONG: (1, 216, 128, 1) - time and mels swapped!
// Model expects mel patterns over time
// But receives time patterns over mels → confusion → extreme outputs
```

---

### **Hypothesis #2: Model Output Misinterpretation** ⚠️

**Correct interpretation:**

Python model output:
```python
output = model.predict(input)  # Shape: (1, 1)
prob_skizofrenia = float(output[0][0])  # Value in [0, 1]
prob_normal = 1 - prob_skizofrenia
```

**Possible Flutter errors:**

#### Error A: Sigmoid applied twice
```dart
// ❌ WRONG
double rawOutput = output[0][0];  // Already sigmoid output [0, 1]
double prob = 1 / (1 + exp(-rawOutput));  // Applying sigmoid AGAIN!
// If rawOutput = 0.7 → sigmoid(0.7) = 0.668 (goes DOWN not up)
```

#### Error B: Softmax on single output
```dart
// ❌ WRONG - Softmax on 1 value always gives 1.0
double prob = exp(output[0][0]) / exp(output[0][0]);  // Always 1.0!
```

#### Error C: Interpreting logits as probabilities
```dart
// If model outputs logits (pre-sigmoid), need to apply sigmoid:
double logit = output[0][0];
double prob = 1 / (1 + exp(-logit));
```

But our model outputs **probabilities** (post-sigmoid), so this would be wrong!

---

### **Hypothesis #3: Different Model Architecture** 🤔

**Check:** Is Flutter using the EXACT same model file as Streamlit?

**Verify:**
```bash
# Check file hash
md5sum models/best_model.h5                           # Python model
md5sum assets/models/audio_classifier.tflite          # Flutter model (float32)

# Should be converted from same source!
```

If different → re-convert TFLite model!

---

## 🧪 DIAGNOSTIC PROCEDURE

### **STEP 1: Verify Input Values Before Model**

**Add debug logging in Flutter:**

```dart
// In classifier_service.dart, BEFORE model.run():

Future<ClassificationResult> classify(Float32List audioSamples) async {
  // ... preprocessing ...
  
  final input = AudioProcessor.toModelInput(melSpec);
  
  // ========== ADD THIS DEBUG CODE ==========
  print('\n' + '='*60);
  print('DEBUG: Input to Model');
  print('='*60);
  
  // Get statistics
  double minVal = double.infinity;
  double maxVal = double.negativeInfinity;
  double sum = 0;
  int count = 0;
  
  for (var batch in input) {
    for (var mel in batch) {
      for (var time in mel) {
        for (var channel in time) {
          double val = channel;
          if (val < minVal) minVal = val;
          if (val > maxVal) maxVal = val;
          sum += val;
          count++;
        }
      }
    }
  }
  
  double mean = sum / count;
  
  print('Input shape: (${input.length}, ${input[0].length}, ${input[0][0].length}, ${input[0][0][0].length})');
  print('Input min: ${minVal.toStringAsFixed(2)}');
  print('Input max: ${maxVal.toStringAsFixed(2)}');
  print('Input mean: ${mean.toStringAsFixed(2)}');
  
  // Print first 10 values
  List<double> first10 = [];
  for (int i = 0; i < 10 && i < input[0][0].length; i++) {
    first10.add(input[0][0][i][0]);
  }
  print('First 10 time frames (mel band 0): $first10');
  
  print('='*60);
  // ========== END DEBUG CODE ==========
  
  // Run model
  _interpreter!.run(input, output);
  
  // ... rest of code ...
}
```

**Expected output (CORRECT):**
```
============================================================
DEBUG: Input to Model
============================================================
Input shape: (1, 128, 216, 1)
Input min: -80.00
Input max: 0.00
Input mean: -42.50
First 10 time frames: [-52.30, -46.50, -50.60, -48.10, -48.70, -51.20, -49.80, -47.30, -50.10, -48.90]
============================================================
```

**If you see DIFFERENT values:**

| What You See | Problem | Fix |
|--------------|---------|-----|
| Min: 0, Max: 1 | Normalized (WRONG!) | Remove normalization |
| Min: -8000, Max: 0 | Scaled by 100 (WRONG!) | Remove scaling |
| Min: -120, Max: -120 | All same value | Preprocessing broken |
| Shape: (1, 216, 128, 1) | Axes swapped | Fix transpose |

---

### **STEP 2: Verify Model Output**

**Add debug logging AFTER model.run():**

```dart
// After model inference:
_interpreter!.run(input, output);

// ========== ADD THIS DEBUG CODE ==========
print('\n' + '='*60);
print('DEBUG: Model Output');
print('='*60);
print('Raw output shape: (${output.length}, ${output[0].length})');
print('Raw output[0][0]: ${output[0][0]}');
print('Output type: ${output[0][0].runtimeType}');
print('='*60 + '\n');
// ========== END DEBUG CODE ==========

double probSkizofrenia = output[0][0];
// ... rest ...
```

**Expected output (CORRECT):**
```
============================================================
DEBUG: Model Output
============================================================
Raw output shape: (1, 1)
Raw output[0][0]: 0.1234567
Output type: double
============================================================
```

**Test with SAME audio as Python:**

**Python output for reference:**
```python
# Run in Streamlit with SAME audio file:
Raw output: [[0.1234567]]
Prob Skizofrenia: 12.35%
Prob Normal: 87.65%
```

**Flutter should show:**
```
Raw output[0][0]: 0.1234567  ← Should match Python exactly!
```

**If values are VERY different:**

| Python Output | Flutter Output | Problem |
|---------------|----------------|---------|
| 0.12 | 0.99 | Input preprocessing wrong |
| 0.85 | 0.14 | Labels might be swapped |
| 0.50 | 0.99 | Extreme scaling issue |

---

### **STEP 3: Compare Mel Spectrograms Directly**

**Python - Save mel spectrogram:**
```python
import librosa
import numpy as np

audio, sr = librosa.load('test_audio.wav', sr=22050)
mel_spec = extract_mel_spectrogram(audio, sr)

# Save for comparison
np.save('python_mel_debug.npy', mel_spec)

print('Python Mel Spectrogram:')
print(f'  Shape: {mel_spec.shape}')
print(f'  Min: {mel_spec.min():.2f} dB')
print(f'  Max: {mel_spec.max():.2f} dB')
print(f'  Mean: {mel_spec.mean():.2f} dB')
print(f'  First 10 values (mel=0): {mel_spec[0, :10]}')
```

**Flutter - Print mel spectrogram:**
```dart
var melSpec = await AudioProcessor.extractMelSpectrogram(audioSamples);

print('Flutter Mel Spectrogram:');
print('  Shape: (${melSpec[0].length}, ${melSpec.length})');
print('  Min: $minVal dB');
print('  Max: $maxVal dB');
print('  Mean: $meanVal dB');
print('  First 10 values (mel=0): ${melSpec.map((frame) => frame[0]).take(10).toList()}');
```

**Compare:**
- Shapes should match: Python `(128, 216)` = Flutter `(128, 216)`
- Min/Max/Mean should be ±1 dB
- First 10 values should match ±0.5 dB

**If significantly different → preprocessing mismatch still exists!**

---

## 🔧 LIKELY FIXES

### **Fix #1: Remove Accidental Normalization**

Search for ANY of these in Flutter code:

```dart
// REMOVE if found:
(value - min) / (max - min)  // Min-max normalization
(value - mean) / std          // Z-score normalization
value / 255                   // Image-style normalization
value / 100                   // dB scaling
```

**Correct code should have:**
```dart
// Keep raw dB values!
melSpecDB  // No transformation after dB conversion
```

---

### **Fix #2: Verify Transpose/Reshape**

**Check exact reshape logic:**

```dart
static List<List<List<List<double>>>> toModelInput(
  List<List<double>> melSpec,
) {
  // melSpec shape: (216, 128) - time x mels
  
  // CORRECT: Transpose to (128, 216) - mels x time
  List<List<double>> transposed = [];
  for (int i = 0; i < 128; i++) {  // For each mel band
    List<double> row = [];
    for (int j = 0; j < 216; j++) {  // For each time frame
      row.add(melSpec[j][i]);  // ✅ CORRECT access pattern
    }
    transposed.add(row);
  }
  
  // Add batch and channel dimensions
  return [
    transposed.map((row) => 
      row.map((val) => [val]).toList()
    ).toList()
  ];
  
  // Final shape: (1, 128, 216, 1) ✅
}
```

**Verify shape in debug:**
```dart
print('Shape: (${input.length}, ${input[0].length}, ${input[0][0].length}, ${input[0][0][0].length})');
// Must print: Shape: (1, 128, 216, 1)
```

---

### **Fix #3: Check for Double Sigmoid**

**Search Flutter code for sigmoid applications:**

```dart
// Make sure NO sigmoid here:
double probSkizo = output[0][0];  // ✅ Direct use (already sigmoid from model)

// ❌ REMOVE if found:
probSkizo = 1 / (1 + exp(-output[0][0]));  // Double sigmoid!
probSkizo = exp(output[0][0]) / (1 + exp(output[0][0]));  // Another sigmoid!
```

---

## 📊 COMPARISON TABLE

Create this comparison with SAME audio file:

| Metric | Python Value | Flutter Value | Match? | Action |
|--------|-------------|---------------|--------|--------|
| **Mel Spec Min** | -78.45 dB | ??? | | |
| **Mel Spec Max** | 0.00 dB | ??? | | |
| **Mel Spec Mean** | -42.30 dB | ??? | | |
| **Model Input Shape** | (1, 128, 216, 1) | ??? | | |
| **Model Input Min** | -80.00 dB | ??? | | |
| **Model Input Max** | 0.00 dB | ??? | | |
| **Raw Model Output** | 0.1234 | ??? | | |
| **Final Prob Skizo** | 12.34% | ??? | | |

**Fill this table** by running both Python and Flutter on same audio.

---

## 🎯 ACTION ITEMS

### **Priority 1: Add Debug Logging** (15 minutes)

1. Add debug code from STEP 1 (input values)
2. Add debug code from STEP 2 (model output)
3. Run with test audio
4. **Send us the debug output!**

### **Priority 2: Test with Same Audio** (10 minutes)

1. Pick 1 audio file: `test_audio.wav`
2. Run in Python Streamlit → note output
3. Run in Flutter → note output
4. Compare all values
5. **Send us comparison table!**

### **Priority 3: Search for Bugs** (30 minutes)

1. Search for normalization code
2. Check reshape/transpose logic
3. Verify no double sigmoid
4. Check for any scaling (×100, /100, etc.)

---

## 📝 INFORMATION NEEDED FROM FLUTTER TEAM

Please provide:

### **1. Debug Output**

Run the debug code and paste full output:

```
============================================================
DEBUG: Input to Model
============================================================
Input shape: ???
Input min: ???
Input max: ???
Input mean: ???
First 10 time frames: ???
============================================================

============================================================
DEBUG: Model Output
============================================================
Raw output shape: ???
Raw output[0][0]: ???
============================================================
```

### **2. Comparison with Python**

Using EXACT same audio file:

```
Audio file: test_audio.wav

Python (Streamlit):
  Mel spec min: ???
  Mel spec max: ???
  Model output: ???
  Prediction: ??? (??%)

Flutter:
  Mel spec min: ???
  Mel spec max: ???
  Model output: ???
  Prediction: ??? (??%)
```

### **3. Code Snippets**

Show exact code for:

**A. Model input preparation:**
```dart
// How do you create input?
final input = AudioProcessor.toModelInput(melSpec);
// Show full toModelInput() function
```

**B. Model output interpretation:**
```dart
// How do you interpret output?
double probSkizo = ???;  // Show exact line
```

---

## 💡 EXPECTED RESOLUTION

Once we see the debug output, we can immediately identify:

1. ✅ **If values are correct** → problem is in interpretation
2. ✅ **If values are wrong** → problem is in preprocessing
3. ✅ **If shape is wrong** → problem is in reshape/transpose

**With this info, we can give EXACT fix in <30 minutes!**

---

## 🚨 CRITICAL QUESTIONS

### Q1: Are input dB values in correct range?

**Expected:** `[-80, 0]` dB  
**Your Flutter:** `???`

### Q2: Is model output a reasonable probability?

**Expected:** `[0.0, 1.0]` range, varied values  
**Your Flutter:** `???`

### Q3: Does Flutter output match Python on same audio?

**Expected:** Same within ±0.01  
**Your Flutter:** `???`

---

**Please run the debug code and send us the outputs!**

We can solve this quickly once we see the actual values! 🔍

---

*Document created: 2025-11-24*  
*Purpose: Debug overconfidence issue*  
*Next: Waiting for Flutter team's debug output*
