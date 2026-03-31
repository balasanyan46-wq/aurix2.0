import 'package:flutter_test/flutter_test.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/support_message_model.dart';

void main() {
  group('SupportTicketModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 'st-1',
      'user_id': 'u-1',
      'subject': 'Issue with release',
      'message': 'My release is stuck',
      'status': 'in_progress',
      'priority': 'high',
      'admin_reply': 'Looking into it',
      'admin_id': 'admin-1',
      'created_at': now.toIso8601String(),
      'updated_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields from complete JSON', () {
        final model = SupportTicketModel.fromJson(fullJson);

        expect(model.id, 'st-1');
        expect(model.userId, 'u-1');
        expect(model.subject, 'Issue with release');
        expect(model.message, 'My release is stuck');
        expect(model.status, 'in_progress');
        expect(model.priority, 'high');
        expect(model.adminReply, 'Looking into it');
        expect(model.adminId, 'admin-1');
        expect(model.createdAt, now);
        expect(model.updatedAt, now);
      });

      test('should apply defaults for missing fields', () {
        final model = SupportTicketModel.fromJson({'id': 'st-2'});

        expect(model.userId, '');
        expect(model.subject, '');
        expect(model.message, '');
        expect(model.status, 'open');
        expect(model.priority, 'medium');
        expect(model.adminReply, isNull);
        expect(model.adminId, isNull);
      });
    });

    group('computed properties', () {
      test('isOpen', () {
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'open'}).isOpen, true);
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'in_progress'}).isOpen, false);
      });

      test('isResolved for resolved and closed', () {
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'resolved'}).isResolved, true);
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'closed'}).isResolved, true);
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'open'}).isResolved, false);
      });

      test('statusLabel returns correct Russian labels', () {
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'open'}).statusLabel, 'Открыт');
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'in_progress'}).statusLabel, 'В работе');
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'resolved'}).statusLabel, 'Решён');
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'closed'}).statusLabel, 'Закрыт');
        expect(SupportTicketModel.fromJson({...fullJson, 'status': 'custom'}).statusLabel, 'custom');
      });

      test('priorityLabel returns correct Russian labels', () {
        expect(SupportTicketModel.fromJson({...fullJson, 'priority': 'low'}).priorityLabel, 'Низкий');
        expect(SupportTicketModel.fromJson({...fullJson, 'priority': 'medium'}).priorityLabel, 'Средний');
        expect(SupportTicketModel.fromJson({...fullJson, 'priority': 'high'}).priorityLabel, 'Высокий');
        expect(SupportTicketModel.fromJson({...fullJson, 'priority': 'custom'}).priorityLabel, 'custom');
      });
    });
  });

  group('SupportMessageModel', () {
    final now = DateTime(2025, 1, 15, 12, 0, 0);
    final fullJson = <String, dynamic>{
      'id': 'sm-1',
      'ticket_id': 'st-1',
      'sender_id': 'u-1',
      'sender_role': 'admin',
      'body': 'Hello, how can I help?',
      'created_at': now.toIso8601String(),
    };

    group('fromJson', () {
      test('should parse all fields', () {
        final model = SupportMessageModel.fromJson(fullJson);

        expect(model.id, 'sm-1');
        expect(model.ticketId, 'st-1');
        expect(model.senderId, 'u-1');
        expect(model.senderRole, 'admin');
        expect(model.body, 'Hello, how can I help?');
        expect(model.createdAt, now);
      });

      test('should apply defaults for missing fields', () {
        final model = SupportMessageModel.fromJson({});

        expect(model.id, '');
        expect(model.ticketId, '');
        expect(model.senderId, '');
        expect(model.senderRole, 'user');
        expect(model.body, '');
      });
    });

    group('computed properties', () {
      test('isAdmin / isUser', () {
        final admin = SupportMessageModel.fromJson(fullJson);
        expect(admin.isAdmin, true);
        expect(admin.isUser, false);

        final user = SupportMessageModel.fromJson({...fullJson, 'sender_role': 'user'});
        expect(user.isAdmin, false);
        expect(user.isUser, true);
      });
    });
  });
}
