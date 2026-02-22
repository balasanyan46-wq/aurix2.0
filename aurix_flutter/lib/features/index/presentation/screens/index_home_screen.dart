import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
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
    final padding = isDesktop ? 24.0 : 16.0;

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
                Text(
                  'AURIX INDEX',
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Рейтинг и карьера артистов',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                ),
                const SizedBox(height: 24),
                TabBar(
                  controller: _tabController,
                  labelColor: AurixTokens.accent,
                  unselectedLabelColor: AurixTokens.muted,
                  indicatorColor: AurixTokens.accent,
                  tabs: const [
                    Tab(text: 'Обзор'),
                    Tab(text: 'Рейтинг'),
                    Tab(text: 'Достижения'),
                    Tab(text: 'История роста'),
                    Tab(text: 'Awards'),
                    Tab(text: 'Профиль'),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: indexState.state == IndexState.loading
                ? const Center(child: CircularProgressIndicator(color: AurixTokens.accent))
                : indexState.state == IndexState.error
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.error_outline, size: 48, color: AurixTokens.muted),
                            const SizedBox(height: 16),
                            Text(indexState.error ?? 'Ошибка', style: TextStyle(color: AurixTokens.muted)),
                            const SizedBox(height: 16),
                            TextButton(
                              onPressed: () => ref.read(indexProvider.notifier).load(),
                              child: const Text('Повторить'),
                            ),
                          ],
                        ),
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
