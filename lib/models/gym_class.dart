class GymClass {
  final String id;
  final String gymId;
  final String name;
  final String category;
  final String coach;
  final int dayOfWeek;
  final String startTime;
  final String endTime;
  final int capacity;
  final int enrolled;
  final DateTime createdAt;

  const GymClass({
    required this.id,
    required this.gymId,
    required this.name,
    required this.category,
    required this.coach,
    required this.dayOfWeek,
    required this.startTime,
    required this.endTime,
    required this.capacity,
    this.enrolled = 0,
    required this.createdAt,
  });

  factory GymClass.fromJson(Map<String, dynamic> json) {
    return GymClass(
      id: json['id'] as String,
      gymId: json['gym_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      coach: json['coach'] as String? ?? '',
      dayOfWeek: json['day_of_week'] as int? ?? 0,
      startTime: json['start_time'] as String? ?? '',
      endTime: json['end_time'] as String? ?? '',
      capacity: json['capacity'] as int? ?? 0,
      enrolled: json['enrolled'] as int? ?? 0,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String get dayName {
    const days = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
    if (dayOfWeek >= 0 && dayOfWeek < days.length) return days[dayOfWeek];
    return 'Day $dayOfWeek';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'name': name,
      'category': category,
      'coach': coach,
      'day_of_week': dayOfWeek,
      'start_time': startTime,
      'end_time': endTime,
      'capacity': capacity,
      'enrolled': enrolled,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
