import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/analysis_history.dart';

/// Database helper for managing analysis history
class DatabaseHelper {
  static final DatabaseHelper instance = DatabaseHelper._init();
  static Database? _database;

  DatabaseHelper._init();

  /// Get database instance
  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDB('analysis_history.db');
    return _database!;
  }

  /// Initialize database
  Future<Database> _initDB(String filePath) async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, filePath);

    return await openDatabase(
      path,
      version: 1,
      onCreate: _createDB,
    );
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const textTypeNullable = 'TEXT';

    await db.execute('''
      CREATE TABLE analysis_history (
        id $idType,
        patientName $textType,
        analysisDate $textType,
        result $textType,
        confidence $realType,
        inferenceTime $intType,
        audioFilePath $textTypeNullable
      )
    ''');
  }

  /// Insert new analysis record
  Future<AnalysisHistory> insert(AnalysisHistory history) async {
    final db = await database;
    final id = await db.insert('analysis_history', history.toMap());
    return history.copyWith(id: id);
  }

  /// Get all analysis records (newest first)
  Future<List<AnalysisHistory>> getAllHistory() async {
    final db = await database;
    const orderBy = 'analysisDate DESC';
    final result = await db.query('analysis_history', orderBy: orderBy);
    return result.map((json) => AnalysisHistory.fromMap(json)).toList();
  }

  /// Get analysis record by ID
  Future<AnalysisHistory?> getHistoryById(int id) async {
    final db = await database;
    final maps = await db.query(
      'analysis_history',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return AnalysisHistory.fromMap(maps.first);
    }
    return null;
  }

  /// Search history by patient name
  Future<List<AnalysisHistory>> searchByPatientName(String name) async {
    final db = await database;
    final result = await db.query(
      'analysis_history',
      where: 'patientName LIKE ?',
      whereArgs: ['%$name%'],
      orderBy: 'analysisDate DESC',
    );
    return result.map((json) => AnalysisHistory.fromMap(json)).toList();
  }

  /// Filter history by result type
  Future<List<AnalysisHistory>> getHistoryByResult(String result) async {
    final db = await database;
    final maps = await db.query(
      'analysis_history',
      where: 'result = ?',
      whereArgs: [result],
      orderBy: 'analysisDate DESC',
    );
    return maps.map((json) => AnalysisHistory.fromMap(json)).toList();
  }

  /// Get history count
  Future<int> getHistoryCount() async {
    final db = await database;
    final result = await db.rawQuery('SELECT COUNT(*) FROM analysis_history');
    return Sqflite.firstIntValue(result) ?? 0;
  }

  /// Get statistics
  Future<Map<String, dynamic>> getStatistics() async {
    final allHistory = await getAllHistory();
    
    if (allHistory.isEmpty) {
      return {
        'total': 0,
        'normal': 0,
        'skizofrenia': 0,
        'averageConfidence': 0.0,
      };
    }

    final normalCount = allHistory.where((h) => h.result.toLowerCase() == 'normal').length;
    final skizofreniaCount = allHistory.where((h) => h.result.toLowerCase() == 'skizofrenia').length;
    final avgConfidence = allHistory.fold<double>(
      0.0, 
      (sum, h) => sum + h.confidence,
    ) / allHistory.length;

    return {
      'total': allHistory.length,
      'normal': normalCount,
      'skizofrenia': skizofreniaCount,
      'averageConfidence': avgConfidence,
    };
  }

  /// Delete history record by ID
  Future<int> delete(int id) async {
    final db = await database;
    return await db.delete(
      'analysis_history',
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  /// Delete all history
  Future<int> deleteAll() async {
    final db = await database;
    return await db.delete('analysis_history');
  }

  /// Update history record
  Future<int> update(AnalysisHistory history) async {
    final db = await database;
    return db.update(
      'analysis_history',
      history.toMap(),
      where: 'id = ?',
      whereArgs: [history.id],
    );
  }

  /// Close database
  Future<void> close() async {
    if (_database != null) {
      await _database!.close();
      _database = null;
    }
  }
}
