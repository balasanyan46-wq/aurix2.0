import 'package:flutter/foundation.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

class BillingService {
  /// Create checkout session via T-Bank.
  /// Returns payment URL to redirect the user.
  Future<({bool ok, String? url, String? error})> createCheckoutSession({
    required String plan,
    required String billingPeriod,
  }) async {
    try {
      final res = await ApiClient.post('/payments/create', data: {
        'plan': plan,
        'billingPeriod': billingPeriod,
      });

      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (body['success'] == true && body['data'] != null) {
        final data = Map<String, dynamic>.from(body['data'] as Map);
        return (ok: true, url: data['paymentUrl'] as String?, error: null);
      }
      return (ok: false, url: null, error: (body['error'] as String?) ?? '\u041e\u0448\u0438\u0431\u043a\u0430 (${res.statusCode})');
    } catch (e) {
      debugPrint('[BillingService] createCheckoutSession error: $e');
      return (ok: false, url: null, error: e.toString());
    }
  }

  /// Admin: assign plan directly.
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
      return (ok: false, error: (body['error'] as String?) ?? '\u041e\u0448\u0438\u0431\u043a\u0430 (${res.statusCode})');
    } catch (e) {
      debugPrint('[BillingService] adminAssignPlan error: $e');
      return (ok: false, error: e.toString());
    }
  }

  /// Get current subscription status.
  Future<Map<String, dynamic>?> getSubscription() async {
    try {
      final res = await ApiClient.get('/me/subscription');
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (body['success'] == true && body['data'] != null) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return null;
    } catch (e) {
      debugPrint('[BillingService] getSubscription error: $e');
      return null;
    }
  }

  /// Check payment status by orderId.
  /// Backend will auto-sync with T-Bank GetState if still pending.
  Future<Map<String, dynamic>?> checkPayment(String orderId) async {
    try {
      final res = await ApiClient.get('/payments/check?orderId=$orderId');
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (body['success'] == true && body['data'] != null) {
        return Map<String, dynamic>.from(body['data'] as Map);
      }
      return null;
    } catch (e) {
      debugPrint('[BillingService] checkPayment error: $e');
      return null;
    }
  }

  /// Get payment history.
  Future<List<Map<String, dynamic>>> getPaymentHistory() async {
    try {
      final res = await ApiClient.get('/payments/history');
      final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      if (body['success'] == true && body['data'] != null) {
        return (body['data'] as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
      return [];
    } catch (e) {
      debugPrint('[BillingService] getPaymentHistory error: $e');
      return [];
    }
  }
}
