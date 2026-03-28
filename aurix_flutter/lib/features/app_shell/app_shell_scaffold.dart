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
import 'package:aurix_flutter/core/api/api_client.dart';

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
            title: const Text(
              'Подписка истекла',
              style: TextStyle(color: AurixTokens.text),
            ),
            content: const Text(
              'Доступ к инструментам временно закрыт. Продли тариф, чтобы продолжить работу.',
              style: TextStyle(color: AurixTokens.muted),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Позже'),
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
                child: const Text('Открыть тарифы'),
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
    _NavItem(path: '/home', icon: Icons.home_rounded, labelKey: 'home'),
    _NavItem(path: '/ai', icon: Icons.auto_awesome, labelKey: 'studioAi'),
    _NavItem(path: '/artist', icon: Icons.person_pin_rounded, label: 'Артист'),
    _NavItem(path: '/promo', icon: Icons.rocket_launch_rounded, labelKey: 'promo'),
    _NavItem(path: '/releases', icon: Icons.album_rounded, labelKey: 'releases'),
  ]),
  _NavGroup(titleKey: 'navGroupTools', items: [
    _NavItem(path: '/stats', icon: Icons.analytics_rounded, labelKey: 'statistics'),
    _NavItem(path: '/index', icon: Icons.leaderboard_rounded, label: 'Aurix Рейтинг'),
    _NavItem(path: '/dnk', icon: Icons.fingerprint, label: 'Aurix DNK'),
    _NavItem(path: '/progress', icon: Icons.calendar_month_rounded, labelKey: 'progress'),
    _NavItem(path: '/navigator', icon: Icons.explore_rounded, label: 'Навигатор'),
  ]),
  _NavGroup(titleKey: 'navGroupManagement', items: [
    _NavItem(path: '/finance', icon: Icons.account_balance_wallet_rounded, labelKey: 'finances'),
    _NavItem(path: '/subscription', icon: Icons.card_membership_rounded, labelKey: 'subscription'),
    _NavItem(path: '/team', icon: Icons.groups_rounded, label: 'Продакшн'),
    if (isAdmin) _NavItem(path: '/admin', icon: Icons.admin_panel_settings_rounded, labelKey: 'admin'),
  ]),
  _NavGroup(titleKey: 'navGroupMore', items: [
    _NavItem(path: '/achievements', icon: Icons.emoji_events_rounded, label: 'Достижения'),
    _NavItem(path: '/goals', icon: Icons.flag_rounded, label: 'Цели'),
    _NavItem(path: '/public-profile', icon: Icons.public_rounded, label: 'Публичный профиль'),
    _NavItem(path: '/support', icon: Icons.support_agent_rounded, labelKey: 'support'),
    _NavItem(path: '/settings', icon: Icons.settings_rounded, labelKey: 'settings'),
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
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: ListView(
        shrinkWrap: true,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
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
          ...groups.expand((g) => [
            if (g.titleKey != null) ...[
              Padding(
                padding: const EdgeInsets.only(left: 16, top: 12, bottom: 6),
                child: Text(
                  L10n.t(context, g.titleKey!),
                  style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 0.5),
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
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 22),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AurixTokens.bg1.withValues(alpha: 0.84),
            AurixTokens.bg0.withValues(alpha: 0.74),
          ],
        ),
        border: Border(
          right: BorderSide(color: AurixTokens.stroke(0.2)),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 26,
            spreadRadius: -20,
            offset: const Offset(10, 0),
          ),
        ],
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'AURIX',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      color: AurixTokens.accentWarm,
                      letterSpacing: 3.6,
                      fontWeight: FontWeight.w800,
                    ),
              ),
            ),
            const SizedBox(height: 28),
            ...groups.expand((g) => [
              if (g.titleKey != null) ...[
                Padding(
                  padding: const EdgeInsets.only(left: 20, top: 8, bottom: 4),
                  child: Text(
                    L10n.t(context, g.titleKey!).toUpperCase(),
                    style: TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1),
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
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
          child: AnimatedScale(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            scale: _pressed ? 0.99 : 1,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOut,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: (widget.selected || _hover)
                    ? AurixTokens.bgElevated.withValues(alpha: 0.8)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: widget.selected
                      ? AurixTokens.accent.withValues(alpha: 0.42)
                      : (_hover ? AurixTokens.stroke(0.24) : Colors.transparent),
                  width: 1,
                ),
                boxShadow: widget.selected
                    ? [
                        BoxShadow(
                          color: AurixTokens.accentGlow.withValues(alpha: 0.2),
                          blurRadius: 20,
                          spreadRadius: -10,
                          offset: const Offset(0, 8),
                        ),
                      ]
                    : null,
              ),
              child: Row(
                children: [
                  Icon(
                    widget.icon,
                    size: 20,
                    color: widget.selected ? AurixTokens.accentWarm : AurixTokens.muted,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      widget.label,
                      style: TextStyle(
                        color: widget.selected ? AurixTokens.text : AurixTokens.textSecondary,
                        fontWeight: widget.selected ? FontWeight.w700 : FontWeight.w500,
                        fontSize: 13.5,
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
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AurixTokens.bg1.withValues(alpha: 0.56),
            AurixTokens.bg0.withValues(alpha: 0.26),
          ],
        ),
        border: Border(
          bottom: BorderSide(color: AurixTokens.stroke(0.16)),
        ),
      ),
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
          const _CreditChip(),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => context.go('/profile'),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AurixTokens.bgElevated.withValues(alpha: 0.9),
                    AurixTokens.bg1.withValues(alpha: 0.92),
                  ],
                ),
                border: Border.all(color: AurixTokens.stroke(0.3)),
                boxShadow: [
                  BoxShadow(
                    color: AurixTokens.accentGlow.withValues(alpha: 0.08),
                    blurRadius: 14,
                    spreadRadius: -8,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: const Icon(Icons.person, color: AurixTokens.textSecondary, size: 21),
            ),
          ),
        ],
      ),
    );
  }

  static String _titleFor(BuildContext context, String loc) {
    if (loc == '/home') return L10n.t(context, 'home');
    if (loc == '/releases' || loc.startsWith('/releases/')) return L10n.t(context, 'releases');
    if (loc == '/upload' || loc == '/releases/create') return L10n.t(context, 'uploadRelease');
    if (loc == '/stats') return L10n.t(context, 'statistics');
    if (loc == '/promo/video') return 'Промо-видео';
    if (loc == '/promo') return L10n.t(context, 'promo');
    if (loc.startsWith('/index')) return 'Aurix Рейтинг';
    if (loc.startsWith('/dnk/artist')) return 'DNK Арстиста';
    if (loc.startsWith('/dnk/tests') || loc == '/dnk') return 'Aurix DNK';
    if (loc.startsWith('/navigator')) return 'Навигатор артиста';
    if (loc == '/artist') return 'Артист';
    if (loc == '/ai') return L10n.t(context, 'studioAi');
    if (loc == '/finance') return L10n.t(context, 'finances');
    if (loc == '/team' || loc == '/production') return 'Продакшн';
    if (loc == '/subscription') return L10n.t(context, 'subscription');
    if (loc == '/services') return L10n.t(context, 'services');
    if (loc == '/support') return L10n.t(context, 'support');
    if (loc.startsWith('/legal')) return 'Юридические документы';
    if (loc == '/profile') return L10n.t(context, 'profile');
    if (loc == '/settings') return L10n.t(context, 'settings');
    if (loc.contains('/admin')) return L10n.t(context, 'admin');
    return L10n.t(context, 'home');
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
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            hintText: L10n.t(context, 'search'),
            hintStyle: TextStyle(color: AurixTokens.muted, fontSize: 14),
            filled: true,
            fillColor: AurixTokens.bg2.withValues(alpha: 0.68),
            prefixIcon: Icon(
              Icons.search_rounded,
              size: 18,
              color: AurixTokens.muted.withValues(alpha: 0.9),
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(16),
              borderSide: BorderSide(color: AurixTokens.stroke(0.24)),
            ),
            contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
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
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: AurixTokens.orange.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded, size: 14, color: AurixTokens.orange),
            const SizedBox(width: 3),
            balanceAsync.when(
              data: (b) => Text(
                b.toString(),
                style: const TextStyle(
                  color: AurixTokens.orange,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              loading: () => const SizedBox(
                width: 10, height: 10,
                child: CircularProgressIndicator(strokeWidth: 1.5, color: AurixTokens.orange),
              ),
              error: (_, __) => const Text('—', style: TextStyle(color: AurixTokens.orange, fontSize: 12)),
            ),
          ],
        ),
      ),
    );
  }
}
