import 'package:flutter/material.dart';
import 'dart:typed_data';

class AudioVisualizationDialog extends StatefulWidget {
  final Float32List audioData;
  final List<List<double>> melSpectrogram;
  
  const AudioVisualizationDialog({
    super.key,
    required this.audioData,
    required this.melSpectrogram,
  });

  @override
  State<AudioVisualizationDialog> createState() => _AudioVisualizationDialogState();
}

class _AudioVisualizationDialogState extends State<AudioVisualizationDialog> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        constraints: const BoxConstraints(maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFF6366F1), Color(0xFF8B5CF6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  topRight: Radius.circular(20),
                ),
              ),
              child: Row(
                children: [
                  const Icon(Icons.graphic_eq, color: Colors.white, size: 28),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'Audio Visualization',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            
            // Tab Bar
            Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                border: Border(
                  bottom: BorderSide(color: Colors.grey.shade300),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelColor: const Color(0xFF6366F1),
                unselectedLabelColor: Colors.grey,
                indicatorColor: const Color(0xFF6366F1),
                tabs: const [
                  Tab(
                    icon: Icon(Icons.show_chart),
                    text: 'Waveform',
                  ),
                  Tab(
                    icon: Icon(Icons.gradient),
                    text: 'Spectrogram',
                  ),
                ],
              ),
            ),
            
            // Tab Content
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _WaveformView(audioData: widget.audioData),
                  _SpectrogramView(melSpectrogram: widget.melSpectrogram),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WaveformView extends StatelessWidget {
  final Float32List audioData;
  
  const _WaveformView({required this.audioData});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Audio Waveform',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${audioData.length} samples • ${(audioData.length / 22050).toStringAsFixed(2)}s',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              painter: WaveformPainter(audioData: audioData),
              child: Container(),
            ),
          ),
        ],
      ),
    );
  }
}

class WaveformPainter extends CustomPainter {
  final Float32List audioData;
  
  WaveformPainter({required this.audioData});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = const Color(0xFF6366F1)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final centerY = size.height / 2;
    final path = Path();
    
    // Downsample for performance (show max 1000 points)
    final step = (audioData.length / 1000).ceil();
    
    path.moveTo(0, centerY);
    
    for (int i = 0; i < audioData.length; i += step) {
      final x = (i / audioData.length) * size.width;
      final amplitude = audioData[i];
      final y = centerY - (amplitude * centerY * 0.8); // Scale to 80% of half height
      path.lineTo(x, y);
    }
    
    canvas.drawPath(path, paint);
    
    // Draw center line
    final centerLinePaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1.0;
    canvas.drawLine(
      Offset(0, centerY),
      Offset(size.width, centerY),
      centerLinePaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _SpectrogramView extends StatelessWidget {
  final List<List<double>> melSpectrogram;
  
  const _SpectrogramView({required this.melSpectrogram});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            'Mel Spectrogram',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: Colors.grey.shade800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${melSpectrogram[0].length} time frames • ${melSpectrogram.length} mel bands',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
          const SizedBox(height: 20),
          Expanded(
            child: CustomPaint(
              painter: SpectrogramPainter(melSpectrogram: melSpectrogram),
              child: Container(),
            ),
          ),
          const SizedBox(height: 12),
          // Color scale legend
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 100,
                height: 20,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [
                      Colors.blue,
                      Colors.cyan,
                      Colors.green,
                      Colors.yellow,
                      Colors.red,
                    ],
                  ),
                  borderRadius: BorderRadius.circular(4),
                  border: Border.all(color: Colors.grey.shade400),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Low → High Energy',
                style: TextStyle(
                  fontSize: 11,
                  color: Colors.grey.shade600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class SpectrogramPainter extends CustomPainter {
  final List<List<double>> melSpectrogram;
  
  SpectrogramPainter({required this.melSpectrogram});

  Color _valueToColor(double normalizedValue) {
    // Map value [0,1] to color gradient: blue -> cyan -> green -> yellow -> red
    if (normalizedValue < 0.25) {
      // Blue to Cyan
      return Color.lerp(Colors.blue, Colors.cyan, normalizedValue / 0.25)!;
    } else if (normalizedValue < 0.5) {
      // Cyan to Green
      return Color.lerp(Colors.cyan, Colors.green, (normalizedValue - 0.25) / 0.25)!;
    } else if (normalizedValue < 0.75) {
      // Green to Yellow
      return Color.lerp(Colors.green, Colors.yellow, (normalizedValue - 0.5) / 0.25)!;
    } else {
      // Yellow to Red
      return Color.lerp(Colors.yellow, Colors.red, (normalizedValue - 0.75) / 0.25)!;
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (melSpectrogram.isEmpty || melSpectrogram[0].isEmpty) return;
    
    final numBands = melSpectrogram.length;
    final numFrames = melSpectrogram[0].length;
    
    // Find min and max for normalization
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    
    for (var band in melSpectrogram) {
      for (var value in band) {
        if (value < minVal) minVal = value;
        if (value > maxVal) maxVal = value;
      }
    }
    
    final range = maxVal - minVal;
    if (range == 0) return;
    
    final cellWidth = size.width / numFrames;
    final cellHeight = size.height / numBands;
    
    // Draw spectrogram (frequency axis is inverted: high freq at top)
    for (int bandIdx = 0; bandIdx < numBands; bandIdx++) {
      for (int frameIdx = 0; frameIdx < numFrames; frameIdx++) {
        final value = melSpectrogram[bandIdx][frameIdx];
        final normalizedValue = (value - minVal) / range;
        
        final paint = Paint()
          ..color = _valueToColor(normalizedValue)
          ..style = PaintingStyle.fill;
        
        // Draw from top (high freq) to bottom (low freq)
        final rect = Rect.fromLTWH(
          frameIdx * cellWidth,
          (numBands - 1 - bandIdx) * cellHeight, // Invert y-axis
          cellWidth,
          cellHeight,
        );
        
        canvas.drawRect(rect, paint);
      }
    }
    
    // Draw border
    final borderPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;
    canvas.drawRect(Offset.zero & size, borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
