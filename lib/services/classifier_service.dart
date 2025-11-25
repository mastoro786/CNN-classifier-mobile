import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'audio_processor.dart';

/// TensorFlow Lite classifier service for audio classification
class ClassifierService {
  Interpreter? _interpreter;
  List<String> _labels = [];
  
  bool get isLoaded => _interpreter != null;
  
  /// Check if audio is silence (no voice detected)
  /// Uses RMS energy threshold optimized for speech detection
  bool isSilence(Float32List samples, {double threshold = 0.0005}) {
    if (samples.isEmpty) return true;
    
    // Calculate RMS (Root Mean Square) energy
    double sumSquares = 0.0;
    for (var sample in samples) {
      sumSquares += sample * sample;
    }
    double energy = sumSquares / samples.length;
    
    // Also check peak amplitude to detect very quiet recordings
    double maxAbs = 0.0;
    for (var sample in samples) {
      final abs = sample.abs();
      if (abs > maxAbs) maxAbs = abs;
    }
    
    print('🔊 Audio energy check:');
    print('   RMS Energy: ${energy.toStringAsFixed(8)}');
    print('   Peak Amplitude: ${maxAbs.toStringAsFixed(6)}');
    print('   Threshold: $threshold');
    print('   Samples count: ${samples.length}');
    print('   First 10 samples: ${samples.take(10).toList()}');
    
    // Consider silence if BOTH energy is low AND peak amplitude is very low
    // Adjusted thresholds for normalized audio
    final isSilent = energy < threshold && maxAbs < 0.005;
    print('   Is silence: $isSilent (energy < $threshold AND peak < 0.005)');
    
    return isSilent;
  }
  
  /// Load TFLite model
  Future<void> loadModel() async {
    try {
      print('📦 Loading TFLite model...');
      
      // Load model (non-quantized version for better accuracy)
      _interpreter = await Interpreter.fromAsset(
        'assets/models/audio_classifier.tflite',
        options: InterpreterOptions()..threads = 4,
      );
      
      print('✅ Model loaded successfully');
      print('   Input tensors: ${_interpreter!.getInputTensors()}');
      print('   Output tensors: ${_interpreter!.getOutputTensors()}');
      
      // Load labels
      await _loadLabels();
      
    } catch (e) {
      print('❌ Error loading model: $e');
      rethrow;
    }
  }
  
  /// Load class labels
  Future<void> _loadLabels() async {
    final labelsData = await rootBundle.loadString(
      'assets/models/label_map.txt',
    );
    _labels = labelsData.split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();
    
    print('📋 Labels loaded: $_labels');
  }
  
