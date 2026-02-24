import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'dart:typed_data';
import 'package:uuid/uuid.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/core/l10n.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/repositories/file_repository.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

/// Пошаговый мастер загрузки релиза (RU).
/// Шаг 1: Основное | Шаг 2: Треки | Шаг 3: Сплиты | Шаг 4: Площадки + Отправка
class ReleaseCreateFlowScreen extends ConsumerStatefulWidget {
  final bool embedded;
  final VoidCallback? onBack;

  const ReleaseCreateFlowScreen({super.key, this.embedded = false, this.onBack});

  @override
  ConsumerState<ReleaseCreateFlowScreen> createState() => _ReleaseCreateFlowScreenState();
}

class _ReleaseCreateFlowScreenState extends ConsumerState<ReleaseCreateFlowScreen> {
  int _step = 0;
  final _tracks = <_TrackEntry>[];
  final _splits = <_SplitEntry>[];

  static const _steps = ['Основное', 'Треки', 'Сплиты', 'Площадки и отправка'];

  // Step 1 data
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _genreController = TextEditingController();
  String _releaseType = 'single';
  DateTime? _releaseDate;

  String? _coverUrl;
  Uint8List? _coverPreviewBytes;
  bool _coverUploading = false;

  ReleaseModel? _createdRelease;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _genreController.dispose();
    super.dispose();
  }

  Future<void> _saveDraft() async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(releaseRepositoryProvider);
      var r = _createdRelease;
      if (r == null) {
        r = await repo.createRelease(
          ownerId: user.id,
          title: _titleController.text.trim().isEmpty ? 'Новый релиз' : _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim(),
          releaseType: _releaseType,
          releaseDate: _releaseDate,
          genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
          coverUrl: _coverUrl,
          coverPath: null,
        );
        setState(() => _createdRelease = r);
      } else {
        await repo.updateRelease(r.id,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim(),
          releaseType: _releaseType,
          releaseDate: _releaseDate,
          genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
          coverUrl: _coverUrl,
        );
      }
      ref.invalidate(releasesProvider);
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Черновик сохранён')));
        widget.onBack?.call();
      }
    } catch (e) {
      setState(() { _error = _formatError(e); _loading = false; });
    }
  }

  String _formatError(Object e) {
    final detail = formatSupabaseError(e);
    if (detail.toLowerCase().contains('network') || detail.contains('Connection') || detail.contains('SocketException')) return 'Нет связи. Проверьте интернет.';
    if (detail.toLowerCase().contains('storage') || detail.contains('upload') || detail.contains('StorageException')) return 'Ошибка загрузки. Попробуйте ещё раз.';
    if (detail.contains('PGRST') || detail.contains('PostgrestException')) return 'Ошибка базы данных. Проверьте подключение.';
    return detail.length > 120 ? 'Ошибка: ${detail.substring(0, 117)}...' : 'Ошибка: $detail';
  }

  String? _validateForSubmit() {
    if (_titleController.text.trim().isEmpty) return 'Введите название релиза';
    if (_coverUrl == null) return 'Загрузите обложку';
    if (_tracks.isEmpty) return 'Добавьте хотя бы один трек';
    return null;
  }

  Future<void> _submit() async {
    final err = _validateForSubmit();
    if (err != null) {
      setState(() => _error = err);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'Войдите в аккаунт');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final repo = ref.read(releaseRepositoryProvider);
      var release = _createdRelease;
      if (release == null) {
        release = await repo.createRelease(
          ownerId: user.id,
          title: _titleController.text.trim().isEmpty ? 'Новый релиз' : _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim(),
          releaseType: _releaseType,
          releaseDate: _releaseDate,
          genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
          coverUrl: _coverUrl,
        );
        setState(() => _createdRelease = release);
      } else {
        await repo.updateRelease(release.id,
          title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim(),
          releaseType: _releaseType,
          releaseDate: _releaseDate,
          genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
          coverUrl: _coverUrl,
        );
      }
      await repo.submitRelease(release!.id);
      ref.invalidate(releasesProvider);
      setState(() => _loading = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Отправлено на модерацию')));
        widget.onBack?.call();
      }
    } catch (e) {
      setState(() { _error = _formatError(e); _loading = false; });
    }
  }

  Future<Uint8List?> _getFileBytes(PlatformFile file) async {
    if (file.bytes != null) return file.bytes;
    if (!kIsWeb && file.path != null) {
      try {
        return await File(file.path!).readAsBytes();
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  Future<void> _uploadCover(PlatformFile file) async {
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    var release = _createdRelease;
    if (release == null) {
      try {
        final repo = ref.read(releaseRepositoryProvider);
        release = await repo.createRelease(
          ownerId: user.id,
          title: _titleController.text.trim().isEmpty ? 'Новый релиз' : _titleController.text.trim(),
          artist: _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim(),
          releaseType: _releaseType,
          releaseDate: _releaseDate,
          genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        );
        setState(() => _createdRelease = release);
      } catch (e, st) {
        debugPrint('Ошибка создания релиза: $e\n$st');
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_formatError(e))));
        return;
      }
    }
    setState(() => _coverUploading = true);
    try {
      final bytes = await _getFileBytes(file);
      if (bytes == null || bytes.isEmpty) {
        setState(() => _coverUploading = false);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось прочитать файл')));
        return;
      }
      final fileRepo = ref.read(fileRepositoryProvider);
      final releaseId = release!.id;
      final result = await fileRepo.uploadCoverBytes(user.id, releaseId, bytes, file.name);
      await ref.read(releaseRepositoryProvider).updateRelease(releaseId, coverUrl: result.publicUrl, coverPath: result.coverPath);
      setState(() { _coverUrl = result.publicUrl; _coverPreviewBytes = bytes; _coverUploading = false; });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Обложка загружена')));
    } catch (e, st) {
      debugPrint('Ошибка загрузки обложки: $e\n$st');
      setState(() => _coverUploading = false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки файла: ${_formatError(e)}')));
    }
  }

  Future<void> _removeTrack(int index) async {
    final entry = index < _tracks.length ? _tracks[index] : null;
    if (entry?.id == null) {
      setState(() => _tracks.removeAt(index));
      return;
    }
    try {
      final trackRepo = ref.read(trackRepositoryProvider);
      final fileRepo = ref.read(fileRepositoryProvider);
      final track = await trackRepo.getTrack(entry!.id!);
      if (track != null && track.audioPath.isNotEmpty) {
        await fileRepo.removeFromStorage(FileRepository.tracksBucket, track.audioPath);
      }
      await trackRepo.deleteTrack(entry.id!);
      setState(() => _tracks.removeAt(index));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Трек удалён')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Не удалось удалить: ${_formatError(e)}')));
    }
  }

  Future<void> _addTrackWithFile() async {
    if (_createdRelease == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Сначала заполните Основное и нажмите Далее')));
      return;
    }
    final user = ref.read(currentUserProvider);
    if (user == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    final release = _createdRelease!;
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      if (result == null) return;
      final f = result.files.single;
      if (f.size > 200 * 1024 * 1024) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Трек не более 200 МБ')));
        return;
      }

      final bytes = await _getFileBytes(f);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось прочитать файл')));
        return;
      }

      final trackId = const Uuid().v4();
      final ext = f.extension ?? f.name.split('.').lastOrNull ?? 'wav';

      final fileRepo = ref.read(fileRepositoryProvider);
      final trackRepo = ref.read(trackRepositoryProvider);
      final r = await fileRepo.uploadTrackBytes(user.id, release.id, trackId, bytes, ext);
      final path = r.path;
      final fileUrl = r.publicUrl;

      final baseName = f.name.replaceAll(RegExp(r'\.(mp3|wav|flac|m4a)$', caseSensitive: false), '');
      await trackRepo.addTrack(
        id: trackId,
        releaseId: release.id,
        audioPath: path,
        audioUrl: fileUrl,
        title: baseName.isNotEmpty ? baseName : f.name,
        trackNumber: _tracks.length,
        version: 'original',
        explicit: false,
      );
      final title = baseName.isNotEmpty ? baseName : f.name;
      setState(() => _tracks.add(_TrackEntry(id: trackId, title: title, version: 'original', explicit: false)));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Трек загружен')));
    } catch (e, st) {
      debugPrint('Ошибка загрузки трека: $e\n$st');
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка загрузки файла: ${_formatError(e)}')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _StepIndicator(current: _step, total: 4, labels: _steps),
              const SizedBox(height: 32),
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red.withValues(alpha: 0.5)),
                  ),
                  child: Text(_error!, style: TextStyle(color: Colors.red.shade200)),
                ),
                const SizedBox(height: 16),
              ],
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                child: KeyedSubtree(key: ValueKey(_step), child: _buildStepContent()),
              ),
            ],
          ),
        ),
      ),
    );
    if (widget.embedded && widget.onBack != null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: [
                IconButton(icon: const Icon(Icons.arrow_back), onPressed: widget.onBack),
                const SizedBox(width: 8),
                Text('Загрузить релиз', style: Theme.of(context).textTheme.titleLarge),
              ],
            ),
          ),
          Expanded(child: body),
        ],
      );
    }
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: widget.onBack ?? () => Navigator.pop(context),
        ),
        title: const Text('Загрузить релиз'),
      ),
      body: body,
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _Step1Main(
          titleController: _titleController,
          artistController: _artistController,
          genreController: _genreController,
          releaseType: _releaseType,
          releaseDate: _releaseDate,
          onReleaseTypeChanged: (v) => setState(() => _releaseType = v),
          onReleaseDateChanged: (d) => setState(() => _releaseDate = d),
          coverUrl: _coverUrl,
          coverPreviewBytes: _coverPreviewBytes,
          coverUploading: _coverUploading,
          onCoverTap: () async {
            final result = await FilePicker.platform.pickFiles(
              type: FileType.custom,
              allowedExtensions: ['png', 'jpg', 'jpeg'],
              allowMultiple: false,
              withData: true,
            );
            if (result != null) {
              final f = result.files.single;
              if (f.size > 10 * 1024 * 1024) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Обложка не более 10 МБ')));
                return;
              }
              if ((kIsWeb && f.bytes != null) || (!kIsWeb && f.path != null)) {
                _uploadCover(f);
              } else if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Не удалось прочитать файл')));
              }
            }
          },
          onNext: () async {
            if (_createdRelease == null) {
              try {
                final user = ref.read(currentUserProvider);
                if (user == null) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
                  return;
                }
                final repo = ref.read(releaseRepositoryProvider);
                final r = await repo.createRelease(
                  ownerId: user.id,
                  title: _titleController.text.trim().isEmpty ? 'Новый релиз' : _titleController.text.trim(),
                  artist: _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim(),
                  releaseType: _releaseType,
                  releaseDate: _releaseDate,
                  genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
                  coverUrl: _coverUrl,
                );
                setState(() => _createdRelease = r);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(_formatError(e))));
                return;
              }
            } else {
              await ref.read(releaseRepositoryProvider).updateRelease(_createdRelease!.id,
                title: _titleController.text.trim().isEmpty ? null : _titleController.text.trim(),
                artist: _artistController.text.trim().isEmpty ? 'Unknown Artist' : _artistController.text.trim(),
                releaseType: _releaseType,
                releaseDate: _releaseDate,
                genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
              );
            }
            setState(() => _step = 1);
          },
        );
      case 1:
        return _Step2Tracks(
          tracks: _tracks,
          onAdd: _addTrackWithFile,
          onRemove: _removeTrack,
          onUpdate: (i, t) => setState(() { if (i < _tracks.length) _tracks[i] = t; }),
          canProceed: _tracks.isNotEmpty,
          onNext: () => setState(() => _step = 2),
          onPrev: () => setState(() => _step = 0),
        );
      case 2:
        return _Step3Splits(
          splits: _splits,
          onAdd: () => setState(() => _splits.add(_SplitEntry(name: '', percent: 0))),
          onRemove: (i) => setState(() => _splits.removeAt(i)),
          onUpdate: (i, s) => setState(() { if (i < _splits.length) _splits[i] = s; }),
          onNext: () => setState(() => _step = 3),
          onPrev: () => setState(() => _step = 1),
        );
      case 3:
        return _Step4PlatformsSubmit(
          onPrev: () => setState(() => _step = 2),
          onSaveDraft: _saveDraft,
          onSubmit: _submit,
          loading: _loading,
        );
      default:
        return const SizedBox();
    }
  }
}

