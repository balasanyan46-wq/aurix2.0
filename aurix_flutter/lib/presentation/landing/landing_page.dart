import 'dart:math' as math;
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:go_router/go_router.dart';

// ─────────────────────────────────────────────────────────────────────────────
// AURIX — Premium Landing v8  ·  cinematic · futuristic · high-conversion
// ─────────────────────────────────────────────────────────────────────────────

/// Мобильная оптимизация — проверяем ширину вью БЕЗ context.
/// Используется в initState (где context ещё нет) чтобы не запускать
/// бесконечные 60fps анимации на мобильных устройствах.
bool _isDesktopView() {
  try {
    final view = WidgetsBinding.instance.platformDispatcher.views.first;
    final w = view.physicalSize.width / view.devicePixelRatio;
    return w >= 700;
  } catch (_) {
    return true;
  }
}

/* ── Design tokens ────────────────────────────────────────────────────────── */

class _T {
  _T._();
  static const bg       = Color(0xFF030305);
  static const bg2      = Color(0xFF08080E);
  static const surface  = Color(0xFF0A0A0F);
  static const card     = Color(0xFF0D0D14);
  static const cardHi   = Color(0xFF141420);
  static const glass    = Color(0x08FFFFFF);
  static const glassHi  = Color(0x14FFFFFF);
  static const border   = Color(0x0EFFFFFF);
  static const borderHi = Color(0x1AFFFFFF);
  static const text     = Color(0xFFF5F5F7);
  static const sub      = Color(0xFFA1A1AA);
  static const muted    = Color(0xFF71717A);
  static const dim      = Color(0xFF3F3F46);
  static const accent   = Color(0xFFFF6A1A);
  static const accentHi = Color(0xFFFF8844);
  static const green    = Color(0xFF34D399);
  static const purple   = Color(0xFF8B5CF6);
  static const blue     = Color(0xFF3B82F6);
  static const cyan     = Color(0xFF06B6D4);
  static Color w([double a = .06]) => Color.fromRGBO(255, 255, 255, a);
  static Color g([double a = .1])  => Color.fromRGBO(255, 106, 26, a);
  static const hd = 'Unbounded';
  static const bd = 'Manrope';
}

bool _isDesktop(BuildContext c) => MediaQuery.sizeOf(c).width >= 1024;
bool _isNarrow(BuildContext c)  => MediaQuery.sizeOf(c).width < 640;
bool _isMid(BuildContext c)     { final w = MediaQuery.sizeOf(c).width; return w >= 640 && w < 1024; }

// ─────────────────────────────────────────────────────────────────────────────
// PAGE
// ─────────────────────────────────────────────────────────────────────────────

class LandingPage extends StatefulWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;
  const LandingPage({super.key, this.onLogin, this.onRegister});
  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage> with TickerProviderStateMixin {
  final _sc = ScrollController();
  final _sy = ValueNotifier<double>(0.0);
  final _mouse = ValueNotifier<Offset>(Offset.zero);
  final _kDist = GlobalKey();
  final _kAI = GlobalKey();
  final _kAnalytics = GlobalKey();
  final _kHow = GlobalKey();

  void _scrollTo(GlobalKey key) {
    final ctx = key.currentContext;
    if (ctx != null) {
      Scrollable.ensureVisible(ctx, duration: const Duration(milliseconds: 600), curve: Curves.easeOutCubic, alignment: .05);
    }
  }

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (mounted) _sy.value = _sc.offset;
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final a = Uri.base.queryParameters['auth'];
      if (a == 'login') _login();
      if (a == 'register') _reg();
    });
  }

  @override
  void dispose() { _sy.dispose(); _mouse.dispose(); _sc.dispose(); super.dispose(); }
  void _login() { widget.onLogin != null ? widget.onLogin!() : context.go('/login'); }
  void _reg() { widget.onRegister != null ? widget.onRegister!() : context.go('/register'); }

  @override
  Widget build(BuildContext context) {
    final sz = MediaQuery.sizeOf(context);
    return Scaffold(
      backgroundColor: _T.bg,
      body: MouseRegion(
        onHover: (e) => _mouse.value = e.localPosition,
        child: Stack(children: [
          // Heavy painters only on desktop; mobile gets static gradient
          if (sz.width >= 1024) ...[
            Positioned.fill(
              child: AnimatedBuilder(
                animation: Listenable.merge([_sy, _mouse]),
                builder: (_, __) => _WaveBackground(sy: _sy.value, mouse: _mouse.value, sz: sz),
              ),
            ),
            Positioned.fill(
              child: ValueListenableBuilder<double>(
                valueListenable: _sy,
                builder: (_, sy, __) => _ParticleField(sy: sy, mouse: _mouse.value, sz: sz),
              ),
            ),
          ] else
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -.5),
                    radius: 1.4,
                    colors: [_T.accent.withValues(alpha: .04), _T.bg, _T.bg],
                    stops: const [0, .4, 1],
                  ),
                ),
              ),
            ),
          CustomScrollView(
            controller: _sc,
            physics: const BouncingScrollPhysics(),
            slivers: [
              _NavBar(onLogin: _login, onReg: _reg, sc: _sc, navItems: [
                ('Дистрибуция', () => _scrollTo(_kDist)),
                ('AI', () => _scrollTo(_kAI)),
                ('Аналитика', () => _scrollTo(_kAnalytics)),
                ('Как работает', () => _scrollTo(_kHow)),
              ]),
              SliverToBoxAdapter(
                child: ValueListenableBuilder<Offset>(
                  valueListenable: _mouse,
                  builder: (_, mouse, __) => _HeroSection(mouse: mouse, sz: sz, onReg: _reg),
                ),
              ),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: const _MetricsStrip())),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: const _DeviceShowcase())),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: const _LiveDemoBlock())),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: const _ProblemSection())),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: const _SolutionSection())),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: KeyedSubtree(key: _kDist, child: const _DistributionSection()))),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: KeyedSubtree(key: _kAI, child: const _AIStudioSection()))),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: KeyedSubtree(key: _kAnalytics, child: const _AnalyticsSection()))),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: const _PromoSection())),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: KeyedSubtree(key: _kHow, child: const _HowItWorksSection()))),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: const _ProductPreview())),
              SliverToBoxAdapter(child: _Rv(sc: _sc, child: _FinalCta(onReg: _reg))),
              SliverToBoxAdapter(child: _Footer(onLogin: _login)),
            ],
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// WAVE BACKGROUND
// ─────────────────────────────────────────────────────────────────────────────

class _WaveBackground extends StatefulWidget {
  final double sy;
  final Offset mouse;
  final Size sz;
  const _WaveBackground({required this.sy, required this.mouse, required this.sz});
  @override
  State<_WaveBackground> createState() => _WaveBackgroundState();
}

class _WaveBackgroundState extends State<_WaveBackground> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 20));

    if (_isDesktopView()) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _WavePainter(t: _c.value, sy: widget.sy, mouse: widget.mouse, sz: widget.sz),
        size: Size.infinite,
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final double t, sy;
  final Offset mouse;
  final Size sz;
  _WavePainter({required this.t, required this.sy, required this.mouse, required this.sz});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final fade = (1.0 - sy / (sz.height * 2)).clamp(0.0, 1.0);
    final mx = (mouse.dx / sz.width - .5) * 30;
    final my = (mouse.dy / sz.height - .5) * 20;
    final phase = t * math.pi * 2;

    _drawWave(canvas, w, h, fade, phase, mx, my, isLeft: true);
    _drawWave(canvas, w, h, fade, phase, mx, my, isLeft: false);

    // Central gradient orb
    final cx = w / 2 + mx;
    final cy = h * .25 - sy * .15 + my;
    final breath = .85 + .15 * math.sin(phase * .7);

    canvas.drawCircle(
      Offset(cx, cy),
      w * .5 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _T.accent.withValues(alpha: .04 * fade),
            _T.purple.withValues(alpha: .015 * fade),
            Colors.transparent,
          ],
          stops: const [0, .4, 1],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: w * .5 * breath)),
    );

    canvas.drawCircle(
      Offset(cx, cy),
      180 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _T.accent.withValues(alpha: .14 * fade * breath),
            _T.accent.withValues(alpha: .04 * fade),
            Colors.transparent,
          ],
          stops: const [0, .5, 1],
        ).createShader(Rect.fromCircle(center: Offset(cx, cy), radius: 180 * breath)),
    );

    // Secondary orb (purple, offset)
    final cx2 = w * .65 + mx * .5;
    final cy2 = h * .35 - sy * .1 + my * .5;
    canvas.drawCircle(
      Offset(cx2, cy2),
      120 * breath,
      Paint()
        ..shader = RadialGradient(
          colors: [
            _T.purple.withValues(alpha: .06 * fade * breath),
            Colors.transparent,
          ],
        ).createShader(Rect.fromCircle(center: Offset(cx2, cy2), radius: 120 * breath)),
    );
  }

  void _drawWave(Canvas canvas, double w, double h, double fade, double phase, double mx, double my, {required bool isLeft}) {
    final side = isLeft ? -1.0 : 1.0;
    final baseX = isLeft ? w * .08 + mx * .3 : w * .92 + mx * .3;

    for (var layer = 0; layer < 3; layer++) {
      final path = Path();
      final layerPhase = phase * (.6 + layer * .15) + (isLeft ? 0 : math.pi * .7);
      final amplitude = (40 + layer * 25) * (.8 + .2 * math.sin(phase * .4 + layer));
      final spread = 120.0 + layer * 60;
      final alpha = (.04 - layer * .012) * fade;

      path.moveTo(baseX + side * spread, 0);
      for (var y = 0.0; y <= h; y += 8) {
        final wave1 = math.sin(y * .003 + layerPhase) * amplitude;
        final wave2 = math.sin(y * .006 - layerPhase * .7) * amplitude * .4;
        final wave3 = math.sin(y * .001 + layerPhase * .3) * amplitude * .6;
        final x = baseX + (wave1 + wave2 + wave3) * (.7 + .3 * math.sin(y * .002 + phase));
        if (y == 0) path.moveTo(x, y); else path.lineTo(x, y);
      }

      final color = layer == 0
          ? _T.accent.withValues(alpha: alpha)
          : layer == 1
              ? _T.purple.withValues(alpha: alpha * .7)
              : _T.blue.withValues(alpha: alpha * .5);

      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..strokeWidth = 2.0 + layer * 1.5
          ..style = PaintingStyle.stroke
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, 12 + layer * 8),
      );
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// PARTICLE FIELD
// ─────────────────────────────────────────────────────────────────────────────

class _ParticleField extends StatefulWidget {
  final double sy;
  final Offset mouse;
  final Size sz;
  const _ParticleField({required this.sy, required this.mouse, required this.sz});
  @override
  State<_ParticleField> createState() => _ParticleFieldState();
}

class _ParticleFieldState extends State<_ParticleField> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 30));

    if (_isDesktopView()) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => CustomPaint(
        painter: _ParticlePainter(t: _c.value, sy: widget.sy, sz: widget.sz),
        size: Size.infinite,
      ),
    );
  }
}

class _ParticlePainter extends CustomPainter {
  final double t, sy;
  final Size sz;
  _ParticlePainter({required this.t, required this.sy, required this.sz});

  @override
  void paint(Canvas canvas, Size size) {
    final rng = math.Random(77);
    final pp = Paint();
    final phase = t * math.pi * 2;
    final fade = (1.0 - sy / (sz.height * 3)).clamp(0.0, 1.0);

    for (var i = 0; i < 20; i++) {
      final bx = rng.nextDouble() * size.width;
      final by = rng.nextDouble() * size.height * 2;
      final speed = .3 + rng.nextDouble() * .7;
      final drift = math.sin(phase * speed + i * .8) * 20;
      final float = math.cos(phase * speed * .5 + i * 1.3) * 15;

      final x = bx + drift;
      final y = (by - sy * (.2 + rng.nextDouble() * .3)) % (size.height * 2) + float;

      if (y < -20 || y > size.height + 20) continue;

      final alpha = (.03 + .04 * math.sin(phase * 2 + i * .9)).clamp(0.0, 1.0) * fade;
      final radius = .5 + rng.nextDouble() * 1.8;

      pp.color = (i % 3 == 0 ? _T.accent : i % 3 == 1 ? _T.purple : _T.blue)
          .withValues(alpha: alpha);
      canvas.drawCircle(Offset(x, y), radius, pp);
    }
  }

  @override
  bool shouldRepaint(covariant _ParticlePainter old) => true;
}

// ─────────────────────────────────────────────────────────────────────────────
// NAVBAR
// ─────────────────────────────────────────────────────────────────────────────

class _NavBar extends StatefulWidget {
  final VoidCallback onLogin, onReg;
  final ScrollController sc;
  final List<(String, VoidCallback)> navItems;
  const _NavBar({required this.onLogin, required this.onReg, required this.sc, this.navItems = const []});
  @override
  State<_NavBar> createState() => _NavBarState();
}

class _NavBarState extends State<_NavBar> {
  bool _scrolled = false;

  void _onScroll() {
    final s = widget.sc.offset > 50;
    if (s != _scrolled) setState(() => _scrolled = s);
  }

  @override
  void initState() {
    super.initState();
    widget.sc.addListener(_onScroll);
  }

