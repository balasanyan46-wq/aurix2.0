import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/data/providers/growth_providers.dart';
import 'package:aurix_flutter/design/widgets/section_onboarding.dart';

/// Map DB icon names to Material Icons.
IconData _mapIcon(String? icon) => switch (icon) {
      'login' => Icons.login_rounded,
      'album' => Icons.album_rounded,
      'music_note' => Icons.music_note_rounded,
      'image' => Icons.image_rounded,
      'send' => Icons.send_rounded,
      'smart_toy' => Icons.smart_toy_rounded,
      'auto_fix_high' => Icons.auto_fix_high_rounded,
      'library_music' => Icons.library_music_rounded,
      'rocket_launch' => Icons.rocket_launch_rounded,
      'local_fire_department' => Icons.local_fire_department_rounded,
      'diamond' => Icons.diamond_rounded,
      'workspace_premium' => Icons.workspace_premium_rounded,
      'share' => Icons.share_rounded,
      'person' => Icons.person_rounded,
      'whatshot' => Icons.whatshot_rounded,
      _ => Icons.emoji_events_rounded,
    };

Color _categoryColor(String? category, bool unlocked) {
  if (!unlocked) return AurixTokens.muted;
  return switch (category) {
    'milestone' => AurixTokens.accent,
    'creative' => AurixTokens.aiAccent,
    'social' => AurixTokens.positive,
    'general' => AurixTokens.warning,
    _ => AurixTokens.accent,
  };
}

