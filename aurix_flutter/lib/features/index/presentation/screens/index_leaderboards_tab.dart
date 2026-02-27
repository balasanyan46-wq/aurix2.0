import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';
import 'package:aurix_flutter/features/index_engine/presentation/providers/artist_insights_provider.dart';

class IndexLeaderboardsTab extends ConsumerStatefulWidget {
  const IndexLeaderboardsTab({super.key});

  @override
  ConsumerState<IndexLeaderboardsTab> createState() => _IndexLeaderboardsTabState();
}

class _IndexLeaderboardsTabState extends ConsumerState<IndexLeaderboardsTab> {
  String _filter = 'overall'; // overall, genre
  String _period = 'this_month'; // this_month, last_month
  String? _genreFilter;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indexProvider);
    final data = state.data;
    final levelEngine = ref.watch(levelEngineProvider);
    if (data == null) {
      return const Center(
        child: CircularProgressIndicator(color: AurixTokens.accent),
      );
    }

    var scores = data.scores;
    final genres = data.artists.map((a) => a.genrePrimary).toSet().toList()..sort();
    if (_filter == 'genre' && _genreFilter != null) {
      final artistIds = data.artists.where((a) => a.genrePrimary == _genreFilter).map((a) => a.id).toSet();
      scores = scores.where((s) => artistIds.contains(s.artistId)).toList();
    }
    scores = scores.take(50).toList();

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 24.0 : 16.0;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'РЕЙТИНГ',
            style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 2),
          ),
          const SizedBox(height: 12),
          AurixGlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _FilterChip(
                    label: 'Overall',
                    selected: _filter == 'overall',
                    onTap: () => setState(() => _filter = 'overall'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'По жанрам',
                    selected: _filter == 'genre',
                    onTap: () => setState(() {
                      _filter = 'genre';
                      if (_genreFilter == null && data.artists.isNotEmpty) {
                        _genreFilter = data.artists.map((a) => a.genrePrimary).toSet().first;
                      }
                    }),
                  ),
                  const SizedBox(width: 16),
                  _FilterChip(
                    label: 'Этот месяц',
                    selected: _period == 'this_month',
                    onTap: () => setState(() => _period = 'this_month'),
                  ),
                  const SizedBox(width: 8),
                  _FilterChip(
                    label: 'Пред. месяц',
                    selected: _period == 'last_month',
                    onTap: () => setState(() => _period = 'last_month'),
                  ),
                ],
              ),
            ),
          ),
          if (_filter == 'genre') ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: genres.map((g) => _FilterChip(
                label: g,
                selected: _genreFilter == g,
                onTap: () => setState(() => _genreFilter = _genreFilter == g ? null : g),
              )).toList(),
            ),
          ],
          const SizedBox(height: 20),
          AurixGlassCard(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: scores.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: AurixTokens.stroke(0.08)),
              itemBuilder: (context, i) {
                final score = scores[i];
                final artist = data.artistFor(score.artistId);
                if (artist == null) return const SizedBox.shrink();
                final rank = _filter == 'genre' ? (data.scores.where((s) => data.artistFor(s.artistId)?.genrePrimary == artist.genrePrimary).toList().indexWhere((s) => s.artistId == score.artistId) + 1) : (i + 1);
                final level = levelEngine.getLevel(score.score);
                return InkWell(
                  onTap: () => context.push('/index/artist/${score.artistId}'),
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: isDesktop ? 20 : 12, vertical: 10),
                    child: Row(
                      children: [
                        SizedBox(
                          width: 32,
                          child: Text(
                            '#$rank',
                            style: TextStyle(
                              color: rank == 1 ? const Color(0xFFE8A317) : rank == 2 ? const Color(0xFF9CA3AF) : rank == 3 ? const Color(0xFFCD7F32) : AurixTokens.muted,
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              fontFeatures: AurixTokens.tabularFigures,
                            ),
                          ),
                        ),
                        CircleAvatar(
                          radius: isDesktop ? 20 : 16,
                          backgroundColor: AurixTokens.accent.withValues(alpha: 0.12),
                          child: Text(
                            artist.name.trim().isNotEmpty
                                ? artist.name.trim().substring(0, 1).toUpperCase()
                                : '?',
                            style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w600, fontSize: isDesktop ? 14 : 12),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                artist.name,
                                style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                                maxLines: 1,
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Flexible(
                                    child: Text(
                                      artist.genrePrimary,
                                      style: TextStyle(color: AurixTokens.muted, fontSize: 11),
                                      overflow: TextOverflow.ellipsis,
                                      maxLines: 1,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                                    decoration: BoxDecoration(
                                      color: AurixTokens.accent.withValues(alpha: 0.12),
                                      border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.4)),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(level.title, style: TextStyle(color: AurixTokens.accent, fontSize: 9, fontWeight: FontWeight.w600)),
                                  ),
                                ],
                              ),
                              if (score.badges.isNotEmpty) ...[
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: score.badges.take(isDesktop ? 3 : 2).map((b) {
                                    return Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: AurixTokens.accent.withValues(alpha: 0.10),
                                        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.35)),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        b,
                                        style: TextStyle(color: AurixTokens.accent, fontSize: 9, fontWeight: FontWeight.w600),
                                      ),
                                    );
                                  }).toList(),
                                ),
                              ],
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text('${score.score}', style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w700, fontSize: 14, fontFeatures: AurixTokens.tabularFigures)),
                            if (score.trendDelta != 0)
                              Text(
                                '${score.trendDelta > 0 ? '+' : ''}${score.trendDelta}',
                                style: TextStyle(color: score.trendDelta > 0 ? AurixTokens.positive : AurixTokens.muted, fontSize: 11, fontFeatures: AurixTokens.tabularFigures),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

}

class _FilterChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.accent.withValues(alpha: 0.12) : AurixTokens.bg2,
          border: Border.all(color: selected ? AurixTokens.accent : AurixTokens.border),
        ),
        child: Text(label, style: TextStyle(color: selected ? AurixTokens.accent : AurixTokens.muted, fontWeight: selected ? FontWeight.w600 : FontWeight.w500)),
      ),
    );
  }
}
