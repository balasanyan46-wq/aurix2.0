import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/reports_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/presentation/screens/home/producer_providers.dart';
import 'package:aurix_flutter/presentation/screens/home/widgets/home_shared.dart';
import 'package:aurix_flutter/presentation/screens/home/widgets/release_blocks.dart';
import 'package:aurix_flutter/presentation/screens/home/widgets/action_blocks.dart';
import 'package:aurix_flutter/presentation/screens/home/widgets/stats_blocks.dart';
import 'package:aurix_flutter/presentation/screens/home/widgets/growth_block.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onViewDemo,
    this.onCreateRelease,
    this.onViewReleases,
    this.onViewSubscription,
    this.onViewIndex,
    this.onOpenStudioAi,
    this.onOpenPromotion,
    this.onOpenAnalytics,
    this.onOpenFinances,
    this.onOpenTeam,
    this.onOpenLegal,
    this.onOpenReleaseDetails,
    this.onOpenAchievements,
    this.onOpenGoals,
  });

  final VoidCallback? onViewDemo;
  final VoidCallback? onCreateRelease;
  final VoidCallback? onViewReleases;
  final VoidCallback? onViewSubscription;
  final VoidCallback? onViewIndex;
  final VoidCallback? onOpenStudioAi;
  final VoidCallback? onOpenPromotion;
  final VoidCallback? onOpenAnalytics;
  final VoidCallback? onOpenFinances;
  final VoidCallback? onOpenTeam;
  final VoidCallback? onOpenLegal;
  final void Function(String releaseId)? onOpenReleaseDetails;
  final VoidCallback? onOpenAchievements;
  final VoidCallback? onOpenGoals;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);
    final reduceMotion = MediaQuery.of(context).accessibleNavigation;
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    final releasesAsync = ref.watch(releasesProvider);
    final rowsAsync = ref.watch(userReportRowsProvider);
    final releases = releasesAsync.valueOrNull ?? const <ReleaseModel>[];
    final rows = rowsAsync.valueOrNull ?? const <ReportRowModel>[];
    final focusRelease = _focusRelease(releases);
    final trackCountAsync = focusRelease == null
        ? const AsyncValue<int>.data(0)
        : ref.watch(trackCountByReleaseProvider(focusRelease.id));
    final trackCount = trackCountAsync.valueOrNull ?? 0;

    final loading = releasesAsync.isLoading && rowsAsync.isLoading && releases.isEmpty;
    final activeRelease = focusRelease;

    final hasCover = (focusRelease?.coverUrl?.isNotEmpty ?? false) ||
        (focusRelease?.coverPath?.isNotEmpty ?? false);
    final hasMaterial = trackCount > 0;
    final hasLaunch = _isLaunchStage(focusRelease?.status);
    final doneSteps = [hasCover, hasMaterial, hasLaunch].where((v) => v).length;
    final releaseProgress = doneSteps / 3;

    final analytics = _buildAnalytics(rows);
    final monthRevenue = _monthRevenue(rows);

    if (loading) {
      return PremiumPageContainer(
        padding: EdgeInsets.fromLTRB(
          isMobile ? 16 : 24,
          isMobile ? 16 : 22,
          isMobile ? 16 : 24,
          28,
        ),
        child: const HomeLoadingSkeleton(),
      );
    }

    return PremiumPageContainer(
      maxWidth: 1140,
      padding: EdgeInsets.fromLTRB(
        isMobile ? 16 : 24,
        isMobile ? 16 : 22,
        isMobile ? 16 : 24,
        30,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          HomeAppear(
            delayMs: 0,
            reduceMotion: reduceMotion,
            child: const HomeDashboardHeader(),
          ),
          const SizedBox(height: 16),
          HomeAppear(
            delayMs: 40,
            reduceMotion: reduceMotion,
            child: activeRelease != null
                ? CurrentReleaseBlock(
                    release: activeRelease,
                    progress: releaseProgress,
                    hasCover: hasCover,
                    hasMaterial: hasMaterial,
                    hasLaunch: hasLaunch,
                    onContinue: () => _openRelease(appState, activeRelease),
                  )
                : CreateFirstReleaseBlock(
                    onCreate: () => _createRelease(context, appState),
                  ),
          ),
          const SizedBox(height: 20),
          HomeAppear(
            delayMs: 70,
            reduceMotion: reduceMotion,
            child: QuickActionsBlock(
              onCreateRelease: () => _createRelease(context, appState),
              onUploadTrack: () => _openRelease(appState, focusRelease),
              onGenerateCover: () => _openStudio(appState),
              onPromotion: () => _openPromotion(appState),
            ),
          ),
          const SizedBox(height: 20),
          HomeAppear(
            delayMs: 100,
            reduceMotion: reduceMotion,
            child: GrowthBlock(
              onOpenAchievements: widget.onOpenAchievements,
              onOpenGoals: widget.onOpenGoals,
            ),
          ),
          const SizedBox(height: 20),
          HomeAppear(
            delayMs: 160,
            reduceMotion: reduceMotion,
            child: AnalyticsBlock(
              analytics: analytics,
              onOpenAnalytics: () => _openAnalytics(appState),
            ),
          ),
          const SizedBox(height: 20),
          HomeAppear(
            delayMs: 180,
            reduceMotion: reduceMotion,
            child: FinanceBlock(
              revenue: monthRevenue,
              onOpen: () => _openFinances(appState),
            ),
          ),
          const SizedBox(height: 20),
          HomeAppear(
            delayMs: 230,
            reduceMotion: reduceMotion,
            child: ToolsBlock(
              onStudio: () => _openStudio(appState),
              onPromotion: () => _openPromotion(appState),
              onTeam: () => _openTeam(appState),
              onLegal: () => _openLegal(appState),
            ),
          ),
        ],
      ),
    );
  }

  void _openRelease(AppState appState, ReleaseModel? focusRelease) {
    if (focusRelease != null) {
      final cb = widget.onOpenReleaseDetails;
      if (cb != null) {
        cb(focusRelease.id);
      } else {
        appState.navigateTo(AppScreen.releaseDetails, releaseId: focusRelease.id);
      }
    } else {
      (widget.onViewReleases ?? () => appState.navigateTo(AppScreen.releases))();
    }
  }

  void _openStudio(AppState appState) {
    (widget.onOpenStudioAi ?? () => appState.navigateTo(AppScreen.studioAi))();
  }

  void _openPromotion(AppState appState) {
    (widget.onOpenPromotion ?? () => appState.navigateTo(AppScreen.promotion))();
  }

  void _openAnalytics(AppState appState) {
    (widget.onOpenAnalytics ?? () => appState.navigateTo(AppScreen.analytics))();
  }

  void _openFinances(AppState appState) {
    (widget.onOpenFinances ?? () => appState.navigateTo(AppScreen.finances))();
  }

  void _openTeam(AppState appState) {
    (widget.onOpenTeam ?? () => appState.navigateTo(AppScreen.team))();
  }

  void _openLegal(AppState appState) {
    (widget.onOpenLegal ?? () => appState.navigateTo(AppScreen.legal))();
  }

  bool _isLaunchStage(String? status) {
    if (status == null) return false;
    return status == 'submitted' ||
        status == 'in_review' ||
        status == 'approved' ||
        status == 'scheduled' ||
        status == 'live';
  }

  ReleaseModel? _focusRelease(List<ReleaseModel> releases) {
    if (releases.isEmpty) return null;
    final drafts = releases.where((r) => r.isDraft).toList();
    if (drafts.isNotEmpty) return drafts.first;
    return releases.first;
  }

  void _createRelease(BuildContext context, AppState appState) {
    final cb = widget.onCreateRelease ??
        (appState.canSubmitRelease
            ? () {}
            : () => _showUpgradeModal(context, ref, widget.onViewSubscription));
    cb();
  }

  AnalyticsViewModel _buildAnalytics(List<ReportRowModel> rows) {
    if (rows.isEmpty) return const AnalyticsViewModel.empty();

    final now = DateTime.now();
    final points = List<double>.filled(7, 0);
    var streams = 0;

    for (final row in rows) {
      final d = row.reportDate;
      if (d == null) continue;
      final day = DateTime(d.year, d.month, d.day);
      final diff = now.difference(day).inDays;
      if (diff < 0 || diff > 6) continue;
      final idx = 6 - diff;
      points[idx] += row.streams.toDouble();
      streams += row.streams;
    }

    return AnalyticsViewModel(
      hasData: points.any((v) => v > 0),
      streams: streams,
      savesText: 'Нет данных',
      points: points,
    );
  }

  double _monthRevenue(List<ReportRowModel> rows) {
    final now = DateTime.now();
    return rows
        .where((r) =>
            r.reportDate != null &&
            r.reportDate!.year == now.year &&
            r.reportDate!.month == now.month)
        .fold<double>(0, (sum, r) => sum + r.revenue);
  }

  void _showUpgradeModal(
    BuildContext context,
    WidgetRef ref,
    VoidCallback? onViewSubscription,
  ) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text(L10n.t(context, 'upgradeRequired')),
        content: Text(L10n.t(context, 'upgradeRequiredDesc')),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(L10n.t(context, 'back')),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              (onViewSubscription ??
                  () => ref.read(appStateProvider).navigateTo(AppScreen.subscription))();
            },
            child: Text(L10n.t(context, 'viewPlans')),
          ),
        ],
      ),
    );
  }
}
