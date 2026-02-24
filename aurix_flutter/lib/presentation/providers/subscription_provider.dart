import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/supabase_client.dart';
import 'package:aurix_flutter/data/models/subscription_model.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final currentSubscriptionProvider = StreamProvider<SubscriptionModel?>((ref) {
  final user = ref.watch(currentUserProvider);
  if (user == null) return Stream.value(null);

  return supabase
      .from('subscriptions')
      .stream(primaryKey: const ['user_id'])
      .eq('user_id', user.id)
      .map((rows) {
        if (rows.isEmpty) return null;
        return SubscriptionModel.fromJson(rows.first);
      });
});

/// Effective plan slug used across the app.
/// Falls back to profiles.plan if subscriptions row is missing.
final effectivePlanProvider = Provider<String>((ref) {
  final sub = ref.watch(currentSubscriptionProvider).valueOrNull;
  if (sub != null && sub.plan.isNotEmpty) return sub.plan;
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.plan ?? 'start';
});

final effectiveBillingPeriodProvider = Provider<String>((ref) {
  final sub = ref.watch(currentSubscriptionProvider).valueOrNull;
  if (sub != null && sub.billingPeriod.isNotEmpty) return sub.billingPeriod;
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.billingPeriod ?? 'monthly';
});

