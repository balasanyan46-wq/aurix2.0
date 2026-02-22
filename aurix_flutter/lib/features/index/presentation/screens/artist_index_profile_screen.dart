import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';
import 'package:aurix_flutter/features/index_engine/presentation/providers/artist_insights_provider.dart';
import 'package:aurix_flutter/features/index_engine/presentation/widgets/level_progress_widget.dart';
import 'package:aurix_flutter/features/index_engine/presentation/widgets/badges_grid_widget.dart';
import 'package:aurix_flutter/features/index_engine/presentation/widgets/next_steps_list_widget.dart';

class ArtistIndexProfileScreen extends ConsumerWidget {
  const ArtistIndexProfileScreen({super.key, required this.artistId});

  final String artistId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.read(indexProvider.notifier).selectArtist(artistId);
    final state = ref.watch(indexProvider);
    final data = state.data;
    final artist = data?.artistFor(artistId);
    final score = data?.scoreFor(artistId);
    final insightsAsync = ref.watch(artistInsightsProvider(artistId));

    if (data == null || artist == null) {
      return Scaffold(
        body: Center(
          child: state.state == IndexState.loading
              ? const CircularProgressIndicator(color: AurixTokens.accent)
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Артист не найден', style: TextStyle(color: AurixTokens.muted)),
                    const SizedBox(height: 16),
                    TextButton(onPressed: () => context.go('/index'), child: const Text('Назад')),
                  ],
                ),
        ),
      );
    }

    final padding = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint ? 24.0 : 16.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: SingleChildScrollView(
        padding: EdgeInsets.all(padding),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
                      onPressed: () => context.go('/index'),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'ПРОФИЛЬ',
                        style: TextStyle(
                          color: AurixTokens.text,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                if (insightsAsync.valueOrNull != null) ...[
                  LevelProgressWidget(
                    level: insightsAsync.value!.level,
                    progressToNext: insightsAsync.value!.progressToNext,
                    pointsToNext: insightsAsync.value!.pointsToNext,
                  ),
                  const SizedBox(height: 20),
                ],
                AurixGlassCard(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Row(
                        children: [
                          CircleAvatar(
                            radius: 48,
                            backgroundColor: AurixTokens.accent.withValues(alpha: 0.12),
                            child: Text(
                              artist.name.substring(0, 1).toUpperCase(),
                              style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w800, fontSize: 36),
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
                          if (score != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text('${score.score}', style: TextStyle(color: AurixTokens.accent, fontSize: 48, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
                                Text('AURIX INDEX', style: TextStyle(color: AurixTokens.muted, fontSize: 11, letterSpacing: 1)),
                                if (score.trendDelta != 0)
                                  Text(
                                    '${score.trendDelta > 0 ? '+' : ''}${score.trendDelta}',
                                    style: TextStyle(color: score.trendDelta > 0 ? AurixTokens.positive : AurixTokens.muted, fontSize: 14, fontFeatures: AurixTokens.tabularFigures),
                                  ),
                              ],
                            ),
                        ],
                      ),
                      if (score != null) ...[
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _StatCell(label: 'Overall', value: '#${score.rankOverall}'),
                            _StatCell(label: 'В жанре', value: '#${score.rankInGenre}'),
                          ],
                        ),
                        if (score.badges.isNotEmpty && insightsAsync.valueOrNull == null) ...[
                          const SizedBox(height: 20),
                          Wrap(
                            spacing: 10,
                            runSpacing: 10,
                            children: score.badges.map((b) => Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: AurixTokens.accent.withValues(alpha: 0.12),
                                border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.4)),
                              ),
                              child: Text(_badgeLabel(b), style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w600, fontSize: 12)),
                            )).toList(),
                          ),
                        ],
                      ],
                    ],
                  ),
                ),
                if (insightsAsync.valueOrNull != null && insightsAsync.value!.badges.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  AurixGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('ДОСТИЖЕНИЯ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1)),
                        const SizedBox(height: 16),
                        BadgesGridWidget(badges: insightsAsync.value!.badges),
                      ],
                    ),
                  ),
                ],
                if (insightsAsync.valueOrNull != null) ...[
                  const SizedBox(height: 24),
                  AurixGlassCard(
                    padding: const EdgeInsets.all(20),
                    child: NextStepsListWidget(plan: insightsAsync.value!.nextStepPlan),
                  ),
                ],
              ],
            ),
          ),
        ),
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
        Text(value, style: TextStyle(color: AurixTokens.accent, fontSize: 20, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
        Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
      ],
    );
  }
}
