import 'package:aurix_flutter/core/enums.dart';

/// Mock artist data
class MockArtistData {
  final String artistName;
  final String displayName;
  final int totalStreams;
  final double estimatedRevenue;
  final int activeReleases;
  final int pendingReview;
  final String topPlatform;

  const MockArtistData({
    this.artistName = 'Your Artist Name',
    this.displayName = 'Artist',
    this.totalStreams = 124000,
    this.estimatedRevenue = 2840.0,
    this.activeReleases = 2,
    this.pendingReview = 1,
    this.topPlatform = 'Spotify',
  });
}

/// Mock release for Release OS
class MockRelease {
  final String id;
  final String title;
  final String artistName;
  final ReleaseStatus status;
  final String releaseType;
  final int streams;
  final DateTime? releaseDate;
  final int completionPercent;
  final DateTime? deadline;
  final bool hasWarnings;

  const MockRelease({
    required this.id,
    required this.title,
    required this.artistName,
    required this.status,
    this.releaseType = 'single',
    this.streams = 0,
    this.releaseDate,
    this.completionPercent = 0,
    this.deadline,
    this.hasWarnings = false,
  });
}

/// Mock analytics point for graphs
class MockAnalyticsPoint {
  final String label;
  final int streams;
  final double revenue;

  const MockAnalyticsPoint({required this.label, required this.streams, required this.revenue});
}

/// Central mock data — single source of truth for design mode
class MockData {
  MockData._();

  static const artist = MockArtistData();

  static final releases = <MockRelease>[
    MockRelease(id: '1', title: 'Midnight Sessions', artistName: 'Your Artist', status: ReleaseStatus.live, streams: 45000, releaseType: 'album', completionPercent: 100, releaseDate: DateTime(2025, 1, 15)),
    MockRelease(id: '2', title: 'Summer EP', artistName: 'Your Artist', status: ReleaseStatus.inReview, releaseType: 'ep', completionPercent: 85, deadline: DateTime(2025, 3, 1), hasWarnings: true),
    MockRelease(id: '3', title: 'Acoustic Live', artistName: 'Your Artist', status: ReleaseStatus.draft, releaseType: 'single', completionPercent: 40, deadline: DateTime(2025, 4, 15)),
  ];

  static List<MockAnalyticsPoint> get monthlyStreams => const [
        MockAnalyticsPoint(label: 'Jan', streams: 12000, revenue: 280),
        MockAnalyticsPoint(label: 'Feb', streams: 18000, revenue: 420),
        MockAnalyticsPoint(label: 'Mar', streams: 15000, revenue: 350),
        MockAnalyticsPoint(label: 'Apr', streams: 22000, revenue: 510),
        MockAnalyticsPoint(label: 'May', streams: 28000, revenue: 650),
        MockAnalyticsPoint(label: 'Jun', streams: 29000, revenue: 630),
      ];

  static List<({String platform, int streams})> get streamsByPlatform => const [
        (platform: 'Spotify', streams: 52000),
        (platform: 'Apple Music', streams: 31000),
        (platform: 'YouTube', streams: 25000),
        (platform: 'Deezer', streams: 12000),
        (platform: 'Other', streams: 4000),
      ];

  static double get streamsGrowthPercent => 18.0;
}
