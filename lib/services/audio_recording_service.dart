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
      
      // Convert WAV to Float32List
      // Skip WAV header (44 bytes) and convert PCM data
      final audioSamples = _wavBytesToFloat32(bytes);
      
      print('📊 Audio samples: ${audioSamples.length}');
      
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
  
  /// Convert WAV bytes to Float32List
  Float32List _wavBytesToFloat32(Uint8List bytes) {
    // Skip WAV header (44 bytes)
    const headerSize = 44;
    
    if (bytes.length < headerSize) {
      throw Exception('Invalid WAV file: too short');
    }
    
    // Extract PCM data (16-bit signed integers)
    final pcmData = bytes.sublist(headerSize);
    final numSamples = pcmData.length ~/ 2; // 2 bytes per sample (16-bit)
    
    final Float32List samples = Float32List(numSamples);
    
    for (int i = 0; i < numSamples; i++) {
      // Read 16-bit signed integer (little-endian)
      final byte1 = pcmData[i * 2];
      final byte2 = pcmData[i * 2 + 1];
      final int16Value = (byte2 << 8) | byte1;
      
      // Convert to signed
      final signedValue = int16Value > 32767 ? int16Value - 65536 : int16Value;
      
      // Normalize to [-1.0, 1.0]
      samples[i] = signedValue / 32768.0;
    }
    
    return samples;
  }
  
  /// Dispose resources
  void dispose() {
    _recorder.dispose();
  }
}
