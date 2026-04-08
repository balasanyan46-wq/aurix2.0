import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/casting/data/casting_repository.dart';
import 'package:aurix_flutter/features/casting/domain/casting_application.dart';

// ═══════════════════════════════════════════════════════════
// КОД АРТИСТА — PREMIUM LANDING
// ═══════════════════════════════════════════════════════════

const _kCities = <String, String>{
  'Москва': '24 мая',
  'Санкт-Петербург': '31 мая',
  'Воронеж': '7 июня',
  'Ростов-на-Дону': '14 июня',
  'Краснодар': '21 июня',
  'Сочи': '28 июня',
};

class CastingLandingPage extends StatefulWidget {
  const CastingLandingPage({super.key});
  @override
  State<CastingLandingPage> createState() => _CastingLandingPageState();
}

class _CastingLandingPageState extends State<CastingLandingPage>
    with TickerProviderStateMixin {
  final _sc = ScrollController();
  double _scrollY = 0;
  String? _selectedCity;
  CastingSlots? _slots;

  late final AnimationController _pressureCtrl;
  int _mockApplicants = 214;
  int _mockSeatsLeft = 17;

  @override
  void initState() {
    super.initState();
    _sc.addListener(() {
      if (mounted) setState(() => _scrollY = _sc.offset);
    });
    _pressureCtrl = AnimationController(
        vsync: this, duration: const Duration(seconds: 8))
      ..addStatusListener((s) {
        if (s == AnimationStatus.completed) {
          setState(() {
            _mockApplicants += math.Random().nextInt(3) + 1;
            if (_mockSeatsLeft > 3) {
              _mockSeatsLeft -= math.Random().nextInt(2);
            }
          });
          _pressureCtrl.forward(from: 0);
        }
      })
      ..forward();
  }

  Future<void> _loadSlots(String city) async {
    try {
      final s = await CastingRepository.instance.getSlots(city);
      if (mounted) setState(() => _slots = s);
    } catch (_) {}
  }

  @override
  void dispose() {
    _sc.dispose();
    _pressureCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final dk = w > 800;
    final hp = dk ? 80.0 : 24.0;
    const mw = 1080.0;

    return Scaffold(
      backgroundColor: const Color(0xFF050507),
      body: Stack(children: [
        // ── Atmospheric orbs — subtle, cinematic ──
        _ParallaxOrb(
            scrollY: _scrollY,
            factor: 0.12,
            top: -300,
            left: -200,
            size: 800,
            color: AurixTokens.accent.withValues(alpha: 0.05)),
        _ParallaxOrb(
            scrollY: _scrollY,
            factor: 0.06,
            top: 800,
            right: -300,
            size: 900,
            color: AurixTokens.aiAccent.withValues(alpha: 0.03)),
        _ParallaxOrb(
            scrollY: _scrollY,
            factor: 0.08,
            top: 2400,
            left: w * 0.4,
            size: 600,
            color: AurixTokens.accent.withValues(alpha: 0.04)),

        // ── Content ──
        CustomScrollView(controller: _sc, slivers: [
          // ═══ NAVBAR ═══
          SliverToBoxAdapter(
              child: _Navbar(onBack: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/home');
            }
          })),

          // ═══ 1. HERO ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 120 : 64, hp, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Reveal(
                      child: Text('КОД\nАРТИСТА',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontDisplay,
                            color: AurixTokens.text,
                            fontSize: dk ? 96 : 52,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -3,
                            height: 0.88,
                          ))),
                  SizedBox(height: dk ? 32 : 24),
                  _Reveal(
                      d: 120,
                      child: SizedBox(
                          width: dk ? 520 : double.infinity,
                          child: Text(
                            'Ты выходишь на сцену.\nМы смотрим.',
                            style: TextStyle(
                              fontFamily: AurixTokens.fontHeading,
                              color: AurixTokens.accent,
                              fontSize: dk ? 24 : 18,
                              fontWeight: FontWeight.w700,
                              height: 1.4,
                            ),
                          ))),
                  SizedBox(height: dk ? 48 : 32),
                  _Reveal(
                      d: 240,
                      child: _PulseCTA(
                          label: 'ЗАБРАТЬ СЛОТ',
                          onTap: () => context.push('/casting/apply'))),
                  const SizedBox(height: 24),
                  _Reveal(
                      d: 340,
                      child: _LivePressure(
                          applicants: _mockApplicants,
                          seatsLeft: _mockSeatsLeft)),
                ]),
          )),

          // ═══ 2. WHAT IS THIS ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 180 : 120, hp, 0),
            child: _Reveal(
                child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _Label('О ПРОЕКТЕ'),
                const SizedBox(height: 20),
                Text('Живой отбор артистов.',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontDisplay,
                      color: AurixTokens.text,
                      fontSize: dk ? 44 : 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: -1.5,
                      height: 1.1,
                    )),
                SizedBox(height: dk ? 24 : 16),
                SizedBox(
                    width: dk ? 560 : double.infinity,
                    child: Text(
                      'Одна сцена. Живой звук. Жюри из индустрии.\nЛучшие получают контракт и деньги.',
                      style: TextStyle(
                        color: AurixTokens.textSecondary,
                        fontSize: dk ? 18 : 15,
                        height: 1.8,
                      ),
                    )),
              ],
            )),
          )),

          // ═══ 3. WHAT YOU GET — visual cards ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 180 : 120, hp, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Reveal(child: _Label('ЧТО БУДЕТ')),
                  const SizedBox(height: 32),
                  _Reveal(
                      child: Text('На мероприятии',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontDisplay,
                            color: AurixTokens.text,
                            fontSize: dk ? 44 : 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ))),
                  SizedBox(height: dk ? 48 : 32),
                  LayoutBuilder(builder: (context, constraints) {
                    final cols = dk ? 3 : 2;
                    final gap = dk ? 16.0 : 12.0;
                    final cw =
                        (constraints.maxWidth - gap * (cols - 1)) / cols;
                    return Wrap(
                        spacing: gap,
                        runSpacing: gap,
                        children: [
                          _Reveal(
                              d: 60,
                              child: _FeatureCard(
                                  w: cw,
                                  icon: Icons.stadium_rounded,
                                  title: 'Живая сцена',
                                  sub: 'Профессиональный звук и свет')),
                          _Reveal(
                              d: 120,
                              child: _FeatureCard(
                                  w: cw,
                                  icon: Icons.groups_rounded,
                                  title: 'Жюри из индустрии',
                                  sub: 'Продюсеры и A&R менеджеры')),
                          _Reveal(
                              d: 180,
                              child: _FeatureCard(
                                  w: cw,
                                  icon: Icons.videocam_rounded,
                                  title: 'Видеосъёмка',
                                  sub: 'Многокамерная запись')),
                          _Reveal(
                              d: 240,
                              child: _FeatureCard(
                                  w: cw,
                                  icon: Icons.emoji_events_rounded,
                                  title: 'Денежные призы',
                                  sub: 'Реальные деньги, не грамоты')),
                          _Reveal(
                              d: 300,
                              child: _FeatureCard(
                                  w: cw,
                                  icon: Icons.description_rounded,
                                  title: 'Контракт',
                                  sub:
                                      'Дистрибуция, промо, стратегия')),
                          _Reveal(
                              d: 360,
                              child: _FeatureCard(
                                  w: cw,
                                  icon: Icons.people_rounded,
                                  title: 'Нетворкинг',
                                  sub: 'Связи, которые работают')),
                        ]);
                  }),
                ]),
          )),

          // ═══ 4. HOW IT WORKS — 3 steps ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 180 : 120, hp, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Reveal(child: _Label('КАК ЭТО РАБОТАЕТ')),
                  const SizedBox(height: 32),
                  _Reveal(
                      child: Text('Три шага',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontDisplay,
                            color: AurixTokens.text,
                            fontSize: dk ? 44 : 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ))),
                  SizedBox(height: dk ? 56 : 40),
                  _Reveal(
                      d: 80,
                      child: _Step(
                          n: '01',
                          title: 'Забираешь слот',
                          desc:
                              'Выбираешь город и тариф. Место — твоё.',
                          dk: dk)),
                  _Reveal(
                      d: 180,
                      child: _Step(
                          n: '02',
                          title: 'Выходишь на сцену',
                          desc:
                              'Живой звук. Живая публика. Живое жюри.',
                          dk: dk)),
                  _Reveal(
                      d: 280,
                      child: _Step(
                          n: '03',
                          title: 'Получаешь результат',
                          desc:
                              'Разбор от жюри. Лучшие — контракт и деньги.',
                          dk: dk,
                          last: true)),
                ]),
          )),

          // ═══ 5. CITIES ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 180 : 120, hp, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Reveal(child: _Label('ГЕОГРАФИЯ')),
                  const SizedBox(height: 32),
                  _Reveal(
                      child: Text('Выбери город',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontDisplay,
                            color: AurixTokens.text,
                            fontSize: dk ? 44 : 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ))),
                  const SizedBox(height: 12),
                  _Reveal(
                      child: Text('6 городов · 50 мест в каждом',
                          style: TextStyle(
                              color: AurixTokens.muted, fontSize: 14))),
                  SizedBox(height: dk ? 48 : 32),
                  _Reveal(
                      d: 100,
                      child: LayoutBuilder(builder: (context, constraints) {
                        final cols = dk ? 3 : 2;
                        final gap = dk ? 14.0 : 10.0;
                        final cw =
                            (constraints.maxWidth - gap * (cols - 1)) / cols;
                        return Wrap(
                            spacing: gap,
                            runSpacing: gap,
                            children: _kCities.entries
                                .map((e) => _CityCard(
                                      city: e.key,
                                      date: e.value,
                                      width: cw,
                                      selected: _selectedCity == e.key,
                                      slots: _selectedCity == e.key
                                          ? _slots
                                          : null,
                                      onTap: () {
                                        setState(
                                            () => _selectedCity = e.key);
                                        _loadSlots(e.key);
                                      },
                                    ))
                                .toList());
                      })),
                  if (_selectedCity != null && _slots != null) ...[
                    const SizedBox(height: 20),
                    _SlotsIndicator(
                        city: _selectedCity!, slots: _slots!),
                  ],
                ]),
          )),

          // ═══ 6. PRICING ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 180 : 120, hp, 0),
            child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _Reveal(child: _Label('ТАРИФЫ')),
                  const SizedBox(height: 32),
                  _Reveal(
                      child: Text('Забери слот',
                          style: TextStyle(
                            fontFamily: AurixTokens.fontDisplay,
                            color: AurixTokens.text,
                            fontSize: dk ? 44 : 28,
                            fontWeight: FontWeight.w900,
                            letterSpacing: -1.5,
                          ))),
                  SizedBox(height: dk ? 48 : 32),
                  _Reveal(
                      d: 100,
                      child: dk
                          ? Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                  Expanded(
                                      child: _PriceCard(
                                    name: 'BASE',
                                    price: '990 ₽',
                                    sub: 'попробовать',
                                    color: AurixTokens.muted,
                                    featured: false,
                                    perks: const [
                                      '5 минут на сцене',
                                      'Участие в отборе',
                                      'Шанс на контракт',
                                    ],
                                    onTap: () =>
                                        context.push('/casting/apply'),
                                  )),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: _PriceCard(
                                    name: 'PRO',
                                    price: '2 990 ₽',
                                    sub: 'оптимальный',
                                    color: AurixTokens.accent,
                                    featured: true,
                                    perks: const [
                                      '10 минут на сцене',
                                      'Обратная связь от жюри',
                                      'Видеозапись выступления',
                                      'Увеличенные шансы',
                                    ],
                                    onTap: () =>
                                        context.push('/casting/apply'),
                                  )),
                                  const SizedBox(width: 14),
                                  Expanded(
                                      child: _PriceCard(
                                    name: 'VIP',
                                    price: '5 990 ₽',
                                    sub: 'максимум',
                                    color: AurixTokens.aiAccent,
                                    featured: false,
                                    perks: const [
                                      '15 минут на сцене',
                                      'Личный разбор от A&R',
                                      'Видео + промо-ролик',
                                      'Приоритет при отборе',
                                      'Первый на контракт',
                                    ],
                                    onTap: () =>
                                        context.push('/casting/apply'),
                                  )),
                                ])
                          : Column(children: [
                              _PriceCard(
                                name: 'PRO',
                                price: '2 990 ₽',
                                sub: 'оптимальный',
                                color: AurixTokens.accent,
                                featured: true,
                                perks: const [
                                  '10 минут на сцене',
                                  'Обратная связь от жюри',
                                  'Видеозапись выступления',
                                  'Увеличенные шансы',
                                ],
                                onTap: () =>
                                    context.push('/casting/apply'),
                              ),
                              const SizedBox(height: 12),
                              _PriceCard(
                                name: 'VIP',
                                price: '5 990 ₽',
                                sub: 'максимум',
                                color: AurixTokens.aiAccent,
                                featured: false,
                                perks: const [
                                  '15 минут на сцене',
                                  'Личный разбор от A&R',
                                  'Видео + промо-ролик',
                                  'Приоритет при отборе',
                                  'Первый на контракт',
                                ],
                                onTap: () =>
                                    context.push('/casting/apply'),
                              ),
                              const SizedBox(height: 12),
                              _PriceCard(
                                name: 'BASE',
                                price: '990 ₽',
                                sub: 'попробовать',
                                color: AurixTokens.muted,
                                featured: false,
                                perks: const [
                                  '5 минут на сцене',
                                  'Участие в отборе',
                                  'Шанс на контракт',
                                ],
                                onTap: () =>
                                    context.push('/casting/apply'),
                              ),
                            ])),
                  const SizedBox(height: 24),
                  _Reveal(
                      d: 200,
                      child: Center(
                          child: GestureDetector(
                        onTap: () =>
                            context.push('/casting/apply?type=audience'),
                        child: Text(
                          'Не выступаешь? Билет зрителя — 1 000 ₽',
                          style: TextStyle(
                            color: AurixTokens.aiAccent,
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                            decorationColor:
                                AurixTokens.aiAccent.withValues(alpha: 0.4),
                          ),
                        ),
                      ))),
                ]),
          )),

          // ═══ 7. FOUNDER BLOCK ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 180 : 120, hp, 0),
            child: _Reveal(child: _FounderCard(dk: dk)),
          )),

          // ═══ 8. FINAL CTA ═══
          SliverToBoxAdapter(
              child: _Sec(
            mw: mw,
            p: EdgeInsets.fromLTRB(hp, dk ? 180 : 120, hp, 0),
            child: _Reveal(
                child: Center(
                    child: Column(children: [
              Text(
                'Если не сейчас —\nтогда когда?',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontFamily: AurixTokens.fontDisplay,
                  color: AurixTokens.text,
                  fontSize: dk ? 56 : 32,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -2,
                  height: 1.0,
                ),
              ),
              SizedBox(height: dk ? 28 : 20),
              SizedBox(
                  width: dk ? 420 : double.infinity,
                  child: Text(
                    'Можешь закрыть эту страницу.\nА можешь выйти на сцену.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AurixTokens.textSecondary,
                      fontSize: dk ? 17 : 15,
                      height: 1.8,
                    ),
                  )),
              const SizedBox(height: 48),
              _PulseCTA(
                  label: 'Я ИДУ',
                  onTap: () => context.push('/casting/apply')),
              const SizedBox(height: 20),
              Text('$_mockSeatsLeft мест осталось',
                  style: TextStyle(
                    color: AurixTokens.muted,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  )),
            ]))),
          )),

          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ]),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════
