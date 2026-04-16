import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/features/casting/data/casting_repository.dart';
import 'package:aurix_flutter/features/casting/domain/casting_application.dart';

const _kCities = <String, _CityInfo>{
  'Москва':          _CityInfo('24 мая',  12),
  'Санкт-Петербург': _CityInfo('31 мая',  18),
  'Воронеж':         _CityInfo('7 июня',  31),
  'Ростов-на-Дону':  _CityInfo('14 июня', 27),
  'Краснодар':       _CityInfo('21 июня', 22),
  'Сочи':            _CityInfo('28 июня', 9),
};

class _CityInfo {
  final String date;
  final int mockSeats;
  const _CityInfo(this.date, this.mockSeats);
}

const _plans = {
  'base': {'label': 'BASE', 'price': 990, 'sub': 'для тех, кто хочет попробовать', 'perks': ['5 минут на сцене', 'Участие в отборе', 'Шанс на контракт']},
  'pro': {'label': 'PRO', 'price': 2990, 'sub': 'оптимальный выбор', 'perks': ['10 минут на сцене', 'Обратная связь от жюри', 'Видеозапись', 'Увеличенные шансы']},
  'vip': {'label': 'VIP', 'price': 5990, 'sub': 'максимум внимания', 'perks': ['15 минут на сцене', 'Личный разбор от A&R', 'Видео + промо', 'Приоритет контракта', 'Первый на контракт']},
};

class CastingApplyPage extends StatefulWidget {
  const CastingApplyPage({super.key});
  @override
  State<CastingApplyPage> createState() => _CastingApplyPageState();
}

class _CastingApplyPageState extends State<CastingApplyPage> with TickerProviderStateMixin {
  int _step = 0;
  String? _city;
  String _plan = 'pro';
  bool _isAudience = false;
  int _audienceQty = 1;
  final _nameCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();
  bool _loading = false;
  CastingSlots? _slots;

  // City select animation
  late final AnimationController _zoomCtrl;
  late final Animation<double> _zoomAnim;

