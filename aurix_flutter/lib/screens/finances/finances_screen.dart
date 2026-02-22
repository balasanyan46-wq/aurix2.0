import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';

/// Финансы — без демо-данных. Показывает EmptyState.
class FinancesScreen extends ConsumerWidget {
  const FinancesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          FadeInSlide(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(L10n.t(context, 'finances'),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 8),
                Text('Доходы и выплаты',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 16)),
              ],
            ),
          ),
          const SizedBox(height: 40),
          FadeInSlide(
            delayMs: 50,
            child: AurixGlassCard(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.account_balance_wallet_outlined, size: 64, color: AurixTokens.muted),
                    const SizedBox(height: 24),
                    Text(
                      'Пока нет данных',
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600, color: AurixTokens.text),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Пока нет данных. Здесь появятся начисления после релизов.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: AurixTokens.muted, fontSize: 16, height: 1.5),
                    ),
                    const SizedBox(height: 24),
                    FilledButton.icon(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Загрузка отчёта — скоро')),
                        );
                      },
                      icon: const Icon(Icons.upload_file, size: 20),
                      label: const Text('Загрузить отчёт'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AurixTokens.orange,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
