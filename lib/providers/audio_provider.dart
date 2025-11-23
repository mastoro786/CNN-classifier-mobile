import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/audio_recording_service.dart';
import '../services/classifier_service.dart';

/// Provider for managing audio recording and classification state
class AudioProvider extends ChangeNotifier {
  final AudioRecordingService _recordingService = AudioRecordingService();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  ClassificationResult? _result;
  String? _error;
  Float32List? _lastAudioSamples;
  
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  ClassificationResult? get result => _result;
  String? get error => _error;
  Float32List? get lastAudioSamples => _lastAudioSamples;
  
  /// Start recording audio
  Future<void> startRecording() async {
    try {
      _error = null;
      _isRecording = true;
      notifyListeners();
      
      await _recordingService.startRecording();
    } catch (e) {
      _error = e.toString();
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }
  
  /// Stop recording and return audio samples
  Future<Float32List?> stopRecording() async {
    try {
      final audioSamples = await _recordingService.stopRecording();
      _isRecording = false;
      _lastAudioSamples = audioSamples;
      notifyListeners();
      return audioSamples;
    } catch (e) {
      _error = e.toString();
      _isRecording = false;
      notifyListeners();
      rethrow;
    }
  }
  
  /// Set classification result
  void setResult(ClassificationResult result) {
    _result = result;
    notifyListeners();
  }
  
  /// Set processing state
  void setProcessing(bool processing) {
    _isProcessing = processing;
    notifyListeners();
  }
  
  /// Clear result
  void clearResult() {
    _result = null;
    _error = null;
    _lastAudioSamples = null;
    notifyListeners();
  }
  
  /// Set error
  void setError(String error) {
    _error = error;
    notifyListeners();
  }
  
  @override
  void dispose() {
    _recordingService.dispose();
    super.dispose();
  }
}
