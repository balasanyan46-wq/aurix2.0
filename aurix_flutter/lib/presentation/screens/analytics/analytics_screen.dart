import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/reports_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/core/services/event_tracker.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';
import 'package:aurix_flutter/presentation/screens/analytics/analytics_charts.dart';

// \u2500\u2500 Screen \u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500\u2500

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen> {
  @override
  void initState() {
    super.initState();
    EventTracker.track('viewed_analytics');
  }

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(releasesProvider);
    final reportsAsync = ref.watch(userReportRowsProvider);

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: releasesAsync.when(
        loading: () => const PremiumLoadingState(
          message: '\u0410\u043d\u0430\u043b\u0438\u0437\u0438\u0440\u0443\u0435\u043c \u0442\u0432\u043e\u044e \u043c\u0443\u0437\u044b\u043a\u0443...',
        ),
        error: (e, _) => PremiumErrorState(
          message: '\u041d\u0435 \u0443\u0434\u0430\u043b\u043e\u0441\u044c \u0437\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u044c \u0434\u0430\u043d\u043d\u044b\u0435',
          onRetry: () {
            ref.invalidate(releasesProvider);
            ref.invalidate(userReportRowsProvider);
          },
        ),
        data: (releases) {
          final reports = reportsAsync.valueOrNull ?? <ReportRowModel>[];
          return _AnalyticsDashboard(
            releases: releases,
            reports: reports,
            onRefresh: () async {
              ref.invalidate(releasesProvider);
              ref.invalidate(userReportRowsProvider);
            },
          );
        },
      ),
    );
  }
}

class _AnalyticsDashboard extends StatelessWidget {
  const _AnalyticsDashboard({
    required this.releases,
    required this.reports,
    required this.onRefresh,
  });
  final List<ReleaseModel> releases;
  final List<ReportRowModel> reports;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final totalStreams = reports.fold<int>(0, (s, r) => s + r.streams);
    final totalRevenue = reports.fold<double>(0, (s, r) => s + r.revenue);

    // Build daily series from reports
    final dayMap = <String, int>{};
    for (final r in reports) {
      if (r.reportDate != null) {
        final key = r.reportDate!.toIso8601String().substring(0, 10);
        dayMap[key] = (dayMap[key] ?? 0) + r.streams;
      }
    }
    final sortedDays = dayMap.keys.toList()..sort();
    final series = sortedDays
        .map((d) => <String, dynamic>{'day': d, 'streams': dayMap[d]})
        .toList();

    // Build per-release stats
    final releaseStats = <Map<String, dynamic>>[];
    for (final rel in releases) {
      final relReports = reports.where((r) => r.releaseId == rel.id);
      final streams = relReports.fold<int>(0, (s, r) => s + r.streams);
      final revenue = relReports.fold<double>(0, (s, r) => s + r.revenue);
      releaseStats.add({
        'title': rel.title,
        'genre': rel.genre ?? '',
        'streams': streams,
        'revenue': revenue,
        'clicks': 0,
      });
    }

    final isDesktop = MediaQuery.sizeOf(context).width >= 900;

