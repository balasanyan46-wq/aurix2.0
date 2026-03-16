import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/reports_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/screens/home/producer_providers.dart';
import 'package:aurix_flutter/screens/releases/release_create_flow_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

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
        child: const _HomeLoadingSkeleton(),
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
          _Appear(
            delayMs: 0,
            reduceMotion: reduceMotion,
            child: const _DashboardHeader(),
          ),
          const SizedBox(height: 16),
          _Appear(
            delayMs: 40,
            reduceMotion: reduceMotion,
            child: activeRelease != null
                ? _CurrentReleaseBlock(
                    release: activeRelease,
                    progress: releaseProgress,
                    hasCover: hasCover,
                    hasMaterial: hasMaterial,
                    hasLaunch: hasLaunch,
                    onContinue: () => _openRelease(appState, activeRelease),
                  )
                : _CreateFirstReleaseBlock(
                    onCreate: () => _createRelease(context, appState),
                  ),
          ),
          const SizedBox(height: 20),
          _Appear(
            delayMs: 70,
            reduceMotion: reduceMotion,
            child: _QuickActionsBlock(
              onCreateRelease: () => _createRelease(context, appState),
              onUploadTrack: () => _openRelease(appState, focusRelease),
              onGenerateCover: () => _openStudio(appState),
              onPromotion: () => _openPromotion(appState),
            ),
          ),
          const SizedBox(height: 20),
          _Appear(
            delayMs: 130,
            reduceMotion: reduceMotion,
            child: _AnalyticsBlock(
              analytics: analytics,
              onOpenAnalytics: () => _openAnalytics(appState),
            ),
          ),
          const SizedBox(height: 20),
          _Appear(
            delayMs: 180,
            reduceMotion: reduceMotion,
            child: _FinanceBlock(
              revenue: monthRevenue,
              onOpen: () => _openFinances(appState),
            ),
          ),
          const SizedBox(height: 20),
          _Appear(
            delayMs: 230,
            reduceMotion: reduceMotion,
            child: _ToolsBlock(
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
            ? () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ReleaseCreateFlowScreen()),
                )
            : () => _showUpgradeModal(context, ref, widget.onViewSubscription));
    cb();
  }

  _AnalyticsViewModel _buildAnalytics(List<ReportRowModel> rows) {
    if (rows.isEmpty) return const _AnalyticsViewModel.empty();

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

    return _AnalyticsViewModel(
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

class _CreateFirstReleaseBlock extends StatelessWidget {
  const _CreateFirstReleaseBlock({required this.onCreate});
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(24),
      radius: 22,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Создать первый релиз',
            style: TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 30,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Начни с трека, обложки и базовых метаданных.',
            style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: onCreate,
            style: FilledButton.styleFrom(
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            ),
            child: const Text('Создать первый релиз'),
          ),
        ],
      ),
    );
  }
}

class _CurrentReleaseBlock extends StatelessWidget {
  const _CurrentReleaseBlock({
    required this.release,
    required this.progress,
    required this.hasCover,
    required this.hasMaterial,
    required this.hasLaunch,
    required this.onContinue,
  });

  final ReleaseModel release;
  final double progress;
  final bool hasCover;
  final bool hasMaterial;
  final bool hasLaunch;
  final VoidCallback onContinue;

  @override
  Widget build(BuildContext context) {
    final statusColor = release.isLive
        ? AurixTokens.positive
        : release.isSubmitted
            ? AurixTokens.warning
            : AurixTokens.orange;
    final status = releaseStatusFromString(release.status).label;

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _CoverThumb(url: release.coverUrl),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Текущий релиз',
                      style: TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.1,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      release.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AurixTokens.text,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  border: Border.all(color: statusColor.withValues(alpha: 0.4)),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  status,
                  style: TextStyle(color: statusColor, fontSize: 12, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 9,
              backgroundColor: AurixTokens.glass(0.16),
              valueColor: const AlwaysStoppedAnimation<Color>(AurixTokens.orange),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _StageChip(label: 'Образ', done: hasCover),
              _StageChip(label: 'Материал', done: hasMaterial),
              _StageChip(label: 'Запуск', done: hasLaunch),
            ],
          ),
          const SizedBox(height: 14),
          FilledButton(
            onPressed: onContinue,
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Продолжить'),
          ),
        ],
      ),
    );
  }
}

class _QuickActionsBlock extends StatelessWidget {
  const _QuickActionsBlock({
    required this.onCreateRelease,
    required this.onUploadTrack,
    required this.onGenerateCover,
    required this.onPromotion,
  });

