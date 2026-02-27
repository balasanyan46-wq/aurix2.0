import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_habit.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_checkin.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_daily_note.dart';
import 'package:aurix_flutter/features/progress/data/progress_schema_guard.dart';

enum ProgressViewMode { month, week }

enum ArtistOsMode { growth, release, system }

enum ProgressPreset { growthReels, release14Days, trackPerWeek }

class ProgressState {
  final ProgressViewMode mode;
  final DateTime anchorDay; // any day inside the selected range (month/week)
  final bool loading;
  final String? error;
  final String? schemaWarning; // shown inline, not as error snackbar
  final ArtistOsMode osMode;
  final List<ProgressHabit> habits;
  final Map<String, ProgressCheckin> checkinsByKey; // "$habitId|YYYY-MM-DD"
  final ProgressDailyNote? todayNote;

  const ProgressState({
    required this.mode,
    required this.anchorDay,
    required this.loading,
    required this.error,
    required this.schemaWarning,
    required this.osMode,
    required this.habits,
    required this.checkinsByKey,
    required this.todayNote,
  });

  ProgressState copyWith({
    ProgressViewMode? mode,
    DateTime? anchorDay,
    bool? loading,
    String? error,
    String? schemaWarning,
    ArtistOsMode? osMode,
    List<ProgressHabit>? habits,
    Map<String, ProgressCheckin>? checkinsByKey,
    ProgressDailyNote? todayNote,
  }) {
    return ProgressState(
      mode: mode ?? this.mode,
      anchorDay: anchorDay ?? this.anchorDay,
      loading: loading ?? this.loading,
      error: error,
      schemaWarning: schemaWarning,
      osMode: osMode ?? this.osMode,
      habits: habits ?? this.habits,
      checkinsByKey: checkinsByKey ?? this.checkinsByKey,
      todayNote: todayNote ?? this.todayNote,
    );
  }
}

final progressControllerProvider = StateNotifierProvider.autoDispose<ProgressController, ProgressState>((ref) {
  return ProgressController(ref)..load();
});

class ProgressController extends StateNotifier<ProgressState> {
  ProgressController(this._ref)
      : super(ProgressState(
          mode: ProgressViewMode.month,
          anchorDay: _dateOnly(DateTime.now()),
          loading: false,
          error: null,
          schemaWarning: null,
          osMode: ArtistOsMode.growth,
          habits: const [],
          checkinsByKey: const {},
          todayNote: null,
        ));

  final Ref _ref;

  Future<void> load() async {
    state = state.copyWith(loading: true, error: null, schemaWarning: null);
    try {
      final habitsRepo = _ref.read(progressHabitsRepositoryProvider);
      final checkinsRepo = _ref.read(progressCheckinsRepositoryProvider);
      final notesRepo = _ref.read(progressDailyNotesRepositoryProvider);

      final habits = await habitsRepo.getHabits(activeOnly: false);
      final range = _rangeFor(state.mode, state.anchorDay);
      String? schemaWarning;

      final byKey = <String, ProgressCheckin>{};
      try {
        final checkins = await checkinsRepo.getCheckins(startDay: range.$1, endDay: range.$2);
        for (final c in checkins) {
          byKey[_key(c.habitId, c.day)] = c;
        }
      } on ProgressSchemaMissingException catch (e) {
        schemaWarning = 'Нужно применить миграцию: таблица ${e.table} отсутствует.';
      }

      ProgressDailyNote? todayNote;
      try {
        todayNote = await notesRepo.getByDay(DateTime.now());
      } on ProgressSchemaMissingException catch (e) {
        schemaWarning ??= 'Нужно применить миграцию: таблица ${e.table} отсутствует.';
        todayNote = null;
      }

      state = state.copyWith(
        loading: false,
        habits: habits,
        checkinsByKey: byKey,
        todayNote: todayNote,
        schemaWarning: schemaWarning,
      );
    } catch (e) {
      state = state.copyWith(loading: false, error: e.toString());
    }
  }

  void setMode(ProgressViewMode mode) {
    if (state.mode == mode) return;
    state = state.copyWith(mode: mode);
    unawaited(load());
  }

  void setOsMode(ArtistOsMode mode) {
    if (state.osMode == mode) return;
    state = state.copyWith(osMode: mode);
  }

  void setAnchorDay(DateTime day) {
    final d = _dateOnly(day);
    if (_dateOnly(state.anchorDay) == d) return;
    state = state.copyWith(anchorDay: d);
    unawaited(load());
  }

