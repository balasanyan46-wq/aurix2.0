import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/track_model.dart';
import 'package:aurix_flutter/data/models/admin_note_model.dart';
import 'package:aurix_flutter/data/models/release_aai_model.dart';
import 'package:aurix_flutter/features/covers/cover_generator_sheet.dart';
import 'package:aurix_flutter/presentation/screens/releases/widgets/release_aai_block.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/premium_ui.dart';
import 'package:aurix_flutter/design/widgets/fade_in_slide.dart';
import 'package:aurix_flutter/design/widgets/premium_page_scaffold.dart';
import 'package:aurix_flutter/presentation/screens/releases/widgets/track_player.dart';

final releaseDetailProvider = FutureProvider.family<ReleaseModel?, String>((ref, id) async {
  return ref.watch(releaseRepositoryProvider).getRelease(id);
});

final releaseTracksProvider = FutureProvider.family<List<TrackModel>, String>((ref, releaseId) async {
  return ref.watch(trackRepositoryProvider).getTracksByRelease(releaseId);
});

final releaseNotesProvider = FutureProvider.family<List<AdminNoteModel>, String>((ref, releaseId) async {
  return ref.watch(releaseRepositoryProvider).getNotesForRelease(releaseId);
});

final releaseAaiProvider = FutureProvider.family<ReleaseAaiModel?, String>((ref, releaseId) async {
  return ref.watch(releaseAaiRepositoryProvider).getReleaseAai(releaseId);
});

