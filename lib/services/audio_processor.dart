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
    print('   Mel filters: ${_cachedMelFilters!.length} bands');
    
    // 3. Apply Mel filterbank
    List<List<double>> melSpec = MelFilterbank.applyFilterbank(
      stft,
      _cachedMelFilters!,
    );
    print('   Mel spec shape: ${melSpec.length} x ${melSpec[0].length}');
    
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
  
  /// Compute Short-Time Fourier Transform
  static Future<List<List<double>>> _computeSTFT(Float32List audio) async {
    List<List<double>> stft = [];
    
    final numFrames = ((audio.length - fftSize) ~/ hopLength) + 1;
    final fftInstance = FFT(fftSize);
    
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
      
      // Compute FFT using fftea
      final Float64x2List fftResult = fftInstance.realFft(frame);
      
      // Compute power (magnitude squared)
      List<double> power = [];
      for (int k = 0; k < fftSize ~/ 2; k++) {
        double real = fftResult[k].x;
        double imag = fftResult[k].y;
        // Power spectrum (not just magnitude)
        power.add(real * real + imag * imag);
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
    for (var frame in spec) {
      List<double> dbFrame = frame.map((value) {
        // librosa formula: 10 * log10(S / ref)
        double db = 10.0 * log(max(value, 1e-10) / refPower) / ln10;
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
    var input = [
      transposed.map((row) => 
        row.map((val) => [val]).toList()
      ).toList()
    ];
    
    print('   Model input shape: (${input.length}, ${input[0].length}, ${input[0][0].length}, ${input[0][0][0].length})');
    
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
