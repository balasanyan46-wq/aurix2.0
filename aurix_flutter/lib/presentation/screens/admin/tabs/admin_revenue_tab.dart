import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';

/// Revenue Dashboard — SaaS-метрики (MRR / ARR / ARPU / LTV / Churn /
/// Conversion / Failed / Refunds / Forecast + 12-month timeseries).
///
/// Источник: GET /admin/revenue (10+ параллельных SQL под капотом).
/// Не кэшируется на бэкенде — обновляется по pull-to-refresh.
class AdminRevenueTab extends ConsumerWidget {
  const AdminRevenueTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final metricsAsync = ref.watch(adminRevenueProvider);
    final fmt = NumberFormat.decimalPattern('ru');

    return metricsAsync.when(
      loading: () => const Center(
        child: CircularProgressIndicator(color: AurixTokens.accent),
      ),
      error: (e, _) => Center(
        child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted)),
      ),
      data: (m) => RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminRevenueProvider),
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _HeadlineCard(mrr: m.mrrRub, arr: m.arrRub, momGrowth: m.momGrowthPct, fmt: fmt),
            const SizedBox(height: 16),
            _KpiGrid(metrics: m, fmt: fmt),
            const SizedBox(height: 16),
            if (m.monthlyRevenue12m.isNotEmpty) ...[
              _SectionTitle(title: 'ВЫРУЧКА ПО МЕСЯЦАМ (12)'),
              const SizedBox(height: 8),
              _MonthlyChart(data: m.monthlyRevenue12m, fmt: fmt),
              const SizedBox(height: 16),
            ],
            if (m.revenueByPlan.isNotEmpty) ...[
              _SectionTitle(title: 'ВЫРУЧКА ПО ПЛАНАМ (30 ДНЕЙ)'),
              const SizedBox(height: 8),
              _RevenueByPlanList(data: m.revenueByPlan, fmt: fmt),
              const SizedBox(height: 16),
            ],
            _RiskCards(metrics: m, fmt: fmt),
            const SizedBox(height: 12),
            if (m.generatedAt != null)
              Text(
                'Обновлено: ${m.generatedAt!.replaceFirst('T', ' ').substring(0, 19)}',
                style: const TextStyle(color: AurixTokens.muted, fontSize: 10),
                textAlign: TextAlign.center,
              ),
          ],
        ),
      ),
    );
  }
}

class _HeadlineCard extends StatelessWidget {
  const _HeadlineCard({
    required this.mrr,
    required this.arr,
    required this.momGrowth,
    required this.fmt,
  });
  final int mrr;
  final int arr;
  final double momGrowth;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final growthColor = momGrowth > 0
        ? AurixTokens.positive
        : (momGrowth < 0 ? AurixTokens.danger : AurixTokens.muted);
    final growthIcon = momGrowth > 0
        ? Icons.trending_up_rounded
        : (momGrowth < 0 ? Icons.trending_down_rounded : Icons.trending_flat_rounded);
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
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.attach_money_rounded, color: AurixTokens.positive, size: 22),
              const SizedBox(width: 8),
              const Text('MRR', style: TextStyle(
                color: AurixTokens.positive,
                fontSize: 12,
                fontWeight: FontWeight.w800,
                letterSpacing: 1.5,
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: growthColor.withValues(alpha: 0.18),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(growthIcon, size: 13, color: growthColor),
                    const SizedBox(width: 4),
                    Text(
                      '${momGrowth > 0 ? '+' : ''}${momGrowth.toStringAsFixed(1)}%',
                      style: TextStyle(
                        color: growthColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '${fmt.format(mrr)} ₽',
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 32,
              fontWeight: FontWeight.w900,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ARR ≈ ${fmt.format(arr)} ₽  ·  MoM growth',
            style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({required this.metrics, required this.fmt});
  final RevenueMetrics metrics;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _KpiCard(
          label: 'ARPU 30D',
          value: '${fmt.format(metrics.arpu30dRub)} ₽',
          color: AurixTokens.accent,
          tooltip: 'Средний доход с одного платящего юзера за 30 дней',
        ),
        _KpiCard(
          label: 'LTV',
          value: '${fmt.format(metrics.ltvRub)} ₽',
          color: AurixTokens.aiAccent,
          tooltip: 'Среднее всего денег от одного юзера за всё время',
        ),
        _KpiCard(
          label: 'CHURN 30D',
          value: '${metrics.churn30dPct.toStringAsFixed(1)}%',
          color: metrics.churn30dPct > 5 ? AurixTokens.danger : AurixTokens.muted,
          tooltip: 'Процент отписавшихся от активных за 30 дней',
        ),
        _KpiCard(
          label: 'CONVERSION',
          value: '${metrics.conversionToPaidPct.toStringAsFixed(1)}%',
          color: AurixTokens.positive,
          tooltip: 'Платящих юзеров от всех зарегистрированных',
        ),
        _KpiCard(
          label: 'FORECAST NEXT MONTH',
          value: '${fmt.format(metrics.forecastNextMonthRub)} ₽',
          color: AurixTokens.orange,
          tooltip: 'Прогноз MRR следующего месяца на основе текущего тренда',
        ),
      ],
    );
  }
}

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label,
    required this.value,
    required this.color,
    this.tooltip,
  });
  final String label;
  final String value;
  final Color color;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      width: 180,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(
            color: color, fontSize: 10,
            fontWeight: FontWeight.w800, letterSpacing: 1.5,
          )),
          const SizedBox(height: 6),
          Text(
            value,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 18,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
    return tooltip != null ? Tooltip(message: tooltip!, child: card) : card;
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title});
  final String title;
  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(left: 4),
        child: Text(title, style: const TextStyle(
          color: AurixTokens.muted,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 1.5,
        )),
      );
}

