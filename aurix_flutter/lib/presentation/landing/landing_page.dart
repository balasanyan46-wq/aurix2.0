import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';

class LandingPage extends StatefulWidget {
  final VoidCallback? onLogin;
  final VoidCallback? onRegister;

  const LandingPage({super.key, this.onLogin, this.onRegister});

  @override
  State<LandingPage> createState() => _LandingPageState();
}

class _LandingPageState extends State<LandingPage>
    with TickerProviderStateMixin {
  late final AnimationController _heroController;
  late final AnimationController _shimmerController;
  late final ScrollController _scrollController;

  late final Animation<double> _heroFade;
  late final Animation<Offset> _heroSlide;

  int _shimmerCycles = 0;
  static const _maxShimmerCycles = 3;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _heroController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    );
    _shimmerController.addStatusListener((status) {
      if (status == AnimationStatus.completed) {
        _shimmerCycles++;
        if (_shimmerCycles < _maxShimmerCycles) {
          _shimmerController.forward(from: 0);
        }
      }
    });
    _shimmerController.forward();

    _heroFade = CurvedAnimation(
      parent: _heroController,
      curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
    );
    _heroSlide = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _heroController,
      curve: Curves.easeOutCubic,
    ));

    _heroController.forward();
  }

  @override
  void dispose() {
    _heroController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  bool _isDesktop(BuildContext context) =>
      MediaQuery.sizeOf(context).width >= 840;

  void _goLogin(BuildContext context) {
    if (widget.onLogin != null) {
      widget.onLogin!();
    } else {
      context.go('/login');
    }
  }

  void _goRegister(BuildContext context) {
    if (widget.onRegister != null) {
      widget.onRegister!();
    } else {
      context.go('/register');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      body: Stack(
        children: [
          Positioned(
            top: -120,
            left: 0,
            right: 0,
            height: 600,
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _heroController,
                builder: (context, _) {
                  return CustomPaint(
                    painter: _HeroGlowPainter(
                      progress: 0.5,
                      fade: _heroFade.value,
                    ),
                  );
                },
              ),
            ),
          ),
          CustomScrollView(
            controller: _scrollController,
            slivers: [
              SliverToBoxAdapter(child: _buildNav(context)),
              SliverToBoxAdapter(child: _buildHero(context)),
              SliverToBoxAdapter(child: _buildFeatures(context)),
              SliverToBoxAdapter(child: _buildWhy(context)),
              SliverToBoxAdapter(child: _buildForWho(context)),
              SliverToBoxAdapter(child: _buildFinalCta(context)),
              SliverToBoxAdapter(child: _buildFooter()),
            ],
          ),
        ],
      ),
    );
  }

  // ─── NAV ───────────────────────────────────────────────────────────

  Widget _buildNav(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: _isDesktop(context) ? 48 : 20,
        vertical: 16,
      ),
      child: Row(
        children: [
          RepaintBoundary(
            child: AnimatedBuilder(
              animation: _shimmerController,
              builder: (context, _) {
                final t = _shimmerController.value;
                return ShaderMask(
                  shaderCallback: (bounds) => LinearGradient(
                    colors: [
                      AurixTokens.orange,
                      AurixTokens.orange.withValues(alpha: 0.6),
                      Colors.white,
                      AurixTokens.orange.withValues(alpha: 0.6),
                      AurixTokens.orange,
                    ],
                    stops: [
                      0.0,
                      math.max(0, t - 0.15),
                      t,
                      math.min(1, t + 0.15),
                      1.0,
                    ],
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
                );
              },
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () => _goLogin(context),
            style: TextButton.styleFrom(
              foregroundColor: AurixTokens.textSecondary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
            child: const Text(
              'Войти',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
          const SizedBox(width: 8),
          _SmallCta(
            label: 'Начать',
            onTap: () => _goRegister(context),
          ),
        ],
      ),
    );
  }

  // ─── HERO ──────────────────────────────────────────────────────────

  Widget _buildHero(BuildContext context) {
    final desktop = _isDesktop(context);

    return FadeTransition(
      opacity: _heroFade,
      child: SlideTransition(
        position: _heroSlide,
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: desktop ? 48 : 20,
            vertical: desktop ? 80 : 48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: Column(
                crossAxisAlignment: desktop
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(
                    'Экосистема артиста:\nрелизы, AI-студия, аналитика —\nв одном месте.',
                    textAlign: desktop ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: AurixTokens.text,
                      fontSize: desktop ? 44 : 28,
                      fontWeight: FontWeight.w800,
                      height: 1.15,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 20),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: desktop ? 600 : double.infinity,
                    ),
                    child: Text(
                      'Загружай релизы, раздавай сплиты, собирай контент и тексты, '
                      'контролируй процесс и результаты.\n'
                      'Без хаоса. Без табличек. Без «а где это лежит?».',
                      textAlign: desktop ? TextAlign.center : TextAlign.left,
                      style: TextStyle(
                        color: AurixTokens.textSecondary,
                        fontSize: desktop ? 17 : 15,
                        height: 1.6,
                      ),
                    ),
                  ),
                  const SizedBox(height: 36),
                  Wrap(
                    alignment:
                        desktop ? WrapAlignment.center : WrapAlignment.start,
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      _PrimaryCta(
                        label: 'Начать бесплатно',
                        shimmer: _shimmerController,
                        onTap: () => _goRegister(context),
                      ),
                      _OutlineCta(
                        label: 'Войти',
                        onTap: () => _goLogin(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'Собери релиз от идеи до публикации в одной системе.',
                    textAlign: desktop ? TextAlign.center : TextAlign.left,
                    style: TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 13,
                      letterSpacing: 0.2,
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

  // ─── FEATURES ──────────────────────────────────────────────────────

  Widget _buildFeatures(BuildContext context) {
    final desktop = _isDesktop(context);

    const features = [
      _FeatureData(
        icon: Icons.album_rounded,
        title: 'Distribution',
        text:
            'Релизы, статусы, файлы, метаданные, сплиты, контроль каждого шага.',
      ),
      _FeatureData(
        icon: Icons.auto_awesome_rounded,
        title: 'AURIX Studio AI',
        text:
            'Хуки, тексты, сниппеты, сценарии Reels, прогрев, контент-кит — быстро и без воды.',
      ),
      _FeatureData(
        icon: Icons.dashboard_rounded,
        title: 'Dashboard',
        text:
            'Вся картина в одном месте: что готово, что зависло, что надо сделать сегодня.',
      ),
      _FeatureData(
        icon: Icons.description_rounded,
        title: 'Content Kit',
        text:
            'Описание релиза, заголовки, подписи, идеи для обложек и контента — под ключ.',
      ),
    ];

    return _Section(
      child: Column(
        children: [
          const _SectionLabel(text: 'ЧТО ВНУТРИ'),
          const SizedBox(height: 12),
          Text(
            'Всё для релиза — в одном продукте',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 28 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 40),
          desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: features
                      .map((f) => Expanded(child: _FeatureCard(data: f)))
                      .toList(),
                )
              : Column(
                  children:
                      features.map((f) => _FeatureCard(data: f)).toList(),
                ),
        ],
      ),
    );
  }

  // ─── WHY AURIX ─────────────────────────────────────────────────────

  Widget _buildWhy(BuildContext context) {
    final desktop = _isDesktop(context);

    const reasons = [
      _ReasonData(
        num: '01',
        title: 'Всё в одном месте',
        text: 'Релиз → контент → контроль. Один продукт вместо пяти.',
      ),
      _ReasonData(
        num: '02',
        title: 'Быстрее в 3 раза',
        text: 'Меньше рутины, больше музыки. AI делает черновую работу.',
      ),
      _ReasonData(
        num: '03',
        title: 'Порядок вместо хаоса',
        text: 'Ты видишь процесс и результат. Всегда знаешь, что дальше.',
      ),
    ];

    return _Section(
      child: Column(
        children: [
          const _SectionLabel(text: 'ПОЧЕМУ AURIX'),
          const SizedBox(height: 40),
          desktop
              ? Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: reasons
                      .map((r) => Expanded(child: _ReasonCard(data: r)))
                      .toList(),
                )
              : Column(
                  children:
                      reasons.map((r) => _ReasonCard(data: r)).toList(),
                ),
        ],
      ),
    );
  }

  // ─── FOR WHO ───────────────────────────────────────────────────────

  Widget _buildForWho(BuildContext context) {
    const roles = ['Артист', 'Продюсер', 'Лейбл', 'Менеджер', 'Сонграйтер'];

    return _Section(
      child: Column(
        children: [
          const _SectionLabel(text: 'ДЛЯ КОГО'),
          const SizedBox(height: 12),
          Text(
            'AURIX для всех, кто делает музыку',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: _isDesktop(context) ? 28 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 32),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 10,
            children: roles.map((r) => _RoleBadge(label: r)).toList(),
          ),
        ],
      ),
    );
  }

  // ─── FINAL CTA ─────────────────────────────────────────────────────

  Widget _buildFinalCta(BuildContext context) {
    final desktop = _isDesktop(context);

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 48 : 20,
        vertical: desktop ? 80 : 48,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Container(
            padding: EdgeInsets.all(desktop ? 56 : 32),
            decoration: BoxDecoration(
              color: AurixTokens.bg1,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AurixTokens.border),
            ),
            child: Column(
              children: [
                Text(
                  'Хватит работать\nв пяти сервисах.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AurixTokens.text,
                    fontSize: desktop ? 32 : 24,
                    fontWeight: FontWeight.w800,
                    height: 1.2,
                    letterSpacing: -0.3,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Собери релиз в AURIX и веди всё в одном месте —\nот идеи до публикации.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 15,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 32),
                _PrimaryCta(
                  label: 'Создать аккаунт',
                  shimmer: _shimmerController,
                  onTap: () => _goRegister(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ─── FOOTER ────────────────────────────────────────────────────────

  Widget _buildFooter() {
    return Padding(
      padding: const EdgeInsets.only(bottom: 28, top: 8),
      child: Center(
        child: Text.rich(
          TextSpan(children: [
            TextSpan(
              text: 'AURIX',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.85),
                fontSize: 12,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.4,
              ),
            ),
            TextSpan(
              text: ' • by Armen Balasanyan',
              style: TextStyle(
                color: Colors.white.withValues(alpha: 0.55),
                fontSize: 12,
                fontWeight: FontWeight.w400,
                letterSpacing: 0.3,
              ),
            ),
          ]),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// REUSABLE WIDGETS
// ═══════════════════════════════════════════════════════════════════════

class _Section extends StatelessWidget {
  final Widget child;
  const _Section({required this.child});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 840;
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: desktop ? 48 : 20,
        vertical: desktop ? 56 : 36,
      ),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: child,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
        decoration: BoxDecoration(
          color: AurixTokens.orange.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: AurixTokens.orange.withValues(alpha: 0.15),
          ),
        ),
        child: Text(
          text,
          style: TextStyle(
            color: AurixTokens.orange,
            fontSize: 11,
            fontWeight: FontWeight.w600,
            letterSpacing: 2,
          ),
        ),
      ),
    );
  }
}

// ─── Feature card ────────────────────────────────────────────────────

class _FeatureData {
  final IconData icon;
  final String title;
  final String text;
  const _FeatureData(
      {required this.icon, required this.title, required this.text});
}

class _FeatureCard extends StatefulWidget {
  final _FeatureData data;
  const _FeatureCard({required this.data});

  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: _hovered ? AurixTokens.glass(0.06) : AurixTokens.glass(0.03),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: _hovered
                ? AurixTokens.orange.withValues(alpha: 0.2)
                : AurixTokens.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: AurixTokens.orange.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                widget.data.icon,
                color: AurixTokens.orange,
                size: 20,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              widget.data.title,
              style: const TextStyle(
                color: AurixTokens.text,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.data.text,
              style: TextStyle(
                color: AurixTokens.textSecondary,
                fontSize: 14,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Reason card ─────────────────────────────────────────────────────

class _ReasonData {
  final String num;
  final String title;
  final String text;
  const _ReasonData(
      {required this.num, required this.title, required this.text});
}

class _ReasonCard extends StatelessWidget {
  final _ReasonData data;
  const _ReasonCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            data.num,
            style: TextStyle(
              color: AurixTokens.orange,
              fontSize: 32,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.title,
            style: const TextStyle(
              color: AurixTokens.text,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            data.text,
            style: TextStyle(
              color: AurixTokens.textSecondary,
              fontSize: 14,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

// ─── Role badge ──────────────────────────────────────────────────────

class _RoleBadge extends StatefulWidget {
  final String label;
  const _RoleBadge({required this.label});

  @override
  State<_RoleBadge> createState() => _RoleBadgeState();
}

class _RoleBadgeState extends State<_RoleBadge> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: _hovered
              ? AurixTokens.orange.withValues(alpha: 0.1)
              : AurixTokens.glass(0.04),
          borderRadius: BorderRadius.circular(100),
          border: Border.all(
            color: _hovered
                ? AurixTokens.orange.withValues(alpha: 0.3)
                : AurixTokens.border,
          ),
        ),
        child: Text(
          widget.label,
          style: TextStyle(
            color: _hovered ? AurixTokens.orange : AurixTokens.text,
            fontSize: 14,
            fontWeight: FontWeight.w500,
          ),
        ),
      ),
    );
  }
}

// ─── CTA Buttons ─────────────────────────────────────────────────────

class _PrimaryCta extends StatelessWidget {
  final String label;
  final AnimationController shimmer;
  final VoidCallback onTap;

  const _PrimaryCta({
    required this.label,
    required this.shimmer,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: shimmer,
      builder: (context, _) {
        final t = shimmer.value;
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: AurixTokens.orange.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: -4,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: onTap,
              child: Ink(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(12),
                  gradient: LinearGradient(
                    colors: [
                      AurixTokens.orange,
                      AurixTokens.orange2,
                      AurixTokens.orange,
                      Color.lerp(AurixTokens.orange, Colors.white, 0.25)!,
                      AurixTokens.orange,
                    ],
                    stops: [
                      0.0,
                      math.max(0, t - 0.2),
                      math.max(0, t - 0.05),
                      t,
                      math.min(1, t + 0.15),
                    ],
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 14,
                  ),
                  child: Text(
                    label,
                    style: const TextStyle(
                      color: Colors.black,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _OutlineCta extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _OutlineCta({required this.label, required this.onTap});

  @override
  State<_OutlineCta> createState() => _OutlineCtaState();
}

class _OutlineCtaState extends State<_OutlineCta> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color:
                _hovered ? AurixTokens.glass(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered
                  ? AurixTokens.textSecondary
                  : AurixTokens.borderLight,
            ),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: 15,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.3,
            ),
          ),
        ),
      ),
    );
  }
}

class _SmallCta extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _SmallCta({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return FilledButton(
      onPressed: onTap,
      style: FilledButton.styleFrom(
        backgroundColor: AurixTokens.orange,
        foregroundColor: Colors.black,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        textStyle: const TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w700,
        ),
      ),
      child: Text(label),
    );
  }
}

// ─── Background painter ──────────────────────────────────────────────

class _HeroGlowPainter extends CustomPainter {
  final double progress;
  final double fade;

  _HeroGlowPainter({required this.progress, required this.fade});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height * 0.55);
    final baseRadius = size.width * 0.5;
    final r = baseRadius * (0.9 + 0.1 * math.sin(progress * math.pi));

    final paint = Paint()
      ..shader = RadialGradient(
        colors: [
          AurixTokens.orange.withValues(alpha: 0.05 * fade),
          AurixTokens.orange.withValues(alpha: 0.015 * fade),
          Colors.transparent,
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: r));

    canvas.drawCircle(center, r, paint);
  }

  @override
  bool shouldRepaint(_HeroGlowPainter old) =>
      old.progress != progress || old.fade != fade;
}