// COMPONENTS
// ═══════════════════════════════════════════════════════════

// ── Navbar ──

class _Navbar extends StatelessWidget {
  final VoidCallback onBack;
  const _Navbar({required this.onBack});
  @override
  Widget build(BuildContext context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: Row(children: [
        GestureDetector(
            onTap: onBack,
            child: Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: AurixTokens.surface1.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.stroke(0.1)),
                ),
                child: const Icon(Icons.arrow_back_rounded,
                    color: AurixTokens.text, size: 18))),
        const SizedBox(width: 16),
        Text('КОД АРТИСТА',
            style: TextStyle(
              fontFamily: AurixTokens.fontHeading,
              color: AurixTokens.text,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 3,
            )),
        const Spacer(),
        Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AurixTokens.danger.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              _PulseDot(c: AurixTokens.danger),
              const SizedBox(width: 8),
              const Text('LIVE',
                  style: TextStyle(
                    color: AurixTokens.danger,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1,
                  )),
            ])),
      ]));
}

// ── Live pressure ──

class _LivePressure extends StatelessWidget {
  final int applicants, seatsLeft;
  const _LivePressure({required this.applicants, required this.seatsLeft});
  @override
  Widget build(BuildContext context) => Row(children: [
        _PChip(Icons.people_rounded, '$applicants заявок',
            AurixTokens.accent),
        const SizedBox(width: 12),
        _PChip(
            Icons.event_seat_rounded,
            '$seatsLeft мест',
            seatsLeft <= 15 ? AurixTokens.danger : AurixTokens.positive),
      ]);
}

