import 'dart:typed_data';
import 'dart:math';
import 'package:fftea/fftea.dart';
import 'mel_filterbank.dart';

/// FIXED Audio Processor - Matches Python Preprocessing
/// 
/// This version fixes the bias issue by:
/// 1. Using proper Mel filterbank (librosa-compatible)
/// 2. Removing incorrect normalization
/// 3. Using correct dB conversion with max reference
class AudioProcessor {
  // Configuration matching Python preprocessing
  static const int sampleRate = 22050;
  static const int nMels = 128;
  static const int maxLen = 216;
  static const int fftSize = 2048;
  static const int hopLength = 512;
  static const int fMax = 8000;
  
  // Cache Mel filterbank (compute once)
  static List<List<double>>? _cachedMelFilters;
  
  /// Extract Mel Spectrogram - FIXED VERSION
  static Future<List<List<double>>> extractMelSpectrogram(
    Float32List audioSamples,
  ) async {
    print('📊 Extracting Mel Spectrogram (FIXED)...');
    print('   Sample rate: $sampleRate Hz');
    print('   Audio length: ${audioSamples.length} samples');
    
    // 1. STFT (Short-Time Fourier Transform)
    List<List<double>> stft = await _computeSTFT(audioSamples);
    print('   STFT shape: ${stft.length} x ${stft[0].length}');
    
    // 2. Create Mel filterbank (cache it!)
    _cachedMelFilters ??= MelFilterbank.createMelFilterbank(
      nfft: fftSize,
      nMels: nMels,
      sampleRate: sampleRate,
      fMin: 0.0,
      fMax: fMax.toDouble(),
    );
    print('   Mel filters: ${_cachedMelFilters!.length} x ${_cachedMelFilters![0].length} (bands x bins)');
    
    // 3. Apply Mel filterbank
    List<List<double>> melSpec = MelFilterbank.applyFilterbank(
      stft,
      _cachedMelFilters!,
    );
    print('   Mel spec shape: ${melSpec.length} x ${melSpec[0].length}');
    
    // DEBUG: Mel spec power statistics
    double melMax = double.negativeInfinity;
    double melMin = double.infinity;
    double melSum = 0;
    int melCount = 0;
    for (var frame in melSpec) {
      for (var value in frame) {
        if (value > melMax) melMax = value;
        if (value < melMin) melMin = value;
        melSum += value;
        melCount++;
      }
    }
    print('🔬 DEBUG Mel Spec (POWER):');
    print('   Max: ${melMax.toStringAsFixed(4)}');
    print('   Mean: ${(melSum / melCount).toStringAsFixed(4)}');
    print('   Min: ${melMin.toStringAsFixed(4)}');
    
    // 4. Convert to dB scale (librosa-style: ref=max)
    List<List<double>> melSpecDB = _powerToDbLibrosa(melSpec);
    
    // 5. NO NORMALIZATION! (Python doesn't normalize to [0,1])
    // Direct pad/truncate
    List<List<double>> fixed = _fixLength(melSpecDB, maxLen);
    print('   Final shape: ${fixed.length} x ${fixed[0].length}');
    
    // Debug: Print value range
    _printValueStats(fixed);
    
    return fixed;
  }
  
  /// Add center padding (librosa center=True equivalent)
  /// 
  /// Pads audio with reflection at start and end
  /// Padding length = n_fft / 2 = 1024 samples
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
  
  /// Compute Short-Time Fourier Transform with center padding
  static Future<List<List<double>>> _computeSTFT(Float32List audio) async {
    List<List<double>> stft = [];
    
    // CRITICAL FIX #1: Add center padding (matching librosa center=True)
    Float32List paddedAudio = _addCenterPadding(audio, fftSize);
    print('   Center padding: ${audio.length} → ${paddedAudio.length} samples');
    
    final numFrames = ((paddedAudio.length - fftSize) ~/ hopLength) + 1;
    final fftInstance = FFT(fftSize);
    
    for (int i = 0; i < numFrames; i++) {
      final start = i * hopLength;
      final end = min(start + fftSize, paddedAudio.length);
      
      // Extract frame
      List<double> frame = List.filled(fftSize, 0.0);
      for (int j = 0; j < end - start; j++) {
        // Apply Hann window
        double window = 0.5 * (1 - cos(2 * pi * j / (fftSize - 1)));
        frame[j] = paddedAudio[start + j] * window;
      }
      
      // Compute FFT using fftea
      final Float64x2List fftResult = fftInstance.realFft(frame);
      
      // CRITICAL FIX #2: Compute power with 1025 bins (include Nyquist)
      // Librosa returns (n_fft/2 + 1) bins, not (n_fft/2)
      List<double> power = [];
      for (int k = 0; k < fftSize ~/ 2 + 1; k++) {
        double real = fftResult[k].x;
        double imag = fftResult[k].y;
        // Power spectrum (not just magnitude)
        power.add(real * real + imag * imag);
      }
      
      // DEBUG: Log first frame's power values
      if (i == 0) {
        print('\n🔬 DEBUG STFT (First Frame):');
        print('   FFT result[10] real: ${fftResult[10].x.toStringAsFixed(6)}');
        print('   FFT result[10] imag: ${fftResult[10].y.toStringAsFixed(6)}');
        print('   Power[10]: ${power[10].toStringAsFixed(6)}');
        double maxPwr = power.reduce(max);
        double sumPwr = power.reduce((a, b) => a + b);
        print('   Max power: ${maxPwr.toStringAsFixed(4)}');
        print('   Mean power: ${(sumPwr / power.length).toStringAsFixed(4)}');
      }
      
      stft.add(power);
    }
    
    return stft;
  }
  
