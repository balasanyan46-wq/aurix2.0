import 'dart:typed_data';
import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/track_model.dart';
import 'package:aurix_flutter/data/models/admin_note_model.dart';
import 'package:aurix_flutter/features/covers/cover_generator_sheet.dart';

final releaseDetailProvider = FutureProvider.family<ReleaseModel?, String>((ref, id) async {
  return ref.watch(releaseRepositoryProvider).getRelease(id);
});

final releaseTracksProvider = FutureProvider.family<List<TrackModel>, String>((ref, releaseId) async {
  return ref.watch(trackRepositoryProvider).getTracksByRelease(releaseId);
});

final releaseNotesProvider = FutureProvider.family<List<AdminNoteModel>, String>((ref, releaseId) async {
  return ref.watch(releaseRepositoryProvider).getNotesForRelease(releaseId);
});

class ReleaseDetailScreen extends ConsumerStatefulWidget {
  const ReleaseDetailScreen({super.key, required this.releaseId});
  final String releaseId;

  @override
  ConsumerState<ReleaseDetailScreen> createState() => _ReleaseDetailScreenState();
}

class _ReleaseDetailScreenState extends ConsumerState<ReleaseDetailScreen> {
  bool _editing = false;
  bool _saving = false;
  bool _pickingFile = false;

  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _genreCtrl;
  late TextEditingController _languageCtrl;

  bool _initialized = false;

  void _initControllers(ReleaseModel r) {
    if (_initialized) return;
    _titleCtrl = TextEditingController(text: r.title);
    _artistCtrl = TextEditingController(text: r.artist ?? '');
    _genreCtrl = TextEditingController(text: r.genre ?? '');
    _languageCtrl = TextEditingController(text: r.language ?? '');
    _initialized = true;
  }

  @override
  void dispose() {
    if (_initialized) {
      _titleCtrl.dispose();
      _artistCtrl.dispose();
      _genreCtrl.dispose();
      _languageCtrl.dispose();
    }
    super.dispose();
  }

