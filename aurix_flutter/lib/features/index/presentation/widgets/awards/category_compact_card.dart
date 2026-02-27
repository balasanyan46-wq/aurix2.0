import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_data.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/votes_progress_bar.dart';

class CategoryCompactCard extends StatelessWidget {
  final AwardCategory category;
  final AwardNominee? leader;
  final List<AwardNominee> topThree;
  final Map<String, int> voteOverrides;
  final IndexDataLookup lookup;
  final VoidCallback onOpen;

  const CategoryCompactCard({
    super.key,
    required this.category,
    required this.leader,
    required this.topThree,
    required this.voteOverrides,
    required this.lookup,
    required this.onOpen,
  });

  int _votes(AwardNominee n) => voteOverrides[n.nomineeId] ?? n.votes;
  int _totalVotes() {
    var t = 0;
    for (final n in topThree) t += _votes(n);
    return t > 0 ? t : 1;
  }

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.title, style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          if (leader != null) ...[
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AurixTokens.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: _avatar(lookup.artistFor(leader!.nomineeId), leader!.displayTitle),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#1 ${leader!.displayTitle}', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
                      Text('${_votes(leader!)} голосов', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            VotesProgressBar(
              leaderVotes: _votes(leader!),
              secondVotes: topThree.length > 1 ? _votes(topThree[1]) : 0,
              totalVotes: _totalVotes(),
            ),
          ],
          const SizedBox(height: 16),
          OutlinedButton(
            onPressed: onOpen,
            style: OutlinedButton.styleFrom(
              foregroundColor: AurixTokens.orange,
              side: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            child: const Text('Открыть'),
          ),
        ],
      ),
    );
  }

  Widget _avatar(dynamic artist, String name) {
    if (artist != null && artist.avatarUrl != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(10), child: Image.network(artist.avatarUrl!, fit: BoxFit.cover));
    }
    return Center(
      child: Text(
        name.trim().isNotEmpty ? name.trim().substring(0, 1).toUpperCase() : '?',
        style: TextStyle(color: AurixTokens.orange, fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}