final releaseDnkAaiHintsProvider = FutureProvider.family<List<DnkAaiHint>, String>((ref, releaseId) async {
  return ref.watch(releaseAaiRepositoryProvider).getDnkAaiHints(releaseId);
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
      if (mounted) _snack('Сохранено');
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) _snack('Ошибка: $e');
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
      if (mounted) setState(() => _saving = false);
      if (mounted) _snack('Обложка обновлена');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) _snack('Ошибка: $e');
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
      await trackRepo.addTrack(
        id: trackId,
        releaseId: r.id,
        userId: userId,
        audioPath: uploaded.path,
        audioUrl: uploaded.publicUrl,
        title: f.name,
      );
      ref.invalidate(releaseTracksProvider(widget.releaseId));
      if (mounted) setState(() => _saving = false);
      if (mounted) _snack('Трек добавлен');
    } catch (e) {
      if (mounted) setState(() => _saving = false);
      if (mounted) _snack('Ошибка: $e');
    } finally {
      _pickingFile = false;
    }
  }

  Future<void> _editIsrc(TrackModel track) async {
    final controller = TextEditingController(text: track.isrc ?? '');
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusCard)),
        title: const Text('ISRC код', style: TextStyle(color: AurixTokens.text)),
        content: TextField(
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          style: const TextStyle(color: AurixTokens.text),
          decoration: const InputDecoration(
            labelText: 'ISRC',
            hintText: 'QZDA72198362',
            helperText: 'Нужен для привязки финансовых отчётов',
            helperStyle: TextStyle(color: AurixTokens.muted, fontSize: 12),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, controller.text),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    controller.dispose();
    if (result == null) return;
    try {
      await ref.read(trackRepositoryProvider).updateTrackIsrc(track.id, result.trim().isEmpty ? null : result.trim());
      ref.invalidate(releaseTracksProvider(widget.releaseId));
      if (mounted) _snack('ISRC сохранён');
    } catch (e) {
      if (mounted) _snack('Ошибка: $e');
    }
  }

  Future<void> _deleteTrack(TrackModel track) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AurixTokens.radiusCard)),
        title: const Text('Удалить трек?', style: TextStyle(color: AurixTokens.text)),
        content: Text(
          track.title ?? track.audioPath.split('/').last,
          style: const TextStyle(color: AurixTokens.muted),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Отмена')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(trackRepositoryProvider).deleteTrack(track.id);
      ref.invalidate(releaseTracksProvider(widget.releaseId));
      if (mounted) _snack('Трек удалён');
    } catch (e) {
      if (mounted) _snack('Ошибка: $e');
    }
  }

  void _snack(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(text),
      backgroundColor: AurixTokens.bg2,
      behavior: SnackBarBehavior.floating,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final release = ref.watch(releaseDetailProvider(widget.releaseId));
    final tracks = ref.watch(releaseTracksProvider(widget.releaseId));
    final notes = ref.watch(releaseNotesProvider(widget.releaseId));
    final aai = ref.watch(releaseAaiProvider(widget.releaseId));
    final dnkHints = ref.watch(releaseDnkAaiHintsProvider(widget.releaseId));
    final userId = ref.watch(currentUserProvider)?.id;
    final isAdmin = ref.watch(isAdminProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: release.when(
        data: (r) {
          if (r == null) {
            return PremiumErrorState(
              title: 'Релиз не найден',
              message: 'Возможно, он был удалён или вы не имеете к нему доступа.',
              icon: Icons.album_outlined,
              onRetry: () {
                if (context.canPop()) context.pop();
                else context.go('/releases');
              },
            );
          }
          _initControllers(r);
          final isOwner = r.ownerId == userId;
          final canEdit = isOwner && r.isDraft;

          return Stack(
            children: [
              PremiumPageScaffold(
                maxWidth: 720,
                title: r.title,
                subtitle: [
                  if (r.artist != null && r.artist!.isNotEmpty) r.artist!,
                  _releaseTypeLabel(r.releaseType),
                  _statusLabel(r.status),
                ].join(' · '),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.arrow_back_rounded, color: AurixTokens.text, size: 20),
                      style: IconButton.styleFrom(
                        backgroundColor: AurixTokens.bg2.withValues(alpha: 0.7),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (context.canPop()) context.pop();
                        else context.go('/releases');
                      },
                    ),
                  ],
                ),
                children: [
                  // Cover section
                  _buildCoverSection(r, canEdit),
                  const SizedBox(height: 20),

                  // Metadata section
                  _buildMetadataSection(r, canEdit),
                  const SizedBox(height: 16),

                  // AAI block
                  FadeInSlide(
                    delayMs: 150,
                    child: ReleaseAaiBlock(aaiAsync: aai, dnkHintsAsync: dnkHints),
                  ),
                  const SizedBox(height: 12),

                  // AI Analysis button
                  if (isOwner)
                    FadeInSlide(
                      delayMs: 200,
                      child: _AiAnalyzeButton(releaseId: widget.releaseId, releaseTitle: r.title),
                    ),
                  const SizedBox(height: 16),

                  // Actions
                  if (isOwner && r.isDraft) ...[
                    _buildSubmitAction(r),
                    const SizedBox(height: 12),
                  ],
                  if (r.status == 'rejected' && isOwner) ...[
                    _buildRejectedBanner(r),
                    const SizedBox(height: 12),
                  ],

                  // Tracks section
                  _buildTracksSection(tracks, r, canEdit),

                  // Admin notes
                  if (isAdmin.valueOrNull == true) ...[
                    const SizedBox(height: 20),
                    _buildAdminNotes(notes),
                  ],
                  const SizedBox(height: 32),
                ],
              ),
              if (_saving) _buildSavingOverlay(),
            ],
          );
        },
        loading: () => const PremiumLoadingState(message: 'Загрузка релиза…'),
        error: (e, _) => PremiumErrorState(
          title: 'Ошибка загрузки',
          message: '$e',
          onRetry: () => ref.invalidate(releaseDetailProvider(widget.releaseId)),
        ),
      ),
    );
  }

  // ─── Cover ────────────────────────────────────────────────────────────

  Widget _buildCoverSection(ReleaseModel r, bool canEdit) {
    return FadeInSlide(
      delayMs: 50,
      child: PremiumSectionCard(
        radius: AurixTokens.radiusCard,
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: r.coverUrl != null && r.coverUrl!.isNotEmpty
                  ? Image.network(
                      ApiClient.fixUrl(r.coverUrl),
                      height: 220,
                      width: double.infinity,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _coverPlaceholder(),
                    )
                  : _coverPlaceholder(),
            ),
            if (canEdit) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: _SecondaryAction(
                      icon: Icons.image_rounded,
                      label: r.coverUrl != null ? 'Заменить' : 'Загрузить',
                      onTap: _saving ? null : () => _replaceCover(r),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _SecondaryAction(
                      icon: Icons.auto_awesome_rounded,
                      label: 'AI обложка',
                      accent: true,
                      onTap: _saving
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
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _coverPlaceholder() {
    return Container(
      height: 220,
      width: double.infinity,
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.album_rounded, size: 48, color: AurixTokens.muted.withValues(alpha: 0.3)),
          const SizedBox(height: 8),
          Text('Нет обложки', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 13)),
        ],
      ),
    );
  }

  // ─── Metadata ─────────────────────────────────────────────────────────

  Widget _buildMetadataSection(ReleaseModel r, bool canEdit) {
    if (_editing && canEdit) return _buildEditForm(r);

    return FadeInSlide(
      delayMs: 100,
      child: PremiumSectionCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    'Информация',
                    style: TextStyle(
                      color: AurixTokens.text,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                if (canEdit)
                  _GhostButton(
                    icon: Icons.edit_rounded,
                    label: 'Изменить',
                    onTap: () => setState(() => _editing = true),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            _InfoRow(label: 'Тип', value: _releaseTypeLabel(r.releaseType)),
            _InfoRow(label: 'Статус', value: _statusLabel(r.status), valueColor: _statusColor(r.status)),
            if (r.releaseDate != null) _InfoRow(label: 'Дата', value: DateFormat('dd.MM.yyyy').format(r.releaseDate!)),
            if (r.genre != null) _InfoRow(label: 'Жанр', value: r.genre!),
            if (r.language != null) _InfoRow(label: 'Язык', value: r.language!),
            if (r.upc != null) _InfoRow(label: 'UPC', value: r.upc!),
            if (r.label != null) _InfoRow(label: 'Лейбл', value: r.label!),
            if (r.explicit) _InfoRow(label: '', value: 'Explicit', valueColor: AurixTokens.warning),
          ],
        ),
      ),
    );
  }

  Widget _buildEditForm(ReleaseModel r) {
    return FadeInSlide(
      child: PremiumSectionCard(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Редактирование',
              style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: AurixTokens.text, fontSize: 15),
              decoration: const InputDecoration(labelText: 'Название'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _artistCtrl,
              style: const TextStyle(color: AurixTokens.text, fontSize: 15),
              decoration: const InputDecoration(labelText: 'Артист'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _genreCtrl,
              style: const TextStyle(color: AurixTokens.text, fontSize: 15),
              decoration: const InputDecoration(labelText: 'Жанр'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _languageCtrl,
              style: const TextStyle(color: AurixTokens.text, fontSize: 15),
              decoration: const InputDecoration(labelText: 'Язык'),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: FilledButton(
                    onPressed: _saving ? null : () => _saveEdits(r),
                    child: _saving
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Сохранить'),
                  ),
                ),
                const SizedBox(width: 10),
                TextButton(
                  onPressed: () => setState(() => _editing = false),
                  child: const Text('Отмена'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // ─── Actions ──────────────────────────────────────────────────────────

  Widget _buildSubmitAction(ReleaseModel r) {
    return FadeInSlide(
      delayMs: 200,
      child: PremiumHoverLift(
        child: FilledButton.icon(
          onPressed: _saving
              ? null
              : () async {
                  try {
                    await ref.read(releaseRepositoryProvider).submitRelease(widget.releaseId);
                    ref.invalidate(releaseDetailProvider(widget.releaseId));
                    if (context.mounted) _snack('Релиз отправлен на модерацию');
                  } catch (e) {
                    if (context.mounted) _snack('Ошибка: $e');
                  }
                },
          icon: const Icon(Icons.send_rounded, size: 18),
          label: const Text('Отправить на модерацию'),
          style: FilledButton.styleFrom(
            minimumSize: const Size(double.infinity, 50),
          ),
        ),
      ),
    );
  }

  Widget _buildRejectedBanner(ReleaseModel r) {
    return FadeInSlide(
      delayMs: 200,
      child: PremiumSectionCard(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AurixTokens.danger.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(Icons.info_outline_rounded, size: 18, color: AurixTokens.danger.withValues(alpha: 0.8)),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Text(
                    'Релиз отклонён',
                    style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Text(
              'Вы можете исправить замечания и отправить повторно.',
              style: TextStyle(color: AurixTokens.muted, fontSize: 13, height: 1.4),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(releaseRepositoryProvider).updateRelease(widget.releaseId, status: 'draft');
                ref.invalidate(releaseDetailProvider(widget.releaseId));
              },
              icon: const Icon(Icons.edit_note_rounded, size: 18),
              label: const Text('Вернуть в черновик'),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Tracks ───────────────────────────────────────────────────────────

  Widget _buildTracksSection(AsyncValue<List<TrackModel>> tracks, ReleaseModel r, bool canEdit) {
    return FadeInSlide(
      delayMs: 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Row(
            children: [
              const Text(
                'Треки',
                style: TextStyle(
                  color: AurixTokens.text,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const Spacer(),
              if (canEdit)
                _GhostButton(
                  icon: Icons.add_rounded,
                  label: 'Добавить',
                  onTap: _saving ? null : () => _addTrack(r),
                ),
            ],
          ),
          const SizedBox(height: 12),
          tracks.when(
            data: (trackList) {
              if (trackList.isEmpty) {
                return PremiumEmptyState(
                  title: 'Нет треков',
                  description: canEdit
                      ? 'Загрузите аудиофайл, чтобы добавить трек в релиз.'
                      : 'В этом релизе пока нет треков.',
                  icon: Icons.audiotrack_rounded,
                );
              }
              return Column(
                children: [
                  for (int i = 0; i < trackList.length; i++) ...[
                    if (i > 0) const SizedBox(height: 8),
                    _TrackItem(
                      track: trackList[i],
                      index: i + 1,
                      canEdit: canEdit,
                      onEditIsrc: () => _editIsrc(trackList[i]),
                      onDelete: () => _deleteTrack(trackList[i]),
                    ),
                  ],
                ],
              );
            },
            loading: () => const Column(
              children: [
                PremiumSkeletonBox(height: 64),
                SizedBox(height: 8),
                PremiumSkeletonBox(height: 64),
              ],
            ),
            error: (_, __) => const PremiumEmptyState(
              title: 'Нет треков',
              description: 'Не удалось загрузить список треков.',
              icon: Icons.audiotrack_rounded,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Admin notes ──────────────────────────────────────────────────────

  Widget _buildAdminNotes(AsyncValue<List<AdminNoteModel>> notes) {
    return FadeInSlide(
      delayMs: 300,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          const Text(
            'Заметки администратора',
            style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          notes.when(
            data: (list) {
              if (list.isEmpty) {
                return const PremiumEmptyState(
                  title: 'Нет заметок',
                  description: 'Администратор пока не оставил комментариев.',
                  icon: Icons.note_alt_outlined,
                );
              }
              return Column(
                children: list.map((n) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: PremiumSectionCard(
                    padding: const EdgeInsets.all(14),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(n.note, style: const TextStyle(color: AurixTokens.text, fontSize: 14, height: 1.4)),
                        const SizedBox(height: 6),
                        Text(
                          DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt),
                          style: const TextStyle(color: AurixTokens.micro, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                )).toList(),
              );
            },
            loading: () => const PremiumSkeletonBox(height: 60),
            error: (_, __) => const Text('Не удалось загрузить', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─── Saving overlay ───────────────────────────────────────────────────

  Widget _buildSavingOverlay() {
    return Container(
      color: AurixTokens.bg0.withValues(alpha: 0.5),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AurixTokens.bg1,
            borderRadius: BorderRadius.circular(AurixTokens.radiusCard),
            border: Border.all(color: AurixTokens.stroke(0.2)),
          ),
          child: const Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 2.5, color: AurixTokens.accent),
              ),
              SizedBox(height: 12),
              Text('Сохранение…', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }

  // ─── Helpers ──────────────────────────────────────────────────────────

  static String _releaseTypeLabel(String t) => switch (t) { 'single' => 'Сингл', 'ep' => 'EP', 'album' => 'Альбом', _ => t };
  static String _statusLabel(String s) => switch (s) {
    'draft' => 'Черновик', 'submitted' => 'На модерации', 'in_review' => 'На проверке',
    'approved' => 'Одобрен', 'rejected' => 'Отклонён', 'live' => 'Опубликован', _ => s
  };
  static Color _statusColor(String s) => switch (s) {
    'approved' || 'live' => AurixTokens.positive,
    'rejected' => AurixTokens.danger,
    'submitted' || 'in_review' => AurixTokens.warning,
    _ => AurixTokens.muted,
  };
}

// ─── Subcomponents ────────────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          if (label.isNotEmpty)
            SizedBox(
              width: 80,
              child: Text(
                label,
                style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
              ),
            ),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                color: valueColor ?? AurixTokens.text,
                fontSize: 14,
                fontWeight: valueColor != null ? FontWeight.w600 : FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackItem extends StatelessWidget {
  const _TrackItem({
    required this.track,
    required this.index,
    required this.canEdit,
    required this.onEditIsrc,
    required this.onDelete,
  });

  final TrackModel track;
  final int index;
  final bool canEdit;
  final VoidCallback onEditIsrc;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final audioUrl = ApiClient.fixUrl(track.audioUrl);

    return PremiumSectionCard(
      padding: const EdgeInsets.all(14),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AurixTokens.bg2,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Center(
                  child: Text(
                    '$index',
                    style: const TextStyle(
                      color: AurixTokens.muted,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      fontFeatures: AurixTokens.tabularFigures,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      track.title ?? track.audioPath.split('/').last,
                      style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    if (track.isrc != null && track.isrc!.isNotEmpty)
                      Text(
                        'ISRC: ${track.isrc}',
                        style: TextStyle(color: AurixTokens.accent.withValues(alpha: 0.8), fontSize: 12, fontWeight: FontWeight.w500),
                      )
                    else if (canEdit)
                      Text(
                        'ISRC не указан',
                        style: TextStyle(color: AurixTokens.warning.withValues(alpha: 0.7), fontSize: 12),
                      ),
                  ],
                ),
              ),
              if (canEdit) ...[
                IconButton(
                  icon: const Icon(Icons.edit_note_rounded, size: 18, color: AurixTokens.muted),
                  onPressed: onEditIsrc,
                  tooltip: 'ISRC',
                  style: IconButton.styleFrom(
                    backgroundColor: AurixTokens.glass(0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
                const SizedBox(width: 4),
                IconButton(
                  icon: Icon(Icons.delete_outline_rounded, size: 18, color: AurixTokens.danger.withValues(alpha: 0.6)),
                  onPressed: onDelete,
                  style: IconButton.styleFrom(
                    backgroundColor: AurixTokens.glass(0.06),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ],
            ],
          ),
          if (audioUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            TrackPlayer(url: audioUrl),
          ],
        ],
      ),
    );
  }
}

class _SecondaryAction extends StatefulWidget {
  const _SecondaryAction({required this.icon, required this.label, this.onTap, this.accent = false});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final bool accent;

  @override
  State<_SecondaryAction> createState() => _SecondaryActionState();
}

class _SecondaryActionState extends State<_SecondaryAction> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    final accentColor = widget.accent ? AurixTokens.aiAccent : AurixTokens.text;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: _hovered ? AurixTokens.glass(0.08) : AurixTokens.glass(0.04),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AurixTokens.stroke(_hovered ? 0.24 : 0.14)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(widget.icon, size: 16, color: accentColor.withValues(alpha: 0.8)),
              const SizedBox(width: 6),
              Text(
                widget.label,
                style: TextStyle(color: accentColor.withValues(alpha: 0.9), fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiAnalyzeButton extends StatefulWidget {
  final String releaseId;
  final String releaseTitle;
  const _AiAnalyzeButton({required this.releaseId, required this.releaseTitle});

  @override
  State<_AiAnalyzeButton> createState() => _AiAnalyzeButtonState();
}

class _AiAnalyzeButtonState extends State<_AiAnalyzeButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: () {
          // Navigate to studio tab with this release pre-selected
          context.push('/studio?release=${widget.releaseId}');
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AurixTokens.accent.withValues(alpha: _hovered ? 0.18 : 0.1),
                AurixTokens.accentWarm.withValues(alpha: _hovered ? 0.1 : 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: AurixTokens.accent.withValues(alpha: _hovered ? 0.3 : 0.15),
            ),
            boxShadow: _hovered ? [
              BoxShadow(
                color: AurixTokens.accentGlow.withValues(alpha: 0.1),
                blurRadius: 20,
                spreadRadius: -8,
              ),
            ] : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.auto_awesome_rounded, size: 18, color: AurixTokens.accent),
              const SizedBox(width: 8),
              Text(
                'AI разбор трека',
                style: TextStyle(
                  color: AurixTokens.accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GhostButton extends StatefulWidget {
  const _GhostButton({required this.icon, required this.label, this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  @override
  State<_GhostButton> createState() => _GhostButtonState();
}

class _GhostButtonState extends State<_GhostButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: _hovered ? AurixTokens.glass(0.08) : Colors.transparent,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: _hovered ? AurixTokens.stroke(0.2) : Colors.transparent),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.icon, size: 14, color: AurixTokens.accent.withValues(alpha: 0.8)),
              const SizedBox(width: 5),
              Text(
                widget.label,
                style: TextStyle(
                  color: AurixTokens.accent.withValues(alpha: 0.9),
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
