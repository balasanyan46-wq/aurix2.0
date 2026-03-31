import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/team_member_model.dart';

void main() {
  group('TeamMemberModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 'tm-1',
      'owner_id': 'u-1',
      'member_name': 'Jane Doe',
      'member_email': 'jane@example.com',
      'role': 'manager',
      'split_percent': 25.5,
      'status': 'active',
      'created_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = TeamMemberModel.fromJson(fullJson);

        expect(model.id, 'tm-1');
        expect(model.ownerId, 'u-1');
        expect(model.memberName, 'Jane Doe');
        expect(model.memberEmail, 'jane@example.com');
        expect(model.role, 'manager');
        expect(model.splitPercent, 25.5);
        expect(model.status, 'active');
        expect(model.createdAt, now);
      });

      test('should apply defaults for missing fields', () {
        final model = TeamMemberModel.fromJson({'id': 'tm-2'});

        expect(model.ownerId, '');
        expect(model.memberName, '');
        expect(model.memberEmail, isNull);
        expect(model.role, 'producer');
        expect(model.splitPercent, 0);
        expect(model.status, 'active');
      });

      test('should handle int split_percent as double', () {
        final json = <String, dynamic>{...fullJson, 'split_percent': 50};
        expect(TeamMemberModel.fromJson(json).splitPercent, 50.0);
      });
    });

    group('roleLabel', () {
      test('should return correct Russian labels for known roles', () {
        expect(TeamMemberModel.fromJson({...fullJson, 'role': 'producer'}).roleLabel, 'Продюсер');
        expect(TeamMemberModel.fromJson({...fullJson, 'role': 'manager'}).roleLabel, 'Менеджер');
        expect(TeamMemberModel.fromJson({...fullJson, 'role': 'engineer'}).roleLabel, 'Звукорежиссёр');
        expect(TeamMemberModel.fromJson({...fullJson, 'role': 'songwriter'}).roleLabel, 'Автор');
        expect(TeamMemberModel.fromJson({...fullJson, 'role': 'designer'}).roleLabel, 'Дизайнер');
      });

      test('should return default for unknown role', () {
        expect(TeamMemberModel.fromJson({...fullJson, 'role': 'intern'}).roleLabel, 'Другое');
      });
    });

    group('toInsertJson', () {
      test('should produce correct insert JSON without id or created_at', () {
        final model = TeamMemberModel.fromJson(fullJson);
        final json = model.toInsertJson();

        expect(json.containsKey('id'), false);
        expect(json.containsKey('created_at'), false);
        expect(json['owner_id'], 'u-1');
        expect(json['member_name'], 'Jane Doe');
        expect(json['member_email'], 'jane@example.com');
        expect(json['role'], 'manager');
        expect(json['split_percent'], 25.5);
        expect(json['status'], 'active');
      });
    });
  });
}
