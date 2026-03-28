import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// How It Works: 3 simple steps.
class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        children: [
          const SectionLabel(text: 'КАК ЭТО РАБОТАЕТ'),
          const SizedBox(height: 20),
          Text(
            'Три шага до результата',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 42 : 30,
              fontWeight: FontWeight.w900,
              height: 1.1,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 48),
          TimelineFlow(
            steps: const [
              TimelineStep(
                icon: Icons.upload_file_rounded,
                label: 'Загрузи трек',
                description: 'Или просто напиши идею — AI начнёт работать мгновенно',
              ),
              TimelineStep(
                icon: Icons.auto_awesome_rounded,
                label: 'Получи анализ + план',
                description: 'AI оценит потенциал, найдёт лучший момент и составит стратегию',
              ),
              TimelineStep(
                icon: Icons.rocket_launch_rounded,
                label: 'Создай контент и запусти',
                description: 'Обложка, видео, тексты — всё готово. Нажми «Запустить»',
              ),
            ],
          ),
        ],
      ),
    );
  }
}
