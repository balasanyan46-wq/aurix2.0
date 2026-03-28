import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/growth_providers.dart';
import 'home_shared.dart';

/// Growth block on home screen: XP bar + level + streak + achievements count.
class GrowthBlock extends ConsumerWidget {
  const GrowthBlock({super.key, this.onOpenAchievements, this.onOpenGoals});

  final VoidCallback? onOpenAchievements;
  final VoidCallback? onOpenGoals;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stateAsync = ref.watch(growthStateProvider);

    return stateAsync.when(
      loading: () => const _GrowthBlockSkeleton(),
      error: (_, __) => const SizedBox.shrink(),
      data: (data) {
        if (data.isEmpty) return const SizedBox.shrink();
        final xp = data['xp'] as Map<String, dynamic>? ?? {};
        final streak = data['streak'] as Map<String, dynamic>? ?? {};
        final achievements = data['achievements'] as List? ?? [];
        final goals = data['goals'] as List? ?? [];

        final level = xp['level'] ?? 1;
        final levelName = xp['level_name'] ?? 'Rookie';
        final currentXp = xp['xp'] ?? 0;
        final progress = (xp['progress'] ?? 0).toDouble();
        final xpToNext = xp['xp_to_next'] ?? 0;
        final currentStreak = streak['current_streak'] ?? 0;
        final unlockedCount = achievements.where((a) => a['unlocked_at'] != null).length;
        final totalAch = achievements.length;
        final activeGoals = goals.where((g) => g['is_completed'] != true).length;

        return HomeSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const HomeSectionTitle('Рост'),
                  const SizedBox(width: 8),
                  _LevelBadge(level: level, name: levelName),
                  const Spacer(),
                  if (currentStreak > 0) _StreakChip(streak: currentStreak),
                ],
              ),
              const SizedBox(height: 14),

              // XP Progress bar
              _XpProgressBar(
                currentXp: currentXp,
                progress: progress,
                xpToNext: xpToNext,
                level: level,
              ),
              const SizedBox(height: 14),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _GrowthStatTile(
                      icon: Icons.emoji_events_rounded,
                      color: AurixTokens.warning,
                      label: 'Достижения',
                      value: '$unlockedCount / $totalAch',
                      onTap: onOpenAchievements,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GrowthStatTile(
                      icon: Icons.flag_rounded,
                      color: AurixTokens.positive,
                      label: 'Цели',
                      value: activeGoals > 0 ? '$activeGoals активных' : 'Создать',
                      onTap: onOpenGoals,
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _LevelBadge extends StatelessWidget {
  const _LevelBadge({required this.level, required this.name});
  final int level;
  final String name;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AurixTokens.accent.withValues(alpha: 0.22),
            AurixTokens.aiAccent.withValues(alpha: 0.15),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
      ),
      child: Text(
        'Lv.$level $name',
        style: const TextStyle(
          color: AurixTokens.accentWarm,
          fontSize: 11,
          fontWeight: FontWeight.w700,
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});
  final int streak;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AurixTokens.warning.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 14, color: AurixTokens.warning),
          const SizedBox(width: 3),
          Text(
            '$streak д.',
            style: const TextStyle(
              color: AurixTokens.warning,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _XpProgressBar extends StatelessWidget {
  const _XpProgressBar({
    required this.currentXp,
    required this.progress,
    required this.xpToNext,
    required this.level,
  });
  final int currentXp;
  final double progress;
  final int xpToNext;
  final int level;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              '$currentXp XP',
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 20,
                fontWeight: FontWeight.w800,
                fontFeatures: AurixTokens.tabularFigures,
              ),
            ),
            const Spacer(),
            if (xpToNext > 0)
              Text(
                'до Lv.${level + 1}: $xpToNext XP',
                style: TextStyle(
                  color: AurixTokens.muted,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 8,
            child: Stack(
              children: [
                // Background
                Container(
                  decoration: BoxDecoration(
                    color: AurixTokens.glass(0.08),
                    borderRadius: BorderRadius.circular(6),
                  ),
                ),
                // Progress fill
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AurixTokens.accent, AurixTokens.accentWarm],
                      ),
                      borderRadius: BorderRadius.circular(6),
                      boxShadow: [
                        BoxShadow(
                          color: AurixTokens.accent.withValues(alpha: 0.4),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _GrowthStatTile extends StatelessWidget {
  const _GrowthStatTile({
    required this.icon,
    required this.color,
    required this.label,
    required this.value,
    this.onTap,
  });
  final IconData icon;
  final Color color;
  final String label;
  final String value;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.05),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.stroke(0.14)),
        ),
        child: Row(
          children: [
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, size: 16, color: color),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, size: 16, color: AurixTokens.muted),
          ],
        ),
      ),
    );
  }
}

class _GrowthBlockSkeleton extends StatelessWidget {
  const _GrowthBlockSkeleton();

  @override
  Widget build(BuildContext context) {
    return HomeSectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(width: 120, height: 16, decoration: BoxDecoration(color: AurixTokens.glass(0.08), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 14),
          Container(width: double.infinity, height: 8, decoration: BoxDecoration(color: AurixTokens.glass(0.08), borderRadius: BorderRadius.circular(6))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Container(height: 56, decoration: BoxDecoration(color: AurixTokens.glass(0.05), borderRadius: BorderRadius.circular(14)))),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 56, decoration: BoxDecoration(color: AurixTokens.glass(0.05), borderRadius: BorderRadius.circular(14)))),
            ],
          ),
        ],
      ),
    );
  }
}
