import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/progress/data/models/progress_habit.dart';
import 'package:aurix_flutter/features/progress/presentation/progress_controller.dart';

class HabitManageScreen extends ConsumerStatefulWidget {
  const HabitManageScreen({super.key, this.openNewOnStart = false});

  final bool openNewOnStart;

  @override
  ConsumerState<HabitManageScreen> createState() => _HabitManageScreenState();
}

class _HabitManageScreenState extends ConsumerState<HabitManageScreen> {
  bool _loading = false;
  bool _reordering = false;
  bool _handledInitialNew = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (_handledInitialNew) return;
      if (!widget.openNewOnStart) return;
      _handledInitialNew = true;
      await _openEditSheet(context, ref, habit: null);
      if (mounted) context.go('/progress/manage');
    });
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(progressControllerProvider);
    final pad = horizontalPadding(context);
    final habits = List<ProgressHabit>.from(state.habits)..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(pad),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconButton(
                    onPressed: _loading ? null : () => context.pop(),
                    icon: const Icon(Icons.arrow_back_rounded),
                    color: AurixTokens.muted,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      L10n.t(context, 'progressManage'),
                      style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  AurixButton(
                    text: L10n.t(context, 'progressAddHabit'),
                    icon: Icons.add_rounded,
                    onPressed: _loading ? null : () => _openAddSheet(context),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(L10n.t(context, 'progressManageHint'), style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              const SizedBox(height: 16),
              if (_loading) const LinearProgressIndicator(color: AurixTokens.orange, backgroundColor: Colors.transparent),
              const SizedBox(height: 12),
              if (habits.isEmpty)
                AurixGlassCard(
                  padding: const EdgeInsets.all(16),
                  child: Text(L10n.t(context, 'progressEmptyManage'), style: const TextStyle(color: AurixTokens.muted)),
                )
              else
                AurixGlassCard(
                  padding: const EdgeInsets.all(12),
                  child: ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: habits.length,
                    onReorder: _loading ? (_, __) {} : (oldIndex, newIndex) => _onReorder(habits, oldIndex, newIndex),
                    itemBuilder: (ctx, i) {
                      final h = habits[i];
                      return _HabitTile(
                        key: ValueKey('habit_${h.id}'),
                        habit: h,
                        onEdit: () => _openEditSheet(context, ref, habit: h),
                        onToggleActive: (v) => _updateHabit(h.id, isActive: v),
                        onMoveToTop: () => _moveToTop(h),
                        onDelete: () => _deleteHabit(h),
                        dragHandle: ReorderableDragStartListener(
                          index: i,
                          enabled: !_loading,
                          child: Icon(Icons.drag_handle_rounded, color: AurixTokens.muted.withValues(alpha: 0.8)),
                        ),
                      );
                    },
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _persistOrder(List<ProgressHabit> ordered) async {
    final repo = ref.read(progressHabitsRepositoryProvider);
    for (var i = 0; i < ordered.length; i++) {
      final h = ordered[i];
      if (h.sortOrder != i) {
        await repo.updateHabit(h.id, sortOrder: i);
      }
    }
  }

  Future<void> _onReorder(List<ProgressHabit> habits, int oldIndex, int newIndex) async {
    if (_reordering) return;
    setState(() => _reordering = true);
    try {
      if (newIndex > oldIndex) newIndex -= 1;
      final next = List<ProgressHabit>.from(habits);
      final item = next.removeAt(oldIndex);
      next.insert(newIndex, item);

      // Persist sequential order as 0..n (MVP, small N).
      await _persistOrder(next);
      await ref.read(progressControllerProvider.notifier).load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _moveToTop(ProgressHabit habit) async {
    if (_reordering) return;
    setState(() => _reordering = true);
    try {
      final current = List<ProgressHabit>.from(ref.read(progressControllerProvider).habits)
        ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final idx = current.indexWhere((h) => h.id == habit.id);
      if (idx <= 0) return;
      final item = current.removeAt(idx);
      current.insert(0, item);
      await _persistOrder(current);
      await ref.read(progressControllerProvider.notifier).load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _reordering = false);
    }
  }

  Future<void> _updateHabit(
    String id, {
    String? title,
    String? category,
    String? targetType,
    int? targetCount,
    bool? isActive,
  }) async {
    setState(() => _loading = true);
    try {
      await ref.read(progressHabitsRepositoryProvider).updateHabit(
            id,
            title: title,
            category: category,
            targetType: targetType,
            targetCount: targetCount,
            isActive: isActive,
          );
      await ref.read(progressControllerProvider.notifier).load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteHabit(ProgressHabit h) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text(L10n.t(context, 'progressDeleteHabitTitle')),
        content: Text(L10n.t(context, 'progressDeleteHabitConfirm')),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: Text(L10n.t(context, 'back'))),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white),
            child: Text(L10n.t(context, 'progressDelete')),
          ),
        ],
      ),
    );
    if (ok != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(progressHabitsRepositoryProvider).deleteHabit(h.id);
      await ref.read(progressControllerProvider.notifier).load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openEditSheet(BuildContext context, WidgetRef ref, {required ProgressHabit? habit}) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AurixTokens.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) => _HabitEditSheet(
        habit: habit,
        onSave: (data) async {
          setState(() => _loading = true);
          try {
            final repo = ref.read(progressHabitsRepositoryProvider);
            if (habit == null) {
              final current = (ref.read(progressControllerProvider).habits);
              final maxOrder = current.isEmpty ? -1 : current.map((h) => h.sortOrder).reduce((a, b) => a > b ? a : b);
              await repo.createHabit(
                title: data.title,
                category: data.category,
                targetType: data.targetType,
                targetCount: data.targetCount,
                isActive: data.isActive,
                sortOrder: maxOrder + 1,
              );
            } else {
              await repo.updateHabit(
                habit.id,
                title: data.title,
                category: data.category,
                targetType: data.targetType,
                targetCount: data.targetCount,
                isActive: data.isActive,
              );
            }
            await ref.read(progressControllerProvider.notifier).load();
            if (ctx.mounted) Navigator.of(ctx).pop();
          } catch (e) {
            if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: Text('$e')));
          } finally {
            if (mounted) setState(() => _loading = false);
          }
        },
      ),
    );
  }

  void _openAddSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AurixTokens.bg1,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (ctx) {
        final pad = horizontalPadding(context);
        final inset = MediaQuery.viewInsetsOf(ctx);
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
                    onPressed: () => Navigator.of(ctx).pop(),
                    icon: const Icon(Icons.close_rounded),
                    color: AurixTokens.muted,
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(L10n.t(context, 'osPresetsSubtitle'), style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 12)),
              const SizedBox(height: 14),
              _PresetRow(
                title: L10n.t(context, 'presetGrowthReelsTitle'),
                desc: L10n.t(context, 'presetGrowthReelsDesc'),
                onTap: () async {
                  await ref.read(progressControllerProvider.notifier).applyPreset(ProgressPreset.growthReels);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              _PresetRow(
                title: L10n.t(context, 'presetRelease14Title'),
                desc: L10n.t(context, 'presetRelease14Desc'),
                onTap: () async {
                  await ref.read(progressControllerProvider.notifier).applyPreset(ProgressPreset.release14Days);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              _PresetRow(
                title: L10n.t(context, 'presetTrackWeekTitle'),
                desc: L10n.t(context, 'presetTrackWeekDesc'),
                onTap: () async {
                  await ref.read(progressControllerProvider.notifier).applyPreset(ProgressPreset.trackPerWeek);
                  if (ctx.mounted) Navigator.of(ctx).pop();
                },
              ),
              const SizedBox(height: 6),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    Navigator.of(ctx).pop();
                    await _openEditSheet(context, ref, habit: null);
                  },
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: Text(L10n.t(context, 'osCustomStep')),
                  style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _PresetRow extends StatelessWidget {
  const _PresetRow({required this.title, required this.desc, required this.onTap});
  final String title;
  final String desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
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
      ),
    );
  }
}

