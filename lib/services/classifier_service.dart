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
  bool isSilence(Float32List samples, {double threshold = 0.0001}) {
    if (samples.isEmpty) return true;
    
    // Calculate RMS (Root Mean Square) energy
    double sumSquares = 0.0;
    for (var sample in samples) {
      sumSquares += sample * sample;
    }
    double rms = sumSquares / samples.length;
    double energy = rms;
    
    print('🔊 Audio energy: ${energy.toStringAsFixed(8)} (threshold: $threshold)');
    print('   Samples count: ${samples.length}');
    print('   First 10 samples: ${samples.take(10).toList()}');
    print('   Is silence: ${energy < threshold}');
    
    return energy < threshold;
  }
  
  /// Load TFLite model
  Future<void> loadModel() async {
    try {
      print('📦 Loading TFLite model...');
      
      // Load model
      _interpreter = await Interpreter.fromAsset(
        'assets/models/audio_classifier_quantized.tflite',
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
  Future<ClassificationResult> classify(Float32List audioSamples) async {
    if (!isLoaded) {
      throw Exception('Model not loaded. Call loadModel() first.');
    }
    
    print('\n🔮 Running inference...');
    final stopwatch = Stopwatch()..start();
    
    // 1. Extract features
    print('   1️⃣ Extracting Mel Spectrogram...');
    final melSpec = await AudioProcessor.extractMelSpectrogram(audioSamples);
    
    // 2. Prepare input
    print('   2️⃣ Preparing model input...');
    final input = AudioProcessor.toModelInput(melSpec);
    
    // 3. Create output buffer
    // Output shape: (1, 1) for binary classification with sigmoid
    var output = List.filled(1, 0.0).reshape([1, 1]);
    
    // 4. Run inference
    print('   3️⃣ Running TFLite inference...');
    _interpreter!.run(input, output);
    
    // 5. Process output
    print('   4️⃣ Processing results...');
    double probSkizofrenia = output[0][0];
    double probNormal = 1.0 - probSkizofrenia;
    
    List<double> probabilities = [probNormal, probSkizofrenia];
    int predictedIndex = probNormal > probSkizofrenia ? 0 : 1;
    String predictedClass = _labels[predictedIndex];
    double confidence = probabilities[predictedIndex];
    
    stopwatch.stop();
    
    print('✅ Inference complete!');
    print('   Time: ${stopwatch.elapsedMilliseconds}ms');
    print('   Result: $predictedClass (${(confidence * 100).toStringAsFixed(1)}%)');
    
    return ClassificationResult(
      predictedClass: predictedClass,
      confidence: confidence,
      probabilities: {
        _labels[0]: probabilities[0],
        _labels[1]: probabilities[1],
      },
      inferenceTime: stopwatch.elapsedMilliseconds,
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
  
  ClassificationResult({
    required this.predictedClass,
    required this.confidence,
    required this.probabilities,
    required this.inferenceTime,
  });
  
  // Helper getters for easier access
  String get predictedLabel => predictedClass;
  int get predictedIndex => predictedClass == 'Normal' ? 0 : 1;
  List<double> get probabilitiesList => [
    probabilities['Normal'] ?? 0.0,
    probabilities['Skizofrenia'] ?? 0.0,
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
