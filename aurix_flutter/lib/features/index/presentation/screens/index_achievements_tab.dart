import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/domain/badge_engine.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';

/// Вкладка «Достижения» — бейджи и прогресс артиста.
class IndexAchievementsTab extends ConsumerWidget {
  const IndexAchievementsTab({super.key});

  static const _badgeDefs = [
    (id: BadgeEngine.top10, title: 'Top 10', desc: 'В топ-10 рейтинга', icon: Icons.emoji_events_rounded, rarity: 'epic'),
    (id: BadgeEngine.rising, title: 'Rising', desc: 'Рост индекса +30 за период', icon: Icons.trending_up_rounded, rarity: 'rare'),
    (id: BadgeEngine.consistent, title: 'Consistent', desc: '2+ релиза за период', icon: Icons.repeat_rounded, rarity: 'common'),
    (id: BadgeEngine.viral, title: 'Viral', desc: 'Высокий share rate', icon: Icons.volunteer_activism_rounded, rarity: 'rare'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(indexProvider);
    final data = state.data;
    if (data == null) return const SizedBox.shrink();

    final score = data.selectedScore;
    final earned = score?.badges ?? [];
    final padding = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Достижения',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AurixTokens.text,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            '${earned.length} из ${_badgeDefs.length} бейджей',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
          Wrap(
            spacing: 16,
            runSpacing: 16,
            children: _badgeDefs.map((b) {
              final isEarned = earned.contains(b.id);
              return _BadgeCard(
                title: b.title,
                description: b.desc,
                icon: b.icon,
                rarity: b.rarity,
                isEarned: isEarned,
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

class _BadgeCard extends StatelessWidget {
  final String title;
  final String description;
  final IconData icon;
  final String rarity;
  final bool isEarned;

  const _BadgeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.rarity,
    required this.isEarned,
  });

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: SizedBox(
        width: 200,
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isEarned
                    ? AurixTokens.orange.withValues(alpha: 0.2)
                    : AurixTokens.glass(0.08),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                icon,
                size: 28,
                color: isEarned ? AurixTokens.orange : AurixTokens.muted,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: isEarned ? AurixTokens.text : AurixTokens.muted,
                          fontWeight: FontWeight.w600,
                          fontSize: 15,
                        ),
                      ),
                      if (isEarned) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle, size: 16, color: AurixTokens.orange),
                      ],
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 12,
                      height: 1.3,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
