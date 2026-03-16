import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

class NavigatorOnboardingScreen extends StatelessWidget {
  const NavigatorOnboardingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final pad = horizontalPadding(context);
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(pad, 18, pad, 28),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: AurixGlassCard(
            radius: 22,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'AI-настройка Навигатора',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 30,
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'За 5-8 вопросов AURIX соберет персональный обучающий профиль: твой этап, цель, главный блокер и подборку материалов без лишнего шума.',
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 14),
                const Text(
                  'Что получишь после настройки:',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• 3 обязательных материала\n• 3 дополнительных материала\n• фокус на ближайшие 7 дней\n• список тем, которые пока не нужно трогать',
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    height: 1.45,
                  ),
                ),
                const SizedBox(height: 14),
                FilledButton.icon(
                  onPressed: () => context.go('/navigator/ai-intake'),
                  icon: const Icon(Icons.auto_awesome_rounded),
                  label: const Text('Начать AI-настройку'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
