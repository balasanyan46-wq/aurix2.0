import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/progress/presentation/progress_controller.dart';

class ProgressHomeScreen extends ConsumerWidget {
  const ProgressHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressControllerProvider);
    final ctrl = ref.read(progressControllerProvider.notifier);
    final pad = horizontalPadding(context);

    ref.listen(progressControllerProvider, (prev, next) {
      if (prev?.error != next.error && next.error != null && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(next.error!)));
      }
    });

    final today = DateTime.now();
    final todayComp = ctrl.completionForDay(today);
    final range = _rangeFor(state.mode, state.anchorDay);
    final rangeComp = ctrl.completionForRange(range.$1, range.$2);
    final streak = ctrl.streak();
    final hasAny = state.habits.where((h) => h.isActive).isNotEmpty;

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Header(
            mode: state.mode,
            osMode: state.osMode,
            anchorDay: state.anchorDay,
            onModeChanged: ctrl.setMode,
            onOsModeChanged: ctrl.setOsMode,
            onPrev: () => ctrl.setAnchorDay(_prevAnchor(state.mode, state.anchorDay)),
            onNext: () => ctrl.setAnchorDay(_nextAnchor(state.mode, state.anchorDay)),
            onManageHabits: () => context.push('/progress/manage'),
          ),
          const SizedBox(height: 16),
          AurixGlassCard(
            padding: const EdgeInsets.all(18),
            child: LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 520;
                return Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (state.schemaWarning != null)
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: Colors.amber.withValues(alpha: 0.35)),
                        ),
                        child: Text(
                          state.schemaWarning!,
                          style: TextStyle(color: Colors.amber.shade200, fontSize: 12, fontWeight: FontWeight.w600),
                        ),
                      ),
                    _Ring(
                      percent: todayComp.percent,
                      title: L10n.t(context, 'progressToday'),
                      subtitle: '${todayComp.done}/${todayComp.total}',
                      size: narrow ? 84 : 92,
                    ),
                    _Ring(
                      percent: rangeComp.percent,
                      title: state.mode == ProgressViewMode.week ? L10n.t(context, 'progressWeek') : L10n.t(context, 'progressMonth'),
                      subtitle: '${(rangeComp.percent * 100).round()}%',
                      size: narrow ? 84 : 92,
                    ),
                    _StreakChip(streak: streak),
                    OutlinedButton.icon(
                      onPressed: () => _openTodayNote(context, ref),
                      icon: const Icon(Icons.edit_note_rounded, size: 18),
                      label: Text(L10n.t(context, 'progressNote')),
                      style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                    ),
                    SizedBox(
                      width: double.infinity,
                      child: Text(
                        L10n.t(context, 'progressTagline'),
                        style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _TodayModeCard(
            onPickPreset: () => _openPresetPicker(context, ref),
          ),
          if (!hasAny) ...[
            const SizedBox(height: 16),
            _PickModeEmptyState(onPickPreset: () => _openPresetPicker(context, ref)),
          ] else ...[
            const SizedBox(height: 16),
            _GridCard(mode: state.mode),
            const SizedBox(height: 16),
            AurixButton(
              text: L10n.t(context, 'progressAddHabit'),
              icon: Icons.add_rounded,
              onPressed: () => _openPresetPicker(context, ref),
            ),
          ],
          if (state.loading) ...[
            const SizedBox(height: 16),
            const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
          ],
        ],
      ),
    );
  }

  static void _openPresetPicker(BuildContext context, WidgetRef ref) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AurixTokens.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _PresetPickerSheet(
        onPick: (preset) async {
          await ref.read(progressControllerProvider.notifier).applyPreset(preset);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
        onCustom: () {
          Navigator.of(ctx).pop();
          if (context.mounted) context.push('/progress/manage?new=1');
        },
      ),
    );
  }

  static void _openTodayNote(BuildContext context, WidgetRef ref) {
    final state = ref.read(progressControllerProvider);
    final ctrl = ref.read(progressControllerProvider.notifier);
    final note = state.todayNote;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AurixTokens.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _TodayNoteSheet(
        initialMood: note?.mood,
        initialWin: note?.win ?? '',
        initialBlocker: note?.blocker ?? '',
        onSave: (mood, win, blocker) async {
          await ctrl.saveTodayNote(mood: mood, win: win, blocker: blocker);
          if (ctx.mounted) Navigator.of(ctx).pop();
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.mode,
    required this.osMode,
    required this.anchorDay,
    required this.onModeChanged,
    required this.onOsModeChanged,
    required this.onPrev,
    required this.onNext,
    required this.onManageHabits,
  });

  final ProgressViewMode mode;
  final ArtistOsMode osMode;
  final DateTime anchorDay;
  final void Function(ProgressViewMode mode) onModeChanged;
  final void Function(ArtistOsMode mode) onOsModeChanged;
  final VoidCallback onPrev;
  final VoidCallback onNext;
  final VoidCallback onManageHabits;

  @override
  Widget build(BuildContext context) {
    final monthFmt = DateFormat('LLLL yyyy', L10nScope.of(context) == AppLocale.ru ? 'ru' : 'en');
    final title = mode == ProgressViewMode.week
        ? '${L10n.t(context, 'progressWeek')} · ${DateFormat('d MMM', L10nScope.of(context) == AppLocale.ru ? 'ru' : 'en').format(anchorDay)}'
        : monthFmt.format(anchorDay);

    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 520;
        return Wrap(
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          runSpacing: 12,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  L10n.t(context, 'progressTitle'),
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(title, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _ModePill(
                  mode: mode,
                  onChanged: onModeChanged,
                ),
                _OsModePill(
                  mode: osMode,
                  onChanged: onOsModeChanged,
                ),
                IconButton(
                  onPressed: onPrev,
                  tooltip: L10n.t(context, 'back'),
                  icon: const Icon(Icons.chevron_left_rounded),
                  visualDensity: VisualDensity.compact,
                  color: AurixTokens.muted,
                ),
                IconButton(
                  onPressed: onNext,
                  tooltip: L10n.t(context, 'next'),
                  icon: const Icon(Icons.chevron_right_rounded),
                  visualDensity: VisualDensity.compact,
                  color: AurixTokens.muted,
                ),
                if (!narrow)
                  OutlinedButton.icon(
                    onPressed: onManageHabits,
                    icon: const Icon(Icons.tune_rounded, size: 18),
                    label: Text(L10n.t(context, 'progressManage')),
                    style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                  )
                else
                  IconButton(
                    onPressed: onManageHabits,
                    tooltip: L10n.t(context, 'progressManage'),
                    icon: const Icon(Icons.tune_rounded),
                    visualDensity: VisualDensity.compact,
                    color: AurixTokens.orange,
                  ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({required this.mode, required this.onChanged});

  final ProgressViewMode mode;
  final void Function(ProgressViewMode mode) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(L10n.t(context, 'progressModeMonth')),
          selected: mode == ProgressViewMode.month,
          onSelected: (_) => onChanged(ProgressViewMode.month),
          selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            color: mode == ProgressViewMode.month ? AurixTokens.orange : AurixTokens.muted,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: AurixTokens.orange.withValues(alpha: mode == ProgressViewMode.month ? 0.45 : 0.25)),
          backgroundColor: AurixTokens.glass(0.06),
        ),
        ChoiceChip(
          label: Text(L10n.t(context, 'progressModeWeek')),
          selected: mode == ProgressViewMode.week,
          onSelected: (_) => onChanged(ProgressViewMode.week),
          selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
          labelStyle: TextStyle(
            color: mode == ProgressViewMode.week ? AurixTokens.orange : AurixTokens.muted,
            fontWeight: FontWeight.w600,
          ),
          side: BorderSide(color: AurixTokens.orange.withValues(alpha: mode == ProgressViewMode.week ? 0.45 : 0.25)),
          backgroundColor: AurixTokens.glass(0.06),
        ),
      ],
    );
  }
}

