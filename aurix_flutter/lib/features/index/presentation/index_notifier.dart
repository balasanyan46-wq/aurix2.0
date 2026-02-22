import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/repositories/index_repository.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';

enum IndexState { loading, ready, error }

class IndexData {
  final List<Artist> artists;
  final List<IndexScore> scores;
  final List<AwardCategory> categories;
  final Map<String, List<AwardNominee>> nomineesByCategory;
  final String? selectedArtistId;

  const IndexData({
    required this.artists,
    required this.scores,
    required this.categories,
    required this.nomineesByCategory,
    this.selectedArtistId,
  });

  IndexData copyWith({String? selectedArtistId}) => IndexData(
        artists: artists,
        scores: scores,
        categories: categories,
        nomineesByCategory: nomineesByCategory,
        selectedArtistId: selectedArtistId ?? this.selectedArtistId,
      );

  Artist? get selectedArtist {
    if (selectedArtistId != null) {
      for (final a in artists) if (a.id == selectedArtistId) return a;
      return null;
    }
    return artists.isNotEmpty ? artists.first : null;
  }

  IndexScore? get selectedScore {
    if (selectedArtistId != null) {
      for (final s in scores) if (s.artistId == selectedArtistId) return s;
      return null;
    }
    return scores.isNotEmpty ? scores.first : null;
  }

  IndexScore? scoreFor(String artistId) {
    try {
      return scores.firstWhere((s) => s.artistId == artistId);
    } catch (_) {
      return null;
    }
  }

  Artist? artistFor(String id) {
    try {
      return artists.firstWhere((a) => a.id == id);
    } catch (_) {
      return null;
    }
  }

  IndexScore? get topLeader => scores.isNotEmpty ? scores.first : null;
  IndexScore? get topRising => scores.isEmpty ? null : scores.reduce((a, b) => a.trendDelta >= b.trendDelta ? a : b);
}

class IndexNotifier extends StateNotifier<({IndexState state, IndexData? data, String? error})> {
  IndexNotifier(this._repo) : super((state: IndexState.loading, data: null, error: null)) {
    load();
  }

  final IndexRepository _repo;

  Future<void> load() async {
    state = (state: IndexState.loading, data: state.data, error: null);
    try {
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month - 1, 1);
      final periodEnd = now;
      final artists = await _repo.getArtists();
      final scores = await _repo.getIndexScores(periodStart: periodStart, periodEnd: periodEnd);
      final categories = await _repo.getAwardCategories(seasonYear: now.year);
      final nomineesByCategory = <String, List<AwardNominee>>{};
      for (final c in categories) {
        nomineesByCategory[c.id] = await _repo.getNominees(categoryId: c.id);
      }
      state = (
        state: IndexState.ready,
        data: IndexData(
          artists: artists,
          scores: scores,
          categories: categories,
          nomineesByCategory: nomineesByCategory,
          selectedArtistId: state.data?.selectedArtistId,
        ),
        error: null,
      );
    } catch (e, st) {
      state = (state: IndexState.error, data: state.data, error: e.toString());
    }
  }

  void selectArtist(String? id) {
    if (state.data != null) {
      state = (state: state.state, data: state.data!.copyWith(selectedArtistId: id), error: state.error);
    }
  }

  Future<void> vote(String categoryId, String nomineeId) async {
    // MVP: local increment, auth/anti-fraud later
    // For now we just show a snackbar from the UI
  }
}

final indexProvider = StateNotifierProvider<IndexNotifier, ({IndexState state, IndexData? data, String? error})>((ref) {
  return IndexNotifier(ref.read(indexRepositoryProvider));
});
