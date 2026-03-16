import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorHeroSection extends StatelessWidget {
  const NavigatorHeroSection({
    super.key,
    required this.answers,
    required this.nextStep,
    required this.estimatedMinutes,
    required this.hasRouteProfile,
    required this.onBuildRoute,
    required this.onContinueRoute,
    required this.onRebuildRoute,
    required this.onOpenLibrary,
  });

  final NavigatorOnboardingAnswers? answers;
  final NavigatorRecommendationCard? nextStep;
  final int estimatedMinutes;
  final bool hasRouteProfile;
  final VoidCallback onBuildRoute;
  final VoidCallback onContinueRoute;
  final VoidCallback onRebuildRoute;
  final VoidCallback onOpenLibrary;

  @override
  Widget build(BuildContext context) {
    final stage = answers?.stage ?? 'не определен';
    final goal = answers?.goal ?? 'не определена';
    final blocker = answers?.blocker ?? 'пока не выявлено';
    final next = nextStep?.material.title ?? 'Собери маршрут и получи next best step';
    return LayoutBuilder(
      builder: (context, c) {
        final desktop = c.maxWidth >= 900;
        return AurixGlassCard(
          radius: 24,
          padding: EdgeInsets.all(desktop ? 22 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.35)),
                ),
                child: const Text(
                  'AI-НАВИГАЦИЯ ПО РОСТУ',
                  style: TextStyle(
                    color: AurixTokens.orange,
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.8,
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Навигатор артиста',
                style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: desktop ? 40 : 30,
                  fontWeight: FontWeight.w800,
                  height: 1.08,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                hasRouteProfile
                    ? 'AURIX учитывает твой этап, цель и блокер, чтобы вести по конкретному маршруту роста, а не перегружать материалами.'
                    : 'Внутри не просто статьи: AURIX соберет персональный маршрут и подскажет следующий лучший шаг под твою ситуацию.',
                style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: desktop ? 10 : 8,
                runSpacing: desktop ? 10 : 8,
                children: [
                  _insightTile('Твой этап', stage, desktop),
                  _insightTile('Твоя цель', goal, desktop),
                  _insightTile('Точка роста', blocker, desktop),
                  _insightTile('Следующий шаг', next, desktop),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'Ориентировочное время маршрута: ~$estimatedMinutes минут',
                style: const TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: onBuildRoute,
                    icon: const Icon(Icons.auto_awesome_rounded),
                    label: const Text('Собрать мой маршрут'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onContinueRoute,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Продолжить маршрут'),
                  ),
                  OutlinedButton.icon(
                    onPressed: hasRouteProfile ? onRebuildRoute : onBuildRoute,
                    icon: const Icon(Icons.refresh_rounded),
                    label: const Text('Пересобрать маршрут'),
                  ),
                  OutlinedButton.icon(
                    onPressed: onOpenLibrary,
                    icon: const Icon(Icons.library_books_rounded),
                    label: const Text('Открыть библиотеку'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _insightTile(String label, String value, bool desktop) {
    return Container(
      width: desktop ? 230 : 190,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.07),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AurixTokens.muted,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