class _OsModePill extends StatelessWidget {
  const _OsModePill({required this.mode, required this.onChanged});

  final ArtistOsMode mode;
  final void Function(ArtistOsMode mode) onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      children: [
        ChoiceChip(
          label: Text(L10n.t(context, 'osModeGrowth')),
          selected: mode == ArtistOsMode.growth,
          onSelected: (_) => onChanged(ArtistOsMode.growth),
          selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
          labelStyle: TextStyle(color: mode == ArtistOsMode.growth ? AurixTokens.orange : AurixTokens.muted, fontWeight: FontWeight.w700),
          side: BorderSide(color: AurixTokens.orange.withValues(alpha: mode == ArtistOsMode.growth ? 0.45 : 0.25)),
          backgroundColor: AurixTokens.glass(0.06),
        ),
        ChoiceChip(
          label: Text(L10n.t(context, 'osModeRelease')),
          selected: mode == ArtistOsMode.release,
          onSelected: (_) => onChanged(ArtistOsMode.release),
          selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
          labelStyle: TextStyle(color: mode == ArtistOsMode.release ? AurixTokens.orange : AurixTokens.muted, fontWeight: FontWeight.w700),
          side: BorderSide(color: AurixTokens.orange.withValues(alpha: mode == ArtistOsMode.release ? 0.45 : 0.25)),
          backgroundColor: AurixTokens.glass(0.06),
        ),
        ChoiceChip(
          label: Text(L10n.t(context, 'osModeSystem')),
          selected: mode == ArtistOsMode.system,
          onSelected: (_) => onChanged(ArtistOsMode.system),
          selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
          labelStyle: TextStyle(color: mode == ArtistOsMode.system ? AurixTokens.orange : AurixTokens.muted, fontWeight: FontWeight.w700),
          side: BorderSide(color: AurixTokens.orange.withValues(alpha: mode == ArtistOsMode.system ? 0.45 : 0.25)),
          backgroundColor: AurixTokens.glass(0.06),
        ),
      ],
    );
  }
}