    return RefreshIndicator(
      color: AurixTokens.accent,
      onRefresh: onRefresh,
      child: PremiumPageScaffold(
        title: 'Статистика',
        subtitle: 'Стримы, доходы и динамика твоих релизов',
        systemLabel: 'ANALYTICS',
        systemColor: AurixTokens.accent,
        children: [
          SectionOnboarding(tip: OnboardingTips.stats),
          // KPI Grid
          FadeInSlide(
            delayMs: 60,
            child: _KpiGrid(
              isDesktop: isDesktop,
              totalStreams: totalStreams,
              totalRevenue: totalRevenue,
              totalReleases: releases.length,
              liveReleases: releases.where((r) => r.isLive).length,
            ),
          ),

          // Chart
          const SizedBox(height: 20),
          FadeInSlide(
            delayMs: 180,
            child: _StreamChartBlock(series: series),
          ),

          // AI Insights — самое важное, сверху разделов
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 20),
            FadeInSlide(
              delayMs: 220,
              child: AiInsightsPanel(rows: reports, totalReleases: releases.length),
            ),
          ],

          // Чарты: платформы + типы использования (двумя колонками на десктопе)
          if (reports.isNotEmpty) ...[
            const SizedBox(height: 20),
            FadeInSlide(
              delayMs: 260,
              child: isDesktop
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: PlatformDonutChart(rows: reports)),
                      const SizedBox(width: 12),
                      Expanded(child: UsageTypeChart(rows: reports)),
                    ])
                  : Column(children: [
                      PlatformDonutChart(rows: reports),
                      const SizedBox(height: 12),
                      UsageTypeChart(rows: reports),
                    ]),
            ),

            // География + Топ треков
            const SizedBox(height: 20),
            FadeInSlide(
              delayMs: 300,
              child: isDesktop
                  ? Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Expanded(child: CountriesBarChart(rows: reports)),
                      const SizedBox(width: 12),
                      Expanded(child: TopTracksChart(rows: reports)),
                    ])
                  : Column(children: [
                      CountriesBarChart(rows: reports),
                      const SizedBox(height: 12),
                      TopTracksChart(rows: reports),
                    ]),
            ),
          ],

          // Releases
          if (releaseStats.isNotEmpty) ...[
            const SizedBox(height: 20),
            FadeInSlide(
              delayMs: 340,
              child: _ReleasesSection(releases: releaseStats),
            ),
          ],
        ],
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// KPI Grid \u2014 responsive grid of metric cards
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _KpiGrid extends StatelessWidget {
  const _KpiGrid({
    required this.isDesktop,
    required this.totalStreams,
    required this.totalRevenue,
    required this.totalReleases,
    required this.liveReleases,
  });
  final bool isDesktop;
  final int totalStreams, totalReleases, liveReleases;
  final double totalRevenue;

  @override
  Widget build(BuildContext context) {
    final kpis = [
      _KpiData(
        label: 'Стримы',
        value: _formatNumber(totalStreams),
        icon: Icons.headphones_rounded,
        color: AurixTokens.accent,
      ),
      _KpiData(
        label: 'Доход',
        value: '${totalRevenue.toStringAsFixed(0)} \u20bd',
        icon: Icons.account_balance_wallet_rounded,
        color: AurixTokens.positive,
      ),
      _KpiData(
        label: 'Релизы',
        value: '$liveReleases',
        suffix: '/ $totalReleases',
        icon: Icons.album_rounded,
        color: AurixTokens.aiAccent,
      ),
    ];

    if (isDesktop) {
      return Row(
        children: [
          for (int i = 0; i < kpis.length; i++) ...[
            if (i > 0) const SizedBox(width: 12),
            Expanded(child: _KpiCard(data: kpis[i])),
          ],
        ],
      );
    }

    // Mobile: 2-column wrap
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: kpis
          .map((k) => SizedBox(
                width: (MediaQuery.sizeOf(context).width - 52) / 2,
                child: _KpiCard(data: k),
              ))
          .toList(),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

class _KpiData {
  const _KpiData({
    required this.label,
    required this.value,
    required this.icon,
    required this.color,
    this.change,
    this.suffix,
  });
  final String label, value;
  final IconData icon;
  final Color color;
  final int? change;
  final String? suffix;
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({required this.data});
  final _KpiData data;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final d = widget.data;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AurixTokens.dMedium,
        curve: AurixTokens.cEase,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _hovered
                  ? d.color.withValues(alpha: 0.06)
                  : AurixTokens.surface1.withValues(alpha: 0.5),
              AurixTokens.bg1.withValues(alpha: 0.9),
            ],
          ),
          border: Border.all(
            color: _hovered
                ? d.color.withValues(alpha: 0.3)
                : AurixTokens.stroke(0.14),
          ),
          boxShadow: _hovered
              ? [
                  BoxShadow(
                    color: d.color.withValues(alpha: 0.1),
                    blurRadius: 24,
                    spreadRadius: -8,
                  ),
                ]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: d.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(d.icon, size: 14, color: d.color),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    d.label.toUpperCase(),
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      color: AurixTokens.micro,
                      fontSize: 9,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.8,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  d.value,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.text,
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    fontFeatures: AurixTokens.tabularFigures,
                    height: 1,
                  ),
                ),
                if (d.suffix != null) ...[
                  const SizedBox(width: 4),
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Text(
                      d.suffix!,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontMono,
                        color: AurixTokens.micro,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            if (d.change != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  color: (d.change! >= 0 ? AurixTokens.positive : AurixTokens.danger)
                      .withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      d.change! >= 0
                          ? Icons.trending_up_rounded
                          : Icons.trending_down_rounded,
                      size: 11,
                      color: d.change! >= 0
                          ? AurixTokens.positive
                          : AurixTokens.danger,
                    ),
                    const SizedBox(width: 3),
                    Text(
                      '${d.change! >= 0 ? '+' : ''}${d.change}%',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontMono,
                        color: d.change! >= 0
                            ? AurixTokens.positive
                            : AurixTokens.danger,
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Diagnosis Section
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _DiagnosisSection extends StatelessWidget {
  const _DiagnosisSection({required this.diagnosis});
  final List<Map<String, dynamic>> diagnosis;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      glowColor: AurixTokens.warning,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AurixTokens.warning.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.health_and_safety_rounded, size: 14, color: AurixTokens.warning),
              ),
              const SizedBox(width: 10),
              Text(
                '\u0414\u0418\u0410\u0413\u041d\u041e\u0417',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.text,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AurixTokens.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${diagnosis.length}',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.warning,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          for (int i = 0; i < diagnosis.length; i++) ...[
            if (i > 0) const SizedBox(height: 10),
            _DiagnosisCard(item: diagnosis[i]),
          ],
        ],
      ),
    );
  }
}

