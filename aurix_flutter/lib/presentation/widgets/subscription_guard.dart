import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/subscription_provider.dart';

class SubscriptionGuard extends ConsumerWidget {
  const SubscriptionGuard({
    super.key,
    required this.requiredPlan,
    required this.child,
    this.lockedTitle,
    this.lockedSubtitle,
  });

  final String requiredPlan;
  final Widget child;
  final String? lockedTitle;
  final String? lockedSubtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasPlanAccessProvider(requiredPlan));
    if (hasAccess) return child;
    return _SubscriptionPaywall(
      title: lockedTitle ?? 'Функция недоступна на текущем тарифе',
      subtitle: lockedSubtitle ??
          'Открой доступ на тарифе ${_label(requiredPlan)}. Также проверь, что подписка активна.',
    );
  }

  String _label(String slug) {
    switch (slug) {
      case 'empire':
        return 'Империя';
      case 'breakthrough':
        return 'Прорыв';
      default:
        return 'Старт';
    }
  }
}

class _SubscriptionPaywall extends StatelessWidget {
  const _SubscriptionPaywall({required this.title, required this.subtitle});

  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: Container(
          margin: const EdgeInsets.all(20),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AurixTokens.stroke(0.2)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.lock_rounded, color: AurixTokens.orange, size: 42),
              const SizedBox(height: 12),
              Text(
                title,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  color: AurixTokens.text,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
              ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: () => context.go('/subscription'),
                style: FilledButton.styleFrom(
                  backgroundColor: AurixTokens.orange,
                  foregroundColor: Colors.black,
                ),
                icon: const Icon(Icons.workspace_premium_rounded),
                label: const Text('Открыть тарифы'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

