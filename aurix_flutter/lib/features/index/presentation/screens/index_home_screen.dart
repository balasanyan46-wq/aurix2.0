import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/features/index/presentation/index_notifier.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_overview_tab.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_leaderboards_tab.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_achievements_tab.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_growth_history_tab.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_awards_tab.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_profile_tab.dart';

class IndexHomeScreen extends ConsumerStatefulWidget {
  const IndexHomeScreen({super.key, this.initialTab = 0});

  final int initialTab;

  @override
  ConsumerState<IndexHomeScreen> createState() => _IndexHomeScreenState();
}

class _IndexHomeScreenState extends ConsumerState<IndexHomeScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 6, vsync: this, initialIndex: widget.initialTab.clamp(0, 5));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final indexState = ref.watch(indexProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 28.0 : 20.0;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(padding, padding, padding, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                FadeInSlide(
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              AurixTokens.accent.withValues(alpha: 0.15),
                              AurixTokens.aiAccent.withValues(alpha: 0.1),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: AurixTokens.stroke(0.18)),
                        ),
                        child: const Icon(Icons.leaderboard_rounded, size: 22, color: AurixTokens.accent),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'AURIX РЕЙТИНГ',
                              style: TextStyle(
                                color: AurixTokens.text,
                                fontSize: isDesktop ? 26 : 22,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 0.5,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              isDesktop ? 'Рейтинг и карьера артистов' : 'Рейтинг артистов',
                              style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                FadeInSlide(
                  delayMs: 50,
                  child: Container(
                    decoration: BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: AurixTokens.stroke(0.1)),
                      ),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      labelColor: AurixTokens.accent,
                      unselectedLabelColor: AurixTokens.muted,
                      indicatorColor: AurixTokens.accent,
                      indicatorWeight: 2.5,
                      dividerColor: Colors.transparent,
                      isScrollable: true,
                      tabAlignment: TabAlignment.start,
                      labelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                      unselectedLabelStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                      tabs: const [
                        Tab(text: 'Обзор'),
                        Tab(text: 'Рейтинг'),
                        Tab(text: 'Достижения'),
                        Tab(text: 'История'),
                        Tab(text: 'Awards'),
                        Tab(text: 'Профиль'),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: indexState.state == IndexState.loading
                ? const PremiumLoadingState(message: 'Загрузка рейтинга…')
                : indexState.state == IndexState.error
                    ? PremiumErrorState(
                        title: 'Не удалось загрузить рейтинг',
                        message: indexState.error ?? 'Проверьте подключение и попробуйте снова.',
                        icon: Icons.leaderboard_rounded,
                        onRetry: () => ref.read(indexProvider.notifier).load(),
                      )
                    : TabBarView(
                        controller: _tabController,
                        children: const [
                          IndexOverviewTab(),
                          IndexLeaderboardsTab(),
                          IndexAchievementsTab(),
                          IndexGrowthHistoryTab(),
                          IndexAwardsTab(),
                          IndexProfileTab(),
                        ],
                      ),
          ),
        ],
      ),
    );
  }
}