  Future<Uint8List?> _getFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (!kIsWeb && file.path != null) {
      try { return await File(file.path!).readAsBytes(); } catch (_) { return null; }
    }
    return null;
  }

  Future<void> _saveEdits(ReleaseModel r) async {
    setState(() => _saving = true);
    try {
      await ref.read(releaseRepositoryProvider).updateRelease(
        r.id,
        title: _titleCtrl.text.trim(),
        artist: _artistCtrl.text.trim(),
        genre: _genreCtrl.text.trim().isEmpty ? null : _genreCtrl.text.trim(),
        language: _languageCtrl.text.trim().isEmpty ? null : _languageCtrl.text.trim(),
      );
      ref.invalidate(releaseDetailProvider(widget.releaseId));
      setState(() { _editing = false; _saving = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сохранено')));
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _replaceCover(ReleaseModel r) async {
    if (_saving || _pickingFile) return;
    _pickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, withData: true);
      if (result == null) return;
      final f = result.files.single;
      final bytes = await _getFileBytes(f);
      if (bytes == null || bytes.isEmpty) return;
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) return;

      setState(() => _saving = true);
      final fileRepo = ref.read(fileRepositoryProvider);
      final uploaded = await fileRepo.uploadCoverBytes(userId, r.id, bytes, f.name);
      await ref.read(releaseRepositoryProvider).updateRelease(r.id, coverUrl: uploaded.publicUrl, coverPath: uploaded.coverPath);
      ref.invalidate(releaseDetailProvider(widget.releaseId));
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Обложка обновлена')));
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      _pickingFile = false;
    }
  }

  Future<void> _addTrack(ReleaseModel r) async {
    if (_saving || _pickingFile) return;
    _pickingFile = true;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio, withData: true);
      if (result == null) return;
      final f = result.files.single;
      final bytes = await _getFileBytes(f);
      if (bytes == null || bytes.isEmpty) return;
      final userId = ref.read(currentUserProvider)?.id;
      if (userId == null) return;

      setState(() => _saving = true);
      final fileRepo = ref.read(fileRepositoryProvider);
      final trackRepo = ref.read(trackRepositoryProvider);
      final trackId = const Uuid().v4();
      final ext = f.extension ?? f.name.split('.').lastOrNull ?? 'wav';
      final uploaded = await fileRepo.uploadTrackBytes(userId, r.id, trackId, bytes, ext);
      await trackRepo.addTrack(id: trackId, releaseId: r.id, audioPath: uploaded.path, audioUrl: uploaded.publicUrl, title: f.name);
      ref.invalidate(releaseTracksProvider(widget.releaseId));
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Трек добавлен')));
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    } finally {
      _pickingFile = false;
    }
  }

  Future<void> _editIsrc(TrackModel track) async {
    final controller = TextEditingController(text: track.isrc ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('ISRC код'),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: 'ISRC',
            hintText: 'QZDA72198362',
            helperText: 'Нужен для привязки финансовых отчётов',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, controller.text), child: const Text('Сохранить')),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await ref.read(trackRepositoryProvider).updateTrackIsrc(track.id, result.trim().isEmpty ? null : result.trim());
      ref.invalidate(releaseTracksProvider(widget.releaseId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ISRC сохранён')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _deleteTrack(TrackModel track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Удалить трек?'),
        content: Text(track.title ?? track.audioPath.split('/').last),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Удалить')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(trackRepositoryProvider).deleteTrack(track.id);
      ref.invalidate(releaseTracksProvider(widget.releaseId));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Трек удалён')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(releaseDetailProvider(widget.releaseId));
    final tracks = ref.watch(releaseTracksProvider(widget.releaseId));
    final notes = ref.watch(releaseNotesProvider(widget.releaseId));
    final userId = ref.watch(currentUserProvider)?.id;
    final isAdmin = ref.watch(isAdminProvider);
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Релиз'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop()),
      ),
      body: release.when(
        data: (r) {
          if (r == null) return const Center(child: Text('Релиз не найден'));
          _initControllers(r);
          final isOwner = r.ownerId == userId;
          final canEdit = isOwner && r.isDraft;

          return Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 600),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Cover
                        if (r.coverUrl != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(r.coverUrl!, height: 200, fit: BoxFit.cover),
                          ),
                        if (canEdit) ...[
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _saving ? null : () => _replaceCover(r),
                            icon: const Icon(Icons.image, size: 18),
                            label: Text(r.coverUrl != null ? 'Заменить обложку' : 'Загрузить обложку'),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: _saving
                                ? null
                                : () async {
                                    final userId = ref.read(currentUserProvider)?.id;
                                    if (userId == null) return;
                                    await CoverGeneratorSheet.open(
                                      context,
                                      releaseId: r.id,
                                      initialArtistName: r.artist ?? '',
                                      initialReleaseTitle: r.title,
                                      initialGenre: r.genre,
                                      onApplied: (_, __) {
                                        ref.invalidate(releaseDetailProvider(widget.releaseId));
                                      },
                                    );
                                  },
                            icon: const Icon(Icons.auto_awesome_rounded, size: 18),
                            label: const Text('Сгенерировать обложку'),
                          ),
                        ],
                        const SizedBox(height: 16),

                        // Metadata
                        if (_editing && canEdit) ...[
                          TextField(controller: _titleCtrl, decoration: const InputDecoration(labelText: 'Название')),
                          const SizedBox(height: 8),
                          TextField(controller: _artistCtrl, decoration: const InputDecoration(labelText: 'Артист')),
                          const SizedBox(height: 8),
                          TextField(controller: _genreCtrl, decoration: const InputDecoration(labelText: 'Жанр')),
                          const SizedBox(height: 8),
                          TextField(controller: _languageCtrl, decoration: const InputDecoration(labelText: 'Язык')),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Expanded(
                                child: FilledButton(
                                  onPressed: _saving ? null : () => _saveEdits(r),
                                  child: _saving
                                      ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                      : const Text('Сохранить'),
                                ),
                              ),
                              const SizedBox(width: 8),
                              TextButton(
                                onPressed: () => setState(() => _editing = false),
                                child: const Text('Отмена'),
                              ),
                            ],
                          ),
                        ] else ...[
                          Card(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(child: Text(r.title, style: Theme.of(context).textTheme.headlineSmall)),
                                      if (canEdit)
                                        IconButton(
                                          icon: const Icon(Icons.edit, size: 20),
                                          onPressed: () => setState(() => _editing = true),
                                          tooltip: 'Редактировать',
                                        ),
                                    ],
                                  ),
                                  if (r.artist != null) Text(r.artist!, style: Theme.of(context).textTheme.titleMedium?.copyWith(color: cs.onSurface.withValues(alpha: 0.6))),
                                  const SizedBox(height: 8),
                                  _infoChip('Тип', _releaseTypeLabel(r.releaseType)),
                                  _infoChip('Статус', _statusLabel(r.status)),
                                  if (r.releaseDate != null) _infoChip('Дата', DateFormat('dd.MM.yyyy').format(r.releaseDate!)),
                                  if (r.genre != null) _infoChip('Жанр', r.genre!),
                                  if (r.language != null) _infoChip('Язык', r.language!),
                                  if (r.upc != null) _infoChip('UPC', r.upc!),
                                  if (r.label != null) _infoChip('Лейбл', r.label!),
                                  if (r.explicit) _infoChip('', 'Explicit'),
                                ],
                              ),
                            ),
                          ),
                        ],

                        // Actions
                        if (isOwner && r.isDraft) ...[
                          const SizedBox(height: 16),
                          FilledButton.icon(
                            onPressed: _saving ? null : () async {
                              try {
                                await ref.read(releaseRepositoryProvider).submitRelease(widget.releaseId);
                                ref.invalidate(releaseDetailProvider(widget.releaseId));
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Релиз отправлен на модерацию')));
                              } catch (e) {
                                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                              }
                            },
                            icon: const Icon(Icons.send_rounded),
                            label: const Text('Отправить на модерацию'),
                          ),
                        ],
                        if (r.status == 'rejected' && isOwner) ...[
                          const SizedBox(height: 8),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.red.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Text('Релиз отклонён. Вы можете исправить и отправить повторно.',
                                style: TextStyle(color: Colors.redAccent, fontSize: 13)),
                          ),
                          const SizedBox(height: 8),
                          OutlinedButton.icon(
                            onPressed: () async {
                              await ref.read(releaseRepositoryProvider).updateRelease(widget.releaseId, status: 'draft');
                              ref.invalidate(releaseDetailProvider(widget.releaseId));
                            },
                            icon: const Icon(Icons.edit_note_rounded),
                            label: const Text('Вернуть в черновик для редактирования'),
                          ),
                        ],

                        const SizedBox(height: 20),

                        // Tracks
                        Row(
                          children: [
                            const Text('Треки', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                            const Spacer(),
                            if (canEdit)
                              TextButton.icon(
                                onPressed: _saving ? null : () => _addTrack(r),
                                icon: const Icon(Icons.add, size: 18),
                                label: const Text('Добавить'),
                              ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        tracks.when(
                          data: (trackList) {
                            if (trackList.isEmpty) {
                              return Container(
                                padding: const EdgeInsets.all(24),
                                decoration: BoxDecoration(
                                  color: cs.surfaceContainerHighest.withValues(alpha: 0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Column(
                                    children: [
                                      Icon(Icons.audiotrack, size: 32, color: cs.onSurface.withValues(alpha: 0.3)),
                                      const SizedBox(height: 8),
                                      const Text('Нет треков'),
                                      if (canEdit) ...[
                                        const SizedBox(height: 8),
                                        FilledButton.icon(
                                          onPressed: () => _addTrack(r),
                                          icon: const Icon(Icons.upload_file, size: 18),
                                          label: const Text('Загрузить трек'),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              );
                            }
                            return Column(
                              children: trackList.map((t) => Card(
                                child: ListTile(
                                  leading: const Icon(Icons.audiotrack),
                                  title: Text(t.title ?? t.audioPath.split('/').last),
                                  subtitle: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(t.audioPath.split('/').last),
                                      if (t.isrc != null && t.isrc!.isNotEmpty)
                                        Text('ISRC: ${t.isrc}', style: TextStyle(color: cs.primary, fontSize: 12, fontWeight: FontWeight.w500))
                                      else if (canEdit)
                                        Text('ISRC не указан', style: TextStyle(color: cs.error.withValues(alpha: 0.7), fontSize: 12)),
                                    ],
                                  ),
                                  trailing: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (canEdit)
                                        IconButton(
                                          icon: const Icon(Icons.edit_note, size: 20),
                                          tooltip: 'Редактировать ISRC',
                                          onPressed: () => _editIsrc(t),
                                        ),
                                      if (canEdit)
                                        IconButton(
                                          icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20),
                                          onPressed: () => _deleteTrack(t),
                                        ),
                                    ],
                                  ),
                                ),
                              )).toList(),
                            );
                          },
                          loading: () => const Padding(padding: EdgeInsets.all(16), child: Center(child: CircularProgressIndicator())),
                          error: (e, _) => Text('Ошибка загрузки треков: $e'),
                        ),

                        // Admin notes
                        if (isAdmin.valueOrNull == true) ...[
                          const SizedBox(height: 20),
                          const Text('Заметки администратора', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 8),
                          notes.when(
                            data: (list) {
                              if (list.isEmpty) return const Text('Нет заметок', style: TextStyle(color: Colors.grey));
                              return Column(
                                children: list.map((n) => Card(
                                  child: ListTile(
                                    title: Text(n.note),
                                    subtitle: Text(DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt)),
                                  ),
                                )).toList(),
                              );
                            },
                            loading: () => const CircularProgressIndicator(),
                            error: (e, _) => Text('$e'),
                          ),
                        ],
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
              if (_saving)
                Container(
                  color: Colors.black26,
                  child: const Center(child: CircularProgressIndicator()),
                ),
            ],
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text('Ошибка: $e'),
              const SizedBox(height: 12),
              FilledButton(onPressed: () => ref.invalidate(releaseDetailProvider(widget.releaseId)), child: const Text('Повторить')),
            ],
          ),
        ),
      ),
    );
  }

  Widget _infoChip(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(width: 70, child: Text(label, style: TextStyle(color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5), fontSize: 13))),
        Text(value, style: const TextStyle(fontSize: 13)),
      ],
    ),
  );

  static String _releaseTypeLabel(String t) => switch (t) { 'single' => 'Сингл', 'ep' => 'EP', 'album' => 'Альбом', _ => t };
  static String _statusLabel(String s) => switch (s) {
    'draft' => 'Черновик', 'submitted' => 'На модерации', 'in_review' => 'На проверке',
    'approved' => 'Одобрен', 'rejected' => 'Отклонён', 'live' => 'Опубликован', _ => s
  };
}
