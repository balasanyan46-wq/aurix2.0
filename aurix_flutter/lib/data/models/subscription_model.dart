class SubscriptionModel {
  final String userId;
  final String plan; // start | breakthrough | empire
  final String status; // inactive | active | past_due | canceled
  final String billingPeriod; // monthly | yearly

  const SubscriptionModel({
    required this.userId,
    required this.plan,
    required this.status,
    required this.billingPeriod,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    return SubscriptionModel(
      userId: (json['user_id'] ?? json['userId']) as String? ?? '',
      plan: (json['plan'] as String?) ?? 'start',
      status: (json['status'] as String?) ?? 'inactive',
      billingPeriod: (json['billing_period'] as String?) ?? (json['billingPeriod'] as String?) ?? 'monthly',
    );
  }
}

