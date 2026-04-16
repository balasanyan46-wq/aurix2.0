import 'package:aurix_flutter/core/api/api_client.dart' show ApiClient, asList;
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/support_message_model.dart';

class SupportTicketRepository {
  // ─── Tickets ───

  Future<List<SupportTicketModel>> getAllTickets({String? statusFilter}) async {
    final query = <String, dynamic>{
      'order': 'updated_at.desc',
    };
    if (statusFilter != null && statusFilter.isNotEmpty) {
      query['status'] = statusFilter;
    }

    final res = await ApiClient.get('/support-tickets', query: query);
    final list = asList(res.data);
    return list
        .map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SupportTicketModel>> getMyTickets(String userId) async {
    // Backend gets user_id from JWT, order is hardcoded DESC
    final res = await ApiClient.get('/support-tickets');
    final list = asList(res.data);
    return list
        .map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupportTicketModel> createTicket({
    required String userId,
    required String subject,
    required String message,
    String priority = 'medium',
  }) async {
    final res = await ApiClient.post('/support-tickets', data: {
      'user_id': userId,
      'subject': subject,
      'message': message,
      'priority': priority,
    });
    final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
    return SupportTicketModel.fromJson(body);
  }

  Future<void> replyToTicket({
    required String ticketId,
    required String adminId,
    required String reply,
    String status = 'resolved',
  }) async {
    await ApiClient.put('/support-tickets/$ticketId', data: {
      'admin_reply': reply,
      'admin_id': adminId,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> updateStatus(String ticketId, String status) async {
    final now = DateTime.now().toIso8601String();
    final payload = <String, dynamic>{
      'status': status,
      'updated_at': now,
    };
    if (status == 'in_progress') {
      payload['first_response_at'] = now;
    } else if (status == 'resolved') {
      payload['resolved_at'] = now;
    } else if (status == 'open') {
      payload['resolved_at'] = null;
    }
    await ApiClient.put('/support-tickets/$ticketId', data: payload);
  }

  // ─── Messages (chat) ───

  Future<List<SupportMessageModel>> getMessages(String ticketId) async {
    final res = await ApiClient.get('/support-messages', query: {
      'ticket_id': ticketId,
      'order': 'created_at.asc',
    });
    final list = asList(res.data);
    return list
        .map((e) => SupportMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupportMessageModel> sendMessage({
    required String ticketId,
    required String senderId,
    required String senderRole,
    required String body,
  }) async {
    final res = await ApiClient.post('/support-messages', data: {
      'ticket_id': ticketId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'body': body,
    });
    final msgBody = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};

    // Bump ticket updated_at so it floats to top (non-critical)
    try {
      await ApiClient.put('/support-tickets/$ticketId', data: {
        'updated_at': DateTime.now().toIso8601String(),
        if (senderRole == 'user') 'status': 'open',
      });
    } catch (_) {
      // Not critical — message was already sent
    }

    return SupportMessageModel.fromJson(msgBody);
  }
}
