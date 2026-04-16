import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/config/responsive.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/services/csv_report_parser.dart';
import 'package:aurix_flutter/data/providers/reports_provider.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

class AdminFinanceTab extends ConsumerStatefulWidget {
  const AdminFinanceTab({super.key});

  @override
  ConsumerState<AdminFinanceTab> createState() => _AdminFinanceTabState();
}

class _AdminFinanceTabState extends ConsumerState<AdminFinanceTab> {
  ProfileModel? _selectedUser;
  ReleaseModel? _selectedRelease;
  bool _uploading = false;
  bool _pickingFile = false;
  String? _error;
  String? _success;
  String _artistQuery = '';
  String _releaseQuery = '';
  String _reportsQuery = '';

  // Треки выбранного артиста — используются для предпросмотра матча по ISRC.
  // Ключ — userId, значение — список треков (release_id, release_title, title, isrc).
  Map<String, List<Map<String, dynamic>>> _artistTracksCache = {};
  bool _loadingArtistTracks = false;

  @override
  void dispose() {
    _artistTracksCache.clear();
    super.dispose();
  }

  Future<void> _loadArtistTracks(String userId) async {
    if (_artistTracksCache.containsKey(userId)) return;
    setState(() => _loadingArtistTracks = true);
    try {
      final tracks = await ref.read(reportRepositoryProvider).getTracksByUser(userId);
      if (mounted) setState(() => _artistTracksCache[userId] = tracks);
    } catch (_) {
      if (mounted) setState(() => _artistTracksCache[userId] = []);
    } finally {
      if (mounted) setState(() => _loadingArtistTracks = false);
    }
  }

  List<Map<String, dynamic>> _tracksForSelectedUser() {
    final uid = _selectedUser?.userId;
    if (uid == null) return [];
    return _artistTracksCache[uid] ?? [];
  }

  List<Map<String, dynamic>> _tracksForSelectedRelease() {
    final rid = _selectedRelease?.id;
    if (rid == null) return [];
    return _tracksForSelectedUser().where((t) {
      final trid = t['release_id']?.toString() ?? '';
      return trid == rid;
    }).toList()
      ..sort((a, b) => (a['track_number'] ?? 0).toString().compareTo((b['track_number'] ?? 0).toString()));
  }

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final releasesAsync = ref.watch(allReleasesAdminProvider);
    final reportsAsync = ref.watch(adminReportsProvider);
    final rowsAsync = ref.watch(allReportRowsProvider);

