import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/landing/sections/landing_shared.dart';
import 'package:aurix_flutter/presentation/landing/sections/new_hero_section.dart';
import 'package:aurix_flutter/presentation/landing/sections/pain_section.dart';
import 'package:aurix_flutter/presentation/landing/sections/solution_section.dart';
import 'package:aurix_flutter/presentation/landing/sections/product_demo_section.dart';
import 'package:aurix_flutter/presentation/landing/sections/how_it_works_section.dart';
import 'package:aurix_flutter/presentation/landing/sections/viral_section.dart';
import 'package:aurix_flutter/presentation/landing/sections/social_proof_section.dart';
import 'package:aurix_flutter/presentation/landing/sections/new_final_cta_section.dart';
import 'package:aurix_flutter/presentation/landing/widgets/reveal_on_scroll.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
  const LandingPage({super.key, this.onLogin, this.onRegister});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> {
  final _scrollController = ScrollController();
  bool _showStickyCta = false;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) => _handleAuthQuery());
  }

  void _onScroll() {
    final show = _scrollController.offset > 600;
    if (show != _showStickyCta) setState(() => _showStickyCta = show);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  void _goLogin() {
    if (widget.onLogin != null) {
      widget.onLogin!();
    } else {
      context.go('/login');
    }
  }

  void _goRegister() {
    if (widget.onRegister != null) {
      widget.onRegister!();
    } else {
      context.go('/register');
    }
  }

  void _handleAuthQuery() {
    final a = Uri.base.queryParameters['auth'];
    if (a == 'login') _goLogin();
    if (a == 'register') _goRegister();
  }

  @override
  Widget build(BuildContext context) {
    final narrow = isNarrow(context);
    final disableReveal = MediaQuery.of(context).accessibleNavigation;

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: Stack(
        children: [
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              // ── Header ──
              SliverAppBar(
                pinned: true,
                floating: false,
                backgroundColor: AurixTokens.bg0.withValues(alpha: 0.85),
                surfaceTintColor: Colors.transparent,
                toolbarHeight: 64,
                title: Row(
                  children: [
                    ShaderMask(
                      shaderCallback: (bounds) => const LinearGradient(
                        colors: [AurixTokens.accent, AurixTokens.aiAccent],
                      ).createShader(bounds),
                      child: const Text(
                        'AURIX',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    if (!narrow) ...[
                      _NavLink('Продукт', () => _scrollToSection(3)),
                      _NavLink('Как работает', () => _scrollToSection(4)),
                      _NavLink('Результаты', () => _scrollToSection(6)),
                      const SizedBox(width: 24),
                    ],
                    OutlineCta(label: 'Вход', onTap: _goLogin),
                    const SizedBox(width: 10),
                    PrimaryCta(label: 'Начать', onTap: _goRegister),
                  ],
                ),
                automaticallyImplyLeading: false,
              ),

              // ── 1. Hero ──
              SliverToBoxAdapter(
                child: NewHeroSection(onRegister: _goRegister),
              ),

              // ── 2. Pain ──
              _revealSliver(const PainSection(), disabled: disableReveal),

              // ── 3. Solution ──
              _revealSliver(const SolutionSection(), disabled: disableReveal),

              // ── 4. Product Demo ──
              _revealSliver(const ProductDemoSection(), disabled: disableReveal),

              // ── 5. How It Works ──
              _revealSliver(const HowItWorksSection(), disabled: disableReveal),

              // ── 6. Viral Growth ──
              _revealSliver(const ViralSection(), disabled: disableReveal),

              // ── 7. Social Proof ──
              _revealSliver(const SocialProofSection(), disabled: disableReveal),

              // ── 8. Final CTA ──
              _revealSliver(NewFinalCtaSection(onRegister: _goRegister, onLogin: _goLogin), disabled: disableReveal),

              // ── Footer ──
              const SliverToBoxAdapter(child: NewLandingFooter()),
            ],
          ),

          // Sticky CTA bar — appears after scrolling past hero
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            left: 0,
            right: 0,
            bottom: _showStickyCta ? 0 : -80,
            child: Container(
              padding: EdgeInsets.symmetric(horizontal: narrow ? 16 : 32, vertical: 10),
              decoration: BoxDecoration(
                color: AurixTokens.bg0.withValues(alpha: 0.95),
                border: Border(top: BorderSide(color: AurixTokens.accent.withValues(alpha: 0.15))),
                boxShadow: [
                  BoxShadow(
                    color: AurixTokens.accent.withValues(alpha: 0.08),
                    blurRadius: 20,
                    offset: const Offset(0, -4),
                  ),
                ],
              ),
              child: SafeArea(
                top: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (!narrow) ...[
                      Icon(Icons.auto_awesome_rounded, size: 16, color: AurixTokens.aiAccent),
                      const SizedBox(width: 8),
                      Text(
                        '50 AI кредитов бесплатно',
                        style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(width: 20),
                      Text('·', style: TextStyle(color: AurixTokens.micro)),
                      const SizedBox(width: 20),
                      Text(
                        'Осталось 47 мест',
                        style: TextStyle(color: AurixTokens.danger, fontSize: 13, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(width: 24),
                    ],
                    PrimaryCta(label: narrow ? 'Начать бесплатно' : 'Проверить потенциал →', onTap: _goRegister),
                    if (narrow) ...[
                      const SizedBox(width: 10),
                      OutlineCta(label: 'Вход', onTap: _goLogin),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  SliverToBoxAdapter _revealSliver(Widget child, {bool disabled = false}) {
    return SliverToBoxAdapter(
      child: RevealOnScroll(
        scrollListenable: _scrollController,
        disabled: disabled,
        child: child,
      ),
    );
  }

  void _scrollToSection(int sliverIndex) {
    _scrollController.animateTo(
      sliverIndex * 700.0,
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutCubic,
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, this.onTap);

  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Text(
            widget.label,
            style: TextStyle(
              color: _hover ? AurixTokens.text : AurixTokens.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}