class _PChip extends StatelessWidget {
  final IconData ic;
  final String t;
  final Color c;
  const _PChip(this.ic, this.t, this.c);
  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: c.withValues(alpha: 0.15)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(ic, size: 14, color: c),
        const SizedBox(width: 8),
        Text(t,
            style: TextStyle(
                color: c, fontSize: 12, fontWeight: FontWeight.w700)),
      ]));
}

// ── Feature card ──

class _FeatureCard extends StatefulWidget {
  final double w;
  final IconData icon;
  final String title, sub;
  const _FeatureCard(
      {required this.w,
      required this.icon,
      required this.title,
      required this.sub});
  @override
  State<_FeatureCard> createState() => _FeatureCardState();
}

class _FeatureCardState extends State<_FeatureCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOut,
          width: widget.w,
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: AurixTokens.cardGradient,
            border: Border.all(
                color: _h
                    ? AurixTokens.accent.withValues(alpha: 0.3)
                    : AurixTokens.stroke(0.08)),
            boxShadow: _h
                ? [
                    BoxShadow(
                        color: AurixTokens.accent.withValues(alpha: 0.06),
                        blurRadius: 40,
                        spreadRadius: -12)
                  ]
                : null,
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AurixTokens.accent.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(widget.icon,
                        color: AurixTokens.accent, size: 22)),
                const SizedBox(height: 20),
                Text(widget.title,
                    style: const TextStyle(
                        color: AurixTokens.text,
                        fontSize: 15,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text(widget.sub,
                    style: const TextStyle(
                        color: AurixTokens.muted,
                        fontSize: 13,
                        height: 1.5)),
              ])));
}

