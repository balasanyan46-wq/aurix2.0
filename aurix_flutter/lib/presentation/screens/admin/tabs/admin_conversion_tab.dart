import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';

/// Conversion Dashboard — артистическая воронка с деньгами.
///
/// Источник: GET /admin/conversion (view v_conversion_funnel + revenue_by_step).
class AdminConversionTab extends ConsumerWidget {
  const AdminConversionTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminConversionProvider);

    return dataAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AurixTokens.accent),
      ),
      error: (e, _) => Center(
        child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted)),
      ),
      data: (data) {
        if (data.steps.isEmpty) {
          return const Center(
            child: Text('Нет данных по воронке', style: TextStyle(color: AurixTokens.muted)),
          );
        }
        final maxCount = data.steps
            .map((s) => s.usersCount)
            .fold<int>(0, (a, b) => a > b ? a : b);
        return RefreshIndicator(
          onRefresh: () async => ref.invalidate(adminConversionProvider),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              _RevenueHeader(totalRub: data.totalRevenueRub),
              const SizedBox(height: 16),
              ...data.steps.asMap().entries.map((entry) {
                final i = entry.key;
                final step = entry.value;
                return _FunnelStep(
                  index: i + 1,
                  step: step,
                  isFirst: i == 0,
                  maxCount: maxCount,
                );
              }),
            ],
          ),
        );
      },
    );
  }
}

class _RevenueHeader extends StatelessWidget {
  const _RevenueHeader({required this.totalRub});
  final int totalRub;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AurixTokens.positive.withValues(alpha: 0.18),
            AurixTokens.positive.withValues(alpha: 0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.4)),
      ),
      child: Row(
        children: [
          const Icon(Icons.trending_up_rounded, color: AurixTokens.positive, size: 28),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('ОБЩИЙ ДОХОД', style: TextStyle(
                color: AurixTokens.muted, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 4),
              Text(
                '${NumberFormat.decimalPattern('ru').format(totalRub)} ₽',
                style: const TextStyle(
                  color: AurixTokens.text, fontSize: 24, fontWeight: FontWeight.w800,
                  fontFeatures: AurixTokens.tabularFigures,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FunnelStep extends StatelessWidget {
  const _FunnelStep({
    required this.index,
    required this.step,
    required this.isFirst,
    required this.maxCount,
  });
  final int index;
  final ConversionStep step;
  final bool isFirst;
  final int maxCount;

  @override
  Widget build(BuildContext context) {
    final ratio = maxCount > 0 ? step.usersCount / maxCount : 0.0;
    final dropOffSerious = !isFirst && step.dropOffPct > 50;
    final color = dropOffSerious
        ? AurixTokens.danger
        : (step.conversionPct > 30 ? AurixTokens.positive : AurixTokens.orange);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28, height: 28,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$index',
                  style: const TextStyle(
                    color: AurixTokens.accent, fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(step.label, style: const TextStyle(
                  color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700,
                )),
              ),
              Text(
                '${NumberFormat.decimalPattern('ru').format(step.usersCount)}',
                style: const TextStyle(
                  color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w800,
                  fontFeatures: AurixTokens.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // Bar
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio.clamp(0.0, 1.0),
              minHeight: 8,
              backgroundColor: AurixTokens.bg1,
              valueColor: AlwaysStoppedAnimation(color),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              if (!isFirst) ...[
                Icon(
                  step.conversionPct >= 50 ? Icons.arrow_upward_rounded : Icons.arrow_downward_rounded,
                  color: color, size: 13,
                ),
                Text('${step.conversionPct.toStringAsFixed(1)}% от прошлого',
                    style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
                const SizedBox(width: 12),
                Text('Drop-off: ${step.dropOffPct.toStringAsFixed(1)}%',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
              ],
              const Spacer(),
              if (step.revenueGeneratedRub > 0)
                Text(
                  '${NumberFormat.decimalPattern('ru').format(step.revenueGeneratedRub)} ₽',
                  style: const TextStyle(
                    color: AurixTokens.positive,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
