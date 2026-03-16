class AdminNoteModel {
  final String id;
  final String releaseId;
  final String adminId;
  final String note;
  final DateTime createdAt;

  const AdminNoteModel({
    required this.id,
    required this.releaseId,
    required this.adminId,
    required this.note,
    required this.createdAt,
  });

  factory AdminNoteModel.fromJson(Map<String, dynamic> json) {
    return AdminNoteModel(
      id: (json['id'])?.toString() ?? '',
      releaseId: json['release_id']?.toString() ?? '',
      adminId: json['admin_id']?.toString() ?? '',
      note: json['note']?.toString() ?? '',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