class AchievementsScreen extends ConsumerWidget {
  const AchievementsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final achAsync = ref.watch(achievementsProvider);
    final xpAsync = ref.watch(xpStateProvider);

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Достижения',
          style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 17),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text),
            onPressed: () {
              ref.invalidate(achievementsProvider);
              ref.invalidate(xpStateProvider);
            },
          ),
        ],
      ),
      body: achAsync.when(
        loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
        error: (e, _) => PremiumErrorState(message: 'Ошибка загрузки: $e'),
        data: (achievements) {
          final unlocked = achievements.where((a) => a['unlocked_at'] != null).toList();
          final locked = achievements.where((a) => a['unlocked_at'] == null).toList();
          final total = achievements.length;
          final progress = total > 0 ? unlocked.length / total : 0.0;

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SectionOnboarding(tip: OnboardingTips.achievements),
                // XP + progress hero
                xpAsync.when(
                  data: (xp) => _HeroCard(
                    xp: xp,
                    unlockedCount: unlocked.length,
                    totalCount: total,
                    progress: progress,
                  ),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 28),

                // Unlocked
                if (unlocked.isNotEmpty) ...[
                  _SectionHeader(title: 'Разблокировано', count: unlocked.length, color: AurixTokens.positive),
                  const SizedBox(height: 12),
                  ...unlocked.map((a) => _AchievementTile(achievement: a, unlocked: true)),
                  const SizedBox(height: 28),
                ],

                // Locked
                if (locked.isNotEmpty) ...[
                  _SectionHeader(title: 'Впереди', count: locked.length, color: AurixTokens.muted),
                  const SizedBox(height: 12),
                  ...locked.map((a) => _AchievementTile(achievement: a, unlocked: false)),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _HeroCard extends StatelessWidget {
  const _HeroCard({
    required this.xp,
    required this.unlockedCount,
    required this.totalCount,
    required this.progress,
  });
  final Map<String, dynamic> xp;
  final int unlockedCount;
  final int totalCount;
  final double progress;

  @override
  Widget build(BuildContext context) {
    final level = xp['level'] ?? 1;
    final levelName = xp['level_name'] ?? 'Rookie';
    final currentXp = xp['xp'] ?? 0;
    final xpProgress = (xp['progress'] ?? 0).toDouble();
    final xpToNext = xp['xp_to_next'] ?? 0;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(isMobile ? 20 : 28),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.12),
            AurixTokens.aiAccent.withValues(alpha: 0.06),
            AurixTokens.bg1,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AurixTokens.accent.withValues(alpha: 0.08),
            blurRadius: 32,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Level badge
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [AurixTokens.accent, AurixTokens.accentWarm],
              ),
              boxShadow: [
                BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.4), blurRadius: 20),
              ],
            ),
            child: Center(
              child: Text(
                '$level',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            levelName,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$currentXp XP',
            style: TextStyle(
              fontFamily: AurixTokens.fontMono,
              color: AurixTokens.accentWarm,
              fontSize: 16,
              fontWeight: FontWeight.w700,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
          const SizedBox(height: 16),

          // XP progress bar
          Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Прогресс до Lv.${level + 1}',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600),
                  ),
                  Text(
                    xpToNext > 0 ? 'ещё $xpToNext XP' : 'MAX',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontMono,
                      color: AurixTokens.micro,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: SizedBox(
                  height: 6,
                  child: Stack(
                    children: [
                      Container(color: AurixTokens.glass(0.1)),
                      FractionallySizedBox(
                        widthFactor: xpProgress.clamp(0.0, 1.0),
                        child: Container(
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentWarm]),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Achievement progress
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AurixTokens.stroke(0.1)),
            ),
            child: Row(
              children: [
                const Icon(Icons.emoji_events_rounded, size: 20, color: AurixTokens.warning),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '$unlockedCount из $totalCount достижений',
                        style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(3),
                        child: SizedBox(
                          height: 4,
                          child: Stack(
                            children: [
                              Container(color: AurixTokens.glass(0.1)),
                              FractionallySizedBox(
                                widthFactor: progress.clamp(0.0, 1.0),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    gradient: LinearGradient(colors: [AurixTokens.warning, AurixTokens.accent]),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  '${(progress * 100).toInt()}%',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: AurixTokens.warning,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.count, required this.color});
  final String title;
  final int count;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 17, fontWeight: FontWeight.w800)),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text('$count', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});
  final Map<String, dynamic> achievement;
  final bool unlocked;

  @override
  Widget build(BuildContext context) {
    final name = achievement['name']?.toString() ?? '';
    final desc = achievement['description']?.toString() ?? '';
    final iconName = achievement['icon']?.toString() ?? '';
    final category = achievement['category']?.toString() ?? '';
    final xpReward = achievement['xp_reward'] ?? 0;

    final iconData = _mapIcon(iconName);
    final color = _categoryColor(category, unlocked);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? color.withValues(alpha: 0.04) : AurixTokens.glass(0.02),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: unlocked ? color.withValues(alpha: 0.2) : AurixTokens.stroke(0.08),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              gradient: unlocked
                  ? LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [color.withValues(alpha: 0.2), color.withValues(alpha: 0.08)],
                    )
                  : null,
              color: unlocked ? null : AurixTokens.glass(0.05),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(color: color.withValues(alpha: unlocked ? 0.2 : 0.08)),
              boxShadow: unlocked
                  ? [BoxShadow(color: color.withValues(alpha: 0.15), blurRadius: 12)]
                  : null,
            ),
            child: Icon(
              iconData,
              size: 22,
              color: unlocked ? color : AurixTokens.micro,
            ),
          ),
          const SizedBox(width: 14),
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    color: unlocked ? AurixTokens.text : AurixTokens.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (desc.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 2),
                    child: Text(
                      desc,
                      style: TextStyle(
                        color: unlocked ? AurixTokens.textSecondary : AurixTokens.micro,
                        fontSize: 12,
                        height: 1.3,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          // XP badge + status
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: (unlocked ? AurixTokens.accent : AurixTokens.muted).withValues(alpha: unlocked ? 0.15 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$xpReward XP',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontMono,
                    color: unlocked ? AurixTokens.accentWarm : AurixTokens.micro,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              unlocked
                  ? Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.check_circle_rounded, size: 14, color: AurixTokens.positive),
                        const SizedBox(width: 3),
                        Text(
                          'Получено',
                          style: TextStyle(color: AurixTokens.positive, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock_outline_rounded, size: 13, color: AurixTokens.micro),
                        const SizedBox(width: 3),
                        Text(
                          'Закрыто',
                          style: TextStyle(color: AurixTokens.micro, fontSize: 10, fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
            ],
          ),
        ],
      ),
    );
  }
}
