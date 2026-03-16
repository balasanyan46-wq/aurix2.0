class ReportRowModel {
  final String id;
  final String reportId;
  final DateTime? reportDate;
  final String? trackTitle;
  final String? isrc;
  final String? platform;
  final String? country;
  final int streams;
  final double revenue;
  final String currency;
  final String? trackId;
  final String? userId;
  final String? releaseId;
  final Map<String, dynamic>? rawRowJson;
  final DateTime createdAt;

  const ReportRowModel({
    required this.id,
    required this.reportId,
    this.reportDate,
    this.trackTitle,
    this.isrc,
    this.platform,
    this.country,
    this.streams = 0,
    this.revenue = 0,
    this.currency = 'USD',
    this.trackId,
    this.userId,
    this.releaseId,
    this.rawRowJson,
    required this.createdAt,
  });

  factory ReportRowModel.fromJson(Map<String, dynamic> json) {
    return ReportRowModel(
      id: (json['id'])?.toString() ?? '',
      reportId: json['report_id']?.toString() ?? '',
      reportDate: json['report_date'] != null ? DateTime.tryParse(json['report_date']?.toString() ?? '') : null,
      trackTitle: json['track_title']?.toString(),
      isrc: json['isrc']?.toString(),
      platform: json['platform']?.toString(),
      country: json['country']?.toString(),
      streams: (json['streams'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      currency: json['currency']?.toString() ?? 'USD',
      trackId: json['track_id']?.toString(),
      userId: json['user_id']?.toString(),
      releaseId: json['release_id']?.toString(),
      rawRowJson: json['raw_row_json'] as Map<String, dynamic>?,
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}
