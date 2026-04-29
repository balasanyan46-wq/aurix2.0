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
              const SizedBox(height: 24),
              const _OfferFunnelSection(),
              const SizedBox(height: 24),
              const _AbTemplatesSection(),
            ],
          ),
        );
      },
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  Offer → Payment funnel (новая секция)
//  Пока в БД нет offer_sent событий — секция показывает заглушку
//  «Накопите хотя бы 10 отправленных офферов для статистики».
// ════════════════════════════════════════════════════════════════════════

class _OfferFunnelSection extends ConsumerWidget {
  const _OfferFunnelSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dataAsync = ref.watch(adminOfferFunnelProvider);
    return dataAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (d) {
        final fmt = NumberFormat.decimalPattern('ru');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.local_offer_rounded, size: 16, color: AurixTokens.orange),
                const SizedBox(width: 8),
                const Text('OFFER → PAYMENT FUNNEL', style: TextStyle(
                  color: AurixTokens.orange, fontSize: 11,
                  fontWeight: FontWeight.w800, letterSpacing: 1.5,
                )),
                const Spacer(),
                Text('${d.total.sent} офферов', style: const TextStyle(
                  color: AurixTokens.muted, fontSize: 11,
                )),
              ],
            ),
            const SizedBox(height: 8),
            if (d.total.sent < 10)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AurixTokens.bg1.withValues(alpha: 0.94),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AurixTokens.stroke(0.24)),
                ),
                child: const Text(
                  'Накопите хотя бы 10 отправленных офферов для осмысленной статистики. '
                  'Окно атрибуции — 14 дней с момента offer_sent.',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.4),
                ),
              )
            else ...[
              // Headline
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${d.total.paidPct.toStringAsFixed(1)}%',
                            style: const TextStyle(
                              color: AurixTokens.positive,
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              fontFeatures: AurixTokens.tabularFigures,
                            ),
                          ),
                          const Text('конверсия offer → paid',
                              style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
                        ],
                      ),
                    ),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('${fmt.format(d.total.revenueRub)} ₽',
                            style: const TextStyle(
                              color: AurixTokens.text,
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              fontFeatures: AurixTokens.tabularFigures,
                            )),
                        const Text('revenue от офферов',
                            style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
              // Per-offer breakdown
              ...d.byOffer.map((o) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AurixTokens.bg1.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: AurixTokens.stroke(0.24)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: Text(
                                o.productOffer.toUpperCase(),
                                style: const TextStyle(
                                  color: AurixTokens.text, fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                ),
                              )),
                              Text('${o.sent} sent · ${o.paid} paid · ${o.paidPct.toStringAsFixed(1)}%',
                                  style: const TextStyle(
                                    color: AurixTokens.positive, fontSize: 11,
                                    fontWeight: FontWeight.w700,
                                  )),
                            ],
                          ),
                          const SizedBox(height: 6),
                          // Mini-funnel: 4 ступени относительно sent
                          Row(children: [
                            _funnelStep('Sent', o.sent, 100, AurixTokens.muted),
                            _funnelStep('Click', o.clicked, o.clickPct, AurixTokens.accent),
                            _funnelStep('Checkout', o.checkout, o.checkoutPct, AurixTokens.orange),
                            _funnelStep('Paid', o.paid, o.paidPct, AurixTokens.positive),
                          ]),
                        ],
                      ),
                    ),
                  )),
            ],
          ],
        );
      },
    );
  }

  Widget _funnelStep(String label, int count, double pct, Color color) {
    return Expanded(
      child: Padding(
        padding: const EdgeInsets.only(right: 6),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 9)),
            Text('$count', style: TextStyle(
              color: color, fontSize: 14, fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            )),
            Text('${pct.toStringAsFixed(1)}%', style: const TextStyle(
              color: AurixTokens.muted, fontSize: 9,
              fontFeatures: AurixTokens.tabularFigures,
            )),
          ],
        ),
      ),
    );
  }
}

// ════════════════════════════════════════════════════════════════════════
//  A/B шаблоны: conversion по вариантам (sent → paid)
// ════════════════════════════════════════════════════════════════════════

class _AbTemplatesSection extends ConsumerWidget {
  const _AbTemplatesSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminTemplateStatsProvider);
    return statsAsync.when(
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
      data: (items) {
        if (items.isEmpty) {
          return const SizedBox.shrink();
        }
        // Группируем по code для удобного сравнения вариантов одного действия.
        final byCode = <String, List<TemplateStat>>{};
        for (final s in items) {
          byCode.putIfAbsent(s.code, () => []).add(s);
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: const [
              Icon(Icons.science_rounded, size: 16, color: AurixTokens.aiAccent),
              SizedBox(width: 8),
              Text('A/B ШАБЛОНЫ — КОНВЕРСИЯ ПО ВАРИАНТАМ', style: TextStyle(
                color: AurixTokens.aiAccent, fontSize: 11,
                fontWeight: FontWeight.w800, letterSpacing: 1.5,
              )),
            ]),
            const SizedBox(height: 8),
            ...byCode.entries.map((entry) {
              final code = entry.key;
              final variants = entry.value;
              variants.sort((a, b) => b.conversionPct.compareTo(a.conversionPct));
              final winner = variants.first;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AurixTokens.bg1.withValues(alpha: 0.94),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AurixTokens.stroke(0.24)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(code, style: const TextStyle(
                        color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w800,
                      )),
                      const SizedBox(height: 6),
                      ...variants.map((v) {
                        final isWinner = v == winner && variants.length > 1 && v.sent >= 5;
                        return Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Container(
                                width: 24,
                                alignment: Alignment.center,
                                child: Text(v.variantKey, style: TextStyle(
                                  color: isWinner ? AurixTokens.positive : AurixTokens.muted,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w800,
                                )),
                              ),
                              const SizedBox(width: 8),
                              Text('${v.sent} sent · ${v.paid} paid',
                                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                              const Spacer(),
                              Text('${v.conversionPct.toStringAsFixed(1)}%', style: TextStyle(
                                color: isWinner ? AurixTokens.positive : AurixTokens.text,
                                fontSize: 13,
                                fontWeight: FontWeight.w800,
                                fontFeatures: AurixTokens.tabularFigures,
                              )),
                              if (isWinner) ...[
                                const SizedBox(width: 4),
                                const Icon(Icons.emoji_events_rounded, size: 12, color: AurixTokens.positive),
                              ],
                            ],
                          ),
                        );
                      }),
                    ],
                  ),
                ),
              );
            }),
          ],
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