class _DiagnosisCard extends StatelessWidget {
  const _DiagnosisCard({required this.item});
  final Map<String, dynamic> item;

  @override
  Widget build(BuildContext context) {
    final problem = item['problem']?.toString() ?? '';
    final cause = item['cause']?.toString() ?? '';
    final fix = item['fix']?.toString() ?? '';
    final effect = item['effect']?.toString() ?? '';
    final severity = item['severity']?.toString() ?? 'medium';

    final isPositive = severity == 'positive';
    final isCritical = severity == 'critical';
    final borderColor = isPositive
        ? AurixTokens.positive
        : isCritical
            ? AurixTokens.danger
            : AurixTokens.warning;
    final severityIcon = isPositive
        ? Icons.check_circle_rounded
        : isCritical
            ? Icons.error_rounded
            : Icons.warning_amber_rounded;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
        color: borderColor.withValues(alpha: 0.04),
        border: Border.all(color: borderColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: borderColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Icon(severityIcon, size: 13, color: borderColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  problem,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: AurixTokens.text,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    height: 1.3,
                  ),
                ),
              ),
            ],
          ),
          if (cause.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 34),
              child: Text(
                cause,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.muted,
                  fontSize: 12,
                  height: 1.4,
                ),
              ),
            ),
          if (fix.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10, left: 34),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.1)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_rounded, size: 13, color: AurixTokens.accent.withValues(alpha: 0.6)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        fix,
                        style: TextStyle(
                          fontFamily: AurixTokens.fontBody,
                          color: AurixTokens.text,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          if (effect.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 34),
              child: Row(
                children: [
                  Icon(Icons.trending_up_rounded, size: 12, color: AurixTokens.positive.withValues(alpha: 0.7)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      effect,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.positive,
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        height: 1.4,
                      ),
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

class _MiniAction extends StatefulWidget {
  const _MiniAction({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_MiniAction> createState() => _MiniActionState();
}

class _MiniActionState extends State<_MiniAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: widget.color.withValues(alpha: _hovered ? 0.15 : 0.08),
            borderRadius: BorderRadius.circular(7),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.3 : 0.15),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 12, color: widget.color),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: widget.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Action Row
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _ActionRow extends StatelessWidget {
  const _ActionRow({required this.isDesktop});
  final bool isDesktop;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ActionBlock(
            icon: Icons.rocket_launch_rounded,
            title: '\u041f\u043e\u0441\u0442\u0440\u043e\u0438\u0442\u044c \u043f\u043b\u0430\u043d',
            subtitle: 'AI \u0441\u043e\u0431\u0435\u0440\u0451\u0442 \u0441\u0442\u0440\u0430\u0442\u0435\u0433\u0438\u044e',
            color: AurixTokens.accent,
            onTap: () => context.push('/stats/release-plan'),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _ActionBlock(
            icon: Icons.local_fire_department_rounded,
            title: '\u041f\u0440\u043e\u043c\u043e \u0438\u0434\u0435\u0438',
            subtitle: '\u0427\u0442\u043e \u0441\u043d\u044f\u0442\u044c \u043f\u0440\u044f\u043c\u043e \u0441\u0435\u0439\u0447\u0430\u0441',
            color: AurixTokens.warning,
            onTap: () => context.push('/stats/promo-ideas'),
          ),
        ),
      ],
    );
  }
}

