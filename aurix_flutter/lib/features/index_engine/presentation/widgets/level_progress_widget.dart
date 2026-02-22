import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/index_engine/domain/levels/artist_level.dart';

class LevelProgressWidget extends StatelessWidget {
  final ArtistLevel level;
  final double progressToNext;
  final int pointsToNext;

  const LevelProgressWidget({
    super.key,
    required this.level,
    required this.progressToNext,
    required this.pointsToNext,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AurixTokens.accent.withValues(alpha: 0.12),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.4)),
                ),
                child: Text(
                  level.title.toUpperCase(),
                  style: TextStyle(
                    color: AurixTokens.accent,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    letterSpacing: 1,
                  ),
                ),
              ),
              if (pointsToNext > 0) ...[
                const SizedBox(width: 12),
                Text(
                  'До следующего: +$pointsToNext',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                ),
              ],
            ],
          ),
          if (pointsToNext > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.zero,
              child: LinearProgressIndicator(
                value: progressToNext,
                minHeight: 4,
                backgroundColor: AurixTokens.border,
                valueColor: const AlwaysStoppedAnimation<Color>(AurixTokens.accent),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
