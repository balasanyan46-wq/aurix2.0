import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/track_model.dart';
import 'package:aurix_flutter/data/models/admin_note_model.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/releases_provider.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class AdminReleasesTab extends ConsumerStatefulWidget {
  const AdminReleasesTab({super.key});

  @override
  ConsumerState<AdminReleasesTab> createState() => _AdminReleasesTabState();
}

class _AdminReleasesTabState extends ConsumerState<AdminReleasesTab> {
  String _search = '';
  final Set<String> _selectedReleaseIds = <String>{};
  bool _bulkLoading = false;

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
        'submitted' => AurixTokens.warning,
        'in_review' => Colors.blue,
        'approved' || 'live' => AurixTokens.positive,
        'rejected' => AurixTokens.danger,
        'draft' => AurixTokens.muted,
        _ => AurixTokens.muted,
      };

  @override
  Widget build(BuildContext context) {
    final releasesAsync = ref.watch(allReleasesAdminProvider);
    final realtime = ref.watch(adminReleasesRealtimeProvider).valueOrNull;
    final statusFilter = ref.watch(adminReleasesFilterProvider);
    final effectiveReleasesAsync = (realtime != null && realtime.isNotEmpty)
        ? AsyncValue.data(realtime)
        : releasesAsync;

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
                    final isSelected = statusFilter == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_statusLabel(s)),
                        selected: isSelected,
                        onSelected: (_) => ref.read(adminReleasesFilterProvider.notifier).state = s,
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
              if (_selectedReleaseIds.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    Text(
                      'Выбрано: ${_selectedReleaseIds.length}',
                      style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700),
                    ),
                    OutlinedButton(
                      onPressed: _bulkLoading ? null : () => _bulkSetStatus('approved'),
                      child: const Text('Одобрить'),
                    ),
                    OutlinedButton(
                      onPressed: _bulkLoading ? null : () => _bulkSetStatus('rejected'),
                      child: const Text('Отклонить'),
                    ),
                    OutlinedButton(
                      onPressed: _bulkLoading ? null : () => _bulkSetStatus('in_review'),
                      child: const Text('На проверку'),
                    ),
                    TextButton(
                      onPressed: _bulkLoading ? null : () => setState(_selectedReleaseIds.clear),
                      child: const Text('Сброс'),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
        Expanded(
          child: effectiveReleasesAsync.when(
            data: (releases) {
              var filtered = releases.where((r) {
                if (statusFilter != 'all' && r.status != statusFilter) return false;
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
                    selected: _selectedReleaseIds.contains(r.id),
                    onToggleSelected: (v) {
                      setState(() {
                        if (v) {
                          _selectedReleaseIds.add(r.id);
                        } else {
                          _selectedReleaseIds.remove(r.id);
                        }
                      });
                    },
                    statusColor: _statusColor(r.status),
                    statusLabel: _statusLabel(r.status),
                    onTap: () => _openDetail(context, r),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted), textAlign: TextAlign.center),
                  const SizedBox(height: 10),
                  TextButton.icon(
                    onPressed: () => ref.invalidate(allReleasesAdminProvider),
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Повторить'),
                    style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _openDetail(BuildContext context, ReleaseModel release) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => Dialog.fullscreen(
        backgroundColor: AurixTokens.bg0,
        child: _ReleaseDetailSheet(
          release: release,
          scrollController: ScrollController(),
          onUpdated: () => ref.invalidate(allReleasesAdminProvider),
        ),
      ),
    );
  }

  Future<void> _bulkSetStatus(String status) async {
    final reason = await _askBulkReason('Массовая смена статуса');
    if (reason == null) return;
    setState(() => _bulkLoading = true);
    try {
      final count = await ref.read(releaseRepositoryProvider).bulkUpdateStatuses(
            _selectedReleaseIds.toList(),
            status,
            reason: reason,
          );
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'releases_bulk_status_changed',
          targetType: 'release',
          details: {'count': count, 'status': status, 'reason': reason},
        );
      }
      ref.invalidate(allReleasesAdminProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Обновлено релизов: $count')),
        );
      }
      setState(_selectedReleaseIds.clear);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
      }
    } finally {
      if (mounted) setState(() => _bulkLoading = false);
    }
  }

  Future<String?> _askBulkReason(String title) async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text(title, style: const TextStyle(color: AurixTokens.text)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          style: const TextStyle(color: AurixTokens.text),
          decoration: const InputDecoration(
            hintText: 'Причина действия',
            hintStyle: TextStyle(color: AurixTokens.muted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Применить')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (ok != true || text.isEmpty) return null;
    return text;
  }
}

class _ReleaseCard extends StatelessWidget {
  const _ReleaseCard({
    required this.release,
    required this.selected,
    required this.onToggleSelected,
    required this.statusColor,
    required this.statusLabel,
    required this.onTap,
  });
  final ReleaseModel release;
  final bool selected;
  final ValueChanged<bool> onToggleSelected;
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
            Checkbox(
              value: selected,
              onChanged: (v) => onToggleSelected(v == true),
            ),
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: AurixTokens.bg2,
                borderRadius: BorderRadius.circular(8),
                image: release.coverUrl != null
                    ? DecorationImage(image: NetworkImage(ApiClient.fixUrl(release.coverUrl)), fit: BoxFit.cover)
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
  ProfileModel? _ownerProfile;

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
        setState(() => _ownerProfile = profile);
      }
    } catch (_) {}
  }

  Future<void> _openOwnerAdminSheet() async {
    final owner = _ownerProfile;
    if (owner == null) return;
    await showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: AurixTokens.bg1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 48),
        child: _OwnerAdminSheet(
          profile: owner,
          onUpdated: () async {
            await _loadOwner();
            if (mounted) widget.onUpdated();
          },
        ),
      ),
    );
  }

  Future<void> _contactOwnerQuick() async {
    final owner = _ownerProfile;
    if (owner == null) return;

    if (owner.email.isNotEmpty) {
      final uri = Uri(
        scheme: 'mailto',
        path: owner.email,
        queryParameters: {
          'subject': 'AURIX: релиз "${widget.release.title}"',
          'body': 'Здравствуйте!\n\nПишем вам по релизу "${widget.release.title}".',
        },
      );
      final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }

    final phone = owner.phone;
    if (phone != null && phone.trim().isNotEmpty) {
      final telUri = Uri(scheme: 'tel', path: phone.trim());
      final ok = await launchUrl(telUri, mode: LaunchMode.externalApplication);
      if (ok) return;
    }

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('У артиста нет доступных контактов для связи')),
    );
  }

  Future<void> _save() async {
    String? statusReason;
    if (_status != widget.release.status) {
      statusReason = await _askStatusReason();
      if (statusReason == null) return;
    }
    setState(() => _loading = true);
    try {
      // Read all providers BEFORE any async work that might dispose widget
      final releaseRepo = ref.read(releaseRepositoryProvider);
      final adminId = ref.read(currentUserProvider)?.id;
      final logRepo = ref.read(adminLogRepositoryProvider);

      await releaseRepo.updateRelease(
        widget.release.id,
        status: _status,
        title: _titleCtrl.text.trim().isNotEmpty ? _titleCtrl.text.trim() : null,
        artist: _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : null,
        genre: _genreCtrl.text.trim().isNotEmpty ? _genreCtrl.text.trim() : null,
        language: _languageCtrl.text.trim().isNotEmpty ? _languageCtrl.text.trim() : null,
      );

      if (_noteCtrl.text.trim().isNotEmpty && adminId != null) {
        await releaseRepo.addAdminNote(
          releaseId: widget.release.id,
          adminId: adminId,
          note: _noteCtrl.text.trim(),
        );
      }
      if (adminId != null) {
        await logRepo.log(
          adminId: adminId,
          action: 'release_status_changed',
          targetType: 'release',
          targetId: widget.release.id,
          details: {'old': widget.release.status, 'new': _status, 'reason': statusReason ?? ''},
        );
      }
      widget.onUpdated();
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<String?> _askStatusReason() async {
    final ctrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: const Text('Причина смены статуса', style: TextStyle(color: AurixTokens.text)),
        content: TextField(
          controller: ctrl,
          maxLines: 2,
          style: const TextStyle(color: AurixTokens.text),
          decoration: const InputDecoration(
            hintText: 'Укажи причину',
            hintStyle: TextStyle(color: AurixTokens.muted),
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Сохранить')),
        ],
      ),
    );
    final text = ctrl.text.trim();
    if (ok != true || text.isEmpty) return null;
    return text;
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
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.danger),
            child: const Text('Удалить', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final releaseRepo = ref.read(releaseRepositoryProvider);
      final adminId = ref.read(currentUserProvider)?.id;
      final logRepo = ref.read(adminLogRepositoryProvider);

      await releaseRepo.deleteReleaseFully(widget.release.id);

      if (adminId != null) {
        await logRepo.log(
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
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _downloadFile(String url, String defaultName) async {
    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Не удалось открыть $defaultName'), backgroundColor: AurixTokens.danger),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.release;
    return Scaffold(
      backgroundColor: AurixTokens.bg0,
      appBar: AppBar(
        backgroundColor: AurixTokens.bg1,
        surfaceTintColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close, color: AurixTokens.text),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          r.title,
          style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 16),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          if (!_loading)
            TextButton(
              onPressed: _save,
              child: const Text('Сохранить', style: TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700)),
            )
          else
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AurixTokens.orange)),
            ),
        ],
      ),
      body: ListView(
      controller: widget.scrollController,
      padding: const EdgeInsets.all(20),
      children: [

        // --- Quick actions bar ---
        Row(
          children: [
            if (r.status == 'submitted' || r.status == 'in_review') ...[
              Expanded(
                child: _QuickAction(
                  icon: Icons.check_circle_rounded,
                  label: 'Одобрить',
                  color: AurixTokens.positive,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AurixTokens.bg1,
                        title: const Text('Одобрить релиз?', style: TextStyle(color: AurixTokens.text)),
                        content: Text('Вы уверены что хотите одобрить «${widget.release.title}»?', style: const TextStyle(color: AurixTokens.muted)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: AurixTokens.positive),
                            child: const Text('Одобрить', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
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
                  color: AurixTokens.danger,
                  onTap: () async {
                    final confirm = await showDialog<bool>(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        backgroundColor: AurixTokens.bg1,
                        title: const Text('Отклонить релиз?', style: TextStyle(color: AurixTokens.text)),
                        content: Text('Вы уверены что хотите отклонить «${widget.release.title}»?', style: const TextStyle(color: AurixTokens.muted)),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
                          FilledButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            style: FilledButton.styleFrom(backgroundColor: AurixTokens.danger),
                            child: const Text('Отклонить', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                    if (confirm != true) return;
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
                  child: Image.network(ApiClient.fixUrl(r.coverUrl), width: 200, height: 200, fit: BoxFit.cover,
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
                    _downloadFile(ApiClient.fixUrl(r.coverUrl), safeName);
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
        _section('ТРЕКИ (${_tracks.length})'),
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
        _section('АРТИСТ / ВЛАДЕЛЕЦ'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(10)),
          child: _ownerProfile == null
              ? const Text('Загрузка...', style: TextStyle(color: AurixTokens.muted, fontSize: 13))
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 22,
                          backgroundColor: AurixTokens.orange.withValues(alpha: 0.2),
                          child: Text(
                            _ownerProfile!.displayNameOrName.isNotEmpty
                                ? _ownerProfile!.displayNameOrName[0].toUpperCase()
                                : '?',
                            style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700, fontSize: 16),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(_ownerProfile!.displayNameOrName, style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 15)),
                              if (_ownerProfile!.artistName != null && _ownerProfile!.artistName != _ownerProfile!.displayNameOrName)
                                Text('Псевдоним: ${_ownerProfile!.artistName}', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                            ],
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(
                            color: AurixTokens.orange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            _ownerProfile!.plan.toUpperCase(),
                            style: TextStyle(color: AurixTokens.orange, fontSize: 10, fontWeight: FontWeight.w700),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    _ownerRow(Icons.email_outlined, _ownerProfile!.email.isNotEmpty ? _ownerProfile!.email : '—'),
                    if (_ownerProfile!.phone != null && _ownerProfile!.phone!.isNotEmpty)
                      _ownerRow(Icons.phone_outlined, _ownerProfile!.phone!),
                    if (_ownerProfile!.city != null && _ownerProfile!.city!.isNotEmpty)
                      _ownerRow(Icons.location_on_outlined, _ownerProfile!.city!),
                    if (_ownerProfile!.bio != null && _ownerProfile!.bio!.isNotEmpty)
                      _ownerRow(Icons.info_outline, _ownerProfile!.bio!),
                    _ownerRow(Icons.badge_outlined, 'Роль: ${_ownerProfile!.role} · Статус: ${_ownerProfile!.accountStatus}'),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        OutlinedButton.icon(
                          onPressed: _openOwnerAdminSheet,
                          icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                          label: const Text('Открыть артиста'),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AurixTokens.orange,
                            side: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5)),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _contactOwnerQuick,
                          icon: const Icon(Icons.send_rounded, size: 16),
                          label: const Text('Написать артисту'),
                          style: TextButton.styleFrom(foregroundColor: AurixTokens.text),
                        ),
                      ],
                    ),
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
        _infoRow('UPC / EAN', r.upc ?? '—'),
        _infoRow('Лейбл', r.label ?? '—'),
        _infoRow('Explicit', r.explicit ? 'Да' : 'Нет'),
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
            foregroundColor: AurixTokens.danger,
            side: const BorderSide(color: AurixTokens.danger),
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
    ),
    );
  }

  Widget _ownerRow(IconData icon, String text) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AurixTokens.muted),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(color: AurixTokens.text, fontSize: 12))),
      ],
    ),
  );

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

