import 'package:aurix_flutter/features/index/data/models/artist.dart';
import 'package:aurix_flutter/features/index/data/models/award_category.dart';
import 'package:aurix_flutter/features/index/data/models/award_nominee.dart';
import 'package:aurix_flutter/features/index/data/models/index_score.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';

/// Aggregated data for Awards page: totals, myStatus, enriched nominees.
class AwardsPageData {
  final int seasonYear;
  final int participants;
  final int votesTotal;
  final DateTime updatedAt;
  final int? myIndex;
  final int? myRank;
  final int? toTop10;
  final List<AwardCategory> featuredCategories;
  final List<AwardCategory> otherCategories;
  final IndexData indexData;

  const AwardsPageData({
    required this.seasonYear,
    required this.participants,
    required this.votesTotal,
    required this.updatedAt,
    this.myIndex,
    this.myRank,
    this.toTop10,
    required this.featuredCategories,
    required this.otherCategories,
    required this.indexData,
  });

  IndexDataLookup get lookup => _IndexDataLookupAdapter(indexData);

  List<AwardNominee> sortedNominees(AwardCategory cat, Map<String, int> voteOverrides) {
    final list = indexData.nomineesByCategory[cat.id] ?? [];
    final withVotes = list.map((n) => (n, votes: voteOverrides[n.nomineeId] ?? n.votes)).toList();
    if (cat.isPublicVoting) {
      withVotes.sort((a, b) => b.votes.compareTo(a.votes));
    } else {
      withVotes.sort((a, b) => b.$1.scoreProof.compareTo(a.$1.scoreProof));
    }
    return withVotes.map((e) => e.$1).toList();
  }

  AwardNominee? leader(AwardCategory cat, Map<String, int> voteOverrides) {
    final sorted = sortedNominees(cat, voteOverrides);
    return sorted.isEmpty ? null : sorted.first;
  }
}

/// Featured: best_artist, breakthrough, debut. Other: rest.
const _featuredIds = ['best_artist', 'breakthrough', 'debut'];

AwardsPageData? computeAwardsData(IndexData? data, int seasonYear) {
  if (data == null) return null;
  final cats = data.categories.where((c) => c.seasonYear == seasonYear).toList();
  final featured = cats.where((c) => _featuredIds.contains(c.id)).toList();
  final other = cats.where((c) => !_featuredIds.contains(c.id)).toList();

  final score = data.selectedScore;
  final myIndex = score?.score ?? 0;
  final myRank = score != null
      ? (data.scores.indexWhere((s) => s.artistId == score.artistId) + 1)
      : null;
  final top10Score = data.scores.length >= 10 ? data.scores[9].score : null;
  final toTop10 = (top10Score != null && myIndex > 0) ? (myIndex - top10Score) : null;

  int votesTotal = 30000;
  for (final list in data.nomineesByCategory.values) {
    for (final n in list) votesTotal += n.votes;
  }

  return AwardsPageData(
    seasonYear: seasonYear,
    participants: 1248,
    votesTotal: votesTotal,
    updatedAt: DateTime.now(),
    myIndex: myIndex > 0 ? myIndex : null,
    myRank: myRank,
    toTop10: toTop10,
    featuredCategories: featured,
    otherCategories: other,
    indexData: data,
  );
}

abstract class IndexDataLookup {
  Artist? artistFor(String id);
  IndexScore? scoreFor(String id);
}

class _IndexDataLookupAdapter implements IndexDataLookup {
  final IndexData _data;
  _IndexDataLookupAdapter(this._data);
  @override
  Artist? artistFor(String id) => _data.artistFor(id);
  @override
  IndexScore? scoreFor(String id) => _data.scoreFor(id);
}

String formatNumber(int n) {
  final s = n.toString();
  if (s.length <= 3) return s;
  final parts = <String>[];
  for (var i = s.length; i > 0; i -= 3) {
    parts.insert(0, s.substring(i - 3 > 0 ? i - 3 : 0, i));
  }
  return parts.join(' ');
}
