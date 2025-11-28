import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';
import '../services/database_helper.dart';

/// Authentication provider for managing user login state
class AuthProvider extends ChangeNotifier {
  User? _currentUser;
  bool _isLoading = false;

  User? get currentUser => _currentUser;
  bool get isLoggedIn => _currentUser != null;
  bool get isLoading => _isLoading;

  /// Initialize auth state from SharedPreferences
  Future<void> init() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      final userId = prefs.getInt('user_id');

      if (userId != null) {
        // Load user from database
        _currentUser = await DatabaseHelper.instance.getUserById(userId);
      }
    } catch (e) {
      print('❌ Error loading user: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Register new user
  Future<Map<String, dynamic>> register({
    required String username,
    required String password,
    required String fullName,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      // Check if username already exists
      final existingUser = await DatabaseHelper.instance.getUserByUsername(username);
      if (existingUser != null) {
        _isLoading = false;
        notifyListeners();
        return {
          'success': false,
          'message': 'Username sudah digunakan',
        };
      }

      // Create new user
      final user = User(
        username: username,
        password: password, // In production, use proper hashing!
        fullName: fullName,
        createdAt: DateTime.now(),
      );

      final userId = await DatabaseHelper.instance.insertUser(user);
      _currentUser = user.copyWith(id: userId);

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', userId);

      _isLoading = false;
      notifyListeners();
      return {
        'success': true,
        'message': 'Registrasi berhasil',
      };
    } catch (e) {
      print('❌ Registration error: $e');
      _isLoading = false;
      notifyListeners();
      return {
        'success': false,
        'message': 'Terjadi kesalahan: ${e.toString()}',
      };
    }
  }

  /// Login user
  Future<bool> login({
    required String username,
    required String password,
  }) async {
    try {
      _isLoading = true;
      notifyListeners();

      final user = await DatabaseHelper.instance.getUserByUsername(username);

      if (user == null || user.password != password) {
        _isLoading = false;
        notifyListeners();
        return false;
      }

      _currentUser = user;

      // Save to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.setInt('user_id', user.id!);

      _isLoading = false;
      notifyListeners();
      return true;
    } catch (e) {
      print('❌ Login error: $e');
      _isLoading = false;
      notifyListeners();
      return false;
    }
  }

  /// Logout user
  Future<void> logout() async {
    try {
      _currentUser = null;
      
      // Clear SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('user_id');
      
      notifyListeners();
    } catch (e) {
      print('❌ Logout error: $e');
    }
  }
}
