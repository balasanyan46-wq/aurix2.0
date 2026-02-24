import 'package:aurix_flutter/core/enums.dart';

typedef PlanFeatureKey = String;

class PlanConfig {
  final SubscriptionPlan plan;
  final String priceKey;
  final List<PlanFeatureKey> featureKeys;
  final String? badgeKey;
  final bool hasStudioAccess;
  final int studioGenerationsLimit;
  final String? studioAiNoteKey;

  const PlanConfig({
    required this.plan,
    required this.priceKey,
    required this.featureKeys,
    this.badgeKey,
    required this.hasStudioAccess,
    required this.studioGenerationsLimit,
    this.studioAiNoteKey,
  });

  /// DB slug for this plan
  String get slug => plan.slug;
}

bool planHasStudioAccess(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.breakthrough:
    case SubscriptionPlan.empire:
      return true;
    case SubscriptionPlan.start:
      return false;
  }
}

int planStudioGenerationsLimit(SubscriptionPlan plan) {
  switch (plan) {
    case SubscriptionPlan.breakthrough:
      return 300;
    case SubscriptionPlan.empire:
      return 1500;
    case SubscriptionPlan.start:
      return 0;
  }
}

const List<PlanConfig> planConfigs = [
  PlanConfig(
    plan: SubscriptionPlan.start,
    priceKey: 'planStartPrice',
    featureKeys: [
      'planStartF1',
      'planStartF2',
      'planStartF3',
      'planStartF4',
      'planStartStudioNo',
    ],
    badgeKey: null,
    hasStudioAccess: false,
    studioGenerationsLimit: 0,
    studioAiNoteKey: null,
  ),
  PlanConfig(
    plan: SubscriptionPlan.breakthrough,
    priceKey: 'planBreakthroughPrice',
    featureKeys: [
      'planBreakthroughF1',
      'planBreakthroughF2',
      'planBreakthroughF3',
      'planBreakthroughF4',
      'planBreakthroughF5',
      'planBreakthroughF6',
      'planBreakthroughStudioYes',
      'planBreakthroughStudioLimit',
    ],
    badgeKey: 'planBadgeRecommended',
    hasStudioAccess: true,
    studioGenerationsLimit: 300,
    studioAiNoteKey: 'planBreakthroughStudioLimit',
  ),
  PlanConfig(
    plan: SubscriptionPlan.empire,
    priceKey: 'planEmpirePrice',
    featureKeys: [
      'planEmpireF1',
      'planEmpireF2',
      'planEmpireF3',
      'planEmpireF4',
      'planEmpireF5',
      'planEmpireF6',
      'planEmpireStudioYes',
      'planEmpireStudioLimit',
      'planEmpireContentKit',
    ],
    badgeKey: null,
    hasStudioAccess: true,
    studioGenerationsLimit: 1500,
    studioAiNoteKey: 'planEmpireStudioLimit',
  ),
];
