class BillingSubscriptionModel {
  final String id;
  final String userId;
  final String planId;
  final String status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final bool cancelAtPeriodEnd;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BillingSubscriptionModel({
    required this.id,
    required this.userId,
    required this.planId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    required this.cancelAtPeriodEnd,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BillingSubscriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime parseDate(String key) {
      final raw = json[key]?.toString();
      final dt = raw == null ? null : DateTime.tryParse(raw);
      return dt ?? DateTime.now();
    }

    return BillingSubscriptionModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      planId: (json['plan_id'] ?? 'start').toString(),
      status: (json['status'] ?? 'trial').toString(),
      currentPeriodStart: parseDate('current_period_start'),
      currentPeriodEnd: parseDate('current_period_end'),
      cancelAtPeriodEnd: json['cancel_at_period_end'] == true,
      createdAt: parseDate('created_at'),
      updatedAt: parseDate('updated_at'),
    );
  }
}