  final VoidCallback onCreateRelease;
  final VoidCallback onUploadTrack;
  final VoidCallback onGenerateCover;
  final VoidCallback onPromotion;

  @override
  Widget build(BuildContext context) {
    final cards = [
      _ActionCardData(
        title: 'Создать релиз',
        subtitle: 'Новый релиз и базовые данные',
        icon: Icons.album_rounded,
        onTap: onCreateRelease,
      ),
      _ActionCardData(
        title: 'Загрузить трек',
        subtitle: 'Добавить материал в текущий релиз',
        icon: Icons.upload_file_rounded,
        onTap: onUploadTrack,
      ),
      _ActionCardData(
        title: 'Сгенерировать обложку',
        subtitle: 'Быстро получить вариант обложки',
        icon: Icons.auto_awesome_rounded,
        onTap: onGenerateCover,
      ),
      _ActionCardData(
        title: 'Запустить продвижение',
        subtitle: 'Перейти к промо и запуску',
        icon: Icons.rocket_launch_rounded,
        onTap: onPromotion,
      ),
    ];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Быстрые действия'),
          const SizedBox(height: 10),
          LayoutBuilder(
            builder: (context, c) {
              final isMobile = c.maxWidth < 760;
              final width = isMobile ? c.maxWidth : (c.maxWidth - 12) / 2;
              return Wrap(
                spacing: 12,
                runSpacing: 12,
                children: cards
                    .map((card) => SizedBox(width: width, child: _ActionCard(data: card)))
                    .toList(),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AnalyticsBlock extends StatelessWidget {
  const _AnalyticsBlock({required this.analytics, required this.onOpenAnalytics});

  final _AnalyticsViewModel analytics;
  final VoidCallback onOpenAnalytics;

  @override
  Widget build(BuildContext context) {
    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const _SectionTitle('Аналитика'),
              const Spacer(),
              TextButton(onPressed: onOpenAnalytics, child: const Text('Открыть')),
            ],
          ),
          const SizedBox(height: 8),
          if (!analytics.hasData)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AurixTokens.glass(0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AurixTokens.stroke(0.16)),
              ),
              child: const Text(
                'Данных по динамике пока нет. Загрузите отчёты, чтобы увидеть тренд.',
                style: TextStyle(
                  color: AurixTokens.textSecondary,
                  fontSize: 13,
                  height: 1.45,
                  fontWeight: FontWeight.w500,
                ),
              ),
            )
          else ...[
            SizedBox(
              height: 90,
              child: CustomPaint(
                painter: _MiniChartPainter(points: analytics.points),
                size: const Size(double.infinity, 90),
              ),
            ),
            const SizedBox(height: 10),
          ],
          Row(
            children: [
              Expanded(
                child: _MetricTile(
                  title: 'Прослушивания',
                  value: NumberFormat.compact(locale: 'ru').format(analytics.streams),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _MetricTile(
                  title: 'Сохранения',
                  value: analytics.savesText,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FinanceBlock extends StatelessWidget {
  const _FinanceBlock({required this.revenue, required this.onOpen});
  final double revenue;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final value = NumberFormat.compactCurrency(
      locale: 'ru',
      symbol: '₽',
      decimalDigits: 1,
    ).format(revenue);
    return _SectionCard(
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SectionTitle('Финансы'),
                const SizedBox(height: 6),
                const Text(
                  'Доход за месяц',
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w900,
                    fontSize: 28,
                    fontFeatures: AurixTokens.tabularFigures,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: onOpen,
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.orange,
              foregroundColor: Colors.black,
              textStyle: const TextStyle(fontWeight: FontWeight.w800),
            ),
            child: const Text('Перейти'),
          ),
        ],
      ),
    );
  }
}

class _ToolsBlock extends StatelessWidget {
  const _ToolsBlock({
    required this.onStudio,
    required this.onPromotion,
    required this.onTeam,
    required this.onLegal,
  });

  final VoidCallback onStudio;
  final VoidCallback onPromotion;
  final VoidCallback onTeam;
  final VoidCallback onLegal;

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final cards = [
      _ActionCardData(
        title: 'Студия',
        subtitle: 'AI-инструменты для релиза',
        icon: Icons.auto_awesome_rounded,
        onTap: onStudio,
      ),
      _ActionCardData(
        title: 'Продвижение',
        subtitle: 'Кампании и рекламные шаги',
        icon: Icons.rocket_launch_rounded,
        onTap: onPromotion,
      ),
      _ActionCardData(
        title: 'Команда',
        subtitle: 'Исполнители и продакшн-задачи',
        icon: Icons.groups_rounded,
        onTap: onTeam,
      ),
      _ActionCardData(
        title: 'Юридические документы',
        subtitle: 'Договоры и правовые шаблоны',
        icon: Icons.gavel_rounded,
        onTap: onLegal,
      ),
    ];

    return _SectionCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _SectionTitle('Инструменты'),
          const SizedBox(height: 10),
          if (isMobile)
            ...cards
                .map((c) => Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: _ActionCard(data: c, compact: true),
                    ))
          else
            Row(
              children: [
                Expanded(flex: 2, child: _ActionCard(data: cards[0])),
                const SizedBox(width: 10),
                Expanded(child: _ActionCard(data: cards[1], compact: true)),
                const SizedBox(width: 10),
                Expanded(child: _ActionCard(data: cards[2], compact: true)),
                const SizedBox(width: 10),
                Expanded(flex: 2, child: _ActionCard(data: cards[3])),
              ],
            ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);
  final String title;

  @override
  Widget build(BuildContext context) {
    return Text(
      title,
      style: const TextStyle(
        color: AurixTokens.text,
        fontSize: 17,
        fontWeight: FontWeight.w800,
        letterSpacing: 0.1,
      ),
    );
  }
}

class _ActionCardData {
  const _ActionCardData({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
}

class _ActionCard extends StatefulWidget {
  const _ActionCard({required this.data, this.compact = false});
  final _ActionCardData data;
  final bool compact;

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final h = widget.compact ? 106.0 : 126.0;
    final borderColor = _hovered ? AurixTokens.stroke(0.34) : AurixTokens.stroke(0.22);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        constraints: BoxConstraints(minHeight: h),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: AurixTokens.bg1.withValues(alpha: 0.94),
          border: Border.all(color: borderColor),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: _hovered ? 0.26 : 0.2),
              blurRadius: _hovered ? 18 : 10,
              spreadRadius: -10,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: AnimatedPadding(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: EdgeInsets.only(top: _hovered ? 0 : 2, bottom: _hovered ? 2 : 0),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.data.onTap,
              borderRadius: BorderRadius.circular(16),
              child: LayoutBuilder(
                builder: (context, c) {
                  final isNarrow = c.maxWidth < 190;
                  final isUltraNarrow = c.maxWidth < 120;
                  final hPad = isUltraNarrow ? 8.0 : 14.0;
                  final vPad = isUltraNarrow ? 10.0 : 12.0;
                  final iconSize = isUltraNarrow ? 28.0 : 34.0;
                  final iconInner = isUltraNarrow ? 15.0 : 18.0;
                  late final Widget content;
                  if (isUltraNarrow) {
                    content = Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: AurixTokens.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(widget.data.icon, size: iconInner, color: AurixTokens.orange),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          widget.data.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: AurixTokens.text,
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            height: 1.15,
                          ),
                        ),
                      ],
                    );
                  } else {
                    content = Row(
                      children: [
                        Container(
                          width: iconSize,
                          height: iconSize,
                          decoration: BoxDecoration(
                            color: AurixTokens.orange.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(widget.data.icon, size: iconInner, color: AurixTokens.orange),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                widget.data.title,
                                maxLines: isNarrow ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AurixTokens.text,
                                  fontSize: isNarrow ? 14.5 : 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.data.subtitle,
                                maxLines: isNarrow ? 2 : 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: AurixTokens.textSecondary.withValues(alpha: 0.95),
                                  fontSize: isNarrow ? 12 : 12.5,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (!isNarrow)
                          const Icon(Icons.chevron_right_rounded, color: AurixTokens.muted),
                      ],
                    );
                  }
                  return Padding(
                    padding: EdgeInsets.symmetric(horizontal: hPad, vertical: vPad),
                    child: content,
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 900;
    return PremiumHoverLift(
      enabled: desktop,
      child: PremiumSectionCard(
        padding: const EdgeInsets.all(18),
        child: child,
      ),
    );
  }
}

class _StageChip extends StatelessWidget {
  const _StageChip({required this.label, required this.done});
  final String label;
  final bool done;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
      decoration: BoxDecoration(
        color: done ? AurixTokens.orange.withValues(alpha: 0.12) : AurixTokens.glass(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: done ? AurixTokens.orange.withValues(alpha: 0.28) : AurixTokens.stroke(0.13),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            done ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
            size: 14,
            color: done ? AurixTokens.orange : AurixTokens.muted,
          ),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(
              color: done ? AurixTokens.text : AurixTokens.muted,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({required this.title, required this.value});
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    return PremiumMetricTile(
      label: title,
      value: value,
    );
  }
}

class _DashboardHeader extends StatelessWidget {
  const _DashboardHeader();

  @override
  Widget build(BuildContext context) {
    return const PremiumHeroBlock(
      title: 'Центр управления релизом',
      subtitle:
          'Ключевые действия, текущий фокус и прогресс кампании в одном месте. Чистый операционный обзор без визуального шума.',
      pills: [
        PremiumChip(label: 'Release OS', icon: Icons.album_rounded, selected: true),
        PremiumChip(label: 'Фокус недели', icon: Icons.track_changes_rounded),
        PremiumChip(label: 'Рост и аналитика', icon: Icons.insights_rounded),
      ],
      trailing: Icon(
        Icons.auto_graph_rounded,
        size: 28,
        color: AurixTokens.accentWarm,
      ),
    );
  }
}

class _HomeLoadingSkeleton extends StatelessWidget {
  const _HomeLoadingSkeleton();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: const [
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 18, width: 260),
              SizedBox(height: 8),
              PremiumSkeletonBox(height: 12, width: 340),
            ],
          ),
        ),
        SizedBox(height: 16),
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 22, width: 200),
              SizedBox(height: 12),
              PremiumSkeletonBox(height: 10),
              SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: PremiumSkeletonBox(height: 44)),
                  SizedBox(width: 10),
                  Expanded(child: PremiumSkeletonBox(height: 44)),
                ],
              ),
            ],
          ),
        ),
        SizedBox(height: 16),
        PremiumSectionCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              PremiumSkeletonBox(height: 16, width: 180),
              SizedBox(height: 12),
              PremiumSkeletonBox(height: 96),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniChartPainter extends CustomPainter {
  const _MiniChartPainter({required this.points});
  final List<double> points;

  @override
  void paint(Canvas canvas, Size size) {
    if (points.isEmpty || points.every((p) => p <= 0)) return;
    final max = points.reduce((a, b) => a > b ? a : b);
    if (max <= 0) return;

    final path = Path();
    final step = size.width / (points.length - 1);
    for (var i = 0; i < points.length; i++) {
      final x = i * step;
      final y = size.height - ((points[i] / max) * (size.height - 8)) - 4;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final glow = Paint()
      ..color = AurixTokens.orange.withValues(alpha: 0.2)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 7
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);
    final line = Paint()
      ..color = AurixTokens.orange
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(path, glow);
    canvas.drawPath(path, line);
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter oldDelegate) => oldDelegate.points != points;
}

