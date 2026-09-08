class ClassBooking {
  final String id;
  final String gymMemberId;
  final String classId;
  final String gymId;
  final DateTime bookedAt;

  const ClassBooking({
    required this.id,
    required this.gymMemberId,
    required this.classId,
    required this.gymId,
    required this.bookedAt,
  });

  factory ClassBooking.fromJson(Map<String, dynamic> json) {
    return ClassBooking(
      id: json['id'] as String,
      gymMemberId: json['gym_member_id'] as String? ?? '',
      classId: json['class_id'] as String? ?? '',
      gymId: json['gym_id'] as String? ?? '',
      bookedAt: json['booked_at'] != null
          ? DateTime.tryParse(json['booked_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_member_id': gymMemberId,
      'class_id': classId,
      'gym_id': gymId,
      'booked_at': bookedAt.toIso8601String(),
    };
  }
}