    return SingleChildScrollView(
      padding: EdgeInsets.all(horizontalPadding(context)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ФИНАНСЫ',
            style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 8),
          Text(
            'Загружайте отчёты дистрибьютора для каждого релиза отдельно',
            style: TextStyle(color: AurixTokens.muted, fontSize: 13),
          ),
          const SizedBox(height: 24),

          rowsAsync.when(
            data: (rows) => _buildSummary(rows),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2))),
            error: (e, _) => Text('$e', style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
          ),

          const SizedBox(height: 28),

          const Text('ИМПОРТ ОТЧЁТА', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),

          profilesAsync.when(
            data: (profiles) {
              final releases = releasesAsync.valueOrNull ?? [];
              return _buildImportCard(profiles, releases);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
            error: (e, _) => Text('$e', style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
          ),

          const SizedBox(height: 28),

          const Text('ЗАГРУЖЕННЫЕ ОТЧЁТЫ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: TextField(
                onChanged: (v) => setState(() => _reportsQuery = v.trim().toLowerCase()),
                style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                decoration: InputDecoration(
                  hintText: 'Поиск по артисту, релизу, файлу...',
                  hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                  border: InputBorder.none,
                  icon: Icon(Icons.search_rounded, color: AurixTokens.muted.withValues(alpha: 0.8)),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          reportsAsync.when(
            data: (list) {
              if (list.isEmpty) return _emptyCard('Нет отчётов');
              final profiles = profilesAsync.valueOrNull ?? [];
              final releases = releasesAsync.valueOrNull ?? [];
              return _buildReportsTable(list, profiles, releases, _reportsQuery);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
            error: (e, _) => Text('$e', style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
          ),

          const SizedBox(height: 28),

          rowsAsync.when(
            data: (rows) => _buildBreakdowns(rows),
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
            error: (e, _) => Text('Ошибка разбивки: $e', style: const TextStyle(color: AurixTokens.danger, fontSize: 12)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(List<ReportRowModel> rows) {
    final totalRevenue = rows.fold<double>(0, (s, r) => s + r.revenue);
    final totalStreams = rows.fold<int>(0, (s, r) => s + r.streams);
    final now = DateTime.now();
    final thisMonthRevenue = rows
        .where((r) => r.reportDate != null && r.reportDate!.year == now.year && r.reportDate!.month == now.month)
        .fold<double>(0, (s, r) => s + r.revenue);

    final tracks = <String>{};
    for (final r in rows) {
      if (r.trackTitle != null && r.trackTitle!.isNotEmpty) tracks.add(r.trackTitle!);
    }
    final avgPerTrack = tracks.isNotEmpty ? totalRevenue / tracks.length : 0.0;
    final currencies = rows.map((r) => r.currency).toSet();
    final cs = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      final cards = [
        _SummaryCard(label: 'ОБЩИЙ ДОХОД', value: '$cs${_fmt(totalRevenue)}', icon: Icons.attach_money_rounded),
        _SummaryCard(label: 'ЗА МЕСЯЦ', value: '$cs${_fmt(thisMonthRevenue)}', icon: Icons.calendar_month_rounded, accentColor: AurixTokens.positive),
        _SummaryCard(label: 'ПРОСЛУШИВАНИЯ', value: _fmtInt(totalStreams), icon: Icons.headphones_rounded),
        _SummaryCard(label: 'СРЕДНЕЕ НА ТРЕК', value: '$cs${_fmt(avgPerTrack)}', icon: Icons.music_note_rounded, accentColor: AurixTokens.orange),
      ];

      if (isWide) {
        return Row(children: cards.map((c) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 12), child: c))).toList());
      }
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: cards.map((c) => SizedBox(width: (constraints.maxWidth - 12) / 2, child: c)).toList(),
      );
    });
  }

  Widget _buildImportCard(List<ProfileModel> profiles, List<ReleaseModel> allReleases) {
    final artistFiltered = profiles
        .where((p) => p.role != 'admin')
        .where((p) {
          if (_artistQuery.isEmpty) return true;
          final hay = '${p.displayNameOrName} ${p.email}'.toLowerCase();
          return hay.contains(_artistQuery);
        })
        .toList();

    final userReleases = _selectedUser != null
        ? allReleases.where((r) => r.ownerId == _selectedUser!.userId).toList()
        : <ReleaseModel>[];
    final releaseFiltered = userReleases.where((r) {
      if (_releaseQuery.isEmpty) return true;
      final hay = '${r.title} ${r.artist ?? ''} ${r.releaseType}'.toLowerCase();
      return hay.contains(_releaseQuery);
    }).toList();

    if (_selectedRelease != null && !userReleases.any((r) => r.id == _selectedRelease!.id)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _selectedRelease = null);
      });
    }

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.upload_file_rounded, size: 20, color: AurixTokens.orange),
                const SizedBox(width: 8),
                const Text('Загрузка отчёта по релизу', style: TextStyle(color: AurixTokens.text, fontSize: 14, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 16),

            // Step 1: Pick user
            _buildStepLabel('1', 'Выберите артиста'),
            const SizedBox(height: 8),
            _card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _artistQuery = v.trim().toLowerCase()),
                  style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Поиск артиста (имя/email)',
                    hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                    border: InputBorder.none,
                    icon: Icon(Icons.search_rounded, color: AurixTokens.muted.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDropdown<ProfileModel>(
              value: _selectedUser,
              hint: 'Артист',
              items: artistFiltered,
              labelBuilder: (p) => '${p.displayNameOrName} (${p.email})',
              onChanged: (p) {
                setState(() {
                  _selectedUser = p;
                  _selectedRelease = null;
                  _error = null;
                  _success = null;
                });
                if (p != null) _loadArtistTracks(p.userId);
              },
            ),

            const SizedBox(height: 16),

            // Step 2: Pick release (optional — CSV может покрывать несколько релизов)
            _buildStepLabel('2', 'Релиз (необязательно — один CSV может охватывать все релизы артиста)'),
            const SizedBox(height: 8),
            _card(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                child: TextField(
                  onChanged: (v) => setState(() => _releaseQuery = v.trim().toLowerCase()),
                  enabled: _selectedUser != null,
                  style: const TextStyle(color: AurixTokens.text, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Поиск релиза (название/артист/тип)',
                    hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
                    border: InputBorder.none,
                    icon: Icon(Icons.search_rounded, color: AurixTokens.muted.withValues(alpha: 0.8)),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 8),
            _buildDropdown<ReleaseModel>(
              value: _selectedRelease,
              hint: _selectedUser == null ? 'Сначала выберите артиста' : (releaseFiltered.isEmpty ? 'Нет релизов' : 'Все релизы (не фильтровать)'),
              items: releaseFiltered,
              labelBuilder: (r) => '${r.title}${r.artist != null ? " — ${r.artist}" : ""} (${r.releaseType})',
              onChanged: _selectedUser == null ? null : (r) => setState(() {
                _selectedRelease = r;
                _error = null;
                _success = null;
              }),
            ),

            // ── Треки релиза (после выбора релиза) ─────────────────
            if (_selectedRelease != null) ...[
              const SizedBox(height: 14),
              _buildReleaseTracksBlock(),
            ] else if (_selectedUser != null && _artistTracksCache.containsKey(_selectedUser!.userId)) ...[
              const SizedBox(height: 14),
              _buildAllArtistTracksBlock(),
            ],

            const SizedBox(height: 16),

            // Step 3: Upload CSV
            _buildStepLabel('3', 'Загрузите отчёт (.xlsx, .csv, .tsv)'),
            const SizedBox(height: 4),
            Text(
              'После выбора файла откроется превью с разбивкой по релизам и совпадениями по ISRC. Импорт происходит только после подтверждения.',
              style: TextStyle(color: AurixTokens.muted, fontSize: 11, height: 1.4),
            ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (_uploading || _selectedUser == null) ? null : _importCsv,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(_uploading ? 'Парсинг...' : 'Выбрать файл и открыть превью'),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.orange,
                foregroundColor: Colors.black,
                disabledBackgroundColor: AurixTokens.orange.withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
            ),

            if (_error != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurixTokens.danger.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_error!, style: TextStyle(color: AurixTokens.danger, fontSize: 12)),
              ),
            ],
            if (_success != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AurixTokens.positive.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_success!, style: TextStyle(color: AurixTokens.positive, fontSize: 12)),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStepLabel(String step, String text) {
    return Row(
      children: [
        Container(
          width: 22, height: 22,
          decoration: BoxDecoration(
            color: AurixTokens.orange.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.center,
          child: Text(step, style: TextStyle(color: AurixTokens.orange, fontSize: 11, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required String Function(T) labelBuilder,
    required void Function(T?)? onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AurixTokens.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AurixTokens.muted, fontSize: 13)),
          isExpanded: true,
          dropdownColor: AurixTokens.bg1,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: AurixTokens.muted),
          style: TextStyle(color: AurixTokens.text, fontSize: 13),
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(labelBuilder(item), overflow: TextOverflow.ellipsis),
          )).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  Widget _buildReportsTable(
    List<ReportModel> reports,
    List<ProfileModel> profiles,
    List<ReleaseModel> releases,
    String query,
  ) {
    String userName(String? uid) {
      if (uid == null) return '—';
      final p = profiles.where((p) => p.userId == uid);
      return p.isNotEmpty ? p.first.displayNameOrName : (uid.length > 8 ? '${uid.substring(0, 8)}...' : uid);
    }
    String releaseName(String? rid) {
      if (rid == null) return '—';
      final r = releases.where((r) => r.id == rid);
      return r.isNotEmpty ? r.first.title : (rid.length > 8 ? '${rid.substring(0, 8)}...' : rid);
    }

    final filtered = reports.where((r) {
      if (query.isEmpty) return true;
      final hay = '${userName(r.userId)} ${releaseName(r.releaseId)} ${r.fileName ?? ''} ${r.status}'.toLowerCase();
      return hay.contains(query);
    }).toList();

    if (filtered.isEmpty) {
      return _emptyCard('По запросу ничего не найдено');
    }

    return _card(
      child: Column(
        children: filtered.map((r) {
          final period = '${DateFormat('MMM yyyy', 'ru').format(r.periodStart)} — ${DateFormat('MMM yyyy', 'ru').format(r.periodEnd)}';
          return ListTile(
            dense: true,
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    releaseName(r.releaseId),
                    style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AurixTokens.orange.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    r.status,
                    style: TextStyle(color: AurixTokens.orange, fontSize: 10, fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            subtitle: Text(
              '${userName(r.userId)} • $period • ${r.fileName ?? "—"}',
              style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
            ),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              if (r.userId != null && r.userId!.isNotEmpty)
                IconButton(
                  icon: const Icon(Icons.visibility_rounded, size: 18, color: AurixTokens.orange),
                  tooltip: 'Просмотреть как артист',
                  onPressed: () => _openPreviewAsArtist(r.userId!, userName(r.userId)),
                ),
              IconButton(
                icon: const Icon(Icons.delete_outline_rounded, size: 18, color: AurixTokens.muted),
                tooltip: 'Удалить отчёт',
                onPressed: () => _confirmDelete(r.id, r.fileName),
              ),
            ]),
          );
        }).toList(),
      ),
    );
  }

  void _confirmDelete(String reportId, String? fileName) {
    final reasonCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text('Удалить отчёт?', style: TextStyle(color: AurixTokens.text)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${fileName ?? "Отчёт"} будет удалён вместе со всеми строками.', style: TextStyle(color: AurixTokens.muted)),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              maxLines: 2,
              style: const TextStyle(color: AurixTokens.text),
              decoration: const InputDecoration(
                hintText: 'Причина удаления',
                hintStyle: TextStyle(color: AurixTokens.muted),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: AurixTokens.muted))),
          FilledButton(
            onPressed: () async {
              final reason = reasonCtrl.text.trim();
              if (reason.isEmpty) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Укажи причину удаления')));
                }
                return;
              }
              Navigator.pop(ctx);
              try {
                await ref.read(reportRepositoryProvider).deleteReport(reportId);
                final adminId = ref.read(currentUserProvider)?.id;
                if (adminId != null) {
                  await ref.read(adminLogRepositoryProvider).log(
                    adminId: adminId,
                    action: 'report_deleted',
                    targetType: 'report',
                    targetId: reportId,
                    details: {'file_name': fileName ?? '', 'reason': reason},
                  );
                }
                ref.invalidate(adminReportsProvider);
                ref.invalidate(allReportRowsProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.danger),
            child: const Text('Удалить'),
          ),
        ],
      ),
    );
  }

  Widget _buildBreakdowns(List<ReportRowModel> rows) {
    final byPlatform = <String, double>{};
    for (final r in rows) {
      final p = r.platform ?? 'Unknown';
      byPlatform[p] = (byPlatform[p] ?? 0) + r.revenue;
    }
    final sortedPlatforms = byPlatform.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    final currencies = rows.map((r) => r.currency).toSet();
    final cs = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('ДОХОД ПО ПЛАТФОРМАМ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
        const SizedBox(height: 12),
        if (sortedPlatforms.isEmpty)
          _emptyCard('Нет данных')
        else
          _card(
            child: Column(
              children: sortedPlatforms.take(10).map((e) => ListTile(
                dense: true,
                title: Text(e.key, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500)),
                trailing: Text(
                  '$cs${_fmt(e.value)}',
                  style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures),
                ),
              )).toList(),
            ),
          ),
      ],
    );
  }

  Future<void> _importCsv() async {
    if (_uploading || _pickingFile) return;
    _pickingFile = true;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'tsv', 'txt', 'xlsx', 'xls'],
      withData: true,
    );
    _pickingFile = false;
    if (result == null || result.files.isEmpty) return;
    final file = result.files.single;
    final bytes = file.bytes;
    if (bytes == null || bytes.isEmpty) {
      setState(() => _error = 'Не удалось прочитать файл');
      return;
    }
    final admin = ref.read(currentUserProvider);
    if (admin == null) {
      setState(() => _error = 'Войдите в аккаунт');
      return;
    }
    if (_selectedUser == null) {
      setState(() => _error = 'Выберите артиста');
      return;
    }

    setState(() { _error = null; _success = null; _uploading = true; });

    // 1. Парсим локально
    final parseResult = CsvReportParser.parseWithDetails(bytes);
    if (!parseResult.hasData) {
      setState(() {
        _error = parseResult.error ?? 'Не удалось распарсить CSV';
        _uploading = false;
      });
      return;
    }

    // 2. Убедимся что треки артиста загружены (для превью матча по ISRC)
    await _loadArtistTracks(_selectedUser!.userId);

    final tracks = _tracksForSelectedUser();
    final preview = _PreviewData.build(
      fileName: file.name,
      fileBytes: bytes,
      rows: parseResult.rows,
      headers: parseResult.detectedHeaders,
      artistTracks: tracks,
    );

    setState(() => _uploading = false);

    if (!mounted) return;

    // 3. Показываем превью
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _PreviewDialog(data: preview, artistName: _selectedUser!.displayNameOrName),
    );
    if (confirmed != true) return;

    // 4. Коммитим
    setState(() => _uploading = true);
    try {
      final repo = ref.read(reportRepositoryProvider);
      final periodStart = preview.periodStart ?? DateTime(DateTime.now().year, DateTime.now().month, 1).subtract(const Duration(days: 60));
      final periodEnd = preview.periodEnd ?? DateTime(DateTime.now().year, DateTime.now().month + 1, 0);
      final importHash = _quickImportHash(
        bytes,
        file.name,
        _selectedRelease?.id ?? '',
        _selectedUser?.id ?? '',
      );

      final report = await repo.createReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        fileName: file.name,
        createdBy: admin.id,
        userId: _selectedUser!.userId,
        releaseId: _selectedRelease?.id,
        importHash: importHash,
      );
      await repo.updateReportStatus(report.id, 'parsing');
      await repo.addReportRows(
        report.id,
        preview.rows,
        userId: _selectedUser!.userId,
        releaseId: _selectedRelease?.id,
      );

      // Быстрый массовый матч — один SQL UPDATE
      final matchResult = await repo.matchReportRowsByIsrcBulk(report.id);
      final matched = matchResult['matched'] as int? ?? 0;
      final unmatched = matchResult['unmatched'] as int? ?? 0;

      await repo.updateReportStatus(report.id, 'ready');

      await ref.read(adminLogRepositoryProvider).log(
        adminId: admin.id,
        action: 'report_imported',
        targetType: 'report',
        targetId: report.id,
        details: {
          'rows': preview.rows.length,
          'matched': matched,
          'unmatched': unmatched,
          'user': _selectedUser!.displayNameOrName,
          'release': _selectedRelease?.title ?? 'все релизы',
          'file': file.name,
        },
      );

      ref.invalidate(adminReportsProvider);
      ref.invalidate(allReportRowsProvider);
      ref.invalidate(userReportRowsProvider);

      setState(() {
        _success = 'Импорт завершён: ${preview.rows.length} строк (${matched} сопоставлено с треками, ${unmatched} без привязки) — ${_selectedUser!.displayNameOrName}';
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().length > 180 ? '${e.toString().substring(0, 177)}...' : e.toString();
        _uploading = false;
      });
    }
  }

  // ── Треки релиза: отображение списка с ISRC ──────────────

  Widget _buildReleaseTracksBlock() {
    if (_loadingArtistTracks && _tracksForSelectedUser().isEmpty) {
      return _card(child: const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
      ));
    }
    final tracks = _tracksForSelectedRelease();
    if (tracks.isEmpty) {
      return _card(child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(children: [
          const Icon(Icons.warning_amber_rounded, color: AurixTokens.warning, size: 18),
          const SizedBox(width: 8),
          Expanded(child: Text('В релизе «${_selectedRelease!.title}» нет треков', style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
        ]),
      ));
    }
    final withoutIsrc = tracks.where((t) => (t['isrc'] ?? '').toString().trim().isEmpty).length;

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Icon(Icons.music_note_rounded, size: 14, color: AurixTokens.muted),
            const SizedBox(width: 6),
            Text('ТРЕКИ РЕЛИЗА (${tracks.length})',
                style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const Spacer(),
            if (withoutIsrc > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AurixTokens.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('⚠ без ISRC: $withoutIsrc',
                    style: const TextStyle(color: AurixTokens.warning, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 8),
          ...tracks.map((t) {
            final isrc = (t['isrc'] ?? '').toString().trim();
            final title = (t['title'] ?? '').toString();
            final num = t['track_number']?.toString() ?? '';
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(width: 26, child: Text(num, style: const TextStyle(color: AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w700))),
                Expanded(child: Text(
                  title.isNotEmpty ? title : '—',
                  style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500),
                  overflow: TextOverflow.ellipsis,
                )),
                const SizedBox(width: 8),
                if (isrc.isNotEmpty)
                  SelectableText(isrc, style: const TextStyle(
                    color: AurixTokens.accent, fontSize: 11, fontWeight: FontWeight.w600,
                    fontFeatures: AurixTokens.tabularFigures,
                  ))
                else
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AurixTokens.warning.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text('ISRC не указан',
                        style: TextStyle(color: AurixTokens.warning, fontSize: 10, fontWeight: FontWeight.w600)),
                  ),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _buildAllArtistTracksBlock() {
    if (_loadingArtistTracks) {
      return _card(child: const Padding(
        padding: EdgeInsets.all(16),
        child: Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
      ));
    }
    final tracks = _tracksForSelectedUser();
    if (tracks.isEmpty) {
      return _card(child: const Padding(
        padding: EdgeInsets.all(14),
        child: Text('У артиста пока нет треков', style: TextStyle(color: AurixTokens.muted, fontSize: 12)),
      ));
    }
    final withIsrc = tracks.where((t) => (t['isrc'] ?? '').toString().trim().isNotEmpty).length;
    final withoutIsrc = tracks.length - withIsrc;

    // Группируем треки по релизам
    final byRelease = <String, List<Map<String, dynamic>>>{};
    for (final t in tracks) {
      final key = '${t['release_id']}';
      byRelease.putIfAbsent(key, () => []).add(t);
    }

    return _card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Header with summary
          Row(children: [
            const Icon(Icons.inventory_2_rounded, size: 14, color: AurixTokens.muted),
            const SizedBox(width: 6),
            Text('КАТАЛОГ АРТИСТА (${tracks.length} треков · с ISRC: $withIsrc)',
                style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
            const Spacer(),
            if (withoutIsrc > 0)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AurixTokens.warning.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text('⚠ без ISRC: $withoutIsrc',
                    style: const TextStyle(color: AurixTokens.warning, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
          ]),
          const SizedBox(height: 10),
          // Releases → tracks
          ...byRelease.entries.map((entry) {
            final relTracks = entry.value;
            final releaseTitle = relTracks.first['release_title']?.toString() ?? 'Без названия';
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.album_rounded, size: 12, color: AurixTokens.muted),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(releaseTitle,
                        style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w700),
                        overflow: TextOverflow.ellipsis),
                  ),
                  Text('${relTracks.length} трек.',
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                ]),
                const SizedBox(height: 4),
                ...relTracks.map((t) => _trackLine(t)),
              ]),
            );
          }),
        ]),
      ),
    );
  }

  Widget _trackLine(Map<String, dynamic> t) {
    final isrc = (t['isrc'] ?? '').toString().trim();
    final title = (t['title'] ?? '').toString();
    final num = t['track_number']?.toString() ?? '';
    final trackId = t['id']?.toString();

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        SizedBox(width: 22, child: Text(num, style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700))),
        Expanded(
          child: Text(
            title.isNotEmpty ? title : '—',
            style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        const SizedBox(width: 8),
        if (isrc.isNotEmpty)
          SelectableText(isrc, style: const TextStyle(
            color: AurixTokens.accent, fontSize: 11, fontWeight: FontWeight.w600,
            fontFeatures: AurixTokens.tabularFigures,
          ))
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: AurixTokens.warning.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(4),
            ),
            child: const Text('ISRC не указан',
                style: TextStyle(color: AurixTokens.warning, fontSize: 10, fontWeight: FontWeight.w600)),
          ),
        if (trackId != null) ...[
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _editTrackIsrc(trackId, title, isrc),
            borderRadius: BorderRadius.circular(4),
            child: Padding(
              padding: const EdgeInsets.all(4),
              child: Icon(isrc.isEmpty ? Icons.add_circle_outline_rounded : Icons.edit_rounded,
                  size: 14, color: isrc.isEmpty ? AurixTokens.warning : AurixTokens.muted),
            ),
          ),
        ],
      ]),
    );
  }

  Future<void> _editTrackIsrc(String trackId, String trackTitle, String currentIsrc) async {
    final ctrl = TextEditingController(text: currentIsrc);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text('ISRC для "${trackTitle.isNotEmpty ? trackTitle : trackId}"',
            style: const TextStyle(color: AurixTokens.text, fontSize: 15)),
        content: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Формат: 12 символов, буквы+цифры (например RUAH62413212)',
              style: TextStyle(color: AurixTokens.muted, fontSize: 11)),
          const SizedBox(height: 10),
          TextField(
            controller: ctrl,
            autofocus: true,
            style: const TextStyle(color: AurixTokens.text, fontSize: 14, fontFeatures: AurixTokens.tabularFigures),
            textCapitalization: TextCapitalization.characters,
            decoration: const InputDecoration(
              hintText: 'RUAH62413212',
              hintStyle: TextStyle(color: AurixTokens.muted),
            ),
          ),
        ]),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Отмена', style: TextStyle(color: AurixTokens.muted))),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: AurixTokens.orange, foregroundColor: Colors.black),
            child: const Text('Сохранить'),
          ),
        ],
      ),
    );
    if (saved != true) return;

    try {
      final newIsrc = ctrl.text.trim().toUpperCase();
      await ref.read(trackRepositoryProvider).updateTrackIsrc(trackId, newIsrc.isEmpty ? null : newIsrc);
      // Сбрасываем кэш чтобы подтянулись актуальные данные
      final uid = _selectedUser?.userId;
      if (uid != null) {
        _artistTracksCache.remove(uid);
        await _loadArtistTracks(uid);
      }
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(newIsrc.isEmpty ? 'ISRC удалён' : 'ISRC обновлён: $newIsrc'),
            backgroundColor: AurixTokens.positive,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger),
        );
      }
    }
  }

  void _openPreviewAsArtist(String userId, String artistName) {
    showDialog(
      context: context,
      builder: (ctx) => _PreviewAsArtistDialog(userId: userId, artistName: artistName),
    );
  }

  String _quickImportHash(List<int> bytes, String fileName, String releaseId, String userId) {
    var h = 2166136261;
    final max = bytes.length > 8192 ? 8192 : bytes.length;
    for (var i = 0; i < max; i++) {
      h ^= bytes[i];
      h = (h * 16777619) & 0x7fffffff;
    }
    return '${fileName.toLowerCase()}|$releaseId|$userId|${bytes.length}|$h';
  }

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  static String _fmtInt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  static Widget _card({required Widget child}) => Container(
    decoration: BoxDecoration(
      color: AurixTokens.bg1,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AurixTokens.border),
    ),
    child: child,
  );

  static Widget _emptyCard(String text) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: AurixTokens.bg1,
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: AurixTokens.border),
    ),
    child: Center(child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 13))),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.label, required this.value, required this.icon, this.accentColor});
  final String label;
  final String value;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: AurixTokens.muted),
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: TextStyle(
              color: accentColor ?? AurixTokens.text,
              fontSize: 24,
              fontWeight: FontWeight.w800,
              fontFeatures: AurixTokens.tabularFigures,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREVIEW DATA & DIALOG
// ═══════════════════════════════════════════════════════════════

class _PreviewData {
  final String fileName;
  final List<int> fileBytes;
  final List<Map<String, dynamic>> rows;
  final List<String> headers;
  final double totalRevenue;
  final int totalStreams;
  final String currency;
  final DateTime? periodStart;
  final DateTime? periodEnd;
  final Map<String, double> byPlatform;
  final Map<String, _ReleaseMatchBucket> byRelease;
  final List<String> unmatchedIsrcs;
  final int unmatchedRowCount;

  _PreviewData({
    required this.fileName,
    required this.fileBytes,
    required this.rows,
    required this.headers,
    required this.totalRevenue,
    required this.totalStreams,
    required this.currency,
    required this.periodStart,
    required this.periodEnd,
    required this.byPlatform,
    required this.byRelease,
    required this.unmatchedIsrcs,
    required this.unmatchedRowCount,
  });

  static _PreviewData build({
    required String fileName,
    required List<int> fileBytes,
    required List<Map<String, dynamic>> rows,
    required List<String> headers,
    required List<Map<String, dynamic>> artistTracks,
  }) {
    // Индекс ISRC → (releaseId, releaseTitle, trackTitle)
    final isrcIndex = <String, Map<String, String>>{};
    for (final t in artistTracks) {
      final isrc = (t['isrc'] ?? '').toString().trim().toUpperCase();
      if (isrc.isEmpty) continue;
      isrcIndex[isrc] = {
        'release_id': t['release_id']?.toString() ?? '',
        'release_title': t['release_title']?.toString() ?? '—',
        'track_title': t['title']?.toString() ?? '',
      };
    }

    double totalRevenue = 0;
    int totalStreams = 0;
    final currencies = <String>{};
    final byPlatform = <String, double>{};
    final byRelease = <String, _ReleaseMatchBucket>{};
    final unmatchedIsrcs = <String>{};
    int unmatchedRowCount = 0;
    DateTime? minDate;
    DateTime? maxDate;

    for (final r in rows) {
      final revenue = (r['revenue'] is num) ? (r['revenue'] as num).toDouble() : 0.0;
      final streams = (r['streams'] is num) ? (r['streams'] as num).toInt() : 0;
      totalRevenue += revenue;
      totalStreams += streams;
      currencies.add((r['currency'] ?? 'RUB').toString());

      final platform = (r['platform'] ?? '—').toString();
      byPlatform[platform] = (byPlatform[platform] ?? 0) + revenue;

      final isrc = (r['isrc'] ?? '').toString().trim().toUpperCase();
      final match = isrc.isNotEmpty ? isrcIndex[isrc] : null;
      if (match != null) {
        final key = match['release_id']!;
        final bucket = byRelease.putIfAbsent(key, () => _ReleaseMatchBucket(title: match['release_title']!));
        bucket.rows += 1;
        bucket.revenue += revenue;
        bucket.streams += streams;
      } else {
        unmatchedRowCount += 1;
        if (isrc.isNotEmpty) {
          unmatchedIsrcs.add(isrc);
        }
      }

      final dateStr = r['report_date']?.toString();
      if (dateStr != null && dateStr.isNotEmpty) {
        final d = DateTime.tryParse(dateStr);
        if (d != null) {
          if (minDate == null || d.isBefore(minDate)) minDate = d;
          if (maxDate == null || d.isAfter(maxDate)) maxDate = d;
        }
      }
    }

    final currency = currencies.length == 1 ? currencies.first : 'mixed';

    return _PreviewData(
      fileName: fileName,
      fileBytes: fileBytes,
      rows: rows,
      headers: headers,
      totalRevenue: totalRevenue,
      totalStreams: totalStreams,
      currency: currency,
      periodStart: minDate,
      periodEnd: maxDate,
      byPlatform: byPlatform,
      byRelease: byRelease,
      unmatchedIsrcs: unmatchedIsrcs.toList()..sort(),
      unmatchedRowCount: unmatchedRowCount,
    );
  }
}

class _ReleaseMatchBucket {
  final String title;
  int rows = 0;
  double revenue = 0;
  int streams = 0;
  _ReleaseMatchBucket({required this.title});
}

class _PreviewDialog extends StatelessWidget {
  final _PreviewData data;
  final String artistName;
  const _PreviewDialog({required this.data, required this.artistName});

  String _cs() => data.currency == 'RUB' ? '₽' : data.currency == 'USD' ? '\$' : data.currency;

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  static String _fmtInt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    final platformTop = data.byPlatform.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final releaseList = data.byRelease.values.toList()
      ..sort((a, b) => b.revenue.compareTo(a.revenue));
    final sample = data.rows.take(15).toList();
    final cs = _cs();

    return Dialog(
      backgroundColor: AurixTokens.bg1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 980, maxHeight: size.height * 0.92),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 16, 16),
              child: Row(children: [
                const Icon(Icons.preview_rounded, color: AurixTokens.orange, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Превью импорта', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text('${data.fileName} · $artistName', style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
                  ]),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded, color: AurixTokens.muted),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ]),
            ),
            const Divider(height: 1, color: AurixTokens.border),

            // Body
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Summary cards
                  LayoutBuilder(builder: (ctx, c) {
                    final isWide = c.maxWidth > 600;
                    final cards = [
                      _summaryCard('СТРОК', _fmtInt(data.rows.length), Icons.list_alt_rounded, AurixTokens.orange),
                      _summaryCard('ДОХОД', '$cs${_fmt(data.totalRevenue)}', Icons.attach_money_rounded, AurixTokens.positive),
                      _summaryCard('ПРОСЛУШИВАНИЯ', _fmtInt(data.totalStreams), Icons.headphones_rounded, AurixTokens.text),
                      _summaryCard('ПЛАТФОРМЫ', '${data.byPlatform.length}', Icons.apps_rounded, AurixTokens.text),
                    ];
                    if (isWide) {
                      return Row(children: cards.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: w))).toList());
                    }
                    return Wrap(spacing: 10, runSpacing: 10, children: cards.map((w) => SizedBox(width: (c.maxWidth - 10) / 2, child: w)).toList());
                  }),

                  const SizedBox(height: 16),

                  // Period
                  if (data.periodStart != null)
                    Text(
                      'Период в файле: ${DateFormat('dd MMM yyyy', 'ru').format(data.periodStart!)}'
                      '${data.periodEnd != null && data.periodEnd != data.periodStart ? ' — ${DateFormat('dd MMM yyyy', 'ru').format(data.periodEnd!)}' : ''}',
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 12),
                    ),

                  const SizedBox(height: 20),

                  // Release breakdown
                  _section('СОПОСТАВЛЕНИЕ С РЕЛИЗАМИ АРТИСТА'),
                  const SizedBox(height: 8),
                  if (releaseList.isEmpty && data.unmatchedRowCount == 0)
                    _emptyRow('Нет данных для матча')
                  else ...[
                    ...releaseList.map((b) => _releaseRow(b.title, b.rows, b.revenue, b.streams, cs, AurixTokens.positive)),
                    if (data.unmatchedRowCount > 0)
                      _unmatchedRow(data.unmatchedRowCount, data.unmatchedIsrcs),
                  ],

                  const SizedBox(height: 20),

                  // Platform breakdown
                  _section('ПО ПЛАТФОРМАМ'),
                  const SizedBox(height: 8),
                  ...platformTop.take(8).map((e) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(children: [
                      Expanded(child: Text(e.key, style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
                      Text('$cs${_fmt(e.value)}', style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
                    ]),
                  )),

                  const SizedBox(height: 20),

                  // Sample rows
                  _section('ПРИМЕР СТРОК (первые ${sample.length})'),
                  const SizedBox(height: 8),
                  _SampleTable(rows: sample, currency: cs),
                ]),
              ),
            ),

            const Divider(height: 1, color: AurixTokens.border),

            // Footer
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(children: [
                if (data.unmatchedRowCount > 0)
                  Expanded(child: Text(
                    '⚠ ${data.unmatchedRowCount} строк не сопоставится с треками. Они всё равно сохранятся, но не появятся в профиле артиста пока ISRC не будет прописан в треке.',
                    style: const TextStyle(color: AurixTokens.warning, fontSize: 11),
                  ))
                else
                  const Spacer(),
                const SizedBox(width: 12),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Отмена', style: TextStyle(color: AurixTokens.muted)),
                ),
                const SizedBox(width: 8),
                FilledButton.icon(
                  onPressed: () => Navigator.of(context).pop(true),
                  icon: const Icon(Icons.check_rounded, size: 18),
                  label: Text('Импортировать ${data.rows.length} строк'),
                  style: FilledButton.styleFrom(
                    backgroundColor: AurixTokens.orange,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
                  ),
                ),
              ]),
            ),
          ],
        ),
      ),
    );
  }

  Widget _summaryCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.border),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: AurixTokens.muted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 8),
        Text(value, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
      ]),
    );
  }

  Widget _section(String text) => Text(
    text,
    style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
  );

  Widget _releaseRow(String title, int rows, double revenue, int streams, String cs, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        const Icon(Icons.check_circle_rounded, size: 16, color: AurixTokens.positive),
        const SizedBox(width: 8),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
            Text('$rows строк · ${_fmtInt(streams)} прослушиваний', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          ]),
        ),
        Text('$cs${_fmt(revenue)}', style: TextStyle(color: color, fontSize: 14, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
      ]),
    );
  }

  Widget _unmatchedRow(int count, List<String> isrcs) {
    final preview = isrcs.take(3).join(', ');
    final more = isrcs.length > 3 ? ' и ещё ${isrcs.length - 3}' : '';
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AurixTokens.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AurixTokens.warning.withValues(alpha: 0.2)),
      ),
      child: Row(children: [
        const Icon(Icons.warning_amber_rounded, color: AurixTokens.warning, size: 18),
        const SizedBox(width: 10),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Не сопоставлено: $count строк',
              style: const TextStyle(color: AurixTokens.warning, fontSize: 12, fontWeight: FontWeight.w700)),
          const SizedBox(height: 3),
          Text(
            isrcs.isEmpty
                ? 'Строки без ISRC — проверьте колонку "ISRC контента" в файле.'
                : 'ISRC в файле, которых нет в каталоге артиста: $preview$more',
            style: const TextStyle(color: AurixTokens.text, fontSize: 11, height: 1.5),
          ),
        ])),
      ]),
    );
  }

  Widget _emptyRow(String text) => Padding(
    padding: const EdgeInsets.all(8),
    child: Text(text, style: const TextStyle(color: AurixTokens.muted, fontSize: 12)),
  );
}

