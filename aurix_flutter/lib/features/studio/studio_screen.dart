import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/screens/studio_ai/studio_ai_screen.dart';

/// Studio AI в shell. Paywall если нет доступа.
class StudioScreen extends ConsumerWidget {
  const StudioScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasStudioAccessProvider);

    return hasAccess.when(
      data: (access) {
        if (access) {
          return const _StudioChatScreen();
        }
        return _PaywallScreen();
      },
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (_, __) => const _StudioChatScreen(),
    );
  }
}

class _StudioChatScreen extends StatelessWidget {
  const _StudioChatScreen();

  @override
  Widget build(BuildContext context) {
    return const StudioAiScreen();
  }
}

class _PaywallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Studio AI')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.lock_outline, size: 64, color: Theme.of(context).colorScheme.primary),
              const SizedBox(height: 24),
              Text(
                'Studio AI доступен в планах Прорыв и Империя',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Text(
                'Оформите подписку, чтобы использовать AI.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: Colors.grey),
              ),
              const SizedBox(height: 32),
              FilledButton(
                onPressed: () => context.push('/subscription'),
                child: const Text('К планам'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
