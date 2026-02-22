import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_backdrop.dart';
import 'package:aurix_flutter/screens/home/home_screen.dart';
import 'package:aurix_flutter/screens/releases/releases_list_screen.dart';
import 'package:aurix_flutter/screens/releases/release_detail_screen.dart';
import 'package:aurix_flutter/screens/analytics/analytics_screen.dart';
import 'package:aurix_flutter/screens/promotion/promotion_screen.dart';
import 'package:aurix_flutter/screens/subscription/subscription_screen.dart';
import 'package:aurix_flutter/screens/services/services_screen.dart';
import 'package:aurix_flutter/screens/finances/finances_screen.dart';
import 'package:aurix_flutter/screens/team/team_screen.dart';
import 'package:aurix_flutter/screens/admin/admin_screen.dart';
import 'package:aurix_flutter/screens/settings/settings_screen.dart';
import 'package:aurix_flutter/features/profile/presentation/profile_page.dart';
import 'package:aurix_flutter/features/index/presentation/screens/index_home_screen.dart';
import 'package:aurix_flutter/screens/support/support_screen.dart';
import 'package:aurix_flutter/features/legal/legal_screen.dart';
import 'package:aurix_flutter/screens/releases/release_create_flow_screen.dart';
import 'package:aurix_flutter/screens/studio_ai/studio_ai_screen.dart';
import 'package:aurix_flutter/ai/ai_assistant_overlay.dart';
import 'package:aurix_flutter/core/admin_config.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Shell: sidebar (desktop) / Drawer (mobile) + content. Uses AppState.currentScreen.
class DesignShell extends ConsumerStatefulWidget {
  const DesignShell({super.key});

  @override
  ConsumerState<DesignShell> createState() => _DesignShellState();
}

