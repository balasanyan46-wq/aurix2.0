import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';

void main() {
  group('ProfileModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'user_id': 'u-1',
      'name': 'John Doe',
      'city': 'Moscow',
      'phone': '+79001234567',
      'gender': 'male',
      'bio': 'Artist bio',
      'avatar_url': 'https://example.com/avatar.jpg',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
      'email': 'john@example.com',
      'display_name': 'JohnD',
      'artist_name': 'DJ John',
      'role': 'admin',
      'account_status': 'active',
      'plan_id': 'empire',
      'billing_period': 'yearly',
      'subscription_status': 'active',
      'subscription_end': '2026-01-15T00:00:00.000',
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = ProfileModel.fromJson(fullJson);

        expect(model.userId, 'u-1');
        expect(model.name, 'John Doe');
        expect(model.city, 'Moscow');
        expect(model.phone, '+79001234567');
        expect(model.gender, 'male');
        expect(model.bio, 'Artist bio');
        expect(model.avatarUrl, 'https://example.com/avatar.jpg');
        expect(model.email, 'john@example.com');
        expect(model.displayName, 'JohnD');
        expect(model.artistName, 'DJ John');
        expect(model.role, 'admin');
        expect(model.accountStatus, 'active');
        expect(model.plan, 'empire');
        expect(model.planId, 'empire');
        expect(model.billingPeriod, 'yearly');
        expect(model.subscriptionStatus, 'active');
        expect(model.subscriptionEnd, DateTime(2026, 1, 15));
      });

      test('should use id fallback when user_id is absent', () {
        final json = <String, dynamic>{'id': 'u-2', 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String()};
        expect(ProfileModel.fromJson(json).userId, 'u-2');
      });

      test('should apply defaults for missing fields', () {
        final model = ProfileModel.fromJson({'user_id': 'u-3', 'created_at': now.toIso8601String(), 'updated_at': now.toIso8601String()});

        expect(model.email, '');
        expect(model.role, 'artist');
        expect(model.accountStatus, 'active');
        expect(model.plan, 'start');
        expect(model.billingPeriod, 'monthly');
        expect(model.subscriptionStatus, 'trial');
        expect(model.subscriptionEnd, isNull);
      });

      test('should migrate legacy plan slugs', () {
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'base'}).plan, 'start');
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'basic'}).plan, 'start');
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'BASE'}).plan, 'start');
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'pro'}).plan, 'breakthrough');
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'PRO'}).plan, 'breakthrough');
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'studio'}).plan, 'empire');
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'STUDIO'}).plan, 'empire');
      });

      test('should default unknown plan slugs to start', () {
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'unknown'}).plan, 'start');
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': null, 'plan': null}).plan, 'start');
      });

      test('should read plan from plan key when plan_id is absent', () {
        final json = <String, dynamic>{...fullJson, 'plan_id': null, 'plan': 'breakthrough'};
        expect(ProfileModel.fromJson(json).plan, 'breakthrough');
      });
    });

    group('toJson', () {
      test('should produce valid JSON roundtrip', () {
        final model = ProfileModel.fromJson(fullJson);
        final json = model.toJson();

        expect(json['user_id'], 'u-1');
        expect(json['id'], 'u-1');
        expect(json['email'], 'john@example.com');
        expect(json['role'], 'admin');
        expect(json['plan'], 'empire');
        expect(json['subscription_end'], isNotNull);
      });

      test('should output null subscription_end when not set', () {
        final model = ProfileModel.fromJson({
          'user_id': 'u-4',
          'created_at': now.toIso8601String(),
          'updated_at': now.toIso8601String(),
        });
        expect(model.toJson()['subscription_end'], isNull);
      });
    });

    group('computed properties', () {
      test('id returns userId', () {
        final model = ProfileModel.fromJson(fullJson);
        expect(model.id, model.userId);
      });

      test('hasStudioAccess for breakthrough and empire', () {
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'breakthrough'}).hasStudioAccess, true);
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'empire'}).hasStudioAccess, true);
        expect(ProfileModel.fromJson({...fullJson, 'plan_id': 'start'}).hasStudioAccess, false);
      });

      test('isAdmin', () {
        expect(ProfileModel.fromJson({...fullJson, 'role': 'admin'}).isAdmin, true);
        expect(ProfileModel.fromJson({...fullJson, 'role': 'artist'}).isAdmin, false);
      });

      test('isActive', () {
        expect(ProfileModel.fromJson({...fullJson, 'account_status': 'active'}).isActive, true);
        expect(ProfileModel.fromJson({...fullJson, 'account_status': 'suspended'}).isActive, false);
      });

      test('displayNameOrName fallback chain', () {
        expect(ProfileModel.fromJson(fullJson).displayNameOrName, 'John Doe');

        final noName = ProfileModel.fromJson({...fullJson, 'name': null});
        expect(noName.displayNameOrName, 'JohnD');

        final noDisplay = ProfileModel.fromJson({...fullJson, 'name': null, 'display_name': null});
        expect(noDisplay.displayNameOrName, 'DJ John');

        final emailOnly = ProfileModel.fromJson({...fullJson, 'name': null, 'display_name': null, 'artist_name': null});
        expect(emailOnly.displayNameOrName, 'john@example.com');
      });

      test('isYearly', () {
        expect(ProfileModel.fromJson({...fullJson, 'billing_period': 'yearly'}).isYearly, true);
        expect(ProfileModel.fromJson({...fullJson, 'billing_period': 'monthly'}).isYearly, false);
      });
    });

    group('copyWith', () {
      test('should override specified fields only', () {
        final original = ProfileModel.fromJson(fullJson);
        final copy = original.copyWith(name: 'Jane', plan: 'start');

        expect(copy.name, 'Jane');
        expect(copy.plan, 'start');
        expect(copy.userId, original.userId);
        expect(copy.email, original.email);
      });
    });
  });
}
