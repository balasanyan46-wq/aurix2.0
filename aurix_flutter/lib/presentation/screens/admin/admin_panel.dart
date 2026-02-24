import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_dashboard_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_users_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_releases_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_finance_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_content_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_analytics_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_logs_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_support_tab.dart';

const _kDesktopBreak = 800.0;

class _TabDef {
  final String key;
  final String label;
  final IconData icon;
  const _TabDef(this.key, this.label, this.icon);
}

const _tabs = [
  _TabDef('dashboard', 'Обзор', Icons.dashboard_rounded),
  _TabDef('users', 'Пользователи', Icons.people_rounded),
  _TabDef('releases', 'Релизы', Icons.album_rounded),
  _TabDef('finance', 'Финансы', Icons.payments_rounded),
  _TabDef('analytics', 'Аналитика', Icons.bar_chart_rounded),
  _TabDef('content', 'Контент', Icons.description_rounded),
  _TabDef('logs', 'Логи', Icons.history_rounded),
  _TabDef('support', 'Поддержка', Icons.support_agent_rounded),
];

class AdminPanel extends ConsumerStatefulWidget {
  const AdminPanel({super.key, this.initialTab});
  final String? initialTab;

  @override
  ConsumerState<AdminPanel> createState() => _AdminPanelState();
}

class _AdminPanelState extends ConsumerState<AdminPanel>
    with SingleTickerProviderStateMixin {
  late TabController _tc;

  @override
  void initState() {
    super.initState();
    final idx = _tabs.indexWhere((t) => t.key == widget.initialTab);
    _tc = TabController(
      length: _tabs.length,
      vsync: this,
      initialIndex: idx >= 0 ? idx : 0,
    );
  }

  @override
  void didUpdateWidget(covariant AdminPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.initialTab != null && widget.initialTab != oldWidget.initialTab) {
      final idx = _tabs.indexWhere((t) => t.key == widget.initialTab);
      if (idx >= 0 && idx != _tc.index) {
        _tc.animateTo(idx);
      }
    }
  }

  void goToTab(String key) {
    final idx = _tabs.indexWhere((t) => t.key == key);
    if (idx >= 0) _tc.animateTo(idx);
  }

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isAdminAsync = ref.watch(isAdminProvider);

    return isAdminAsync.when(
      data: (isAdmin) {
        if (!isAdmin) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (context.mounted) context.go('/home');
          });
          return const Scaffold(body: Center(child: Text('Доступ запрещён')));
        }
        final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreak;
        return isDesktop ? _buildDesktop(context) : _buildMobile(context);
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
      ),
      error: (_, __) => Scaffold(
        body: Center(
          child: Text('Ошибка загрузки', style: TextStyle(color: AurixTokens.muted)),
        ),
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(allReleasesAdminProvider);
    ref.invalidate(allProfilesProvider);
    ref.invalidate(allReportRowsProvider);
    ref.invalidate(adminLogsProvider);
    ref.invalidate(allTicketsProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Данные обновлены'),
        duration: Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'ПАНЕЛЬ УПРАВЛЕНИЯ',
          style: TextStyle(
            color: AurixTokens.text,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text),
            tooltip: 'Обновить данные',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
        bottom: TabBar(
          controller: _tc,
          isScrollable: true,
          indicatorColor: AurixTokens.orange,
          labelColor: AurixTokens.orange,
          unselectedLabelColor: AurixTokens.muted,
          indicatorWeight: 2,
          tabAlignment: TabAlignment.start,
          labelStyle: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.3,
          ),
          tabs: _tabs
              .map((t) => Tab(
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(t.icon, size: 16),
                        const SizedBox(width: 6),
                        Text(t.label),
                      ],
                    ),
                  ))
              .toList(),
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: [
          AdminDashboardTab(onGoToTab: goToTab),
          const AdminUsersTab(),
          const AdminReleasesTab(),
          const AdminFinanceTab(),
          const AdminAnalyticsTab(),
          const AdminContentTab(),
          const AdminLogsTab(),
          const AdminSupportTab(),
        ],
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () => context.go('/home'),
        ),
        title: const Text(
          'ПАНЕЛЬ УПРАВЛЕНИЯ',
          style: TextStyle(
            color: AurixTokens.text,
            fontWeight: FontWeight.w800,
            fontSize: 16,
            letterSpacing: 1.5,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text),
            tooltip: 'Обновить данные',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AurixTokens.bg1,
        child: SafeArea(
          child: Column(
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'ПАНЕЛЬ УПРАВЛЕНИЯ',
                  style: TextStyle(
                    color: AurixTokens.orange,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: AurixTokens.border, height: 1),
              const SizedBox(height: 8),
              ..._tabs.asMap().entries.map((e) {
                final idx = e.key;
                final tab = e.value;
                final selected = _tc.index == idx;
                return ListTile(
                  leading: Icon(
                    tab.icon,
                    color: selected ? AurixTokens.orange : AurixTokens.muted,
                    size: 20,
                  ),
                  title: Text(
                    tab.label,
                    style: TextStyle(
                      color: selected ? AurixTokens.text : AurixTokens.muted,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                      fontSize: 14,
                    ),
                  ),
                  onTap: () {
                    setState(() => _tc.index = idx);
                    Navigator.of(context).pop();
                  },
                );
              }),
            ],
          ),
        ),
      ),
      body: AnimatedBuilder(
        animation: _tc,
        builder: (context, _) {
          return IndexedStack(
            index: _tc.index,
            children: [
              AdminDashboardTab(onGoToTab: goToTab),
              const AdminUsersTab(),
              const AdminReleasesTab(),
              const AdminFinanceTab(),
              const AdminAnalyticsTab(),
              const AdminContentTab(),
              const AdminLogsTab(),
              const AdminSupportTab(),
            ],
          );
        },
      ),
    );
  }
}
