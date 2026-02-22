import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';

/// Вкладка «История роста» — график индекса и рейтинга.
class IndexGrowthHistoryTab extends ConsumerWidget {
  const IndexGrowthHistoryTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(indexProvider);
    final data = state.data;
    if (data == null) return const SizedBox.shrink();

    final score = data.selectedScore;
    final padding = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint ? 24.0 : 16.0;

    // Мок-история: 6 месяцев назад → сейчас (на основе текущего score и trendDelta)
    final now = DateTime.now();
    final history = _buildMockHistory(score, now);

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'История роста',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AurixTokens.text,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            'Динамика индекса за последние месяцы',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          AurixGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (history.isNotEmpty) ...[
                  SizedBox(
                    height: 180,
                    child: _SparklineChart(data: history),
                  ),
                  const SizedBox(height: 16),
                  Wrap(
                    spacing: 24,
                    runSpacing: 8,
                    children: history.asMap().entries.map((e) {
                      final m = e.value.month;
                      final lbl = _monthLabel(m);
                      return Text(
                        lbl,
                        style: TextStyle(
                          color: AurixTokens.muted,
                          fontSize: 12,
                        ),
                      );
                    }).toList(),
                  ),
                ] else
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 40),
                      child: Text(
                        'Недостаточно данных',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (score != null) ...[
            const SizedBox(height: 24),
            _RankHistoryCard(score: score),
          ],
        ],
      ),
    );
  }

  static List<_HistoryPoint> _buildMockHistory(IndexScore? score, DateTime now) {
    if (score == null) return [];
    final points = <_HistoryPoint>[];
    var s = score.score - score.trendDelta;
    for (var i = 5; i >= 0; i--) {
      final d = DateTime(now.year, now.month - i, 1);
      if (i == 0) s = score.score;
      else s = (s + (score.trendDelta / 5)).round().clamp(0, 999);
      points.add(_HistoryPoint(month: d, score: s));
    }
    return points;
  }

  static String _monthLabel(DateTime d) {
    const months = ['Янв', 'Фев', 'Мар', 'Апр', 'Май', 'Июн', 'Июл', 'Авг', 'Сен', 'Окт', 'Ноя', 'Дек'];
    return '${months[d.month - 1]} ${d.year.toString().substring(2)}';
  }
}

class _HistoryPoint {
  final DateTime month;
  final int score;

  _HistoryPoint({required this.month, required this.score});
}

class _SparklineChart extends StatelessWidget {
  final List<_HistoryPoint> data;

  const _SparklineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final values = data.map((e) => e.score.toDouble()).toList();
    final minY = values.reduce(math.min) * 0.9;
    final maxY = values.reduce(math.max) * 1.1;
    final range = (maxY - minY).clamp(1.0, double.infinity);
    final padding = const EdgeInsets.only(top: 8, bottom: 8, left: 8, right: 8);

    return LayoutBuilder(
      builder: (ctx, constraints) {
        final w = constraints.maxWidth - padding.horizontal;
        final h = constraints.maxHeight - padding.vertical;
        final step = data.length > 1 ? w / (data.length - 1) : 0.0;
        final path = Path();
        for (var i = 0; i < data.length; i++) {
          final x = padding.left + i * step;
          final y = padding.top + h - (values[i] - minY) / range * h;
          if (i == 0) {
            path.moveTo(x, y);
          } else {
            path.lineTo(x, y);
          }
        }
        return CustomPaint(
          size: Size(constraints.maxWidth, constraints.maxHeight),
          painter: _SparklinePainter(path: path, color: AurixTokens.orange),
        );
      },
    );
  }
}

class _SparklinePainter extends CustomPainter {
  final Path path;
  final Color color;

  _SparklinePainter({required this.path, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawPath(
      path,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _RankHistoryCard extends StatelessWidget {
  final IndexScore score;

  const _RankHistoryCard({required this.score});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Текущая позиция', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Text(
                '#${score.rankOverall}',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.orange,
                    ),
              ),
            ],
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('Динамика за месяц', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    score.trendDelta >= 0 ? Icons.trending_up_rounded : Icons.trending_down_rounded,
                    size: 20,
                    color: score.trendDelta >= 0 ? AurixTokens.orange : AurixTokens.muted,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '${score.trendDelta >= 0 ? '+' : ''}${score.trendDelta}',
                    style: TextStyle(
                      color: score.trendDelta >= 0 ? AurixTokens.orange : AurixTokens.muted,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
