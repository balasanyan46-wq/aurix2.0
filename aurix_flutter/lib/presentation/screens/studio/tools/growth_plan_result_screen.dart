import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/data/models/release_model.dart';

import 'growth_plan_form_screen.dart';

class GrowthPlanResultScreen extends ConsumerWidget {
  final ReleaseModel release;
  final Map<String, dynamic> planData;
  final bool isDemo;

  const GrowthPlanResultScreen({
    super.key,
    required this.release,
    required this.planData,
    required this.isDemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final summary = planData['summary'] as String? ?? '';
    final weeklyFocus = (planData['weekly_focus'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final days = (planData['days'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final checkpoints = (planData['checkpoints'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Карта роста: ${release.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Обновить план',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => GrowthPlanFormScreen(release: release)),
              );
            },
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (isDemo) _demoBanner(context),
          if (summary.isNotEmpty) ...[
            _card(
              context,
              icon: Icons.summarize_rounded,
              title: 'Резюме',
              child: Text(summary, style: tt.bodyMedium),
            ),
            const SizedBox(height: 12),
          ],
          if (weeklyFocus.isNotEmpty) ...[
            _card(
              context,
              icon: Icons.calendar_view_week_rounded,
              title: 'Фокус по неделям',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: weeklyFocus.map((w) {
                  final week = w['week'] ?? '?';
                  final focus = w['focus'] ?? '';
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.primary.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          alignment: Alignment.center,
                          child: Text('$week', style: TextStyle(fontWeight: FontWeight.bold, color: cs.primary)),
                        ),
                        const SizedBox(width: 12),
                        Expanded(child: Text(focus.toString(), style: tt.bodyMedium)),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (checkpoints.isNotEmpty) ...[
            _card(
              context,
              icon: Icons.flag_rounded,
              title: 'Контрольные точки',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: checkpoints.map((cp) {
                  final day = cp['day'] ?? '?';
                  final kpi = (cp['kpi'] as List?)?.cast<String>() ?? [];
                  final actions = (cp['actions'] as List?)?.cast<String>() ?? [];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('День $day', style: tt.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                        if (kpi.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...kpi.map((k) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                const Icon(Icons.check_circle_outline, size: 16, color: Color(0xFF22C55E)),
                                const SizedBox(width: 6),
                                Expanded(child: Text(k, style: tt.bodySmall)),
                              ],
                            ),
                          )),
                        ],
                        if (actions.isNotEmpty) ...[
                          const SizedBox(height: 6),
                          ...actions.map((a) => Padding(
                            padding: const EdgeInsets.only(bottom: 2),
                            child: Row(
                              children: [
                                Icon(Icons.arrow_forward_rounded, size: 14, color: cs.primary),
                                const SizedBox(width: 6),
                                Expanded(child: Text(a, style: tt.bodySmall)),
                              ],
                            ),
                          )),
                        ],
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (days.isNotEmpty)
            _card(
              context,
              icon: Icons.view_day_rounded,
              title: 'План по дням (${days.length} дней)',
              child: _DaysExpansionList(days: days),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _demoBanner(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF59E0B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFF59E0B).withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.star_rounded, color: Color(0xFFF59E0B)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Демо-версия', style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.bold, color: const Color(0xFFF59E0B))),
                const SizedBox(height: 2),
                Text('Перейдите на Прорыв для персонализации', style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
          TextButton(
            onPressed: () => context.push('/subscription'),
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  Widget _card(BuildContext context, {required IconData icon, required String title, required Widget child}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cs.outlineVariant.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: cs.primary),
              const SizedBox(width: 8),
              Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _DaysExpansionList extends StatelessWidget {
  final List<Map<String, dynamic>> days;
  const _DaysExpansionList({required this.days});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Column(
      children: days.map((d) {
        final day = d['day'] ?? '?';
        final title = d['title'] ?? 'День $day';
        final tasks = (d['tasks'] as List?)?.cast<String>() ?? [];
        final outputs = (d['outputs'] as List?)?.cast<String>() ?? [];
        final timeMin = d['time_min'] ?? 0;

        return ExpansionTile(
          tilePadding: EdgeInsets.zero,
          childrenPadding: const EdgeInsets.only(bottom: 8),
          leading: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            alignment: Alignment.center,
            child: Text('$day', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: cs.primary)),
          ),
          title: Text(title.toString(), style: tt.bodyMedium?.copyWith(fontWeight: FontWeight.w600)),
          subtitle: Text('~$timeMin мин', style: tt.bodySmall?.copyWith(color: cs.onSurface.withValues(alpha: 0.45))),
          children: [
            if (tasks.isNotEmpty) ...[
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Задачи:', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: cs.onSurface.withValues(alpha: 0.6))),
              ),
              const SizedBox(height: 4),
              ...tasks.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: cs.primary)),
                    Expanded(child: Text(t, style: tt.bodySmall)),
                  ],
                ),
              )),
            ],
            if (outputs.isNotEmpty) ...[
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: Text('Результаты:', style: tt.labelSmall?.copyWith(fontWeight: FontWeight.w700, color: const Color(0xFF22C55E))),
              ),
              const SizedBox(height: 4),
              ...outputs.map((o) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check_rounded, size: 14, color: Color(0xFF22C55E)),
                    const SizedBox(width: 6),
                    Expanded(child: Text(o, style: tt.bodySmall)),
                  ],
                ),
              )),
            ],
          ],
        );
      }).toList(),
    );
  }
}
