import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/design/components/liquid_glass.dart';
import 'package:aurix_flutter/screens/releases/release_create_flow_screen.dart';

class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appState = ref.watch(appStateProvider);
    final asyncReleases = ref.watch(releasesProvider);
    final releases = asyncReleases.valueOrNull ?? [];
    final activeCount = releases.where((r) => r.status == 'live').length;
    final pendingCount = releases.where((r) => r.status == 'submitted').length;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              return Wrap(
                spacing: 16,
                runSpacing: 16,
                children: [
                  _OverviewCard(title: L10n.t(context, 'activeReleases'), value: '$activeCount', icon: Icons.album_rounded),
                  _OverviewCard(title: L10n.t(context, 'pendingReview'), value: '$pendingCount', icon: Icons.schedule_rounded),
                  _OverviewCard(title: L10n.t(context, 'totalStreams'), value: '0', icon: Icons.play_circle_rounded),
                  _OverviewCard(title: L10n.t(context, 'estRevenue'), value: '—', icon: Icons.payments_rounded),
                ],
              );
            },
          ),
          const SizedBox(height: 32),
          Text(L10n.t(context, 'releaseStatus'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          AurixGlassCard(
            padding: const EdgeInsets.all(20),
            child: _ReleaseTimeline(releases: releases),
          ),
          const SizedBox(height: 32),
          Text(L10n.t(context, 'quickActions'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              AurixButton(
                text: L10n.t(context, 'newRelease'),
                onPressed: appState.canSubmitRelease
                    ? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReleaseCreateFlowScreen()))
                    : null,
                icon: Icons.add_rounded,
              ),
              AurixButton(
                text: L10n.t(context, 'uploadTrack'),
                onPressed: () => ref.read(appStateProvider).navigateTo(AppScreen.releases),
                icon: Icons.upload_rounded,
              ),
              AurixButton(
                text: L10n.t(context, 'planLaunch'),
                onPressed: () => ref.read(appStateProvider).navigateTo(AppScreen.promotion),
                icon: Icons.rocket_launch_rounded,
              ),
              AurixButton(
                text: L10n.t(context, 'viewAnalytics'),
                onPressed: () => ref.read(appStateProvider).navigateTo(AppScreen.analytics),
                icon: Icons.analytics_rounded,
              ),
            ],
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, c) {
              final useRow = c.maxWidth > 700;
              return useRow
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 2,
                          child: AurixGlassCard(
                            padding: const EdgeInsets.all(20),
                            child: _SpotlightSection(releases: releases),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: LiquidGlass(
                            level: GlassLevel.medium,
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(L10n.t(context, 'growthInsights'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                                const SizedBox(height: 16),
                                _InsightChip(
                                  icon: Icons.trending_up,
                                  text: L10n.t(context, 'statsCsvNote'),
                                  color: AurixTokens.orange,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    )
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        AurixGlassCard(
                          padding: const EdgeInsets.all(20),
                          child: _SpotlightSection(releases: releases),
                        ),
                        const SizedBox(height: 20),
                        LiquidGlass(
                          level: GlassLevel.medium,
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(L10n.t(context, 'growthInsights'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
                              const SizedBox(height: 16),
                              _InsightChip(
                                icon: Icons.trending_up,
                                text: L10n.t(context, 'statsCsvNote'),
                                color: AurixTokens.orange,
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
            },
          ),
          const SizedBox(height: 32),
          LayoutBuilder(
            builder: (context, c) {
              final useRow = c.maxWidth > 800;
              return useRow
                  ? Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: _WhatIsAurixCard(onLearnMore: () => ref.read(appStateProvider).navigateTo(AppScreen.subscription))),
                        const SizedBox(width: 20),
                        Expanded(child: _WhyInnovativeCard(onLearnMore: () => ref.read(appStateProvider).navigateTo(AppScreen.subscription))),
                      ],
                    )
                  : Column(
                      children: [
                        _WhatIsAurixCard(onLearnMore: () => ref.read(appStateProvider).navigateTo(AppScreen.subscription)),
                        const SizedBox(height: 20),
                        _WhyInnovativeCard(onLearnMore: () => ref.read(appStateProvider).navigateTo(AppScreen.subscription)),
                      ],
                    );
            },
          ),
        ],
      ),
    );
  }
}

