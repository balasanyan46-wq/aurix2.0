import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/core/plan_config.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  bool _isYearly = false;
  bool _synced = false;

  static const _monthlyPrices = <String, int>{
    'start': 12,
    'breakthrough': 24,
    'empire': 59,
  };

  int _yearlyPrice(int monthly) => (monthly * 12 * 0.8).round();

  String _priceLabel(SubscriptionPlan plan) {
    final monthly = _monthlyPrices[plan.slug] ?? 0;
    if (_isYearly) return '\$${_yearlyPrice(monthly)}/год';
    return '\$$monthly/мес';
  }

  String? _savingsLabel(SubscriptionPlan plan) {
    if (!_isYearly) return null;
    final monthly = _monthlyPrices[plan.slug] ?? 0;
    final saved = (monthly * 12) - _yearlyPrice(monthly);
    if (saved <= 0) return null;
    return '−\$$saved в год';
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: AurixTokens.bg2,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;
    final subscription = ref.watch(currentSubscriptionProvider);
    final currentSlug = subscription?.plan ?? profile?.plan ?? 'start';
    final currentPlan = SubscriptionPlan.fromSlug(currentSlug);
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    final effectiveBillingPeriod = subscription?.billingPeriod ?? profile?.billingPeriod ?? 'monthly';
    if (!_synced && (subscription != null || profile != null)) {
      _isYearly = effectiveBillingPeriod == 'yearly';
      _synced = true;
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 8),

              // ── Header ──────────────────────────────────────
              FadeInSlide(
                child: Row(
                  mainAxisAlignment: isDesktop ? MainAxisAlignment.center : MainAxisAlignment.start,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            AurixTokens.accent.withValues(alpha: 0.15),
                            AurixTokens.aiAccent.withValues(alpha: 0.1),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AurixTokens.stroke(0.18)),
                      ),
                      child: const Icon(Icons.workspace_premium_rounded, size: 22, color: AurixTokens.accent),
                    ),
                    const SizedBox(width: 14),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isDesktop
                              ? 'Выбери масштаб, на котором ты собираешься играть.'
                              : 'Выбери свой масштаб.',
                          style: TextStyle(
                            color: AurixTokens.text,
                            fontSize: isDesktop ? 24 : 20,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '7 дней trial с доступом уровня ПРОРЫВ, затем выбери тариф.',
                          style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 28),

              // ── Billing toggle ──────────────────────────────
              FadeInSlide(
                delayMs: 50,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: AurixTokens.bg2,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AurixTokens.stroke(0.18)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildToggle('Месяц', isActive: !_isYearly, onTap: () => setState(() => _isYearly = false)),
                        _buildToggle('Год  −20%', isActive: _isYearly, onTap: () => setState(() => _isYearly = true)),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 32),

              // ── Plan cards ──────────────────────────────────
              LayoutBuilder(
                builder: (context, constraints) {
                  final configs = planConfigs;
                  final cards = <Widget>[];
                  for (int i = 0; i < configs.length; i++) {
                    final cfg = configs[i];
                    cards.add(
                      FadeInSlide(
                        delayMs: 100 + i * 60,
                        child: _PlanCard(
                          config: cfg,
                          isCurrent: currentPlan == cfg.plan,
                          priceLabel: _priceLabel(cfg.plan),
                          savingsLabel: _savingsLabel(cfg.plan),
                          onSubscribe: () => _startCheckout(context, ref, cfg, currentPlan),
                        ),
                      ),
                    );
                  }

                  if (constraints.maxWidth > 900) {
                    return IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (int i = 0; i < cards.length; i++) ...[
                            if (i > 0) const SizedBox(width: 16),
                            Expanded(child: cards[i]),
                          ],
                        ],
                      ),
                    );
                  }

                  return Column(
                    children: [
                      for (int i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(height: 16),
                        cards[i],
                      ],
                    ],
                  );
                },
              ),

              const SizedBox(height: 48),

              // ── Why ПРОРЫВ section ──────────────────────────
              FadeInSlide(
                delayMs: 300,
                child: _buildWhyBreakthroughSection(context),
              ),

              const SizedBox(height: 32),

              // ── Help ────────────────────────────────────────
              FadeInSlide(
                delayMs: 350,
                child: PremiumSectionCard(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: AurixTokens.accent.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(Icons.mail_outline_rounded, color: AurixTokens.accent, size: 20),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Нужна помощь с выбором?',
                              style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 15),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Напишите в поддержку — поможем выбрать план.',
                              style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  // ── Toggle button ─────────────────────────────────────────────────────

  Widget _buildToggle(String label, {required bool isActive, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: isActive ? AurixTokens.accent.withValues(alpha: 0.12) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: isActive ? Border.all(color: AurixTokens.accent.withValues(alpha: 0.35)) : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isActive ? AurixTokens.accent : AurixTokens.muted,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            fontSize: 14,
          ),
        ),
      ),
    );
  }

  // ── Upgrade dialog ────────────────────────────────────────────────────

  void _startCheckout(BuildContext context, WidgetRef ref, PlanConfig config, SubscriptionPlan currentPlan) {
    final newPlan = config.plan;
    final price = _priceLabel(newPlan);
    final billingPeriod = _isYearly ? 'yearly' : 'monthly';

    showDialog(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusCard)),
        title: Text(
          'Перейти к оплате: ${newPlan.label}?',
          style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'План: ${newPlan.label} ($price)',
              style: const TextStyle(color: AurixTokens.muted),
            ),
            const SizedBox(height: 4),
            Text(
              'Оплата: ${_isYearly ? "ежегодно" : "ежемесячно"}',
              style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
            ),
            if (_savingsLabel(newPlan) != null) ...[
              const SizedBox(height: 4),
              Text(
                _savingsLabel(newPlan)!,
                style: const TextStyle(color: AurixTokens.positive, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(dialogCtx).pop();
              final result = await ref.read(billingServiceProvider).createCheckoutSession(
                    plan: newPlan.slug,
                    billingPeriod: billingPeriod,
                  );
              if (!context.mounted) return;

              if (result.ok && (result.url?.isNotEmpty ?? false)) {
                final uri = Uri.tryParse(result.url!);
                if (uri == null) {
                  _snack('Не удалось открыть оплату.');
                  return;
                }
                final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
                if (!ok && context.mounted) {
                  _snack('Не удалось открыть ссылку оплаты.');
                }
                return;
              }

              _snack(result.error ?? 'Оплата скоро будет доступна.');
            },
            style: FilledButton.styleFrom(
              backgroundColor: AurixTokens.accent,
              foregroundColor: Colors.white,
            ),
            child: const Text('Перейти к оплате'),
          ),
        ],
      ),
    );
  }

  // ── Why Breakthrough ──────────────────────────────────────────────────

  Widget _buildWhyBreakthroughSection(BuildContext context) {
    return PremiumSectionCard(
      padding: const EdgeInsets.all(28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      AurixTokens.accent.withValues(alpha: 0.15),
                      AurixTokens.accent.withValues(alpha: 0.05),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.2)),
                ),
                child: const Icon(Icons.rocket_launch_rounded, size: 20, color: AurixTokens.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Text(
                  'Почему артисты выбирают ПРОРЫВ?',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          _benefitRow(
            Icons.trending_up_rounded,
            'Инструменты роста',
            'Безлимит релизов, AI-генерации и расширенная аналитика — всё для масштабирования.',
          ),
          const SizedBox(height: 16),
          _benefitRow(
            Icons.speed_rounded,
            'Приоритет в системе',
            'Релизы проверяются быстрее, поддержка отвечает в первую очередь.',
          ),
          const SizedBox(height: 16),
          _benefitRow(
            Icons.auto_awesome_rounded,
            'AI-стратег под каждый релиз',
            '300 персональных AI-генераций: контент-планы, бюджеты, питчи.',
          ),
        ],
      ),
    );
  }

  Widget _benefitRow(IconData icon, String title, String desc) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: AurixTokens.accent.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: AurixTokens.accent, size: 20),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 15)),
              const SizedBox(height: 4),
              Text(desc, style: const TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.4)),
            ],
          ),
        ),
      ],
    );
  }
}