  @override
  void initState() {
    super.initState();
    _zoomCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 500));
    _zoomAnim = CurvedAnimation(parent: _zoomCtrl, curve: Curves.easeInOutCubicEmphasized);
    // Check if audience ticket flow
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final type = GoRouterState.of(context).uri.queryParameters['type'];
      if (type == 'audience') {
        setState(() { _isAudience = true; _plan = 'audience'; });
      }
    });
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _phoneCtrl.dispose();
    _zoomCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadSlots(String city) async {
    try {
      final s = await CastingRepository.instance.getSlots(city);
      if (mounted) setState(() => _slots = s);
    } catch (_) {}
  }

  void _selectCity(String city) {
    setState(() => _city = city);
    _loadSlots(city);
    _zoomCtrl.forward(from: 0).then((_) {
      if (mounted) setState(() => _step = _isAudience ? 2 : 1);
    });
  }

  Future<void> _purchase() async {
    if (_nameCtrl.text.trim().isEmpty || _phoneCtrl.text.trim().length < 6) {
      _showError('Заполни имя и телефон');
      return;
    }
    setState(() { _loading = true; _step = 3; });
    try {
      final result = await CastingRepository.instance.purchase(
        name: _nameCtrl.text.trim(),
        phone: _phoneCtrl.text.trim(),
        city: _city!,
        plan: _plan,
        quantity: _isAudience ? _audienceQty : 1,
      );
      final url = result['paymentUrl'] as String?;
      if (url != null && url.isNotEmpty) {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      if (mounted) { setState(() { _step = 2; _loading = false; }); _showError('$e'); }
    }
  }

  void _showError(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg), backgroundColor: AurixTokens.danger, behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final dk = w > 600;
    final maxW = dk ? 560.0 : double.infinity;

    return Scaffold(
      backgroundColor: const Color(0xFF020204),
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1.withValues(alpha: 0.72),
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text),
          onPressed: () {
            if (_step > 0 && _step < 3) setState(() => _step--);
            else if (context.canPop()) context.pop();
          },
        ),
        title: Text(
          _step == 0 ? 'ГОРОД' : _step == 1 ? 'ТАРИФ' : _step == 2 ? 'ДАННЫЕ' : 'ОПЛАТА',
          style: const TextStyle(fontFamily: AurixTokens.fontHeading, color: AurixTokens.text, fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 1.5),
        ),
        centerTitle: true,
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_step + 1) / 4, backgroundColor: AurixTokens.surface1, color: AurixTokens.accent, minHeight: 3),
        ),
      ),
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 300),
        transitionBuilder: (child, anim) {
          final slide = Tween<Offset>(begin: const Offset(0.05, 0), end: Offset.zero).animate(CurvedAnimation(parent: anim, curve: Curves.easeOutCubic));
          return FadeTransition(opacity: anim, child: SlideTransition(position: slide, child: child));
        },
        child: _step == 0 ? _buildCityStep(w, dk)
             : _step == 1 ? _buildPlanStep(w, dk, maxW)
             : _step == 2 ? _buildInfoStep(w, dk, maxW)
             : _buildProcessing(),
      ),
    );
  }

  // ═══ STEP 0: CITY ═══

  Widget _buildCityStep(double w, bool dk) {
    final hp = dk ? (w - 720) / 2 : 20.0;
    return SingleChildScrollView(
      key: const ValueKey('city'),
      padding: EdgeInsets.fromLTRB(hp.clamp(20.0, 200.0), 36, hp.clamp(20.0, 200.0), 40),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(_isAudience ? 'В КАКОМ ГОРОДЕ\nТЫ ХОЧЕШЬ\nПОСМОТРЕТЬ?' : 'В КАКОМ ГОРОДЕ\nТЫ ВЫЙДЕШЬ\nНА СЦЕНУ?', style: TextStyle(
          fontFamily: AurixTokens.fontDisplay, color: AurixTokens.text,
          fontSize: dk ? 36 : 26, fontWeight: FontWeight.w900, letterSpacing: -1, height: 1.05,
        )),
        const SizedBox(height: 10),
        Text(_isAudience ? 'Выбери город и купи билет зрителя.' : '50 артистов. 1 день. Живой отбор.', style: const TextStyle(color: AurixTokens.muted, fontSize: 14)),
        const SizedBox(height: 32),
        // City grid
        Wrap(
          spacing: 14, runSpacing: 14,
          children: _kCities.entries.toList().asMap().entries.map((entry) {
            final i = entry.key;
            final city = entry.value.key;
            final info = entry.value.value;
            return _CitySelectCard(
              city: city, date: info.date, seatsLeft: info.mockSeats,
              selected: _city == city, delay: i * 80,
              onTap: () => _selectCity(city),
            );
          }).toList(),
        ),
      ]),
    );
  }

  // ═══ STEP 1: PLAN ═══

  Widget _buildPlanStep(double w, bool dk, double maxW) {
    final cityInfo = _kCities[_city];
    return SingleChildScrollView(
      key: const ValueKey('plan'),
      padding: EdgeInsets.symmetric(horizontal: dk ? (w - maxW) / 2 : 20, vertical: 28),
      child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // City summary
          Row(children: [
            const Icon(Icons.location_on_rounded, color: AurixTokens.accent, size: 18),
            const SizedBox(width: 8),
            Text(_city ?? '', style: const TextStyle(color: AurixTokens.accent, fontSize: 14, fontWeight: FontWeight.w700)),
            if (cityInfo != null) ...[
              const SizedBox(width: 8),
              Text('· ${cityInfo.date}', style: TextStyle(fontFamily: AurixTokens.fontMono, color: AurixTokens.muted, fontSize: 12)),
            ],
            if (_slots != null) ...[
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: (_slots!.remaining <= 10 ? AurixTokens.danger : AurixTokens.positive).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('${_slots!.remaining} мест', style: TextStyle(
                  color: _slots!.remaining <= 10 ? AurixTokens.danger : AurixTokens.positive,
                  fontSize: 11, fontWeight: FontWeight.w700,
                )),
              ),
            ],
          ]),
          const SizedBox(height: 28),
          Text('ВЫБЕРИ СВОЙ СЛОТ', style: TextStyle(
            fontFamily: AurixTokens.fontDisplay, color: AurixTokens.text,
            fontSize: 22, fontWeight: FontWeight.w900,
          )),
          const SizedBox(height: 24),
          ..._plans.entries.map((e) {
            final key = e.key;
            final plan = e.value;
            final selected = _plan == key;
            final color = key == 'base' ? AurixTokens.muted : key == 'pro' ? AurixTokens.accent : AurixTokens.aiAccent;
            return Padding(padding: const EdgeInsets.only(bottom: 12), child: _PlanSelectCard(
              name: plan['label'] as String, price: '${plan['price']} ₽', sub: plan['sub'] as String,
              perks: (plan['perks'] as List).cast<String>(), color: color,
              selected: selected, featured: key == 'pro',
              onTap: () => setState(() => _plan = key),
            ));
          }),
          const SizedBox(height: 24),
          SizedBox(width: double.infinity, height: 54, child: FilledButton(
            onPressed: () => setState(() => _step = 2),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('ДАЛЕЕ', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
              SizedBox(width: 8),
              Icon(Icons.arrow_forward_rounded, size: 18),
            ]),
          )),
        ]),
      )),
    );
  }

  // ═══ STEP 2: INFO ═══

  Widget _buildInfoStep(double w, bool dk, double maxW) {
    final planData = _isAudience
        ? {'label': 'ЗРИТЕЛЬ', 'price': 1000}
        : _plans[_plan]!;
    final totalPrice = _isAudience ? 1000 * _audienceQty : planData['price'] as int;
    return SingleChildScrollView(
      key: const ValueKey('info'),
      padding: EdgeInsets.symmetric(horizontal: dk ? (w - maxW) / 2 : 20, vertical: 28),
      child: Center(child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Summary
          Container(
            width: double.infinity, padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(14), gradient: AurixTokens.cardGradient, border: Border.all(color: AurixTokens.stroke(0.18))),
            child: Row(children: [
              const Icon(Icons.location_on_rounded, color: AurixTokens.accent, size: 16),
              const SizedBox(width: 8),
              Text(_city ?? '', style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
              const Spacer(),
              Text('${planData['label']}', style: TextStyle(fontFamily: AurixTokens.fontMono, color: _isAudience ? AurixTokens.aiAccent : AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Text('$totalPrice ₽', style: const TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w800)),
            ]),
          ),

          // Audience quantity selector
          if (_isAudience) ...[
            const SizedBox(height: 20),
            _Label('КОЛИЧЕСТВО БИЛЕТОВ'),
            const SizedBox(height: 10),
            Row(children: [
              GestureDetector(
                onTap: () { if (_audienceQty > 1) setState(() => _audienceQty--); },
                child: Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AurixTokens.stroke(0.2))),
                  child: const Icon(Icons.remove_rounded, color: AurixTokens.text, size: 20)),
              ),
              const SizedBox(width: 16),
              Text('$_audienceQty', style: const TextStyle(color: AurixTokens.text, fontSize: 24, fontWeight: FontWeight.w800)),
              const SizedBox(width: 16),
              GestureDetector(
                onTap: () { if (_audienceQty < 10) setState(() => _audienceQty++); },
                child: Container(width: 44, height: 44, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: AurixTokens.stroke(0.2))),
                  child: const Icon(Icons.add_rounded, color: AurixTokens.text, size: 20)),
              ),
              const SizedBox(width: 16),
              Text('× 1 000 ₽ = $totalPrice ₽', style: const TextStyle(color: AurixTokens.muted, fontSize: 13)),
            ]),
          ],

          const SizedBox(height: 28),
          Text('ТВОИ ДАННЫЕ', style: TextStyle(fontFamily: AurixTokens.fontDisplay, color: AurixTokens.text, fontSize: 22, fontWeight: FontWeight.w900)),
          const SizedBox(height: 24),
          _Label('ИМЯ'), const SizedBox(height: 8),
          TextFormField(controller: _nameCtrl, style: const TextStyle(color: AurixTokens.text, fontSize: 14), decoration: const InputDecoration(hintText: 'Как тебя зовут')),
          const SizedBox(height: 20),
          _Label('ТЕЛЕФОН'), const SizedBox(height: 8),
          TextFormField(controller: _phoneCtrl, keyboardType: TextInputType.phone, style: const TextStyle(color: AurixTokens.text, fontSize: 14), decoration: const InputDecoration(hintText: '+7 (999) 123-45-67')),
          const SizedBox(height: 36),
          SizedBox(width: double.infinity, height: 54, child: FilledButton(
            onPressed: _loading ? null : _purchase,
            style: FilledButton.styleFrom(backgroundColor: _isAudience ? AurixTokens.aiAccent : AurixTokens.accent, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
            child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text('ОПЛАТИТЬ $totalPrice ₽', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14, letterSpacing: 0.5)),
              const SizedBox(width: 10), const Icon(Icons.lock_rounded, size: 16),
            ]),
          )),
          const SizedBox(height: 12),
          const Center(child: Text('Безопасная оплата через T-Bank', style: TextStyle(color: AurixTokens.muted, fontSize: 11))),
        ]),
      )),
    );
  }

  // ═══ STEP 3: PROCESSING ═══

  Widget _buildProcessing() {
    return SizedBox(key: const ValueKey('proc'), height: 300, child: Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
      const CircularProgressIndicator(color: AurixTokens.accent),
      const SizedBox(height: 24),
      const Text('Переход к оплате...', style: TextStyle(color: AurixTokens.textSecondary, fontSize: 15)),
      const SizedBox(height: 32),
      TextButton(onPressed: () => setState(() { _step = 2; _loading = false; }),
        child: const Text('Вернуться назад', style: TextStyle(color: AurixTokens.muted))),
    ])));
  }
}

