class SubscriptionModel {
  final String userId;
  final String plan; // start | breakthrough | empire
  final String status; // trial | active | past_due | expired | canceled
  final String billingPeriod; // monthly | yearly
  final DateTime? currentPeriodStart;
  final DateTime? currentPeriodEnd;

  const SubscriptionModel({
    required this.userId,
    required this.plan,
    required this.status,
    required this.billingPeriod,
    this.currentPeriodStart,
    this.currentPeriodEnd,
  });

  factory SubscriptionModel.fromJson(Map<String, dynamic> json) {
    DateTime? parseDt(dynamic raw) {
      if (raw == null) return null;
      final s = raw.toString();
      if (s.isEmpty) return null;
      return DateTime.tryParse(s);
    }

    return SubscriptionModel(
      userId: (json['user_id'] ?? json['userId'])?.toString() ?? '',
      plan: (json['plan_id'] ?? json['plan'])?.toString() ?? 'start',
      status: json['status']?.toString() ?? 'trial',
      billingPeriod: (json['billing_period'] ?? json['billingPeriod'])?.toString() ?? 'monthly',
      currentPeriodStart: parseDt(json['current_period_start']),
      currentPeriodEnd: parseDt(json['current_period_end']),
    );
  }

  bool get isActiveNow {
    if (status != 'active' && status != 'trial') return false;
    final end = currentPeriodEnd;
    if (end == null) return true;
    return end.isAfter(DateTime.now());
  }
}