  @override
  void dispose() {
    widget.sc.removeListener(_onScroll);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final nr = _isNarrow(context);
    final dk = _isDesktop(context);
    final scrolled = _scrolled;
    return SliverAppBar(
      pinned: true,
      floating: false,
      backgroundColor: scrolled ? _T.bg.withValues(alpha: .92) : Colors.transparent,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: nr ? 56 : 64,
      automaticallyImplyLeading: false,
      elevation: 0,
      titleSpacing: 0,
      title: Container(
        padding: EdgeInsets.symmetric(horizontal: nr ? 10 : 24),
        child: nr
          // ═══ MOBILE: «Код Артиста» слева · AURIX по центру · кнопки справа ═══
          ? Row(children: [
              // Слева — pill «Код Артиста»
              _CastingNavBtn(
                compact: true,
                onTap: () => GoRouter.of(context).go('/casting'),
              ),
              // Распорка → лого ляжет по центру между pill и кнопками
              const Spacer(),
              // Центр — AURIX
              Text(
                'AURIX',
                style: TextStyle(
                  fontFamily: _T.hd,
                  color: _T.accent,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 3,
                ),
              ),
              const Spacer(),
              // Справа — «Войти» + «Создать»
              _NavTextLink('Войти', onTap: widget.onLogin),
              const SizedBox(width: 6),
              _NavBtn('Создать', onTap: widget.onReg, compact: true),
            ])
          // ═══ DESKTOP: AURIX слева · nav · spacer · pill · кнопки справа ═══
          : Row(children: [
              Text(
                'AURIX',
                style: TextStyle(
                  fontFamily: _T.hd,
                  color: _T.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 4,
                ),
              ),
              if (dk) ...[
                const SizedBox(width: 32),
                for (final item in widget.navItems)
                  _NavLink(item.$1, onTap: item.$2),
              ],
              const SizedBox(width: 10),
              _CastingNavBtn(onTap: () => GoRouter.of(context).go('/casting')),
              const Spacer(),
              _NavBtn('Войти', onTap: widget.onLogin, ghost: true),
              const SizedBox(width: 10),
              _NavBtn('Создать аккаунт', onTap: widget.onReg),
            ]),
      ),
    );
  }
}

// Простой текст-линк для «Войти» в компактной версии хедера.
class _NavTextLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavTextLink(this.label, {required this.onTap});
  @override
  State<_NavTextLink> createState() => _NavTextLinkState();
}

class _NavTextLinkState extends State<_NavTextLink> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 14),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: _T.bd,
              color: _h ? _T.text : _T.sub,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavLink extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _NavLink(this.label, {required this.onTap});
  @override
  State<_NavLink> createState() => _NavLinkState();
}

class _NavLinkState extends State<_NavLink> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      child: MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: _T.bd,
              color: _h ? _T.text : _T.muted,
              fontSize: 13,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HERO — cinematic entrance with floating metrics
// ─────────────────────────────────────────────────────────────────────────────

class _HeroSection extends StatefulWidget {
  final Offset mouse;
  final Size sz;
  final VoidCallback onReg;
  const _HeroSection({required this.mouse, required this.sz, required this.onReg});
  @override
  State<_HeroSection> createState() => _HeroSectionState();
}

class _HeroSectionState extends State<_HeroSection> with TickerProviderStateMixin {
  late final AnimationController _enter;
  late final Animation<double> _fadeBadge, _fadeTitle, _fadeSub, _fadeBtn, _fadeChips;

  @override
  void initState() {
    super.initState();
    _enter = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400));
    _fadeBadge = CurvedAnimation(parent: _enter, curve: const Interval(0, .35, curve: Curves.easeOutCubic));
    _fadeTitle = CurvedAnimation(parent: _enter, curve: const Interval(.1, .5, curve: Curves.easeOutCubic));
    _fadeSub = CurvedAnimation(parent: _enter, curve: const Interval(.25, .65, curve: Curves.easeOutCubic));
    _fadeBtn = CurvedAnimation(parent: _enter, curve: const Interval(.4, .8, curve: Curves.easeOutCubic));
    _fadeChips = CurvedAnimation(parent: _enter, curve: const Interval(.55, .95, curve: Curves.easeOutCubic));
    Future.delayed(const Duration(milliseconds: 300), () { if (mounted) _enter.forward(); });
  }

  @override
  void dispose() { _enter.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    return SizedBox(
      height: widget.sz.height * (dk ? .92 : .88),
      child: AnimatedBuilder(
        animation: _enter,
        builder: (_, __) => Stack(children: [
          // Floating metric chips (desktop only)
          if (dk) ...[
            _FloatingChip(
              label: '142K', sub: 'стримов',
              color: _T.accent,
              left: widget.sz.width * .08, top: widget.sz.height * .28,
              anim: _fadeChips.value,
              mouse: widget.mouse, sz: widget.sz,
            ),
            _FloatingChip(
              label: '+24.3%', sub: 'рост',
              color: _T.green,
              left: widget.sz.width * .85, top: widget.sz.height * .22,
              anim: _fadeChips.value,
              mouse: widget.mouse, sz: widget.sz,
            ),
            _FloatingChip(
              label: '20+', sub: 'площадок',
              color: _T.purple,
              left: widget.sz.width * .06, top: widget.sz.height * .58,
              anim: _fadeChips.value,
              mouse: widget.mouse, sz: widget.sz,
            ),
            _FloatingChip(
              label: '₽84K', sub: 'доход',
              color: _T.blue,
              left: widget.sz.width * .88, top: widget.sz.height * .55,
              anim: _fadeChips.value,
              mouse: widget.mouse, sz: widget.sz,
            ),
          ],

          // Center content
          Center(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: nr ? 24 : 48),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Badge — urgency
                  Opacity(
                    opacity: _fadeBadge.value,
                    child: Transform.translate(
                      offset: Offset(0, 14 * (1 - _fadeBadge.value)),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 7),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(24),
                          color: _T.accent.withValues(alpha: .06),
                          border: Border.all(color: _T.accent.withValues(alpha: .2)),
                        ),
                        child: Row(mainAxisSize: MainAxisSize.min, children: [
                          _PulsingDot(color: _T.accent),
                          const SizedBox(width: 10),
                          Text(
                            'Ранний доступ · Места ограничены',
                            style: TextStyle(fontFamily: _T.bd, color: _T.accent, fontSize: 13, fontWeight: FontWeight.w600, letterSpacing: .3),
                          ),
                        ]),
                      ),
                    ),
                  ),

                  SizedBox(height: dk ? 40 : 28),

                  // Title
                  Opacity(
                    opacity: _fadeTitle.value,
                    child: Transform.translate(
                      offset: Offset(0, 36 * (1 - _fadeTitle.value)),
                      child: Text(
                        'Пока ты ждёшь —\nдругие растут',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontFamily: _T.hd,
                          color: _T.text,
                          fontSize: dk ? 68 : (nr ? 32 : 48),
                          fontWeight: FontWeight.w700,
                          height: 1.1,
                          letterSpacing: dk ? -2 : -1,
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: dk ? 28 : 20),

                  // Subtitle
                  Opacity(
                    opacity: _fadeSub.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _fadeSub.value)),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxWidth: dk ? 620 : double.infinity),
                        child: Text(
                          'AURIX — единственная система, которая дистрибутирует, анализирует, продвигает и растит артиста. Автоматически.',
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontFamily: _T.bd,
                            color: _T.sub,
                            fontSize: dk ? 17 : (nr ? 14 : 15),
                            fontWeight: FontWeight.w400,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),

                  SizedBox(height: dk ? 52 : 36),

                  // CTA
                  Opacity(
                    opacity: _fadeBtn.value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - _fadeBtn.value)),
                      child: Column(children: [
                        _GlowButton(label: 'Начать бесплатно', onTap: widget.onReg),
                        const SizedBox(height: 16),
                        // Live social proof
                        _LiveSocialProof(),
                      ]),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ]),
      ),
    );
  }
}

class _FloatingChip extends StatelessWidget {
  final String label, sub;
  final Color color;
  final double left, top, anim;
  final Offset mouse;
  final Size sz;
  const _FloatingChip({
    required this.label, required this.sub, required this.color,
    required this.left, required this.top, required this.anim,
    required this.mouse, required this.sz,
  });

  @override
  Widget build(BuildContext context) {
    final px = (mouse.dx / sz.width - .5) * 12;
    final py = (mouse.dy / sz.height - .5) * 8;
    return Positioned(
      left: left + px,
      top: top + py,
      child: Opacity(
        opacity: anim,
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - anim)),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _T.card.withValues(alpha: .8),
              border: Border.all(color: color.withValues(alpha: .15)),
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: .08), blurRadius: 24, spreadRadius: -4),
                BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 20),
              ],
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(label, style: TextStyle(fontFamily: _T.hd, color: color, fontSize: 16, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text(sub, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 11, fontWeight: FontWeight.w500)),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Live social proof counter ──

class _LiveSocialProof extends StatefulWidget {
  @override
  State<_LiveSocialProof> createState() => _LiveSocialProofState();
}

class _LiveSocialProofState extends State<_LiveSocialProof> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 40));

    if (_isDesktopView()) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final count = 847 + (_c.value * 12).toInt();
        return Row(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _T.green,
              boxShadow: [BoxShadow(color: _T.green.withValues(alpha: .5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            '$count артистов уже внутри',
            style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 13, fontWeight: FontWeight.w500),
          ),
        ]);
      },
    );
  }
}

// LIVE METRICS STRIP
// ─────────────────────────────────────────────────────────────────────────────

class _MetricsStrip extends StatefulWidget {
  const _MetricsStrip();
  @override
  State<_MetricsStrip> createState() => _MetricsStripState();
}

class _MetricsStripState extends State<_MetricsStrip> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 40));

    if (_isDesktopView()) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  String _fmt(int n) => n.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} ');

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: dk ? 120 : (nr ? 20 : 48), vertical: dk ? 24 : 16),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final streams = 143022 + (t * 380).toInt();
          final revenue = 84674 + (t * 120).toInt();
          final growth = 24.6 + t * 0.4;
          final listeners = 38455 + (t * 85).toInt();

          return Container(
            padding: EdgeInsets.all(dk ? 28 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _T.glass,
              border: Border.all(color: _T.border),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: dk
                ? Row(children: [
                    Expanded(child: _LiveMetric(label: 'Стримы', value: _fmt(streams), icon: Icons.play_circle_rounded, color: _T.accent)),
                    _MetricDivider(),
                    Expanded(child: _LiveMetric(label: 'Доход', value: '₽${_fmt(revenue)}', icon: Icons.trending_up_rounded, color: _T.green)),
                    _MetricDivider(),
                    Expanded(child: _LiveMetric(label: 'Рост', value: '+${growth.toStringAsFixed(1)}%', icon: Icons.rocket_launch_rounded, color: _T.purple, pulse: true)),
                    _MetricDivider(),
                    Expanded(child: _LiveMetric(label: 'Слушатели', value: _fmt(listeners), icon: Icons.headphones_rounded, color: _T.blue)),
                  ])
                : Wrap(
                    spacing: 16, runSpacing: 16, alignment: WrapAlignment.center,
                    children: [
                      _LiveMetric(label: 'Стримы', value: _fmt(streams), icon: Icons.play_circle_rounded, color: _T.accent, compact: true),
                      _LiveMetric(label: 'Доход', value: '₽${_fmt(revenue)}', icon: Icons.trending_up_rounded, color: _T.green, compact: true),
                      _LiveMetric(label: 'Рост', value: '+${growth.toStringAsFixed(1)}%', icon: Icons.rocket_launch_rounded, color: _T.purple, pulse: true, compact: true),
                      _LiveMetric(label: 'Слушатели', value: _fmt(listeners), icon: Icons.headphones_rounded, color: _T.blue, compact: true),
                    ],
                  ),
          );
        },
      ),
    );
  }
}

class _LiveMetric extends StatelessWidget {
  final String label, value;
  final IconData icon;
  final Color color;
  final bool pulse, compact;
  const _LiveMetric({required this.label, required this.value, required this.icon, required this.color, this.pulse = false, this.compact = false});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: compact ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: .1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 11, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Row(children: [
            Text(value, style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 16, fontWeight: FontWeight.w700)),
            if (pulse) ...[const SizedBox(width: 6), _PulsingDot(color: color)],
          ]),
        ]),
      ],
    );
  }
}

class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});
  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

    if (_isDesktopView()) _c.repeat(reverse: true);
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        width: 6, height: 6,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: widget.color.withValues(alpha: .5 + .5 * _c.value),
          boxShadow: [BoxShadow(color: widget.color.withValues(alpha: .3 * _c.value), blurRadius: 8)],
        ),
      ),
    );
  }
}

class _MetricDivider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(width: 1, height: 40, margin: const EdgeInsets.symmetric(horizontal: 8), color: _T.border);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// LIVE DEMO BLOCK — simulated real-time product activity
// ─────────────────────────────────────────────────────────────────────────────

class _LiveDemoBlock extends StatefulWidget {
  const _LiveDemoBlock();
  @override
  State<_LiveDemoBlock> createState() => _LiveDemoBlockState();
}

class _LiveDemoBlockState extends State<_LiveDemoBlock> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 8));

    if (_isDesktopView()) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: dk ? 120 : (nr ? 20 : 48),
        vertical: dk ? 32 : 20,
      ),
      child: AnimatedBuilder(
        animation: _c,
        builder: (_, __) {
          final t = _c.value;
          final pulse = (.5 + .5 * math.sin(t * math.pi * 2)).clamp(0.0, 1.0);

          return Container(
            padding: EdgeInsets.all(dk ? 28 : 20),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              color: _T.card,
              border: Border.all(color: _T.accent.withValues(alpha: .08)),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .3), blurRadius: 40, offset: const Offset(0, 12))],
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  width: 6, height: 6,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _T.green.withValues(alpha: .6 + .4 * pulse),
                    boxShadow: [BoxShadow(color: _T.green.withValues(alpha: .4 * pulse), blurRadius: 8)],
                  ),
                ),
                const SizedBox(width: 8),
                Text('LIVE', style: TextStyle(fontFamily: _T.hd, color: _T.green, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2)),
                const SizedBox(width: 12),
                Text('Прямо сейчас в AURIX', style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 12)),
              ]),
              SizedBox(height: dk ? 20 : 16),
              if (dk)
                Row(children: [
                  Expanded(child: _DemoActivity(
                    icon: Icons.play_circle_rounded,
                    label: 'Стримы растут',
                    value: '${(1428 + (t * 47).toInt())}',
                    sub: 'за последний час',
                    color: _T.accent,
                    t: t,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _DemoActivity(
                    icon: Icons.auto_awesome_rounded,
                    label: 'AI анализирует',
                    value: '«${['Новый рассвет', 'Огни ночи', 'Без тормозов'][(t * 3).toInt() % 3]}»',
                    sub: 'определение хуков...',
                    color: _T.purple,
                    t: t,
                  )),
                  const SizedBox(width: 12),
                  Expanded(child: _DemoActivity(
                    icon: Icons.cloud_upload_rounded,
                    label: 'Новый релиз',
                    value: 'Загрузка на 20+ площадок',
                    sub: '${(t * 100).toInt() % 100}% завершено',
                    color: _T.green,
                    t: t,
                  )),
                ])
              else
                Column(children: [
                  _DemoActivity(icon: Icons.play_circle_rounded, label: 'Стримы растут', value: '${(1428 + (t * 47).toInt())}', sub: 'за последний час', color: _T.accent, t: t),
                  const SizedBox(height: 10),
                  _DemoActivity(icon: Icons.auto_awesome_rounded, label: 'AI анализирует', value: '«Новый рассвет»', sub: 'определение хуков...', color: _T.purple, t: t),
                  const SizedBox(height: 10),
                  _DemoActivity(icon: Icons.cloud_upload_rounded, label: 'Новый релиз', value: 'Загрузка на 20+ площадок', sub: '${(t * 100).toInt() % 100}% завершено', color: _T.green, t: t),
                ]),
            ]),
          );
        },
      ),
    );
  }
}

