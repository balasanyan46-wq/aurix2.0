import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:aurix_flutter/core/app_state.dart';
import 'package:aurix_flutter/core/enums.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';

/// Release Workspace — табы: Overview, Tracks, Metadata, Splits, Launch Plan, Review.
class ReleaseWorkspaceScreen extends ConsumerWidget {
  final ReleaseModel release;

  const ReleaseWorkspaceScreen({super.key, required this.release});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statusLabel = releaseStatusFromString(release.status).label;
    return DefaultTabController(
      length: 6,
      child: Scaffold(
        backgroundColor: AurixTokens.bg0,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          title: Text(release.title),
          bottom: TabBar(
            isScrollable: true,
            tabs: const [
              Tab(text: 'Обзор'),
              Tab(text: 'Треки'),
              Tab(text: 'Метаданные'),
              Tab(text: 'Сплиты'),
              Tab(text: 'План запуска'),
              Tab(text: 'Проверка'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _OverviewTab(release: release, statusLabel: statusLabel),
            _TracksTab(release: release),
            _MetadataTab(release: release),
            _SplitsTab(release: release),
            _LaunchPlanTab(release: release),
            _ReviewTab(release: release, canSubmit: ref.watch(appStateProvider).canSubmitRelease),
          ],
        ),
      ),
    );
  }
}

class _OverviewTab extends StatelessWidget {
  final ReleaseModel release;
  final String statusLabel;

  const _OverviewTab({required this.release, required this.statusLabel});

  @override
  Widget build(BuildContext context) {
    final dateStr = release.releaseDate != null
        ? '${release.releaseDate!.day}.${release.releaseDate!.month}.${release.releaseDate!.year}'
        : '—';
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AurixGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Статус', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(statusLabel, style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
            const SizedBox(height: 20),
            Text('Дата релиза', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(dateStr, style: TextStyle(color: AurixTokens.muted)),
            const SizedBox(height: 20),
            Text('Тип', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            Text(release.releaseType, style: TextStyle(color: AurixTokens.muted)),
          ],
        ),
      ),
    );
  }
}

class _TracksTab extends StatelessWidget {
  final ReleaseModel release;

  const _TracksTab({required this.release});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AurixGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Треки', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавить трек — скоро'))),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить трек'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Пока нет треков', style: TextStyle(color: AurixTokens.muted)),
          ],
        ),
      ),
    );
  }
}

class _MetadataTab extends StatelessWidget {
  final ReleaseModel release;

  const _MetadataTab({required this.release});

  @override
  Widget build(BuildContext context) {
    final fields = ['Жанр', 'Язык', 'Композитор', 'Продюсер', 'Правообладатель', 'Лейбл'];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AurixGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Метаданные', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ...fields.map((f) => Padding(
                  padding: const EdgeInsets.only(bottom: 16),
                  child: TextField(
                    decoration: InputDecoration(
                      labelText: f,
                      filled: true,
                      fillColor: AurixTokens.glass(0.06),
                    ),
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _SplitsTab extends StatelessWidget {
  final ReleaseModel release;

  const _SplitsTab({required this.release});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AurixGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Сплиты', style: Theme.of(context).textTheme.titleLarge),
                TextButton.icon(
                  onPressed: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Добавить участника — скоро'))),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Добавить'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Пока нет сплитов', style: TextStyle(color: AurixTokens.muted)),
          ],
        ),
      ),
    );
  }
}

class _LaunchPlanTab extends StatelessWidget {
  final ReleaseModel release;

  const _LaunchPlanTab({required this.release});

  @override
  Widget build(BuildContext context) {
    final tasks = [
      ('Загрузить обложку', false),
      ('Заполнить метаданные', false),
      ('Запланировать промо', false),
      ('Отправить на проверку', false),
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AurixGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('План запуска', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            ...tasks.map((t) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Icon(Icons.check_box_outline_blank, size: 22, color: AurixTokens.muted),
                      const SizedBox(width: 12),
                      Text(t.$1, style: TextStyle(color: AurixTokens.text)),
                    ],
                  ),
                )),
          ],
        ),
      ),
    );
  }
}

class _ReviewTab extends StatelessWidget {
  final ReleaseModel release;
  final bool canSubmit;

  const _ReviewTab({required this.release, required this.canSubmit});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: AurixGlassCard(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Проверка', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 20),
            Text('Проверьте данные перед отправкой.', style: TextStyle(color: AurixTokens.muted)),
            const SizedBox(height: 24),
            AurixButton(
              text: 'Отправить на модерацию',
              icon: Icons.send_rounded,
              onPressed: canSubmit ? () {} : null,
            ),
          ],
        ),
      ),
    );
  }
}