class _Ring extends StatelessWidget {
  const _Ring({
    required this.percent,
    required this.title,
    required this.subtitle,
    required this.size,
  });

  final double percent;
  final String title;
  final String subtitle;
  final double size;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.isFinite ? percent.clamp(0.0, 1.0) : 0.0;
    return SizedBox(
      width: size + 140,
      child: Row(
        children: [
          SizedBox(
            width: size,
            height: size,
            child: Stack(
              alignment: Alignment.center,
              children: [
                CircularProgressIndicator(
                  value: clamped,
                  strokeWidth: 6,
                  backgroundColor: AurixTokens.glass(0.12),
                  valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
                ),
                Text('${(clamped * 100).round()}%', style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(title, style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5)),
                const SizedBox(height: 4),
                Text(subtitle, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w800)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    final label = '${L10n.t(context, 'progressStreak')}: $streak';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.orange.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.35)),
      ),
      child: Text(label, style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700, fontSize: 12)),
    );
  }
}

class _TodayModeCard extends ConsumerWidget {
  const _TodayModeCard({required this.onPickPreset});
  final VoidCallback onPickPreset;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressControllerProvider);
    final ctrl = ref.read(progressControllerProvider.notifier);

    final hasAny = state.habits.where((h) => h.isActive).isNotEmpty;

    final growth = ctrl.firstHabitInCategories(const ['growth', 'content']);
    final music = ctrl.firstHabitInCategories(const ['music']);
    final system = ctrl.firstHabitInCategories(const ['admin', 'health']);

    return AurixGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.t(context, 'osTodayTitle'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(L10n.t(context, 'osTodaySubtitle'), style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
          const SizedBox(height: 14),
          if (!hasAny) ...[
            _OsStepTile.placeholder(title: L10n.t(context, 'osExampleGrowth'), subtitle: L10n.t(context, 'osCatGrowth')),
            const SizedBox(height: 10),
            _OsStepTile.placeholder(title: L10n.t(context, 'osExampleMusic'), subtitle: L10n.t(context, 'osCatMusic')),
            const SizedBox(height: 10),
            _OsStepTile.placeholder(title: L10n.t(context, 'osExampleSystem'), subtitle: L10n.t(context, 'osCatAdmin')),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: onPickPreset,
                icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                label: Text(L10n.t(context, 'osPickPreset')),
                style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
              ),
            ),
          ] else ...[
            _OsStepTile(
              title: growth?.title ?? L10n.t(context, 'osMissingGrowth'),
              subtitle: _categorySubtitle(context, growth?.category ?? 'growth'),
              done: growth != null ? ctrl.isDone(growth.id, DateTime.now(), targetCount: growth.targetCount) : false,
              onToggle: growth == null ? null : () => ctrl.toggleHabitDay(habitId: growth.id, day: DateTime.now(), targetCount: growth.targetCount),
            ),
            const SizedBox(height: 10),
            _OsStepTile(
              title: music?.title ?? L10n.t(context, 'osMissingMusic'),
              subtitle: _categorySubtitle(context, music?.category ?? 'music'),
              done: music != null ? ctrl.isDone(music.id, DateTime.now(), targetCount: music.targetCount) : false,
              onToggle: music == null ? null : () => ctrl.toggleHabitDay(habitId: music.id, day: DateTime.now(), targetCount: music.targetCount),
            ),
            const SizedBox(height: 10),
            _OsStepTile(
              title: system?.title ?? L10n.t(context, 'osMissingSystem'),
              subtitle: _categorySubtitle(context, system?.category ?? 'admin'),
              done: system != null ? ctrl.isDone(system.id, DateTime.now(), targetCount: system.targetCount) : false,
              onToggle: system == null ? null : () => ctrl.toggleHabitDay(habitId: system.id, day: DateTime.now(), targetCount: system.targetCount),
            ),
          ],
        ],
      ),
    );
  }
}

