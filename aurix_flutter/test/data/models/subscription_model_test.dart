import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/subscription_model.dart';

void main() {
  group('SubscriptionModel', () {
    final fullJson = <String, dynamic>{
      'user_id': 'u-1',
      'plan_id': 'breakthrough',
      'status': 'active',
      'billing_period': 'yearly',
      'current_period_start': '2025-01-01T00:00:00.000',
      'current_period_end': '2026-01-01T00:00:00.000',
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = SubscriptionModel.fromJson(fullJson);

        expect(model.userId, 'u-1');
        expect(model.plan, 'breakthrough');
        expect(model.status, 'active');
        expect(model.billingPeriod, 'yearly');
        expect(model.currentPeriodStart, DateTime(2025, 1, 1));
        expect(model.currentPeriodEnd, DateTime(2026, 1, 1));
      });

      test('should use userId fallback key', () {
        final json = <String, dynamic>{'userId': 'u-2', 'plan': 'start', 'status': 'trial', 'billingPeriod': 'monthly'};
        expect(SubscriptionModel.fromJson(json).userId, 'u-2');
        expect(SubscriptionModel.fromJson(json).plan, 'start');
        expect(SubscriptionModel.fromJson(json).billingPeriod, 'monthly');
      });

      test('should apply defaults for missing fields', () {
        final model = SubscriptionModel.fromJson({});

        expect(model.userId, '');
        expect(model.plan, 'start');
        expect(model.status, 'trial');
        expect(model.billingPeriod, 'monthly');
        expect(model.currentPeriodStart, isNull);
        expect(model.currentPeriodEnd, isNull);
      });

      test('should handle empty string dates gracefully', () {
        final json = <String, dynamic>{
          ...fullJson,
          'current_period_start': '',
          'current_period_end': '',
        };
        final model = SubscriptionModel.fromJson(json);
        expect(model.currentPeriodStart, isNull);
        expect(model.currentPeriodEnd, isNull);
      });
    });

    group('isActiveNow', () {
      test('should return true for active status with future end date', () {
        final model = SubscriptionModel(
          userId: 'u-1',
          plan: 'empire',
          status: 'active',
          billingPeriod: 'monthly',
          currentPeriodEnd: DateTime.now().add(const Duration(days: 30)),
        );
        expect(model.isActiveNow, true);
      });

      test('should return true for trial status with no end date', () {
        const model = SubscriptionModel(
          userId: 'u-1',
          plan: 'start',
          status: 'trial',
          billingPeriod: 'monthly',
        );
        expect(model.isActiveNow, true);
      });

      test('should return false for expired status', () {
        const model = SubscriptionModel(
          userId: 'u-1',
          plan: 'start',
          status: 'expired',
          billingPeriod: 'monthly',
        );
        expect(model.isActiveNow, false);
      });

      test('should return false for active status with past end date', () {
        final model = SubscriptionModel(
          userId: 'u-1',
          plan: 'start',
          status: 'active',
          billingPeriod: 'monthly',
          currentPeriodEnd: DateTime.now().subtract(const Duration(days: 1)),
        );
        expect(model.isActiveNow, false);
      });

      test('should return false for canceled status', () {
        const model = SubscriptionModel(
          userId: 'u-1',
          plan: 'start',
          status: 'canceled',
          billingPeriod: 'monthly',
        );
        expect(model.isActiveNow, false);
      });
    });
  });
}
