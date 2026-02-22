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
    this.rawRowJson,
    required this.createdAt,
  });

  factory ReportRowModel.fromJson(Map<String, dynamic> json) {
    return ReportRowModel(
      id: json['id'] as String,
      reportId: json['report_id'] as String,
      reportDate: json['report_date'] != null ? DateTime.tryParse(json['report_date'] as String) : null,
      trackTitle: json['track_title'] as String?,
      isrc: json['isrc'] as String?,
      platform: json['platform'] as String?,
      country: json['country'] as String?,
      streams: (json['streams'] as num?)?.toInt() ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      currency: json['currency'] as String? ?? 'USD',
      trackId: json['track_id'] as String?,
      rawRowJson: json['raw_row_json'] as Map<String, dynamic>?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
