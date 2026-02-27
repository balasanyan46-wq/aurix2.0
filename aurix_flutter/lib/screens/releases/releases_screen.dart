import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/screens/releases/release_create_flow_screen.dart';
import 'package:aurix_flutter/screens/releases/release_detail_screen.dart';

class ReleasesScreen extends ConsumerWidget {
  const ReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final asyncReleases = ref.watch(releasesProvider);
    final releases = asyncReleases.valueOrNull ?? [];

    if (asyncReleases.isLoading && releases.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AurixTokens.orange));
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(L10n.t(context, 'releases'), style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 4),
                  Text('Управление релизами', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                ],
              ),
              AurixButton(
                text: L10n.t(context, 'createRelease'),
                icon: Icons.add_rounded,
                onPressed: appState.canSubmitRelease
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ReleaseCreateFlowScreen(),
                          ),
                        )
                    : () => _showUpgradeModal(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 32),
          if (releases.isEmpty)
            AurixGlassCard(
              padding: const EdgeInsets.all(48),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.album_outlined, size: 64, color: AurixTokens.muted),
                    const SizedBox(height: 16),
                    Text(L10n.t(context, 'noReleasesYet'), style: TextStyle(color: AurixTokens.muted, fontSize: 16)),
                    const SizedBox(height: 20),
                    AurixButton(
                      text: L10n.t(context, 'createRelease'),
                      icon: Icons.add_rounded,
                      onPressed: appState.canSubmitRelease
                          ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReleaseCreateFlowScreen()))
                          : () => _showUpgradeModal(context, ref),
                    ),
                  ],
                ),
              ),
            )
          else
            ...releases.map((r) {
              final status = releaseStatusFromString(r.status);
              return Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: AurixGlassCard(
                  padding: const EdgeInsets.all(20),
                  child: InkWell(
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => ReleaseDetailScreen(release: r)),
                    ),
                    borderRadius: BorderRadius.circular(18),
                    child: Row(
                      children: [
                        Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AurixTokens.glass(0.2),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(Icons.album_rounded, size: 32, color: AurixTokens.orange.withValues(alpha: 0.8)),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(r.title, style: Theme.of(context).textTheme.titleMedium),
                              Text(r.releaseType, style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                          decoration: BoxDecoration(
                            color: _statusColor(status).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: _statusColor(status).withValues(alpha: 0.5)),
                          ),
                          child: Text(status.label, style: TextStyle(color: _statusColor(status), fontSize: 12, fontWeight: FontWeight.w600)),
                        ),
                        const SizedBox(width: 16),
                        Icon(Icons.chevron_right, color: AurixTokens.muted),
                      ],
                    ),
                  ),
                ),
              );
            }),
        ],
      ),
    );
  }

  Color _statusColor(ReleaseStatus s) {
    switch (s) {
      case ReleaseStatus.live:
        return Colors.green;
      case ReleaseStatus.inReview:
        return AurixTokens.orange;
      case ReleaseStatus.rejected:
        return Colors.red;
      default:
        return AurixTokens.muted;
    }
  }

  void _showUpgradeModal(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text(L10n.t(context, 'upgradeRequired')),
        content: Text(L10n.t(context, 'upgradeRequiredDesc')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(L10n.t(context, 'back'))),
          FilledButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              ref.read(appStateProvider).navigateTo(AppScreen.subscription);
            },
            child: Text(L10n.t(context, 'viewPlans')),
          ),
        ],
      ),
    );
  }
}
