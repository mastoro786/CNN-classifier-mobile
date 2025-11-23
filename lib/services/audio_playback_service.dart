import 'package:audioplayers/audioplayers.dart';

/// Service for playing audio files
class AudioPlaybackService {
  final AudioPlayer _player = AudioPlayer();
  bool _isPlaying = false;
  String? _currentFilePath;
  
  bool get isPlaying => _isPlaying;
  String? get currentFilePath => _currentFilePath;
  
  /// Initialize player
  AudioPlaybackService() {
    _player.onPlayerStateChanged.listen((state) {
      _isPlaying = state == PlayerState.playing;
    });
  }
  
  /// Play audio from file path
  Future<void> playFromFile(String filePath) async {
    try {
      print('🔊 Playing audio from: $filePath');
      
      await _player.stop();
      _currentFilePath = filePath;
      
      await _player.play(DeviceFileSource(filePath));
      _isPlaying = true;
      
      print('✅ Audio playback started');
    } catch (e) {
      print('❌ Error playing audio: $e');
      _isPlaying = false;
      rethrow;
    }
  }
  
  /// Play audio from recorded data
  Future<void> playFromRecording(String recordingPath) async {
    try {
      await playFromFile(recordingPath);
    } catch (e) {
      print('❌ Error playing recording: $e');
      rethrow;
    }
  }
  
  /// Pause playback
  Future<void> pause() async {
    try {
      await _player.pause();
      _isPlaying = false;
      print('⏸️ Audio paused');
    } catch (e) {
      print('❌ Error pausing audio: $e');
      rethrow;
    }
  }
  
  /// Resume playback
  Future<void> resume() async {
    try {
      await _player.resume();
      _isPlaying = true;
      print('▶️ Audio resumed');
    } catch (e) {
      print('❌ Error resuming audio: $e');
      rethrow;
    }
  }
  
  /// Stop playback
  Future<void> stop() async {
    try {
      await _player.stop();
      _isPlaying = false;
      _currentFilePath = null;
      print('⏹️ Audio stopped');
    } catch (e) {
      print('❌ Error stopping audio: $e');
      rethrow;
    }
  }
  
  /// Toggle play/pause
  Future<void> togglePlayPause() async {
    if (_isPlaying) {
      await pause();
    } else {
      await resume();
    }
  }
  
  /// Get current position
  Future<Duration?> getCurrentPosition() async {
    try {
      return await _player.getCurrentPosition();
    } catch (e) {
      print('❌ Error getting position: $e');
      return null;
    }
  }
  
  /// Get duration
  Future<Duration?> getDuration() async {
    try {
      return await _player.getDuration();
    } catch (e) {
      print('❌ Error getting duration: $e');
      return null;
    }
  }
  
  /// Seek to position
  Future<void> seek(Duration position) async {
    try {
      await _player.seek(position);
    } catch (e) {
      print('❌ Error seeking: $e');
      rethrow;
    }
  }
  
  /// Set volume (0.0 to 1.0)
  Future<void> setVolume(double volume) async {
    try {
      await _player.setVolume(volume);
    } catch (e) {
      print('❌ Error setting volume: $e');
      rethrow;
    }
  }
  
  /// Dispose player
  void dispose() {
    _player.dispose();
  }
}
