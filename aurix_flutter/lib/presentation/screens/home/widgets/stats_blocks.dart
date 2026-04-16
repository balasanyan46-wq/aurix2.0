import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/notification_providers.dart';
import 'home_shared.dart';

class AnalyticsViewModel {
  const AnalyticsViewModel({
    required this.hasData,
    required this.streams,
    required this.savesText,
    required this.points,
  });

  const AnalyticsViewModel.empty()
      : hasData = false,
        streams = 0,
        savesText = 'Нет данных',
        points = const [];

  final bool hasData;
  final int streams;
  final String savesText;
  final List<double> points;
}

/// Top KPI metrics row — 3-4 compact cards.
class KpiMetricsRow extends StatelessWidget {
  const KpiMetricsRow({
    super.key,
    required this.totalReleases,
    required this.liveReleases,
    required this.streams,
    required this.revenue,
  });

  final int totalReleases;
  final int liveReleases;
  final int streams;
  final double revenue;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final cards = [
      _KpiCard(
        icon: Icons.album_rounded,
        color: AurixTokens.accent,
        label: 'Релизы',
        value: '$liveReleases',
        sub: 'из $totalReleases',
      ),
      _KpiCard(
        icon: Icons.headphones_rounded,
        color: AurixTokens.aiAccent,
        label: 'Стримы',
        value: NumberFormat.compact(locale: 'ru').format(streams),
        sub: 'за 7 дней',
      ),
      _KpiCard(
        icon: Icons.account_balance_wallet_rounded,
        color: AurixTokens.positive,
        label: 'Доход',
        value: NumberFormat.compactCurrency(locale: 'ru', symbol: '₽', decimalDigits: 0).format(revenue),
        sub: 'за месяц',
      ),
    ];

    if (isMobile) {
      return Row(
        children: cards
            .map((c) => Expanded(child: c))
            .expand((w) => [w, const SizedBox(width: 10)])
            .toList()
          ..removeLast(),
      );
    }
    return Row(
      children: cards
          .map((c) => Expanded(child: c))
          .expand((w) => [w, const SizedBox(width: 12)])
          .toList()
        ..removeLast(),
    );
  }
}

class _KpiCard extends StatefulWidget {
  const _KpiCard({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    required this.sub,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final String sub;

  @override
  State<_KpiCard> createState() => _KpiCardState();
}

class _KpiCardState extends State<_KpiCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: AurixTokens.dMedium,
        curve: AurixTokens.cEase,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _hovered ? widget.color.withValues(alpha: 0.08) : AurixTokens.bg1,
              AurixTokens.bg1.withValues(alpha: 0.95),
            ],
          ),
          border: Border.all(
            color: _hovered ? widget.color.withValues(alpha: 0.25) : AurixTokens.stroke(0.12),
          ),
          boxShadow: _hovered
              ? [BoxShadow(color: widget.color.withValues(alpha: 0.1), blurRadius: 24, offset: const Offset(0, 8))]
              : null,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    color: widget.color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: widget.color.withValues(alpha: 0.15)),
                  ),
                  child: Icon(widget.icon, size: 16, color: widget.color),
                ),
                const SizedBox(width: 10),
                Text(
                  widget.label.toUpperCase(),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.muted,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              widget.value,
              style: TextStyle(
                fontFamily: AurixTokens.fontMono,
                color: AurixTokens.text,
                fontSize: 26,
                fontWeight: FontWeight.w800,
                fontFeatures: const [FontFeature.tabularFigures()],
                height: 1,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              widget.sub,
              style: TextStyle(
                fontFamily: AurixTokens.fontBody,
                color: AurixTokens.micro,
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Analytics card with mini chart.
class AnalyticsBlock extends StatelessWidget {
  const AnalyticsBlock({super.key, required this.analytics, required this.onOpenAnalytics});

  final AnalyticsViewModel analytics;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeSectionTitle('Динамика', icon: Icons.insights_rounded, trailing: _OpenButton(onTap: onOpenAnalytics)),
          const SizedBox(height: 14),
          if (!analytics.hasData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              decoration: BoxDecoration(
                color: AurixTokens.surface1.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                border: Border.all(color: AurixTokens.stroke(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 28, color: AurixTokens.micro),
                  const SizedBox(height: 8),
                  Text('Данных пока нет', style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.muted, fontSize: 13)),
                  const SizedBox(height: 4),
                  Text('Загрузите отчёты для аналитики', style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.micro, fontSize: 12)),
                ],
              ),
            )
          else
            SizedBox(
              height: 80,
              child: CustomPaint(
                painter: _MiniChartPainter(points: analytics.points),
                size: const Size(double.infinity, 80),
              ),
            ),
        ],
      ),
    );
  }
}

/// Recent notifications block.
class RecentNotificationsBlock extends ConsumerWidget {
  const RecentNotificationsBlock({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifs = ref.watch(notificationsProvider).valueOrNull ?? [];
    final recent = notifs.take(3).toList();

    if (recent.isEmpty) return const SizedBox.shrink();

    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HomeSectionTitle('Уведомления', icon: Icons.notifications_rounded),
          const SizedBox(height: 12),
          ...recent.map((n) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(top: 6),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: n.isRead ? AurixTokens.micro : AurixTokens.accent,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            n.title,
                            style: TextStyle(
                              color: AurixTokens.text,
                              fontSize: 13,
                              fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w600,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          Text(
                            n.message,
                            style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _OpenButton extends StatefulWidget {
  const _OpenButton({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_OpenButton> createState() => _OpenButtonState();
}

class _OpenButtonState extends State<_OpenButton> {
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
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: _hovered ? AurixTokens.glass(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: _hovered ? AurixTokens.stroke(0.2) : AurixTokens.stroke(0.12),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Открыть',
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: _hovered ? AurixTokens.text : AurixTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_forward_rounded, size: 13, color: _hovered ? AurixTokens.text : AurixTokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

class FinanceBlock extends StatelessWidget {
  const FinanceBlock({super.key, required this.revenue, required this.onOpen});
  final double revenue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final value = NumberFormat.compactCurrency(locale: 'ru', symbol: '₽', decimalDigits: 1).format(revenue);
    return HomeSectionCard(
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AurixTokens.positive.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.15)),
            ),
            child: const Icon(Icons.account_balance_wallet_rounded, size: 20, color: AurixTokens.positive),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Доход за месяц', style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(value, style: TextStyle(fontFamily: AurixTokens.fontMono, color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 24, fontFeatures: AurixTokens.tabularFigures)),
              ],
            ),
          ),
          _OpenButton(onTap: onOpen),
        ],
      ),
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  const _MiniChartPainter({required this.points});
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || points.every((p) => p <= 0)) return;
    final max = points.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return;

    final path = Path();
    final step = size.width / (points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - ((points[i] / max) * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final prevX = (i - 1) * step;
        final prevY = size.height - ((points[i - 1] / max) * (size.height - 8)) - 4;
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [AurixTokens.accent.withValues(alpha: 0.12), AurixTokens.accent.withValues(alpha: 0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    final glow = Paint()
      ..color = AurixTokens.accent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glow);

    final line = Paint()
      ..color = AurixTokens.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);

    if (points.isNotEmpty) {
      final lastX = (points.length - 1) * step;
      final lastY = size.height - ((points.last / max) * (size.height - 8)) - 4;
      canvas.drawCircle(Offset(lastX, lastY), 3.5, Paint()..color = AurixTokens.accent);
      canvas.drawCircle(Offset(lastX, lastY), 6, Paint()..color = AurixTokens.accent.withValues(alpha: 0.2)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4));
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) => oldDelegate.points != points;
}
