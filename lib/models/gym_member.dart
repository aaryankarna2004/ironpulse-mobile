import 'user.dart';

class GymMember {
  final String id;
  final String gymId;
  final String userId;
  final String role;
  final String status;
  final DateTime createdAt;
  final User? user;

  const GymMember({
    required this.id,
    required this.gymId,
    required this.userId,
    required this.role,
    required this.status,
    required this.createdAt,
    this.user,
  });

  /// Creates a [GymMember] from Supabase `gym_members` table JSON map.
  /// Also parses optional joined `users` object if present (e.g. `.select('*, users(*)')`).
  factory GymMember.fromJson(Map<String, dynamic> json) {
    return GymMember(
      id: json['id'] as String,
      gymId: json['gym_id'] as String? ?? '',
      userId: json['user_id'] as String? ?? '',
      role: json['role'] as String? ?? 'member',
      status: json['status'] as String? ?? 'active',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
      user: json['users'] != null && json['users'] is Map<String, dynamic>
          ? User.fromJson(json['users'] as Map<String, dynamic>)
          : null,
    );
  }

  /// Converts this [GymMember] instance to a JSON map matching Supabase columns.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'user_id': userId,
      'role': role,
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }

  GymMember copyWith({
    String? id,
    String? gymId,
    String? userId,
    String? role,
    String? status,
    DateTime? createdAt,
    User? user,
  }) {
    return GymMember(
      id: id ?? this.id,
      gymId: gymId ?? this.gymId,
      userId: userId ?? this.userId,
      role: role ?? this.role,
      status: status ?? this.status,
      createdAt: createdAt ?? this.createdAt,
      user: user ?? this.user,
    );
  }

  @override
  String toString() {
    return 'GymMember(id: $id, gymId: $gymId, userId: $userId, role: $role, status: $status, createdAt: $createdAt, user: $user)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is GymMember &&
        other.id == id &&
        other.gymId == gymId &&
        other.userId == userId &&
        other.role == role &&
        other.status == status &&
        other.createdAt == createdAt &&
        other.user == user;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      gymId,
      userId,
      role,
      status,
      createdAt,
      user,
    );
  }
}