// ── Sample rows table ──────────────────────────────────────────

class _SampleTable extends StatelessWidget {
  final List<Map<String, dynamic>> rows;
  final String currency;
  const _SampleTable({required this.rows, required this.currency});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AurixTokens.bg2,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AurixTokens.border),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: DataTable(
          columnSpacing: 18,
          headingRowHeight: 34,
          dataRowMinHeight: 28,
          dataRowMaxHeight: 32,
          headingTextStyle: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 0.8),
          dataTextStyle: const TextStyle(color: AurixTokens.text, fontSize: 12),
          columns: const [
            DataColumn(label: Text('ПЕРИОД')),
            DataColumn(label: Text('ПЛОЩАДКА')),
            DataColumn(label: Text('СТРАНА')),
            DataColumn(label: Text('ТРЕК')),
            DataColumn(label: Text('ISRC')),
            DataColumn(label: Text('ПРОСЛ.'), numeric: true),
            DataColumn(label: Text('ДОХОД'), numeric: true),
          ],
          rows: rows.map((r) {
            final revenue = (r['revenue'] is num) ? (r['revenue'] as num).toDouble() : 0.0;
            final streams = (r['streams'] is num) ? (r['streams'] as num).toInt() : 0;
            return DataRow(cells: [
              DataCell(Text(r['report_date']?.toString() ?? '—')),
              DataCell(Text(r['platform']?.toString() ?? '—')),
              DataCell(Text(r['country']?.toString() ?? '—')),
              DataCell(Text(r['track_title']?.toString() ?? '—', overflow: TextOverflow.ellipsis)),
              DataCell(Text(r['isrc']?.toString() ?? '—', style: const TextStyle(color: AurixTokens.accent, fontFeatures: AurixTokens.tabularFigures))),
              DataCell(Text('$streams', style: const TextStyle(fontFeatures: AurixTokens.tabularFigures))),
              DataCell(Text('$currency${revenue.toStringAsFixed(4)}', style: const TextStyle(color: AurixTokens.orange, fontFeatures: AurixTokens.tabularFigures))),
            ]);
          }).toList(),
        ),
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════
// PREVIEW AS ARTIST — админ видит то же что артист
// ═══════════════════════════════════════════════════════════════