// ── Step ──

class _Step extends StatelessWidget {
  final String n, title, desc;
  final bool dk;
  final bool last;
  const _Step(
      {required this.n,
      required this.title,
      required this.desc,
      required this.dk,
      this.last = false});
  @override
  Widget build(BuildContext context) => Padding(
      padding: EdgeInsets.only(bottom: last ? 0 : (dk ? 48 : 36)),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Column(children: [
          Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: AurixTokens.accent.withValues(alpha: 0.06),
                border:
                    Border.all(color: AurixTokens.accent.withValues(alpha: 0.18)),
              ),
              child: Center(
                  child: Text(n,
                      style: TextStyle(
                        fontFamily: AurixTokens.fontMono,
                        color: AurixTokens.accent,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      )))),
          if (!last)
            Container(
                width: 1,
                height: dk ? 48 : 36,
                color: AurixTokens.stroke(0.12)),
        ]),
        SizedBox(width: dk ? 28 : 20),
        Expanded(
            child: Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          style: TextStyle(
                            color: AurixTokens.text,
                            fontSize: dk ? 20 : 17,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 8),
                      Text(desc,
                          style: TextStyle(
                            color: AurixTokens.muted,
                            fontSize: dk ? 15 : 13,
                            height: 1.6,
                          )),
                    ]))),
      ]));
}

