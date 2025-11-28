/// Model for analysis history stored in SQLite
class AnalysisHistory {
  final int? id;
  final int userId; // Foreign key to users table
  final String patientName;
  final DateTime analysisDate;
  final String result; // Normal or Skizofrenia
  final double confidence; // Accuracy percentage
  final int inferenceTime; // Processing time in ms
  final String? audioFilePath; // Optional: path to audio file

  AnalysisHistory({
    this.id,
    required this.userId,
    required this.patientName,
    required this.analysisDate,
    required this.result,
    required this.confidence,
    required this.inferenceTime,
    this.audioFilePath,
  });

  /// Convert to Map for SQLite
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'patientName': patientName,
      'analysisDate': analysisDate.toIso8601String(),
      'result': result,
      'confidence': confidence,
      'inferenceTime': inferenceTime,
      'audioFilePath': audioFilePath,
    };
  }

  /// Create from Map (from SQLite)
  factory AnalysisHistory.fromMap(Map<String, dynamic> map) {
    return AnalysisHistory(
      id: map['id'] as int?,
      userId: map['user_id'] as int? ?? 1, // Default to 1 for backward compatibility
      patientName: map['patientName'] as String,
      analysisDate: DateTime.parse(map['analysisDate'] as String),
      result: map['result'] as String,
      confidence: map['confidence'] as double,
      inferenceTime: map['inferenceTime'] as int,
      audioFilePath: map['audioFilePath'] as String?,
    );
  }

  /// Get confidence as percentage string
  String get confidencePercent => '${(confidence * 100).toStringAsFixed(1)}%';

  /// Get formatted date
  String get formattedDate {
    final day = analysisDate.day.toString().padLeft(2, '0');
    final month = analysisDate.month.toString().padLeft(2, '0');
    final year = analysisDate.year;
    final hour = analysisDate.hour.toString().padLeft(2, '0');
    final minute = analysisDate.minute.toString().padLeft(2, '0');
    return '$day/$month/$year $hour:$minute';
  }

  /// Copy with method for updating
  AnalysisHistory copyWith({
    int? id,
    int? userId,
    String? patientName,
    DateTime? analysisDate,
    String? result,
    double? confidence,
    int? inferenceTime,
    String? audioFilePath,
  }) {
    return AnalysisHistory(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      patientName: patientName ?? this.patientName,
      analysisDate: analysisDate ?? this.analysisDate,
      result: result ?? this.result,
      confidence: confidence ?? this.confidence,
      inferenceTime: inferenceTime ?? this.inferenceTime,
      audioFilePath: audioFilePath ?? this.audioFilePath,
    );
  }
}
