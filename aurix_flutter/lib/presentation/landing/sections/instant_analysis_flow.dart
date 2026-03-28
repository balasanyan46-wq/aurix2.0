import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'landing_shared.dart';

/// Shows the instant analysis overlay flow.
/// States: loading → partial result (30%) → lead capture → full result → viral + monetization.
void showInstantAnalysis(BuildContext context, String trackIdea, VoidCallback onRegister) {
  showGeneralDialog(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'analysis',
    barrierColor: Colors.black.withValues(alpha: 0.7),
    transitionDuration: const Duration(milliseconds: 300),
    transitionBuilder: (ctx, a1, a2, child) {
      return FadeTransition(
        opacity: a1,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.95, end: 1.0).animate(
            CurvedAnimation(parent: a1, curve: Curves.easeOutCubic),
          ),
          child: child,
        ),
      );
    },
    pageBuilder: (ctx, a1, a2) {
      return _InstantAnalysisOverlay(trackIdea: trackIdea, onRegister: onRegister);
    },
  );
}

// ── Flow states ────────────────────────────────────────────────────

enum _FlowState { loading, partialResult, leadCapture, fullResult }

class _InstantAnalysisOverlay extends StatefulWidget {
  final String trackIdea;
  final VoidCallback onRegister;
  const _InstantAnalysisOverlay({required this.trackIdea, required this.onRegister});

  @override
  State<_InstantAnalysisOverlay> createState() => _InstantAnalysisOverlayState();
}

class _InstantAnalysisOverlayState extends State<_InstantAnalysisOverlay> with TickerProviderStateMixin {
  _FlowState _state = _FlowState.loading;
  late final AnimationController _loadCtrl;
  late final AnimationController _resultCtrl;
  final _emailCtrl = TextEditingController();
  final _rng = math.Random();

  // Generated scores
  late final int _overallScore;
  late final int _viralScore;
  late final int _productionScore;
  late final int _playlistChance;
  late final int _hookScore;
  late final String _mainIssue;
  late final String _recommendation;
  late final String _strengths;

