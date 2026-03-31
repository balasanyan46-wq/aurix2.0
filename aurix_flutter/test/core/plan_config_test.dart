import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/core/plan_config.dart';
import 'package:aurix_flutter/core/enums.dart';

void main() {
  group('planHasStudioAccess', () {
    test('should return false for start plan', () {
      expect(planHasStudioAccess(SubscriptionPlan.start), isFalse);
    });

    test('should return true for breakthrough plan', () {
      expect(planHasStudioAccess(SubscriptionPlan.breakthrough), isTrue);
    });

    test('should return true for empire plan', () {
      expect(planHasStudioAccess(SubscriptionPlan.empire), isTrue);
    });
  });

  group('planStudioGenerationsLimit', () {
    test('should return 0 for start plan', () {
      expect(planStudioGenerationsLimit(SubscriptionPlan.start), 0);
    });

    test('should return 300 for breakthrough plan', () {
      expect(planStudioGenerationsLimit(SubscriptionPlan.breakthrough), 300);
    });

    test('should return 1500 for empire plan', () {
      expect(planStudioGenerationsLimit(SubscriptionPlan.empire), 1500);
    });
  });

  group('planConfigs', () {
    test('should have exactly 3 configs', () {
      expect(planConfigs.length, 3);
    });

    test('should cover all subscription plans', () {
      final plans = planConfigs.map((c) => c.plan).toSet();
      expect(plans, {SubscriptionPlan.start, SubscriptionPlan.breakthrough, SubscriptionPlan.empire});
    });

    test('should have consistent hasStudioAccess with helper function', () {
      for (final config in planConfigs) {
        expect(config.hasStudioAccess, planHasStudioAccess(config.plan));
      }
    });

    test('should have consistent studioGenerationsLimit with helper function', () {
      for (final config in planConfigs) {
        expect(config.studioGenerationsLimit, planStudioGenerationsLimit(config.plan));
      }
    });

    test('slug should match plan slug', () {
      for (final config in planConfigs) {
        expect(config.slug, config.plan.slug);
      }
    });
  });
}