  /// Run inference on audio
  Future<ClassificationResult> classify(
    Float32List audioSamples, {
    bool includeVisualizationData = false,
    bool applyPreEmphasis = false,
  }) async {
    if (!isLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }
    
    print('\n🔮 Running inference...');
    final stopwatch = Stopwatch()..start();
    
    // 1. Extract features
    print('   1️⃣ Extracting Mel Spectrogram...');
    final melSpec = await AudioProcessor.extractMelSpectrogram(
      audioSamples,
      applyPreEmphasis: applyPreEmphasis,
    );
    
    // 2. Prepare input
    print('   2️⃣ Preparing model input...');
    final input = AudioProcessor.toModelInput(melSpec);
    
    // ========== DEBUG: Input to Model ==========
    print('\n${'='*60}');
    print('🔬 DEBUG: Input to Model');
    print('='*60);
    
    // Get input statistics
    double minVal = double.infinity;
    double maxVal = double.negativeInfinity;
    double sum = 0;
    int count = 0;
    
    for (var batch in input) {
      for (var mel in batch) {
        for (var time in mel) {
          for (var channel in time) {
            double val = channel;
            if (val < minVal) minVal = val;
            if (val > maxVal) maxVal = val;
            sum += val;
            count++;
          }
        }
      }
    }
    
    double mean = sum / count;
    
    print('Input shape: (${input.length}, ${input[0].length}, ${input[0][0].length}, ${input[0][0][0].length})');
    print('Input min: ${minVal.toStringAsFixed(2)} dB');
    print('Input max: ${maxVal.toStringAsFixed(2)} dB');
    print('Input mean: ${mean.toStringAsFixed(2)} dB');
    
    // Print first 10 values (mel band 0)
    List<double> first10 = [];
    for (int i = 0; i < 10 && i < input[0][0].length; i++) {
      first10.add(input[0][0][i][0]);
    }
    print('First 10 time frames (mel band 0):');
    print('  ${first10.map((v) => v.toStringAsFixed(2)).join(", ")}');
    
    print('='*60);
    // ========== END DEBUG ==========
    
    // 3. Create output buffer
    // Output shape: (1, 1) for binary classification with sigmoid
    var output = List.filled(1, 0.0).reshape([1, 1]);
    
    // 4. Run inference
    print('\n   3️⃣ Running TFLite inference...');
    _interpreter!.run(input, output);
    
    // 5. Process output
    print('\n   4️⃣ Processing results...');
    
    // ========== DEBUG: Model Output ==========
    print('\n${'='*60}');
    print('🔬 DEBUG: Model Output');
    print('='*60);
    print('Raw output shape: (${output.length}, ${output[0].length})');
    print('Raw output[0][0]: ${output[0][0]}');
    print('Output type: ${output[0][0].runtimeType}');
    print('='*60 + '\n');
    // ========== END DEBUG ==========
    
    print('   Raw model output (sigmoid): ${output[0][0]}');
    
    // Model output: sigmoid probability for class 1 (skizofrenia)
    double rawOutput = output[0][0];
    double probSkizofrenia = rawOutput;
    double probNormal = 1.0 - rawOutput;
    
    print('   Prob Normal: ${(probNormal * 100).toStringAsFixed(2)}%');
    print('   Prob Skizofrenia: ${(probSkizofrenia * 100).toStringAsFixed(2)}%');
    
    List<double> probabilities = [probNormal, probSkizofrenia];
    int predictedIndex = probNormal > probSkizofrenia ? 0 : 1;
    String predictedClass = _labels[predictedIndex];
    double confidence = probabilities[predictedIndex];
    
    stopwatch.stop();
    
    print('✅ Inference complete!');
    print('   Time: ${stopwatch.elapsedMilliseconds}ms');
    print('   Predicted Index: $predictedIndex');
    print('   Result: $predictedClass (${(confidence * 100).toStringAsFixed(1)}%)');
    
    return ClassificationResult(
      predictedClass: predictedClass,
      confidence: confidence,
      probabilities: {
        _labels[0]: probabilities[0],
        _labels[1]: probabilities[1],
      },
      inferenceTime: stopwatch.elapsedMilliseconds,
      audioData: includeVisualizationData ? audioSamples : null,
      melSpectrogram: includeVisualizationData ? melSpec : null,
    );
  }
  
  /// Dispose resources
  void dispose() {
    _interpreter?.close();
    _interpreter = null;
  }
}

/// Classification result model
class ClassificationResult {
  final String predictedClass;
  final double confidence;
  final Map<String, double> probabilities;
  final int inferenceTime;
  final Float32List? audioData;
  final List<List<double>>? melSpectrogram;
  
  ClassificationResult({
    required this.predictedClass,
    required this.confidence,
    required this.probabilities,
    required this.inferenceTime,
    this.audioData,
    this.melSpectrogram,
  });
  
  // Helper getters for easier access
  String get predictedLabel => predictedClass;
  int get predictedIndex => predictedClass.toLowerCase() == 'normal' ? 0 : 1;
  List<double> get probabilitiesList => [
    probabilities['normal'] ?? 0.0,
    probabilities['skizofrenia'] ?? 0.0,
  ];
  
  bool get isNormal => predictedClass.toLowerCase() == 'normal';
  bool get isHighConfidence => confidence >= 0.8;
  bool get isMediumConfidence => confidence >= 0.6 && confidence < 0.8;
  bool get isLowConfidence => confidence < 0.6;
  
  String get confidenceLevel {
    if (isHighConfidence) return 'High';
    if (isMediumConfidence) return 'Medium';
    return 'Low';
  }
  
  @override
  String toString() {
    return 'ClassificationResult(class: $predictedClass, confidence: ${(confidence * 100).toStringAsFixed(1)}%, time: ${inferenceTime}ms)';
  }
}
