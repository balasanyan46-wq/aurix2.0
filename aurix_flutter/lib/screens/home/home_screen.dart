import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/screens/releases/release_create_flow_screen.dart';
import 'package:aurix_flutter/screens/home/home_dashboard_widgets.dart';

/// Главная — дашборд карьеры артиста.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({
    super.key,
    this.onViewDemo,
    this.onCreateRelease,
    this.onViewReleases,
    this.onViewSubscription,
    this.onViewIndex,
  });

  /// При использовании с go_router — callback вместо appState.navigateTo
  final VoidCallback? onViewDemo;
  final VoidCallback? onCreateRelease;
  final VoidCallback? onViewReleases;
  final VoidCallback? onViewSubscription;
  final VoidCallback? onViewIndex;

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    final appState = ref.watch(appStateProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          HomeIndexHero(
            onImproveIndex: () => _showHowToRise(context),
            onCreateRelease: widget.onCreateRelease ??
                (appState.canSubmitRelease
                    ? () => Navigator.of(context).push(
                          MaterialPageRoute(
                              builder: (_) => const ReleaseCreateFlowScreen()),
                        )
                    : () => _showUpgradeModal(context, ref, widget.onViewSubscription)),
          ),
          const SizedBox(height: 24),
          HomeCareerTrajectory(onViewIndex: widget.onViewIndex ?? () => appState.navigateTo(AppScreen.aurixIndex)),
          const SizedBox(height: 24),
          HomeNextStepAI(onHowToRise: () => _showHowToRise(context)),
          const SizedBox(height: 24),
          HomeLeadersMinimal(onViewIndex: widget.onViewIndex ?? () => appState.navigateTo(AppScreen.aurixIndex)),
          const SizedBox(height: 24),
          HomeActiveRelease(
            onViewReleases: widget.onViewReleases ?? () => appState.navigateTo(AppScreen.releases),
            onCreateRelease: widget.onCreateRelease ?? () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ReleaseCreateFlowScreen())),
          ),
        ],
      ),
    );
  }

  void _showHowToRise(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AurixTokens.bg1,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Как увеличить индекс', style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 16),
            _tip('Увеличь регулярность релизов', 'Выпускай треки раз в 1–2 месяца'),
            _tip('Работай над сохранениями', 'Saves и shares сильно влияют на Index'),
            _tip('Делай коллабы', 'Коллаборации повышают Community-компонент'),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }

  Widget _tip(String title, String desc) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: TextStyle(color: AurixTokens.orange, fontSize: 14, fontWeight: FontWeight.w600)),
          const SizedBox(height: 4),
          Text(desc, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
        ],
      ),
    );
  }

  void _showUpgradeModal(BuildContext context, WidgetRef ref, VoidCallback? onViewSubscription) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text(L10n.t(context, 'upgradeRequired')),
        content: Text(L10n.t(context, 'upgradeRequiredDesc')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(L10n.t(context, 'back'))),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              (onViewSubscription ?? () => ref.read(appStateProvider).navigateTo(AppScreen.subscription))();
            },
            child: Text(L10n.t(context, 'viewPlans')),
          ),
        ],
      ),
    );
  }
}