class _StepIndicator extends StatelessWidget {
  final int current;
  final int total;
  final List<String> labels;

  const _StepIndicator({required this.current, required this.total, required this.labels});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: List.generate(total, (i) {
        final active = i == current;
        final past = i < current;
        return Expanded(
          child: Column(
            children: [
              GestureDetector(
                onTap: () {},
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  height: 4,
                  margin: EdgeInsets.only(right: i < total - 1 ? 4 : 0),
                  decoration: BoxDecoration(
                    color: active || past ? AurixTokens.orange : AurixTokens.glass(0.2),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                labels[i],
                style: TextStyle(
                  color: active ? AurixTokens.text : AurixTokens.muted,
                  fontSize: 11,
                  fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        );
      }),
    );
  }
}

class _Step1Main extends StatelessWidget {
  final TextEditingController titleController;
  final TextEditingController artistController;
  final TextEditingController genreController;
  final String releaseType;
  final DateTime? releaseDate;
  final ValueChanged<String> onReleaseTypeChanged;
  final ValueChanged<DateTime?> onReleaseDateChanged;
  final String? coverUrl;
  final Uint8List? coverPreviewBytes;
  final bool coverUploading;
  final VoidCallback onCoverTap;
  final VoidCallback onNext;

  const _Step1Main({
    required this.titleController,
    required this.artistController,
    required this.genreController,
    required this.releaseType,
    required this.releaseDate,
    required this.onReleaseTypeChanged,
    required this.onReleaseDateChanged,
    this.coverUrl,
    this.coverPreviewBytes,
    this.coverUploading = false,
    required this.onCoverTap,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Основное', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          TextField(
            controller: titleController,
            decoration: InputDecoration(
              labelText: 'Название релиза',
              hintText: 'Например: Summer EP',
              filled: true,
              fillColor: AurixTokens.glass(0.06),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: artistController,
            decoration: InputDecoration(
              labelText: 'Артист',
              filled: true,
              fillColor: AurixTokens.glass(0.06),
            ),
          ),
          const SizedBox(height: 16),
          DropdownButtonFormField<String>(
            value: releaseType,
            decoration: InputDecoration(
              labelText: 'Тип релиза',
              filled: true,
              fillColor: AurixTokens.glass(0.06),
            ),
            items: const [
              DropdownMenuItem(value: 'single', child: Text('Сингл')),
              DropdownMenuItem(value: 'ep', child: Text('EP')),
              DropdownMenuItem(value: 'album', child: Text('Альбом')),
            ],
            onChanged: (v) => onReleaseTypeChanged(v ?? 'single'),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: genreController,
            decoration: InputDecoration(
              labelText: 'Жанр',
              hintText: 'Pop, Rock, ...',
              filled: true,
              fillColor: AurixTokens.glass(0.06),
            ),
          ),
          const SizedBox(height: 16),
          ListTile(
            title: Text(releaseDate == null ? 'Дата выхода (необязательно)' : 'Дата: ${releaseDate!.day}.${releaseDate!.month}.${releaseDate!.year}'),
            trailing: const Icon(Icons.calendar_today),
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: DateTime.now(),
                firstDate: DateTime(2020),
                lastDate: DateTime(2030),
              );
              if (d != null) onReleaseDateChanged(d);
            },
          ),
          const SizedBox(height: 24),
          _CoverDropZone(
            label: 'Обложка',
            coverUrl: coverUrl,
            coverPreviewBytes: coverPreviewBytes,
            uploading: coverUploading,
            onTap: onCoverTap,
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              AurixButton(text: 'Далее', onPressed: onNext, icon: Icons.arrow_forward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _CoverDropZone extends StatefulWidget {
  final String label;
  final String? coverUrl;
  final Uint8List? coverPreviewBytes;
  final bool uploading;
  final VoidCallback onTap;

  const _CoverDropZone({
    required this.label,
    this.coverUrl,
    this.coverPreviewBytes,
    this.uploading = false,
    required this.onTap,
  });

  @override
  State<_CoverDropZone> createState() => _CoverDropZoneState();
}

class _CoverDropZoneState extends State<_CoverDropZone> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final hasPreview = widget.coverUrl != null || widget.coverPreviewBytes != null;

    return MouseRegion(
      onEnter: (_) => setState(() => _hover = true),
      onExit: (_) => setState(() => _hover = false),
      child: GestureDetector(
        onTap: widget.uploading ? null : widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 32, horizontal: 24),
          decoration: BoxDecoration(
            color: AurixTokens.glass(_hover && !widget.uploading ? 0.1 : 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _hover && !widget.uploading ? AurixTokens.orange.withValues(alpha: 0.5) : AurixTokens.stroke(),
              width: 1,
            ),
          ),
          child: widget.uploading
              ? Column(
                  children: [
                    const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
                    const SizedBox(height: 12),
                    Text('Загрузка...', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ],
                )
              : hasPreview
                  ? Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: widget.coverPreviewBytes != null
                              ? Image.memory(widget.coverPreviewBytes!, height: 120, width: 120, fit: BoxFit.cover)
                              : widget.coverUrl != null
                                  ? Image.network(widget.coverUrl!, height: 120, width: 120, fit: BoxFit.cover, errorBuilder: (_, __, ___) => const Icon(Icons.broken_image, size: 48))
                                  : const SizedBox.shrink(),
                        ),
                        const SizedBox(height: 12),
                        Text(widget.label, style: TextStyle(color: AurixTokens.muted, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Нажмите, чтобы заменить', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                      ],
                    )
                  : Column(
                      children: [
                        Icon(Icons.image_rounded, size: 40, color: AurixTokens.orange.withValues(alpha: 0.8)),
                        const SizedBox(height: 12),
                        Text(widget.label, style: TextStyle(color: AurixTokens.muted, fontWeight: FontWeight.w500)),
                        const SizedBox(height: 4),
                        Text('Нажмите для выбора файла', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
                      ],
                    ),
        ),
      ),
    );
  }
}

class _TrackEntry {
  _TrackEntry({this.id, this.title = '', this.version = 'original', this.explicit = false});
  String? id;
  String title;
  String version;
  bool explicit;
}

class _Step2Tracks extends StatelessWidget {
  final List<_TrackEntry> tracks;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int, _TrackEntry) onUpdate;
  final bool canProceed;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _Step2Tracks({
    required this.tracks,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    this.canProceed = false,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Треки', style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Добавить трек'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (tracks.isEmpty)
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AurixTokens.glass(0.06),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.music_note_rounded, size: 48, color: AurixTokens.muted),
                    const SizedBox(height: 12),
                    Text('Пока нет треков', style: TextStyle(color: AurixTokens.muted)),
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: onAdd,
                      icon: const Icon(Icons.add),
                      label: const Text('Добавить первый трек'),
                    ),
                  ],
                ),
              ),
            )
          else
            ...List.generate(tracks.length, (i) {
              final t = tracks[i];
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Icon(Icons.drag_handle, color: AurixTokens.muted),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: (v) => onUpdate(i, _TrackEntry(id: t.id, title: v, version: t.version, explicit: t.explicit)),
                        decoration: InputDecoration(
                          hintText: 'Трек ${i + 1}',
                          filled: true,
                          fillColor: AurixTokens.glass(0.06),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    SizedBox(
                      width: 120,
                      child: DropdownButtonFormField<String>(
                        value: t.version,
                        decoration: const InputDecoration(isDense: true),
                        items: const [
                          DropdownMenuItem(value: 'original', child: Text('Оригинал')),
                          DropdownMenuItem(value: 'remix', child: Text('Ремикс')),
                          DropdownMenuItem(value: 'instrumental', child: Text('Инструментал')),
                        ],
                        onChanged: (v) => onUpdate(i, _TrackEntry(id: t.id, title: t.title, version: v ?? t.version, explicit: t.explicit)),
                      ),
                    ),
                    Checkbox(
                      value: t.explicit,
                      onChanged: (v) => onUpdate(i, _TrackEntry(id: t.id, title: t.title, version: t.version, explicit: v ?? false)),
                      activeColor: AurixTokens.orange,
                    ),
                    IconButton(icon: const Icon(Icons.close), onPressed: () => onRemove(i), color: AurixTokens.muted),
                  ],
                ),
              );
            }),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onPrev, child: const Text('Назад')),
              AurixButton(text: 'Далее', onPressed: canProceed ? onNext : null, icon: Icons.arrow_forward_rounded),
            ],
          ),
          if (!canProceed && tracks.isNotEmpty) const SizedBox.shrink(),
          if (!canProceed && tracks.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text('Добавьте хотя бы один трек', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
            ),
        ],
      ),
    );
  }
}

