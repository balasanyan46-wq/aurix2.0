import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

/// User's current credit balance.
final creditBalanceProvider = FutureProvider<int>((ref) async {
  try {
    final res = await ApiClient.get('/billing/balance');
    final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return data['balance'] as int? ?? 0;
  } catch (_) {
    return 0;
  }
});

/// User's transaction history.
final creditTransactionsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/billing/transactions', query: {'limit': '100'});
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return [];
  }
});

/// Credit costs (what each action costs).
final creditCostsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/billing/costs');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return [];
  }
});

/// Plan credit grants (how many credits each plan gives).
final planCreditsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) async {
  try {
    final res = await ApiClient.get('/billing/plans');
    return (res.data as List?)?.cast<Map<String, dynamic>>() ?? [];
  } catch (_) {
    return [];
  }
});
