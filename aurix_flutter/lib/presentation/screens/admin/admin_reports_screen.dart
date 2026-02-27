import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/design/widgets/aurix_glass_card.dart';
import 'package:aurix_flutter/data/models/report_model.dart';
import 'package:aurix_flutter/data/providers/repositories_provider.dart';
import 'package:aurix_flutter/data/services/csv_report_parser.dart';
import 'package:aurix_flutter/presentation/providers/auth_provider.dart';

final reportsListProvider = FutureProvider((ref) async {
  final isAdmin = await ref.watch(isAdminProvider.future);
  if (!isAdmin) return <_ReportWithCount>[];
  final repo = ref.watch(reportRepositoryProvider);
  final reports = await repo.getReports();
  final result = <_ReportWithCount>[];
  for (final r in reports) {
    final rows = await repo.getReportRows(r.id);
    result.add(_ReportWithCount(report: r, rowCount: rows.length));
  }
  return result;
});

class _ReportWithCount {
  final ReportModel report;
  final int rowCount;
  _ReportWithCount({required this.report, required this.rowCount});
}

class AdminReportsScreen extends ConsumerStatefulWidget {
  const AdminReportsScreen({super.key});

  @override
  ConsumerState<AdminReportsScreen> createState() => _AdminReportsScreenState();
}

class _AdminReportsScreenState extends ConsumerState<AdminReportsScreen> {
  bool _uploading = false;
  bool _pickingFile = false;
  String? _error;

  Future<void> _importCsv() async {
    if (_uploading || _pickingFile) return;
    _pickingFile = true;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv'],
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

    final user = ref.read(currentUserProvider);
    if (user == null) {
      setState(() => _error = 'Войдите в аккаунт');
      return;
    }

    setState(() {
      _error = null;
      _uploading = true;
    });

    try {
      final repo = ref.read(reportRepositoryProvider);
      final now = DateTime.now();
      final periodStart = DateTime(now.year, now.month - 2, 1);
      final periodEnd = DateTime(now.year, now.month, 0);

      final rows = CsvReportParser.parse(bytes, periodStart: periodStart, periodEnd: periodEnd);
      if (rows.isEmpty) {
        setState(() {
          _error = 'Не удалось распарсить CSV. Проверьте формат.';
          _uploading = false;
        });
        return;
      }

      final report = await repo.createReport(
        periodStart: periodStart,
        periodEnd: periodEnd,
        fileName: file.name,
        createdBy: user.id,
      );
      await repo.updateReportStatus(report.id, 'parsing');
      await repo.addReportRows(report.id, rows);
      final matched = await repo.matchReportRowsByIsrc(report.id);
      await repo.updateReportStatus(report.id, 'ready');

      ref.invalidate(reportsListProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Импорт: ${rows.length} строк, сопоставлено по ISRC: $matched'),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = e.toString().length > 100 ? '${e.toString().substring(0, 97)}...' : e.toString();
      });
    } finally {
      setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportsAsync = ref.watch(reportsListProvider);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AurixGlassCard(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Импорт квартальных отчётов',
                  style: TextStyle(color: AurixTokens.text, fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 12),
                Text(
                  'Загрузите CSV от дистрибьютора. Система распарсит данные и сопоставит строки с треками по ISRC.',
                  style: TextStyle(color: AurixTokens.muted, fontSize: 14, height: 1.4),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    FilledButton.icon(
                      onPressed: _uploading ? null : _importCsv,
                      icon: _uploading
                          ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Icon(Icons.upload_file_rounded, size: 20),
                      label: Text(_uploading ? 'Загрузка...' : 'Выбрать CSV'),
                      style: FilledButton.styleFrom(
                        backgroundColor: AurixTokens.orange,
                        foregroundColor: Colors.black,
                      ),
                    ),
                  ],
                ),
                if (_error != null) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(_error!, style: TextStyle(color: Colors.red[200], fontSize: 13)),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'Импортированные отчёты',
            style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          reportsAsync.when(
            data: (list) {
              if (list.isEmpty) {
                return AurixGlassCard(
                  padding: const EdgeInsets.all(32),
                  child: Center(
                    child: Text(
                      'Пока нет импортов',
                      style: TextStyle(color: AurixTokens.muted, fontSize: 14),
                    ),
                  ),
                );
              }
              return AurixGlassCard(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => Divider(height: 1, color: AurixTokens.stroke(0.08)),
                  itemBuilder: (_, i) {
                    final r = list[i];
                    final report = r.report;
                    return ListTile(
                      title: Text(
                        '${DateFormat.yMMM('ru').format(report.periodStart)} — ${DateFormat.yMMM('ru').format(report.periodEnd)}',
                        style: TextStyle(color: AurixTokens.text, fontWeight: FontWeight.w600),
                      ),
                      subtitle: Text(
                        '${r.rowCount} строк • ${report.status}',
                        style: TextStyle(color: AurixTokens.muted, fontSize: 12),
                      ),
                    );
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => Text('Ошибка: $e', style: TextStyle(color: AurixTokens.muted)),
          ),
        ],
      ),
    );
  }
}