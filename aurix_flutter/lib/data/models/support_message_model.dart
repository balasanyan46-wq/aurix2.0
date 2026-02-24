class SupportMessageModel {
  final String id;
  final String ticketId;
  final String senderId;
  final String senderRole;
  final String body;
  final DateTime createdAt;

  const SupportMessageModel({
    required this.id,
    required this.ticketId,
    required this.senderId,
    required this.senderRole,
    required this.body,
    required this.createdAt,
  });

  bool get isAdmin => senderRole == 'admin';
  bool get isUser => senderRole == 'user';

  factory SupportMessageModel.fromJson(Map<String, dynamic> json) {
    return SupportMessageModel(
      id: json['id'] as String,
      ticketId: json['ticket_id'] as String,
      senderId: json['sender_id'] as String,
      senderRole: json['sender_role'] as String? ?? 'user',
      body: json['body'] as String,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }
}
