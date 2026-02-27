import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/presentation/landing/widgets/parallax_layer.dart';
import 'package:aurix_flutter/presentation/landing/widgets/reveal_on_scroll.dart';
import 'package:aurix_flutter/presentation/landing/widgets/tilt_glow_card.dart';

enum _NavSection { hero, inside, how, cases, guide, faq, contacts }

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

  final _sectionKeys = <_NavSection, GlobalKey>{
    _NavSection.hero: GlobalKey(),
    _NavSection.inside: GlobalKey(),
    _NavSection.how: GlobalKey(),
    _NavSection.cases: GlobalKey(),
    _NavSection.guide: GlobalKey(),
    _NavSection.faq: GlobalKey(),
    _NavSection.contacts: GlobalKey(),
  };
  final _sectionOffsets = <_NavSection, double>{};
  _NavSection _active = _NavSection.hero;
  bool _measured = false;

  // Audience switch
  static const _roles = ['Артист', 'Продюсер', 'Лейбл', 'Менеджер', 'Сонграйтер'];
  int _roleIdx = 0;

  bool _isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= 960;
  bool _isNarrow(BuildContext context) => MediaQuery.sizeOf(context).width < 720;
  bool _perfMode(BuildContext context) {
    final mq = MediaQuery.of(context);
    // Heuristic: treat narrow/tablet widths as touch/performance mode.
    return mq.size.width < 900;
  }

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

    _scrollController.addListener(_handleScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _measureSectionOffsets();
      _handleAuthQuery();
    });

    _MetricsObserver.ensure(() {
      if (!mounted) return;
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureSectionOffsets());
    });
  }

  @override
  void dispose() {
    _heroController.dispose();
    _shimmerController.dispose();
    _scrollController.dispose();
    WidgetsBinding.instance.removeObserver(_MetricsObserver._instance);
    super.dispose();
  }

  void _handleAuthQuery() {
    // Support static pages linking back to app: /?auth=login or /?auth=register
    final a = Uri.base.queryParameters['auth'];
    if (a == 'login') {
      _goLogin(context);
    } else if (a == 'register') {
      _goRegister(context);
    }
  }

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

  Future<void> _openStatic(String relativePath) async {
    final uri = Uri.base.resolve(relativePath);
    if (!await launchUrl(uri, mode: LaunchMode.platformDefault)) {
      // No-op: landing should still be usable without guides.
    }
  }

  Widget _anchor(_NavSection section, Widget child) {
    return KeyedSubtree(
      key: _sectionKeys[section],
      child: child,
    );
  }

  void _measureSectionOffsets() {
    if (!mounted) return;
    _sectionOffsets.clear();
    for (final e in _sectionKeys.entries) {
      final ctx = e.value.currentContext;
      if (ctx == null) continue;
      final box = ctx.findRenderObject();
      if (box is! RenderBox) continue;
      final dy = box.localToGlobal(Offset.zero).dy;
      final offset = _scrollController.offset + dy - _headerHeight(context);
      _sectionOffsets[e.key] = offset;
    }
    _measured = _sectionOffsets.isNotEmpty;
    _handleScroll();
  }

  double _headerHeight(BuildContext context) {
    // Matches SliverAppBar height.
    final top = MediaQuery.paddingOf(context).top;
    return top + 64;
  }

  void _handleScroll() {
    if (!_measured) return;
    final y = _scrollController.offset + 2;
    _NavSection current = _NavSection.hero;
    final ordered = _NavSection.values.where(_sectionOffsets.containsKey).toList();
    ordered.sort((a, b) => (_sectionOffsets[a] ?? 0).compareTo(_sectionOffsets[b] ?? 0));
    for (final s in ordered) {
      final off = _sectionOffsets[s] ?? 0;
      if (y >= off) current = s;
    }
    if (current != _active && mounted) setState(() => _active = current);
  }

  Future<void> _scrollTo(_NavSection section) async {
    if (!_measured) _measureSectionOffsets();
    final target = _sectionOffsets[section];
    if (target == null) return;
    await _scrollController.animateTo(
      target.clamp(0, _scrollController.position.maxScrollExtent),
      duration: const Duration(milliseconds: 520),
      curve: Curves.easeOutCubic,
    );
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
            child: ParallaxLayer(
              scrollListenable: _scrollController,
              depth: 0.10,
              maxShift: 48,
              disabled: _perfMode(context),
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
          ),
          NotificationListener<ScrollNotification>(
            onNotification: (_) {
              _handleScroll();
              return false;
            },
            child: CustomScrollView(
              controller: _scrollController,
              slivers: [
                _buildHeader(context),
                SliverToBoxAdapter(child: _anchor(_NavSection.hero, _buildHero(context))),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _anchor(_NavSection.inside, _buildFeatures(context)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    delay: const Duration(milliseconds: 60),
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _anchor(_NavSection.how, _buildHowItWorks(context)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    delay: const Duration(milliseconds: 90),
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _buildForWho(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    delay: const Duration(milliseconds: 120),
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _buildWhyNow(context),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    delay: const Duration(milliseconds: 150),
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _anchor(_NavSection.cases, _buildCases(context)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    delay: const Duration(milliseconds: 170),
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _anchor(_NavSection.guide, _buildGuide(context)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    delay: const Duration(milliseconds: 190),
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _anchor(_NavSection.faq, _buildFaq(context)),
                  ),
                ),
                SliverToBoxAdapter(
                  child: RevealOnScroll(
                    scrollListenable: _scrollController,
                    delay: const Duration(milliseconds: 210),
                    disabled: MediaQuery.of(context).accessibleNavigation,
                    child: _anchor(_NavSection.contacts, _buildFooterExpanded(context)),
                  ),
                ),
              ],
            ),
          ),
          if (_isNarrow(context)) _buildMobileCtaBar(context),
        ],
      ),
    );
  }

  Widget _buildWhyNow(BuildContext context) {
    final desktop = _isDesktop(context);
    const reasons = [
      _ReasonData(num: '01', title: 'Алгоритмы любят регулярность', text: 'Регулярность проще, когда процесс не рассыпан по сервисам.'),
      _ReasonData(num: '02', title: 'Потеря сроков = потеря внимания', text: 'Сдвиг дедлайна часто сдвигает и интерес аудитории.'),
      _ReasonData(num: '03', title: 'Хаос в файлах убивает релиз', text: 'Версии, исходники, договорённости — должны быть в одном месте.'),
    ];
    return _Section(
      child: Column(
        children: [
          const _SectionLabel(text: 'ПОЧЕМУ СЕЙЧАС'),
          const SizedBox(height: 12),
          Text(
            'Пока ты тянешь — релиз стареет.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.text, fontSize: desktop ? 28 : 22, fontWeight: FontWeight.w900, letterSpacing: -0.3),
          ),
          const SizedBox(height: 18),
          _CardsGrid(items: reasons.map((r) => _ReasonCard(data: r)).toList()),
        ],
      ),
    );
  }

  // ─── HEADER ────────────────────────────────────────────────────────

  SliverAppBar _buildHeader(BuildContext context) {
    final desktop = _isDesktop(context);
    return SliverAppBar(
      pinned: true,
      toolbarHeight: 64,
      automaticallyImplyLeading: false,
      backgroundColor: Colors.transparent,
      elevation: 0,
      flexibleSpace: ClipRect(
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            decoration: BoxDecoration(
              color: AurixTokens.bg0.withValues(alpha: 0.72),
              border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.12))),
            ),
          ),
        ),
      ),
      titleSpacing: desktop ? 28 : 16,
      title: Row(
        children: [
          _BrandMark(onTap: () => _scrollTo(_NavSection.hero)),
          const SizedBox(width: 16),
          if (desktop) ...[
            _NavItem(
              label: 'Возможности',
              active: _active == _NavSection.inside || _active == _NavSection.cases,
              onTap: () => _scrollTo(_NavSection.inside),
            ),
            _NavItem(
              label: 'Кейсы',
              active: _active == _NavSection.cases,
              onTap: () => _scrollTo(_NavSection.cases),
            ),
            _NavItem(
              label: 'Как работает',
              active: _active == _NavSection.how,
              onTap: () => _scrollTo(_NavSection.how),
            ),
            _NavItem(
              label: 'Гайд',
              active: _active == _NavSection.guide,
              onTap: () => _scrollTo(_NavSection.guide),
            ),
            _NavItem(
              label: 'FAQ',
              active: _active == _NavSection.faq,
              onTap: () => _scrollTo(_NavSection.faq),
            ),
            _NavItem(
              label: 'Контакты',
              active: _active == _NavSection.contacts,
              onTap: () => _scrollTo(_NavSection.contacts),
            ),
          ],
          const Spacer(),
          if (!desktop)
            IconButton(
              tooltip: 'Меню',
              onPressed: () => _openMobileMenu(context),
              icon: Icon(Icons.menu_rounded, color: AurixTokens.text.withValues(alpha: 0.85)),
            ),
          if (desktop) ...[
            _OutlineCta(label: 'Вход', onTap: () => _goLogin(context)),
            const SizedBox(width: 10),
            _SmallCta(label: 'Регистрация', onTap: () => _goRegister(context)),
          ],
        ],
      ),
    );
  }

  void _openMobileMenu(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.65),
      builder: (_) {
        return Container(
          margin: const EdgeInsets.all(12),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurixTokens.stroke(0.16)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 6),
              _MobileNavRow(label: 'Что внутри', onTap: () { Navigator.pop(context); _scrollTo(_NavSection.inside); }),
              _MobileNavRow(label: 'Как работает', onTap: () { Navigator.pop(context); _scrollTo(_NavSection.how); }),
              _MobileNavRow(label: 'Кейсы', onTap: () { Navigator.pop(context); _scrollTo(_NavSection.cases); }),
              _MobileNavRow(label: 'Гайд', onTap: () { Navigator.pop(context); _scrollTo(_NavSection.guide); }),
              _MobileNavRow(label: 'FAQ', onTap: () { Navigator.pop(context); _scrollTo(_NavSection.faq); }),
              _MobileNavRow(label: 'Контакты', onTap: () { Navigator.pop(context); _scrollTo(_NavSection.contacts); }),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: OutlinedButton(onPressed: () { Navigator.pop(context); _goLogin(context); }, child: const Text('Вход'))),
                  const SizedBox(width: 10),
                  Expanded(child: FilledButton(onPressed: () { Navigator.pop(context); _goRegister(context); }, child: const Text('Регистрация'))),
                ],
              ),
            ],
          ),
        );
      },
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
            horizontal: desktop ? 28 : 16,
            vertical: desktop ? 84 : 48,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 1100),
              child: desktop
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _HeroCopy(shimmer: _shimmerController, onLogin: () => _goLogin(context), onRegister: () => _goRegister(context))),
                        const SizedBox(width: 22),
                        const Expanded(child: _HeroPreview()),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _HeroCopy(shimmer: _shimmerController, onLogin: () => _goLogin(context), onRegister: () => _goRegister(context)),
                        const SizedBox(height: 18),
                        const _HeroPreview(),
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
        text: 'Чтобы релиз не развалился на мелочах: статусы, файлы, метаданные, сплиты.',
      ),
      _FeatureData(
        icon: Icons.auto_awesome_rounded,
        title: 'AURIX Studio AI',
        text: 'Чтобы контент не стопорил релиз: хуки, тексты, сценарии Reels — по делу.',
      ),
      _FeatureData(
        icon: Icons.dashboard_rounded,
        title: 'Dashboard',
        text: 'Чтобы видеть процесс: что готово, что зависло и что делать сегодня.',
      ),
      _FeatureData(
        icon: Icons.description_rounded,
        title: 'Content Kit',
        text: 'Чтобы не придумывать с нуля: упаковка релиза, подписи, идеи, варианты.',
      ),
      _FeatureData(
        icon: Icons.group_rounded,
        title: 'Splits & Roles',
        text: 'Чтобы не ругаться в конце: роли, доли, ответственность и контроль прав.',
      ),
      _FeatureData(
        icon: Icons.checklist_rounded,
        title: 'Release Checklist',
        text: 'Чтобы ничего не забыть: этапы, дедлайны и понятный “следующий шаг”.',
      ),
    ];

    return _Section(
      child: Column(
        children: [
          const _SectionLabel(text: 'ЧТО ВНУТРИ'),
          const SizedBox(height: 12),
          Text(
            'Всё для релиза — в одном кабинете',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: desktop ? 28 : 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.3,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Займёт 2 минуты, чтобы начать. Дальше — шаг за шагом.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.9), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 40),
          _CardsGrid(items: features.map((f) => _FeatureCard(data: f)).toList()),
        ],
      ),
    );
  }

  // ─── HOW IT WORKS ───────────────────────────────────────────────────

  Widget _buildHowItWorks(BuildContext context) {
    final desktop = _isDesktop(context);
    const steps = [
      (n: '01', title: 'Создай релиз', text: 'Название, тип, дата — и сразу видишь структуру.'),
      (n: '02', title: 'Загрузи трек и обложку', text: 'Файлы на месте, версии не теряются.'),
      (n: '03', title: 'Заполни метаданные и сплиты', text: 'Без сюрпризов и “дошли позже в личку”.'),
      (n: '04', title: 'Собери контент и план промо (AI)', text: 'Хуки, тексты, сценарии — чтобы релиз не завис.'),
    ];
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(text: 'КАК ЭТО РАБОТАЕТ'),
          const SizedBox(height: 12),
          Text(
            'Четыре шага — и релиз под контролем',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.text, fontSize: desktop ? 28 : 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 28),
          Column(
            children: steps
                .map((s) => _TimelineStep(num: s.n, title: s.title, text: s.text))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── CASES ─────────────────────────────────────────────────────────

  Widget _buildCases(BuildContext context) {
    final desktop = _isDesktop(context);
    const cases = [
      _CaseData(title: 'Сингл за 7 дней', text: 'Чек‑лист + метаданные + контент — без суеты.', icon: Icons.flash_on_rounded),
      _CaseData(title: 'EP с командой', text: 'Роли и доли фиксируются сразу, права понятны всем.', icon: Icons.groups_rounded),
      _CaseData(title: 'Промо без выгорания', text: 'AI помогает собрать план и тексты под твою музыку.', icon: Icons.auto_awesome_rounded),
    ];
    return _Section(
      child: Column(
        children: [
          const _SectionLabel(text: 'КЕЙСЫ'),
          const SizedBox(height: 12),
          Text(
            'Сценарии, под которые мы строим продукт',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.text, fontSize: desktop ? 28 : 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Text(
            'Без обещаний “чудес”. Только понятный процесс.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.9), fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 22),
          _CardsGrid(items: cases.map((c) => _CaseCard(data: c)).toList()),
          const SizedBox(height: 18),
          _UrgencyBlock(onRegister: () => _goRegister(context)),
        ],
      ),
    );
  }

  // ─── FOR WHO ───────────────────────────────────────────────────────

  Widget _buildForWho(BuildContext context) {
    return _Section(
      child: Column(
        children: [
          const _SectionLabel(text: 'ДЛЯ КОГО'),
          const SizedBox(height: 12),
          Text(
            'Кому подходит AURIX',
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
            children: List.generate(_roles.length, (i) {
              final selected = _roleIdx == i;
              return _SegmentPill(
                label: _roles[i],
                selected: selected,
                onTap: () => setState(() => _roleIdx = i),
              );
            }),
          ),
          const SizedBox(height: 18),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            switchInCurve: Curves.easeOutCubic,
            switchOutCurve: Curves.easeInCubic,
            child: _AudienceCopy(
              key: ValueKey(_roleIdx),
              role: _roles[_roleIdx],
            ),
          ),
        ],
      ),
    );
  }

  // ─── GUIDE / ARTICLES ──────────────────────────────────────────────

  Widget _buildGuide(BuildContext context) {
    final desktop = _isDesktop(context);
    final articles = <_ArticleData>[
      _ArticleData(slug: 'metadata', title: 'Метаданные: что чаще всего ломает релиз', desc: 'Поля, которые важны. Ошибки, которые дорого стоят.'),
      _ArticleData(slug: 'splits', title: 'Сплиты без скандала: как делить доли правильно', desc: 'Договориться заранее — дешевле, чем разбираться потом.'),
      _ArticleData(slug: 'cover-mistakes', title: 'Обложка: 7 ошибок, из-за которых трек выглядит дешевле', desc: 'Композиция, типичные “палевные” решения и как их убрать.'),
      _ArticleData(slug: 'checklist-14', title: 'Чек‑лист релиза: за 14 дней до публикации', desc: 'Что сделать по дням, чтобы не тушить пожары в конце.'),
      _ArticleData(slug: 'versions', title: 'Как не потерять исходники и версии', desc: 'Версии, названия, экспорт — чтобы завтра было понятно.'),
      _ArticleData(slug: 'content-7', title: 'Контент на 7 дней: промо без выгорания', desc: 'Минимальный план, который тянет релиз вперёд.'),
      _ArticleData(slug: '3-seconds', title: 'Как слушатель решает за 3 секунды', desc: 'Визуал, первый кадр, первая фраза — где теряется внимание.'),
      _ArticleData(slug: 'single-ep-album', title: 'Сингл, EP или альбом — что выбрать', desc: 'Выбор формата под твою задачу, а не “как у всех”.'),
      _ArticleData(slug: 'roles', title: 'Чистый релиз‑процесс: кто за что отвечает', desc: 'Роли, дедлайны и контроль без микроменеджмента.'),
      _ArticleData(slug: 'track-prep', title: 'Как подготовить трек к отправке: формат, громкость, экспорт', desc: 'База, которая экономит часы переписок и правок.'),
    ];

    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(text: 'ГАЙД'),
          const SizedBox(height: 12),
          Text(
            'Гайд артиста',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.text, fontSize: desktop ? 28 : 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 10),
          Text(
            'Короткие материалы, которые реально помогают собрать релиз и не потеряться в деталях.',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, height: 1.6),
          ),
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _OutlineCta(label: 'Открыть гайд', onTap: () => _openStatic('guide.html')),
                _SmallCta(label: 'Регистрация', onTap: () => _goRegister(context)),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _CardsGrid(
            items: articles
                .map((a) => _ArticleCard(
                      data: a,
                      onTap: () => _openStatic('articles/${a.slug}.html'),
                    ))
                .toList(),
          ),
        ],
      ),
    );
  }

  // ─── FAQ ───────────────────────────────────────────────────────────

  Widget _buildFaq(BuildContext context) {
    final desktop = _isDesktop(context);
    final items = const <({String q, String a})>[
      (q: 'Чем AURIX отличается от заметок/таблиц?', a: 'Таблица хранит данные. AURIX держит процесс: статус, следующий шаг, файлы, метаданные и контент — в одном месте.'),
      (q: 'Мне подойдёт, если я новичок?', a: 'Да. Важно не “знать всё”, а идти по шагам. AURIX подсказывает структуру и не даёт потерять базу.'),
      (q: 'Это дистрибуция или кабинет релиза?', a: 'Это кабинет релиза: подготовка, контроль, материалы и AI‑инструменты.'),
      (q: 'AI заменит продюсера?', a: 'Нет. AI ускоряет рутину: черновики текстов, хуки, план контента. Решения остаются за тобой.'),
      (q: 'Сколько времени займёт подготовка релиза?', a: 'Если всё готово — старт занимает пару минут. Дальше ты просто закрываешь шаги по мере готовности.'),
      (q: 'Что с правами и сплитами?', a: 'Сплиты фиксируются заранее. В продукте — роли и контроль, чтобы не “вспоминать потом”.'),
      (q: 'Можно ли работать командой?', a: 'В разработке. Сейчас можно вести процесс централизованно и делиться результатами.'),
      (q: 'Где хранятся файлы?', a: 'Файлы загружаются в облачное хранилище проекта (Supabase Storage).'),
      (q: 'Можно ли пользоваться бесплатно?', a: 'Есть базовый доступ для старта. Тарифы и подписка — в развитии продукта.'),
    ];
    return _Section(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const _SectionLabel(text: 'FAQ'),
          const SizedBox(height: 12),
          Text(
            'Вопросы — коротко и по делу',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.text, fontSize: desktop ? 28 : 22, fontWeight: FontWeight.w700, letterSpacing: -0.3),
          ),
          const SizedBox(height: 18),
          ...items.map((it) => _FaqTile(q: it.q, a: it.a)),
          const SizedBox(height: 18),
          Center(
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _SmallCta(label: 'Регистрация', onTap: () => _goRegister(context)),
                _OutlineCta(label: 'Вход', onTap: () => _goLogin(context)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── FOOTER ────────────────────────────────────────────────────────

  Widget _buildFooterExpanded(BuildContext context) {
    final desktop = _isDesktop(context);
    return Padding(
      padding: EdgeInsets.fromLTRB(desktop ? 28 : 16, 18, desktop ? 28 : 16, _isNarrow(context) ? 92 : 28),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(
              color: AurixTokens.glass(0.035),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AurixTokens.stroke(0.14)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    const Text('AURIX', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 4)),
                    const Spacer(),
                    if (desktop)
                      Wrap(
                        spacing: 14,
                        children: [
                          _FooterLink(label: 'Гайд', onTap: () => _openStatic('guide.html')),
                          _FooterLink(label: 'FAQ', onTap: () => _scrollTo(_NavSection.faq)),
                          _FooterLink(label: 'Контакты', onTap: () => _scrollTo(_NavSection.contacts)),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  'Контакты',
                  style: TextStyle(color: AurixTokens.text.withValues(alpha: 0.9), fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  'Почта и Telegram можно добавить позже — сейчас оставил аккуратные заглушки.',
                  style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: const [
                    _ContactChip(icon: Icons.email_rounded, label: 'support@aurix.app'),
                    _ContactChip(icon: Icons.send_rounded, label: '@aurix_support'),
                  ],
                ),
                const SizedBox(height: 16),
                Divider(color: AurixTokens.stroke(0.14), height: 1),
                const SizedBox(height: 14),
                Text(
                  'AURIX by Armen Balasanyan',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.65), fontSize: 12, letterSpacing: 0.2),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMobileCtaBar(BuildContext context) {
    final inset = MediaQuery.viewInsetsOf(context);
    if (inset.bottom > 0) return const SizedBox.shrink();
    return Positioned(
      left: 0,
      right: 0,
      bottom: 0,
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
          decoration: BoxDecoration(
            color: AurixTokens.bg0.withValues(alpha: 0.88),
            border: Border(top: BorderSide(color: AurixTokens.stroke(0.14))),
          ),
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _goLogin(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AurixTokens.text,
                    side: BorderSide(color: AurixTokens.stroke(0.24)),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Вход'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: () => _goRegister(context),
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    textStyle: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  child: const Text('Регистрация'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════
// NEW LANDING PARTS
// ═══════════════════════════════════════════════════════════════════════

class _BrandMark extends StatelessWidget {
  final VoidCallback onTap;
  const _BrandMark({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: ShaderMask(
          shaderCallback: (b) => const LinearGradient(
            colors: [AurixTokens.orange, AurixTokens.orange2],
          ).createShader(b),
          child: const Text(
            'AURIX',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w900,
              letterSpacing: 4,
            ),
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;
  const _NavItem({required this.label, required this.active, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            color: active ? AurixTokens.glass(0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: active ? AurixTokens.orange.withValues(alpha: 0.25) : Colors.transparent),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: active ? AurixTokens.text : AurixTokens.textSecondary,
              fontSize: 13,
              fontWeight: active ? FontWeight.w700 : FontWeight.w500,
              letterSpacing: 0.2,
            ),
          ),
        ),
      ),
    );
  }
}

class _MobileNavRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _MobileNavRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      title: Text(label, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700)),
      trailing: Icon(Icons.chevron_right_rounded, color: AurixTokens.muted.withValues(alpha: 0.7)),
    );
  }
}

class _HeroCopy extends StatelessWidget {
  final AnimationController shimmer;
  final VoidCallback onRegister;
  final VoidCallback onLogin;
  const _HeroCopy({required this.shimmer, required this.onRegister, required this.onLogin});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 960;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Релиз без хаоса.',
          style: TextStyle(
            color: AurixTokens.text,
            fontSize: desktop ? 52 : 32,
            fontWeight: FontWeight.w900,
            height: 1.05,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 14),
        Text(
          'Файлы, метаданные, сплиты, контент и AI‑инструменты — в одном кабинете.\n'
          'Без таблиц и вечных “скинь ещё раз”.',
          style: TextStyle(
            color: AurixTokens.textSecondary,
            fontSize: desktop ? 17 : 15,
            height: 1.65,
          ),
        ),
        const SizedBox(height: 22),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _PrimaryCta(label: 'Регистрация', shimmer: shimmer, onTap: onRegister),
            _OutlineCta(label: 'Вход', onTap: onLogin),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'Займёт 2 минуты. Дальше — всё по шагам.',
          style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.95), fontSize: 13),
        ),
        const SizedBox(height: 18),
        Wrap(
          spacing: 12,
          runSpacing: 10,
          children: const [
            _MiniBullet(icon: Icons.checklist_rounded, text: 'Релиз под ключ'),
            _MiniBullet(icon: Icons.auto_awesome_rounded, text: 'AI‑студия'),
            _MiniBullet(icon: Icons.track_changes_rounded, text: 'Контроль процесса'),
          ],
        ),
      ],
    );
  }
}

