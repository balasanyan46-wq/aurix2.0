import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

class BillingService {
  Future<({bool ok, String? url, String? error})> createCheckoutSession({
    required String plan,
    required String billingPeriod,
  }) async {
    try {
      final res = await ApiClient.post('/tools/billing-create-checkout-session', data: {
        'plan': plan,
        'billingPeriod': billingPeriod,
      });

      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (res.statusCode == 200 && body['ok'] == true) {
        return (ok: true, url: body['url'] as String?, error: null);
      }
      return (ok: false, url: null, error: (body['error'] as String?) ?? 'Ошибка (${res.statusCode})');
    } catch (e) {
      debugPrint('[BillingService] createCheckoutSession error: $e');
      return (ok: false, url: null, error: e.toString());
    }
  }

  Future<({bool ok, String? error})> adminAssignPlan({
    required String userId,
    required String plan,
    String billingPeriod = 'monthly',
  }) async {
    try {
      final res = await ApiClient.post('/tools/admin-subscriptions-assign', data: {
        'userId': userId,
        'plan': plan,
        'billingPeriod': billingPeriod,
      });

      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (res.statusCode == 200 && body['ok'] == true) {
        return (ok: true, error: null);
      }
      return (ok: false, error: (body['error'] as String?) ?? 'Ошибка (${res.statusCode})');
    } catch (e) {
      debugPrint('[BillingService] adminAssignPlan error: $e');
      return (ok: false, error: e.toString());
    }
  }
}