// ═══════════════════════════════════════════════════════════
// CITY SELECT CARD
// ═══════════════════════════════════════════════════════════

class _CitySelectCard extends StatefulWidget {
  final String city, date;
  final int seatsLeft;
  final bool selected;
  final int delay;
  final VoidCallback onTap;
  const _CitySelectCard({required this.city, required this.date, required this.seatsLeft, required this.selected, required this.delay, required this.onTap});
  @override
  State<_CitySelectCard> createState() => _CitySelectCardState();
}

class _CitySelectCardState extends State<_CitySelectCard> with SingleTickerProviderStateMixin {
  bool _hovered = false;
  late final AnimationController _enterCtrl;

  @override
  void initState() {
    super.initState();
    _enterCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 600));
    Future.delayed(Duration(milliseconds: 100 + widget.delay), () { if (mounted) _enterCtrl.forward(); });
  }

  @override
  void dispose() { _enterCtrl.dispose(); super.dispose(); }

  @override
  Widget build(BuildContext context) {
    final w = MediaQuery.sizeOf(context).width;
    final dk = w > 600;
    final cardW = dk ? (w.clamp(0.0, 720.0) - 40 - 14) / 2 : w - 40;
    final active = widget.selected || _hovered;
    final urgent = widget.seatsLeft <= 15;

    return AnimatedBuilder(animation: _enterCtrl, builder: (_, child) {
      final t = Curves.easeOutCubic.transform(_enterCtrl.value);
      return Opacity(opacity: t, child: Transform.translate(offset: Offset(0, 24 * (1 - t)), child: Transform.scale(scale: 0.95 + 0.05 * t, child: child)));
    }, child: MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        width: cardW.clamp(200.0, 400.0),
        padding: const EdgeInsets.all(24),
        transform: Matrix4.identity()..scale(active ? 1.02 : 1.0),
        transformAlignment: Alignment.center,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topLeft, end: Alignment.bottomRight, colors: [
            active ? AurixTokens.accent.withValues(alpha: 0.08) : AurixTokens.bg1.withValues(alpha: 0.95),
            active ? AurixTokens.aiAccent.withValues(alpha: 0.04) : AurixTokens.bg2.withValues(alpha: 0.9),
          ]),
          border: Border.all(
            color: active ? AurixTokens.accent.withValues(alpha: 0.55) : AurixTokens.stroke(0.14),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [
            BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.15), blurRadius: 32, spreadRadius: -8),
          ] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // City name
          Text(widget.city, style: TextStyle(
            fontFamily: AurixTokens.fontHeading, color: active ? AurixTokens.text : AurixTokens.textSecondary,
            fontSize: 20, fontWeight: FontWeight.w800,
          )),
          const SizedBox(height: 10),
          // Date
          Row(children: [
            Icon(Icons.calendar_today_rounded, size: 14, color: active ? AurixTokens.accent : AurixTokens.muted),
            const SizedBox(width: 8),
            Text(widget.date, style: TextStyle(
              fontFamily: AurixTokens.fontMono, color: active ? AurixTokens.accent : AurixTokens.muted,
              fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ]),
          const SizedBox(height: 12),
          // Seats pressure
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: (urgent ? AurixTokens.danger : AurixTokens.warning).withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: (urgent ? AurixTokens.danger : AurixTokens.warning).withValues(alpha: 0.2)),
            ),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              Text(urgent ? '🔥' : '⚡', style: const TextStyle(fontSize: 12)),
              const SizedBox(width: 6),
              Text(
                urgent ? 'Осталось ${widget.seatsLeft} мест' : 'Быстро заполняется',
                style: TextStyle(color: urgent ? AurixTokens.danger : AurixTokens.warning, fontSize: 11, fontWeight: FontWeight.w700),
              ),
            ]),
          ),
        ]),
      )),
    ));
  }
}

