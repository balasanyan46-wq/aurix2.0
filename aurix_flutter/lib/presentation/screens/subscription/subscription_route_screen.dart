import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/core/plan_config.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Экран подписки для AurixApp (Supabase profile.plan).
class SubscriptionRouteScreen extends ConsumerWidget {
  const SubscriptionRouteScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(currentProfileProvider);
    final user = ref.watch(currentUserProvider);

    return profile.when(
      data: (p) {
        final plan = _profilePlanToEnum(p?.plan);
        final isSubscribed = p != null;
        return _SubscriptionWithProfile(
          plan: plan,
          isSubscribed: isSubscribed,
          onActivate: (newPlan) => _activatePlan(context, ref, user?.id, newPlan),
        );
      },
      loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
      error: (_, __) => const Scaffold(body: Center(child: Text('Ошибка загрузки'))),
    );
  }

  SubscriptionPlan _profilePlanToEnum(String? plan) {
    switch (plan) {
      case 'pro': return SubscriptionPlan.pro;
      case 'studio': return SubscriptionPlan.studio;
      default: return SubscriptionPlan.basic;
    }
  }

  Future<void> _activatePlan(
    BuildContext context,
    WidgetRef ref,
    String? userId,
    SubscriptionPlan plan,
  ) async {
    if (userId == null) return;
    final planStr = plan == SubscriptionPlan.pro ? 'pro' : plan == SubscriptionPlan.studio ? 'studio' : 'base';
    await ref.read(profileRepositoryProvider).updatePlan(userId, planStr);
    if (context.mounted) {
      ref.invalidate(currentProfileProvider);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(L10n.t(context, 'paymentSuccess'))),
      );
      context.go('/home');
    }
  }
}

class _SubscriptionWithProfile extends ConsumerWidget {
  final SubscriptionPlan plan;
  final bool isSubscribed;
  final void Function(SubscriptionPlan) onActivate;

  const _SubscriptionWithProfile({
    required this.plan,
    required this.isSubscribed,
    required this.onActivate,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Подписка'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 1100),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'Подписка',
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                Text(
                  isSubscribed ? 'Активна — ${_planName(plan)}' : 'Не активна',
                  style: TextStyle(
                    color: isSubscribed ? Colors.green : Colors.grey,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (!isSubscribed || plan == SubscriptionPlan.basic) ...[
                  const SizedBox(height: 24),
                  _WhatYouLoseCard(onUpgrade: () => _showPaymentModal(context, SubscriptionPlan.pro)),
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
                        final isCurrent = plan == config.plan && isSubscribed;
                        final isPro = config.plan == SubscriptionPlan.pro;
                        return _PlanCardWrapper(
                          config: config,
                          isCurrent: isCurrent,
                          isHighlighted: isPro && !isCurrent,
                          onSubscribe: () => _showPaymentModal(context, config.plan),
                        );
                      }).toList(),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _planName(SubscriptionPlan p) {
    switch (p) {
      case SubscriptionPlan.basic: return 'Базовый';
      case SubscriptionPlan.pro: return 'Pro';
      case SubscriptionPlan.studio: return 'Studio';
    }
  }

  void _showPaymentModal(BuildContext context, SubscriptionPlan plan) {
    final activate = onActivate;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Оплата'),
        content: Text('Демо: нажмите «Оплатить» для активации плана ${plan.name}.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              activate(plan);
            },
            child: const Text('Оплатить (демо)'),
          ),
        ],
      ),
    );
  }
}

class _WhatYouLoseCard extends StatelessWidget {
  final VoidCallback onUpgrade;

  const _WhatYouLoseCard({required this.onUpgrade});

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

class _PlanCardWrapper extends StatelessWidget {
  final PlanConfig config;
  final bool isCurrent;
  final bool isHighlighted;
  final VoidCallback onSubscribe;

  const _PlanCardWrapper({
    required this.config,
    required this.isCurrent,
    this.isHighlighted = false,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    return _PlanCardSimple(
      config: config,
      isCurrent: isCurrent,
      isHighlighted: isHighlighted,
      onSubscribe: onSubscribe,
    );
  }
}

class _PlanCardSimple extends StatelessWidget {
  final PlanConfig config;
  final bool isCurrent;
  final bool isHighlighted;
  final VoidCallback onSubscribe;

  const _PlanCardSimple({
    required this.config,
    required this.isCurrent,
    this.isHighlighted = false,
    required this.onSubscribe,
  });

  @override
  Widget build(BuildContext context) {
    final child = Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.plan.name.toUpperCase(),
              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              L10n.t(context, config.priceKey),
              style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.orange),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: config.featureKeys.take(5).map((k) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.check_circle, size: 18, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(child: Text(L10n.t(context, k), style: const TextStyle(fontSize: 14))),
                      ],
                    ),
                  )).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: isCurrent ? null : onSubscribe,
                child: Text(isCurrent ? L10n.t(context, 'managePlan') : L10n.t(context, 'subscribe')),
              ),
            ),
          ],
        ),
      ),
    );
    if (isHighlighted) {
      return Container(
        padding: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AurixTokens.orange, width: 2),
        ),
        child: child,
      );
    }
    return child;
  }
}