class _MonthlyChart extends StatelessWidget {
  const _MonthlyChart({required this.data, required this.fmt});
  final List<RevenueMonthly> data;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxRev = data
        .map((d) => d.revenueRub)
        .fold<int>(0, (a, b) => a > b ? a : b);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Column(
        children: data.map((d) {
          final ratio = maxRev > 0 ? d.revenueRub / maxRev : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 64,
                  child: Text(
                    d.month, // YYYY-MM
                    style: const TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 11,
                      fontFeatures: AurixTokens.tabularFigures,
                    ),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio.clamp(0.0, 1.0),
                      minHeight: 14,
                      backgroundColor: AurixTokens.bg0,
                      valueColor: const AlwaysStoppedAnimation(AurixTokens.positive),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 90,
                  child: Text(
                    '${fmt.format(d.revenueRub)} ₽',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AurixTokens.tabularFigures,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 36,
                  child: Text(
                    '${d.payingUsers}',
                    textAlign: TextAlign.right,
                    style: const TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 11,
                      fontFeatures: AurixTokens.tabularFigures,
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RevenueByPlanList extends StatelessWidget {
  const _RevenueByPlanList({required this.data, required this.fmt});
  final List<RevenueByPlan> data;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    final total = data.fold<int>(0, (s, p) => s + p.revenue30dRub);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Column(
        children: data.map((p) {
          final pct = total > 0 ? p.revenue30dRub / total : 0.0;
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(
                      p.plan.toUpperCase(),
                      style: const TextStyle(
                        color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w800,
                      ),
                    )),
                    Text('${p.payingUsers} юзеров',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                    const SizedBox(width: 12),
                    Text(
                      '${fmt.format(p.revenue30dRub)} ₽',
                      style: const TextStyle(
                        color: AurixTokens.positive,
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                        fontFeatures: AurixTokens.tabularFigures,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct.clamp(0.0, 1.0),
                    minHeight: 4,
                    backgroundColor: AurixTokens.bg0,
                    valueColor: const AlwaysStoppedAnimation(AurixTokens.accent),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _RiskCards extends StatelessWidget {
  const _RiskCards({required this.metrics, required this.fmt});
  final RevenueMetrics metrics;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        _RiskCard(
          icon: Icons.warning_rounded,
          title: 'Failed payments 30d',
          color: AurixTokens.danger,
          count: metrics.failedPayments30dCount,
          rub: metrics.failedPayments30dTotalRub,
          fmt: fmt,
        ),
        _RiskCard(
          icon: Icons.replay_rounded,
          title: 'Refunds 30d',
          color: AurixTokens.orange,
          count: metrics.refunds30dCount,
          rub: metrics.refunds30dTotalRub,
          fmt: fmt,
        ),
      ],
    );
  }
}

class _RiskCard extends StatelessWidget {
  const _RiskCard({
    required this.icon,
    required this.title,
    required this.color,
    required this.count,
    required this.rub,
    required this.fmt,
  });
  final IconData icon;
  final String title;
  final Color color;
  final int count;
  final int rub;
  final NumberFormat fmt;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(
                  color: AurixTokens.muted, fontSize: 10,
                  fontWeight: FontWeight.w800, letterSpacing: 1.2,
                )),
                const SizedBox(height: 2),
                Text(
                  '$count · ${fmt.format(rub)} ₽',
                  style: const TextStyle(
                    color: AurixTokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
