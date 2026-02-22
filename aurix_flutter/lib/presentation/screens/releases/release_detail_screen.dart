import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/track_model.dart';
import 'package:aurix_flutter/data/models/admin_note_model.dart';

final releaseDetailProvider = FutureProvider.family<ReleaseModel?, String>((ref, id) async {
  return ref.watch(releaseRepositoryProvider).getRelease(id);
});

final releaseTracksProvider = FutureProvider.family<List<TrackModel>, String>((ref, releaseId) async {
  return ref.watch(trackRepositoryProvider).getTracksByRelease(releaseId);
});

final releaseNotesProvider = FutureProvider.family<List<AdminNoteModel>, String>((ref, releaseId) async {
  return ref.watch(releaseRepositoryProvider).getNotesForRelease(releaseId);
});

class ReleaseDetailScreen extends ConsumerWidget {
  const ReleaseDetailScreen({super.key, required this.releaseId});
  final String releaseId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final release = ref.watch(releaseDetailProvider(releaseId));
    final tracks = ref.watch(releaseTracksProvider(releaseId));
    final notes = ref.watch(releaseNotesProvider(releaseId));
    final userId = ref.watch(currentUserProvider)?.id;
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Релиз'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: release.when(
        data: (r) {
          if (r == null) return const Center(child: Text('Релиз не найден'));
          final isOwner = r.ownerId == userId;
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.title, style: Theme.of(context).textTheme.headlineSmall),
                            const SizedBox(height: 8),
                            Text('Тип: ${r.releaseType} • Статус: ${r.status}'),
                            if (r.releaseDate != null) Text('Дата: ${DateFormat.yMMMd().format(r.releaseDate!)}'),
                            if (r.genre != null) Text('Жанр: ${r.genre}'),
                            if (r.language != null) Text('Язык: ${r.language}'),
                          ],
                        ),
                      ),
                    ),
                    if (isOwner && r.isDraft) ...[
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () async {
                          try {
                            await ref.read(releaseRepositoryProvider).submitRelease(releaseId);
                            ref.invalidate(releaseDetailProvider(releaseId));
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Релиз отправлен на модерацию')));
                          } catch (e) {
                            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                          }
                        },
                        child: const Text('Отправить на модерацию'),
                      ),
                    ],
                    const SizedBox(height: 16),
                    const Text('Файлы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    if (r.coverUrl != null || r.coverPath != null)
                      ListTile(
                        leading: const Icon(Icons.image),
                        title: Text('Обложка: ${r.coverPath?.split('/').last ?? 'cover'}'),
                        subtitle: r.coverUrl != null ? null : Text(r.coverPath ?? ''),
                      ),
                    tracks.when(
                      data: (trackList) {
                        final hasCover = r.coverUrl != null || r.coverPath != null;
                        if (trackList.isEmpty && !hasCover) {
                          return const Text('Нет прикреплённых файлов');
                        }
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: trackList
                              .map((t) => ListTile(
                                    leading: const Icon(Icons.audiotrack),
                                    title: Text(t.title ?? t.audioPath.split('/').last),
                                    subtitle: Text(t.audioPath.split('/').last),
                                  ))
                              .toList(),
                        );
                      },
                      loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                      error: (e, _) => Text('Ошибка загрузки треков: $e'),
                    ),
                    if (isAdmin.valueOrNull == true) ...[
                      const SizedBox(height: 16),
                      const Text('Заметки администратора', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      notes.when(
                        data: (list) {
                          if (list.isEmpty) return const Text('Нет заметок');
                          return Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: list
                                .map((n) => ListTile(
                                      title: Text(n.note),
                                      subtitle: Text(DateFormat.yMd().add_Hm().format(n.createdAt)),
                                    ))
                                .toList(),
                          );
                        },
                        loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                        error: (e, _) => Text('$e'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [Text('Ошибка: $e'), FilledButton(onPressed: () => ref.invalidate(releaseDetailProvider(releaseId)), child: const Text('Повторить'))])),
      ),
    );
  }
}