class _SplitEntry {
  String name;
  int percent;
  _SplitEntry({required this.name, required this.percent});
}

class _Step3Splits extends StatelessWidget {
  final List<_SplitEntry> splits;
  final VoidCallback onAdd;
  final ValueChanged<int> onRemove;
  final void Function(int, _SplitEntry) onUpdate;
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _Step3Splits({
    required this.splits,
    required this.onAdd,
    required this.onRemove,
    required this.onUpdate,
    required this.onNext,
    required this.onPrev,
  });

  @override
  Widget build(BuildContext context) {
    final total = splits.fold<int>(0, (s, e) => s + e.percent);
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Сплиты (участники и доли)', style: Theme.of(context).textTheme.titleLarge),
              TextButton.icon(
                onPressed: onAdd,
                icon: const Icon(Icons.add),
                label: const Text('Добавить'),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...splits.asMap().entries.map((e) {
            final i = e.key;
            final s = e.value;
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      onChanged: (v) => onUpdate(i, _SplitEntry(name: v, percent: s.percent)),
                      decoration: InputDecoration(
                        hintText: 'Имя участника',
                        filled: true,
                        fillColor: AurixTokens.glass(0.06),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  SizedBox(
                    width: 80,
                    child: TextField(
                      keyboardType: TextInputType.number,
                      onChanged: (v) => onUpdate(i, _SplitEntry(name: s.name, percent: int.tryParse(v) ?? 0)),
                      decoration: InputDecoration(
                        hintText: '%',
                        filled: true,
                        fillColor: AurixTokens.glass(0.06),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(total == 100 ? Icons.check_circle : Icons.warning_amber, size: 20, color: total == 100 ? Colors.green : AurixTokens.orange),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => onRemove(i), color: AurixTokens.muted),
                ],
              ),
            );
          }),
          const SizedBox(height: 12),
          Text('Сумма: $total%', style: TextStyle(
            color: total == 100 ? Colors.green : AurixTokens.orange,
            fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onPrev, child: const Text('Назад')),
              AurixButton(text: 'Далее', onPressed: onNext, icon: Icons.arrow_forward_rounded),
            ],
          ),
        ],
      ),
    );
  }
}

