/// Запись из public.legal_documents (Supabase).
class LegalDocumentModel {
  const LegalDocumentModel({
    required this.id,
    required this.userId,
    required this.templateId,
    required this.title,
    required this.payload,
    this.filePdfPath,
    required this.status,
    required this.createdAt,
  });

  final String id;
  final String userId;
  final String templateId;
  final String title;
  final Map<String, dynamic> payload;
  final String? filePdfPath;
  final String status;
  final DateTime createdAt;

  factory LegalDocumentModel.fromJson(Map<String, dynamic> json) {
    Map<String, dynamic> payload = {};
    final p = json['payload'];
    if (p is Map) {
      payload = Map<String, dynamic>.from(p);
    }
    return LegalDocumentModel(
      id: json['id'] as String,
      userId: json['user_id'] as String? ?? '',
      templateId: json['template_id'] as String? ?? '',
      title: json['title'] as String? ?? '',
      payload: payload,
      filePdfPath: (json['file_pdf_path'] ?? json['storage_path']) as String?,
      status: json['status'] as String? ?? 'draft',
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'] as String)
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'user_id': userId,
        'template_id': templateId,
        'title': title,
        'payload': payload,
        'file_pdf_path': filePdfPath,
        'status': status,
        'created_at': createdAt.toIso8601String(),
      };
}
