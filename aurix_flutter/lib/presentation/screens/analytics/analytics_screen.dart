import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

// ── Provider ─────────────────────────────────────────────────

final _analyticsProvider = FutureProvider<Map<String, dynamic>>((ref) async {
  final res = await ApiClient.get('/analytics/dashboard');
  final body = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
  return body;
});

// ── Screen ───────────────────────────────────────────────────

class AnalyticsScreen extends ConsumerStatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  ConsumerState<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends ConsumerState<AnalyticsScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entryCtrl;

  @override
  void initState() {
    super.initState();
    _entryCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
  }

  @override
  void dispose() {
    _entryCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dataAsync = ref.watch(_analyticsProvider);

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: dataAsync.when(
        loading: () => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(color: AurixTokens.accent),
              const SizedBox(height: 16),
              Text('Анализируем твою музыку...', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
            ],
          ),
        ),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.wifi_off_rounded, size: 48, color: AurixTokens.muted.withValues(alpha: 0.3)),
              const SizedBox(height: 12),
              const Text('Не удалось загрузить данные', style: TextStyle(color: AurixTokens.muted)),
              const SizedBox(height: 8),
              TextButton(
                onPressed: () => ref.invalidate(_analyticsProvider),
                child: const Text('Попробовать снова', style: TextStyle(color: AurixTokens.orange)),
              ),
            ],
          ),
        ),
        data: (data) => _buildDashboard(data),
      ),
    );
  }

  Widget _buildDashboard(Map<String, dynamic> data) {
    final summary = data['summary'] as Map<String, dynamic>? ?? {};
    final series = (data['stream_series'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final releases = (data['releases'] as List?)?.cast<Map<String, dynamic>>() ?? [];
    final diagnosis = (data['diagnosis'] as List?)?.cast<Map<String, dynamic>>() ?? [];

    final totalStreams = summary['total_streams'] as int? ?? 0;
    final totalRevenue = (summary['total_revenue'] as num?)?.toDouble() ?? 0;
    final growthPct = summary['growth_pct'] as int? ?? 0;
    final engagement = summary['engagement'] as int? ?? 0;
    final viral = summary['viral_score'] as int? ?? 0;
    final totalClicks = summary['total_clicks'] as int? ?? 0;

    return RefreshIndicator(
      color: AurixTokens.orange,
      onRefresh: () async => ref.invalidate(_analyticsProvider),
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          // Header
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 4),
              child: _FadeSlide(controller: _entryCtrl, delay: 0, child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('ДИАГНОСТИКА', style: TextStyle(
                    color: AurixTokens.text, fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: 1.5,
                  )),
                  const SizedBox(height: 4),
                  Text('Что происходит с твоей музыкой прямо сейчас', style: TextStyle(
                    color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 13,
                  )),
                ],
              )),
            ),
          ),

          // ── DIAGNOSIS BLOCK ─────────────────────────────────
          if (diagnosis.isNotEmpty)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              sliver: SliverList.builder(
                itemCount: diagnosis.length,
                itemBuilder: (ctx, i) => _FadeSlide(
                  controller: _entryCtrl,
                  delay: 0.05 + i * 0.06,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _DiagnosisCard(item: diagnosis[i]),
                  ),
                ),
              ),
            ),

          // KPI cards
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            sliver: SliverToBoxAdapter(
              child: Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _FadeSlide(controller: _entryCtrl, delay: 0.25, child: _KpiCard(
                    label: 'СТРИМЫ', value: _formatNumber(totalStreams),
                    change: growthPct, icon: Icons.play_circle_rounded,
                    glowColor: growthPct >= 0 ? AurixTokens.positive : AurixTokens.danger,
                  )),
                  _FadeSlide(controller: _entryCtrl, delay: 0.28, child: _KpiCard(
                    label: 'ВОВЛЕЧЁННОСТЬ', value: '$engagement',
                    suffix: '/ 100', icon: Icons.favorite_rounded,
                    glowColor: AurixTokens.orange,
                  )),
                  _FadeSlide(controller: _entryCtrl, delay: 0.31, child: _KpiCard(
                    label: 'ВИРАЛЬНОСТЬ', value: '$viral',
                    suffix: '/ 100', icon: Icons.whatshot_rounded,
                    glowColor: AurixTokens.accent,
                  )),
                  _FadeSlide(controller: _entryCtrl, delay: 0.34, child: _KpiCard(
                    label: 'КЛИКИ', value: _formatNumber(totalClicks),
                    icon: Icons.touch_app_rounded, glowColor: AurixTokens.muted,
                  )),
                  _FadeSlide(controller: _entryCtrl, delay: 0.37, child: _KpiCard(
                    label: 'ДОХОД', value: '${totalRevenue.toStringAsFixed(0)} ₽',
                    icon: Icons.account_balance_wallet_rounded,
                    glowColor: AurixTokens.positive,
                  )),
                ],
              ),
            ),
          ),

          // ── ACTION BUTTONS ──────────────────────────────────
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _FadeSlide(
                controller: _entryCtrl, delay: 0.4,
                child: Row(
                  children: [
                    Expanded(child: _ActionButton(
                      label: 'Построить план',
                      subtitle: 'AI соберёт стратегию',
                      icon: Icons.rocket_launch_rounded,
                      color: AurixTokens.accent,
                      onTap: () => context.push('/stats/release-plan'),
                    )),
                    const SizedBox(width: 12),
                    Expanded(child: _ActionButton(
                      label: 'Промо идеи',
                      subtitle: 'Что снять прямо сейчас',
                      icon: Icons.local_fire_department_rounded,
                      color: AurixTokens.orange,
                      onTap: () => context.push('/stats/promo-ideas'),
                    )),
                  ],
                ),
              ),
            ),
          ),

          // Chart
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 0),
              child: _FadeSlide(
                controller: _entryCtrl, delay: 0.45,
                child: _StreamChart(series: series),
              ),
            ),
          ),

          // Releases
          if (releases.isNotEmpty) ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 28, 20, 0),
                child: _FadeSlide(
                  controller: _entryCtrl, delay: 0.5,
                  child: const Text('ТВОИ РЕЛИЗЫ', style: TextStyle(
                    color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
                  )),
                ),
              ),
            ),
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
              sliver: SliverList.builder(
                itemCount: releases.length,
                itemBuilder: (ctx, i) => _FadeSlide(
                  controller: _entryCtrl,
                  delay: 0.55 + i * 0.04,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _ReleaseRow(release: releases[i]),
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  static String _formatNumber(int n) {
    if (n >= 1000000) return '${(n / 1000000).toStringAsFixed(1)}M';
    if (n >= 1000) return '${(n / 1000).toStringAsFixed(1)}K';
    return n.toString();
  }
}

// ── DIAGNOSIS CARD ──────────────────────────────────────────

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
            : AurixTokens.orange;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: borderColor.withValues(alpha: 0.3)),
        boxShadow: [BoxShadow(color: borderColor.withValues(alpha: 0.08), blurRadius: 20, spreadRadius: -4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Problem
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(isPositive ? '✅' : isCritical ? '🚨' : '🔥', style: const TextStyle(fontSize: 18)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(problem, style: TextStyle(
                  color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700, height: 1.3,
                )),
              ),
            ],
          ),

          // Cause
          if (cause.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Text(cause, style: TextStyle(
                color: AurixTokens.muted.withValues(alpha: 0.7), fontSize: 12, height: 1.4,
              )),
            ),

          const SizedBox(height: 14),

          // Fix
          if (fix.isNotEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AurixTokens.accent.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.12)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('💡', style: TextStyle(fontSize: 14)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(fix, style: const TextStyle(
                      color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500, height: 1.4,
                    )),
                  ),
                ],
              ),
            ),

          // Effect
          if (effect.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('🚀', style: TextStyle(fontSize: 12)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(effect, style: TextStyle(
                      color: AurixTokens.positive.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w600, height: 1.4,
                    )),
                  ),
                ],
              ),
            ),

          // Action button
          if (!isPositive)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Row(
                children: [
                  _MiniAction(
                    label: 'Сделать это',
                    icon: Icons.check_circle_outline_rounded,
                    color: AurixTokens.accent,
                    onTap: () => context.push('/stats/release-plan'),
                  ),
                  const SizedBox(width: 10),
                  _MiniAction(
                    label: 'Промо-план от AI',
                    icon: Icons.auto_awesome,
                    color: AurixTokens.orange,
                    onTap: () => context.push('/stats/promo-ideas'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ── Mini Action ──────────────────────────────────────────────

class _MiniAction extends StatelessWidget {
  const _MiniAction({required this.label, required this.icon, required this.color, required this.onTap});
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 14, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

// ── KPI Card ─────────────────────────────────────────────────

class _KpiCard extends StatelessWidget {
  const _KpiCard({
    required this.label, required this.value,
    required this.icon, required this.glowColor,
    this.change, this.suffix,
  });
  final String label, value;
  final IconData icon;
  final Color glowColor;
  final int? change;
  final String? suffix;

  @override
  Widget build(BuildContext context) {
    final w = (MediaQuery.sizeOf(context).width - 52) / 2;
    return Container(
      width: w.clamp(140, 220),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: glowColor.withValues(alpha: 0.2)),
        boxShadow: [BoxShadow(color: glowColor.withValues(alpha: 0.08), blurRadius: 24, spreadRadius: -4)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 16, color: glowColor.withValues(alpha: 0.7)),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1)),
          ]),
          const SizedBox(height: 10),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 26, fontWeight: FontWeight.w800, height: 1)),
            if (suffix != null) ...[
              const SizedBox(width: 4),
              Padding(
                padding: const EdgeInsets.only(bottom: 2),
                child: Text(suffix!, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
              ),
            ],
          ]),
          if (change != null) ...[
            const SizedBox(height: 6),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: (change! >= 0 ? AurixTokens.positive : AurixTokens.danger).withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                '${change! >= 0 ? '↑' : '↓'} ${change!.abs()}%',
                style: TextStyle(
                  color: change! >= 0 ? AurixTokens.positive : AurixTokens.danger,
                  fontSize: 11, fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// ── Stream Chart ─────────────────────────────────────────────

class _StreamChart extends StatelessWidget {
  const _StreamChart({required this.series});
  final List<Map<String, dynamic>> series;

  @override
  Widget build(BuildContext context) {
    if (series.isEmpty) {
      return Container(
        height: 160,
        decoration: BoxDecoration(
          color: AurixTokens.bg1, borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.border),
        ),
        child: const Center(child: Text('Данных пока нет — выпусти трек', style: TextStyle(color: AurixTokens.muted, fontSize: 13))),
      );
    }

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('СТРИМЫ ЗА 30 ДНЕЙ', style: TextStyle(
            color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1,
          )),
          const SizedBox(height: 16),
          SizedBox(
            height: 120,
            child: CustomPaint(
              size: Size.infinite,
              painter: _ChartPainter(
                values: series.map((s) => (s['streams'] as int? ?? 0).toDouble()).toList(),
                lineColor: AurixTokens.accent,
                glowColor: AurixTokens.accent.withValues(alpha: 0.15),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(_shortDay(series.first['day']?.toString() ?? ''), style: _axisStyle),
              Text(_shortDay(series[series.length ~/ 2]['day']?.toString() ?? ''), style: _axisStyle),
              Text(_shortDay(series.last['day']?.toString() ?? ''), style: _axisStyle),
            ],
          ),
        ],
      ),
    );
  }

  static String _shortDay(String iso) => iso.length >= 10 ? iso.substring(5, 10) : iso;
  static const _axisStyle = TextStyle(color: AurixTokens.muted, fontSize: 10);
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

    canvas.drawPath(fillPath, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [glowColor, glowColor.withValues(alpha: 0)],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    canvas.drawPath(path, Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);
  }

  @override
  bool shouldRepaint(covariant _ChartPainter old) => old.values != values;
}

