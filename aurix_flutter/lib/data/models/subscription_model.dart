class SubscriptionModel {
  final String userId;
  final String plan; // free | start | breakthrough | empire
  final String status; // none | active | expired | canceled
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
      plan: (json['plan_id'] ?? json['plan'])?.toString() ?? 'free',
      status: json['status']?.toString() ?? 'none',
      billingPeriod: (json['billing_period'] ?? json['billingPeriod'])?.toString() ?? 'monthly',
      currentPeriodStart: parseDt(json['current_period_start']),
      currentPeriodEnd: parseDt(json['current_period_end']),
    );
  }

  /// A subscription is active ONLY if:
  /// 1. status == 'active'
  /// 2. plan is not 'free'
  /// 3. currentPeriodEnd exists and is in the future
  bool get isActiveNow {
    if (status != 'active') return false;
    if (plan == 'free') return false;
    final end = currentPeriodEnd;
    if (end == null) return false;
    return end.isAfter(DateTime.now());
  }

  bool get isFree => plan == 'free' || plan.isEmpty;
}

