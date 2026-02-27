import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/screens/release_os/release_workspace_screen.dart';
import 'package:aurix_flutter/screens/releases/release_create_flow_screen.dart';

/// Release OS — список релизов. Клик → Release Workspace.
class ReleaseOSScreen extends ConsumerWidget {
  const ReleaseOSScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final asyncReleases = ref.watch(releasesProvider);
    final releases = asyncReleases.valueOrNull ?? [];
    final pad = horizontalPadding(context);

    if (asyncReleases.isLoading && releases.isEmpty) {
      return Center(child: CircularProgressIndicator(color: AurixTokens.orange));
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(pad),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, c) {
              final narrow = c.maxWidth < 520;
              return Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                runSpacing: 12,
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: narrow ? c.maxWidth : 420),
                    child: Text(
                      'Release OS',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
                    ),
                  ),
                  AurixButton(
                    text: L10n.t(context, 'newRelease'),
                    icon: Icons.add_rounded,
                    onPressed: appState.canSubmitRelease
                        ? () => Navigator.of(context).push(
                              PageRouteBuilder(
                                pageBuilder: (_, __, ___) => const ReleaseCreateFlowScreen(),
                                transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                              ),
                            )
                        : () => _showUpgradeModal(context, ref),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 8),
          Text(
            L10n.t(context, 'releaseStatus'),
            style: TextStyle(color: AurixTokens.muted, fontSize: 14),
          ),
          const SizedBox(height: 24),
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
                          ? () => Navigator.of(context).push(
                                PageRouteBuilder(
                                  pageBuilder: (_, __, ___) => const ReleaseCreateFlowScreen(),
                                  transitionsBuilder: (_, a, __, c) => FadeTransition(opacity: a, child: c),
                                ),
                              )
                          : () => _showUpgradeModal(context, ref),
                    ),
                  ],
                ),
              ),
            )
          else
            ...releases.map((r) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: _ReleaseCard(
                    release: r,
                    onTap: () => Navigator.of(context).push(
                      PageRouteBuilder(
                        pageBuilder: (_, __, ___) => ReleaseWorkspaceScreen(release: r),
                        transitionsBuilder: (_, a, __, c) => FadeTransition(
                          opacity: a,
                          child: SlideTransition(
                            position: Tween<Offset>(begin: const Offset(0.03, 0), end: Offset.zero).animate(a),
                            child: c,
                          ),
                        ),
                      ),
                    ),
                  ),
                )),
        ],
      ),
    );
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
              Navigator.pop(ctx);
              ref.read(appStateProvider).navigateTo(AppScreen.subscription);
            },
            child: Text(L10n.t(context, 'viewPlans')),
          ),
        ],
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  final ReleaseModel release;
  final VoidCallback onTap;

  const _ReleaseCard({required this.release, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final status = releaseStatusFromString(release.status);
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: InkWell(
        onTap: onTap,
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
                  Text(release.title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(
                    '${release.releaseType} • ${status.label}',
                    style: TextStyle(color: AurixTokens.muted, fontSize: 13),
                  ),
                  if (release.releaseDate != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      '${release.releaseDate!.day}.${release.releaseDate!.month}.${release.releaseDate!.year}',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            _StatusChip(status: status),
            const SizedBox(width: 16),
            Icon(Icons.chevron_right, color: AurixTokens.muted),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final ReleaseStatus status;

  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      ReleaseStatus.live => Colors.green,
      ReleaseStatus.inReview => AurixTokens.orange,
      ReleaseStatus.rejected => Colors.red,
      _ => AurixTokens.muted,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.5)),
      ),
      child: Text(status.label, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
