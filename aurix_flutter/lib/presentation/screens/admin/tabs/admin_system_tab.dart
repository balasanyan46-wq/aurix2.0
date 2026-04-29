import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:aurix_flutter/design/aurix_theme.dart';
import 'package:aurix_flutter/core/api/api_client.dart';
import 'package:aurix_flutter/data/providers/admin_providers.dart';
import 'package:aurix_flutter/data/providers/promo_providers.dart';
import 'package:aurix_flutter/data/models/admin_log_model.dart';
import 'package:aurix_flutter/data/models/support_ticket_model.dart';
import 'package:aurix_flutter/data/models/release_delete_request_model.dart';
import 'package:aurix_flutter/presentation/screens/admin/widgets/confirm_dangerous_dialog.dart';
import 'package:aurix_flutter/data/models/promo_request_model.dart';

class AdminSystemTab extends ConsumerStatefulWidget {
  const AdminSystemTab({super.key});

  @override
  ConsumerState<AdminSystemTab> createState() => _AdminSystemTabState();
}

class _AdminSystemTabState extends ConsumerState<AdminSystemTab> {
  int _section = 0;
  String _logSearch = '';
  String _ticketFilter = 'all';
  String _deleteFilter = 'all';
  String _promoFilter = 'all';

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: AurixTokens.bg1.withValues(alpha: 0.84),
          child: Row(
            children: [
              _seg(0, 'Логи', Icons.history_rounded),
              const SizedBox(width: 6),
              _seg(1, 'Поддержка', Icons.support_agent_rounded),
              const SizedBox(width: 6),
              _seg(2, 'Удаление', Icons.delete_sweep_rounded),
              const SizedBox(width: 6),
              _seg(3, 'Промо', Icons.campaign_rounded),
              const SizedBox(width: 6),
              _seg(4, 'Фрод', Icons.shield_rounded),
            ],
          ),
        ),
        Expanded(
          child: IndexedStack(
            index: _section,
            children: [
              _buildLogs(),
              _buildSupport(),
              _buildDeleteRequests(),
              _buildPromo(),
              _buildFraud(),
            ],
          ),
        ),
      ],
    );
  }

  Widget _seg(int idx, String label, IconData icon) {
    final selected = _section == idx;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _section = idx),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: selected
                ? AurixTokens.accent.withValues(alpha: 0.2)
                : AurixTokens.bg2.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: selected
                  ? AurixTokens.accent.withValues(alpha: 0.36)
                  : AurixTokens.stroke(0.12),
            ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, size: 14, color: selected ? AurixTokens.accent : AurixTokens.muted),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  label,
                  style: TextStyle(
                    color: selected ? AurixTokens.text : AurixTokens.muted,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ── Logs section ───────────────────────────────────────

  Widget _buildLogs() {
    final logsAsync = ref.watch(adminLogsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AurixTokens.bg1.withValues(alpha: 0.5),
          child: TextField(
            style: const TextStyle(color: AurixTokens.text, fontSize: 13),
            decoration: InputDecoration(
              hintText: 'Поиск по действию...',
              hintStyle: const TextStyle(color: AurixTokens.muted, fontSize: 13),
              prefixIcon: const Icon(Icons.search, color: AurixTokens.muted, size: 18),
              filled: true,
              fillColor: AurixTokens.bg2.withValues(alpha: 0.9),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AurixTokens.border)),
              contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              isDense: true,
            ),
            onChanged: (v) => setState(() => _logSearch = v.toLowerCase()),
          ),
        ),
        Expanded(
          child: logsAsync.when(
            data: (logs) {
              final filtered = _logSearch.isEmpty
                  ? logs
                  : logs.where((l) => l.action.toLowerCase().contains(_logSearch) || l.targetType.toLowerCase().contains(_logSearch)).toList();

              if (filtered.isEmpty) return Center(child: Text('Нет логов', style: TextStyle(color: AurixTokens.muted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 4),
                itemBuilder: (context, i) {
                  final log = filtered[i];
                  return _LogRow(log: log);
                },
              );
            },
            loading: () => _loading(),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  // ── Support section ────────────────────────────────────

  Widget _buildSupport() {
    final ticketsAsync = ref.watch(allTicketsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AurixTokens.bg1.withValues(alpha: 0.5),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'open', 'in_progress', 'resolved', 'closed'].map((s) {
                final selected = _ticketFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _ticketFilter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? AurixTokens.accent.withValues(alpha: 0.2) : AurixTokens.bg2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? AurixTokens.accent.withValues(alpha: 0.36) : AurixTokens.stroke(0.12)),
                      ),
                      child: Text(_ticketStatusLabel(s), style: TextStyle(color: selected ? AurixTokens.text : AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: ticketsAsync.when(
            data: (tickets) {
              final filtered = _ticketFilter == 'all' ? tickets : tickets.where((t) => t.status == _ticketFilter).toList();

              if (filtered.isEmpty) return Center(child: Text('Нет тикетов', style: TextStyle(color: AurixTokens.muted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _TicketCard(ticket: filtered[i]),
              );
            },
            loading: () => _loading(),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  // ── Delete requests ────────────────────────────────────

  Widget _buildDeleteRequests() {
    final reqAsync = ref.watch(allReleaseDeleteRequestsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AurixTokens.bg1.withValues(alpha: 0.5),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'pending', 'approved', 'rejected'].map((s) {
                final selected = _deleteFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _deleteFilter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? AurixTokens.accent.withValues(alpha: 0.2) : AurixTokens.bg2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? AurixTokens.accent.withValues(alpha: 0.36) : AurixTokens.stroke(0.12)),
                      ),
                      child: Text(_deleteStatusLabel(s), style: TextStyle(color: selected ? AurixTokens.text : AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: reqAsync.when(
            data: (requests) {
              final filtered = _deleteFilter == 'all' ? requests : requests.where((r) => r.status == _deleteFilter).toList();

              if (filtered.isEmpty) return Center(child: Text('Нет запросов', style: TextStyle(color: AurixTokens.muted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _DeleteRequestCard(
                  request: filtered[i],
                  onAction: () {
                    ref.invalidate(allReleaseDeleteRequestsProvider);
                  },
                ),
              );
            },
            loading: () => _loading(),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  // ── Promo section ──────────────────────────────────────

  Widget _buildPromo() {
    final promoAsync = ref.watch(adminPromoRequestsProvider);

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          color: AurixTokens.bg1.withValues(alpha: 0.5),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: ['all', 'pending', 'in_progress', 'completed', 'rejected'].map((s) {
                final selected = _promoFilter == s;
                return Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: GestureDetector(
                    onTap: () => setState(() => _promoFilter = s),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: selected ? AurixTokens.accent.withValues(alpha: 0.2) : AurixTokens.bg2,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: selected ? AurixTokens.accent.withValues(alpha: 0.36) : AurixTokens.stroke(0.12)),
                      ),
                      child: Text(_promoStatusLabel(s), style: TextStyle(color: selected ? AurixTokens.text : AurixTokens.muted, fontSize: 12, fontWeight: FontWeight.w600)),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        Expanded(
          child: promoAsync.when(
            data: (promos) {
              final filtered = _promoFilter == 'all' ? promos : promos.where((p) => p.status == _promoFilter).toList();

              if (filtered.isEmpty) return Center(child: Text('Нет промо-заявок', style: TextStyle(color: AurixTokens.muted)));

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: filtered.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, i) => _PromoCard(promo: filtered[i]),
              );
            },
            loading: () => _loading(),
            error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted))),
          ),
        ),
      ],
    );
  }

  // ── Fraud section ───────────────────────────────────────

  Widget _buildFraud() {
    final signalsAsync = ref.watch(adminSignalsProvider);

    return signalsAsync.when(
      data: (data) {
        final alerts = data.fraudAlerts;
        // Also include high-priority risk signals
        final riskSignals = data.signals.where((s) => s.type == 'risk' && s.priority == 'high').toList();

        if (alerts.isEmpty && riskSignals.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.shield_rounded, size: 48, color: AurixTokens.positive.withValues(alpha: 0.4)),
                const SizedBox(height: 12),
                const Text('Подозрительная активность не обнаружена', style: TextStyle(color: AurixTokens.muted, fontSize: 14)),
              ],
            ),
          );
        }

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (alerts.isNotEmpty) ...[
              const Text('ПОДОЗРИТЕЛЬНАЯ АКТИВНОСТЬ', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              ...alerts.map((a) => _FraudAlertCard(alert: a, onBlock: () {
                ref.invalidate(adminSignalsProvider);
              })),
            ],
            if (riskSignals.isNotEmpty) ...[
              const SizedBox(height: 20),
              const Text('СИГНАЛЫ РИСКА', style: TextStyle(color: AurixTokens.muted, fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.5)),
              const SizedBox(height: 10),
              ...riskSignals.map((s) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: AurixTokens.danger.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.2)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_rounded, size: 16, color: AurixTokens.danger),
                      const SizedBox(width: 10),
                      Expanded(child: Text(s.message, style: const TextStyle(color: AurixTokens.text, fontSize: 13))),
                    ],
                  ),
                ),
              )),
            ],
          ],
        );
      },
      loading: () => _loading(),
      error: (e, _) => Center(child: Text('Ошибка: $e', style: const TextStyle(color: AurixTokens.muted))),
    );
  }

  // ── Shared helpers ─────────────────────────────────────

  static String _ticketStatusLabel(String s) => switch (s) { 'all' => 'Все', 'open' => 'Открытые', 'in_progress' => 'В работе', 'resolved' => 'Решённые', 'closed' => 'Закрытые', _ => s };
  static String _deleteStatusLabel(String s) => switch (s) { 'all' => 'Все', 'pending' => 'Ожидают', 'approved' => 'Одобрены', 'rejected' => 'Отклонены', _ => s };
  static String _promoStatusLabel(String s) => switch (s) { 'all' => 'Все', 'pending' => 'Ожидают', 'in_progress' => 'В работе', 'completed' => 'Завершены', 'rejected' => 'Отклонены', _ => s };

  static Widget _loading() => const Center(child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator(color: AurixTokens.orange, strokeWidth: 2)));
}