class _MiniBullet extends StatelessWidget {
  final IconData icon;
  final String text;
  const _MiniBullet({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 18, color: AurixTokens.orange),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _HeroPreview extends StatelessWidget {
  const _HeroPreview();

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 960;
    return Container(
      height: desktop ? 420 : 320,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AurixTokens.bg1,
        border: Border.all(color: AurixTokens.stroke(0.18)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(20),
        child: Stack(
          children: [
            Positioned.fill(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(-0.25, -0.15),
                    radius: 1.2,
                    colors: [
                      AurixTokens.orange.withValues(alpha: 0.16),
                      AurixTokens.orange.withValues(alpha: 0.05),
                      Colors.transparent,
                    ],
                    stops: const [0, 0.45, 1],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 34,
                        height: 34,
                        decoration: BoxDecoration(
                          color: AurixTokens.glass(0.06),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: AurixTokens.stroke(0.14)),
                        ),
                        child: const Icon(Icons.auto_awesome_rounded, size: 18, color: AurixTokens.orange),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'AURIX Studio AI',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800),
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AurixTokens.orange.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.22)),
                        ),
                        child: const Text('Готовим релиз', style: TextStyle(color: AurixTokens.orange, fontSize: 11, fontWeight: FontWeight.w800)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  Expanded(
                    child: Row(
                      children: [
                        Expanded(child: _PreviewCard(title: 'Релизы', rows: ['Сингл • draft', 'EP • review', 'Альбом • план'])),
                        const SizedBox(width: 12),
                        Expanded(child: _PreviewCard(title: 'Чек‑лист', rows: ['Обложка', 'ISRC/UPC', 'Сплиты', 'Контент'])),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AurixTokens.glass(0.05),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: AurixTokens.stroke(0.14)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.bolt_rounded, size: 18, color: AurixTokens.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Следующий шаг: заполнить метаданные и сплиты',
                            style: TextStyle(color: AurixTokens.textSecondary, fontSize: desktop ? 13 : 12, height: 1.35),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                          decoration: BoxDecoration(
                            color: AurixTokens.orange,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Text('Открыть', style: TextStyle(color: Colors.black, fontWeight: FontWeight.w900, fontSize: 12)),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewCard extends StatelessWidget {
  final String title;
  final List<String> rows;
  const _PreviewCard({required this.title, required this.rows});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w900, fontSize: 13)),
          const SizedBox(height: 10),
          ...rows.map((r) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(width: 6, height: 6, decoration: BoxDecoration(color: AurixTokens.orange.withValues(alpha: 0.9), shape: BoxShape.circle)),
                    const SizedBox(width: 8),
                    Expanded(child: Text(r, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12), overflow: TextOverflow.ellipsis)),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _CardsGrid extends StatelessWidget {
  final List<Widget> items;
  const _CardsGrid({required this.items});

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final cols = w >= 1100 ? 3 : (w >= 840 ? 2 : 1);
    final rows = <Widget>[];
    for (var i = 0; i < items.length; i += cols) {
      final slice = items.sublist(i, math.min(i + cols, items.length));
      rows.add(Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (var j = 0; j < slice.length; j++) Expanded(child: slice[j]),
          if (slice.length < cols)
            for (var k = 0; k < cols - slice.length; k++) const Expanded(child: SizedBox.shrink()),
        ],
      ));
    }
    return Column(children: rows);
  }
}

class _FxCard extends StatelessWidget {
  final Widget child;
  final bool enabled;
  final VoidCallback? onTap;
  const _FxCard({required this.child, required this.enabled, this.onTap});

  @override
  Widget build(BuildContext context) {
    return TiltGlowCard(
      enabled: enabled,
      onTap: onTap,
      padding: EdgeInsets.zero,
      child: child,
    );
  }
}

class _TimelineStep extends StatelessWidget {
  final String num;
  final String title;
  final String text;
  const _TimelineStep({required this.num, required this.title, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.22)),
            ),
            alignment: Alignment.center,
            child: Text(num, style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w900)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w900, fontSize: 15)),
                const SizedBox(height: 6),
                Text(text, style: TextStyle(color: AurixTokens.textSecondary, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CaseData {
  final String title;
  final String text;
  final IconData icon;
  const _CaseData({required this.title, required this.text, required this.icon});
}

class _CaseCard extends StatelessWidget {
  final _CaseData data;
  const _CaseCard({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.all(6),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(data.icon, color: AurixTokens.orange, size: 20),
          ),
          const SizedBox(height: 14),
          Text(data.title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          Text(data.text, style: TextStyle(color: AurixTokens.textSecondary, height: 1.5)),
        ],
      ),
    );
  }
}

class _UrgencyBlock extends StatelessWidget {
  final VoidCallback onRegister;
  const _UrgencyBlock({required this.onRegister});

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 960;
    const reasons = [
      _ReasonData(num: '01', title: 'Алгоритмы любят регулярность', text: 'Чем ровнее график — тем проще удерживать внимание.'),
      _ReasonData(num: '02', title: 'Сроки = внимание', text: 'Когда дедлайн уплыл — релиз теряет момент.'),
      _ReasonData(num: '03', title: 'Хаос убивает релиз', text: 'Файлы, версии и договорённости должны быть в одном месте.'),
    ];
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AurixTokens.stroke(0.16)),
      ),
      child: Column(
        children: [
          Text('Пока ты тянешь — релиз стареет.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.text, fontSize: desktop ? 22 : 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _CardsGrid(items: reasons.map((r) => _ReasonCard(data: r)).toList()),
          const SizedBox(height: 14),
          _SmallCta(label: 'Регистрация', onTap: onRegister),
        ],
      ),
    );
  }
}