  List<DateTime> visibleDays() {
    final range = _rangeFor(state.mode, state.anchorDay);
    final start = _dateOnly(range.$1);
    final end = _dateOnly(range.$2);
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      days.add(d);
    }
    return days;
  }

  List<ProgressHabit> activeHabits({int limit = 8}) {
    final active = state.habits.where((h) => h.isActive).toList();
    active.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return active.take(limit).toList();
  }

  List<ProgressHabit> habitsForOsMode({int limit = 8}) {
    final active = activeHabits(limit: 999);
    final cats = _categoriesForOsMode(state.osMode);
    final filtered = active.where((h) => cats.contains(h.category)).toList();
    final result = (filtered.isEmpty ? active : filtered);
    return result.take(limit).toList();
  }

  ProgressHabit? firstHabitInCategories(List<String> cats) {
    final active = activeHabits(limit: 999);
    for (final c in cats) {
      for (final h in active) {
        if (h.category == c) return h;
      }
    }
    return null;
  }

  bool isDone(String habitId, DateTime day, {int targetCount = 1}) {
    final c = state.checkinsByKey[_key(habitId, day)];
    if (c == null) return false;
    return c.doneCount >= (targetCount <= 0 ? 1 : targetCount);
  }

  Future<void> toggleHabitDay({
    required String habitId,
    required DateTime day,
    required int targetCount,
  }) async {
    final d = _dateOnly(day);
    final k = _key(habitId, d);
    final wasDone = state.checkinsByKey.containsKey(k);

    // optimistic
    final next = Map<String, ProgressCheckin>.from(state.checkinsByKey);
    if (wasDone) {
      next.remove(k);
    } else {
      next[k] = ProgressCheckin(
        id: 'optimistic',
        userId: 'me',
        habitId: habitId,
        day: d,
        doneCount: targetCount <= 0 ? 1 : targetCount,
        note: null,
        createdAt: DateTime.now(),
      );
    }
    state = state.copyWith(checkinsByKey: next, error: null);

    try {
      final repo = _ref.read(progressCheckinsRepositoryProvider);
      if (wasDone) {
        await repo.delete(habitId: habitId, day: d);
      } else {
        final saved = await repo.upsert(habitId: habitId, day: d, doneCount: targetCount <= 0 ? 1 : targetCount);
        final fixed = Map<String, ProgressCheckin>.from(state.checkinsByKey);
        fixed[k] = saved;
        state = state.copyWith(checkinsByKey: fixed);
      }
    } on ProgressSchemaMissingException catch (e) {
      // revert + show inline warning (no snackbar error)
      final reverted = Map<String, ProgressCheckin>.from(state.checkinsByKey);
      if (wasDone) {
        reverted[k] = ProgressCheckin(
          id: 'reverted',
          userId: 'me',
          habitId: habitId,
          day: d,
          doneCount: targetCount <= 0 ? 1 : targetCount,
          note: null,
          createdAt: DateTime.now(),
        );
      } else {
        reverted.remove(k);
      }
      state = state.copyWith(
        checkinsByKey: reverted,
        schemaWarning: 'Нужно применить миграцию: таблица ${e.table} отсутствует.',
        error: null,
      );
    } catch (e) {
      // revert on failure
      final reverted = Map<String, ProgressCheckin>.from(state.checkinsByKey);
      if (wasDone) {
        reverted[k] = ProgressCheckin(
          id: 'reverted',
          userId: 'me',
          habitId: habitId,
          day: d,
          doneCount: targetCount <= 0 ? 1 : targetCount,
          note: null,
          createdAt: DateTime.now(),
        );
      } else {
        reverted.remove(k);
      }
      state = state.copyWith(checkinsByKey: reverted, error: e.toString());
    }
  }

  ({int done, int total, double percent}) completionForDay(DateTime day) {
    final habits = activeHabits();
    final total = habits.length;
    if (total == 0) return (done: 0, total: 0, percent: 0);
    final d = _dateOnly(day);
    var done = 0;
    for (final h in habits) {
      if (isDone(h.id, d, targetCount: h.targetCount)) done++;
    }
    return (done: done, total: total, percent: done / total);
  }

  ({int doneCells, int totalCells, double percent}) completionForRange(DateTime start, DateTime end) {
    final habits = activeHabits();
    final days = _daysInRange(start, end);
    final totalCells = habits.length * days.length;
    if (totalCells == 0) return (doneCells: 0, totalCells: 0, percent: 0);
    var doneCells = 0;
    for (final d in days) {
      for (final h in habits) {
        if (isDone(h.id, d, targetCount: h.targetCount)) doneCells++;
      }
    }
    return (doneCells: doneCells, totalCells: totalCells, percent: doneCells / totalCells);
  }

  int streak({double threshold = 0.6, int maxLookbackDays = 366}) {
    final today = _dateOnly(DateTime.now());
    var count = 0;
    for (var i = 0; i < maxLookbackDays; i++) {
      final day = today.subtract(Duration(days: i));
      final c = completionForDay(day);
      if (c.total == 0) return 0;
      if (c.percent + 1e-9 >= threshold) {
        count++;
      } else {
        break;
      }
    }
    return count;
  }

  Future<void> saveTodayNote({int? mood, String? win, String? blocker}) async {
    try {
      final repo = _ref.read(progressDailyNotesRepositoryProvider);
      final saved = await repo.upsert(day: DateTime.now(), mood: mood, win: win, blocker: blocker);
      state = state.copyWith(todayNote: saved, error: null);
    } on ProgressSchemaMissingException catch (e) {
      state = state.copyWith(
        schemaWarning: 'Нужно применить миграцию: таблица ${e.table} отсутствует.',
        error: null,
      );
    } catch (e) {
      state = state.copyWith(error: e.toString());
    }
  }

  static (DateTime, DateTime) _rangeFor(ProgressViewMode mode, DateTime anchor) {
    final a = _dateOnly(anchor);
    if (mode == ProgressViewMode.week) {
      final start = a.subtract(const Duration(days: 6));
      return (_dateOnly(start), a);
    }
    final start = DateTime(a.year, a.month, 1);
    final end = DateTime(a.year, a.month + 1, 0);
    return (_dateOnly(start), _dateOnly(end));
  }

  static List<DateTime> _daysInRange(DateTime start, DateTime end) {
    final s = _dateOnly(start);
    final e = _dateOnly(end);
    final out = <DateTime>[];
    for (var d = s; !d.isAfter(e); d = d.add(const Duration(days: 1))) {
      out.add(d);
    }
    return out;
  }

  static String _key(String habitId, DateTime day) => '$habitId|${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';

  static DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  static Set<String> _categoriesForOsMode(ArtistOsMode mode) => switch (mode) {
        ArtistOsMode.growth => {'content', 'growth'},
        ArtistOsMode.release => {'music', 'content', 'growth', 'admin'},
        ArtistOsMode.system => {'admin', 'health'},
      };

  Future<void> applyPreset(ProgressPreset preset) async {
    final presetHabits = switch (preset) {
      ProgressPreset.growthReels => const [
          (title: 'Reels', category: 'content', targetType: 'daily', targetCount: 1),
          (title: 'Stories', category: 'content', targetType: 'daily', targetCount: 1),
          (title: 'Outreach', category: 'growth', targetType: 'daily', targetCount: 1),
          (title: 'Analytics 5 мин', category: 'growth', targetType: 'daily', targetCount: 1),
        ],
      ProgressPreset.release14Days => const [
          (title: 'Teaser', category: 'content', targetType: 'daily', targetCount: 1),
          (title: 'Pitch', category: 'growth', targetType: 'daily', targetCount: 1),
          (title: 'Reels', category: 'content', targetType: 'daily', targetCount: 1),
          (title: 'Pre-save', category: 'admin', targetType: 'weekly', targetCount: 1),
        ],
      ProgressPreset.trackPerWeek => const [
          (title: 'Studio 60 мин', category: 'music', targetType: 'daily', targetCount: 1),
          (title: 'Lyrics 8 строк', category: 'music', targetType: 'daily', targetCount: 1),
          (title: 'Demo', category: 'music', targetType: 'weekly', targetCount: 1),
        ],
    };

    final nextMode = switch (preset) {
      ProgressPreset.growthReels => ArtistOsMode.growth,
      ProgressPreset.release14Days => ArtistOsMode.release,
      ProgressPreset.trackPerWeek => ArtistOsMode.release,
    };

    final repo = _ref.read(progressHabitsRepositoryProvider);
    final existing = await repo.getHabits(activeOnly: false);
    final existingTitles = existing.map((h) => h.title.trim().toLowerCase()).toSet();
    final maxOrder = existing.isEmpty ? -1 : existing.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b);

    var order = maxOrder + 1;
    for (final h in presetHabits) {
      final t = h.title.trim().toLowerCase();
      if (existingTitles.contains(t)) continue;
      await repo.createHabit(
        title: h.title,
        category: h.category,
        targetType: h.targetType,
        targetCount: h.targetCount,
        sortOrder: order,
      );
      order++;
    }

    state = state.copyWith(osMode: nextMode);
    await load();
  }
}