// ── City card ──

class _CityCard extends StatefulWidget {
  final String city, date;
  final double width;
  final bool selected;
  final CastingSlots? slots;
  final VoidCallback onTap;
  const _CityCard(
      {required this.city,
      required this.date,
      required this.width,
      required this.selected,
      this.slots,
      required this.onTap});
  @override
  State<_CityCard> createState() => _CityCardState();
}

class _CityCardState extends State<_CityCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final on = widget.selected || _h;
    return MouseRegion(
        onEnter: (_) => setState(() => _h = true),
        onExit: (_) => setState(() => _h = false),
        child: GestureDetector(
            onTap: widget.onTap,
            child: AnimatedContainer(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOut,
                width: widget.width,
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(18),
                  gradient: AurixTokens.cardGradient,
                  border: Border.all(
                      color: on
                          ? AurixTokens.accent.withValues(alpha: 0.5)
                          : AurixTokens.stroke(0.08),
                      width: on ? 1.5 : 1),
                  boxShadow: on
                      ? [
                          BoxShadow(
                              color:
                                  AurixTokens.accent.withValues(alpha: 0.08),
                              blurRadius: 32,
                              spreadRadius: -10)
                        ]
                      : null,
                ),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(widget.city,
                          style: TextStyle(
                            color: on
                                ? AurixTokens.text
                                : AurixTokens.textSecondary,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          )),
                      const SizedBox(height: 8),
                      Text(widget.date,
                          style: TextStyle(
                            fontFamily: AurixTokens.fontMono,
                            color: on
                                ? AurixTokens.accent
                                : AurixTokens.muted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                          )),
                      if (widget.selected && widget.slots != null) ...[
                        const SizedBox(height: 14),
                        Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 10, vertical: 5),
                            decoration: BoxDecoration(
                              color: (widget.slots!.remaining <= 10
                                      ? AurixTokens.danger
                                      : AurixTokens.positive)
                                  .withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                                '${widget.slots!.remaining} мест',
                                style: TextStyle(
                                  color: widget.slots!.remaining <= 10
                                      ? AurixTokens.danger
                                      : AurixTokens.positive,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ))),
                      ],
                    ]))));
  }
}

