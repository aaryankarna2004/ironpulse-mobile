class Trainer {
  final String id;
  final String gymId;
  final String name;
  final String specialization;
  final String status;
  final int membersCount;
  final double rating;
  final String? imageUrl;
  final DateTime createdAt;

  const Trainer({
    required this.id,
    required this.gymId,
    required this.name,
    required this.specialization,
    required this.status,
    this.membersCount = 0,
    this.rating = 5.0,
    this.imageUrl,
    required this.createdAt,
  });

  factory Trainer.fromJson(Map<String, dynamic> json) {
    return Trainer(
      id: json['id'] as String,
      gymId: json['gym_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      specialization: json['specialization'] as String? ?? '',
      status: json['status'] as String? ?? 'Available',
      membersCount: json['members_count'] as int? ?? 0,
      rating: (json['rating'] as num?)?.toDouble() ?? 5.0,
      imageUrl: json['image_url'] as String?,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'name': name,
      'specialization': specialization,
      'status': status,
      'members_count': membersCount,
      'rating': rating,
      if (imageUrl != null) 'image_url': imageUrl,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
