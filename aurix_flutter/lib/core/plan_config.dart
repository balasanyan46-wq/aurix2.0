import 'package:aurix_flutter/core/enums.dart';

/// Feature item for a plan — l10n key.
typedef PlanFeatureKey = String;

/// Plan configuration — single source of truth for subscription plans.
class PlanConfig {
  final SubscriptionPlan plan;
  final String priceKey;
  final List<PlanFeatureKey> featureKeys;
  final String? badgeKey; // 'recommended' | null
  final bool hasStudioAccess;
  final int studioGenerationsLimit;
  final String? studioAiNoteKey; // l10n key for limit text, e.g. 'planProStudioLimit'

  const PlanConfig({
    required this.plan,
    required this.priceKey,
    required this.featureKeys,
    this.badgeKey,
    required this.hasStudioAccess,
    required this.studioGenerationsLimit,
    this.studioAiNoteKey,
  });
}

/// Access helpers for Aurix Studio AI.
bool hasStudioAccess(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.pro:
    case SubscriptionPlan.studio:
      return true;
    case SubscriptionPlan.basic:
      return false;
  }
}

int studioGenerationsLimit(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.pro:
      return 300;
    case SubscriptionPlan.studio:
      return 1500;
    case SubscriptionPlan.basic:
      return 0;
  }
}

/// All plan configs — use with L10n.t(context, key) for display.
const List<PlanConfig> planConfigs = [
  PlanConfig(
    plan: SubscriptionPlan.basic,
    priceKey: 'planBasicPrice',
    featureKeys: [
      'planBasicF1',
      'planBasicF2',
      'planBasicF3',
      'planBasicF4',
      'planBasicStudioNo',
    ],
    badgeKey: null,
    hasStudioAccess: false,
    studioGenerationsLimit: 0,
    studioAiNoteKey: null,
  ),
  PlanConfig(
    plan: SubscriptionPlan.pro,
    priceKey: 'planProPrice',
    featureKeys: [
      'planProF1',
      'planProF2',
      'planProF3',
      'planProF4',
      'planProF5',
      'planProF6',
      'planProStudioYes',
      'planProStudioLimit',
    ],
    badgeKey: 'planBadgeRecommended',
    hasStudioAccess: true,
    studioGenerationsLimit: 300,
    studioAiNoteKey: 'planProStudioLimit',
  ),
  PlanConfig(
    plan: SubscriptionPlan.studio,
    priceKey: 'planStudioPrice',
    featureKeys: [
      'planStudioF1',
      'planStudioF2',
      'planStudioF3',
      'planStudioF4',
      'planStudioF5',
      'planStudioF6',
      'planStudioStudioYes',
      'planStudioStudioLimit',
      'planStudioStudioContentKit',
    ],
    badgeKey: null,
    hasStudioAccess: true,
    studioGenerationsLimit: 1500,
    studioAiNoteKey: 'planStudioStudioLimit',
  ),
];
