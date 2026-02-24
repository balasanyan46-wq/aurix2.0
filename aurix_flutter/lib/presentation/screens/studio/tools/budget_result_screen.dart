import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/data/models/release_model.dart';

import 'budget_form_screen.dart';

class BudgetResultScreen extends ConsumerWidget {
  final ReleaseModel release;
  final Map<String, dynamic> budgetData;
  final bool isDemo;

  const BudgetResultScreen({
    super.key,
    required this.release,
    required this.budgetData,
    required this.isDemo,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final summary = budgetData['summary'] as String? ?? '';
    final allocation = (budgetData['allocation'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final dontSpendOn = (budgetData['dont_spend_on'] as List?)?.cast<String>() ?? [];
    final mustSpendOn = (budgetData['must_spend_on'] as List?)?.cast<String>() ?? [];
    final nextSteps = (budgetData['next_steps'] as List?)?.cast<String>() ?? [];

    return Scaffold(
      appBar: AppBar(
        title: Text('Бюджет: ${release.title}'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded),
            tooltip: 'Пересчитать',
            onPressed: () {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(builder: (_) => BudgetFormScreen(release: release)),
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
          if (allocation.isNotEmpty) ...[
            _card(
              context,
              icon: Icons.pie_chart_rounded,
              title: 'Распределение бюджета',
              child: _AllocationChart(allocation: allocation, colorScheme: cs, textTheme: tt),
            ),
            const SizedBox(height: 12),
          ],
          if (mustSpendOn.isNotEmpty) ...[
            _card(
              context,
              icon: Icons.check_circle_rounded,
              title: 'Обязательно потратить на',
              child: _StringList(items: mustSpendOn, icon: Icons.check_rounded, color: const Color(0xFF22C55E)),
            ),
            const SizedBox(height: 12),
          ],
          if (dontSpendOn.isNotEmpty) ...[
            _card(
              context,
              icon: Icons.block_rounded,
              title: 'Не тратить на',
              child: _StringList(items: dontSpendOn, icon: Icons.close_rounded, color: const Color(0xFFEF4444)),
            ),
            const SizedBox(height: 12),
          ],
          if (nextSteps.isNotEmpty) ...[
            _card(
              context,
              icon: Icons.checklist_rounded,
              title: 'Следующие шаги',
              child: _NumberedList(items: nextSteps),
            ),
            const SizedBox(height: 12),
          ],
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

class _AllocationChart extends StatelessWidget {
  final List<Map<String, dynamic>> allocation;
  final ColorScheme colorScheme;
  final TextTheme textTheme;

  const _AllocationChart({
    required this.allocation,
    required this.colorScheme,
    required this.textTheme,
  });

  static const _categoryColors = [
    Color(0xFF3B82F6),
    Color(0xFF8B5CF6),
    Color(0xFFEC4899),
    Color(0xFFF59E0B),
    Color(0xFF22C55E),
    Color(0xFF6B7280),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 28,
            child: Row(
              children: allocation.asMap().entries.map((entry) {
                final percent = (entry.value['percent'] as num?)?.toDouble() ?? 0;
                if (percent <= 0) return const SizedBox.shrink();
                return Expanded(
                  flex: (percent * 10).round(),
                  child: Container(color: _categoryColors[entry.key % _categoryColors.length]),
                );
              }).toList(),
            ),
          ),
        ),
        const SizedBox(height: 16),
        ...allocation.asMap().entries.map((entry) {
          final item = entry.value;
          final color = _categoryColors[entry.key % _categoryColors.length];
          final category = item['category'] ?? '';
          final amount = item['amount'] ?? 0;
          final percent = item['percent'] ?? 0;
          final currency = item['currency'] ?? '₽';
          final notes = item['notes'] ?? '';

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 14,
                  height: 14,
                  margin: const EdgeInsets.only(top: 3),
                  decoration: BoxDecoration(
                    color: color,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(child: Text(category.toString(), style: textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600))),
                          Text('$amount $currency ($percent%)', style: textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
                        ],
                      ),
                      if (notes.toString().isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(notes.toString(), style: textTheme.bodySmall?.copyWith(
                            color: colorScheme.onSurface.withValues(alpha: 0.5),
                          )),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

class _StringList extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;

  const _StringList({required this.items, required this.icon, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.map((item) => Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Expanded(child: Text(item, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      )).toList(),
    );
  }
}

class _NumberedList extends StatelessWidget {
  final List<String> items;
  const _NumberedList({required this.items});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items.asMap().entries.map((entry) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 24,
              height: 24,
              decoration: BoxDecoration(
                color: cs.primary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(6),
              ),
              alignment: Alignment.center,
              child: Text('${entry.key + 1}', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: cs.primary)),
            ),
            const SizedBox(width: 10),
            Expanded(child: Text(entry.value, style: Theme.of(context).textTheme.bodyMedium)),
          ],
        ),
      )).toList(),
    );
  }
}