class _HabitTile extends StatelessWidget {
  const _HabitTile({
    super.key,
    required this.habit,
    required this.onEdit,
    required this.onToggleActive,
    required this.onMoveToTop,
    required this.onDelete,
    required this.dragHandle,
  });

  final ProgressHabit habit;
  final VoidCallback onEdit;
  final ValueChanged<bool> onToggleActive;
  final VoidCallback onMoveToTop;
  final VoidCallback onDelete;
  final Widget dragHandle;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final narrow = c.maxWidth < 520;

        final meta = Text(
          '${habit.category} · ${habit.targetType} · x${habit.targetCount}',
          style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.9), fontSize: 12),
          overflow: TextOverflow.ellipsis,
        );

        final actions = Wrap(
          spacing: 4,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Switch(
              value: habit.isActive,
              onChanged: onToggleActive,
              activeColor: AurixTokens.orange,
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            IconButton(
              onPressed: onMoveToTop,
              icon: const Icon(Icons.vertical_align_top_rounded),
              color: AurixTokens.muted,
              tooltip: L10n.t(context, 'progressToTop'),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onEdit,
              icon: const Icon(Icons.edit_rounded),
              color: AurixTokens.orange,
              tooltip: L10n.t(context, 'progressEdit'),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline_rounded),
              color: Colors.redAccent,
              tooltip: L10n.t(context, 'progressDelete'),
              visualDensity: VisualDensity.compact,
            ),
          ],
        );

        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: narrow
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: dragHandle,
                        ),
                        Expanded(
                          child: Text(
                            habit.title,
                            style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    meta,
                    const SizedBox(height: 6),
                    actions,
                  ],
                )
              : Row(
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: dragHandle,
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(habit.title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700)),
                          const SizedBox(height: 2),
                          meta,
                        ],
                      ),
                    ),
                    actions,
                  ],
                ),
        );
      },
    );
  }
}

