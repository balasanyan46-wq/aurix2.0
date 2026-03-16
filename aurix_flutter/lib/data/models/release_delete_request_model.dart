class ReleaseDeleteRequestModel {
  final String id;
  final String releaseId;
  final String requesterId;
  final String status;
  final String? reason;
  final String? adminComment;
  final String? processedBy;
  final DateTime createdAt;
  final DateTime? processedAt;

  const ReleaseDeleteRequestModel({
    required this.id,
    required this.releaseId,
    required this.requesterId,
    required this.status,
    this.reason,
    this.adminComment,
    this.processedBy,
    required this.createdAt,
    this.processedAt,
  });

  bool get isPending => status == 'pending';

  String get statusLabel => switch (status) {
        'pending' => 'Ожидает',
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        'cancelled' => 'Отменён',
        _ => status,
      };

  factory ReleaseDeleteRequestModel.fromJson(Map<String, dynamic> json) {
    final now = DateTime.now();
    return ReleaseDeleteRequestModel(
      id: (json['id'])?.toString() ?? '',
      releaseId: json['release_id']?.toString() ?? '',
      requesterId: json['requester_id']?.toString() ?? '',
      status: json['status']?.toString() ?? 'pending',
      reason: json['reason']?.toString(),
      adminComment: json['admin_comment']?.toString(),
      processedBy: json['processed_by']?.toString(),
      createdAt: json['created_at'] != null ? DateTime.tryParse(json['created_at']?.toString() ?? '') ?? now : now,
      processedAt: json['processed_at'] != null ? DateTime.tryParse(json['processed_at']?.toString() ?? '') : null,
    );
  }
}

