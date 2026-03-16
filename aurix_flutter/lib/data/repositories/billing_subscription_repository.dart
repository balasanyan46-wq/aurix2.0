import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/models/billing_subscription_model.dart';

class BillingSubscriptionRepository {
  /// Fetches all profiles and maps them to BillingSubscriptionModel.
  /// The backend has no separate billing_subscriptions table —
  /// subscription data lives on profiles.
  Future<List<BillingSubscriptionModel>> getAll() async {
    final res = await ApiClient.get('/profiles');
    final body = res.data;
    final List<dynamic> list;
    if (body is Map<String, dynamic> && body['profiles'] is List) {
      list = body['profiles'] as List;
    } else if (body is List) {
      list = body;
    } else {
      return [];
    }
    return list
        .cast<Map<String, dynamic>>()
        .map(_profileToBilling)
        .toList();
  }

  /// Activate (or create) a subscription for a user.
  Future<void> activate({
    required String userId,
    required String planId,
    int extendDays = 30,
  }) async {
    final end = DateTime.now().add(Duration(days: extendDays));
    await _updateSubscription(
      userId: userId,
      planId: planId,
      status: 'active',
      end: end,
    );
  }

  /// Extend an existing subscription.
  Future<void> extend({
    required BillingSubscriptionModel current,
    int extendDays = 30,
  }) async {
    final newEnd = current.currentPeriodEnd.isAfter(DateTime.now())
        ? current.currentPeriodEnd.add(Duration(days: extendDays))
        : DateTime.now().add(Duration(days: extendDays));
    final status = current.status == 'expired' ? 'active' : current.status;
    await _updateSubscription(
      userId: current.userId,
      planId: current.planId,
      status: status,
      end: newEnd,
    );
  }

  /// Cancel a subscription.
  Future<void> cancel({
    required BillingSubscriptionModel current,
    bool atPeriodEnd = true,
  }) async {
    final end = atPeriodEnd ? current.currentPeriodEnd : DateTime.now();
    final status = atPeriodEnd ? current.status : 'canceled';
    await _updateSubscription(
      userId: current.userId,
      planId: current.planId,
      status: status,
      end: end,
    );
  }

  /// Change plan for a subscription.
  Future<void> changePlan({
    required BillingSubscriptionModel current,
    required String newPlanId,
  }) async {
    await _updateSubscription(
      userId: current.userId,
      planId: newPlanId,
      status: current.status,
      end: current.currentPeriodEnd,
    );
  }

  /// Single write path — calls the backend endpoint that actually exists.
  Future<void> _updateSubscription({
    required String userId,
    required String planId,
    required String status,
    required DateTime end,
  }) async {
    await ApiClient.put('/profiles/$userId/subscription', data: {
      'plan_id': planId,
      'subscription_status': status,
      'subscription_end': end.toIso8601String(),
    });
  }

  /// Map a profile JSON row to BillingSubscriptionModel.
  BillingSubscriptionModel _profileToBilling(Map<String, dynamic> json) {
    DateTime parseDate(String key) {
      final raw = json[key]?.toString();
      final dt = raw == null ? null : DateTime.tryParse(raw);
      return dt ?? DateTime.now();
    }

    return BillingSubscriptionModel(
      id: (json['id'] ?? json['user_id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      planId: (json['plan_id'] ?? json['plan'] ?? 'start').toString(),
      status: (json['subscription_status'] ?? 'trial').toString(),
      currentPeriodStart: parseDate('created_at'),
      currentPeriodEnd: json['subscription_end'] != null
          ? parseDate('subscription_end')
          : DateTime.now().add(const Duration(days: 30)),
      cancelAtPeriodEnd: false,
      createdAt: parseDate('created_at'),
      updatedAt: parseDate('updated_at'),
    );
  }
}
