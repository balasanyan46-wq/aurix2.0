import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';
import 'package:aurix_flutter/features/navigator/presentation/navigator_controller.dart';

class NavigatorResultsScreen extends ConsumerWidget {
  const NavigatorResultsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(navigatorControllerProvider);
    final rec = state.recommendations;
    final answers = state.answers;
    final pad = horizontalPadding(context);
    if (state.loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (rec == null || answers == null) {
      return Center(
        child: AurixGlassCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'AI-профиль еще не собран',
                style: TextStyle(
                  color: AurixTokens.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 20,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Пройди AI-настройку, и AURIX покажет, что изучать в первую очередь именно тебе.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AurixTokens.textSecondary),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => context.go('/navigator/ai-intake'),
                child: const Text('Начать AI-настройку'),
              ),
            ],
          ),
        ),
      );
    }

    final recommended = rec.topRequired.followedBy(rec.topAdditional).take(6).toList();
    final skipNow = _skipNow(answers, recommended);

    return ListView(
      padding: EdgeInsets.fromLTRB(pad, 16, pad, 28),
      children: [
        const Text(
          'Твой AI-образовательный профиль',
          style: TextStyle(
            color: AurixTokens.text,
            fontWeight: FontWeight.w900,
            fontSize: 30,
          ),
        ),
        const SizedBox(height: 8),
        const Text(
          'Короткая интерпретация твоего контекста и подборка материалов, которые дадут максимум смысла на текущем этапе.',
          style: TextStyle(color: AurixTokens.textSecondary, height: 1.4),
        ),
        const SizedBox(height: 12),
        AurixGlassCard(
          radius: 18,
          padding: const EdgeInsets.all(14),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill('Этап: ${answers.stage}'),
              _pill('Цель: ${answers.goal}'),
              _pill('Блокер: ${answers.blocker}'),
              if (answers.confusionArea.isNotEmpty) _pill('Фокус: ${answers.confusionArea}'),
              if (answers.learningHoursPerWeek.isNotEmpty) _pill('Время в неделю: ${answers.learningHoursPerWeek}'),
            ],
          ),
        ),
        const SizedBox(height: 14),
        if (skipNow.isNotEmpty)
          AurixGlassCard(
            radius: 16,
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Что пока не трогать',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  skipNow,
                  style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4),
                ),
              ],
            ),
          ),
        const SizedBox(height: 14),
        const Text(
          'Подобрано для тебя',
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: 22,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...recommended.map(
          (card) => Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _Card(card: card),
          ),
        ),
        const SizedBox(height: 12),
        AurixGlassCard(
          radius: 16,
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Фокус на ближайшие 7 дней',
                style: TextStyle(
                  color: AurixTokens.text,
                  fontWeight: FontWeight.w800,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                rec.nextBestStep.personalReason.isNotEmpty
                    ? rec.nextBestStep.personalReason
                    : rec.nextBestStep.whyNow,
                style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4),
              ),
              const SizedBox(height: 10),
              FilledButton(
                onPressed: () => context.push('/navigator/article/${rec.nextBestStep.material.slug}'),
                child: const Text('Открыть главный материал недели'),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _skipNow(
    NavigatorOnboardingAnswers answers,
    List<NavigatorRecommendationCard> selected,
  ) {
    final selectedCats = selected.map((e) => e.material.category).toSet();
    final out = <String>[];
    if (!selectedCats.contains(NavigatorClusters.yandexMusic) &&
        !selectedCats.contains(NavigatorClusters.vkMusic)) {
      out.add('Глубокий разбор платформ оставь на второй этап, сначала собери базовую систему роста.');
    }
    if (answers.goal.contains('релиз') && !selectedCats.contains('Монетизация и direct-to-fan')) {
      out.add('Монетизацию не форсируй до стабилизации релизного цикла.');
    }
    return out.join(' ');
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AurixTokens.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Card extends ConsumerWidget {
  const _Card({required this.card});

  final NavigatorRecommendationCard card;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ctrl = ref.read(navigatorControllerProvider.notifier);
    final m = card.material;
    return AurixGlassCard(
      radius: 16,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _pill(NavigatorClusters.label(m.category)),
              _pill('${m.readingTimeMinutes} мин'),
              _pill(m.difficulty),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            m.title,
            style: const TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 18,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            m.excerpt,
            style: const TextStyle(color: AurixTokens.textSecondary, height: 1.35),
          ),
          const SizedBox(height: 8),
          Text(
            'Почему тебе это важно: ${card.personalReason.isNotEmpty ? card.personalReason : card.whyNow}',
            style: const TextStyle(
              color: AurixTokens.muted,
              fontWeight: FontWeight.w600,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: () {
              ctrl.markOpened(m.id);
              context.push('/navigator/article/${m.slug}');
            },
            child: const Text('Читать'),
          ),
        ],
      ),
    );
  }

  Widget _pill(String text) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.1),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AurixTokens.textSecondary,
          fontWeight: FontWeight.w700,
          fontSize: 11,
        ),
      ),
    );
  }
}
