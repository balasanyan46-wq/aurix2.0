import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'dart:io' if (dart.library.html) 'package:aurix_flutter/io_stub.dart' show File;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/core/supabase_diagnostics.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_button.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:uuid/uuid.dart';
import 'package:aurix_flutter/features/covers/cover_generator_sheet.dart';

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
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  final _genreCtrl = TextEditingController();
  final _languageCtrl = TextEditingController();
  final _upcCtrl = TextEditingController();
  final _labelCtrl = TextEditingController();
  String _releaseType = 'single';
  DateTime? _releaseDate;
  bool _explicit = false;
  bool _loading = false;
  String? _error;
  String? _progress;

  PlatformFile? _coverFile;
  Uint8List? _coverBytes;
  final List<_TrackEntry> _tracks = [];
  bool _isPicking = false;

  @override
  void initState() {
    super.initState();
    final profile = ref.read(currentProfileProvider).valueOrNull;
    if (profile != null) {
      _artistCtrl.text = profile.artistName ?? profile.displayName ?? '';
    }
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _genreCtrl.dispose();
    _languageCtrl.dispose();
    _upcCtrl.dispose();
    _labelCtrl.dispose();
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
    if (_isPicking) return;
    _isPicking = true;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.image, allowMultiple: false, withData: true);
      if (result == null) return;
      final f = result.files.single;
      if (f.size > 10 * 1024 * 1024) {
        if (mounted) _snack('Обложка не более 10 МБ');
        return;
      }
      final bytes = await _getFileBytes(f);
      if (bytes != null && mounted) setState(() { _coverFile = f; _coverBytes = bytes; });
    } catch (e) {
      if (mounted) _snack('Ошибка: $e');
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _pickTracks() async {
    if (_isPicking) return;
    _isPicking = true;
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio, allowMultiple: true, withData: true);
      if (result == null) return;
      if (mounted) {
        setState(() {
          for (final f in result.files) {
            if (f.size > 200 * 1024 * 1024) continue;
            if (f.bytes != null || f.path != null) _tracks.add(_TrackEntry(file: f));
          }
        });
      }
    } catch (e) {
      if (mounted) _snack('Ошибка: $e');
    } finally {
      _isPicking = false;
    }
  }

  Future<void> _openCoverGenerator() async {
    if (_loading || _isPicking) return;
    final bytes = await CoverGeneratorSheet.open(
      context,
      initialArtistName: _artistCtrl.text.trim(),
      initialReleaseTitle: _titleCtrl.text.trim(),
      initialGenre: _genreCtrl.text.trim(),
      onApplied: null,
    );
    if (!mounted) return;
    if (bytes == null || bytes.isEmpty) return;
    setState(() {
      _coverBytes = bytes;
      _coverFile = PlatformFile(name: 'generated_cover.png', size: bytes.length, bytes: bytes);
    });
  }

  void _removeTrack(int i) {
    setState(() { _tracks[i].dispose(); _tracks.removeAt(i); });
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  Future<void> _submit() async {
    final userId = ref.read(currentUserProvider)?.id;
    if (userId == null) { _snack('Войдите в аккаунт'); return; }
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (_tracks.isEmpty) { setState(() => _error = 'Добавьте хотя бы один трек'); return; }

    setState(() { _error = null; _loading = true; _progress = 'Создание релиза...'; });
    try {
      final repo = ref.read(releaseRepositoryProvider);
      final fileRepo = ref.read(fileRepositoryProvider);
      final trackRepo = ref.read(trackRepositoryProvider);

      final release = await repo.createRelease(
        ownerId: userId,
        title: _titleCtrl.text.trim(),
        artist: _artistCtrl.text.trim().isEmpty ? 'Unknown Artist' : _artistCtrl.text.trim(),
        releaseType: _releaseType,
        releaseDate: _releaseDate,
        genre: _genreCtrl.text.trim().isEmpty ? null : _genreCtrl.text.trim(),
        language: _languageCtrl.text.trim().isEmpty ? null : _languageCtrl.text.trim(),
        explicit: _explicit,
        upc: _upcCtrl.text.trim().isEmpty ? null : _upcCtrl.text.trim(),
        label: _labelCtrl.text.trim().isEmpty ? null : _labelCtrl.text.trim(),
        copyrightYear: DateTime.now().year,
      );

      if (_coverFile != null) {
        setState(() => _progress = 'Загрузка обложки...');
        final bytes = _coverBytes ?? await _getFileBytes(_coverFile!);
        if (bytes == null || bytes.isEmpty) throw StateError('Не удалось прочитать файл обложки');
        final r = await fileRepo.uploadCoverBytes(userId, release.id, bytes, _coverFile!.name);
        await repo.updateRelease(release.id, coverUrl: r.publicUrl, coverPath: r.coverPath);
      }

      for (var i = 0; i < _tracks.length; i++) {
        final entry = _tracks[i];
        setState(() => _progress = 'Загрузка трека ${i + 1}/${_tracks.length}...');
        final bytes = await _getFileBytes(entry.file);
        if (bytes == null || bytes.isEmpty) throw StateError('Не удалось прочитать файл: ${entry.file.name}');
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Релиз создан'), backgroundColor: AurixTokens.positive),
        );
        context.go('/releases/${release.id}');
      }
    } catch (e, st) {
      final detail = formatSupabaseError(e);
      debugPrint('Ошибка создания: $detail\n$st');
      setState(() {
        _error = detail.length > 120 ? '${detail.substring(0, 117)}...' : detail;
        _loading = false;
        _progress = null;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDesktop = MediaQuery.sizeOf(context).width >= kDesktopBreakpoint;

    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: AurixTokens.text),
          onPressed: () { if (context.canPop()) context.pop(); else context.go('/releases'); },
        ),
        title: const Text('Новый релиз', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 18)),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.all(isDesktop ? 32 : 20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 780),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (_error != null) ...[
                    _ErrorBanner(message: _error!),
                    const SizedBox(height: 20),
                  ],

                  // ── Section 1: Cover + Metadata ──────────────
                  _Section(
                    title: 'Основная информация',
                    icon: Icons.album_rounded,
                    child: isDesktop
                        ? Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              _CoverPicker(
                                bytes: _coverBytes,
                                fileName: _coverFile?.name,
                                onPick: _pickCover,
                              ),
                              const SizedBox(height: 10),
                              OutlinedButton.icon(
                                onPressed: _loading ? null : () => _openCoverGenerator(),
                                icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: AurixTokens.orange),
                                label: const Text('Сгенерировать'),
                                style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                              ),
                              const SizedBox(width: 24),
                              Expanded(child: _buildMetadataFields()),
                            ],
                          )
                        : Column(
                            children: [
                              _CoverPicker(
                                bytes: _coverBytes,
                                fileName: _coverFile?.name,
                                onPick: _pickCover,
                              ),
                              const SizedBox(height: 10),
                              SizedBox(
                                width: double.infinity,
                                child: OutlinedButton.icon(
                                  onPressed: _loading ? null : () => _openCoverGenerator(),
                                  icon: const Icon(Icons.auto_awesome_rounded, size: 18, color: AurixTokens.orange),
                                  label: const Text('Сгенерировать обложку'),
                                  style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                                ),
                              ),
                              const SizedBox(height: 20),
                              _buildMetadataFields(),
                            ],
                          ),
                  ),

                  const SizedBox(height: 20),

                  // ── Section 2: Details ───────────────────────
                  _Section(
                    title: 'Детали',
                    icon: Icons.tune_rounded,
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Expanded(child: _field('Язык', _languageCtrl, hint: 'Русский, English...')),
                            const SizedBox(width: 12),
                            Expanded(child: _field('Лейбл', _labelCtrl, hint: 'Самовыпуск')),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(child: _field('UPC / EAN', _upcCtrl, hint: 'Штрихкод (необязательно)')),
                            const SizedBox(width: 12),
                            Expanded(
                              child: InkWell(
                                onTap: () async {
                                  final d = await showDatePicker(
                                    context: context,
                                    initialDate: _releaseDate ?? DateTime.now(),
                                    firstDate: DateTime(1900),
                                    lastDate: DateTime(2100),
                                    builder: (ctx, child) => Theme(
                                      data: Theme.of(ctx).copyWith(
                                        colorScheme: ColorScheme.dark(primary: AurixTokens.orange, surface: AurixTokens.bg1),
                                      ),
                                      child: child!,
                                    ),
                                  );
                                  if (d != null) setState(() => _releaseDate = d);
                                },
                                borderRadius: BorderRadius.circular(12),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                                  decoration: BoxDecoration(
                                    color: AurixTokens.bg2,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: AurixTokens.border),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.calendar_today_rounded, size: 18, color: AurixTokens.muted),
                                      const SizedBox(width: 10),
                                      Text(
                                        _releaseDate != null ? DateFormat('dd.MM.yyyy').format(_releaseDate!) : 'Дата выхода',
                                        style: TextStyle(color: _releaseDate != null ? AurixTokens.text : AurixTokens.muted, fontSize: 14),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _buildExplicitToggle(),
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // ── Section 3: Tracks ────────────────────────
                  _Section(
                    title: 'Треки',
                    icon: Icons.music_note_rounded,
                    trailing: TextButton.icon(
                      onPressed: _pickTracks,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text('Добавить'),
                      style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
                    ),
                    child: _tracks.isEmpty
                        ? _buildEmptyTracks()
                        : Column(
                            children: [
                              ReorderableListView.builder(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                itemCount: _tracks.length,
                                onReorder: (old, idx) {
                                  setState(() {
                                    if (idx > old) idx--;
                                    final item = _tracks.removeAt(old);
                                    _tracks.insert(idx, item);
                                  });
                                },
                                itemBuilder: (_, i) => _TrackCard(
                                  key: ValueKey(_tracks[i]),
                                  index: i,
                                  entry: _tracks[i],
                                  onRemove: () => _removeTrack(i),
                                  onVersionChanged: (v) => setState(() => _tracks[i].version = v),
                                  onExplicitChanged: (v) => setState(() => _tracks[i].explicit = v),
                                ),
                              ),
                              const SizedBox(height: 12),
                              _AddTrackButton(onTap: _pickTracks),
                            ],
                          ),
                  ),

                  const SizedBox(height: 32),

                  // ── Submit ───────────────────────────────────
                  SizedBox(
                    height: 56,
                    child: _loading
                        ? Container(
                            decoration: BoxDecoration(
                              color: AurixTokens.orange.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.3)),
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
                                if (_progress != null) ...[
                                  const SizedBox(width: 12),
                                  Text(_progress!, style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600)),
                                ],
                              ],
                            ),
                          )
                        : AurixButton(text: 'Создать релиз', icon: Icons.publish_rounded, onPressed: _submit),
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

  Widget _buildMetadataFields() {
    return Column(
      children: [
        _field('Название релиза *', _titleCtrl, hint: 'Summer EP', validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите название' : null),
        const SizedBox(height: 12),
        _field('Артист *', _artistCtrl, validator: (v) => (v == null || v.trim().isEmpty) ? 'Введите имя артиста' : null),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: DropdownButtonFormField<String>(
                value: _releaseType,
                dropdownColor: AurixTokens.bg2,
                style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                decoration: _inputDecoration('Тип релиза'),
                items: const [
                  DropdownMenuItem(value: 'single', child: Text('Сингл')),
                  DropdownMenuItem(value: 'ep', child: Text('EP')),
                  DropdownMenuItem(value: 'album', child: Text('Альбом')),
                ],
                onChanged: (v) => setState(() => _releaseType = v ?? 'single'),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(child: _field('Жанр', _genreCtrl, hint: 'Pop, Rap, R&B...')),
          ],
        ),
      ],
    );
  }

  Widget _buildExplicitToggle() {
    return InkWell(
      onTap: () => setState(() => _explicit = !_explicit),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AurixTokens.bg2,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Row(
          children: [
            Icon(
              _explicit ? Icons.explicit_rounded : Icons.explicit_rounded,
              color: _explicit ? AurixTokens.orange : AurixTokens.muted,
              size: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Explicit (ненормативная лексика)',
                style: TextStyle(color: _explicit ? AurixTokens.text : AurixTokens.muted, fontSize: 14),
              ),
            ),
            Switch(
              value: _explicit,
              onChanged: (v) => setState(() => _explicit = v),
              activeColor: AurixTokens.orange,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyTracks() {
    return InkWell(
      onTap: _pickTracks,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
        decoration: BoxDecoration(
          color: AurixTokens.bg2,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AurixTokens.border, style: BorderStyle.solid),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AurixTokens.orange.withValues(alpha: 0.08),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.audiotrack_rounded, size: 32, color: AurixTokens.orange.withValues(alpha: 0.6)),
            ),
            const SizedBox(height: 16),
            const Text('Добавьте треки', style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 15)),
            const SizedBox(height: 6),
            Text('MP3, WAV, FLAC — до 200 МБ на трек', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              decoration: BoxDecoration(
                border: Border.all(color: AurixTokens.orange.withValues(alpha: 0.4)),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text('Выбрать файлы', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w600, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _field(String label, TextEditingController ctrl, {String? hint, String? Function(String?)? validator}) {
    return TextFormField(
      controller: ctrl,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      validator: validator,
      decoration: _inputDecoration(label, hint: hint),
    );
  }

  InputDecoration _inputDecoration(String label, {String? hint}) => InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 13),
        hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.5), fontSize: 13),
        filled: true,
        fillColor: AurixTokens.bg2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.border)),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5))),
        errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: Colors.redAccent.withValues(alpha: 0.5))),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      );
}

