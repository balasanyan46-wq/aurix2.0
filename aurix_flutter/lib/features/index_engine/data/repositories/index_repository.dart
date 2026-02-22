import 'package:aurix_flutter/features/index_engine/data/models/artist.dart';
import 'package:aurix_flutter/features/index_engine/data/models/metrics_snapshot.dart';

abstract class IndexEngineRepository {
  Future<List<Artist>> getArtists();
  Future<List<MetricsSnapshot>> getSnapshots({
    required DateTime from,
    required DateTime to,
  });
}
