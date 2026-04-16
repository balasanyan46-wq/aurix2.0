import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:html' if (dart.library.io) 'dart:io' as html;
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
import 'package:aurix_flutter/presentation/screens/releases/widgets/track_player.dart';

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
        'submitted' || 'review' => 'На модерации',
        'in_review' => 'На проверке',
        'approved' => 'Одобрен',
        'rejected' => 'Отклонён',
        'live' => 'Опубликован',
        _ => s,
      };

  Color _statusColor(String status) => switch (status) {
        'submitted' || 'review' => AurixTokens.warning,
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
                // Normalize 'review' → 'submitted' for filtering
                final normalizedStatus = r.status == 'review' ? 'submitted' : r.status;
                if (statusFilter != 'all' && normalizedStatus != statusFilter) return false;
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
  late TextEditingController _upcCtrl;

  @override
  void initState() {
    super.initState();
    _status = widget.release.status;
    _titleCtrl = TextEditingController(text: widget.release.title);
    _artistCtrl = TextEditingController(text: widget.release.artist ?? '');
    _genreCtrl = TextEditingController(text: widget.release.genre ?? '');
    _languageCtrl = TextEditingController(text: widget.release.language ?? '');
    _upcCtrl = TextEditingController(text: widget.release.upc ?? '');
    _loadAll();
  }

  @override
  void dispose() {
    _noteCtrl.dispose();
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    _genreCtrl.dispose();
    _languageCtrl.dispose();
    _upcCtrl.dispose();
    super.dispose();
  }

  Map<String, dynamic>? _extData;

  Future<Map<String, dynamic>> _loadExtendedData() async {
    if (_extData != null) return _extData!;
    try {
      final res = await ApiClient.get('/releases/${widget.release.id}');
      final data = res.data is Map ? Map<String, dynamic>.from(res.data as Map) : <String, dynamic>{};
      final rel = data['release'] is Map ? Map<String, dynamic>.from(data['release'] as Map) : <String, dynamic>{};
      _extData = rel;
      return rel;
    } catch (_) {
      return {};
    }
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
      final releaseRepo = ref.read(releaseRepositoryProvider);
      final adminId = ref.read(currentUserProvider)?.id;
      final logRepo = ref.read(adminLogRepositoryProvider);
      final oldStatus = widget.release.status;

      // Use dedicated moderation endpoints (they send notifications + emails)
      if (_status != oldStatus) {
        if (_status == 'approved') {
          await ApiClient.post('/releases/${widget.release.id}/approve');
        } else if (_status == 'live') {
          await ApiClient.post('/releases/${widget.release.id}/live');
        } else if (_status == 'rejected') {
          await ApiClient.post('/releases/${widget.release.id}/reject', data: {
            'reason': statusReason ?? '',
          });
        } else {
          // Fallback for other status changes
          await releaseRepo.updateRelease(widget.release.id, {'status': _status});
        }
      }

      // Update other fields if changed
      final updates = <String, dynamic>{};
      if (_titleCtrl.text.trim().isNotEmpty && _titleCtrl.text.trim() != widget.release.title) {
        updates['title'] = _titleCtrl.text.trim();
      }
      if (_artistCtrl.text.trim().isNotEmpty) updates['artist'] = _artistCtrl.text.trim();
      if (_genreCtrl.text.trim().isNotEmpty) updates['genre'] = _genreCtrl.text.trim();
      if (_languageCtrl.text.trim().isNotEmpty) updates['language'] = _languageCtrl.text.trim();
      if (_upcCtrl.text.trim().isNotEmpty) updates['upc'] = _upcCtrl.text.trim();
      if (updates.isNotEmpty) {
        await releaseRepo.updateRelease(widget.release.id, updates);
      }

      if (_noteCtrl.text.trim().isNotEmpty && adminId != null) {
        await releaseRepo.addAdminNote(
          releaseId: widget.release.id,
          adminId: adminId,
          note: _noteCtrl.text.trim(),
        );
      }
      if (adminId != null && _status != oldStatus) {
        await logRepo.log(
          adminId: adminId,
          action: 'release_status_changed',
          targetType: 'release',
          targetId: widget.release.id,
          details: {'old': oldStatus, 'new': _status, 'reason': statusReason ?? ''},
        );
      }
      widget.onUpdated();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(_status != oldStatus ? 'Статус изменён на: $_status' : 'Сохранено'),
          backgroundColor: AurixTokens.positive,
          duration: const Duration(seconds: 2),
        ));
        Navigator.of(context).pop();
      }
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

  static const _revisionTemplates = [
    'Обложка не соответствует требованиям (минимум 3000x3000 px, без текста поверх)',
    'Название содержит ошибки или не соответствует стандартам площадок',
    'Имя артиста указано неверно — проверьте написание',
    'Отсутствует текст песни — необходим для Apple Music и Spotify',
    'ISRC код указан некорректно — проверьте формат',
    'Аудио файл низкого качества — загрузите WAV 16/24 bit, 44.1 kHz',
    'Жанр указан неверно — уточните основной и поджанр',
    'Обнаружен чужой контент / сэмпл без лицензии',
    'Дата релиза слишком близкая — минимум 7 дней для дистрибуции',
    'Копирайт не заполнен или заполнен некорректно',
    'Explicit метка не указана, хотя в треке есть ненормативная лексика',
    'Нужно указать всех авторов музыки и текста',
  ];

  Future<void> _sendToRevision() async {
    final reasonCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(builder: (ctx, setDlgState) {
          return AlertDialog(
            backgroundColor: AurixTokens.bg1,
            title: const Text('Отправить на доработку', style: TextStyle(color: AurixTokens.text)),
            content: SizedBox(
              width: 480,
              child: Column(mainAxisSize: MainAxisSize.min, children: [
                Text('Артист получит уведомление и email с причиной.', style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
                const SizedBox(height: 12),
                // Template chips
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 180),
                  child: SingleChildScrollView(child: Wrap(spacing: 6, runSpacing: 6, children: _revisionTemplates.map((t) {
                    return InkWell(
                      onTap: () {
                        final cur = reasonCtrl.text.trim();
                        if (cur.isNotEmpty && !cur.endsWith('\n')) {
                          reasonCtrl.text = '$cur\n$t';
                        } else {
                          reasonCtrl.text = cur.isEmpty ? t : '$cur$t';
                        }
                        reasonCtrl.selection = TextSelection.collapsed(offset: reasonCtrl.text.length);
                        setDlgState(() {});
                      },
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AurixTokens.bg2,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AurixTokens.stroke(0.15)),
                        ),
                        child: Text(t, style: TextStyle(color: AurixTokens.textSecondary, fontSize: 11)),
                      ),
                    );
                  }).toList())),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: reasonCtrl,
                  maxLines: 4,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 14),
                  decoration: const InputDecoration(hintText: 'Или напишите свою причину...', hintStyle: TextStyle(color: AurixTokens.muted)),
                ),
              ]),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена')),
              FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: FilledButton.styleFrom(backgroundColor: AurixTokens.warning),
                child: const Text('Отправить', style: TextStyle(color: Colors.white)),
              ),
            ],
          );
        });
      },
    );
    if (ok != true || reasonCtrl.text.trim().isEmpty) return;

    setState(() => _loading = true);
    try {
      await ApiClient.post('/releases/${widget.release.id}/revision', data: {'reason': reasonCtrl.text.trim()});
      widget.onUpdated();
      if (mounted) {
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Отправлено на доработку'), backgroundColor: AurixTokens.warning),
        );
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger));
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

  /// Извлекает S3-ключ из полного storage-URL. Возвращает null если не удаётся.
  String? _extractKey(String url) {
    final m = RegExp(r'/storage/([a-zA-Z0-9\-_./]+)').firstMatch(url);
    return m?.group(1);
  }

  /// Админское скачивание через API с принудительным Content-Disposition.
  /// Запрашивает файл как bytes → создаёт blob → триггерит скачивание.
  Future<void> _downloadFile(String url, String filename) async {
    final key = _extractKey(ApiClient.fixUrl(url));
    if (key == null) {
      // Fallback: старый путь для внешних URL
      _triggerDirectDownload(ApiClient.fixUrl(url), filename);
      return;
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Скачивание: $filename...'), duration: const Duration(seconds: 2)),
      );
    }

    try {
      final res = await ApiClient.dio.get(
        '/upload/admin/download',
        queryParameters: {'key': key, 'filename': filename},
        options: Options(
          responseType: ResponseType.bytes,
          receiveTimeout: const Duration(minutes: 3),
        ),
      );
      final bytes = res.data as List<int>;
      final mime = res.headers.value('content-type') ?? 'application/octet-stream';
      if (kIsWeb) {
        _triggerBlobDownload(bytes, filename, mime);
      } else {
        _triggerDirectDownload(ApiClient.fixUrl(url), filename);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка скачивания: $e'), backgroundColor: AurixTokens.danger),
        );
      }
    }
  }

  void _triggerBlobDownload(List<int> bytes, String filename, String mime) {
    try {
      // ignore: avoid_dynamic_calls
      final blob = html.Blob([bytes], mime);
      // ignore: avoid_dynamic_calls
      final url = html.Url.createObjectUrlFromBlob(blob);
      // ignore: avoid_dynamic_calls
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename);
      // ignore: avoid_dynamic_calls
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
      // ignore: avoid_dynamic_calls
      html.Url.revokeObjectUrl(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger),
        );
      }
    }
  }

  void _triggerDirectDownload(String url, String filename) {
    try {
      // ignore: avoid_dynamic_calls
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', filename)
        ..setAttribute('target', '_blank');
      // ignore: avoid_dynamic_calls
      html.document.body?.append(anchor);
      anchor.click();
      anchor.remove();
    } catch (_) {
      launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
    }
  }

  /// Копирование в буфер + snackbar.
  void _copy(String text, [String? label]) {
    if (text.trim().isEmpty) return;
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Скопировано${label != null ? ': $label' : ''}'),
          duration: const Duration(seconds: 1),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  /// Открывает обложку на весь экран с кнопкой скачивания.
  void _openCoverFullscreen(String url, String filename) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withValues(alpha: 0.92),
      builder: (ctx) => _CoverFullscreenViewer(
        url: ApiClient.fixUrl(url),
        onDownload: () => _downloadFile(url, filename),
      ),
    );
  }

  /// Копирует все ключевые метаданные релиза в виде текста для вставки в агрегатор.
  void _copyAllMetadata(Map<String, dynamic> ext) {
    final r = widget.release;
    final lines = <String>[
      '=== РЕЛИЗ ===',
      'Название: ${_titleCtrl.text.trim()}',
      'Артист: ${_artistCtrl.text.trim()}',
      'Тип: ${_releaseTypeLabel(r.releaseType)}',
      if (r.releaseDate != null) 'Дата релиза: ${DateFormat('dd.MM.yyyy').format(r.releaseDate!)}',
      if (_genreCtrl.text.trim().isNotEmpty) 'Жанр: ${_genreCtrl.text.trim()}',
      if (_languageCtrl.text.trim().isNotEmpty) 'Язык: ${_languageCtrl.text.trim()}',
      'Explicit: ${r.explicit ? 'Да' : 'Нет'}',
      if (_upcCtrl.text.trim().isNotEmpty) 'UPC: ${_upcCtrl.text.trim()}',
      if (r.label != null && r.label!.isNotEmpty) 'Лейбл: ${r.label}',
      if (r.copyrightYear != null) 'Копирайт: © ${r.copyrightYear}',
      if (ext['copyright_holders'] != null && '${ext['copyright_holders']}'.isNotEmpty)
        'Правообладатели: ${ext['copyright_holders']}',
      '',
      '=== ТРЕКИ (${_tracks.length}) ===',
      ..._tracks.asMap().entries.map((e) {
        final t = e.value;
        return '${e.key + 1}. ${t.title ?? '—'}'
            '${t.isrc != null && t.isrc!.isNotEmpty ? ' · ISRC: ${t.isrc}' : ' · ISRC не указан'}'
            '${t.explicit ? ' · Explicit' : ''}';
      }),
    ];

    final links = ext['platform_links'] is Map ? Map<String, dynamic>.from(ext['platform_links'] as Map) : <String, dynamic>{};
    if (links.isNotEmpty) {
      lines.add('');
      lines.add('=== ССЫЛКИ ===');
      links.forEach((k, v) => lines.add('$k: $v'));
    }

    final owner = _ownerProfile;
    if (owner != null) {
      lines.add('');
      lines.add('=== АРТИСТ ===');
      lines.add('Имя: ${owner.displayNameOrName}');
      if (owner.email.isNotEmpty) lines.add('Email: ${owner.email}');
      if (owner.phone != null && owner.phone!.isNotEmpty) lines.add('Телефон: ${owner.phone}');
    }

    final text = lines.join('\n');
    Clipboard.setData(ClipboardData(text: text));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Все метаданные скопированы — можно вставить в агрегатор'),
          backgroundColor: AurixTokens.positive,
          behavior: SnackBarBehavior.floating,
        ),
      );
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
                  icon: Icons.edit_note_rounded,
                  label: 'На доработку',
                  color: AurixTokens.warning,
                  onTap: () => _sendToRevision(),
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

        // --- Hero: cover + title/artist + status chips ---
        _buildHero(r),
        const SizedBox(height: 20),

        // --- Tracks with inline player ---
        _sectionHeader(
          'ТРЕКИ (${_tracks.length})',
          trailing: _tracks.isNotEmpty ? TextButton.icon(
            onPressed: () {
              for (final t in _tracks) {
                final ext = _extFromUrl(t.audioUrl);
                final artist = _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : (widget.release.artist ?? 'Unknown');
                final trackName = t.title ?? 'track${t.trackNumber + 1}';
                final safeName = '$artist - $trackName.$ext'.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
                _downloadFile(t.audioUrl, safeName);
              }
            },
            icon: const Icon(Icons.download_for_offline_rounded, size: 16),
            label: Text('Скачать все (${_tracks.length})'),
            style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
          ) : null,
        ),
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
              final ext = _extFromUrl(t.audioUrl);
              final artist = _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : (widget.release.artist ?? 'Unknown');
              final trackName = t.title ?? _titleCtrl.text.trim();
              final safeName = '$artist - $trackName.$ext'.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
              _downloadFile(t.audioUrl, safeName);
            },
            onCopyIsrc: (t.isrc != null && t.isrc!.isNotEmpty) ? () => _copy(t.isrc!, 'ISRC') : null,
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
                    _ownerRow(
                      Icons.email_outlined,
                      _ownerProfile!.email.isNotEmpty ? _ownerProfile!.email : '—',
                      onCopy: _ownerProfile!.email.isNotEmpty ? () => _copy(_ownerProfile!.email, 'email') : null,
                    ),
                    if (_ownerProfile!.phone != null && _ownerProfile!.phone!.isNotEmpty)
                      _ownerRow(
                        Icons.phone_outlined,
                        _ownerProfile!.phone!,
                        onCopy: () => _copy(_ownerProfile!.phone!, 'телефон'),
                      ),
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
        _metaField('UPC / EAN', _upcCtrl),
        const SizedBox(height: 8),
        _infoRow('Тип', _releaseTypeLabel(r.releaseType)),
        _infoRow('Дата релиза', r.releaseDate != null ? DateFormat('dd.MM.yyyy').format(r.releaseDate!) : '—'),
        _infoRow('Лейбл', r.label ?? '—'),
        _infoRow('Explicit', r.explicit ? 'Да' : 'Нет'),

        const SizedBox(height: 20),

        // --- Extended data (from release JSON) — wizard steps, links, services, lyrics ---
        FutureBuilder<Map<String, dynamic>>(
          future: _loadExtendedData(),
          builder: (ctx, snap) {
            if (!snap.hasData) return const SizedBox();
            final ext = snap.data!;
            final desc = ext['description'] as String? ?? '';
            final lyrics = ext['lyrics'] as String? ?? '';
            final copyrightH = ext['copyright_holders'] as String? ?? '';
            final authorMusic = ext['author_music'] as String? ?? '';
            final authorLyrics = ext['author_lyrics'] as String? ?? '';
            final subtitle = ext['subtitle'] as String? ?? '';
            final tiktokClipField = ext['tiktok_clip'];
            final tiktokClipStr = tiktokClipField is String ? tiktokClipField : '';
            final tiktokClipBool = tiktokClipField is bool ? tiktokClipField : null;
            final yandexSoon = ext['yandex_soon'] == true;
            final noArtistPage = ext['no_artist_page'] == true;
            final syncLyrics = ext['sync_lyrics'] == true;
            final termsAccepted = ext['terms_accepted'] == true;
            final tiktokDate = ext['tiktok_date']?.toString() ?? '';
            final links = ext['platform_links'] is Map ? Map<String, dynamic>.from(ext['platform_links'] as Map) : <String, dynamic>{};
            final svcs = ext['services'] is List ? ext['services'] as List : [];
            final totalPrice = ext['total_price'] is num ? (ext['total_price'] as num).toDouble() : double.tryParse(ext['total_price']?.toString() ?? '') ?? 0;
            final bpm = ext['bpm'];
            final mood = ext['mood'] as String? ?? '';
            final audience = ext['target_audience'] as String? ?? '';
            final refs = ext['reference_tracks'] as String? ?? '';
            final revReason = ext['revision_reason'] as String? ?? '';
            final needsRev = ext['needs_revision'] == true;

            // Компактная выжимка того, что артист заполнил по шагам
            final hasAuthors = authorMusic.isNotEmpty || authorLyrics.isNotEmpty || copyrightH.isNotEmpty;
            final hasStep4 = hasAuthors || subtitle.isNotEmpty || tiktokClipStr.isNotEmpty || tiktokClipBool != null || lyrics.isNotEmpty;
            final hasStep5 = links.isNotEmpty || noArtistPage || termsAccepted;

            return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              if (needsRev && revReason.isNotEmpty) ...[
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AurixTokens.warning.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: AurixTokens.warning.withValues(alpha: 0.2)),
                  ),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Icon(Icons.warning_amber_rounded, size: 18, color: AurixTokens.warning),
                    const SizedBox(width: 10),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('Отправлен на доработку', style: TextStyle(color: AurixTokens.warning, fontSize: 12, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Text(revReason, style: const TextStyle(color: AurixTokens.text, fontSize: 13)),
                    ])),
                  ]),
                ),
                const SizedBox(height: 16),
              ],

              // ── ШАГИ АРТИСТА — всё что он заполнил в wizard ─────────
              _sectionHeader('ШАГИ АРТИСТА', icon: Icons.checklist_rounded),
              const SizedBox(height: 8),
              _WizardStepsCard(
                steps: [
                  _WizardStepData(
                    title: 'Шаг 1 · Тип релиза',
                    filled: true,
                    rows: [_WizardRow('Тип', _releaseTypeLabel(r.releaseType))],
                  ),
                  _WizardStepData(
                    title: 'Шаг 2 · Основная информация',
                    filled: r.title.isNotEmpty || r.artist != null,
                    rows: [
                      _WizardRow('Название', r.title, onCopy: () => _copy(r.title, 'название')),
                      _WizardRow('Артист', r.artist ?? '—', onCopy: (r.artist != null && r.artist!.isNotEmpty) ? () => _copy(r.artist!, 'артист') : null),
                      _WizardRow('Дата релиза', r.releaseDate != null ? DateFormat('dd.MM.yyyy').format(r.releaseDate!) : '—'),
                      if (tiktokDate.isNotEmpty) _WizardRow('Дата TikTok', tiktokDate),
                      _WizardRow('Жанр', r.genre ?? '—'),
                      _WizardRow('Язык', r.language ?? '—'),
                      _WizardRow('Яндекс "Скоро новый релиз"', yandexSoon ? '✓ Включено' : '— Выключено'),
                    ],
                  ),
                  _WizardStepData(
                    title: 'Шаг 3 · Аудио',
                    filled: _tracks.isNotEmpty,
                    rows: [
                      _WizardRow('Треков загружено', '${_tracks.length}'),
                      if (_tracks.any((t) => t.isrc == null || t.isrc!.isEmpty))
                        _WizardRow('⚠ Треков без ISRC', '${_tracks.where((t) => t.isrc == null || t.isrc!.isEmpty).length}'),
                    ],
                  ),
                  _WizardStepData(
                    title: 'Шаг 4 · Важная информация',
                    filled: hasStep4,
                    rows: [
                      if (authorMusic.isNotEmpty) _WizardRow('Автор музыки', authorMusic, onCopy: () => _copy(authorMusic, 'автор музыки')),
                      if (authorLyrics.isNotEmpty) _WizardRow('Автор слов', authorLyrics, onCopy: () => _copy(authorLyrics, 'автор слов')),
                      if (copyrightH.isNotEmpty) _WizardRow('Правообладатели', copyrightH, onCopy: () => _copy(copyrightH, 'правообладатели')),
                      if (subtitle.isNotEmpty) _WizardRow('Подзаголовок', subtitle),
                      if (tiktokClipStr.isNotEmpty) _WizardRow('Отрезок в TikTok', tiktokClipStr),
                      if (tiktokClipBool != null) _WizardRow('TikTok превью', tiktokClipBool ? '✓ Да' : '— Нет'),
                      if (r.copyrightYear != null) _WizardRow('Копирайт', '© ${r.copyrightYear}'),
                      _WizardRow('Explicit', r.explicit ? '✓ Да' : '— Нет'),
                      _WizardRow('Синхронизация текста', syncLyrics ? '✓ Да' : '— Нет'),
                    ],
                  ),
                  _WizardStepData(
                    title: 'Шаг 5 · Ссылки и оферта',
                    filled: hasStep5,
                    rows: [
                      ...links.entries.map((e) => _WizardRow(
                        _platformLabel(e.key),
                        e.value.toString(),
                        onCopy: () => _copy(e.value.toString(), _platformLabel(e.key)),
                        onOpen: () => launchUrl(Uri.parse(e.value.toString()), mode: LaunchMode.externalApplication),
                      )),
                      _WizardRow('Нет карточки артиста', noArtistPage ? '✓ Да' : '— Нет'),
                      _WizardRow('Принял оферту', termsAccepted ? '✓ Да' : '⚠ Нет', valueColor: termsAccepted ? AurixTokens.positive : AurixTokens.warning),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),

              if (desc.isNotEmpty) ...[
                _sectionHeader('ОПИСАНИЕ', onCopy: () => _copy(desc, 'описание')),
                const SizedBox(height: 6),
                Text(desc, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 13, height: 1.5)),
                const SizedBox(height: 16),
              ],

              if (bpm != null) _infoRow('BPM', '$bpm'),
              if (mood.isNotEmpty) _infoRow('Настроение', mood),
              if (audience.isNotEmpty) _infoRow('Целевая аудитория', audience),
              if (refs.isNotEmpty) _infoRow('Референсы', refs),

              if (lyrics.isNotEmpty) ...[
                const SizedBox(height: 16),
                _sectionHeader('ТЕКСТ ПЕСНИ', onCopy: () => _copy(lyrics, 'текст песни')),
                const SizedBox(height: 6),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: AurixTokens.bg2, borderRadius: BorderRadius.circular(10)),
                  child: Text(lyrics,
                      style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12, height: 1.6)),
                ),
                const SizedBox(height: 16),
              ],

              if (svcs.isNotEmpty) ...[
                _sectionHeader('ВЫБРАННЫЕ УСЛУГИ', icon: Icons.shopping_bag_rounded),
                const SizedBox(height: 6),
                ...svcs.map((s) {
                  final svc = s is Map ? s : {};
                  final name = svc['name'] ?? svc['id'] ?? '—';
                  final price = svc['price'] is num ? (svc['price'] as num).toDouble() : double.tryParse(svc['price']?.toString() ?? '') ?? 0;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Row(children: [
                      const Icon(Icons.check_circle_rounded, size: 16, color: AurixTokens.positive),
                      const SizedBox(width: 8),
                      Expanded(child: Text('$name', style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
                      Text(price > 0 ? '${price.toStringAsFixed(0)} \u20bd' : 'Бесплатно', style: const TextStyle(color: AurixTokens.accent, fontSize: 13, fontWeight: FontWeight.w600)),
                    ]),
                  );
                }),
                if (totalPrice > 0) ...[
                  const Divider(color: AurixTokens.border),
                  Row(children: [
                    const Text('Итого:', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w700)),
                    const Spacer(),
                    Text('${totalPrice.toStringAsFixed(0)} \u20bd', style: const TextStyle(color: AurixTokens.accent, fontSize: 16, fontWeight: FontWeight.w800)),
                  ]),
                ],
                const SizedBox(height: 16),
              ],

              // --- Кнопка: скопировать всё ---
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _copyAllMetadata(ext),
                  icon: const Icon(Icons.copy_all_rounded, size: 18),
                  label: const Text('Скопировать всё для агрегатора'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AurixTokens.orange,
                    side: BorderSide(color: AurixTokens.orange.withValues(alpha: 0.5)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                ),
              ),
              const SizedBox(height: 16),
            ]);
          },
        ),

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

  Widget _ownerRow(IconData icon, String text, {VoidCallback? onCopy}) => Padding(
    padding: const EdgeInsets.only(bottom: 4),
    child: Row(
      children: [
        Icon(icon, size: 14, color: AurixTokens.muted),
        const SizedBox(width: 8),
        Expanded(child: SelectableText(text, style: const TextStyle(color: AurixTokens.text, fontSize: 12))),
        if (onCopy != null)
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 12, color: AurixTokens.muted)),
          ),
      ],
    ),
  );

  Widget _section(String text) => Text(
    text,
    style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
  );

  /// Заголовок секции с опциональной иконкой, копированием и trailing-виджетом.
  Widget _sectionHeader(String text, {IconData? icon, VoidCallback? onCopy, Widget? trailing}) {
    return Row(
      children: [
        if (icon != null) ...[
          Icon(icon, size: 14, color: AurixTokens.muted),
          const SizedBox(width: 6),
        ],
        Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const Spacer(),
        if (onCopy != null)
          InkWell(
            onTap: onCopy,
            borderRadius: BorderRadius.circular(6),
            child: const Padding(
              padding: EdgeInsets.all(4),
              child: Icon(Icons.copy_rounded, size: 14, color: AurixTokens.muted),
            ),
          ),
        if (trailing != null) trailing,
      ],
    );
  }

  String _extFromUrl(String url) {
    final m = RegExp(r'\.([a-zA-Z0-9]{2,5})(\?|$)').firstMatch(url);
    return m?.group(1)?.toLowerCase() ?? 'mp3';
  }

  String _platformLabel(String key) {
    switch (key) {
      case 'spotify': return 'Spotify';
      case 'apple_music': case 'apple': return 'Apple Music';
      case 'youtube': return 'YouTube';
      case 'vk': return 'VK';
      case 'yandex': return 'Яндекс Музыка';
      default: return key;
    }
  }

  /// Hero-секция: большая кликабельная обложка + название/артист/chips.
  Widget _buildHero(ReleaseModel r) {
    final hasCover = r.coverUrl != null && r.coverUrl!.isNotEmpty;
    final coverUrl = r.coverUrl;
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Clickable cover
          InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: hasCover
                ? () {
                    final ext = _extFromUrl(coverUrl!);
                    final artist = _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : (r.artist ?? 'Unknown');
                    final safeName = '$artist - ${r.title} (cover).$ext'.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
                    _openCoverFullscreen(coverUrl, safeName);
                  }
                : null,
            child: Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: hasCover
                      ? Image.network(
                          ApiClient.fixUrl(coverUrl),
                          width: 160, height: 160, fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => _coverStub(),
                        )
                      : _coverStub(),
                ),
                if (hasCover)
                  Positioned(
                    right: 6, bottom: 6,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.55),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.zoom_in_rounded, size: 12, color: Colors.white),
                        SizedBox(width: 4),
                        Text('На весь экран', style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w600)),
                      ]),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          // Title + artist + chips
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  Expanded(
                    child: Text(
                      r.title,
                      style: const TextStyle(color: AurixTokens.text, fontSize: 22, fontWeight: FontWeight.w800, height: 1.2),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  InkWell(
                    onTap: () => _copy(r.title, 'название'),
                    borderRadius: BorderRadius.circular(6),
                    child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 14, color: AurixTokens.muted)),
                  ),
                ]),
                const SizedBox(height: 4),
                if (r.artist != null && r.artist!.isNotEmpty)
                  Row(children: [
                    Expanded(
                      child: Text(
                        r.artist!,
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 15, fontWeight: FontWeight.w500),
                        maxLines: 1, overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    InkWell(
                      onTap: () => _copy(r.artist!, 'артист'),
                      borderRadius: BorderRadius.circular(6),
                      child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 14, color: AurixTokens.muted)),
                    ),
                  ]),
                const SizedBox(height: 10),
                Wrap(spacing: 6, runSpacing: 6, children: [
                  _heroChip(_releaseTypeLabel(r.releaseType), AurixTokens.orange),
                  _heroChip(_statusLabel(r.status), _statusColor(r.status)),
                  if (r.explicit) _heroChip('Explicit', AurixTokens.warning),
                  if (r.genre != null && r.genre!.isNotEmpty) _heroChip(r.genre!, AurixTokens.muted),
                  if (r.language != null && r.language!.isNotEmpty) _heroChip(r.language!, AurixTokens.muted),
                ]),
                const SizedBox(height: 12),
                if (hasCover)
                  TextButton.icon(
                    onPressed: () {
                      final ext = _extFromUrl(coverUrl!);
                      final artist = _artistCtrl.text.trim().isNotEmpty ? _artistCtrl.text.trim() : (r.artist ?? 'Unknown');
                      final safeName = '$artist - ${r.title} (cover).$ext'.replaceAll(RegExp(r'[/\\:*?"<>|]'), '_');
                      _downloadFile(coverUrl, safeName);
                    },
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Скачать обложку'),
                    style: TextButton.styleFrom(
                      foregroundColor: AurixTokens.orange,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: const Size(0, 32),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _coverStub() => Container(
    width: 160, height: 160,
    color: AurixTokens.bg2,
    child: const Icon(Icons.album_rounded, color: AurixTokens.muted, size: 42),
  );

  Widget _heroChip(String label, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.14),
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: color.withValues(alpha: 0.3)),
    ),
    child: Text(label, style: TextStyle(color: color, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.3)),
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

  static Color _statusColor(String s) => switch (s) {
        'submitted' || 'review' => AurixTokens.warning,
        'in_review' => Colors.blue,
        'approved' || 'live' => AurixTokens.positive,
        'rejected' => AurixTokens.danger,
        _ => AurixTokens.muted,
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
  final VoidCallback? onCopyIsrc;

  const _TrackRow({required this.track, required this.onDownload, this.onCopyIsrc});

  @override
  Widget build(BuildContext context) {
    final fileName = track.audioPath.isNotEmpty ? track.audioPath.split('/').last : track.audioUrl.split('/').last.split('?').first;
    final ext = fileName.split('.').last.toUpperCase();
    final audioUrl = ApiClient.fixUrl(track.audioUrl);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        children: [
          Row(
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
                    style: const TextStyle(color: AurixTokens.orange, fontWeight: FontWeight.w700, fontSize: 14),
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
                    Row(children: [
                      Text(
                        '$ext · ${track.version}${track.explicit ? ' · Explicit' : ''}',
                        style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                      ),
                    ]),
                    const SizedBox(height: 2),
                    if (track.isrc != null && track.isrc!.isNotEmpty)
                      Row(children: [
                        const Text('ISRC:', style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
                        const SizedBox(width: 4),
                        SelectableText(track.isrc!, style: TextStyle(color: AurixTokens.accent.withValues(alpha: 0.85), fontSize: 11, fontWeight: FontWeight.w600)),
                        if (onCopyIsrc != null) ...[
                          const SizedBox(width: 4),
                          InkWell(
                            onTap: onCopyIsrc,
                            borderRadius: BorderRadius.circular(4),
                            child: const Padding(padding: EdgeInsets.all(2), child: Icon(Icons.copy_rounded, size: 12, color: AurixTokens.muted)),
                          ),
                        ],
                      ])
                    else
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
          // Inline player
          if (audioUrl.isNotEmpty) ...[
            const SizedBox(height: 10),
            TrackPlayer(key: ValueKey('admin-player-${track.id}'), url: audioUrl),
          ],
        ],
      ),
    );
  }
}

