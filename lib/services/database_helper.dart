import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';
import '../models/analysis_history.dart';
import '../models/user.dart';

/// Database helper for managing analysis history and users
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
      version: 2, // Increment version for migration
      onCreate: _createDB,
      onUpgrade: _onUpgrade,
    );
  }

  /// Create database tables
  Future<void> _createDB(Database db, int version) async {
    const idType = 'INTEGER PRIMARY KEY AUTOINCREMENT';
    const textType = 'TEXT NOT NULL';
    const realType = 'REAL NOT NULL';
    const intType = 'INTEGER NOT NULL';
    const textTypeNullable = 'TEXT';

    // Users table
    await db.execute('''
      CREATE TABLE users (
        id $idType,
        username $textType UNIQUE,
        password $textType,
        full_name $textType,
        created_at $textType
      )
    ''');

    // Analysis history table with user_id foreign key
    await db.execute('''
      CREATE TABLE analysis_history (
        id $idType,
        user_id $intType,
        patientName $textType,
        analysisDate $textType,
        result $textType,
        confidence $realType,
        inferenceTime $intType,
        audioFilePath $textTypeNullable,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
  }

  /// Upgrade database schema
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Add users table
      await db.execute('''
        CREATE TABLE IF NOT EXISTS users (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          username TEXT NOT NULL UNIQUE,
          password TEXT NOT NULL,
          full_name TEXT NOT NULL,
          created_at TEXT NOT NULL
        )
      ''');

      // Add user_id column to analysis_history
      await db.execute('''
        ALTER TABLE analysis_history ADD COLUMN user_id INTEGER DEFAULT 1
      ''');

      // Create default admin user for existing data
      await db.execute('''
        INSERT OR IGNORE INTO users (id, username, password, full_name, created_at)
        VALUES (1, 'admin', 'admin123', 'Administrator', '${DateTime.now().toIso8601String()}')
      ''');
    }
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

  /// Get analysis records by user ID (newest first)
  Future<List<AnalysisHistory>> getHistoryByUserId(int userId) async {
    final db = await database;
    final result = await db.query(
      'analysis_history',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'analysisDate DESC',
    );
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

  // ==================== USER METHODS ====================

  /// Insert new user
  Future<int> insertUser(User user) async {
    final db = await database;
    return await db.insert('users', user.toMap());
  }

  /// Get user by ID
  Future<User?> getUserById(int id) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'id = ?',
      whereArgs: [id],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// Get user by username
  Future<User?> getUserByUsername(String username) async {
    final db = await database;
    final maps = await db.query(
      'users',
      where: 'username = ?',
      whereArgs: [username],
    );

    if (maps.isNotEmpty) {
      return User.fromMap(maps.first);
    }
    return null;
  }

  /// Get all users
  Future<List<User>> getAllUsers() async {
    final db = await database;
    final result = await db.query('users', orderBy: 'created_at DESC');
    return result.map((json) => User.fromMap(json)).toList();
  }

  /// Update user
  Future<int> updateUser(User user) async {
    final db = await database;
    return db.update(
      'users',
      user.toMap(),
      where: 'id = ?',
      whereArgs: [user.id],
    );
  }

  /// Delete user
  Future<int> deleteUser(int id) async {
    final db = await database;
    return await db.delete(
      'users',
      where: 'id = ?',
      whereArgs: [id],
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