class _ActionBlock extends StatefulWidget {
  const _ActionBlock({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });
  final IconData icon;
  final String title, subtitle;
  final Color color;
  final VoidCallback onTap;

  @override
  State<_ActionBlock> createState() => _ActionBlockState();
}

class _ActionBlockState extends State<_ActionBlock> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dMedium,
          curve: AurixTokens.cEase,
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.color.withValues(alpha: _hovered ? 0.12 : 0.06),
                AurixTokens.bg1.withValues(alpha: 0.9),
              ],
            ),
            border: Border.all(
              color: widget.color.withValues(alpha: _hovered ? 0.35 : 0.18),
            ),
            boxShadow: _hovered
                ? [
                    BoxShadow(
                      color: widget.color.withValues(alpha: 0.12),
                      blurRadius: 24,
                      spreadRadius: -8,
                    ),
                  ]
                : null,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              AnimatedContainer(
                duration: AurixTokens.dMedium,
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: _hovered ? 0.2 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: widget.color.withValues(alpha: _hovered ? 0.3 : 0.15),
                  ),
                ),
                child: Icon(widget.icon, size: 18, color: widget.color),
              ),
              const SizedBox(height: 12),
              Text(
                widget.title,
                style: TextStyle(
                  fontFamily: AurixTokens.fontHeading,
                  color: _hovered ? widget.color : AurixTokens.text,
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                widget.subtitle,
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.micro,
                  fontSize: 11.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Stream Chart Block
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _StreamChartBlock extends StatelessWidget {
  const _StreamChartBlock({required this.series});
  final List<Map<String, dynamic>> series;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      glowColor: AurixTokens.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.show_chart_rounded, size: 14, color: AurixTokens.accent),
              ),
              const SizedBox(width: 10),
              Text(
                '\u0421\u0422\u0420\u0418\u041c\u042b \u0417\u0410 30 \u0414\u041d\u0415\u0419',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (series.isEmpty)
            Container(
              height: 120,
              width: double.infinity,
              decoration: BoxDecoration(
                color: AurixTokens.surface1.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                border: Border.all(color: AurixTokens.stroke(0.08)),
              ),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.bar_chart_rounded, size: 24, color: AurixTokens.micro),
                    const SizedBox(height: 8),
                    Text(
                      '\u0414\u0430\u043d\u043d\u044b\u0445 \u043f\u043e\u043a\u0430 \u043d\u0435\u0442 \u2014 \u0432\u044b\u043f\u0443\u0441\u0442\u0438 \u0442\u0440\u0435\u043a',
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.muted,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 140,
              child: CustomPaint(
                size: Size.infinite,
                painter: _ChartPainter(
                  values: series.map((s) => (s['streams'] as int? ?? 0).toDouble()).toList(),
                  lineColor: AurixTokens.accent,
                  glowColor: AurixTokens.accent.withValues(alpha: 0.15),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _shortDay(series.first['day']?.toString() ?? ''),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.micro,
                    fontSize: 10,
                  ),
                ),
                Text(
                  _shortDay(series[series.length ~/ 2]['day']?.toString() ?? ''),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.micro,
                    fontSize: 10,
                  ),
                ),
                Text(
                  _shortDay(series.last['day']?.toString() ?? ''),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.micro,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  static String _shortDay(String iso) => iso.length >= 10 ? iso.substring(5, 10) : iso;
}

class _ChartPainter extends CustomPainter {
  _ChartPainter({required this.values, required this.lineColor, required this.glowColor});
  final List<double> values;
  final Color lineColor, glowColor;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final maxVal = values.reduce(max).clamp(1.0, double.infinity);
    final step = size.width / (values.length - 1);

    final path = Path();
    final fillPath = Path();

    for (int i = 0; i < values.length; i++) {
      final x = i * step;
      final y = size.height - (values[i] / maxVal) * size.height * 0.9;
      if (i == 0) {
        path.moveTo(x, y);
        fillPath.moveTo(x, size.height);
        fillPath.lineTo(x, y);
      } else {
        final px = (i - 1) * step;
        final py = size.height - (values[i - 1] / maxVal) * size.height * 0.9;
        final cx1 = px + step * 0.4;
        final cx2 = x - step * 0.4;
        path.cubicTo(cx1, py, cx2, y, x, y);
        fillPath.cubicTo(cx1, py, cx2, y, x, y);
      }
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Fill gradient
    canvas.drawPath(
      fillPath,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [glowColor, glowColor.withValues(alpha: 0)],
        ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)),
    );

    // Glow line
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor.withValues(alpha: 0.15)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );

    // Main line
    canvas.drawPath(
      path,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..strokeCap = StrokeCap.round,
    );

    // End dot
    if (values.isNotEmpty) {
      final lastX = (values.length - 1) * step;
      final lastY = size.height - (values.last / maxVal) * size.height * 0.9;
      canvas.drawCircle(
        Offset(lastX, lastY),
        3.5,
        Paint()..color = lineColor,
      );
      canvas.drawCircle(
        Offset(lastX, lastY),
        6,
        Paint()
          ..color = lineColor.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.values != values;
}

// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550
// Releases Section
// \u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550\u2550

class _ReleasesSection extends StatelessWidget {
  const _ReleasesSection({required this.releases});
  final List<Map<String, dynamic>> releases;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  color: AurixTokens.aiAccent.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(Icons.album_rounded, size: 14, color: AurixTokens.aiAccent),
              ),
              const SizedBox(width: 10),
              Text(
                '\u0422\u0412\u041e\u0418 \u0420\u0415\u041b\u0418\u0417\u042b',
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.text,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.0,
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AurixTokens.aiAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  '${releases.length}',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.aiAccent,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          for (int i = 0; i < releases.length; i++) ...[
            if (i > 0) const SizedBox(height: 8),
            _ReleaseRow(release: releases[i]),
          ],
        ],
      ),
    );
  }
}

