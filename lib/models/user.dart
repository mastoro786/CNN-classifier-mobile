/// User model for authentication
class User {
  final int? id;
  final String username;
  final String password;
  final String fullName;
  final DateTime createdAt;

  User({
    this.id,
    required this.username,
    required this.password,
    required this.fullName,
    required this.createdAt,
  });

  /// Convert User to Map for database
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'password': password,
      'full_name': fullName,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Create User from Map
  factory User.fromMap(Map<String, dynamic> map) {
    return User(
      id: map['id'] as int?,
      username: map['username'] as String,
      password: map['password'] as String,
      fullName: map['full_name'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }

  /// Create a copy with updated fields
  User copyWith({
    int? id,
    String? username,
    String? password,
    String? fullName,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      password: password ?? this.password,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
