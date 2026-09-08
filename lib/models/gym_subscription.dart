class GymSubscription {
  final String id;
  final String gymId;
  final Map<String, dynamic> raw;

  const GymSubscription({
    required this.id,
    required this.gymId,
    required this.raw,
  });

  factory GymSubscription.fromJson(Map<String, dynamic> json) {
    return GymSubscription(
      id: json['id'] as String? ?? '',
      gymId: json['gym_id'] as String? ?? '',
      raw: Map<String, dynamic>.from(json),
    );
  }

  Map<String, dynamic> toJson() => Map<String, dynamic>.from(raw);
}
