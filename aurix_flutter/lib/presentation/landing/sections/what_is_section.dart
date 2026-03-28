import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class WhatIsSection extends StatelessWidget {
  const WhatIsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      color: AurixTokens.surface1.withValues(alpha: 0.4),
      child: LandingSection(
        child: Column(
          children: [
            const SectionLabel(text: 'ЧТО ТАКОЕ AURIX'),
            const SizedBox(height: 20),
            Text(
              'Операционная система артиста',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AurixTokens.text,
                fontSize: desktop ? 36 : 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.8,
              ),
            ),
            const SizedBox(height: 16),
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: Text(
                'Единая платформа, которая объединяет анализ музыки, стратегию продвижения, аудиторию и AI-инструменты в одном месте.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: desktop ? 16 : 14,
                  height: 1.6,
                ),
              ),
            ),
            const SizedBox(height: 48),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              alignment: WrapAlignment.center,
              children: const [
                _Pillar(icon: Icons.analytics_outlined, label: 'Анализ трека'),
                _Pillar(icon: Icons.route_outlined, label: 'Стратегия'),
                _Pillar(icon: Icons.people_outline_rounded, label: 'Аудитория'),
                _Pillar(icon: Icons.auto_awesome_outlined, label: 'AI-инструменты'),
                _Pillar(icon: Icons.trending_up_rounded, label: 'Рост артиста'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Pillar extends StatelessWidget {
  final IconData icon;
  final String label;
  const _Pillar({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: AurixTokens.bg0.withValues(alpha: 0.6),
        border: Border.all(color: AurixTokens.stroke(0.10)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: AurixTokens.accent, size: 20),
          const SizedBox(width: 10),
          Text(
            label,
            style: const TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