class _DemoActivity extends StatelessWidget {
  final IconData icon;
  final String label, value, sub;
  final Color color;
  final double t;
  const _DemoActivity({required this.icon, required this.label, required this.value, required this.sub, required this.color, required this.t});

  @override
  Widget build(BuildContext context) {
    final pulse = (.5 + .5 * math.sin(t * math.pi * 4 + label.hashCode.toDouble())).clamp(0.0, 1.0);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: color.withValues(alpha: .03 + .02 * pulse),
        border: Border.all(color: color.withValues(alpha: .08 + .06 * pulse)),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: .1),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
          Text(label, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 10, fontWeight: FontWeight.w500)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
          const SizedBox(height: 1),
          Text(sub, style: TextStyle(fontFamily: _T.bd, color: color.withValues(alpha: .7), fontSize: 10)),
        ])),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// PROBLEM SECTION — pain points with visual cards
// ─────────────────────────────────────────────────────────────────────────────

class _ProblemSection extends StatelessWidget {
  const _ProblemSection();

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    return _Section(
      padding: EdgeInsets.symmetric(
        horizontal: dk ? 120 : (nr ? 20 : 48),
        vertical: dk ? 140 : 80,
      ),
      child: Column(children: [
        // Big statement — emotional punch
        Text(
          'Твоя музыка умирает\nв тишине',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _T.hd,
            color: _T.text,
            fontSize: dk ? 52 : (nr ? 28 : 38),
            fontWeight: FontWeight.w700,
            height: 1.1,
            letterSpacing: dk ? -1.5 : -.5,
          ),
        ),
        SizedBox(height: dk ? 16 : 12),
        Text(
          'И дело не в таланте. Дело в системе, которой у тебя нет.',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _T.bd, color: _T.accent.withValues(alpha: .7), fontSize: dk ? 18 : 15, height: 1.5, fontWeight: FontWeight.w500),
        ),

        SizedBox(height: dk ? 64 : 40),

        // Pain cards
        if (dk)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(child: _PainCard(
              icon: Icons.volume_off_rounded,
              stat: '90%',
              title: 'Релизов не слышат',
              desc: 'Музыку выпускают все. Но без стратегии и продвижения 90% треков не набирают даже 1000 стримов.',
              color: _T.accent,
            )),
            const SizedBox(width: 20),
            Expanded(child: _PainCard(
              icon: Icons.casino_rounded,
              stat: '0',
              title: 'Стратегий у артиста',
              desc: 'Промо на удачу. Контент-план — ноль. Результат — тишина. Каждый релиз как лотерея.',
              color: _T.purple,
            )),
            const SizedBox(width: 20),
            Expanded(child: _PainCard(
              icon: Icons.visibility_off_rounded,
              stat: '5×',
              title: 'Разница в росте',
              desc: 'Артисты с системой растут в 5 раз быстрее. Без анализа и плана музыка остаётся невидимой.',
              color: _T.blue,
            )),
          ])
        else
          Column(children: [
            _PainCard(
              icon: Icons.volume_off_rounded, stat: '90%',
              title: 'Релизов не слышат',
              desc: 'Музыку выпускают все. Без стратегии 90% треков не набирают даже 1000 стримов.',
              color: _T.accent,
            ),
            const SizedBox(height: 16),
            _PainCard(
              icon: Icons.casino_rounded, stat: '0',
              title: 'Стратегий у артиста',
              desc: 'Промо на удачу. Контент-план — ноль. Каждый релиз как лотерея.',
              color: _T.purple,
            ),
            const SizedBox(height: 16),
            _PainCard(
              icon: Icons.visibility_off_rounded, stat: '5×',
              title: 'Разница в росте',
              desc: 'Артисты с системой растут в 5 раз быстрее.',
              color: _T.blue,
            ),
          ]),
      ]),
    );
  }
}

class _PainCard extends StatefulWidget {
  final IconData icon;
  final String stat, title, desc;
  final Color color;
  const _PainCard({required this.icon, required this.stat, required this.title, required this.desc, required this.color});
  @override
  State<_PainCard> createState() => _PainCardState();
}

class _PainCardState extends State<_PainCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedScale(
        scale: _h ? 1.03 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _h ? _T.cardHi : _T.card,
            border: Border.all(color: _h ? widget.color.withValues(alpha: .2) : _T.border),
            boxShadow: [
              BoxShadow(color: Colors.black.withValues(alpha: .4), blurRadius: 40, offset: const Offset(0, 12)),
              if (_h) BoxShadow(color: widget.color.withValues(alpha: .08), blurRadius: 60, spreadRadius: -10),
            ],
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Container(
              width: 48, height: 48,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                gradient: LinearGradient(colors: [widget.color.withValues(alpha: .12), widget.color.withValues(alpha: .04)]),
              ),
              child: Icon(widget.icon, color: widget.color, size: 22),
            ),
            const Spacer(),
            Text(widget.stat, style: TextStyle(fontFamily: _T.hd, color: widget.color.withValues(alpha: .3), fontSize: 42, fontWeight: FontWeight.w800)),
          ]),
          const SizedBox(height: 20),
          Text(widget.title, style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 17, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(widget.desc, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 14, height: 1.6)),
        ]),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SOLUTION SECTION — system diagram
// ─────────────────────────────────────────────────────────────────────────────

class _SolutionSection extends StatelessWidget {
  const _SolutionSection();

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    const nodes = [
      ('Дистрибуция', 'Релиз на 20+ площадках', Icons.album_rounded, _T.accent),
      ('AI Анализ', 'Стратегия для каждого трека', Icons.auto_awesome_rounded, _T.purple),
      ('Аналитика', 'Стримы и доход в реальном времени', Icons.insights_rounded, _T.blue),
      ('Промо', 'Контент-план и идеи', Icons.rocket_launch_rounded, _T.green),
    ];

    return _Section(
      padding: EdgeInsets.symmetric(
        horizontal: dk ? 80 : (nr ? 20 : 40),
        vertical: dk ? 120 : 80,
      ),
      child: Column(children: [
        _SectionTag('Решение'),
        SizedBox(height: dk ? 20 : 12),
        Text(
          'Не дистрибутор.\nСистема роста.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _T.hd, color: _T.text,
            fontSize: dk ? 48 : (nr ? 28 : 36),
            fontWeight: FontWeight.w700, height: 1.1,
            letterSpacing: dk ? -1.5 : -.5,
          ),
        ),
        SizedBox(height: dk ? 16 : 12),
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dk ? 560 : double.infinity),
          child: Text(
            'AURIX объединяет четыре модуля в одну систему. От загрузки трека до роста аудитории — каждый шаг продуман.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: dk ? 16 : 14, height: 1.6),
          ),
        ),

        SizedBox(height: dk ? 64 : 40),

        // System nodes
        if (dk)
          Row(
            children: [
              for (var i = 0; i < nodes.length; i++) ...[
                Expanded(child: _SystemNode(label: nodes[i].$1, desc: nodes[i].$2, icon: nodes[i].$3, color: nodes[i].$4)),
                if (i < nodes.length - 1) _ConnectorLine(),
              ],
            ],
          )
        else
          Column(children: [
            for (var i = 0; i < nodes.length; i++) ...[
              _SystemNode(label: nodes[i].$1, desc: nodes[i].$2, icon: nodes[i].$3, color: nodes[i].$4),
              if (i < nodes.length - 1) Container(width: 2, height: 32, color: _T.w(.06)),
            ],
          ]),
      ]),
    );
  }
}

class _SystemNode extends StatefulWidget {
  final String label, desc;
  final IconData icon;
  final Color color;
  const _SystemNode({required this.label, required this.desc, required this.icon, required this.color});
  @override
  State<_SystemNode> createState() => _SystemNodeState();
}

class _SystemNodeState extends State<_SystemNode> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedScale(
        scale: _h ? 1.06 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            color: _h ? widget.color.withValues(alpha: .06) : _T.glass,
            border: Border.all(color: _h ? widget.color.withValues(alpha: .2) : _T.border),
            boxShadow: _h ? [BoxShadow(color: widget.color.withValues(alpha: .08), blurRadius: 32, spreadRadius: -8)] : [],
          ),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(
            width: 52, height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(colors: [widget.color.withValues(alpha: .15), widget.color.withValues(alpha: .04)]),
            ),
            child: Icon(widget.icon, color: widget.color, size: 24),
          ),
          const SizedBox(height: 16),
          Text(widget.label, textAlign: TextAlign.center, style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 15, fontWeight: FontWeight.w600)),
          const SizedBox(height: 6),
          Text(widget.desc, textAlign: TextAlign.center, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 12, height: 1.4)),
        ]),
      ),
      ),
    );
  }
}

class _ConnectorLine extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: 32, height: 2,
      margin: const EdgeInsets.symmetric(horizontal: 4),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [_T.accent.withValues(alpha: .2), _T.purple.withValues(alpha: .2)]),
        borderRadius: BorderRadius.circular(1),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DISTRIBUTION — core feature, platform board
// ─────────────────────────────────────────────────────────────────────────────

class _DistributionSection extends StatefulWidget {
  const _DistributionSection();
  @override
  State<_DistributionSection> createState() => _DistributionSectionState();
}

class _DistributionSectionState extends State<_DistributionSection> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 3));

    if (_isDesktopView()) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    Widget textBlock() => Column(crossAxisAlignment: dk ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      _SectionTag('Дистрибуция'),
      SizedBox(height: dk ? 20 : 12),
      Text(
        'Один клик —\nвсе площадки',
        textAlign: dk ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          fontFamily: _T.hd, color: _T.text,
          fontSize: dk ? 44 : (nr ? 26 : 34),
          fontWeight: FontWeight.w700, height: 1.1,
          letterSpacing: dk ? -1.5 : -.5,
        ),
      ),
      SizedBox(height: dk ? 16 : 12),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dk ? 420 : double.infinity),
        child: Text(
          'Загрузи трек — и он появится на Spotify, Apple Music, YouTube Music, Яндекс Музыке, VK и ещё 15+ площадках. Без посредников. Отслеживай статус каждой площадки в реальном времени.',
          textAlign: dk ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: dk ? 15 : 14, height: 1.65),
        ),
      ),
      SizedBox(height: dk ? 28 : 20),

      // Feature pills
      Wrap(spacing: 10, runSpacing: 10, alignment: dk ? WrapAlignment.start : WrapAlignment.center, children: [
        _FeaturePill('20+ площадок', Icons.public_rounded, _T.accent),
        _FeaturePill('ISRC автоматически', Icons.qr_code_rounded, _T.green),
        _FeaturePill('Pre-save', Icons.schedule_rounded, _T.purple),
      ]),
    ]);

    Widget platformBoard() => AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: _T.card,
          border: Border.all(color: _T.accent.withValues(alpha: .1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 48, offset: const Offset(0, 16)),
            BoxShadow(color: _T.g(.04), blurRadius: 60, spreadRadius: -10),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Upload flow
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _T.accent.withValues(alpha: .04),
              border: Border.all(color: _T.accent.withValues(alpha: .1)),
            ),
            child: Row(children: [
              _FlowStep('Загрузка', Icons.cloud_upload_rounded, _T.green, true),
              Expanded(child: _AnimatedDots(t: _c.value, color: _T.green)),
              _FlowStep('Обработка', Icons.settings_rounded, _T.accent, _c.value > .3),
              Expanded(child: _AnimatedDots(t: _c.value, color: _T.accent)),
              _FlowStep('Live', Icons.check_circle_rounded, _T.green, _c.value > .7),
            ]),
          ),
          const SizedBox(height: 16),

          // Platform list
          _PlatformRow('Spotify', 'Live', _T.green, _c.value, 0),
          const SizedBox(height: 8),
          _PlatformRow('Apple Music', 'Live', _T.green, _c.value, 1),
          const SizedBox(height: 8),
          _PlatformRow('YouTube Music', 'Live', _T.green, _c.value, 2),
          const SizedBox(height: 8),
          _PlatformRow('Яндекс Музыка', 'Live', _T.green, _c.value, 3),
          const SizedBox(height: 8),
          _PlatformRow('VK Музыка', 'Обработка', _T.accent, _c.value, 4),
          const SizedBox(height: 8),
          _PlatformRow('Deezer', 'Live', _T.green, _c.value, 5),
          const SizedBox(height: 8),
          _PlatformRow('BOOM', 'Live', _T.green, _c.value, 6),

          const SizedBox(height: 12),
          Center(
            child: Text('+13 площадок', style: TextStyle(fontFamily: _T.bd, color: _T.dim, fontSize: 12, fontWeight: FontWeight.w500)),
          ),
        ]),
      ),
    );

    return _SectionGlow(
      color: _T.accent,
      child: _Section(
        padding: EdgeInsets.symmetric(
          horizontal: dk ? 80 : (nr ? 20 : 40),
          vertical: dk ? 120 : 80,
        ),
        child: dk
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: textBlock()),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: platformBoard()),
              ])
            : Column(children: [
                textBlock(),
                const SizedBox(height: 36),
                platformBoard(),
              ]),
      ),
    );
  }
}

