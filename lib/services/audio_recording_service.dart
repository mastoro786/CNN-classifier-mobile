import 'dart:io';
import 'dart:typed_data';
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
      
      // Start recording
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.wav,
          sampleRate: 22050, // Match model's expected sample rate
          numChannels: 1,    // Mono
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
      
      // Debug: Audio statistics
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
        
        print('📊 Recording audio statistics:');
        print('   Min: ${min.toStringAsFixed(6)}');
        print('   Max: ${max.toStringAsFixed(6)}');
        print('   Mean: ${mean.toStringAsFixed(6)}');
        print('   RMS Energy: ${energy.toStringAsFixed(8)}');
        print('   First 10 samples: ${audioSamples.sublist(0, audioSamples.length >= 10 ? 10 : audioSamples.length).map((e) => e.toStringAsFixed(6)).join(", ")}');
      }
      
      // Save path for playback (don't delete file yet)
      _lastRecordingPath = path;
      
      return audioSamples;
    } catch (e) {
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
  
  /// Dispose resources
  void dispose() {
    _recorder.dispose();
  }
}