// ── Release Row ──────────────────────────────────────────────

class _ReleaseRow extends StatelessWidget {
  const _ReleaseRow({required this.release});
  final Map<String, dynamic> release;

  @override
  Widget build(BuildContext context) {
    final title = release['title']?.toString() ?? '';
    final streams = release['streams'] as int? ?? 0;
    final revenue = (release['revenue'] as num?)?.toDouble() ?? 0;
    final clicks = release['clicks'] as int? ?? 0;
    final genre = release['genre']?.toString() ?? '';

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Row(children: [
        Container(
          width: 42, height: 42,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: LinearGradient(
              colors: [AurixTokens.accent.withValues(alpha: 0.2), AurixTokens.orange.withValues(alpha: 0.1)],
            ),
          ),
          child: const Icon(Icons.music_note_rounded, color: AurixTokens.accent, size: 20),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
            if (genre.isNotEmpty) Text(genre, style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          ],
        )),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text('$streams стр.', style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('${revenue.toStringAsFixed(0)} ₽ · $clicks кл.', style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
          ],
        ),
      ]),
    );
  }
}

// ── Action Button ────────────────────────────────────────────

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.label, required this.subtitle,
    required this.icon, required this.color, required this.onTap,
  });
  final String label, subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 14),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.2)),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.06), blurRadius: 16)],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: color),
            const SizedBox(height: 10),
            Text(label, style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700)),
            const SizedBox(height: 2),
            Text(subtitle, style: TextStyle(color: color.withValues(alpha: 0.5), fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

// ── FadeSlide ────────────────────────────────────────────────

class _FadeSlide extends StatelessWidget {
  const _FadeSlide({required this.controller, required this.delay, required this.child});
  final AnimationController controller;
  final double delay;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: controller,
      curve: Interval(delay.clamp(0, 0.9), (delay + 0.3).clamp(0, 1), curve: Curves.easeOutCubic),
    );
    return AnimatedBuilder(
      animation: curved,
      builder: (_, __) => Opacity(
        opacity: curved.value,
        child: Transform.translate(
          offset: Offset(0, 20 * (1 - curved.value)),
          child: child,
        ),
      ),
    );
  }
}
