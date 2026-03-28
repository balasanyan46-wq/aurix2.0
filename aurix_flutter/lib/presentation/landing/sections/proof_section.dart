import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class ProofSection extends StatelessWidget {
  const ProofSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.3),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'РАННИЙ ДОСТУП'),
            const SizedBox(height: 20),
            Text(
              'AURIX уже работает',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 36 : 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Платформа в стадии раннего доступа. Артисты уже тестируют AI-инструменты.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: desktop ? 32 : 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: const [
                _MetricCard(value: 'AI', label: 'Анализ треков\nв реальном времени'),
                _MetricCard(value: 'DNA', label: 'Уникальный профиль\nдля каждого артиста'),
                _MetricCard(value: '24/7', label: 'Стратегия и идеи\nбез ожидания'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MetricCard extends StatelessWidget {
  final String value, label;
  const _MetricCard({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 220,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        border: Border.all(color: AurixTokens.stroke(0.10)),
      ),
      child: Column(
        children: [
          ShaderMask(
            shaderCallback: (bounds) => const LinearGradient(
              colors: [AurixTokens.accent, AurixTokens.aiAccent],
            ).createShader(bounds),
            child: Text(
              value,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w800,
                letterSpacing: -1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.4),
          ),
        ],
      ),
    );
  }
}