class _FlowStep extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final bool active;
  const _FlowStep(this.label, this.icon, this.color, this.active);

  @override
  Widget build(BuildContext context) {
    return Column(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 36, height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? color.withValues(alpha: .15) : _T.glass,
          border: Border.all(color: active ? color.withValues(alpha: .3) : _T.border),
        ),
        child: Icon(icon, color: active ? color : _T.dim, size: 16),
      ),
      const SizedBox(height: 6),
      Text(label, style: TextStyle(fontFamily: _T.bd, color: active ? color : _T.dim, fontSize: 10, fontWeight: FontWeight.w600)),
    ]);
  }
}

class _AnimatedDots extends StatelessWidget {
  final double t;
  final Color color;
  const _AnimatedDots({required this.t, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisAlignment: MainAxisAlignment.center, children: [
      for (var i = 0; i < 3; i++)
        Container(
          width: 4, height: 4,
          margin: const EdgeInsets.symmetric(horizontal: 2),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: (.2 + .6 * math.sin(t * math.pi * 2 + i * 1.2)).clamp(0.0, 1.0)),
          ),
        ),
    ]);
  }
}

class _PlatformRow extends StatelessWidget {
  final String name, status;
  final Color color;
  final double t;
  final int index;
  const _PlatformRow(this.name, this.status, this.color, this.t, this.index);

  @override
  Widget build(BuildContext context) {
    final pulse = (.5 + .5 * math.sin(t * math.pi * 2 + index * 1.2)).clamp(0.0, 1.0);
    final icons = [Icons.music_note_rounded, Icons.apple_rounded, Icons.smart_display_rounded, Icons.graphic_eq_rounded, Icons.play_circle_rounded, Icons.album_rounded, Icons.audiotrack_rounded];
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _T.glass,
        border: Border.all(color: _T.border),
      ),
      child: Row(children: [
        Icon(icons[index % icons.length], color: _T.sub, size: 16),
        const SizedBox(width: 10),
        Expanded(child: Text(name, style: TextStyle(fontFamily: _T.bd, color: _T.text, fontSize: 13, fontWeight: FontWeight.w500))),
        Container(
          width: 6, height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: color.withValues(alpha: .5 + .5 * pulse),
            boxShadow: [BoxShadow(color: color.withValues(alpha: .3 * pulse), blurRadius: 6)],
          ),
        ),
        const SizedBox(width: 8),
        Text(status, style: TextStyle(fontFamily: _T.bd, color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _FeaturePill(this.label, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: color.withValues(alpha: .06),
        border: Border.all(color: color.withValues(alpha: .12)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, color: color, size: 14),
        const SizedBox(width: 8),
        Text(label, style: TextStyle(fontFamily: _T.bd, color: color, fontSize: 12, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// AI STUDIO — chat mock with typing
// ─────────────────────────────────────────────────────────────────────────────

class _AIStudioSection extends StatefulWidget {
  const _AIStudioSection();
  @override
  State<_AIStudioSection> createState() => _AIStudioSectionState();
}

class _AIStudioSectionState extends State<_AIStudioSection> with SingleTickerProviderStateMixin {
  // Multi-phase analysis
  static const _phases = [
    ('Сканирование аудио...', 'Загрузка WAV · 48kHz · Stereo', 1800),
    ('Анализ структуры', 'BPM: 128 · Тональность: Am · Drop на 0:42', 2200),
    ('Определение хуков', 'Хук на 0:14 — 94% потенциал для Reels', 2000),
    ('Генерация стратегии', 'Pre-save за 5 дней · Stories промо · TikTok с хуком 0:14–0:22', 2500),
  ];
  int _phase = -1;
  double _progress = 0;
  Timer? _timer;
  bool _started = false;
  late final AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(vsync: this, duration: const Duration(milliseconds: 1500));

    if (_isDesktopView()) _pulse.repeat(reverse: true);
  }

  void _startAnalysis() {
    if (_started) return;
    _started = true;
    _advancePhase();
  }

  void _advancePhase() {
    if (_phase >= _phases.length - 1) return;
    setState(() { _phase++; _progress = 0; });
    final dur = _phases[_phase].$3;
    final steps = 30;
    var step = 0;
    _timer?.cancel();
    _timer = Timer.periodic(Duration(milliseconds: dur ~/ steps), (_) {
      step++;
      if (step >= steps) {
        setState(() => _progress = 1.0);
        _timer?.cancel();
        if (_phase < _phases.length - 1) {
          Future.delayed(const Duration(milliseconds: 400), () { if (mounted) _advancePhase(); });
        }
      } else {
        setState(() => _progress = step / steps);
      }
    });
  }

  @override
  void dispose() { _timer?.cancel(); _pulse.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    if (!_started) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!_started && mounted) {
          final ro = context.findRenderObject();
          if (ro is RenderBox && ro.hasSize) {
            final top = ro.localToGlobal(Offset.zero).dy;
            if (top < MediaQuery.sizeOf(context).height * .95) _startAnalysis();
          }
        }
      });
    }

    Widget textBlock() => Column(crossAxisAlignment: dk ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      _SectionTag('AI Студия'),
      SizedBox(height: dk ? 20 : 12),
      Text(
        'AI, который\nпонимает музыку',
        textAlign: dk ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          fontFamily: _T.hd, color: _T.text,
          fontSize: dk ? 44 : (nr ? 26 : 34),
          fontWeight: FontWeight.w700, height: 1.1,
          letterSpacing: dk ? -1.5 : -.5,
        ),
      ),
      SizedBox(height: dk ? 16 : 12),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dk ? 420 : double.infinity),
        child: Text(
          'Загрузи трек — AI разберёт структуру, определит хуки, подберёт стратегию продвижения и создаст контент-план. Персональная стратегия для каждого релиза.',
          textAlign: dk ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: dk ? 15 : 14, height: 1.65),
        ),
      ),
      SizedBox(height: dk ? 28 : 20),
      Wrap(spacing: 10, runSpacing: 10, alignment: dk ? WrapAlignment.start : WrapAlignment.center, children: [
        _FeaturePill('Анализ трека', Icons.equalizer_rounded, _T.purple),
        _FeaturePill('Генерация обложек', Icons.image_rounded, _T.purple),
        _FeaturePill('Контент-план', Icons.calendar_month_rounded, _T.purple),
      ]),
    ]);

    Widget analysisMock() => AnimatedBuilder(
      animation: _pulse,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: _T.card,
          border: Border.all(color: _T.purple.withValues(alpha: .1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 48, offset: const Offset(0, 16)),
            BoxShadow(color: _T.purple.withValues(alpha: .04), blurRadius: 60, spreadRadius: -10),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: _T.bg,
              border: Border.all(color: _T.border),
            ),
            child: Row(children: [
              Container(width: 6, height: 6, decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: _phase >= 0 ? _T.green : _T.dim,
                boxShadow: _phase >= 0 ? [BoxShadow(color: _T.green.withValues(alpha: .5), blurRadius: 6)] : [],
              )),
              const SizedBox(width: 8),
              Text('AURIX AI', style: TextStyle(fontFamily: _T.hd, color: _T.purple, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const Spacer(),
              if (_phase >= 0 && _phase < _phases.length - 1 || (_phase == _phases.length - 1 && _progress < 1))
                Text('анализирует...', style: TextStyle(fontFamily: _T.bd, color: _T.purple.withValues(alpha: .4 + .3 * _pulse.value), fontSize: 10)),
              if (_phase == _phases.length - 1 && _progress >= 1)
                Text('готово', style: TextStyle(fontFamily: _T.bd, color: _T.green, fontSize: 10, fontWeight: FontWeight.w600)),
            ]),
          ),
          const SizedBox(height: 14),

          // User message
          Align(
            alignment: Alignment.centerRight,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: _T.accent.withValues(alpha: .1),
                border: Border.all(color: _T.accent.withValues(alpha: .12)),
              ),
              child: Text('Проанализируй мой новый трек', style: TextStyle(fontFamily: _T.bd, color: _T.accent, fontSize: 13)),
            ),
          ),
          const SizedBox(height: 14),

          // Multi-phase analysis steps
          for (var i = 0; i <= _phase && i < _phases.length; i++) ...[
            _AnalysisStep(
              title: _phases[i].$1,
              detail: _phases[i].$2,
              progress: i < _phase ? 1.0 : _progress,
              isActive: i == _phase,
              isDone: i < _phase || (i == _phase && _progress >= 1),
              pulseValue: _pulse.value,
            ),
            if (i < _phase || (i == _phase && i < _phases.length - 1)) const SizedBox(height: 10),
          ],

          // Quick actions after all phases done
          if (_phase == _phases.length - 1 && _progress >= 1) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                color: _T.green.withValues(alpha: .04),
                border: Border.all(color: _T.green.withValues(alpha: .12)),
              ),
              child: Row(children: [
                Icon(Icons.check_circle_rounded, color: _T.green, size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text('Анализ завершён · Confidence: 94%', style: TextStyle(fontFamily: _T.bd, color: _T.green, fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            ),
            const SizedBox(height: 12),
            Wrap(spacing: 8, runSpacing: 8, children: [
              _QuickAction('Сгенерировать обложку', Icons.image_rounded, _T.purple),
              _QuickAction('Запустить промо', Icons.rocket_launch_rounded, _T.accent),
              _QuickAction('Контент-план', Icons.calendar_month_rounded, _T.green),
            ]),
          ],
        ]),
      ),
    );

    return _SectionGlow(
      color: _T.purple,
      child: _Section(
        padding: EdgeInsets.symmetric(
          horizontal: dk ? 80 : (nr ? 20 : 40),
          vertical: dk ? 120 : 80,
        ),
        child: dk
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: analysisMock()),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: textBlock()),
              ])
            : Column(children: [
                textBlock(),
                const SizedBox(height: 36),
                analysisMock(),
              ]),
      ),
    );
  }
}

// ── Analysis step widget ──

class _AnalysisStep extends StatelessWidget {
  final String title, detail;
  final double progress, pulseValue;
  final bool isActive, isDone;
  const _AnalysisStep({required this.title, required this.detail, required this.progress, required this.isActive, required this.isDone, required this.pulseValue});

  @override
  Widget build(BuildContext context) {
    final color = isDone ? _T.green : _T.purple;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: isActive ? _T.purple.withValues(alpha: .04 + .02 * pulseValue) : _T.glass,
        border: Border.all(color: isActive ? _T.purple.withValues(alpha: .15) : _T.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(
            isDone ? Icons.check_circle_rounded : Icons.circle_outlined,
            color: color,
            size: 14,
          ),
          const SizedBox(width: 8),
          Expanded(child: Text(title, style: TextStyle(fontFamily: _T.hd, color: isDone ? _T.green : _T.text, fontSize: 12, fontWeight: FontWeight.w600))),
          if (isActive && !isDone)
            Text('${(progress * 100).toInt()}%', style: TextStyle(fontFamily: _T.hd, color: _T.purple, fontSize: 11, fontWeight: FontWeight.w700)),
        ]),
        if (progress > .1) ...[
          const SizedBox(height: 6),
          // Progress bar
          Container(
            height: 3,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: _T.w(.04)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progress.clamp(0, 1),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(2),
                  color: color,
                  boxShadow: isActive ? [BoxShadow(color: color.withValues(alpha: .4), blurRadius: 6)] : [],
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(detail, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 11, height: 1.4)),
        ],
      ]),
    );
  }
}

class _QuickAction extends StatefulWidget {
  final String label;
  final IconData icon;
  final Color color;
  const _QuickAction(this.label, this.icon, this.color);
  @override
  State<_QuickAction> createState() => _QuickActionState();
}

