import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_backdrop.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/core/admin_config.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/ai/ai_assistant_overlay.dart';

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

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(currentUserProvider);
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = (isAdminAsync.valueOrNull ?? false) ||
        ref.watch(appStateProvider).isAdmin ||
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
    };

class _NavGroup {
  final String? titleKey;
  final List<_NavItem> items;
  _NavGroup({this.titleKey, required this.items});
}

List<_NavGroup> _appNavGroups(bool isAdmin) => [
  _NavGroup(titleKey: null, items: [
    _NavItem(path: '/home', icon: Icons.home_rounded, labelKey: 'home'),
    _NavItem(path: '/releases', icon: Icons.album_rounded, labelKey: 'releases'),
    _NavItem(path: '/index', icon: Icons.leaderboard_rounded, label: 'Aurix Рейтинг'),
  ]),
  _NavGroup(titleKey: 'navGroupManagement', items: [
    _NavItem(path: '/team', icon: Icons.groups_rounded, labelKey: 'team'),
    _NavItem(path: '/finance', icon: Icons.account_balance_wallet_rounded, labelKey: 'finances'),
    _NavItem(path: '/subscription', icon: Icons.card_membership_rounded, labelKey: 'subscription'),
    if (isAdmin) _NavItem(path: '/admin', icon: Icons.admin_panel_settings_rounded, labelKey: 'admin'),
  ]),
  _NavGroup(titleKey: 'navGroupTools', items: [
    _NavItem(path: '/stats', icon: Icons.analytics_rounded, labelKey: 'statistics'),
    _NavItem(path: '/promo', icon: Icons.rocket_launch_rounded, labelKey: 'promo'),
    _NavItem(path: '/ai', icon: Icons.auto_awesome, labelKey: 'studioAi'),
    _NavItem(path: '/services', icon: Icons.build_rounded, labelKey: 'services'),
  ]),
  _NavGroup(titleKey: 'navGroupMore', items: [
    _NavItem(path: '/legal', icon: Icons.description_outlined, label: 'Юридические документы'),
    _NavItem(path: '/support', icon: Icons.support_agent_rounded, labelKey: 'support'),
    _NavItem(path: '/profile', icon: Icons.person_rounded, labelKey: 'profile'),
  ]),
];

List<_NavItem> _appNavItems(bool isAdmin) =>
    _appNavGroups(isAdmin).expand((g) => g.items).toList();

class _NavDrawerContent extends StatelessWidget {
  final String currentLocation;
  final bool isAdmin;
  final void Function(String path) onTap;

  const _NavDrawerContent({required this.currentLocation, required this.isAdmin, required this.onTap});

  bool _selected(_NavItem i) =>
      currentLocation == i.path ||
      (currentLocation.startsWith('/releases/') && i.path == '/releases') ||
      (currentLocation == '/releases/create' && i.path == '/upload') ||
      (currentLocation.startsWith('/legal') && i.path == '/legal') ||
      (currentLocation.startsWith('/index') && i.path == '/index') ||
      (currentLocation.startsWith('/admin') && i.path == '/admin') ||
      (currentLocation == '/profile' && i.path == '/profile');

  @override
  Widget build(BuildContext context) {
    final groups = _appNavGroups(isAdmin);
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
    (currentLocation.startsWith('/releases/') && i.path == '/releases') ||
    (currentLocation == '/releases/create' && i.path == '/upload') ||
    (currentLocation.startsWith('/legal') && i.path == '/legal') ||
    (currentLocation.startsWith('/index') && i.path == '/index') ||
    (currentLocation.startsWith('/admin') && i.path == '/admin') ||
    (currentLocation == '/profile' && i.path == '/profile');

class _Sidebar extends StatelessWidget {
  final String currentLocation;
  final bool isAdmin;

  const _Sidebar({required this.currentLocation, required this.isAdmin});

  @override
  Widget build(BuildContext context) {
    final groups = _appNavGroups(isAdmin);
    return Container(
      width: 260,
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
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

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
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
              child: _SearchField(
                onSelectRelease: (id) => context.go('/releases/$id'),
              ),
            ),
          if (isDesktop) const SizedBox(width: 12),
          const _LocaleToggle(),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => context.go('/profile'),
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

  static String _titleFor(BuildContext context, String loc) {
    if (loc == '/home') return L10n.t(context, 'home');
    if (loc == '/releases' || loc.startsWith('/releases/')) return L10n.t(context, 'releases');
    if (loc == '/upload' || loc == '/releases/create') return L10n.t(context, 'uploadRelease');
    if (loc == '/stats') return L10n.t(context, 'statistics');
    if (loc == '/promo') return L10n.t(context, 'promo');
    if (loc.startsWith('/index')) return 'Aurix Рейтинг';
    if (loc == '/ai') return L10n.t(context, 'studioAi');
    if (loc == '/finance') return L10n.t(context, 'finances');
    if (loc == '/team') return L10n.t(context, 'team');
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
          _LocalePill(
            label: 'RU',
            active: appState.locale == AppLocale.ru,
            onTap: () => appState.setLocale(AppLocale.ru),
          ),
          _LocalePill(
            label: 'EN',
            active: appState.locale == AppLocale.en,
            onTap: () => appState.setLocale(AppLocale.en),
          ),
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
