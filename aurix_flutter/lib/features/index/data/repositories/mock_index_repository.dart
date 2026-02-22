import 'dart:math';
import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/data/models/metrics_snapshot.dart';
import 'package:aurix_flutter/features/index/data/repositories/index_repository.dart';
import 'package:aurix_flutter/features/index/domain/badge_engine.dart';
import 'package:aurix_flutter/features/index/domain/index_calculator.dart';

class MockIndexRepository implements IndexRepository {
  static final Random _r = Random(42);
  late final List<Artist> _artists;
  late final List<MetricsSnapshot> _snapshots;
  late final List<IndexScore> _scores;
  late final List<AwardCategory> _categories;
  late final Map<String, List<AwardNominee>> _nomineesByCategory;

  MockIndexRepository() {
    _initArtists();
    _initSnapshots();
    _initScores();
    _initAwards();
  }

  void _initArtists() {
    const genres = ['Pop', 'Hip-Hop', 'R&B', 'Electronic', 'Rock', 'Indie', 'Jazz', 'Folk'];
    const locations = ['Moscow', 'St. Petersburg', 'London', 'Berlin', 'NYC', 'LA', 'Paris', 'Tokyo', 'Seoul', null];
    final names = _artistNames;

    _artists = List.generate(45, (i) {
      final createdAt = DateTime(2022 + (i % 4), (i % 12) + 1, (i % 28) + 1);
      return Artist(
        id: 'artist_$i',
        name: names[i % names.length],
        avatarUrl: null,
        genrePrimary: genres[i % genres.length],
        location: locations[i % locations.length],
        aurixReleaseCount: 1 + (i % 12),
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
        strikes: 0,
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

  void _initScores() {
    final now = DateTime.now();
    final periodStart = DateTime(now.year, now.month - 1, 1);
    final periodEnd = now;

    final calc = IndexCalculator();
    var scores = calc.calculateScores(_snapshots, periodStart, periodEnd);
    scores = BadgeEngine().applyBadges(scores, _snapshots);

    final byGenre = <String, List<IndexScore>>{};
    for (final s in scores) {
      final a = _artists.firstWhere((x) => x.id == s.artistId);
      byGenre.putIfAbsent(a.genrePrimary, () => []).add(s);
    }
    for (final list in byGenre.values) {
      list.sort((a, b) => a.score.compareTo(b.score));
    }
    final genreRank = <String, int>{};
    for (final e in byGenre.entries) {
      for (var i = 0; i < e.value.length; i++) {
        genreRank[e.value[i].artistId] = i + 1;
      }
    }

    _scores = scores.asMap().entries.map((e) {
      final s = e.value;
      final trendDelta = _r.nextInt(80) - 20;
      return IndexScore(
        artistId: s.artistId,
        score: s.score,
        rankOverall: e.key + 1,
        rankInGenre: genreRank[s.artistId] ?? (e.key + 1),
        trendDelta: trendDelta,
        badges: s.badges,
        updatedAt: now,
      );
    }).toList();
  }

  void _initAwards() {
    final year = DateTime.now().year;
    _categories = [
      AwardCategory(id: 'best_artist', title: 'Лучший артист года', description: 'Высший индекс за сезон', type: 'artist', isPublicVoting: true, seasonYear: year),
      AwardCategory(id: 'breakthrough', title: 'Прорыв года', description: 'Максимальный рост индекса', type: 'artist', isPublicVoting: true, seasonYear: year),
      AwardCategory(id: 'debut', title: 'Лучший дебют', description: 'Артисты года с лучшим ростом', type: 'artist', isPublicVoting: true, seasonYear: year),
      AwardCategory(id: 'best_duo', title: 'Лучший дуэт', description: 'По коллаборациям', type: 'duo', isPublicVoting: false, seasonYear: year),
      AwardCategory(id: 'best_hit', title: 'Лучший хит', description: 'Высокие shares и streams', type: 'song', isPublicVoting: true, seasonYear: year),
      AwardCategory(id: 'stable_growth', title: 'Самый стабильный рост', description: 'Регулярность релизов и метрик', type: 'artist', isPublicVoting: false, seasonYear: year),
      AwardCategory(id: 'best_live', title: 'Лучший лайв', description: 'Лучшие живые выступления', type: 'artist', isPublicVoting: true, seasonYear: year),
      AwardCategory(id: 'best_album', title: 'Лучший альбом', description: 'Полноформатные релизы сезона', type: 'song', isPublicVoting: true, seasonYear: year),
      AwardCategory(id: 'best_producer', title: 'Лучший продюсер', description: 'Продюсерские работы', type: 'artist', isPublicVoting: false, seasonYear: year),
    ];

    final topByGrowth = List<IndexScore>.from(_scores)..sort((a, b) => b.trendDelta.compareTo(a.trendDelta));
    final thisYear = _artists.where((a) => a.createdAt.year == year).toList();
    final debuts = thisYear.take(5).map((a) => _scores.firstWhere((s) => s.artistId == a.id, orElse: () => _scores.first)).toList();
    final breakouts = topByGrowth.take(5).toList();
    final best = _scores.take(5).toList();
    final byCollab = _artists.where((a) {
      final snap = _snapshots.where((s) => s.artistId == a.id).firstOrNull;
      return (snap?.collabCountPeriod ?? 0) >= 2;
    }).take(5).toList();

    _nomineesByCategory = {};
    _nomineesByCategory['debut'] = debuts.asMap().entries.map((e) {
      final a = _artists.firstWhere((x) => x.id == e.value.artistId);
      return AwardNominee(categoryId: 'debut', nomineeId: e.value.artistId, displayTitle: a.name, scoreProof: e.value.score, isFinalist: e.key < 3, votes: _r.nextInt(500));
    }).toList();
    _nomineesByCategory['breakthrough'] = breakouts.asMap().entries.map((e) {
      final a = _artists.firstWhere((x) => x.id == e.value.artistId);
      return AwardNominee(categoryId: 'breakthrough', nomineeId: e.value.artistId, displayTitle: a.name, scoreProof: e.value.trendDelta, isFinalist: e.key < 3, votes: _r.nextInt(400));
    }).toList();
    _nomineesByCategory['best_artist'] = best.asMap().entries.map((e) {
      final a = _artists.firstWhere((x) => x.id == e.value.artistId);
      return AwardNominee(categoryId: 'best_artist', nomineeId: e.value.artistId, displayTitle: a.name, scoreProof: e.value.score, isFinalist: e.key < 3, votes: _r.nextInt(600));
    }).toList();
    _nomineesByCategory['best_duo'] = (byCollab.isEmpty ? _artists.take(5) : byCollab).map((a) {
      final s = _scores.firstWhere((x) => x.artistId == a.id, orElse: () => _scores.first);
      return AwardNominee(categoryId: 'best_duo', nomineeId: a.id, displayTitle: a.name, scoreProof: s.score, isFinalist: false, votes: 0);
    }).toList();
    _nomineesByCategory['best_hit'] = best.asMap().entries.map((e) {
      final a = _artists.firstWhere((x) => x.id == e.value.artistId);
      return AwardNominee(categoryId: 'best_hit', nomineeId: e.value.artistId, displayTitle: a.name, scoreProof: e.value.score, isFinalist: e.key < 3, votes: _r.nextInt(350));
    }).toList();
    final stableByReleases = List<IndexScore>.from(_scores)..sort((a, b) => b.score.compareTo(a.score));
    _nomineesByCategory['stable_growth'] = stableByReleases.take(5).toList().asMap().entries.map((e) {
      final a = _artists.firstWhere((x) => x.id == e.value.artistId);
      return AwardNominee(categoryId: 'stable_growth', nomineeId: e.value.artistId, displayTitle: a.name, scoreProof: e.value.score, isFinalist: e.key < 3, votes: 0);
    }).toList();
    _nomineesByCategory['best_live'] = _scores.take(5).toList().asMap().entries.map((e) {
      final a = _artists.firstWhere((x) => x.id == e.value.artistId);
      return AwardNominee(categoryId: 'best_live', nomineeId: e.value.artistId, displayTitle: a.name, scoreProof: e.value.score, isFinalist: e.key < 3, votes: _r.nextInt(200));
    }).toList();
    _nomineesByCategory['best_album'] = _scores.take(5).toList().asMap().entries.map((e) {
      final a = _artists.firstWhere((x) => x.id == e.value.artistId);
      return AwardNominee(categoryId: 'best_album', nomineeId: e.value.artistId, displayTitle: a.name, scoreProof: e.value.score, isFinalist: e.key < 3, votes: _r.nextInt(280));
    }).toList();
    _nomineesByCategory['best_producer'] = _artists.take(5).map((a) {
      final s = _scores.firstWhere((x) => x.artistId == a.id, orElse: () => _scores.first);
      return AwardNominee(categoryId: 'best_producer', nomineeId: a.id, displayTitle: a.name, scoreProof: s.score, isFinalist: false, votes: 0);
    }).toList();
  }

  @override
  Future<List<Artist>> getArtists() async => _artists;

  @override
  Future<List<MetricsSnapshot>> getSnapshots({required DateTime from, required DateTime to}) async {
    return _snapshots.where((s) =>
        (s.periodStart.isBefore(to) || s.periodStart.isAtSameMomentAs(to)) &&
        (s.periodEnd.isAfter(from) || s.periodEnd.isAtSameMomentAs(from))).toList();
  }

  @override
  Future<List<IndexScore>> getIndexScores({required DateTime periodStart, required DateTime periodEnd}) async =>
      _scores;

  @override
  Future<List<AwardCategory>> getAwardCategories({required int seasonYear}) async =>
      _categories.where((c) => c.seasonYear == seasonYear).toList();

  @override
  Future<List<AwardNominee>> getNominees({required String categoryId}) async =>
      _nomineesByCategory[categoryId] ?? [];
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
