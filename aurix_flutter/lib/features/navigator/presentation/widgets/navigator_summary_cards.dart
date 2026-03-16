import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

class NavigatorSummaryCards extends StatelessWidget {
  const NavigatorSummaryCards({
    super.key,
    required this.routeDone,
    required this.routeTotal,
    required this.completedMaterials,
    required this.savedMaterials,
    required this.currentStage,
    required this.nextStage,
  });

  final int routeDone;
  final int routeTotal;
  final int completedMaterials;
  final int savedMaterials;
  final String currentStage;
  final String nextStage;

  @override
  Widget build(BuildContext context) {
    final progress = routeTotal == 0 ? 0.0 : routeDone / routeTotal;
    final isDesktop = MediaQuery.sizeOf(context).width >= 900;
    return AurixGlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Прогресс маршрута',
            style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: AurixTokens.glass(0.12),
              valueColor: const AlwaysStoppedAnimation(AurixTokens.orange),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Маршрут: $routeDone из $routeTotal шагов',
            style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _mini('Пройдено', '$completedMaterials материалов', isDesktop: isDesktop),
              _mini('Сохранено', '$savedMaterials материалов', isDesktop: isDesktop),
              _mini('Текущий этап', currentStage, isDesktop: isDesktop),
              _mini('Следующий этап', nextStage, isDesktop: isDesktop),
            ],
          ),
        ],
      ),
    );
  }

  Widget _mini(String k, String v, {required bool isDesktop}) {
    return Container(
      width: isDesktop ? 190 : 160,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(k, style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          const SizedBox(height: 4),
          Text(v,
              style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 13,
                  fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
