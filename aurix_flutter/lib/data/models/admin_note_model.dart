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
      id: json['id'] as String,
      releaseId: json['release_id'] as String,
      adminId: json['admin_id'] as String,
      note: json['note'] as String,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