  @override
  void initState() {
    super.initState();
    _loadCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 2500));
    _resultCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 800));

    // Generate pseudo-random scores based on input
    final seed = widget.trackIdea.hashCode;
    final r = math.Random(seed);
    _overallScore = 68 + r.nextInt(25); // 68-92
    _viralScore = 55 + r.nextInt(38);
    _productionScore = 60 + r.nextInt(35);
    _playlistChance = 40 + r.nextInt(45);
    _hookScore = 45 + r.nextInt(45);

    // Pick issue and recommendation based on lowest score
    final lowest = [_viralScore, _productionScore, _playlistChance, _hookScore];
    final lowestIdx = lowest.indexOf(lowest.reduce(math.min));
    final issues = [
      'Потенциал вирусности ниже среднего — не хватает запоминающегося момента в первые 3 секунды',
      'Продакшн требует доработки — сведение не конкурентно для стриминговых платформ',
      'Низкий шанс попадания в плейлист — трек не вписывается в текущие тренды жанра',
      'Слабый текстовый hook — припев не цепляет с первого прослушивания',
    ];
    final recs = [
      'Добавь яркий звуковой элемент в первые 3 секунды. Используй AI для генерации TikTok-фрагмента',
      'Рекомендуем AI-мастеринг и анализ референсов. AURIX подберёт оптимальные настройки',
      'AI составит стратегию продвижения и подберёт целевые плейлисты для твоего жанра',
      'Переработай припев с помощью AI-анализа текста. Мы покажем, что работает в твоём жанре',
    ];
    final strengths = [
      'Сильная мелодическая линия, хороший темп',
      'Интересная структура аранжировки',
      'Правильный BPM для жанра, качественные сэмплы',
      'Атмосферный саунд-дизайн, запоминающийся вайб',
    ];
    _mainIssue = issues[lowestIdx];
    _recommendation = recs[lowestIdx];
    _strengths = strengths[r.nextInt(strengths.length)];

    // Start loading
    _loadCtrl.forward().then((_) {
      if (!mounted) return;
      setState(() => _state = _FlowState.partialResult);
      _resultCtrl.forward();
    });
  }

  @override
  void dispose() {
    _loadCtrl.dispose();
    _resultCtrl.dispose();
    _emailCtrl.dispose();
    super.dispose();
  }

  void _unlockFull() {
    setState(() => _state = _FlowState.leadCapture);
  }

  void _submitLead() {
    // In real app: send email to backend
    setState(() => _state = _FlowState.fullResult);
  }

  void _skipToRegister() {
    Navigator.of(context).pop();
    widget.onRegister();
  }

  @override
  Widget build(BuildContext context) {
    final desktop = MediaQuery.sizeOf(context).width >= 960;
    final maxW = desktop ? 560.0 : MediaQuery.sizeOf(context).width - 32;

    return Center(
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: maxW,
          constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * 0.9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            color: AurixTokens.bg0,
            border: Border.all(color: AurixTokens.stroke(0.15)),
            boxShadow: [
              BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.1), blurRadius: 60, offset: const Offset(0, 20)),
              BoxShadow(color: Colors.black.withValues(alpha: 0.5), blurRadius: 40),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header
                  _buildHeader(),
                  // Body
                  AnimatedSwitcher(
                    duration: const Duration(milliseconds: 400),
                    switchInCurve: Curves.easeOutCubic,
                    child: _buildBody(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: AurixTokens.stroke(0.08))),
      ),
      child: Row(
        children: [
          Icon(Icons.auto_awesome_rounded, size: 18, color: AurixTokens.aiAccent),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('AI Анализ потенциала', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
                if (widget.trackIdea.isNotEmpty)
                  Text(
                    widget.trackIdea.length > 40 ? '${widget.trackIdea.substring(0, 40)}...' : widget.trackIdea,
                    style: TextStyle(color: AurixTokens.muted, fontSize: 11),
                  ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => Navigator.of(context).pop(),
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AurixTokens.glass(0.06),
              ),
              child: Icon(Icons.close_rounded, size: 16, color: AurixTokens.muted),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBody() {
    switch (_state) {
      case _FlowState.loading:
        return _LoadingView(key: const ValueKey('loading'), ctrl: _loadCtrl);
      case _FlowState.partialResult:
        return _PartialResultView(
          key: const ValueKey('partial'),
          ctrl: _resultCtrl,
          overall: _overallScore,
          viral: _viralScore,
          production: _productionScore,
          playlist: _playlistChance,
          hook: _hookScore,
          issue: _mainIssue,
          strengths: _strengths,
          onUnlock: _unlockFull,
          onRegister: _skipToRegister,
        );
      case _FlowState.leadCapture:
        return _LeadCaptureView(
          key: const ValueKey('lead'),
          emailCtrl: _emailCtrl,
          onSubmit: _submitLead,
          onSkip: _skipToRegister,
        );
      case _FlowState.fullResult:
        return _FullResultView(
          key: const ValueKey('full'),
          overall: _overallScore,
          viral: _viralScore,
          production: _productionScore,
          playlist: _playlistChance,
          hook: _hookScore,
          issue: _mainIssue,
          recommendation: _recommendation,
          strengths: _strengths,
          trackIdea: widget.trackIdea,
          onRegister: _skipToRegister,
        );
    }
  }
}

// ═══════════════════════════════════════════════════════════════════
// 1. LOADING VIEW
// ═══════════════════════════════════════════════════════════════════

class _LoadingView extends StatelessWidget {
  final AnimationController ctrl;
  const _LoadingView({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ctrl,
      builder: (context, _) {
        final progress = ctrl.value;
        final steps = [
          (0.0, 'Анализирую структуру трека...'),
          (0.25, 'Оцениваю вирусный потенциал...'),
          (0.5, 'Сравниваю с трендами жанра...'),
          (0.75, 'Формирую рекомендации...'),
        ];
        String currentStep = steps.last.$2;
        for (final s in steps.reversed) {
          if (progress >= s.$1) {
            currentStep = s.$2;
            break;
          }
        }

        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            children: [
              // Animated circle
              SizedBox(
                width: 80, height: 80,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    SizedBox(
                      width: 80, height: 80,
                      child: CircularProgressIndicator(
                        value: progress,
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation(AurixTokens.accent),
                        backgroundColor: AurixTokens.stroke(0.1),
                      ),
                    ),
                    Text(
                      '${(progress * 100).round()}%',
                      style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Text(
                currentStep,
                style: TextStyle(color: AurixTokens.textSecondary, fontSize: 14, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 16),
              // Step indicators
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final active = progress >= i * 0.25;
                  return Container(
                    width: 8, height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: active ? AurixTokens.accent : AurixTokens.stroke(0.15),
                    ),
                  );
                }),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 2. PARTIAL RESULT (30% visible, rest blurred)
// ═══════════════════════════════════════════════════════════════════

class _PartialResultView extends StatelessWidget {
  final AnimationController ctrl;
  final int overall, viral, production, playlist, hook;
  final String issue, strengths;
  final VoidCallback onUnlock;
  final VoidCallback onRegister;

  const _PartialResultView({
    super.key,
    required this.ctrl,
    required this.overall,
    required this.viral,
    required this.production,
    required this.playlist,
    required this.hook,
    required this.issue,
    required this.strengths,
    required this.onUnlock,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: ctrl,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Score badge — visible
            Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(16),
                  color: _scoreColor(overall).withValues(alpha: 0.08),
                  border: Border.all(color: _scoreColor(overall).withValues(alpha: 0.25)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      '$overall',
                      style: TextStyle(color: _scoreColor(overall), fontSize: 40, fontWeight: FontWeight.w900, fontFeatures: AurixTokens.tabularFigures),
                    ),
                    Text('/100', style: TextStyle(color: AurixTokens.muted, fontSize: 16)),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Общий потенциал', style: TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700)),
                        Text(_scoreLabel(overall), style: TextStyle(color: _scoreColor(overall), fontSize: 11, fontWeight: FontWeight.w600)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Visible: main issue + strengths
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AurixTokens.danger.withValues(alpha: 0.05),
                border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded, size: 18, color: AurixTokens.danger),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Главная проблема', style: TextStyle(color: AurixTokens.danger, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(issue, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: AurixTokens.positive.withValues(alpha: 0.05),
                border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.15)),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.check_circle_outline_rounded, size: 18, color: AurixTokens.positive),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Сильные стороны', style: TextStyle(color: AurixTokens.positive, fontSize: 12, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 4),
                        Text(strengths, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // BLURRED: detailed metrics — locked
            Stack(
              children: [
                // Blurred content
                ImageFiltered(
                  imageFilter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
                  child: Opacity(
                    opacity: 0.5,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Детальный анализ', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
                        const SizedBox(height: 14),
                        _metricRow('Вирусность', viral / 100, AurixTokens.accent),
                        const SizedBox(height: 8),
                        _metricRow('Продакшн', production / 100, AurixTokens.aiAccent),
                        const SizedBox(height: 8),
                        _metricRow('Плейлист', playlist / 100, AurixTokens.positive),
                        const SizedBox(height: 8),
                        _metricRow('Hook', hook / 100, AurixTokens.warning),
                        const SizedBox(height: 16),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(14),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: AurixTokens.aiAccent.withValues(alpha: 0.06),
                          ),
                          child: Text(
                            'AI рекомендация: подробный план действий для увеличения потенциала...',
                            style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                // Lock overlay
                Positioned.fill(
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: AurixTokens.bg0.withValues(alpha: 0.9),
                        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
                        boxShadow: [
                          BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.08), blurRadius: 20),
                        ],
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.lock_rounded, size: 28, color: AurixTokens.accent),
                          const SizedBox(height: 12),
                          const Text(
                            'Полный анализ заблокирован',
                            style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Детальные метрики, AI рекомендации\nи план действий',
                            textAlign: TextAlign.center,
                            style: TextStyle(color: AurixTokens.muted, fontSize: 12, height: 1.4),
                          ),
                          const SizedBox(height: 16),
                          GestureDetector(
                            onTap: onUnlock,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                gradient: const LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentWarm]),
                                boxShadow: [
                                  BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.3), blurRadius: 16, offset: const Offset(0, 4)),
                                ],
                              ),
                              child: const Text(
                                'Получить полный анализ →',
                                style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w700),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _metricRow(String label, double fill, Color color) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12))),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: AurixTokens.stroke(0.08)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill.clamp(0, 1),
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: color)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(fill * 100).round()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 3. LEAD CAPTURE
// ═══════════════════════════════════════════════════════════════════

class _LeadCaptureView extends StatefulWidget {
  final TextEditingController emailCtrl;
  final VoidCallback onSubmit;
  final VoidCallback onSkip;
  const _LeadCaptureView({super.key, required this.emailCtrl, required this.onSubmit, required this.onSkip});

  @override
  State<_LeadCaptureView> createState() => _LeadCaptureViewState();
}

class _LeadCaptureViewState extends State<_LeadCaptureView> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          Icon(Icons.mail_outline_rounded, size: 40, color: AurixTokens.aiAccent),
          const SizedBox(height: 16),
          const Text(
            'Отправим полный разбор',
            style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            'Детальный анализ, AI рекомендации и пошаговый\nплан действий — прямо на почту или в Telegram',
            textAlign: TextAlign.center,
            style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 28),

          // Email input
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _focused ? AurixTokens.accent.withValues(alpha: 0.5) : AurixTokens.stroke(0.15),
              ),
              color: AurixTokens.surface1,
              boxShadow: [
                if (_focused) BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.1), blurRadius: 20),
              ],
            ),
            child: Row(
              children: [
                const SizedBox(width: 16),
                Icon(Icons.alternate_email_rounded, size: 18, color: AurixTokens.accent.withValues(alpha: 0.5)),
                const SizedBox(width: 12),
                Expanded(
                  child: Focus(
                    onFocusChange: (f) => setState(() => _focused = f),
                    child: TextField(
                      controller: widget.emailCtrl,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                      decoration: InputDecoration(
                        hintText: 'Email или @telegram',
                        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 14),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(vertical: 16),
                      ),
                      onSubmitted: (_) => widget.onSubmit(),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: widget.onSubmit,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(10),
                      gradient: const LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentWarm]),
                    ),
                    child: const Text('Отправить', style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w700)),
                  ),
                ),
                const SizedBox(width: 6),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Bonus note
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AurixTokens.aiAccent.withValues(alpha: 0.05),
              border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Icon(Icons.card_giftcard_rounded, size: 16, color: AurixTokens.aiAccent),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Бонус: 50 AI кредитов при регистрации + 3 бесплатные обложки',
                    style: TextStyle(color: AurixTokens.aiAccent, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Skip link
          GestureDetector(
            onTap: widget.onSkip,
            child: Text(
              'Или зарегистрируйся и получи результат сразу →',
              style: TextStyle(color: AurixTokens.accent, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// 4. FULL RESULT + VIRAL LOOP + MONETIZATION
// ═══════════════════════════════════════════════════════════════════

class _FullResultView extends StatelessWidget {
  final int overall, viral, production, playlist, hook;
  final String issue, recommendation, strengths, trackIdea;
  final VoidCallback onRegister;

  const _FullResultView({
    super.key,
    required this.overall,
    required this.viral,
    required this.production,
    required this.playlist,
    required this.hook,
    required this.issue,
    required this.recommendation,
    required this.strengths,
    required this.trackIdea,
    required this.onRegister,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Score
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                color: _scoreColor(overall).withValues(alpha: 0.08),
                border: Border.all(color: _scoreColor(overall).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('$overall', style: TextStyle(color: _scoreColor(overall), fontSize: 40, fontWeight: FontWeight.w900, fontFeatures: AurixTokens.tabularFigures)),
                  Text('/100', style: TextStyle(color: AurixTokens.muted, fontSize: 16)),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Общий потенциал', style: TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700)),
                      Text(_scoreLabel(overall), style: TextStyle(color: _scoreColor(overall), fontSize: 11, fontWeight: FontWeight.w600)),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Detailed metrics — all visible
          const Text('Детальный анализ', style: TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
          const SizedBox(height: 14),
          _metricRow('Вирусность', viral / 100, AurixTokens.accent),
          const SizedBox(height: 8),
          _metricRow('Продакшн', production / 100, AurixTokens.aiAccent),
          const SizedBox(height: 8),
          _metricRow('Плейлист', playlist / 100, AurixTokens.positive),
          const SizedBox(height: 8),
          _metricRow('Hook', hook / 100, AurixTokens.warning),
          const SizedBox(height: 20),

          // Issue
          _infoCard(Icons.warning_amber_rounded, 'Проблема', issue, AurixTokens.danger),
          const SizedBox(height: 10),
          // Recommendation
          _infoCard(Icons.auto_awesome_rounded, 'AI Рекомендация', recommendation, AurixTokens.aiAccent),
          const SizedBox(height: 10),
          // Strengths
          _infoCard(Icons.check_circle_outline_rounded, 'Сильные стороны', strengths, AurixTokens.positive),
          const SizedBox(height: 28),

          // ── VIRAL LOOP ──
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              gradient: LinearGradient(
                colors: [AurixTokens.accent.withValues(alpha: 0.06), AurixTokens.aiAccent.withValues(alpha: 0.04)],
              ),
              border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
            ),
            child: Column(
              children: [
                const Text('Поделись результатом', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
                const SizedBox(height: 6),
                Text('Покажи друзьям свой score', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                const SizedBox(height: 14),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _ShareButton(icon: Icons.link_rounded, label: 'Копировать', onTap: () {
                      Clipboard.setData(ClipboardData(text: 'Мой трек набрал $overall/100 на AURIX AI! Проверь свой: aurixmusic.ru'));
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Ссылка скопирована!'), backgroundColor: AurixTokens.accent, duration: const Duration(seconds: 2)),
                      );
                    }),
                    const SizedBox(width: 10),
                    _ShareButton(icon: Icons.share_rounded, label: 'Telegram', onTap: () {
                      // In real app: open Telegram share URL
                    }),
                    const SizedBox(width: 10),
                    _ShareButton(icon: Icons.camera_alt_rounded, label: 'Stories', onTap: () {
                      // In real app: generate shareable image
                    }),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // ── Share preview card ──
          _SharePreview(score: overall, trackIdea: trackIdea),
          const SizedBox(height: 28),

          // ── MONETIZATION ENTRY ──
          const Text('Следующий шаг', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text('Используй AI, чтобы улучшить результат', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          const SizedBox(height: 16),
          _MonetizationCard(
            icon: Icons.image_rounded,
            title: 'Создать обложку',
            desc: 'AI сгенерирует обложку за 30 сек',
            color: AurixTokens.aiAccent,
            tag: 'БЕСПЛАТНО',
            onTap: onRegister,
          ),
          const SizedBox(height: 10),
          _MonetizationCard(
            icon: Icons.videocam_rounded,
            title: 'Сделать промо видео',
            desc: 'Вертикальное видео для Reels и TikTok',
            color: AurixTokens.accent,
            tag: '5 кредитов',
            onTap: onRegister,
          ),
          const SizedBox(height: 10),
          _MonetizationCard(
            icon: Icons.route_rounded,
            title: 'Получить стратегию',
            desc: 'Персональный план запуска трека',
            color: AurixTokens.accentWarm,
            tag: '10 кредитов',
            onTap: onRegister,
          ),
          const SizedBox(height: 24),

          // Final CTA
          Center(
            child: GestureDetector(
              onTap: onRegister,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  gradient: const LinearGradient(colors: [AurixTokens.accent, AurixTokens.accentWarm]),
                  boxShadow: [
                    BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 6)),
                  ],
                ),
                child: const Text(
                  'Создать аккаунт бесплатно →',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              '50 AI кредитов бесплатно · Без карты',
              style: TextStyle(color: AurixTokens.micro, fontSize: 11),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _metricRow(String label, double fill, Color color) {
    return Row(
      children: [
        SizedBox(width: 90, child: Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 12))),
        Expanded(
          child: Container(
            height: 6,
            decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: AurixTokens.stroke(0.08)),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill.clamp(0, 1),
              child: Container(decoration: BoxDecoration(borderRadius: BorderRadius.circular(3), color: color)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        Text('${(fill * 100).round()}%', style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
      ],
    );
  }

  Widget _infoCard(IconData icon, String title, String text, Color color) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        color: color.withValues(alpha: 0.05),
        border: Border.all(color: color.withValues(alpha: 0.15)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
                const SizedBox(height: 4),
                Text(text, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12.5, height: 1.5)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Shareable preview card ─────────────────────────────────────────

class _SharePreview extends StatelessWidget {
  final int score;
  final String trackIdea;
  const _SharePreview({required this.score, required this.trackIdea});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF0f0a1a), Color(0xFF0a1020)],
        ),
        border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AurixTokens.accent, AurixTokens.aiAccent],
                ).createShader(bounds),
                child: const Text('AURIX', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w900, letterSpacing: 3)),
              ),
              const SizedBox(width: 8),
              Text('AI АНАЛИЗ', style: TextStyle(color: AurixTokens.micro, fontSize: 10, fontWeight: FontWeight.w600, letterSpacing: 1)),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            '$score/100',
            style: TextStyle(color: _scoreColor(score), fontSize: 48, fontWeight: FontWeight.w900, fontFeatures: AurixTokens.tabularFigures),
          ),
          Text(
            _scoreLabel(score),
            style: TextStyle(color: _scoreColor(score), fontSize: 13, fontWeight: FontWeight.w600),
          ),
          if (trackIdea.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              trackIdea.length > 50 ? '${trackIdea.substring(0, 50)}...' : trackIdea,
              textAlign: TextAlign.center,
              style: TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            'aurixmusic.ru',
            style: TextStyle(color: AurixTokens.accent.withValues(alpha: 0.7), fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

// ── Monetization card ──────────────────────────────────────────────

class _MonetizationCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String desc;
  final Color color;
  final String tag;
  final VoidCallback onTap;
  const _MonetizationCard({required this.icon, required this.title, required this.desc, required this.color, required this.tag, required this.onTap});

  @override
  State<_MonetizationCard> createState() => _MonetizationCardState();
}

class _MonetizationCardState extends State<_MonetizationCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            color: _hover ? widget.color.withValues(alpha: 0.08) : AurixTokens.surface1,
            border: Border.all(
              color: _hover ? widget.color.withValues(alpha: 0.3) : AurixTokens.stroke(0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  color: widget.color.withValues(alpha: 0.12),
                ),
                child: Icon(widget.icon, color: widget.color, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.title, style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
                    Text(widget.desc, style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: widget.color.withValues(alpha: 0.1),
                ),
                child: Text(widget.tag, style: TextStyle(color: widget.color, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(width: 8),
              Icon(Icons.arrow_forward_ios_rounded, size: 14, color: AurixTokens.muted),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Share button ───────────────────────────────────────────────────

class _ShareButton extends StatefulWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  const _ShareButton({required this.icon, required this.label, required this.onTap});

  @override
  State<_ShareButton> createState() => _ShareButtonState();
}

class _ShareButtonState extends State<_ShareButton> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: _hover ? AurixTokens.accent.withValues(alpha: 0.1) : AurixTokens.surface1,
            border: Border.all(color: _hover ? AurixTokens.accent.withValues(alpha: 0.3) : AurixTokens.stroke(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 16, color: _hover ? AurixTokens.accent : AurixTokens.textSecondary),
              const SizedBox(width: 6),
              Text(widget.label, style: TextStyle(color: _hover ? AurixTokens.accent : AurixTokens.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }
}

// ── Helpers ─────────────────────────────────────────────────────────

Color _scoreColor(int score) {
  if (score >= 80) return AurixTokens.positive;
  if (score >= 60) return AurixTokens.accent;
  if (score >= 40) return AurixTokens.warning;
  return AurixTokens.danger;
}

String _scoreLabel(int score) {
  if (score >= 85) return 'Отличный потенциал';
  if (score >= 75) return 'Высокий потенциал';
  if (score >= 60) return 'Средний потенциал';
  if (score >= 40) return 'Требует доработки';
  return 'Низкий потенциал';
}
