import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/core/plan_config.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileAsync = ref.watch(currentProfileProvider);
    final profile = profileAsync.valueOrNull;
    final currentSlug = profile?.plan ?? 'start';
    final currentPlan = SubscriptionPlan.fromSlug(currentSlug);
    final isAdmin = profile?.isAdmin ?? false;

    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding(context)),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 1100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      L10n.t(context, 'subscription'),
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AurixTokens.orange.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.3)),
                    ),
                    child: Text(
                      'Текущий план: ${currentPlan.label}',
                      style: TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                L10n.t(context, 'planSubtitle'),
                style: TextStyle(color: AurixTokens.muted, fontSize: 14),
              ),
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
                      final isCurrent = currentPlan == config.plan;
                      final isRecommended = config.plan == SubscriptionPlan.breakthrough;
                      return _PlanCard(
                        config: config,
                        isCurrent: isCurrent,
                        isHighlighted: isRecommended && !isCurrent,
                        isAdmin: isAdmin,
                        onSubscribe: () => _confirmUpgrade(context, ref, config, currentPlan),
                      );
                    }).toList(),
                  );
                },
              ),
              const SizedBox(height: 32),
              AurixGlassCard(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.mail_outline_rounded, color: AurixTokens.orange, size: 20),
                        const SizedBox(width: 10),
                        Text('Нужна помощь с выбором?', style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('Напишите в поддержку — поможем выбрать план.', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _confirmUpgrade(BuildContext context, WidgetRef ref, PlanConfig config, SubscriptionPlan currentPlan) {
    final newPlan = config.plan;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text('Перейти на ${newPlan.label}?', style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700)),
        content: Text(
          'Ваш план изменится на ${newPlan.label} (${L10n.t(context, config.priceKey)}).',
          style: TextStyle(color: AurixTokens.muted),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              final user = ref.read(currentUserProvider);
              if (user == null) return;
              await ref.read(profileRepositoryProvider).updatePlan(user.id, newPlan.slug);
              ref.invalidate(currentProfileProvider);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('План обновлён на ${newPlan.label}')),
                );
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
            child: const Text('Подтвердить'),
          ),
        ],
      ),
    );
  }
}

class _PlanCard extends StatelessWidget {
  final PlanConfig config;
  final bool isCurrent;
  final bool isHighlighted;
  final bool isAdmin;
  final VoidCallback onSubscribe;

  const _PlanCard({required this.config, required this.isCurrent, this.isHighlighted = false, this.isAdmin = false, required this.onSubscribe});

  @override
  Widget build(BuildContext context) {
    final price = L10n.t(context, config.priceKey);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: (isCurrent && !isAdmin) ? null : onSubscribe,
        borderRadius: BorderRadius.circular(18),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: isHighlighted ? const EdgeInsets.all(3) : EdgeInsets.zero,
          decoration: isHighlighted
              ? BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: AurixTokens.orange, width: 2),
                  boxShadow: [BoxShadow(color: AurixTokens.orange.withValues(alpha: 0.15), blurRadius: 20)],
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
                        decoration: BoxDecoration(color: AurixTokens.orange, borderRadius: BorderRadius.circular(20)),
                        child: Text(L10n.t(context, config.badgeKey!), style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w700, fontSize: 12)),
                      ),
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(config.plan.label.toUpperCase(),
                          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
                    ),
                    if (isCurrent)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(8), border: Border.all(color: Colors.green.withValues(alpha: 0.5))),
                        child: const Text('Активен', style: TextStyle(color: Colors.green, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(price, style: Theme.of(context).textTheme.titleLarge?.copyWith(color: AurixTokens.orange, fontWeight: FontWeight.w800), overflow: TextOverflow.ellipsis),
                const SizedBox(height: 20),
                Expanded(
                  child: SingleChildScrollView(
                    physics: const ClampingScrollPhysics(),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: config.featureKeys.map((key) {
                        final isNegative = key == 'planStartStudioNo';
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(isNegative ? Icons.remove_circle_outline : Icons.check_circle, size: 18, color: isNegative ? AurixTokens.muted : AurixTokens.orange),
                              const SizedBox(width: 10),
                              Expanded(child: Text(L10n.t(context, key), style: TextStyle(color: isNegative ? AurixTokens.muted : AurixTokens.text, fontSize: 14), maxLines: 2, overflow: TextOverflow.ellipsis)),
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
                  child: isCurrent
                      ? OutlinedButton(
                          onPressed: isAdmin ? onSubscribe : null,
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            side: BorderSide(color: isCurrent && isAdmin ? AurixTokens.orange : AurixTokens.muted),
                          ),
                          child: Text(
                            isCurrent && isAdmin ? 'Текущий (изменить)' : 'Текущий план',
                            style: TextStyle(color: isCurrent && isAdmin ? AurixTokens.orange : AurixTokens.muted),
                          ),
                        )
                      : FilledButton(
                          onPressed: onSubscribe,
                          style: FilledButton.styleFrom(
                            backgroundColor: AurixTokens.orange,
                            foregroundColor: Colors.black,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                          child: const Text('Выбрать'),
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
