import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_category_modal.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_data.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/awards_hero.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/category_compact_card.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/category_featured_card.dart';
import 'package:aurix_flutter/features/index/presentation/widgets/awards/my_status_card.dart';

class IndexAwardsTab extends ConsumerStatefulWidget {
  const IndexAwardsTab({super.key});

  @override
  ConsumerState<IndexAwardsTab> createState() => _IndexAwardsTabState();
}

class _IndexAwardsTabState extends ConsumerState<IndexAwardsTab> {
  int _seasonYear = DateTime.now().year;
  final Map<String, int> _voteOverrides = {};

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(indexProvider);
    final data = state.data;
    if (data == null) return const SizedBox.shrink();

    final awardsData = computeAwardsData(data, _seasonYear);
    if (awardsData == null) return const SizedBox.shrink();

    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 24.0 : 16.0;

    final bestArtistCat = awardsData.featuredCategories.cast<AwardCategory?>().firstWhere(
          (c) => c?.id == 'best_artist',
          orElse: () => null,
        );
    final seasonLeader = bestArtistCat != null
        ? awardsData.leader(bestArtistCat, _voteOverrides)
        : awardsData.indexData.topLeader != null
            ? _leaderFromScore(awardsData, awardsData.indexData.topLeader!.artistId)
            : null;

    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _seasonSelector(context),
          const SizedBox(height: 24),
          AwardsHero(
            seasonYear: _seasonYear,
            participants: awardsData.participants,
            votesTotal: awardsData.votesTotal,
            updatedAt: awardsData.updatedAt,
            leader: seasonLeader,
            lookup: awardsData.lookup,
          ),
          const SizedBox(height: 24),
          MyStatusCard(
            myIndex: awardsData.myIndex,
            myRank: awardsData.myRank,
            toTop10: awardsData.toTop10,
            onHowToRise: () => _showHowToRise(context),
          ),
          const SizedBox(height: 40),
          _sectionTitle('Главные номинации'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth > 900) {
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final cat in awardsData.featuredCategories)
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.only(right: 16),
                          child: _buildFeaturedCard(awardsData, cat),
                        ),
                      ),
                  ],
                );
              }
              return Column(
                children: awardsData.featuredCategories
                    .map((cat) => Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _buildFeaturedCard(awardsData, cat),
                        ))
                    .toList(),
              );
            },
          ),
          const SizedBox(height: 40),
          _sectionTitle('Категории'),
          const SizedBox(height: 16),
          LayoutBuilder(
            builder: (context, c) {
              final crossCount = c.maxWidth > 700 ? 3 : (c.maxWidth > 480 ? 2 : 1);
              return GridView.count(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisCount: crossCount,
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.1,
                children: awardsData.otherCategories
                    .map((cat) => _buildCompactCard(awardsData, cat))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _seasonSelector(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.1)),
      ),
      child: Row(
        children: [
          Text('Сезон', style: TextStyle(color: AurixTokens.muted, fontWeight: FontWeight.w600, fontSize: 14)),
          const SizedBox(width: 12),
          DropdownButton<int>(
            value: _seasonYear,
            dropdownColor: AurixTokens.bg2,
            items: [DateTime.now().year, DateTime.now().year - 1]
                .map((y) => DropdownMenuItem(value: y, child: Text('$y', style: TextStyle(color: AurixTokens.text))))
                .toList(),
            onChanged: (v) => setState(() => _seasonYear = v ?? _seasonYear),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) {
    return Text(
      text,
      style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700),
    );
  }

  Widget _buildFeaturedCard(AwardsPageData data, AwardCategory cat) {
    final sorted = data.sortedNominees(cat, _voteOverrides);
    final leader = data.leader(cat, _voteOverrides);
    final finalists = sorted.take(4).toList();

    return CategoryFeaturedCard(
      category: cat,
      leader: leader,
      finalists: finalists,
      voteOverrides: _voteOverrides,
      lookup: data.lookup,
      onVote: cat.isPublicVoting ? (id) => _vote(cat.id, id) : null,
      onOpenModal: () => _showModal(context, cat),
    );
  }

  Widget _buildCompactCard(AwardsPageData data, AwardCategory cat) {
    final sorted = data.sortedNominees(cat, _voteOverrides);
    final leader = data.leader(cat, _voteOverrides);
    final topThree = sorted.take(3).toList();

    return CategoryCompactCard(
      category: cat,
      leader: leader,
      topThree: topThree,
      voteOverrides: _voteOverrides,
      lookup: data.lookup,
      onOpen: () => _showModal(context, cat),
    );
  }

  AwardNominee? _leaderFromScore(AwardsPageData data, String artistId) {
    for (final list in data.indexData.nomineesByCategory.values) {
      for (final n in list) {
        if (n.nomineeId == artistId) return n;
      }
    }
    return null;
  }

  void _vote(String categoryId, String nomineeId) {
    setState(() {
      _voteOverrides[nomineeId] = (_voteOverrides[nomineeId] ?? 0) + 1;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Голос принят'),
        backgroundColor: AurixTokens.bg2,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _showHowToRise(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurixTokens.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Как подняться в рейтинге', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _tip('Увеличь регулярность релизов', 'Выпускай треки раз в 1–2 месяца'),
            _tip('Работай над сохранениями', 'Saves и shares сильно влияют на Index'),
            _tip('Делай коллабы', 'Коллаборации повышают Community-компонент'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _tip(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AurixTokens.orange, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        ],
      ),
    );
  }

  void _showModal(BuildContext context, AwardCategory cat) {
    final state = ref.read(indexProvider);
    final data = state.data;
    if (data == null) return;

    final awardsData = computeAwardsData(data, _seasonYear);
    if (awardsData == null) return;

    final nominees = awardsData.sortedNominees(cat, _voteOverrides);

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) => AwardsCategoryModal(
          category: cat,
          nominees: nominees,
          voteOverrides: _voteOverrides,
          lookup: awardsData.lookup,
          onVote: cat.isPublicVoting
              ? (id) {
                  _vote(cat.id, id);
                  setModalState(() {});
                }
              : null,
          onClose: () => Navigator.of(ctx).pop(),
        ),
      ),
    );
  }
}
