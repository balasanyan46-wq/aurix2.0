import 'package:aurix_flutter/features/index/data/models/artist.dart' as legacy;
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart' as legacy;
import 'package:aurix_flutter/features/index/data/models/metrics_snapshot.dart' as legacy;
import 'package:aurix_flutter/features/index/data/repositories/index_repository.dart';
import 'package:aurix_flutter/features/index_engine/adapters/index_engine_to_legacy_adapter.dart';
import 'package:aurix_flutter/features/index_engine/data/repositories/index_repository.dart' as engine_repo;
import 'package:aurix_flutter/features/index_engine/index_engine_service.dart';

/// Implements legacy IndexRepository using IndexEngineService. Awards from fallback.
class EngineBackedIndexRepository implements IndexRepository {
  final IndexEngineService _service;
  final engine_repo.IndexEngineRepository _engineRepo;
  final IndexEngineToLegacyAdapter _adapter;
  final IndexRepository _awardsFallback;

  EngineBackedIndexRepository({
    required IndexEngineService service,
    required engine_repo.IndexEngineRepository engineRepo,
    required IndexEngineToLegacyAdapter adapter,
    required IndexRepository awardsFallback,
  })  : _service = service,
        _engineRepo = engineRepo,
        _adapter = adapter,
        _awardsFallback = awardsFallback;

  @override
  Future<List<legacy.Artist>> getArtists() async {
    final artists = await _engineRepo.getArtists();
    return artists.map(_adapter.toLegacyArtist).toList();
  }

  @override
  Future<List<legacy.MetricsSnapshot>> getSnapshots({
    required DateTime from,
    required DateTime to,
  }) async {
    final snapshots = await _engineRepo.getSnapshots(from: from, to: to);
    return snapshots.map(_adapter.toLegacySnapshot).toList();
  }

  @override
  Future<List<legacy.IndexScore>> getIndexScores({
    required DateTime periodStart,
    required DateTime periodEnd,
  }) async {
    final scores = await _service.computePeriodScores(periodStart, periodEnd);
    final snapshots = await getSnapshots(from: periodStart, to: periodEnd);
    return _adapter.toLegacyScores(scores, snapshots);
  }

  @override
  Future<List<AwardCategory>> getAwardCategories({required int seasonYear}) =>
      _awardsFallback.getAwardCategories(seasonYear: seasonYear);

  @override
  Future<List<AwardNominee>> getNominees({required String categoryId}) =>
      _awardsFallback.getNominees(categoryId: categoryId);
}