class _Step4PlatformsSubmit extends StatelessWidget {
  final VoidCallback onPrev;
  final Future<void> Function() onSaveDraft;
  final Future<void> Function() onSubmit;
  final bool loading;

  const _Step4PlatformsSubmit({
    required this.onPrev,
    required this.onSaveDraft,
    required this.onSubmit,
    required this.loading,
  });

  @override
  Widget build(BuildContext context) {
    return AurixGlassCard(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Площадки и отправка', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 24),
          Text('Платформы', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          CheckboxListTile(title: const Text('Spotify'), value: true, onChanged: (_) {}, activeColor: AurixTokens.orange),
          CheckboxListTile(title: const Text('Apple Music'), value: true, onChanged: (_) {}, activeColor: AurixTokens.orange),
          CheckboxListTile(title: const Text('YouTube Music'), value: true, onChanged: (_) {}, activeColor: AurixTokens.orange),
          CheckboxListTile(title: const Text('Deezer'), value: true, onChanged: (_) {}, activeColor: AurixTokens.orange),
          const SizedBox(height: 24),
          Text('Подтвердите и отправьте релиз на модерацию.', style: TextStyle(color: AurixTokens.muted)),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              TextButton(onPressed: onPrev, child: const Text('Назад')),
              Row(
                children: [
                  TextButton(
                    onPressed: loading ? null : () async { await onSaveDraft(); },
                    child: const Text('Сохранить черновик'),
                  ),
                  const SizedBox(width: 12),
                  AurixButton(
                    text: 'Отправить на модерацию',
                    onPressed: loading ? null : () async { await onSubmit(); },
                    icon: Icons.send_rounded,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}