  /// Convert power to dB - Librosa style (ref=np.max)
  /// 
  /// Formula: 10 * log10(S / ref)
  /// where ref = max(S) to match librosa.power_to_db(ref=np.max)
  static List<List<double>> _powerToDbLibrosa(List<List<double>> spec) {
    // Find maximum value in entire spectrogram
    double maxPower = double.negativeInfinity;
    for (var frame in spec) {
      for (var value in frame) {
        if (value > maxPower) maxPower = value;
      }
    }
    
    // Use max as reference (matching Python)
    double refPower = max(maxPower, 1e-10);  // Avoid log(0)
    
    print('   Power range: max=$maxPower, ref=$refPower');
    
    List<List<double>> dbSpec = [];
    double maxDb = 0.0; // Because ref=max, max dB is always 0
    
    for (var frame in spec) {
      List<double> dbFrame = frame.map((value) {
        // librosa formula: 10 * log10(S / ref)
        double db = 10.0 * log(max(value, 1e-10) / refPower) / ln10;
        
        // CRITICAL FIX #3: Apply top_db clipping (librosa default = 80)
        // Clip values below (max - 80) dB
        if (db < maxDb - 80.0) {
          db = maxDb - 80.0;
        }
        
        return db;
      }).toList();
      dbSpec.add(dbFrame);
    }
    
    return dbSpec;
  }
  
  /// Pad or truncate to fixed length
  static List<List<double>> _fixLength(
    List<List<double>> spec,
    int targetLen,
  ) {
    if (spec.length >= targetLen) {
      return spec.sublist(0, targetLen);
    } else {
      // Pad with 0.0 dB (MATCHING PYTHON TRAINING)
      // Python training used np.pad(mode='constant', constant_values=0.0)
      // Model learned to expect padding regions with 0.0 dB values
      List<List<double>> paddedSpec = List.from(spec);
      int padLen = targetLen - spec.length;
      
      print('   ⚠️  Padding $padLen frames with 0.0 dB (matching Python training)');
      
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
    var input = [
      transposed.map((row) => 
        row.map((val) => [val]).toList()
      ).toList()
    ];
    
    print('   Model input shape: (${input.length}, ${input[0].length}, ${input[0][0].length}, ${input[0][0][0].length})');
    
    // Debug: Print sample input values
    print('   Sample input values (first 10):');
    for (int i = 0; i < min(10, transposed[0].length); i++) {
      print('      [0][0][$i][0] = ${transposed[0][i].toStringAsFixed(2)}');
    }
    
    return input;
  }
  
  /// Debug: Print value statistics
  static void _printValueStats(List<List<double>> spec) {
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sum = 0;
    int count = 0;
    
    for (var frame in spec) {
      for (var value in frame) {
        if (value < minVal) minVal = value;
        if (value > maxVal) maxVal = value;
        sum += value;
        count++;
      }
    }
    
    double mean = sum / count;
    
    print('   Value stats:');
    print('     Min: ${minVal.toStringAsFixed(2)} dB');
    print('     Max: ${maxVal.toStringAsFixed(2)} dB');
    print('     Mean: ${mean.toStringAsFixed(2)} dB');
    print('     Expected range: [-80, 0] dB');
    
    // Validation
    if (maxVal > 5 || minVal > 0) {
      print('   ⚠️  WARNING: Values outside expected dB range!');
    } else {
      print('   ✅ Values in expected dB range');
    }
  }
}