class _DesignShellState extends ConsumerState<DesignShell> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  @override
  Widget build(BuildContext context) {
    final screen = ref.watch(appStateProvider).currentScreen;
    final selectedReleaseId = ref.watch(appStateProvider).selectedReleaseId;
    final user = ref.watch(currentUserProvider);
    final isAdmin = ref.watch(appStateProvider).isAdmin ||
        (user?.email != null && adminEmails.contains(user!.email!.toLowerCase()));
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    return AurixBackdrop(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: isDesktop ? null : Drawer(
          backgroundColor: AurixTokens.bg1,
          child: SafeArea(
            child: _NavDrawerContent(
              screen: screen,
              isAdmin: isAdmin,
              onTap: (s, [rid]) {
                Navigator.of(context).pop();
                ref.read(appStateProvider).navigateTo(s, releaseId: rid);
              },
            ),
          ),
        ),
        body: SafeArea(
          child: Row(
            children: [
              if (isDesktop)
                _Sidebar(
                  screen: screen,
                  isAdmin: isAdmin,
                  onTap: (s, [rid]) => ref.read(appStateProvider).navigateTo(s, releaseId: rid),
                ),
              Expanded(
                child: Stack(
                  children: [
                    Column(
                      children: [
                        _TopBar(
                          title: _screenTitle(context, screen),
                          onMenuTap: isDesktop ? null : () => _scaffoldKey.currentState?.openDrawer(),
                        ),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 280),
                            transitionBuilder: (child, animation) => FadeTransition(
                              opacity: animation,
                              child: SlideTransition(
                                position: Tween<Offset>(begin: const Offset(0.02, 0), end: Offset.zero)
                                    .animate(CurvedAnimation(parent: animation, curve: Curves.easeOutCubic)),
                                child: child,
                              ),
                            ),
                            child: KeyedSubtree(
                              key: ValueKey('$screen-$selectedReleaseId'),
                              child: _buildContent(context, ref, screen, selectedReleaseId),
                            ),
                          ),
                        ),
                      ],
                    ),
                    if (screen != AppScreen.studioAi)
                      Positioned(
                        right: 0,
                        bottom: 0,
                        width: isDesktop ? 420 : (MediaQuery.sizeOf(context).width * 0.9).clamp(280.0, 420.0),
                        height: isDesktop ? 560 : 400,
                        child: AiAssistantOverlay(
                          page: screen == AppScreen.uploadRelease ? 'release_form' : 'cabinet',
                          context: screen == AppScreen.uploadRelease ? {} : null,
                          onNavigate: (s, [rid]) => ref.read(appStateProvider).navigateTo(s, releaseId: rid),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _screenTitle(BuildContext context, AppScreen screen) {
    final k = switch (screen) {
      AppScreen.home => 'home',
      AppScreen.releases => 'releases',
      AppScreen.uploadRelease => 'uploadRelease',
      AppScreen.releaseDetails => 'releases',
      AppScreen.analytics => 'statistics',
      AppScreen.promotion => 'promo',
      AppScreen.studioAi => 'studioAi',
      AppScreen.services => 'services',
      AppScreen.finances => 'finances',
      AppScreen.team => 'team',
      AppScreen.subscription => 'subscription',
      AppScreen.support => 'support',
      AppScreen.legal => 'legal',
      AppScreen.settings => 'settings',
      AppScreen.profile => 'profile',
      AppScreen.aurixIndex => 'index',
      AppScreen.admin => 'management',
    };
    return L10n.t(context, k);
  }

  Widget _buildContent(BuildContext context, WidgetRef ref, AppScreen screen, String? releaseId) {
    switch (screen) {
      case AppScreen.home:
        return HomeScreen(
          onViewIndex: () => ref.read(appStateProvider).navigateTo(AppScreen.aurixIndex),
        );
      case AppScreen.releases:
        return const ReleasesListScreen();
      case AppScreen.uploadRelease:
        return _UploadReleaseWrapper(
          onBack: () => ref.read(appStateProvider).navigateTo(AppScreen.releases),
        );
      case AppScreen.releaseDetails:
        if (releaseId == null) return const ReleasesListScreen();
        return _ReleaseDetailById(releaseId: releaseId, onNotFound: () => ref.read(appStateProvider).navigateTo(AppScreen.releases));
      case AppScreen.analytics:
        return const AnalyticsScreen();
      case AppScreen.promotion:
        return const PromotionScreen();
      case AppScreen.studioAi:
        return const StudioAiScreen();
      case AppScreen.services:
        return const ServicesScreen();
      case AppScreen.finances:
        return const FinancesScreen();
      case AppScreen.team:
        return const TeamScreen();
      case AppScreen.subscription:
        return const SubscriptionScreen();
      case AppScreen.support:
        return const SupportScreen();
      case AppScreen.legal:
        return const LegalScreen();
      case AppScreen.settings:
        return const SettingsScreen();
      case AppScreen.aurixIndex:
        return const IndexHomeScreen();
      case AppScreen.profile:
        return ProfilePage(
          onBack: () => ref.read(appStateProvider).navigateTo(AppScreen.settings),
          onViewIndex: () => ref.read(appStateProvider).navigateTo(AppScreen.aurixIndex),
        );
      case AppScreen.admin:
        return const AdminScreen();
    }
  }
}

List<_NavItem> _navItems(BuildContext context, bool isAdmin) => [
      _NavItem(screen: AppScreen.home, icon: Icons.home_rounded, label: L10n.t(context, 'home')),
      _NavItem(screen: AppScreen.releases, icon: Icons.album_rounded, label: L10n.t(context, 'releases')),
      _NavItem(screen: AppScreen.uploadRelease, icon: Icons.upload_rounded, label: L10n.t(context, 'uploadRelease')),
      _NavItem(screen: AppScreen.analytics, icon: Icons.analytics_rounded, label: L10n.t(context, 'statistics')),
      _NavItem(screen: AppScreen.promotion, icon: Icons.rocket_launch_rounded, label: L10n.t(context, 'promo')),
      _NavItem(screen: AppScreen.studioAi, icon: Icons.auto_awesome, label: L10n.t(context, 'studioAi')),
      _NavItem(screen: AppScreen.finances, icon: Icons.account_balance_wallet_rounded, label: L10n.t(context, 'finances')),
      _NavItem(screen: AppScreen.team, icon: Icons.groups_rounded, label: L10n.t(context, 'team')),
      _NavItem(screen: AppScreen.subscription, icon: Icons.card_membership_rounded, label: L10n.t(context, 'subscription')),
      _NavItem(screen: AppScreen.services, icon: Icons.build_rounded, label: L10n.t(context, 'services')),
      _NavItem(screen: AppScreen.support, icon: Icons.support_agent_rounded, label: L10n.t(context, 'support')),
      _NavItem(screen: AppScreen.legal, icon: Icons.gavel_rounded, label: L10n.t(context, 'legal')),
      if (isAdmin) _NavItem(screen: AppScreen.admin, icon: Icons.admin_panel_settings_rounded, label: L10n.t(context, 'management')),
      _NavItem(screen: AppScreen.profile, icon: Icons.person_rounded, label: L10n.t(context, 'profile')),
      _NavItem(screen: AppScreen.aurixIndex, icon: Icons.leaderboard_rounded, label: 'Aurix Index'),
      _NavItem(screen: AppScreen.settings, icon: Icons.settings_rounded, label: L10n.t(context, 'settings')),
    ];

class _NavDrawerContent extends StatelessWidget {
  final AppScreen screen;
  final bool isAdmin;
  final void Function(AppScreen screen, [String? releaseId]) onTap;

  const _NavDrawerContent({required this.screen, required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = _navItems(context, isAdmin);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'AURIX',
              style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AurixTokens.orange,
                    letterSpacing: 4,
                    fontWeight: FontWeight.w800,
                  ),
            ),
          ),
          const SizedBox(height: 24),
          ...items.map((i) => _SidebarItem(
                icon: i.icon,
                label: i.label,
                selected: screen == i.screen ||
                    (screen == AppScreen.releaseDetails && i.screen == AppScreen.releases) ||
                    (screen == AppScreen.uploadRelease && i.screen == AppScreen.releases),
                onTap: () => onTap(i.screen),
              )),
        ],
      ),
    );
  }
}

class _Sidebar extends StatelessWidget {
  final AppScreen screen;
  final bool isAdmin;
  final void Function(AppScreen screen, [String? releaseId]) onTap;

  const _Sidebar({required this.screen, required this.isAdmin, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final items = _navItems(context, isAdmin);
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Text(
                'AURIX',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: AurixTokens.orange,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 32),
            ...items.map((i) => _SidebarItem(
                icon: i.icon,
                label: i.label,
                selected: screen == i.screen ||
                    (screen == AppScreen.releaseDetails && i.screen == AppScreen.releases) ||
                    (screen == AppScreen.uploadRelease && i.screen == AppScreen.releases),
                onTap: () => onTap(i.screen),
              )),
          ],
        ),
      ),
    );
  }
}

