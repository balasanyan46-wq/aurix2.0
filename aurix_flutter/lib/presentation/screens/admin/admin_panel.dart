import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/crm_providers.dart';
import 'package:aurix_flutter/data/providers/promo_providers.dart';
import 'package:aurix_flutter/features/casting/data/casting_providers.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_dashboard_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_action_center_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_leads_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_conversion_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_revenue_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_users_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_releases_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_delete_requests_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_finance_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_analytics_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_content_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_production_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_crm_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_subscriptions_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_promo_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_logs_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_support_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_billing_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_system_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_services_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_errors_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_beats_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_ai_feedback_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_donations_tab.dart';
import 'package:aurix_flutter/presentation/screens/admin/tabs/admin_payments_tab.dart';
import 'package:aurix_flutter/features/casting/presentation/admin_casting_tab.dart';

const _kDesktopBreak = 800.0;

class _TabDef {
  final String key;
  final String label;
  final IconData icon;
  const _TabDef(this.key, this.label, this.icon);
}

const _tabs = [
  _TabDef('dashboard', 'Обзор', Icons.dashboard_rounded),
  // Action Center — "что сделать сегодня". Сразу после дашборда.
  _TabDef('action_center', 'Что делать', Icons.dashboard_customize_rounded),
  // Leads pipeline — sales-генерация выручки. Между Action Center и Users:
  // менеджер сначала смотрит общую очередь, потом свои leads, потом юзеров.
  _TabDef('leads', 'Leads', Icons.trending_up_rounded),
  // Conversion — funnel с деньгами. Менеджер должен видеть, где артисты
  // отваливаются и сколько денег теряется на каждом шаге.
  _TabDef('conversion', 'Воронка', Icons.show_chart_rounded),
  // Revenue — SaaS-метрики (MRR/ARR/ARPU/LTV/Churn/Conversion). Финансовый
  // язык бизнеса; менеджер/CEO видит здоровье продукта.
  _TabDef('revenue', 'Выручка', Icons.attach_money_rounded),
  _TabDef('users', 'Пользователи', Icons.people_rounded),
  _TabDef('releases', 'Релизы', Icons.album_rounded),
  _TabDef('delete_requests', 'Запросы на удаление', Icons.delete_sweep_rounded),
  _TabDef('finance', 'Финансы', Icons.monetization_on_rounded),
  _TabDef('analytics', 'Аналитика', Icons.bar_chart_rounded),
  _TabDef('content', 'Контент', Icons.article_rounded),
  _TabDef('production', 'Продакшн', Icons.engineering_rounded),
  _TabDef('crm', 'CRM', Icons.contact_mail_rounded),
  _TabDef('subscriptions', 'Подписки', Icons.card_membership_rounded),
  _TabDef('promo', 'Промо', Icons.campaign_rounded),
  _TabDef('logs', 'Логи', Icons.receipt_long_rounded),
  _TabDef('support', 'Поддержка', Icons.support_agent_rounded),
  _TabDef('billing', 'Биллинг', Icons.payments_rounded),
  _TabDef('payments', 'Платежи', Icons.receipt_rounded),
  _TabDef('donations', 'Донаты', Icons.favorite_rounded),
  _TabDef('services', 'Услуги', Icons.sell_rounded),
  _TabDef('errors', 'Ошибки', Icons.bug_report_rounded),
  _TabDef('system', 'Система', Icons.settings_rounded),
  _TabDef('beats', 'Биты', Icons.graphic_eq_rounded),
  _TabDef('casting', 'Код Артиста', Icons.mic_external_on_rounded),
  _TabDef('ai_feedback', 'AI Feedback', Icons.psychology_rounded),
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
    if (widget.initialTab != null &&
        widget.initialTab != oldWidget.initialTab) {
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
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }
        final isDesktop = MediaQuery.sizeOf(context).width >= _kDesktopBreak;
        return isDesktop ? _buildDesktop(context) : _buildMobile(context);
      },
      loading: () => const Scaffold(
        backgroundColor: Colors.transparent,
        body: Center(child: CircularProgressIndicator(color: AurixTokens.accent)),
      ),
      error: (_, __) => Scaffold(
        body: Center(
          child: Text('Ошибка загрузки',
              style: TextStyle(color: AurixTokens.muted)),
        ),
      ),
    );
  }

  void _refreshAll() {
    ref.invalidate(adminDashboardProvider);
    ref.invalidate(adminDauProvider);
    ref.invalidate(adminEventsBreakdownProvider);
    ref.invalidate(allReleasesAdminProvider);
    ref.invalidate(allReleaseDeleteRequestsProvider);
    ref.invalidate(allProfilesProvider);
    ref.invalidate(allReportRowsProvider);
    ref.invalidate(adminReportsProvider);
    ref.invalidate(adminLogsProvider);
    ref.invalidate(allTicketsProvider);
    ref.invalidate(adminBillingSubscriptionsProvider);
    ref.invalidate(adminPromoRequestsProvider);
    ref.invalidate(adminAiActionsProvider);
    ref.invalidate(adminBillingStatsProvider);
    ref.invalidate(adminBillingTransactionsProvider);
    ref.invalidate(adminSignalsProvider);
    ref.invalidate(adminCastingApplicationsProvider);
    ref.invalidate(adminCastingStatsProvider);
    ref.invalidate(adminCrmLeadsProvider);
    ref.invalidate(adminCrmDealsProvider);
    ref.invalidate(adminCrmInvoicesProvider);
    ref.invalidate(adminCrmTasksProvider);
    ref.invalidate(adminActionCenterProvider);
    ref.invalidate(adminConversionProvider);
    ref.invalidate(adminAiSalesSignalsProvider);
    ref.invalidate(adminMySalesDashboardProvider);
    ref.invalidate(adminStaffListProvider);
    ref.invalidate(adminRevenueProvider);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Данные обновлены'),
        backgroundColor: AurixTokens.bg2,
        duration: const Duration(seconds: 1),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  List<Widget> _buildTabWidgets() => [
        AdminDashboardTab(onGoToTab: goToTab),
        const AdminActionCenterTab(),
        const AdminLeadsTab(),
        const AdminConversionTab(),
        const AdminRevenueTab(),
        const AdminUsersTab(),
        const AdminReleasesTab(),
        const AdminDeleteRequestsTab(),
        const AdminFinanceTab(),
        const AdminAnalyticsTab(),
        const AdminContentTab(),
        const AdminProductionTab(),
        const AdminCrmTab(),
        const AdminSubscriptionsTab(),
        const AdminPromoTab(),
        const AdminLogsTab(),
        const AdminSupportTab(),
        const AdminBillingTab(),
        const AdminPaymentsTab(),
        const AdminDonationsTab(),
        const AdminServicesTab(),
        const AdminErrorsTab(),
        const AdminSystemTab(),
        const AdminBeatsTab(),
        const AdminCastingTab(),
        const AdminAiFeedbackTab(),
      ];

  Widget _buildDesktop(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () { if (context.canPop()) context.pop(); else context.go('/home'); },
        ),
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 28, height: 28,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: LinearGradient(colors: [AurixTokens.accent, AurixTokens.accent.withValues(alpha: 0.6)]),
              ),
              child: const Icon(Icons.admin_panel_settings_rounded, color: Colors.white, size: 15),
            ),
            const SizedBox(width: 10),
            const Text(
              'AURIX ADMIN',
              style: TextStyle(
                color: AurixTokens.text,
                fontWeight: FontWeight.w800,
                fontSize: 15,
                letterSpacing: 1.5,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text),
            tooltip: 'Обновить данные',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 8),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(46),
          child: Align(
            alignment: Alignment.centerLeft,
            child: TabBar(
              controller: _tc,
              isScrollable: true,
              indicatorSize: TabBarIndicatorSize.tab,
              indicator: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                gradient: LinearGradient(colors: [
                  AurixTokens.accent.withValues(alpha: 0.2),
                  AurixTokens.accent.withValues(alpha: 0.08),
                ]),
                border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.3)),
              ),
              labelColor: AurixTokens.text,
              unselectedLabelColor: AurixTokens.muted,
              dividerColor: Colors.transparent,
              indicatorPadding: const EdgeInsets.symmetric(vertical: 5, horizontal: 4),
              tabAlignment: TabAlignment.start,
              labelStyle: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.25,
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
        ),
      ),
      body: TabBarView(
        controller: _tc,
        children: _buildTabWidgets(),
      ),
    );
  }

  Widget _buildMobile(BuildContext context) {
    final scaffoldKey = GlobalKey<ScaffoldState>();
    return Scaffold(
      key: scaffoldKey,
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.74),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.menu_rounded, color: AurixTokens.text),
          onPressed: () => scaffoldKey.currentState?.openDrawer(),
        ),
        title: AnimatedBuilder(
          animation: _tc,
          builder: (context, _) => Text(
            _tabs[_tc.index].label.toUpperCase(),
            style: const TextStyle(
              color: AurixTokens.text,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 1.5,
            ),
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.close_rounded, color: AurixTokens.muted),
            tooltip: 'Закрыть',
            onPressed: () { if (context.canPop()) context.pop(); else context.go('/home'); },
          ),
          IconButton(
            icon: const Icon(Icons.refresh_rounded, color: AurixTokens.text),
            tooltip: 'Обновить данные',
            onPressed: _refreshAll,
          ),
          const SizedBox(width: 4),
        ],
      ),
      drawer: Drawer(
        backgroundColor: AurixTokens.bg0,
        child: SafeArea(
          child: ListView(
            padding: EdgeInsets.zero,
            children: [
              const SizedBox(height: 24),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Text(
                  'ПАНЕЛЬ УПРАВЛЕНИЯ',
                  style: TextStyle(
                    color: AurixTokens.accent,
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.5,
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Divider(color: AurixTokens.stroke(0.2), height: 1),
              const SizedBox(height: 8),
              ..._tabs.asMap().entries.map((e) {
                final idx = e.key;
                final tab = e.value;
                final selected = _tc.index == idx;
                return ListTile(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  tileColor: selected
                      ? AurixTokens.accent.withValues(alpha: 0.16)
                      : Colors.transparent,
                  leading: Icon(
                    tab.icon,
                    color: selected ? AurixTokens.accentWarm : AurixTokens.muted,
                    size: 20,
                  ),
                  title: Text(
                    tab.label,
                    style: TextStyle(
                      color: selected ? AurixTokens.text : AurixTokens.textSecondary,
                      fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
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
            children: _buildTabWidgets(),
          );
        },
      ),
    );
  }
}
