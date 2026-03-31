import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_backdrop.dart';
import 'package:aurix_flutter/design/widgets/app_back_button.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/core/admin_config.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';
import 'package:aurix_flutter/ai/ai_assistant_overlay.dart';
import 'package:aurix_flutter/data/providers/billing_providers.dart';
import 'package:aurix_flutter/data/providers/notification_providers.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:intl/intl.dart';

/// Shell: sidebar (desktop) / Drawer (mobile) + topbar + content.
class AppShellScaffold extends ConsumerStatefulWidget {
  const AppShellScaffold({
    super.key,
    required this.child,
    required this.currentLocation,
  });

  final Widget child;
  final String currentLocation;

  @override
  ConsumerState<AppShellScaffold> createState() => _AppShellScaffoldState();
}

class _AppShellScaffoldState extends ConsumerState<AppShellScaffold> {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  String? _paywallShownForUser;
  bool _checkedIn = false;

  @override
  void initState() {
    super.initState();
    _dailyCheckin();
  }

  void _dailyCheckin() {
    if (_checkedIn) return;
    _checkedIn = true;
    // Fire-and-forget daily checkin for streak + XP
    ApiClient.post('/growth/checkin').ignore();
  }

  bool _isSubscriptionLockedSection(String location) {
    return location == '/ai' ||
        location == '/artist' ||
        location == '/promo' ||
        location == '/promo/video' ||
        location == '/team' ||
        location == '/production' ||
        location == '/dnk' ||
        location.startsWith('/dnk/tests');
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final hasActiveSubscription = ref.watch(hasActiveSubscriptionProvider);
    final profileAsync = ref.watch(currentProfileProvider);
    final profileLoaded = profileAsync.hasValue;
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = (isAdminAsync.valueOrNull ?? false) ||
        ref.watch(appStateProvider).isAdmin ||
        (user != null && user.email.isNotEmpty && adminEmails.contains(user.email.toLowerCase()));
    final canShowGlobalPaywall = user != null &&
        profileLoaded &&
        !isAdmin &&
        _isSubscriptionLockedSection(widget.currentLocation) &&
        widget.currentLocation != '/subscription' &&
        !widget.currentLocation.startsWith('/admin');

    if (canShowGlobalPaywall &&
        !hasActiveSubscription &&
        _paywallShownForUser != user.id) {
      _paywallShownForUser = user.id;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            backgroundColor: AurixTokens.bg1,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
              side: BorderSide(color: AurixTokens.stroke(0.2)),
            ),
            title: Text(
              '\u041f\u043e\u0434\u043f\u0438\u0441\u043a\u0430 \u0438\u0441\u0442\u0435\u043a\u043b\u0430',
              style: TextStyle(
                fontFamily: AurixTokens.fontHeading,
                color: AurixTokens.text,
                fontSize: 18,
              ),
            ),
            content: const Text(
              '\u0414\u043e\u0441\u0442\u0443\u043f \u043a \u0438\u043d\u0441\u0442\u0440\u0443\u043c\u0435\u043d\u0442\u0430\u043c \u0432\u0440\u0435\u043c\u0435\u043d\u043d\u043e \u0437\u0430\u043a\u0440\u044b\u0442. \u041f\u0440\u043e\u0434\u043b\u0438 \u0442\u0430\u0440\u0438\u0444, \u0447\u0442\u043e\u0431\u044b \u043f\u0440\u043e\u0434\u043e\u043b\u0436\u0438\u0442\u044c \u0440\u0430\u0431\u043e\u0442\u0443.',
              style: TextStyle(color: AurixTokens.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('\u041f\u043e\u0437\u0436\u0435'),
              ),
              FilledButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  if (mounted) context.go('/subscription');
                },
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.orange,
                  foregroundColor: Colors.black,
                ),
                child: const Text('\u041e\u0442\u043a\u0440\u044b\u0442\u044c \u0442\u0430\u0440\u0438\u0444\u044b'),
              ),
            ],
          ),
        );
      });
    }
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final hideTopBar =
        widget.currentLocation == '/releases/create' ||
        (widget.currentLocation.startsWith('/releases/') && widget.currentLocation != '/releases') ||
        widget.currentLocation.startsWith('/legal/') ||
        widget.currentLocation.startsWith('/index/artist/') ||
        widget.currentLocation.startsWith('/admin');

    return AurixBackdrop(
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: Colors.transparent,
        drawer: isDesktop ? null : Drawer(
          backgroundColor: AurixTokens.bg0,
          child: SafeArea(
            child: _NavDrawerContent(
              currentLocation: widget.currentLocation,
              isAdmin: isAdmin,
              onTap: (path) {
                Navigator.of(context).pop();
                context.go(path);
              },
            ),
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: [
              Row(
                children: [
                  if (isDesktop)
                    _Sidebar(
                      currentLocation: widget.currentLocation,
                      isAdmin: isAdmin,
                    ),
                  Expanded(
                    child: Column(
                      children: [
                        if (!hideTopBar)
                          _TopBar(
                            currentLocation: widget.currentLocation,
                            onMenuTap: isDesktop ? null : () => _scaffoldKey.currentState?.openDrawer(),
                          ),
                        Expanded(
                          child: widget.child,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              Positioned(
                right: 16,
                bottom: 16,
                width: isDesktop ? 420 : (MediaQuery.sizeOf(context).width * 0.9).clamp(280.0, 420.0),
                height: isDesktop ? 560 : 400,
                child: AiAssistantOverlay(
                  page: widget.currentLocation.startsWith('/releases/create') ? 'release_form' : 'cabinet',
                  onNavigate: (screen, [releaseId]) {
                    final path = _screenToPath(screen, releaseId);
                    if (context.mounted) context.go(path);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _screenToPath(AppScreen screen, [String? releaseId]) => switch (screen) {
      AppScreen.home => '/home',
      AppScreen.releases => '/releases',
      AppScreen.uploadRelease => '/releases/create',
      AppScreen.releaseDetails => '/releases/${releaseId ?? ''}',
      AppScreen.analytics => '/stats',
      AppScreen.promotion => '/promo',
      AppScreen.progress => '/progress',
      AppScreen.studioAi => '/ai',
      AppScreen.services => '/services',
      AppScreen.finances => '/finance',
      AppScreen.team => '/team',
      AppScreen.subscription => '/subscription',
      AppScreen.support => '/support',
      AppScreen.settings => '/settings',
      AppScreen.profile => '/profile',
      AppScreen.aurixIndex => '/index',
      AppScreen.admin => '/admin',
      AppScreen.legal => '/legal',
      AppScreen.aurixDnk => '/dnk',
    };

class _NavGroup {
  final String? titleKey;
  final List<_NavItem> items;
  _NavGroup({this.titleKey, required this.items});
}

List<_NavGroup> _appNavGroups(bool isAdmin) => [
  _NavGroup(titleKey: null, items: [
    _NavItem(path: '/home', icon: Icons.space_dashboard_rounded, labelKey: 'home'),
    _NavItem(path: '/ai', icon: Icons.auto_awesome, labelKey: 'studioAi'),
    _NavItem(path: '/artist', icon: Icons.person_pin_rounded, label: '\u0410\u0440\u0442\u0438\u0441\u0442'),
    _NavItem(path: '/promo', icon: Icons.campaign_rounded, labelKey: 'promo'),
    _NavItem(path: '/releases', icon: Icons.album_rounded, labelKey: 'releases'),
  ]),
  _NavGroup(titleKey: 'navGroupTools', items: [
    _NavItem(path: '/stats', icon: Icons.insights_rounded, labelKey: 'statistics'),
    _NavItem(path: '/index', icon: Icons.leaderboard_rounded, label: 'Aurix \u0420\u0435\u0439\u0442\u0438\u043d\u0433'),
    _NavItem(path: '/dnk', icon: Icons.fingerprint, label: 'Aurix DNK'),
    _NavItem(path: '/progress', icon: Icons.trending_up_rounded, labelKey: 'progress'),
    _NavItem(path: '/navigator', icon: Icons.explore_rounded, label: '\u041d\u0430\u0432\u0438\u0433\u0430\u0442\u043e\u0440'),
  ]),
  _NavGroup(titleKey: 'navGroupManagement', items: [
    _NavItem(path: '/finance', icon: Icons.account_balance_wallet_rounded, labelKey: 'finances'),
    _NavItem(path: '/subscription', icon: Icons.diamond_rounded, labelKey: 'subscription'),
    _NavItem(path: '/services', icon: Icons.build_circle_rounded, labelKey: 'services'),
    _NavItem(path: '/team', icon: Icons.groups_rounded, label: '\u041f\u0440\u043e\u0434\u0430\u043a\u0448\u043d'),
    if (isAdmin) _NavItem(path: '/admin', icon: Icons.admin_panel_settings_rounded, labelKey: 'admin'),
  ]),
  _NavGroup(titleKey: 'navGroupMore', items: [
    _NavItem(path: '/achievements', icon: Icons.emoji_events_rounded, label: '\u0414\u043e\u0441\u0442\u0438\u0436\u0435\u043d\u0438\u044f'),
    _NavItem(path: '/goals', icon: Icons.flag_rounded, label: '\u0426\u0435\u043b\u0438'),
    _NavItem(path: '/public-profile', icon: Icons.public_rounded, label: '\u041f\u0443\u0431\u043b\u0438\u0447\u043d\u044b\u0439 \u043f\u0440\u043e\u0444\u0438\u043b\u044c'),
    _NavItem(path: '/support', icon: Icons.support_agent_rounded, labelKey: 'support'),
    _NavItem(path: '/settings', icon: Icons.tune_rounded, labelKey: 'settings'),
    _NavItem(path: '/profile', icon: Icons.person_rounded, labelKey: 'profile'),
  ]),
];

class _NavDrawerContent extends StatelessWidget {
  final String currentLocation;
  final bool isAdmin;
  final void Function(String path) onTap;

  const _NavDrawerContent({required this.currentLocation, required this.isAdmin, required this.onTap});

  bool _selected(_NavItem i) =>
      currentLocation == i.path ||
      (currentLocation.startsWith('/production') && i.path == '/team') ||
      (currentLocation.startsWith('/releases/') && i.path == '/releases') ||
      (currentLocation.startsWith('/legal') && i.path == '/legal') ||
      (currentLocation.startsWith('/index') && i.path == '/index') ||
      (currentLocation.startsWith('/progress') && i.path == '/progress') ||
      (currentLocation.startsWith('/navigator') && i.path == '/navigator') ||
      (currentLocation.startsWith('/admin') && i.path == '/admin') ||
      (currentLocation == '/profile' && i.path == '/profile') ||
    (currentLocation == '/artist' && i.path == '/artist');

  @override
  Widget build(BuildContext context) {
    final groups = _appNavGroups(isAdmin);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              'AURIX',
              style: TextStyle(
                fontFamily: AurixTokens.fontDisplay,
                color: AurixTokens.orange,
                fontSize: 18,
                letterSpacing: 5,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 28),
          ...groups.expand((g) => [
            if (g.titleKey != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 16, bottom: 6),
                child: Text(
                  L10n.t(context, g.titleKey!).toUpperCase(),
                  style: TextStyle(
                    fontFamily: AurixTokens.fontBody,
                    color: AurixTokens.micro,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ),
            ],
            ...g.items.map((i) => _SidebarItem(
                icon: i.icon,
                label: i.label ?? L10n.t(context, i.labelKey!),
                selected: _selected(i),
                onTap: () => onTap(i.path),
              )),
          ]),
        ],
      ),
    );
  }
}

bool _isSelected(String currentLocation, _NavItem i) =>
    currentLocation == i.path ||
    (currentLocation.startsWith('/production') && i.path == '/team') ||
    (currentLocation.startsWith('/releases/') && i.path == '/releases') ||
    (currentLocation.startsWith('/legal') && i.path == '/legal') ||
    (currentLocation.startsWith('/index') && i.path == '/index') ||
    (currentLocation.startsWith('/progress') && i.path == '/progress') ||
    (currentLocation.startsWith('/navigator') && i.path == '/navigator') ||
    (currentLocation.startsWith('/admin') && i.path == '/admin') ||
    (currentLocation == '/profile' && i.path == '/profile') ||
    (currentLocation == '/artist' && i.path == '/artist');

class _Sidebar extends StatelessWidget {
  final String currentLocation;
  final bool isAdmin;

  const _Sidebar({required this.currentLocation, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final groups = _appNavGroups(isAdmin);
    return Container(
      width: 250,
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(
        color: AurixTokens.bg0.withValues(alpha: 0.92),
        border: Border(
          right: BorderSide(color: AurixTokens.stroke(0.14)),
        ),
      ),
      child: Column(
        children: [
          // Logo
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 22),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AurixTokens.accent,
                        AurixTokens.accentWarm,
                      ],
                    ),
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: AurixTokens.accent.withValues(alpha: 0.3),
                        blurRadius: 12,
                        spreadRadius: -4,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Text(
                      'A',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'AURIX',
                  style: TextStyle(
                    fontFamily: AurixTokens.fontDisplay,
                    color: AurixTokens.text,
                    fontSize: 15,
                    letterSpacing: 3,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          // Divider
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              height: 1,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.transparent,
                    AurixTokens.stroke(0.2),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          // Nav groups
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  ...groups.expand((g) => [
                    if (g.titleKey != null) ...[
                      Padding(
                        padding: const EdgeInsets.only(left: 14, top: 20, bottom: 6),
                        child: Text(
                          L10n.t(context, g.titleKey!).toUpperCase(),
                          style: TextStyle(
                            fontFamily: AurixTokens.fontBody,
                            color: AurixTokens.micro,
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                    ],
                    ...g.items.map((i) => _SidebarItem(
                          icon: i.icon,
                          label: i.label ?? L10n.t(context, i.labelKey!),
                          selected: _isSelected(currentLocation, i),
                          onTap: () => context.go(i.path),
                        )),
                  ]),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem {
  final String path;
  final IconData icon;
  final String? label;
  final String? labelKey;

  _NavItem({required this.path, required this.icon, this.label, this.labelKey});
}

class _SidebarItem extends StatefulWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _SidebarItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  State<_SidebarItem> createState() => _SidebarItemState();
}

class _SidebarItemState extends State<_SidebarItem> {
  bool _hover = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final isActive = widget.selected;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() {
          _hover = false;
          _pressed = false;
        }),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTapDown: (_) => setState(() => _pressed = true),
          onTapUp: (_) => setState(() => _pressed = false),
          onTapCancel: () => setState(() => _pressed = false),
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: AurixTokens.dFast,
            curve: AurixTokens.cEase,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: isActive
                  ? AurixTokens.accent.withValues(alpha: 0.1)
                  : (_hover ? AurixTokens.glass(0.04) : Colors.transparent),
              borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
              border: Border.all(
                color: isActive
                    ? AurixTokens.accent.withValues(alpha: 0.22)
                    : Colors.transparent,
                width: 1,
              ),
            ),
            child: Row(
              children: [
                // Active indicator dot
                AnimatedContainer(
                  duration: AurixTokens.dMedium,
                  curve: AurixTokens.cEase,
                  width: 3,
                  height: isActive ? 18 : 0,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: isActive ? AurixTokens.accent : Colors.transparent,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: isActive
                        ? [
                            BoxShadow(
                              color: AurixTokens.accent.withValues(alpha: 0.5),
                              blurRadius: 8,
                              spreadRadius: -2,
                            ),
                          ]
                        : null,
                  ),
                ),
                Icon(
                  widget.icon,
                  size: 19,
                  color: isActive ? AurixTokens.accent : (_hover ? AurixTokens.textSecondary : AurixTokens.muted),
                ),
                const SizedBox(width: 11),
                Expanded(
                  child: Text(
                    widget.label,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontBody,
                      color: isActive ? AurixTokens.text : (_hover ? AurixTokens.textSecondary : AurixTokens.muted),
                      fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                      fontSize: 13,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends ConsumerWidget {
  final String currentLocation;
  final VoidCallback? onMenuTap;

  const _TopBar({required this.currentLocation, this.onMenuTap});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final title = _titleFor(context, currentLocation);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;
    final padding = isDesktop ? 24.0 : kMobileHorizontalPadding;
    final showBack = currentLocation != '/home';

    return Container(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 12),
      decoration: BoxDecoration(
        color: AurixTokens.bg0.withValues(alpha: 0.7),
        border: Border(
          bottom: BorderSide(color: AurixTokens.stroke(0.1)),
        ),
      ),
      child: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Row(
            children: [
              if (showBack)
                AppBackButton(
                  tooltip: L10n.t(context, 'back'),
                  onPressed: () {
                    if (context.canPop()) {
                      context.pop();
                    } else {
                      context.go('/home');
                    }
                  },
                ),
              if (showBack) const SizedBox(width: 6),
              if (onMenuTap != null)
                IconButton(
                  icon: const Icon(Icons.menu_rounded, color: AurixTokens.text, size: 22),
                  onPressed: onMenuTap,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                ),
              if (onMenuTap != null) const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontFamily: AurixTokens.fontHeading,
                    color: AurixTokens.text,
                    fontWeight: FontWeight.w700,
                    fontSize: isDesktop ? 18 : 16,
                    letterSpacing: -0.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (isDesktop)
                SizedBox(
                  width: 220,
                  child: _SearchField(
                    onSelectRelease: (id) => context.go('/releases/$id'),
                  ),
                ),
              if (isDesktop) const SizedBox(width: 12),
              const _LocaleToggle(),
              const SizedBox(width: 8),
              const _NotificationBell(),
              const SizedBox(width: 8),
              const _CreditChip(),
              const SizedBox(width: 8),
              _ProfileAvatar(onTap: () => context.go('/profile')),
            ],
          ),
        ),
      ),
    );
  }

  static String _titleFor(BuildContext context, String loc) {
    if (loc == '/home') return L10n.t(context, 'home');
    if (loc == '/releases' || loc.startsWith('/releases/')) return L10n.t(context, 'releases');
    if (loc == '/upload' || loc == '/releases/create') return L10n.t(context, 'uploadRelease');
    if (loc == '/stats') return L10n.t(context, 'statistics');
    if (loc == '/promo/video') return '\u041f\u0440\u043e\u043c\u043e-\u0432\u0438\u0434\u0435\u043e';
    if (loc == '/promo') return L10n.t(context, 'promo');
    if (loc.startsWith('/index')) return 'Aurix \u0420\u0435\u0439\u0442\u0438\u043d\u0433';
    if (loc.startsWith('/dnk/artist')) return 'DNK \u0410\u0440\u0441\u0442\u0438\u0441\u0442\u0430';
    if (loc.startsWith('/dnk/tests') || loc == '/dnk') return 'Aurix DNK';
    if (loc.startsWith('/navigator')) return '\u041d\u0430\u0432\u0438\u0433\u0430\u0442\u043e\u0440 \u0430\u0440\u0442\u0438\u0441\u0442\u0430';
    if (loc == '/artist') return '\u0410\u0440\u0442\u0438\u0441\u0442';
    if (loc == '/ai') return L10n.t(context, 'studioAi');
    if (loc == '/finance') return L10n.t(context, 'finances');
    if (loc == '/team' || loc == '/production') return '\u041f\u0440\u043e\u0434\u0430\u043a\u0448\u043d';
    if (loc == '/subscription') return L10n.t(context, 'subscription');
    if (loc == '/services') return L10n.t(context, 'services');
    if (loc == '/support') return L10n.t(context, 'support');
    if (loc.startsWith('/legal')) return '\u042e\u0440\u0438\u0434\u0438\u0447\u0435\u0441\u043a\u0438\u0435 \u0434\u043e\u043a\u0443\u043c\u0435\u043d\u0442\u044b';
    if (loc == '/profile') return L10n.t(context, 'profile');
    if (loc == '/settings') return L10n.t(context, 'settings');
    if (loc.contains('/admin')) return L10n.t(context, 'admin');
    return L10n.t(context, 'home');
  }
}

class _ProfileAvatar extends StatefulWidget {
  const _ProfileAvatar({required this.onTap});
  final VoidCallback onTap;

  @override
  State<_ProfileAvatar> createState() => _ProfileAvatarState();
}

class _ProfileAvatarState extends State<_ProfileAvatar> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      cursor: SystemMouseCursors.click,
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: AurixTokens.dFast,
          width: 36,
          height: 36,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: _hovered
                ? AurixTokens.surface2
                : AurixTokens.surface1,
            border: Border.all(
              color: _hovered
                  ? AurixTokens.accent.withValues(alpha: 0.3)
                  : AurixTokens.stroke(0.2),
            ),
          ),
          child: const Icon(Icons.person_rounded, color: AurixTokens.muted, size: 18),
        ),
      ),
    );
  }
}

class _SearchField extends ConsumerStatefulWidget {
  final void Function(String releaseId) onSelectRelease;

  const _SearchField({required this.onSelectRelease});

  @override
  ConsumerState<_SearchField> createState() => _SearchFieldState();
}

class _SearchFieldState extends ConsumerState<_SearchField> {
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
    _debounce = Timer(const Duration(milliseconds: 300), () => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final query = _controller.text.trim().toLowerCase();
    final asyncReleases = ref.watch(releasesProvider);
    final releases = asyncReleases.valueOrNull ?? [];
    final matches = query.isEmpty
        ? <ReleaseModel>[]
        : releases
            .where((r) =>
                r.title.toLowerCase().contains(query) ||
                r.releaseType.toLowerCase().contains(query) ||
                (r.artist?.toLowerCase().contains(query) ?? false))
            .take(8)
            .toList();

    return Stack(
      clipBehavior: Clip.none,
      children: [
        TextField(
          controller: _controller,
          focusNode: _focusNode,
          onChanged: _onChanged,
          style: TextStyle(
            fontFamily: AurixTokens.fontBody,
            color: AurixTokens.text,
            fontSize: 13,
          ),
          decoration: InputDecoration(
            hintText: L10n.t(context, 'search'),
            hintStyle: TextStyle(
              fontFamily: AurixTokens.fontBody,
              color: AurixTokens.micro,
              fontSize: 13,
            ),
            filled: true,
            fillColor: AurixTokens.surface1.withValues(alpha: 0.6),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 17,
              color: AurixTokens.micro,
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
              borderSide: BorderSide(color: AurixTokens.stroke(0.16)),
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
              borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
              elevation: 8,
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(AurixTokens.radiusSm),
                  border: Border.all(color: AurixTokens.stroke(0.18)),
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: ListView(
                    shrinkWrap: true,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    children: [
                      if (matches.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(16),
                          child: Text(
                            '\u041d\u0438\u0447\u0435\u0433\u043e \u043d\u0435 \u043d\u0430\u0439\u0434\u0435\u043d\u043e',
                            style: TextStyle(
                              fontFamily: AurixTokens.fontBody,
                              color: AurixTokens.muted,
                              fontSize: 13,
                            ),
                          ),
                        )
                      else
                        ...matches.map((r) => ListTile(
                              dense: true,
                              title: Text(r.title, style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.text, fontSize: 13)),
                              subtitle: Text(r.releaseType, style: TextStyle(fontFamily: AurixTokens.fontBody, color: AurixTokens.micro, fontSize: 11)),
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
          ),
      ],
    );
  }
}

class _LocaleToggle extends ConsumerWidget {
  const _LocaleToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    return PremiumSegmentedControl<AppLocale>(
      options: const [
        (AppLocale.ru, 'RU'),
        (AppLocale.en, 'EN'),
      ],
      selected: appState.locale,
      onSelected: appState.setLocale,
    );
  }
}

/// Compact credit balance chip — tappable, navigates to /credits.
class _CreditChip extends ConsumerWidget {
  const _CreditChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final balanceAsync = ref.watch(creditBalanceProvider);

    return GestureDetector(
      onTap: () => context.push('/credits'),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
        decoration: BoxDecoration(
          color: AurixTokens.orange.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(AurixTokens.radiusXs),
          border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 13, color: AurixTokens.orange),
            const SizedBox(width: 3),
            balanceAsync.when(
              data: (b) => Text(
                b.toString(),
                style: TextStyle(
                  fontFamily: AurixTokens.fontMono,
                  color: AurixTokens.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              loading: () => const SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AurixTokens.orange),
              ),
              error: (_, __) => const Text('\u2014', style: TextStyle(color: AurixTokens.orange, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}

class _NotificationBell extends ConsumerStatefulWidget {
  const _NotificationBell();

  @override
  ConsumerState<_NotificationBell> createState() => _NotificationBellState();
}

class _NotificationBellState extends ConsumerState<_NotificationBell> {
  OverlayEntry? _overlay;

  void _toggle() {
    if (_overlay != null) {
      _overlay!.remove();
      _overlay = null;
      return;
    }
    final box = context.findRenderObject() as RenderBox;
    final offset = box.localToGlobal(Offset.zero);
    _overlay = OverlayEntry(
      builder: (_) => _NotificationPopup(
        top: offset.dy + box.size.height + 8,
        right: MediaQuery.sizeOf(context).width - offset.dx - box.size.width,
        onClose: () {
          _overlay?.remove();
          _overlay = null;
          ref.invalidate(unreadCountProvider);
          ref.invalidate(notificationsProvider);
        },
      ),
    );
    Overlay.of(context).insert(_overlay!);
  }

  @override
  void dispose() {
    _overlay?.remove();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final unread = ref.watch(unreadCountProvider).valueOrNull ?? 0;

    return GestureDetector(
      onTap: _toggle,
      child: SizedBox(
        width: 36,
        height: 36,
        child: Stack(
          children: [
            Center(
              child: Icon(
                Icons.notifications_none_rounded,
                color: unread > 0 ? AurixTokens.orange : AurixTokens.muted,
                size: 22,
              ),
            ),
            if (unread > 0)
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  width: 16,
                  height: 16,
                  decoration: BoxDecoration(
                    color: AurixTokens.orange,
                    shape: BoxShape.circle,
                    border: Border.all(color: AurixTokens.bg0, width: 1.5),
                  ),
                  child: Center(
                    child: Text(
                      unread > 9 ? '9+' : '$unread',
                      style: const TextStyle(color: Colors.white, fontSize: 8, fontWeight: FontWeight.w800),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _NotificationPopup extends ConsumerStatefulWidget {
  final double top;
  final double right;
  final VoidCallback onClose;

  const _NotificationPopup({required this.top, required this.right, required this.onClose});

  @override
  ConsumerState<_NotificationPopup> createState() => _NotificationPopupState();
}

class _NotificationPopupState extends ConsumerState<_NotificationPopup> {
  @override
  void initState() {
    super.initState();
    // Mark all as read when opened
    markNotificationsRead();
  }

  IconData _iconForType(String type) => switch (type) {
    'success' => Icons.check_circle_rounded,
    'warning' => Icons.warning_amber_rounded,
    'promo' => Icons.campaign_rounded,
    'ai' => Icons.auto_awesome,
    _ => Icons.notifications_rounded,
  };

  Color _colorForType(String type) => switch (type) {
    'success' => AurixTokens.positive,
    'warning' => AurixTokens.warning,
    'promo' => AurixTokens.orange,
    'ai' => const Color(0xFF8B5CF6),
    _ => AurixTokens.coolUndertone,
  };

  @override
  Widget build(BuildContext context) {
    final notifs = ref.watch(notificationsProvider).valueOrNull ?? [];

    return Stack(
      children: [
        // Backdrop
        Positioned.fill(
          child: GestureDetector(
            onTap: widget.onClose,
            child: const ColoredBox(color: Colors.transparent),
          ),
        ),
        // Popup
        Positioned(
          top: widget.top,
          right: widget.right,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 360,
              constraints: const BoxConstraints(maxHeight: 440),
              decoration: BoxDecoration(
                color: AurixTokens.bg1,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AurixTokens.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.3),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 8, 10),
                    child: Row(
                      children: [
                        const Icon(Icons.notifications_rounded, color: AurixTokens.orange, size: 18),
                        const SizedBox(width: 8),
                        const Expanded(
                          child: Text(
                            'Уведомления',
                            style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 14),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, color: AurixTokens.muted, size: 18),
                          onPressed: widget.onClose,
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: AurixTokens.border),
                  if (notifs.isEmpty)
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 40),
                      child: Column(
                        children: [
                          Icon(Icons.notifications_off_outlined, color: AurixTokens.muted, size: 32),
                          SizedBox(height: 8),
                          Text('Нет уведомлений', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                        ],
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: notifs.length,
                        separatorBuilder: (_, __) => Divider(height: 1, color: AurixTokens.stroke(0.06)),
                        itemBuilder: (context, i) {
                          final n = notifs[i];
                          final color = _colorForType(n.type);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 32,
                                  height: 32,
                                  decoration: BoxDecoration(
                                    color: color.withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Icon(_iconForType(n.type), color: color, size: 16),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              n.title,
                                              style: TextStyle(
                                                color: AurixTokens.text,
                                                fontWeight: n.isRead ? FontWeight.w500 : FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                            ),
                                          ),
                                          if (!n.isRead)
                                            Container(
                                              width: 7,
                                              height: 7,
                                              margin: const EdgeInsets.only(left: 6),
                                              decoration: const BoxDecoration(
                                                color: AurixTokens.orange,
                                                shape: BoxShape.circle,
                                              ),
                                            ),
                                        ],
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        n.message,
                                        style: const TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.3),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        _timeAgo(n.createdAt),
                                        style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 10),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _timeAgo(DateTime dt) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return 'только что';
    if (diff.inMinutes < 60) return '${diff.inMinutes} мин назад';
    if (diff.inHours < 24) return '${diff.inHours} ч назад';
    if (diff.inDays < 7) return '${diff.inDays} дн назад';
    return DateFormat('dd.MM.yy').format(dt);
  }
}
