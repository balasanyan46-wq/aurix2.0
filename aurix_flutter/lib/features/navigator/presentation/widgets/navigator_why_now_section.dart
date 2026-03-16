import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/navigator/data/navigator_models.dart';

class NavigatorWhyNowSection extends StatelessWidget {
  const NavigatorWhyNowSection({
    super.key,
    required this.answers,
    required this.explanation,
    this.nextStepTitle,
  });

  final NavigatorOnboardingAnswers? answers;
  final String explanation;
  final String? nextStepTitle;

  @override
  Widget build(BuildContext context) {
    final a = answers;
    return AurixGlassCard(
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Почему AURIX рекомендует именно это',
            style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            explanation,
            style: const TextStyle(color: AurixTokens.textSecondary, height: 1.4),
          ),
          if (nextStepTitle != null && nextStepTitle!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Поэтому маршрут начинается с шага: $nextStepTitle',
              style: const TextStyle(
                color: AurixTokens.muted,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (a != null)
            Text(
              'Этап: ${a.stage} · Цель: ${a.goal} · Блокер: ${a.blocker}',
              style: const TextStyle(
                color: AurixTokens.muted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
        ],
      ),
    );
  }
}