class _OsStepTile extends StatelessWidget {
  const _OsStepTile({
    required this.title,
    required this.subtitle,
    required this.done,
    required this.onToggle,
  });

  final String title;
  final String subtitle;
  final bool done;
  final VoidCallback? onToggle;

  factory _OsStepTile.placeholder({required String title, required String subtitle}) {
    return _OsStepTile(title: title, subtitle: subtitle, done: false, onToggle: null);
  }

  @override
  Widget build(BuildContext context) {
    final disabled = onToggle == null;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: disabled ? AurixTokens.muted : AurixTokens.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(subtitle, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          IconButton(
            onPressed: disabled ? null : onToggle,
            icon: Icon(done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded),
            color: disabled ? AurixTokens.muted.withValues(alpha: 0.5) : (done ? AurixTokens.orange : AurixTokens.muted),
            tooltip: done ? L10n.t(context, 'osDone') : L10n.t(context, 'osDo'),
          ),
        ],
      ),
    );
  }
}

class _PickModeEmptyState extends StatelessWidget {
  const _PickModeEmptyState({required this.onPickPreset});
  final VoidCallback onPickPreset;

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            L10n.t(context, 'osPickPreset'),
            style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          _PresetCard(
            title: L10n.t(context, 'presetGrowthReelsTitle'),
            desc: L10n.t(context, 'presetGrowthReelsDesc'),
            onTap: onPickPreset,
          ),
          const SizedBox(height: 10),
          _PresetCard(
            title: L10n.t(context, 'presetRelease14Title'),
            desc: L10n.t(context, 'presetRelease14Desc'),
            onTap: onPickPreset,
          ),
          const SizedBox(height: 10),
          _PresetCard(
            title: L10n.t(context, 'presetTrackWeekTitle'),
            desc: L10n.t(context, 'presetTrackWeekDesc'),
            onTap: onPickPreset,
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onPickPreset,
              icon: const Icon(Icons.auto_awesome_rounded, size: 18),
              label: Text(L10n.t(context, 'osPresetsTitle')),
              style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
            ),
          ),
        ],
      ),
    );
  }
}