// ─── Section Card ───────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String title;
  final IconData icon;
  final Widget child;
  final Widget? trailing;

  const _Section({required this.title, required this.icon, required this.child, this.trailing});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: AurixTokens.orange),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 20),
          child,
        ],
      ),
    );
  }
}

// ─── Cover Picker ───────────────────────────────────────────────────────

class _CoverPicker extends StatefulWidget {
  final Uint8List? bytes;
  final String? fileName;
  final VoidCallback onPick;

  const _CoverPicker({this.bytes, this.fileName, required this.onPick});

  @override
  State<_CoverPicker> createState() => _CoverPickerState();
}

class _CoverPickerState extends State<_CoverPicker> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    const size = 180.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: GestureDetector(
        onTap: widget.onPick,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AurixTokens.bg2,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: _hovered ? AurixTokens.orange.withValues(alpha: 0.5) : AurixTokens.border,
              width: _hovered ? 1.5 : 1,
            ),
            image: widget.bytes != null
                ? DecorationImage(image: MemoryImage(widget.bytes!), fit: BoxFit.cover)
                : null,
          ),
          child: widget.bytes != null
              ? AnimatedOpacity(
                  opacity: _hovered ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 200),
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      borderRadius: BorderRadius.circular(13),
                    ),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.edit_rounded, color: Colors.white70, size: 24),
                          SizedBox(height: 4),
                          Text('Заменить', style: TextStyle(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ),
                  ),
                )
              : Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.image_rounded, size: 36, color: AurixTokens.orange.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text('Обложка', style: TextStyle(color: AurixTokens.muted, fontWeight: FontWeight.w500, fontSize: 13)),
                    const SizedBox(height: 4),
                    Text('JPG, PNG', style: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.6), fontSize: 11)),
                  ],
                ),
        ),
      ),
    );
  }
}