class _QuickActionState extends State<_QuickAction> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          color: widget.color.withValues(alpha: _h ? .12 : .06),
          border: Border.all(color: widget.color.withValues(alpha: _h ? .25 : .1)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(widget.icon, color: widget.color, size: 13),
          const SizedBox(width: 6),
          Text(widget.label, style: TextStyle(fontFamily: _T.bd, color: widget.color, fontSize: 12, fontWeight: FontWeight.w600)),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// ANALYTICS — charts and growth
// ─────────────────────────────────────────────────────────────────────────────

class _AnalyticsSection extends StatefulWidget {
  const _AnalyticsSection();
  @override
  State<_AnalyticsSection> createState() => _AnalyticsSectionState();
}

class _AnalyticsSectionState extends State<_AnalyticsSection> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(seconds: 5));

    if (_isDesktopView()) _c.repeat();
  }
  @override
  void dispose() { _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    Widget textBlock() => Column(crossAxisAlignment: dk ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      _SectionTag('Аналитика'),
      SizedBox(height: dk ? 20 : 12),
      Text(
        'Каждый стрим\nна виду',
        textAlign: dk ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          fontFamily: _T.hd, color: _T.text,
          fontSize: dk ? 44 : (nr ? 26 : 34),
          fontWeight: FontWeight.w700, height: 1.1,
          letterSpacing: dk ? -1.5 : -.5,
        ),
      ),
      SizedBox(height: dk ? 16 : 12),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dk ? 420 : double.infinity),
        child: Text(
          'Стримы, доход, география, динамика роста — всё в одном дашборде. В реальном времени. Принимай решения на основе данных, а не интуиции.',
          textAlign: dk ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: dk ? 15 : 14, height: 1.65),
        ),
      ),
      SizedBox(height: dk ? 28 : 20),
      Wrap(spacing: 10, runSpacing: 10, alignment: dk ? WrapAlignment.start : WrapAlignment.center, children: [
        _FeaturePill('Real-time', Icons.bolt_rounded, _T.blue),
        _FeaturePill('По площадкам', Icons.bar_chart_rounded, _T.blue),
        _FeaturePill('Динамика', Icons.show_chart_rounded, _T.green),
      ]),
    ]);

    Widget chartPanel() => AnimatedBuilder(
      animation: _c,
      builder: (_, __) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(24),
          color: _T.card,
          border: Border.all(color: _T.blue.withValues(alpha: .1)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: .5), blurRadius: 48, offset: const Offset(0, 16)),
            BoxShadow(color: _T.blue.withValues(alpha: .04), blurRadius: 60, spreadRadius: -10),
          ],
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PanelChrome(title: 'Аналитика', live: true),
          const SizedBox(height: 16),

          // Main chart
          Container(
            height: 120,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _T.bg,
              border: Border.all(color: _T.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                painter: _MiniChartPainter(t: _c.value, color: _T.blue),
                size: const Size(double.infinity, double.infinity),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Platform bars
          _BarRow('Spotify', .78 + _c.value * .05, '12.4K', _T.green),
          const SizedBox(height: 10),
          _BarRow('Apple Music', .52 + _c.value * .03, '6.1K', _T.blue),
          const SizedBox(height: 10),
          _BarRow('Яндекс Музыка', .65 + _c.value * .04, '8.8K', _T.accent),
          const SizedBox(height: 10),
          _BarRow('YouTube Music', .38 + _c.value * .02, '4.2K', _T.purple),
          const SizedBox(height: 16),

          // Stats — dynamic
          Row(children: [
            Expanded(child: _MiniStat('Всего', '${(30.5 + _c.value * 1.2).toStringAsFixed(1)}K', '+${(18 + _c.value * 2).toStringAsFixed(0)}%', _T.green)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Доход', '₽${(22.1 + _c.value * .8).toStringAsFixed(1)}K', '+${(12 + _c.value * 1.5).toStringAsFixed(0)}%', _T.accent)),
            const SizedBox(width: 8),
            Expanded(child: _MiniStat('Охват', '${(24.1 + _c.value * 1.5).toStringAsFixed(1)}K', '+${(34 + _c.value * 3).toStringAsFixed(0)}%', _T.blue)),
          ]),
        ]),
      ),
    );

    return _SectionGlow(
      color: _T.blue,
      child: _Section(
        padding: EdgeInsets.symmetric(
          horizontal: dk ? 80 : (nr ? 20 : 40),
          vertical: dk ? 120 : 80,
        ),
        child: dk
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: textBlock()),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: chartPanel()),
              ])
            : Column(children: [
                textBlock(),
                const SizedBox(height: 36),
                chartPanel(),
              ]),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final String label, value, trend;
  final Color trendColor;
  const _MiniStat(this.label, this.value, this.trend, this.trendColor);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        color: _T.glass,
        border: Border.all(color: _T.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(label, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 10)),
        const SizedBox(height: 3),
        Text(value, style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 14, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(trend, style: TextStyle(fontFamily: _T.hd, color: trendColor, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

class _BarRow extends StatelessWidget {
  final String label;
  final double fraction;
  final String value;
  final Color color;
  const _BarRow(this.label, this.fraction, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [
        Text(label, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 12, fontWeight: FontWeight.w500)),
        const Spacer(),
        Text(value, style: TextStyle(fontFamily: _T.hd, color: _T.sub, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
      const SizedBox(height: 6),
      Container(
        height: 6,
        decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: _T.w(.04)),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: fraction.clamp(0, 1),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(3),
              color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: .3), blurRadius: 8)],
            ),
          ),
        ),
      ),
    ]);
  }
}

class _MiniChartPainter extends CustomPainter {
  final double t;
  final Color color;
  _MiniChartPainter({required this.t, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final pts = [.22, .35, .28, .48, .42, .58, .52, .70, .64, .82, .75, .88 + t * .08];
    final path = Path();
    final dotPositions = <Offset>[];
    for (var i = 0; i < pts.length; i++) {
      final x = (i / (pts.length - 1)) * size.width;
      final y = size.height - pts[i] * size.height * .8 - 4;
      dotPositions.add(Offset(x, y));
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        final px = ((i - 1) / (pts.length - 1)) * size.width;
        final py = size.height - pts[i - 1] * size.height * .8 - 4;
        path.cubicTo((px + x) / 2, py, (px + x) / 2, y, x, y);
      }
    }
    canvas.drawPath(path, Paint()..color = color.withValues(alpha: .6)..strokeWidth = 2..style = PaintingStyle.stroke);
    final fp = Path.from(path)..lineTo(size.width, size.height)..lineTo(0, size.height)..close();
    canvas.drawPath(fp, Paint()..shader = LinearGradient(
      begin: Alignment.topCenter, end: Alignment.bottomCenter,
      colors: [color.withValues(alpha: .12), Colors.transparent],
    ).createShader(Rect.fromLTWH(0, 0, size.width, size.height)));

    // Pulsing data points
    final pulse = (.5 + .5 * math.sin(t * math.pi * 6)).clamp(0.0, 1.0);
    for (var i = 0; i < dotPositions.length; i++) {
      final isLast = i == dotPositions.length - 1;
      final r = isLast ? 4.5 : 2.5;
      final a = isLast ? (.6 + .4 * pulse) : .3;
      canvas.drawCircle(dotPositions[i], r, Paint()..color = color.withValues(alpha: a));
      if (isLast) {
        // Glow ring on last point
        canvas.drawCircle(dotPositions[i], r + 4 * pulse, Paint()..color = color.withValues(alpha: .15 * pulse)..style = PaintingStyle.stroke..strokeWidth = 2);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _MiniChartPainter old) => (old.t - t).abs() > .01;
}

// ─────────────────────────────────────────────────────────────────────────────
// PROMO SECTION — content ideas
// ─────────────────────────────────────────────────────────────────────────────

class _PromoSection extends StatelessWidget {
  const _PromoSection();

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    Widget textBlock() => Column(crossAxisAlignment: dk ? CrossAxisAlignment.start : CrossAxisAlignment.center, children: [
      _SectionTag('Промо'),
      SizedBox(height: dk ? 20 : 12),
      Text(
        'Превращай релиз\nв событие',
        textAlign: dk ? TextAlign.left : TextAlign.center,
        style: TextStyle(
          fontFamily: _T.hd, color: _T.text,
          fontSize: dk ? 44 : (nr ? 26 : 34),
          fontWeight: FontWeight.w700, height: 1.1,
          letterSpacing: dk ? -1.5 : -.5,
        ),
      ),
      SizedBox(height: dk ? 16 : 12),
      ConstrainedBox(
        constraints: BoxConstraints(maxWidth: dk ? 420 : double.infinity),
        child: Text(
          'Готовые идеи для контента. AI создаёт контент-план, подбирает форматы для Reels, TikTok, Stories. Ты просто запускаешь.',
          textAlign: dk ? TextAlign.left : TextAlign.center,
          style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: dk ? 15 : 14, height: 1.65),
        ),
      ),
    ]);

    Widget contentCards() => Column(children: [
      _ContentCard(
        title: 'Reels с хуком',
        desc: '15-секундный ролик с самым сильным моментом трека. AI определит хук автоматически.',
        icon: Icons.video_camera_back_rounded,
        badge: 'REELS',
        color: _T.accent,
      ),
      const SizedBox(height: 12),
      _ContentCard(
        title: 'TikTok челлендж',
        desc: 'Идея для вирального формата на основе ритма и настроения трека.',
        icon: Icons.music_video_rounded,
        badge: 'TIKTOK',
        color: _T.purple,
      ),
      const SizedBox(height: 12),
      _ContentCard(
        title: 'Stories промо',
        desc: 'Серия Stories за 5 дней до релиза. Тизеры, обратный отсчёт, pre-save.',
        icon: Icons.amp_stories_rounded,
        badge: 'STORIES',
        color: _T.green,
      ),
      const SizedBox(height: 12),
      _ContentCard(
        title: 'Коллаборация',
        desc: 'Подбор артистов в смежном жанре для кросс-промо и расширения аудитории.',
        icon: Icons.people_rounded,
        badge: 'COLLAB',
        color: _T.blue,
      ),
    ]);

    return _SectionGlow(
      color: _T.accent,
      child: _Section(
        padding: EdgeInsets.symmetric(
          horizontal: dk ? 80 : (nr ? 20 : 40),
          vertical: dk ? 120 : 80,
        ),
        child: dk
            ? Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
                Expanded(flex: 5, child: contentCards()),
                const SizedBox(width: 48),
                Expanded(flex: 5, child: textBlock()),
              ])
            : Column(children: [
                textBlock(),
                const SizedBox(height: 36),
                contentCards(),
              ]),
      ),
    );
  }
}

class _ContentCard extends StatefulWidget {
  final String title, desc, badge;
  final IconData icon;
  final Color color;
  const _ContentCard({required this.title, required this.desc, required this.badge, required this.icon, required this.color});
  @override
  State<_ContentCard> createState() => _ContentCardState();
}

class _ContentCardState extends State<_ContentCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedScale(
        scale: _h ? 1.02 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            color: _h ? _T.cardHi : _T.card,
            border: Border.all(color: _h ? widget.color.withValues(alpha: .2) : _T.border),
            boxShadow: _h ? [BoxShadow(color: widget.color.withValues(alpha: .06), blurRadius: 32, spreadRadius: -8)] : [],
          ),
        child: Row(children: [
          Container(
            width: 48, height: 48,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(colors: [widget.color.withValues(alpha: .12), widget.color.withValues(alpha: .04)]),
            ),
            child: Icon(widget.icon, color: widget.color, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(child: Text(widget.title, style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 14, fontWeight: FontWeight.w600))),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(6),
                  color: widget.color.withValues(alpha: .08),
                ),
                child: Text(widget.badge, style: TextStyle(fontFamily: _T.hd, color: widget.color, fontSize: 9, fontWeight: FontWeight.w700, letterSpacing: 1)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(widget.desc, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 12, height: 1.5)),
          ])),
        ]),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// HOW IT WORKS — 3 steps
// ─────────────────────────────────────────────────────────────────────────────

class _HowItWorksSection extends StatelessWidget {
  const _HowItWorksSection();

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    const steps = [
      ('01', 'Загрузи', 'Добавь трек, обложку и метаданные. Всё через простой интерфейс за 5 минут.', Icons.cloud_upload_rounded, _T.accent),
      ('02', 'Запускай', 'AI анализирует трек, дистрибуция стартует на все площадки, стратегия готова.', Icons.auto_awesome_rounded, _T.purple),
      ('03', 'Расти', 'Отслеживай стримы, продвигай по плану, масштабируй успех каждого релиза.', Icons.trending_up_rounded, _T.green),
    ];

    return _Section(
      padding: EdgeInsets.symmetric(
        horizontal: dk ? 80 : (nr ? 20 : 40),
        vertical: dk ? 120 : 80,
      ),
      child: Column(children: [
        _SectionTag('Как это работает'),
        SizedBox(height: dk ? 20 : 12),
        Text(
          'Три шага к росту',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _T.hd, color: _T.text,
            fontSize: dk ? 48 : (nr ? 28 : 36),
            fontWeight: FontWeight.w700, height: 1.1,
            letterSpacing: dk ? -1.5 : -.5,
          ),
        ),

        SizedBox(height: dk ? 64 : 40),

        if (dk)
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (var i = 0; i < steps.length; i++) ...[
              Expanded(child: _StepCard(
                num: steps[i].$1, title: steps[i].$2, desc: steps[i].$3,
                icon: steps[i].$4, color: steps[i].$5,
              )),
              if (i < steps.length - 1)
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: Container(
                    width: 40, height: 2,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [steps[i].$5.withValues(alpha: .3), steps[i + 1].$5.withValues(alpha: .3)]),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                ),
            ],
          ])
        else
          Column(children: [
            for (var i = 0; i < steps.length; i++) ...[
              _StepCard(num: steps[i].$1, title: steps[i].$2, desc: steps[i].$3, icon: steps[i].$4, color: steps[i].$5),
              if (i < steps.length - 1) Container(width: 2, height: 32, color: _T.w(.06)),
            ],
          ]),
      ]),
    );
  }
}

class _StepCard extends StatefulWidget {
  final String num, title, desc;
  final IconData icon;
  final Color color;
  const _StepCard({required this.num, required this.title, required this.desc, required this.icon, required this.color});
  @override
  State<_StepCard> createState() => _StepCardState();
}

