import 'package:aurix_flutter/data/models/release_aai_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class ReleaseAaiBlock extends StatelessWidget {
  final AsyncValue<ReleaseAaiModel?> aaiAsync;
  final AsyncValue<List<DnkAaiHint>>? dnkHintsAsync;
  const ReleaseAaiBlock({super.key, required this.aaiAsync, this.dnkHintsAsync});

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(18),
      child: aaiAsync.when(
        data: (aai) {
          if (aai == null) {
            return Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AurixTokens.aiAccent.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.insights_rounded, size: 20, color: AurixTokens.aiAccent),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AURIX Attention Index',
                        style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Появится после первых переходов по смарт-ссылке',
                        style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.8), fontSize: 12.5),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AurixTokens.aiAccent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.insights_rounded, size: 18, color: AurixTokens.aiAccent),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Text(
                      'AURIX Attention Index',
                      style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 15),
                    ),
                  ),
                  _scorePill(aai.totalScore, aai.statusLabel),
                ],
              ),
              const SizedBox(height: 14),
              _trend(aai.trend),
              const SizedBox(height: 14),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _metricTile('Импульс', aai.impulseScore.toStringAsFixed(1)),
                  _metricTile('Конверсия', aai.conversionScore.toStringAsFixed(1)),
                  _metricTile('Вовлечённость', aai.engagementScore.toStringAsFixed(1)),
                  _metricTile('География', aai.geographyScore.toStringAsFixed(1)),
                ],
              ),
              const SizedBox(height: 14),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: _bucketList(title: 'Платформы', items: aai.platforms.take(4).toList())),
                  const SizedBox(width: 10),
                  Expanded(child: _bucketList(title: 'География', items: aai.countries.take(4).toList())),
                ],
              ),
              if (dnkHintsAsync != null) ...[
                const SizedBox(height: 14),
                dnkHintsAsync!.when(
                  data: (hints) {
                    if (hints.isEmpty) return const SizedBox.shrink();
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AurixTokens.aiAccent.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Связка DNK × AAI',
                            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AurixTokens.aiGlow),
                          ),
                          const SizedBox(height: 8),
                          ...hints.map((h) {
                            final testTitle = _testTitle(h.testSlug);
                            final channel = h.expectedGrowthChannel.trim();
                            final note = h.notes.trim();
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: Text(
                                '• $testTitle${channel.isNotEmpty ? ' → $channel' : ''}${note.isNotEmpty ? ' — $note' : ''}',
                                style: const TextStyle(fontSize: 12, color: AurixTokens.textSecondary, height: 1.35),
                              ),
                            );
                          }),
                        ],
                      ),
                    );
                  },
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
              ],
            ],
          );
        },
        loading: () => const Column(
          children: [
            PremiumSkeletonBox(height: 16, width: 200),
            SizedBox(height: 12),
            PremiumSkeletonBox(height: 80),
          ],
        ),
        error: (_, __) => Row(
          children: [
            Icon(Icons.warning_amber_rounded, size: 18, color: AurixTokens.danger.withValues(alpha: 0.6)),
            const SizedBox(width: 8),
            const Text(
              'Не удалось загрузить AAI',
              style: TextStyle(color: AurixTokens.muted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _scorePill(double score, String status) {
    final color = score >= 80
        ? AurixTokens.danger
        : score >= 60
            ? AurixTokens.accent
            : score >= 40
                ? AurixTokens.warning
                : AurixTokens.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '${score.toStringAsFixed(1)} · $status',
        style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 11.5),
      ),
    );
  }

  Widget _metricTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: AurixTokens.muted)),
          const SizedBox(height: 3),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              fontSize: 15,
              color: AurixTokens.text,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }

  Widget _bucketList({required String title, required List<ReleaseAaiBucket> items}) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 12, color: AurixTokens.textSecondary)),
          const SizedBox(height: 6),
          if (items.isEmpty)
            const Text('Нет данных', style: TextStyle(color: AurixTokens.muted, fontSize: 12))
          else
            ...items.map(
              (e) => Padding(
                padding: const EdgeInsets.only(bottom: 3),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(e.key, style: const TextStyle(fontSize: 12, color: AurixTokens.text)),
                    ),
                    Text(
                      '${e.count}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AurixTokens.textSecondary,
                        fontWeight: FontWeight.w600,
                        fontFeatures: AurixTokens.tabularFigures,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _trend(List<ReleaseAaiPoint> points) {
    if (points.isEmpty || points.every((p) => p.value == 0)) {
      return Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.04),
          borderRadius: BorderRadius.circular(12),
        ),
        child: const Text(
          'Динамика появится после первых кликов',
          style: TextStyle(color: AurixTokens.muted, fontSize: 12.5),
        ),
      );
    }
    return SizedBox(
      height: 80,
      child: CustomPaint(
        size: const Size(double.infinity, 80),
        painter: _AaiTrendPainter(points: points, lineColor: AurixTokens.aiAccent),
      ),
    );
  }

  String _testTitle(String slug) => switch (slug) {
        'artist_archetype' => 'Архетип артиста',
        'tone_communication' => 'Тон коммуникации',
        'story_core' => 'Сюжетное ядро',
        'growth_profile' => 'Профиль роста',
        'discipline_index' => 'Индекс дисциплины',
        'career_risk' => 'Риск-профиль карьеры',
        _ => slug,
      };
}

class _AaiTrendPainter extends CustomPainter {
  final List<ReleaseAaiPoint> points;
  final Color lineColor;
  const _AaiTrendPainter({required this.points, required this.lineColor});

  @override
  void paint(Canvas canvas, Size size) {
    final maxVal = points.map((e) => e.value).fold<int>(1, (a, b) => a > b ? a : b);
    final step = points.length > 1 ? size.width / (points.length - 1) : size.width;
    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = step * i;
      final y = size.height - ((points[i].value / maxVal) * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final glow = Paint()
      ..color = lineColor.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final line = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _AaiTrendPainter oldDelegate) =>
      oldDelegate.points != points || oldDelegate.lineColor != lineColor;
}
