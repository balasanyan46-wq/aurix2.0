import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
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
  bool _uploading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final rowsAsync = ref.watch(allReportRowsProvider);
    final reportsAsync = ref.watch(adminReportsProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'ФИНАНСЫ',
            style: TextStyle(color: AurixTokens.text, fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 1.2),
          ),
          const SizedBox(height: 20),

          rowsAsync.when(
            data: (rows) => _buildSummary(rows),
            loading: () => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2))),
            error: (e, _) => Text('Ошибка: $e', style: const TextStyle(color: Colors.redAccent)),
          ),

          const SizedBox(height: 28),

          const Text('ИМПОРТ CSV', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          _buildImportCard(),

          const SizedBox(height: 28),

          const Text('ЗАГРУЖЕННЫЕ ОТЧЁТЫ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
          const SizedBox(height: 12),
          reportsAsync.when(
            data: (list) {
              if (list.isEmpty) return _emptyCard('Нет отчётов');
              return _card(
                child: Column(
                  children: list.map((r) => ListTile(
                    dense: true,
                    title: Text(
                      '${DateFormat.yMMM("ru").format(r.periodStart)} — ${DateFormat.yMMM("ru").format(r.periodEnd)}',
                      style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    subtitle: Text(
                      '${r.fileName ?? "—"} • ${r.status}',
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                    ),
                    trailing: Text(
                      DateFormat('dd.MM.yy').format(r.createdAt),
                      style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                    ),
                  )).toList(),
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)),
            error: (e, _) => Text('Ошибка: $e', style: const TextStyle(color: Colors.redAccent)),
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

    final artists = <String>{};
    for (final r in rows) {
      if (r.trackTitle != null) artists.add(r.trackTitle!);
    }
    final avgPerArtist = artists.isNotEmpty ? totalRevenue / artists.length : 0.0;

    return LayoutBuilder(builder: (context, constraints) {
      final isWide = constraints.maxWidth > 600;
      final cards = [
        _SummaryCard(label: 'ОБЩИЙ ДОХОД', value: '\$${_fmt(totalRevenue)}', icon: Icons.attach_money_rounded),
        _SummaryCard(label: 'ЗА МЕСЯЦ', value: '\$${_fmt(thisMonthRevenue)}', icon: Icons.calendar_month_rounded, accentColor: AurixTokens.positive),
        _SummaryCard(label: 'ПРОСЛУШИВАНИЯ', value: _fmtInt(totalStreams), icon: Icons.headphones_rounded),
        _SummaryCard(label: 'СРЕДНЕЕ НА ТРЕК', value: '\$${_fmt(avgPerArtist)}', icon: Icons.person_rounded, accentColor: AurixTokens.orange),
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

  Widget _buildImportCard() {
    return _card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Загрузите CSV от дистрибьютора для импорта данных.',
              style: TextStyle(color: AurixTokens.muted, fontSize: 13),
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _uploading ? null : _importCsv,
              icon: _uploading
                  ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                  : const Icon(Icons.upload_file_rounded, size: 18),
              label: Text(_uploading ? 'Загрузка...' : 'Выбрать CSV'),
              style: FilledButton.styleFrom(
                backgroundColor: AurixTokens.orange,
                foregroundColor: Colors.black,
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
          ],
        ),
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
                  '\$${_fmt(e.value)}',
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
    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'Войдите в аккаунт');
      return;
    }
    setState(() { _error = null; _uploading = true; });
    try {
      final repo = ref.read(reportRepositoryProvider);
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month - 2, 1);
      final periodEnd = DateTime(now.year, now.month, 0);
      final rows = CsvReportParser.parse(bytes, periodStart: periodStart, periodEnd: periodEnd);
      if (rows.isEmpty) {
        setState(() { _error = 'Не удалось распарсить CSV'; _uploading = false; });
        return;
      }
      final report = await repo.createReport(periodStart: periodStart, periodEnd: periodEnd, fileName: file.name, createdBy: user.id);
      await repo.updateReportStatus(report.id, 'parsing');
      await repo.addReportRows(report.id, rows);
      final matched = await repo.matchReportRowsByIsrc(report.id);
      await repo.updateReportStatus(report.id, 'ready');

      await ref.read(adminLogRepositoryProvider).log(
        adminId: user.id,
        action: 'report_imported',
        targetType: 'report',
        targetId: report.id,
        details: {'rows': rows.length, 'matched': matched},
      );

      ref.invalidate(adminReportsProvider);
      ref.invalidate(allReportRowsProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Импорт: ${rows.length} строк, сопоставлено: $matched')),
        );
      }
    } catch (e) {
      setState(() => _error = e.toString().length > 100 ? '${e.toString().substring(0, 97)}...' : e.toString());
    } finally {
      setState(() => _uploading = false);
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
