class Gym {
  final String id;
  final String name;
  final String subdomain;
  final String status;
  final String subscriptionStatus;
  final double pricePerMember;
  final String billingCurrency;
  final DateTime? lastBilledAt;
  final DateTime createdAt;

  const Gym({
    required this.id,
    required this.name,
    required this.subdomain,
    this.status = 'active',
    this.subscriptionStatus = 'none',
    this.pricePerMember = 100.0,
    this.billingCurrency = 'NPR',
    this.lastBilledAt,
    required this.createdAt,
  });

  factory Gym.fromJson(Map<String, dynamic> json) {
    return Gym(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      subdomain: json['subdomain'] as String? ?? '',
      status: json['status'] as String? ?? 'active',
      subscriptionStatus: json['subscription_status'] as String? ?? 'none',
      pricePerMember: (json['price_per_member'] as num?)?.toDouble() ?? 100.0,
      billingCurrency: json['billing_currency'] as String? ?? 'NPR',
      lastBilledAt: json['last_billed_at'] != null
          ? DateTime.tryParse(json['last_billed_at'] as String)
          : null,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'subdomain': subdomain,
      'status': status,
      'subscription_status': subscriptionStatus,
      'price_per_member': pricePerMember,
      'billing_currency': billingCurrency,
      if (lastBilledAt != null) 'last_billed_at': lastBilledAt!.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
    };
  }
}
