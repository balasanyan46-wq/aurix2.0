import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'release_picker_screen.dart';

class ToolsHomeScreen extends ConsumerWidget {
  const ToolsHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text('AI-Инструменты', style: tt.headlineSmall?.copyWith(fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text('Выберите инструмент для работы с вашим релизом',
          style: tt.bodyMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
        const SizedBox(height: 24),
        _ToolCard(
          icon: Icons.trending_up_rounded,
          title: 'Карта роста релиза',
          subtitle: '30-дневный AI-план продвижения с позиционированием и рисками',
          color: const Color(0xFF22C55E),
          tag: 'AI',
          onTap: () => _openTool(context, ToolType.growth),
        ),
        const SizedBox(height: 12),
        _ToolCard(
          icon: Icons.account_balance_wallet_rounded,
          title: 'Бюджет-менеджер',
          subtitle: 'AI-распределение бюджета с анти-сливом и стратегией',
          color: const Color(0xFFFF6B35),
          tag: 'AI',
          onTap: () => _openTool(context, ToolType.budget),
        ),
        const SizedBox(height: 12),
        _ToolCard(
          icon: Icons.auto_awesome_rounded,
          title: 'AI-Упаковка релиза',
          subtitle: 'Описания для платформ, хуки для видео, CTA, сторителлинг',
          color: const Color(0xFF8B5CF6),
          tag: 'NEW',
          onTap: () => _openTool(context, ToolType.packaging),
        ),
        const SizedBox(height: 12),
        _ToolCard(
          icon: Icons.video_library_rounded,
          title: 'Контент-план Reels/Shorts',
          subtitle: '14 дней: сценарии, хуки, шотлисты, CTA',
          color: const Color(0xFFEC4899),
          tag: 'NEW',
          onTap: () => _openTool(context, ToolType.contentPlan),
        ),
        const SizedBox(height: 12),
        _ToolCard(
          icon: Icons.mail_rounded,
          title: 'Плейлист-питч пакет',
          subtitle: 'Питчи, email-темы, пресс-строки, биография артиста',
          color: const Color(0xFF0EA5E9),
          tag: 'NEW',
          onTap: () => _openTool(context, ToolType.pitchPack),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  void _openTool(BuildContext context, ToolType tool) {
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => ReleasePickerScreen(toolType: tool)),
    );
  }
}

class _ToolCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final String? tag;
  final VoidCallback onTap;

  const _ToolCard({
    required this.icon, required this.title, required this.subtitle,
    required this.color, required this.onTap, this.tag,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Row(
            children: [
              Container(
                width: 56, height: 56,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(title,
                            style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                        ),
                        if (tag != null) ...[
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: color.withValues(alpha: 0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(tag!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: cs.onSurface.withValues(alpha: 0.55))),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: cs.onSurface.withValues(alpha: 0.3)),
            ],
          ),
        ),
      ),
    );
  }
}