class _SegmentPill extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _SegmentPill({required this.label, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? AurixTokens.orange.withValues(alpha: 0.12) : AurixTokens.glass(0.04),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: selected ? AurixTokens.orange.withValues(alpha: 0.28) : AurixTokens.stroke(0.14)),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: selected ? AurixTokens.orange : AurixTokens.text,
            fontWeight: FontWeight.w800,
            fontSize: 13,
          ),
        ),
      ),
    );
  }
}

class _AudienceCopy extends StatelessWidget {
  final String role;
  const _AudienceCopy({super.key, required this.role});

  @override
  Widget build(BuildContext context) {
    final copy = switch (role) {
      'Артист' => (
          t: 'Собирай релиз как систему, а не как папку на рабочем столе.',
          bullets: ['Статусы и дедлайны без хаоса', 'Контент и тексты под релиз', 'Один кабинет вместо 5 сервисов']
        ),
      'Продюсер' => (
          t: 'Держи процесс и коммуникацию в одном месте — меньше “куда залить?” и “какая версия?”.',
          bullets: ['Версии файлов и структура релиза', 'Контроль задач и статусов', 'Быстрые AI‑черновики для промо']
        ),
      'Лейбл' => (
          t: 'Стандартизируй подготовку релизов, чтобы команда работала одинаково аккуратно.',
          bullets: ['Единые правила метаданных', 'Роли и сплиты заранее', 'Контроль по этапам']
        ),
      'Менеджер' => (
          t: 'Веди релизы и промо без вечных таблиц: что сделано, что зависло, что дальше.',
          bullets: ['Чек‑лист и дедлайны', 'Материалы под контент', 'Понятный следующий шаг']
        ),
      _ => (
          t: 'Собери структуру релиза и договорённости заранее — чтобы творчество не тонуло в быту.',
          bullets: ['Чёткая роль в процессе', 'Материалы и версии на месте', 'Контроль без лишней рутины']
        ),
    };

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(copy.t, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, height: 1.6)),
          const SizedBox(height: 12),
          ...copy.bullets.map((b) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    const Icon(Icons.check_rounded, size: 18, color: AurixTokens.orange),
                    const SizedBox(width: 8),
                    Expanded(child: Text(b, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700))),
                  ],
                ),
              )),
        ],
      ),
    );
  }
}

