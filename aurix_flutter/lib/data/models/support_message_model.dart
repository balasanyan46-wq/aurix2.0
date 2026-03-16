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
      id: (json['id'])?.toString() ?? '',
      ticketId: json['ticket_id']?.toString() ?? '',
      senderId: json['sender_id']?.toString() ?? '',
      senderRole: json['sender_role']?.toString() ?? 'user',
      body: json['body']?.toString() ?? '',
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
