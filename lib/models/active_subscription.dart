class ActiveSubscription {
  final String id;
  final String gymMemberId;
  final String? planId;
  final DateTime startDate;
  final DateTime endDate;
  final String status;
  final DateTime createdAt;

  const ActiveSubscription({
    required this.id,
    required this.gymMemberId,
    this.planId,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.createdAt,
  });

  factory ActiveSubscription.fromJson(Map<String, dynamic> json) {
    return ActiveSubscription(
      id: json['id'] as String,
      gymMemberId: json['gym_member_id'] as String? ?? '',
      planId: json['plan_id'] as String?,
      startDate: json['start_date'] != null
          ? DateTime.tryParse(json['start_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      endDate: json['end_date'] != null
          ? DateTime.tryParse(json['end_date'] as String) ?? DateTime.now()
          : DateTime.now(),
      status: json['status'] as String? ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_member_id': gymMemberId,
      if (planId != null) 'plan_id': planId,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'status': status,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
