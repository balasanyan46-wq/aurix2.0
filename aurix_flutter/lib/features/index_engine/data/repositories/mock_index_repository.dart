import 'dart:math';
import 'package:aurix_flutter/features/index_engine/data/models/artist.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index_engine/data/repositories/index_repository.dart';

class MockIndexEngineRepository implements IndexEngineRepository {
  static final Random _r = Random(42);
  late final List<Artist> _artists;
  late final List<MetricsSnapshot> _snapshots;

  MockIndexEngineRepository() {
    _initArtists();
    _initSnapshots();
  }

  void _initArtists() {
    const genres = ['Pop', 'Hip-Hop', 'R&B', 'Electronic', 'Rock', 'Indie', 'Jazz', 'Folk'];
    const regions = ['Moscow', 'St. Petersburg', 'London', 'Berlin', 'NYC', 'LA', 'Paris', 'Tokyo', 'Seoul', null];
    final names = _artistNames;

    _artists = List.generate(45, (i) {
      final createdAt = DateTime(2022 + (i % 4), (i % 12) + 1, (i % 28) + 1);
      return Artist(
        id: 'artist_$i',
        name: names[i % names.length],
        avatarUrl: null,
        genrePrimary: genres[i % genres.length],
        region: regions[i % regions.length],
        createdAt: createdAt,
      );
    });
  }

  static const _artistNames = [
    'Luna Nova', 'Alex Blade', 'Maya Stone', 'Jordan Frost', 'Raven Dark',
    'Cairo Keys', 'Phoenix Rise', 'Indigo Wave', 'Vega Star', 'Orion Sound',
    'Nova Spark', 'Echo Lane', 'Atlas Beats', 'Helix One', 'Pulse Theory',
    'Zen Flow', 'Blaze Heart', 'Arctic Moon', 'Solar Wind', 'Crimson Tide',
    'Velvet Voice', 'Silver Strings', 'Amber Glow', 'Ruby Sky', 'Jade Dream',
    'Opal Night', 'Pearl Drop', 'Sage Sound', 'Willow Breeze', 'Maple Beat',
    'Birch Tone', 'Cedar Note', 'Ash Melody', 'Elm Rhythm', 'Oak Pulse',
    'Pine Wave', 'Spruce Bass', 'Ivy Chord', 'Rose Key', 'Lily Note',
  ];

  void _initSnapshots() {
    final now = DateTime.now();
    final thisMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = thisMonthStart.subtract(const Duration(days: 1));
    _snapshots = [];

    for (final a in _artists) {
      final baseListeners = 1000 + _r.nextInt(900000);
      final baseStreams = baseListeners * (3 + _r.nextInt(15));
      _snapshots.add(MetricsSnapshot(
        artistId: a.id,
        periodStart: thisMonthStart,
        periodEnd: now,
        listenersMonthly: baseListeners,
        streams: baseStreams,
        saves: (baseStreams * (0.02 + _r.nextDouble() * 0.08)).round(),
        shares: (baseStreams * (0.001 + _r.nextDouble() * 0.01)).round(),
        completionRate: 0.3 + _r.nextDouble() * 0.6,
        releaseCountPeriod: _r.nextInt(3) + (a.id == 'artist_0' ? 2 : 0),
        collabCountPeriod: _r.nextInt(3),
        liveEventsPeriod: _r.nextInt(5),
        strikes: _r.nextInt(4) == 0 ? 1 : 0,
      ));
      _snapshots.add(MetricsSnapshot(
        artistId: a.id,
        periodStart: lastMonthStart,
        periodEnd: lastMonthEnd,
        listenersMonthly: (baseListeners * (0.7 + _r.nextDouble() * 0.5)).round(),
        streams: (baseStreams * (0.6 + _r.nextDouble() * 0.6)).round(),
        saves: (baseStreams * 0.04 * (0.5 + _r.nextDouble())).round(),
        shares: (baseStreams * 0.005 * (0.5 + _r.nextDouble())).round(),
        completionRate: 0.35 + _r.nextDouble() * 0.5,
        releaseCountPeriod: _r.nextInt(2) + 1,
        collabCountPeriod: _r.nextInt(2),
        liveEventsPeriod: _r.nextInt(3),
        strikes: 0,
      ));
    }
  }

  @override
  Future<List<Artist>> getArtists() async => _artists;

  @override
  Future<List<MetricsSnapshot>> getSnapshots({
    required DateTime from,
    required DateTime to,
  }) async {
    return _snapshots.where((s) =>
        (s.periodStart.isBefore(to) || s.periodStart.isAtSameMomentAs(to)) &&
        (s.periodEnd.isAfter(from) || s.periodEnd.isAtSameMomentAs(from))).toList();
  }
}
