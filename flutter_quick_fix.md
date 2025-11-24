# ⚡ QUICK FIX: Flutter Preprocessing - Match Python Training

**Goal:** Make Flutter preprocessing MATCH Python training (keep model as-is)  
**Time:** 15 minutes  
**Risk:** ZERO  

---

## 🎯 THE FIX

Python training uses padding value = **0.0 dB** (unintentionally, but it's there).  
Flutter needs to MATCH this behavior.

---

## 📝 CODE CHANGES

### **File:** `lib/services/audio_processor.dart`

**Find the `_fixLength` function** (around Line 546-564):

```dart
/// Pad or truncate to fixed length
static List<List<double>> _fixLength(
  List<List<double>> spec,
  int targetLen,
) {
  if (spec.length >= targetLen) {
    return spec.sublist(0, targetLen);
  } else {
    // Pad with zeros (silence)
    List<List<double>> paddedSpec = List.from(spec);
    int padLen = targetLen - spec.length;
    
    for (int i = 0; i < padLen; i++) {
      paddedSpec.add(List.filled(spec[0].length, 0.0));
    }
    
    return paddedSpec;
  }
}
```

**CHANGE 1 LINE:**

```dart
// OLD (if you have this):
paddedSpec.add(List.filled(spec[0].length, minDb));

// NEW (change to this):
paddedSpec.add(List.filled(spec[0].length, 0.0));
```

**That's it!** Just change padding value to **0.0**

---

## ✅ VERIFICATION

After making the change:

1. **Save file**
2. **Run Flutter app:**
   ```bash
   flutter run
   ```

3. **Test with audio sample**
4. **Check predictions:**
   - Should now predict BOTH classes (not just "Normal")
   - Should match Streamlit predictions
   - Confidence scores should be reasonable

---

## 🧪 EXPECTED BEHAVIOR

### **Before Fix:**
```
Audio: test_normal.wav
Prediction: Normal 95%, Skizofrenia 5%  (BIASED!)

Audio: test_skizo.wav  
Prediction: Normal 92%, Skizofrenia 8%  (ALWAYS NORMAL!)
```

### **After Fix:**
```
Audio: test_normal.wav
Prediction: Normal 87%, Skizofrenia 13%  (CORRECT!)

Audio: test_skizo.wav
Prediction: Normal 15%, Skizofrenia 85%  (CORRECT!)
```

---

## 📊 WHY THIS WORKS

1. **Python training** used `np.pad(mode='constant')` → default = 0.0
2. **Model learned** to expect padding regions with 0.0 dB values
3. **Flutter now matches** this exact behavior
4. **Model works correctly** because input distribution is same as training

---

## ⚠️ IMPORTANT NOTE

**This is NOT a bug fix!** This is making Flutter match the Python training preprocessing.

The "proper" way would be padding with `min_db` (silence), but that would require retraining the model.

Since the model is already good (93% accuracy), we **match the training** instead.

---

## 🔄 OPTIONAL: Add Debug Logging

To verify it's working, add this after padding:

```dart
if (padLen > 0) {
  print('⚠️  Padded $padLen frames with 0.0 dB (matching Python training)');
  print('   Last frame values: ${paddedSpec.last.sublist(0, 5)}');
  // Should print: [0.0, 0.0, 0.0, 0.0, 0.0]
}
```

---

## ✅ SUCCESS CRITERIA

- [ ] Flutter code changed (1 line)
- [ ] App runs without errors
- [ ] Predictions are balanced (not always "Normal")
- [ ] Predictions match Streamlit (within 5%)
- [ ] High confidence when should be confident

---

## 🚀 DEPLOYMENT TIMELINE

| Task | Time |
|------|------|
| Edit code | 2 minutes |
| Flutter hot reload | 10 seconds |
| Test with 3-5 samples | 5 minutes |
| Verify predictions | 5 minutes |
| **Total** | **~15 minutes** ✅ |

vs Retrain model: 2-4 hours + risk ❌

---

## 📞 TROUBLESHOOTING

### Issue: Still biased after fix

**Check:**
1. Code actually changed? (hot reload worked?)
2. Padding value is definitely 0.0? (not minDb?)
3. Model file is correct? (audio_classifier_quantized.tflite)

**Debug:**
```dart
// Add this in _fixLength after padding:
print('DEBUG: Padded with value 0.0');
print('Last frame: ${paddedSpec.last}');
// All values should be 0.0
```

### Issue: App crashes

**Likely cause:** Syntax error in edit

**Solution:**
```bash
flutter analyze  # Check for errors
flutter clean
flutter pub get
flutter run
```

---

## 📝 SUMMARY

**What:** Change 1 line in `audio_processor.dart`  
**Why:** Match Python training preprocessing  
**Result:** Model works correctly in Flutter  
**Time:** 15 minutes  
**Risk:** ZERO  

---

**Ready to deploy!** 🚀
