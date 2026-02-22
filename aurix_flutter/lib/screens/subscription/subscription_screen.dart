import 'package:flutter/material.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/core/plan_config.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';

/// Подписка — выбор плана Basic / Pro / Studio.
/// Все тарифы из PlanConfig. Aurix Studio AI — только Pro и выше.
class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);

    final padding = horizontalPadding(context);
    return SingleChildScrollView(
      padding: EdgeInsets.all(padding),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                L10n.t(context, 'subscription'),
                style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 8),
              Text(
                appState.isSubscribed
                    ? '${L10n.t(context, 'active')} — ${L10n.t(context, appState.subscriptionPlan.name)}'
                    : L10n.t(context, 'inactive'),
                style: TextStyle(
                    color: appState.isSubscribed ? Colors.green : AurixTokens.muted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 24),
              Text(
                L10n.t(context, 'selectPlan'),
                style: TextStyle(color: AurixTokens.muted, fontSize: 16),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 8),
              Text(
                L10n.t(context, 'planSubtitle'),
                style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.5),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (!appState.isSubscribed || appState.subscriptionPlan == SubscriptionPlan.basic) ...[
                const SizedBox(height: 24),
                _WhatYouLoseWithoutProCard(onUpgrade: () => _showPaymentModal(context, ref, SubscriptionPlan.pro)),
              ],
              const SizedBox(height: 32),
              LayoutBuilder(
                builder: (context, constraints) {
                  final w = constraints.maxWidth;
                  final crossAxisCount = w > 900 ? 3 : (w > 600 ? 2 : 1);
                  return GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    crossAxisCount: crossAxisCount,
                    mainAxisSpacing: 20,
                    crossAxisSpacing: 20,
                    childAspectRatio: 0.65,
                    children: planConfigs.map((config) {
                      final isCurrent = appState.subscriptionPlan == config.plan && appState.isSubscribed;
                      final isPro = config.plan == SubscriptionPlan.pro;
                      return _PlanCard(
                        config: config,
                        isCurrent: isCurrent,
                        isHighlighted: isPro && !isCurrent,
                        onSubscribe: () => _showPaymentModal(context, ref, config.plan),
                      );
                    }).toList(),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showPaymentModal(
      BuildContext context, WidgetRef ref, SubscriptionPlan plan) {
    showDialog(
      context: context,
      builder: (ctx) => _PaymentModal(
        plan: plan,
        onSuccess: () {
          Navigator.of(ctx).pop();
          ref.read(appStateProvider).activateSubscription(plan);
        },
      ),
    );
  }
}

class _WhatYouLoseWithoutProCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _WhatYouLoseWithoutProCard({required this.onUpgrade});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.lock_outline_rounded, color: AurixTokens.orange, size: 22),
              const SizedBox(width: 10),
              Text(
                'Без Pro ты теряешь',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AurixTokens.text,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              _LoseChip(text: 'Безлимит релизов'),
              _LoseChip(text: 'Aurix Studio AI'),
              _LoseChip(text: 'Сплиты и доли'),
              _LoseChip(text: 'Content Kit'),
              _LoseChip(text: 'Приоритет проверки'),
            ],
          ),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onUpgrade,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
            label: Text('Перейти на Pro', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
            style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
          ),
        ],
      ),
    );
  }
}

class _LoseChip extends StatelessWidget {
  final String text;

  const _LoseChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AurixTokens.glass(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AurixTokens.stroke(0.12)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.remove_circle_outline, size: 16, color: AurixTokens.muted),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanConfig config;
  final bool isCurrent;
  final bool isHighlighted;
  final VoidCallback onSubscribe;

  const _PlanCard({
    required this.config,
    required this.isCurrent,
    this.isHighlighted = false,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final price = L10n.t(context, config.priceKey);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: isCurrent ? null : onSubscribe,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: isHighlighted ? const EdgeInsets.all(3) : EdgeInsets.zero,
          decoration: isHighlighted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AurixTokens.orange, width: 2),
                  boxShadow: [
                    BoxShadow(
                      color: AurixTokens.orange.withValues(alpha: 0.15),
                      blurRadius: 20,
                      spreadRadius: 0,
                    ),
                  ],
                )
              : null,
          child: AurixGlassCard(
            padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (config.badgeKey != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Center(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                      decoration: BoxDecoration(
                        color: AurixTokens.orange,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        L10n.t(context, config.badgeKey!),
                        style: TextStyle(
                            color: Colors.black,
                            fontWeight: FontWeight.w700,
                            fontSize: 12),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                  ),
                ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      L10n.t(context, config.plan.name).toUpperCase(),
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                  if (isCurrent)
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.green.withValues(alpha: 0.5)),
                      ),
                      child: Text(
                        L10n.t(context, 'active'),
                        style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        softWrap: false,
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                price,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AurixTokens.orange, fontWeight: FontWeight.w800),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
              ),
              const SizedBox(height: 20),
              Expanded(
                child: SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: config.featureKeys.map((key) {
                      final isNegative = key == 'planBasicStudioNo';
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              isNegative ? Icons.remove_circle_outline : Icons.check_circle,
                              size: 18,
                              color: isNegative ? AurixTokens.muted : AurixTokens.orange,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                L10n.t(context, key),
                                style: TextStyle(
                                  color: isNegative ? AurixTokens.muted : AurixTokens.text,
                                  fontSize: 14,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: AurixButton(
                  text: isCurrent
                      ? L10n.t(context, 'managePlan')
                      : L10n.t(context, 'subscribe'),
                  onPressed: isCurrent ? null : onSubscribe,
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

class _PaymentModal extends StatefulWidget {
  final SubscriptionPlan plan;
  final VoidCallback onSuccess;

  const _PaymentModal({required this.plan, required this.onSuccess});

  @override
  State<_PaymentModal> createState() => _PaymentModalState();
}

class _PaymentModalState extends State<_PaymentModal> {
  bool _success = false;

  @override
  Widget build(BuildContext context) {
    final maxW = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint
        ? kDialogMaxWidth
        : MediaQuery.sizeOf(context).width - 32;
    if (_success) {
      return Dialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: maxW),
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 64),
                  const SizedBox(height: 20),
                  Text(
                    L10n.t(context, 'paymentSuccess'),
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    softWrap: false,
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }
    return Dialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW, maxHeight: MediaQuery.sizeOf(context).height * 0.9),
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  L10n.t(context, 'payment'),
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                const SizedBox(height: 8),
                Text(
                  '${L10n.t(context, 'selectPlan')}: ${L10n.t(context, widget.plan.name)}',
                  style: TextStyle(color: AurixTokens.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  softWrap: false,
                ),
                const SizedBox(height: 24),
                Wrap(
                  spacing: 12,
                  runSpacing: 12,
                  children: [
                    _PaymentChip(label: L10n.t(context, 'applePay'), onTap: _handlePay),
                    _PaymentChip(label: L10n.t(context, 'card'), onTap: _handlePay),
                    _PaymentChip(label: L10n.t(context, 'stripe'), onTap: _handlePay),
                  ],
                ),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handlePay,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AurixTokens.orange,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: Text(
                      L10n.t(context, 'payDemo'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _handlePay() {
    setState(() => _success = true);
    Future.delayed(const Duration(milliseconds: 800), () {
      if (mounted) {
        Navigator.of(context).pop();
        widget.onSuccess();
      }
    });
  }
}

class _PaymentChip extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _PaymentChip({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          decoration: BoxDecoration(
            color: AurixTokens.glass(0.08),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AurixTokens.stroke(0.15)),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: AurixTokens.orange, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
          ),
        ),
      ),
    );
  }
}
