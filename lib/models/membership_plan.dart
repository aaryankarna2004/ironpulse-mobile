class MembershipPlan {
  final String id;
  final String gymId;
  final String name;
  final double price;
  final String billingCycle;
  final String? description;
  final DateTime createdAt;

  const MembershipPlan({
    required this.id,
    required this.gymId,
    required this.name,
    required this.price,
    required this.billingCycle,
    this.description,
    required this.createdAt,
  });

  factory MembershipPlan.fromJson(Map<String, dynamic> json) {
    return MembershipPlan(
      id: json['id'] as String,
      gymId: json['gym_id'] as String? ?? '',
      name: json['name'] as String? ?? '',
      price: (json['price'] as num?)?.toDouble() ?? 0.0,
      billingCycle: json['billing_cycle'] as String? ?? 'monthly',
      description: json['description'] as String?,
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
      'price': price,
      'billing_cycle': billingCycle,
      if (description != null) 'description': description,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
