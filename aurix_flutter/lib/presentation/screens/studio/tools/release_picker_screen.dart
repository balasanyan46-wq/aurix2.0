import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';

import 'growth_plan_form_screen.dart';
import 'budget_form_screen.dart';
import 'packaging_form_screen.dart';
import 'content_plan_form_screen.dart';
import 'pitch_pack_form_screen.dart';

enum ToolType { growth, budget, packaging, contentPlan, pitchPack }

String toolTypeLabel(ToolType t) => switch (t) {
  ToolType.growth => 'Карта роста релиза',
  ToolType.budget => 'Бюджет-менеджер',
  ToolType.packaging => 'AI-Упаковка релиза',
  ToolType.contentPlan => 'Контент-план 14 дней',
  ToolType.pitchPack => 'Плейлист-питч пакет',
};

class ReleasePickerScreen extends ConsumerStatefulWidget {
  final ToolType toolType;
  const ReleasePickerScreen({super.key, required this.toolType});

  @override
  ConsumerState<ReleasePickerScreen> createState() => _ReleasePickerScreenState();
}

class _ReleasePickerScreenState extends ConsumerState<ReleasePickerScreen> {
  List<ReleaseModel>? _releases;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadReleases();
  }

  Future<void> _loadReleases() async {
    try {
      final user = ref.read(currentUserProvider);
      if (user == null) {
        setState(() { _loading = false; _error = 'Не авторизован'; });
        return;
      }
      final releases = await ref.read(releaseRepositoryProvider).getReleasesByOwner(user.id);
      setState(() { _releases = releases; _loading = false; });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(toolTypeLabel(widget.toolType))),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)));
    if (_releases == null || _releases!.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.album_outlined, size: 64, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3)),
              const SizedBox(height: 16),
              Text('У вас пока нет релизов', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              Text('Создайте релиз, чтобы использовать этот инструмент',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5))),
            ],
          ),
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _releases!.length + 1,
      itemBuilder: (context, index) {
        if (index == 0) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text('Выберите релиз',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
          );
        }
        final release = _releases![index - 1];
        return _ReleaseCard(release: release, onTap: () => _openTool(release));
      },
    );
  }

  void _openTool(ReleaseModel release) {
    Widget screen;
    switch (widget.toolType) {
      case ToolType.growth:
        screen = GrowthPlanFormScreen(release: release);
      case ToolType.budget:
        screen = BudgetFormScreen(release: release);
      case ToolType.packaging:
        screen = PackagingFormScreen(release: release);
      case ToolType.contentPlan:
        screen = ContentPlanFormScreen(release: release);
      case ToolType.pitchPack:
        screen = PitchPackFormScreen(release: release);
    }
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
  }
}

class _ReleaseCard extends StatelessWidget {
  final ReleaseModel release;
  final VoidCallback onTap;

  const _ReleaseCard({required this.release, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.25),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  width: 44, height: 44,
                  decoration: BoxDecoration(
                    color: cs.primary.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    image: release.coverUrl != null
                        ? DecorationImage(image: NetworkImage(release.coverUrl!), fit: BoxFit.cover)
                        : null,
                  ),
                  child: release.coverUrl == null
                      ? Icon(Icons.album_rounded, color: cs.primary, size: 22)
                      : null,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(release.title,
                        style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 2),
                      Text(
                        [if (release.artist != null) release.artist!, release.genre ?? '']
                            .where((s) => s.isNotEmpty).join(' · '),
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: cs.onSurface.withValues(alpha: 0.5)),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right_rounded, size: 20, color: cs.onSurface.withValues(alpha: 0.3)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
