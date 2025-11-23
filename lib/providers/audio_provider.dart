import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import '../services/audio_recording_service.dart';
import '../services/audio_file_service.dart';
import '../services/audio_playback_service.dart';
import '../services/classifier_service.dart';

/// Provider for managing audio recording and classification state
class AudioProvider extends ChangeNotifier {
  final AudioRecordingService _recordingService = AudioRecordingService();
  final AudioFileService _fileService = AudioFileService();
  final AudioPlaybackService _playbackService = AudioPlaybackService();
  
  bool _isRecording = false;
  bool _isProcessing = false;
  bool _isPlaying = false;
  ClassificationResult? _result;
  String? _error;
  Float32List? _lastAudioSamples;
  String? _lastAudioFilePath;
  
  bool get isRecording => _isRecording;
  bool get isProcessing => _isProcessing;
  bool get isPlaying => _isPlaying;
  ClassificationResult? get result => _result;
  String? get error => _error;
  Float32List? get lastAudioSamples => _lastAudioSamples;
  String? get lastAudioFilePath => _lastAudioFilePath;
  
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
      
      // Save recording path for playback
      _lastAudioFilePath = _recordingService.lastRecordingPath;
      
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
  
  /// Pick and load audio file
  Future<Float32List?> pickAudioFile() async {
    try {
      _error = null;
      notifyListeners();
      
      // Pick file
      final file = await _fileService.pickAudioFile();
      if (file == null) {
        return null;
      }
      
      // Validate file
      final isValid = await _fileService.validateAudioFile(file);
      if (!isValid) {
        _error = 'Invalid audio file. Please select a WAV file (max 10 MB).';
        notifyListeners();
        return null;
      }
      
      // Load audio data
      final audioSamples = await _fileService.loadAudioFile(file);
      if (audioSamples == null) {
        _error = 'Failed to load audio file';
        notifyListeners();
        return null;
      }
      
      _lastAudioSamples = audioSamples;
      _lastAudioFilePath = file.path;
      notifyListeners();
      return audioSamples;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      rethrow;
    }
  }
  
  /// Play audio
  Future<void> playAudio() async {
    try {
      if (_lastAudioFilePath == null) {
        _error = 'No audio file to play';
        notifyListeners();
        return;
      }
      
      await _playbackService.playFromFile(_lastAudioFilePath!);
      _isPlaying = true;
      notifyListeners();
    } catch (e) {
      _error = 'Playback error: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Pause audio
  Future<void> pauseAudio() async {
    try {
      await _playbackService.pause();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      _error = 'Pause error: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Stop audio
  Future<void> stopAudio() async {
    try {
      await _playbackService.stop();
      _isPlaying = false;
      notifyListeners();
    } catch (e) {
      _error = 'Stop error: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    try {
      if (_isPlaying) {
        await pauseAudio();
      } else {
        await playAudio();
      }
    } catch (e) {
      _error = 'Toggle playback error: $e';
      notifyListeners();
      rethrow;
    }
  }
  
  @override
  void dispose() {
    _recordingService.dispose();
    _playbackService.dispose();
    super.dispose();
  }
}