// ─── Plan Card ──────────────────────────────────────────────────────────

class _PlanCard extends StatefulWidget {
  final PlanConfig config;
  final bool isCurrent;
  final String priceLabel;
  final String? savingsLabel;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.config,
    required this.isCurrent,
    required this.priceLabel,
    this.savingsLabel,
    required this.onSubscribe,
  });

  @override
  State<_PlanCard> createState() => _PlanCardState();
}

class _PlanCardState extends State<_PlanCard> {
  bool _hovered = false;

  SubscriptionPlan get _plan => widget.config.plan;
  bool get _isStart => _plan == SubscriptionPlan.start;
  bool get _isBreakthrough => _plan == SubscriptionPlan.breakthrough;
  bool get _isEmpire => _plan == SubscriptionPlan.empire;

  Color get _accentColor => _isBreakthrough
      ? AurixTokens.accent
      : _isEmpire
          ? AurixTokens.aiAccent
          : AurixTokens.muted;

  @override
  Widget build(BuildContext context) {
    final borderColor = _isBreakthrough
        ? AurixTokens.accent.withValues(alpha: 0.6)
        : _isEmpire
            ? AurixTokens.aiAccent.withValues(alpha: 0.5)
            : AurixTokens.stroke(0.24);

    final borderWidth = _isBreakthrough ? 1.5 : _isEmpire ? 1.5 : 1.0;

    final glowColor = _isBreakthrough
        ? AurixTokens.accent.withValues(alpha: _hovered ? 0.16 : 0.08)
        : _isEmpire
            ? AurixTokens.aiAccent.withValues(alpha: _hovered ? 0.12 : 0.05)
            : Colors.transparent;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: AnimatedScale(
        scale: _hovered ? 1.015 : 1.0,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: _isEmpire
                  ? [
                      const Color(0xFF0F0D18),
                      AurixTokens.aiAccent.withValues(alpha: 0.04),
                    ]
                  : [
                      AurixTokens.bg1.withValues(alpha: 0.97),
                      AurixTokens.bg2.withValues(alpha: 0.92),
                    ],
            ),
            borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: [
              ...AurixTokens.subtleShadow,
              if (!_isStart)
                BoxShadow(color: glowColor, blurRadius: _hovered ? 28 : 18, spreadRadius: _hovered ? 1 : 0),
            ],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Badge (breakthrough only)
              if (_isBreakthrough) ...[
                Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          AurixTokens.accent,
                          AurixTokens.accent.withValues(alpha: 0.8),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(AurixTokens.radiusChip),
                      boxShadow: [BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.25), blurRadius: 12)],
                    ),
                    child: const Text(
                      'Самый популярный',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
              ],

              // Plan name
              Text(
                _plan.label.toUpperCase(),
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                      letterSpacing: 1,
                    ),
              ),

              // Plan subtitle
              if (_isStart)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text('Для теста платформы', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                ),
              if (_isEmpire)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    'Для тех, кто строит систему',
                    style: TextStyle(color: AurixTokens.aiAccent.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),

              // Active badge
              if (widget.isCurrent) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AurixTokens.positive.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AurixTokens.positive.withValues(alpha: 0.35)),
                    ),
                    child: Text(
                      'Активен',
                      style: TextStyle(color: AurixTokens.positive, fontSize: 11, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 16),

              // Price
              Text(
                widget.priceLabel,
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: _isStart ? AurixTokens.text : _accentColor,
                      fontWeight: FontWeight.w800,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
              ),
              if (widget.savingsLabel != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    widget.savingsLabel!,
                    style: const TextStyle(color: AurixTokens.positive, fontSize: 12, fontWeight: FontWeight.w600),
                  ),
                ),

              // Comparison badge (breakthrough)
              if (_isBreakthrough) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AurixTokens.accent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AurixTokens.accent.withValues(alpha: 0.15)),
                  ),
                  child: const Text(
                    '+37% больше инструментов роста\nпо сравнению со СТАРТ',
                    style: TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500, height: 1.4),
                  ),
                ),
              ],

              // Priority badge (empire)
              if (_isEmpire) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: AurixTokens.aiAccent.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AurixTokens.aiAccent.withValues(alpha: 0.15)),
                  ),
                  child: const Text(
                    'Максимальный приоритет внутри AURIX',
                    style: TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Features
              ...widget.config.featureKeys.map((key) {
                final isNegative = key == 'planStartStudioNo';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        isNegative ? Icons.remove_circle_outline : Icons.check_circle,
                        size: 18,
                        color: isNegative ? AurixTokens.muted.withValues(alpha: 0.4) : _accentColor.withValues(alpha: 0.8),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          L10n.t(context, key),
                          style: TextStyle(
                            color: isNegative ? AurixTokens.muted.withValues(alpha: 0.4) : AurixTokens.text,
                            fontSize: 14,
                            decoration: isNegative ? TextDecoration.lineThrough : null,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                );
              }),

              const SizedBox(height: 16),

              // CTA button
              PremiumHoverLift(
                child: _buildButton(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildButton() {
    if (widget.isCurrent) {
      return OutlinedButton(
        onPressed: null,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          side: BorderSide(color: AurixTokens.muted.withValues(alpha: 0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusField)),
        ),
        child: Text(
          'Текущий тариф',
          style: TextStyle(color: AurixTokens.muted),
        ),
      );
    }

    if (_isStart) {
      return OutlinedButton(
        onPressed: widget.onSubscribe,
        style: OutlinedButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 16),
          foregroundColor: AurixTokens.muted,
          side: BorderSide(color: AurixTokens.stroke(0.2)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusField)),
        ),
        child: const Text('Перейти к оплате'),
      );
    }

    if (_isBreakthrough) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AurixTokens.radiusField),
          gradient: LinearGradient(
            colors: [
              AurixTokens.accent,
              AurixTokens.accent.withValues(alpha: 0.85),
            ],
          ),
          boxShadow: [BoxShadow(color: AurixTokens.accent.withValues(alpha: 0.25), blurRadius: 16, offset: const Offset(0, 4))],
        ),
        child: FilledButton(
          onPressed: widget.onSubscribe,
          style: FilledButton.styleFrom(
            backgroundColor: Colors.transparent,
            foregroundColor: Colors.white,
            shadowColor: Colors.transparent,
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusField)),
            textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
          ),
          child: const Text('Перейти к оплате'),
        ),
      );
    }

    // Empire
    return FilledButton(
      onPressed: widget.onSubscribe,
      style: FilledButton.styleFrom(
        backgroundColor: AurixTokens.aiAccent,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusField)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
      child: const Text('Перейти к оплате'),
    );
  }
}
