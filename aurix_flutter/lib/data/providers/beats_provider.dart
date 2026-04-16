import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/models/beat_model.dart';
import 'package:aurix_flutter/data/repositories/beat_repository.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';

final beatsProvider = FutureProvider.family<List<BeatModel>, BeatFilters>((ref, filters) async {
  final repo = ref.read(beatRepositoryProvider);
  return repo.getBeats(
    genre: filters.genre,
    mood: filters.mood,
    bpmMin: filters.bpmMin,
    bpmMax: filters.bpmMax,
    search: filters.search,
    limit: filters.limit,
    offset: filters.offset,
  );
});

final myBeatsProvider = FutureProvider<List<BeatModel>>((ref) async {
  final repo = ref.read(beatRepositoryProvider);
  return repo.getMyBeats();
});

class BeatFilters {
  final String? genre;
  final String? mood;
  final int? bpmMin;
  final int? bpmMax;
  final String? search;
  final int limit;
  final int offset;

  const BeatFilters({
    this.genre,
    this.mood,
    this.bpmMin,
    this.bpmMax,
    this.search,
    this.limit = 20,
    this.offset = 0,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BeatFilters &&
          genre == other.genre &&
          mood == other.mood &&
          bpmMin == other.bpmMin &&
          bpmMax == other.bpmMax &&
          search == other.search &&
          limit == other.limit &&
          offset == other.offset;

  @override
  int get hashCode => Object.hash(genre, mood, bpmMin, bpmMax, search, limit, offset);
}
