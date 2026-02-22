import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';

class IndexOverviewTab extends ConsumerWidget {
  const IndexOverviewTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(indexProvider);
    final data = state.data;
    if (data == null) return const SizedBox.shrink();

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 24.0 : 16.0;

    final top1 = data.topLeader;
    final topRising = data.topRising;
    final myScore = data.selectedScore;
    final myArtist = data.selectedArtist;

    final recommendations = <String>[];
    if (myScore != null) {
      if (myScore.score < 500) recommendations.add('Увеличь регулярность релизов');
      if (myScore.badges.isEmpty || !myScore.badges.contains('rising')) recommendations.add('Работай над ростом слушателей');
      if (!myScore.badges.contains('viral')) recommendations.add('Делай коллабы и поощряй шеринг');
    }
    if (recommendations.isEmpty) recommendations.add('Продолжай в том же духе');
    recommendations.add('Добавляй новые треки в плейлисты');
    recommendations.add('Прокачивай completion rate — качество треков');

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (isDesktop)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    children: [
                      if (top1 != null) _LeaderCard(data: data, score: top1, label: 'Лидер месяца'),
                      const SizedBox(height: 20),
                      if (topRising != null && topRising.artistId != top1?.artistId)
                        _LeaderCard(data: data, score: topRising, label: 'Самый быстрый рост'),
                    ],
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    children: [
                      if (myScore != null && myArtist != null)
                        _MyIndexCard(artist: myArtist, score: myScore),
                      const SizedBox(height: 20),
                      _RecommendationsCard(recommendations: recommendations),
                    ],
                  ),
                ),
              ],
            )
          else
            Column(
              children: [
                if (top1 != null) _LeaderCard(data: data, score: top1, label: 'Лидер месяца'),
                const SizedBox(height: 20),
                if (topRising != null && topRising.artistId != top1?.artistId)
                  _LeaderCard(data: data, score: topRising, label: 'Самый быстрый рост'),
                const SizedBox(height: 20),
                if (myScore != null && myArtist != null) _MyIndexCard(artist: myArtist, score: myScore),
                const SizedBox(height: 20),
                _RecommendationsCard(recommendations: recommendations),
              ],
            ),
        ],
      ),
    );
  }
}

class _LeaderCard extends StatelessWidget {
  final IndexData data;
  final IndexScore score;
  final String label;

  const _LeaderCard({required this.data, required this.score, required this.label});

  @override
  Widget build(BuildContext context) {
    final artist = data.artistFor(score.artistId);
    if (artist == null) return const SizedBox.shrink();
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: () => context.push('/index/artist/${score.artistId}'),
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label.toUpperCase(),
              style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: AurixTokens.accent.withValues(alpha: 0.12),
                  child: Text(
                    artist.name.substring(0, 1).toUpperCase(),
                    style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w700, fontSize: 20),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(artist.name, style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w600)),
                      Text(artist.genrePrimary, style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${score.score}', style: TextStyle(color: AurixTokens.accent, fontSize: 24, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
                    if (score.trendDelta != 0)
                      Text(
                        '${score.trendDelta > 0 ? '+' : ''}${score.trendDelta}',
                        style: TextStyle(
                          color: score.trendDelta > 0 ? AurixTokens.positive : AurixTokens.muted,
                          fontSize: 12,
                          fontFeatures: AurixTokens.tabularFigures,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MyIndexCard extends StatelessWidget {
  final Artist artist;
  final IndexScore score;

  const _MyIndexCard({required this.artist, required this.score});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'ТВОЙ ИНДЕКС',
            style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              CircleAvatar(
                radius: 32,
                backgroundColor: AurixTokens.accent.withValues(alpha: 0.12),
                child: Text(
                  artist.name.substring(0, 1).toUpperCase(),
                  style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w700, fontSize: 24),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(artist.name, style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w700)),
                    Text('№${score.rankOverall} overall · №${score.rankInGenre} в жанре', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${score.score}', style: TextStyle(color: AurixTokens.accent, fontSize: 32, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
                  if (score.trendDelta != 0)
                    Text(
                      '${score.trendDelta > 0 ? '+' : ''}${score.trendDelta}',
                      style: TextStyle(color: score.trendDelta > 0 ? AurixTokens.positive : AurixTokens.muted, fontSize: 14, fontFeatures: AurixTokens.tabularFigures),
                    ),
                ],
              ),
            ],
          ),
          if (score.badges.isNotEmpty) ...[
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: score.badges.map((b) => _BadgeChip(id: b)).toList(),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecommendationsCard extends StatelessWidget {
  final List<String> recommendations;

  const _RecommendationsCard({required this.recommendations});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'РЕКОМЕНДАЦИИ',
            style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1),
          ),
          const SizedBox(height: 16),
          ...recommendations.take(3).map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.arrow_forward_ios, size: 10, color: AurixTokens.muted),
                    const SizedBox(width: 10),
                    Expanded(child: Text(r, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final String id;

  const _BadgeChip({required this.id});

  @override
  Widget build(BuildContext context) {
    final (label, _) = _badgeInfo(id);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AurixTokens.accent.withValues(alpha: 0.12),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.4)),
      ),
      child: Text(label, style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }

  static (String, String) _badgeInfo(String id) {
    switch (id) {
      case 'top10': return ('Top 10', 'В топ-10 рейтинга');
      case 'rising': return ('Rising', 'Быстрый рост');
      case 'consistent': return ('Consistent', 'Регулярные релизы');
      case 'viral': return ('Viral', 'Высокий шеринг');
      default: return (id, id);
    }
  }
}