class _PresetCard extends StatelessWidget {
  const _PresetCard({required this.title, required this.desc, required this.onTap});
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurixTokens.border.withValues(alpha: 0.7)),
        ),
        child: Row(
          children: [
            Icon(Icons.auto_awesome_rounded, color: AurixTokens.orange.withValues(alpha: 0.9)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(desc, style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            const Icon(Icons.chevron_right_rounded, color: AurixTokens.muted),
          ],
        ),
      ),
    );
  }
}

class _GridCard extends ConsumerWidget {
  const _GridCard({required this.mode});
  final ProgressViewMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressControllerProvider);
    final ctrl = ref.read(progressControllerProvider.notifier);

    final habits = ctrl.habitsForOsMode();
    final days = ctrl.visibleDays();
    final tooMany = state.habits.where((h) => h.isActive).length > habits.length;
    final range = _rangeFor(mode, state.anchorDay);
    final rangeComp = ctrl.completionForRange(range.$1, range.$2);

    return AurixGlassCard(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(L10n.t(context, 'progressGridTitle'), style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              if (mode == ProgressViewMode.month)
                Text('${days.length} ${L10n.t(context, 'progressDays')}', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            _osModeHint(context, state.osMode),
            style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12),
          ),
          const SizedBox(height: 10),
          _RangeProgressBar(
            label: mode == ProgressViewMode.week ? L10n.t(context, 'progressWeek') : L10n.t(context, 'progressMonth'),
            percent: rangeComp.percent,
          ),
          if (tooMany) ...[
            const SizedBox(height: 8),
            Text(
              L10n.t(context, 'progressHabitLimit'),
              style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.9), fontSize: 12),
            ),
          ],
          const SizedBox(height: 12),
          if (habits.isEmpty)
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: AurixTokens.glass(0.06), borderRadius: BorderRadius.circular(12)),
              child: Text(L10n.t(context, 'progressEmpty'), style: const TextStyle(color: AurixTokens.muted)),
            )
          else
            LayoutBuilder(
              builder: (context, c) {
                final narrow = c.maxWidth < 520;
                final titleW = narrow ? 140.0 : 180.0;
                final cell = narrow ? 32.0 : 36.0;
                final headerH = narrow ? 34.0 : 38.0;
                final rowH = narrow ? 46.0 : 50.0;
                final heatH = 10.0;
                final dayPercents = days.map((d) => ctrl.completionForDay(d).percent).toList();

                // Sticky left column (titles) + horizontally scrollable day grid.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: titleW,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            height: headerH,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: Text(
                                L10n.t(context, 'progressHabits'),
                                style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.5),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ...habits.map((h) => SizedBox(
                                height: rowH,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        h.title,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _categorySubtitle(context, h.category),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 11),
                                      ),
                                    ],
                                  ),
                                ),
                              )),
                        ],
                      ),
                    ),
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _DaysHeader(days: days, cellSize: cell, height: headerH),
                            const SizedBox(height: 6),
                            _DayHeatRow(
                              dayPercents: dayPercents,
                              cellSize: cell,
                              height: heatH,
                            ),
                            const SizedBox(height: 8),
                            ...habits.map((h) => _CellsRow(
                                  habitId: h.id,
                                  targetCount: h.targetCount,
                                  days: days,
                                  cellSize: cell,
                                  height: rowH,
                                  onToggle: (d) => ctrl.toggleHabitDay(habitId: h.id, day: d, targetCount: h.targetCount),
                                )),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
        ],
      ),
    );
  }
}

