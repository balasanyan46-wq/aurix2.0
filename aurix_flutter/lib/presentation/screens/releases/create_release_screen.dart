import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/repositories/file_repository.dart';
import 'package:uuid/uuid.dart';

class _TrackEntry {
  PlatformFile file;
  final TextEditingController titleCtrl;
  final TextEditingController isrcCtrl;
  String version;
  bool explicit;

  _TrackEntry({required this.file})
      : titleCtrl = TextEditingController(text: file.name.replaceAll(RegExp(r'\.[^.]+$'), '')),
        isrcCtrl = TextEditingController(),
        version = 'original',
        explicit = false;

  void dispose() {
    titleCtrl.dispose();
    isrcCtrl.dispose();
  }
}

class CreateReleaseScreen extends ConsumerStatefulWidget {
  const CreateReleaseScreen({super.key});

  @override
  ConsumerState<CreateReleaseScreen> createState() => _CreateReleaseScreenState();
}

class _CreateReleaseScreenState extends ConsumerState<CreateReleaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  final _genreController = TextEditingController();
  final _languageController = TextEditingController();
  final _upcController = TextEditingController();
  final _labelController = TextEditingController();
  String _releaseType = 'single';
  DateTime? _releaseDate;
  bool _explicit = false;
  bool _loading = false;
  String? _error;
  String? _progressText;

  PlatformFile? _coverFile;
  final List<_TrackEntry> _tracks = [];

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _genreController.dispose();
    _languageController.dispose();
    _upcController.dispose();
    _labelController.dispose();
    for (final t in _tracks) {
      t.dispose();
    }
    super.dispose();
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

  Future<void> _pickCover() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result != null) {
        final f = result.files.single;
        if (f.bytes != null || f.path != null) setState(() => _coverFile = f);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  Future<void> _pickTracks() async {
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true, withData: true);
      if (result != null) {
        setState(() {
          for (final f in result.files) {
            if (f.bytes != null || f.path != null) {
              _tracks.add(_TrackEntry(file: f));
            }
          }
        });
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
  }

  void _removeTrack(int index) {
    setState(() {
      _tracks[index].dispose();
      _tracks.removeAt(index);
    });
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tracks.isEmpty) {
      setState(() => _error = 'Добавьте хотя бы один трек');
      return;
    }

    setState(() { _error = null; _loading = true; _progressText = 'Создание релиза...'; });
    try {
      final repo = ref.read(releaseRepositoryProvider);
      final fileRepo = ref.read(fileRepositoryProvider);
      final trackRepo = ref.read(trackRepositoryProvider);

      final release = await repo.createRelease(
        ownerId: userId,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        releaseType: _releaseType,
        releaseDate: _releaseDate,
        genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
        explicit: _explicit,
        upc: _upcController.text.trim().isEmpty ? null : _upcController.text.trim(),
        label: _labelController.text.trim().isEmpty ? null : _labelController.text.trim(),
        copyrightYear: DateTime.now().year,
      );

      if (_coverFile != null) {
        setState(() => _progressText = 'Загрузка обложки...');
        final bytes = await _getFileBytes(_coverFile!);
        if (bytes == null || bytes.isEmpty) throw StateError('Не удалось прочитать файл обложки');
        final r = await fileRepo.uploadCoverBytes(userId, release.id, bytes, _coverFile!.name);
        await repo.updateRelease(release.id, coverUrl: r.publicUrl, coverPath: r.coverPath);
      }

      for (var i = 0; i < _tracks.length; i++) {
        final entry = _tracks[i];
        setState(() => _progressText = 'Загрузка трека ${i + 1}/${_tracks.length}...');
        final bytes = await _getFileBytes(entry.file);
        if (bytes == null || bytes.isEmpty) throw StateError('Не удалось прочитать файл трека: ${entry.file.name}');
        final trackId = const Uuid().v4();
        final ext = entry.file.extension ?? entry.file.name.split('.').lastOrNull ?? 'wav';
        final r = await fileRepo.uploadTrackBytes(userId, release.id, trackId, bytes, ext);
        await trackRepo.addTrack(
          id: trackId,
          releaseId: release.id,
          audioPath: r.path,
          audioUrl: r.publicUrl,
          title: entry.titleCtrl.text.trim().isEmpty ? entry.file.name : entry.titleCtrl.text.trim(),
          isrc: entry.isrcCtrl.text.trim().isEmpty ? null : entry.isrcCtrl.text.trim(),
          trackNumber: i,
          version: entry.version,
          explicit: entry.explicit,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Релиз создан')));
        context.go('/releases/${release.id}');
      }
    } catch (e, st) {
      final detail = formatSupabaseError(e);
      debugPrint('Ошибка создания релиза: $detail\n$st');
      setState(() {
        _error = 'Ошибка: ${detail.length > 120 ? '${detail.substring(0, 117)}...' : detail}';
        _loading = false;
        _progressText = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Новый релиз'),
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () {
          if (context.canPop()) { context.pop(); } else { context.go('/releases'); }
        }),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: const TextStyle(color: Colors.redAccent)),
                    ),
                    const SizedBox(height: 16),
                  ],

                  _sectionTitle('ОСНОВНАЯ ИНФОРМАЦИЯ'),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Название релиза *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _artistController,
                    decoration: const InputDecoration(labelText: 'Артист *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя артиста' : null,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: DropdownButtonFormField<String>(
                          value: _releaseType,
                          decoration: const InputDecoration(labelText: 'Тип'),
                          items: const [
                            DropdownMenuItem(value: 'single', child: Text('Single')),
                            DropdownMenuItem(value: 'ep', child: Text('EP')),
                            DropdownMenuItem(value: 'album', child: Text('Album')),
                          ],
                          onChanged: (v) => setState(() => _releaseType = v ?? 'single'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(controller: _genreController, decoration: const InputDecoration(labelText: 'Жанр')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextFormField(controller: _languageController, decoration: const InputDecoration(labelText: 'Язык')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: TextFormField(controller: _labelController, decoration: const InputDecoration(labelText: 'Лейбл')),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _upcController,
                    decoration: const InputDecoration(labelText: 'UPC / EAN', hintText: 'Штрихкод релиза (необязательно)'),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            _releaseDate == null ? 'Дата выхода' : 'Дата: ${_releaseDate!.day}.${_releaseDate!.month}.${_releaseDate!.year}',
                          ),
                          trailing: const Icon(Icons.calendar_today, size: 20),
                          onTap: () async {
                            final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
                            if (d != null) setState(() => _releaseDate = d);
                          },
                        ),
                      ),
                      const SizedBox(width: 12),
                      Row(
                        children: [
                          Checkbox(value: _explicit, onChanged: (v) => setState(() => _explicit = v ?? false)),
                          const Text('Explicit'),
                        ],
                      ),
                    ],
                  ),

                  const Divider(height: 32),
                  _sectionTitle('ОБЛОЖКА'),
                  const SizedBox(height: 8),
                  if (_coverFile != null && _coverFile!.bytes != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(_coverFile!.bytes!, height: 140, width: 140, fit: BoxFit.cover),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickCover,
                    icon: const Icon(Icons.image),
                    label: Text(_coverFile == null ? 'Выбрать обложку (jpg/png)' : 'Обложка: ${_coverFile!.name}'),
                  ),

                  const Divider(height: 32),
                  _sectionTitle('ТРЕКИ'),
                  const SizedBox(height: 8),
                  if (_tracks.isEmpty)
                    Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: AurixTokens.glass(0.05),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: AurixTokens.border),
                      ),
                      child: Column(
                        children: [
                          Icon(Icons.audiotrack, size: 32, color: AurixTokens.muted),
                          const SizedBox(height: 8),
                          Text('Нет треков', style: TextStyle(color: AurixTokens.muted)),
                          const SizedBox(height: 8),
                          FilledButton.icon(
                            onPressed: _pickTracks,
                            icon: const Icon(Icons.add, size: 18),
                            label: const Text('Добавить треки'),
                          ),
                        ],
                      ),
                    )
                  else ...[
                    ReorderableListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: _tracks.length,
                      onReorder: (oldIndex, newIndex) {
                        setState(() {
                          if (newIndex > oldIndex) newIndex--;
                          final item = _tracks.removeAt(oldIndex);
                          _tracks.insert(newIndex, item);
                        });
                      },
                      itemBuilder: (context, i) => _buildTrackCard(i, key: ValueKey(_tracks[i])),
                    ),
                    const SizedBox(height: 8),
                    OutlinedButton.icon(
                      onPressed: _pickTracks,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить ещё треки'),
                    ),
                  ],

                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)),
                                if (_progressText != null) ...[
                                  const SizedBox(width: 12),
                                  Text(_progressText!),
                                ],
                              ],
                            )
                          : const Text('Создать релиз'),
                    ),
                  ),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTrackCard(int index, {required Key key}) {
    final entry = _tracks[index];
    return Card(
      key: key,
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.drag_handle, color: AurixTokens.muted, size: 20),
                const SizedBox(width: 4),
                Container(
                  width: 28, height: 28,
                  decoration: BoxDecoration(color: AurixTokens.accent.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                  alignment: Alignment.center,
                  child: Text('${index + 1}', style: TextStyle(color: AurixTokens.accent, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(entry.file.name, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis),
                ),
                IconButton(
                  icon: const Icon(Icons.close, size: 18, color: Colors.redAccent),
                  onPressed: () => _removeTrack(index),
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: entry.titleCtrl,
              decoration: const InputDecoration(labelText: 'Название трека', isDense: true),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: entry.isrcCtrl,
                    decoration: const InputDecoration(labelText: 'ISRC', hintText: 'QZDA72198362', isDense: true),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: entry.version,
                    decoration: const InputDecoration(labelText: 'Версия', isDense: true),
                    items: const [
                      DropdownMenuItem(value: 'original', child: Text('Original')),
                      DropdownMenuItem(value: 'remix', child: Text('Remix')),
                      DropdownMenuItem(value: 'instrumental', child: Text('Instrumental')),
                    ],
                    onChanged: (v) => setState(() => entry.version = v ?? 'original'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Checkbox(
                  value: entry.explicit,
                  onChanged: (v) => setState(() => entry.explicit = v ?? false),
                  visualDensity: VisualDensity.compact,
                ),
                const Text('Explicit', style: TextStyle(fontSize: 13)),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionTitle(String text) => Text(
    text,
    style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
  );
}