// ── Fullscreen cover viewer ─────────────────────────────────────────────
class _CoverFullscreenViewer extends StatelessWidget {
  final String url;
  final VoidCallback onDownload;

  const _CoverFullscreenViewer({required this.url, required this.onDownload});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        children: [
          Center(
            child: InteractiveViewer(
              minScale: 0.5, maxScale: 5,
              child: Image.network(
                url,
                fit: BoxFit.contain,
                errorBuilder: (_, __, ___) => Container(
                  width: 200, height: 200, color: AurixTokens.bg2,
                  child: const Icon(Icons.broken_image, color: AurixTokens.muted, size: 48),
                ),
              ),
            ),
          ),
          Positioned(
            top: 12, right: 12,
            child: Row(children: [
              _fsButton(icon: Icons.download_rounded, label: 'Скачать', onTap: onDownload),
              const SizedBox(width: 8),
              _fsButton(icon: Icons.close_rounded, label: 'Закрыть', onTap: () => Navigator.of(context).pop()),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _fsButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return Material(
      color: Colors.black.withValues(alpha: 0.6),
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, size: 16, color: Colors.white),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}

// ── Wizard steps card ──────────────────────────────────────────────────
class _WizardRow {
  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onCopy;
  final VoidCallback? onOpen;
  _WizardRow(this.label, this.value, {this.valueColor, this.onCopy, this.onOpen});
}

class _WizardStepData {
  final String title;
  final bool filled;
  final List<_WizardRow> rows;
  _WizardStepData({required this.title, required this.filled, required this.rows});
}

class _WizardStepsCard extends StatelessWidget {
  final List<_WizardStepData> steps;
  const _WizardStepsCard({required this.steps});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        children: [
          for (int i = 0; i < steps.length; i++) ...[
            if (i > 0) const Divider(height: 1, color: AurixTokens.border),
            _WizardStepTile(step: steps[i]),
          ],
        ],
      ),
    );
  }
}

class _WizardStepTile extends StatefulWidget {
  final _WizardStepData step;
  const _WizardStepTile({required this.step});