class _StepCardState extends State<_StepCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedScale(
        scale: _h ? 1.04 : 1.0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: _h ? widget.color.withValues(alpha: .04) : _T.glass,
            border: Border.all(color: _h ? widget.color.withValues(alpha: .2) : _T.border),
            boxShadow: _h ? [BoxShadow(color: widget.color.withValues(alpha: .08), blurRadius: 32, spreadRadius: -8)] : [],
          ),
        child: Column(children: [
          // Step number
          Text(widget.num, style: TextStyle(fontFamily: _T.hd, color: widget.color.withValues(alpha: .25), fontSize: 48, fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Container(
            width: 56, height: 56,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              gradient: LinearGradient(colors: [widget.color.withValues(alpha: .15), widget.color.withValues(alpha: .04)]),
            ),
            child: Icon(widget.icon, color: widget.color, size: 26),
          ),
          const SizedBox(height: 20),
          Text(widget.title, textAlign: TextAlign.center, style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text(widget.desc, textAlign: TextAlign.center, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 13, height: 1.5)),
        ]),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// DEVICE SHOWCASE — iPhone + Web animated mockups with 3D perspective
// ─────────────────────────────────────────────────────────────────────────────

class _DeviceShowcase extends StatefulWidget {
  const _DeviceShowcase();
  @override
  State<_DeviceShowcase> createState() => _DeviceShowcaseState();
}

class _DeviceShowcaseState extends State<_DeviceShowcase> with TickerProviderStateMixin {
  late final AnimationController _anim;   // continuous 8s loop for live data
  late final AnimationController _fade;   // crossfade between screens
  int _page = 0;
  int _prevPage = 0;
  Timer? _timer;

  // Real AURIX feature names
  static const _screens = [
    _SD('Релизы',       'Дистрибуция на 50+ площадок',          _T.accent, Icons.album_rounded),
    _SD('Aurix AI',     'AI-продюсер для каждого трека',        _T.purple, Icons.auto_awesome_rounded),
    _SD('Студия',       'Запись и обработка в браузере',         _T.cyan,   Icons.headphones_rounded),
    _SD('Статистика',   'Аналитика стримов в реальном времени', _T.green,  Icons.insights_rounded),
    _SD('Aurix DNK',    'Глубинный анализ стиля артиста',       _T.blue,   Icons.fingerprint_rounded),
  ];

  bool _isMobile = false;

  @override
  void initState() {
    super.initState();
    // Slow loop for live numbers — desktop 8s, mobile 20s (less repaints)
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 20));

    if (_isDesktopView()) _anim.repeat();
    _fade = AnimationController(vsync: this, duration: const Duration(milliseconds: 500))
      ..value = 1.0;
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _next());
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final mobile = MediaQuery.sizeOf(context).width < 1024;
    if (mobile != _isMobile) {
      _isMobile = mobile;
      // On mobile: slow down to 20s, on desktop: speed up to 8s
      _anim.duration = Duration(seconds: mobile ? 20 : 8);
    }
  }

  void _next() {
    if (!mounted) return;
    _fade.reverse().then((_) {
      if (!mounted) return;
      setState(() { _prevPage = _page; _page = (_page + 1) % _screens.length; });
      _fade.forward();
    });
  }

  void _goTo(int i) {
    if (i == _page || !mounted) return;
    _timer?.cancel();
    _fade.reverse().then((_) {
      if (!mounted) return;
      setState(() { _prevPage = _page; _page = i; });
      _fade.forward();
    });
    _timer = Timer.periodic(const Duration(seconds: 5), (_) => _next());
  }

  @override
  void dispose() { _timer?.cancel(); _anim.dispose(); _fade.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);
    final s = _screens[_page];

    return _SectionGlow(
      color: s.color,
      child: _Section(
        padding: EdgeInsets.symmetric(
          horizontal: dk ? 60 : (nr ? 16 : 32),
          vertical: dk ? 100 : 60,
        ),
        child: Column(children: [
          _SectionTag('Платформа'),
          SizedBox(height: dk ? 20 : 12),
          Text(
            'Всё для артиста. Одна система.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _T.hd, color: _T.text,
              fontSize: dk ? 44 : (nr ? 24 : 32),
              fontWeight: FontWeight.w700, height: 1.1,
              letterSpacing: dk ? -1.5 : -.5,
            ),
          ),
          SizedBox(height: dk ? 40 : 24),

          // ── Feature tabs ──
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              for (int i = 0; i < _screens.length; i++) ...[
                if (i > 0) const SizedBox(width: 6),
                _featureTab(i, _screens[i]),
              ],
            ]),
          ),
          SizedBox(height: dk ? 48 : 28),

          // ── Devices ──
          AnimatedBuilder(
            animation: Listenable.merge([_anim, _fade]),
            builder: (_, __) {
              final opacity = _fade.value.clamp(0.0, 1.0);
              final slide = (1 - _fade.value) * 20;
              final scale = .94 + _fade.value * .06;
              return Opacity(
                opacity: opacity,
                child: Transform.translate(
                  offset: Offset(0, slide),
                  child: Transform.scale(
                    scale: scale,
                    child: dk
                      ? _desktopLayout(s, _anim.value)
                      : _mobileLayout(s, _anim.value, nr),
                  ),
                ),
              );
            },
          ),
        ]),
      ),
    );
  }

  // ── Feature tab button ──
  Widget _featureTab(int i, _SD s) {
    final active = _page == i;
    return GestureDetector(
      onTap: () => _goTo(i),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: EdgeInsets.symmetric(horizontal: active ? 20 : 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: active ? s.color.withValues(alpha: .12) : _T.w(.03),
          border: Border.all(color: active ? s.color.withValues(alpha: .3) : _T.w(.06)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(s.icon, size: 14, color: active ? s.color : _T.muted),
          const SizedBox(width: 8),
          Text(s.title, style: TextStyle(
            fontFamily: _T.hd, fontSize: 12, fontWeight: FontWeight.w600,
            color: active ? s.color : _T.muted)),
        ]),
      ),
    );
  }

  // ── Desktop: iPhone left, Web right, spaced apart ──
  Widget _desktopLayout(_SD s, double t) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1000),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // iPhone — slight 3D perspective tilt
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(0.06),
            child: _iPhoneFrame(s, 260, 520, t),
          ),
          const SizedBox(width: 40),
          // Web browser
          Transform(
            alignment: Alignment.center,
            transform: Matrix4.identity()
              ..setEntry(3, 2, 0.001)
              ..rotateY(-0.03),
            child: _webFrame(s, 580, 400, t),
          ),
        ],
      ),
    );
  }

  // ── Mobile: just iPhone centered ──
  Widget _mobileLayout(_SD s, double t, bool nr) {
    return Center(child: _iPhoneFrame(s, nr ? 240 : 280, nr ? 480 : 560, t));
  }

  // ── iPhone Frame ──
  Widget _iPhoneFrame(_SD s, double w, double h, double t) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(40),
        color: const Color(0xFF0A0A0F),
        border: Border.all(color: _T.w(.1), width: 3),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .7), blurRadius: 50, offset: const Offset(0, 20)),
          BoxShadow(color: s.color.withValues(alpha: .1), blurRadius: 80, spreadRadius: -10),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(37),
        child: Stack(children: [
          Positioned.fill(child: _screenContent(s, t, true)),
          // Dynamic Island
          Positioned(top: 10, left: 0, right: 0,
            child: Center(child: Container(
              width: 90, height: 26,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(20), color: Colors.black),
            ))),
          // Status bar
          Positioned(top: 14, left: 28, right: 28,
            child: Row(children: [
              Text('9:41', style: TextStyle(fontFamily: _T.hd, fontSize: 10, fontWeight: FontWeight.w600, color: Colors.white)),
              const Spacer(),
              Icon(Icons.signal_cellular_alt, size: 10, color: _T.w(.7)),
              const SizedBox(width: 3),
              Icon(Icons.wifi, size: 10, color: _T.w(.7)),
              const SizedBox(width: 3),
              Icon(Icons.battery_full, size: 10, color: _T.w(.7)),
            ])),
          // Home indicator
          Positioned(bottom: 6, left: 0, right: 0,
            child: Center(child: Container(
              width: 100, height: 4,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: _T.w(.2)),
            ))),
        ]),
      ),
    );
  }

  // ── Web Browser Frame ──
  Widget _webFrame(_SD s, double w, double h, double t) {
    return Container(
      width: w, height: h,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFF0A0A0F),
        border: Border.all(color: _T.w(.08), width: 2),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: .6), blurRadius: 60, offset: const Offset(0, 24)),
          BoxShadow(color: s.color.withValues(alpha: .08), blurRadius: 100, spreadRadius: -20),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Column(children: [
          // Chrome bar
          Container(
            height: 34,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(color: _T.bg2, border: Border(bottom: BorderSide(color: _T.w(.06)))),
            child: Row(children: [
              for (final c in [const Color(0xFFFF5F57), const Color(0xFFFFBD2E), const Color(0xFF28CA41)]) ...[
                Container(width: 9, height: 9, decoration: BoxDecoration(shape: BoxShape.circle, color: c.withValues(alpha: .7))),
                const SizedBox(width: 5),
              ],
              const SizedBox(width: 10),
              Expanded(child: Container(
                height: 20,
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(5),
                  color: _T.w(.04), border: Border.all(color: _T.w(.06))),
                child: Row(children: [
                  Icon(Icons.lock_rounded, size: 9, color: _T.green.withValues(alpha: .6)),
                  const SizedBox(width: 5),
                  Text('aurixmusic.ru', style: TextStyle(fontFamily: _T.bd, fontSize: 9, color: _T.muted)),
                ]),
              )),
              const SizedBox(width: 30),
            ]),
          ),
          Expanded(child: _screenContent(s, t, false)),
        ]),
      ),
    );
  }

  // ── Animated screen content ──
  Widget _screenContent(_SD s, double t, bool isPhone) {
    return Container(
      color: _T.bg,
      child: switch (s.title) {
        'Релизы'     => _screenReleases(s, t, isPhone),
        'Aurix AI'   => _screenAI(s, t, isPhone),
        'Студия'     => _screenStudio(s, t, isPhone),
        'Статистика' => _screenStats(s, t, isPhone),
        _            => _screenDNK(s, t, isPhone),
      },
    );
  }

  // ── Screen: Релизы ──
  Widget _screenReleases(_SD s, double t, bool isPhone) {
    final platforms = ['Spotify', 'Apple Music', 'Яндекс Музыка', 'VK Музыка', 'YouTube Music'];
    final statuses  = ['Live', 'Live', 'Live', 'Обработка', 'Черновик'];
    final colors    = [_T.green, _T.green, _T.green, _T.accent, _T.muted];
    return Padding(
      padding: EdgeInsets.only(top: isPhone ? 50 : 10, left: 12, right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(s, isPhone),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10), color: s.color.withValues(alpha: .06),
            border: Border.all(color: s.color.withValues(alpha: .12))),
          child: Row(children: [
            Container(width: 36, height: 36, decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
              color: s.color.withValues(alpha: .1)),
              child: Icon(Icons.cloud_upload_rounded, size: 18, color: s.color)),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('Новый релиз', style: TextStyle(fontFamily: _T.hd, fontSize: 10, fontWeight: FontWeight.w700, color: _T.text)),
              const SizedBox(height: 3),
              ClipRRect(borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(value: ((t * 2) % 1.0), minHeight: 3,
                  backgroundColor: _T.w(.06), valueColor: AlwaysStoppedAnimation(s.color))),
            ])),
          ]),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < (isPhone ? 5 : 4); i++) ...[
          _plRow(platforms[i], statuses[i], colors[i], t, i),
          if (i < 4) const SizedBox(height: 4),
        ],
      ]),
    );
  }

  Widget _plRow(String n, String st, Color c, double t, int i) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: _T.w(.02), border: Border.all(color: _T.w(.04))),
      child: Row(children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(shape: BoxShape.circle, color: c,
          boxShadow: [BoxShadow(color: c.withValues(alpha: ((t + i * .15) % 1 > .5) ? .5 : .15), blurRadius: 4)])),
        const SizedBox(width: 8),
        Expanded(child: Text(n, style: TextStyle(fontFamily: _T.bd, fontSize: 10, color: _T.text))),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(4), color: c.withValues(alpha: .08)),
          child: Text(st, style: TextStyle(fontFamily: _T.hd, fontSize: 7, fontWeight: FontWeight.w700, color: c))),
      ]),
    );
  }

  // ── Screen: Aurix AI ──
  Widget _screenAI(_SD s, double t, bool isPhone) {
    return Padding(
      padding: EdgeInsets.only(top: isPhone ? 50 : 10, left: 12, right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(s, isPhone),
        const SizedBox(height: 12),
        _bubble('Проанализируй мой новый трек', true, s),
        const SizedBox(height: 6),
        _bubble('Анализирую структуру, BPM, частоты...', false, s),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [s.color.withValues(alpha: .08), _T.card]),
            border: Border.all(color: s.color.withValues(alpha: .15))),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Icon(Icons.auto_awesome, size: 11, color: s.color),
              const SizedBox(width: 5),
              Text('AI Score', style: TextStyle(fontFamily: _T.hd, fontSize: 9, fontWeight: FontWeight.w700, color: s.color)),
              const Spacer(),
              Text('${(72 + t * 10).toInt()}/100', style: TextStyle(fontFamily: _T.hd, fontSize: 13, fontWeight: FontWeight.w700, color: _T.text)),
            ]),
            const SizedBox(height: 8),
            _bar('Хук', .82 + t * .05, _T.accent),
            const SizedBox(height: 4),
            _bar('Энергия', .65 + t * .08, _T.green),
            const SizedBox(height: 4),
            _bar('Оригинальность', .73, _T.blue),
          ]),
        ),
      ]),
    );
  }

  Widget _bubble(String text, bool user, _SD s) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(constraints: const BoxConstraints(maxWidth: 220),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
        color: user ? s.color.withValues(alpha: .12) : _T.w(.04),
        border: Border.all(color: user ? s.color.withValues(alpha: .2) : _T.w(.06))),
      child: Text(text, style: TextStyle(fontFamily: _T.bd, fontSize: 9, color: _T.text, height: 1.3))));

  // ── Screen: Студия ──
  Widget _screenStudio(_SD s, double t, bool isPhone) {
    return Padding(
      padding: EdgeInsets.only(top: isPhone ? 50 : 10, left: 6, right: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.symmetric(horizontal: 6), child: _header(s, isPhone)),
        const SizedBox(height: 8),
        for (final tr in [('Beat', _T.accent, 0.85), ('Vocal 1', _T.green, 0.7), ('Vocal 2', _T.purple, 0.5)]) ...[
          _track(tr.$1, tr.$2, tr.$3, t, isPhone),
          const SizedBox(height: 3),
        ],
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
          decoration: BoxDecoration(borderRadius: BorderRadius.circular(7), color: _T.w(.03), border: Border.all(color: _T.w(.06))),
          child: Row(children: [
            Icon(Icons.skip_previous_rounded, size: 12, color: _T.muted),
            const SizedBox(width: 6),
            Container(width: 22, height: 22, decoration: BoxDecoration(shape: BoxShape.circle,
              color: _T.accent.withValues(alpha: .15), border: Border.all(color: _T.accent.withValues(alpha: .3))),
              child: Icon(Icons.play_arrow_rounded, size: 12, color: _T.accent)),
            const SizedBox(width: 6),
            Container(width: 18, height: 18, decoration: BoxDecoration(shape: BoxShape.circle,
              color: const Color(0xFFFF4444).withValues(alpha: .12), border: Border.all(color: const Color(0xFFFF4444).withValues(alpha: .3))),
              child: Icon(Icons.fiber_manual_record_rounded, size: 8, color: const Color(0xFFFF4444))),
            const SizedBox(width: 10),
            Text('00:${((t * 30) % 60).toInt().toString().padLeft(2, '0')}.${((t * 30 % 1) * 1000).toInt().toString().padLeft(3, '0')}',
              style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 12, fontWeight: FontWeight.w700, color: _T.text, letterSpacing: 1)),
            const Spacer(),
            Text('120 BPM', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 8, color: _T.muted, fontWeight: FontWeight.w600)),
          ]),
        ),
      ]),
    );
  }

  Widget _track(String name, Color color, double fill, double t, bool isPhone) {
    return Container(height: isPhone ? 38 : 32, decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(5), color: _T.w(.02), border: Border.all(color: _T.w(.04))),
      child: Row(children: [
        Container(width: isPhone ? 54 : 60, padding: const EdgeInsets.symmetric(horizontal: 5),
          decoration: BoxDecoration(border: Border(right: BorderSide(color: _T.w(.06)))),
          child: Row(children: [
            Container(width: 5, height: 5, decoration: BoxDecoration(shape: BoxShape.circle, color: color)),
            const SizedBox(width: 3),
            Expanded(child: Text(name, overflow: TextOverflow.ellipsis,
              style: TextStyle(fontFamily: _T.bd, fontSize: 8, fontWeight: FontWeight.w600, color: _T.text))),
          ])),
        Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 3, vertical: 3),
          child: RepaintBoundary(child: CustomPaint(painter: _MiniWavePainter(color: color, fill: fill, phase: t),
            size: const Size(double.infinity, double.infinity))))),
      ]),
    );
  }

  // ── Screen: Статистика ──
  Widget _screenStats(_SD s, double t, bool isPhone) {
    return Padding(
      padding: EdgeInsets.only(top: isPhone ? 50 : 10, left: 12, right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(s, isPhone),
        const SizedBox(height: 12),
        Row(children: [
          _stat('Стримы', '${(124 + t * 20).toInt()}K', _T.accent),
          const SizedBox(width: 6),
          _stat('Доход', '₽${(22.1 + t * 5).toStringAsFixed(1)}K', _T.green),
        ]),
        const SizedBox(height: 6),
        Row(children: [
          _stat('Рост', '+${(18 + t * 8).toInt()}%', _T.blue),
          const SizedBox(width: 6),
          _stat('Слушатели', '${(8.4 + t * 3).toStringAsFixed(1)}K', _T.purple),
        ]),
        const SizedBox(height: 10),
        Container(height: isPhone ? 80 : 60, decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8), color: _T.w(.02), border: Border.all(color: _T.w(.04))),
          child: ClipRRect(borderRadius: BorderRadius.circular(8),
            child: CustomPaint(painter: _MiniChartPainter(t: t, color: s.color),
              size: const Size(double.infinity, double.infinity)))),
      ]),
    );
  }

  Widget _stat(String l, String v, Color c) => Expanded(child: Container(
    padding: const EdgeInsets.all(8), decoration: BoxDecoration(borderRadius: BorderRadius.circular(8),
      color: c.withValues(alpha: .06), border: Border.all(color: c.withValues(alpha: .1))),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(l, style: TextStyle(fontFamily: _T.bd, fontSize: 8, color: _T.muted)),
      const SizedBox(height: 3),
      Text(v, style: TextStyle(fontFamily: _T.hd, fontSize: 14, fontWeight: FontWeight.w700, color: _T.text)),
    ])));

  // ── Screen: Aurix DNK ──
  Widget _screenDNK(_SD s, double t, bool isPhone) {
    final tr = [('Мелодичность', .82, _T.accent), ('Эмоциональность', .91, _T.purple),
      ('Ритмичность', .67, _T.green), ('Экспериментальность', .45, _T.cyan), ('Лиричность', .78, _T.blue)];
    return Padding(
      padding: EdgeInsets.only(top: isPhone ? 50 : 10, left: 12, right: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _header(s, isPhone),
        const SizedBox(height: 12),
        Center(child: Container(width: 70, height: 70, decoration: BoxDecoration(shape: BoxShape.circle,
          gradient: RadialGradient(colors: [s.color.withValues(alpha: .15), Colors.transparent]),
          border: Border.all(color: s.color.withValues(alpha: .2), width: 2)),
          child: Center(child: Text('${(85 + t * 5).toInt()}', style: TextStyle(
            fontFamily: _T.hd, fontSize: 22, fontWeight: FontWeight.w700, color: _T.text))))),
        const SizedBox(height: 10),
        for (final x in tr) ...[_bar(x.$1, x.$2 + t * .03, x.$3), const SizedBox(height: 5)],
      ]),
    );
  }

  // ── Shared helpers ──
  Widget _header(_SD s, bool isPhone) => Row(children: [
    Container(padding: const EdgeInsets.all(5), decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(7), color: s.color.withValues(alpha: .1)),
      child: Icon(s.icon, size: 14, color: s.color)),
    const SizedBox(width: 8),
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(s.title, style: TextStyle(fontFamily: _T.hd, fontSize: 11, fontWeight: FontWeight.w700, color: _T.text)),
      Text(s.sub, style: TextStyle(fontFamily: _T.bd, fontSize: 8, color: _T.muted)),
    ]),
  ]);

  Widget _bar(String l, double v, Color c) => Row(children: [
    SizedBox(width: 72, child: Text(l, overflow: TextOverflow.ellipsis,
      style: TextStyle(fontFamily: _T.bd, fontSize: 8, color: _T.sub))),
    Expanded(child: Container(height: 4, decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(2), color: _T.w(.04)),
      child: FractionallySizedBox(alignment: Alignment.centerLeft, widthFactor: v.clamp(0.0, 1.0),
        child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(2), color: c,
          boxShadow: [BoxShadow(color: c.withValues(alpha: .3), blurRadius: 4)]))))),
    const SizedBox(width: 6),
    Text('${(v * 100).toInt()}%', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 8, fontWeight: FontWeight.w600, color: _T.muted)),
  ]);
}

