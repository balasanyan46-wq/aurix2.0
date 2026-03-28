import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_repository.dart';
import 'package:aurix_flutter/features/navigator/domain/navigator_recommendation_service.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final navigatorRepositoryProvider =
    Provider<NavigatorRepository>((ref) => NavigatorRepository());

final navigatorRecommendationServiceProvider =
    Provider<NavigatorRecommendationService>(
  (ref) => NavigatorRecommendationService(),
);

final navigatorControllerProvider =
    StateNotifierProvider<NavigatorController, NavigatorState>((ref) {
  return NavigatorController(ref)..load();
});

class NavigatorState {
  final bool loading;
  final String? error;
  final List<NavigatorMaterial> materials;
  final Set<String> savedIds;
  final Set<String> completedIds;
  final Set<String> openedIds;
  final NavigatorReleaseSignal? releaseSignal;
  final NavigatorOnboardingAnswers? answers;
  final NavigatorRecommendationResult? recommendations;
  final String query;
  final Set<String> categoryFilter;
  final Set<String> stageFilter;
  final Set<String> goalFilter;
  final Set<String> platformFilter;
  final Set<String> durationFilter;
  final Set<String> typeFilter;
  final Set<String> difficultyFilter;
  final Set<String> statusFilter;
  final bool onlySaved;
  final bool onlyCompleted;

  const NavigatorState({
    required this.loading,
    required this.error,
    required this.materials,
    required this.savedIds,
    required this.completedIds,
    required this.openedIds,
    required this.releaseSignal,
    required this.answers,
    required this.recommendations,
    required this.query,
    required this.categoryFilter,
    required this.stageFilter,
    required this.goalFilter,
    required this.platformFilter,
    required this.durationFilter,
    required this.typeFilter,
    required this.difficultyFilter,
    required this.statusFilter,
    required this.onlySaved,
    required this.onlyCompleted,
  });

  NavigatorState copyWith({
    bool? loading,
    String? error,
    List<NavigatorMaterial>? materials,
    Set<String>? savedIds,
    Set<String>? completedIds,
    Set<String>? openedIds,
    NavigatorReleaseSignal? releaseSignal,
    NavigatorOnboardingAnswers? answers,
    NavigatorRecommendationResult? recommendations,
    String? query,
    Set<String>? categoryFilter,
    Set<String>? stageFilter,
    Set<String>? goalFilter,
    Set<String>? platformFilter,
    Set<String>? durationFilter,
    Set<String>? typeFilter,
    Set<String>? difficultyFilter,
    Set<String>? statusFilter,
    bool? onlySaved,
    bool? onlyCompleted,
  }) {
    return NavigatorState(
      loading: loading ?? this.loading,
      error: error,
      materials: materials ?? this.materials,
      savedIds: savedIds ?? this.savedIds,
      completedIds: completedIds ?? this.completedIds,
      openedIds: openedIds ?? this.openedIds,
      releaseSignal: releaseSignal ?? this.releaseSignal,
      answers: answers ?? this.answers,
      recommendations: recommendations ?? this.recommendations,
      query: query ?? this.query,
      categoryFilter: categoryFilter ?? this.categoryFilter,
      stageFilter: stageFilter ?? this.stageFilter,
      goalFilter: goalFilter ?? this.goalFilter,
      platformFilter: platformFilter ?? this.platformFilter,
      durationFilter: durationFilter ?? this.durationFilter,
      typeFilter: typeFilter ?? this.typeFilter,
      difficultyFilter: difficultyFilter ?? this.difficultyFilter,
      statusFilter: statusFilter ?? this.statusFilter,
      onlySaved: onlySaved ?? this.onlySaved,
      onlyCompleted: onlyCompleted ?? this.onlyCompleted,
    );
  }
}