class _SlotsIndicator extends StatelessWidget {
  final String city;
  final CastingSlots slots;
  const _SlotsIndicator({required this.city, required this.slots});
  @override
  Widget build(BuildContext context) {
    final c =
        slots.remaining <= 10 ? AurixTokens.danger : AurixTokens.positive;
    return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: c.withValues(alpha: 0.04),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: c.withValues(alpha: 0.15)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Icon(Icons.event_seat_rounded, color: c, size: 16),
            const SizedBox(width: 10),
            Text('$city — ${slots.remaining} из ${slots.total}',
                style: TextStyle(
                    color: c, fontSize: 13, fontWeight: FontWeight.w700)),
          ]),
          const SizedBox(height: 10),
          ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                  value: slots.taken / slots.total,
                  minHeight: 4,
                  backgroundColor: c.withValues(alpha: 0.08),
                  color: c)),
        ]));
  }
}

// ── Pricing card ──

class _PriceCard extends StatefulWidget {
  final String name, price, sub;
  final Color color;
  final bool featured;
  final List<String> perks;
  final VoidCallback onTap;
  const _PriceCard({
    required this.name,
    required this.price,
    required this.sub,
    required this.color,
    required this.featured,
    required this.perks,
    required this.onTap,
  });
  @override
  State<_PriceCard> createState() => _PriceCardState();
}

