import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/data/models/metrics_snapshot.dart';

abstract class IndexRepository {
  Future<List<Artist>> getArtists();
  Future<List<MetricsSnapshot>> getSnapshots({
    required DateTime from,
    required DateTime to,
  });
  Future<List<IndexScore>> getIndexScores({
    required DateTime periodStart,
    required DateTime periodEnd,
  });
  Future<List<AwardCategory>> getAwardCategories({required int seasonYear});
  Future<List<AwardNominee>> getNominees({required String categoryId});
}
