import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/data/providers/growth_providers.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

class GoalsScreen extends ConsumerStatefulWidget {
  const GoalsScreen({super.key});

  @override
  ConsumerState<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends ConsumerState<GoalsScreen> {
  bool _creating = false;

  void _refresh() {
    ref.invalidate(goalsProvider);
    ref.invalidate(growthStateProvider);
  }

  Future<void> _createGoal() async {
    final result = await showDialog<Map<String, String>>(
      context: context,
      builder: (ctx) => const _CreateGoalDialog(),
    );
    if (result == null) return;

    setState(() => _creating = true);
    try {
      await ApiClient.post('/growth/goals', data: {
        'title': result['title'],
        'description': result['description'],
      });
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger, behavior: SnackBarBehavior.floating),
        );
      }
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _incrementProgress(int goalId) async {
    try {
      await ApiClient.put('/growth/goals/$goalId/progress', data: {'increment': 1});
      _refresh();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger, behavior: SnackBarBehavior.floating),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final goalsAsync = ref.watch(goalsProvider);

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text('ЦЕЛИ', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
        actions: [
          IconButton(icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text), onPressed: _refresh),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _creating ? null : _createGoal,
        backgroundColor: AurixTokens.accent,
        foregroundColor: AurixTokens.text,
        icon: _creating
            ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.text))
            : const Icon(Icons.add_rounded),
        label: const Text('Новая цель', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: goalsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
        error: (e, _) => PremiumErrorState(message: 'Ошибка: $e'),
        data: (goals) {
          if (goals.isEmpty) {
            return Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.flag_rounded, size: 64, color: AurixTokens.muted.withValues(alpha: 0.3)),
                  const SizedBox(height: 16),
                  const Text('Пока нет целей', style: TextStyle(color: AurixTokens.muted, fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 6),
                  const Text('Создайте первую цель и получайте XP', style: TextStyle(color: AurixTokens.micro, fontSize: 13)),
                ],
              ),
            );
          }

          final active = goals.where((g) => g['is_completed'] != true).toList();
          final completed = goals.where((g) => g['is_completed'] == true).toList();

          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              SectionOnboarding(tip: OnboardingTips.goals),
              if (active.isNotEmpty) ...[
                _Header('Активные', active.length, AurixTokens.accent),
                const SizedBox(height: 10),
                ...active.map((g) => _GoalTile(goal: g, onIncrement: () => _incrementProgress(g['id']))),
                const SizedBox(height: 24),
              ],
              if (completed.isNotEmpty) ...[
                _Header('Завершённые', completed.length, AurixTokens.positive),
                const SizedBox(height: 10),
                ...completed.map((g) => _GoalTile(goal: g)),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.title, this.count, this.color);
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(8)),
          child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _GoalTile extends StatelessWidget {
  const _GoalTile({required this.goal, this.onIncrement});
  final Map<String, dynamic> goal;
  final VoidCallback? onIncrement;

  @override
  Widget build(BuildContext context) {
    final title = goal['title'] ?? '';
    final desc = goal['description'] ?? '';
    final progress = goal['progress'] ?? 0;
    final target = goal['target'] ?? 1;
    final isCompleted = goal['is_completed'] == true;
    final xpReward = goal['xp_reward'] ?? 50;
    final fraction = target > 0 ? (progress / target).clamp(0.0, 1.0) : 0.0;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isCompleted ? AurixTokens.positive.withValues(alpha: 0.06) : AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted ? AurixTokens.positive.withValues(alpha: 0.2) : AurixTokens.stroke(0.14),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    color: isCompleted ? AurixTokens.positive : AurixTokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$xpReward XP',
                  style: const TextStyle(color: AurixTokens.accentWarm, fontSize: 10.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          if (desc.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(desc, style: const TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.3)),
          ],
          const SizedBox(height: 10),
          // Progress bar
          Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: fraction.toDouble(),
                    backgroundColor: AurixTokens.glass(0.08),
                    valueColor: AlwaysStoppedAnimation(isCompleted ? AurixTokens.positive : AurixTokens.accent),
                    minHeight: 6,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                '$progress / $target',
                style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  fontFeatures: AurixTokens.tabularFigures,
                ),
              ),
              if (!isCompleted && onIncrement != null) ...[
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: onIncrement,
                  child: Container(
                    width: 28,
                    height: 28,
                    decoration: BoxDecoration(
                      color: AurixTokens.accent.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Icon(Icons.add_rounded, size: 16, color: AurixTokens.accent),
                  ),
                ),
              ],
              if (isCompleted) ...[
                const SizedBox(width: 8),
                const Icon(Icons.check_circle_rounded, size: 20, color: AurixTokens.positive),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CreateGoalDialog extends StatefulWidget {
  const _CreateGoalDialog();

  @override
  State<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<_CreateGoalDialog> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: const Text('Новая цель', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleCtrl,
            style: const TextStyle(color: AurixTokens.text),
            decoration: const InputDecoration(labelText: 'Название', hintText: 'Выпустить трек'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _descCtrl,
            style: const TextStyle(color: AurixTokens.text),
            decoration: const InputDecoration(labelText: 'Описание (необязательно)'),
            maxLines: 2,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Отмена'),
        ),
        FilledButton(
          onPressed: () {
            if (_titleCtrl.text.trim().isEmpty) return;
            Navigator.pop(context, {
              'title': _titleCtrl.text.trim(),
              'description': _descCtrl.text.trim(),
            });
          },
          child: const Text('Создать'),
        ),
      ],
    );
  }
}
