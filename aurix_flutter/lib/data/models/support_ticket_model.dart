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
      id: json['id'] as String,
      userId: json['user_id'] as String,
      subject: json['subject'] as String,
      message: json['message'] as String,
      status: json['status'] as String? ?? 'open',
      priority: json['priority'] as String? ?? 'medium',
      adminReply: json['admin_reply'] as String?,
      adminId: json['admin_id'] as String?,
      createdAt: json['created_at'] != null ? DateTime.parse(json['created_at'] as String) : now,
      updatedAt: json['updated_at'] != null ? DateTime.parse(json['updated_at'] as String) : now,
    );
  }
}