// ── Log row ──────────────────────────────────────────────

class _LogRow extends StatelessWidget {
  const _LogRow({required this.log});
  final AdminLogModel log;

  @override
  Widget build(BuildContext context) {
    final iconData = switch (log.action) {
      'release_status_changed' => Icons.check_circle_rounded,
      'user_suspended' => Icons.block_rounded,
      'user_activated' => Icons.check_rounded,
      'user_role_changed' => Icons.admin_panel_settings_rounded,
      'user_plan_changed' => Icons.workspace_premium_rounded,
      'ticket_replied' => Icons.reply_rounded,
      'ticket_closed' => Icons.close_rounded,
      'report_imported' => Icons.upload_file_rounded,
      _ => Icons.history_rounded,
    };
    final iconColor = switch (log.action) {
      'user_suspended' => AurixTokens.danger,
      'user_activated' || 'release_status_changed' => AurixTokens.positive,
      'report_imported' => AurixTokens.accent,
      _ => AurixTokens.muted,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: AurixTokens.stroke(0.16)),
      ),
      child: Row(
        children: [
          Icon(iconData, size: 16, color: iconColor),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(log.actionLabel, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w500)),
                if (log.targetType.isNotEmpty)
                  Text('${log.targetType}${log.targetId != null ? ' #${log.targetId}' : ''}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
              ],
            ),
          ),
          Text(
            DateFormat('dd.MM HH:mm').format(log.createdAt),
            style: const TextStyle(color: AurixTokens.muted, fontSize: 10, fontFeatures: AurixTokens.tabularFigures),
          ),
        ],
      ),
    );
  }
}

