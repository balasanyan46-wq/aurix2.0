import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/subscription_model.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Billing subscription derived from the user's profile.
/// No separate billing API exists — subscription data lives on the profile.
final currentBillingSubscriptionProvider = FutureProvider<SubscriptionModel?>((ref) async {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile == null) return null;
  return SubscriptionModel(
    userId: profile.userId,
    plan: profile.planId,
    status: profile.subscriptionStatus,
    billingPeriod: profile.billingPeriod,
    currentPeriodEnd: profile.subscriptionEnd,
  );
});

final currentSubscriptionProvider = Provider<SubscriptionModel?>((ref) {
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  if (profile != null) {
    return SubscriptionModel(
      userId: profile.userId,
      plan: profile.planId,
      status: profile.subscriptionStatus,
      billingPeriod: profile.billingPeriod,
      currentPeriodEnd: profile.subscriptionEnd,
    );
  }
  return ref.watch(currentBillingSubscriptionProvider).valueOrNull;
});

/// Effective plan slug used across the app.
final effectivePlanProvider = Provider<String>((ref) {
  final sub = ref.watch(currentSubscriptionProvider);
  if (sub != null && sub.plan.isNotEmpty) return sub.plan;
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.planId ?? profile?.plan ?? 'start';
});

final effectiveBillingPeriodProvider = Provider<String>((ref) {
  final sub = ref.watch(currentSubscriptionProvider);
  if (sub != null && sub.billingPeriod.isNotEmpty) return sub.billingPeriod;
  final profile = ref.watch(currentProfileProvider).valueOrNull;
  return profile?.billingPeriod ?? 'monthly';
});

int _planRank(String raw) {
  switch (raw) {
    case 'empire':
      return 3;
    case 'breakthrough':
      return 2;
    case 'start':
    default:
      return 1;
  }
}

final hasActiveSubscriptionProvider = Provider<bool>((ref) {
  final sub = ref.watch(currentSubscriptionProvider);
  if (sub == null) return false;
  return sub.isActiveNow;
});

final subscriptionDaysLeftProvider = Provider<int?>((ref) {
  final sub = ref.watch(currentSubscriptionProvider);
  final end = sub?.currentPeriodEnd;
  if (end == null) return null;
  return end.difference(DateTime.now()).inDays;
});

final hasPlanAccessProvider = Provider.family<bool, String>((ref, requiredPlan) {
  final sub = ref.watch(currentSubscriptionProvider);
  if (sub == null || !sub.isActiveNow) return false;
  return _planRank(sub.plan) >= _planRank(requiredPlan);
});
