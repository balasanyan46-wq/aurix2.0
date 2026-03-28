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
        savesText = 'Нет данных',
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
              const HomeSectionTitle('Аналитика'),
              const Spacer(),
              TextButton(onPressed: onOpenAnalytics, child: const Text('Открыть')),
            ],
          ),
          const SizedBox(height: 8),
          if (!analytics.hasData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AurixTokens.glass(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AurixTokens.stroke(0.16)),
              ),
              child: const Text(
                'Данных по динамике пока нет. Загрузите отчёты, чтобы увидеть тренд.',
                style: TextStyle(
                  color: AurixTokens.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 90,
              child: CustomPaint(
                painter: _MiniChartPainter(points: analytics.points),
                size: const Size(double.infinity, 90),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: HomeMetricTile(
                  title: 'Прослушивания',
                  value: NumberFormat.compact(locale: 'ru').format(analytics.streams),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: HomeMetricTile(
                  title: 'Сохранения',
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

class FinanceBlock extends StatelessWidget {
  const FinanceBlock({super.key, required this.revenue, required this.onOpen});
  final double revenue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final value = NumberFormat.compactCurrency(
      locale: 'ru',
      symbol: '₽',
      decimalDigits: 1,
    ).format(revenue);
    return HomeSectionCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const HomeSectionTitle('Финансы'),
                const SizedBox(height: 6),
                const Text(
                  'Доход за месяц',
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Перейти'),
          ),
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
        path.lineTo(x, y);
      }
    }

    final glow = Paint()
      ..color = AurixTokens.orange.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final line = Paint()
      ..color = AurixTokens.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) => oldDelegate.points != points;
}