// ═══════════════════════════════════════════════════════════
// PLAN SELECT CARD
// ═══════════════════════════════════════════════════════════

class _PlanSelectCard extends StatefulWidget {
  final String name, price, sub;
  final List<String> perks;
  final Color color;
  final bool selected, featured;
  final VoidCallback onTap;
  const _PlanSelectCard({required this.name, required this.price, required this.sub, required this.perks, required this.color, required this.selected, this.featured = false, required this.onTap});
  @override
  State<_PlanSelectCard> createState() => _PlanSelectCardState();
}

class _PlanSelectCardState extends State<_PlanSelectCard> {
  bool _h = false;
  @override
  Widget build(BuildContext context) {
    final active = widget.selected || _h;
    return MouseRegion(
      onEnter: (_) => setState(() => _h = true),
      onExit: (_) => setState(() => _h = false),
      child: GestureDetector(onTap: widget.onTap, child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(18),
          gradient: AurixTokens.cardGradient,
          border: Border.all(
            color: active ? widget.color.withValues(alpha: 0.6) : AurixTokens.stroke(0.12),
            width: active ? 1.5 : 1,
          ),
          boxShadow: active ? [BoxShadow(color: widget.color.withValues(alpha: 0.12), blurRadius: 24, spreadRadius: -8)] : null,
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (widget.featured) Container(
              margin: const EdgeInsets.only(right: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(color: widget.color.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(6)),
              child: Text('ЛУЧШИЙ ВЫБОР', style: TextStyle(color: widget.color, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
            ),
            Text(widget.name, style: TextStyle(fontFamily: AurixTokens.fontDisplay, color: widget.color, fontSize: 16, fontWeight: FontWeight.w800)),
            const Spacer(),
            Text(widget.price, style: const TextStyle(color: AurixTokens.text, fontSize: 22, fontWeight: FontWeight.w900)),
          ]),
          const SizedBox(height: 4),
          Text(widget.sub, style: TextStyle(color: widget.color.withValues(alpha: 0.6), fontSize: 12)),
          const SizedBox(height: 12),
          Wrap(spacing: 12, runSpacing: 6, children: widget.perks.map((p) => Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(Icons.check_rounded, color: widget.color, size: 14),
            const SizedBox(width: 5),
            Text(p, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12)),
          ])).toList()),
          const SizedBox(height: 14),
          Align(alignment: Alignment.centerRight, child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 24, height: 24,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: widget.selected ? widget.color : AurixTokens.muted.withValues(alpha: 0.3), width: widget.selected ? 2 : 1.5),
            ),
            child: widget.selected ? Center(child: Container(width: 12, height: 12, decoration: BoxDecoration(shape: BoxShape.circle, color: widget.color))) : null,
          )),
        ]),
      )),
    );
  }
}

// ═══ SHARED ═══

class _Label extends StatelessWidget {
  final String t;
  const _Label(this.t);
  @override
  Widget build(BuildContext context) => Text(t, style: TextStyle(
    fontFamily: AurixTokens.fontMono, color: AurixTokens.muted,
    fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5,
  ));
}