class _OverviewCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;

  const _OverviewCard({required this.title, required this.value, required this.icon});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 200,
      child: AurixGlassCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(title, style: TextStyle(color: AurixTokens.muted, fontSize: 13, fontWeight: FontWeight.w500)),
                Icon(icon, color: AurixTokens.orange.withValues(alpha: 0.8), size: 20),
              ],
            ),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
          ],
        ),
      ),
    );
  }
}

class _ReleaseTimeline extends StatelessWidget {
  final List<ReleaseModel> releases;

  const _ReleaseTimeline({required this.releases});

  @override
  Widget build(BuildContext context) {
    const steps = ['Черновик', 'На проверке', 'Одобрен', 'Запланирован', 'Выпущен'];
    final hasDraft = releases.any((r) => r.status == 'draft');
    final hasSubmitted = releases.any((r) => r.status == 'submitted');
    final hasLive = releases.any((r) => r.status == 'live');
    final stepIndex = hasLive ? 4 : (hasSubmitted ? 2 : (hasDraft ? 1 : 0));

    return Row(
      children: [
        for (var i = 0; i < steps.length; i++) ...[
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: i <= stepIndex ? AurixTokens.orange.withValues(alpha: 0.3) : AurixTokens.glass(0.06),
                    border: Border.all(color: i <= stepIndex ? AurixTokens.orange : AurixTokens.stroke()),
                  ),
                  child: Center(
                    child: i <= stepIndex
                        ? Icon(Icons.check, size: 16, color: AurixTokens.orange)
                        : Text('${i + 1}', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ),
                ),
                const SizedBox(height: 8),
                Text(steps[i], style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
          if (i < steps.length - 1)
            Container(
              width: 24,
              height: 2,
              color: AurixTokens.stroke(0.2),
            ),
        ],
      ],
    );
  }
}

class _WhatIsAurixCard extends StatelessWidget {
  final VoidCallback? onLearnMore;

  const _WhatIsAurixCard({this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.t(context, 'whatIsAurix'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _Bullet(L10n.t(context, 'whatIsAurixP1')),
          _Bullet(L10n.t(context, 'whatIsAurixP2')),
          _Bullet(L10n.t(context, 'whatIsAurixP3')),
          _Bullet(L10n.t(context, 'whatIsAurixP4')),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onLearnMore,
            icon: Icon(Icons.arrow_forward_rounded, size: 16, color: AurixTokens.orange),
            label: Text(L10n.t(context, 'learnMore'), style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;

  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('• ', style: TextStyle(color: AurixTokens.orange, fontSize: 14)),
          Expanded(child: Text(text, style: TextStyle(color: AurixTokens.text, fontSize: 14))),
        ],
      ),
    );
  }
}

class _WhyInnovativeCard extends StatelessWidget {
  final VoidCallback? onLearnMore;

  const _WhyInnovativeCard({this.onLearnMore});

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(L10n.t(context, 'whyInnovative'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 16),
          _Bullet(L10n.t(context, 'whyP1')),
          _Bullet(L10n.t(context, 'whyP2')),
          _Bullet(L10n.t(context, 'whyP3')),
          _Bullet(L10n.t(context, 'whyP4')),
          _Bullet(L10n.t(context, 'whyP5')),
          const SizedBox(height: 16),
          TextButton.icon(
            onPressed: onLearnMore,
            icon: Icon(Icons.arrow_forward_rounded, size: 16, color: AurixTokens.orange),
            label: Text(L10n.t(context, 'learnMore'), style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }
}

class _SpotlightSection extends ConsumerWidget {
  final List<ReleaseModel> releases;

  const _SpotlightSection({required this.releases});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mainRelease = releases.isNotEmpty ? releases.first : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(L10n.t(context, 'spotlight'), style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text('Текущий релиз', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
        const SizedBox(height: 16),
        if (mainRelease != null) ...[
          Text(mainRelease.title, style: Theme.of(context).textTheme.titleMedium),
          Text(mainRelease.releaseType, style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
          const SizedBox(height: 16),
          AurixButton(
            text: L10n.t(context, 'viewAnalytics'),
            onPressed: () => ref.read(appStateProvider).navigateTo(AppScreen.analytics),
            icon: Icons.analytics_rounded,
          ),
        ] else
          Text(L10n.t(context, 'noReleasesYet'), style: TextStyle(color: AurixTokens.muted)),
      ],
    );
  }
}

class _InsightChip extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _InsightChip({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: TextStyle(color: AurixTokens.text, fontSize: 14))),
      ],
    );
  }
}
