import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/presentation/screens/studio_ai/track_analysis_screen.dart';

class StudioScreen extends ConsumerWidget {
  final String? releaseId;

  const StudioScreen({super.key, this.releaseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasAccess = ref.watch(hasStudioAccessProvider);

    return hasAccess.when(
      data: (access) {
        if (access) return TrackAnalysisScreen(releaseId: releaseId);
        return _PaywallScreen();
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (_, __) => TrackAnalysisScreen(releaseId: releaseId),
    );
  }
}

class _PaywallScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock_outline, size: 64, color: AurixTokens.accent),
            const SizedBox(height: 24),
            Text(
              'Aurix Studio AI доступен в планах Прорыв и Империя',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            Text(
              'Оформите подписку Прорыв или Империя, чтобы использовать продюсерский AI.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AurixTokens.muted),
            ),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: () => context.push('/subscription'),
              child: const Text('К планам'),
            ),
            const SizedBox(height: 12),
            TextButton(
              onPressed: () { if (context.canPop()) context.pop(); else context.go('/home'); },
              child: const Text('На главную'),
            ),
          ],
        ),
      ),
    );
  }
}
