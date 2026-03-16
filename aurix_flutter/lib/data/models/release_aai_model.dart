class ReleaseAaiModel {
  final double totalScore;
  final String statusCode;
  final double impulseScore;
  final double conversionScore;
  final double engagementScore;
  final double geographyScore;
  final int views48h;
  final int clicks48h;
  final int uniqueCountries48h;
  final DateTime? updatedAt;
  final List<ReleaseAaiPoint> trend;
  final List<ReleaseAaiBucket> platforms;
  final List<ReleaseAaiBucket> countries;

  const ReleaseAaiModel({
    required this.totalScore,
    required this.statusCode,
    required this.impulseScore,
    required this.conversionScore,
    required this.engagementScore,
    required this.geographyScore,
    required this.views48h,
    required this.clicks48h,
    required this.uniqueCountries48h,
    required this.updatedAt,
    required this.trend,
    required this.platforms,
    required this.countries,
  });

  String get statusLabel => switch (statusCode) {
        'hot' => 'Горящий',
        'accelerating' => 'Разгоняется',
        'watching' => 'Наблюдают',
        _ => 'Тихий',
      };

  factory ReleaseAaiModel.fromIndexRow(
    Map<String, dynamic> row, {
    required List<ReleaseAaiPoint> trend,
    required List<ReleaseAaiBucket> platforms,
    required List<ReleaseAaiBucket> countries,
  }) {
    return ReleaseAaiModel(
      totalScore: (row['total_score'] as num?)?.toDouble() ?? 0,
      statusCode: row['status_code']?.toString() ?? 'quiet',
      impulseScore: (row['impulse_score'] as num?)?.toDouble() ?? 0,
      conversionScore: (row['conversion_score'] as num?)?.toDouble() ?? 0,
      engagementScore: (row['engagement_score'] as num?)?.toDouble() ?? 0,
      geographyScore: (row['geography_score'] as num?)?.toDouble() ?? 0,
      views48h: (row['views_48h'] as num?)?.toInt() ?? 0,
      clicks48h: (row['clicks_48h'] as num?)?.toInt() ?? 0,
      uniqueCountries48h: (row['unique_countries_48h'] as num?)?.toInt() ?? 0,
      updatedAt: row['updated_at'] != null ? DateTime.tryParse(row['updated_at']?.toString() ?? '') : null,
      trend: trend,
      platforms: platforms,
      countries: countries,
    );
  }
}

class ReleaseAaiPoint {
  final DateTime day;
  final int value;
  const ReleaseAaiPoint({required this.day, required this.value});
}

class ReleaseAaiBucket {
  final String key;
  final int count;
  const ReleaseAaiBucket({required this.key, required this.count});
}

class DnkAaiHint {
  final String testSlug;
  final String expectedGrowthChannel;
  final String notes;

  const DnkAaiHint({
    required this.testSlug,
    required this.expectedGrowthChannel,
    required this.notes,
  });
}