class _PriceCardState extends State<_PriceCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) => MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: AnimatedContainer(
          duration: const Duration(milliseconds: 260),
          padding: EdgeInsets.all(widget.featured ? 32 : 28),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            gradient: AurixTokens.cardGradient,
            border: Border.all(
                color: (widget.featured || _h)
                    ? widget.color.withValues(alpha: 0.4)
                    : AurixTokens.stroke(0.08),
                width: widget.featured ? 1.5 : 1),
            boxShadow: (widget.featured || _h)
                ? [
                    BoxShadow(
                        color: widget.color.withValues(alpha: 0.08),
                        blurRadius: 40,
                        spreadRadius: -12)
                  ]
                : null,
          ),
          child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (widget.featured)
                  Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: widget.color.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('ЛУЧШИЙ ВЫБОР',
                          style: TextStyle(
                            color: widget.color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800,
                            letterSpacing: 1.5,
                          ))),
                Text(widget.name,
                    style: TextStyle(
                      fontFamily: AurixTokens.fontDisplay,
                      color: widget.color,
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                    )),
                const SizedBox(height: 4),
                Text(widget.sub,
                    style: TextStyle(
                      color: widget.color.withValues(alpha: 0.5),
                      fontSize: 12,
                    )),
                const SizedBox(height: 16),
                Text(widget.price,
                    style: const TextStyle(
                      color: AurixTokens.text,
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 24),
                ...widget.perks.map((p) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Row(children: [
                      Icon(Icons.check_rounded,
                          color: widget.color, size: 16),
                      const SizedBox(width: 12),
                      Expanded(
                          child: Text(p,
                              style: const TextStyle(
                                color: AurixTokens.textSecondary,
                                fontSize: 14,
                                height: 1.4,
                              ))),
                    ]))),
                const SizedBox(height: 24),
                SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: widget.featured
                        ? FilledButton(
                            onPressed: widget.onTap,
                            style: FilledButton.styleFrom(
                              backgroundColor: widget.color,
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: const Text('ЗАБРАТЬ СЛОТ',
                                style: TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.5)))
                        : OutlinedButton(
                            onPressed: widget.onTap,
                            style: OutlinedButton.styleFrom(
                              side: BorderSide(
                                  color: widget.color
                                      .withValues(alpha: 0.3)),
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(14)),
                            ),
                            child: Text('ЗАБРАТЬ СЛОТ',
                                style: TextStyle(
                                    color: widget.color,
                                    fontWeight: FontWeight.w800,
                                    fontSize: 14,
                                    letterSpacing: 0.5)))),
              ])));
}

// ── Founder card ──

class _FounderCard extends StatelessWidget {
  final bool dk;
  const _FounderCard({required this.dk});
  @override
  Widget build(BuildContext context) => Container(
      padding: EdgeInsets.all(dk ? 56 : 32),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AurixTokens.bg1.withValues(alpha: 0.97),
              AurixTokens.bg2.withValues(alpha: 0.92),
            ]),
        border: Border.all(color: AurixTokens.stroke(0.12)),
        boxShadow: [
          BoxShadow(
              color: AurixTokens.accent.withValues(alpha: 0.04),
              blurRadius: 60,
              spreadRadius: -20),
        ],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(dk ? 24 : 20),
                boxShadow: [
                  BoxShadow(
                      color: AurixTokens.accent.withValues(alpha: 0.15),
                      blurRadius: 32,
                      spreadRadius: -8),
                ],
              ),
              child: ClipRRect(
                  borderRadius: BorderRadius.circular(dk ? 24 : 20),
                  child: Image.network(
                    'assets/images/producer.png',
                    width: dk ? 120 : 80,
                    height: dk ? 120 : 80,
                    fit: BoxFit.cover,
                    alignment: const Alignment(0, -0.6),
                    errorBuilder: (_, __, ___) => Container(
                        width: dk ? 120 : 80,
                        height: dk ? 120 : 80,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(dk ? 24 : 20),
                          gradient: LinearGradient(colors: [
                            AurixTokens.accent,
                            AurixTokens.accent.withValues(alpha: 0.6)
                          ]),
                        ),
                        child: Center(
                            child: Text('A',
                                style: TextStyle(
                                  fontFamily: AurixTokens.fontDisplay,
                                  color: Colors.white,
                                  fontSize: dk ? 40 : 28,
                                  fontWeight: FontWeight.w900,
                                )))),
                  ))),
          SizedBox(width: dk ? 32 : 20),
          Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                Text('Армен',
                    style: TextStyle(
                      fontFamily: AurixTokens.fontDisplay,
                      color: AurixTokens.text,
                      fontSize: dk ? 32 : 22,
                      fontWeight: FontWeight.w900,
                    )),
                const SizedBox(height: 8),
                Text('Основатель Aurix · Продюсер',
                    style: TextStyle(
                      color: AurixTokens.accent,
                      fontSize: dk ? 14 : 12,
                      fontWeight: FontWeight.w600,
                    )),
              ])),
        ]),
        SizedBox(height: dk ? 40 : 28),
        Text(
            'Талант есть у многих.\nВозможность показать его — нет.\n\nПоэтому я сделал Код Артиста.',
            style: TextStyle(
              color: AurixTokens.text,
              fontSize: dk ? 18 : 15,
              height: 1.8,
              fontWeight: FontWeight.w500,
            )),
        SizedBox(height: dk ? 20 : 14),
        Text('Приходи, покажи что умеешь.\nЕсли зацепит — будем работать.',
            style: TextStyle(
              color: AurixTokens.accent.withValues(alpha: 0.85),
              fontSize: dk ? 17 : 14,
              height: 1.7,
              fontWeight: FontWeight.w600,
            )),
      ]));
}