class _DaysHeader extends StatelessWidget {
  const _DaysHeader({required this.days, required this.cellSize, required this.height});
  final List<DateTime> days;
  final double cellSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    final dowFmt = DateFormat('E', L10nScope.of(context) == AppLocale.ru ? 'ru' : 'en');
    return SizedBox(
      height: height,
      child: Row(
        children: [
          ...days.map((d) {
            return SizedBox(
              width: cellSize,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('${d.day}', style: const TextStyle(color: AurixTokens.text, fontSize: 11, fontWeight: FontWeight.w700)),
                  Text(dowFmt.format(d), style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.85), fontSize: 9)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _DayHeatRow extends StatelessWidget {
  const _DayHeatRow({
    required this.dayPercents,
    required this.cellSize,
    required this.height,
  });

  final List<double> dayPercents;
  final double cellSize;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: Row(
        children: [
          ...dayPercents.map((p) {
            final clamped = p.isFinite ? p.clamp(0.0, 1.0) : 0.0;
            final alpha = (0.08 + 0.28 * clamped).clamp(0.0, 0.36);
            return SizedBox(
              width: cellSize,
              height: height,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 3),
                child: Container(
                  decoration: BoxDecoration(
                    color: AurixTokens.orange.withValues(alpha: alpha),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: AurixTokens.orange.withValues(alpha: alpha + 0.10)),
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RangeProgressBar extends StatelessWidget {
  const _RangeProgressBar({required this.label, required this.percent});
  final String label;
  final double percent;

  @override
  Widget build(BuildContext context) {
    final clamped = percent.isFinite ? percent.clamp(0.0, 1.0) : 0.0;
    return Row(
      children: [
        Text(
          '$label:',
          style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.9), fontSize: 12, fontWeight: FontWeight.w700),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: LinearProgressIndicator(
              value: clamped,
              minHeight: 8,
              backgroundColor: AurixTokens.glass(0.12),
              valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          '${(clamped * 100).round()}%',
          style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w800),
        ),
      ],
    );
  }
}

class _CellsRow extends ConsumerWidget {
  const _CellsRow({
    required this.habitId,
    required this.targetCount,
    required this.days,
    required this.cellSize,
    required this.height,
    required this.onToggle,
  });

  final String habitId;
  final int targetCount;
  final List<DateTime> days;
  final double cellSize;
  final double height;
  final void Function(DateTime day) onToggle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(progressControllerProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: SizedBox(
        height: height,
        child: Row(
          children: [
            ...days.map((d) {
              final k = '$habitId|${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
              final done = state.checkinsByKey.containsKey(k);
              return SizedBox(
                width: cellSize,
                height: height,
                child: Padding(
                  padding: const EdgeInsets.all(3),
                  child: InkWell(
                    onTap: () => onToggle(d),
                    borderRadius: BorderRadius.circular(8),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 120),
                      decoration: BoxDecoration(
                        color: done ? AurixTokens.orange.withValues(alpha: 0.18) : AurixTokens.glass(0.06),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: done ? AurixTokens.orange.withValues(alpha: 0.55) : AurixTokens.border.withValues(alpha: 0.65),
                        ),
                      ),
                      child: done
                          ? const Icon(Icons.check_rounded, size: 16, color: AurixTokens.orange)
                          : const SizedBox.shrink(),
                    ),
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _Preset {
  final ProgressPreset key;
  final String titleKey;
  final String descKey;
  final ArtistOsMode mode;
  final List<({String title, String category, String targetType, int targetCount})> habits;
  const _Preset({
    required this.key,
    required this.titleKey,
    required this.descKey,
    required this.mode,
    required this.habits,
  });
}

class _PresetPickerSheet extends StatelessWidget {
  const _PresetPickerSheet({required this.onPick, required this.onCustom});
  final Future<void> Function(ProgressPreset key) onPick;
  final VoidCallback onCustom;

  static const presets = <_Preset>[
    _Preset(
      key: ProgressPreset.growthReels,
      titleKey: 'presetGrowthReelsTitle',
      descKey: 'presetGrowthReelsDesc',
      mode: ArtistOsMode.growth,
      habits: [
        (title: 'Reels', category: 'content', targetType: 'daily', targetCount: 1),
        (title: 'Stories', category: 'content', targetType: 'daily', targetCount: 1),
        (title: 'Outreach', category: 'growth', targetType: 'daily', targetCount: 1),
        (title: 'Analytics 5 мин', category: 'growth', targetType: 'daily', targetCount: 1),
      ],
    ),
    _Preset(
      key: ProgressPreset.release14Days,
      titleKey: 'presetRelease14Title',
      descKey: 'presetRelease14Desc',
      mode: ArtistOsMode.release,
      habits: [
        (title: 'Teaser', category: 'content', targetType: 'daily', targetCount: 1),
        (title: 'Pitch', category: 'growth', targetType: 'daily', targetCount: 1),
        (title: 'Reels', category: 'content', targetType: 'daily', targetCount: 1),
        (title: 'Pre-save', category: 'admin', targetType: 'weekly', targetCount: 1),
      ],
    ),
    _Preset(
      key: ProgressPreset.trackPerWeek,
      titleKey: 'presetTrackWeekTitle',
      descKey: 'presetTrackWeekDesc',
      mode: ArtistOsMode.release,
      habits: [
        (title: 'Studio 60 мин', category: 'music', targetType: 'daily', targetCount: 1),
        (title: 'Lyrics 8 строк', category: 'music', targetType: 'daily', targetCount: 1),
        (title: 'Demo', category: 'music', targetType: 'weekly', targetCount: 1),
      ],
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);
    final inset = MediaQuery.viewInsetsOf(context);
    return Padding(
      padding: EdgeInsets.only(left: pad, right: pad, top: 16, bottom: 16 + inset.bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(L10n.t(context, 'osPresetsTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AurixTokens.muted,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(L10n.t(context, 'osPresetsSubtitle'), style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
          const SizedBox(height: 14),
          ...presets.map((p) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: InkWell(
                  onTap: () => onPick(p.key),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AurixTokens.glass(0.06),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AurixTokens.border.withValues(alpha: 0.7)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.auto_awesome_rounded, color: AurixTokens.orange.withValues(alpha: 0.9)),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L10n.t(context, p.titleKey), style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800)),
                              const SizedBox(height: 2),
                              Text(L10n.t(context, p.descKey), style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        const Icon(Icons.chevron_right_rounded, color: AurixTokens.muted),
                      ],
                    ),
                  ),
                ),
              )),
          const SizedBox(height: 6),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: onCustom,
              icon: const Icon(Icons.add_rounded, size: 18),
              label: Text(L10n.t(context, 'osCustomStep')),
              style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
            ),
          ),
        ],
      ),
    );
  }
}

String _categorySubtitle(BuildContext context, String category) => switch (category) {
      'content' => L10n.t(context, 'osCatContent'),
      'music' => L10n.t(context, 'osCatMusic'),
      'growth' => L10n.t(context, 'osCatGrowth'),
      'admin' => L10n.t(context, 'osCatAdmin'),
      'health' => L10n.t(context, 'osCatHealth'),
      _ => category,
    };

String _osModeHint(BuildContext context, ArtistOsMode mode) => switch (mode) {
      ArtistOsMode.growth => '${L10n.t(context, 'osModeGrowth')}: ${L10n.t(context, 'osCatContent')} · ${L10n.t(context, 'osCatGrowth')}',
      ArtistOsMode.release => '${L10n.t(context, 'osModeRelease')}: ${L10n.t(context, 'osCatMusic')} · ${L10n.t(context, 'osCatContent')} · ${L10n.t(context, 'osCatAdmin')}',
      ArtistOsMode.system => '${L10n.t(context, 'osModeSystem')}: ${L10n.t(context, 'osCatAdmin')} · ${L10n.t(context, 'osCatHealth')}',
    };

class _TodayNoteSheet extends StatefulWidget {
  const _TodayNoteSheet({
    required this.initialMood,
    required this.initialWin,
    required this.initialBlocker,
    required this.onSave,
  });

  final int? initialMood;
  final String initialWin;
  final String initialBlocker;
  final Future<void> Function(int? mood, String win, String blocker) onSave;

  @override
  State<_TodayNoteSheet> createState() => _TodayNoteSheetState();
}

class _TodayNoteSheetState extends State<_TodayNoteSheet> {
  late final TextEditingController _win = TextEditingController(text: widget.initialWin);
  late final TextEditingController _blocker = TextEditingController(text: widget.initialBlocker);
  int? _mood;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _mood = widget.initialMood;
  }

  @override
  void dispose() {
    _win.dispose();
    _blocker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final pad = horizontalPadding(context);
    return Padding(
      padding: EdgeInsets.only(
        left: pad,
        right: pad,
        top: 16,
        bottom: 16 + viewInsets.bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(L10n.t(context, 'progressTodayNoteTitle'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
              const Spacer(),
              IconButton(
                onPressed: _saving ? null : () => Navigator.of(context).pop(),
                icon: const Icon(Icons.close_rounded),
                color: AurixTokens.muted,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(L10n.t(context, 'progressMood'), style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: List.generate(5, (i) {
              final v = i + 1;
              final selected = _mood == v;
              return ChoiceChip(
                label: Text('$v'),
                selected: selected,
                onSelected: (_) => setState(() => _mood = selected ? null : v),
                selectedColor: AurixTokens.orange.withValues(alpha: 0.18),
                backgroundColor: AurixTokens.glass(0.06),
                side: BorderSide(color: AurixTokens.orange.withValues(alpha: selected ? 0.45 : 0.25)),
                labelStyle: TextStyle(color: selected ? AurixTokens.orange : AurixTokens.muted, fontWeight: FontWeight.w700),
              );
            }),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _win,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: L10n.t(context, 'progressWin'),
              filled: true,
              fillColor: AurixTokens.glass(0.06),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _blocker,
            maxLines: 1,
            decoration: InputDecoration(
              labelText: L10n.t(context, 'progressBlocker'),
              filled: true,
              fillColor: AurixTokens.glass(0.06),
            ),
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: _saving
                  ? null
                  : () async {
                      setState(() => _saving = true);
                      try {
                        await widget.onSave(_mood, _win.text.trim(), _blocker.text.trim());
                      } finally {
                        if (mounted) setState(() => _saving = false);
                      }
                    },
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(_saving ? L10n.t(context, 'progressSaving') : L10n.t(context, 'progressSave')),
              style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
            ),
          ),
        ],
      ),
    );
  }
}

DateTime _prevAnchor(ProgressViewMode mode, DateTime anchor) {
  if (mode == ProgressViewMode.week) return anchor.subtract(const Duration(days: 7));
  return DateTime(anchor.year, anchor.month - 1, 1);
}

DateTime _nextAnchor(ProgressViewMode mode, DateTime anchor) {
  if (mode == ProgressViewMode.week) return anchor.add(const Duration(days: 7));
  return DateTime(anchor.year, anchor.month + 1, 1);
}

(DateTime, DateTime) _rangeFor(ProgressViewMode mode, DateTime anchor) {
  final a = DateTime(anchor.year, anchor.month, anchor.day);
  if (mode == ProgressViewMode.week) {
    final start = a.subtract(const Duration(days: 6));
    return (DateTime(start.year, start.month, start.day), a);
  }
  final start = DateTime(a.year, a.month, 1);
  final end = DateTime(a.year, a.month + 1, 0);
  return (start, end);
}

