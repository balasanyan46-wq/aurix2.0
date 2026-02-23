import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
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

  static const _statuses = ['all', 'submitted', 'in_review', 'approved', 'rejected', 'draft'];

  Color _statusColor(String status) => switch (status) {
        'submitted' => Colors.amber,
        'in_review' => Colors.blue,
        'approved' => AurixTokens.positive,
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
                        label: Text(s == 'all' ? 'Все' : s.toUpperCase()),
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
        initialChildSize: 0.7,
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
  const _ReleaseCard({required this.release, required this.statusColor, required this.onTap});
  final ReleaseModel release;
  final Color statusColor;
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
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AurixTokens.bg2,
                borderRadius: BorderRadius.circular(6),
                image: release.coverUrl != null
                    ? DecorationImage(image: NetworkImage(release.coverUrl!), fit: BoxFit.cover)
                    : null,
              ),
              child: release.coverUrl == null
                  ? const Icon(Icons.album, color: AurixTokens.muted, size: 20)
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
                    '${release.artist ?? '—'} • ${release.releaseType}',
                    style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
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
                release.status.toUpperCase(),
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
}

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
  List<AdminNoteModel>? _notes;

  @override
  void initState() {
    super.initState();
    _status = widget.release.status;
    _loadNotes();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    super.dispose();
  }

  Future<void> _loadNotes() async {
    try {
      final notes = await ref.read(releaseRepositoryProvider).getNotesForRelease(widget.release.id);
      if (mounted) setState(() => _notes = notes);
    } catch (_) {}
  }

  Future<void> _save() async {
    setState(() => _loading = true);
    try {
      await ref.read(releaseRepositoryProvider).updateRelease(widget.release.id, status: _status);
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    }
    if (mounted) setState(() => _loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(24),
      children: [
        Center(
          child: Container(
            width: 40, height: 4,
            decoration: BoxDecoration(color: AurixTokens.muted, borderRadius: BorderRadius.circular(2)),
          ),
        ),
        const SizedBox(height: 20),
        if (r.coverUrl != null)
          Center(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.network(r.coverUrl!, width: 160, height: 160, fit: BoxFit.cover),
            ),
          ),
        const SizedBox(height: 16),
        Text(r.title, style: const TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w700)),
        const SizedBox(height: 4),
        Text(r.artist ?? '—', style: const TextStyle(color: AurixTokens.muted, fontSize: 14)),
        const SizedBox(height: 16),
        _infoRow('Тип', r.releaseType),
        _infoRow('Жанр', r.genre ?? '—'),
        _infoRow('Язык', r.language ?? '—'),
        _infoRow('Дата релиза', r.releaseDate != null ? DateFormat('dd.MM.yyyy').format(r.releaseDate!) : '—'),
        _infoRow('Создан', DateFormat('dd.MM.yyyy HH:mm').format(r.createdAt)),
        const SizedBox(height: 20),
        const Text('СТАТУС', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: _status, // ignore: deprecated_member_use
          dropdownColor: AurixTokens.bg2,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          decoration: InputDecoration(
            filled: true,
            fillColor: AurixTokens.bg2,
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
          ),
          items: ['draft', 'submitted', 'in_review', 'approved', 'rejected']
              .map((s) => DropdownMenuItem(value: s, child: Text(s)))
              .toList(),
          onChanged: (v) => setState(() => _status = v ?? _status),
        ),
        const SizedBox(height: 16),
        const Text('ЗАМЕТКА', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
        const SizedBox(height: 8),
        TextField(
          controller: _noteCtrl,
          style: const TextStyle(color: AurixTokens.text, fontSize: 14),
          maxLines: 3,
          decoration: InputDecoration(
            hintText: 'Комментарий (необязательно)',
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
              : const Text('Сохранить', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
        if (_notes != null && _notes!.isNotEmpty) ...[
          const SizedBox(height: 24),
          const Text('ИСТОРИЯ ЗАМЕТОК', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1)),
          const SizedBox(height: 8),
          ..._notes!.map((n) => Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AurixTokens.bg2,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(n.note, style: const TextStyle(color: AurixTokens.text, fontSize: 13)),
                const SizedBox(height: 4),
                Text(
                  DateFormat('dd.MM.yyyy HH:mm').format(n.createdAt),
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                ),
              ],
            ),
          )),
        ],
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
          ),
          Expanded(child: Text(value, style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
        ],
      ),
    );
  }
}
