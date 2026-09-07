class User {
  final String id;
  final String email;
  final String? passwordHash;
  final String fullName;
  final bool isSuperAdmin;
  final DateTime createdAt;

  const User({
    required this.id,
    required this.email,
    this.passwordHash,
    required this.fullName,
    this.isSuperAdmin = false,
    required this.createdAt,
  });

  /// Creates a [User] from Supabase `users` table JSON map.
  factory User.fromJson(Map<String, dynamic> json) {
    return User(
      id: json['id'] as String,
      email: json['email'] as String? ?? '',
      passwordHash: json['password_hash'] as String?,
      fullName: json['full_name'] as String? ?? '',
      isSuperAdmin: json['is_super_admin'] as bool? ?? false,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  /// Converts this [User] instance to a JSON map matching Supabase columns.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      if (passwordHash != null) 'password_hash': passwordHash,
      'full_name': fullName,
      'is_super_admin': isSuperAdmin,
      'created_at': createdAt.toIso8601String(),
    };
  }

  User copyWith({
    String? id,
    String? email,
    String? passwordHash,
    String? fullName,
    bool? isSuperAdmin,
    DateTime? createdAt,
  }) {
    return User(
      id: id ?? this.id,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      fullName: fullName ?? this.fullName,
      isSuperAdmin: isSuperAdmin ?? this.isSuperAdmin,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  String toString() {
    return 'User(id: $id, email: $email, fullName: $fullName, isSuperAdmin: $isSuperAdmin, createdAt: $createdAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is User &&
        other.id == id &&
        other.email == email &&
        other.passwordHash == passwordHash &&
        other.fullName == fullName &&
        other.isSuperAdmin == isSuperAdmin &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      email,
      passwordHash,
      fullName,
      isSuperAdmin,
      createdAt,
    );
  }
}