// ── Ticket card ──────────────────────────────────────────

class _TicketCard extends StatelessWidget {
  const _TicketCard({required this.ticket});
  final SupportTicketModel ticket;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (ticket.status) {
      'open' => AurixTokens.orange,
      'in_progress' => AurixTokens.accent,
      'resolved' => AurixTokens.positive,
      'closed' => AurixTokens.muted,
      _ => AurixTokens.textSecondary,
    };
    final statusLabel = switch (ticket.status) {
      'open' => 'Открыт',
      'in_progress' => 'В работе',
      'resolved' => 'Решён',
      'closed' => 'Закрыт',
      _ => ticket.status,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.support_agent_rounded, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ticket.subject, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600), maxLines: 1, overflow: TextOverflow.ellipsis),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                    const SizedBox(width: 8),
                    Text('User #${ticket.userId}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                    const Spacer(),
                    Text(DateFormat('dd.MM.yy').format(ticket.createdAt), style: const TextStyle(color: AurixTokens.muted, fontSize: 10)),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Delete request card ──────────────────────────────────

class _DeleteRequestCard extends StatefulWidget {
  const _DeleteRequestCard({required this.request, required this.onAction});
  final ReleaseDeleteRequestModel request;
  final VoidCallback onAction;

  @override
  State<_DeleteRequestCard> createState() => _DeleteRequestCardState();
}

class _DeleteRequestCardState extends State<_DeleteRequestCard> {
  bool _loading = false;

  Future<void> _approve() async {
    setState(() => _loading = true);
    try {
      await ApiClient.post('/rpc/admin_process_release_delete_request', data: {
        'p_request_id': widget.request.id,
        'p_decision': 'approve',
      });
      widget.onAction();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _reject() async {
    setState(() => _loading = true);
    try {
      await ApiClient.post('/rpc/admin_process_release_delete_request', data: {
        'p_request_id': widget.request.id,
        'p_decision': 'reject',
      });
      widget.onAction();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.request;
    final statusColor = switch (r.status) {
      'pending' => AurixTokens.orange,
      'approved' => AurixTokens.positive,
      'rejected' => AurixTokens.danger,
      _ => AurixTokens.muted,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                child: Icon(Icons.delete_sweep_rounded, size: 18, color: statusColor),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Release #${r.releaseId}', style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    Text('User #${r.requesterId}  •  ${DateFormat('dd.MM.yy').format(r.createdAt)}', style: const TextStyle(color: AurixTokens.muted, fontSize: 11)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                child: Text(r.statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          if (r.reason != null && r.reason!.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(r.reason!, style: const TextStyle(color: AurixTokens.textSecondary, fontSize: 12, height: 1.4), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          if (r.isPending) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                SizedBox(
                  height: 30,
                  child: ElevatedButton.icon(
                    onPressed: _loading ? null : _approve,
                    icon: _loading ? const SizedBox(width: 12, height: 12, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.check_rounded, size: 14),
                    label: const Text('Одобрить', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AurixTokens.positive.withValues(alpha: 0.8),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  height: 30,
                  child: OutlinedButton.icon(
                    onPressed: _loading ? null : _reject,
                    icon: const Icon(Icons.close_rounded, size: 14),
                    label: const Text('Отклонить', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700)),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AurixTokens.danger,
                      side: BorderSide(color: AurixTokens.danger.withValues(alpha: 0.4)),
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ── Promo card ───────────────────────────────────────────

class _PromoCard extends StatelessWidget {
  const _PromoCard({required this.promo});
  final PromoRequestModel promo;

  @override
  Widget build(BuildContext context) {
    final statusColor = switch (promo.status) {
      'pending' => AurixTokens.orange,
      'in_progress' => AurixTokens.accent,
      'completed' => AurixTokens.positive,
      'rejected' => AurixTokens.danger,
      _ => AurixTokens.muted,
    };
    final statusLabel = switch (promo.status) {
      'pending' => 'Ожидает',
      'in_progress' => 'В работе',
      'completed' => 'Завершена',
      'rejected' => 'Отклонена',
      _ => promo.status,
    };
    final typeLabel = switch (promo.type) {
      'dsp_pitch' => 'DSP Pitch',
      'aurix_pitch' => 'Aurix Pitch',
      'influencer' => 'Influencer',
      'ads' => 'Реклама',
      _ => promo.type,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AurixTokens.bg1.withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AurixTokens.stroke(0.24)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
            child: Icon(Icons.campaign_rounded, size: 18, color: statusColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(typeLabel, style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w600)),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.15), borderRadius: BorderRadius.circular(4)),
                      child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  'User #${promo.userId}  •  Release #${promo.releaseId}  •  ${DateFormat('dd.MM.yy').format(promo.createdAt)}',
                  style: const TextStyle(color: AurixTokens.muted, fontSize: 11),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ── Fraud alert card ─────────────────────────────────────

class _FraudAlertCard extends StatefulWidget {
  const _FraudAlertCard({required this.alert, required this.onBlock});
  final Map<String, dynamic> alert;
  final VoidCallback onBlock;

  @override
  State<_FraudAlertCard> createState() => _FraudAlertCardState();
}

class _FraudAlertCardState extends State<_FraudAlertCard> {
  bool _loading = false;

  Future<void> _blockUser() async {
    final userId = widget.alert['user_id'];
    if (userId == null) return;
    // SAFETY: confirm dialog обязателен — fraud-блок без причины раньше
    // часто оказывался ошибочным. Заставляем оператора кратко описать что увидел.
    final res = await showDangerousActionDialog(
      context,
      title: 'Заблокировать user #$userId по сигналу фрода?',
      description: 'Опишите причину блокировки (что именно показалось подозрительным).',
      confirmLabel: 'Заблокировать',
    );
    if (res == null) return;
    setState(() => _loading = true);
    try {
      await ApiClient.post('/admin/users/$userId/block', data: res);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User #$userId заблокирован'), backgroundColor: AurixTokens.positive, behavior: SnackBarBehavior.floating),
        );
      }
      widget.onBlock();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Ошибка: $e'), backgroundColor: AurixTokens.danger));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final userId = widget.alert['user_id']?.toString() ?? '?';
    final cnt = widget.alert['cnt'] ?? 0;
    final events = (widget.alert['events'] as List?)?.join(', ') ?? '';

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AurixTokens.danger.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AurixTokens.danger.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AurixTokens.danger.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
              child: const Icon(Icons.shield_rounded, size: 20, color: AurixTokens.danger),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('User #$userId', style: const TextStyle(color: AurixTokens.text, fontSize: 13, fontWeight: FontWeight.w700)),
                  const SizedBox(height: 2),
                  Text('$cnt событий/час', style: const TextStyle(color: AurixTokens.danger, fontSize: 12, fontWeight: FontWeight.w600)),
                  if (events.isNotEmpty)
                    Text(events, style: const TextStyle(color: AurixTokens.muted, fontSize: 10), maxLines: 1, overflow: TextOverflow.ellipsis),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Column(
              children: [
                SizedBox(
                  height: 28,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _blockUser,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AurixTokens.danger.withValues(alpha: 0.85),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: _loading
                        ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Блок', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
