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
          glowColor: AurixTokens.aiAccent,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  const HomeSectionTitle('\u0420\u043e\u0441\u0442', icon: Icons.trending_up_rounded),
                  const SizedBox(width: 10),
                  _LevelBadge(level: level, name: levelName),
                  const Spacer(),
                  if (currentStreak > 0) _StreakChip(streak: currentStreak),
                ],
              ),
              const SizedBox(height: 18),

              // XP Progress bar
              _XpProgressBar(
                currentXp: currentXp,
                progress: progress,
                xpToNext: xpToNext,
                level: level,
              ),
              const SizedBox(height: 16),

              // Stats row
              Row(
                children: [
                  Expanded(
                    child: _GrowthStatTile(
                      icon: Icons.emoji_events_rounded,
                      color: AurixTokens.warning,
                      label: '\u0414\u043e\u0441\u0442\u0438\u0436\u0435\u043d\u0438\u044f',
                      value: '$unlockedCount / $totalAch',
                      onTap: onOpenAchievements,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _GrowthStatTile(
                      icon: Icons.flag_rounded,
                      color: AurixTokens.positive,
                      label: '\u0426\u0435\u043b\u0438',
                      value: activeGoals > 0 ? '$activeGoals \u0430\u043a\u0442\u0438\u0432\u043d\u044b\u0445' : '\u0421\u043e\u0437\u0434\u0430\u0442\u044c',
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
            AurixTokens.accent.withValues(alpha: 0.18),
            AurixTokens.aiAccent.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.22)),
      ),
      child: Text(
        'Lv.$level $name',
        style: TextStyle(
          fontFamily: AurixTokens.fontMono,
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
        color: AurixTokens.warning.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AurixTokens.warning.withValues(alpha: 0.18)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.local_fire_department_rounded, size: 13, color: AurixTokens.warning),
          const SizedBox(width: 3),
          Text(
            '$streak \u0434.',
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
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
              style: TextStyle(
                fontFamily: AurixTokens.fontMono,
                color: AurixTokens.text,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                fontFeatures: AurixTokens.tabularFigures,
              ),
            ),
            const Spacer(),
            if (xpToNext > 0)
              Text(
                '\u0434\u043e Lv.${level + 1}: $xpToNext XP',
                style: TextStyle(
                  fontFamily: AurixTokens.fontBody,
                  color: AurixTokens.micro,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: SizedBox(
            height: 6,
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    color: AurixTokens.glass(0.06),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
                FractionallySizedBox(
                  widthFactor: progress.clamp(0.0, 1.0),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AurixTokens.aiAccent, AurixTokens.accent],
                      ),
                      borderRadius: BorderRadius.circular(4),
                      boxShadow: [
                        BoxShadow(
                          color: AurixTokens.aiAccent.withValues(alpha: 0.35),
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

class _GrowthStatTile extends StatefulWidget {
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
  State<_GrowthStatTile> createState() => _GrowthStatTileState();
}

class _GrowthStatTileState extends State<_GrowthStatTile> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: widget.onTap != null ? SystemMouseCursors.click : SystemMouseCursors.basic,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hovered ? AurixTokens.surface2.withValues(alpha: 0.6) : AurixTokens.glass(0.04),
            borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
            border: Border.all(
              color: _hovered ? widget.color.withValues(alpha: 0.2) : AurixTokens.stroke(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(widget.icon, size: 16, color: widget.color),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.label,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.micro,
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 0.3,
                      ),
                    ),
                    Text(
                      widget.value,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontBody,
                        color: AurixTokens.text,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (widget.onTap != null)
                Icon(Icons.chevron_right_rounded, size: 16, color: AurixTokens.micro),
            ],
          ),
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
          Container(width: 120, height: 16, decoration: BoxDecoration(color: AurixTokens.glass(0.06), borderRadius: BorderRadius.circular(8))),
          const SizedBox(height: 14),
          Container(width: double.infinity, height: 6, decoration: BoxDecoration(color: AurixTokens.glass(0.06), borderRadius: BorderRadius.circular(4))),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: Container(height: 56, decoration: BoxDecoration(color: AurixTokens.glass(0.04), borderRadius: BorderRadius.circular(AurixTokens.radiusSm)))),
              const SizedBox(width: 10),
              Expanded(child: Container(height: 56, decoration: BoxDecoration(color: AurixTokens.glass(0.04), borderRadius: BorderRadius.circular(AurixTokens.radiusSm)))),
            ],
          ),
        ],
      ),
    );
  }
}
