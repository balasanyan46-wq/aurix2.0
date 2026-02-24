import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/repositories/file_repository.dart';
import 'package:uuid/uuid.dart';

class CreateReleaseScreen extends ConsumerStatefulWidget {
  const CreateReleaseScreen({super.key});

  @override
  ConsumerState<CreateReleaseScreen> createState() => _CreateReleaseScreenState();
}

class _CreateReleaseScreenState extends ConsumerState<CreateReleaseScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _artistController = TextEditingController();
  String _releaseType = 'single';
  DateTime? _releaseDate;
  final _genreController = TextEditingController();
  final _languageController = TextEditingController();
  bool _loading = false;
  String? _error;

  PlatformFile? _coverFile;
  PlatformFile? _trackFile;

  @override
  void dispose() {
    _titleController.dispose();
    _artistController.dispose();
    _genreController.dispose();
    _languageController.dispose();
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
      final result = await FilePicker.platform.pickFiles(
        type: FileType.image,
        allowMultiple: false,
        withData: true,
      );
      if (result != null) {
        final f = result.files.single;
        if (f.bytes != null || f.path != null) setState(() => _coverFile = f);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка выбора файла: $e')));
    }
  }

  Future<void> _pickTrack() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.audio,
        allowMultiple: false,
        withData: true,
      );
      if (result != null) {
        final f = result.files.single;
        if (f.bytes != null || f.path != null) setState(() => _trackFile = f);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка выбора файла: $e')));
    }
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Войдите в аккаунт')));
      return;
    }
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _error = null;
      _loading = true;
    });
    try {
      final repo = ref.read(releaseRepositoryProvider);
      final fileRepo = ref.read(fileRepositoryProvider);

      final release = await repo.createRelease(
        ownerId: userId,
        title: _titleController.text.trim(),
        artist: _artistController.text.trim(),
        releaseType: _releaseType,
        releaseDate: _releaseDate,
        genre: _genreController.text.trim().isEmpty ? null : _genreController.text.trim(),
        language: _languageController.text.trim().isEmpty ? null : _languageController.text.trim(),
      );

      if (_coverFile != null) {
        final bytes = await _getFileBytes(_coverFile!);
        if (bytes == null || bytes.isEmpty) throw StateError('Не удалось прочитать файл обложки');
        final r = await fileRepo.uploadCoverBytes(userId, release.id, bytes, _coverFile!.name);
        await repo.updateRelease(release.id, coverUrl: r.publicUrl, coverPath: r.coverPath);
      }
      if (_trackFile != null) {
        final bytes = await _getFileBytes(_trackFile!);
        if (bytes == null || bytes.isEmpty) throw StateError('Не удалось прочитать файл трека');
        final trackRepo = ref.read(trackRepositoryProvider);
        final trackId = const Uuid().v4();
        final ext = _trackFile!.extension ?? _trackFile!.name.split('.').lastOrNull ?? 'wav';
        final r = await fileRepo.uploadTrackBytes(userId, release.id, trackId, bytes, ext);
        await trackRepo.addTrack(id: trackId, releaseId: release.id, audioPath: r.path, audioUrl: r.publicUrl, title: _trackFile!.name);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Релиз создан')));
        context.go('/releases/${release.id}');
      }
    } catch (e, st) {
      final detail = formatSupabaseError(e);
      debugPrint('Ошибка создания релиза: $detail\n$st');
      setState(() {
        if (detail.toLowerCase().contains('network') || detail.contains('Connection')) {
          _error = 'Нет связи. Проверьте интернет.';
        } else if (detail.contains('PGRST') || detail.contains('PostgrestException')) {
          _error = 'Ошибка базы данных. Проверьте подключение.';
        } else {
          _error = 'Ошибка: ${detail.length > 100 ? '${detail.substring(0, 97)}...' : detail}';
        }
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Новый релиз'), leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => context.pop())),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(color: Theme.of(context).colorScheme.errorContainer, borderRadius: BorderRadius.circular(12)),
                      child: Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.onErrorContainer)),
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(labelText: 'Название релиза *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _artistController,
                    decoration: const InputDecoration(labelText: 'Артист *'),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя артиста' : null,
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: _releaseType, // ignore: deprecated_member_use
                    decoration: const InputDecoration(labelText: 'Тип'),
                    items: const [
                      DropdownMenuItem(value: 'single', child: Text('Single')),
                      DropdownMenuItem(value: 'ep', child: Text('EP')),
                      DropdownMenuItem(value: 'album', child: Text('Album')),
                    ],
                    onChanged: (v) => setState(() => _releaseType = v ?? 'single'),
                  ),
                  const SizedBox(height: 16),
                  ListTile(
                    title: Text(_releaseDate == null ? 'Дата выхода (необязательно)' : 'Дата: ${_releaseDate!.day}.${_releaseDate!.month}.${_releaseDate!.year}'),
                    trailing: const Icon(Icons.calendar_today),
                    onTap: () async {
                      final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(1900), lastDate: DateTime(2100));
                      if (d != null) setState(() => _releaseDate = d);
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(controller: _genreController, decoration: const InputDecoration(labelText: 'Жанр')),
                  const SizedBox(height: 16),
                  TextFormField(controller: _languageController, decoration: const InputDecoration(labelText: 'Язык')),
                  const Divider(height: 32),
                  const Text('Файлы', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 8),
                  if (_coverFile != null && (_coverFile!.bytes != null || _coverFile!.path != null))
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: _coverFile!.bytes != null
                            ? Image.memory(_coverFile!.bytes!, height: 120, width: 120, fit: BoxFit.cover)
                            : const SizedBox.shrink(),
                      ),
                    ),
                  OutlinedButton.icon(
                    onPressed: _pickCover,
                    icon: const Icon(Icons.image),
                    label: Text(_coverFile == null ? 'Выбрать обложку (jpg/png)' : 'Обложка: ${_coverFile!.name}'),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _pickTrack,
                    icon: const Icon(Icons.audiotrack),
                    label: Text(_trackFile == null ? 'Выбрать трек (mp3/wav/flac)' : 'Трек: ${_trackFile!.name}'),
                  ),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _submit,
                    child: _loading ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2)) : const Text('Создать релиз'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
