import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/classifier_service.dart';
import '../providers/audio_provider.dart';
import '../widgets/gradient_header.dart';
import '../widgets/result_card.dart';
import '../widgets/recording_button.dart';
import '../widgets/upload_button.dart';

class ClassifierScreen extends StatefulWidget {
  const ClassifierScreen({super.key});

  @override
  State<ClassifierScreen> createState() => _ClassifierScreenState();
}

class _ClassifierScreenState extends State<ClassifierScreen>
    with TickerProviderStateMixin {
  final ClassifierService _classifier = ClassifierService();
  bool _isLoading = true;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);
    _loadModel();
  }

  Future<void> _loadModel() async {
    try {
      await _classifier.loadModel();
      setState(() => _isLoading = false);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading model: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      appBar: AppBar(
        title: const Text(
          'Audio Classifier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        centerTitle: true,
        elevation: 0,
        flexibleSpace: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
        ),
      ),
      body: _isLoading
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      Theme.of(context).primaryColor,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Loading AI Model...',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF64748B),
                    ),
                  ),
                ],
              ),
            )
          : Consumer<AudioProvider>(
              builder: (context, audioProvider, child) {
                return SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  child: Column(
                    children: [
                      const GradientHeader(),
                      Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Record audio button
                            RecordingButton(
                              isRecording: audioProvider.isRecording,
                              isProcessing: audioProvider.isProcessing,
                              onPressed: () => _handleRecording(audioProvider),
                              pulseController: _pulseController,
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Divider with text
                            Row(
                              children: [
                                const Expanded(child: Divider()),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Text(
                                    'OR',
                                    style: TextStyle(
                                      color: Colors.grey.shade600,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const Expanded(child: Divider()),
                              ],
                            ),
                            
                            const SizedBox(height: 16),
                            
                            // Upload audio button
                            UploadButton(
                              isProcessing: audioProvider.isProcessing,
                              onPressed: () => _handleFileUpload(audioProvider),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Info about supported formats
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.blue.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.blue.shade200,
                                  width: 1,
                                ),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    Icons.info_outline,
                                    color: Colors.blue.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      'Supported formats: WAV (16-bit PCM)\nMax file size: 10 MB',
                                      style: TextStyle(
                                        color: Colors.blue.shade900,
                                        fontSize: 12,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            
                            const SizedBox(height: 24),
                            
                            // Results
                            if (audioProvider.result != null) ...[
                              ResultCard(result: audioProvider.result!),
                              const SizedBox(height: 16),
                              // Playback controls
                              if (audioProvider.lastAudioFilePath != null)
                                _buildPlaybackCard(audioProvider),
                            ],
                            if (audioProvider.error != null)
                              _buildErrorCard(audioProvider.error!),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildPlaybackCard(AudioProvider audioProvider) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF667EEA), Color(0xFF764BA2)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.purple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Play/Pause button
          Material(
            color: Colors.white,
            shape: const CircleBorder(),
            child: InkWell(
              onTap: () => audioProvider.togglePlayPause(),
              customBorder: const CircleBorder(),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Icon(
                  audioProvider.isPlaying ? Icons.pause : Icons.play_arrow,
                  color: const Color(0xFF667EEA),
                  size: 32,
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          // Text
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Audio Playback',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  audioProvider.isPlaying ? 'Playing...' : 'Tap to play audio',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.9),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          // Stop button
          if (audioProvider.isPlaying)
            Material(
              color: Colors.white.withOpacity(0.2),
              shape: const CircleBorder(),
              child: InkWell(
                onTap: () => audioProvider.stopAudio(),
                customBorder: const CircleBorder(),
                child: const Padding(
                  padding: EdgeInsets.all(8),
                  child: Icon(
                    Icons.stop,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildErrorCard(String error) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: Colors.red.shade700, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              error,
              style: TextStyle(
                color: Colors.red.shade900,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleFileUpload(AudioProvider audioProvider) async {
    if (audioProvider.isProcessing) return;

    try {
      // Clear previous results
      audioProvider.clearResult();

      // Pick and load audio file
      final audioData = await audioProvider.pickAudioFile();

      if (audioData == null) {
        return;
      }

      // Show processing
      audioProvider.setProcessing(true);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.graphic_eq,
                        color: Theme.of(context).primaryColor,
                        size: 30,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Analyzing audio...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Processing AI model',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Run classification
      try {
        final result = await _classifier.classify(audioData);
        audioProvider.setResult(result);
      } catch (e) {
        audioProvider.setError('Classification error: $e');
      } finally {
        audioProvider.setProcessing(false);
        if (mounted) {
          Navigator.pop(context); // Close processing dialog
        }
      }
    } catch (e) {
      audioProvider.setError('File upload error: $e');
      audioProvider.setProcessing(false);
    }
  }

  Future<void> _handleRecording(AudioProvider audioProvider) async {
    if (audioProvider.isRecording) return;

    try {
      // Clear previous results
      audioProvider.clearResult();

      // Start recording
      await audioProvider.startRecording();

      // Show recording dialog
      if (!mounted) return;
      
      await showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => _RecordingDialog(
          duration: 5,
          onComplete: () => Navigator.of(context).pop(),
        ),
      );

      // Stop recording
      final audioData = await audioProvider.stopRecording();

      if (audioData == null) {
        audioProvider.setError('Failed to record audio');
        return;
      }

      // Show processing
      audioProvider.setProcessing(true);

      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => Center(
          child: Card(
            elevation: 8,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      SizedBox(
                        width: 60,
                        height: 60,
                        child: CircularProgressIndicator(
                          strokeWidth: 6,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Theme.of(context).primaryColor,
                          ),
                        ),
                      ),
                      Icon(
                        Icons.graphic_eq,
                        color: Theme.of(context).primaryColor,
                        size: 30,
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'Analyzing audio...',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Processing AI model',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey.shade600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Run classification
      try {
        final result = await _classifier.classify(audioData);
        audioProvider.setResult(result);
      } catch (e) {
        audioProvider.setError('Classification error: $e');
      } finally {
        audioProvider.setProcessing(false);
        if (mounted) {
          Navigator.pop(context); // Close processing dialog
        }
      }
    } catch (e) {
      audioProvider.setError('Recording error: $e');
      audioProvider.setProcessing(false);
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _classifier.dispose();
    super.dispose();
  }
}

class _RecordingDialog extends StatefulWidget {
  final int duration;
  final VoidCallback onComplete;

  const _RecordingDialog({
    required this.duration,
    required this.onComplete,
  });

  @override
  State<_RecordingDialog> createState() => _RecordingDialogState();
}

class _RecordingDialogState extends State<_RecordingDialog>
    with SingleTickerProviderStateMixin {
  late int _remainingSeconds;
  late AnimationController _animController;

  @override
  void initState() {
    super.initState();
    _remainingSeconds = widget.duration;
    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    
    _startCountdown();
  }

  void _startCountdown() {
    Future.doWhile(() async {
      await Future.delayed(const Duration(seconds: 1));
      if (!mounted) return false;
      
      setState(() => _remainingSeconds--);
      
      if (_remainingSeconds <= 0) {
        widget.onComplete();
        return false;
      }
      return true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedBuilder(
              animation: _animController,
              builder: (context, child) {
                return Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.red.withOpacity(0.1 + _animController.value * 0.2),
                  ),
                  child: Icon(
                    Icons.mic,
                    size: 40,
                    color: Colors.red.shade700,
                  ),
                );
              },
            ),
            const SizedBox(height: 24),
            const Text(
              'Recording...',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              '$_remainingSeconds seconds remaining',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey.shade600,
              ),
            ),
            const SizedBox(height: 24),
            LinearProgressIndicator(
              value: (_remainingSeconds / widget.duration),
              backgroundColor: Colors.grey.shade200,
              valueColor: AlwaysStoppedAnimation<Color>(Colors.red.shade700),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }
}
