class SupportTicketModel {
  final String id;
  final String userId;
  final String subject;
  final String message;
  final String status;
  final String priority;
  final String? adminReply;
  final String? adminId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SupportTicketModel({
    required this.id,
    required this.userId,
    required this.subject,
    required this.message,
    this.status = 'open',
    this.priority = 'medium',
    this.adminReply,
    this.adminId,
    required this.createdAt,
    required this.updatedAt,
  });

  bool get isOpen => status == 'open';
  bool get isResolved => status == 'resolved' || status == 'closed';

  String get statusLabel => switch (status) {
        'open' => 'Открыт',
        'in_progress' => 'В работе',
        'resolved' => 'Решён',
        'closed' => 'Закрыт',
        _ => status,
      };

  String get priorityLabel => switch (priority) {
        'low' => 'Низкий',
        'medium' => 'Средний',
        'high' => 'Высокий',
        _ => priority,
      };

  factory SupportTicketModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return SupportTicketModel(
      id: (json['id'])?.toString() ?? '',
      userId: json['user_id']?.toString() ?? '',
      subject: json['subject']?.toString() ?? '',
      message: json['message']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      priority: json['priority']?.toString() ?? 'medium',
      adminReply: json['admin_reply']?.toString(),
      adminId: json['admin_id']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']?.toString() ?? '') ?? now : now,
      updatedAt: json['updated_at'] != null ? DateTime.tryParse(json['updated_at']?.toString() ?? '') ?? now : now,
    );
  }
}