class NavigatorController extends StateNotifier<NavigatorState> {
  NavigatorController(this._ref)
      : super(
          const NavigatorState(
            loading: false,
            error: null,
            materials: [],
            savedIds: {},
            completedIds: {},
            openedIds: {},
            releaseSignal: null,
            answers: null,
            recommendations: null,
            query: '',
            categoryFilter: {},
            stageFilter: {},
            goalFilter: {},
            platformFilter: {},
            durationFilter: {},
            typeFilter: {},
            difficultyFilter: {},
            statusFilter: {},
            onlySaved: false,
            onlyCompleted: false,
          ),
        );

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null);
    try {
      final repo = _ref.read(navigatorRepositoryProvider);
      final user = _ref.read(currentUserProvider);
      final materials = await repo.getPublishedMaterials();
      Set<String> saved = <String>{};
      Set<String> completed = <String>{};
      NavigatorOnboardingAnswers? answers;
      if (user != null) {
        saved = await repo.getSavedMaterialIds(user.id);
        completed = await repo.getCompletedMaterialIds(user.id);
        answers = await repo.getOnboardingAnswers(user.id);
      }
      state = state.copyWith(
        loading: true,
        materials: materials,
        savedIds: saved,
        completedIds: completed,
        answers: answers,
      );
      if (answers != null) {
        await buildRecommendations(answers);
      }
      state = state.copyWith(loading: false);
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  Future<void> submitOnboarding(NavigatorOnboardingAnswers answers) async {
    final user = _ref.read(currentUserProvider);
    final repo = _ref.read(navigatorRepositoryProvider);
    if (user != null) {
      await repo.saveOnboardingAnswers(userId: user.id, answers: answers);
    }
    state = state.copyWith(answers: answers);
    await buildRecommendations(answers);
  }

  Future<void> buildRecommendations(NavigatorOnboardingAnswers answers) async {
    final recommendation = _ref.read(navigatorRecommendationServiceProvider);
    final user = _ref.read(currentUserProvider);
    var materials = state.materials;
    if (materials.isEmpty) {
      // AI flow can finish before initial load completed.
      // Ensure we always have a material base for recommendation scoring.
      materials = await _ref.read(navigatorRepositoryProvider).getPublishedMaterials();
      state = state.copyWith(materials: materials);
    }
    final releaseSignal = await _readReleaseSignal(user?.id);
    final progressSignal = await _readProgressSignal(user?.id);
    final dnkSignal = await _readDnkSignal(user?.id);
    final result = recommendation.recommend(
      materials: materials,
      answers: answers,
      dnk: dnkSignal,
      progress: progressSignal,
      release: releaseSignal,
      savedIds: state.savedIds,
      completedIds: state.completedIds,
      openedIds: state.openedIds,
    );
    state = state.copyWith(recommendations: result, releaseSignal: releaseSignal);
  }

  Future<void> toggleSaved(String materialId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    final repo = _ref.read(navigatorRepositoryProvider);
    final next = Set<String>.from(state.savedIds);
    final isSaved = next.contains(materialId);
    if (isSaved) {
      next.remove(materialId);
    } else {
      next.add(materialId);
    }
    state = state.copyWith(savedIds: next);
    try {
      await repo.setSaved(
        userId: user.id,
        materialId: materialId,
        isSaved: !isSaved,
      );
    } catch (_) {
      // Keep UX smooth even when backend tables are not ready yet.
    }
    final answers = state.answers;
    if (answers != null) {
      await buildRecommendations(answers);
    }
  }

  Future<void> toggleCompleted(String materialId) async {
    final user = _ref.read(currentUserProvider);
    if (user == null) return;
    final repo = _ref.read(navigatorRepositoryProvider);
    final next = Set<String>.from(state.completedIds);
    final isCompleted = next.contains(materialId);
    if (isCompleted) {
      next.remove(materialId);
    } else {
      next.add(materialId);
    }
    state = state.copyWith(completedIds: next);
    try {
      await repo.setCompleted(
        userId: user.id,
        materialId: materialId,
        isCompleted: !isCompleted,
      );
    } catch (_) {
      // Keep UX smooth even when backend tables are not ready yet.
    }
    final answers = state.answers;
    if (answers != null) {
      await buildRecommendations(answers);
    }
  }

  Future<void> addToRoute(String materialId) async {
    if (state.savedIds.contains(materialId)) return;
    await toggleSaved(materialId);
  }

  void setQuery(String value) => state = state.copyWith(query: value);

  void setOnlySaved(bool enabled) => state = state.copyWith(onlySaved: enabled);
  void setOnlyCompleted(bool enabled) => state = state.copyWith(onlyCompleted: enabled);

  void toggleCategoryFilter(String v) {
    final next = Set<String>.from(state.categoryFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(categoryFilter: next);
  }

  void toggleStageFilter(String v) {
    final next = Set<String>.from(state.stageFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(stageFilter: next);
  }

  void toggleGoalFilter(String v) {
    final next = Set<String>.from(state.goalFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(goalFilter: next);
  }

  void togglePlatformFilter(String v) {
    final next = Set<String>.from(state.platformFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(platformFilter: next);
  }

  void toggleDurationFilter(String v) {
    final next = Set<String>.from(state.durationFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(durationFilter: next);
  }

  void toggleTypeFilter(String v) {
    final next = Set<String>.from(state.typeFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(typeFilter: next);
  }

  void toggleDifficultyFilter(String v) {
    final next = Set<String>.from(state.difficultyFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(difficultyFilter: next);
  }

  void toggleStatusFilter(String v) {
    final next = Set<String>.from(state.statusFilter);
    next.contains(v) ? next.remove(v) : next.add(v);
    state = state.copyWith(statusFilter: next);
  }

  void resetFilters() {
    state = state.copyWith(
      categoryFilter: {},
      stageFilter: {},
      goalFilter: {},
      platformFilter: {},
      durationFilter: {},
      typeFilter: {},
      difficultyFilter: {},
      statusFilter: {},
      onlySaved: false,
      onlyCompleted: false,
      query: '',
    );
  }

  void markOpened(String materialId) {
    final next = Set<String>.from(state.openedIds)..add(materialId);
    state = state.copyWith(openedIds: next);
  }

  String materialStatus(String materialId) {
    NavigatorMaterial? mat;
    for (final item in state.materials) {
      if (item.id == materialId) {
        mat = item;
        break;
      }
    }
    if (state.completedIds.contains(materialId)) return 'завершено';
    if (state.savedIds.contains(materialId)) return 'сохранено';
    if (state.openedIds.contains(materialId)) return 'в процессе';
    if (mat != null && DateTime.now().difference(mat.updatedAt).inDays <= 14) {
      return 'новое';
    }
    return 'не открывал';
  }

  List<NavigatorMaterial> visibleMaterials() {
    final q = state.query.trim().toLowerCase();
    final out = <NavigatorMaterial>[];
    for (final m in state.materials) {
      if (state.onlySaved && !state.savedIds.contains(m.id)) continue;
      if (state.onlyCompleted && !state.completedIds.contains(m.id)) continue;
      if (state.categoryFilter.isNotEmpty &&
          !state.categoryFilter.contains(m.category)) {
        continue;
      }
      if (state.stageFilter.isNotEmpty &&
          m.stages.where(state.stageFilter.contains).isEmpty) {
        continue;
      }
      if (state.goalFilter.isNotEmpty &&
          m.goals.where(state.goalFilter.contains).isEmpty) {
        continue;
      }
      if (state.platformFilter.isNotEmpty &&
          m.platforms.where(state.platformFilter.contains).isEmpty) {
        continue;
      }
      if (state.durationFilter.isNotEmpty &&
          !state.durationFilter.contains(m.durationBucket)) {
        continue;
      }
      if (state.typeFilter.isNotEmpty && !state.typeFilter.contains(m.formatType)) {
        continue;
      }
      if (state.difficultyFilter.isNotEmpty &&
          !state.difficultyFilter.contains(m.difficulty)) {
        continue;
      }
      if (state.statusFilter.isNotEmpty &&
          !state.statusFilter.contains(materialStatus(m.id))) {
        continue;
      }
      if (q.isNotEmpty) {
        final bag = '${m.title} ${m.subtitle} ${m.excerpt} ${m.tags.join(' ')}'
            .toLowerCase();
        if (!bag.contains(q)) continue;
      }
      out.add(m);
    }
    out.sort((a, b) => b.priorityScore.compareTo(a.priorityScore));
    return out;
  }

  Future<NavigatorReleaseSignal?> _readReleaseSignal(String? userId) async {
    if (userId == null) return null;
    final releases =
        await _ref.read(releaseRepositoryProvider).getReleasesByOwner(userId);
    if (releases.isEmpty) {
      return const NavigatorReleaseSignal(daysToRelease: null, alreadyReleased: false);
    }
    releases.sort((a, b) {
      final da = a.releaseDate ?? DateTime(2100);
      final db = b.releaseDate ?? DateTime(2100);
      return da.compareTo(db);
    });
    final now = DateTime.now();
    for (final r in releases) {
      if (r.releaseDate == null) continue;
      final date = DateTime(r.releaseDate!.year, r.releaseDate!.month, r.releaseDate!.day);
      final days = date.difference(DateTime(now.year, now.month, now.day)).inDays;
      if (days >= 0) {
        return NavigatorReleaseSignal(daysToRelease: days, alreadyReleased: false);
      }
    }
    return const NavigatorReleaseSignal(daysToRelease: null, alreadyReleased: true);
  }

  Future<NavigatorProgressSignal?> _readProgressSignal(String? userId) async {
    if (userId == null) return null;
    final repo = _ref.read(progressCheckinsRepositoryProvider);
    final end = DateTime.now();
    final start = end.subtract(const Duration(days: 13));
    final checkins = await repo.getCheckins(startDay: start, endDay: end);
    if (checkins.isEmpty) {
      return const NavigatorProgressSignal(consistencyScore: 0.2, disciplineDrop: true);
    }
    final recent = checkins.where((c) =>
        c.day.isAfter(end.subtract(const Duration(days: 7))) ||
        c.day.isAtSameMomentAs(end.subtract(const Duration(days: 7))));
    final prev = checkins.where((c) =>
        c.day.isBefore(end.subtract(const Duration(days: 7))));
    final recentCount = recent.length;
    final prevCount = prev.length;
    final consistency = (recentCount / 7).clamp(0, 1).toDouble();
    final drop = prevCount > 0 && recentCount < (prevCount * 0.6);
    return NavigatorProgressSignal(
      consistencyScore: consistency,
      disciplineDrop: drop || consistency < 0.35,
    );
  }

  Future<NavigatorDnkSignal?> _readDnkSignal(String? userId) async {
    if (userId == null) return null;
    try {
      final res = await ApiClient.get('/dnk-results/latest', query: {'user_id': userId});
      final row = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : null;
      final raw = (row?['tags'] as List?) ?? const [];
      return NavigatorDnkSignal(
        focusTags: raw.map((e) => e.toString()).toList(),
      );
    } catch (e) {
      return null;
    }
  }
}
