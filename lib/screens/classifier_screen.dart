import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/classifier_service.dart';
import '../providers/audio_provider.dart';
import '../widgets/gradient_header.dart';
import '../widgets/recording_button.dart';
import '../widgets/upload_button.dart';
import '../services/database_helper.dart';
import '../models/analysis_history.dart';
import 'history_screen.dart';

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
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: Colors.white),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const HistoryScreen(),
                ),
              );
            },
            tooltip: 'History Analisis',
          ),
        ],
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
                            
                            // Playback controls (only show if result exists)
                            if (audioProvider.result != null && 
                                audioProvider.lastAudioFilePath != null)
                              _buildPlaybackCard(audioProvider),
                            
                            // Error card
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

      // Check for silence FIRST before showing loading
      if (_classifier.isSilence(audioData)) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.volume_off, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Text('No Voice Detected'),
                ],
              ),
              content: const Text(
                'File audio yang dipilih tidak mengandung suara. Silakan pilih file audio yang berbeda.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Show processing after silence check passes
      audioProvider.setProcessing(true);

      if (!mounted) return;

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
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
                      'Processing with CNN Model',
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
        ),
      );

      // Run classification
      try {
        final result = await _classifier.classify(audioData);
        audioProvider.setResult(result);
        
        // Close loading dialog
        if (mounted) {
          Navigator.pop(context);
        }
        
        // Show result popup
        if (mounted) {
          _showResultDialog(result);
        }
      } catch (e) {
        audioProvider.setError('Classification error: $e');
        if (mounted) {
          Navigator.pop(context);
        }
      } finally {
        audioProvider.setProcessing(false);
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

      // Check for silence
      if (_classifier.isSilence(audioData)) {
        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              title: Row(
                children: [
                  Icon(Icons.volume_off, color: Colors.orange.shade700),
                  const SizedBox(width: 12),
                  const Text('No Voice Detected'),
                ],
              ),
              content: const Text(
                'Tidak terdeteksi suara pada rekaman audio. Silakan coba lagi dengan berbicara lebih jelas atau di tempat yang lebih tenang.',
                style: TextStyle(fontSize: 14),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('OK'),
                ),
              ],
            ),
          );
        }
        return;
      }

      // Show processing
      audioProvider.setProcessing(true);

      if (!mounted) return;
      
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => WillPopScope(
          onWillPop: () async => false,
          child: Center(
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
                      'Processing with CNN Model',
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
        ),
      );

      // Run classification
      try {
        final result = await _classifier.classify(audioData);
        audioProvider.setResult(result);
        
        // Close loading dialog
        if (mounted) {
          Navigator.pop(context);
        }
        
        // Show result popup
        if (mounted) {
          _showResultDialog(result);
        }
      } catch (e) {
        audioProvider.setError('Classification error: $e');
        if (mounted) {
          Navigator.pop(context);
        }
      } finally {
        audioProvider.setProcessing(false);
      }
    } catch (e) {
      audioProvider.setError('Recording error: $e');
      audioProvider.setProcessing(false);
    }
  }

  /// Show result dialog popup with name input and save option
  void _showResultDialog(ClassificationResult result) async {
    final bool isNormal = result.predictedIndex == 0;
    final Color primaryColor = isNormal ? Colors.green : Colors.red;
    final IconData icon = isNormal ? Icons.check_circle : Icons.warning;
    final String title = result.predictedLabel;
    final double confidence = result.confidence * 100;
    final TextEditingController nameController = TextEditingController();
    
    final shouldSave = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              gradient: LinearGradient(
                colors: [
                  primaryColor.withOpacity(0.1),
                  Colors.white,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon with animation
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: 60,
                    color: primaryColor,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Title
                Text(
                  'Hasil Klasifikasi',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                
                // Result label
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                
                // Confidence
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  decoration: BoxDecoration(
                    color: primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.analytics,
                        color: primaryColor,
                        size: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Confidence: ${confidence.toStringAsFixed(1)}%',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: primaryColor,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Probability bars
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey.shade100,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    children: [
                      _buildProbabilityRow(
                        'Normal',
                        result.probabilitiesList[0],
                        Colors.green,
                      ),
                      const SizedBox(height: 12),
                      _buildProbabilityRow(
                        'Skizofrenia',
                        result.probabilitiesList[1],
                        Colors.red,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Processing time
                Text(
                  'Waktu proses: ${result.inferenceTime}ms',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey.shade600,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Name input field
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Pasien (opsional)',
                    hintText: 'Masukkan nama pasien',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),
                const SizedBox(height: 20),
                
                // Buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context, false),
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          side: BorderSide(color: Colors.grey.shade400),
                        ),
                        child: const Text(
                          'Tutup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.pop(context, true);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 2,
                        ),
                        child: const Text(
                          'Simpan',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
    
    // Save to database if user clicked "Simpan"
    if (shouldSave == true && mounted) {
      await _saveToHistory(
        patientName: nameController.text.trim().isEmpty 
            ? 'Unknown' 
            : nameController.text.trim(),
        result: result,
      );
    }
  }
  
  /// Build probability bar row
  Widget _buildProbabilityRow(String label, double probability, Color color) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: probability,
              backgroundColor: Colors.grey.shade300,
              valueColor: AlwaysStoppedAnimation<Color>(color),
              minHeight: 12,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          width: 50,
          child: Text(
            '${(probability * 100).toStringAsFixed(1)}%',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: color,
            ),
            textAlign: TextAlign.right,
          ),
        ),
      ],
    );
  }

  /// Save analysis result to history database
  Future<void> _saveToHistory({
    required String patientName,
    required ClassificationResult result,
  }) async {
    try {
      final audioProvider = Provider.of<AudioProvider>(context, listen: false);
      
      final history = AnalysisHistory(
        patientName: patientName,
        analysisDate: DateTime.now(),
        result: result.predictedLabel,
        confidence: result.confidence,
        inferenceTime: result.inferenceTime,
        audioFilePath: audioProvider.lastAudioFilePath,
      );

      await DatabaseHelper.instance.insert(history);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Text('Hasil analisis disimpan: $patientName'),
              ],
            ),
            backgroundColor: Colors.green,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Gagal menyimpan: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
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
