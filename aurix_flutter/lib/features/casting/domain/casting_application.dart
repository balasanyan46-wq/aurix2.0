class CastingApplication {
  final int id;
  final int userId;
  final String name;
  final String artistName;
  final String phone;
  final String city;
  final String plan;
  final String status;
  final String? orderId;
  final int amount;
  final DateTime createdAt;
  final DateTime? paidAt;

  const CastingApplication({
    required this.id,
    required this.userId,
    required this.name,
    required this.artistName,
    required this.phone,
    required this.city,
    required this.plan,
    required this.status,
    this.orderId,
    required this.amount,
    required this.createdAt,
    this.paidAt,
  });

  factory CastingApplication.fromJson(Map<String, dynamic> json) {
    return CastingApplication(
      id: json['id'] as int,
      userId: json['user_id'] as int? ?? 0,
      name: json['name'] as String? ?? '',
      artistName: json['artist_name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      city: json['city'] as String? ?? '',
      plan: json['plan'] as String? ?? 'base',
      status: json['status'] as String? ?? 'paid',
      orderId: json['order_id'] as String?,
      amount: json['amount'] as int? ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      paidAt: json['paid_at'] != null ? DateTime.parse(json['paid_at'] as String) : null,
    );
  }

  String get planLabel => switch (plan) {
    'base' => 'BASE',
    'pro' => 'PRO',
    'vip' => 'VIP',
    _ => plan.toUpperCase(),
  };

  String get statusLabel => switch (status) {
    'paid' => 'Оплачено',
    'approved' => 'Одобрен',
    'rejected' => 'Отклонён',
    'invited' => 'Приглашён',
    _ => status,
  };

  String get amountFormatted {
    final rub = amount ~/ 100;
    return '$rub ₽';
  }
}

class CastingSlots {
  final int total;
  final int remaining;
  final int taken;

  const CastingSlots({required this.total, required this.remaining, required this.taken});

  factory CastingSlots.fromJson(Map<String, dynamic> json) {
    return CastingSlots(
      total: json['total'] as int? ?? 50,
      remaining: json['remaining'] as int? ?? 50,
      taken: json['taken'] as int? ?? 0,
    );
  }
}

class CastingStats {
  final int total;
  final int paidCount;
  final int approvedCount;
  final int rejectedCount;
  final int invitedCount;
  final int totalRevenue;

  const CastingStats({
    required this.total,
    required this.paidCount,
    required this.approvedCount,
    required this.rejectedCount,
    required this.invitedCount,
    required this.totalRevenue,
  });

  factory CastingStats.fromJson(Map<String, dynamic> json) {
    return CastingStats(
      total: json['total'] as int? ?? 0,
      paidCount: json['paid_count'] as int? ?? 0,
      approvedCount: json['approved_count'] as int? ?? 0,
      rejectedCount: json['rejected_count'] as int? ?? 0,
      invitedCount: json['invited_count'] as int? ?? 0,
      totalRevenue: json['total_revenue'] as int? ?? 0,
    );
  }

  String get revenueFormatted {
    final rub = totalRevenue ~/ 100;
    return '$rub ₽';
  }
}
