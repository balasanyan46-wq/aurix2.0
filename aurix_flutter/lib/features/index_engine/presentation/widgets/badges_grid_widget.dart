import 'package:flutter/material.dart' hide Badge;
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/badge.dart';

class BadgesGridWidget extends StatelessWidget {
  final List<Badge> badges;

  const BadgesGridWidget({super.key, required this.badges});

  @override
  Widget build(BuildContext context) {
    if (badges.isEmpty) return const SizedBox.shrink();
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: badges.map<Widget>((b) => _BadgeChip(badge: b)).toList(),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final Badge badge;

  const _BadgeChip({required this.badge});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AurixTokens.accent.withValues(alpha: 0.12),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.4)),
      ),
      child: Text(
        badge.title,
        style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w600, fontSize: 13),
      ),
    );
  }
}