/// Wrapper that loads release by id from Supabase and shows ReleaseDetailScreen.
class _ReleaseDetailById extends ConsumerWidget {
  final String releaseId;
  final VoidCallback onNotFound;

  const _ReleaseDetailById({required this.releaseId, required this.onNotFound});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(releasesProvider);
    return async.when(
      data: (releases) {
        final release = releases.where((r) => r.id == releaseId).firstOrNull;
        if (release == null) {
          WidgetsBinding.instance.addPostFrameCallback((_) => onNotFound());
          return const ReleasesListScreen();
        }
        return ReleaseDetailScreen(release: release);
      },
      loading: () => Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
      error: (_, __) => const ReleasesListScreen(),
    );
  }
}

class _NavItem {
  final AppScreen screen;
  final IconData icon;
  final String label;

  _NavItem({required this.screen, required this.icon, required this.label});
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({required this.icon, required this.label, required this.selected, required this.onTap});

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: Listener(
        behavior: HitTestBehavior.opaque,
        child: MouseRegion(
          onEnter: (_) => setState(() => _hover = true),
          onExit: (_) => setState(() => _hover = false),
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: (widget.selected || _hover) ? AurixTokens.glass(0.1) : null,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: widget.selected ? AurixTokens.orange.withValues(alpha: 0.5) : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  widget.icon,
                  size: 22,
                  color: widget.selected ? AurixTokens.orange : AurixTokens.muted,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      color: widget.selected ? AurixTokens.text : AurixTokens.muted,
                      fontWeight: widget.selected ? FontWeight.w600 : FontWeight.w500,
                      fontSize: 14,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

class _SearchWithDropdown extends ConsumerStatefulWidget {
  final void Function(String) onChanged;
  final void Function(String releaseId) onSelectRelease;

  const _SearchWithDropdown({required this.onChanged, required this.onSelectRelease});

  @override
  ConsumerState<_SearchWithDropdown> createState() => _SearchWithDropdownState();
}

class _SearchWithDropdownState extends ConsumerState<_SearchWithDropdown> {
  final _controller = TextEditingController();
  final _focusNode = FocusNode();
  Timer? _debounce;
  bool _showDropdown = false;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(() => setState(() => _showDropdown = _focusNode.hasFocus));
  }

  @override
  void dispose() {
    _controller.dispose();
    _focusNode.dispose();
    _debounce?.cancel();
    super.dispose();
  }

  void _onChanged(String value) {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 300), () => widget.onChanged(value.trim()));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final asyncReleases = ref.watch(releasesProvider);
    final releases = asyncReleases.valueOrNull ?? [];
    final matches = query.isEmpty
        ? <ReleaseModel>[]
        : releases
            .where((r) {
              final q = query.toLowerCase();
              return r.title.toLowerCase().contains(q) ||
                  r.releaseType.toLowerCase().contains(q) ||
                  (r.artist?.toLowerCase().contains(q) ?? false);
            })
            .take(8)
            .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: L10n.t(context, 'search'),
            hintStyle: TextStyle(color: AurixTokens.muted, fontSize: 14),
            filled: true,
            fillColor: AurixTokens.glass(0.06),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AurixTokens.stroke()),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            isDense: true,
          ),
        ),
        if (_showDropdown && query.isNotEmpty)
          Positioned(
            top: 44,
            left: 0,
            right: 0,
            child: Material(
              color: AurixTokens.bg1,
              borderRadius: BorderRadius.circular(12),
              elevation: 8,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 240),
                child: ListView(
                  shrinkWrap: true,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  children: [
                    if (matches.isEmpty)
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Text('Ничего не найдено', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                      )
                    else
                      ...matches.map((r) => ListTile(
                        dense: true,
                        title: Text(r.title, style: const TextStyle(color: AurixTokens.text, fontSize: 14)),
                        subtitle: Text(r.releaseType, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                        onTap: () {
                          _focusNode.unfocus();
                          _controller.clear();
                          widget.onSelectRelease(r.id);
                        },
                      )),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _TopBar extends ConsumerWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const _TopBar({required this.title, this.onMenuTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.read(appStateProvider);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 24.0 : kMobileHorizontalPadding;

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 16),
      child: Row(
        children: [
          if (onMenuTap != null)
            IconButton(
              icon: const Icon(Icons.menu, color: AurixTokens.text),
              onPressed: onMenuTap,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
            ),
          if (onMenuTap != null) const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    fontSize: isDesktop ? null : 20,
                  ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          if (isDesktop)
            SizedBox(
              width: 220,
              child: _SearchWithDropdown(
                onChanged: (q) => appState.setSearchQuery(q),
                onSelectRelease: (id) => appState.navigateTo(AppScreen.releaseDetails, releaseId: id),
              ),
            ),
          if (isDesktop) const SizedBox(width: 12),
          const _LocaleToggle(),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => appState.navigateTo(AppScreen.settings),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.orange.withValues(alpha: 0.3),
                border: Border.all(color: AurixTokens.stroke(0.2)),
              ),
              child: const Icon(Icons.person, color: AurixTokens.text, size: 22),
            ),
          ),
        ],
      ),
    );
  }
}

class _LocaleToggle extends ConsumerWidget {
  const _LocaleToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.08),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.15), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _LocalePill(label: 'RU', active: appState.locale == AppLocale.ru, onTap: () => appState.setLocale(AppLocale.ru)),
          _LocalePill(label: 'EN', active: appState.locale == AppLocale.en, onTap: () => appState.setLocale(AppLocale.en)),
        ],
      ),
    );
  }
}

class _LocalePill extends StatefulWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _LocalePill({required this.label, required this.active, required this.onTap});

  @override
  State<_LocalePill> createState() => _LocalePillState();
}

class _UploadReleaseWrapper extends StatelessWidget {
  final VoidCallback onBack;

  const _UploadReleaseWrapper({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return ReleaseCreateFlowScreen(embedded: true, onBack: onBack);
  }
}

class _LocalePillState extends State<_LocalePill> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final highlighted = widget.active || _hover;
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOutCubic,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: highlighted ? AurixTokens.orange.withValues(alpha: 0.25) : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: highlighted ? AurixTokens.text : AurixTokens.muted,
              fontSize: 12,
              fontWeight: widget.active ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
