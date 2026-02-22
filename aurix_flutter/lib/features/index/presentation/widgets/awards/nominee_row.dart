import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';

class NomineeRow extends StatelessWidget {
  final AwardNominee nominee;
  final int displayVotes;
  final int? trendDelta;
  final Artist? artist;
  final int rank;
  final VoidCallback? onVote;
  final bool compact;

  const NomineeRow({
    super.key,
    required this.nominee,
    required this.displayVotes,
    this.trendDelta,
    this.artist,
    this.rank = 0,
    this.onVote,
    this.compact = false,
  });

  Color _rankColor() {
    switch (rank) {
      case 1:
        return const Color(0xFFFFD700);
      case 2:
        return const Color(0xFFC0C0C0);
      case 3:
        return const Color(0xFFCD7F32);
      default:
        return AurixTokens.muted;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: compact ? 8 : 12),
      child: Row(
        children: [
          if (rank > 0)
            Container(
              width: 28,
              alignment: Alignment.center,
              child: Text(
                '#$rank',
                style: TextStyle(color: _rankColor(), fontSize: compact ? 12 : 14, fontWeight: FontWeight.w700),
              ),
            ),
          if (rank > 0) const SizedBox(width: 12),
          if (artist != null)
            Container(
              width: compact ? 36 : 44,
              height: compact ? 36 : 44,
              decoration: BoxDecoration(
                color: AurixTokens.bg2,
                borderRadius: BorderRadius.circular(compact ? 8 : 10),
              ),
              child: artist!.avatarUrl != null
                  ? ClipRRect(
                      borderRadius: BorderRadius.circular(compact ? 8 : 10),
                      child: Image.network(artist!.avatarUrl!, fit: BoxFit.cover),
                    )
                  : Center(
                      child: Text(
                        artist!.name.substring(0, 1).toUpperCase(),
                        style: TextStyle(color: AurixTokens.muted, fontSize: compact ? 14 : 16, fontWeight: FontWeight.w600),
                      ),
                    ),
            ),
          if (artist != null) const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  nominee.displayTitle,
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontSize: compact ? 14 : 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Text('Index: ${nominee.scoreProof}', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                    const SizedBox(width: 8),
                    Text('${displayVotes} голосов', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                    if (trendDelta != null && trendDelta != 0) ...[
                      const SizedBox(width: 8),
                      Text(
                        '${trendDelta! > 0 ? '+' : ''}$trendDelta',
                        style: TextStyle(
                          color: trendDelta! > 0 ? Colors.green : AurixTokens.muted,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ],
                ),
              ],
            ),
          ),
          if (onVote != null)
            TextButton(
              onPressed: onVote,
              child: Text('Голосовать', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
            ),
        ],
      ),
    );
  }
}
