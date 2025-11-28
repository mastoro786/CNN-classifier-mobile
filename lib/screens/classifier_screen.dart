import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/classifier_service.dart';
import '../providers/audio_provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/gradient_header.dart';
import '../widgets/recording_button.dart';
import '../widgets/upload_button.dart';
import '../widgets/audio_visualization_dialog.dart';
import '../services/database_helper.dart';
import '../models/analysis_history.dart';
import 'history_screen.dart';
import 'login_screen.dart';

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
  
  // Recording feature toggle (disabled by default)
  bool _isRecordingEnabled = false;
  
  // Recording preprocessing mode setting
  String _preprocessMode = 'Standard'; // 'Conservative', 'Standard', 'Aggressive'

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
          'CNN Mental Health Classifier',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            color: Colors.white,
            fontSize: 18,
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
          // Toggle Recording Feature
          IconButton(
            icon: Icon(
              _isRecordingEnabled ? Icons.mic : Icons.mic_off,
              color: Colors.white,
            ),
            onPressed: () {
              if (!_isRecordingEnabled) {
                // Show disclaimer dialog before enabling
                _showRecordingDisclaimerDialog();
              } else {
                // Disable directly
                setState(() {
                  _isRecordingEnabled = false;
                });
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('🔇 Fitur Recording Dinonaktifkan'),
                    duration: Duration(seconds: 2),
                    backgroundColor: Colors.orange,
                  ),
                );
              }
            },
            tooltip: _isRecordingEnabled ? 'Nonaktifkan Recording' : 'Aktifkan Recording',
          ),
          // Settings icon (only show when recording enabled)
          if (_isRecordingEnabled)
            IconButton(
              icon: const Icon(Icons.tune, color: Colors.white),
              onPressed: _showPreprocessModeDialog,
              tooltip: 'Pengaturan Preprocessing',
            ),
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
            tooltip: 'Riwayat Analisis',
          ),
          // Logout button
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, color: Colors.white),
            tooltip: 'Akun',
            onSelected: (value) async {
              if (value == 'logout') {
                final confirm = await showDialog<bool>(
                  context: context,
                  builder: (context) => AlertDialog(
                    title: const Text('Konfirmasi Logout'),
                    content: const Text('Apakah Anda yakin ingin keluar?'),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(context, false),
                        child: const Text('Batal'),
                      ),
                      ElevatedButton(
                        onPressed: () => Navigator.pop(context, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                        ),
                        child: const Text('Keluar'),
                      ),
                    ],
                  ),
                );

                if (confirm == true && mounted) {
                  final authProvider = context.read<AuthProvider>();
                  await authProvider.logout();
                  
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                      (route) => false,
                    );
                  }
                }
              }
            },
            itemBuilder: (context) {
              final authProvider = context.read<AuthProvider>();
              return [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        authProvider.currentUser?.fullName ?? '',
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '@${authProvider.currentUser?.username ?? ''}',
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Colors.red),
                      SizedBox(width: 12),
                      Text('Keluar'),
                    ],
                  ),
                ),
              ];
            },
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
                            // Record audio button (only show when enabled)
                            if (_isRecordingEnabled) ...[
                              RecordingButton(
                                isRecording: audioProvider.isRecording,
                                isProcessing: audioProvider.isProcessing,
                                onPressed: () => _handleRecording(audioProvider),
                                pulseController: _pulseController,
                              ),
                              
                              const SizedBox(height: 8),
                              
                              // Preprocessing mode indicator
                              Center(
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                decoration: BoxDecoration(
                                  color: _preprocessMode == 'Conservative' 
                                      ? Colors.green.shade50
                                      : _preprocessMode == 'Aggressive'
                                      ? Colors.orange.shade50
                                      : Colors.blue.shade50,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _preprocessMode == 'Conservative'
                                        ? Colors.green.shade300
                                        : _preprocessMode == 'Aggressive'
                                        ? Colors.orange.shade300
                                        : Colors.blue.shade300,
                                    width: 1,
                                  ),
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      Icons.tune,
                                      size: 14,
                                      color: _preprocessMode == 'Conservative'
                                          ? Colors.green.shade700
                                          : _preprocessMode == 'Aggressive'
                                          ? Colors.orange.shade700
                                          : Colors.blue.shade700,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Preprocessing: $_preprocessMode',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600,
                                        color: _preprocessMode == 'Conservative'
                                            ? Colors.green.shade900
                                            : _preprocessMode == 'Aggressive'
                                            ? Colors.orange.shade900
                                            : Colors.blue.shade900,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            
                            const SizedBox(height: 16),
                          ],
                            
                            // Divider with text (only show when recording enabled)
                            if (_isRecordingEnabled)
                              Row(
                                children: [
                                  const Expanded(child: Divider()),
                                  Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                    child: Text(
                                      'ATAU',
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
                            
                            // Upload audio button
                            UploadButton(
                              isProcessing: audioProvider.isProcessing,
                              onPressed: () => _handleFileUpload(audioProvider),
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Info about supported formats - Recommended method
                            Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.green.shade50,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.green.shade300,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle_outline,
                                    color: Colors.green.shade700,
                                    size: 20,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '✓ Metode Direkomendasikan',
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.green.shade900,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Format: WAV (16-bit PCM)\nMax file size: 10 MB',
                                          style: TextStyle(
                                            color: Colors.green.shade800,
                                            fontSize: 11,
                                            height: 1.4,
                                          ),
                                        ),
                                      ],
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

      // TEMPORARY: Silence check disabled for debugging
      // Will log audio energy to console for threshold tuning
      _classifier.isSilence(audioData); // Just log, don't block
      
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

      // Wait for dialog to render
      await Future.delayed(const Duration(milliseconds: 100));

      // Run classification
      try {
        final result = await _classifier.classify(
          audioData,
          includeVisualizationData: true,
        );
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

      // Set preprocessing mode before recording
      audioProvider.setPreprocessingMode(_preprocessMode);

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
          preprocessMode: _preprocessMode,
        ),
      );

      // Stop recording
      final audioData = await audioProvider.stopRecording();

      if (audioData == null) {
        audioProvider.setError('Failed to record audio');
        return;
      }

      // Validate recording duration
      final durationSeconds = audioData.length / 22050;
      print('⏱️ Recording duration: ${durationSeconds.toStringAsFixed(2)}s');
      
      if (durationSeconds < 1.0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Recording too short! Please record at least 1 second of audio.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
        audioProvider.setError('Recording too short');
        return;
      }
      
      if (durationSeconds > 10.0) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('⚠️ Recording too long! Please keep it under 10 seconds for best results.'),
              backgroundColor: Colors.orange,
              duration: Duration(seconds: 3),
            ),
          );
        }
      }

      // Check if recording contains actual voice (not silence)
      final isSilent = _classifier.isSilence(audioData);
      if (isSilent) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Row(
                children: [
                  Icon(Icons.mic_off, color: Colors.white),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      '⚠️ No voice detected! Please speak clearly during recording.',
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ],
              ),
              backgroundColor: Colors.red,
              duration: Duration(seconds: 4),
            ),
          );
        }
        audioProvider.setError('No voice detected - silence');
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

      // Wait for dialog to render
      await Future.delayed(const Duration(milliseconds: 100));

      // Run classification with power compression for recording
      try {
        final result = await _classifier.classify(
          audioData,
          includeVisualizationData: true,
          applyPreEmphasis: true, // Reuse this flag for power compression
        );
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
    print('🎯 Result Dialog Debug:');
    print('   Predicted Label: ${result.predictedLabel}');
    print('   Predicted Index: ${result.predictedIndex}');
    print('   Probabilities: ${result.probabilitiesList}');
    print('   Confidence: ${result.confidence}');
    
    final bool isNormal = result.predictedIndex == 0;
    final Color primaryColor = isNormal ? Colors.green : Colors.red;
    final IconData icon = isNormal ? Icons.check_circle : Icons.warning;
    final String title = result.predictedLabel;
    final double confidence = result.confidence * 100;
    
    print('   isNormal: $isNormal');
    print('   primaryColor: ${primaryColor == Colors.green ? "Green" : "Red"}');
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
                      Builder(
                        builder: (context) {
                          print('🎨 Probability Bar Debug:');
                          print('   Normal: ${result.probabilitiesList[0]}');
                          print('   Skizofrenia: ${result.probabilitiesList[1]}');
                          return Column(
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
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Visualization button (if data available)
                if (result.audioData != null && result.melSpectrogram != null)
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => AudioVisualizationDialog(
                            audioData: result.audioData!,
                            melSpectrogram: result.melSpectrogram!,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.graphic_eq),
                    label: const Text('Lihat Waveform & Spectrogram'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: const Color(0xFF6366F1),
                      side: const BorderSide(color: Color(0xFF6366F1)),
                      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                
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
                
                // Name input field (REQUIRED)
                TextField(
                  controller: nameController,
                  decoration: InputDecoration(
                    labelText: 'Nama Pasien *',
                    hintText: 'Wajib diisi',
                    prefixIcon: const Icon(Icons.person),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                  textCapitalization: TextCapitalization.words,
                  autofocus: false,
                ),
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '* Wajib diisi untuk menyimpan hasil analisis',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey.shade600,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                
                // Medical Disclaimer
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.info_outline,
                        color: Colors.blue.shade700,
                        size: 20,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Disclaimer',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blue.shade900,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Hasil ini hanya sebagai alat screening awal dan tidak dapat menggantikan diagnosis profesional. Untuk diagnosis yang akurat dan penanganan yang tepat, silakan konsultasikan dengan tenaga medis profesional di RSJD (Rumah Sakit Jiwa Daerah).',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue.shade800,
                                height: 1.4,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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
                          // Validate name is not empty
                          final name = nameController.text.trim();
                          if (name.isEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Row(
                                  children: [
                                    Icon(Icons.error_outline, color: Colors.white),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Text('Nama pasien wajib diisi!'),
                                    ),
                                  ],
                                ),
                                backgroundColor: Colors.red,
                                duration: Duration(seconds: 2),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                            return;
                          }
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
    
    // Save to database if user clicked "Simpan" and name is provided
    if (shouldSave == true && mounted) {
      final name = nameController.text.trim();
      // Name validation already done in dialog, but double-check
      if (name.isNotEmpty) {
        await _saveToHistory(
          patientName: name,
          result: result,
        );
      }
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
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      
      final history = AnalysisHistory(
        userId: authProvider.currentUser!.id!,
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

  void _showRecordingDisclaimerDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, // User must make a choice
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.warning_amber_rounded,
          color: Colors.orange.shade700,
          size: 48,
        ),
        title: const Text(
          'Peringatan: Fitur Eksperimental',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 18,
          ),
          textAlign: TextAlign.center,
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade800, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Tentang Fitur Recording:',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: Colors.amber.shade900,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '• Masih dalam tahap pengembangan\n'
                      '• Hasil dapat bervariasi tergantung perangkat\n'
                      '• Akurasi belum optimal untuk semua kondisi\n'
                      '• Dipengaruhi oleh kualitas mikrofon dan lingkungan',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.amber.shade900,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade300),
                ),
                child: Row(
                  children: [
                    Icon(Icons.check_circle_outline, color: Colors.green.shade700, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Untuk hasil terbaik, gunakan Upload File audio WAV yang direkam dengan kualitas baik.',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.green.shade900,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Apakah Anda tetap ingin mengaktifkan fitur recording?',
                style: TextStyle(
                  fontSize: 13,
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              // Stay disabled
            },
            child: Text(
              'BATAL',
              style: TextStyle(color: Colors.grey.shade600),
            ),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              setState(() {
                _isRecordingEnabled = true;
              });
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('🎙️ Fitur Recording Diaktifkan (Eksperimental)'),
                  duration: Duration(seconds: 3),
                  backgroundColor: Colors.green,
                ),
              );
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.orange.shade700,
              foregroundColor: Colors.white,
            ),
            child: const Text('AKTIFKAN'),
          ),
        ],
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      ),
    );
  }

  void _showPreprocessModeDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Mode Preprocessing Audio',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.blue.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blue.shade200),
                ),
                child: Row(
                  children: [
                    Icon(Icons.tips_and_updates, color: Colors.blue.shade700, size: 18),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Coba mode berbeda jika hasil kurang akurat',
                        style: TextStyle(
                          fontSize: 11,
                          color: Colors.blue.shade900,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Pilih intensitas preprocessing untuk recording:',
                style: TextStyle(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 12),
            RadioListTile<String>(
              title: const Text('Konservatif'),
              subtitle: const Text(
                'Pemrosesan minimal. Cocok untuk lingkungan tenang dengan suara yang jelas.',
                style: TextStyle(fontSize: 12),
              ),
              value: 'Conservative',
              groupValue: _preprocessMode,
              onChanged: (value) {
                setState(() {
                  _preprocessMode = value!;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mode preprocessing: Konservatif'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const Divider(),
            RadioListTile<String>(
              title: const Text('Standard (Direkomendasikan)'),
              subtitle: const Text(
                'Pemrosesan seimbang. Bekerja untuk sebagian besar kondisi recording.',
                style: TextStyle(fontSize: 12),
              ),
              value: 'Standard',
              groupValue: _preprocessMode,
              onChanged: (value) {
                setState(() {
                  _preprocessMode = value!;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mode preprocessing: Standard'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const Divider(),
            RadioListTile<String>(
              title: const Text('Agresif'),
              subtitle: const Text(
                'Pemrosesan maksimal. Untuk lingkungan bising atau audio yang sulit.',
                style: TextStyle(fontSize: 12),
              ),
              value: 'Aggressive',
              groupValue: _preprocessMode,
              onChanged: (value) {
                setState(() {
                  _preprocessMode = value!;
                });
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Mode preprocessing: Agresif'),
                    duration: Duration(seconds: 2),
                  ),
                );
              },
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.orange.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Hasil recording dapat bervariasi tergantung perangkat dan kondisi lingkungan',
                      style: TextStyle(
                        fontSize: 10,
                        color: Colors.orange.shade900,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('TUTUP'),
          ),
        ],
      ),
    );
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
  final String preprocessMode;

  const _RecordingDialog({
    required this.duration,
    required this.onComplete,
    required this.preprocessMode,
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
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue.shade50,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.shade200),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue.shade700, size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Speak naturally and clearly in a quiet environment',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue.shade900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
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
