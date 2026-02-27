import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';

class IndexProfileTab extends ConsumerWidget {
  const IndexProfileTab({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(indexProvider);
    final data = state.data;
    if (data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AurixTokens.accent),
      );
    }

    final artist = data.selectedArtist ?? data.artists.firstOrNull;
    final score = artist != null ? data.scoreFor(artist.id) : null;

    final padding = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AurixGlassCard(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Выберите артиста', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  value: data.selectedArtistId ?? artist?.id,
                  dropdownColor: AurixTokens.bg2,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AurixTokens.glass(0.06),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  items: data.artists.map((a) => DropdownMenuItem(value: a.id, child: Text(a.name, style: TextStyle(color: AurixTokens.text)))).toList(),
                  onChanged: (v) => ref.read(indexProvider.notifier).selectArtist(v),
                ),
              ],
            ),
          ),
          if (artist != null && score != null) ...[
            const SizedBox(height: 24),
            _ProfileHeader(artist: artist, score: score),
            const SizedBox(height: 24),
            _ProfileMetrics(data: data, artistId: artist.id),
            const SizedBox(height: 24),
            _ImproveIndexCard(score: score),
          ],
        ],
      ),
    );
  }
}

extension _FirstOrNull<T> on List<T> {
  T? get firstOrNull => isEmpty ? null : first;
}

class _ProfileHeader extends StatelessWidget {
  final Artist artist;
  final IndexScore score;

  const _ProfileHeader({required this.artist, required this.score});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: AurixTokens.orange.withValues(alpha: 0.3),
                child: Text(
                  artist.name.trim().isNotEmpty
                      ? artist.name.trim().substring(0, 1).toUpperCase()
                      : '?',
                  style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w800, fontSize: 32),
                ),
              ),
              const SizedBox(width: 24),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(artist.name, style: TextStyle(color: AurixTokens.text, fontSize: 24, fontWeight: FontWeight.w700)),
                    Text(artist.genrePrimary, style: TextStyle(color: AurixTokens.muted, fontSize: 15)),
                    if (artist.location != null) Text(artist.location!, style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${score.score}', style: TextStyle(color: AurixTokens.orange, fontSize: 40, fontWeight: FontWeight.w800)),
                  Text('Aurix Рейтинг', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  if (score.trendDelta != 0)
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text(
                        '${score.trendDelta > 0 ? '+' : ''}${score.trendDelta} за период',
                        style: TextStyle(color: score.trendDelta > 0 ? Colors.green : AurixTokens.muted, fontSize: 14),
                      ),
                    ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _StatCell(label: 'Overall', value: '#${score.rankOverall}'),
              _StatCell(label: 'В жанре', value: '#${score.rankInGenre}'),
            ],
          ),
          if (score.badges.isNotEmpty) ...[
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: score.badges.map((b) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.5)),
                ),
                child: Text(_badgeLabel(b), style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
              )).toList(),
            ),
          ],
        ],
      ),
    );
  }

  String _badgeLabel(String id) {
    switch (id) {
      case 'top10': return 'Top 10';
      case 'rising': return 'Rising Star';
      case 'consistent': return 'Consistent';
      case 'viral': return 'Viral';
      default: return id;
    }
  }
}

class _StatCell extends StatelessWidget {
  final String label;
  final String value;

  const _StatCell({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Text(value, style: TextStyle(color: AurixTokens.orange, fontSize: 20, fontWeight: FontWeight.w700)),
        Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
      ],
    );
  }
}

class _ProfileMetrics extends StatelessWidget {
  final IndexData data;
  final String artistId;

  const _ProfileMetrics({required this.data, required this.artistId});

  @override
  Widget build(BuildContext context) {
    // MVP: мы не храним snapshots в IndexData. Пока заглушка или берём из repo.
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Метрики', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          Text(
            'Детальные метрики (listeners, streams, saves, shares) будут доступны при подключении DSP API.',
            style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.4),
          ),
        ],
      ),
    );
  }
}

class _ImproveIndexCard extends StatelessWidget {
  final IndexScore score;

  const _ImproveIndexCard({required this.score});

  @override
  Widget build(BuildContext context) {
    final tips = <String>[];
    if (!score.badges.contains('consistent')) tips.add('Выпускай релизы регулярно — минимум 2 в месяц');
    if (!score.badges.contains('rising')) tips.add('Работай над ростом слушателей и стримов');
    if (!score.badges.contains('viral')) tips.add('Поощряй шеринг и делай коллабы');
    if (score.rankOverall > 10) tips.add('Цель: попасть в Top 10 — повышай все компоненты индекса');
    if (tips.isEmpty) tips.add('Продолжай в том же духе!');

    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up_rounded, color: AurixTokens.orange, size: 24),
              const SizedBox(width: 12),
              Text('Как улучшить индекс', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 16),
          ...tips.map((t) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('• ', style: TextStyle(color: AurixTokens.orange)),
                    Expanded(child: Text(t, style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.4))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}
