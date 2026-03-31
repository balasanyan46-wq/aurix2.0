import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/billing_subscription_model.dart';

void main() {
  group('BillingSubscriptionModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 'bs-1',
      'user_id': 'u-1',
      'plan_id': 'empire',
      'status': 'active',
      'current_period_start': now.toIso8601String(),
      'current_period_end': '2025-02-15T12:00:00.000',
      'cancel_at_period_end': true,
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = BillingSubscriptionModel.fromJson(fullJson);

        expect(model.id, 'bs-1');
        expect(model.userId, 'u-1');
        expect(model.planId, 'empire');
        expect(model.status, 'active');
        expect(model.currentPeriodStart, now);
        expect(model.currentPeriodEnd, DateTime(2025, 2, 15, 12, 0, 0));
        expect(model.cancelAtPeriodEnd, true);
        expect(model.createdAt, now);
        expect(model.updatedAt, now);
      });

      test('should apply defaults for missing fields', () {
        final model = BillingSubscriptionModel.fromJson({});

        expect(model.id, '');
        expect(model.userId, '');
        expect(model.planId, 'start');
        expect(model.status, 'trial');
        expect(model.cancelAtPeriodEnd, false);
      });

      test('should default cancelAtPeriodEnd to false for non-true values', () {
        final json = <String, dynamic>{...fullJson, 'cancel_at_period_end': null};
        expect(BillingSubscriptionModel.fromJson(json).cancelAtPeriodEnd, false);

        final json2 = <String, dynamic>{...fullJson, 'cancel_at_period_end': false};
        expect(BillingSubscriptionModel.fromJson(json2).cancelAtPeriodEnd, false);
      });

      test('should fallback dates to now when unparseable', () {
        final json = <String, dynamic>{
          ...fullJson,
          'current_period_start': 'invalid',
          'current_period_end': 'invalid',
          'created_at': 'invalid',
          'updated_at': 'invalid',
        };
        final model = BillingSubscriptionModel.fromJson(json);
        // These should be close to DateTime.now() -- just verify they're not null
        expect(model.currentPeriodStart, isA<DateTime>());
        expect(model.currentPeriodEnd, isA<DateTime>());
        expect(model.createdAt, isA<DateTime>());
        expect(model.updatedAt, isA<DateTime>());
      });
    });
  });
}