class _SD {
  final String title, sub;
  final Color color;
  final IconData icon;
  const _SD(this.title, this.sub, this.color, this.icon);
}

class _MiniWavePainter extends CustomPainter {
  final Color color;
  final double fill, phase;
  _MiniWavePainter({required this.color, required this.fill, required this.phase});

  @override
  void paint(Canvas canvas, Size size) {
    final n = 60;
    final mid = size.height / 2;
    final clipW = size.width * fill;
    canvas.drawRRect(RRect.fromRectAndRadius(Rect.fromLTWH(0, 2, clipW, size.height - 4), const Radius.circular(4)),
      Paint()..color = color.withValues(alpha: 0.08));
    for (int i = 0; i < n; i++) {
      final x = i * size.width / n;
      if (x > clipW) break;
      final amp = (math.sin(i * 0.7 + phase * math.pi * 6) * 0.5 + 0.5) * fill;
      final h = amp * (size.height - 6) * 0.45;
      canvas.drawRRect(RRect.fromRectAndRadius(
        Rect.fromCenter(center: Offset(x, mid), width: 2, height: h.clamp(2, size.height)), const Radius.circular(1)),
        Paint()..color = color.withValues(alpha: 0.5));
    }
    final px = (phase * 3 % 1.0) * clipW;
    canvas.drawLine(Offset(px, 2), Offset(px, size.height - 2),
      Paint()..color = const Color(0xFFFF6A1A)..strokeWidth = 1.5);
  }

  @override
  bool shouldRepaint(_MiniWavePainter o) => o.phase != phase;
}

// ─────────────────────────────────────────────────────────────────────────────
// PRODUCT PREVIEW — tabbed interface
// ─────────────────────────────────────────────────────────────────────────────

class _ProductPreview extends StatefulWidget {
  const _ProductPreview();
  @override
  State<_ProductPreview> createState() => _ProductPreviewState();
}

class _ProductPreviewState extends State<_ProductPreview> with SingleTickerProviderStateMixin {
  int _tab = 0;
  late final AnimationController _anim;

  @override
  void initState() {
    super.initState();
    _anim = AnimationController(vsync: this, duration: const Duration(seconds: 6));

    if (_isDesktopView()) _anim.repeat();
  }
  @override
  void dispose() { _anim.dispose(); super.dispose(); }

  void _setTab(int i) { if (i != _tab) setState(() => _tab = i); }

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    return _Section(
      padding: EdgeInsets.symmetric(
        horizontal: dk ? 80 : (nr ? 16 : 40),
        vertical: dk ? 120 : 80,
      ),
      child: Column(children: [
        _SectionTag('Внутри продукта'),
        SizedBox(height: dk ? 20 : 12),
        Text(
          'Мощь под капотом',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: _T.hd, color: _T.text,
            fontSize: dk ? 48 : (nr ? 28 : 36),
            fontWeight: FontWeight.w700, height: 1.1,
            letterSpacing: dk ? -1.5 : -.5,
          ),
        ),
        SizedBox(height: dk ? 16 : 10),
        Text(
          'Интерфейс, в котором хочется работать',
          textAlign: TextAlign.center,
          style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: dk ? 16 : 14),
        ),
        SizedBox(height: dk ? 40 : 28),

        // Tab bar
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _T.glass,
            border: Border.all(color: _T.border),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            _TabBtn('Аналитика', 0, _tab, _setTab, _T.blue),
            _TabBtn('AI Студия', 1, _tab, _setTab, _T.purple),
            _TabBtn('Релизы', 2, _tab, _setTab, _T.accent),
          ]),
        ),
        SizedBox(height: dk ? 36 : 24),

        // Content panel
        ConstrainedBox(
          constraints: BoxConstraints(maxWidth: dk ? 820 : double.infinity),
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 400),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: Tween<Offset>(begin: const Offset(0, .03), end: Offset.zero).animate(anim),
                child: child,
              ),
            ),
            child: _tab == 0
                ? _PreviewAnalytics(key: const ValueKey(0), anim: _anim)
                : _tab == 1
                    ? _PreviewAI(key: const ValueKey(1))
                    : _PreviewReleases(key: const ValueKey(2), anim: _anim),
          ),
        ),
      ]),
    );
  }
}

class _TabBtn extends StatefulWidget {
  final String label;
  final int index, current;
  final ValueChanged<int> onTap;
  final Color color;
  const _TabBtn(this.label, this.index, this.current, this.onTap, this.color);
  @override
  State<_TabBtn> createState() => _TabBtnState();
}

class _TabBtnState extends State<_TabBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.index == widget.current;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: () => widget.onTap(widget.index),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            color: active ? widget.color.withValues(alpha: .12) : (_h ? _T.glassHi : Colors.transparent),
            border: active ? Border.all(color: widget.color.withValues(alpha: .2)) : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: _T.hd,
              color: active ? widget.color : (_h ? _T.text : _T.muted),
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

// ── Preview: Analytics ──

class _PreviewAnalytics extends StatelessWidget {
  final AnimationController anim;
  const _PreviewAnalytics({super.key, required this.anim});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: anim,
      builder: (_, __) => _GlassPanel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _PanelChrome(title: 'Аналитика — Дашборд', live: true),
          const SizedBox(height: 20),
          Container(
            height: 130,
            width: double.infinity,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              color: _T.bg,
              border: Border.all(color: _T.border),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: CustomPaint(
                painter: _MiniChartPainter(t: anim.value, color: _T.accent),
                size: const Size(double.infinity, double.infinity),
              ),
            ),
          ),
          const SizedBox(height: 16),
          _BarRow('Spotify', .78 + anim.value * .05, '12.4K', _T.green),
          const SizedBox(height: 10),
          _BarRow('Apple Music', .52 + anim.value * .03, '6.1K', _T.blue),
          const SizedBox(height: 10),
          _BarRow('Яндекс Музыка', .65 + anim.value * .04, '8.8K', _T.accent),
          const SizedBox(height: 16),
          Row(children: [
            _StatPill('Всего', '30.5K', _T.text),
            const SizedBox(width: 8),
            _StatPill('Рост', '+18%', _T.green),
            const SizedBox(width: 8),
            _StatPill('Доход', '₽22.1K', _T.accent),
          ]),
        ]),
      ),
    );
  }
}

class _StatPill extends StatelessWidget {
  final String label, value;
  final Color color;
  const _StatPill(this.label, this.value, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: color.withValues(alpha: .06),
        border: Border.all(color: color.withValues(alpha: .1)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Text('$label ', style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 11)),
        Text(value, style: TextStyle(fontFamily: _T.hd, color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ]),
    );
  }
}

// ── Preview: AI ──

class _PreviewAI extends StatefulWidget {
  const _PreviewAI({super.key});
  @override
  State<_PreviewAI> createState() => _PreviewAIState();
}

class _PreviewAIState extends State<_PreviewAI> {
  final _msgs = [
    ('user', 'Проанализируй мой новый трек'),
    ('ai', 'Анализирую структуру и звук...'),
    ('ai', 'BPM: 128 · Тональность: Am · Жанр: Pop/Electronic'),
    ('ai', 'Хук на 0:14 — сильный потенциал для Reels и TikTok'),
    ('ai', 'Рекомендую: pre-save кампания, Stories промо с хуком'),
  ];
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 800), (_) {
      if (_shown < _msgs.length) { setState(() => _shown++); } else { _timer?.cancel(); }
    });
  }
  @override
  void dispose() { _timer?.cancel(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PanelChrome(title: 'AI Студия', live: _shown > 0),
        const SizedBox(height: 16),
        for (var i = 0; i < _shown && i < _msgs.length; i++) ...[
          _ChatBubble(role: _msgs[i].$1, text: _msgs[i].$2),
          if (i < _shown - 1) const SizedBox(height: 8),
        ],
        if (_shown > 0 && _shown <= _msgs.length) ...[
          const SizedBox(height: 12),
          Row(children: [
            for (var i = 0; i < 3; i++) ...[
              if (i > 0) const SizedBox(width: 4),
              Container(width: 4, height: 4, decoration: BoxDecoration(shape: BoxShape.circle, color: _T.purple.withValues(alpha: 1.0 - i * .3))),
            ],
          ]),
        ],
        if (_shown >= _msgs.length) ...[
          const SizedBox(height: 14),
          Wrap(spacing: 8, runSpacing: 8, children: [
            _QuickAction('Сделать обложку', Icons.image_rounded, _T.purple),
            _QuickAction('Контент-план', Icons.calendar_month_rounded, _T.purple),
            _QuickAction('Промо-видео', Icons.movie_rounded, _T.purple),
          ]),
        ],
      ]),
    );
  }
}

