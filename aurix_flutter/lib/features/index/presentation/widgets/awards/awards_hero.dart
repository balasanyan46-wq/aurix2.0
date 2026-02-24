import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_data.dart' show formatNumber, IndexDataLookup;

class AwardsHero extends StatelessWidget {
  final int seasonYear;
  final int participants;
  final int votesTotal;
  final DateTime updatedAt;
  final AwardNominee? leader;
  final IndexDataLookup lookup;

  const AwardsHero({
    super.key,
    required this.seasonYear,
    required this.participants,
    required this.votesTotal,
    required this.updatedAt,
    this.leader,
    required this.lookup,
  });

  @override
  Widget build(BuildContext context) {
    final artist = leader != null ? lookup.artistFor(leader!.nomineeId) : null;
    final score = leader != null ? lookup.scoreFor(leader!.nomineeId) : null;
    final votes = leader?.votes ?? 0;

    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AurixTokens.bg1,
            AurixTokens.bg2.withValues(alpha: 0.8),
          ],
        ),
        border: Border.all(color: AurixTokens.stroke(0.12), width: 1),
        boxShadow: [
          BoxShadow(
            color: AurixTokens.orange.withValues(alpha: 0.06),
            blurRadius: 40,
            spreadRadius: -8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'AURIX AWARDS $seasonYear',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                            color: AurixTokens.text,
                          ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Главная премия независимой сцены. Номинанты на основе Aurix Рейтинг.',
                      style: TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 15,
                        height: 1.4,
                      ),
                    ),
                  ],
                ),
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  _KpiChip(icon: Icons.people_rounded, text: 'Участников: ${formatNumber(participants)}'),
                  _KpiChip(icon: Icons.how_to_vote_rounded, text: 'Голосов: ${formatNumber(votesTotal)}'),
                  _KpiChip(
                    icon: Icons.update_rounded,
                    text: 'Обновлено: ${_formatTime(updatedAt)}',
                  ),
                ],
              ),
            ],
          ),
          if (leader != null && artist != null) ...[
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AurixTokens.glass(0.08),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.2), width: 1),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AurixTokens.orange.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: artist.avatarUrl != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(14),
                            child: Image.network(artist.avatarUrl!, fit: BoxFit.cover),
                          )
                        : Center(
                            child: Text(
                              artist.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(color: AurixTokens.orange, fontSize: 24, fontWeight: FontWeight.w700),
                            ),
                          ),
                  ),
                  const SizedBox(width: 20),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Лидер сезона', style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                        const SizedBox(height: 4),
                        Text('#1 ${artist.name}', style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Text('Index: ${score?.score ?? leader?.scoreProof ?? 0}', style: TextStyle(color: AurixTokens.orange, fontSize: 14, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 16),
                            Text('Votes: $votes', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                            if (score != null && score.trendDelta != 0) ...[
                              const SizedBox(width: 12),
                              Text(
                                '${score.trendDelta > 0 ? '+' : ''}${score.trendDelta}',
                                style: TextStyle(color: score.trendDelta > 0 ? Colors.green : AurixTokens.muted, fontSize: 14, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                  FilledButton.icon(
                    onPressed: () => context.push('/index/artist/${leader!.nomineeId}'),
                    icon: const Icon(Icons.person_rounded, size: 18),
                    label: const Text('Посмотреть профиль'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AurixTokens.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime dt) {
    final now = DateTime.now();
    if (dt.day == now.day && dt.month == now.month && dt.year == now.year) {
      return 'сегодня, ${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    }
    return '${dt.day}.${dt.month}.${dt.year}';
  }
}

class _KpiChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _KpiChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AurixTokens.muted),
          const SizedBox(width: 8),
          Text(text, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        ],
      ),
    );
  }
}
