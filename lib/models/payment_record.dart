class PaymentRecord {
  final String id;
  final String gymId;
  final String gymMemberId;
  final double amount;
  final String currency;
  final String status;
  final String transactionId;
  final DateTime paymentDate;

  const PaymentRecord({
    required this.id,
    required this.gymId,
    required this.gymMemberId,
    required this.amount,
    required this.currency,
    required this.status,
    required this.transactionId,
    required this.paymentDate,
  });

  factory PaymentRecord.fromJson(Map<String, dynamic> json) {
    return PaymentRecord(
      id: json['id'] as String,
      gymId: json['gym_id'] as String? ?? '',
      gymMemberId: json['gym_member_id'] as String? ?? '',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      currency: json['currency'] as String? ?? 'NPR',
      status: json['status'] as String? ?? '',
      transactionId: json['transaction_id'] as String? ?? '',
      paymentDate: json['payment_date'] != null
          ? DateTime.tryParse(json['payment_date'] as String) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'gym_id': gymId,
      'gym_member_id': gymMemberId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'transaction_id': transactionId,
      'payment_date': paymentDate.toIso8601String(),
    };
  }
}
