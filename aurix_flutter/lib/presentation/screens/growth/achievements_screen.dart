import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/data/providers/growth_providers.dart';

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
        title: const Text('ДОСТИЖЕНИЯ', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 16, letterSpacing: 1)),
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

          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // XP summary card
                xpAsync.when(
                  data: (xp) => _XpSummaryCard(xp: xp),
                  loading: () => const SizedBox.shrink(),
                  error: (_, __) => const SizedBox.shrink(),
                ),
                const SizedBox(height: 24),

                // Unlocked
                if (unlocked.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Разблокировано',
                    count: unlocked.length,
                    color: AurixTokens.positive,
                  ),
                  const SizedBox(height: 12),
                  ...unlocked.map((a) => _AchievementTile(achievement: a, unlocked: true)),
                  const SizedBox(height: 24),
                ],

                // Locked
                if (locked.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Заблокировано',
                    count: locked.length,
                    color: AurixTokens.muted,
                  ),
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

class _XpSummaryCard extends StatelessWidget {
  const _XpSummaryCard({required this.xp});
  final Map<String, dynamic> xp;

  @override
  Widget build(BuildContext context) {
    final level = xp['level'] ?? 1;
    final levelName = xp['level_name'] ?? 'Rookie';
    final currentXp = xp['xp'] ?? 0;
    final progress = (xp['progress'] ?? 0).toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.accent.withValues(alpha: 0.18),
            AurixTokens.aiAccent.withValues(alpha: 0.12),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.25)),
      ),
      child: Column(
        children: [
          Text(
            'Уровень $level',
            style: const TextStyle(color: AurixTokens.accentWarm, fontSize: 13, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(
            levelName,
            style: const TextStyle(color: AurixTokens.text, fontSize: 28, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$currentXp XP',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14, fontWeight: FontWeight.w600, fontFeatures: AurixTokens.tabularFigures),
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.clamp(0.0, 1.0),
              backgroundColor: AurixTokens.glass(0.1),
              valueColor: const AlwaysStoppedAnimation(AurixTokens.accent),
              minHeight: 6,
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
        Text(
          title,
          style: const TextStyle(color: AurixTokens.text, fontSize: 17, fontWeight: FontWeight.w800),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            '$count',
            style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700),
          ),
        ),
      ],
    );
  }
}

class _AchievementTile extends StatelessWidget {
  const _AchievementTile({required this.achievement, required this.unlocked});
  final Map<String, dynamic> achievement;
  final bool unlocked;

  static const _categoryIcons = <String, IconData>{
    'milestone': Icons.flag_rounded,
    'ai': Icons.auto_awesome_rounded,
    'social': Icons.share_rounded,
    'streak': Icons.local_fire_department_rounded,
    'release': Icons.album_rounded,
  };

  @override
  Widget build(BuildContext context) {
    final name = achievement['name'] ?? '';
    final desc = achievement['description'] ?? '';
    final icon = achievement['icon'] ?? '';
    final category = achievement['category'] ?? '';
    final xpReward = achievement['xp_reward'] ?? 0;
    final unlockedAt = achievement['unlocked_at'];

    final iconData = _categoryIcons[category] ?? Icons.star_rounded;
    final accentColor = unlocked ? AurixTokens.warning : AurixTokens.muted;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: unlocked ? AurixTokens.glass(0.06) : AurixTokens.glass(0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unlocked ? AurixTokens.warning.withValues(alpha: 0.25) : AurixTokens.stroke(0.12),
        ),
      ),
      child: Row(
        children: [
          // Icon
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: unlocked ? 0.18 : 0.08),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: icon.isNotEmpty
                  ? Text(icon, style: TextStyle(fontSize: 22, color: unlocked ? null : AurixTokens.muted))
                  : Icon(iconData, size: 22, color: accentColor),
            ),
          ),
          const SizedBox(width: 12),
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
                  Text(
                    desc,
                    style: TextStyle(
                      color: unlocked ? AurixTokens.textSecondary : AurixTokens.micro,
                      fontSize: 11.5,
                      height: 1.3,
                    ),
                  ),
              ],
            ),
          ),
          // XP badge
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: unlocked ? 0.18 : 0.08),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$xpReward XP',
                  style: TextStyle(
                    color: unlocked ? AurixTokens.accentWarm : AurixTokens.muted,
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (unlocked && unlockedAt != null) ...[
                const SizedBox(height: 4),
                Icon(Icons.check_circle_rounded, size: 16, color: AurixTokens.positive),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