class _ArticleData {
  final String slug;
  final String title;
  final String desc;
  const _ArticleData({required this.slug, required this.title, required this.desc});
}

class _ArticleCard extends StatelessWidget {
  final _ArticleData data;
  final VoidCallback onTap;
  const _ArticleCard({required this.data, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.all(6),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AurixTokens.glass(0.035),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AurixTokens.stroke(0.14)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              data.title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w900, height: 1.2),
            ),
            const SizedBox(height: 10),
            Text(
              data.desc,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: AurixTokens.textSecondary, height: 1.5),
            ),
            const SizedBox(height: 14),
            Text('Читать →', style: TextStyle(color: AurixTokens.orange.withValues(alpha: 0.95), fontWeight: FontWeight.w900)),
          ],
        ),
      ),
    );
  }
}

class _FaqTile extends StatefulWidget {
  final String q;
  final String a;
  const _FaqTile({required this.q, required this.a});

  @override
  State<_FaqTile> createState() => _FaqTileState();
}

class _FaqTileState extends State<_FaqTile> {
  bool _open = false;
  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.035),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: InkWell(
        onTap: () => setState(() => _open = !_open),
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.q,
                      style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w900),
                    ),
                  ),
                  Icon(_open ? Icons.expand_less_rounded : Icons.expand_more_rounded, color: AurixTokens.muted),
                ],
              ),
              AnimatedCrossFade(
                duration: const Duration(milliseconds: 180),
                crossFadeState: _open ? CrossFadeState.showSecond : CrossFadeState.showFirst,
                firstChild: const SizedBox.shrink(),
                secondChild: Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Text(
                    widget.a,
                    style: TextStyle(color: AurixTokens.textSecondary, height: 1.55),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FooterLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _FooterLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        child: Text(label, style: TextStyle(color: AurixTokens.textSecondary, fontWeight: FontWeight.w700, fontSize: 12)),
      ),
    );
  }
}