// ═══════════════════════════════════════════════════════════
// SHARED PRIMITIVES
// ═══════════════════════════════════════════════════════════

class _Sec extends StatelessWidget {
  final double mw;
  final EdgeInsetsGeometry p;
  final Widget child;
  const _Sec({required this.mw, required this.p, required this.child});
  @override
  Widget build(BuildContext context) => Padding(
      padding: p,
      child: Center(
          child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: mw), child: child)));
}

class _Label extends StatelessWidget {
  final String t;
  const _Label(this.t);
  @override
  Widget build(BuildContext context) => Text(t,
      style: TextStyle(
        fontFamily: AurixTokens.fontMono,
        color: AurixTokens.accent.withValues(alpha: 0.7),
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 4,
      ));
}

// ── Pulse CTA ──

class _PulseCTA extends StatefulWidget {
  final String label;
  final VoidCallback onTap;
  const _PulseCTA({required this.label, required this.onTap});
  @override
  State<_PulseCTA> createState() => _PulseCTAState();
}

class _PulseCTAState extends State<_PulseCTA>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(seconds: 3))
      ..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (_, child) => Container(
            decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                      color: AurixTokens.accent.withValues(
                          alpha: 0.15 +
                              0.12 * math.sin(_c.value * math.pi * 2)),
                      blurRadius: 48,
                      spreadRadius: -12,
                      offset: const Offset(0, 8)),
                ]),
            child: child,
          ),
      child: FilledButton(
          onPressed: widget.onTap,
          style: FilledButton.styleFrom(
            backgroundColor: AurixTokens.accent,
            padding:
                const EdgeInsets.symmetric(horizontal: 36, vertical: 20),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(18)),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Text(widget.label,
                style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                    letterSpacing: 0.5)),
            const SizedBox(width: 12),
            const Icon(Icons.arrow_forward_rounded, size: 18),
          ])));
}

// ── Animations ──

class _Reveal extends StatefulWidget {
  final Widget child;
  final int d;
  const _Reveal({required this.child, this.d = 0});
  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  @override
  void initState() {
    super.initState();
    _c = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 800));
    Future.delayed(Duration(milliseconds: 100 + widget.d), () {
      if (mounted) _c.forward();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _c,
      builder: (_, child) {
        final t = Curves.easeOutCubic.transform(_c.value);
        return Opacity(
            opacity: t,
            child: Transform.translate(
                offset: Offset(0, 24 * (1 - t)), child: child));
      },
      child: widget.child);
}

class _PulseDot extends StatefulWidget {
  final Color c;
  const _PulseDot({required this.c});
  @override
  State<_PulseDot> createState() => _PulseDotState();
}

class _PulseDotState extends State<_PulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a;
  @override
  void initState() {
    super.initState();
    _a = AnimationController(
        vsync: this, duration: const Duration(seconds: 2))
      ..repeat();
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
      animation: _a,
      builder: (_, __) => Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.c,
            boxShadow: [
              BoxShadow(
                  color: widget.c.withValues(
                      alpha:
                          0.3 + 0.3 * math.sin(_a.value * math.pi * 2)),
                  blurRadius: 8),
            ],
          )));
}

class _ParallaxOrb extends StatelessWidget {
  final double scrollY, factor;
  final double? top, bottom, left, right;
  final double size;
  final Color color;
  const _ParallaxOrb(
      {required this.scrollY,
      required this.factor,
      this.top,
      this.bottom,
      this.left,
      this.right,
      required this.size,
      required this.color});
  @override
  Widget build(BuildContext context) {
    final dy = -scrollY * factor;
    return Positioned(
        top: top != null ? top! + dy : null,
        bottom: bottom != null ? bottom! - dy : null,
        left: left,
        right: right,
        child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                    colors: [color, Colors.transparent]))));
  }
}
