import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_data.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/nominee_row.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/votes_progress_bar.dart';

class CategoryFeaturedCard extends StatelessWidget {
  final AwardCategory category;
  final AwardNominee? leader;
  final List<AwardNominee> finalists;
  final Map<String, int> voteOverrides;
  final IndexDataLookup lookup;
  final void Function(String nomineeId)? onVote;
  final VoidCallback? onOpenModal;

  const CategoryFeaturedCard({
    super.key,
    required this.category,
    required this.leader,
    required this.finalists,
    required this.voteOverrides,
    required this.lookup,
    this.onVote,
    this.onOpenModal,
  });

  int _votes(AwardNominee n) => voteOverrides[n.nomineeId] ?? n.votes;
  int _totalVotes() {
    var t = 0;
    for (final n in finalists) t += _votes(n);
    return t > 0 ? t : 1;
  }

  @override
  Widget build(BuildContext context) {
    final canVote = category.isPublicVoting && onVote != null;
    final votingOpens = !category.isPublicVoting;

    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(category.title, style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(category.description, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          const SizedBox(height: 24),
          if (leader != null) ...[
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: AurixTokens.orange.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: _avatar(lookup.artistFor(leader!.nomineeId), leader!.displayTitle),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('#1 ${leader!.displayTitle}', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text('Index: ${leader!.scoreProof}', style: TextStyle(color: AurixTokens.orange, fontSize: 14, fontWeight: FontWeight.w600)),
                          const SizedBox(width: 12),
                          Text('${_votes(leader!)} голосов', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            VotesProgressBar(
              leaderVotes: _votes(leader!),
              secondVotes: finalists.length > 1 ? _votes(finalists[1]) : 0,
              totalVotes: _totalVotes(),
            ),
          ],
          if (finalists.isNotEmpty) ...[
            const SizedBox(height: 20),
            Text('Финалисты', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
            const SizedBox(height: 12),
            ...finalists.asMap().entries.map((e) {
              if (e.key == 0 && leader != null && e.value.nomineeId == leader!.nomineeId) return const SizedBox.shrink();
              return NomineeRow(
                nominee: e.value,
                displayVotes: _votes(e.value),
                trendDelta: lookup.scoreFor(e.value.nomineeId)?.trendDelta,
                artist: lookup.artistFor(e.value.nomineeId),
                rank: e.key + 1,
                onVote: canVote ? () => onVote!(e.value.nomineeId) : null,
                compact: true,
              );
            }),
          ],
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (votingOpens)
                Text('Голосование откроется 1 марта', style: TextStyle(color: AurixTokens.muted, fontSize: 13))
              else if (canVote)
                FilledButton(
                  onPressed: onOpenModal,
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.orange,
                    foregroundColor: Colors.black,
                  ),
                  child: const Text('Голосовать'),
                )
              else if (onOpenModal != null)
                OutlinedButton(
                  onPressed: onOpenModal,
                  style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange, side: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5))),
                  child: const Text('Открыть'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _avatar(dynamic artist, String name) {
    if (artist != null && artist.avatarUrl != null) {
      return ClipRRect(borderRadius: BorderRadius.circular(14), child: Image.network(artist.avatarUrl!, fit: BoxFit.cover));
    }
    return Center(
      child: Text(name.substring(0, 1).toUpperCase(), style: TextStyle(color: AurixTokens.orange, fontSize: 22, fontWeight: FontWeight.w700)),
    );
  }
}
