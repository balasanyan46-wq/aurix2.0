import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class HowItWorksSection extends StatelessWidget {
  const HowItWorksSection({super.key});

  static const _steps = [
    _Step('01', 'Загрузи трек', 'Добавь аудиофайл — и система начнёт анализ.'),
    _Step('02', 'Получи AI-анализ', 'Жанр, энергия, эмоция, потенциал — за секунды.'),
    _Step('03', 'Построй стратегию', 'AI подберёт план промо под твой стиль и аудиторию.'),
    _Step('04', 'Расти системно', 'Работай как артист нового поколения — с данными и пониманием.'),
  ];

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.3),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'КАК ЭТО РАБОТАЕТ'),
            const SizedBox(height: 20),
            Text(
              'Четыре шага к системной работе',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 36 : 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 48),
            if (desktop)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = 0; i < _steps.length; i++) ...[
                    if (i > 0) const SizedBox(width: 20),
                    Expanded(child: _StepCard(step: _steps[i], isLast: i == _steps.length - 1)),
                  ],
                ],
              )
            else
              Column(
                children: [
                  for (var i = 0; i < _steps.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: _StepCard(step: _steps[i], isLast: i == _steps.length - 1),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _Step {
  final String num, title, text;
  const _Step(this.num, this.title, this.text);
}

class _StepCard extends StatelessWidget {
  final _Step step;
  final bool isLast;
  const _StepCard({required this.step, required this.isLast});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        border: Border.all(color: AurixTokens.stroke(0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: const LinearGradient(
                colors: [AurixTokens.accent, AurixTokens.aiAccent],
              ),
            ),
            alignment: Alignment.center,
            child: Text(
              step.num,
              style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            step.title,
            style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            step.text,
            style: TextStyle(color: AurixTokens.muted, fontSize: 13.5, height: 1.5),
          ),
        ],
      ),
    );
  }
}