class _PreviewAsArtistDialog extends ConsumerStatefulWidget {
  final String userId;
  final String artistName;
  const _PreviewAsArtistDialog({required this.userId, required this.artistName});

  @override
  ConsumerState<_PreviewAsArtistDialog> createState() => _PreviewAsArtistDialogState();
}

class _PreviewAsArtistDialogState extends ConsumerState<_PreviewAsArtistDialog> {
  List<ReportRowModel>? _rows;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(reportRepositoryProvider).getRowsByUserAdmin(widget.userId);
      if (mounted) setState(() => _rows = rows);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  static String _fmt(double v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(2)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toStringAsFixed(2);
  }

  static String _fmtInt(int v) {
    if (v >= 1000000) return '${(v / 1000000).toStringAsFixed(1)}M';
    if (v >= 1000) return '${(v / 1000).toStringAsFixed(1)}K';
    return v.toString();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    return Dialog(
      backgroundColor: AurixTokens.bg0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: 900, maxHeight: size.height * 0.92),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          // Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AurixTokens.orange.withValues(alpha: 0.1),
              border: const Border(bottom: BorderSide(color: AurixTokens.border)),
            ),
            child: Row(children: [
              const Icon(Icons.visibility_rounded, color: AurixTokens.orange, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('Просмотр как артист', style: TextStyle(color: AurixTokens.orange, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
                const SizedBox(height: 2),
                Text(widget.artistName, style: const TextStyle(color: AurixTokens.text, fontSize: 15, fontWeight: FontWeight.w700)),
              ])),
              IconButton(
                icon: const Icon(Icons.close_rounded, color: AurixTokens.muted),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ]),
          ),
          Flexible(child: _buildBody()),
        ]),
      ),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Text('Ошибка: $_error', style: const TextStyle(color: AurixTokens.danger, fontSize: 13)),
      );
    }
    if (_rows == null) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
      );
    }
    if (_rows!.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(40),
        child: Center(child: Text('У этого артиста ещё нет отчётов', style: TextStyle(color: AurixTokens.muted, fontSize: 14))),
      );
    }

    final totalRevenue = _rows!.fold<double>(0, (s, r) => s + r.revenue);
    final totalStreams = _rows!.fold<int>(0, (s, r) => s + r.streams);
    final byPlatform = <String, ({double revenue, int streams})>{};
    final byRelease = <String, ({double revenue, int streams, int rowCount})>{};
    final byTrack = <String, ({double revenue, int streams, String? isrc, String? release})>{};
    for (final r in _rows!) {
      final p = r.platform ?? 'Другое';
      final prevP = byPlatform[p];
      byPlatform[p] = (revenue: (prevP?.revenue ?? 0) + r.revenue, streams: (prevP?.streams ?? 0) + r.streams);

      final rel = r.releaseId ?? 'без релиза';
      final prevR = byRelease[rel];
      byRelease[rel] = (
        revenue: (prevR?.revenue ?? 0) + r.revenue,
        streams: (prevR?.streams ?? 0) + r.streams,
        rowCount: (prevR?.rowCount ?? 0) + 1,
      );

      final t = r.trackTitle ?? (r.isrc ?? '—');
      final prevT = byTrack[t];
      byTrack[t] = (
        revenue: (prevT?.revenue ?? 0) + r.revenue,
        streams: (prevT?.streams ?? 0) + r.streams,
        isrc: r.isrc ?? prevT?.isrc,
        release: prevT?.release,
      );
    }

    final currencies = _rows!.map((r) => r.currency).toSet();
    final cs = currencies.length == 1 && currencies.first == 'RUB' ? '₽' : '\$';

    final platforms = byPlatform.entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    final releases = byRelease.entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));
    final tracks = byTrack.entries.toList()..sort((a, b) => b.value.revenue.compareTo(a.value.revenue));

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Summary
        LayoutBuilder(builder: (ctx, c) {
          final isWide = c.maxWidth > 600;
          final cards = [
            _bigCard('ОБЩИЙ ДОХОД', '$cs${_fmt(totalRevenue)}', Icons.attach_money_rounded, AurixTokens.positive),
            _bigCard('ПРОСЛУШИВАНИЯ', _fmtInt(totalStreams), Icons.headphones_rounded, AurixTokens.orange),
            _bigCard('ТРЕКОВ', '${tracks.length}', Icons.music_note_rounded, AurixTokens.text),
            _bigCard('ПЛАТФОРМ', '${platforms.length}', Icons.apps_rounded, AurixTokens.text),
          ];
          if (isWide) return Row(children: cards.map((w) => Expanded(child: Padding(padding: const EdgeInsets.only(right: 10), child: w))).toList());
          return Wrap(spacing: 10, runSpacing: 10, children: cards.map((w) => SizedBox(width: (c.maxWidth - 10) / 2, child: w)).toList());
        }),
        const SizedBox(height: 24),
        _section('ПО РЕЛИЗАМ'),
        const SizedBox(height: 8),
        ...releases.map((e) => _rowLine(e.key == 'без релиза' ? 'Без привязки к релизу' : 'Релиз #${e.key}', '${e.value.rowCount} строк · ${_fmtInt(e.value.streams)} прослушиваний', '$cs${_fmt(e.value.revenue)}', warning: e.key == 'без релиза')),
        const SizedBox(height: 20),
        _section('ПО ТРЕКАМ (топ 15)'),
        const SizedBox(height: 8),
        ...tracks.take(15).map((e) => _rowLine(e.key, e.value.isrc ?? '—', '$cs${_fmt(e.value.revenue)} · ${_fmtInt(e.value.streams)}')),
        const SizedBox(height: 20),
        _section('ПО ПЛАТФОРМАМ'),
        const SizedBox(height: 8),
        ...platforms.map((e) => _rowLine(e.key, '${_fmtInt(e.value.streams)} прослушиваний', '$cs${_fmt(e.value.revenue)}')),
        const SizedBox(height: 24),
      ]),
    );
  }

  Widget _bigCard(String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(color: AurixTokens.bg1, borderRadius: BorderRadius.circular(10), border: Border.all(color: AurixTokens.border)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Icon(icon, size: 14, color: AurixTokens.muted),
          const SizedBox(width: 6),
          Text(label, style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontWeight: FontWeight.w700, letterSpacing: 1.2)),
        ]),
        const SizedBox(height: 10),
        Text(value, style: TextStyle(color: color, fontSize: 22, fontWeight: FontWeight.w800, fontFeatures: AurixTokens.tabularFigures)),
      ]),
    );
  }

  Widget _section(String text) => Text(
    text,
    style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5),
  );

  Widget _rowLine(String title, String sub, String value, {bool warning = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AurixTokens.bg1,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: warning ? AurixTokens.warning.withValues(alpha: 0.3) : AurixTokens.border),
      ),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title, style: TextStyle(color: warning ? AurixTokens.warning : AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
            const SizedBox(height: 2),
            Text(sub, style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
          ]),
        ),
        const SizedBox(width: 10),
        Text(value, style: const TextStyle(color: AurixTokens.orange, fontSize: 13, fontWeight: FontWeight.w700, fontFeatures: AurixTokens.tabularFigures)),
      ]),
    );
  }
}
