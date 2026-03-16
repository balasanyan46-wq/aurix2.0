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
      id: (json['id'])?.toString() ?? '',
      periodStart: DateTime.tryParse(json['period_start']?.toString() ?? '') ?? DateTime.now(),
      periodEnd: DateTime.tryParse(json['period_end']?.toString() ?? '') ?? DateTime.now(),
      distributor: json['distributor']?.toString() ?? 'zvonko',
      fileName: json['file_name']?.toString(),
      fileUrl: json['file_url']?.toString(),
      status: json['status']?.toString() ?? 'uploaded',
      createdBy: json['created_by']?.toString(),
      userId: json['user_id']?.toString(),
      releaseId: json['release_id']?.toString(),
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
