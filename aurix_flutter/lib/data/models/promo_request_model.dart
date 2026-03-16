class PromoRequestModel {
  const PromoRequestModel({
    required this.id,
    required this.userId,
    required this.releaseId,
    required this.type,
    required this.status,
    required this.formData,
    required this.createdAt,
    required this.updatedAt,
    this.adminNotes,
    this.assignedManager,
  });

  final String id;
  final String userId;
  final String releaseId;
  final String type;
  final String status;
  final Map<String, dynamic> formData;
  final String? adminNotes;
  final String? assignedManager;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory PromoRequestModel.fromJson(Map<String, dynamic> json) {
    return PromoRequestModel(
      id: (json['id'] ?? '').toString(),
      userId: (json['user_id'] ?? '').toString(),
      releaseId: (json['release_id'] ?? '').toString(),
      type: (json['type'] ?? '').toString(),
      status: (json['status'] ?? '').toString(),
      formData: (json['form_data'] as Map<String, dynamic>?) ?? const {},
      adminNotes: json['admin_notes'] as String?,
      assignedManager: json['assigned_manager'] as String?,
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'user_id': userId,
      'release_id': releaseId,
      'type': type,
      'status': status,
      'form_data': formData,
      'admin_notes': adminNotes,
      'assigned_manager': assignedManager,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class PromoEventModel {
  const PromoEventModel({
    required this.id,
    required this.promoRequestId,
    required this.eventType,
    required this.payload,
    required this.createdAt,
  });

  final String id;
  final String promoRequestId;
  final String eventType;
  final Map<String, dynamic> payload;
  final DateTime createdAt;

  factory PromoEventModel.fromJson(Map<String, dynamic> json) {
    return PromoEventModel(
      id: (json['id'] ?? '').toString(),
      promoRequestId: (json['promo_request_id'] ?? '').toString(),
      eventType: (json['event_type'] ?? '').toString(),
      payload: (json['payload'] as Map<String, dynamic>?) ?? const {},
      createdAt: DateTime.tryParse((json['created_at'] ?? '').toString()) ?? DateTime.now(),
    );
  }
}
