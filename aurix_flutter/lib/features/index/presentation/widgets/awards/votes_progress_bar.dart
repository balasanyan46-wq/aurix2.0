import 'package:flutter/material.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class VotesProgressBar extends StatelessWidget {
  final int leaderVotes;
  final int secondVotes;
  final int totalVotes;

  const VotesProgressBar({
    super.key,
    required this.leaderVotes,
    required this.secondVotes,
    required this.totalVotes,
  });

  @override
  Widget build(BuildContext context) {
    if (totalVotes == 0) return const SizedBox.shrink();
    final leaderPct = leaderVotes / totalVotes;
    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: leaderPct.clamp(0.0, 1.0),
        minHeight: 6,
        backgroundColor: AurixTokens.stroke(0.15),
        valueColor: AlwaysStoppedAnimation<Color>(AurixTokens.orange.withValues(alpha: 0.8)),
      ),
    );
  }
}
