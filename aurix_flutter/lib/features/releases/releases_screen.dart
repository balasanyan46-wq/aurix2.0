import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final _releasesProvider = FutureProvider<List<ReleaseModel>>((ref) async {
  final user = ref.watch(currentUserProvider);
  if (user == null) return [];
  return ref.read(releaseRepositoryProvider).getReleasesByOwner(user.id);
});

/// Релизы в shell (без back button).
class ReleasesScreen extends ConsumerWidget {
  const ReleasesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final releases = ref.watch(_releasesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Релизы'),
        actions: [
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/releases/create'),
            tooltip: 'Создать релиз',
          ),
        ],
      ),
      body: releases.when(
        data: (list) {
          if (list.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.album_outlined, size: 64, color: Theme.of(context).colorScheme.outline),
                  const SizedBox(height: 16),
                  Text('Пока нет релизов', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  FilledButton.icon(
                    onPressed: () => context.push('/releases/create'),
                    icon: const Icon(Icons.add),
                    label: const Text('Создать релиз'),
                  ),
                ],
              ),
            );
          }
          return RefreshIndicator(
            onRefresh: () async => ref.invalidate(_releasesProvider),
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: list.length,
              itemBuilder: (context, i) {
                final r = list[i];
                return Card(
                  child: ListTile(
                    title: Text(r.title),
                    subtitle: Text('${r.releaseType} • ${r.status}${r.releaseDate != null ? ' • ${DateFormat.yMMMd().format(r.releaseDate!)}' : ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push('/releases/${r.id}'),
                  ),
                );
              },
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: $e', textAlign: TextAlign.center),
              const SizedBox(height: 16),
              FilledButton(onPressed: () => ref.invalidate(_releasesProvider), child: const Text('Повторить')),
            ],
          ),
        ),
      ),
      floatingActionButton: releases.valueOrNull != null && (releases.valueOrNull?.isNotEmpty ?? false)
          ? FloatingActionButton(
              onPressed: () => context.push('/releases/create'),
              child: const Icon(Icons.add),
            )
          : null,
    );
  }
}
