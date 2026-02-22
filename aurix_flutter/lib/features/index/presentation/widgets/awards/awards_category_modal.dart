import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_data.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/nominee_row.dart';

class AwardsCategoryModal extends StatelessWidget {
  final AwardCategory category;
  final List<AwardNominee> nominees;
  final Map<String, int> voteOverrides;
  final IndexDataLookup lookup;
  final void Function(String nomineeId)? onVote;
  final VoidCallback onClose;

  const AwardsCategoryModal({
    super.key,
    required this.category,
    required this.nominees,
    required this.voteOverrides,
    required this.lookup,
    this.onVote,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final canVote = category.isPublicVoting && onVote != null;

    return Dialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560, maxHeight: 700),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(category.title, style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(category.description, style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: onClose,
                    icon: const Icon(Icons.close_rounded, color: AurixTokens.muted),
                  ),
                ],
              ),
            ),
            Divider(height: 1, color: AurixTokens.stroke(0.12)),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                itemCount: nominees.length,
                itemBuilder: (context, i) {
                  final n = nominees[i];
                  final artist = lookup.artistFor(n.nomineeId);
                  final score = lookup.scoreFor(n.nomineeId);
                  return NomineeRow(
                    nominee: n,
                    displayVotes: voteOverrides[n.nomineeId] ?? n.votes,
                    trendDelta: score?.trendDelta,
                    artist: artist,
                    rank: i + 1,
                    onVote: canVote ? () => onVote!(n.nomineeId) : null,
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Показать всех номинантов',
                style: TextStyle(color: AurixTokens.muted, fontSize: 13),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
