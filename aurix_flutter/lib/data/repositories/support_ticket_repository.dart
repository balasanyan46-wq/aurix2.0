import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/support_message_model.dart';

class SupportTicketRepository {
  // ─── Tickets ───

  Future<List<SupportTicketModel>> getAllTickets({String? statusFilter}) async {
    var query = supabase
        .from('support_tickets')
        .select()
        .order('updated_at', ascending: false);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = supabase
          .from('support_tickets')
          .select()
          .eq('status', statusFilter)
          .order('updated_at', ascending: false);
    }

    final res = await query;
    return (res as List)
        .map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<List<SupportTicketModel>> getMyTickets(String userId) async {
    final res = await supabase
        .from('support_tickets')
        .select()
        .eq('user_id', userId)
        .order('updated_at', ascending: false);
    return (res as List)
        .map((e) => SupportTicketModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupportTicketModel> createTicket({
    required String userId,
    required String subject,
    required String message,
    String priority = 'medium',
  }) async {
    final res = await supabase.from('support_tickets').insert({
      'user_id': userId,
      'subject': subject,
      'message': message,
      'priority': priority,
    }).select().single();
    return SupportTicketModel.fromJson(res);
  }

  Future<void> replyToTicket({
    required String ticketId,
    required String adminId,
    required String reply,
    String status = 'resolved',
  }) async {
    await supabase.from('support_tickets').update({
      'admin_reply': reply,
      'admin_id': adminId,
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }

  Future<void> updateStatus(String ticketId, String status) async {
    await supabase.from('support_tickets').update({
      'status': status,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', ticketId);
  }

  // ─── Messages (chat) ───

  Future<List<SupportMessageModel>> getMessages(String ticketId) async {
    final res = await supabase
        .from('support_messages')
        .select()
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);
    return (res as List)
        .map((e) => SupportMessageModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<SupportMessageModel> sendMessage({
    required String ticketId,
    required String senderId,
    required String senderRole,
    required String body,
  }) async {
    final res = await supabase.from('support_messages').insert({
      'ticket_id': ticketId,
      'sender_id': senderId,
      'sender_role': senderRole,
      'body': body,
    }).select().single();

    // Bump ticket updated_at so it floats to top
    await supabase.from('support_tickets').update({
      'updated_at': DateTime.now().toIso8601String(),
      if (senderRole == 'user') 'status': 'open',
    }).eq('id', ticketId);

    return SupportMessageModel.fromJson(res);
  }
}
