import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

class StrategySection extends StatelessWidget {
  const StrategySection({super.key});

  @override
  Widget build(BuildContext context) {
    final desktop = isDesktop(context);
    return LandingSection(
      child: SplitCanvas(
        reversed: true,
        left: _StrategyCopy(desktop: desktop),
        right: const _StrategyTerminal(),
      ),
    );
  }
}

class _StrategyCopy extends StatelessWidget {
  final bool desktop;
  const _StrategyCopy({required this.desktop});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: desktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        const SectionLabel(text: 'СТРАТЕГИЯ'),
        const SizedBox(height: 24),
        Text(
          'AI строит стратегию\nпродвижения',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: desktop ? 38 : 28,
            fontWeight: FontWeight.w800,
            height: 1.15,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Не шаблон, а персональная стратегия на основе анализа твоего трека, аудитории и текущих трендов.',
          textAlign: desktop ? TextAlign.left : TextAlign.center,
          style: TextStyle(color: AurixTokens.muted, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 28),
        _StrategyPoint(icon: Icons.calendar_today_rounded, text: 'Когда выпускать трек'),
        const SizedBox(height: 12),
        _StrategyPoint(icon: Icons.devices_rounded, text: 'Какие платформы использовать'),
        const SizedBox(height: 12),
        _StrategyPoint(icon: Icons.auto_awesome_rounded, text: 'Какой контент делать'),
        const SizedBox(height: 12),
        _StrategyPoint(icon: Icons.rocket_launch_rounded, text: 'Как запускать промо'),
      ],
    );
  }
}

class _StrategyPoint extends StatelessWidget {
  final IconData icon;
  final String text;
  const _StrategyPoint({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AurixTokens.accent.withValues(alpha: 0.7), size: 18),
        const SizedBox(width: 12),
        Text(text, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, fontWeight: FontWeight.w500)),
      ],
    );
  }
}

class _StrategyTerminal extends StatelessWidget {
  const _StrategyTerminal();

  @override
  Widget build(BuildContext context) {
    return const TerminalPanel(
      lines: [
        TerminalLine(prefix: '▸', text: 'Анализ трека: «Midnight Drive»...'),
        TerminalLine(prefix: '▸', text: 'Жанр: Dark Pop / Lo-Fi'),
        TerminalLine(prefix: '▸', text: 'Аудитория: 18-24, эмоциональная, ночной вайб'),
        TerminalLine(prefix: '', text: ''),
        TerminalLine(prefix: '◆', text: 'Стратегия релиза:', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '  →', text: 'Лучшее время релиза: Четверг 18:00', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '  →', text: 'Основные платформы: TikTok, Spotify, VK Music', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '  →', text: 'Pre-save кампания: за 5 дней до релиза', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '', text: ''),
        TerminalLine(prefix: '◆', text: 'Контент план:', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '  →', text: 'TikTok: атмосферные ночные видео', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '  →', text: 'Reels: behind-the-scenes из студии', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '  →', text: 'Stories: обратный отсчёт + тизер-сниппеты', prefixColor: AurixTokens.aiAccent),
        TerminalLine(prefix: '', text: ''),
        TerminalLine(prefix: '✓', text: 'Уверенность: 84%  •  Готово к запуску', prefixColor: Color(0xFF4DB88C)),
      ],
    );
  }
}
