import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/api/api_client.dart';

class AdminErrorsTab extends ConsumerStatefulWidget {
  const AdminErrorsTab({super.key});
  @override
  ConsumerState<AdminErrorsTab> createState() => _AdminErrorsTabState();
}

class _AdminErrorsTabState extends ConsumerState<AdminErrorsTab> {
  bool _loading = true;
  List<dynamic> _errors = [];
  Map<String, dynamic> _stats = {};
  List<dynamic> _topPaths = [];
  List<dynamic> _aiServices = [];
  int _hours = 24;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final results = await Future.wait([
        ApiClient.get('/system/errors?hours=$_hours&limit=100'),
        ApiClient.get('/system/ai-status').catchError((_) => null),
      ]);
      final d = results[0]?.data is Map ? Map<String, dynamic>.from(results[0]!.data as Map) : <String, dynamic>{};
      final ai = results[1]?.data is Map ? Map<String, dynamic>.from(results[1]!.data as Map) : <String, dynamic>{};
      if (mounted) setState(() {
        _errors = d['errors'] as List? ?? [];
        _stats = d['stats'] as Map<String, dynamic>? ?? {};
        _topPaths = d['top_paths'] as List? ?? [];
        _aiServices = ai['services'] as List? ?? [];
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _loading = false; });
    }
  }

  Color _statusColor(int code) {
    if (code >= 500) return AurixTokens.danger;
    if (code >= 400) return AurixTokens.warning;
    return AurixTokens.positive;
  }

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      // Header with stats
      Container(
        padding: const EdgeInsets.all(16),
        color: AurixTokens.bg1,
        child: Column(children: [
          Row(children: [
            Icon(Icons.bug_report_rounded, size: 20, color: AurixTokens.danger),
            const SizedBox(width: 8),
            const Expanded(child: Text('Мониторинг ошибок', style: TextStyle(color: AurixTokens.text, fontSize: 16, fontWeight: FontWeight.w700))),
            // Period selector
            ...([1, 6, 24, 72].map((h) => Padding(
              padding: const EdgeInsets.only(left: 4),
              child: ChoiceChip(
                label: Text('${h}ч'),
                selected: _hours == h,
                onSelected: (_) { _hours = h; _load(); },
                selectedColor: AurixTokens.accent.withValues(alpha: 0.2),
                backgroundColor: AurixTokens.bg2,
                labelStyle: TextStyle(color: _hours == h ? AurixTokens.accent : AurixTokens.muted, fontSize: 11),
                side: BorderSide(color: _hours == h ? AurixTokens.accent.withValues(alpha: 0.4) : AurixTokens.border),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
              ),
            ))),
            const SizedBox(width: 8),
            IconButton(icon: const Icon(Icons.refresh_rounded, size: 20, color: AurixTokens.muted), onPressed: _load),
          ]),

          if (!_loading && _stats.isNotEmpty) ...[
            const SizedBox(height: 12),
            Row(children: [
              _StatBadge(label: 'Всего', value: '${_stats['total'] ?? 0}', color: AurixTokens.text),
              _StatBadge(label: '5xx', value: '${_stats['server_errors'] ?? 0}', color: AurixTokens.danger),
              _StatBadge(label: '4xx', value: '${_stats['client_errors'] ?? 0}', color: AurixTokens.warning),
              _StatBadge(label: 'Юзеров', value: '${_stats['affected_users'] ?? 0}', color: AurixTokens.aiAccent),
              _StatBadge(label: 'Путей', value: '${_stats['unique_paths'] ?? 0}', color: AurixTokens.muted),
            ]),
          ],

          // Top error paths
          if (!_loading && _topPaths.isNotEmpty) ...[
            const SizedBox(height: 12),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: _topPaths.length,
                separatorBuilder: (_, __) => const SizedBox(width: 6),
                itemBuilder: (_, i) {
                  final p = _topPaths[i] is Map ? _topPaths[i] as Map : {};
                  return Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: AurixTokens.danger.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.15)),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text('${p['count']}×', style: TextStyle(color: AurixTokens.danger, fontSize: 11, fontWeight: FontWeight.w700)),
                      const SizedBox(width: 4),
                      Text('${p['path'] ?? '?'}', style: TextStyle(color: AurixTokens.muted, fontSize: 11), overflow: TextOverflow.ellipsis),
                    ]),
                  );
                },
              ),
            ),
          ],
        ]),
      ),

      // AI Services status
      if (!_loading && _aiServices.isNotEmpty)
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AurixTokens.bg1,
          child: Row(children: _aiServices.map((s) {
            final svc = s is Map ? Map<String, dynamic>.from(s as Map) : <String, dynamic>{};
            final ok = svc['status'] == 'ok';
            final latency = svc['latency'] is num ? svc['latency'] as num : num.tryParse(svc['latency']?.toString() ?? '');
            return Expanded(child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 3),
              padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 8),
              decoration: BoxDecoration(
                color: (ok ? AurixTokens.positive : AurixTokens.danger).withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: (ok ? AurixTokens.positive : AurixTokens.danger).withValues(alpha: 0.15)),
              ),
              child: Row(mainAxisSize: MainAxisSize.min, children: [
                Icon(ok ? Icons.check_circle_rounded : Icons.error_rounded, size: 14, color: ok ? AurixTokens.positive : AurixTokens.danger),
                const SizedBox(width: 6),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(svc['name']?.toString() ?? '?', style: TextStyle(color: AurixTokens.text, fontSize: 11, fontWeight: FontWeight.w600), overflow: TextOverflow.ellipsis),
                  if (latency != null) Text('${latency}ms', style: TextStyle(color: AurixTokens.muted, fontSize: 9)),
                ])),
              ]),
            ));
          }).toList()),
        ),

      // Error list
      Expanded(
        child: _loading
            ? const Center(child: CircularProgressIndicator(color: AurixTokens.accent))
            : _errors.isEmpty
                ? Center(child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.check_circle_rounded, size: 48, color: AurixTokens.positive.withValues(alpha: 0.5)),
                    const SizedBox(height: 12),
                    Text('Нет ошибок за $_hours ч', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                  ]))
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: _errors.length,
                    itemBuilder: (_, i) {
                      final e = _errors[i] is Map ? Map<String, dynamic>.from(_errors[i] as Map) : <String, dynamic>{};
                      final status = e['status_code'] is num ? (e['status_code'] as num).toInt() : int.tryParse(e['status_code']?.toString() ?? '') ?? 0;
                      final time = DateTime.tryParse(e['created_at']?.toString() ?? '');

                      return Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: AurixTokens.bg1,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: _statusColor(status).withValues(alpha: 0.15)),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            // Status badge
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(color: _statusColor(status).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                              child: Text('$status', style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.w800)),
                            ),
                            const SizedBox(width: 8),
                            // Method
                            Text(e['method']?.toString() ?? '?', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w600)),
                            const SizedBox(width: 6),
                            // Path
                            Expanded(child: Text(e['path']?.toString() ?? '?', style: const TextStyle(color: AurixTokens.text, fontSize: 12, fontWeight: FontWeight.w500), overflow: TextOverflow.ellipsis)),
                            // Duration
                            if (e['duration_ms'] != null)
                              Text('${e['duration_ms']}ms', style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
                            const SizedBox(width: 8),
                            // Time
                            if (time != null) Text(DateFormat('HH:mm:ss').format(time), style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
                          ]),
                          const SizedBox(height: 6),
                          // Error message
                          Text(e['error_message']?.toString() ?? '', style: TextStyle(color: AurixTokens.textSecondary, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
                          // User + IP
                          if (e['user_id'] != null || e['ip'] != null) ...[
                            const SizedBox(height: 4),
                            Row(children: [
                              if (e['user_id'] != null) ...[
                                Icon(Icons.person_outline_rounded, size: 12, color: AurixTokens.muted),
                                const SizedBox(width: 3),
                                Text('${e['user_id']}', style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
                                const SizedBox(width: 8),
                              ],
                              if (e['ip'] != null) ...[
                                Icon(Icons.language_rounded, size: 12, color: AurixTokens.muted),
                                const SizedBox(width: 3),
                                Text('${e['ip']}', style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
                              ],
                            ]),
                          ],
                        ]),
                      );
                    },
                  ),
      ),
    ]);
  }
}

class _StatBadge extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _StatBadge({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return Expanded(child: Container(
      margin: const EdgeInsets.symmetric(horizontal: 3),
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.06), borderRadius: BorderRadius.circular(8)),
      child: Column(children: [
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.w800)),
        Text(label, style: TextStyle(color: AurixTokens.muted, fontSize: 10)),
      ]),
    ));
  }
}