class _ChatBubble extends StatelessWidget {
  final String role, text;
  const _ChatBubble({required this.role, required this.text});

  @override
  Widget build(BuildContext context) {
    final isUser = role == 'user';
    return Align(
      alignment: isUser ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        constraints: BoxConstraints(maxWidth: MediaQuery.sizeOf(context).width * .6),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isUser ? _T.accent.withValues(alpha: .12) : _T.glass,
          border: Border.all(color: isUser ? _T.accent.withValues(alpha: .15) : _T.border),
        ),
        child: Text(
          text,
          style: TextStyle(fontFamily: _T.bd, color: isUser ? _T.accent : _T.sub, fontSize: 13, height: 1.4),
        ),
      ),
    );
  }
}

// ── Preview: Releases ──

class _PreviewReleases extends StatelessWidget {
  final AnimationController anim;
  const _PreviewReleases({super.key, required this.anim});

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _PanelChrome(title: 'Релизы', live: true),
        const SizedBox(height: 16),
        _ReleaseRow('Новый сингл «Огни»', 'Live на 5 площадках', _T.green, true),
        const SizedBox(height: 8),
        _ReleaseRow('EP «Полёт»', 'На модерации', _T.accent, false),
        const SizedBox(height: 8),
        _ReleaseRow('Альбом «Система»', 'Черновик', _T.dim, false),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _T.bg,
            border: Border.all(color: _T.border),
          ),
          child: AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final streams = 24800 + (anim.value * 400).toInt();
              return Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Стримы сегодня', style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(
                    streams.toString().replaceAllMapped(RegExp(r'(\d)(?=(\d{3})+$)'), (m) => '${m[1]} '),
                    style: TextStyle(fontFamily: _T.hd, color: _T.text, fontSize: 22, fontWeight: FontWeight.w700),
                  ),
                ])),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(8), color: _T.green.withValues(alpha: .1)),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.trending_up_rounded, color: _T.green, size: 14),
                    const SizedBox(width: 4),
                    Text('+12%', style: TextStyle(fontFamily: _T.hd, color: _T.green, fontSize: 13, fontWeight: FontWeight.w700)),
                  ]),
                ),
              ]);
            },
          ),
        ),
      ]),
    );
  }
}

class _ReleaseRow extends StatelessWidget {
  final String title, status;
  final Color color;
  final bool live;
  const _ReleaseRow(this.title, this.status, this.color, this.live);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _T.glass,
        border: Border.all(color: _T.border),
      ),
      child: Row(children: [
        Container(
          width: 36, height: 36,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            gradient: LinearGradient(colors: [_T.accent.withValues(alpha: .12), _T.purple.withValues(alpha: .08)]),
          ),
          child: const Icon(Icons.album_rounded, color: _T.accent, size: 18),
        ),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: TextStyle(fontFamily: _T.bd, color: _T.text, fontSize: 13, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text(status, style: TextStyle(fontFamily: _T.bd, color: _T.muted, fontSize: 11)),
        ])),
        if (live) ...[
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: color,
              boxShadow: [BoxShadow(color: color.withValues(alpha: .5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
        ],
        Text(live ? 'Live' : '', style: TextStyle(fontFamily: _T.bd, color: color, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FINAL CTA — emotional push
// ─────────────────────────────────────────────────────────────────────────────

class _FinalCta extends StatelessWidget {
  final VoidCallback onReg;
  const _FinalCta({required this.onReg});

  @override
  Widget build(BuildContext context) {
    final dk = _isDesktop(context);
    final nr = _isNarrow(context);

    return _Section(
      padding: EdgeInsets.symmetric(
        horizontal: dk ? 120 : (nr ? 20 : 48),
        vertical: dk ? 120 : 80,
      ),
      child: Container(
        width: double.infinity,
        padding: EdgeInsets.symmetric(
          horizontal: dk ? 100 : 28,
          vertical: dk ? 80 : 56,
        ),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(32),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              _T.accent.withValues(alpha: .08),
              _T.purple.withValues(alpha: .04),
              _T.bg,
            ],
          ),
          border: Border.all(color: _T.accent.withValues(alpha: .12)),
          boxShadow: [
            BoxShadow(color: _T.g(.06), blurRadius: 100, spreadRadius: -20),
            BoxShadow(color: _T.purple.withValues(alpha: .03), blurRadius: 80, spreadRadius: -30, offset: const Offset(40, 20)),
          ],
        ),
        child: Column(children: [
          Text(
            'Каждый день без системы —\nпотерянная аудитория',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: _T.hd, color: _T.text,
              fontSize: dk ? 48 : (nr ? 28 : 38),
              fontWeight: FontWeight.w700,
              height: 1.1,
              letterSpacing: dk ? -1.5 : -.5,
            ),
          ),
          SizedBox(height: dk ? 16 : 12),
          Text(
            'Пока ты думаешь — 847 артистов уже используют AURIX.',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: _T.bd, color: _T.accent.withValues(alpha: .8), fontSize: dk ? 17 : 14, height: 1.5, fontWeight: FontWeight.w500),
          ),
          SizedBox(height: dk ? 44 : 32),
          _GlowButton(label: 'Начать сейчас — бесплатно', onTap: onReg),
          const SizedBox(height: 16),
          Text(
            'Без карты · 5 минут до первого релиза · Отмена в любой момент',
            textAlign: TextAlign.center,
            style: TextStyle(fontFamily: _T.bd, color: _T.dim, fontSize: 12),
          ),
        ]),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// FOOTER
// ─────────────────────────────────────────────────────────────────────────────

class _Footer extends StatelessWidget {
  final VoidCallback onLogin;
  const _Footer({required this.onLogin});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 48, horizontal: 32),
      decoration: BoxDecoration(border: Border(top: BorderSide(color: _T.w(.04)))),
      child: Center(
        child: Column(children: [
          Text('AURIX', style: TextStyle(fontFamily: _T.hd, color: _T.accent.withValues(alpha: .3), fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 4)),
          const SizedBox(height: 20),
          Wrap(spacing: 28, alignment: WrapAlignment.center, children: [
            _FooterLink('Вход', onTap: onLogin),
            _FooterLink('Конфиденциальность', path: '/legal/privacy'),
            _FooterLink('Условия', path: '/legal/terms'),
          ]),
          const SizedBox(height: 20),
          Text('© ${DateTime.now().year} AURIX', style: TextStyle(fontFamily: _T.bd, color: _T.dim, fontSize: 11)),
        ]),
      ),
    );
  }
}

class _FooterLink extends StatefulWidget {
  final String label;
  final String? path;
  final VoidCallback? onTap;
  const _FooterLink(this.label, {this.path, this.onTap});
  @override
  State<_FooterLink> createState() => _FooterLinkState();
}

class _FooterLinkState extends State<_FooterLink> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap ?? () => context.go(widget.path ?? '/'),
        child: Text(
          widget.label,
          style: TextStyle(fontFamily: _T.bd, color: _h ? _T.sub : _T.muted, fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// SHARED COMPONENTS
// ─────────────────────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry? padding;
  const _Section({required this.child, this.padding});
  @override
  Widget build(BuildContext context) {
    return Padding(padding: padding ?? EdgeInsets.zero, child: Center(child: child));
  }
}

class _SectionTag extends StatelessWidget {
  final String label;
  const _SectionTag(this.label);
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: _T.accent.withValues(alpha: .06),
        border: Border.all(color: _T.accent.withValues(alpha: .12)),
      ),
      child: Text(
        label.toUpperCase(),
        style: TextStyle(fontFamily: _T.hd, color: _T.accent, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 2),
      ),
    );
  }
}

class _SectionGlow extends StatelessWidget {
  final Color color;
  final Widget child;
  const _SectionGlow({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Stack(children: [
      Positioned(
        left: 0, right: 0, top: -100, bottom: -100,
        child: Center(child: Container(
          width: 500, height: 500,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(colors: [color.withValues(alpha: .04), Colors.transparent]),
          ),
        )),
      ),
      child,
    ]);
  }
}

class _GlowButton extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _GlowButton({required this.label, required this.onTap});
  @override
  State<_GlowButton> createState() => _GlowButtonState();
}

class _GlowButtonState extends State<_GlowButton> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.symmetric(horizontal: 48, vertical: 18),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: _h ? _T.accentHi : _T.accent,
            boxShadow: [
              BoxShadow(color: _T.accent.withValues(alpha: _h ? .5 : .25), blurRadius: _h ? 48 : 28, offset: const Offset(0, 8)),
              if (_h) BoxShadow(color: _T.accent.withValues(alpha: .15), blurRadius: 80, spreadRadius: -10),
            ],
          ),
          child: Text(
            widget.label,
            style: TextStyle(fontFamily: _T.hd, color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600, letterSpacing: .3),
          ),
        ),
      ),
    );
  }
}

class _NavBtn extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  final bool ghost;
  final bool compact;
  const _NavBtn(this.label, {required this.onTap, this.ghost = false, this.compact = false});
  @override
  State<_NavBtn> createState() => _NavBtnState();
}

class _NavBtnState extends State<_NavBtn> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final c = widget.compact;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: EdgeInsets.symmetric(
            horizontal: c ? 12 : 20,
            vertical: c ? 7 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(c ? 10 : 12),
            color: widget.ghost ? Colors.transparent : (_h ? _T.accentHi : _T.accent),
            border: widget.ghost ? Border.all(color: _T.w(_h ? .15 : .08)) : null,
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: _T.bd,
              color: widget.ghost ? (_h ? _T.text : _T.sub) : Colors.white,
              fontSize: c ? 12 : 13,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: _T.card,
        border: Border.all(color: _T.border),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: .6), blurRadius: 60, offset: const Offset(0, 24))],
      ),
      child: child,
    );
  }
}

class _PanelChrome extends StatelessWidget {
  final String title;
  final bool live;
  const _PanelChrome({required this.title, this.live = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: _T.bg,
        border: Border.all(color: _T.border),
      ),
      child: Row(children: [
        for (var i = 0; i < 3; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Container(width: 8, height: 8, decoration: BoxDecoration(shape: BoxShape.circle, color: _T.w(.12))),
        ],
        const SizedBox(width: 12),
        Text(title, style: TextStyle(fontFamily: _T.hd, color: _T.muted, fontSize: 11, fontWeight: FontWeight.w600)),
        const Spacer(),
        if (live) ...[
          Container(
            width: 6, height: 6,
            decoration: BoxDecoration(
              shape: BoxShape.circle, color: _T.green,
              boxShadow: [BoxShadow(color: _T.green.withValues(alpha: .5), blurRadius: 6)],
            ),
          ),
          const SizedBox(width: 6),
          Text('Live', style: TextStyle(fontFamily: _T.bd, color: _T.green, fontSize: 10, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

// ── Scroll reveal ──

class _Rv extends StatefulWidget {
  final ScrollController sc;
  final Widget child;
  const _Rv({required this.sc, required this.child});
  @override
  State<_Rv> createState() => _RvState();
}

class _RvState extends State<_Rv> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  bool _s = false;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));
    widget.sc.addListener(_chk);
    WidgetsBinding.instance.addPostFrameCallback((_) => _chk());
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && !_s) { _s = true; _c.forward(); }
    });
  }

  void _chk() {
    if (_s || !mounted) return;
    final ro = context.findRenderObject();
    if (ro is! RenderBox || !ro.hasSize) return;
    if (ro.localToGlobal(Offset.zero).dy < MediaQuery.sizeOf(context).height * .9) {
      _s = true;
      widget.sc.removeListener(_chk);
      _c.forward();
    }
  }

  @override
  void dispose() { widget.sc.removeListener(_chk); _c.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 36 * (1 - t)), child: child));
      },
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// CASTING NAV BUTTON — «Код Артиста» in navbar
// ─────────────────────────────────────────────────────────────────────────────

class _CastingNavBtn extends StatefulWidget {
  final VoidCallback onTap;
  final bool compact;
  const _CastingNavBtn({required this.onTap, this.compact = false});
  @override
  State<_CastingNavBtn> createState() => _CastingNavBtnState();
}

class _CastingNavBtnState extends State<_CastingNavBtn> {
  bool _h = false;

  @override
  Widget build(BuildContext context) {
    final c = widget.compact;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: EdgeInsets.symmetric(
            horizontal: c ? 9 : 16,
            vertical: c ? 5 : 10,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(c ? 999 : 12),
            gradient: LinearGradient(
              colors: [
                _T.accent.withValues(alpha: _h ? 0.22 : 0.12),
                const Color(0xFF7B5CFF).withValues(alpha: _h ? 0.14 : 0.06),
              ],
            ),
            border: Border.all(color: _T.accent.withValues(alpha: _h ? 0.5 : 0.3)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: c ? 5 : 6, height: c ? 5 : 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: _T.accent,
                  boxShadow: c ? [] : [BoxShadow(color: _T.accent.withValues(alpha: 0.6), blurRadius: 6)],
                ),
              ),
              SizedBox(width: c ? 6 : 8),
              Text(
                'Код Артиста',
                style: TextStyle(
                  fontFamily: _T.hd,
                  color: _T.accent,
                  fontSize: c ? 10 : 12,
                  fontWeight: FontWeight.w700,
                  letterSpacing: c ? 0.3 : 0.5,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
