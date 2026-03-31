import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
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
        savesText = '\u041d\u0435\u0442 \u0434\u0430\u043d\u043d\u044b\u0445',
        points = const [];

  final bool hasData;
  final int streams;
  final String savesText;
  final List<double> points;
}

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
          Row(
            children: [
              const HomeSectionTitle('\u0410\u043d\u0430\u043b\u0438\u0442\u0438\u043a\u0430', icon: Icons.insights_rounded),
              const Spacer(),
              _OpenButton(onTap: onOpenAnalytics),
            ],
          ),
          const SizedBox(height: 14),
          if (!analytics.hasData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
              decoration: BoxDecoration(
                color: AurixTokens.surface1.withValues(alpha: 0.5),
                borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                border: Border.all(color: AurixTokens.stroke(0.1)),
              ),
              child: Column(
                children: [
                  Icon(Icons.bar_chart_rounded, size: 28, color: AurixTokens.micro),
                  const SizedBox(height: 8),
                  Text(
                    '\u0414\u0430\u043d\u043d\u044b\u0445 \u043f\u043e \u0434\u0438\u043d\u0430\u043c\u0438\u043a\u0435 \u043f\u043e\u043a\u0430 \u043d\u0435\u0442',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      color: AurixTokens.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '\u0417\u0430\u0433\u0440\u0443\u0437\u0438\u0442\u0435 \u043e\u0442\u0447\u0451\u0442\u044b, \u0447\u0442\u043e\u0431\u044b \u0443\u0432\u0438\u0434\u0435\u0442\u044c \u0442\u0440\u0435\u043d\u0434.',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      color: AurixTokens.micro,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            )
          else ...[
            SizedBox(
              height: 80,
              child: CustomPaint(
                painter: _MiniChartPainter(points: analytics.points),
                size: const Size(double.infinity, 80),
              ),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: HomeMetricTile(
                  title: '\u041f\u0440\u043e\u0441\u043b\u0443\u0448\u0438\u0432\u0430\u043d\u0438\u044f',
                  value: NumberFormat.compact(locale: 'ru').format(analytics.streams),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HomeMetricTile(
                  title: '\u0421\u043e\u0445\u0440\u0430\u043d\u0435\u043d\u0438\u044f',
                  value: analytics.savesText,
                ),
              ),
            ],
          ),
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
                '\u041e\u0442\u043a\u0440\u044b\u0442\u044c',
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: _hovered ? AurixTokens.text : AurixTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_forward_rounded,
                size: 13,
                color: _hovered ? AurixTokens.text : AurixTokens.muted,
              ),
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
    final value = NumberFormat.compactCurrency(
      locale: 'ru',
      symbol: '\u20bd',
      decimalDigits: 1,
    ).format(revenue);
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
                Text(
                  '\u0414\u043e\u0445\u043e\u0434 \u0437\u0430 \u043c\u0435\u0441\u044f\u0446',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: AurixTokens.muted,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w700,
                    fontSize: 24,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
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
        // Smooth curve between points
        final prevX = (i - 1) * step;
        final prevY = size.height - ((points[i - 1] / max) * (size.height - 8)) - 4;
        final midX = (prevX + x) / 2;
        path.cubicTo(midX, prevY, midX, y, x, y);
      }
    }

    // Gradient fill under curve
    final fillPath = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          AurixTokens.accent.withValues(alpha: 0.12),
          AurixTokens.accent.withValues(alpha: 0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));
    canvas.drawPath(fillPath, fillPaint);

    // Glow line
    final glow = Paint()
      ..color = AurixTokens.accent.withValues(alpha: 0.15)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 6
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8);
    canvas.drawPath(path, glow);

    // Main line
    final line = Paint()
      ..color = AurixTokens.accent
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, line);

    // End dot
    if (points.isNotEmpty) {
      final lastX = (points.length - 1) * step;
      final lastY = size.height - ((points.last / max) * (size.height - 8)) - 4;
      canvas.drawCircle(
        Offset(lastX, lastY),
        3.5,
        Paint()..color = AurixTokens.accent,
      );
      canvas.drawCircle(
        Offset(lastX, lastY),
        6,
        Paint()
          ..color = AurixTokens.accent.withValues(alpha: 0.2)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) => oldDelegate.points != points;
}
