import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';

class AdminLogsTab extends ConsumerStatefulWidget {
  const AdminLogsTab({super.key});

  @override
  ConsumerState<AdminLogsTab> createState() => _AdminLogsTabState();
}

class _AdminLogsTabState extends ConsumerState<AdminLogsTab> {
  String _actionFilter = 'all';
  String _search = '';

  static const _actions = [
    'all',
    'release_status_changed',
    'user_role_changed',
    'user_plan_changed',
    'user_suspended',
    'user_activated',
    'ticket_replied',
    'ticket_closed',
    'report_imported',
  ];

  IconData _actionIcon(String action) => switch (action) {
        'release_status_changed' => Icons.album_rounded,
        'user_role_changed' => Icons.admin_panel_settings_rounded,
        'user_plan_changed' => Icons.credit_card_rounded,
        'user_suspended' => Icons.block_rounded,
        'user_activated' => Icons.check_circle_rounded,
        'ticket_replied' => Icons.reply_rounded,
        'ticket_closed' => Icons.close_rounded,
        'report_imported' => Icons.upload_file_rounded,
        _ => Icons.history_rounded,
      };

  Color _actionColor(String action) => switch (action) {
        'release_status_changed' => Colors.blue,
        'user_role_changed' => AurixTokens.orange,
        'user_plan_changed' => AurixTokens.positive,
        'user_suspended' => Colors.redAccent,
        'user_activated' => AurixTokens.positive,
        'ticket_replied' => Colors.amber,
        'report_imported' => AurixTokens.orange,
        _ => AurixTokens.muted,
      };

  @override
  Widget build(BuildContext context) {
    final logsAsync = ref.watch(adminLogsProvider);

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
                  hintText: 'Поиск по действиям...',
                  hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 14),
                  prefixIcon: const Icon(Icons.search, color: AurixTokens.muted, size: 20),
                  filled: true, fillColor: AurixTokens.bg2,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                ),
                onChanged: (v) => setState(() => _search = v.toLowerCase()),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _actions.map((a) {
                final selected = _actionFilter == a;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: ChoiceChip(
                    label: Text(a == 'all' ? 'Все' : _actionLabel(a)),
                    selected: selected,
                    onSelected: (_) => setState(() => _actionFilter = a),
                    selectedColor: AurixTokens.orange.withValues(alpha: 0.2),
                    backgroundColor: AurixTokens.bg2,
                    labelStyle: TextStyle(
                      color: selected ? AurixTokens.orange : AurixTokens.muted,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    side: BorderSide(color: selected ? AurixTokens.orange.withValues(alpha: 0.4) : AurixTokens.border),
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
          child: logsAsync.when(
            data: (logs) {
              var filtered = _actionFilter == 'all'
                  ? logs
                  : logs.where((l) => l.action == _actionFilter).toList();
              if (_search.isNotEmpty) {
                filtered = filtered.where((l) {
                  return l.actionLabel.toLowerCase().contains(_search) ||
                      l.targetType.toLowerCase().contains(_search) ||
                      (l.targetId?.toLowerCase().contains(_search) ?? false) ||
                      l.details.values.any((v) => v.toString().toLowerCase().contains(_search));
                }).toList();
              }

              if (filtered.isEmpty) {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.history_rounded, size: 48, color: AurixTokens.muted.withValues(alpha: 0.3)),
                      const SizedBox(height: 12),
                      const Text('Нет записей', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
                    ],
                  ),
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 6),
                itemBuilder: (context, i) {
                  final log = filtered[i];
                  final color = _actionColor(log.action);
                  return Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AurixTokens.bg1,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AurixTokens.border),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: color.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(_actionIcon(log.action), size: 16, color: color),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                log.actionLabel,
                                style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${log.targetType}${log.targetId != null ? " • ${log.targetId!.substring(0, 8)}..." : ""}',
                                style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                              ),
                              if (log.details.isNotEmpty) ...[
                                const SizedBox(height: 4),
                                Text(
                                  log.details.entries.map((e) => '${e.key}: ${e.value}').join(', '),
                                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11, fontFamily: 'monospace'),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ],
                          ),
                        ),
                        Text(
                          DateFormat('dd.MM HH:mm').format(log.createdAt),
                          style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                        ),
                      ],
                    ),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator(color: AurixTokens.orange)),
            error: (e, _) => _ErrorRetry(
              message: e.toString(),
              onRetry: () => ref.invalidate(adminLogsProvider),
            ),
          ),
        ),
      ],
    );
  }

  String _actionLabel(String action) => switch (action) {
        'release_status_changed' => 'Релизы',
        'user_role_changed' => 'Роли',
        'user_plan_changed' => 'Планы',
        'user_suspended' => 'Блокировки',
        'user_activated' => 'Разблокировки',
        'ticket_replied' => 'Ответы',
        'ticket_closed' => 'Закрытия',
        'report_imported' => 'Импорт',
        _ => action,
      };
}

class _ErrorRetry extends StatelessWidget {
  const _ErrorRetry({required this.message, required this.onRetry});
  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 40, color: Colors.redAccent.withValues(alpha: 0.6)),
            const SizedBox(height: 12),
            Text(
              message.replaceAll('Exception: ', ''),
              style: const TextStyle(color: AurixTokens.muted, fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            TextButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh, size: 18),
              label: const Text('Повторить'),
              style: TextButton.styleFrom(foregroundColor: AurixTokens.orange),
            ),
          ],
        ),
      ),
    );
  }
}
