import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/track_model.dart';
import 'package:aurix_flutter/data/models/admin_note_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class AdminReleasesTab extends ConsumerStatefulWidget {
  const AdminReleasesTab({super.key});

  @override
  ConsumerState<AdminReleasesTab> createState() => _AdminReleasesTabState();
}

class _AdminReleasesTabState extends ConsumerState<AdminReleasesTab> {
  String _statusFilter = 'all';
  String _search = '';

  static const _statuses = ['all', 'draft', 'submitted', 'in_review', 'approved', 'rejected', 'live'];

  static String _statusLabel(String s) => switch (s) {
        'all' => 'Все',
        'draft' => 'Черновик',
        'submitted' => 'На модерации',
        'in_review' => 'На проверке',
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        'live' => 'Опубликован',
        _ => s,
      };

  Color _statusColor(String status) => switch (status) {
        'submitted' => Colors.amber,
        'in_review' => Colors.blue,
        'approved' || 'live' => AurixTokens.positive,
        'rejected' => Colors.redAccent,
        'draft' => AurixTokens.muted,
        _ => AurixTokens.muted,
      };

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(allReleasesAdminProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          color: AurixTokens.bg1,
          child: Column(
            children: [
              TextField(
                style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                decoration: InputDecoration(
                  hintText: 'Поиск по названию или артисту...',
                  hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AurixTokens.muted, size: 20),
                  filled: true,
                  fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _statuses.map((s) {
                    final isSelected = _statusFilter == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_statusLabel(s)),
                        selected: isSelected,
                        onSelected: (_) => setState(() => _statusFilter = s),
                        selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
                        backgroundColor: AurixTokens.bg2,
                        labelStyle: TextStyle(
                          color: isSelected ? AurixTokens.orange : AurixTokens.muted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                        side: BorderSide(
                          color: isSelected ? AurixTokens.orange.withValues(alpha: 0.4) : AurixTokens.border,
                        ),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: releasesAsync.when(
            data: (releases) {
              var filtered = releases.where((r) {
                if (_statusFilter != 'all' && r.status != _statusFilter) return false;
                if (_search.isNotEmpty) {
                  final t = r.title.toLowerCase();
                  final a = (r.artist ?? '').toLowerCase();
                  if (!t.contains(_search) && !a.contains(_search)) return false;
                }
                return true;
              }).toList();

              if (filtered.isEmpty) {
                return Center(child: Text('Нет релизов', style: TextStyle(color: AurixTokens.muted)));
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) {
                  final r = filtered[i];
                  return _ReleaseCard(
                    release: r,
                    statusColor: _statusColor(r.status),
                    statusLabel: _statusLabel(r.status),
                    onTap: () => _openDetail(context, r),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, ReleaseModel release) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AurixTokens.bg1,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
      builder: (_) => DraggableScrollableSheet(
        initialChildSize: 0.85,
        minChildSize: 0.4,
        maxChildSize: 0.95,
        expand: false,
        builder: (ctx, scrollCtrl) => _ReleaseDetailSheet(
          release: release,
          scrollController: scrollCtrl,
          onUpdated: () => ref.invalidate(allReleasesAdminProvider),
        ),
      ),
    );
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({required this.release, required this.statusColor, required this.statusLabel, required this.onTap});
  final ReleaseModel release;
  final Color statusColor;
  final String statusLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.bg1,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.border),
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AurixTokens.bg2,
                borderRadius: BorderRadius.circular(8),
                image: release.coverUrl != null
                    ? DecorationImage(image: NetworkImage(release.coverUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: release.coverUrl == null
                  ? const Icon(Icons.album, color: AurixTokens.muted, size: 22)
                  : null,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(release.title, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14)),
                  const SizedBox(height: 2),
                  Text(
                    '${release.artist ?? '—'} · ${_releaseTypeLabel(release.releaseType)} · ${release.genre ?? '—'}',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: statusColor.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                statusLabel,
                style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 8),
            Text(
              DateFormat('dd.MM.yy').format(release.createdAt),
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }

  static String _releaseTypeLabel(String type) => switch (type) {
        'single' => 'Сингл',
        'ep' => 'EP',
        'album' => 'Альбом',
        _ => type,
      };
}

// ---------------------------------------------------------------------------
// Full Release Detail Sheet
// ---------------------------------------------------------------------------
class _ReleaseDetailSheet extends ConsumerStatefulWidget {
  const _ReleaseDetailSheet({required this.release, required this.scrollController, required this.onUpdated});
  final ReleaseModel release;
  final ScrollController scrollController;
  final VoidCallback onUpdated;

  @override
  ConsumerState<_ReleaseDetailSheet> createState() => _ReleaseDetailSheetState();
}

class _ReleaseDetailSheetState extends ConsumerState<_ReleaseDetailSheet> {
  late String _status;
  final _noteCtrl = TextEditingController();
  bool _loading = false;
  bool _loadingTracks = true;
  List<TrackModel> _tracks = [];
  List<AdminNoteModel>? _notes;
  String? _ownerName;
  String? _ownerEmail;

  // Editable metadata
  late TextEditingController _titleCtrl;
  late TextEditingController _artistCtrl;
  late TextEditingController _genreCtrl;
  late TextEditingController _languageCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.release.status;
    _titleCtrl = TextEditingController(text: widget.release.title);
    _artistCtrl = TextEditingController(text: widget.release.artist ?? '');
    _genreCtrl = TextEditingController(text: widget.release.genre ?? '');
    _languageCtrl = TextEditingController(text: widget.release.language ?? '');
    _loadAll();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _genreCtrl.dispose();
    _languageCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadAll() async {
    await Future.wait([_loadTracks(), _loadNotes(), _loadOwner()]);
  }

  Future<void> _loadTracks() async {
    try {
      final tracks = await ref.read(trackRepositoryProvider).getTracksByRelease(widget.release.id);
      if (mounted) setState(() { _tracks = tracks; _loadingTracks = false; });
    } catch (e) {
      if (mounted) setState(() => _loadingTracks = false);
    }
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ref.read(releaseRepositoryProvider).getNotesForRelease(widget.release.id);
      if (mounted) setState(() => _notes = notes);
    } catch (_) {}
  }

  Future<void> _loadOwner() async {
    try {
      final profile = await ref.read(profileRepositoryProvider).getProfile(widget.release.ownerId);
      if (profile != null && mounted) {
        setState(() {
          _ownerName = profile.displayNameOrName;
          _ownerEmail = profile.email;
        });
      }
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(releaseRepositoryProvider).updateRelease(
        widget.release.id,
        status: _status,
        title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
        artist: _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : null,
        genre: _genreCtrl.text.trim().isNotEmpty ? _genreCtrl.text.trim() : null,
        language: _languageCtrl.text.trim().isNotEmpty ? _languageCtrl.text.trim() : null,
      );

      final adminId = ref.read(currentUserProvider)?.id;
      if (_noteCtrl.text.trim().isNotEmpty && adminId != null) {
        await ref.read(releaseRepositoryProvider).addAdminNote(
          releaseId: widget.release.id,
          adminId: adminId,
          note: _noteCtrl.text.trim(),
        );
      }
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'release_status_changed',
          targetType: 'release',
          targetId: widget.release.id,
          details: {'old': widget.release.status, 'new': _status},
        );
      }
      widget.onUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _confirmDelete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Удалить релиз?', style: TextStyle(color: AurixTokens.text)),
        content: Text(
          'Будет удалён релиз «${widget.release.title}», все треки и обложка из хранилища. Это действие необратимо.',
          style: const TextStyle(color: AurixTokens.muted, fontSize: 14),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Отмена'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.redAccent),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      await ref.read(releaseRepositoryProvider).deleteReleaseFully(widget.release.id);

      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'release_deleted',
          targetType: 'release',
          targetId: widget.release.id,
          details: {'title': widget.release.title, 'artist': widget.release.artist},
        );
      }

      widget.onUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Релиз полностью удалён'), backgroundColor: AurixTokens.positive),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _downloadFile(String url, String defaultName) async {
    try {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Скачивание $defaultName...'),
          duration: const Duration(seconds: 1),
        ),
      );

      final response = await http.get(Uri.parse(url));
      if (response.statusCode != 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Ошибка скачивания: ${response.statusCode}'), backgroundColor: Colors.red),
          );
        }
        return;
      }

      final savePath = await FilePicker.platform.saveFile(
        dialogTitle: 'Сохранить $defaultName',
        fileName: defaultName,
      );

      if (savePath == null) return;

      final file = File(savePath);
      await file.writeAsBytes(response.bodyBytes);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$defaultName сохранён'),
            backgroundColor: AurixTokens.positive,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AurixTokens.muted, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 16),

        // --- Quick actions bar ---
        Row(
          children: [
            if (r.status == 'submitted' || r.status == 'in_review') ...[
              Expanded(
                child: _QuickAction(
                  icon: Icons.check_circle_rounded,
                  label: 'Одобрить',
                  color: AurixTokens.positive,
                  onTap: () {
                    setState(() => _status = 'approved');
                    _save();
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _QuickAction(
                  icon: Icons.cancel_rounded,
                  label: 'Отклонить',
                  color: Colors.redAccent,
                  onTap: () {
                    setState(() => _status = 'rejected');
                    _save();
                  },
                ),
              ),
              const SizedBox(width: 8),
            ],
            if (r.status == 'approved')
              Expanded(
                child: _QuickAction(
                  icon: Icons.publish_rounded,
                  label: 'Опубликовать',
                  color: AurixTokens.positive,
                  onTap: () {
                    setState(() => _status = 'live');
                    _save();
                  },
                ),
              ),
          ],
        ),
        if (r.status == 'submitted' || r.status == 'in_review' || r.status == 'approved')
          const SizedBox(height: 16),

        // --- Cover image ---
        _section('ОБЛОЖКА'),
        const SizedBox(height: 8),
        if (r.coverUrl != null)
          Center(
            child: Column(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.network(r.coverUrl!, width: 200, height: 200, fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      width: 200, height: 200,
                      color: AurixTokens.bg2,
                      child: const Icon(Icons.broken_image, color: AurixTokens.muted, size: 40),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                TextButton.icon(
                  onPressed: () {
                    final ext = r.coverUrl!.split('.').last.split('?').first;
                    final artist = _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : (r.artist ?? 'Unknown');
                    final safeName = '${artist} - ${r.title} (cover).$ext'.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
                    _downloadFile(r.coverUrl!, safeName);
                  },
                  icon: const Icon(Icons.download_rounded, size: 16),
                  label: const Text('Скачать обложку'),
                  style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
                ),
              ],
            ),
          )
        else
          Container(
            height: 100,
            decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('Обложка не загружена', style: TextStyle(color: AurixTokens.muted, fontSize: 13))),
          ),
        const SizedBox(height: 20),

        // --- Tracks ---
        _section('ТРЕКИ'),
        const SizedBox(height: 8),
        if (_loadingTracks)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
          )
        else if (_tracks.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(10)),
            child: const Center(child: Text('Нет треков', style: TextStyle(color: AurixTokens.muted, fontSize: 13))),
          )
        else
          ..._tracks.map((t) => _TrackRow(
            track: t,
            onDownload: () {
              final ext = t.audioPath.split('.').last;
              final artist = _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : (widget.release.artist ?? 'Unknown');
              final trackName = t.title ?? _titleCtrl.text.trim();
              final safeName = '${artist} - ${trackName}.$ext'.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
              _downloadFile(t.audioUrl, safeName);
            },
          )),

        const SizedBox(height: 20),

        // --- Owner info ---
        _section('ВЛАДЕЛЕЦ'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(10)),
          child: Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AurixTokens.orange.withValues(alpha: 0.2),
                child: const Icon(Icons.person, color: AurixTokens.orange, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_ownerName ?? 'Загрузка...', style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 14)),
                    if (_ownerEmail != null)
                      Text(_ownerEmail!, style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ],
                ),
              ),
              Text(r.ownerId.substring(0, 8), style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontFamily: 'monospace')),
            ],
          ),
        ),

        const SizedBox(height: 20),

        // --- Editable metadata ---
        _section('МЕТАДАННЫЕ'),
        const SizedBox(height: 8),
        _metaField('Название', _titleCtrl),
        _metaField('Артист', _artistCtrl),
        Row(
          children: [
            Expanded(child: _metaField('Жанр', _genreCtrl)),
            const SizedBox(width: 8),
            Expanded(child: _metaField('Язык', _languageCtrl)),
          ],
        ),
        const SizedBox(height: 8),
        _infoRow('Тип', _releaseTypeLabel(r.releaseType)),
        _infoRow('Дата релиза', r.releaseDate != null ? DateFormat('dd.MM.yyyy').format(r.releaseDate!) : '—'),
        _infoRow('Создан', DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt)),
        _infoRow('Обновлён', DateFormat('dd.MM.yyyy HH:mm').format(r.updatedAt)),

        const SizedBox(height: 20),

        // --- Status control ---
        _section('СТАТУС'),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _status,
          dropdownColor: AurixTokens.bg2,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AurixTokens.bg2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
          ),
          items: ['draft', 'submitted', 'in_review', 'approved', 'rejected', 'live']
              .map((s) => DropdownMenuItem(value: s, child: Text(_statusLabel(s))))
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),

        const SizedBox(height: 16),

        // --- Admin note ---
        _section('ЗАМЕТКА АДМИНИСТРАТОРА'),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Комментарий для истории (необязательно)',
            hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
            filled: true,
            fillColor: AurixTokens.bg2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
          ),
        ),
        const SizedBox(height: 16),
        FilledButton(
          onPressed: _loading ? null : _save,
          style: FilledButton.styleFrom(
            backgroundColor: AurixTokens.orange,
            foregroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: _loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
              : const Text('Сохранить изменения', style: TextStyle(fontWeight: FontWeight.w700)),
        ),

        // --- Notes history ---
        if (_notes != null && _notes!.isNotEmpty) ...[
          const SizedBox(height: 24),
          _section('ИСТОРИЯ ЗАМЕТОК'),
          const SizedBox(height: 8),
          ..._notes!.map((n) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(8)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.note, style: const TextStyle(color: AurixTokens.text, fontSize: 13)),
                const SizedBox(height: 4),
                Text(DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt), style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
              ],
            ),
          )),
        ],

        const SizedBox(height: 24),
        const Divider(color: AurixTokens.border),
        const SizedBox(height: 12),
        _section('ОПАСНАЯ ЗОНА'),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: _loading ? null : _confirmDelete,
          icon: const Icon(Icons.delete_forever_rounded, size: 18),
          label: const Text('Удалить релиз полностью'),
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.redAccent,
            side: const BorderSide(color: Colors.redAccent),
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
        ),
        const SizedBox(height: 4),
        const Text(
          'Удалит релиз, все треки, обложку и заметки из базы данных и хранилища. Это действие необратимо.',
          style: TextStyle(color: AurixTokens.muted, fontSize: 11),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _section(String text) => Text(
    text,
    style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
  );

  Widget _metaField(String label, TextEditingController ctrl) => Padding(
    padding: const EdgeInsets.only(bottom: 8),
    child: TextField(
      controller: ctrl,
      style: const TextStyle(color: AurixTokens.text, fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: const TextStyle(color: AurixTokens.muted, fontSize: 12),
        filled: true,
        fillColor: AurixTokens.bg2,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 12))),
        Expanded(child: Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
      ],
    ),
  );

  static String _releaseTypeLabel(String type) => switch (type) {
        'single' => 'Сингл',
        'ep' => 'EP',
        'album' => 'Альбом',
        _ => type,
      };

  static String _statusLabel(String s) => switch (s) {
        'draft' => 'Черновик',
        'submitted' => 'На модерации',
        'in_review' => 'На проверке',
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        'live' => 'Опубликован',
        _ => s,
      };
}

class _QuickAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  const _QuickAction({required this.icon, required this.label, required this.color, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: color.withValues(alpha: 0.1),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 6),
              Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w700, fontSize: 13)),
            ],
          ),
        ),
      ),
    );
  }
}

class _TrackRow extends StatelessWidget {
  final TrackModel track;
  final VoidCallback onDownload;

  const _TrackRow({required this.track, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    final fileName = track.audioPath.split('/').last;
    final ext = fileName.split('.').last.toUpperCase();

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Center(
              child: Text(
                '${track.trackNumber + 1}',
                style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700, fontSize: 14),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  track.title ?? fileName,
                  style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  '$ext · ${track.version}${track.explicit ? ' · Explicit' : ''}',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDownload,
            icon: const Icon(Icons.download_rounded, color: AurixTokens.orange, size: 20),
            tooltip: 'Скачать трек',
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }
}
