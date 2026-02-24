import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/models/profile_model.dart';
import 'package:aurix_flutter/data/models/release_model.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/models/report_row_model.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/services/csv_report_parser.dart';
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
  String? _error;
  String? _success;

  @override
  Widget build(BuildContext context) {
    final profilesAsync = ref.watch(allProfilesProvider);
    final releasesAsync = ref.watch(allReleasesAdminProvider);
    final reportsAsync = ref.watch(adminReportsProvider);
    final rowsAsync = ref.watch(allReportRowsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
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
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
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
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),

          const SizedBox(height: 28),

          const Text('ЗАГРУЖЕННЫЕ ОТЧЁТЫ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          reportsAsync.when(
            data: (list) {
              if (list.isEmpty) return _emptyCard('Нет отчётов');
              final profiles = profilesAsync.valueOrNull ?? [];
              final releases = releasesAsync.valueOrNull ?? [];
              return _buildReportsTable(list, profiles, releases);
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
            error: (e, _) => Text('$e', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
          ),

          const SizedBox(height: 28),

          rowsAsync.when(
            data: (rows) => _buildBreakdowns(rows),
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
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
    final userReleases = _selectedUser != null
        ? allReleases.where((r) => r.ownerId == _selectedUser!.userId).toList()
        : <ReleaseModel>[];

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
            _buildDropdown<ProfileModel>(
              value: _selectedUser,
              hint: 'Артист',
              items: profiles.where((p) => p.role != 'admin').toList(),
              labelBuilder: (p) => '${p.displayNameOrName} (${p.email})',
              onChanged: (p) => setState(() {
                _selectedUser = p;
                _selectedRelease = null;
                _error = null;
                _success = null;
              }),
            ),

            const SizedBox(height: 16),

            // Step 2: Pick release
            _buildStepLabel('2', 'Выберите релиз'),
            const SizedBox(height: 8),
            _buildDropdown<ReleaseModel>(
              value: _selectedRelease,
              hint: _selectedUser == null ? 'Сначала выберите артиста' : (userReleases.isEmpty ? 'Нет релизов' : 'Релиз'),
              items: userReleases,
              labelBuilder: (r) => '${r.title}${r.artist != null ? " — ${r.artist}" : ""} (${r.releaseType})',
              onChanged: _selectedUser == null ? null : (r) => setState(() {
                _selectedRelease = r;
                _error = null;
                _success = null;
              }),
            ),

            const SizedBox(height: 16),

            // Step 3: Upload CSV
            _buildStepLabel('3', 'Загрузите CSV'),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: (_uploading || _selectedUser == null || _selectedRelease == null) ? null : _importCsv,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(_uploading ? 'Загрузка...' : 'Выбрать CSV'),
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
                  color: Colors.red.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_error!, style: TextStyle(color: Colors.red[300], fontSize: 12)),
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
  ) {
    String userName(String? uid) {
      if (uid == null) return '—';
      final p = profiles.where((p) => p.userId == uid);
      return p.isNotEmpty ? p.first.displayNameOrName : uid.substring(0, 8);
    }
    String releaseName(String? rid) {
      if (rid == null) return '—';
      final r = releases.where((r) => r.id == rid);
      return r.isNotEmpty ? r.first.title : rid.substring(0, 8);
    }

    return _card(
      child: Column(
        children: reports.map((r) {
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
            trailing: IconButton(
              icon: Icon(Icons.delete_outline_rounded, size: 18, color: AurixTokens.muted),
              tooltip: 'Удалить отчёт',
              onPressed: () => _confirmDelete(r.id, r.fileName),
            ),
          );
        }).toList(),
      ),
    );
  }

  void _confirmDelete(String reportId, String? fileName) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AurixTokens.bg1,
        title: Text('Удалить отчёт?', style: TextStyle(color: AurixTokens.text)),
        content: Text('${fileName ?? "Отчёт"} будет удалён вместе со всеми строками.', style: TextStyle(color: AurixTokens.muted)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Отмена', style: TextStyle(color: AurixTokens.muted))),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                await ref.read(reportRepositoryProvider).deleteReport(reportId);
                ref.invalidate(adminReportsProvider);
                ref.invalidate(allReportRowsProvider);
              } catch (e) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e')));
                }
              }
            },
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
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
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: ['csv'], withData: true);
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
    if (_selectedUser == null || _selectedRelease == null) {
      setState(() => _error = 'Выберите артиста и релиз');
      return;
    }

    setState(() { _error = null; _success = null; _uploading = true; });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final now = DateTime.now();
      final ps = DateTime(now.year, now.month, 1).subtract(const Duration(days: 60));
      final periodStart = DateTime(ps.year, ps.month, 1);
      final periodEnd = DateTime(now.year, now.month, 0);

      final parseResult = CsvReportParser.parseWithDetails(bytes, periodStart: periodStart, periodEnd: periodEnd);
      if (!parseResult.hasData) {
        setState(() { _error = parseResult.error ?? 'Не удалось распарсить CSV'; _uploading = false; });
        return;
      }
      final rows = parseResult.rows;

      final report = await repo.createReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        fileName: file.name,
        createdBy: admin.id,
      );
      await repo.updateReportStatus(report.id, 'parsing');
      await repo.addReportRows(report.id, rows);
      final matched = await repo.matchReportRowsByIsrc(report.id);
      await repo.updateReportStatus(report.id, 'ready');

      await ref.read(adminLogRepositoryProvider).log(
        adminId: admin.id,
        action: 'report_imported',
        targetType: 'report',
        targetId: report.id,
        details: {
          'rows': rows.length,
          'matched': matched,
          'user': _selectedUser!.displayNameOrName,
          'release': _selectedRelease!.title,
        },
      );

      ref.invalidate(adminReportsProvider);
      ref.invalidate(allReportRowsProvider);

      setState(() {
        _success = 'Импорт завершён: ${rows.length} строк для "${_selectedRelease!.title}" (${_selectedUser!.displayNameOrName})';
        _uploading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().length > 150 ? '${e.toString().substring(0, 147)}...' : e.toString();
        _uploading = false;
      });
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
