import 'dart:math';

/// Mel Filterbank Calculator - Librosa Compatible
/// 
/// This implementation matches librosa.filters.mel() behavior
class MelFilterbank {
  /// Convert frequency in Hz to Mel scale
  static double hzToMel(double hz) {
    return 2595.0 * log(1.0 + hz / 700.0) / ln10;
  }
  
  /// Convert Mel scale to frequency in Hz
  static double melToHz(double mel) {
    return 700.0 * (pow(10, mel / 2595.0) - 1.0);
  }
  
  /// Create Mel filterbank matching librosa implementation
  /// 
  /// Parameters:
  ///   nfft: FFT size
  ///   nMels: Number of Mel bands
  ///   sampleRate: Audio sample rate
  ///   fMin: Minimum frequency (Hz)
  ///   fMax: Maximum frequency (Hz)
  /// 
  /// Returns: List of Mel filters (nMels x fftBins)
  static List<List<double>> createMelFilterbank({
    required int nfft,
    required int nMels,
    required int sampleRate,
    double fMin = 0.0,
    required double fMax,
  }) {
    // Calculate FFT bins
    int fftBins = nfft ~/ 2 + 1;
    
    // 1. Create mel-spaced frequencies
    double melFMin = hzToMel(fMin);
    double melFMax = hzToMel(fMax);
    
    // Generate nMels + 2 points (including edges)
    List<double> melPoints = List.generate(
      nMels + 2,
      (i) => melFMin + (melFMax - melFMin) * i / (nMels + 1),
    );
    
    // 2. Convert back to Hz
    List<double> hzPoints = melPoints.map((m) => melToHz(m)).toList();
    
    // 3. Convert Hz to FFT bin numbers
    List<double> binPoints = hzPoints.map((hz) {
      return (nfft + 1) * hz / sampleRate;
    }).toList();
    
    // 4. Create triangular filterbank
    List<List<double>> filterbank = [];
    
    for (int i = 1; i < nMels + 1; i++) {
      List<double> filter = List.filled(fftBins, 0.0);
      
      double leftBin = binPoints[i - 1];
      double centerBin = binPoints[i];
      double rightBin = binPoints[i + 1];
      
      // Left slope (rising)
      for (int j = 0; j < fftBins; j++) {
        if (j >= leftBin && j < centerBin) {
          filter[j] = (j - leftBin) / (centerBin - leftBin);
        }
        // Right slope (falling)
        else if (j >= centerBin && j < rightBin) {
          filter[j] = (rightBin - j) / (rightBin - centerBin);
        }
      }
      
      // Normalize filter (optional, librosa does this)
      double filterSum = filter.reduce((a, b) => a + b);
      if (filterSum > 0) {
        for (int j = 0; j < fftBins; j++) {
          filter[j] /= filterSum;
        }
      }
      
      filterbank.add(filter);
    }
    
    return filterbank;
  }
  
  /// Apply Mel filterbank to STFT magnitude spectrogram
  /// 
  /// Parameters:
  ///   stft: STFT magnitude (frames x bins)
  ///   filterbank: Mel filterbank (nMels x bins)
  /// 
  /// Returns: Mel spectrogram (frames x nMels)
  static List<List<double>> applyFilterbank(
    List<List<double>> stft,
    List<List<double>> filterbank,
  ) {
    List<List<double>> melSpec = [];
    
    for (var frame in stft) {
      List<double> melFrame = [];
      
      for (var filter in filterbank) {
        double melValue = 0.0;
        
        // Dot product of frame and filter
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
