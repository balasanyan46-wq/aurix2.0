class ReportModel {
  final String id;
  final DateTime periodStart;
  final DateTime periodEnd;
  final String distributor;
  final String? fileName;
  final String? fileUrl;
  final String status;
  final String? createdBy;
  final String? userId;
  final String? releaseId;
  final DateTime createdAt;

  const ReportModel({
    required this.id,
    required this.periodStart,
    required this.periodEnd,
    this.distributor = 'zvonko',
    this.fileName,
    this.fileUrl,
    this.status = 'uploaded',
    this.createdBy,
    this.userId,
    this.releaseId,
    required this.createdAt,
  });

  factory ReportModel.fromJson(Map<String, dynamic> json) {
    return ReportModel(
      id: json['id'] as String,
      periodStart: DateTime.parse(json['period_start'] as String),
      periodEnd: DateTime.parse(json['period_end'] as String),
      distributor: json['distributor'] as String? ?? 'zvonko',
      fileName: json['file_name'] as String?,
      fileUrl: json['file_url'] as String?,
      status: json['status'] as String? ?? 'uploaded',
      createdBy: json['created_by'] as String?,
      userId: json['user_id'] as String?,
      releaseId: json['release_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
