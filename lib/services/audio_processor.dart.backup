import 'dart:typed_data';
import 'dart:math';
import 'package:fftea/fftea.dart';

/// Audio Processor for extracting Mel Spectrogram features
/// This implementation matches the Python preprocessing pipeline
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
      
      // Compute magnitude
      List<double> magnitude = [];
      for (int k = 0; k < fftSize ~/ 2; k++) {
        double real = fftResult[k].x;
        double imag = fftResult[k].y;
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
