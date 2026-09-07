class Attendance {
  final String id;
  final String gymMemberId;
  final String gymId;
  final String checkInDate;
  final DateTime createdAt;

  const Attendance({
    required this.id,
    required this.gymMemberId,
    required this.gymId,
    required this.checkInDate,
    required this.createdAt,
  });

  factory Attendance.fromJson(Map<String, dynamic> json) {
    return Attendance(
      id: json['id'] as String,
      gymMemberId: json['gym_member_id'] as String? ?? '',
      gymId: json['gym_id'] as String? ?? '',
      checkInDate: json['check_in_date'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_member_id': gymMemberId,
      'gym_id': gymId,
      'check_in_date': checkInDate,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