class _ContactChip extends StatelessWidget {
  final IconData icon;
  final String label;
  const _ContactChip({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.04),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AurixTokens.stroke(0.14)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AurixTokens.orange),
          const SizedBox(width: 8),
          Text(label, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 12)),
        ],
      ),
    );
  }
}

/// Very small helper to re-measure section offsets on resize.
class _MetricsObserver with WidgetsBindingObserver {
  static final _instance = _MetricsObserver._();
  _MetricsObserver._();

  VoidCallback? _onChanged;

  static void ensure(VoidCallback onChanged) {
    final inst = _instance;
    inst._onChanged = onChanged;
    WidgetsBinding.instance.addObserver(inst);
  }

  @override
  void didChangeMetrics() {
    _onChanged?.call();
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
    final perf = MediaQuery.of(context).size.width < 900;
    return Padding(
      padding: const EdgeInsets.all(6),
      child: MouseRegion(
        onEnter: (_) => setState(() => _hovered = true),
        onExit: (_) => setState(() => _hovered = false),
        child: _FxCard(
          enabled: !perf,
          child: Padding(
            padding: const EdgeInsets.all(22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    color: AurixTokens.orange.withValues(alpha: 0.10),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AurixTokens.orange.withValues(alpha: _hovered ? 0.26 : 0.16)),
                  ),
                  child: Icon(widget.data.icon, color: AurixTokens.orange, size: 20),
                ),
                const SizedBox(height: 16),
                Text(
                  widget.data.title,
                  style: const TextStyle(
                    color: AurixTokens.text,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  widget.data.text,
                  style: TextStyle(
                    color: AurixTokens.textSecondary,
                    fontSize: 14,
                    height: 1.55,
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