class _CoverThumb extends StatelessWidget {
  const _CoverThumb({required this.url});
  final String? url;

  @override
  Widget build(BuildContext context) {
    if (url != null && url!.isNotEmpty) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          url!,
          width: 70,
          height: 70,
          fit: BoxFit.cover,
          errorBuilder: (_, __, ___) => _placeholder(),
        ),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return Container(
      width: 70,
      height: 70,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.14)),
        color: AurixTokens.bg2.withValues(alpha: 0.92),
      ),
      child: const Icon(Icons.music_note_rounded, color: AurixTokens.textSecondary),
    );
  }
}

class _AnalyticsViewModel {
  const _AnalyticsViewModel({
    required this.hasData,
    required this.streams,
    required this.savesText,
    required this.points,
  });

  const _AnalyticsViewModel.empty()
      : hasData = false,
        streams = 0,
        savesText = 'Нет данных',
        points = const [];

  final bool hasData;
  final int streams;
  final String savesText;
  final List<double> points;
}

class _Appear extends StatefulWidget {
  const _Appear({
    required this.child,
    required this.delayMs,
    required this.reduceMotion,
  });

  final Widget child;
  final int delayMs;
  final bool reduceMotion;

  @override
  State<_Appear> createState() => _AppearState();
}

class _AppearState extends State<_Appear> {
  bool _show = false;

  @override
  void initState() {
    super.initState();
    if (widget.reduceMotion) {
      _show = true;
    } else {
      Future.delayed(Duration(milliseconds: widget.delayMs), () {
        if (mounted) setState(() => _show = true);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.reduceMotion) return widget.child;
    return AnimatedOpacity(
      opacity: _show ? 1 : 0,
      duration: const Duration(milliseconds: 360),
      curve: Curves.easeOutCubic,
      child: AnimatedSlide(
        offset: _show ? Offset.zero : const Offset(0, 0.04),
        duration: const Duration(milliseconds: 360),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}

