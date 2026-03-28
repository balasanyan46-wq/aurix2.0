import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class EducationSection extends StatelessWidget {
  const EducationSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: Column(
        children: [
          const SectionLabel(text: 'ОБУЧЕНИЕ', color: AurixTokens.aiAccent),
          const SizedBox(height: 24),
          Text(
            'AI обучает тебя',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 40 : 28,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 14),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 560),
            child: Text(
              'Платформа включает базу знаний, чтобы ты рос не только как артист, но и как стратег своей карьеры.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.muted, fontSize: desktop ? 16 : 14, height: 1.6),
            ),
          ),
          SizedBox(height: desktop ? 56 : 40),
          // Minimal icon row — NOT cards
          Wrap(
            spacing: desktop ? 48 : 24,
            runSpacing: 32,
            alignment: WrapAlignment.center,
            children: const [
              _EduItem(icon: Icons.menu_book_rounded, label: 'Гайды'),
              _EduItem(icon: Icons.article_outlined, label: 'Статьи'),
              _EduItem(icon: Icons.lightbulb_outline_rounded, label: 'Стратегии'),
              _EduItem(icon: Icons.school_outlined, label: 'Индустрия'),
            ],
          ),
        ],
      ),
    );
  }
}

class _EduItem extends StatelessWidget {
  final IconData icon;
  final String label;
  const _EduItem({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 100,
      child: Column(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AurixTokens.aiAccent.withValues(alpha: 0.12),
                  AurixTokens.accent.withValues(alpha: 0.08),
                ],
              ),
              border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
            ),
            child: Icon(icon, color: AurixTokens.aiAccent.withValues(alpha: 0.8), size: 24),
          ),
          const SizedBox(height: 12),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}
