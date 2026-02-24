import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/config/app_config.dart';

class BillingService {
  Future<({bool ok, String? url, String? error})> createCheckoutSession({
    required String plan,
    required String billingPeriod,
  }) async {
    try {
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) return (ok: false, url: null, error: 'Not authenticated');

      final url = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/billing-create-checkout-session');
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'plan': plan, 'billingPeriod': billingPeriod}),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
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
      final token = supabase.auth.currentSession?.accessToken;
      if (token == null) return (ok: false, error: 'Not authenticated');

      final url = Uri.parse('${AppConfig.supabaseUrl}/functions/v1/admin-subscriptions-assign');
      final res = await http.post(
        url,
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'userId': userId, 'plan': plan, 'billingPeriod': billingPeriod}),
      );

      final body = jsonDecode(res.body) as Map<String, dynamic>? ?? {};
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