class _ReleaseRow extends StatefulWidget {
  const _ReleaseRow({required this.release});
  final Map<String, dynamic> release;

  @override
  State<_ReleaseRow> createState() => _ReleaseRowState();
}

class _ReleaseRowState extends State<_ReleaseRow> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final title = widget.release['title']?.toString() ?? '';
    final streams = widget.release['streams'] as int? ?? 0;
    final revenue = (widget.release['revenue'] as num?)?.toDouble() ?? 0;
    final clicks = widget.release['clicks'] as int? ?? 0;
    final genre = widget.release['genre']?.toString() ?? '';

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AurixTokens.dFast,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
          color: _hovered
              ? AurixTokens.surface2.withValues(alpha: 0.5)
              : AurixTokens.surface1.withValues(alpha: 0.3),
          border: Border.all(
            color: _hovered
                ? AurixTokens.accent.withValues(alpha: 0.15)
                : AurixTokens.stroke(0.08),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                gradient: LinearGradient(
                  colors: [
                    AurixTokens.accent.withValues(alpha: 0.18),
                    AurixTokens.aiAccent.withValues(alpha: 0.1),
                  ],
                ),
                border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
              ),
              child: const Icon(Icons.music_note_rounded, color: AurixTokens.accent, size: 18),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      color: AurixTokens.text,
                      fontSize: 13.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (genre.isNotEmpty)
                    Text(
                      genre,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.micro,
                        fontSize: 11,
                      ),
                    ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$streams \u0441\u0442\u0440.',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.text,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
                Text(
                  '${revenue.toStringAsFixed(0)} \u20bd \u00b7 $clicks \u043a\u043b.',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.micro,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
