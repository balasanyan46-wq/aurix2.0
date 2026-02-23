import 'package:aurix_flutter/data/supabase_client.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';

class SupportTicketRepository {
  Future<List<SupportTicketModel>> getAllTickets({String? statusFilter}) async {
    var query = supabase
        .from('support_tickets')
        .select()
        .order('created_at', ascending: false);

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = supabase
          .from('support_tickets')
          .select()
          .eq('status', statusFilter)
          .order('created_at', ascending: false);
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
        .order('created_at', ascending: false);
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
}