  @override
  State<_WizardStepTile> createState() => _WizardStepTileState();
}

class _WizardStepTileState extends State<_WizardStepTile> {
  bool _open = true;

  @override
  Widget build(BuildContext context) {
    final step = widget.step;
    final color = step.filled ? AurixTokens.positive : AurixTokens.muted;
    return Column(
      children: [
        InkWell(
          onTap: () => setState(() => _open = !_open),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Container(
                width: 20, height: 20,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: color.withValues(alpha: 0.15),
                ),
                child: Icon(step.filled ? Icons.check_rounded : Icons.circle_outlined, size: 14, color: color),
              ),
              const SizedBox(width: 10),
              Expanded(child: Text(step.title, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700))),
              Icon(_open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded, size: 18, color: AurixTokens.muted),
            ]),
          ),
        ),
        if (_open && step.rows.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(40, 0, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: step.rows.map((row) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(width: 150, child: Text(row.label, style: const TextStyle(color: AurixTokens.muted, fontSize: 12))),
                      Expanded(
                        child: SelectableText(
                          row.value,
                          style: TextStyle(color: row.valueColor ?? AurixTokens.text, fontSize: 13, fontWeight: row.valueColor != null ? FontWeight.w700 : FontWeight.w500),
                        ),
                      ),
                      if (row.onOpen != null)
                        InkWell(
                          onTap: row.onOpen,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.open_in_new_rounded, size: 14, color: AurixTokens.muted)),
                        ),
                      if (row.onCopy != null)
                        InkWell(
                          onTap: row.onCopy,
                          borderRadius: BorderRadius.circular(6),
                          child: const Padding(padding: EdgeInsets.all(4), child: Icon(Icons.copy_rounded, size: 14, color: AurixTokens.muted)),
                        ),
                    ],
                  ),
                );
              }).toList(),
            ),
          ),
      ],
    );
  }
}