class _OwnerAdminSheet extends ConsumerStatefulWidget {
  const _OwnerAdminSheet({
    required this.profile,
    required this.onUpdated,
  });

  final ProfileModel profile;
  final Future<void> Function() onUpdated;

  @override
  ConsumerState<_OwnerAdminSheet> createState() => _OwnerAdminSheetState();
}

class _OwnerAdminSheetState extends ConsumerState<_OwnerAdminSheet> {
  late String _status;
  final _messageCtrl = TextEditingController();
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _status = widget.profile.accountStatus;
  }

  @override
  void dispose() {
    _messageCtrl.dispose();
    super.dispose();
  }

  Future<void> _saveStatus() async {
    setState(() => _loading = true);
    try {
      await ref.read(profileRepositoryProvider).updateAccountStatus(
            widget.profile.userId,
            _status,
          );
      final adminId = ref.read(currentUserProvider)?.id;
      if (adminId != null) {
        await ref.read(adminLogRepositoryProvider).log(
          adminId: adminId,
          action: 'user_status_changed_from_release',
          targetType: 'profile',
          targetId: widget.profile.userId,
          details: {
            'old': widget.profile.accountStatus,
            'new': _status,
          },
        );
      }
      await widget.onUpdated();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Статус артиста обновлён'),
          backgroundColor: AurixTokens.positive,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Ошибка обновления статуса: $e')),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _sendEmail() async {
    if (widget.profile.email.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Email у артиста не указан')),
      );
      return;
    }
    final body = _messageCtrl.text.trim().isEmpty
        ? 'Здравствуйте!\n\nПишем вам по вашему релизу в AURIX.'
        : _messageCtrl.text.trim();
    final uri = Uri(
      scheme: 'mailto',
      path: widget.profile.email,
      queryParameters: {
        'subject': 'AURIX: сообщение от администратора',
        'body': body,
      },
    );
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть почтовый клиент')),
      );
    }
  }

  Future<void> _callArtist() async {
    final phone = widget.profile.phone;
    if (phone == null || phone.trim().isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Телефон у артиста не указан')),
      );
      return;
    }
    final uri = Uri(scheme: 'tel', path: phone.trim());
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Не удалось открыть звонок')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.profile;
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 480),
      child: SingleChildScrollView(
        padding: EdgeInsets.only(
          left: 20,
          right: 20,
          top: 20,
          bottom: MediaQuery.viewInsetsOf(context).bottom + 20,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                CircleAvatar(
                  radius: 20,
                  backgroundColor: AurixTokens.orange.withValues(alpha: 0.18),
                  child: Text(
                    p.displayNameOrName.isNotEmpty ? p.displayNameOrName[0].toUpperCase() : '?',
                    style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    p.displayNameOrName,
                    style: const TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w700, fontSize: 16),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: AurixTokens.muted),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text('Email: ${p.email.isEmpty ? '—' : p.email}', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
            Text('Телефон: ${(p.phone == null || p.phone!.isEmpty) ? '—' : p.phone!}', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
            const SizedBox(height: 14),
            const Text('Статус аккаунта', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
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
              items: const [
                DropdownMenuItem(value: 'active', child: Text('Активен')),
                DropdownMenuItem(value: 'suspended', child: Text('Заблокирован')),
              ],
              onChanged: _loading ? null : (v) => setState(() => _status = v ?? _status),
            ),
            const SizedBox(height: 10),
            FilledButton.icon(
              onPressed: _loading ? null : _saveStatus,
              icon: const Icon(Icons.save_rounded, size: 16),
              label: Text(_loading ? 'Сохранение...' : 'Сохранить статус'),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.orange,
                foregroundColor: Colors.black,
              ),
            ),
            const SizedBox(height: 14),
            const Text('Сообщение артисту', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            TextField(
              controller: _messageCtrl,
              maxLines: 3,
              style: const TextStyle(color: AurixTokens.text, fontSize: 13),
              decoration: InputDecoration(
                hintText: 'Текст письма (необязательно)',
                hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                filled: true,
                fillColor: AurixTokens.bg2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
              ),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  onPressed: _sendEmail,
                  icon: const Icon(Icons.email_outlined, size: 16),
                  label: const Text('Написать на email'),
                  style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.orange),
                ),
                OutlinedButton.icon(
                  onPressed: _callArtist,
                  icon: const Icon(Icons.phone_outlined, size: 16),
                  label: const Text('Позвонить'),
                  style: OutlinedButton.styleFrom(foregroundColor: AurixTokens.text),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
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
                  '$ext · ${track.version}${track.explicit ? ' · Explicit' : ''}'
                  '${track.isrc != null && track.isrc!.isNotEmpty ? ' · ISRC: ${track.isrc}' : ''}',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                ),
                if (track.isrc == null || track.isrc!.isEmpty)
                  Text('⚠ ISRC не указан', style: TextStyle(color: Colors.orange[300], fontSize: 10)),
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
