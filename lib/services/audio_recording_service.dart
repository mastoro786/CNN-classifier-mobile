import 'dart:io';
import 'dart:typed_data';
import 'dart:math';
import 'package:record/record.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

/// Service for recording audio from microphone
class AudioRecordingService {
  final _recorder = AudioRecorder();
  String? _recordingPath;
  String? _lastRecordingPath;
  
  String? get lastRecordingPath => _lastRecordingPath;
  
  /// Check if microphone permission is granted
  Future<bool> checkPermission() async {
    final status = await Permission.microphone.status;
    return status.isGranted;
  }
  
  /// Request microphone permission
  Future<bool> requestPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
  }
  
  /// Start recording audio
  Future<void> startRecording() async {
    try {
      // Check permission
      if (!await checkPermission()) {
        final granted = await requestPermission();
        if (!granted) {
          throw Exception('Microphone permission not granted');
        }
      }
      
      // Get temporary directory
      final tempDir = await getTemporaryDirectory();
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      _recordingPath = '${tempDir.path}/recording_$timestamp.wav';
      
      // Start recording with explicit config
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 22050,     // Match model's expected sample rate
          numChannels: 1,        // Mono (critical!)
          bitRate: 128000,       // 128 kbps
          autoGain: false,       // Disable auto gain (preserve natural amplitude)
          echoCancel: false,     // Disable echo cancellation (preserve natural audio)
          noiseSuppress: false,  // Disable noise suppression (preserve natural audio)
        ),
        path: _recordingPath!,
      );
      
      print('🎙️ Recording started: $_recordingPath');
    } catch (e) {
      print('❌ Error starting recording: $e');
      rethrow;
    }
  }
  
  /// Stop recording and return audio samples
  Future<Float32List?> stopRecording() async {
    try {
      final path = await _recorder.stop();
      
      if (path == null) {
        print('❌ No recording path');
        return null;
      }
      
      print('✅ Recording stopped: $path');
      
      // Read WAV file
      final file = File(path);
      if (!await file.exists()) {
        print('❌ Recording file not found');
        return null;
      }
      
      // Read file bytes
      final bytes = await file.readAsBytes();
      
      print('📂 Recording file size: ${bytes.length} bytes');
      
      // Convert WAV to Float32List using proper WAV parser
      final audioSamples = _parseWavFile(bytes);
      
      print('📊 Audio samples: ${audioSamples.length}');
      print('📊 Duration: ${(audioSamples.length / 22050).toStringAsFixed(2)}s');
      
      // Debug: Audio statistics BEFORE normalization
      if (audioSamples.isNotEmpty) {
        double min = audioSamples[0];
        double max = audioSamples[0];
        double sum = 0.0;
        double sumSquares = 0.0;
        
        for (var sample in audioSamples) {
          if (sample < min) min = sample;
          if (sample > max) max = sample;
          sum += sample;
          sumSquares += sample * sample;
        }
        
        final mean = sum / audioSamples.length;
        final rms = (sumSquares / audioSamples.length);
        final energy = rms;
        
      print('📊 Recording audio statistics (RAW):');
      print('   Min: ${min.toStringAsFixed(6)}');
      print('   Max: ${max.toStringAsFixed(6)}');
      print('   Mean: ${mean.toStringAsFixed(6)}');
      print('   RMS Energy: ${energy.toStringAsFixed(8)}');
      print('   First 10 samples: ${audioSamples.sublist(0, audioSamples.length >= 10 ? 10 : audioSamples.length).map((e) => e.toStringAsFixed(6)).join(", ")}');
    }
    
    // Remove DC offset (mean centering)
    final dcRemovedSamples = _removeDCOffset(audioSamples);
    
    // Trim silence from beginning and end
    final trimmedSamples = _trimSilence(dcRemovedSamples, threshold: 0.01);
    print('✂️ Trimmed silence: ${audioSamples.length} → ${trimmedSamples.length} samples');
    
    // Apply high-pass filter to remove low-frequency noise (below 80 Hz)
    final filteredSamples = _applyHighPassFilter(trimmedSamples);
    
    // Apply soft clipping to reduce peaks
    final clippedSamples = _applySoftClipping(filteredSamples, threshold: 0.6);
    
    // Normalize amplitude to match typical file upload levels
    final normalizedSamples = _smartNormalize(clippedSamples);
    
    // Save path for playback (don't delete file yet)
    _lastRecordingPath = path;
    
    print('✅ Returning processed audio samples');
    return normalizedSamples;    } catch (e) {
      print('❌ Error stopping recording: $e');
      rethrow;
    }
  }
  
  /// Check if recording is active
  Future<bool> isRecording() async {
    return await _recorder.isRecording();
  }
  
  /// Check if audio is silence (no voice detected)
  /// Returns true if audio RMS energy is below threshold
  bool isSilence(Float32List samples, {double threshold = 0.01}) {
    if (samples.isEmpty) return true;
    
    // Calculate RMS (Root Mean Square) energy
    double sumSquares = 0.0;
    for (var sample in samples) {
      sumSquares += sample * sample;
    }
    double rms = sumSquares / samples.length;
    double energy = rms;
    
    print('🔊 Audio energy: ${energy.toStringAsFixed(6)} (threshold: $threshold)');
    
    return energy < threshold;
  }
  
  /// Parse WAV file with proper chunk parsing (matching audio_file_service.dart)
  Float32List _parseWavFile(Uint8List bytes) {
    try {
      if (bytes.length < 44) {
        throw const FormatException('Invalid WAV file: too short');
      }
      
      // Check RIFF header
      final riffHeader = String.fromCharCodes(bytes.sublist(0, 4));
      if (riffHeader != 'RIFF') {
        throw const FormatException('Invalid WAV file: missing RIFF header');
      }
      
      // Check WAVE format
      final waveFormat = String.fromCharCodes(bytes.sublist(8, 12));
      if (waveFormat != 'WAVE') {
        throw const FormatException('Invalid WAV file: missing WAVE format');
      }
      
      // Parse fmt chunk to get audio format info
      int numChannels = 1;
      int sampleRate = 22050;
      int bitsPerSample = 16;
      int dataOffset = 12;
      int dataSize = 0;
      
      while (dataOffset < bytes.length - 8) {
        final chunkId = String.fromCharCodes(bytes.sublist(dataOffset, dataOffset + 4));
        final chunkSize = _readInt32(bytes, dataOffset + 4);
        
        if (chunkId == 'fmt ') {
          // Read audio format parameters
          numChannels = bytes[dataOffset + 10] | (bytes[dataOffset + 11] << 8);
          sampleRate = _readInt32(bytes, dataOffset + 12);
          bitsPerSample = bytes[dataOffset + 22] | (bytes[dataOffset + 23] << 8);
          
          print('   WAV fmt: $numChannels channels, $sampleRate Hz, $bitsPerSample bits');
        } else if (chunkId == 'data') {
          dataSize = chunkSize;
          dataOffset += 8;
          break;
        }
        
        dataOffset += 8 + chunkSize;
      }
      
      if (dataSize == 0) {
        throw const FormatException('Invalid WAV file: no data chunk found');
      }
      
      print('   WAV data chunk at offset $dataOffset, size: $dataSize bytes');
      
      // Extract PCM data
      final pcmData = bytes.sublist(dataOffset, dataOffset + dataSize);
      
      // Calculate number of samples per channel
      final bytesPerSample = bitsPerSample ~/ 8;
      final totalSamples = pcmData.length ~/ bytesPerSample;
      final samplesPerChannel = totalSamples ~/ numChannels;
      
      // Read and convert to float, handling stereo by averaging channels
      final Float32List monoSamples = Float32List(samplesPerChannel);
      
      if (numChannels == 1) {
        // Mono: direct conversion
        for (int i = 0; i < samplesPerChannel; i++) {
          final byte1 = pcmData[i * 2];
          final byte2 = pcmData[i * 2 + 1];
          final int16Value = (byte2 << 8) | byte1;
          final signedValue = int16Value > 32767 ? int16Value - 65536 : int16Value;
          monoSamples[i] = signedValue / 32768.0;
        }
      } else if (numChannels == 2) {
        // Stereo: average left and right channels
        print('   ⚠️ Recording is stereo, converting to mono by averaging channels');
        for (int i = 0; i < samplesPerChannel; i++) {
          // Read left channel
          final leftByte1 = pcmData[i * 4];
          final leftByte2 = pcmData[i * 4 + 1];
          final leftInt16 = (leftByte2 << 8) | leftByte1;
          final leftSigned = leftInt16 > 32767 ? leftInt16 - 65536 : leftInt16;
          final leftFloat = leftSigned / 32768.0;
          
          // Read right channel
          final rightByte1 = pcmData[i * 4 + 2];
          final rightByte2 = pcmData[i * 4 + 3];
          final rightInt16 = (rightByte2 << 8) | rightByte1;
          final rightSigned = rightInt16 > 32767 ? rightInt16 - 65536 : rightInt16;
          final rightFloat = rightSigned / 32768.0;
          
          // Average channels
          monoSamples[i] = (leftFloat + rightFloat) / 2.0;
        }
      } else {
        throw UnsupportedError('Only mono and stereo supported, got $numChannels channels');
      }
      
      // Resample if not 22050 Hz (should not happen with correct RecordConfig)
      if (sampleRate != 22050) {
        print('   ⚠️ Recording sample rate is $sampleRate Hz, expected 22050 Hz');
        print('   This should not happen - check RecordConfig!');
        return _resample(monoSamples, sampleRate, 22050);
      }
      
      return monoSamples;
    } catch (e) {
      print('❌ Error parsing WAV file: $e');
      rethrow;
    }
  }
  
  /// Read 32-bit integer from bytes (little-endian)
  int _readInt32(Uint8List bytes, int offset) {
    return bytes[offset] |
           (bytes[offset + 1] << 8) |
           (bytes[offset + 2] << 16) |
           (bytes[offset + 3] << 24);
  }
  
  /// Resample audio using linear interpolation
  Float32List _resample(Float32List input, int fromRate, int toRate) {
    if (fromRate == toRate) return input;
    
    final double ratio = toRate / fromRate;
    final int outputLength = (input.length * ratio).round();
    final Float32List output = Float32List(outputLength);
    
    for (int i = 0; i < outputLength; i++) {
      final double position = i / ratio;
      final int index = position.floor();
      final double fraction = position - index;
      
      if (index + 1 < input.length) {
        output[i] = input[index] * (1.0 - fraction) + input[index + 1] * fraction;
      } else {
        output[i] = input[index];
      }
    }
    
    return output;
  }
  
  /// Apply soft clipping to compress loud peaks using tanh function
  /// This reduces dynamic range while preserving quieter sounds
  Float32List _applySoftClipping(Float32List audio, {double threshold = 0.6}) {
    if (audio.isEmpty) return audio;
    
    final clipped = Float32List(audio.length);
    
    for (int i = 0; i < audio.length; i++) {
      final sample = audio[i];
      final absValue = sample.abs();
      
      if (absValue > threshold) {
        // Apply soft clipping using sigmoid-like compression
        final sign = sample > 0 ? 1.0 : -1.0;
        final excess = (absValue - threshold) / (1.0 - threshold);
        // Simple compression: y = threshold + (1-threshold) * x / (1 + x)
        final compressed = threshold + (1.0 - threshold) * excess / (1.0 + excess);
        clipped[i] = sign * compressed;
      } else {
        clipped[i] = sample;
      }
    }
    
    print('📉 Soft clipping applied (threshold: $threshold)');
    return clipped;
  }
  
  /// Apply simple high-pass filter to remove low-frequency rumble/noise
  /// Uses first-order IIR high-pass filter with cutoff ~80 Hz
  Float32List _applyHighPassFilter(Float32List audio) {
    if (audio.length < 2) return audio;
    
    // High-pass filter coefficient (cutoff ~80 Hz at 22050 Hz sample rate)
    const double alpha = 0.98;
    
    final filtered = Float32List(audio.length);
    filtered[0] = audio[0];
    
    for (int i = 1; i < audio.length; i++) {
      filtered[i] = alpha * (filtered[i - 1] + audio[i] - audio[i - 1]);
    }
    
    print('🎚️ High-pass filter applied (cutoff ~80 Hz)');
    return filtered;
  }
  
  /// Remove DC offset by subtracting mean
  Float32List _removeDCOffset(Float32List audio) {
    if (audio.isEmpty) return audio;
    
    // Calculate mean
    double sum = 0.0;
    for (var sample in audio) {
      sum += sample;
    }
    final mean = sum / audio.length;
    
    // Only remove if DC offset is significant
    if (mean.abs() < 0.001) {
      return audio; // DC offset negligible
    }
    
    // Subtract mean from all samples
    final corrected = Float32List(audio.length);
    for (int i = 0; i < audio.length; i++) {
      corrected[i] = audio[i] - mean;
    }
    
    print('🔧 DC offset removed: ${mean.toStringAsFixed(6)}');
    return corrected;
  }
  
  /// Trim silence from beginning and end of audio using energy detection
  Float32List _trimSilence(Float32List audio, {double threshold = 0.01}) {
    if (audio.isEmpty) return audio;
    
    // Use energy-based detection in windows for more robust trimming
    const int windowSize = 441; // 20ms window at 22050 Hz
    int start = 0;
    int end = audio.length - 1;
    
    // Find first non-silent window
    for (int i = 0; i < audio.length - windowSize; i += windowSize ~/ 2) {
      double energy = 0.0;
      for (int j = 0; j < windowSize && i + j < audio.length; j++) {
        energy += audio[i + j].abs();
      }
      double avgEnergy = energy / windowSize;
      
      if (avgEnergy > threshold) {
        start = i;
        break;
      }
    }
    
    // Find last non-silent window
    for (int i = audio.length - windowSize; i >= 0; i -= windowSize ~/ 2) {
      double energy = 0.0;
      for (int j = 0; j < windowSize && i + j < audio.length; j++) {
        energy += audio[i + j].abs();
      }
      double avgEnergy = energy / windowSize;
      
      if (avgEnergy > threshold) {
        end = i + windowSize;
        break;
      }
    }
    
    // Add minimal padding (50ms = 1102 samples)
    const int padding = 1102;
    start = (start - padding).clamp(0, audio.length);
    end = (end + padding).clamp(0, audio.length - 1);
    
    if (start >= end) {
      print('⚠️ Audio is completely silent!');
      return audio;
    }
    
    print('   Trimmed range: $start to $end');
    return Float32List.sublistView(audio, start, end + 1);
  }
  
  /// Smart normalization - RMS-based to match file upload characteristics
  Float32List _smartNormalize(Float32List audio) {
    if (audio.isEmpty) return audio;
    
    // Calculate RMS (Root Mean Square)
    double sumSquares = 0.0;
    for (var sample in audio) {
      sumSquares += sample * sample;
    }
    final rms = sqrt(sumSquares / audio.length);
    
    if (rms < 0.001) {
      print('⚠️ Audio too quiet, skipping normalization');
      return audio;
    }
    
    // Target RMS: 0.0265 to match file upload exactly
    // File normal has RMS energy ~0.000704 = sqrt(0.000704) ≈ 0.0265
    // This should produce Mel Spec Max ~400 and Mean dB ~-60
    const double targetRMS = 0.0265;
    
    // Calculate scale factor
    final scale = targetRMS / rms;
    
    // Apply normalization
    final normalized = Float32List(audio.length);
    for (int i = 0; i < audio.length; i++) {
      normalized[i] = (audio[i] * scale).clamp(-1.0, 1.0);
    }
    
    print('🔊 RMS Normalized: ${rms.toStringAsFixed(6)} → ${targetRMS.toStringAsFixed(6)} (scale: ${scale.toStringAsFixed(2)}x)');
    
    // Verify final RMS
    double finalSumSquares = 0.0;
    for (var sample in normalized) {
      finalSumSquares += sample * sample;
    }
    final finalRMS = sqrt(finalSumSquares / normalized.length);
    print('   Final RMS: ${finalRMS.toStringAsFixed(6)}');
    
    return normalized;
  }
  
  /// Save last recording to Downloads folder for analysis
  Future<String?> saveRecordingForAnalysis() async {
    try {
      if (_lastRecordingPath == null) {
        print('⚠️ No recording to save');
        return null;
      }
      
      final File sourceFile = File(_lastRecordingPath!);
      if (!await sourceFile.exists()) {
        print('⚠️ Recording file not found: $_lastRecordingPath');
        return null;
      }
      
      // Get Downloads directory (for Android)
      Directory? downloadsDir;
      if (Platform.isAndroid) {
        downloadsDir = Directory('/storage/emulated/0/Download');
      } else {
        downloadsDir = await getDownloadsDirectory();
      }
      
      if (downloadsDir == null || !await downloadsDir.exists()) {
        // Fallback to external storage
        downloadsDir = await getExternalStorageDirectory();
      }
      
      if (downloadsDir == null) {
        print('⚠️ Could not find downloads directory');
        return null;
      }
      
      // Create filename with timestamp
      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final destPath = '${downloadsDir.path}/recording_analysis_$timestamp.wav';
      
      // Copy file
      await sourceFile.copy(destPath);
      
      print('💾 Recording saved for analysis: $destPath');
      return destPath;
      
    } catch (e) {
      print('❌ Error saving recording: $e');
      return null;
    }
  }
  
  /// Dispose resources
  void dispose() {
    _recorder.dispose();
  }
}