class _HabitFormData {
  final String title;
  final String category;
  final String targetType;
  final int targetCount;
  final bool isActive;
  const _HabitFormData({
    required this.title,
    required this.category,
    required this.targetType,
    required this.targetCount,
    required this.isActive,
  });
}

class _HabitEditSheet extends StatefulWidget {
  const _HabitEditSheet({required this.habit, required this.onSave});
  final ProgressHabit? habit;
  final Future<void> Function(_HabitFormData data) onSave;

  @override
  State<_HabitEditSheet> createState() => _HabitEditSheetState();
}

class _HabitEditSheetState extends State<_HabitEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _title = TextEditingController(text: widget.habit?.title ?? '');
  late final TextEditingController _targetCount = TextEditingController(text: (widget.habit?.targetCount ?? 1).toString());
  late String _category = widget.habit?.category ?? 'content';
  late String _targetType = widget.habit?.targetType ?? 'daily';
  late bool _isActive = widget.habit?.isActive ?? true;
  bool _saving = false;

  @override
  void dispose() {
    _title.dispose();
    _targetCount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.viewInsetsOf(context);
    final pad = horizontalPadding(context);
    return Padding(
      padding: EdgeInsets.only(left: pad, right: pad, top: 16, bottom: 16 + viewInsets.bottom),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  widget.habit == null ? L10n.t(context, 'progressAddHabit') : L10n.t(context, 'progressEditHabit'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close_rounded),
                  color: AurixTokens.muted,
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _title,
              decoration: InputDecoration(
                labelText: L10n.t(context, 'progressHabitTitle'),
                filled: true,
                fillColor: AurixTokens.glass(0.06),
              ),
              validator: (v) => (v == null || v.trim().isEmpty) ? L10n.t(context, 'progressRequired') : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _category,
              decoration: InputDecoration(
                labelText: L10n.t(context, 'progressCategory'),
                filled: true,
                fillColor: AurixTokens.glass(0.06),
              ),
              dropdownColor: AurixTokens.bg1,
              items: const [
                DropdownMenuItem(value: 'content', child: Text('content')),
                DropdownMenuItem(value: 'music', child: Text('music')),
                DropdownMenuItem(value: 'growth', child: Text('growth')),
                DropdownMenuItem(value: 'health', child: Text('health')),
                DropdownMenuItem(value: 'admin', child: Text('admin')),
              ],
              onChanged: (v) => setState(() => _category = v ?? 'content'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _targetType,
                    decoration: InputDecoration(
                      labelText: L10n.t(context, 'progressTargetType'),
                      filled: true,
                      fillColor: AurixTokens.glass(0.06),
                    ),
                    dropdownColor: AurixTokens.bg1,
                    items: const [
                      DropdownMenuItem(value: 'daily', child: Text('daily')),
                      DropdownMenuItem(value: 'weekly', child: Text('weekly')),
                    ],
                    onChanged: (v) => setState(() => _targetType = v ?? 'daily'),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 120,
                  child: TextFormField(
                    controller: _targetCount,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: L10n.t(context, 'progressTargetCount'),
                      filled: true,
                      fillColor: AurixTokens.glass(0.06),
                    ),
                    validator: (v) {
                      final n = int.tryParse((v ?? '').trim());
                      if (n == null || n < 1) return '>= 1';
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            SwitchListTile(
              value: _isActive,
              onChanged: (v) => setState(() => _isActive = v),
              contentPadding: EdgeInsets.zero,
              activeColor: AurixTokens.orange,
              title: Text(L10n.t(context, 'active'), style: const TextStyle(color: AurixTokens.text)),
              subtitle: Text(L10n.t(context, 'progressActiveHint'), style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.9), fontSize: 12)),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _saving
                    ? null
                    : () async {
                        if (!_formKey.currentState!.validate()) return;
                        final data = _HabitFormData(
                          title: _title.text.trim(),
                          category: _category,
                          targetType: _targetType,
                          targetCount: int.parse(_targetCount.text.trim()),
                          isActive: _isActive,
                        );
                        setState(() => _saving = true);
                        try {
                          await widget.onSave(data);
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
      ),
    );
  }
}

