import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Viral block: your music can grow itself.
class ViralSection extends StatelessWidget {
  const ViralSection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AurixTokens.bg0,
            AurixTokens.aiAccent.withValues(alpha: 0.03),
            AurixTokens.bg0,
          ],
        ),
      ),
      child: LandingSection(
        child: SplitCanvas(
          left: Column(
            crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
            children: [
              const SectionLabel(text: 'РОСТ', color: AurixTokens.aiAccent),
              const SizedBox(height: 20),
              Text(
                'Твои треки могут\nсами приводить\nаудиторию',
                textAlign: desktop ? TextAlign.left : TextAlign.center,
                style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: desktop ? 38 : 28,
                  fontWeight: FontWeight.w900,
                  height: 1.1,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Каждый AI-контент содержит ссылку на твой профиль. Каждый share — это новый слушатель. Система работает на тебя 24/7.',
                textAlign: desktop ? TextAlign.left : TextAlign.center,
                style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
              ),
              const SizedBox(height: 28),
              // Metrics
              _ViralMetric(icon: Icons.share_rounded, label: 'Share ссылки', value: 'Каждый контент = точка входа', color: AurixTokens.aiAccent),
              const SizedBox(height: 12),
              _ViralMetric(icon: Icons.videocam_rounded, label: 'AI видео', value: 'Вертикальный формат для всех платформ', color: AurixTokens.accent),
              const SizedBox(height: 12),
              _ViralMetric(icon: Icons.trending_up_rounded, label: 'Рост', value: 'XP, уровни, достижения мотивируют продолжать', color: AurixTokens.positive),
            ],
          ),
          right: _ViralVisual(),
        ),
      ),
    );
  }
}

class _ViralMetric extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color color;
  const _ViralMetric({required this.icon, required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.12)),
      ),
      child: Row(
        children: [
          Container(
            width: 36, height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: color.withValues(alpha: 0.12),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700)),
                Text(value, style: TextStyle(color: AurixTokens.muted, fontSize: 11.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ViralVisual extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(maxWidth: 420),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AurixTokens.surface1,
        border: Border.all(color: AurixTokens.stroke(0.12)),
        boxShadow: [
          BoxShadow(color: AurixTokens.aiAccent.withValues(alpha: 0.06), blurRadius: 40, offset: const Offset(0, 16)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.person_rounded, size: 16, color: AurixTokens.aiAccent),
              const SizedBox(width: 8),
              const Text('Публичный профиль', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          // Fake profile card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AurixTokens.aiAccent.withValues(alpha: 0.1), AurixTokens.accent.withValues(alpha: 0.06)],
              ),
              border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    // Avatar
                    Container(
                      width: 44, height: 44,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(colors: [AurixTokens.accent, AurixTokens.aiAccent]),
                      ),
                      child: const Center(child: Text('MD', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800))),
                    ),
                    const SizedBox(width: 12),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Midnight Dreamer', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
                        Text('Hip-Hop / R&B  ·  Lv.5 Pro', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                // Stats row
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _statCol('3', 'Релиза'),
                    _statCol('1.2K', 'XP'),
                    _statCol('8', 'Ачивок'),
                    _statCol('142', 'Просм.'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Share link mockup
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              color: AurixTokens.glass(0.05),
              border: Border.all(color: AurixTokens.stroke(0.1)),
            ),
            child: Row(
              children: [
                Icon(Icons.link_rounded, size: 14, color: AurixTokens.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('aurixmusic.ru/p/midnight-dreamer', style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w500)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(6),
                    color: AurixTokens.accent.withValues(alpha: 0.12),
                  ),
                  child: const Text('Копировать', style: TextStyle(color: AurixTokens.accent, fontSize: 10, fontWeight: FontWeight.w700)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _statCol(String value, String label) {
    return Column(
      children: [
        Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
        Text(label, style: TextStyle(color: AurixTokens.micro, fontSize: 10)),
      ],
    );
  }
}