// ─── Error Banner ───────────────────────────────────────────────────────

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.25)),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline_rounded, color: Colors.redAccent, size: 20),
          const SizedBox(width: 12),
          Expanded(child: Text(message, style: const TextStyle(color: Colors.redAccent, fontSize: 13))),
        ],
      ),
    );
  }
}

// ─── Track Card ─────────────────────────────────────────────────────────

class _TrackCard extends StatelessWidget {
  final int index;
  final _TrackEntry entry;
  final VoidCallback onRemove;
  final ValueChanged<String> onVersionChanged;
  final ValueChanged<bool> onExplicitChanged;

  const _TrackCard({
    super.key,
    required this.index,
    required this.entry,
    required this.onRemove,
    required this.onVersionChanged,
    required this.onExplicitChanged,
  });

  @override
  Widget build(BuildContext context) {
    final ext = entry.file.name.split('.').last.toUpperCase();
    final sizeMb = (entry.file.size / (1024 * 1024)).toStringAsFixed(1);

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Icon(Icons.drag_handle_rounded, color: AurixTokens.muted, size: 20),
              const SizedBox(width: 8),
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: AurixTokens.orange.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                alignment: Alignment.center,
                child: Text(
                  '${index + 1}',
                  style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700, fontSize: 13),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.file.name,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text('$ext · $sizeMb МБ', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close_rounded, size: 18, color: Colors.redAccent),
                onPressed: onRemove,
                visualDensity: VisualDensity.compact,
                tooltip: 'Удалить трек',
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Title + ISRC
          Row(
            children: [
              Expanded(
                flex: 3,
                child: TextFormField(
                  controller: entry.titleCtrl,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                  decoration: InputDecoration(
                    labelText: 'Название',
                    isDense: true,
                    labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 12),
                    filled: true,
                    fillColor: AurixTokens.bg1,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: TextFormField(
                  controller: entry.isrcCtrl,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                  textCapitalization: TextCapitalization.characters,
                  decoration: InputDecoration(
                    labelText: 'ISRC',
                    hintText: 'QZDA7...',
                    isDense: true,
                    labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 12),
                    hintStyle: TextStyle(color: AurixTokens.muted.withValues(alpha: 0.4), fontSize: 12),
                    filled: true,
                    fillColor: AurixTokens.bg1,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          // Version + Explicit
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: entry.version,
                  dropdownColor: AurixTokens.bg1,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                  decoration: InputDecoration(
                    labelText: 'Версия',
                    isDense: true,
                    labelStyle: TextStyle(color: AurixTokens.muted, fontSize: 12),
                    filled: true,
                    fillColor: AurixTokens.bg1,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: AurixTokens.border)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'original', child: Text('Original')),
                    DropdownMenuItem(value: 'remix', child: Text('Remix')),
                    DropdownMenuItem(value: 'instrumental', child: Text('Instrumental')),
                    DropdownMenuItem(value: 'acoustic', child: Text('Acoustic')),
                    DropdownMenuItem(value: 'live', child: Text('Live')),
                  ],
                  onChanged: (v) => onVersionChanged(v ?? 'original'),
                ),
              ),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => onExplicitChanged(!entry.explicit),
                borderRadius: BorderRadius.circular(10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: entry.explicit ? AurixTokens.orange.withValues(alpha: 0.12) : AurixTokens.bg1,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: entry.explicit ? AurixTokens.orange.withValues(alpha: 0.3) : AurixTokens.border),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.explicit_rounded, size: 18, color: entry.explicit ? AurixTokens.orange : AurixTokens.muted),
                      const SizedBox(width: 6),
                      Text('E', style: TextStyle(color: entry.explicit ? AurixTokens.orange : AurixTokens.muted, fontWeight: FontWeight.w700, fontSize: 13)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Add Track Button ───────────────────────────────────────────────────

class _AddTrackButton extends StatefulWidget {
  final VoidCallback onTap;
  const _AddTrackButton({required this.onTap});

  @override
  State<_AddTrackButton> createState() => _AddTrackButtonState();
}

class _AddTrackButtonState extends State<_AddTrackButton> {
  bool _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: _hovered ? AurixTokens.orange.withValues(alpha: 0.06) : Colors.transparent,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _hovered ? AurixTokens.orange.withValues(alpha: 0.3) : AurixTokens.border,
              style: BorderStyle.solid,
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.add_rounded, size: 18, color: _hovered ? AurixTokens.orange : AurixTokens.muted),
              const SizedBox(width: 8),
              Text(
                'Добавить ещё треки',
                style: TextStyle(color: _hovered ? AurixTokens.orange : AurixTokens.muted, fontSize: 13, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
